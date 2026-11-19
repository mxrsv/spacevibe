package mutate

import (
	"context"
	"errors"
	"os"
	"strings"
	"testing"

	"spacevibe.dev/core/internal/clis"
	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/usage"
)

func TestWritersMatchRegistry(t *testing.T) {
	if err := writers.Check(); err != nil {
		t.Fatal(err)
	}
}

// MC-T3: a write naming a CLI SpaceVibe does not write (Gemini CLI has no mutate concept) or an id the registry does
// not know is refused and writes nothing. The old cliRoots sent every id that was not Claude Code to Codex's folders,
// so these calls created ~/.codex/skills/<name> and ~/.codex/agents/<name>.toml.
func TestWriteToAnUnwrittenCLIIsRefused(t *testing.T) {
	cases := []struct {
		id   usage.CLI
		want error
	}{{clis.Gemini, clis.ErrConceptAbsent}, {"nope", clis.ErrUnknownCLI}}
	for _, c := range cases {
		h := newHome(t)
		h.write(".codex/config.toml", "")
		h.write(".claude/settings.json", "{}")
		r := h.roots()
		if _, err := AddSkill(r, []usage.CLI{c.id}, "stray", "Synthetic skill", ""); !errors.Is(err, c.want) {
			t.Errorf("AddSkill(%s) = %v, want %v", c.id, err, c.want)
		}
		if _, err := AddAgent(r, []usage.CLI{c.id}, "stray", "Synthetic agent", "Do it."); !errors.Is(err, c.want) {
			t.Errorf("AddAgent(%s) = %v, want %v", c.id, err, c.want)
		}
		if _, err := AddHook(r, []usage.CLI{c.id}, "Stop", nil, "true", nil); !errors.Is(err, c.want) {
			t.Errorf("AddHook(%s) = %v, want %v", c.id, err, c.want)
		}
		for _, rel := range []string{".codex/skills/stray", ".codex/agents/stray.toml", ".claude/skills/stray", ".codex/hooks.json"} {
			if _, err := os.Lstat(h.path(rel)); !errors.Is(err, os.ErrNotExist) {
				t.Errorf("%s: %s was written (err %v)", c.id, rel, err)
			}
		}
	}
}

// loadout.removeDeadHooks accepts exactly the CLIs with a writer, and words the refusal from the registry.
func TestRemoveDeadHooksAcceptsOnlyWrittenCLIs(t *testing.T) {
	h := newHome(t)
	s := NewService(h.roots())
	for _, id := range []usage.CLI{clis.Gemini, "nope", ""} {
		_, err := s.RemoveDeadHooks(context.Background(), CLIParams{CLI: id})
		e, ok := coreerr.As(err)
		if !ok || e.Message != "cli must be claude or codex." {
			t.Errorf("%q: err = %v", id, err)
		}
	}
	for _, id := range clis.IDsWith(clis.Mutate) {
		_, err := s.RemoveDeadHooks(context.Background(), CLIParams{CLI: id})
		if e, ok := coreerr.As(err); !ok || strings.HasPrefix(e.Message, "cli must be") {
			t.Errorf("%s was refused as a CLI: %v", id, err)
		}
	}
}
