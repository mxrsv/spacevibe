// Package findings stores the user's Keep list: the Inbox findings the user chose to keep, so they leave the count
// and stay kept across restarts (spec RD26, "Inferred, not decided": Keep is stored). The ids are the shell's
// (Sources/SpaceVibe/Shell/Findings.swift); the core checks their length and characters and never reads meaning
// into them. The list lives in <data>/kept-findings.json; every change is one journaled file edit, so journal.undo
// restores the list as it was.
package findings

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"syscall"
	"unicode"
	"unicode/utf8"

	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/fsx"
	"spacevibe.dev/core/internal/mutate"
	"spacevibe.dev/core/internal/roots"
)

const (
	// KeptFile is the Keep list inside the data folder.
	KeptFile = "kept-findings.json"
	// MaxIDBytes is the longest id Keep takes. Ids hold paths (a row key names its project folder), so the cap is
	// generous; an id is never cut.
	MaxIDBytes = 1024
	// MaxKept is how many ids the list holds. Keeping one more drops the oldest: Window ids carry their reset time,
	// so kept Windows pile up and the list must stay bounded.
	MaxKept = 2000
	// KeepLabel and UnkeepLabel are the journal labels of findings.keep and findings.unkeep.
	KeepLabel   = "Kept a finding"
	UnkeepLabel = "Stopped keeping a finding"

	keptVersion = 1
	// maxFileBytes caps the read: MaxKept ids of MaxIDBytes, escaped, fit with room to spare.
	maxFileBytes = 16 << 20
)

// Messages of the refusals. None quotes the file or the id.
const (
	badIDMessage     = "A finding id must be 1 to 1024 bytes of text with no control characters."
	alreadyKept      = "That finding is already kept."
	notKept          = "That finding is not kept."
	unreadableSuffix = " could not be read as SpaceVibe's Keep list, so nothing was changed."
	linkSuffix       = " is a link, so SpaceVibe left it alone."
	unreadableOnRead = " could not be read as SpaceVibe's Keep list."
)

// keptStore is the file: {"version":1,"kept":[ids, oldest first]}.
type keptStore struct {
	Version int      `json:"version"`
	Kept    []string `json:"kept"`
}

// Service holds findings.kept, findings.keep and findings.unkeep.
type Service struct {
	roots roots.Roots
}

// NewService returns a service over the roots; the list is under r.Data.
func NewService(r roots.Roots) *Service { return &Service{roots: r} }

// IDParams is the params of findings.keep and findings.unkeep.
type IDParams struct {
	ID string `json:"id"`
}

// KeptResult is the result of findings.kept: the kept ids, oldest first, never null.
type KeptResult struct {
	Kept []string `json:"kept"`
}

func (s *Service) path() string { return filepath.Join(s.roots.Data, KeptFile) }

// Kept is findings.kept. A missing file is an empty list; a file that cannot be read as the list is a 409, never
// read as empty, so a broken file cannot bring every kept finding back without a word.
func (s *Service) Kept(ctx context.Context) (KeptResult, error) {
	if err := ctx.Err(); err != nil {
		return KeptResult{}, err
	}
	kept, err := readKept(s.path(), unreadableOnRead)
	if err != nil {
		return KeptResult{}, err
	}
	return KeptResult{Kept: kept}, nil
}

// Keep is findings.keep: the id is added last. 409 when it is kept already (nothing is written, no entry).
func (s *Service) Keep(ctx context.Context, p IDParams) (mutate.EntryResult, error) {
	return s.edit(ctx, p.ID, KeepLabel, func(kept []string) ([]string, error) {
		if slices.Contains(kept, p.ID) {
			return nil, coreerr.NewStatus(alreadyKept, coreerr.StatusConflict)
		}
		next := append(slices.Clone(kept), p.ID)
		if len(next) > MaxKept {
			next = next[len(next)-MaxKept:]
		}
		return next, nil
	})
}

// Unkeep is findings.unkeep: the id leaves the list. 409 when it is not there (nothing is written, no entry).
func (s *Service) Unkeep(ctx context.Context, p IDParams) (mutate.EntryResult, error) {
	return s.edit(ctx, p.ID, UnkeepLabel, func(kept []string) ([]string, error) {
		if !slices.Contains(kept, p.ID) {
			return nil, coreerr.NewStatus(notKept, coreerr.StatusConflict)
		}
		return slices.DeleteFunc(slices.Clone(kept), func(id string) bool { return id == p.ID }), nil
	})
}

// edit is one journaled write of the list under the write lock. The refusals come in this order: the id (400), the
// lock and a cancel, a link in place of the file (409), the journal (409), the file (409), the change (409).
func (s *Service) edit(ctx context.Context, id, label string, change func([]string) ([]string, error)) (mutate.EntryResult, error) {
	if err := ctx.Err(); err != nil {
		return mutate.EntryResult{}, err
	}
	if !ValidID(id) {
		return mutate.EntryResult{}, coreerr.New(badIDMessage)
	}
	path := s.path()
	var entry *mutate.Entry
	err := mutate.WithLockContext(ctx, s.roots, func(tx *mutate.Tx) error {
		if err := ctx.Err(); err != nil {
			return err
		}
		if info, err := os.Lstat(path); err == nil && info.Mode()&fs.ModeSymlink != 0 {
			return coreerr.NewStatus(path+linkSuffix, coreerr.StatusConflict)
		}
		var err error
		entry, err = tx.Edit(path, label, validText(path), func(current *string) (*string, error) {
			kept := []string{}
			if current != nil {
				parsed, err := parseKept([]byte(*current))
				if err != nil {
					return nil, coreerr.NewStatus(path+unreadableSuffix, coreerr.StatusConflict)
				}
				kept = parsed
			}
			next, err := change(kept)
			if err != nil {
				return nil, err
			}
			text, err := encodeKept(next)
			if err != nil {
				return nil, err
			}
			return &text, nil
		})
		return err
	})
	if err != nil {
		return mutate.EntryResult{}, err
	}
	if entry == nil { // the change always differs; kept for safety, never a silent success
		return mutate.EntryResult{}, coreerr.NewStatus(alreadyKept, coreerr.StatusConflict)
	}
	return mutate.EntryResult{Entry: entry.Ref()}, nil
}

// ValidID is the only check an id gets: 1 to MaxIDBytes bytes of UTF-8 with no control character (C0, DEL, C1) and
// no line or paragraph separator. Its meaning stays the shell's.
func ValidID(id string) bool {
	if id == "" || len(id) > MaxIDBytes || !utf8.ValidString(id) {
		return false
	}
	for _, r := range id {
		if unicode.IsControl(r) || r == ' ' || r == ' ' {
			return false
		}
	}
	return true
}

// readKept reads the list at path: missing is empty; anything else that is not the list is a 409 naming the file.
func readKept(path, suffix string) ([]string, error) {
	if info, err := os.Lstat(path); err == nil && info.Mode()&fs.ModeSymlink != 0 {
		return nil, coreerr.NewStatus(path+linkSuffix, coreerr.StatusConflict)
	}
	data, err := fsx.ReadRegular(path, maxFileBytes)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) || errors.Is(err, syscall.ENOTDIR) {
			return []string{}, nil
		}
		return nil, coreerr.NewStatus(path+suffix, coreerr.StatusConflict)
	}
	kept, err := parseKept(data)
	if err != nil {
		return nil, coreerr.NewStatus(path+suffix, coreerr.StatusConflict)
	}
	return kept, nil
}

var errNotTheList = errors.New("not the Keep list")

// parseKept is the list of a file: version 1, a kept array of valid ids. A repeated id is listed once, at its first
// place. Any other shape (a newer version included) is an error, so it is never overwritten or read as empty.
func parseKept(data []byte) ([]string, error) {
	var store keptStore
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&store); err != nil || dec.More() || store.Version != keptVersion || store.Kept == nil {
		return nil, errNotTheList
	}
	out := make([]string, 0, len(store.Kept))
	seen := make(map[string]bool, len(store.Kept))
	for _, id := range store.Kept {
		if !ValidID(id) {
			return nil, errNotTheList
		}
		if !seen[id] {
			seen[id] = true
			out = append(out, id)
		}
	}
	return out, nil
}

// encodeKept is the file text of a list: compact JSON and a final newline.
func encodeKept(kept []string) (string, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(keptStore{Version: keptVersion, Kept: kept}); err != nil {
		return "", err
	}
	return buf.String(), nil
}

// validText is the check of the bytes read back from the temp file before the rename.
func validText(path string) func(string) error {
	return func(text string) error {
		if _, err := parseKept([]byte(text)); err != nil {
			return coreerr.NewStatus(path+unreadableSuffix, coreerr.StatusInternalFailure)
		}
		return nil
	}
}
