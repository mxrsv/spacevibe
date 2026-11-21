package mutate

import (
	"context"
	"slices"
	"strings"

	"spacevibe.dev/core/internal/cliregistry"
	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/hashes"
	"spacevibe.dev/core/internal/inventory"
	"spacevibe.dev/core/internal/ojson"
	"spacevibe.dev/core/internal/roots"
)

// Batch removal (RB-E4, spec RD-R4 and RD-A6): the selection of Skills, Subagents and Hooks, mixed, removed in one
// journal entry, so one Undo restores all of it. Each id is one member (an item or a hook of one CLI), as the list
// sends it; the call is all or nothing: every refusal comes before the first change, and a step that fails puts back
// the steps already written (afterRollback, as createAll and addHook do).

// RemoveManyResult is the result of loadout.removeMany: Lost are the CLIs that lost at least one item or hook, in
// registry order. Never null.
type RemoveManyResult struct {
	Entry EntryRef `json:"entry"`
	Lost  []string `json:"lost"`
}

// RemoveMany removes every member in ids (Go API of loadout.removeMany).
func RemoveMany(r roots.Roots, ids []string) (RemoveManyResult, error) {
	return removeMany(context.Background(), r, ids)
}

func removeMany(ctx context.Context, r roots.Roots, ids []string) (RemoveManyResult, error) {
	return lockedContext(ctx, r, func(tx *Tx) (RemoveManyResult, error) { return tx.removeMany(ids) })
}

// removeMany refuses, before anything changes, what the single paths refuse: an id that is gone (404), a plugin or
// project member (403), a hook that changed (409, inside the one edit of its file). And one rule of its own: a member
// whose file another member also reaches (a link to it, or the same folder under another spelling) goes only when that
// member is in ids too (409, naming every reader), so nothing is left dangling that the caller did not pick.
func (tx *Tx) removeMany(ids []string) (RemoveManyResult, error) {
	if err := tx.PrepareMutation(); err != nil {
		return RemoveManyResult{}, err
	}
	if err := need(len(ids) > 0, "Pick at least one item to remove."); err != nil {
		return RemoveManyResult{}, err
	}
	m := inventory.ReadMembers(tx.r)
	var items []inventory.Item
	var hooks []inventory.Hook
	picked := map[string]bool{}
	for _, id := range ids {
		if picked[id] {
			continue
		}
		picked[id] = true
		if i := slices.IndexFunc(m.Items, func(item inventory.Item) bool { return item.ID == id }); i >= 0 {
			if err := requireRemovable(m.Items[i].Removable, m.Items[i].Scope); err != nil {
				return RemoveManyResult{}, err
			}
			items = append(items, m.Items[i])
			continue
		}
		if i := slices.IndexFunc(m.Hooks, func(hook inventory.Hook) bool { return hook.ID == id }); i >= 0 {
			if err := requireRemovable(m.Hooks[i].Removable, m.Hooks[i].Scope); err != nil {
				return RemoveManyResult{}, err
			}
			hooks = append(hooks, m.Hooks[i])
			continue
		}
		return RemoveManyResult{}, fail(msgRefreshList, coreerr.StatusNotFound)
	}
	for _, item := range items {
		going := expandRemoval(m.Items, []inventory.Item{item})
		if slices.ContainsFunc(going, func(member inventory.Item) bool { return !picked[member.ID] }) {
			return RemoveManyResult{}, sharedFileRefusal(hashes.Bare(item.Name), readersOf(m, going), "pick every copy of it to remove it.")
		}
	}

	ops, err := tx.removeMembers(items)
	if err != nil {
		return RemoveManyResult{}, err
	}
	hookOps, err := tx.removeHooks(hooks)
	if err != nil {
		return RemoveManyResult{}, tx.afterRollback(ops, err)
	}
	ops = append(ops, hookOps...)

	lost := lostByMany(m, items, hooks, picked)
	entry, err := tx.RecordMutation(manyLabel(items, hooks, lost), ops)
	if err != nil {
		return RemoveManyResult{}, err
	}
	return RemoveManyResult{Entry: entry.Ref(), Lost: nonNil(lost)}, nil
}

// removeHooks removes the hooks with one edit per hook file, so the hook-removed ops of one file share its restore and
// Undo puts that file back byte for byte. A hook that is no longer in its file refuses the whole call (409); the files
// already edited are put back.
func (tx *Tx) removeHooks(hooks []inventory.Hook) ([]Op, error) {
	var files []string
	byFile := map[string][]inventory.Hook{}
	for _, hook := range hooks {
		file := tx.cliRoots(hook.CLI).HookFile
		if _, ok := byFile[file]; !ok {
			files = append(files, file)
		}
		byFile[file] = append(byFile[file], hook)
	}
	changed := func() error { return fail("This hook has already changed. Refresh the list.", coreerr.StatusConflict) }
	var ops []Op
	for _, file := range files {
		type removal struct {
			hook  inventory.Hook
			value ojson.Value
		}
		var removed []removal
		edit, err := tx.ApplyJSON(file, nil, func(doc *ojson.Document) (*ojson.Document, error) {
			for _, h := range byFile[file] {
				next, value, ok, err := hookRemoving(doc, file, h.Event, h.Matcher, h.Command)
				if err != nil {
					return nil, err
				}
				if !ok {
					return nil, changed()
				}
				doc = next
				removed = append(removed, removal{h, value})
			}
			return doc, nil
		})
		if err == nil && (edit == nil || len(removed) != len(byFile[file])) {
			err = changed()
		}
		if err != nil {
			return nil, tx.afterRollback(ops, err)
		}
		for _, rm := range removed {
			ops = append(ops, hookOp("hook-removed", file, rm.hook.Event, rm.hook.Matcher, rm.value, *edit))
		}
	}
	return ops, nil
}

// lostByMany are the CLIs that lose at least one item or hook, in registry order: for an item row, a CLI that read it
// and reads none of its members any more; for a hook, its CLI unless another hook of the same row stays in that CLI.
func lostByMany(m inventory.Members, items []inventory.Item, hooks []inventory.Hook, gone map[string]bool) []string {
	seen := map[string]bool{}
	rows := map[string]bool{}
	for _, item := range items {
		if rows[item.Key()] {
			continue
		}
		rows[item.Key()] = true
		lost, _ := lostAndKept(m, m.Row(item), gone)
		for _, id := range lost {
			seen[id] = true
		}
	}
	for _, hook := range hooks {
		stays := slices.ContainsFunc(m.Hooks, func(other inventory.Hook) bool {
			return other.Key() == hook.Key() && other.CLI == hook.CLI && !gone[other.ID]
		})
		if !stays {
			seen[string(hook.CLI)] = true
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

// manyLabel is the journal label: the single-path label for one item or one hook, otherwise the counts by kind (rows,
// not members: a skill removed from two CLIs is one skill) and the CLIs that lost something.
func manyLabel(items []inventory.Item, hooks []inventory.Hook, lost []string) string {
	count := map[inventory.Kind]map[string]bool{inventory.KindSkill: {}, inventory.KindAgent: {}, inventory.KindHook: {}}
	for _, item := range items {
		count[item.Kind][item.Key()] = true
	}
	for _, hook := range hooks {
		count[inventory.KindHook][hook.Key()] = true
	}
	total := len(count[inventory.KindSkill]) + len(count[inventory.KindAgent]) + len(count[inventory.KindHook])
	// No CLI lost anything when every member removed was a second copy: the label says a copy went.
	from, single := "", "Removed a copy of "
	if len(lost) > 0 {
		from, single = " from "+idLabels(lost), "Removed "
	}
	if total == 1 && len(items) > 0 {
		return single + string(items[0].Kind) + " " + hashes.Bare(items[0].Name) + from
	}
	if total == 1 {
		return single + hooks[0].Event + " hook" + from
	}
	var parts []string
	for _, kind := range []inventory.Kind{inventory.KindSkill, inventory.KindAgent, inventory.KindHook} {
		if n := len(count[kind]); n > 0 {
			noun := string(kind)
			if n > 1 {
				noun += "s"
			}
			parts = append(parts, itoa(n)+" "+noun)
		}
	}
	text := parts[0]
	if len(parts) > 1 {
		text = strings.Join(parts[:len(parts)-1], ", ") + " and " + parts[len(parts)-1]
	}
	return "Removed " + text + from
}
