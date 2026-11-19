package usage

import (
	"errors"
	"testing"

	"spacevibe.dev/core/internal/clis"
)

func TestParsersMatchRegistry(t *testing.T) {
	if err := parsers.Check(); err != nil {
		t.Fatal(err)
	}
}

// Every CLI the scan reads has a member in each fixed wire object. A CLI that gains the usage concept fails here
// until the wire carries a map keyed by CLI id (step 0b).
func TestEveryUsageCLIHasAWireSlot(t *testing.T) {
	var r Result
	for _, id := range clis.IDsWith(clis.Usage) {
		if _, err := r.Totals.slot(id); err != nil {
			t.Error(err)
		}
		if _, err := r.Windows.slot(id); err != nil {
			t.Error(err)
		}
		if _, err := r.Sessions.slot(id); err != nil {
			t.Error(err)
		}
	}
}

// The old Totals.For and Windows.For answered Codex's member for any id that was not Claude Code.
func TestWireSlotOfAnotherCLIIsAnError(t *testing.T) {
	totals := Totals{Codex: CLITotals{Skill: map[string]NameUsage{"codex-only": {Sessions: 1}}}}
	for _, id := range []CLI{clis.Gemini, "nope"} {
		if got, err := totals.For(id); !errors.Is(err, clis.ErrUnknownCLI) || got.Skill != nil {
			t.Errorf("Totals.For(%s) = %+v, %v", id, got, err)
		}
		if _, err := (Windows{}).For(id); !errors.Is(err, clis.ErrUnknownCLI) {
			t.Errorf("Windows.For(%s) = %v", id, err)
		}
	}
}
