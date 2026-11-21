package clean

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"spacevibe.dev/core/internal/activity"
	"spacevibe.dev/core/internal/config"
	"spacevibe.dev/core/internal/fsx"
	"spacevibe.dev/core/internal/goldentest"
	"spacevibe.dev/core/internal/roots"
	"spacevibe.dev/core/internal/usage"
)

// TestMain arms the real-home write guard for the package: every test writes under t.TempDir() only, and the Trash is
// the <data>/test-trash stand-in (roots.Resolve under SPACEVIBE_TEST=1).
func TestMain(m *testing.M) {
	fsx.InstallWriteGuard(config.Config{Test: true})
	os.Exit(m.Run())
}

// testNow is the clock of the synthetic homes.
var testNow = time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)

type home struct {
	t    *testing.T
	root string
	r    roots.Roots
	// report is what the fake Activity read answers; readErr makes it fail.
	report  activity.Report
	readErr error
	// procs and procErr are what the fake process list answers (RD35 cache locks).
	procs   map[string][]int
	procErr error
	svc     *Service
	scanner *usage.Scanner
}

func newHomeAt(t *testing.T, root string) *home {
	t.Helper()
	cfg := config.Config{Test: true, UserHome: root, ClaudeConfigDir: root + "/.claude", CodexHome: root + "/.codex", Home: root + "/.spacevibe"}
	r, err := roots.Resolve(cfg, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	h := &home{t: t, root: root, r: r, report: activity.Report{}}
	h.scanner = usage.NewScanner(r)
	h.svc = NewService(r, h.scanner, func(context.Context) (activity.Report, error) { return h.report, h.readErr },
		func(context.Context) (map[string][]int, error) { return h.procs, h.procErr }, true)
	h.svc.Now = func() time.Time { return testNow }
	return h
}

// newHome is an empty throwaway home; its path has links resolved (macOS /var is a link).
func newHome(t *testing.T) *home {
	t.Helper()
	root, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	return newHomeAt(t, root)
}

// fixtureHome is a private copy of the frozen fixture home (never the shared tree, B6), clocked 120 days after the
// fixture's now, so every fixture log is older than 90 days.
func fixtureHome(t *testing.T) *home {
	t.Helper()
	parent, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	dest := filepath.Join(parent, "home")
	if err := goldentest.MaterializeInto(dest); err != nil {
		t.Fatal(err)
	}
	h := newHomeAt(t, dest)
	now, err := goldentest.Now()
	if err != nil {
		t.Fatal(err)
	}
	h.svc.Now = func() time.Time { return now.Add(120 * day) }
	return h
}

func (h *home) path(rel string) string { return filepath.Join(h.root, rel) }

// write makes a file with its folders and sets its modification time to ageDays before testNow.
func (h *home) write(rel, content string, ageDays int) string {
	h.t.Helper()
	p := h.path(rel)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		h.t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(content), 0o644); err != nil {
		h.t.Fatal(err)
	}
	at := testNow.Add(-time.Duration(ageDays) * day)
	if err := os.Chtimes(p, at, at); err != nil {
		h.t.Fatal(err)
	}
	return p
}

func (h *home) exists(rel string) bool {
	_, err := os.Lstat(h.path(rel))
	return err == nil
}

func (h *home) scan() ScanResult {
	h.t.Helper()
	res, err := h.svc.Scan(context.Background())
	if err != nil {
		h.t.Fatal(err)
	}
	return res
}

func (h *home) move(p MoveParams) MoveResult {
	h.t.Helper()
	res, err := h.svc.Move(context.Background(), p, nil)
	if err != nil {
		h.t.Fatal(err)
	}
	return res
}

func (s ScanResult) cli(id string) CLIScan {
	for _, c := range s.CLIs {
		if c.CLI == id {
			return c
		}
	}
	return CLIScan{}
}

func (c CLIScan) bucket(days int) LogBucket {
	for _, b := range c.Logs.Buckets {
		if b.OlderThanDays == days {
			return b
		}
	}
	return LogBucket{}
}

// trashItems lists what the stand-in Trash holds (a test may list it; the core never lists the real one).
func (h *home) trashItems() []string {
	h.t.Helper()
	entries, err := os.ReadDir(h.r.Trash)
	if err != nil {
		return nil
	}
	var out []string
	for _, e := range entries {
		out = append(out, e.Name())
	}
	return out
}

// claudeLog is a Claude transcript line that uses a skill, so the usage scan counts it.
func claudeLog(skill string) string {
	return `{"type":"assistant","timestamp":"2026-01-02T10:00:00.000Z","message":{"model":"claude-opus-4-1","id":"m1","usage":{"input_tokens":10,"output_tokens":5},"content":[{"type":"tool_use","name":"Skill","input":{"skill":"` + skill + `"}}]}}` + "\n"
}
