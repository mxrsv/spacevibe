package clean

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"spacevibe.dev/core/internal/usage"
)

// A later op of the same Undo fails (the archive cannot be read): the files already put back return to the Trash
// folder, and the entry stays undoable.
func TestUndoPutsBackWhenTheArchiveStepFails(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/a.jsonl", claudeLog("x"), 100)
	res := h.move(MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}})
	archive := usage.ArchivePath(h.r.Data)
	good, err := os.ReadFile(archive)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(archive, []byte("not json"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := h.undo(res.Entry.ID); statusOf(err) != 409 {
		t.Fatalf("err %v", err)
	}
	if h.exists(".claude/projects/p/a.jsonl") {
		t.Fatal("a failed Undo left the log in place")
	}
	if _, err := os.Lstat(filepath.Join(*res.Trash, "claude/projects/p/a.jsonl")); err != nil {
		t.Fatalf("the log did not go back to the Trash folder: %v", err)
	}
	if err := os.WriteFile(archive, good, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := h.undo(res.Entry.ID); err != nil {
		t.Fatalf("the entry stopped being undoable: %v", err)
	}
}

// The journal cannot be written at the end: every moved file goes back and the archive records go, nothing is recorded.
func TestJournalFailureRollsTheMoveBack(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/a.jsonl", claudeLog("x"), 100)
	h.write(".claude/shell-snapshots/s", "s", 1)
	before := h.tree()
	journal := filepath.Join(h.r.Data, "journal.json")
	_, err := h.svc.Move(context.Background(), MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}, Caches: []string{"claude:shell-snapshots"}},
		func(p ProgressParams) {
			if p.Phase == "moving" && p.Done == p.Total {
				_ = os.Mkdir(journal, 0o700) // a folder where the journal should be: the final write is refused
			}
		})
	if statusOf(err) != 409 {
		t.Fatalf("err %v", err)
	}
	sameFiles(t, before, h.tree())
	if paths, _ := usage.ArchivedPaths(h.r.Data); len(paths) != 0 {
		t.Errorf("the archive kept %v", paths)
	}
	if items := h.trashItems(); len(items) != 0 {
		t.Errorf("the Trash holds %v", items)
	}
}
