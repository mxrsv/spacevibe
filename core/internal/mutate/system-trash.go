package mutate

import (
	"context"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"

	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/fsx"
	"spacevibe.dev/core/internal/usage"
)

// Clean's move to the macOS Trash (clean.move, CL-R5; docs/internals/clean.md). Logs and caches leave their CLI folder
// for the Trash, never for SpaceVibe's own trash, and nothing is ever copied: every step is a rename on one volume.
//
// The core can rename into ~/.Trash, Lstat a name it knows and rename back out, without Full Disk Access; it cannot
// list the Trash (plan RB-T0 (b)). So the files go first into a staging folder <data>/clean/<slot>, keeping their path
// under the CLI root (<staging>/<cli>/<rel>), and the whole folder is renamed into the Trash at the end as one item,
// "SpaceVibe Clean <date>", under a name picked free by Lstat. Undo renames that folder back to the staging path, then
// each file back to where it was. Only proven operations touch the Trash: one rename in, one rename out.
//
// The list of what a move takes lives in <data>/clean/<slot>.json (clean-list.go), written before the first rename, so
// the journal entry stays small and a core that dies part way leaves enough on disk to put every file back.

const (
	cleanStagingName   = "clean"
	trashFolderPrefix  = "SpaceVibe Clean "
	maxTrashNameTries  = 1000
	opSystemTrashMoved = "system-trash-moved"
	opUsageArchived    = "usage-archived"
)

// TrashFile is one path clean.move takes: a session log (or its compressed twin), or one entry directly inside an
// allowlisted cache folder.
type TrashFile struct {
	// Group is the selection row it belongs to: "logs:<cli>" or a cache id.
	Group string
	// CLI is the registry id of the CLI whose root holds it.
	CLI string
	// Rel is the path under that CLI's root, clean and relative.
	Rel string
	// Log is true for a session log: it must still be a regular file, and when Archive is set its stamp must still be
	// the one that record was read at.
	Log bool
	// Archive is the usage record of a log (CL-R3); nil for a cache entry, a twin or a log that could not be read.
	Archive *usage.ArchivedLog
}

// TrashPlan is one clean.move: the files in move order, and the journal label of what did move, per group.
type TrashPlan struct {
	Files []TrashFile
	Label func(moved map[string]TrashAmount) string
}

// TrashProgress is sent after each path; Bytes is what has moved so far.
type TrashProgress struct {
	Done, Total int
	Bytes       int64
}

// TrashAmount counts files (or cache entries) and their allocated bytes.
type TrashAmount struct {
	Files int   `json:"files"`
	Bytes int64 `json:"bytes"`
}

// TrashOutcome is what a move did, per group.
type TrashOutcome struct {
	Entry     *EntryRef
	Moved     map[string]TrashAmount
	Stayed    map[string]int
	Reasons   map[string]string
	Trash     string
	Cancelled bool
}

func (o *TrashOutcome) stay(group, reason string) {
	o.Stayed[group]++
	if _, ok := o.Reasons[group]; !ok {
		o.Reasons[group] = reason
	}
}

// cliRoot is the root of a registry CLI id, or "" for any other id.
func (tx *Tx) cliRoot(cli string) string {
	switch cli {
	case "claude":
		return tx.r.Claude.Root
	case "codex":
		return tx.r.Codex.Root
	}
	return ""
}

// validRel is a clean, relative path with no ".." segment, never empty or ".".
func validRel(rel string) bool {
	if rel == "" || rel == "." || filepath.IsAbs(rel) || filepath.Clean(rel) != rel {
		return false
	}
	return !slices.Contains(strings.Split(rel, string(filepath.Separator)), "..")
}

// mkdirBelow makes the missing folders between root and the entry at rel (0700), one level at a time, and refuses a
// link or a file on the way, so a put-back never creates a folder through a link (CL-R7).
func mkdirBelow(root, rel string) error {
	if filepath.Dir(rel) == "." {
		return nil
	}
	dir := root
	for _, part := range strings.Split(filepath.Dir(rel), string(filepath.Separator)) {
		dir = filepath.Join(dir, part)
		info, err := os.Lstat(dir)
		if errors.Is(err, fs.ErrNotExist) {
			if err := fsx.MkdirExclusive(dir, 0o700); err != nil {
				return err
			}
			continue
		}
		if err != nil || !info.IsDir() || info.Mode()&fs.ModeSymlink != 0 {
			return fail(dir+" is not a plain folder, so nothing was put back below it.", coreerr.StatusConflict)
		}
	}
	return nil
}

// move is the state of one MoveToSystemTrash, kept so a failure at the end can put everything back.
type move struct {
	tx      *Tx
	slot    string
	staging string
	list    string
	// added are the archive keys this call wrote, the only ones it may remove again (H1: another core may have
	// archived the same paths).
	added map[string]bool
	moved map[string][]string
	dirs  map[string]bool
}

// MoveToSystemTrash is clean.move's write: lock, every check that can refuse the whole call, the list of what will
// move, the archive records this call adds, the moves one by one (ctx is looked at before each path, so a cancel stops
// before the next file), the rename of the staging folder into the Trash, and one journal entry. A cancel before the
// first path moved changes nothing and returns ctx's error.
func MoveToSystemTrash(ctx context.Context, tx *Tx, plan TrashPlan, progress func(TrashProgress)) (TrashOutcome, error) {
	out := TrashOutcome{Moved: map[string]TrashAmount{}, Stayed: map[string]int{}, Reasons: map[string]string{}}
	if err := tx.PrepareMutation(); err != nil {
		return out, err
	}
	if len(plan.Files) == 0 {
		return out, fail("Nothing is left to move. Scan again.", coreerr.StatusConflict)
	}
	clis := map[string]bool{}
	for _, f := range plan.Files {
		if tx.cliRoot(f.CLI) == "" || !validRel(f.Rel) {
			return out, fail("A path to move is not inside a CLI folder.", coreerr.StatusBadRequest)
		}
		clis[f.CLI] = true
	}
	if err := tx.ensureSystemTrash(); err != nil {
		return out, err
	}
	volumes := []string{tx.r.Trash, tx.r.Data}
	for _, cli := range keysInOrder(clis) {
		volumes = append(volumes, tx.cliRoot(cli))
	}
	same, err := fsx.SameVolume(volumes...)
	if err != nil {
		return out, err
	}
	if !same {
		return out, fail("The CLI folder, the SpaceVibe data folder and the Trash are not on one volume, so nothing was moved.", coreerr.StatusConflict)
	}

	// Owner check (H1): a record already in the archive belongs to whoever wrote it; this call adds only the others.
	present, err := usage.ArchivedPaths(tx.r.Data)
	if err != nil {
		return out, err
	}
	have := make(map[string]bool, len(present))
	for _, p := range present {
		have[p] = true
	}
	m := &move{tx: tx, added: map[string]bool{}, moved: map[string][]string{}, dirs: map[string]bool{}}
	records := map[string]usage.ArchivedLog{}
	for _, f := range plan.Files {
		path := filepath.Join(tx.cliRoot(f.CLI), f.Rel)
		if f.Archive != nil && !have[path] {
			records[path] = *f.Archive
			m.added[path] = true
		}
	}
	if m.slot, err = tx.newSlotName(); err != nil {
		return out, err
	}
	m.staging = filepath.Join(tx.stagingRoot(), m.slot)
	m.list = m.staging + cleanListSuffix
	// The intent comes first: a core that dies from here on leaves the list beside the staging folder (M1).
	if err := tx.writeCleanList(m.list, plannedGroups(tx, plan.Files), keysInOrder(m.added)); err != nil {
		return out, err
	}
	if err := usage.AddToArchive(tx.r.Data, records); err != nil {
		_ = fsx.RemoveFile(m.list)
		return out, err
	}
	if err := fsx.MkdirExclusive(m.staging, 0o700); err != nil {
		return out, m.undoStart(err)
	}

	var bytes int64
	var firstErr error
	for i, f := range plan.Files {
		if ctx.Err() != nil {
			out.Cancelled = true
			for _, rest := range plan.Files[i:] {
				out.stay(rest.Group, "The move was cancelled before this file.")
			}
			break
		}
		size, err := m.moveOne(f)
		if err != nil {
			if firstErr == nil {
				firstErr = err
			}
			out.stay(f.Group, safeMessage(err))
		} else {
			m.moved[f.CLI] = append(m.moved[f.CLI], f.Rel)
			amount := out.Moved[f.Group]
			amount.Files++
			amount.Bytes += size
			out.Moved[f.Group] = amount
			bytes += size
		}
		if progress != nil {
			progress(TrashProgress{Done: i + 1, Total: len(plan.Files), Bytes: bytes})
		}
	}
	fsx.SyncDirs(m.dirs)

	if len(m.moved) == 0 {
		cause := firstErr
		if out.Cancelled {
			cause = ctx.Err()
		}
		return out, m.undoStart(cause)
	}
	// The records of logs that stayed go again: only the ones this call added.
	gone := map[string]bool{}
	for cli, rels := range m.moved {
		for _, rel := range rels {
			gone[filepath.Join(tx.cliRoot(cli), rel)] = true
		}
	}
	var unmoved, kept []string
	for path := range m.added {
		if gone[path] {
			kept = append(kept, path)
		} else {
			unmoved = append(unmoved, path)
		}
	}
	slices.Sort(unmoved)
	slices.Sort(kept)
	if _, err := usage.RemoveFromArchive(tx.r.Data, unmoved); err != nil {
		return out, m.unstage(err)
	}
	for _, p := range unmoved {
		delete(m.added, p)
	}
	if err := tx.writeCleanList(m.list, movedGroups(tx, m.moved), kept); err != nil {
		return out, m.unstage(err)
	}
	trash, err := tx.freeTrashName(time.Now())
	if err == nil {
		err = fsx.RenameSameVolume(m.staging, trash)
	}
	if err != nil {
		return out, m.unstage(err)
	}
	ops := []Op{}
	if len(kept) > 0 {
		ops = append(ops, usageArchived(usage.ArchivePath(tx.r.Data), m.list))
	}
	ops = append(ops, systemTrashMoved(trash, m.staging, m.list))
	entry, err := tx.RecordMutation(plan.Label(out.Moved), ops)
	if err != nil {
		return out, err
	}
	ref := entry.Ref()
	out.Entry = &ref
	out.Trash = trash
	return out, nil
}

// moveOne checks one path again right before it moves and renames it into the staging folder. It returns the allocated
// bytes that left the CLI folder.
func (m *move) moveOne(f TrashFile) (int64, error) {
	root := m.tx.cliRoot(f.CLI)
	from, to := filepath.Join(root, f.Rel), filepath.Join(m.staging, f.CLI, f.Rel)
	if err := fsx.PlainFoldersBelow(root, f.Rel); err != nil {
		return 0, err
	}
	info, err := os.Lstat(from)
	if err != nil {
		return 0, fail(from+" is gone, so it was skipped.", coreerr.StatusNotFound)
	}
	if f.Log {
		if !info.Mode().IsRegular() {
			return 0, fail(from+" is not a plain file, so it was left in place.", coreerr.StatusConflict)
		}
		if f.Archive != nil {
			if stamp, ok := usage.StampOf(from); !ok || stamp != f.Archive.Stamp() {
				return 0, fail(from+" changed after it was read, so it was left in place.", coreerr.StatusConflict)
			}
		}
	}
	size := fsx.AllocatedBytes(info)
	if info.IsDir() {
		u, err := fsx.DiskUsage(from)
		if err != nil {
			return 0, err
		}
		size = u.Bytes
	}
	if err := fsx.MkdirAll(filepath.Dir(to), 0o700); err != nil {
		return 0, err
	}
	if err := fsx.RenameSameVolumeNoSync(from, to); err != nil {
		return 0, err
	}
	m.dirs[filepath.Dir(from)] = true
	m.dirs[filepath.Dir(to)] = true
	return size, nil
}

// undoStart ends a move that moved nothing: the records it added and the list go, the empty staging folder goes.
func (m *move) undoStart(cause error) error {
	added := keysInOrder(m.added)
	if _, err := usage.RemoveFromArchive(m.tx.r.Data, added); err != nil {
		return chain(coreerr.NewStatus(RollbackFailureMessage, coreerr.StatusInternalFailure), errors.Join(cause, err))
	}
	m.tx.dropStaging(m.staging)
	_ = fsx.RemoveFile(m.list)
	return cause
}

// unstage puts every staged file back (its missing folders made again, never through a link) and drops the archive
// records this call added, after a step that ends the move failed. cause is returned, or the rollback sentence when a
// put-back failed too.
func (m *move) unstage(cause error) error {
	var failures []error
	for _, cli := range keysInOrder(m.moved) {
		root := m.tx.cliRoot(cli)
		for _, rel := range m.moved[cli] {
			err := mkdirBelow(root, rel)
			if err == nil {
				err = fsx.RenameSameVolume(filepath.Join(m.staging, cli, rel), filepath.Join(root, rel))
			}
			if err != nil {
				failures = append(failures, err)
			}
		}
	}
	if _, err := usage.RemoveFromArchive(m.tx.r.Data, keysInOrder(m.added)); err != nil {
		failures = append(failures, err)
	}
	m.tx.dropStaging(m.staging)
	if len(failures) > 0 {
		return chain(coreerr.NewStatus(RollbackFailureMessage, coreerr.StatusInternalFailure), errors.Join(append([]error{cause}, failures...)...))
	}
	_ = fsx.RemoveFile(m.list)
	return cause
}

// ensureSystemTrash checks that the Trash folder exists and is a folder. The stand-in under SPACEVIBE_TEST=1 lives in
// the data folder and is made when missing; the real ~/.Trash is never created by the core.
func (tx *Tx) ensureSystemTrash() error {
	info, err := os.Lstat(tx.r.Trash)
	if err == nil && info.IsDir() {
		return nil
	}
	if err != nil && errors.Is(err, fs.ErrNotExist) && filepath.Dir(tx.r.Trash) == filepath.Clean(tx.r.Data) {
		return fsx.MkdirAll(tx.r.Trash, 0o700)
	}
	return fail("The Trash folder "+tx.r.Trash+" was not found, so nothing was moved.", coreerr.StatusConflict)
}

// dropStaging removes the folders of a staging tree that hold nothing; any file left inside keeps its folder.
func (tx *Tx) dropStaging(staging string) {
	var dirs []string
	_ = filepath.WalkDir(staging, func(p string, d fs.DirEntry, err error) error {
		if err == nil && d.IsDir() {
			dirs = append(dirs, p)
		}
		return nil
	})
	for _, d := range slices.Backward(dirs) {
		_ = fsx.RemoveEmptyDir(d)
	}
}

// freeTrashName is the first "SpaceVibe Clean <date>[ n]" that nothing in the Trash holds, found by Lstat alone (the
// Trash cannot be listed without Full Disk Access).
func (tx *Tx) freeTrashName(now time.Time) (string, error) {
	base := trashFolderPrefix + now.Format("2006-01-02 15.04.05")
	for n := 1; n <= maxTrashNameTries; n++ {
		name := base
		if n > 1 {
			name += " " + strconv.Itoa(n)
		}
		path := filepath.Join(tx.r.Trash, name)
		if _, err := os.Lstat(path); errors.Is(err, fs.ErrNotExist) {
			return path, nil
		}
	}
	return "", fail("No free name was found in the Trash, so nothing was moved.", coreerr.StatusConflict)
}

// safeMessage is the coreerr sentence of err, or a fixed one.
func safeMessage(err error) string {
	if e, ok := coreerr.As(err); ok {
		return e.Message
	}
	return "A file could not be moved."
}

func keysInOrder[V any](m map[string]V) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	slices.Sort(out)
	return out
}
