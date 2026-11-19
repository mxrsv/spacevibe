package inventory

import (
	"errors"
	"slices"
	"testing"

	"spacevibe.dev/core/internal/clis"
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
