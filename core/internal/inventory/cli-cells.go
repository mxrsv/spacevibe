package inventory

import (
	"encoding/json"
	"slices"
	"time"

	"spacevibe.dev/core/internal/cliregistry"
	"spacevibe.dev/core/internal/usage"
)

// CLICell states: the cells of the `cliCells` map that loadout.rows puts on every item and hook, one per
// registry CLI (cliregistry). It sits beside the two-CLI Cells, which the v5 shell reads and which stay as they
// are until the cut-over (plan AR1).
const (
	// CLICellCounted: installed and measured. A skill or subagent carries sessions and days, a hook runs and
	// errors. A zero is Never ran; Note then carries D63's "added recently" sentence when the item is too new
	// for the scanned logs to have covered it.
	CLICellCounted = "counted"
	// CLICellScanning: installed, and the usage scan of this process has not finished yet.
	CLICellScanning = "scanning"
	// CLICellUnmeasurable: installed (loaded), but the CLI keeps no log SpaceVibe can count it from. Never 0.
	CLICellUnmeasurable = "unmeasurable"
	// CLICellMissing: the CLI has the concept and its folder was read; the item is not installed there.
	CLICellMissing = "missing"
	// CLICellUnknown: the CLI's folder or file for this kind could not be read, so whether the item is there
	// is not known. It replaces Missing, never a cell of an item that was read.
	CLICellUnknown = "unknown"
	// CLICellNotSupported: the CLI has no such concept (cliregistry.Supports).
	CLICellNotSupported = "notSupported"
)

// Reasons and notes of the cliCells that the two-CLI Cells do not have.
const (
	// NoLogsScanned is why an installed item of a CLI with no scanned log at all is unmeasurable. The two-CLI
	// Cells report the same sentence as a pending reason.
	NoLogsScanned = "No logs scanned for this CLI yet"
	// NoCountableLog is why an installed item of a CLI whose registry entry has no logs is unmeasurable.
	NoCountableLog = "This CLI keeps no log SpaceVibe can count"
)

// CLICell is one CLI's cell for one row. Which members are set depends on State: see MarshalJSON.
type CLICell struct {
	State string
	// Sessions and Days are set on a counted skill or subagent: the sessions that used it and the days it
	// was used on (YYYY-MM-DD, sorted, never nil).
	Sessions *int
	Days     []string
	// Runs and Errors are set on a counted hook (lifetime, inside the scanned logs). Week is the same hook's last
	// HookWeekDays days, oldest first and ending today, every day present (RD26 counts errors here, never Errors).
	Runs   *int
	Errors *int
	Week   []HookDayCount
	// Last is the last day it was used, null when unknown. Counted only.
	Last *string
	// Note is set on a counted zero that may be too new for the logs (D63). Counted only; "" when none.
	Note string
	// Reason says why a cell is unmeasurable. Unmeasurable only.
	Reason string
}

// HookWeekDays is how many days a counted hook cell lists: errors in the last 7 days make a failing Hook (RD26).
const HookWeekDays = 7

// HookDayCount is one day of a hook cell's week: the day (YYYY-MM-DD, the log's own date text, as usage days are)
// and the runs and errors logged on it.
type HookDayCount struct {
	Day    string `json:"day"`
	Runs   int    `json:"runs"`
	Errors int    `json:"errors"`
}

// hookWeek is the last HookWeekDays days of one hook up to the day of now, oldest first, zeros included. The day
// of now is taken in UTC, because a usage day is the date text of the log's timestamp, which the CLIs write in UTC.
func hookWeek(days usage.HookDays, now time.Time) []HookDayCount {
	today := now.UTC()
	out := make([]HookDayCount, HookWeekDays)
	for i := range out {
		day := today.AddDate(0, 0, i-(HookWeekDays-1)).Format("2006-01-02")
		d := days[day]
		out[i] = HookDayCount{Day: day, Runs: d.Runs, Errors: d.Errors}
	}
	return out
}

// errorsIn is the sum of the errors of a week.
func errorsIn(week []HookDayCount) int {
	sum := 0
	for _, d := range week {
		sum += d.Errors
	}
	return sum
}

// cliCellWire is every member any state can write; MarshalJSON fills the ones its state has.
type cliCellWire struct {
	State           string         `json:"state"`
	Sessions        *int           `json:"sessions,omitempty"`
	Days            []string       `json:"days,omitempty"`
	Runs            *int           `json:"runs,omitempty"`
	Errors          *int           `json:"errors,omitempty"`
	ErrorsLast7Days *int           `json:"errorsLast7Days,omitempty"`
	Last7Days       []HookDayCount `json:"last7Days,omitempty"`
	Last            *string        `json:"last"`
	Note            string         `json:"note,omitempty"`
	Reason          string         `json:"reason,omitempty"`
}

// MarshalJSON writes:
//
//	counted skill or agent  {state, sessions, days, last, note?}
//	counted hook            {state, runs, errors, errorsLast7Days, last7Days, last, note?}
//	unmeasurable            {state, reason}
//	scanning, missing, unknown, notSupported  {state}
//
// errorsLast7Days is the sum of last7Days' errors, written so a caller never adds it up differently.
func (c CLICell) MarshalJSON() ([]byte, error) {
	switch c.State {
	case CLICellCounted:
		if c.Runs != nil {
			week := c.Week
			if week == nil {
				week = []HookDayCount{}
			}
			return json.Marshal(struct {
				State           string         `json:"state"`
				Runs            int            `json:"runs"`
				Errors          int            `json:"errors"`
				ErrorsLast7Days int            `json:"errorsLast7Days"`
				Last7Days       []HookDayCount `json:"last7Days"`
				Last            *string        `json:"last"`
				Note            string         `json:"note,omitempty"`
			}{c.State, *c.Runs, derefInt(c.Errors), errorsIn(week), week, c.Last, c.Note})
		}
		days := c.Days
		if days == nil {
			days = []string{}
		}
		return json.Marshal(struct {
			State    string   `json:"state"`
			Sessions int      `json:"sessions"`
			Days     []string `json:"days"`
			Last     *string  `json:"last"`
			Note     string   `json:"note,omitempty"`
		}{c.State, derefInt(c.Sessions), days, c.Last, c.Note})
	case CLICellUnmeasurable:
		return json.Marshal(struct {
			State  string `json:"state"`
			Reason string `json:"reason"`
		}{c.State, c.Reason})
	case CLICellScanning, CLICellMissing, CLICellUnknown, CLICellNotSupported:
		return json.Marshal(struct {
			State string `json:"state"`
		}{c.State})
	}
	return nil, errBadCell
}

// UnmarshalJSON reads the same shapes back; an unknown state or a counted cell with neither sessions nor
// runs is an error.
func (c *CLICell) UnmarshalJSON(data []byte) error {
	var w cliCellWire
	if err := json.Unmarshal(data, &w); err != nil {
		return err
	}
	switch w.State {
	case CLICellCounted:
		switch {
		case w.Runs != nil:
			errors := derefInt(w.Errors)
			week := w.Last7Days
			if week == nil {
				week = []HookDayCount{}
			}
			*c = CLICell{State: w.State, Runs: w.Runs, Errors: &errors, Week: week, Last: w.Last, Note: w.Note}
		case w.Sessions != nil:
			days := w.Days
			if days == nil {
				days = []string{}
			}
			*c = CLICell{State: w.State, Sessions: w.Sessions, Days: days, Last: w.Last, Note: w.Note}
		default:
			return errBadCell
		}
	case CLICellUnmeasurable:
		*c = CLICell{State: w.State, Reason: w.Reason}
	case CLICellScanning, CLICellMissing, CLICellUnknown, CLICellNotSupported:
		*c = CLICell{State: w.State}
	default:
		return errBadCell
	}
	return nil
}

// supportsKind is the registry's answer for one item kind.
func supportsKind(s cliregistry.Supports, kind Kind) bool {
	switch kind {
	case KindSkill:
		return s.Skill
	case KindAgent:
		return s.Agent
	case KindHook:
		return s.Hook
	}
	return false
}

// readsCLI reports whether the engine has a reader for the registry id. A registry CLI without one would read
// as unknown everywhere; cliregistry's test keeps the two lists equal.
func readsCLI(id cliregistry.ID) bool {
	return slices.Contains(clisRead[:], CLI(id))
}

// clisRead are the CLIs inventory and usage read.
var clisRead = [...]CLI{Claude, Codex}

// unreadableKinds records, per CLI, the kinds whose own folder or file the reader could not use: the CLI root,
// its skills or agents folder, its hook file, and for Claude the plugin list, the settings that enable plugins
// and a plugin's own folders. An item absent from such a CLI is unknown, not missing. Only user-level
// configuration counts: project rows hold Claude items only, read from the project's own folder.
type unreadableKinds map[CLI]map[Kind]bool

// mark records kinds as unreadable for cli. It returns a new value; the receiver is not changed (C1).
func (u unreadableKinds) mark(cli CLI, kinds ...Kind) unreadableKinds {
	out := make(unreadableKinds, len(u)+1)
	for c, ks := range u {
		out[c] = ks
	}
	next := make(map[Kind]bool, len(u[cli])+len(kinds))
	for k, v := range u[cli] {
		next[k] = v
	}
	for _, k := range kinds {
		next[k] = true
	}
	out[cli] = next
	return out
}

// markIf is mark when cond holds, else the receiver unchanged.
func (u unreadableKinds) markIf(cond bool, cli CLI, kinds ...Kind) unreadableKinds {
	if !cond {
		return u
	}
	return u.mark(cli, kinds...)
}

func (u unreadableKinds) has(cli CLI, kind Kind) bool { return u[cli][kind] }

func derefInt(p *int) int {
	if p == nil {
		return 0
	}
	return *p
}
