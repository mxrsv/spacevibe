package clean

import (
	"context"
	"errors"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	"spacevibe.dev/core/internal/activity"
	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/fsx"
	"spacevibe.dev/core/internal/inventory"
	"spacevibe.dev/core/internal/mutate"
	"spacevibe.dev/core/internal/roots"
	"spacevibe.dev/core/internal/usage"
)

// progressEvery is how many paths go between two clean/progress notifications (one more is sent at the end).
const progressEvery = 20

// errNoProcessList is the answer when no process lister was given: unknown, so the caches lock.
var errNoProcessList = errors.New("no process list")

// clis are the CLIs Clean covers, in registry order (RD42).
var clis = []string{"claude", "codex"}

// Service is clean.scan and clean.move over one set of roots.
type Service struct {
	roots roots.Roots
	usage *usage.Scanner
	// activity reads the Activity report the locks come from; measurable is the process adapter's Measurable.
	activity   func(context.Context) (activity.Report, error)
	measurable bool
	// processes lists the live processes of each CLI by registry id, every one the adapter sees (RD35); an error
	// means the list is unknown, which locks the caches.
	processes func(context.Context) (map[string][]int, error)
	// Now is the clock the ages are measured against; tests may replace it.
	Now func() time.Time

	// moving is set while a clean.move of this core runs; a second one is refused (H1).
	mu     sync.Mutex
	moving bool
}

// NewService builds the service. report is activity.Service.Read; processes lists every live process of each CLI
// (proc.ProcessLister); measurable is false where no process can be seen, which locks every log and cache.
func NewService(r roots.Roots, scanner *usage.Scanner, report func(context.Context) (activity.Report, error),
	processes func(context.Context) (map[string][]int, error), measurable bool) *Service {
	return &Service{roots: r, usage: scanner, activity: report, processes: processes, measurable: measurable, Now: time.Now}
}

// lockState is one reading of the locks, and the live Activity rows whose logs are never picked (L4).
type lockState struct {
	locks map[string]Locks
	live  map[string]map[string]bool
}

func (s *Service) locks(ctx context.Context) (lockState, error) {
	report, err := s.activity(ctx)
	if cerr := ctx.Err(); cerr != nil {
		return lockState{}, cerr
	}
	input := lockInput{report: report, readFailed: err != nil, measurable: s.measurable}
	if s.processes == nil {
		input.processErr = errNoProcessList
	} else {
		input.processes, input.processErr = s.processes(ctx)
		if cerr := ctx.Err(); cerr != nil {
			return lockState{}, cerr
		}
	}
	out := lockState{locks: map[string]Locks{}, live: liveRows(report)}
	for _, cli := range clis {
		out.locks[cli] = lockFor(input, s.roots, cli)
	}
	return out, nil
}

// Scan is clean.scan. It reads and writes nothing but the Activity read behind the locks.
func (s *Service) Scan(ctx context.Context) (ScanResult, error) {
	state, err := s.locks(ctx)
	if err != nil {
		return ScanResult{}, err
	}
	now := s.Now()
	result := ScanResult{CLIs: []CLIScan{}, Items: []ItemSize{}}
	for _, cli := range clis {
		r, _ := cliRoots(s.roots, cli)
		files, logState, err := sessionLogs(ctx, r, state.live[cli])
		if err != nil {
			return ScanResult{}, err
		}
		scan := CLIScan{CLI: cli, Logs: LogScan{State: logState, Buckets: []LogBucket{}}, Caches: []CacheScan{}, Locks: state.locks[cli]}
		for _, age := range Ages {
			bucket := LogBucket{OlderThanDays: age}
			for _, f := range olderThan(files, age, now) {
				bucket.Files += 1 + len(f.twins)
				bucket.Bytes += f.bytes
				for _, tw := range f.twins {
					bucket.Bytes += tw.bytes
				}
			}
			if bucket.Files > 0 {
				scan.Logs.Buckets = append(scan.Logs.Buckets, bucket)
			}
		}
		for _, c := range allowlist {
			if c.CLI != cli {
				continue
			}
			entries, err := cacheEntries(ctx, r.Root, c)
			if err != nil {
				return ScanResult{}, err
			}
			if len(entries) == 0 {
				continue
			}
			cs := CacheScan{ID: c.ID, Path: filepath.Join(r.Root, c.Rel), Entries: len(entries)}
			for _, e := range entries {
				cs.Files += e.Files
				cs.Bytes += e.Bytes
			}
			scan.Caches = append(scan.Caches, cs)
		}
		result.CLIs = append(result.CLIs, scan)
	}
	items, err := itemSizes(ctx, s.roots)
	if err != nil {
		return ScanResult{}, err
	}
	result.Items = items
	result.Problems = mutate.StrandedStaging(s.roots)
	return result, nil
}

// itemSizes is the allocated bytes of the removable Skill and Subagent members of every row: each real path once, a
// link as 0 (removing it unlinks it and frees nothing).
func itemSizes(ctx context.Context, r roots.Roots) ([]ItemSize, error) {
	m := inventory.ReadMembers(r)
	byKey := map[string]int64{}
	seen := map[string]map[string]bool{}
	var order []string
	for _, item := range m.Items {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		if !item.Removable || (item.Kind != inventory.KindSkill && item.Kind != inventory.KindAgent) {
			continue
		}
		key := item.Key()
		if _, ok := byKey[key]; !ok {
			byKey[key] = 0
			seen[key] = map[string]bool{}
			order = append(order, key)
		}
		if item.Owner == "link" {
			continue
		}
		real := item.RealPath
		if real == "" {
			real = item.Path
		}
		if seen[key][real] {
			continue
		}
		seen[key][real] = true
		if u, err := fsx.DiskUsage(item.Path); err == nil {
			byKey[key] += u.Bytes
		}
	}
	slices.Sort(order)
	out := make([]ItemSize, 0, len(order))
	for _, key := range order {
		out = append(out, ItemSize{Key: key, Bytes: byKey[key]})
	}
	return out, nil
}

// group is one picked row of a move with the paths it takes.
type group struct {
	id    string
	cli   string
	isLog bool
	files []mutate.TrashFile
	// twins are the rels of compressed twins that go with their rollout: never archived, the rollout's record counts.
	twins map[string]bool
	// stayed and reason are set when the whole group is held back (a lock).
	stayed int
	reason string
}

func badParams(message string) error { return coreerr.New(message) }

// plan turns the params into groups, every check that refuses the whole call first.
func (s *Service) plan(ctx context.Context, p MoveParams, live map[string]map[string]bool) ([]*group, error) {
	if len(p.Logs) == 0 && len(p.Caches) == 0 {
		return nil, badParams("Pick at least one log group or cache to move.")
	}
	now := s.Now()
	var groups []*group
	seen := map[string]bool{}
	for _, pick := range p.Logs {
		r, ok := cliRoots(s.roots, pick.CLI)
		if !ok {
			return nil, badParams("cli must be claude or codex.")
		}
		if !slices.Contains(Ages, pick.OlderThanDays) {
			return nil, badParams("olderThanDays must be 30, 90 or 180.")
		}
		id := "logs:" + pick.CLI
		if seen[id] {
			return nil, badParams("Each CLI's logs can be picked once.")
		}
		seen[id] = true
		files, _, err := sessionLogs(ctx, r, live[pick.CLI])
		if err != nil {
			return nil, err
		}
		g := &group{id: id, cli: pick.CLI, isLog: true, twins: map[string]bool{}}
		for _, f := range olderThan(files, pick.OlderThanDays, now) {
			g.files = append(g.files, mutate.TrashFile{Group: id, CLI: pick.CLI, Rel: f.rel, Log: true})
			// M3: a .jsonl.zst twin goes with its rollout, so it never shows up as a log of its own.
			for _, tw := range f.twins {
				g.files = append(g.files, mutate.TrashFile{Group: id, CLI: pick.CLI, Rel: tw.rel, Log: true})
				g.twins[tw.rel] = true
			}
		}
		groups = append(groups, g)
	}
	for _, id := range p.Caches {
		c, ok := cacheByID(id)
		if !ok {
			return nil, badParams("Unknown cache " + strconv.Quote(id) + ".")
		}
		if seen[id] {
			return nil, badParams("Each cache can be picked once.")
		}
		seen[id] = true
		r, _ := cliRoots(s.roots, c.CLI)
		entries, err := cacheEntries(ctx, r.Root, c)
		if err != nil {
			return nil, err
		}
		g := &group{id: id, cli: c.CLI}
		for _, e := range entries {
			g.files = append(g.files, mutate.TrashFile{Group: id, CLI: c.CLI, Rel: e.rel})
		}
		groups = append(groups, g)
	}
	return groups, nil
}

// holdLocked marks every group its CLI's lock holds back. It reports whether any group is still open.
func holdLocked(groups []*group, locks map[string]Locks) {
	for _, g := range groups {
		if g.reason != "" {
			continue
		}
		l := locks[g.cli].Caches
		if g.isLog {
			l = locks[g.cli].Logs
		}
		if l != nil {
			g.stayed, g.reason, g.files = len(g.files), l.Message, nil
		}
	}
}

// Move is clean.move: every check that can refuse the whole call, then the usage archive of the logs (phase reading),
// the locks read again, and the move itself under the write lock (phase moving). A cancel before the first file moved
// changes nothing and answers ctx's error; a later cancel stops before the next file and answers what moved.
func (s *Service) Move(ctx context.Context, p MoveParams, progress func(ProgressParams)) (MoveResult, error) {
	s.mu.Lock()
	if s.moving {
		s.mu.Unlock()
		return MoveResult{}, coreerr.NewStatus("A Clean move is already running.", coreerr.StatusConflict)
	}
	s.moving = true
	s.mu.Unlock()
	defer func() {
		s.mu.Lock()
		s.moving = false
		s.mu.Unlock()
	}()
	state, err := s.locks(ctx)
	if err != nil {
		return MoveResult{}, err
	}
	groups, err := s.plan(ctx, p, state.live)
	if err != nil {
		return MoveResult{}, err
	}
	// An archive that cannot be read refuses before the long read of the logs (L2).
	if _, err := usage.ArchivedPaths(s.roots.Data); err != nil {
		return MoveResult{}, err
	}
	holdLocked(groups, state.locks)
	if err := refuseAllHeld(groups); err != nil {
		return MoveResult{}, err
	}

	var refs []usage.LogRef
	for _, g := range groups {
		if !g.isLog {
			continue
		}
		r, _ := cliRoots(s.roots, g.cli)
		for _, f := range g.files {
			if g.twins[f.Rel] {
				continue
			}
			refs = append(refs, usage.LogRef{Path: filepath.Join(r.Root, f.Rel), CLI: usage.CLI(g.cli)})
		}
	}
	notify := throttled(progress)
	records, err := s.usage.ArchiveRecords(ctx, refs, logTokens, func(done int) { notify("reading", done, len(refs), 0) })
	if err != nil {
		return MoveResult{}, err
	}
	for _, g := range groups {
		if !g.isLog {
			continue
		}
		r, _ := cliRoots(s.roots, g.cli)
		for i := range g.files {
			if rec, ok := records[filepath.Join(r.Root, g.files[i].Rel)]; ok {
				g.files[i].Archive = &rec
			}
		}
	}
	// Reading the logs can take a while: a session that started meanwhile holds its CLI back now.
	if state, err = s.locks(ctx); err != nil {
		return MoveResult{}, err
	}
	holdLocked(groups, state.locks)
	dropLive(groups, state.live)
	if err := refuseAllHeld(groups); err != nil {
		return MoveResult{}, err
	}

	var files []mutate.TrashFile
	for _, g := range groups {
		files = append(files, g.files...)
	}
	var outcome mutate.TrashOutcome
	err = mutate.WithLockContext(ctx, s.roots, func(tx *mutate.Tx) error {
		if err := ctx.Err(); err != nil {
			return err
		}
		var err error
		outcome, err = mutate.MoveToSystemTrash(ctx, tx, mutate.TrashPlan{Files: files, Label: label}, func(pr mutate.TrashProgress) {
			notify("moving", pr.Done, pr.Total, pr.Bytes)
		})
		return err
	})
	if err != nil {
		return MoveResult{}, err
	}
	return result(groups, outcome), nil
}

// dropLive takes out of the log groups every path of a row that became live while the logs were read (L4).
func dropLive(groups []*group, live map[string]map[string]bool) {
	for _, g := range groups {
		if !g.isLog {
			continue
		}
		kept := g.files[:0]
		for _, f := range g.files {
			if ofLiveRow(f.Rel, live[g.cli]) {
				g.stayed++
				if g.reason == "" {
					g.reason = "A session of this log is open again, so it was left in place."
				}
				continue
			}
			kept = append(kept, f)
		}
		g.files = kept
	}
}

// refuseAllHeld is the 409 of a move with nothing open: every picked group is locked, or none holds a path.
func refuseAllHeld(groups []*group) error {
	open := false
	for _, g := range groups {
		if len(g.files) > 0 {
			open = true
		}
	}
	if open {
		return nil
	}
	for _, g := range groups {
		if g.reason != "" {
			return coreerr.NewStatus(g.reason+" Nothing was moved.", coreerr.StatusConflict)
		}
	}
	return coreerr.NewStatus("Nothing is left to move. Scan again.", coreerr.StatusConflict)
}

func result(groups []*group, o mutate.TrashOutcome) MoveResult {
	res := MoveResult{Entry: o.Entry, Groups: []GroupResult{}, Cancelled: o.Cancelled}
	if o.Trash != "" {
		trash := o.Trash
		res.Trash = &trash
	}
	for _, g := range groups {
		gr := GroupResult{ID: g.id, Moved: o.Moved[g.id], Stayed: g.stayed + o.Stayed[g.id]}
		reason := g.reason
		if reason == "" {
			reason = o.Reasons[g.id]
		}
		if reason != "" {
			gr.Reason = &reason
		}
		res.Moved.Files += gr.Moved.Files
		res.Moved.Bytes += gr.Moved.Bytes
		res.Groups = append(res.Groups, gr)
	}
	return res
}

// label is the journal label of what moved: "Moved 3 files to the Trash: Claude Code logs, Codex caches".
func label(moved map[string]mutate.TrashAmount) string {
	files := 0
	var parts []string
	for _, cli := range clis {
		name := cliName(cli)
		logs, caches := false, false
		for id, a := range moved {
			if a.Files == 0 {
				continue
			}
			switch {
			case id == "logs:"+cli:
				logs = true
			case strings.HasPrefix(id, cli+":"):
				caches = true
			}
		}
		if logs {
			parts = append(parts, name+" logs")
		}
		if caches {
			parts = append(parts, name+" caches")
		}
	}
	for _, a := range moved {
		files += a.Files
	}
	noun := "files"
	if files == 1 {
		noun = "file"
	}
	return "Moved " + strconv.Itoa(files) + " " + noun + " to the Trash: " + strings.Join(parts, ", ")
}

// throttled sends a progress notification every progressEvery paths and at the last one of each phase.
func throttled(progress func(ProgressParams)) func(phase string, done, total int, bytes int64) {
	return func(phase string, done, total int, bytes int64) {
		if progress == nil || (done%progressEvery != 0 && done != total) {
			return
		}
		progress(ProgressParams{Phase: phase, Done: done, Total: total, Bytes: bytes})
	}
}

// logTokens is activity.LogTokens in the archive's shape.
func logTokens(ctx context.Context, path string, cli usage.CLI) ([]usage.ModelTokens, bool, error) {
	tokens, ok, err := activity.LogTokens(ctx, path, activity.CLI(cli))
	if err != nil || !ok {
		return nil, ok, err
	}
	out := make([]usage.ModelTokens, len(tokens))
	for i, t := range tokens {
		out[i] = usage.ModelTokens{Model: t.Model, Input: t.Usage.Input, Output: t.Usage.Output, CacheWrite: t.Usage.CacheWrite,
			CacheWriteLong: t.Usage.CacheWriteLong, CacheRead: t.Usage.CacheRead}
	}
	return out, true, nil
}
