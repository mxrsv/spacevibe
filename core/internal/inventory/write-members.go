package inventory

import (
	"context"
	"slices"

	"spacevibe.dev/core/internal/cliregistry"
	"spacevibe.dev/core/internal/roots"
)

// Members is what the per-CLI write methods (loadout.copyTo, loadout.removeFrom, loadout.removeMany; RB-E3, RB-E4) look
// ids up in: every item of loadout.rows, the v5 items and the shared ~/.agents/skills ones alike, each with its Folder
// and RealPath, the hooks with their Folder, and the folder table with the readers of each folder. It is the readers map
// of loadout.rows without the usage join, so a write and the list the shell shows agree on who reads what.
//
// One difference from loadout.rows: a skill of ~/.agents/skills is Removable here. It is a user file Codex reads, and the
// new methods remove it like any other; only the v5 fields keep it out (and loadout.rows' extraItems keep Removable false
// until RB-X1, so the v5 decode never meets a change).
type Members struct {
	Items   []Item
	Hooks   []Hook
	Folders []Folder
}

// ReadMembers reads the inventory once and returns its members with the readers map (readers-map.go).
func ReadMembers(r roots.Roots) Members {
	raw, _, _ := read(context.Background(), r)
	shared := make([]Item, len(raw.shared))
	for i, item := range raw.shared {
		// Read with no owner and no project, so it is a user-level item (reader.go isUserLevel).
		item.Removable = item.Project == nil
		shared[i] = item
	}
	m := readersMap(raw.folders, raw.Items, shared, raw.Hooks, cliregistry.All())
	return Members{Items: append(slices.Clone(m.items), m.extra...), Hooks: m.hooks, Folders: m.folders}
}

// Readers are the registry ids that read the folder at path: its own readBy together with that of every folder with the
// same real path (a folder that is a link to another is the same folder on disk), in registry order. Empty when the
// folder is not in the table.
func (m Members) Readers(path string) []string {
	real := ""
	for _, f := range m.Folders {
		if f.Path == path {
			real = f.RealPath
			break
		}
	}
	if real == "" {
		return nil
	}
	seen := map[string]bool{}
	for _, f := range m.Folders {
		if f.RealPath == real {
			for _, id := range f.ReadBy {
				seen[id] = true
			}
		}
	}
	var out []string
	for _, c := range cliregistry.All() {
		if seen[string(c.ID)] {
			out = append(out, string(c.ID))
		}
	}
	return out
}

// Row is every item with the same row key as item (the item itself included), in the order of Items.
func (m Members) Row(item Item) []Item {
	var out []Item
	for _, other := range m.Items {
		if other.Key() == item.Key() {
			out = append(out, other)
		}
	}
	return out
}
