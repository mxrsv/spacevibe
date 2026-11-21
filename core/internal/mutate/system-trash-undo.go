package mutate

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/fsx"
	"spacevibe.dev/core/internal/ojson"
	"spacevibe.dev/core/internal/usage"
)

// The two op kinds of clean.move and their Undo. Both name the move's list (<data>/clean/<slot>.json, clean-list.go)
// instead of holding paths, so an entry stays a few hundred bytes however many files moved (M4):
//
//   - usage-archived {file, list}: file is <data>/usage-archive.json; the list's archived paths are the records this
//     move added. Undo removes exactly those, so a log that comes back is counted once (CL-R3).
//   - system-trash-moved {trash, staging, list}: trash is the folder the move left in the Trash, staging the path it was
//     built at, list = staging + ".json". File <rel> of group <cli> sits at <trash>/<cli>/<rel>. Undo renames trash back
//     to staging, then every file back to <root>/<rel>.

func usageArchived(file, list string) Op {
	return Op{ojson.Object(member("type", ojson.String(opUsageArchived)), member("file", ojson.String(file)), member("list", ojson.String(list)))}
}

func systemTrashMoved(trash, staging, list string) Op {
	return Op{ojson.Object(member("type", ojson.String(opSystemTrashMoved)), member("trash", ojson.String(trash)),
		member("staging", ojson.String(staging)), member("list", ojson.String(list)))}
}

type trashMove struct {
	trash, staging, list string
}

func (m trashMove) staged(g cleanListGroup, rel string) string {
	return filepath.Join(m.staging, g.CLI, rel)
}

// parseTrashMove reads the op; a missing field is the unknown-entry 400.
func parseTrashMove(op Op) (trashMove, error) {
	trash, ok1 := op.str("trash")
	staging, ok2 := op.str("staging")
	list, ok3 := op.str("list")
	if !ok1 || !ok2 || !ok3 {
		return trashMove{}, fail(unknownEntryMessage, coreerr.StatusBadRequest)
	}
	return trashMove{trash: trash, staging: staging, list: list}, nil
}

// checkTrashMove is the containment rule of the op (journal.json is user-editable): the Trash folder is a direct child
// of the Trash with the SpaceVibe Clean prefix, staging a direct child of <data>/clean named like a slot, the list that
// staging path plus ".json". The list's own paths are checked when it is read (readCleanList).
func (c *containment) checkTrashMove(op Op) error {
	bad := fail(outsideManagedMessage, coreerr.StatusBadRequest)
	m, err := parseTrashMove(op)
	if err != nil {
		return err
	}
	trash, ok1 := absoluteClean(m.trash)
	staging, ok2 := absoluteClean(m.staging)
	list, ok3 := absoluteClean(m.list)
	if !ok1 || !ok2 || !ok3 || !slices.Contains(spellings(c.r.Trash), filepath.Dir(trash)) || !strings.HasPrefix(filepath.Base(trash), trashFolderPrefix) ||
		!inDirectly(spellings(filepath.Join(c.r.Data, cleanStagingName)), filepath.Dir(staging)) || !cleanSlotPattern.MatchString(filepath.Base(staging)) ||
		list != staging+cleanListSuffix {
		return bad
	}
	return nil
}

// checkUsageArchived: file is this data folder's archive, the list a Clean list.
func (c *containment) checkUsageArchived(op Op) error {
	file, ok1 := op.str("file")
	list, ok2 := op.str("list")
	if !ok1 || !ok2 {
		return fail(unknownEntryMessage, coreerr.StatusBadRequest)
	}
	if clean, ok := absoluteClean(file); !ok || clean != filepath.Clean(usage.ArchivePath(c.r.Data)) || !c.cleanListPath(list) {
		return fail(outsideManagedMessage, coreerr.StatusBadRequest)
	}
	return nil
}

// undoUsageArchived removes the records the move added; the put-back adds them again.
func (tx *Tx) undoUsageArchived(op Op) (putBack, error) {
	list, ok := op.str("list")
	if !ok {
		return nil, fail(unknownEntryMessage, coreerr.StatusBadRequest)
	}
	l, err := tx.readCleanList(list)
	if err != nil {
		return nil, err
	}
	removed, err := usage.RemoveFromArchive(tx.r.Data, l.Archived)
	if err != nil {
		return nil, err
	}
	return func() error { return usage.AddToArchive(tx.r.Data, removed) }, nil
}

// undoSystemTrash brings the folder back from the Trash and every file back to where it was, all or nothing: a file
// whose place is taken again, or that is gone from the Trash folder, refuses the whole Undo with 409 and nothing stays
// changed.
func (tx *Tx) undoSystemTrash(op Op) (putBack, error) {
	m, err := parseTrashMove(op)
	if err != nil {
		return nil, err
	}
	l, err := tx.readCleanList(m.list)
	if err != nil {
		return nil, err
	}
	info, err := os.Lstat(m.trash)
	if err != nil || !info.IsDir() || info.Mode()&fs.ModeSymlink != 0 {
		return nil, fail("The moved files are no longer in the Trash ("+filepath.Base(m.trash)+"), so nothing was put back.", coreerr.StatusConflict)
	}
	if pathExists(m.staging) {
		return nil, fail(m.staging+" already exists, so nothing was put back.", coreerr.StatusConflict)
	}
	for _, g := range l.Groups {
		for _, rel := range g.Files {
			if from := filepath.Join(g.Root, rel); pathExists(from) {
				return nil, fail(from+" already exists again, so it was left alone.", coreerr.StatusConflict)
			}
		}
	}
	if err := fsx.RenameSameVolume(m.trash, m.staging); err != nil {
		return nil, err
	}
	toTrash := func() error { return fsx.RenameSameVolume(m.staging, m.trash) }
	for _, g := range l.Groups {
		for _, rel := range g.Files {
			if !pathExists(m.staged(g, rel)) {
				if berr := toTrash(); berr != nil {
					return nil, chain(coreerr.NewStatus(PartlyUndoneMessage, coreerr.StatusInternalFailure), berr)
				}
				return nil, fail(filepath.Join(g.Root, rel)+" is gone from the Trash folder, so nothing was put back.", coreerr.StatusConflict)
			}
		}
	}
	type step struct{ from, staged string }
	var done []step
	dirs := map[string]bool{}
	back := func() error {
		var failures []error
		for _, s := range slices.Backward(done) {
			if err := fsx.MkdirAll(filepath.Dir(s.staged), 0o700); err != nil {
				failures = append(failures, err)
				continue
			}
			if err := fsx.RenameSameVolume(s.from, s.staged); err != nil {
				failures = append(failures, err)
			}
		}
		if err := toTrash(); err != nil {
			failures = append(failures, err)
		}
		return errors.Join(failures...)
	}
	for _, g := range l.Groups {
		for _, rel := range g.Files {
			from, staged := filepath.Join(g.Root, rel), m.staged(g, rel)
			err := mkdirBelow(g.Root, rel)
			if err == nil {
				err = fsx.RenameSameVolumeNoSync(staged, from)
			}
			if err != nil {
				if berr := back(); berr != nil {
					return nil, chain(coreerr.NewStatus(PartlyUndoneMessage, coreerr.StatusInternalFailure), errors.Join(err, berr))
				}
				return nil, err
			}
			dirs[filepath.Dir(from)] = true
			done = append(done, step{from, staged})
		}
	}
	fsx.SyncDirs(dirs)
	tx.dropStaging(m.staging)
	return back, nil
}
