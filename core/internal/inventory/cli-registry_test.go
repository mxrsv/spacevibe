package inventory

import (
	"context"
	"errors"
	"reflect"
	"slices"
	"testing"

	"spacevibe.dev/core/internal/clis"
	"spacevibe.dev/core/internal/roots"
)

func TestInventoryAdaptersMatchRegistry(t *testing.T) {
	if err := adapters.Check(); err != nil {
		t.Fatal(err)
	}
}

// The fixed wire objects carry exactly the inventory CLIs. A CLI that gains the inventory concept fails here until
// the wire carries a map keyed by CLI id (step 0b).
func TestEveryInventoryCLIHasAWireSlot(t *testing.T) {
	if got := clis.IDsWith(clis.Inventory); !slices.Equal(got, wireCLIs) {
		t.Fatalf("inventory CLIs %v, wire members %v", got, wireCLIs)
	}
	for _, id := range wireCLIs {
		if _, ok := (Cells{}).For(id); !ok {
			t.Errorf("Cells has no member for %s", id)
		}
	}
}

// The old Cells.For answered Codex's cell for any id that was not Claude Code; events and the hook-log rule of a CLI
// without an inventory adapter are errors, never another CLI's.
func TestAnotherCLIIsNotReadAsCodex(t *testing.T) {
	cells := Cells{Claude: Missing(), Codex: Counted(3, nil, nil)}
	for _, c := range []struct {
		id   CLI
		want error
	}{{clis.Gemini, clis.ErrConceptAbsent}, {"nope", clis.ErrUnknownCLI}} {
		if cell, ok := cells.For(c.id); ok {
			t.Errorf("Cells.For(%s) = %+v", c.id, cell)
		}
		if _, err := EventsOf(c.id); !errors.Is(err, c.want) {
			t.Errorf("EventsOf(%s) = %v, want %v", c.id, err, c.want)
		}
		if _, err := UnloggedHooks(c.id); !errors.Is(err, c.want) {
			t.Errorf("UnloggedHooks(%s) = %v, want %v", c.id, err, c.want)
		}
	}
	if _, has := Events()[string(clis.Gemini)]; has {
		t.Error("Events lists gemini, which has no inventory")
	}
}

// otherProjectsCLI is a second CLI with a project folder (.other) that names the given candidates.
type otherProjectsCLI struct {
	codexInventory
	candidates []string
}

func (o otherProjectsCLI) projectCandidates(context.Context, roots.CLIRoots) []string {
	return o.candidates
}
func (otherProjectsCLI) projectFolder() (projectFolder, bool) {
	return projectFolder{Name: ".other"}, true
}

// ProjectFolders is Undo's write containment inside projects, so it lists only the folders discovery found in each
// project. With a second CLI that has project folders, a project with only .claude must not also allow writes under
// <project>/.other, and the other way round.
func TestProjectFoldersListOnlyFoldersThatExist(t *testing.T) {
	h := newTempHome(t)
	claudeOnly, otherOnly, both := h.path("work/claude-only"), h.path("work/other-only"), h.path("work/both")
	h.write("work/claude-only/.claude/settings.json", "{}")
	h.write("work/other-only/.other/settings.json", "{}")
	h.write("work/both/.claude/settings.json", "{}")
	h.write("work/both/.other/settings.json", "{}")
	h.write(".codex/config.toml", "[projects.\""+claudeOnly+"\"]\n[projects.\""+otherOnly+"\"]\n[projects.\""+both+"\"]\n")
	r := h.roots()
	bound, err := bind(r)
	if err != nil {
		t.Fatal(err)
	}
	other, err := r.CLI(clis.Codex)
	if err != nil {
		t.Fatal(err)
	}
	bound = append(bound, boundAdapter{"other", otherProjectsCLI{candidates: []string{claudeOnly, otherOnly, both}}, other})
	got := discoverBound(context.Background(), bound)
	want := []discoveredProject{
		{claudeOnly, []string{claudeOnly + "/.claude"}},
		{otherOnly, []string{otherOnly + "/.other"}},
		{both, []string{both + "/.claude", both + "/.other"}},
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("discovered = %+v\nwant %+v", got, want)
	}
	// Today, with Claude Code the only CLI with project folders, ProjectFolders is <project>/.claude per project.
	if got, want := ProjectFolders(r), []string{both + "/.claude", claudeOnly + "/.claude"}; !slicesEqualSorted(got, want) {
		t.Errorf("ProjectFolders = %q, want %q", got, want)
	}
}

func slicesEqualSorted(a, b []string) bool {
	a, b = slices.Clone(a), slices.Clone(b)
	slices.Sort(a)
	slices.Sort(b)
	return slices.Equal(a, b)
}
