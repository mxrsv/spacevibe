package activity

import (
	"errors"
	"testing"

	"spacevibe.dev/core/internal/clis"
)

func TestActivityAdaptersMatchRegistry(t *testing.T) {
	if err := adapters.Check(); err != nil {
		t.Fatal(err)
	}
}

// MC-T3: a log of a CLI with no Activity adapter is an error. The old fold folded every id that was not Claude Code
// as a Codex rollout, and the old file grouping dropped it without a word.
func TestFoldRefusesACLIWithoutAdapter(t *testing.T) {
	sb := newSandbox(t)
	path := sb.put(".gemini/tmp/chat.jsonl", "{}\n", 0)
	cases := []struct {
		id   CLI
		want error
	}{{clis.Gemini, clis.ErrConceptAbsent}, {"nope", clis.ErrUnknownCLI}}
	for _, c := range cases {
		e := NewEngine()
		if _, _, err := e.advance(logFile{path: path, cli: c.id}, 1<<20); !errors.Is(err, c.want) {
			t.Errorf("advance(%s) = %v, want %v", c.id, err, c.want)
		}
		if len(e.cache) != 0 {
			t.Errorf("advance(%s) cached a log it could not fold", c.id)
		}
		if _, err := editsOf(newLogState(c.id)); !errors.Is(err, c.want) {
			t.Errorf("editsOf(%s) = %v, want %v", c.id, err, c.want)
		}
	}
}

func TestFileGroupingRefusesACLIWithoutAdapter(t *testing.T) {
	st := newLogState("nope")
	st.edits = []editEvent{{id: "e1", path: "/work/app/a.go", at: activityNowMs}}
	rows, err := groupFiles([]logEntry{{state: st, session: "nope:s1"}}, 10)
	if !errors.Is(err, clis.ErrUnknownCLI) || rows != nil {
		t.Fatalf("groupFiles = %v, %v; want ErrUnknownCLI", rows, err)
	}
}

// Stop of a session whose CLI has no Activity adapter signals nothing. The old livePid looked every id that was not
// Codex up as a Claude Code session, so Stop("gemini", <a Claude session id>) stopped that Claude session.
func TestStopRefusesACLIWithoutAdapter(t *testing.T) {
	sb := newSandbox(t)
	sb.status(11, obj{"procStart": stopStart})
	p := newFakeProc([]int{11}, map[int]string{11: stopStart}, nil)
	for _, c := range []struct {
		id   CLI
		want error
	}{{clis.Gemini, clis.ErrConceptAbsent}, {"nope", clis.ErrUnknownCLI}} {
		if _, err := stopSession(t, sb, c.id, activitySid(11), p, fastStop); !errors.Is(err, c.want) {
			t.Errorf("Stop(%s) = %v, want %v", c.id, err, c.want)
		}
	}
	if got := p.killedPids(); len(got) != 0 {
		t.Fatalf("signalled %v", got)
	}
}

// Every report lists each CLI's fixed limits in wire order, as the old fixed table did.
func TestFixedLimitsInWireOrder(t *testing.T) {
	want := []Limit{
		{CLI: clis.Claude, Code: ReasonClaudePromptVsBusy}, {CLI: clis.Codex, Code: ReasonCodexToolSilent},
		{CLI: clis.Codex, Code: ReasonCodexNoRollout}, {CLI: clis.Codex, Code: ReasonCodexHookRuns},
	}
	got := fixedLimits()
	if len(got) != len(want) {
		t.Fatalf("limits = %+v", got)
	}
	for i := range want {
		if got[i].CLI != want[i].CLI || got[i].Code != want[i].Code || got[i].Text != want[i].Code.Text() {
			t.Errorf("limit %d = %+v, want %+v", i, got[i], want[i])
		}
	}
}
