package proc

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"slices"
	"strconv"
	"sync"
	"time"

	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/identity"
)

// EnvProcFixture names the env var that points at a fixture process list (read by the caller through
// internal/config, never here).
const EnvProcFixture = identity.EnvPrefix + "PROC_FIXTURE"

// Fixture is a process list replayed from a JSON file, for dev runs and screenshots against a
// synthetic home. It never starts a process and never signals one: Terminate only edits the
// in-memory list, so Stop works end to end without touching the machine. The pids in the file are
// made up; nothing real answers to them.
//
// File format (what scripts/fixture-home.mjs writes to <dir>/.spacevibe/activity-proc.json; the golden
// file wraps the same shape in "shared", which is unwrapped here):
//
//	{ "alive": [41001], "starts": { "52003": "Mon Nov  2 11:58:00 2026" },
//	  "threads": [{ "pid": 52001, "threadId": "a000..." }, { "pid": 52003, "threadId": null }], "delayMs": 20000 }
//
// alive: pids IsAlive finds. starts: `ps lstart` text per pid. threads: live codex processes with
// their thread lock. delayMs: the first question waits this long once, so a run can sit on "Reading logs".
// others (optional): more live processes per CLI id that Activity gives no row, `{"codex": [53001]}` for a Codex
// app-server; CLIProcesses lists them with the alive pids (Claude Code) and the thread pids (Codex).
type Fixture struct {
	mu           sync.Mutex
	alive        map[int]bool
	starts       map[int]string
	threads      []Thread
	others       map[string][]int
	pendingDelay time.Duration
}

// NewFixture builds a list from values. With no arguments it is the empty list that SPACEVIBE_TEST=1
// uses when no file is given, so test mode can never see a real process.
func NewFixture(alive []int, starts map[int]string, threads []Thread, delay time.Duration) *Fixture {
	f := &Fixture{alive: map[int]bool{}, starts: map[int]string{}, threads: slices.Clone(threads), others: map[string][]int{}, pendingDelay: delay}
	for _, p := range alive {
		f.alive[p] = true
	}
	for p, s := range starts {
		f.starts[p] = s
	}
	return f
}

var errFixtureUnreadable = coreerr.New(EnvProcFixture + " does not point at a readable process list file.")

// LoadFixture reads a fixture file. A field of the wrong type counts as absent, as in the Swift
// loader; a file that is not a JSON object is an error.
func LoadFixture(path string) (*Fixture, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, errFixtureUnreadable
	}
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.UseNumber()
	var top any
	spec, ok := map[string]any(nil), false
	if dec.Decode(&top) == nil {
		spec, ok = top.(map[string]any)
	}
	if !ok {
		return nil, errFixtureUnreadable
	}
	if shared, isObj := spec["shared"].(map[string]any); isObj {
		spec = shared
	}
	alive, _ := intList(spec["alive"])
	starts := map[int]string{}
	if obj, isObj := spec["starts"].(map[string]any); isObj && allStrings(obj) {
		for k, v := range obj {
			if pid, err := strconv.Atoi(k); err == nil {
				starts[pid] = v.(string)
			}
		}
	}
	var threads []Thread
	if items, isArr := spec["threads"].([]any); isArr {
		for _, item := range items {
			obj, isObj := item.(map[string]any)
			if !isObj {
				continue
			}
			pid, isInt := asInt(obj["pid"])
			if !isInt {
				continue
			}
			id, _ := obj["threadId"].(string)
			threads = append(threads, Thread{Pid: pid, ThreadID: id})
		}
	}
	delay, _ := asInt(spec["delayMs"])
	f := NewFixture(alive, starts, threads, time.Duration(delay)*time.Millisecond)
	if obj, isObj := spec["others"].(map[string]any); isObj {
		for cli, v := range obj {
			if pids, ok := intList(v); ok {
				f.others[cli] = pids
			}
		}
	}
	return f, nil
}

func asInt(v any) (int, bool) {
	n, ok := v.(json.Number)
	if !ok {
		return 0, false
	}
	i, err := strconv.Atoi(n.String())
	return i, err == nil
}

// intList is the Swift `as? [Int]` cast: every element must be an integer or the whole list is absent.
func intList(v any) ([]int, bool) {
	arr, ok := v.([]any)
	if !ok {
		return nil, false
	}
	out := make([]int, 0, len(arr))
	for _, e := range arr {
		i, isInt := asInt(e)
		if !isInt {
			return nil, false
		}
		out = append(out, i)
	}
	return out, true
}

func allStrings(obj map[string]any) bool {
	for _, v := range obj {
		if _, ok := v.(string); !ok {
			return false
		}
	}
	return true
}

// firstQuestionDelay sleeps the configured delay once, for the first caller only.
func (f *Fixture) firstQuestionDelay(ctx context.Context) {
	f.mu.Lock()
	d := f.pendingDelay
	f.pendingDelay = 0
	f.mu.Unlock()
	if d <= 0 {
		return
	}
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-t.C:
	case <-ctx.Done():
	}
}

// Measurable is true: the fixture answers every question.
func (f *Fixture) Measurable() bool { return true }

// IsAlive reports whether pid is in the alive list.
func (f *Fixture) IsAlive(ctx context.Context, pid int) bool {
	f.firstQuestionDelay(ctx)
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.alive[pid]
}

// StartTime returns the recorded start text for pid.
func (f *Fixture) StartTime(ctx context.Context, pid int) (string, bool) {
	f.firstQuestionDelay(ctx)
	f.mu.Lock()
	defer f.mu.Unlock()
	s, ok := f.starts[pid]
	return s, ok
}

// fixtureStart and fixtureName stand in for a start time and name the file does not list, so Stop works
// end to end in a dev run for every pid in the list. They never equal a real procStart.
const (
	fixtureStart = "fixture-start"
	fixtureName  = "fixture"
)

// Identify returns the recorded start text (or fixtureStart) for a pid in the list, ErrNoSuchProcess otherwise.
func (f *Fixture) Identify(ctx context.Context, pid int) (Identity, error) {
	f.firstQuestionDelay(ctx)
	f.mu.Lock()
	defer f.mu.Unlock()
	if !f.knows(pid) {
		return Identity{}, ErrNoSuchProcess
	}
	start, ok := f.starts[pid]
	if !ok {
		start = fixtureStart
	}
	return Identity{Start: start, Name: fixtureName}, nil
}

func (f *Fixture) knows(pid int) bool {
	return f.alive[pid] || slices.ContainsFunc(f.threads, func(t Thread) bool { return t.Pid == pid })
}

// CodexThreads returns a copy of the thread list; the fixture never fails.
func (f *Fixture) CodexThreads(ctx context.Context) ([]Thread, error) {
	f.firstQuestionDelay(ctx)
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.Clone(f.threads), nil
}

// WithOthers adds live processes per CLI id that have no Activity row (a Codex app-server), for tests.
func (f *Fixture) WithOthers(others map[string][]int) *Fixture {
	f.mu.Lock()
	defer f.mu.Unlock()
	for cli, pids := range others {
		f.others[cli] = append(f.others[cli], pids...)
	}
	return f
}

// CLIProcesses is the alive pids as Claude Code, the thread pids as Codex, and the others; the fixture never fails.
func (f *Fixture) CLIProcesses(ctx context.Context) (map[string][]int, error) {
	f.firstQuestionDelay(ctx)
	f.mu.Lock()
	defer f.mu.Unlock()
	out := map[string][]int{}
	for pid := range f.alive {
		out["claude"] = append(out["claude"], pid)
	}
	slices.Sort(out["claude"])
	for _, t := range f.threads {
		out["codex"] = append(out["codex"], t.Pid)
	}
	for cli, pids := range f.others {
		out[cli] = append(out[cli], pids...)
	}
	return out, nil
}

// Terminate removes pid from the in-memory list; a pid the list does not know is ErrNoSuchProcess.
func (f *Fixture) Terminate(_ context.Context, pid int) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if !f.knows(pid) {
		return ErrNoSuchProcess
	}
	delete(f.alive, pid)
	f.threads = slices.DeleteFunc(f.threads, func(t Thread) bool { return t.Pid == pid })
	return nil
}
