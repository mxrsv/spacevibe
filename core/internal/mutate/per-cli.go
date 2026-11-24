package mutate

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"spacevibe.dev/core/internal/cliregistry"
	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/fsx"
	"spacevibe.dev/core/internal/hashes"
	"spacevibe.dev/core/internal/inventory"
	"spacevibe.dev/core/internal/roots"
	"spacevibe.dev/core/internal/textjs"
	"spacevibe.dev/core/internal/usage"
)

// Per-CLI copy and remove of one Skill or Subagent (RB-E3, spec RD14 and RD-R11): the logo toggles and the per-CLI
// sheet. They sit beside loadout.copyToOther and loadout.removeItem, which the v5 shell calls until RB-X1 (plan AR1).
//
// Both look the id up in inventory.ReadMembers, so an item of the shared ~/.agents/skills is found too, and both answer
// in the readers map's terms: copying into a folder another CLI also reads names those CLIs; removing names who lost the
// item and who still has it. Plugin and project items are refused (403): a plugin row is a lock, a project row is
// read-only. One call is one journal entry, so one Undo restores every file of it.

// CopyToResult is the result of loadout.copyTo. AlsoReaders are the CLIs the call did not name that read a folder the
// copy went into, so they have the item too ("… read the same folder, so they have it too"). Never null.
type CopyToResult struct {
	Entry       EntryRef `json:"entry"`
	AlsoReaders []string `json:"alsoReaders"`
}

// RemoveFromResult is the result of loadout.removeFrom: Lost are the CLIs that no longer have the item, StillHave the
// ones that read it from a file that stayed. Registry order, never null.
type RemoveFromResult struct {
	Entry     EntryRef `json:"entry"`
	Lost      []string `json:"lost"`
	StillHave []string `json:"stillHave"`
}

// findMember is the item with the id in a fresh read. A hook id is 400: these methods take Skills and Subagents.
func findMember(m inventory.Members, id string) (inventory.Item, error) {
	for _, item := range m.Items {
		if item.ID == id {
			return item, nil
		}
	}
	for _, hook := range m.Hooks {
		if hook.ID == id {
			return inventory.Item{}, coreerr.New("This method takes a Skill or a Subagent, not a Hook.")
		}
	}
	return inventory.Item{}, fail(msgRefreshList, coreerr.StatusNotFound)
}

// CopyTo copies a Skill or Subagent into each target CLI's own folder (Go API of loadout.copyTo).
func CopyTo(r roots.Roots, id string, targets []string) (CopyToResult, error) {
	return copyTo(context.Background(), r, id, targets)
}

func copyTo(ctx context.Context, r roots.Roots, id string, targets []string) (CopyToResult, error) {
	return lockedContext(ctx, r, func(tx *Tx) (CopyToResult, error) { return tx.copyTo(id, targets) })
}

func (tx *Tx) copyTo(id string, targetIDs []string) (CopyToResult, error) {
	if err := tx.PrepareMutation(); err != nil {
		return CopyToResult{}, err
	}
	m := inventory.ReadMembers(tx.r)
	item, err := findMember(m, id)
	if err != nil {
		return CopyToResult{}, err
	}
	if item.Scope == inventory.ScopeProject {
		return CopyToResult{}, requireRemovable(false, item.Scope)
	}
	if !item.Removable {
		return CopyToResult{}, fail("This one belongs to a plugin, so SpaceVibe does not copy it. Install the plugin in the other CLI instead.", coreerr.StatusForbidden)
	}
	targets, err := writableCLIs(targetIDs)
	if err != nil {
		return CopyToResult{}, err
	}
	row := m.Row(item)
	bare := hashes.Bare(item.Name)
	for _, target := range targets {
		if len(readBy(m, row, string(target))) > 0 {
			return CopyToResult{}, fail(label(target)+" already has "+bare+", so nothing was copied.", coreerr.StatusConflict)
		}
		// The target CLI's own folder must exist: a copy never makes the folder of a CLI that is not installed.
		if info, err := os.Stat(tx.cliRoots(target).Root); err != nil || !info.IsDir() {
			return CopyToResult{}, fail(label(target)+" is not installed on this Mac, so nothing was copied.", coreerr.StatusConflict)
		}
	}
	name, err := copyName(item)
	if err != nil {
		return CopyToResult{}, err
	}
	var ops []Op
	if item.Kind == inventory.KindSkill {
		tree, err := listSkillFolder(fsx.RealPath(item.Path))
		if err != nil {
			return CopyToResult{}, err
		}
		ops, err = tx.createAll(targets, func(cli usage.CLI) (createPlan, error) {
			dir := filepath.Join(tx.cliRoots(cli).Skills, name)
			if err := need(!pathExists(dir), label(cli)+" already has a skill named "+name+".", coreerr.StatusConflict); err != nil {
				return createPlan{}, err
			}
			return createPlan{path: dir, write: func() (bool, error) { return tree.copyTo(dir) }}, nil
		})
		if err != nil {
			return CopyToResult{}, err
		}
	} else {
		description, instructions, err := agentSource(item)
		if err != nil {
			return CopyToResult{}, err
		}
		ops, err = tx.createAll(targets, func(cli usage.CLI) (createPlan, error) {
			return tx.agentPlan(cli, name, description, instructions, true)
		})
		if err != nil {
			return CopyToResult{}, err
		}
	}
	entry, err := tx.RecordMutation("Copied "+string(item.Kind)+" "+name+" to "+labels(targets), ops)
	if err != nil {
		return CopyToResult{}, err
	}
	return CopyToResult{Entry: entry.Ref(), AlsoReaders: tx.alsoReaders(m, item.Kind, targets)}, nil
}

// copyName is the file name a copy gets: a skill is named after its folder, not the display name in SKILL.md ("PDF
// Tools" lives in pdf-tools); an agent after its name.
func copyName(item inventory.Item) (string, error) {
	name := hashes.Bare(item.Name)
	if item.Kind == inventory.KindSkill {
		name = item.Entry
	}
	if err := validName(name); err != nil {
		if item.Kind == inventory.KindSkill {
			return "", fail("The skill folder \""+name+"\" has a name SpaceVibe cannot use as a file name, so nothing was copied. Rename the folder in "+label(item.CLI)+" first.", coreerr.StatusConflict)
		}
		return "", fail("The "+string(item.Kind)+" \""+item.Name+"\" has a name SpaceVibe cannot use as a file name, so nothing was copied. Rename it in "+label(item.CLI)+" first.", coreerr.StatusConflict)
	}
	return name, nil
}

// agentSource reads an agent file once for every target.
func agentSource(item inventory.Item) (description, instructions string, err error) {
	data, err := readRegular(item.Path, maxAgentBytes)
	if err != nil {
		if err == errTooLarge {
			return "", "", fail("This agent file is larger than 1 MiB, so it was not copied. Nothing was changed.", coreerr.StatusTooLarge)
		}
		return "", "", fail("Could not read "+item.Path+". Nothing was changed.", coreerr.StatusConflict)
	}
	description, instructions = agentFields(strings.HasSuffix(item.Path, ".toml"), textjs.Repair(string(data)))
	return description, instructions, nil
}

// alsoReaders are the CLIs outside targets that read a folder the copy went into, in registry order.
func (tx *Tx) alsoReaders(m inventory.Members, kind inventory.Kind, targets []usage.CLI) []string {
	seen := map[string]bool{}
	for _, target := range targets {
		folder := tx.cliRoots(target).Agents
		if kind == inventory.KindSkill {
			folder = tx.cliRoots(target).Skills
		}
		for _, id := range m.Readers(strings.TrimRight(folder, "/")) {
			if !slices.Contains(targets, usage.CLI(id)) {
				seen[id] = true
			}
		}
	}
	out := []string{}
	for _, c := range cliregistry.All() {
		if seen[string(c.ID)] {
			out = append(out, string(c.ID))
		}
	}
	return out
}

// RemoveFrom takes a Skill or Subagent away from each CLI (Go API of loadout.removeFrom).
func RemoveFrom(r roots.Roots, id string, clis []string) (RemoveFromResult, error) {
	return removeFrom(context.Background(), r, id, clis)
}

func removeFrom(ctx context.Context, r roots.Roots, id string, clis []string) (RemoveFromResult, error) {
	return lockedContext(ctx, r, func(tx *Tx) (RemoveFromResult, error) { return tx.removeFrom(id, clis) })
}

// removeFrom removes every file each named CLI reads the item from (RD-R11), and refuses, before anything changes:
//   - a plugin or project item (403), or a plugin copy among the files that would go (403);
//   - a named CLI that does not have the item (409);
//   - a file that a CLI the call did not name also reads (409, naming every reader): a shared file goes only when the
//     caller passes every reader of it.
func (tx *Tx) removeFrom(id string, cliIDs []string) (RemoveFromResult, error) {
	if err := tx.PrepareMutation(); err != nil {
		return RemoveFromResult{}, err
	}
	m := inventory.ReadMembers(tx.r)
	item, err := findMember(m, id)
	if err != nil {
		return RemoveFromResult{}, err
	}
	if err := requireRemovable(item.Removable, item.Scope); err != nil {
		return RemoveFromResult{}, err
	}
	clis, err := writableCLIs(cliIDs)
	if err != nil {
		return RemoveFromResult{}, err
	}
	row := m.Row(item)
	bare := hashes.Bare(item.Name)
	var chosen []inventory.Item
	for _, cli := range clis {
		read := readBy(m, row, string(cli))
		if len(read) == 0 {
			return RemoveFromResult{}, fail(label(cli)+" does not have "+bare+", so nothing was removed.", coreerr.StatusConflict)
		}
		chosen = append(chosen, read...)
	}
	// Every member, not only the row: a link under another name (its SKILL.md has no name) reaches the file too.
	going := expandRemoval(m.Items, chosen)
	for _, member := range going {
		if err := requireMemberRemovable(member); err != nil {
			return RemoveFromResult{}, err
		}
	}
	named := make([]string, len(clis))
	for i, cli := range clis {
		named[i] = string(cli)
	}
	for _, file := range byFile(going) {
		readers := readersOf(m, file)
		if slices.ContainsFunc(readers, func(id string) bool { return !slices.Contains(named, id) }) {
			return RemoveFromResult{}, sharedFileRefusal(bare, readers, "it can only be removed from all of them at once.")
		}
	}
	ops, err := tx.removeMembers(going)
	if err != nil {
		return RemoveFromResult{}, err
	}
	gone := map[string]bool{}
	for _, member := range going {
		gone[member.ID] = true
	}
	lost, kept := lostAndKept(m, row, gone)
	entry, err := tx.RecordMutation("Removed "+string(item.Kind)+" "+bare+" from "+idLabels(lost), ops)
	if err != nil {
		return RemoveFromResult{}, err
	}
	return RemoveFromResult{Entry: entry.Ref(), Lost: nonNil(lost), StillHave: nonNil(kept)}, nil
}

func nonNil(ids []string) []string {
	if ids == nil {
		return []string{}
	}
	return ids
}
