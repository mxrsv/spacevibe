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

// The two op kinds of clean.move and their Undo:
//
//   - usage-archived {file, logs}: file is <data>/usage-archive.json, logs the original paths whose records the move
//     added. Undo removes exactly those records, so a log that comes back is counted once (CL-R3).
//   - system-trash-moved {trash, staging, groups: [{cli, root, files}]}: trash is the folder the move left in the
//     Trash, staging the path it was built at, files the paths under root. File <rel> of CLI <cli> sits at
//     <trash>/<cli>/<rel>. Undo renames trash back to staging, then every file back to <root>/<rel>.

func usageArchived(file string, logs []string) Op {
	items := make([]ojson.Value, len(logs))
	for i, l := range logs {
		items[i] = ojson.String(l)
	}
	return Op{ojson.Object(member("type", ojson.String(opUsageArchived)), member("file", ojson.String(file)), member("logs", ojson.Array(items...)))}
}

func systemTrashMoved(trash, staging string, tx *Tx, moved map[string][]string) Op {
	var groups []ojson.Value
	for _, cli := range keysInOrder(moved) {
		files := make([]ojson.Value, len(moved[cli]))
		for i, rel := range moved[cli] {
			files[i] = ojson.String(rel)
		}
		groups = append(groups, ojson.Object(member("cli", ojson.String(cli)), member("root", ojson.String(tx.cliRoot(cli))), member("files", ojson.Array(files...))))
	}
	return Op{ojson.Object(member("type", ojson.String(opSystemTrashMoved)), member("trash", ojson.String(trash)),
		member("staging", ojson.String(staging)), member("groups", ojson.Array(groups...)))}
}

// trashGroup is one CLI's files of a system-trash-moved op.
type trashGroup struct {
	cli, root string
	files     []string
}

type trashMove struct {
	trash, staging string
	groups         []trashGroup
}

func (m trashMove) staged(g trashGroup, rel string) string {
	return filepath.Join(m.staging, g.cli, rel)
}

func stringsOf(v ojson.Value) ([]string, bool) {
	items, ok := v.ArrayValue()
	if !ok {
		return nil, false
	}
	out := make([]string, 0, len(items))
	for _, item := range items {
		s, ok := item.StringValue()
		if !ok {
			return nil, false
		}
		out = append(out, s)
	}
	return out, true
}

// parseTrashMove reads the op; a missing or mistyped field is the unknown-entry 400.
func parseTrashMove(op Op) (trashMove, error) {
	bad := fail(unknownEntryMessage, coreerr.StatusBadRequest)
	trash, ok1 := op.str("trash")
	staging, ok2 := op.str("staging")
	groupsValue, ok3 := op.JSON.Member("groups")
	items, ok4 := groupsValue.ArrayValue()
	if !ok1 || !ok2 || !ok3 || !ok4 {
		return trashMove{}, bad
	}
	m := trashMove{trash: trash, staging: staging}
	for _, item := range items {
		g := Op{item}
		cli, ok1 := g.str("cli")
		root, ok2 := g.str("root")
		filesValue, ok3 := item.Member("files")
		files, ok4 := stringsOf(filesValue)
		if !ok1 || !ok2 || !ok3 || !ok4 {
			return trashMove{}, bad
		}
		m.groups = append(m.groups, trashGroup{cli: cli, root: root, files: files})
	}
	return m, nil
}

// checkTrashMove is the containment rule of the op (journal.json is user-editable): the Trash folder is a direct child
// of the Trash with the SpaceVibe Clean prefix, staging a direct child of <data>/clean, every root the root of its CLI
// now, every file a clean relative path.
func (c *containment) checkTrashMove(op Op) error {
	bad := fail(outsideManagedMessage, coreerr.StatusBadRequest)
	m, err := parseTrashMove(op)
	if err != nil {
		return err
	}
	trash, ok1 := absoluteClean(m.trash)
	staging, ok2 := absoluteClean(m.staging)
	if !ok1 || !ok2 || !slices.Contains(spellings(c.r.Trash), filepath.Dir(trash)) || !strings.HasPrefix(filepath.Base(trash), trashFolderPrefix) ||
		!slices.Contains(spellings(filepath.Join(c.r.Data, cleanStagingName)), filepath.Dir(staging)) {
		return bad
	}
	tx := &Tx{r: c.r}
	for _, g := range m.groups {
		root := tx.cliRoot(g.cli)
		if root == "" || filepath.Clean(g.root) != filepath.Clean(root) {
			return bad
		}
		for _, rel := range g.files {
			if !validRel(rel) {
				return bad
			}
		}
	}
	return nil
}

// checkUsageArchived: file is this data folder's archive, every log inside a CLI root.
func (c *containment) checkUsageArchived(op Op) error {
	bad := fail(outsideManagedMessage, coreerr.StatusBadRequest)
	file, ok := op.str("file")
	logsValue, has := op.JSON.Member("logs")
	logs, ok2 := stringsOf(logsValue)
	if !ok || !has || !ok2 {
		return fail(unknownEntryMessage, coreerr.StatusBadRequest)
	}
	if clean, ok := absoluteClean(file); !ok || clean != filepath.Clean(usage.ArchivePath(c.r.Data)) {
		return bad
	}
	roots := append(spellings(c.r.Claude.Root), spellings(c.r.Codex.Root)...)
	for _, l := range logs {
		clean, ok := absoluteClean(l)
		if !ok || !inside(roots, clean) {
			return bad
		}
	}
	return nil
}

// undoUsageArchived removes the records the move added; the put-back adds them again.
func (tx *Tx) undoUsageArchived(op Op) (putBack, error) {
	logsValue, _ := op.JSON.Member("logs")
	logs, ok := stringsOf(logsValue)
	if !ok {
		return nil, fail(unknownEntryMessage, coreerr.StatusBadRequest)
	}
	removed, err := usage.RemoveFromArchive(tx.r.Data, logs)
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
	info, err := os.Lstat(m.trash)
	if err != nil || !info.IsDir() || info.Mode()&fs.ModeSymlink != 0 {
		return nil, fail("The moved files are no longer in the Trash ("+filepath.Base(m.trash)+"), so nothing was put back.", coreerr.StatusConflict)
	}
	if pathExists(m.staging) {
		return nil, fail(m.staging+" already exists, so nothing was put back.", coreerr.StatusConflict)
	}
	for _, g := range m.groups {
		for _, rel := range g.files {
			if from := filepath.Join(g.root, rel); pathExists(from) {
				return nil, fail(from+" already exists again, so it was left alone.", coreerr.StatusConflict)
			}
		}
	}
	if err := fsx.RenameSameVolume(m.trash, m.staging); err != nil {
		return nil, err
	}
	toTrash := func() error { return fsx.RenameSameVolume(m.staging, m.trash) }
	for _, g := range m.groups {
		for _, rel := range g.files {
			if !pathExists(m.staged(g, rel)) {
				if berr := toTrash(); berr != nil {
					return nil, chain(coreerr.NewStatus(PartlyUndoneMessage, coreerr.StatusInternalFailure), berr)
				}
				return nil, fail(filepath.Join(g.root, rel)+" is gone from the Trash folder, so nothing was put back.", coreerr.StatusConflict)
			}
		}
	}
	type step struct{ from, staged string }
	var done []step
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
	for _, g := range m.groups {
		for _, rel := range g.files {
			from, staged := filepath.Join(g.root, rel), m.staged(g, rel)
			err := mkdirBelow(g.root, rel)
			if err == nil {
				err = fsx.RenameSameVolume(staged, from)
			}
			if err != nil {
				if berr := back(); berr != nil {
					return nil, chain(coreerr.NewStatus(PartlyUndoneMessage, coreerr.StatusInternalFailure), errors.Join(err, berr))
				}
				return nil, err
			}
			done = append(done, step{from, staged})
		}
	}
	tx.dropStaging(m.staging)
	return back, nil
}
