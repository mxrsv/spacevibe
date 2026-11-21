package inventory

import (
	"encoding/json"
	"flag"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"spacevibe.dev/core/internal/cliregistry"
	"spacevibe.dev/core/internal/goldentest"
	"spacevibe.dev/core/internal/usage"
)

// updateReadersMap rewrites golden/readers-map.json, a new golden of the redesign build (RB-E2). After a rewrite its
// line in SHA256SUMS must be updated in the same commit (SV5).
var updateReadersMap = flag.Bool("update-readers-map", false, "rewrite core/testdata/fixtures/golden/readers-map.json")

func rowsOf(t *testing.T, h tempHome) LoadoutRows {
	t.Helper()
	return BuildLoadoutRows(Read(h.roots()), usage.Scanning, mustTime(t, "2026-11-02T00:00:00Z"))
}

func folderOf(rows LoadoutRows, path string) *Folder {
	for i := range rows.Folders {
		if rows.Folders[i].Path == path {
			return &rows.Folders[i]
		}
	}
	return nil
}

// allItems is what the new frame reads: the v5 items and the extra items together.
func allItems(rows LoadoutRows) []Item {
	return append(slices.Clone(rows.Items), rows.ExtraItems...)
}

func membersOf(rows LoadoutRows, key string) []Item {
	var out []Item
	for _, it := range allItems(rows) {
		if it.Key() == key {
			out = append(out, it)
		}
	}
	return out
}

// readersOf is what the shell derives for one member: the readers of its folder and of every folder that is the
// same folder on disk (same realPath).
func readersOf(rows LoadoutRows, m Item) []string {
	own := folderOf(rows, m.Folder)
	var out []string
	for _, f := range rows.Folders {
		if f.Path == own.Path || f.RealPath == own.RealPath {
			for _, c := range f.ReadBy {
				if !slices.Contains(out, c) {
					out = append(out, c)
				}
			}
		}
	}
	return out
}

// losersOf is the shell's "who loses the item" (RD-R11) written as a pure function over the wire, to prove the data
// suffices: removing a member that is a link takes only that link; removing any other member takes its file, so every
// member with the same realPath goes. A CLI loses the item when it reads at least one member and all of them are gone.
func losersOf(rows LoadoutRows, key string, removed ...string) []string {
	members := membersOf(rows, key)
	gone := map[string]bool{}
	for _, m := range members {
		if !slices.Contains(removed, m.ID) {
			continue
		}
		if m.Owner == "link" {
			gone[m.ID] = true
			continue
		}
		for _, other := range members {
			if other.RealPath == m.RealPath {
				gone[other.ID] = true
			}
		}
	}
	var out []string
	for _, c := range cliregistry.All() {
		read, lost := 0, 0
		for _, m := range members {
			if slices.Contains(readersOf(rows, m), string(c.ID)) {
				read++
				if gone[m.ID] {
					lost++
				}
			}
		}
		if read > 0 && read == lost {
			out = append(out, string(c.ID))
		}
	}
	return out
}

// filesOf is D53's count: the distinct files of a row.
func filesOf(rows LoadoutRows, key string) int {
	var files []string
	for _, m := range membersOf(rows, key) {
		if !slices.Contains(files, m.RealPath) {
			files = append(files, m.RealPath)
		}
	}
	return len(files)
}

// viaOf is RD31 over the wire: the owners of the folders cli reads the row from, when none of them is its own.
func viaOf(folders []Folder, memberFolders []string, cli string) []string {
	var owners []string
	for _, path := range memberFolders {
		for _, f := range folders {
			if f.Path == path && slices.Contains(f.ReadBy, cli) {
				if f.OwnedBy == cli {
					return nil
				}
				if !slices.Contains(owners, f.OwnedBy) {
					owners = append(owners, f.OwnedBy)
				}
			}
		}
	}
	return owners
}

// RB-T0a: Codex lists a skill that is only in ~/.agents/skills, so for the new frame it is a Codex skill, not Missing
// for Codex: an extra item with its own id, not removable, counted in cliCells. The v5 fields do not see it (AR1).
func TestAgentsSkillsAreCodexSkills(t *testing.T) {
	h := newTempHome(t)
	h.write(".claude/skills/shared/SKILL.md", skillFile("shared"))
	h.write(".codex/config.toml", "")
	h.write(".agents/skills/shared/SKILL.md", skillFile("shared"))
	h.write(".agents/skills/agents-only/SKILL.md", skillFile("agents-only"))
	rows := rowsOf(t, h)
	inv := Snapshot{Items: allItems(rows)}

	only := item(inv, "agents-only", Codex)
	if only == nil {
		t.Fatal("a skill in ~/.agents/skills is not listed for Codex")
	}
	if only.ID != "codex:skill:agents:agents-only" || only.Removable || only.Owner != "user" || only.Scope != ScopeGlobal || only.Cells != nil {
		t.Errorf("agents-only = %+v", *only)
	}
	if only.Path != h.path(".agents/skills/agents-only") || only.Folder != h.path(".agents/skills") {
		t.Errorf("path %q, folder %q", only.Path, only.Folder)
	}
	if len(rows.Items) != 1 || len(rows.ExtraItems) != 2 {
		t.Fatalf("%d v5 items, %d extra items; want 1 and 2", len(rows.Items), len(rows.ExtraItems))
	}
	shared := item(inv, "shared", Claude)
	if shared == nil {
		t.Fatal("no Claude skill")
	}
	if shared.InOther || !shared.Cells.Codex.IsMissing() {
		t.Errorf("the v5 view of the Claude skill changed: inOther %v, Codex cell %+v", shared.InOther, shared.Cells.Codex)
	}
	if got := shared.CLICells["codex"].State; got != CLICellScanning {
		t.Errorf("Claude skill, Codex cliCell = %s, want scanning", got)
	}
	if got := only.CLICells["claude"].State; got != CLICellMissing {
		t.Errorf("agents-only, Claude cliCell = %s, want missing: Claude Code does not read ~/.agents/skills", got)
	}
	if extra := item(Snapshot{Items: rows.ExtraItems}, "shared", Codex); extra == nil || !extra.InOther {
		t.Errorf("the shared Codex copy: %+v", extra)
	}
}

// AR1 and FE-P9: everything the v5 shell decodes from loadout.rows (and inventory.read) for a home with
// ~/.agents/skills is byte for byte what it was without that folder, also when the folder holds a skill that is in
// ~/.codex/skills too (v5 would split that key into two rows) and when the folder cannot be read.
func TestV5FieldsIgnoreAgentsSkills(t *testing.T) {
	h := rowsHome(t)
	r := h.roots()
	scan := usage.Ready(scanOf(t, r))
	at := mustTime(t, "2026-12-01T00:00:00Z")
	// v5Fields is the loadout.rows answer as the v5 DTOs read it: the members CoreTypesLoadout.swift and
	// CoreTypesInventory.swift decode, with the new members (cliCells, folder, realPath) dropped.
	v5Fields := func() (string, string) {
		t.Helper()
		data, err := json.Marshal(BuildLoadoutRows(Read(r), scan, at))
		if err != nil {
			t.Fatal(err)
		}
		var top map[string]any
		if err := json.Unmarshal(data, &top); err != nil {
			t.Fatal(err)
		}
		for _, member := range []string{"folders", "extraItems", "extraProblems"} {
			delete(top, member)
		}
		for _, list := range []string{"items", "hooks"} {
			for _, row := range top[list].([]any) {
				for _, member := range []string{"cliCells", "folder", "realPath"} {
					delete(row.(map[string]any), member)
				}
			}
		}
		rowsText, err := json.Marshal(top)
		if err != nil {
			t.Fatal(err)
		}
		inventoryText, err := json.Marshal(Read(r))
		if err != nil {
			t.Fatal(err)
		}
		return string(rowsText), string(inventoryText)
	}
	wantRows, wantInventory := v5Fields()
	h.write(".agents/skills/both/SKILL.md", skillFile("both"))
	h.write(".agents/skills/solo/SKILL.md", skillFile("solo"))
	h.write(".agents/skills/agents-only/SKILL.md", skillFile("agents-only"))
	gotRows, gotInventory := v5Fields()
	if gotRows != wantRows {
		t.Errorf("loadout.rows' v5 fields changed with ~/.agents/skills:\nwant %s\n got %s", wantRows, gotRows)
	}
	if gotInventory != wantInventory {
		t.Errorf("inventory.read changed with ~/.agents/skills:\nwant %s\n got %s", wantInventory, gotInventory)
	}
	rows := BuildLoadoutRows(Read(r), scan, at)
	if len(rows.ExtraItems) != 3 {
		t.Fatalf("extra items = %d, want 3", len(rows.ExtraItems))
	}
	if got := item(Snapshot{Items: rows.Items}, "solo").CLICells["codex"].State; got != CLICellCounted {
		t.Errorf("solo, Codex cliCell = %s, want counted: Codex reads ~/.agents/skills/solo", got)
	}
}

// The shared folder is read only while Codex's own folder is there: without ~/.codex, nothing says Codex is installed.
func TestAgentsSkillsNeedTheCodexRoot(t *testing.T) {
	h := newTempHome(t)
	h.write(".claude/skills/solo/SKILL.md", skillFile("solo"))
	h.write(".agents/skills/x/SKILL.md", skillFile("x"))
	rows := rowsOf(t, h)
	if item(Snapshot{Items: allItems(rows)}, "x", Codex) != nil {
		t.Error("~/.agents/skills was read without a Codex folder")
	}
	if folderOf(rows, h.path(".agents/skills")) != nil || folderOf(rows, h.path(".codex/skills")) != nil {
		t.Errorf("folders list a CLI that is not there: %+v", rows.Folders)
	}
}

// Codex keeps its own bundled skills in $CODEX_HOME/skills/.system. They are not listed: Codex manages them, they are
// not the user's to remove or copy. A dot-named entry of ~/.agents/skills is skipped the same way.
func TestSystemSkillsAreNotListed(t *testing.T) {
	h := newTempHome(t)
	h.write(".codex/skills/.system/bundled/SKILL.md", skillFile("bundled"))
	h.write(".agents/skills/.system/other/SKILL.md", skillFile("other"))
	h.write(".codex/skills/mine/SKILL.md", skillFile("mine"))
	rows := rowsOf(t, h)
	if len(rows.Items) != 1 || rows.Items[0].Name != "mine" || len(rows.ExtraItems) != 0 {
		t.Fatalf("items = %+v", rows.Items)
	}
}

// The folder table: each installed CLI's own global folders (the copy targets), the shared ~/.agents/skills read by
// Codex alone, and every plugin and project folder a row lives in. Every item and hook names a folder of the table that
// its own CLI reads.
func TestReadersMapTable(t *testing.T) {
	h := rowsHome(t)
	h.write(".agents/skills/shared/SKILL.md", skillFile("shared"))
	h.write(".claude/plugins/installed_plugins.json", `{"plugins": {"acme@market": [{"installPath": "`+h.path("cache/acme")+`"}]}}`)
	h.write("cache/acme/skills/plug/SKILL.md", skillFile("plug"))
	settings := `{"enabledPlugins": {"acme@market": true}, "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "echo live"}]}]}}`
	h.write(".claude/settings.json", settings)
	rows := rowsOf(t, h)

	want := []Folder{
		{Path: h.path(".agents/skills"), Kind: KindSkill, ReadBy: []string{"codex"}, OwnedBy: "codex"},
		{Path: h.path(".claude/agents"), Kind: KindAgent, ReadBy: []string{"claude"}, OwnedBy: "claude", CopyTarget: true},
		{Path: h.path(".claude/settings.json"), Kind: KindHook, ReadBy: []string{"claude"}, OwnedBy: "claude", CopyTarget: true},
		{Path: h.path(".claude/skills"), Kind: KindSkill, ReadBy: []string{"claude"}, OwnedBy: "claude", CopyTarget: true},
		{Path: h.path(".codex/agents"), Kind: KindAgent, ReadBy: []string{"codex"}, OwnedBy: "codex", CopyTarget: true},
		{Path: h.path(".codex/hooks.json"), Kind: KindHook, ReadBy: []string{"codex"}, OwnedBy: "codex", CopyTarget: true},
		{Path: h.path(".codex/skills"), Kind: KindSkill, ReadBy: []string{"codex"}, OwnedBy: "codex", CopyTarget: true},
		{Path: h.path("cache/acme/skills"), Kind: KindSkill, ReadBy: []string{"claude"}, OwnedBy: "claude"},
		{Path: h.path("work/alpha/.claude/skills"), Kind: KindSkill, ReadBy: []string{"claude"}, OwnedBy: "claude"},
	}
	if len(rows.Folders) != len(want) {
		t.Fatalf("folders = %+v", rows.Folders)
	}
	for i, w := range want {
		got := rows.Folders[i]
		w.RealPath = w.Path // the temp home has its links resolved
		if got.Path != w.Path || got.RealPath != w.RealPath || got.Kind != w.Kind || !slices.Equal(got.ReadBy, w.ReadBy) ||
			got.OwnedBy != w.OwnedBy || got.CopyTarget != w.CopyTarget {
			t.Errorf("folder %d = %+v, want %+v", i, got, w)
		}
	}
	for _, it := range allItems(rows) {
		f := folderOf(rows, it.Folder)
		if f == nil || f.Kind != it.Kind || !slices.Contains(f.ReadBy, string(it.CLI)) || it.RealPath != it.Path {
			t.Errorf("%s: folder %q (%+v), realPath %q", it.ID, it.Folder, f, it.RealPath)
		}
	}
	for _, hk := range rows.Hooks {
		if f := folderOf(rows, hk.Folder); hk.Folder != hk.File || f == nil || f.Kind != KindHook {
			t.Errorf("hook %s: folder %q", hk.ID, hk.Folder)
		}
	}
}

// Who loses an item, counted by files (D53, RD-R11), in the four layouts a home can have.
func TestReadersMapLosers(t *testing.T) {
	const key = "skill::s"
	idOf := func(rows LoadoutRows, path string) string {
		for _, it := range allItems(rows) {
			if it.Path == path {
				return it.ID
			}
		}
		t.Fatalf("no item at %s", path)
		return ""
	}
	t.Run("a copy in ~/.claude/skills and one in ~/.agents/skills", func(t *testing.T) {
		h := newTempHome(t)
		h.write(".claude/skills/s/SKILL.md", skillFile("s"))
		h.write(".agents/skills/s/SKILL.md", skillFile("s"))
		h.write(".codex/config.toml", "")
		rows := rowsOf(t, h)
		if n := filesOf(rows, key); n != 2 {
			t.Errorf("files = %d, want 2", n)
		}
		if got := losersOf(rows, key, idOf(rows, h.path(".claude/skills/s"))); !slices.Equal(got, []string{"claude"}) {
			t.Errorf("removing Claude's copy loses %v", got)
		}
		if got := losersOf(rows, key, idOf(rows, h.path(".agents/skills/s"))); !slices.Equal(got, []string{"codex"}) {
			t.Errorf("removing the ~/.agents copy loses %v", got)
		}
	})
	t.Run("Codex reads it from two folders", func(t *testing.T) {
		h := newTempHome(t)
		h.write(".codex/skills/s/SKILL.md", skillFile("s"))
		h.write(".agents/skills/s/SKILL.md", skillFile("s"))
		rows := rowsOf(t, h)
		own, shared := idOf(rows, h.path(".codex/skills/s")), idOf(rows, h.path(".agents/skills/s"))
		if own == shared {
			t.Fatal("the two Codex copies share an id")
		}
		if got := losersOf(rows, key, own); len(got) != 0 {
			t.Errorf("removing ~/.codex/skills/s alone loses %v: Codex still reads ~/.agents/skills/s", got)
		}
		if got := losersOf(rows, key, own, shared); !slices.Equal(got, []string{"codex"}) {
			t.Errorf("removing both loses %v", got)
		}
	})
	t.Run("~/.agents/skills is a link to ~/.claude/skills", func(t *testing.T) {
		h := newTempHome(t)
		h.write(".claude/skills/s/SKILL.md", skillFile("s"))
		h.write(".codex/config.toml", "")
		if err := os.MkdirAll(h.path(".agents"), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(h.path(".claude/skills"), h.path(".agents/skills")); err != nil {
			t.Skipf("symlinks unavailable: %v", err)
		}
		rows := rowsOf(t, h)
		if f := folderOf(rows, h.path(".agents/skills")); f == nil || f.RealPath != h.path(".claude/skills") {
			t.Fatalf("the shared folder's realPath: %+v", f)
		}
		if n := filesOf(rows, key); n != 1 {
			t.Errorf("files = %d, want 1: both CLIs read one file", n)
		}
		want := []string{"claude", "codex"}
		if got := losersOf(rows, key, idOf(rows, h.path(".claude/skills/s"))); !slices.Equal(got, want) {
			t.Errorf("removing Claude's copy loses %v, want %v", got, want)
		}
		if got := losersOf(rows, key, idOf(rows, h.path(".agents/skills/s"))); !slices.Equal(got, want) {
			t.Errorf("removing it through ~/.agents loses %v, want %v", got, want)
		}
	})
	t.Run("Codex's copy is a link to Claude's", func(t *testing.T) {
		h := newTempHome(t)
		h.write(".claude/skills/s/SKILL.md", skillFile("s"))
		if err := os.MkdirAll(h.path(".codex/skills"), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(h.path(".claude/skills/s"), h.path(".codex/skills/s")); err != nil {
			t.Skipf("symlinks unavailable: %v", err)
		}
		rows := rowsOf(t, h)
		link := item(Snapshot{Items: allItems(rows)}, "s", Codex)
		if link == nil || link.Owner != "link" || link.RealPath != h.path(".claude/skills/s") {
			t.Fatalf("the link: %+v", link)
		}
		if n := filesOf(rows, key); n != 1 {
			t.Errorf("files = %d, want 1", n)
		}
		if got := losersOf(rows, key, link.ID); !slices.Equal(got, []string{"codex"}) {
			t.Errorf("removing the link loses %v", got)
		}
		if got := losersOf(rows, key, idOf(rows, h.path(".claude/skills/s"))); !slices.Equal(got, []string{"claude", "codex"}) {
			t.Errorf("removing the real copy loses %v: the link would dangle", got)
		}
	})
}

// RD31 is a pure function of the table: no CLI the engine reads today reads another CLI's folder, so nobody is "via";
// a reader of another CLI's folder (here a made-up entry) is via that CLI, unless it also reads its own folder.
func TestReadersMapVia(t *testing.T) {
	h := rowsHome(t)
	h.write(".agents/skills/both/SKILL.md", skillFile("both"))
	rows := rowsOf(t, h)
	var folders []string
	for _, m := range membersOf(rows, "skill::both") {
		folders = append(folders, m.Folder)
	}
	for _, c := range []string{"claude", "codex"} {
		if via := viaOf(rows.Folders, folders, c); via != nil {
			t.Errorf("%s reads both via %v", c, via)
		}
	}
	table := []Folder{
		{Path: "/h/.claude/skills", ReadBy: []string{"claude", "cursor"}, OwnedBy: "claude"},
		{Path: "/h/.agents/skills", ReadBy: []string{"codex", "cursor"}, OwnedBy: "codex"},
		{Path: "/h/.cursor/skills", ReadBy: []string{"cursor"}, OwnedBy: "cursor"},
	}
	if via := viaOf(table, []string{"/h/.claude/skills", "/h/.agents/skills"}, "cursor"); !slices.Equal(via, []string{"claude", "codex"}) {
		t.Errorf("via = %v", via)
	}
	if via := viaOf(table, []string{"/h/.claude/skills", "/h/.cursor/skills"}, "cursor"); via != nil {
		t.Errorf("a CLI with its own copy is not via: %v", via)
	}
}

// AR1: inventory.read and the two-CLI cells keep their shape; only loadout.rows carries the readers map.
func TestReadersMapOnlyOnLoadoutRows(t *testing.T) {
	h := rowsHome(t)
	h.write(".agents/skills/shared/SKILL.md", skillFile("shared"))
	data, err := json.Marshal(Read(h.roots()))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, member := range []string{`"folder"`, `"realPath"`, `"folders"`, `"extraItems"`, `"extraProblems"`, `.agents`} {
		if strings.Contains(text, member) {
			t.Errorf("inventory.read writes %s", member)
		}
	}
	rows := rowsOf(t, h)
	data, err = json.Marshal(rows)
	if err != nil {
		t.Fatal(err)
	}
	var tree struct {
		Folders       []map[string]any `json:"folders"`
		Items         []map[string]any `json:"items"`
		ExtraItems    []map[string]any `json:"extraItems"`
		ExtraProblems []string         `json:"extraProblems"`
		Hooks         []map[string]any `json:"hooks"`
	}
	if err := json.Unmarshal(data, &tree); err != nil {
		t.Fatal(err)
	}
	if len(tree.Folders) == 0 || len(tree.Folders[0]) != 6 {
		t.Fatalf("folders = %v", tree.Folders)
	}
	if len(tree.ExtraItems) != 1 || tree.ExtraProblems == nil {
		t.Fatalf("extraItems = %v, extraProblems = %v", tree.ExtraItems, tree.ExtraProblems)
	}
	if _, has := tree.ExtraItems[0]["cells"]; has || tree.ExtraItems[0]["cliCells"] == nil {
		t.Errorf("an extra item carries cliCells and no cells: %v", tree.ExtraItems[0])
	}
	for _, it := range append(tree.Items, tree.ExtraItems...) {
		if it["folder"] == nil || it["realPath"] == nil {
			t.Errorf("item without folder or realPath: %v", it["id"])
		}
	}
	for _, hk := range tree.Hooks {
		if hk["folder"] != hk["file"] {
			t.Errorf("hook %v: folder %v", hk["id"], hk["folder"])
		}
		if _, has := hk["realPath"]; has {
			t.Errorf("hook %v carries realPath", hk["id"])
		}
	}
	var back LoadoutRows
	if err := json.Unmarshal(data, &back); err != nil {
		t.Fatal(err)
	}
	for i := range back.Items {
		if back.Items[i].Folder != rows.Items[i].Folder || back.Items[i].RealPath != rows.Items[i].RealPath {
			t.Errorf("round trip of %s lost folder or realPath", rows.Items[i].ID)
		}
	}
}

// Swift has no counterpart: the readers map is new in RB-E2. The golden is the projection {folders, members}: the
// folder table of the fixture home and, per item and hook id, its folder and (items) its realPath.
func TestGoldenReadersMap(t *testing.T) {
	r, root := fixtureRoots(t)
	rows := BuildLoadoutRows(Read(r), usage.Scanning, fixtureNow(t))
	members := map[string]any{}
	for _, it := range allItems(rows) {
		members[it.ID] = map[string]any{"folder": it.Folder, "realPath": it.RealPath}
	}
	for _, hk := range rows.Hooks {
		members[hk.ID] = map[string]any{"folder": hk.Folder}
	}
	got := tokenHome(map[string]any{"folders": jsonTree(t, rows.Folders), "members": members}, root)
	if *updateReadersMap {
		text, err := goldentest.Canonical(got)
		if err != nil {
			t.Fatal(err)
		}
		dir, err := goldentest.FixturesDir()
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, "golden", "readers-map.json"), text, 0o644); err != nil {
			t.Fatal(err)
		}
		t.Log("wrote golden/readers-map.json: update its line in SHA256SUMS")
	}
	want, err := goldentest.LoadGolden("readers-map")
	if err != nil {
		t.Fatal(err)
	}
	goldentest.AssertCanonicalEqual(t, "readers-map", want, got)
	goldentest.AssertCaseCount(t, "readers-map golden members", len(members), 31)
}
