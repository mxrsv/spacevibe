package clean

import (
	"context"
	"testing"

	"spacevibe.dev/core/internal/inventory"
	"spacevibe.dev/core/internal/mutate"
)

// neverRan is a counted zero in every CLI that counts it.
func neverRan(cells map[string]inventory.CLICell) bool {
	counted := false
	for _, c := range cells {
		if c.Sessions != nil {
			if *c.Sessions > 0 {
				return false
			}
			counted = true
		}
	}
	return counted
}

// CL-R1, through loadout.removeMany (Clean never removes equipment itself): on a fixture home, 3 Never ran items and 1
// Dead hook go in one entry, and one Undo brings all 4 back byte for byte. A plugin-owned Never ran Skill cannot be
// picked: removeMany refuses it, and clean.scan gives its row no size, so the shell offers nothing to select.
func TestEquipmentInBulkThroughRemoveMany(t *testing.T) {
	t.Parallel()
	h := fixtureHome(t)
	// The fixture's plugin skill ran; a synthetic one beside it in the private copy never did (the frozen tree stays).
	h.write(".claude/plugins/cache/neon/skills/sv-unused/SKILL.md", "---\nname: sv-unused\ndescription: Synthetic plugin skill\n---\n", 1)
	ctx := context.Background()
	if _, err := h.scanner.Scan(ctx, nil); err != nil {
		t.Fatal(err)
	}
	rows, err := inventory.NewService(h.r, h.scanner).Rows(ctx)
	if err != nil {
		t.Fatal(err)
	}
	var ids []string
	var plugin string
	keys := map[string]bool{}
	for _, it := range rows.Items {
		if !neverRan(it.CLICells) {
			continue
		}
		if !it.Removable && it.Owner != "user" && it.Owner != "link" && it.Project == nil && plugin == "" {
			plugin = it.ID
		}
		if it.Removable && it.Owner == "user" && len(ids) < 3 && !keys[it.Key()] {
			ids = append(ids, it.ID)
			keys[it.Key()] = true
		}
	}
	for _, hk := range rows.Hooks {
		if hk.Dead && hk.Removable {
			ids = append(ids, hk.ID)
			break
		}
	}
	if len(ids) != 4 || plugin == "" {
		t.Fatalf("the fixture lacks 3 Never ran items, a Dead hook and a plugin Never ran skill: %v %q", ids, plugin)
	}
	svc := mutate.NewService(h.r)
	if _, err := svc.RemoveMany(ctx, mutate.IDsParams{IDs: []string{ids[0], plugin}}); statusOf(err) != 403 {
		t.Fatalf("a plugin item was accepted: %v", err)
	}
	sizes := map[string]bool{}
	for _, it := range h.scan().Items {
		sizes[it.Key] = true
	}
	for _, it := range rows.Items {
		if it.ID == plugin && sizes[it.Key()] {
			pluginOnly := true
			for _, other := range rows.Items {
				if other.Key() == it.Key() && other.Removable {
					pluginOnly = false
				}
			}
			if pluginOnly {
				t.Errorf("clean.scan sizes the plugin-only row %s", it.Key())
			}
		}
	}

	before := h.tree()
	res, err := svc.RemoveMany(ctx, mutate.IDsParams{IDs: ids})
	if err != nil {
		t.Fatal(err)
	}
	after := inventory.ReadMembers(h.r)
	for _, id := range ids {
		for _, it := range after.Items {
			if it.ID == id {
				t.Errorf("%s is still there", id)
			}
		}
		for _, hk := range after.Hooks {
			if hk.ID == id {
				t.Errorf("hook %s is still there", id)
			}
		}
	}
	if hist, _ := mutate.History(h.r); len(hist) != 1 {
		t.Fatalf("%d journal entries, want 1", len(hist))
	}
	if err := h.undo(res.Entry.ID); err != nil {
		t.Fatal(err)
	}
	sameFiles(t, withoutTimes(before), withoutTimes(h.tree()))
}
