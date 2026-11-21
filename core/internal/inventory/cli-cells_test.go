package inventory

import (
	"encoding/json"
	"flag"
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"spacevibe.dev/core/internal/cliregistry"
	"spacevibe.dev/core/internal/goldentest"
	"spacevibe.dev/core/internal/usage"
)

// updateCLICells rewrites golden/cli-cells.json, a new golden of the redesign build (RB-E1). The frozen
// goldens are never written by a test; after a rewrite its line in SHA256SUMS must be updated in the same
// commit (SV5).
var updateCLICells = flag.Bool("update-cli-cells", false, "rewrite core/testdata/fixtures/golden/cli-cells.json")

func TestCLICellWireShapes(t *testing.T) {
	last := "2026-11-01"
	cases := []struct {
		cell CLICell
		want string
	}{
		{CLICell{State: CLICellCounted, Sessions: ptr(3), Days: []string{"2026-10-30", "2026-11-01"}, Last: &last},
			`{"state":"counted","sessions":3,"days":["2026-10-30","2026-11-01"],"last":"2026-11-01"}`},
		{CLICell{State: CLICellCounted, Sessions: ptr(0), Days: []string{}, Note: "Added in the last 24 hours"},
			`{"state":"counted","sessions":0,"days":[],"last":null,"note":"Added in the last 24 hours"}`},
		{CLICell{State: CLICellCounted, Runs: ptr(7), Errors: ptr(2), Last: &last},
			`{"state":"counted","runs":7,"errors":2,"last":"2026-11-01"}`},
		{CLICell{State: CLICellUnmeasurable, Reason: CodexHooksReason}, `{"state":"unmeasurable","reason":"Codex does not log hook runs"}`},
		{CLICell{State: CLICellScanning}, `{"state":"scanning"}`},
		{CLICell{State: CLICellMissing}, `{"state":"missing"}`},
		{CLICell{State: CLICellUnknown}, `{"state":"unknown"}`},
		{CLICell{State: CLICellNotSupported}, `{"state":"notSupported"}`},
	}
	for _, c := range cases {
		data, err := json.Marshal(c.cell)
		if err != nil {
			t.Fatal(err)
		}
		if string(data) != c.want {
			t.Errorf("marshal %+v = %s, want %s", c.cell, data, c.want)
		}
		var back CLICell
		if err := json.Unmarshal(data, &back); err != nil {
			t.Fatalf("unmarshal %s: %v", data, err)
		}
		again, _ := json.Marshal(back)
		if string(again) != c.want {
			t.Errorf("round trip of %s gave %s", c.want, again)
		}
	}
	for _, bad := range []string{`{"state":"pending","reason":"x"}`, `{"state":"counted"}`, `{"state":""}`} {
		var c CLICell
		if err := json.Unmarshal([]byte(bad), &c); err == nil {
			t.Errorf("%s decoded as %+v, want an error", bad, c)
		}
	}
	if _, err := json.Marshal(CLICell{State: "pending"}); err == nil {
		t.Error("a cell with an unknown state must not be written")
	}
}

// inventory.read and AttachUsage never carry cliCells: only loadout.rows does, so the frozen inventory golden and
// the v5 shell's inventory.read decode stay as they were (AR1).
func TestCLICellsOnlyOnLoadoutRows(t *testing.T) {
	h := rowsHome(t)
	r := h.roots()
	raw := Read(r)
	input := usage.Ready(scanOf(t, r))
	attached := AttachUsage(raw, &input, mustTime(t, "2026-12-01T00:00:00Z"))
	for _, it := range attached.Items {
		if it.CLICells != nil {
			t.Fatalf("AttachUsage set cliCells on %s", it.ID)
		}
	}
	data, _ := json.Marshal(raw)
	var tree struct {
		Items []map[string]any `json:"items"`
	}
	if err := json.Unmarshal(data, &tree); err != nil {
		t.Fatal(err)
	}
	for _, it := range tree.Items {
		if _, ok := it["cliCells"]; ok {
			t.Fatalf("inventory.read wrote cliCells: %v", it)
		}
	}
	rows := BuildLoadoutRows(raw, input, mustTime(t, "2026-12-01T00:00:00Z"))
	for _, it := range rows.Items {
		if len(it.CLICells) != len(cliregistry.All()) {
			t.Fatalf("%s cliCells = %v, want one per registry CLI", it.ID, it.CLICells)
		}
	}
}

// Over the fixture home, every cliCell says what the two-CLI cell of the same row says, in the terms of RD-R10
// and D63: counted stays counted with the same count; "added recently" pending is a counted zero with the note;
// "no logs scanned" pending is unmeasurable; unmeasurable and missing stay. All members of a key share cells.
func TestCLICellsAgreeWithCells(t *testing.T) {
	r, _ := fixtureRoots(t)
	raw := Read(r)
	input := usage.Ready(scanOf(t, r))
	rows := BuildLoadoutRows(raw, input, fixtureNow(t))
	check := func(id string, cells *Cells, cli map[string]CLICell) {
		t.Helper()
		for _, c := range usage.CLIs {
			old, got := cells.For(c), cli[string(c)]
			var ok bool
			switch old.State {
			case StateMissing:
				ok = got.State == CLICellMissing
			case StateUnmeasurable:
				ok = got.State == CLICellUnmeasurable && got.Reason == old.Reason
			case StatePending:
				if old.Reason == NoLogsScanned {
					ok = got.State == CLICellUnmeasurable && got.Reason == NoLogsScanned
				} else {
					ok = got.State == CLICellCounted && got.Note == old.Reason && derefInt(got.Sessions)+derefInt(got.Runs) == 0
				}
			case StateCounted:
				count := got.Sessions
				if old.Errors != nil {
					count = got.Runs
					ok = got.Errors != nil && *got.Errors == *old.Errors
				} else {
					ok = got.Runs == nil
				}
				ok = ok && got.State == CLICellCounted && count != nil && *count == old.Runs && got.Note == "" &&
					reflect.DeepEqual(got.Last, old.Last)
			}
			if !ok {
				t.Errorf("%s %s: cell %+v, cliCell %+v", id, c, old, got)
			}
		}
	}
	byKey := map[string]map[string]CLICell{}
	same := func(key, id string, cli map[string]CLICell) {
		t.Helper()
		if prev, seen := byKey[key]; seen && !reflect.DeepEqual(prev, cli) {
			t.Errorf("%s: cliCells differ from another member of %s", id, key)
		}
		byKey[key] = cli
	}
	for _, it := range rows.Items {
		check(it.ID, it.Cells, it.CLICells)
		same(it.Key(), it.ID, it.CLICells)
	}
	for _, hk := range rows.Hooks {
		check(hk.ID, hk.Cells, hk.CLICells)
		same(hk.Key(), hk.ID, hk.CLICells)
	}
	goldentest.AssertCaseCount(t, "fixture rows checked", len(rows.Items)+len(rows.Hooks), 29)
}

// While no scan has finished, an installed cell is scanning (a Codex hook stays unmeasurable: Codex never logs it).
func TestCLICellsWhileScanning(t *testing.T) {
	h := rowsHome(t)
	h.write(".codex/hooks.json", hookConfig("Stop", "echo codex"))
	rows := BuildLoadoutRows(Read(h.roots()), usage.Scanning, mustTime(t, "2026-11-02T00:00:00Z"))
	for _, it := range rows.Items {
		for _, c := range usage.CLIs {
			want := CLICellScanning
			if it.Cells.For(c).IsMissing() {
				want = CLICellMissing
			}
			if got := it.CLICells[string(c)].State; got != want {
				t.Errorf("%s %s = %s, want %s", it.ID, c, got, want)
			}
		}
	}
	var codexHook bool
	for _, hk := range rows.Hooks {
		if hk.CLI == Codex {
			codexHook = true
			if got := hk.CLICells["codex"]; got.State != CLICellUnmeasurable || got.Reason != CodexHooksReason {
				t.Errorf("codex hook while scanning = %+v", got)
			}
		}
	}
	if !codexHook {
		t.Fatal("the test home has no Codex hook")
	}
}

// A hook file or plugin list that cannot be used makes an absent member of that CLI unknown, never missing, for
// that kind only; the two-CLI cells stay missing (AR1).
func TestCLICellsUnknownWhenAFileCannotBeUsed(t *testing.T) {
	h := newTempHome(t)
	h.write(".claude/settings.json", hookConfig("Stop", "echo claude"))
	h.write(".claude/agents/reviewer.md", "---\nname: reviewer\n---\n")
	h.write(".codex/skills/codex-only/SKILL.md", skillFile("codex-only"))
	h.write(".codex/hooks.json", "{ not json")
	h.write(".claude/plugins/installed_plugins.json", "[")
	rows := BuildLoadoutRows(Read(h.roots()), usage.Scanning, mustTime(t, "2026-11-02T00:00:00Z"))

	hook := hookByCommand(Snapshot{Hooks: rows.Hooks}, "echo claude")
	if hook == nil {
		t.Fatal("the Claude hook is not listed")
	}
	if got := hook.CLICells["codex"].State; got != CLICellUnknown {
		t.Errorf("Claude hook, Codex cell = %s, want unknown: Codex hooks.json is not valid JSON", got)
	}
	if !hook.Cells.Codex.IsMissing() {
		t.Errorf("the v5 cell changed: %+v", hook.Cells.Codex)
	}
	// The plugin list is unusable, so a plugin could hold a skill of that name: unknown for Claude too.
	skill := item(Snapshot{Items: rows.Items}, "codex-only", Codex)
	if skill == nil {
		t.Fatal("the Codex skill is not listed")
	}
	if got := skill.CLICells["claude"].State; got != CLICellUnknown {
		t.Errorf("Codex-only skill, Claude cell = %s, want unknown: installed_plugins.json is not usable", got)
	}
	// The Codex agents folder is fine (absent), so the agent is simply missing there.
	agent := item(Snapshot{Items: rows.Items}, "reviewer", Claude)
	if agent == nil {
		t.Fatal("the Claude agent is not listed")
	}
	if got := agent.CLICells["codex"].State; got != CLICellMissing {
		t.Errorf("Claude agent, Codex cell = %s, want missing", got)
	}
}

// Plugins listed while the settings that enable them cannot be used: the Claude plugin set is not known. With no
// settings file at all, nothing is enabled and absent reads missing.
func TestCLICellsPluginSetDependsOnSettings(t *testing.T) {
	for _, tc := range []struct {
		name     string
		settings string
		want     string
	}{
		{"settings not valid JSON", "{", CLICellUnknown},
		{"no settings file", "", CLICellMissing},
	} {
		t.Run(tc.name, func(t *testing.T) {
			h := newTempHome(t)
			h.write(".claude/plugins/installed_plugins.json", `{"plugins": {"acme@market": [{"installPath": "`+h.path("cache/acme")+`"}]}}`)
			h.write("cache/acme/skills/x/SKILL.md", skillFile("x"))
			if tc.settings != "" {
				h.write(".claude/settings.json", tc.settings)
			}
			h.write(".codex/skills/codex-only/SKILL.md", skillFile("codex-only"))
			rows := BuildLoadoutRows(Read(h.roots()), usage.Scanning, mustTime(t, "2026-11-02T00:00:00Z"))
			skill := item(Snapshot{Items: rows.Items}, "codex-only", Codex)
			if skill == nil {
				t.Fatal("the Codex skill is not listed")
			}
			if got := skill.CLICells["claude"].State; got != tc.want {
				t.Errorf("Claude cell = %s, want %s", got, tc.want)
			}
		})
	}
}

// The registry decides Not supported and the no-log case; a registry CLI the engine has no reader for is unknown.
func TestCLICellsFollowTheRegistry(t *testing.T) {
	h := rowsHome(t)
	h.write(".codex/agents/helper.toml", "name = \"helper\"\n")
	r := h.roots()
	raw := Read(r)
	input := usage.Ready(scanOf(t, r))
	registry := []cliregistry.CLI{
		{ID: cliregistry.Claude, Name: "Claude Code", Supports: cliregistry.Supports{Skill: true, Agent: false, Hook: false, Logs: true}},
		{ID: cliregistry.Codex, Name: "Codex", Supports: cliregistry.Supports{Skill: true, Agent: true, Hook: true, Logs: false}},
		{ID: "elsewhere", Name: "Elsewhere", Supports: cliregistry.Supports{Skill: true, Agent: true, Hook: true, Logs: true}},
	}
	rows := buildLoadoutRows(raw, input, mustTime(t, "2026-12-01T00:00:00Z"), nil, registry)
	both := item(Snapshot{Items: rows.Items}, "both", Claude)
	if both == nil {
		t.Fatal("no skill both")
	}
	if got := both.CLICells["codex"]; got.State != CLICellUnmeasurable || got.Reason != NoCountableLog {
		t.Errorf("a CLI with no countable log: %+v, want unmeasurable, never 0", got)
	}
	if got := both.CLICells["claude"].State; got != CLICellCounted {
		t.Errorf("claude cell of both = %s", got)
	}
	if got := both.CLICells["elsewhere"].State; got != CLICellUnknown {
		t.Errorf("a CLI without a reader = %s, want unknown", got)
	}
	helper := item(Snapshot{Items: rows.Items}, "helper", Codex)
	if helper == nil {
		t.Fatal("no agent helper")
	}
	if got := helper.CLICells["claude"].State; got != CLICellNotSupported {
		t.Errorf("an agent in a CLI without subagents = %s, want notSupported", got)
	}
	for _, hk := range rows.Hooks {
		if got := hk.CLICells["claude"].State; got != CLICellNotSupported {
			t.Errorf("hook %s claude = %s, want notSupported (it beats a present member)", hk.ID, got)
		}
	}
	if len(rows.Hooks) == 0 {
		t.Fatal("the test home has no hook")
	}
}

// Swift has no counterpart: loadout.rows' cliCells are new in RB-E1. The golden is the projection
// {now, registry, ready, scanning}: the cliCells of every row key, after a full scan and before one.
func TestGoldenCLICells(t *testing.T) {
	r, root := fixtureRoots(t)
	manifest, err := goldentest.LoadManifest()
	if err != nil {
		t.Fatal(err)
	}
	raw := Read(r)
	byKey := func(rows LoadoutRows) map[string]any {
		out := map[string]any{}
		for _, it := range rows.Items {
			out[it.Key()] = jsonTree(t, it.CLICells)
		}
		for _, hk := range rows.Hooks {
			out[hk.Key()] = jsonTree(t, hk.CLICells)
		}
		return out
	}
	got := tokenHome(map[string]any{
		"now":      json.Number(jsonNumber(manifest.Now)),
		"registry": jsonTree(t, cliregistry.Read()),
		"ready":    byKey(BuildLoadoutRows(raw, usage.Ready(scanOf(t, r)), fixtureNow(t))),
		"scanning": byKey(BuildLoadoutRows(raw, usage.Scanning, fixtureNow(t))),
	}, root)
	if *updateCLICells {
		text, err := goldentest.Canonical(got)
		if err != nil {
			t.Fatal(err)
		}
		dir, err := goldentest.FixturesDir()
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, "golden", "cli-cells.json"), text, 0o644); err != nil {
			t.Fatal(err)
		}
		t.Log("wrote golden/cli-cells.json: update its line in SHA256SUMS")
	}
	want, err := goldentest.LoadGolden("cli-cells")
	if err != nil {
		t.Fatal(err)
	}
	goldentest.AssertCanonicalEqual(t, "cli-cells", want, got)
	goldentest.AssertCaseCount(t, "cli-cells golden row keys", len(got.(map[string]any)["ready"].(map[string]any)), 20)
}
