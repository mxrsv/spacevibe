package clean

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"spacevibe.dev/core/internal/config"
	"spacevibe.dev/core/internal/fsx"
	"spacevibe.dev/core/internal/mutate"
	"spacevibe.dev/core/internal/roots"
)

// CL-R7 and S-R1 for the move paths of clean.move and its Undo.

// Under SPACEVIBE_TEST=1 the Trash is <data>/test-trash, whatever HOME says; outside it, $HOME/.Trash.
func TestTrashSeam(t *testing.T) {
	cfg := config.Config{Test: true, UserHome: "/tmp/h", ClaudeConfigDir: "/tmp/h/.claude", CodexHome: "/tmp/h/.codex", Home: "/tmp/d"}
	r, err := roots.Resolve(cfg, "/nonexistent-real-home")
	if err != nil {
		t.Fatal(err)
	}
	if r.Trash != "/tmp/d/test-trash" {
		t.Errorf("test trash %q", r.Trash)
	}
	cfg.Test = false
	if r, _ := roots.Resolve(cfg, "/nonexistent-real-home"); r.Trash != "/tmp/h/.Trash" {
		t.Errorf("trash %q", r.Trash)
	}
}

// A link inside a cache folder moves as a link: its target is never touched, and Undo makes the same link again.
func TestCacheLinkMovesAsLink(t *testing.T) {
	h := newHome(t)
	target := h.write("precious/data", "keep me", 1)
	if err := os.MkdirAll(h.path(".claude/cache"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Dir(target), h.path(".claude/cache/link")); err != nil {
		t.Fatal(err)
	}
	res := h.move(MoveParams{Caches: []string{"claude:cache"}})
	if data, err := os.ReadFile(target); err != nil || string(data) != "keep me" {
		t.Fatalf("the link's target changed: %q %v", data, err)
	}
	moved, err := os.Readlink(filepath.Join(*res.Trash, "claude/cache/link"))
	if err != nil || moved != filepath.Dir(target) {
		t.Fatalf("the link did not move as a link: %q %v", moved, err)
	}
	if err := h.undo(res.Entry.ID); err != nil {
		t.Fatal(err)
	}
	if back, err := os.Readlink(h.path(".claude/cache/link")); err != nil || back != filepath.Dir(target) {
		t.Fatalf("Undo: %q %v", back, err)
	}
}

// A folder swapped for a link after the scan is caught at move time: nothing below it moves.
func TestMoveRefusesAPlantedLink(t *testing.T) {
	h := newHome(t)
	outside := h.write("outside/p/a.jsonl", claudeLog("x"), 100)
	if err := os.MkdirAll(h.path(".claude/projects"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(h.path("outside/p"), h.path(".claude/projects/p")); err != nil {
		t.Fatal(err)
	}
	err := mutate.WithLockContext(context.Background(), h.r, func(tx *mutate.Tx) error {
		_, err := mutate.MoveToSystemTrash(context.Background(), tx, mutate.TrashPlan{
			Files: []mutate.TrashFile{{Group: "logs:claude", CLI: "claude", Rel: "projects/p/a.jsonl", Log: true}}, Label: label}, nil)
		return err
	})
	if statusOf(err) != 409 || !strings.Contains(err.Error(), "not a plain folder") {
		t.Fatalf("err %v", err)
	}
	if _, err := os.Lstat(outside); err != nil {
		t.Fatal("a file behind a link was moved")
	}
	for _, rel := range []string{"../outside/p/a.jsonl", "/etc/hosts", "projects/../../x", ""} {
		err := mutate.WithLockContext(context.Background(), h.r, func(tx *mutate.Tx) error {
			_, err := mutate.MoveToSystemTrash(context.Background(), tx, mutate.TrashPlan{
				Files: []mutate.TrashFile{{Group: "logs:claude", CLI: "claude", Rel: rel, Log: true}}, Label: label}, nil)
			return err
		})
		if statusOf(err) != 400 {
			t.Errorf("rel %q: %v", rel, err)
		}
	}
}

// journal.json and the move's list are user-editable: an entry or a list whose paths leave the managed folders is
// refused before anything moves, or, for the archive step, with every file put back into the Trash folder.
func TestUndoContainment(t *testing.T) {
	for _, tamper := range []struct {
		name, from, to string
		inList         bool
	}{
		{"trash outside the Trash", `"trash": "`, `"trash": "/private/tmp/elsewhere/SpaceVibe Clean x", "was": "`, false},
		{"staging outside the data folder", `"staging": "`, `"staging": "/private/tmp/stage", "was": "`, false},
		{"a list beside another staging", `"list": "`, `"list": "/private/tmp/1-abcdef01.json", "was": "`, false},
		{"an archive file elsewhere", `"file": "`, `"file": "/private/tmp/usage-archive.json", "was": "`, false},
		{"a file that climbs out", `"files":[`, `"files":["../../etc/x",`, true},
		{"an absolute file", `"files":[`, `"files":["/etc/x",`, true},
		{"a root that is not the CLI root", `"root":"`, `"root":"/private/tmp","was":"`, true},
		{"an archived log outside the roots", `"archived":[`, `"archived":["/etc/passwd",`, true},
	} {
		t.Run(tamper.name, func(t *testing.T) {
			h := newHome(t)
			h.write(".claude/projects/p/a.jsonl", claudeLog("x"), 100)
			res := h.move(MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}})
			file := filepath.Join(h.r.Data, "journal.json")
			if tamper.inList {
				lists, _ := filepath.Glob(filepath.Join(h.r.Data, "clean", "*.json"))
				if len(lists) != 1 {
					t.Fatalf("lists %v", lists)
				}
				file = lists[0]
			}
			raw, err := os.ReadFile(file)
			if err != nil {
				t.Fatal(err)
			}
			if !strings.Contains(string(raw), tamper.from) {
				t.Fatalf("%s has no %s:\n%s", file, tamper.from, raw)
			}
			if err := os.WriteFile(file, []byte(strings.Replace(string(raw), tamper.from, tamper.to, 1)), 0o600); err != nil {
				t.Fatal(err)
			}
			if err := h.undo(res.Entry.ID); statusOf(err) != 400 {
				t.Fatalf("err %v", err)
			}
			if h.exists(".claude/projects/p/a.jsonl") || len(h.trashItems()) != 1 || h.exists("../etc/x") {
				t.Fatal("a refused Undo changed something")
			}
		})
	}
}

// Never across volumes: the files would be copied, not moved. /dev is another device than the temp folder.
func TestMoveRefusesAnotherVolume(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/a.jsonl", claudeLog("x"), 100)
	h.r.Trash = "/dev"
	h.svc.roots = h.r
	_, err := h.svc.Move(context.Background(), MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}}, nil)
	if statusOf(err) != 409 || !strings.Contains(err.Error(), "not on one volume") {
		t.Fatalf("err %v", err)
	}
	if !h.exists(".claude/projects/p/a.jsonl") {
		t.Fatal("the log moved")
	}
}

// guardStandIn arms, beside the real-home guard, the same home check aimed at a temporary stand-in for the real home,
// and gives that stand-in a .Trash. A test points the Trash there: a guard regression then meets a temporary folder,
// never the real ~/.Trash (L6).
func guardStandIn(t *testing.T) (trash string) {
	t.Helper()
	fake, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	trash = filepath.Join(fake, ".Trash")
	if err := os.Mkdir(trash, 0o700); err != nil {
		t.Fatal(err)
	}
	real := config.Config{Test: true}
	fsx.SetWriteGuard(func(p string) error {
		if err := roots.RefuseRealHomeUnderTest(real, p); err != nil {
			return err
		}
		return roots.RefuseUnderHome(fake, p)
	})
	t.Cleanup(func() { fsx.InstallWriteGuard(real) })
	return trash
}

// S-R1: with SPACEVIBE_TEST=1, a Trash under the (stand-in) real home is refused by the write guard like every other
// write, and the files that were staged go back.
func TestRealHomeGuardRefusesTheRealTrash(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/a.jsonl", claudeLog("x"), 100)
	before := h.tree()
	h.r.Trash = guardStandIn(t)
	h.svc.roots = h.r
	_, err := h.svc.Move(context.Background(), MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}}, nil)
	if err == nil || !strings.Contains(err.Error(), "refusing to write under the real home") {
		t.Fatalf("a move into the guarded Trash was not refused by the guard: %v", err)
	}
	sameFiles(t, before, h.tree())
	if hist, _ := mutate.History(h.r); len(hist) != 0 {
		t.Fatalf("a refused move wrote %d journal entries", len(hist))
	}
	if entries, _ := os.ReadDir(h.r.Trash); len(entries) != 0 {
		t.Fatalf("the guarded Trash holds %v", entries)
	}
}

// L5: the final rename is refused and a staged file's folder is gone meanwhile: unstage makes it again (no link
// followed) and puts the file back.
func TestUnstageRemakesMissingParents(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/deep/a.jsonl", claudeLog("x"), 100)
	before := h.tree()
	h.r.Trash = guardStandIn(t)
	h.svc.roots = h.r
	_, err := h.svc.Move(context.Background(), MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}}, func(p ProgressParams) {
		if p.Phase == "moving" && p.Done == p.Total {
			_ = os.Remove(h.path(".claude/projects/p/deep")) // emptied by the move
		}
	})
	if err == nil || !strings.Contains(err.Error(), "refusing to write under the real home") {
		t.Fatalf("err %v", err)
	}
	sameFiles(t, before, h.tree())
}
