package inventory

import (
	"strings"
	"testing"

	"spacevibe.dev/core/internal/usage"
)

// hookLine is one Claude hook attachment on a day; failed makes it a hook error.
func hookLine(day, command string, failed bool) string {
	kind, code := "hook_success", "0"
	if failed {
		kind, code = "hook_non_blocking_error", "1"
	}
	return `{"type":"attachment","timestamp":"` + day + `T10:00:00.000Z","attachment":{"type":"` + kind +
		`","hookEvent":"PostToolUse","command":"` + command + `","durationMs":5,"exitCode":` + code + `}}`
}

// RB-E5 (RD26): a counted hook cell lists the last 7 days, oldest first and ending today, with the runs and errors of
// each, and errorsLast7Days is their sum. An error 8 days ago counts in the lifetime errors only. A dead hook keeps
// the runs the logs hold ("Inferred, not decided": Dead Hook runs).
func TestHookCellWeek(t *testing.T) {
	h := newTempHome(t)
	h.write(".claude/settings.json", `{"hooks": {"PostToolUse": [{"matcher": "Edit", "hooks": [`+
		`{"type": "command", "command": "echo live"}, {"type": "command", "command": "sh '`+h.root+`/gone/fmt.sh'"}]}]}}`)
	dead := "sh '" + h.root + "/gone/fmt.sh'"
	lines := []string{
		hookLine("2026-11-13", "echo live", true), // 8 days before now: lifetime only
		hookLine("2026-11-15", "echo live", true), // the first day of the week
		hookLine("2026-11-18", "echo live", false),
		hookLine("2026-11-18", "echo live", true),
		hookLine("2026-11-21", "echo live", false), // today
		hookLine("2026-11-20", strings.ReplaceAll(dead, "'", `'`), false),
	}
	h.write(".claude/projects/-p/s1.jsonl", strings.Join(lines, "\n")+"\n")
	h.setModified(h.path(".claude/settings.json"), "2026-09-20T00:00:00Z")
	r := h.roots()
	now := mustTime(t, "2026-11-21T08:00:00Z")
	rows := BuildLoadoutRows(Read(r), usage.Ready(scanOf(t, r)), now)

	live := hookByCommand(Snapshot{Hooks: rows.Hooks}, "echo live")
	if live == nil {
		t.Fatal("no hook echo live")
	}
	cell := live.CLICells["claude"]
	if cell.State != CLICellCounted || *cell.Runs != 5 || *cell.Errors != 3 {
		t.Fatalf("live cell = %+v, want counted, 5 runs, 3 lifetime errors", cell)
	}
	want := []HookDayCount{
		{"2026-11-15", 1, 1}, {"2026-11-16", 0, 0}, {"2026-11-17", 0, 0}, {"2026-11-18", 2, 1},
		{"2026-11-19", 0, 0}, {"2026-11-20", 0, 0}, {"2026-11-21", 1, 0},
	}
	if len(cell.Week) != HookWeekDays {
		t.Fatalf("week has %d days: %+v", len(cell.Week), cell.Week)
	}
	for i := range want {
		if cell.Week[i] != want[i] {
			t.Errorf("day %d = %+v, want %+v", i, cell.Week[i], want[i])
		}
	}
	if got := errorsIn(cell.Week); got != 2 {
		t.Errorf("errors in the last 7 days = %d, want 2 (the error 8 days ago is lifetime only)", got)
	}

	gone := hookByCommand(Snapshot{Hooks: rows.Hooks}, dead)
	if gone == nil || !gone.Dead {
		t.Fatalf("no dead hook: %+v", gone)
	}
	if c := gone.CLICells["claude"]; c.State != CLICellCounted || *c.Runs != 1 || c.Week[5].Runs != 1 {
		t.Errorf("dead hook cell = %+v, want its one logged run", c)
	}
}

// The week moves with the clock, and a hook the logs never name lists 7 zero days.
func TestHookWeekDays(t *testing.T) {
	days := usage.HookDays{"2026-11-01": {Runs: 4, Errors: 2}, "2026-10-25": {Runs: 1, Errors: 1}}
	week := hookWeek(days, mustTime(t, "2026-11-01T23:59:59Z"))
	if week[0].Day != "2026-10-26" || week[6] != (HookDayCount{"2026-11-01", 4, 2}) || errorsIn(week) != 2 {
		t.Errorf("week = %+v", week)
	}
	if empty := hookWeek(nil, mustTime(t, "2026-11-01T00:00:00Z")); len(empty) != HookWeekDays || errorsIn(empty) != 0 {
		t.Errorf("week of an unnamed hook = %+v", empty)
	}
}
