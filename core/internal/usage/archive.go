package usage

import (
	"context"
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strconv"

	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/fsx"
	"spacevibe.dev/core/internal/logs"
)

// The usage archive (CL-R3): before Clean moves a session log to the Trash, the scan record of that log is kept in
// <data>/usage-archive.json, so Never ran, session counts and hook runs stay what they were. The scan merges the
// archive with the live logs; a live log at an archived path wins, so a log that came back (Undo) is never counted
// twice. Undo of the move also removes its records (mutate, op usage-archived).
//
// A record holds what the scan cache holds (names, days, hook hashes, durations) plus the token counts per model,
// never log text (S-R3). Unlike the cache it is the only copy of facts that can no longer be read from a log, so it is
// never dropped by a scan, never rebuilt, and a file that exists but cannot be read refuses every write (409) rather
// than being replaced.

// ArchiveFileName is the archive inside the data folder.
const ArchiveFileName = "usage-archive.json"

// archiveVersion is the layout of the archive file.
const archiveVersion = 1

// maxArchiveBytes bounds the read of the archive; a larger file is refused like a corrupt one.
const maxArchiveBytes = 512 << 20

// ArchiveUnreadableMessage is the refusal of a write that meets an archive it cannot read. It never quotes the file.
const ArchiveUnreadableMessage = "The usage archive (usage-archive.json) cannot be read, so no log was moved. Fix or move the file, then try again."

// ModelTokens are the tokens one model used in one log, as Activity folds them.
type ModelTokens struct {
	Model          string  `json:"model"`
	Input          float64 `json:"input"`
	Output         float64 `json:"output"`
	CacheWrite     float64 `json:"cacheWrite"`
	CacheWriteLong float64 `json:"cacheWriteLong"`
	CacheRead      float64 `json:"cacheRead"`
}

// ArchivedLog is the archive record of one moved log: its scan record and its tokens per model.
type ArchivedLog struct {
	file   cachedFile
	Tokens []ModelTokens
}

// Stamp is "<size>:<mtime ms>" of the log when it was read; a move compares it again just before the rename.
func (a ArchivedLog) Stamp() string { return a.file.Stamp }

type archivedJSON struct {
	V       int           `json:"v"`
	Stamp   string        `json:"stamp"`
	CLI     CLI           `json:"cli"`
	Session string        `json:"session"`
	First   *string       `json:"first,omitempty"`
	Rec     fileRecord    `json:"rec"`
	Tokens  []ModelTokens `json:"tokens"`
}

type archiveJSON struct {
	V    int                     `json:"v"`
	Logs map[string]archivedJSON `json:"logs"`
}

// ArchivePath is the archive file under a data folder.
func ArchivePath(dataDir string) string { return filepath.Join(dataDir, ArchiveFileName) }

// LogRef is one log Clean is about to move.
type LogRef struct {
	Path string
	CLI  CLI
}

// TokensFunc folds a whole log into its token counts per model; ok is false when the log cannot be read.
type TokensFunc func(ctx context.Context, path string, cli CLI) (tokens []ModelTokens, ok bool, err error)

// ArchiveRecords reads the record of every log for the archive: the scan cache's record when its stamp still matches,
// otherwise a fresh parse, plus the tokens from tokensOf. A log that cannot be read to the end gets no record: the scan
// leaves such a log out whole, so moving it changes no count. progress, which may be nil, is called after each log.
// The only error is the context's.
func (s *Scanner) ArchiveRecords(ctx context.Context, refs []LogRef, tokensOf TokensFunc, progress func(done int)) (map[string]ArchivedLog, error) {
	maxLine := s.MaxLineBytes
	if maxLine <= 0 {
		maxLine = DefaultMaxLineBytes
	}
	cache := loadCache(s.roots.Data)
	out := make(map[string]ArchivedLog, len(refs))
	for i, ref := range refs {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		entry, ok, err := s.entry(ctx, target{ref.Path, ref.CLI}, cache[ref.Path], maxLine)
		if err != nil {
			return nil, err
		}
		if ok {
			// The usage record decides: a log the scan counts is archived, with no tokens if only the fold failed.
			tokens, _, err := tokensOf(ctx, ref.Path, ref.CLI)
			if err != nil {
				return nil, err
			}
			out[ref.Path] = ArchivedLog{file: entry, Tokens: tokens}
		}
		if progress != nil {
			progress(i + 1)
		}
	}
	return out, nil
}

// StampOf is the stamp the scan and the archive use for the file at path, or false when it cannot be statted.
func StampOf(path string) (string, bool) {
	info, err := os.Stat(path)
	if err != nil {
		return "", false
	}
	return strconv.FormatInt(info.Size(), 10) + ":" + strconv.FormatInt(info.ModTime().UnixMilli(), 10), true
}

// loadArchive reads the archive. A missing file is empty; anything else that cannot be read whole is an error.
func loadArchive(dataDir string) (map[string]ArchivedLog, error) {
	path := ArchivePath(dataDir)
	if _, err := os.Lstat(path); err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return map[string]ArchivedLog{}, nil
		}
		return nil, errArchiveUnreadable()
	}
	var data []byte
	err := logs.ForEachChunk(path, func(chunk []byte) error {
		if len(data)+len(chunk) > maxArchiveBytes {
			return errCacheTooLarge
		}
		data = append(data, chunk...)
		return nil
	})
	if err != nil {
		return nil, errArchiveUnreadable()
	}
	var doc archiveJSON
	if json.Unmarshal(data, &doc) != nil || doc.V != archiveVersion || doc.Logs == nil {
		return nil, errArchiveUnreadable()
	}
	out := make(map[string]ArchivedLog, len(doc.Logs))
	for key, a := range doc.Logs {
		if a.CLI != Claude && a.CLI != Codex {
			return nil, errArchiveUnreadable()
		}
		rec := a.Rec
		if rec.Skill == nil {
			rec.Skill = map[string][]string{}
		}
		if rec.Agent == nil {
			rec.Agent = map[string][]string{}
		}
		if rec.Hook == nil {
			rec.Hook = map[string]HookTotals{}
		}
		if rec.HookDays == nil {
			rec.HookDays = map[string]HookDays{}
		}
		out[key] = ArchivedLog{file: cachedFile{V: a.V, Stamp: a.Stamp, CLI: a.CLI, Session: a.Session, First: a.First, Rec: rec}, Tokens: a.Tokens}
	}
	return out, nil
}

func errArchiveUnreadable() error {
	return coreerr.NewStatus(ArchiveUnreadableMessage, coreerr.StatusConflict)
}

func writeArchive(dataDir string, records map[string]ArchivedLog) error {
	doc := archiveJSON{V: archiveVersion, Logs: make(map[string]archivedJSON, len(records))}
	for key, a := range records {
		tokens := a.Tokens
		if tokens == nil {
			tokens = []ModelTokens{}
		}
		doc.Logs[key] = archivedJSON{V: a.file.V, Stamp: a.file.Stamp, CLI: a.file.CLI, Session: a.file.Session, First: a.file.First, Rec: a.file.Rec, Tokens: tokens}
	}
	data, err := json.Marshal(doc)
	if err != nil {
		return coreerr.NewStatus("Could not write the usage archive.", coreerr.StatusInternalFailure)
	}
	if err := fsx.MkdirAll(dataDir, 0o700); err != nil {
		return err
	}
	return fsx.AtomicWrite(ArchivePath(dataDir), data, 0o600, fsx.AtomicWriteOptions{})
}

// AddToArchive adds records (a key already there is replaced) in one atomic write. The caller holds the write lock.
func AddToArchive(dataDir string, records map[string]ArchivedLog) error {
	if len(records) == 0 {
		return nil
	}
	all, err := loadArchive(dataDir)
	if err != nil {
		return err
	}
	for key, a := range records {
		all[key] = a
	}
	return writeArchive(dataDir, all)
}

// RemoveFromArchive removes the records of paths in one atomic write and returns what it removed, so a failed Undo
// can put them back. A path with no record is skipped. The caller holds the write lock.
func RemoveFromArchive(dataDir string, paths []string) (map[string]ArchivedLog, error) {
	all, err := loadArchive(dataDir)
	if err != nil {
		return nil, err
	}
	removed := map[string]ArchivedLog{}
	for _, p := range paths {
		if a, ok := all[p]; ok {
			removed[p] = a
			delete(all, p)
		}
	}
	if len(removed) == 0 {
		return removed, nil
	}
	return removed, writeArchive(dataDir, all)
}

// ArchivedPaths lists the paths the archive holds, sorted; an unreadable archive is an error.
func ArchivedPaths(dataDir string) ([]string, error) {
	all, err := loadArchive(dataDir)
	if err != nil {
		return nil, err
	}
	out := make([]string, 0, len(all))
	for p := range all {
		out = append(out, p)
	}
	sort.Strings(out)
	return out, nil
}

// withArchive adds to the scanned records every archived log whose path is not a live log of this scan, and returns
// how many it added. An archive that cannot be read adds nothing: the scan still answers, and Clean refuses to write
// until the file is fixed.
func withArchive(next map[string]cachedFile, live map[string]bool, dataDir string) (map[string]cachedFile, int) {
	archived, err := loadArchive(dataDir)
	if err != nil || len(archived) == 0 {
		return next, 0
	}
	merged := make(map[string]cachedFile, len(next)+len(archived))
	for k, v := range next {
		merged[k] = v
	}
	added := 0
	for path, a := range archived {
		if live[path] {
			continue
		}
		merged[path] = a.file
		added++
	}
	return merged, added
}
