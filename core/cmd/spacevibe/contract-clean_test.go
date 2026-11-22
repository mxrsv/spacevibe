package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// cleanCases are the contract cases of Clean (RB-E7): clean.scan, clean.move refused and then moved with its progress,
// and journal.undo putting every file back. The Trash is the <data>/test-trash stand-in (SPACEVIBE_TEST=1).
func cleanCases(t *testing.T) {
	// aged copies the fixture, dates every log to now except a fixed set dated 2025-01-01, so no bucket moves with the
	// clock and the transcript stays the same on any day.
	aged := func(t *testing.T) string {
		home := copiedHome(t)
		old, now := time.Date(2025, 1, 1, 12, 0, 0, 0, time.UTC), time.Now()
		oldLogs := map[string]bool{
			".claude/projects/-work-spacevibe-api/session-010.jsonl": true,
			".claude/projects/-work-spacevibe-api/session-013.jsonl": true,
			".codex/sessions/2026/10/rollout-014.jsonl":              true,
		}
		for _, logs := range []string{".claude/projects", ".codex/sessions"} {
			_ = filepath.Walk(filepath.Join(home, logs), func(p string, info os.FileInfo, err error) error {
				if err != nil || info.IsDir() {
					return nil
				}
				rel, _ := filepath.Rel(home, p)
				at := now
				if oldLogs[rel] {
					at = old
				}
				if err := os.Chtimes(p, at, at); err != nil {
					t.Fatal(err)
				}
				return nil
			})
		}
		writeFile(t, filepath.Join(home, ".claude/shell-snapshots/snapshot-zsh-1.sh"), strings.Repeat("s", 5000))
		return home
	}

	t.Run("clean_scan", func(t *testing.T) {
		home := aged(t)
		c := startOn(t, shippedBin, home)
		c.initialize()
		var res struct {
			CLIs []struct {
				CLI  string
				Logs struct {
					State   string
					Buckets []struct{ OlderThanDays, Files int }
				}
				Caches []struct{ ID string }
			}
			Items []struct {
				Key   string
				Bytes int64
			}
		}
		decodeInto(t, c.ok(c.call("1", "clean.scan", `{}`)), &res)
		if len(res.CLIs) != 2 || res.CLIs[0].Logs.State != "measured" || len(res.CLIs[0].Logs.Buckets) == 0 || len(res.CLIs[0].Caches) != 1 || len(res.Items) == 0 {
			t.Fatalf("scan %+v", res)
		}
		// The transcript masks these sizes (diskMask, see diskSized), so their shape is checked here: every item occupies
		// whole 512-byte blocks and none is empty.
		for _, item := range res.Items {
			if item.Bytes <= 0 || item.Bytes%512 != 0 {
				t.Errorf("item %s has size %d, want whole allocated blocks", item.Key, item.Bytes)
			}
		}
		c.wantError(c.call("2", "clean.scan", `{"cli":"claude"}`), -32602)
		c.finish("clean_scan")
	})

	t.Run("clean_move_then_undo", func(t *testing.T) {
		home := aged(t)
		before := homeTree(t, home)
		c := startOn(t, shippedBin, home)
		c.initialize()
		for _, refusal := range []struct {
			id, params string
			status     int
		}{
			{"1", `{}`, 400},
			{"2", `{"logs":[{"cli":"claude","olderThanDays":60}]}`, 400},
			{"3", `{"caches":["claude:file-history"]}`, 400},
			{"4", `{"caches":["codex:cache"]}`, 409},
		} {
			if got := c.status(c.call(refusal.id, "clean.move", refusal.params)); got != refusal.status {
				t.Errorf("call %s: status %d, want %d", refusal.id, got, refusal.status)
			}
		}
		c.wantError(c.call("5", "clean.move", `{"logs":[{"cli":"claude","olderThanDays":90,"all":true}]}`), -32602)
		wantHomeTree(t, before, homeTree(t, home))

		c.send(request("6", "clean.move", `{"logs":[{"cli":"claude","olderThanDays":90},{"cli":"codex","olderThanDays":90}],"caches":["claude:shell-snapshots"]}`))
		phases := map[string]int{}
		var res struct {
			Entry struct {
				ID, Label string
				Count     int
			}
			Moved  struct{ Files int }
			Groups []struct {
				ID     string
				Moved  struct{ Files int }
				Stayed int
			}
			Cancelled bool
			Trash     string
		}
		for {
			line := c.recv()
			if strings.Contains(line, `"method":"clean/progress"`) {
				var note struct {
					Params struct {
						ID    json.RawMessage `json:"id"`
						Phase string
					} `json:"params"`
				}
				decodeInto(t, json.RawMessage(line), &note)
				if string(note.Params.ID) != "6" {
					t.Fatalf("progress names id %s", note.Params.ID)
				}
				phases[note.Params.Phase]++
				continue
			}
			r := parseReply(t, line)
			if string(r.ID) != "6" {
				t.Fatalf("reply %s", line)
			}
			decodeInto(t, c.ok(r), &res)
			break
		}
		c.norm.mask(res.Entry.ID, "$ENTRY_ID")
		c.norm.mask(filepath.Base(res.Trash), "SpaceVibe Clean $DATE")
		if res.Moved.Files == 0 || res.Cancelled || res.Entry.Count != 2 || len(res.Groups) != 3 || phases["reading"] == 0 || phases["moving"] == 0 {
			t.Fatalf("move %+v, progress %v", res, phases)
		}
		if !strings.HasPrefix(res.Trash, filepath.Join(home, ".spacevibe", "test-trash")+"/SpaceVibe Clean ") {
			t.Fatalf("trash %q is not the test stand-in", res.Trash)
		}
		var hist struct{ Entries []json.RawMessage }
		decodeInto(t, c.ok(c.call("7", "journal.history", `{}`)), &hist)
		if len(hist.Entries) != 1 {
			t.Fatalf("history has %d entries, want 1", len(hist.Entries))
		}
		decodeInto(t, c.ok(c.call("8", "journal.undo", `{"id":"`+res.Entry.ID+`"}`)), &struct{ Label string }{})
		c.finish("clean_move_then_undo")
		after := homeTree(t, home)
		for k, v := range after {
			if _, ok := before[k]; !ok && strings.HasPrefix(v, "dir ") {
				delete(after, k) // a folder Undo had to make again is not a file
			}
		}
		wantHomeTree(t, before, after)
	})

	t.Run("clean_move_locked", func(t *testing.T) {
		home := aged(t)
		c := startOn(t, shippedBin, home, "SPACEVIBE_PROC_FIXTURE="+filepath.Join(home, ".spacevibe", "activity-proc.json"))
		c.initialize()
		var scan struct {
			CLIs []struct {
				CLI   string
				Locks struct {
					Logs *struct{ Reason, Message string }
				}
			}
		}
		decodeInto(t, c.ok(c.call("1", "clean.scan", `{}`)), &scan)
		if scan.CLIs[0].Locks.Logs == nil || scan.CLIs[0].Locks.Logs.Reason != "sessions" {
			t.Fatalf("the fixture's running Claude sessions do not lock its logs: %+v", scan.CLIs[0].Locks)
		}
		if got := c.status(c.call("2", "clean.move", `{"logs":[{"cli":"claude","olderThanDays":90}]}`)); got != 409 {
			t.Fatalf("status %d", got)
		}
		c.finish("clean_move_locked")
	})
}
