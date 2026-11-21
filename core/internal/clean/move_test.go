package clean

import (
	"bytes"
	"context"
	"errors"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"runtime"
	"strconv"
	"strings"
	"testing"

	"spacevibe.dev/core/internal/activity"
	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/mutate"
	"spacevibe.dev/core/internal/usage"
)

func statusOf(err error) int {
	if e, ok := coreerr.As(err); ok {
		return e.Status
	}
	return 0
}

func (h *home) undo(id string) error {
	_, err := mutate.Undo(h.r, id)
	return err
}

// tree is every path under the home outside the data folder, with its bytes, link text and mode.
func (h *home) tree() map[string]string {
	h.t.Helper()
	out := map[string]string{}
	err := filepath.WalkDir(h.root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(h.root, p)
		if d.IsDir() && (rel == ".spacevibe" || rel == ".reins") {
			return filepath.SkipDir
		}
		info, err := os.Lstat(p)
		if err != nil {
			return err
		}
		switch {
		case info.Mode()&fs.ModeSymlink != 0:
			target, _ := os.Readlink(p)
			out[rel] = "link:" + target
		case info.IsDir():
			out[rel] = "dir"
		default:
			data, _ := os.ReadFile(p)
			out[rel] = info.Mode().Perm().String() + timeMark + info.ModTime().String() + timeMark + string(data)
		}
		return nil
	})
	if err != nil {
		h.t.Fatal(err)
	}
	return out
}

// timeMark brackets the modification time in a tree entry, so withoutTimes can drop it.
const timeMark = "\x00"

// withoutTimes keeps mode and bytes: an edited config file comes back byte for byte under a new mtime.
func withoutTimes(tree map[string]string) map[string]string {
	out := make(map[string]string, len(tree))
	for k, v := range tree {
		if parts := strings.SplitN(v, timeMark, 3); len(parts) == 3 {
			v = parts[0] + " " + parts[2]
		}
		out[k] = v
	}
	return out
}

// sameFiles compares two trees by files and links only: Undo may leave a folder the move emptied, never a file.
func sameFiles(t *testing.T, before, after map[string]string) {
	t.Helper()
	for k, v := range before {
		if v != "dir" && after[k] != v {
			t.Errorf("%s differs after Undo", k)
		}
	}
	for k, v := range after {
		if _, ok := before[k]; !ok && v != "dir" {
			t.Errorf("%s appeared", k)
		}
	}
}

// CL-R2, CL-R5: logs older than 90 days go to the Trash; every memory folder and SQLite file stays; Undo brings the
// files back byte for byte with their times.
func TestMoveLogsKeepsMemoryAndSQLite(t *testing.T) {
	t.Parallel()
	h := fixtureHome(t)
	keep := []string{
		h.write(".claude/projects/-work-spacevibe-api/memory/MEMORY.md", "notes", 400),
		h.write(".claude/projects/-work-spacevibe-api/memory/old.jsonl", "{}\n", 400),
		h.write(".codex/thread_history_1.sqlite", "db", 400),
		h.write(".codex/state_5.sqlite", "db", 400),
		h.write(".codex/logs_2.sqlite", "db", 400),
		h.write(".codex/sessions/2026/10/08/notes.sqlite", "db", 400),
	}
	for i := range keep {
		keep[i], _ = filepath.Rel(h.root, keep[i])
	}
	before := h.tree()
	scan := h.scan()
	claude, codex := scan.cli("claude").bucket(90), scan.cli("codex").bucket(90)
	if claude.Files == 0 || codex.Files == 0 {
		t.Fatalf("fixture has no old logs: %+v %+v", claude, codex)
	}
	res := h.move(MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}, {CLI: "codex", OlderThanDays: 90}}})
	if res.Entry == nil || res.Moved.Files != claude.Files+codex.Files || res.Moved.Bytes != claude.Bytes+codex.Bytes || res.Cancelled {
		t.Fatalf("result %+v, scan said %+v %+v", res, claude, codex)
	}
	for _, rel := range keep {
		if !h.exists(rel) {
			t.Errorf("%s left its folder", rel)
		}
	}
	if left := h.scan(); len(left.cli("claude").Logs.Buckets)+len(left.cli("codex").Logs.Buckets) != 0 {
		t.Errorf("logs left after the move: %+v", left.CLIs)
	}
	items := h.trashItems()
	if len(items) != 1 || !strings.HasPrefix(items[0], "SpaceVibe Clean ") || res.Trash == nil || *res.Trash != filepath.Join(h.r.Trash, items[0]) {
		t.Fatalf("trash %v, result %v", items, res.Trash)
	}
	if _, err := os.Lstat(filepath.Join(*res.Trash, "claude/projects/-work-spacevibe-api/session-010.jsonl")); err != nil {
		t.Errorf("a moved log is not at <trash>/<cli>/<rel>: %v", err)
	}
	if res.Entry.Label != "Moved "+strconv.Itoa(res.Moved.Files)+" files to the Trash: Claude Code logs, Codex logs" {
		t.Errorf("label %q", res.Entry.Label)
	}
	if err := h.undo(res.Entry.ID); err != nil {
		t.Fatal(err)
	}
	sameFiles(t, before, h.tree())
	if items := h.trashItems(); len(items) != 0 {
		t.Errorf("the Trash still holds %v after Undo", items)
	}
	if _, err := os.Lstat(filepath.Join(h.r.Data, "clean")); err == nil {
		entries, _ := os.ReadDir(filepath.Join(h.r.Data, "clean"))
		for _, e := range entries {
			if e.IsDir() {
				t.Errorf("staging left behind: %v", e.Name())
			}
		}
		if len(entries) > 1 {
			t.Errorf("more than the entry's list left: %v", entries)
		}
	}
}

func comparable(r usage.Result) usage.Result {
	r.Files = 0 // counts unreadable logs too; an unreadable log has no record to keep (docs/internals/clean.md)
	return r
}

// CL-R3: the usage scan gives the same counts per item before the move, after it and after Undo, with no doubles.
func TestUsageSurvivesMoveAndUndo(t *testing.T) {
	t.Parallel()
	h := fixtureHome(t)
	ctx := context.Background()
	before, err := h.scanner.Scan(ctx, nil)
	if err != nil {
		t.Fatal(err)
	}
	res := h.move(MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 30}, {CLI: "codex", OlderThanDays: 30}}})
	after, err := h.scanner.Scan(ctx, nil)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(comparable(before), comparable(after)) {
		t.Fatalf("usage changed after the move:\nbefore %+v\nafter  %+v", before.Sessions, after.Sessions)
	}
	if after.Windows.Claude.Files == 0 || after.Totals.Claude.Skill == nil || len(after.Totals.Claude.Skill) == 0 {
		t.Fatal("the fixture counted nothing; the test proves nothing")
	}
	paths, err := usage.ArchivedPaths(h.r.Data)
	if err != nil || len(paths) == 0 {
		t.Fatalf("archive %v %v", paths, err)
	}
	raw, _ := os.ReadFile(usage.ArchivePath(h.r.Data))
	if bytes.Contains(raw, []byte(`"text"`)) || bytes.Contains(raw, []byte("content")) {
		t.Error("the archive holds log text (S-R3)")
	}
	if !bytes.Contains(raw, []byte(`"tokens":[{"model":`)) {
		t.Error("the archive holds no token counts per model")
	}
	if err := h.undo(res.Entry.ID); err != nil {
		t.Fatal(err)
	}
	undone, err := h.scanner.Scan(ctx, nil)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(comparable(before), comparable(undone)) {
		t.Fatalf("usage changed after Undo:\nbefore %+v\nundone %+v", before.Sessions, undone.Sessions)
	}
	if paths, _ := usage.ArchivedPaths(h.r.Data); len(paths) != 0 {
		t.Errorf("Undo left %d archived records", len(paths))
	}
}

// A live log at an archived path wins: an archive that still names a log that came back never doubles it.
func TestArchiveNeverDoubles(t *testing.T) {
	t.Parallel()
	h := fixtureHome(t)
	ctx := context.Background()
	before, _ := h.scanner.Scan(ctx, nil)
	res := h.move(MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}})
	paths, _ := usage.ArchivedPaths(h.r.Data)
	// Put the files back by hand, leaving the archive as it is.
	for _, p := range paths {
		rel, _ := filepath.Rel(h.r.Claude.Root, p)
		if err := os.Rename(filepath.Join(*res.Trash, "claude", rel), p); err != nil {
			t.Fatal(err)
		}
	}
	got, _ := h.scanner.Scan(ctx, nil)
	if !reflect.DeepEqual(comparable(before), comparable(got)) {
		t.Fatalf("a log both live and archived was counted twice: %+v vs %+v", before.Sessions, got.Sessions)
	}
}

// CL-R6: the bytes reported as freed equal the `du` difference of the CLI root, in allocated 512-byte blocks.
func TestFreedBytesEqualDuDifference(t *testing.T) {
	t.Parallel()
	if runtime.GOOS != "darwin" {
		t.Skip("BSD du")
	}
	h := fixtureHome(t)
	h.write(".claude/shell-snapshots/snapshot-zsh-1.sh", strings.Repeat("s", 70000), 1)
	h.write(".claude/shell-snapshots/sub/x", strings.Repeat("s", 9000), 1)
	du := func() int64 {
		cmd := exec.Command("du", "-s", h.r.Claude.Root)
		cmd.Env = append(os.Environ(), "BLOCKSIZE=512")
		out, err := cmd.Output()
		if err != nil {
			t.Fatal(err)
		}
		n, err := strconv.ParseInt(strings.Fields(string(out))[0], 10, 64)
		if err != nil {
			t.Fatal(err)
		}
		return n * 512
	}
	scan := h.scan()
	before := du()
	res := h.move(MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}, Caches: []string{"claude:shell-snapshots"}})
	freed := before - du()
	if res.Moved.Bytes != freed {
		t.Fatalf("reported %d bytes freed, du says %d", res.Moved.Bytes, freed)
	}
	var estimate int64 = scan.cli("claude").bucket(90).Bytes
	for _, c := range scan.cli("claude").Caches {
		if c.ID == "claude:shell-snapshots" {
			estimate += c.Bytes
		}
	}
	if estimate != res.Moved.Bytes {
		t.Errorf("scan estimated %d, the move freed %d", estimate, res.Moved.Bytes)
	}
	if !h.exists(".claude/shell-snapshots") {
		t.Error("the cache folder itself left; only its entries go")
	}
}

// CL-R5, RD27, RD35: a locked CLI is refused with the lock's reason and nothing changes; with something else open the
// rest moves and the locked row says why it stayed (the mock's "Moved 2 of 3").
func TestLocksRefuseWithReason(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/a.jsonl", claudeLog("x"), 100)
	h.write(".codex/sessions/2026/01/01/rollout-a.jsonl", "{}\n", 100)
	h.write(".codex/cache/c", "c", 1)
	h.report = activity.Report{Sessions: []activity.Session{{CLI: activity.CLIClaude, ID: "s1", State: activity.StateRunning}}}
	before := h.tree()
	_, err := h.svc.Move(context.Background(), MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}}, nil)
	if statusOf(err) != 409 || err.Error() != "Claude Code has 1 running session, so its logs stay until it ends. Nothing was moved." {
		t.Fatalf("err %v", err)
	}
	sameFiles(t, before, h.tree())
	if hist, _ := mutate.History(h.r); len(hist) != 0 {
		t.Fatalf("a refused move wrote %d journal entries", len(hist))
	}

	// An idle Codex session locks its caches only (RD35): Codex logs move, Codex cache stays, Claude logs stay.
	h.report.Sessions = append(h.report.Sessions, activity.Session{CLI: activity.CLICodex, ID: "x1", State: activity.StateIdle})
	res := h.move(MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}, {CLI: "codex", OlderThanDays: 90}}, Caches: []string{"codex:cache"}})
	if res.Moved.Files != 1 || len(res.Groups) != 3 {
		t.Fatalf("result %+v", res)
	}
	byID := map[string]GroupResult{}
	for _, g := range res.Groups {
		byID[g.ID] = g
	}
	if g := byID["logs:claude"]; g.Stayed != 1 || g.Reason == nil || !strings.Contains(*g.Reason, "running session") {
		t.Errorf("claude logs %+v", g)
	}
	if g := byID["codex:cache"]; g.Stayed != 1 || g.Reason == nil || *g.Reason != "Codex has 1 open session, so its caches are in use." {
		t.Errorf("codex cache %+v", g)
	}
	if g := byID["logs:codex"]; g.Moved.Files != 1 || g.Reason != nil {
		t.Errorf("codex logs %+v", g)
	}
	if !h.exists(".claude/projects/p/a.jsonl") || !h.exists(".codex/cache/c") || h.exists(".codex/sessions/2026/01/01/rollout-a.jsonl") {
		t.Error("the locks did not hold")
	}
}

func TestMoveRefusesBadParams(t *testing.T) {
	h := newHome(t)
	for _, p := range []MoveParams{
		{},
		{Logs: []LogPick{{CLI: "gemini", OlderThanDays: 90}}},
		{Logs: []LogPick{{CLI: "claude", OlderThanDays: 60}}},
		{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}, {CLI: "claude", OlderThanDays: 30}}},
		{Caches: []string{"claude:file-history"}},
		{Caches: []string{"claude:cache", "claude:cache"}},
	} {
		if _, err := h.svc.Move(context.Background(), p, nil); statusOf(err) != 400 {
			t.Errorf("%+v: %v", p, err)
		}
	}
	if _, err := h.svc.Move(context.Background(), MoveParams{Caches: []string{"claude:cache"}}, nil); statusOf(err) != 409 {
		t.Errorf("an empty selection: %v", err)
	}
}

// A cancel stops before the next file: what moved is one entry that Undo puts back; a cancel before any file changes
// nothing.
func TestCancelStopsBeforeNextFile(t *testing.T) {
	h := newHome(t)
	for i := 0; i < 5; i++ {
		h.write(".claude/projects/p/s"+strconv.Itoa(i)+".jsonl", claudeLog("x"), 100)
	}
	before := h.tree()
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := h.svc.Move(ctx, MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}}, nil); !errors.Is(err, context.Canceled) {
		t.Fatalf("err %v", err)
	}
	sameFiles(t, before, h.tree())

	ctx, cancel = context.WithCancel(context.Background())
	defer cancel()
	var phases []ProgressParams
	res, err := h.svc.Move(ctx, MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}}, func(p ProgressParams) {
		phases = append(phases, p)
	})
	if err != nil || res.Moved.Files != 5 {
		t.Fatalf("uncancelled move %+v %v", res, err)
	}
	if len(phases) != 2 || phases[0].Phase != "reading" || phases[1].Phase != "moving" || phases[1].Bytes != res.Moved.Bytes {
		t.Errorf("progress %+v", phases)
	}
	if err := h.undo(res.Entry.ID); err != nil {
		t.Fatal(err)
	}

	// Cancel from inside the move: the plan's first file goes, the rest stay.
	moved := 0
	r := h.r
	err = mutate.WithLockContext(context.Background(), r, func(tx *mutate.Tx) error {
		files := []mutate.TrashFile{}
		for i := 0; i < 5; i++ {
			files = append(files, mutate.TrashFile{Group: "logs:claude", CLI: "claude", Rel: "projects/p/s" + strconv.Itoa(i) + ".jsonl", Log: true})
		}
		out, err := mutate.MoveToSystemTrash(ctx, tx, mutate.TrashPlan{Files: files, Label: label}, func(mutate.TrashProgress) { cancel() })
		moved = out.Moved["logs:claude"].Files
		if !out.Cancelled || out.Stayed["logs:claude"] != 4 || out.Entry == nil {
			t.Errorf("outcome %+v", out)
		}
		return err
	})
	if err != nil || moved != 1 {
		t.Fatalf("moved %d, err %v", moved, err)
	}
	hist, _ := mutate.History(h.r)
	if err := h.undo(hist[0].ID); err != nil {
		t.Fatal(err)
	}
	sameFiles(t, before, h.tree())
}

// Partial failure: a file that cannot move stays with its reason, the rest move, Undo puts back what moved.
func TestPartialFailureReportsWhatStayed(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/ok/a.jsonl", claudeLog("x"), 100)
	h.write(".claude/projects/stuck/b.jsonl", claudeLog("x"), 100)
	if err := os.Chmod(h.path(".claude/projects/stuck"), 0o500); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(h.path(".claude/projects/stuck"), 0o755) })
	res := h.move(MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}})
	g := res.Groups[0]
	if g.Moved.Files != 1 || g.Stayed != 1 || g.Reason == nil || !strings.Contains(*g.Reason, "b.jsonl") {
		t.Fatalf("group %+v", g)
	}
	if !h.exists(".claude/projects/stuck/b.jsonl") || h.exists(".claude/projects/ok/a.jsonl") {
		t.Fatal("the wrong file moved")
	}
	if err := h.undo(res.Entry.ID); err != nil {
		t.Fatal(err)
	}
	if !h.exists(".claude/projects/ok/a.jsonl") {
		t.Fatal("Undo did not put the moved file back")
	}
}

// Undo is all or nothing: a file whose place is taken again, or a Trash folder that is gone, refuses with 409 and the
// entry stays undoable.
func TestUndoRefusals(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/a.jsonl", claudeLog("x"), 100)
	h.write(".claude/projects/p/b.jsonl", claudeLog("y"), 100)
	res := h.move(MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}})
	h.write(".claude/projects/p/b.jsonl", "new", 0)
	if err := h.undo(res.Entry.ID); statusOf(err) != 409 || !strings.Contains(err.Error(), "already exists again") {
		t.Fatalf("err %v", err)
	}
	if h.exists(".claude/projects/p/a.jsonl") || len(h.trashItems()) != 1 {
		t.Fatal("a refused Undo changed something")
	}
	if err := os.Remove(h.path(".claude/projects/p/b.jsonl")); err != nil {
		t.Fatal(err)
	}
	aside := h.path("aside")
	if err := os.Rename(*res.Trash, aside); err != nil {
		t.Fatal(err)
	}
	if err := h.undo(res.Entry.ID); statusOf(err) != 409 || !strings.Contains(err.Error(), "no longer in the Trash") {
		t.Fatalf("err %v", err)
	}
	if err := os.Rename(aside, *res.Trash); err != nil {
		t.Fatal(err)
	}
	if err := h.undo(res.Entry.ID); err != nil {
		t.Fatalf("the entry stopped being undoable: %v", err)
	}
	if err := h.undo(res.Entry.ID); statusOf(err) != 409 {
		t.Fatalf("a second Undo: %v", err)
	}
}

// A dropped journal entry never deletes from the Trash: only <data>/trash slots are swept.
func TestRetentionLeavesTheTrashAlone(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/a.jsonl", claudeLog("x"), 100)
	res := h.move(MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}})
	journal := filepath.Join(h.r.Data, "journal.json")
	raw, err := os.ReadFile(journal)
	if err != nil {
		t.Fatal(err)
	}
	old := strings.Replace(string(raw), `"at": "`, `"at": "2020-01-01T00:00:00.000Z", "was": "`, 1)
	if err := os.WriteFile(journal, []byte(old), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := mutate.Record(h.r, "later", nil); err != nil {
		t.Fatal(err)
	}
	if hist, _ := mutate.History(h.r); len(hist) != 1 {
		t.Fatalf("the old entry was not dropped: %d entries", len(hist))
	}
	if _, err := os.Lstat(*res.Trash); err != nil {
		t.Fatalf("dropping the entry removed the Trash folder: %v", err)
	}
}
