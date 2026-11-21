package mutate

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/fsx"
	"spacevibe.dev/core/internal/ojson"
	"spacevibe.dev/core/internal/usage"
)

// The list of one Clean move, <data>/clean/<slot>.json beside its staging folder <data>/clean/<slot> (M4): which paths
// under which CLI root the move takes, and the archive records it added. The journal entry names the list instead of
// holding the paths, so journal.json stays small whatever a move takes. The list is written twice: as the intent before
// the first rename (every planned path, every record added), and as the result before the staging folder enters the
// Trash (the paths that moved, the records that stay).
//
// It is also what puts a crashed move back (M1): every write first runs recoverClean under the lock, and a staging
// folder that exists then belongs to a core that died part way (only a locked body ever holds one).

const (
	cleanListSuffix   = ".json"
	cleanListVersion  = 1
	maxCleanListBytes = 256 << 20
)

// cleanSlotPattern is the name of a staging folder; its list adds cleanListSuffix.
var cleanSlotPattern = regexp.MustCompile(`^([0-9]+)-[0-9a-f]{8}$`)

type cleanListGroup struct {
	CLI   string   `json:"cli"`
	Root  string   `json:"root"`
	Files []string `json:"files"`
}

type cleanList struct {
	V        int              `json:"v"`
	Groups   []cleanListGroup `json:"groups"`
	Archived []string         `json:"archived"`
}

func (tx *Tx) stagingRoot() string { return filepath.Join(tx.r.Data, cleanStagingName) }

// newSlotName is a fresh "<ms>-<8 hex>" in the staging root, made sure to exist.
func (tx *Tx) newSlotName() (string, error) {
	if err := fsx.MkdirAll(tx.stagingRoot(), 0o700); err != nil {
		return "", err
	}
	var b [4]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", fail("Could not create the staging folder.", coreerr.StatusInternalFailure)
	}
	return strconv.FormatInt(time.Now().UnixMilli(), 10) + "-" + hex.EncodeToString(b[:]), nil
}

func plannedGroups(tx *Tx, files []TrashFile) []cleanListGroup {
	byCLI := map[string][]string{}
	for _, f := range files {
		byCLI[f.CLI] = append(byCLI[f.CLI], f.Rel)
	}
	return movedGroups(tx, byCLI)
}

func movedGroups(tx *Tx, byCLI map[string][]string) []cleanListGroup {
	out := []cleanListGroup{}
	for _, cli := range keysInOrder(byCLI) {
		out = append(out, cleanListGroup{CLI: cli, Root: tx.cliRoot(cli), Files: byCLI[cli]})
	}
	return out
}

func (tx *Tx) writeCleanList(path string, groups []cleanListGroup, archived []string) error {
	if archived == nil {
		archived = []string{}
	}
	data, err := json.Marshal(cleanList{V: cleanListVersion, Groups: groups, Archived: archived})
	if err != nil {
		return fail("Could not write the list of the move.", coreerr.StatusInternalFailure)
	}
	return fsx.AtomicWrite(path, data, 0o600, fsx.AtomicWriteOptions{})
}

// readCleanList reads a list and checks every path in it the way Undo checks the journal: each root is the current
// root of its CLI, each file a clean relative path, each archived path inside a CLI root. Anything else is the
// outside-managed 400; a list that cannot be read is a 409.
func (tx *Tx) readCleanList(path string) (cleanList, error) {
	data, err := readRegular(path, maxCleanListBytes)
	if err != nil {
		return cleanList{}, fail("The list of the moved files ("+filepath.Base(path)+") is gone or cannot be read, so nothing was put back.", coreerr.StatusConflict)
	}
	var l cleanList
	if json.Unmarshal(data, &l) != nil || l.V != cleanListVersion {
		return cleanList{}, fail("The list of the moved files ("+filepath.Base(path)+") is gone or cannot be read, so nothing was put back.", coreerr.StatusConflict)
	}
	bad := fail(outsideManagedMessage, coreerr.StatusBadRequest)
	for _, g := range l.Groups {
		root := tx.cliRoot(g.CLI)
		if root == "" || filepath.Clean(g.Root) != filepath.Clean(root) {
			return cleanList{}, bad
		}
		for _, rel := range g.Files {
			if !validRel(rel) {
				return cleanList{}, bad
			}
		}
	}
	roots := append(spellings(tx.r.Claude.Root), spellings(tx.r.Codex.Root)...)
	for _, p := range l.Archived {
		clean, ok := absoluteClean(p)
		if !ok || !inside(roots, clean) {
			return cleanList{}, bad
		}
	}
	return l, nil
}

// cleanListPath is the rule for a list named by a journal op: a direct child of <data>/clean called <slot>.json.
func (c *containment) cleanListPath(p string) bool {
	clean, ok := absoluteClean(p)
	if !ok || !strings.HasSuffix(clean, cleanListSuffix) {
		return false
	}
	return cleanSlotPattern.MatchString(strings.TrimSuffix(filepath.Base(clean), cleanListSuffix)) &&
		inDirectly(spellings(filepath.Join(c.r.Data, cleanStagingName)), filepath.Dir(clean))
}

func inDirectly(folders []string, dir string) bool {
	for _, f := range folders {
		if f == dir {
			return true
		}
	}
	return false
}

// recoverClean puts back what a core that died part way through a Clean move or its Undo left in <data>/clean (M1). It
// runs under the write lock before every write body, so it never meets a move in progress: only a locked body holds a
// staging folder. Every staged path whose place is free goes back (its folders made again, never through a link), and
// every archive record of the list whose log is live again goes. A list with no staging folder that no journal entry
// names is dropped the same way. Best effort: what cannot be put back stays for the next write; with an unreadable
// journal nothing is touched.
func (tx *Tx) recoverClean() {
	items, err := os.ReadDir(tx.stagingRoot())
	if err != nil || len(items) == 0 {
		return
	}
	entries, err := entriesForWriting(tx.r)
	if err != nil {
		return
	}
	named := map[string]bool{}
	for _, e := range entries {
		for _, op := range e.Ops {
			if s, ok := op.str("list"); ok {
				named[filepath.Clean(s)] = true
			}
		}
	}
	dirs := map[string]bool{}
	for _, item := range items {
		if item.IsDir() && cleanSlotPattern.MatchString(item.Name()) {
			dirs[item.Name()] = true
		}
	}
	for name := range dirs {
		tx.restoreStaging(filepath.Join(tx.stagingRoot(), name))
	}
	for _, item := range items {
		name := strings.TrimSuffix(item.Name(), cleanListSuffix)
		list := filepath.Join(tx.stagingRoot(), item.Name())
		if item.IsDir() || name == item.Name() || !cleanSlotPattern.MatchString(name) || dirs[name] || named[list] {
			continue
		}
		if l, err := tx.readCleanList(list); err == nil {
			tx.dropLiveRecords(l.Archived)
		}
		_ = fsx.RemoveFile(list)
	}
}

// restoreStaging puts back one orphaned staging folder, from its list, or from its <cli>/<rel> layout without one.
func (tx *Tx) restoreStaging(staging string) {
	type item struct{ cli, rel string }
	var todo []item
	l, err := tx.readCleanList(staging + cleanListSuffix)
	if err == nil {
		for _, g := range l.Groups {
			for _, rel := range g.Files {
				todo = append(todo, item{g.CLI, rel})
			}
		}
	} else {
		for _, cli := range []string{"claude", "codex"} {
			base := filepath.Join(staging, cli)
			_ = filepath.WalkDir(base, func(p string, d fs.DirEntry, err error) error {
				if err != nil || d.IsDir() {
					return nil
				}
				if rel, err := filepath.Rel(base, p); err == nil && validRel(rel) {
					todo = append(todo, item{cli, rel})
				}
				return nil
			})
		}
	}
	for _, it := range todo {
		root := tx.cliRoot(it.cli)
		staged, from := filepath.Join(staging, it.cli, it.rel), filepath.Join(root, it.rel)
		if !pathExists(staged) || pathExists(from) {
			continue
		}
		if mkdirBelow(root, it.rel) == nil {
			_ = fsx.RenameSameVolume(staged, from)
		}
	}
	tx.dropLiveRecords(l.Archived)
	tx.dropStaging(staging)
}

// dropLiveRecords removes the archive records of paths whose log is in place again: a live log counts by itself.
func (tx *Tx) dropLiveRecords(paths []string) {
	var live []string
	for _, p := range paths {
		if pathExists(p) {
			live = append(live, p)
		}
	}
	if len(live) > 0 {
		_, _ = usage.RemoveFromArchive(tx.r.Data, live)
	}
}

// pruneCleanLists ends the lists of the entries the journal just dropped, and sweeps lists older than JournalMaxAge
// that no kept entry names. A list beside a staging folder is left for recoverClean. Like the trash sweep, it runs
// after the journal is written and is best effort.
func (tx *Tx) pruneCleanLists(kept, cut []Entry, now time.Time) {
	listsOf := func(entries []Entry) map[string]bool {
		out := map[string]bool{}
		walkStrings(entries, func(s string) { out[filepath.Clean(s)] = true })
		return out
	}
	referenced, dropped := listsOf(kept), listsOf(cut)
	items, err := os.ReadDir(tx.stagingRoot())
	if err != nil {
		return
	}
	for _, item := range items {
		name := strings.TrimSuffix(item.Name(), cleanListSuffix)
		match := cleanSlotPattern.FindStringSubmatch(name)
		path := filepath.Join(tx.stagingRoot(), item.Name())
		if item.IsDir() || name == item.Name() || match == nil || referenced[path] || pathExists(filepath.Join(tx.stagingRoot(), name)) {
			continue
		}
		ms, _ := strconv.ParseInt(match[1], 10, 64)
		if dropped[path] || now.Sub(time.UnixMilli(ms)) > JournalMaxAge {
			_ = fsx.RemoveFile(path)
		}
	}
}

// walkStrings calls fn with every string inside every op of entries.
func walkStrings(entries []Entry, fn func(string)) {
	var walk func(v ojson.Value)
	walk = func(v ojson.Value) {
		if s, ok := v.StringValue(); ok {
			fn(s)
		}
		if items, ok := v.ArrayValue(); ok {
			for _, item := range items {
				walk(item)
			}
		}
		if members, ok := v.ObjectValue(); ok {
			for _, m := range members {
				walk(m.Value)
			}
		}
	}
	for _, e := range entries {
		for _, op := range e.Ops {
			walk(op.JSON)
		}
	}
}
