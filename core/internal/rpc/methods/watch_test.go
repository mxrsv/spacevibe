package methods

import (
	"context"
	"path/filepath"
	"testing"
	"time"

	"spacevibe.dev/core/internal/activity"
	"spacevibe.dev/core/internal/config"
	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/proc"
	"spacevibe.dev/core/internal/roots"
)

// After Close no watcher starts, and the refusal is a fixed error: the handler must never return (nil, nil), which
// the server would answer as a successful null result (finding 6).
func TestSubscribeAfterCloseIsRefused(t *testing.T) {
	dir := t.TempDir()
	cfg := config.Config{Test: true, UserHome: dir, ClaudeConfigDir: filepath.Join(dir, ".claude"),
		CodexHome: filepath.Join(dir, ".codex"), Home: filepath.Join(dir, ".spacevibe")}
	r, err := roots.Resolve(cfg, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	s := New(cfg, r, proc.NewFixture(nil, nil, nil, 0), nil)
	s.Close()
	res, err := s.Run(context.Background(), "activity.subscribe", []byte("{}"))
	if res != nil {
		t.Errorf("result = %v", res)
	}
	got, ok := coreerr.As(err)
	if !ok || got != errClosed {
		t.Fatalf("err = %v, want the fixed closed error", err)
	}
}

// The subscribe interval is optional, defaults to the 3 s poll and is bounded: a caller cannot ask for a busy loop or an
// interval so long the page looks frozen.
func TestSubscribeIntervalBounds(t *testing.T) {
	ms := func(v int) subscribeParams { return subscribeParams{IntervalMs: &v} }
	if d, err := (subscribeParams{}).interval(); err != nil || d != activity.WatchInterval {
		t.Fatalf("default = %v, %v; want %v", d, err, activity.WatchInterval)
	}
	if d, err := ms(20_000).interval(); err != nil || d != 20*time.Second {
		t.Fatalf("20000 = %v, %v", d, err)
	}
	for _, v := range []int{0, 999, 60_001, -1} {
		if _, err := ms(v).interval(); err == nil {
			t.Errorf("intervalMs %d was accepted", v)
		}
	}
	for _, v := range []int{1000, 60_000} {
		if _, err := ms(v).interval(); err != nil {
			t.Errorf("intervalMs %d refused: %v", v, err)
		}
	}
}
