package clean

import (
	"context"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"spacevibe.dev/core/internal/mutate"
	"spacevibe.dev/core/internal/usage"
)

// crashAfterStaging runs a move of the CLI's old logs and ends it once every file is staged: nothing is in the Trash
// and no journal entry exists, what a core that died there leaves. It returns the staging folder.
func (h *home) crashAfterStaging(cli string) string {
	h.t.Helper()
	done := make(chan struct{})
	go func() {
		defer close(done)
		_, _ = h.svc.Move(context.Background(), MoveParams{Logs: []LogPick{{CLI: cli, OlderThanDays: 90}}}, func(p ProgressParams) {
			if p.Phase == "moving" && p.Done == p.Total {
				crashHere()
			}
		})
	}()
	<-done
	dirs, _ := filepath.Glob(filepath.Join(h.r.Data, "clean", "*-*"))
	for _, d := range dirs {
		if info, err := os.Stat(d); err == nil && info.IsDir() {
			return d
		}
	}
	h.t.Fatal("the simulated crash left no staging folder")
	return ""
}

func (h *home) anyWrite() {
	h.t.Helper()
	if _, err := mutate.Record(h.r, "any later write", nil); err != nil {
		h.t.Fatal(err)
	}
}

// A list that exists but is refused (it names another root) leaves the staging folder alone, never putting its files
// under the current root, and clean.scan says so.
func TestRecoveryLeavesARefusedListAlone(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/a.jsonl", claudeLog("x"), 100)
	staging := h.crashAfterStaging("claude")
	list := staging + ".json"
	raw, err := os.ReadFile(list)
	if err != nil {
		t.Fatal(err)
	}
	tampered := strings.Replace(string(raw), `"root":"`+h.r.Claude.Root+`"`, `"root":"/private/tmp/elsewhere"`, 1)
	if tampered == string(raw) {
		t.Fatalf("list has no root:\n%s", raw)
	}
	if err := os.WriteFile(list, []byte(tampered), 0o600); err != nil {
		t.Fatal(err)
	}
	h.anyWrite()
	if h.exists(".claude/projects/p/a.jsonl") {
		t.Fatal("recovery put a file under a root its list does not name")
	}
	if _, err := os.Lstat(filepath.Join(staging, "claude/projects/p/a.jsonl")); err != nil {
		t.Fatalf("the staged file left staging: %v", err)
	}
	if len(h.trashItems()) != 0 {
		t.Fatal("a refused staging folder went to the Trash")
	}
	if p := h.scan().Problems; len(p) != 1 || !strings.Contains(p[0], filepath.Base(staging)) {
		t.Fatalf("problems %v", p)
	}
}

// A staged path whose place was taken again goes on into the Trash as its own "SpaceVibe Clean" folder; the others go
// back.
func TestRecoveryTrashesWhatCannotGoBack(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/a.jsonl", claudeLog("x"), 100)
	h.write(".claude/projects/p/b.jsonl", claudeLog("y"), 100)
	staging := h.crashAfterStaging("claude")
	h.write(".claude/projects/p/b.jsonl", "a new b", 0)
	h.anyWrite()
	if !h.exists(".claude/projects/p/a.jsonl") {
		t.Fatal("a.jsonl did not go back")
	}
	if data, _ := os.ReadFile(h.path(".claude/projects/p/b.jsonl")); string(data) != "a new b" {
		t.Fatalf("the new b.jsonl was touched: %q", data)
	}
	if _, err := os.Lstat(staging); err == nil {
		t.Fatal("the staging folder stayed")
	}
	items := h.trashItems()
	if len(items) != 1 || !strings.HasPrefix(items[0], "SpaceVibe Clean ") {
		t.Fatalf("trash %v", items)
	}
	if data, err := os.ReadFile(filepath.Join(h.r.Trash, items[0], "claude/projects/p/b.jsonl")); err != nil || string(data) != claudeLog("y") {
		t.Fatalf("the old b.jsonl is not in the Trash folder: %q %v", data, err)
	}
	if h.scan().Problems != nil {
		t.Fatal("a settled recovery is still a problem")
	}
}

// A staging folder with no list at all is put back from its <cli>/<rel> layout.
func TestRecoveryWithoutAList(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/a.jsonl", claudeLog("x"), 100)
	before := h.tree()
	staging := h.crashAfterStaging("claude")
	if err := os.Remove(staging + ".json"); err != nil {
		t.Fatal(err)
	}
	h.anyWrite()
	sameFiles(t, before, h.tree())
	if _, err := os.Lstat(staging); err == nil {
		t.Fatal("the staging folder stayed")
	}
}

// A crash after the staging folder reached the Trash and before the journal write: the files stay in the Trash folder,
// their usage stays archived, and the next write drops only the orphaned list.
func TestCrashAfterTheTrashRename(t *testing.T) {
	h := newHome(t)
	h.write(".claude/projects/p/a.jsonl", claudeLog("tdd"), 100)
	before := h.usage()
	res := h.move(MoveParams{Logs: []LogPick{{CLI: "claude", OlderThanDays: 90}}})
	// The journal write never happened: no entry names the list.
	if err := os.WriteFile(filepath.Join(h.r.Data, "journal.json"), []byte("[]"), 0o600); err != nil {
		t.Fatal(err)
	}
	h.anyWrite()
	if _, err := os.Lstat(filepath.Join(*res.Trash, "claude/projects/p/a.jsonl")); err != nil {
		t.Fatalf("the moved log left the Trash folder: %v", err)
	}
	if h.exists(".claude/projects/p/a.jsonl") {
		t.Fatal("recovery brought a trashed log back")
	}
	if lists, _ := filepath.Glob(filepath.Join(h.r.Data, "clean", "*.json")); len(lists) != 0 {
		t.Errorf("the orphaned list stayed: %v", lists)
	}
	if paths, _ := usage.ArchivedPaths(h.r.Data); len(paths) != 1 {
		t.Errorf("archive %v, want the moved log's record", paths)
	}
	if got := h.usage(); !reflect.DeepEqual(before, got) {
		t.Fatalf("usage changed: %+v", got.Totals.Claude.Skill)
	}
}
