package findings

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"testing"

	"spacevibe.dev/core/internal/config"
	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/fsx"
	"spacevibe.dev/core/internal/mutate"
	"spacevibe.dev/core/internal/roots"
)

// TestMain arms the real-home write guard: every test here writes only under t.TempDir() (S-R1).
func TestMain(m *testing.M) {
	fsx.InstallWriteGuard(config.Config{Test: true})
	os.Exit(m.Run())
}

// newService is a Keep service over a throwaway home; data is its data folder.
func newService(t *testing.T) (svc *Service, r roots.Roots, data string) {
	t.Helper()
	root, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	cfg := config.Config{Test: true, UserHome: root, ClaudeConfigDir: root + "/.claude", CodexHome: root + "/.codex", Home: root + "/.spacevibe"}
	r, err = roots.Resolve(cfg, t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	return NewService(r), r, r.Data
}

func kept(t *testing.T, s *Service) []string {
	t.Helper()
	res, err := s.Kept(t.Context())
	if err != nil {
		t.Fatalf("findings.kept: %v", err)
	}
	return res.Kept
}

func status(err error) int {
	if e, ok := coreerr.As(err); ok {
		return e.Status
	}
	return 0
}

// The ids the shell builds (Findings.swift): a row key with a project path, a hook failure, a rule, a Window, a session.
var shellIDs = []string{
	"skill:/Users/someone/Dự án/payments-web:lint",
	"hook::43c00ce9a764:fail",
	"R:/Users/someone/work:Bash(rm -rf:*)",
	"W:claude:five_hour:1794000000",
	"S:codex:019a-77f3",
}

func TestKeepUnkeepAndUndo(t *testing.T) {
	s, r, data := newService(t)
	if got := kept(t, s); len(got) != 0 || got == nil {
		t.Fatalf("no file: kept = %#v, want an empty list", got)
	}

	var entries []mutate.EntryRef
	for _, id := range shellIDs {
		res, err := s.Keep(t.Context(), IDParams{ID: id})
		if err != nil {
			t.Fatalf("keep %q: %v", id, err)
		}
		if res.Entry.Label != KeepLabel || res.Entry.Count != 1 || res.Entry.Undone {
			t.Fatalf("entry %+v", res.Entry)
		}
		entries = append(entries, res.Entry)
	}
	if got := kept(t, s); !slices.Equal(got, shellIDs) {
		t.Fatalf("kept = %q, want the ids verbatim in the order kept", got)
	}
	info, err := os.Stat(filepath.Join(data, KeptFile))
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("the list file: %v %v, want 0600", info, err)
	}

	// Refusals write nothing and record nothing.
	before, _ := os.ReadFile(filepath.Join(data, KeptFile))
	for _, c := range []struct {
		call func() error
		want int
	}{
		{func() error { _, err := s.Keep(t.Context(), IDParams{ID: shellIDs[0]}); return err }, 409},
		{func() error { _, err := s.Unkeep(t.Context(), IDParams{ID: "never-kept"}); return err }, 409},
		{func() error { _, err := s.Keep(t.Context(), IDParams{ID: ""}); return err }, 400},
		{func() error { _, err := s.Keep(t.Context(), IDParams{ID: "a\nb"}); return err }, 400},
	} {
		if got := status(c.call()); got != c.want {
			t.Errorf("status %d, want %d", got, c.want)
		}
	}
	if after, _ := os.ReadFile(filepath.Join(data, KeptFile)); string(after) != string(before) {
		t.Error("a refusal changed the list")
	}
	if history, _ := mutate.History(r); len(history) != len(shellIDs) {
		t.Fatalf("history has %d entries, want %d", len(history), len(shellIDs))
	}

	res, err := s.Unkeep(t.Context(), IDParams{ID: shellIDs[2]})
	if err != nil || res.Entry.Label != UnkeepLabel {
		t.Fatalf("unkeep: %+v %v", res, err)
	}
	if got := kept(t, s); slices.Contains(got, shellIDs[2]) || len(got) != len(shellIDs)-1 {
		t.Fatalf("after unkeep: %q", got)
	}

	// Undo, newest first: the unkeep comes back, then each keep goes; the first keep created the file.
	if label, err := mutate.Undo(r, res.Entry.ID); err != nil || label != UnkeepLabel {
		t.Fatalf("undo unkeep: %q %v", label, err)
	}
	if got := kept(t, s); !slices.Equal(got, shellIDs) {
		t.Fatalf("after undoing the unkeep: %q", got)
	}
	for i := len(entries) - 1; i >= 0; i-- {
		if _, err := mutate.Undo(r, entries[i].ID); err != nil {
			t.Fatalf("undo keep %d: %v", i, err)
		}
		if got := kept(t, s); !slices.Equal(got, shellIDs[:i]) {
			t.Fatalf("after undoing keep %d: %q", i, got)
		}
	}
	if _, err := os.Lstat(filepath.Join(data, KeptFile)); err == nil {
		t.Error("undoing the first keep left the file it created")
	}
}

// An undo under a newer change of the list is refused (the file-edited rule): Undo goes newest first.
func TestUndoUnderANewerKeepIsRefused(t *testing.T) {
	s, r, _ := newService(t)
	first, err := s.Keep(t.Context(), IDParams{ID: "a"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.Keep(t.Context(), IDParams{ID: "b"}); err != nil {
		t.Fatal(err)
	}
	if _, err := mutate.Undo(r, first.Entry.ID); status(err) != 409 {
		t.Fatalf("undo under a newer keep: %v, want 409", err)
	}
	if got := kept(t, s); !slices.Equal(got, []string{"a", "b"}) {
		t.Fatalf("a refused undo changed the list: %q", got)
	}
}

func TestBrokenListIsNeverReadAsEmpty(t *testing.T) {
	for name, content := range map[string]string{
		"garbage":       "{not json",
		"newer version": `{"version":2,"kept":[]}`,
		"no list":       `{"version":1}`,
		"bad id":        `{"version":1,"kept":["ok","a\u0000b"]}`,
		"extra member":  `{"version":1,"kept":[],"more":1}`,
		"two values":    `{"version":1,"kept":[]} {}`,
	} {
		t.Run(name, func(t *testing.T) {
			s, _, data := newService(t)
			path := filepath.Join(data, KeptFile)
			if err := os.MkdirAll(data, 0o700); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
				t.Fatal(err)
			}
			if _, err := s.Kept(t.Context()); status(err) != 409 || strings.Contains(err.Error(), content) {
				t.Errorf("kept: %v, want a 409 that does not quote the file", err)
			}
			if _, err := s.Keep(t.Context(), IDParams{ID: "x"}); status(err) != 409 {
				t.Errorf("keep: %v, want 409", err)
			}
			if after, _ := os.ReadFile(path); string(after) != content {
				t.Errorf("the file was overwritten: %q", after)
			}
		})
	}
}

func TestALinkInPlaceOfTheListIsLeftAlone(t *testing.T) {
	s, _, data := newService(t)
	elsewhere := filepath.Join(t.TempDir(), "elsewhere.json")
	if err := os.WriteFile(elsewhere, []byte(`{"version":1,"kept":[]}`+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(data, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(elsewhere, filepath.Join(data, KeptFile)); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Keep(t.Context(), IDParams{ID: "x"}); status(err) != 409 {
		t.Fatalf("keep through a link: %v, want 409", err)
	}
	if _, err := s.Kept(t.Context()); status(err) != 409 {
		t.Fatalf("read through a link: %v, want 409", err)
	}
	if text, _ := os.ReadFile(elsewhere); string(text) != `{"version":1,"kept":[]}`+"\n" {
		t.Errorf("the link target was written: %q", text)
	}
}

func TestTheListStaysBounded(t *testing.T) {
	s, _, data := newService(t)
	ids := make([]string, MaxKept)
	for i := range ids {
		ids[i] = "W:claude:five_hour:" + strconv.Itoa(1794000000+i)
	}
	text, err := encodeKept(ids)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(data, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(data, KeptFile), []byte(text), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Keep(t.Context(), IDParams{ID: "newest"}); err != nil {
		t.Fatal(err)
	}
	got := kept(t, s)
	if len(got) != MaxKept || got[0] != ids[1] || got[len(got)-1] != "newest" {
		t.Fatalf("len %d first %q last %q: the oldest id must drop", len(got), got[0], got[len(got)-1])
	}
}

func TestValidID(t *testing.T) {
	for _, id := range append(slices.Clone(shellIDs), strings.Repeat("x", MaxIDBytes), "emoji 🙂 and <&>") {
		if !ValidID(id) {
			t.Errorf("%q refused", id)
		}
	}
	for _, id := range []string{"", strings.Repeat("x", MaxIDBytes+1), "tab\there", "nul\x00", "del\x7f", "c1\u0085", "sep\u2028", string([]byte{0xff})} {
		if ValidID(id) {
			t.Errorf("%q accepted", id)
		}
	}
}

func TestCancelledBeforeTheLockWritesNothing(t *testing.T) {
	s, _, data := newService(t)
	ctx, cancel := context.WithCancel(t.Context())
	cancel()
	if _, err := s.Keep(ctx, IDParams{ID: "x"}); err == nil {
		t.Fatal("a cancelled keep succeeded")
	}
	if _, err := os.Lstat(filepath.Join(data, KeptFile)); err == nil {
		t.Error("a cancelled keep wrote the list")
	}
}
