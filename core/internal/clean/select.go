package clean

import (
	"context"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"time"

	"spacevibe.dev/core/internal/activity"
	"spacevibe.dev/core/internal/fsx"
	"spacevibe.dev/core/internal/logs"
	"spacevibe.dev/core/internal/roots"
)

// The paths a move takes, found the same way by clean.scan and by clean.move, so the sizes the scan shows are the
// sizes of the exact paths the move renames (CL-R6).

// logFile is one session log under a CLI root, with the compressed twins that go with it (M3).
type logFile struct {
	rel   string
	mtime time.Time
	bytes int64
	twins []twin
}

// twin is a .jsonl.zst or .jsonl.zstd beside a plain .jsonl of the same session: logs.Walk lists only the plain one.
type twin struct {
	rel   string
	bytes int64
}

// cacheEntry is one entry directly inside an allowlisted cache folder.
type cacheEntry struct {
	rel string
	fsx.Usage
}

const day = 24 * time.Hour

// cliRoots is the roots of a registry CLI id; ok is false for any other id.
func cliRoots(r roots.Roots, cli string) (roots.CLIRoots, bool) {
	switch cli {
	case "claude":
		return r.Claude, true
	case "codex":
		return r.Codex, true
	}
	return roots.CLIRoots{}, false
}

// keptOut is a name Clean never moves even inside a folder it may move from: a memory folder, and a SQLite database
// with its journal files (CL-R2). logs.Walk lists neither; this is the second line.
func keptOut(rel string) bool {
	for _, part := range strings.Split(rel, string(filepath.Separator)) {
		if keptOutName(part) {
			return true
		}
	}
	return false
}

func keptOutName(name string) bool { return name == "memory" || strings.Contains(name, ".sqlite") }

// holdsKeptOut is true when anything at or below path (no link followed) is a memory folder or a SQLite file, or the
// tree cannot be read whole: such an entry is never offered nor moved (L3).
func holdsKeptOut(path string) bool {
	found := false
	err := filepath.WalkDir(path, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if keptOutName(d.Name()) {
			found = true
			return filepath.SkipAll
		}
		return nil
	})
	return found || err != nil
}

// liveRows are the Activity rows that still have a process (every state but ended), by CLI: their logs are never
// picked, an idle one included (L4).
func liveRows(report activity.Report) map[string]map[string]bool {
	out := map[string]map[string]bool{}
	for _, s := range report.Sessions {
		if s.State == activity.StateEnded || s.ID == "" {
			continue
		}
		cli := string(s.CLI)
		if out[cli] == nil {
			out[cli] = map[string]bool{}
		}
		out[cli][s.ID] = true
	}
	return out
}

// ofLiveRow is true for a log of a live row: a Claude transcript <id>.jsonl or anything under a folder named <id> (its
// subagents), a Codex rollout whose name ends in -<thread id>.
func ofLiveRow(rel string, live map[string]bool) bool {
	if len(live) == 0 {
		return false
	}
	base := logs.BaseName(rel)
	for id := range live {
		if base == id || strings.HasSuffix(base, "-"+id) {
			return true
		}
	}
	for _, part := range strings.Split(filepath.Dir(rel), string(filepath.Separator)) {
		if live[part] {
			return true
		}
	}
	return false
}

// sessionLogs lists the session logs of one CLI through logs.Walk only (CL-R2: .jsonl.zst included, nothing twice),
// keeping a log only when it is a regular file under the CLI root with no link on the way (CL-R7). state says whether
// the logs folder could be read at all.
func sessionLogs(ctx context.Context, cli roots.CLIRoots, live map[string]bool) ([]logFile, string, error) {
	if _, err := os.Lstat(cli.Logs); err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return nil, LogsMissing, nil
		}
		return nil, LogsUnreadable, nil
	}
	if _, err := os.ReadDir(cli.Logs); err != nil {
		return nil, LogsUnreadable, nil
	}
	var out []logFile
	for i, path := range logs.Walk(cli.Logs) {
		if i%256 == 0 {
			if err := ctx.Err(); err != nil {
				return nil, "", err
			}
		}
		rel, err := filepath.Rel(cli.Root, path)
		if err != nil || rel == "." || strings.HasPrefix(rel, "..") || keptOut(rel) || ofLiveRow(rel, live) {
			continue
		}
		if fsx.PlainFoldersBelow(cli.Root, rel) != nil {
			continue
		}
		info, err := os.Lstat(path)
		if err != nil || !info.Mode().IsRegular() {
			continue
		}
		f := logFile{rel: rel, mtime: info.ModTime(), bytes: fsx.AllocatedBytes(info)}
		if plain, ok := strings.CutSuffix(rel, ".jsonl"); ok {
			for _, suffix := range []string{".jsonl.zst", ".jsonl.zstd"} {
				if ti, err := os.Lstat(filepath.Join(cli.Root, plain+suffix)); err == nil && ti.Mode().IsRegular() {
					f.twins = append(f.twins, twin{rel: plain + suffix, bytes: fsx.AllocatedBytes(ti)})
				}
			}
		}
		out = append(out, f)
	}
	return out, LogsMeasured, nil
}

// olderThan keeps the logs last written more than days ago, in path order.
func olderThan(files []logFile, days int, now time.Time) []logFile {
	cut := now.Add(-time.Duration(days) * day)
	var out []logFile
	for _, f := range files {
		if f.mtime.Before(cut) {
			out = append(out, f)
		}
	}
	return out
}

// cacheEntries lists what sits directly in one allowlisted cache folder, each entry with its size. The folder must be
// a real folder under the CLI root, reached through no link; an entry that is a link is moved as a link, never followed.
func cacheEntries(ctx context.Context, root string, c Cache) ([]cacheEntry, error) {
	dir := filepath.Join(root, c.Rel)
	if fsx.PlainFoldersBelow(root, filepath.Join(c.Rel, "x")) != nil {
		return nil, nil
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, nil
	}
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		names = append(names, e.Name())
	}
	slices.Sort(names)
	var out []cacheEntry
	for _, name := range names {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		rel := filepath.Join(c.Rel, name)
		if keptOut(rel) || holdsKeptOut(filepath.Join(root, rel)) {
			continue
		}
		u, err := fsx.DiskUsage(filepath.Join(root, rel))
		if err != nil {
			continue
		}
		out = append(out, cacheEntry{rel: rel, Usage: u})
	}
	return out, nil
}
