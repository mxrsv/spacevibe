package activity

import (
	"context"
	"testing"

	"spacevibe.dev/core/internal/proc"
)

func TestServiceStopTakesNoPid(t *testing.T) {
	sb := newSandbox(t)
	sb.status(161, obj{"procStart": stopStart})
	p := newFakeProc([]int{161}, map[int]string{161: stopStart}, []proc.Thread{})
	s := NewService(sb.roots, p, DefaultOptions(), nil)
	// activity.stop {cli, id}: an id the system does not know is a 404 and signals nothing (contract case stop_refuses_unknown).
	if _, err := s.Stop(context.Background(), CLIClaude, "no-such-session"); stopStatusOf(err) != 404 {
		t.Errorf("unknown id: %v", err)
	}
	if len(p.killedPids()) != 0 {
		t.Errorf("signalled %v", p.killedPids())
	}
	if r, err := s.Stop(context.Background(), CLIClaude, activitySid(161)); err != nil || !r.Exited {
		t.Errorf("known id: %+v %v", r, err)
	}
}
