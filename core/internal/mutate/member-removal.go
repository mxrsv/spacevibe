package mutate

import (
	"path/filepath"
	"slices"
	"strings"

	"spacevibe.dev/core/internal/cliregistry"
	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/hashes"
	"spacevibe.dev/core/internal/inventory"
	"spacevibe.dev/core/internal/roots"
	"spacevibe.dev/core/internal/textjs"
	"spacevibe.dev/core/internal/usage"
)

// What the per-CLI writes (per-cli.go, remove-many.go) share: which CLIs a call names, which members go when a member
// goes, who loses the item, and the removal itself. The rules are the readers map's (docs/internals/inventory.md
// #readers-map): removing a link takes only the link; removing any other member takes its file, so every member with the
// same real path goes with it (a link to it would dangle).

// msgNotAKnownCLI is the 400 for a CLI id the write methods cannot write for.
const msgNotAKnownCLI = "That CLI is not one SpaceVibe can change."

// writableCLIs checks the CLI ids of a call: at least one, each a registry CLI SpaceVibe has folders for (Claude Code
// and Codex today), in the order given with repeats dropped.
func writableCLIs(ids []string) ([]usage.CLI, error) {
	if err := need(len(ids) > 0, "Pick at least one CLI."); err != nil {
		return nil, err
	}
	var out []usage.CLI
	for _, id := range ids {
		cli := usage.CLI(id)
		if _, ok := cliregistry.Lookup(cliregistry.ID(id)); !ok || (cli != inventory.Claude && cli != inventory.Codex) {
			return nil, coreerr.New(msgNotAKnownCLI)
		}
		if !slices.Contains(out, cli) {
			out = append(out, cli)
		}
	}
	return out, nil
}

// idLabels is labels for registry ids.
func idLabels(ids []string) string {
	clis := make([]usage.CLI, len(ids))
	for i, id := range ids {
		clis[i] = usage.CLI(id)
	}
	return labels(clis)
}

func isLinkMember(item inventory.Item) bool { return item.Owner == "link" }

// readersOf are the registry ids that read any of the members, in registry order.
func readersOf(m inventory.Members, members []inventory.Item) []string {
	seen := map[string]bool{}
	for _, item := range members {
		for _, id := range m.Readers(item.Folder) {
			seen[id] = true
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

// readBy are the members of the row that the CLI reads.
func readBy(m inventory.Members, row []inventory.Item, cli string) []inventory.Item {
	var out []inventory.Item
	for _, item := range row {
		if slices.Contains(m.Readers(item.Folder), cli) {
			out = append(out, item)
		}
	}
	return out
}

// expandRemoval is chosen plus, for each chosen member that is not a link, every member of all with the same real
// path, in the order of all.
func expandRemoval(all, chosen []inventory.Item) []inventory.Item {
	take := map[string]bool{}
	for _, c := range chosen {
		take[c.ID] = true
		if isLinkMember(c) {
			continue
		}
		for _, other := range all {
			if other.RealPath == c.RealPath {
				take[other.ID] = true
			}
		}
	}
	var out []inventory.Item
	for _, item := range all {
		if take[item.ID] {
			out = append(out, item)
		}
	}
	return out
}

// byFile groups members by real path, in first-seen order: one group is one file on disk and every path that reaches it.
func byFile(members []inventory.Item) [][]inventory.Item {
	index := map[string]int{}
	var out [][]inventory.Item
	for _, item := range members {
		i, ok := index[item.RealPath]
		if !ok {
			i = len(out)
			index[item.RealPath] = i
			out = append(out, nil)
		}
		out[i] = append(out[i], item)
	}
	return out
}

// sharedFileRefusal is the 409 for a file read by more CLIs than the call names. It names every reader.
func sharedFileRefusal(name string, readers []string, ask string) error {
	return fail(name+" is one file that "+idLabels(readers)+" read, so "+ask+" Nothing was changed.", coreerr.StatusConflict)
}

// lostAndKept says, for every registry CLI that reads the row, whether it loses the item once gone (ids) is removed or
// still has it, in registry order. A hidden CLI counts like any other (spec "Show in Settings › CLIs").
func lostAndKept(m inventory.Members, row []inventory.Item, gone map[string]bool) (lost, kept []string) {
	for _, c := range cliregistry.All() {
		read := readBy(m, row, string(c.ID))
		if len(read) == 0 {
			continue
		}
		if slices.IndexFunc(read, func(item inventory.Item) bool { return !gone[item.ID] }) < 0 {
			lost = append(lost, string(c.ID))
		} else {
			kept = append(kept, string(c.ID))
		}
	}
	return lost, kept
}

// requireMemberRemovable is requireRemovable for a member that goes with another one: a plugin copy of the same item is
// never taken away by a per-CLI write.
func requireMemberRemovable(item inventory.Item) error {
	if item.Removable {
		return nil
	}
	if item.Scope == inventory.ScopeProject {
		return requireRemovable(false, item.Scope)
	}
	return fail(label(item.CLI)+" also reads "+hashes.Bare(item.Name)+" from a plugin, so SpaceVibe cannot take it away. Remove the plugin instead.", coreerr.StatusForbidden)
}

// memberBase is the CLI folder the member sits directly in: the CLI's own skills or agents folder, or for a Codex skill
// also the shared ~/.agents/skills. The path must be a direct child of that folder lexically, and its parent must be
// that folder once links are followed, so a link in the middle of the path cannot send the removal anywhere else. The
// member itself may be a link (it is unlinked, never followed).
func (tx *Tx) memberBase(item inventory.Item) error {
	cli := tx.cliRoots(item.CLI)
	bases := []string{cli.Agents}
	if item.Kind == inventory.KindSkill {
		bases = []string{cli.Skills}
		if item.CLI == inventory.Codex && tx.r.AgentsSkills != "" {
			bases = append(bases, tx.r.AgentsSkills)
		}
	}
	path := textjs.Normalize(item.Path)
	for _, base := range bases {
		if base == "" {
			continue
		}
		if filepath.Dir(path) == textjs.Normalize(base) && strings.HasPrefix(path, textjs.Normalize(base)+"/") &&
			roots.ResolvedPath(filepath.Dir(path)) == roots.ResolvedPath(base) {
			return nil
		}
	}
	return fail("Refusing a path outside the CLI folder.", coreerr.StatusForbidden)
}

// removeMembers removes the members, every check first: each path must pass memberBase. Then, per file, the links go
// (each unlinked, its text kept) and one path of the file goes to the trash (the one that is the real path when there is
// one), which takes every other spelling of it along. A failed step puts back what this call already removed.
func (tx *Tx) removeMembers(members []inventory.Item) ([]Op, error) {
	for _, item := range members {
		if err := tx.memberBase(item); err != nil {
			return nil, err
		}
	}
	var links, files []string
	for _, group := range byFile(members) {
		var plain []inventory.Item
		for _, item := range group {
			if isLinkMember(item) {
				links = append(links, item.Path)
			} else {
				plain = append(plain, item)
			}
		}
		if len(plain) == 0 {
			continue
		}
		pick := plain[0]
		for _, item := range plain {
			if textjs.Normalize(item.Path) == item.RealPath {
				pick = item
				break
			}
		}
		files = append(files, pick.Path)
	}
	var ops []Op
	for _, path := range append(links, files...) {
		op, err := removePath(tx.r, path)
		if err != nil {
			return nil, tx.afterRollback(ops, err)
		}
		ops = append(ops, op)
	}
	return ops, nil
}
