package inventory

import (
	"math"
	"slices"
	"time"

	"spacevibe.dev/core/internal/cliregistry"
	"spacevibe.dev/core/internal/hashes"
	"spacevibe.dev/core/internal/usage"
)

// Usage cells for the Matrix:
//
//	counted       Runs is how many times it ran (hooks) or how many sessions used it (skills, agents); 0 = never
//	              ran inside the scanned logs. Errors is set for hooks.
//	pending       installed, but no scanned log can have covered it yet (see pendingReason)
//	unmeasurable  the CLI does not log it (Codex hooks); Reason says why
//	missing       not installed in that CLI
//
// loadout.rows also writes cliCells, one per registry CLI, from the same readings (cli-cells.go).

// pendingGrace: a zero-run item that changed inside this window is "pending", not "never ran".
const pendingGraceMs = 24 * 3600 * 1000

// pendingReason is a HEURISTIC, not a fact: the age of an item is unknowable, so "added" is the first time
// SpaceVibe saw its id (first-seen.go) or, without that store, the mtime of its file (SKILL.md, the agent file,
// or the settings file that holds the hook; any edit of that file moves it). An item with zero runs is pending instead of "never ran" when
//  1. its CLI has no scanned logs at all, or
//  2. it changed within the last 24 hours, or
//  3. it changed after the newest scanned log, so no session could have used it yet.
func pendingReason(addedMs *float64, window *usage.LogWindow, nowMs float64) string {
	if window != nil && window.Files == 0 {
		return NoLogsScanned
	}
	if addedMs != nil && nowMs-*addedMs < pendingGraceMs {
		return "Added in the last 24 hours"
	}
	if addedMs != nil && window != nil && window.Newest != nil && *addedMs > float64(*window.Newest) {
		return "Added after the newest log"
	}
	return ""
}

// isoMs is a time in ms since 1970 as the protocol's timestamp text (ISO 8601 UTC with milliseconds, the text of a
// journal `at`), nil for nil. A fraction of a millisecond is dropped.
func isoMs(ms *float64) *string {
	if ms == nil {
		return nil
	}
	text := time.UnixMilli(int64(*ms)).UTC().Format("2006-01-02T15:04:05.000Z")
	return &text
}

type matrixRow struct {
	id    string
	kind  Kind
	name  string
	entry string
	hash  string
	file  string
}

// rowGroup is the members of one row key, one per CLI (the last member of a CLI wins), plus what every member
// shares: the kind, and whether the row is user-level configuration.
type rowGroup struct {
	members map[CLI]matrixRow
	kind    Kind
	global  bool
}

// reading is what the scanned logs say about one member: runs (hooks) or sessions (skills, agents), the days
// of use (skills and agents), the last day, hook errors, and the pending reason when the count is zero.
type reading struct {
	runs    int
	days    []string
	last    *string
	errors  *int
	week    []HookDayCount
	pending string
}

// AttachUsage returns a copy of the snapshot with Cells on every item and hook, and Usage on every Claude hook
// (nil when the scan has not finished or the CLI does not log it). Pure apart from reading file mtimes. Hook
// runs are keyed by event plus command, so the same hook in a global and a project file shares one count: the
// log does not say which file it came from. A nil usage reads like the scanning state. It never sets
// CLICells: only loadout.rows carries them.
func AttachUsage(inv Snapshot, in *usage.Input, now time.Time) Snapshot {
	return attachUsage(inv, in, now, nil, nil)
}

// attachUsage is AttachUsage with firstSeen: the first-seen time in ms by item id, from the store of
// Service.Rows. An id it holds is "added" at that time; any other id falls back to the file's mtime. A
// non-empty registry also fills CLICells, one per entry (loadout.rows passes cliregistry.All(); tests pass
// others), and FirstSeen: that same "added" time, store or mtime, so "added N ago" and the D63 note agree.
func attachUsage(inv Snapshot, in *usage.Input, now time.Time, firstSeen map[string]float64, registry []cliregistry.CLI) Snapshot {
	nowMs := float64(now.UnixNano()) / 1e6
	// groups hold the v5 members only: the two-CLI cells never see a shared skill (plan AR1). allGroups add the
	// shared Codex skills of ~/.agents/skills first, so a v5 member of the same CLI wins, and feed the cliCells.
	groups, allGroups := map[string]*rowGroup{}, map[string]*rowGroup{}
	add := func(into map[string]*rowGroup, key string, cli CLI, row matrixRow, global bool) {
		if into[key] == nil {
			into[key] = &rowGroup{members: map[CLI]matrixRow{}, kind: row.kind, global: global}
		}
		into[key].members[cli] = row
	}
	itemRow := func(item Item) matrixRow {
		return matrixRow{id: item.ID, kind: item.Kind, name: item.Name, entry: item.Entry, file: item.File}
	}
	for _, item := range inv.shared {
		add(allGroups, item.Key(), item.CLI, itemRow(item), item.Project == nil)
	}
	for _, item := range inv.Items {
		add(groups, item.Key(), item.CLI, itemRow(item), item.Project == nil)
		add(allGroups, item.Key(), item.CLI, itemRow(item), item.Project == nil)
	}
	for _, hook := range inv.Hooks {
		row := matrixRow{id: hook.ID, kind: KindHook, hash: hook.Hash, file: hook.File}
		add(groups, hook.Key(), hook.CLI, row, hook.Project == nil)
		add(allGroups, hook.Key(), hook.CLI, row, hook.Project == nil)
	}
	type mtime struct {
		ms *float64
	}
	mtimes := map[string]mtime{}
	addedAt := func(id, file string) *float64 {
		if ms, ok := firstSeen[id]; ok {
			return &ms
		}
		if known, ok := mtimes[file]; ok {
			return known.ms
		}
		var ms *float64
		if v, ok := modifiedMs(file); ok {
			ms = &v
		}
		mtimes[file] = mtime{ms}
		return ms
	}
	var totals *usage.Totals
	var windows *usage.Windows
	if in != nil {
		totals, windows = in.Totals, in.Windows
	}
	// read is the logs' answer for one member; only called once totals are known.
	read := func(row matrixRow, cli CLI) reading {
		perCLI := totals.For(cli)
		var r reading
		if row.kind == KindHook {
			h := perCLI.Hook[row.hash]
			e := h.Errors
			r = reading{runs: h.Runs, last: h.Last, errors: &e, week: hookWeek(perCLI.HookDays[row.hash], now)}
		} else {
			names := perCLI.Skill
			if row.kind == KindAgent {
				names = perCLI.Agent
			}
			n := names[hashes.Bare(row.name)]
			if row.kind == KindSkill && row.entry != "" {
				// Codex logs a skill under its folder name, which can differ from the frontmatter name. One
				// session can match both names, so take the larger count instead of adding them; the last day is
				// the later of the two.
				byEntry := names[hashes.Bare(row.entry)]
				last := n.Last
				if byEntry.Last != nil && (last == nil || *byEntry.Last > *last) {
					last = byEntry.Last
				}
				if byEntry.Sessions > n.Sessions {
					n = byEntry
				}
				n.Last = last
			}
			r = reading{runs: n.Sessions, days: n.Days, last: n.Last}
		}
		if r.runs == 0 {
			var window *usage.LogWindow
			if windows != nil {
				w := windows.For(cli)
				window = &w
			}
			r.pending = pendingReason(addedAt(row.id, row.file), window, nowMs)
		}
		return r
	}
	cellFor := func(row *matrixRow, cli CLI) Cell {
		if row == nil {
			return Missing()
		}
		if row.kind == KindHook && cli == Codex {
			return Unmeasurable(CodexHooksReason)
		}
		if totals == nil {
			return Pending(ScanNotFinished)
		}
		r := read(*row, cli)
		if r.pending != "" {
			return Pending(r.pending)
		}
		return Counted(r.runs, r.last, r.errors)
	}
	cliCellFor := func(group *rowGroup, entry cliregistry.CLI) CLICell {
		if !supportsKind(entry.Supports, group.kind) {
			return CLICell{State: CLICellNotSupported}
		}
		if !readsCLI(entry.ID) {
			return CLICell{State: CLICellUnknown}
		}
		cli := CLI(entry.ID)
		row, ok := group.members[cli]
		if !ok {
			if group.global && inv.unreadable.has(cli, group.kind) {
				return CLICell{State: CLICellUnknown}
			}
			return CLICell{State: CLICellMissing}
		}
		if row.kind == KindHook && cli == Codex {
			return CLICell{State: CLICellUnmeasurable, Reason: CodexHooksReason}
		}
		if !entry.Supports.Logs {
			return CLICell{State: CLICellUnmeasurable, Reason: NoCountableLog}
		}
		if totals == nil {
			return CLICell{State: CLICellScanning}
		}
		r := read(row, cli)
		if r.pending == NoLogsScanned {
			return CLICell{State: CLICellUnmeasurable, Reason: NoLogsScanned}
		}
		cell := CLICell{State: CLICellCounted, Last: r.last, Note: r.pending}
		if row.kind == KindHook {
			runs := r.runs
			cell.Runs, cell.Errors, cell.Week = &runs, r.errors, r.week
		} else {
			sessions := r.runs
			cell.Sessions, cell.Days = &sessions, slices.Clone(r.days)
			if cell.Days == nil {
				cell.Days = []string{}
			}
		}
		return cell
	}
	cellsFor := func(key string) *Cells {
		group := groups[key]
		get := func(cli CLI) *matrixRow {
			if row, ok := group.members[cli]; ok {
				return &row
			}
			return nil
		}
		return &Cells{Claude: cellFor(get(Claude), Claude), Codex: cellFor(get(Codex), Codex)}
	}
	cliCellsFor := func(key string) map[string]CLICell {
		if len(registry) == 0 {
			return nil
		}
		group := allGroups[key]
		out := make(map[string]CLICell, len(registry))
		for _, entry := range registry {
			out[string(entry.ID)] = cliCellFor(group, entry)
		}
		return out
	}

	// firstSeenOf is the "added" time the pending rule reads, as wire text; loadout.rows only (a non-empty registry).
	firstSeenOf := func(id, file string) *string {
		if len(registry) == 0 {
			return nil
		}
		return isoMs(addedAt(id, file))
	}

	out := inv
	out.Items = make([]Item, len(inv.Items))
	for i, item := range inv.Items {
		item.Cells = cellsFor(item.Key())
		item.CLICells = cliCellsFor(item.Key())
		item.FirstSeen = firstSeenOf(item.ID, item.File)
		out.Items[i] = item
	}
	// A shared skill gets cliCells only: it is in no v5 field, so it has no two-CLI cells.
	if inv.shared != nil {
		out.shared = make([]Item, len(inv.shared))
		for i, item := range inv.shared {
			item.CLICells = cliCellsFor(item.Key())
			item.FirstSeen = firstSeenOf(item.ID, item.File)
			out.shared[i] = item
		}
	}
	out.Hooks = make([]Hook, len(inv.Hooks))
	for i, hook := range inv.Hooks {
		hook.Cells = cellsFor(hook.Key())
		hook.CLICells = cliCellsFor(hook.Key())
		hook.FirstSeen = firstSeenOf(hook.ID, hook.File)
		hook.Usage = nil
		if hook.CLI == Claude && totals != nil {
			u := totals.Claude.Hook[hook.Hash]
			var avg *int
			if u.Timed > 0 {
				v := int(math.Round(u.Ms / float64(u.Timed)))
				avg = &v
			}
			hook.Usage = &HookUsage{Runs: u.Runs, AvgMs: avg, TotalMs: u.Ms, Errors: u.Errors, Last: u.Last}
		}
		out.Hooks[i] = hook
	}
	return out
}
