package inventory

import (
	"slices"
	"strings"

	"spacevibe.dev/core/internal/cliregistry"
	"spacevibe.dev/core/internal/roots"
)

// The readers map (RB-E2): loadout.rows lists every folder a row lives in, and every installed CLI's own global
// folders, with the CLIs that read each one. Every item and hook names its folder, and every item its real path, so
// the shell can tell from data alone which CLI reads an item through another CLI's folder ("via", RD31), how many
// files a row has (D53 counts files) and which CLIs lose the item when files go (RD-R11). The core states what it
// read; it never guesses a reader. docs/internals/inventory.md#readers-map has the rules the shell derives.

// agentsSkillsTag is the id tag of a skill read from the shared ~/.agents/skills: "codex:skill:agents:<entry>", so
// it never shares an id with the same entry in ~/.codex/skills ("codex:skill:local:<entry>").
const agentsSkillsTag = "agents"

// Folder is one place a CLI reads items of one kind from: a skills or agents folder, or for hooks the file that holds
// them. Path is the spelling the reader used, which an item's or hook's Folder repeats exactly.
type Folder struct {
	Path string `json:"path"`
	// RealPath is Path with every link followed (roots.ResolvedPath). Two folders with the same RealPath are one
	// folder on disk: their readers add up.
	RealPath string `json:"realPath"`
	Kind     Kind   `json:"kind"`
	// ReadBy are the registry ids of the CLIs that read this folder, in registry order. Never empty.
	ReadBy []string `json:"readBy"`
	// OwnedBy is the CLI whose folder this is. A CLI that reads an item only from folders other CLIs own reads it
	// "via" them (RD31).
	OwnedBy string `json:"ownedBy"`
	// CopyTarget: loadout.copyToOther writes a copy into OwnedBy here (the CLI's own skills or agents folder, or its
	// hook file). False for the shared ~/.agents/skills, plugin and project folders.
	CopyTarget bool `json:"copyTarget"`
}

// ownFolders are a CLI's own global skills folder, agents folder and hook file, read by that CLI alone.
func ownFolders(cli CLI, r roots.CLIRoots) []Folder {
	own := func(path string, kind Kind) Folder {
		return Folder{Path: trimSlash(path), Kind: kind, ReadBy: []string{string(cli)}, OwnedBy: string(cli), CopyTarget: true}
	}
	return []Folder{own(r.Skills, KindSkill), own(r.Agents, KindAgent), own(r.HookFile, KindHook)}
}

// agentsSkillsFolder is ~/.agents/skills. Codex reads it (codex-cli 0.170.0, plan RB-T0a); Claude Code does not, as
// far as anyone checked, so it is not listed as a reader. Another registry CLI that reads it joins ReadBy together
// with its registry entry.
func agentsSkillsFolder(path string) Folder {
	return Folder{Path: trimSlash(path), Kind: KindSkill, ReadBy: []string{string(Codex)}, OwnedBy: string(Codex)}
}

// sharedSkills are the skills of ~/.agents/skills as Codex items: their own id tag, and not removable. They are in no
// field the v5 shell decodes until RB-X1 (plan AR1, FE-P9): not in inventory.read, not in loadout.rows' items, cells,
// countsByScope, rowFlags or problems. loadout.rows writes them as extraItems, and they count in every row's
// cliCells. The write methods find ids through inventory.Read, so they do not see them either (RB-E3 owns writes to a
// shared folder). It returns new items (C1).
func sharedSkills(items []Item) []Item {
	out := make([]Item, len(items))
	for i, item := range items {
		item.ID = string(Codex) + ":skill:" + agentsSkillsTag + ":" + item.Entry
		item.Removable = false
		out[i] = item
	}
	return out
}

// mapped is one loadout.rows answer's readers map: the folder table, and copies of the v5 items, the extra items and
// the hooks with Folder (and for items RealPath) set.
type mapped struct {
	folders []Folder
	items   []Item
	extra   []Item
	hooks   []Hook
}

// readersMap is the folder table of one loadout.rows answer plus each row's folder: the global folders the reader
// recorded, then every folder a row lives in that is not one of them (plugin and project folders), sorted by path.
// extra are the items no v5 field carries (the shared skills). It returns new slices.
func readersMap(global []Folder, items, extra []Item, hooks []Hook, registry []cliregistry.CLI) mapped {
	byPath := map[string]int{}
	var folders []Folder
	add := func(path string, kind Kind, cli CLI) {
		if i, ok := byPath[path]; ok {
			if !slices.Contains(folders[i].ReadBy, string(cli)) {
				folders[i].ReadBy = append(slices.Clone(folders[i].ReadBy), string(cli))
			}
			return
		}
		byPath[path] = len(folders)
		folders = append(folders, Folder{Path: path, Kind: kind, ReadBy: []string{string(cli)}, OwnedBy: string(cli)})
	}
	for _, f := range global {
		byPath[f.Path] = len(folders)
		folders = append(folders, Folder{Path: f.Path, Kind: f.Kind, ReadBy: slices.Clone(f.ReadBy), OwnedBy: f.OwnedBy, CopyTarget: f.CopyTarget})
	}
	withFolders := func(list []Item) []Item {
		if list == nil {
			return nil
		}
		out := make([]Item, len(list))
		for i, item := range list {
			item.Folder = parentOf(item.Path)
			item.RealPath = roots.ResolvedPath(item.Path)
			add(item.Folder, item.Kind, item.CLI)
			out[i] = item
		}
		return out
	}
	outItems, outExtra := withFolders(items), withFolders(extra)
	outHooks := make([]Hook, len(hooks))
	for i, hook := range hooks {
		hook.Folder = hook.File
		add(hook.Folder, KindHook, hook.CLI)
		outHooks[i] = hook
	}
	order := func(id string) int {
		return slices.IndexFunc(registry, func(c cliregistry.CLI) bool { return string(c.ID) == id })
	}
	for i := range folders {
		folders[i].RealPath = roots.ResolvedPath(folders[i].Path)
		slices.SortStableFunc(folders[i].ReadBy, func(a, b string) int { return order(a) - order(b) })
	}
	slices.SortStableFunc(folders, func(a, b Folder) int { return strings.Compare(a.Path, b.Path) })
	if folders == nil {
		folders = []Folder{}
	}
	if outExtra == nil {
		outExtra = []Item{}
	}
	return mapped{folders: folders, items: outItems, extra: outExtra, hooks: outHooks}
}

// parentOf is the folder an item path was joined onto (fileio.join), with no cleaning, so it equals the folder path
// the reader used.
func parentOf(path string) string {
	if i := strings.LastIndex(path, "/"); i > 0 {
		return path[:i]
	}
	return path
}

func trimSlash(path string) string {
	if trimmed := strings.TrimRight(path, "/"); trimmed != "" {
		return trimmed
	}
	return path
}
