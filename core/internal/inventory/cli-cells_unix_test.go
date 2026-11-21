//go:build unix

package inventory

import (
	"os"
	"slices"
	"testing"

	"spacevibe.dev/core/internal/config"
	"spacevibe.dev/core/internal/roots"
	"spacevibe.dev/core/internal/usage"
)

// denyFolder makes a folder unlistable and unsearchable for the test, and gives it back its mode so the temp
// folder can be removed.
func denyFolder(t *testing.T, path string) {
	t.Helper()
	if err := os.Chmod(path, 0); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(path, 0o755) })
}

// RD-R10: an unreadable CLI folder makes every cell of that CLI unknown, Missing included. Here the Codex root
// sits under a folder that denies the lookup, so the core cannot even tell whether ~/.codex exists.
func TestCLICellsUnknownWhenTheCLIRootCannotBeRead(t *testing.T) {
	requireNotRoot(t)
	h := newTempHome(t)
	h.write(".claude/skills/solo/SKILL.md", skillFile("solo"))
	h.write(".claude/agents/reviewer.md", "---\nname: reviewer\n---\n")
	h.write(".claude/settings.json", hookConfig("Stop", "echo claude"))
	h.write("locked/codex/skills/hidden/SKILL.md", skillFile("hidden"))
	denyFolder(t, h.path("locked"))
	cfg := config.Config{Test: true, UserHome: h.root, ClaudeConfigDir: h.path(".claude"), CodexHome: h.path("locked/codex"), Home: h.data()}
	r, err := roots.Resolve(cfg, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	rows := BuildLoadoutRows(Read(r), usage.Scanning, mustTime(t, "2026-11-02T00:00:00Z"))
	if len(rows.Items) != 2 || len(rows.Hooks) != 1 {
		t.Fatalf("rows: %d items, %d hooks", len(rows.Items), len(rows.Hooks))
	}
	for _, it := range rows.Items {
		if got := it.CLICells["codex"].State; got != CLICellUnknown {
			t.Errorf("%s codex = %s, want unknown", it.ID, got)
		}
		if !it.Cells.Codex.IsMissing() {
			t.Errorf("%s: the v5 cell changed to %+v", it.ID, it.Cells.Codex)
		}
	}
	if got := rows.Hooks[0].CLICells["codex"].State; got != CLICellUnknown {
		t.Errorf("hook codex = %s, want unknown", got)
	}
}

// Only the kind whose folder cannot be listed turns unknown: a denied skills folder leaves agents measured as
// missing.
func TestCLICellsUnknownOnlyForTheUnreadableKind(t *testing.T) {
	requireNotRoot(t)
	h := newTempHome(t)
	h.write(".claude/skills/locked/SKILL.md", skillFile("locked"))
	h.write(".codex/skills/codex-only/SKILL.md", skillFile("codex-only"))
	h.write(".codex/agents/helper.toml", "name = \"helper\"\n")
	h.write(".claude/agents/.keep", "")
	denyFolder(t, h.path(".claude/skills"))
	rows := BuildLoadoutRows(Read(h.roots()), usage.Scanning, mustTime(t, "2026-11-02T00:00:00Z"))
	skill := item(Snapshot{Items: rows.Items}, "codex-only", Codex)
	agent := item(Snapshot{Items: rows.Items}, "helper", Codex)
	if skill == nil || agent == nil {
		t.Fatalf("items: %+v", rows.Items)
	}
	if got := skill.CLICells["claude"].State; got != CLICellUnknown {
		t.Errorf("skill claude = %s, want unknown: ~/.claude/skills cannot be listed", got)
	}
	if got := agent.CLICells["claude"].State; got != CLICellMissing {
		t.Errorf("agent claude = %s, want missing: ~/.claude/agents was read", got)
	}
}

// Codex reads skills from ~/.agents/skills too (RB-T0a), so a denied ~/.agents/skills makes an absent Codex skill
// unknown in cliCells, says so in extraProblems, and leaves Codex agents missing. The v5 problems and cells do not
// change (AR1).
func TestCLICellsUnknownWhenAgentsSkillsCannotBeRead(t *testing.T) {
	requireNotRoot(t)
	h := newTempHome(t)
	h.write(".claude/skills/solo/SKILL.md", skillFile("solo"))
	h.write(".claude/agents/reviewer.md", "---\nname: reviewer\n---\n")
	h.write(".codex/config.toml", "")
	h.write(".agents/skills/hidden/SKILL.md", skillFile("hidden"))
	denyFolder(t, h.path(".agents/skills"))
	rows := BuildLoadoutRows(Read(h.roots()), usage.Scanning, mustTime(t, "2026-11-02T00:00:00Z"))
	skill := item(Snapshot{Items: rows.Items}, "solo")
	agent := item(Snapshot{Items: rows.Items}, "reviewer")
	if skill == nil || agent == nil || len(rows.Items) != 2 {
		t.Fatalf("items: %+v", rows.Items)
	}
	if got := skill.CLICells["codex"].State; got != CLICellUnknown {
		t.Errorf("skill codex = %s, want unknown: ~/.agents/skills cannot be listed", got)
	}
	if !skill.Cells.Codex.IsMissing() {
		t.Errorf("the v5 cell changed to %+v", skill.Cells.Codex)
	}
	if got := agent.CLICells["codex"].State; got != CLICellMissing {
		t.Errorf("agent codex = %s, want missing", got)
	}
	want := h.path(".agents/skills") + " cannot be read, so its skills cannot be shown."
	if !slices.Equal(rows.ExtraProblems, []string{want}) {
		t.Errorf("extraProblems = %v, want %q", rows.ExtraProblems, want)
	}
	if len(rows.Problems) != 0 {
		t.Errorf("the v5 problems changed: %v", rows.Problems)
	}
}
