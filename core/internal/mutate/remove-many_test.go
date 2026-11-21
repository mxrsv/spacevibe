package mutate

import (
	"os"
	"slices"
	"strings"
	"testing"

	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/inventory"
	"spacevibe.dev/core/internal/roots"
)

// RB-E4: loadout.removeMany. Every test writes under t.TempDir() (TestMain arms the real-home guard).

// mixedHome has a skill in both CLIs and in ~/.agents/skills, an agent in Codex, two Claude hooks and one Codex hook,
// with hand-made spacing and a secret in settings.json, which Undo must give back byte for byte.
func mixedHome(t *testing.T) (tempHome, roots.Roots) {
	h := newHome(t)
	h.write(".claude/skills/foo/SKILL.md", skillMd("foo", "claude copy"))
	h.write(".codex/skills/foo/SKILL.md", skillMd("foo", "codex copy"))
	h.write(".agents/skills/foo/SKILL.md", skillMd("foo", "shared copy"))
	h.write(".claude/skills/keep/SKILL.md", skillMd("keep", "stays"))
	h.write(".codex/agents/rev.toml", "name = \"rev\"\ndescription = \"Reviews\"\ndeveloper_instructions = \"Review.\"\n")
	h.write(".claude/settings.json", "{\n    \"env\": { \"TOKEN\": \"secret\" },\n    \"hooks\": {\n        \"Stop\": [ { \"hooks\": [ { \"type\": \"command\", \"command\": \"echo one\" }, { \"type\": \"command\", \"command\": \"echo two\" } ] } ],\n        \"PreToolUse\": [ { \"matcher\": \"Bash\", \"hooks\": [ { \"type\": \"command\", \"command\": \"echo keep\" } ] } ]\n    }\n}\n")
	h.write(".codex/hooks.json", "{\"hooks\":{\"Stop\":[{\"hooks\":[{\"type\":\"command\",\"command\":\"echo codex\"}]}]}}\n")
	return h, h.roots()
}

func hookID(t *testing.T, r roots.Roots, cli inventory.CLI, command string) string {
	t.Helper()
	for _, hook := range inventory.ReadMembers(r).Hooks {
		if hook.CLI == cli && hook.Command == command {
			return hook.ID
		}
	}
	t.Fatalf("no %s hook %q", cli, command)
	return ""
}

func TestRemoveManyMixedOneEntryOneUndo(t *testing.T) {
	h, r := mixedHome(t)
	before := tree(t, h.root)
	ids := []string{
		memberID(t, r, h.path(".claude/skills/foo")), memberID(t, r, h.path(".codex/skills/foo")),
		memberID(t, r, h.path(".agents/skills/foo")), memberID(t, r, h.path(".codex/agents/rev.toml")),
		hookID(t, r, inventory.Claude, "echo one"), hookID(t, r, inventory.Codex, "echo codex"),
		hookID(t, r, inventory.Claude, "echo two"),
	}
	res := must(RemoveMany(r, ids))
	if res.Entry.Count != 7 || res.Entry.Label != "Removed 1 skill, 1 agent and 3 hooks from Claude Code and Codex" ||
		!slices.Equal(res.Lost, []string{"claude", "codex"}) {
		t.Fatalf("result %+v", res)
	}
	for _, gone := range []string{".claude/skills/foo", ".codex/skills/foo", ".agents/skills/foo", ".codex/agents/rev.toml"} {
		if exists(h.path(gone)) {
			t.Errorf("%s is still there", gone)
		}
	}
	commands := []string{}
	for _, hook := range inventory.Read(r).Hooks {
		commands = append(commands, hook.Command)
	}
	if !slices.Equal(commands, []string{"echo keep"}) {
		t.Fatalf("hooks left %v", commands)
	}
	if len(historyOf(t, r)) != 1 {
		t.Fatal("not one journal entry")
	}
	must(Undo(r, res.Entry.ID))
	wantSameTree(t, before, tree(t, h.root))
}

// Hooks only, from two files: not the one-file dead-hook batch, so Undo groups the ops by the edit that made them.
func TestRemoveManyHooksOfTwoFilesUndo(t *testing.T) {
	h, r := mixedHome(t)
	before := tree(t, h.root)
	res := must(RemoveMany(r, []string{hookID(t, r, inventory.Claude, "echo one"), hookID(t, r, inventory.Claude, "echo two"), hookID(t, r, inventory.Codex, "echo codex")}))
	if res.Entry.Label != "Removed 3 hooks from Claude Code and Codex" || res.Entry.Count != 3 {
		t.Fatalf("result %+v", res)
	}
	must(Undo(r, res.Entry.ID))
	wantSameTree(t, before, tree(t, h.root))

	one := must(RemoveMany(r, []string{hookID(t, r, inventory.Claude, "echo one"), hookID(t, r, inventory.Claude, "echo two")}))
	must(Undo(r, one.Entry.ID))
	wantSameTree(t, before, tree(t, h.root))
}

func TestRemoveManyRefusesBeforeAnyChange(t *testing.T) {
	h, r := mixedHome(t)
	h.symlink(h.path(".claude/skills/keep"), ".codex/skills/keep")
	before := tree(t, h.root)
	foo := memberID(t, r, h.path(".claude/skills/foo"))
	for _, c := range []struct {
		name   string
		ids    []string
		status int
		says   string
	}{
		{"empty", nil, coreerr.StatusBadRequest, "Pick at least one item"},
		{"gone", []string{foo, "claude:skill:local:nope"}, coreerr.StatusNotFound, msgRefreshList},
		{"a file Codex reaches by a link", []string{foo, memberID(t, r, h.path(".claude/skills/keep"))}, coreerr.StatusConflict,
			"keep is one file that Claude Code and Codex read, so pick every copy of it to remove it."},
	} {
		_, err := RemoveMany(r, c.ids)
		if msg := wantErr(t, err, c.status); !strings.Contains(msg, c.says) {
			t.Errorf("%s: %q", c.name, msg)
		}
	}
	wantSameTree(t, before, tree(t, h.root))
	if len(historyOf(t, r)) != 0 {
		t.Fatal("a refusal wrote a journal entry")
	}
	// With the link picked too, both go.
	res := must(RemoveMany(r, []string{memberID(t, r, h.path(".claude/skills/keep")), memberID(t, r, h.path(".codex/skills/keep"))}))
	if res.Entry.Count != 2 || exists(h.path(".codex/skills/keep")) || exists(h.path(".claude/skills/keep")) {
		t.Fatalf("result %+v", res)
	}
	// A second copy only: nobody lost the item.
	copyOnly := must(RemoveMany(r, []string{memberID(t, r, h.path(".agents/skills/foo"))}))
	if copyOnly.Entry.Label != "Removed a copy of skill foo" || len(copyOnly.Lost) != 0 || copyOnly.Lost == nil {
		t.Fatalf("result %+v", copyOnly)
	}
}

func TestRemoveManyRefusesPluginItems(t *testing.T) {
	h := newCopy(t)
	var plugin, user inventory.Item
	for _, item := range inventory.ReadMembers(h.r).Items {
		if plugin.ID == "" && !item.Removable {
			plugin = item
		}
		if user.ID == "" && item.Removable {
			user = item
		}
	}
	_, err := RemoveMany(h.r, []string{user.ID, plugin.ID})
	wantErr(t, err, coreerr.StatusForbidden)
	if !exists(user.Path) || len(historyOf(t, h.r)) != 0 {
		t.Fatal("a refused batch changed something")
	}
}

// A step that fails after others were written puts them back: here the Codex hook file cannot be written (its folder
// is read-only), after a skill was moved and the Claude hooks were edited.
func TestRemoveManyRollsBackWhenALaterFileFails(t *testing.T) {
	h, r := mixedHome(t)
	ids := []string{memberID(t, r, h.path(".claude/skills/keep")), hookID(t, r, inventory.Claude, "echo one"), hookID(t, r, inventory.Codex, "echo codex")}
	before := tree(t, h.root)
	if err := os.Chmod(h.path(".codex"), 0o555); err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.Chmod(h.path(".codex"), 0o755) }()
	if _, err := RemoveMany(r, ids); err == nil {
		t.Fatal("the failed write was not reported")
	}
	if err := os.Chmod(h.path(".codex"), 0o755); err != nil {
		t.Fatal(err)
	}
	wantSameTree(t, before, tree(t, h.root))
	if len(historyOf(t, r)) != 0 {
		t.Fatal("a failed batch wrote a journal entry")
	}
}

func TestRemoveManyUnreadableJournal(t *testing.T) {
	h, r := mixedHome(t)
	h.write(".spacevibe/journal.json", "not json")
	_, err := RemoveMany(r, []string{memberID(t, r, h.path(".claude/skills/keep"))})
	wantErr(t, err, coreerr.StatusConflict)
	if !exists(h.path(".claude/skills/keep")) {
		t.Fatal("removed with an unreadable journal")
	}
}
