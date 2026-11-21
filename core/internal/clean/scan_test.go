package clean

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"spacevibe.dev/core/internal/activity"
	"spacevibe.dev/core/internal/fsx"
)

func allocated(t *testing.T, path string) int64 {
	t.Helper()
	u, err := fsx.DiskUsage(path)
	if err != nil {
		t.Fatal(err)
	}
	return u.Bytes
}

// CL-R2, RD-R17: logs by age with counts and allocated bytes, only buckets with files; memory folders and SQLite files
// never count; a CLI with only fresh logs offers no bucket.
func TestScanLogBuckets(t *testing.T) {
	h := newHome(t)
	a := h.write(".claude/projects/p/a.jsonl", claudeLog("x"), 10)
	b := h.write(".claude/projects/p/b.jsonl", strings.Repeat("y", 9000), 40)
	c := h.write(".claude/projects/p/c/subagents/agent-1.jsonl", claudeLog("x"), 100)
	d := h.write(".claude/projects/q/d.jsonl", claudeLog("x"), 200)
	h.write(".claude/projects/p/memory/notes.jsonl", "{}\n", 400)
	h.write(".claude/projects/p/memory/MEMORY.md", "x", 400)
	h.write(".codex/sessions/2026/01/01/rollout-1.jsonl", "{}\n", 5)
	h.write(".codex/state_5.sqlite", "db", 400)
	_ = a

	res := h.scan()
	claude := res.cli("claude")
	if claude.Logs.State != LogsMeasured {
		t.Fatalf("state %q", claude.Logs.State)
	}
	want := map[int][]string{30: {b, c, d}, 90: {c, d}, 180: {d}}
	for days, files := range want {
		var bytes int64
		for _, f := range files {
			bytes += allocated(t, f)
		}
		if got := claude.bucket(days); got.Files != len(files) || got.Bytes != bytes {
			t.Errorf("older than %d: %+v, want %d files %d bytes", days, got, len(files), bytes)
		}
	}
	if len(claude.Logs.Buckets) != 3 {
		t.Errorf("buckets %+v", claude.Logs.Buckets)
	}
	codex := res.cli("codex")
	if codex.Logs.State != LogsMeasured || len(codex.Logs.Buckets) != 0 {
		t.Errorf("codex logs %+v: an empty bucket is never offered", codex.Logs)
	}
	if len(res.CLIs) != 2 || res.CLIs[0].CLI != "claude" || res.CLIs[1].CLI != "codex" {
		t.Errorf("clis %+v", res.CLIs)
	}
}

func TestScanLogStates(t *testing.T) {
	h := newHome(t)
	if err := os.MkdirAll(h.path(".codex/sessions"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(h.path(".codex/sessions"), 0o000); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(h.path(".codex/sessions"), 0o755) })
	res := h.scan()
	if got := res.cli("claude").Logs.State; got != LogsMissing {
		t.Errorf("claude %q, want missing", got)
	}
	if got := res.cli("codex").Logs.State; got != LogsUnreadable {
		t.Errorf("codex %q, want unreadable", got)
	}
}

// CL-R4: only allowlisted folders, only non-empty ones, sized from the entries a move takes.
func TestScanCaches(t *testing.T) {
	h := newHome(t)
	s1 := h.write(".claude/shell-snapshots/snapshot-zsh-1.sh", strings.Repeat("s", 5000), 1)
	s2 := h.write(".claude/shell-snapshots/snapshot-zsh-2.sh", "s", 1)
	h.write(".claude/cache/changelog.md", "c", 1)
	h.write(".claude/file-history/x/1", "keep", 1) // not a cache: checkpoint restore (docs)
	h.write(".claude/paste-cache/p", "keep", 1)    // not a cache: recalled prompts (docs)
	h.write(".codex/packages/standalone/releases/1/codex", "bin", 1)
	if err := os.MkdirAll(h.path(".claude/debug"), 0o755); err != nil {
		t.Fatal(err)
	}
	res := h.scan()
	ids := map[string]CacheScan{}
	for _, c := range append(res.cli("claude").Caches, res.cli("codex").Caches...) {
		ids[c.ID] = c
	}
	if len(ids) != 2 {
		t.Fatalf("caches %+v", ids)
	}
	snaps := ids["claude:shell-snapshots"]
	if snaps.Entries != 2 || snaps.Files != 2 || snaps.Bytes != allocated(t, s1)+allocated(t, s2) || snaps.Path != h.path(".claude/shell-snapshots") {
		t.Errorf("shell-snapshots %+v", snaps)
	}
	if _, ok := ids["claude:cache"]; !ok {
		t.Error("claude:cache missing")
	}
}

// CL-R7: a cache folder reached through a link, a logs tree with a linked folder, are not offered.
func TestScanFollowsNoLink(t *testing.T) {
	h := newHome(t)
	outside := h.write("elsewhere/old.jsonl", claudeLog("x"), 300)
	h.write("elsewhere/cache/big", strings.Repeat("b", 9000), 300)
	if err := os.MkdirAll(h.path(".claude/projects"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Dir(outside), h.path(".claude/projects/linked")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(h.path("elsewhere/cache"), h.path(".claude/cache")); err != nil {
		t.Fatal(err)
	}
	res := h.scan()
	if b := res.cli("claude").Logs.Buckets; len(b) != 0 {
		t.Errorf("a log behind a link is offered: %+v", b)
	}
	if c := res.cli("claude").Caches; len(c) != 0 {
		t.Errorf("a linked cache folder is offered: %+v", c)
	}
}

// RD27 and RD35, from the activity report; the lock fails closed.
func TestScanLocks(t *testing.T) {
	h := newHome(t)
	unknown := activity.ReasonCodexProcessUnknown
	h.report = activity.Report{Sessions: []activity.Session{
		{CLI: activity.CLIClaude, ID: "c-run", State: activity.StateRunning},
		{CLI: activity.CLIClaude, ID: "c-wait", State: activity.StateWaiting},
		{CLI: activity.CLIClaude, ID: "c-idle", State: activity.StateIdle},
		{CLI: activity.CLIClaude, ID: "c-ended", State: activity.StateEnded},
		{CLI: activity.CLICodex, ID: "x-unm", State: activity.StateUnmeasurable},
	}}
	res := h.scan()
	claude, codex := res.cli("claude").Locks, res.cli("codex").Locks
	if claude.Logs == nil || claude.Logs.Reason != LockSessions || strings.Join(claude.Logs.Sessions, ",") != "c-run,c-wait" ||
		claude.Logs.Message != "Claude Code has 2 running sessions, so its logs stay until they end." {
		t.Errorf("claude logs lock %+v", claude.Logs)
	}
	if claude.Caches == nil || strings.Join(claude.Caches.Sessions, ",") != "c-run,c-wait,c-idle" {
		t.Errorf("claude caches lock %+v", claude.Caches)
	}
	if codex.Logs != nil {
		t.Errorf("an unmeasurable session locks Codex logs: %+v (RD35 locks caches only)", codex.Logs)
	}
	if codex.Caches == nil || codex.Caches.Message != "Codex has 1 open session, so its caches are in use." {
		t.Errorf("codex caches lock %+v", codex.Caches)
	}

	h.report = activity.Report{Sessions: []activity.Session{{CLI: activity.CLICodex, ID: "x", State: activity.StateUnmeasurable, ReasonCode: &unknown}}}
	if l := h.scan().cli("codex").Locks; l.Logs == nil || l.Logs.Reason != LockProcessUnknown || l.Caches == nil {
		t.Errorf("a failed lsof must lock Codex: %+v", l)
	}
	h.report = activity.Report{Unmeasurable: []activity.Limit{{CLI: activity.CLICodex, Code: unknown}}}
	if l := h.scan().cli("codex").Locks; l.Logs == nil || l.Caches == nil {
		t.Errorf("a failed ps must lock Codex: %+v", l)
	}
	h.report, h.readErr = activity.Report{}, errors.New("read failed")
	for _, c := range h.scan().CLIs {
		if c.Locks.Logs == nil || c.Locks.Caches == nil {
			t.Errorf("%s: a failed activity read must lock: %+v", c.CLI, c.Locks)
		}
	}
	h.readErr = nil
	h.svc.measurable = false
	if l := h.scan().cli("claude").Locks; l.Logs == nil || l.Logs.Reason != LockProcessUnknown {
		t.Errorf("no process adapter must lock: %+v", l)
	}
	h.svc.measurable = true
	if err := os.MkdirAll(h.path(".claude"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(h.path(".claude/sessions"), 0o000); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(h.path(".claude/sessions"), 0o755) })
	if l := h.scan().cli("claude").Locks; l.Logs == nil || l.Caches == nil {
		t.Errorf("an unreadable Claude sessions folder must lock: %+v", l)
	}
}

// CL-R6 and CL-R1: the size of a row is its removable members' allocated bytes, a link counts nothing, a plugin-only
// row has no size (it is never selectable).
func TestScanItemSizes(t *testing.T) {
	h := newHome(t)
	h.write(".claude/skills/tdd/SKILL.md", "---\nname: tdd\ndescription: d\n---\n"+strings.Repeat("t", 6000), 1)
	h.write(".claude/skills/tdd/ref.md", "r", 1)
	h.write(".claude/agents/rev.md", "---\nname: rev\ndescription: d\n---\nbody", 1)
	h.write("dot/linked/SKILL.md", "---\nname: linked\ndescription: d\n---\n", 1)
	if err := os.Symlink(h.path("dot/linked"), h.path(".claude/skills/linked")); err != nil {
		t.Fatal(err)
	}
	res := h.scan()
	sizes := map[string]int64{}
	for _, it := range res.Items {
		sizes[it.Key] = it.Bytes
	}
	if got, want := sizes["skill::tdd"], allocated(t, h.path(".claude/skills/tdd")); got != want {
		t.Errorf("tdd %d, want %d", got, want)
	}
	if got, want := sizes["agent::rev"], allocated(t, h.path(".claude/agents/rev.md")); got != want {
		t.Errorf("rev %d, want %d", got, want)
	}
	if got, ok := sizes["skill::linked"]; !ok || got != 0 {
		t.Errorf("a linked skill frees nothing: %d %v", got, ok)
	}
}

func TestScanStopsOnCancel(t *testing.T) {
	h := newHome(t)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := h.svc.Scan(ctx); !errors.Is(err, context.Canceled) {
		t.Fatalf("err %v", err)
	}
}
