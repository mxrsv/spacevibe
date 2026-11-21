package mutate

import (
	"io/fs"
	"maps"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/inventory"
	"spacevibe.dev/core/internal/roots"
	"spacevibe.dev/core/internal/usage"
)

// RB-E3: loadout.copyTo and loadout.removeFrom. Every test writes under t.TempDir() (TestMain arms the real-home guard).

// tree is every path under the home except the data folder, with its file bytes, link text or "dir" and the mode: the
// byte-for-byte picture an Undo must restore.
func tree(t *testing.T, root string) map[string]string {
	t.Helper()
	out := map[string]string{}
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(root, path)
		if rel == ".spacevibe" {
			return filepath.SkipDir
		}
		info, err := os.Lstat(path)
		if err != nil {
			return err
		}
		switch {
		case info.Mode()&os.ModeSymlink != 0:
			target, _ := os.Readlink(path)
			out[rel] = "link:" + target
		case info.IsDir():
			out[rel] = "dir " + info.Mode().Perm().String()
		default:
			data, _ := os.ReadFile(path)
			out[rel] = info.Mode().Perm().String() + " " + string(data)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return out
}

func wantSameTree(t *testing.T, before, after map[string]string) {
	t.Helper()
	if maps.Equal(before, after) {
		return
	}
	for k, v := range before {
		if after[k] != v {
			t.Errorf("%s: %q, was %q", k, after[k], v)
		}
	}
	for k, v := range after {
		if _, ok := before[k]; !ok {
			t.Errorf("%s appeared: %q", k, v)
		}
	}
}

// memberID is the id of the member with that path, read through ReadMembers (so ~/.agents/skills counts).
func memberID(t *testing.T, r roots.Roots, path string) string {
	t.Helper()
	for _, item := range inventory.ReadMembers(r).Items {
		if item.Path == path {
			return item.ID
		}
	}
	t.Fatalf("no member at %s", path)
	return ""
}

// twoCLIHome has Claude Code and Codex installed, each with a copy of the skill foo, and the agent rev in Claude Code.
func twoCLIHome(t *testing.T) (tempHome, roots.Roots) {
	h := newHome(t)
	h.write(".claude/skills/foo/SKILL.md", skillMd("foo", "claude copy"))
	h.write(".codex/skills/foo/SKILL.md", skillMd("foo", "codex copy"))
	h.write(".claude/agents/rev.md", "---\nname: rev\ndescription: Reviews\n---\n\nReview the change.\n")
	return h, h.roots()
}

func TestCopyToSkillAndAgentThenUndo(t *testing.T) {
	h := newHome(t)
	h.write(".claude/skills/solo/SKILL.md", skillMd("solo", "only claude"))
	h.write(".claude/skills/solo/scripts/run.sh", "#!/bin/sh\n")
	h.write(".claude/agents/rev.md", "---\nname: rev\ndescription: Reviews\n---\n\nReview the change.\n")
	if err := os.MkdirAll(h.path(".codex"), 0o755); err != nil {
		t.Fatal(err)
	}
	r := h.roots()
	before := tree(t, h.root)

	res := must(CopyTo(r, memberID(t, r, h.path(".claude/skills/solo")), []string{"codex"}))
	if res.Entry.Label != "Copied skill solo to Codex" || res.Entry.Count != 1 || len(res.AlsoReaders) != 0 || res.AlsoReaders == nil {
		t.Fatalf("result %+v", res)
	}
	if h.read(".codex/skills/solo/SKILL.md") != skillMd("solo", "only claude") || h.read(".codex/skills/solo/scripts/run.sh") != "#!/bin/sh\n" {
		t.Fatal("the copy is not the source")
	}
	agent := must(CopyTo(r, memberID(t, r, h.path(".claude/agents/rev.md")), []string{"codex"}))
	if agent.Entry.Label != "Copied agent rev to Codex" || !strings.Contains(h.read(".codex/agents/rev.toml"), "Review the change.") {
		t.Fatalf("agent copy %+v", agent)
	}

	must(Undo(r, agent.Entry.ID))
	must(Undo(r, res.Entry.ID))
	after := tree(t, h.root)
	// The copies are gone; the Codex folders they created stay (empty), as a v5 copy leaves them.
	delete(after, ".codex/skills")
	delete(after, ".codex/agents")
	wantSameTree(t, before, after)
}

func TestCopyToRefusals(t *testing.T) {
	h, r := twoCLIHome(t)
	h.write(".agents/skills/shared/SKILL.md", skillMd("shared", "codex reads it here"))
	h.write(".claude/skills/shared/SKILL.md", skillMd("shared", "claude copy"))
	claudeFoo := memberID(t, r, h.path(".claude/skills/foo"))
	before := tree(t, h.root)
	for _, c := range []struct {
		name    string
		id      string
		targets []string
		status  int
		says    string
	}{
		{"no target", claudeFoo, nil, coreerr.StatusBadRequest, "Pick at least one CLI."},
		{"unknown CLI", claudeFoo, []string{"gemini"}, coreerr.StatusBadRequest, msgNotAKnownCLI},
		{"has it", claudeFoo, []string{"codex"}, coreerr.StatusConflict, "Codex already has foo"},
		{"itself", memberID(t, r, h.path(".claude/agents/rev.md")), []string{"codex", "claude"}, coreerr.StatusConflict, "Claude Code already has rev"},
		{"shared folder counts", memberID(t, r, h.path(".claude/skills/shared")), []string{"codex"}, coreerr.StatusConflict, "Codex already has shared"},
		{"gone", "claude:skill:local:nope", []string{"codex"}, coreerr.StatusNotFound, msgRefreshList},
	} {
		_, err := CopyTo(r, c.id, c.targets)
		if msg := wantErr(t, err, c.status); !strings.Contains(msg, c.says) {
			t.Errorf("%s: %q", c.name, msg)
		}
	}
	wantSameTree(t, before, tree(t, h.root))
	if len(historyOf(t, r)) != 0 {
		t.Fatal("a refusal wrote a journal entry")
	}
}

func TestCopyToNotInstalledAndHook(t *testing.T) {
	h := newHome(t)
	h.write(".claude/skills/solo/SKILL.md", skillMd("solo", "only claude"))
	h.write(".claude/settings.json", `{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo hi"}]}]}}`)
	r := h.roots()
	_, err := CopyTo(r, memberID(t, r, h.path(".claude/skills/solo")), []string{"codex"})
	if msg := wantErr(t, err, coreerr.StatusConflict); !strings.Contains(msg, "not installed") {
		t.Fatal(msg)
	}
	hook := inventory.Read(r).Hooks[0]
	_, err = CopyTo(r, hook.ID, []string{"codex"})
	wantErr(t, err, coreerr.StatusBadRequest)
	if exists(h.path(".codex")) {
		t.Fatal("a refused copy made the Codex folder")
	}
}

// Plugin and project items are read-only for the per-CLI writes (spec "Project items": 403).
func TestPerCLIRefusesPluginAndProjectItems(t *testing.T) {
	h := newCopy(t)
	var plugin, project inventory.Item
	for _, item := range inventory.ReadMembers(h.r).Items {
		switch {
		case plugin.ID == "" && item.Scope == inventory.ScopeGlobal && !item.Removable:
			plugin = item
		case project.ID == "" && item.Scope == inventory.ScopeProject:
			project = item
		}
	}
	if plugin.ID == "" || project.ID == "" {
		t.Fatal("the fixture lacks a plugin or a project item")
	}
	other := string(plugin.CLI.Other())
	_, err := CopyTo(h.r, plugin.ID, []string{other})
	if msg := wantErr(t, err, coreerr.StatusForbidden); !strings.Contains(msg, "plugin") {
		t.Error(msg)
	}
	_, err = RemoveFrom(h.r, plugin.ID, []string{string(plugin.CLI)})
	if msg := wantErr(t, err, coreerr.StatusForbidden); !strings.Contains(msg, "plugin") {
		t.Error(msg)
	}
	_, err = CopyTo(h.r, project.ID, []string{string(project.CLI.Other())})
	if msg := wantErr(t, err, coreerr.StatusForbidden); !strings.Contains(msg, "project folder") {
		t.Error(msg)
	}
	_, err = RemoveFrom(h.r, project.ID, []string{string(project.CLI)})
	if msg := wantErr(t, err, coreerr.StatusForbidden); !strings.Contains(msg, "project folder") {
		t.Error(msg)
	}
	if len(historyOf(t, h.r)) != 0 {
		t.Fatal("a refusal wrote a journal entry")
	}
}

func TestRemoveFromOneCLIThenBothAndUndo(t *testing.T) {
	h, r := twoCLIHome(t)
	before := tree(t, h.root)
	id := memberID(t, r, h.path(".claude/skills/foo"))

	one := must(RemoveFrom(r, id, []string{"codex"}))
	if one.Entry.Label != "Removed skill foo from Codex" || !slices.Equal(one.Lost, []string{"codex"}) || !slices.Equal(one.StillHave, []string{"claude"}) {
		t.Fatalf("result %+v", one)
	}
	if exists(h.path(".codex/skills/foo")) || !exists(h.path(".claude/skills/foo")) {
		t.Fatal("the wrong copy went")
	}
	must(Undo(r, one.Entry.ID))
	wantSameTree(t, before, tree(t, h.root))

	both := must(RemoveFrom(r, id, []string{"claude", "codex", "claude"}))
	if both.Entry.Count != 2 || both.Entry.Label != "Removed skill foo from Claude Code and Codex" || len(both.StillHave) != 0 || both.StillHave == nil {
		t.Fatalf("result %+v", both)
	}
	if exists(h.path(".codex/skills/foo")) || exists(h.path(".claude/skills/foo")) {
		t.Fatal("a copy is left")
	}
	if len(trashFiles(r)) != 2 {
		t.Fatalf("trash %v", trashFiles(r))
	}
	must(Undo(r, both.Entry.ID))
	wantSameTree(t, before, tree(t, h.root))

	_, err := RemoveFrom(r, memberID(t, r, h.path(".claude/agents/rev.md")), []string{"codex"})
	if msg := wantErr(t, err, coreerr.StatusConflict); msg != "Codex does not have rev, so nothing was removed." {
		t.Fatal(msg)
	}
}

// Codex reads ~/.agents/skills beside its own folder: turning Codex off removes both copies (RD-R11 "removes every file
// it reads the item from"), they go to the SpaceVibe trash, and one Undo brings both back (RB-E2 findings F1, F4).
func TestRemoveFromCodexTakesTheSharedCopyToo(t *testing.T) {
	h, r := twoCLIHome(t)
	h.write(".agents/skills/foo/SKILL.md", skillMd("foo", "shared copy"))
	h.write(".agents/skills/only-shared/SKILL.md", skillMd("only-shared", "codex reads it here only"))
	before := tree(t, h.root)

	res := must(RemoveFrom(r, memberID(t, r, h.path(".agents/skills/foo")), []string{"codex"}))
	if res.Entry.Count != 2 || !slices.Equal(res.Lost, []string{"codex"}) || !slices.Equal(res.StillHave, []string{"claude"}) {
		t.Fatalf("result %+v", res)
	}
	if exists(h.path(".agents/skills/foo")) || exists(h.path(".codex/skills/foo")) || !exists(h.path(".claude/skills/foo")) {
		t.Fatal("Codex still has a copy, or Claude lost its own")
	}
	alone := must(RemoveFrom(r, memberID(t, r, h.path(".agents/skills/only-shared")), []string{"codex"}))
	if alone.Entry.Label != "Removed skill only-shared from Codex" || exists(h.path(".agents/skills/only-shared")) {
		t.Fatalf("result %+v", alone)
	}
	must(Undo(r, alone.Entry.ID))
	must(Undo(r, res.Entry.ID))
	wantSameTree(t, before, tree(t, h.root))
	// The rest of ~/.agents is not managed: an entry pointing there is refused.
	guard := newContainment(r)
	if !guard.managedPath(h.path(".agents/skills/foo")) || guard.managedPath(h.path(".agents/other/foo")) || guard.managedPath(h.path(".agents/skills")) {
		t.Fatal("containment of ~/.agents/skills is wrong")
	}
}

// A Codex link to Claude's file: turning Codex off takes only the link; turning Claude off alone would leave Codex
// with a dangling link, so it is refused naming both readers; both together take the link and the file.
func TestRemoveFromSharedFileNeedsEveryReader(t *testing.T) {
	h := newHome(t)
	h.write(".claude/skills/foo/SKILL.md", skillMd("foo", "the one file"))
	h.symlink(h.path(".claude/skills/foo"), ".codex/skills/foo")
	r := h.roots()
	before := tree(t, h.root)
	claudeID := memberID(t, r, h.path(".claude/skills/foo"))

	_, err := RemoveFrom(r, claudeID, []string{"claude"})
	if msg := wantErr(t, err, coreerr.StatusConflict); msg != "foo is one file that Claude Code and Codex read, so it can only be removed from all of them at once. Nothing was changed." {
		t.Fatal(msg)
	}
	wantSameTree(t, before, tree(t, h.root))

	link := must(RemoveFrom(r, claudeID, []string{"codex"}))
	if link.Entry.Count != 1 || exists(h.path(".codex/skills/foo")) || !exists(h.path(".claude/skills/foo/SKILL.md")) {
		t.Fatalf("result %+v", link)
	}
	must(Undo(r, link.Entry.ID))

	both := must(RemoveFrom(r, claudeID, []string{"claude", "codex"}))
	if both.Entry.Count != 2 || exists(h.path(".codex/skills/foo")) || exists(h.path(".claude/skills/foo")) {
		t.Fatalf("result %+v", both)
	}
	must(Undo(r, both.Entry.ID))
	wantSameTree(t, before, tree(t, h.root))
}

// ~/.codex/skills is a link to ~/.claude/skills: one folder on disk, read by both. Copying into it names the other
// reader; removing needs both CLIs and moves the folder once.
func TestPerCLIOnALinkedFolder(t *testing.T) {
	h := newHome(t)
	h.write(".claude/skills/foo/SKILL.md", skillMd("foo", "one folder"))
	h.symlink(h.path(".claude/skills"), ".codex/skills")
	h.write(".agents/skills/bar/SKILL.md", skillMd("bar", "shared only"))
	r := h.roots()
	before := tree(t, h.root)

	_, err := RemoveFrom(r, memberID(t, r, h.path(".claude/skills/foo")), []string{"claude"})
	wantErr(t, err, coreerr.StatusConflict)
	both := must(RemoveFrom(r, memberID(t, r, h.path(".claude/skills/foo")), []string{"codex", "claude"}))
	if both.Entry.Count != 1 || exists(h.path(".claude/skills/foo")) {
		t.Fatalf("result %+v", both)
	}
	must(Undo(r, both.Entry.ID))
	wantSameTree(t, before, tree(t, h.root))

	copied := must(CopyTo(r, memberID(t, r, h.path(".agents/skills/bar")), []string{"claude"}))
	if !slices.Equal(copied.AlsoReaders, []string{"codex"}) || h.read(".claude/skills/bar/SKILL.md") != skillMd("bar", "shared only") {
		t.Fatalf("result %+v", copied)
	}
}

// A failed step puts back what the call already removed, and writes no entry.
func TestRemoveFromRollsBackAFailedMove(t *testing.T) {
	h, r := twoCLIHome(t)
	before := tree(t, h.root)
	old := renameFile
	calls := 0
	renameFile = func(from, to string) error {
		calls++
		if calls == 2 {
			return &os.LinkError{Op: "rename", Old: from, New: to, Err: fs.ErrPermission}
		}
		return old(from, to)
	}
	defer func() { renameFile = old }()
	_, err := RemoveFrom(r, memberID(t, r, h.path(".claude/skills/foo")), []string{"claude", "codex"})
	if err == nil {
		t.Fatal("the failed move was not reported")
	}
	renameFile = old
	wantSameTree(t, before, tree(t, h.root))
	if len(historyOf(t, r)) != 0 {
		t.Fatal("a failed call wrote a journal entry")
	}
}

func TestMemberBase(t *testing.T) {
	h := newHome(t)
	h.write(".claude/skills/a/SKILL.md", "x")
	h.write(".agents/skills/b/SKILL.md", "x")
	h.write("elsewhere/c/SKILL.md", "x")
	h.symlink(h.path("elsewhere"), ".claude/skills/middle")
	r := h.roots()
	tx := &Tx{r: r}
	for _, c := range []struct {
		cli  usage.CLI
		path string
		ok   bool
	}{
		{inventory.Claude, h.path(".claude/skills/a"), true},
		{inventory.Codex, h.path(".agents/skills/b"), true},
		{inventory.Claude, h.path(".agents/skills/b"), false},
		{inventory.Claude, h.path("elsewhere/c"), false},
		{inventory.Claude, h.path(".claude/skills/middle/c"), false},
		{inventory.Claude, h.path(".claude/skills/../../elsewhere/c"), false},
	} {
		err := tx.memberBase(inventory.Item{CLI: c.cli, Kind: inventory.KindSkill, Path: c.path})
		if (err == nil) != c.ok {
			t.Errorf("%s %s: %v", c.cli, c.path, err)
		}
	}
}

// v5 paths and ~/.agents/skills (RB-E2 findings): the v5 shell never sees a shared id (F1 is a 404 now); a v5 copy into
// Codex is refused when Codex already reads the skill from the shared folder (F3); removing Codex's own copy says Codex
// still reads the shared one (F4).
func TestV5PathsAndTheSharedFolder(t *testing.T) {
	h, r := twoCLIHome(t)
	h.write(".claude/skills/both/SKILL.md", skillMd("both", "claude copy"))
	h.write(".agents/skills/both/SKILL.md", skillMd("both", "shared copy"))
	h.write(".agents/skills/foo/SKILL.md", skillMd("foo", "shared copy"))

	_, err := RemoveItem(r, memberID(t, r, h.path(".agents/skills/foo")))
	wantErr(t, err, coreerr.StatusNotFound)

	var claudeBoth string
	for _, item := range inventory.Read(r).Items {
		if item.Path == h.path(".claude/skills/both") {
			claudeBoth = item.ID
		}
	}
	_, err = CopyToOther(r, claudeBoth)
	if msg := wantErr(t, err, coreerr.StatusConflict); msg != "Codex already reads a skill named both from ~/.agents/skills, so nothing was copied." {
		t.Fatal(msg)
	}
	if exists(h.path(".codex/skills/both")) {
		t.Fatal("the refused copy wrote")
	}

	var codexFoo string
	for _, item := range inventory.Read(r).Items {
		if item.Path == h.path(".codex/skills/foo") {
			codexFoo = item.ID
		}
	}
	entry := must(RemoveItem(r, codexFoo))
	if entry.Label != "Removed skill foo from Codex; Codex still reads it from ~/.agents/skills" || !exists(h.path(".agents/skills/foo")) {
		t.Fatalf("label %q", entry.Label)
	}
}

// A link under another name reaches the same file from another row (its SKILL.md has no name, so each copy is named
// after its folder): removing the file still needs that reader, so nothing is left dangling.
func TestRemoveFromSeesALinkInAnotherRow(t *testing.T) {
	h := newHome(t)
	h.write(".claude/skills/foo/SKILL.md", "---\ndescription: no name\n---\n")
	h.symlink(h.path(".claude/skills/foo"), ".codex/skills/bar")
	r := h.roots()
	_, err := RemoveFrom(r, memberID(t, r, h.path(".claude/skills/foo")), []string{"claude"})
	if msg := wantErr(t, err, coreerr.StatusConflict); !strings.Contains(msg, "Claude Code and Codex") {
		t.Fatal(msg)
	}
	_, err = RemoveMany(r, []string{memberID(t, r, h.path(".claude/skills/foo"))})
	wantErr(t, err, coreerr.StatusConflict)
	if !exists(h.path(".claude/skills/foo/SKILL.md")) {
		t.Fatal("the file went")
	}
}
