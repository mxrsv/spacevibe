package main

import (
	"bytes"
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

// perCLIWriteCases are the contract cases of the per-CLI and batch writes (RB-E3, RB-E4): loadout.copyTo,
// loadout.removeFrom, loadout.removeMany and rules.removeMany, each refused first, then written and undone byte for byte.
func perCLIWriteCases(t *testing.T) {
	type entryResult struct {
		Entry struct {
			ID, Label string
			Count     int
		}
		AlsoReaders, Lost, StillHave []string
	}
	// ids reads inventory.read once: project and hook ids are hashes of absolute paths, so they differ per copied home.
	type invHook struct {
		ID, CLI, Command, Scope string
	}
	ids := func(c *core, callID string) (project string, hooks []invHook) {
		var snap struct {
			Items []invItem
			Hooks []invHook
		}
		decodeInto(t, c.ok(c.call(callID, "inventory.read", `{}`)), &snap)
		for _, it := range snap.Items {
			if project == "" && it.Scope == "project" && it.Kind == "skill" {
				project = it.ID
			}
		}
		if project == "" {
			t.Fatal("the fixture lacks a project skill")
		}
		// The hashes follow the copied home's path, so the transcript names them by role.
		c.norm.mask(project, "$PROJECT_SKILL_ID")
		for i, h := range snap.Hooks {
			c.norm.mask(h.ID, "$HOOK_ID_"+itoaID(i))
		}
		return project, snap.Hooks
	}
	hookWith := func(hooks []invHook, cli, suffix, scope string) string {
		for _, h := range hooks {
			if h.CLI == cli && h.Scope == scope && strings.HasSuffix(strings.TrimSuffix(h.Command, "'"), suffix) {
				return h.ID
			}
		}
		t.Fatalf("no %s %s hook ending %s", scope, cli, suffix)
		return ""
	}

	t.Run("loadout_copyTo_removeFrom_then_undo", func(t *testing.T) {
		home := copiedHome(t)
		// A synthetic skill in the shared folder Codex reads (RB-E2); the fixture itself has none.
		writeFile(t, filepath.Join(home, ".agents/skills/sv-shared/SKILL.md"), "---\nname: sv-shared\ndescription: Synthetic shared skill\n---\n")
		before := homeTree(t, home)
		c := startOn(t, shippedBin, home)
		c.initialize()
		project, hooks := ids(c, "100")
		stopHook := hookWith(hooks, "claude", "old-dotfiles/notify.sh", "global")

		for _, refusal := range []struct {
			id, method, params string
			status             int
		}{
			{"1", "loadout.copyTo", `{"id":"claude:skill:neon:neon-postgres","targets":["codex"]}`, 403},
			{"2", "loadout.copyTo", `{"id":"claude:skill:local:explain","targets":["codex"]}`, 409},
			{"3", "loadout.copyTo", `{"id":"claude:skill:local:tdd","targets":["gemini"]}`, 400},
			{"4", "loadout.removeFrom", `{"id":"claude:skill:local:explain","clis":[]}`, 400},
			{"5", "loadout.removeFrom", `{"id":"` + project + `","clis":["claude"]}`, 403},
			{"6", "loadout.removeFrom", `{"id":"claude:skill:local:tdd","clis":["codex"]}`, 409},
			{"7", "loadout.removeFrom", `{"id":"` + stopHook + `","clis":["claude"]}`, 400},
			{"8", "loadout.copyTo", `{"id":"codex:skill:agents:no-such","targets":["claude"]}`, 404},
		} {
			if got := c.status(c.call(refusal.id, refusal.method, refusal.params)); got != refusal.status {
				t.Errorf("call %s: status %d, want %d", refusal.id, got, refusal.status)
			}
		}
		c.wantError(c.call("9", "loadout.copyTo", `{"id":"claude:skill:local:tdd","targets":["codex"],"path":"/etc"}`), -32602)
		var hist struct{ Entries []json.RawMessage }
		decodeInto(t, c.ok(c.call("10", "journal.history", `{}`)), &hist)
		if len(hist.Entries) != 0 {
			t.Fatalf("a refused write left %d journal entries", len(hist.Entries))
		}

		var copied, shared, both entryResult
		decodeInto(t, c.ok(c.call("11", "loadout.copyTo", `{"id":"codex:skill:agents:sv-shared","targets":["claude"]}`)), &copied)
		c.norm.mask(copied.Entry.ID, "$COPY_ID")
		if copied.Entry.Label != "Copied skill sv-shared to Claude Code" || copied.AlsoReaders == nil || len(copied.AlsoReaders) != 0 {
			t.Fatalf("copy %+v", copied)
		}
		decodeInto(t, c.ok(c.call("12", "loadout.removeFrom", `{"id":"codex:skill:agents:sv-shared","clis":["codex"]}`)), &shared)
		c.norm.mask(shared.Entry.ID, "$SHARED_ID")
		if !slices.Equal(shared.Lost, []string{"codex"}) || !slices.Equal(shared.StillHave, []string{"claude"}) {
			t.Fatalf("shared removal %+v", shared)
		}
		if _, err := os.Lstat(filepath.Join(home, ".agents/skills/sv-shared")); err == nil {
			t.Fatal("the shared skill is still there")
		}
		decodeInto(t, c.ok(c.call("13", "loadout.removeFrom", `{"id":"claude:skill:local:explain","clis":["claude","codex"]}`)), &both)
		c.norm.mask(both.Entry.ID, "$BOTH_ID")
		if both.Entry.Count != 2 || both.Entry.Label != "Removed skill explain from Claude Code and Codex" {
			t.Fatalf("removal %+v", both)
		}
		for i, id := range []string{both.Entry.ID, shared.Entry.ID, copied.Entry.ID} {
			decodeInto(t, c.ok(c.call(itoaID(14+i), "journal.undo", `{"id":"`+id+`"}`)), &struct{ Label string }{})
		}
		c.finish("loadout_copyTo_removeFrom_then_undo")
		wantHomeTree(t, before, homeTree(t, home))
	})

	t.Run("loadout_removeMany_then_undo", func(t *testing.T) {
		home := copiedHome(t)
		before := homeTree(t, home)
		c := startOn(t, shippedBin, home)
		c.initialize()
		_, hooks := ids(c, "100")
		oldStop := hookWith(hooks, "claude", "old-dotfiles/notify.sh", "global")
		claudeDone := hookWith(hooks, "claude", "notify-done.sh", "global")
		codexDone := hookWith(hooks, "codex", "notify-done.sh", "global")
		projectHook := ""
		for _, h := range hooks {
			if h.Scope == "project" {
				projectHook = h.ID
			}
		}
		for _, refusal := range []struct {
			id, params string
			status     int
		}{
			{"1", `{"ids":[]}`, 400},
			{"2", `{"ids":["claude:skill:local:tdd","claude:skill:neon:neon-postgres"]}`, 403},
			{"3", `{"ids":["claude:skill:local:tdd","` + projectHook + `"]}`, 403},
			{"4", `{"ids":["claude:skill:local:tdd","claude:agent:local:no-such.md"]}`, 404},
		} {
			if got := c.status(c.call(refusal.id, "loadout.removeMany", refusal.params)); got != refusal.status {
				t.Errorf("call %s: status %d, want %d", refusal.id, got, refusal.status)
			}
		}
		c.wantError(c.call("5", "loadout.removeMany", `{"ids":"claude:skill:local:tdd"}`), -32602)
		wantHomeTree(t, before, homeTree(t, home))

		var removed entryResult
		decodeInto(t, c.ok(c.call("6", "loadout.removeMany", `{"ids":["claude:skill:local:tdd","codex:agent:local:security-reviewer.toml","`+oldStop+`","`+claudeDone+`","`+codexDone+`"]}`)), &removed)
		c.norm.mask(removed.Entry.ID, "$ENTRY_ID")
		if removed.Entry.Count != 5 || removed.Entry.Label != "Removed 1 skill, 1 agent and 2 hooks from Claude Code and Codex" || !slices.Equal(removed.Lost, []string{"claude", "codex"}) {
			t.Fatalf("removal %+v", removed)
		}
		if _, err := os.Lstat(filepath.Join(home, ".claude/skills/tdd")); err == nil {
			t.Fatal("the skill is still there")
		}
		var hist struct{ Entries []json.RawMessage }
		decodeInto(t, c.ok(c.call("7", "journal.history", `{}`)), &hist)
		if len(hist.Entries) != 1 {
			t.Fatalf("history has %d entries, want 1", len(hist.Entries))
		}
		decodeInto(t, c.ok(c.call("8", "journal.undo", `{"id":"`+removed.Entry.ID+`"}`)), &struct{ Label string }{})
		c.finish("loadout_removeMany_then_undo")
		wantHomeTree(t, before, homeTree(t, home))
	})

	t.Run("rules_removeMany_then_undo", func(t *testing.T) {
		home := copiedHome(t)
		c := startOn(t, shippedBin, home)
		c.initialize()
		file := filepath.Join(home, ".claude", "settings.json")
		global := `"scope":"global","dir":null`
		for i, rule := range []string{"Bash(sv-one)", "Bash(sv-two:*)"} {
			var added struct{ Entry struct{ ID string } }
			decodeInto(t, c.ok(c.call(itoaID(1+i), "rules.add", `{`+global+`,"verdict":"allow","rule":"`+rule+`"}`)), &added)
			c.norm.mask(added.Entry.ID, "$SETUP_ID_"+itoaID(1+i))
		}
		afterSetup, err := os.ReadFile(file)
		if err != nil {
			t.Fatal(err)
		}
		for _, refusal := range []struct {
			id, params string
			status     int
		}{
			{"3", `{` + global + `,"ids":[]}`, 400},
			{"4", `{` + global + `,"ids":["project:allow:Bash(sv-one)"]}`, 400},
			{"5", `{` + global + `,"ids":["global:allow:Bash(sv-one)","global:deny:Bash(sv-two:*)"]}`, 409},
		} {
			if got := c.status(c.call(refusal.id, "rules.removeMany", refusal.params)); got != refusal.status {
				t.Errorf("call %s: status %d, want %d", refusal.id, got, refusal.status)
			}
		}
		if now, _ := os.ReadFile(file); !bytes.Equal(now, afterSetup) {
			t.Fatal("a refused call changed the settings file")
		}
		var removed struct {
			Entry struct {
				ID, Label string
				Count     int
			}
		}
		decodeInto(t, c.ok(c.call("6", "rules.removeMany", `{`+global+`,"ids":["global:allow:Bash(sv-one)","global:allow:Bash(sv-two:*)"]}`)), &removed)
		c.norm.mask(removed.Entry.ID, "$ENTRY_ID")
		if removed.Entry.Label != "Removed 2 rules (global)" || removed.Entry.Count != 1 {
			t.Fatalf("entry %+v", removed.Entry)
		}
		decodeInto(t, c.ok(c.call("7", "journal.undo", `{"id":"`+removed.Entry.ID+`"}`)), &struct{ Label string }{})
		if now, _ := os.ReadFile(file); !bytes.Equal(now, afterSetup) {
			t.Fatal("Undo did not put the settings file back byte for byte")
		}
		c.finish("rules_removeMany_then_undo")
	})
}

func itoaID(n int) string { b, _ := json.Marshal(n); return string(b) }

// homeTree is every path under the home outside the data folder, with its bytes or link text and its mode.
func homeTree(t *testing.T, home string) map[string]string {
	t.Helper()
	out := map[string]string{}
	err := filepath.WalkDir(home, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(home, path)
		if d.IsDir() && (rel == ".spacevibe" || rel == ".reins") {
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

func wantHomeTree(t *testing.T, before, after map[string]string) {
	t.Helper()
	for k, v := range before {
		if after[k] != v {
			t.Errorf("%s changed", k)
		}
	}
	for k := range after {
		if _, ok := before[k]; !ok {
			t.Errorf("%s appeared", k)
		}
	}
}
