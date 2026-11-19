package methods

import (
	"context"
	"path/filepath"
	"testing"

	"spacevibe.dev/core/internal/clis"
	"spacevibe.dev/core/internal/config"
	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/proc"
	"spacevibe.dev/core/internal/roots"
)

// activity.stop accepts exactly the CLIs with the activity concept and words the refusal from the registry; Gemini
// CLI, which the registry knows, is refused like an unknown id.
func TestActivityStopAcceptsOnlyActivityCLIs(t *testing.T) {
	dir := t.TempDir()
	cfg := config.Config{Test: true, UserHome: dir, Home: filepath.Join(dir, ".spacevibe")}
	r, err := roots.Resolve(cfg, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	s := New(cfg, r, proc.NewFixture(nil, nil, nil, 0), nil)
	defer s.Close()
	for _, id := range []clis.ID{clis.Gemini, "nope", ""} {
		_, err := s.activityStop(context.Background(), StopParams{CLI: id, ID: "s1"})
		if e, ok := coreerr.As(err); !ok || e.Message != "cli must be claude or codex." {
			t.Errorf("%q: err = %v", id, err)
		}
	}
	for _, id := range clis.IDsWith(clis.Activity) {
		_, err := s.activityStop(context.Background(), StopParams{CLI: id, ID: "s1"})
		if e, ok := coreerr.As(err); ok && e.Message == "cli must be claude or codex." {
			t.Errorf("%s was refused as a CLI", id)
		}
	}
}
