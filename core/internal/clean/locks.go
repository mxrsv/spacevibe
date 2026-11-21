package clean

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strconv"

	"spacevibe.dev/core/internal/activity"
	"spacevibe.dev/core/internal/cliregistry"
	"spacevibe.dev/core/internal/roots"
)

// Locks come from the Activity report alone, the same reading the shell's CleanLocks makes, and fail closed: an answer
// the core cannot get locks.
//
//   - Logs (RD27): a running or waiting session of the CLI is writing its logs.
//   - Caches (RD35): any live session of the CLI (running, waiting, idle or unmeasurable) may be using them. An ended
//     row has no process and locks nothing.
//   - Both, for processUnknown: the Activity read failed, the process adapter cannot see processes, the Codex process
//     check failed (codex-process-unknown, on the report or on a row), or Claude Code's sessions folder exists and
//     cannot be read (the read path then lists no Claude rows and reports nothing).

// lockInput is what the locks are computed from.
type lockInput struct {
	report     activity.Report
	readFailed bool
	measurable bool
}

func lockFor(input lockInput, r roots.Roots, cli string) Locks {
	name := cliName(cli)
	unknown := &Lock{Reason: LockProcessUnknown, Sessions: []string{},
		Message: "The process check failed just now, so SpaceVibe cannot tell whether " + name + " is running. Try again in a moment."}
	if input.readFailed || !input.measurable || processUnknown(input.report, cli) || (cli == "claude" && sessionsUnreadable(r)) {
		return Locks{Logs: unknown, Caches: unknown}
	}
	var writing, live []string
	for _, s := range input.report.Sessions {
		if string(s.CLI) != cli {
			continue
		}
		switch s.State {
		case activity.StateRunning, activity.StateWaiting:
			writing = append(writing, s.ID)
			live = append(live, s.ID)
		case activity.StateIdle, activity.StateUnmeasurable:
			live = append(live, s.ID)
		}
	}
	var out Locks
	if len(writing) > 0 {
		out.Logs = &Lock{Reason: LockSessions, Sessions: writing,
			Message: name + " has " + sessions(len(writing), "running") + ", so its logs stay until " + untilEnd(len(writing)) + "."}
	}
	if len(live) > 0 {
		out.Caches = &Lock{Reason: LockSessions, Sessions: live,
			Message: name + " has " + sessions(len(live), "open") + ", so its caches are in use."}
	}
	return out
}

func processUnknown(report activity.Report, cli string) bool {
	for _, l := range report.Unmeasurable {
		if string(l.CLI) == cli && l.Code == activity.ReasonCodexProcessUnknown {
			return true
		}
	}
	for _, s := range report.Sessions {
		if string(s.CLI) == cli && s.ReasonCode != nil && *s.ReasonCode == activity.ReasonCodexProcessUnknown {
			return true
		}
	}
	return false
}

// sessionsUnreadable: Claude Code's sessions folder exists but cannot be listed, so its rows are unknown.
func sessionsUnreadable(r roots.Roots) bool {
	dir := filepath.Join(r.Claude.Root, "sessions")
	if _, err := os.ReadDir(dir); err != nil && !errors.Is(err, fs.ErrNotExist) {
		return true
	}
	return false
}

func cliName(cli string) string {
	if c, ok := cliregistry.Lookup(cliregistry.ID(cli)); ok {
		return c.Name
	}
	return cli
}

func sessions(n int, adjective string) string {
	if n == 1 {
		return "1 " + adjective + " session"
	}
	return strconv.Itoa(n) + " " + adjective + " sessions"
}

func untilEnd(n int) string {
	if n == 1 {
		return "it ends"
	}
	return "they end"
}
