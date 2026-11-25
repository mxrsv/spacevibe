package activity

import (
	"context"
	"time"

	"spacevibe.dev/core/internal/proc"
	"spacevibe.dev/core/internal/roots"
)

// WatchInterval is how often a subscription polls when `activity.subscribe` names no interval
// (docs/internals/core-protocol.md, "Activity subscription"). MinWatchInterval and MaxWatchInterval bound the
// interval a caller may ask for.
const (
	WatchInterval    = 3 * time.Second
	MinWatchInterval = time.Second
	MaxWatchInterval = time.Minute
)

// Service is the Activity methods over one engine: activity.read, the activity.subscribe poll and activity.stop.
// Reads and polls share the engine, so folded offsets are never repeated.
type Service struct {
	roots  roots.Roots
	proc   proc.Adapter
	opts   Options
	now    func() time.Time
	engine *Engine
}

// NewService builds a service. now is the clock every age is computed against (time.Now in the app, fixed in tests);
// a nil now means time.Now.
func NewService(r roots.Roots, adapter proc.Adapter, opts Options, now func() time.Time) *Service {
	if now == nil {
		now = time.Now
	}
	return &Service{roots: r, proc: adapter, opts: opts, now: now, engine: NewEngine()}
}

// Read is the full report (activity.read, and the resync after a restart: a full read, never a delta).
func (s *Service) Read(ctx context.Context) (Report, error) {
	return s.engine.Read(ctx, s.roots, s.now(), s.proc, s.opts)
}

// Stop ends the running session cli/id; see Stop. It never takes a pid.
func (s *Service) Stop(ctx context.Context, cli CLI, id string) (StopResult, error) {
	return Stop(ctx, s.roots, cli, id, s.proc, DefaultStopOptions())
}
