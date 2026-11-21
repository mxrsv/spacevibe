package clean

import (
	"bytes"
	"context"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strconv"
	"strings"
	"testing"

	"github.com/klauspost/compress/zstd"

	"spacevibe.dev/core/internal/activity"
	"spacevibe.dev/core/internal/mutate"
	"spacevibe.dev/core/internal/usage"
)

// Regression tests for the RB-E7 build-review findings (H1, M1 to M4, L1 to L5).

func zstdBytes(t *testing.T, payload string) []byte {
	t.Helper()
	var buf bytes.Buffer
	enc, err := zstd.NewWriter(&buf, zstd.WithEncoderConcurrency(1))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := enc.Write([]byte(payload)); err != nil {
		t.Fatal(err)
	}
	if err := enc.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func codexLog(skill string) string {
	return `{"timestamp":"2026-01-02T10:00:00.000Z","type":"response_item","payload":{"type":"function_call","name":"shell","arguments":"{\"command\":[\"cat\",\"/x/skills/` + skill + `/SKILL.md\"]}"}}` + "\n"
}

func (h *home) usage() usage.Result {
	h.t.Helper()
	res, err := h.scanner.Scan(context.Background(), nil)
	if err != nil {
		h.t.Fatal(err)
	}
	res.Problems = nil
	return comparable(res)
}

// H1: two cores move the same logs at once. The second finds the files gone; its cleanup must not drop the records the
// first one archived for them.
func TestOverlappingMovesKeepTheFirstMovesRecords(t *testing.T) {
	h := newHome(t)
	for i := 0; i < 3; i++ {
		h.write(".claude/projects/p/s"+strconv.Itoa(i)+".jsonl", claudeLog("tdd"), 100)
	}
	before := h.usage()
	other := newHomeAt(t, h.root) // a second core on the same folders
	other.svc.Now = h.svc.Now
	pick := MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}}
	var second MoveResult
	var secondErr error
	_, err := h.svc.Move(context.Background(), pick, func(p ProgressParams) {
		if p.Phase == "reading" && p.Done == p.Total && second.Entry == nil && secondErr == nil {
			// The first move has read the logs and not yet taken the lock: the second runs whole now.
			second, secondErr = other.svc.Move(context.Background(), pick, nil)
		}
	})
	if secondErr != nil || second.Moved.Files != 3 {
		t.Fatalf("second move %+v %v", second, secondErr)
	}
	if statusOf(err) != 404 && statusOf(err) != 409 {
		t.Fatalf("the first move should find nothing left: %v", err)
	}
	if got := h.usage(); !reflect.DeepEqual(before, got) {
		t.Fatalf("usage lost by the overlap:\nbefore %+v\nafter  %+v", before.Totals.Claude.Skill, got.Totals.Claude.Skill)
	}
}

// H1: the same pick sent twice to one core while the first runs is refused with 409.
func TestSecondMoveWhileOneRunsIsRefused(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/a.jsonl", claudeLog("x"), 100)
	pick := MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}}
	var secondErr error
	res, err := h.svc.Move(context.Background(), pick, func(p ProgressParams) {
		if p.Phase == "reading" {
			_, secondErr = h.svc.Move(context.Background(), pick, nil)
		}
	})
	if err != nil || res.Moved.Files != 1 {
		t.Fatalf("first move %+v %v", res, err)
	}
	if statusOf(secondErr) != 409 || !strings.Contains(secondErr.Error(), "already running") {
		t.Fatalf("second move: %v", secondErr)
	}
}

// M3: a Codex rollout and its .zst twin move together, so the twin never shows up as a log of its own and no count
// changes; Undo brings both back.
func TestRolloutMovesWithItsCompressedTwin(t *testing.T) {
	h := newHome(t)
	plain := h.write(".codex/sessions/2026/01/02/rollout-2026-01-02T10-00-00-u1.jsonl", codexLog("tdd"), 100)
	twin := plain + ".zst"
	if err := os.WriteFile(twin, zstdBytes(t, codexLog("tdd")), 0o644); err != nil {
		t.Fatal(err)
	}
	at := testNow.Add(-100 * day)
	_ = os.Chtimes(twin, at, at)
	before := h.usage()
	scan := h.scan().cli("codex").bucket(90)
	res := h.move(MoveParams{Logs: []LogPick{{CLI: "codex", OlderThanDays: 90}}})
	if _, err := os.Lstat(twin); err == nil {
		t.Fatal("the compressed twin stayed behind")
	}
	if res.Moved.Files != 2 || scan.Files != 2 || scan.Bytes != res.Moved.Bytes {
		t.Fatalf("moved %+v, scan said %+v", res.Moved, scan)
	}
	if got := h.usage(); !reflect.DeepEqual(before, got) {
		t.Fatalf("counts changed: %+v vs %+v", before.Windows, got.Windows)
	}
	if err := h.undo(res.Entry.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Lstat(twin); err != nil {
		t.Fatal("Undo did not bring the twin back")
	}
}

// L3: a cache entry with a SQLite file or a memory folder anywhere below it is never offered nor moved.
func TestCacheEntryHoldingASQLiteFileStays(t *testing.T) {
	h := newHome(t)
	h.write(".codex/cache/plugins/catalog.json", "{}", 1)
	h.write(".codex/cache/db/inner/state.sqlite", "db", 1)
	h.write(".claude/cache/notes/memory/m.md", "m", 1)
	res := h.scan()
	for _, c := range append(res.cli("claude").Caches, res.cli("codex").Caches...) {
		if c.ID == "codex:cache" && c.Entries != 1 {
			t.Errorf("codex cache offers %d entries, want only plugins", c.Entries)
		}
		if c.ID == "claude:cache" {
			t.Errorf("claude cache offers an entry holding a memory folder: %+v", c)
		}
	}
	h.move(MoveParams{Caches: []string{"codex:cache"}})
	if !h.exists(".codex/cache/db/inner/state.sqlite") || h.exists(".codex/cache/plugins/catalog.json") {
		t.Fatal("the wrong cache entries moved")
	}
}

// L4: the logs of a live Activity row, an idle one included, are never picked.
func TestLiveRowLogsAreNeverPicked(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/s-idle.jsonl", claudeLog("x"), 100)
	h.write(".claude/projects/p/s-idle/subagents/agent-1.jsonl", claudeLog("x"), 100)
	h.write(".claude/projects/p/s-old.jsonl", claudeLog("x"), 100)
	h.write(".codex/sessions/2026/01/02/rollout-2026-01-02T10-00-00-a0000000-0000-4000-8000-000000000009.jsonl", codexLog("x"), 100)
	h.report = activity.Report{Sessions: []activity.Session{
		{CLI: activity.CLIClaude, ID: "s-idle", State: activity.StateIdle},
		{CLI: activity.CLICodex, ID: "a0000000-0000-4000-8000-000000000009", State: activity.StateIdle},
	}}
	h.svc.processes = func(context.Context) (map[string][]int, error) { return nil, nil }
	if b := h.scan().cli("claude").bucket(90); b.Files != 1 {
		t.Errorf("claude offers %d logs, want only s-old", b.Files)
	}
	res := h.move(MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}})
	if res.Moved.Files != 1 || !h.exists(".claude/projects/p/s-idle.jsonl") || !h.exists(".claude/projects/p/s-idle/subagents/agent-1.jsonl") {
		t.Fatalf("a live row's log moved: %+v", res.Moved)
	}
	if _, err := h.svc.Move(context.Background(), MoveParams{Logs: []LogPick{{CLI: "codex", OlderThanDays: 90}}}, nil); statusOf(err) != 409 {
		t.Fatalf("the live Codex rollout was offered: %v", err)
	}
}

// M4: a Clean entry keeps the journal small, however many files it moved.
func TestJournalStaysSmallForManyFiles(t *testing.T) {
	h := newHome(t)
	for i := 0; i < 3000; i++ {
		h.write(".claude/shell-snapshots/snapshot-zsh-"+strconv.Itoa(i)+"-with-a-long-name-to-weigh.sh", "s", 1)
	}
	res := h.move(MoveParams{Caches: []string{"claude:shell-snapshots"}})
	info, err := os.Stat(filepath.Join(h.r.Data, "journal.json"))
	if err != nil {
		t.Fatal(err)
	}
	if info.Size() > 4096 {
		t.Fatalf("journal.json is %d bytes for one Clean entry", info.Size())
	}
	if err := h.undo(res.Entry.ID); err != nil {
		t.Fatal(err)
	}
	if !h.exists(".claude/shell-snapshots/snapshot-zsh-2999-with-a-long-name-to-weigh.sh") {
		t.Fatal("Undo lost a file")
	}
}

// L1: an archived log whose path holds an unreadable file again still counts from the archive.
func TestArchiveCountsWhenTheLiveFileCannotBeRead(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/a.jsonl", claudeLog("tdd"), 100)
	before := h.usage()
	h.move(MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}})
	p := h.write(".claude/projects/p/a.jsonl", "unreadable", 1)
	if err := os.Chmod(p, 0o000); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(p, 0o644) })
	if got := h.usage(); !reflect.DeepEqual(before.Totals, got.Totals) {
		t.Fatalf("the archived counts were dropped for an unreadable file: %+v", got.Totals.Claude.Skill)
	}
}

// L2: an archive that cannot be read is said on the usage.scan result, and Clean writes keep refusing.
func TestUnreadableArchiveIsReported(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/a.jsonl", claudeLog("tdd"), 100)
	h.write(".claude/projects/p/b.jsonl", claudeLog("tdd"), 100)
	if err := os.MkdirAll(h.r.Data, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(usage.ArchivePath(h.r.Data), []byte("{"), 0o600); err != nil {
		t.Fatal(err)
	}
	res, err := h.scanner.Scan(context.Background(), nil)
	if err != nil {
		t.Fatal(err)
	}
	if len(res.Problems) != 1 || !strings.Contains(res.Problems[0], "usage-archive.json") {
		t.Fatalf("problems %v", res.Problems)
	}
	if _, err := h.svc.Move(context.Background(), MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}}, nil); statusOf(err) != 409 {
		t.Fatalf("a Clean write went ahead over an unreadable archive: %v", err)
	}
}

// M1: a core that dies part way through a move leaves files in <data>/clean; the next write puts them back first.
func TestCrashedMoveIsPutBackBeforeTheNextWrite(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/a.jsonl", claudeLog("tdd"), 100)
	h.write(".claude/projects/p/b.jsonl", claudeLog("tdd"), 100)
	before := h.tree()
	usageBefore := h.usage()
	done := make(chan struct{})
	go func() {
		defer close(done)
		_, _ = h.svc.Move(context.Background(), MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}}, func(p ProgressParams) {
			if p.Phase == "moving" && p.Done == p.Total { // every file staged, nothing in the Trash, no journal
				crashHere()
			}
		})
	}()
	<-done
	if h.exists(".claude/projects/p/a.jsonl") && h.exists(".claude/projects/p/b.jsonl") {
		t.Fatal("the simulated crash moved nothing; the test proves nothing")
	}
	if _, err := mutate.Record(h.r, "any later write", nil); err != nil {
		t.Fatal(err)
	}
	sameFiles(t, before, h.tree())
	if got := h.usage(); !reflect.DeepEqual(usageBefore, got) {
		t.Fatalf("usage after recovery: %+v", got.Totals.Claude.Skill)
	}
	if paths, _ := usage.ArchivedPaths(h.r.Data); len(paths) != 0 {
		t.Errorf("recovery left archive records %v", paths)
	}
}

// M2 (RD35): a CLI's caches lock while any process of it is alive, one with no Activity row included; an unknown
// process list locks them; its logs keep the RD27 rule.
func TestCacheLockCountsEveryProcess(t *testing.T) {
	h := newHome(t)
	h.write(".codex/cache/c", "c", 1)
	h.write(".codex/sessions/2026/01/02/rollout-a.jsonl", codexLog("x"), 100)
	h.write(".claude/cache/c", "c", 1)
	h.procs = map[string][]int{"codex": {53001}, "claude": {42001}} // a Codex app-server, a Claude with no status file
	res := h.scan()
	for _, cli := range []string{"claude", "codex"} {
		l := res.cli(cli).Locks
		if l.Caches == nil || l.Caches.Reason != LockProcesses || l.Logs != nil {
			t.Errorf("%s locks %+v %+v", cli, l.Caches, l.Logs)
		}
	}
	if got := res.cli("codex").Locks.Caches.Message; got != "Codex is running (1 process), so its caches are in use." {
		t.Errorf("message %q", got)
	}
	out := h.move(MoveParams{Logs: []LogPick{{CLI: "codex", OlderThanDays: 90}}, Caches: []string{"codex:cache"}})
	if out.Moved.Files != 1 || !h.exists(".codex/cache/c") {
		t.Fatalf("the cache moved under a live process: %+v", out)
	}
	h.procs, h.procErr = nil, errors.New("ps failed")
	if l := h.scan().cli("claude").Locks; l.Caches == nil || l.Caches.Reason != LockProcessUnknown || l.Logs != nil {
		t.Errorf("an unknown process list must lock the caches only: %+v %+v", l.Caches, l.Logs)
	}
	h.procErr = nil
	h.svc.processes = nil
	if l := h.scan().cli("codex").Locks; l.Caches == nil || l.Caches.Reason != LockProcessUnknown {
		t.Errorf("no process lister must lock the caches: %+v", l.Caches)
	}
}
