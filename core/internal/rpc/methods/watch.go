package methods

import (
	"bytes"
	"context"
	"encoding/json"
	"time"

	"spacevibe.dev/core/internal/activity"
	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/rpc"
)

// errClosed answers a subscribe that arrives after Close; never (nil, nil), which would read as a null result.
var errClosed = coreerr.NewStatus("The core is shutting down.", coreerr.StatusInternalFailure)

// watch is the one activity subscription of the connection.
type watch struct {
	cancel context.CancelFunc
	done   chan struct{}
}

// stop ends the poll and waits for it, so nothing is sent after stop returns. A nil watch is fine.
func (w *watch) stop() {
	if w == nil {
		return
	}
	w.cancel()
	<-w.done
}

// subscribeParams is `activity.subscribe`'s optional member: the poll interval in milliseconds.
type subscribeParams struct {
	IntervalMs *int `json:"intervalMs"`
}

// interval is the poll interval the params ask for, WatchInterval when they ask for none.
func (p subscribeParams) interval() (time.Duration, error) {
	if p.IntervalMs == nil {
		return activity.WatchInterval, nil
	}
	d := time.Duration(*p.IntervalMs) * time.Millisecond
	if d < activity.MinWatchInterval || d > activity.MaxWatchInterval {
		return 0, coreerr.New("intervalMs must be between 1000 and 60000.")
	}
	return d, nil
}

// activitySubscribe returns the full report and starts the poll that pushes activity/report when the encoded
// report differs from the last one sent on this connection. The baseline is the very report returned here, so a
// change between the two reads is not lost. A second subscribe replaces the first and returns a fresh snapshot.
func (s *Services) activitySubscribe(ctx context.Context, call rpc.Call) (any, error) {
	var p subscribeParams
	if err := rpc.DecodeParams(call.Params, &p); err != nil {
		return nil, err
	}
	interval, err := p.interval()
	if err != nil {
		return nil, err
	}
	report, err := s.activity.Read(ctx)
	if err != nil {
		s.noteFailure("activity.subscribe", err)
		return nil, err
	}
	last, err := json.Marshal(report)
	if err != nil {
		return nil, err
	}
	base := call.Session // cancelled at end of input, before the drain wait
	if base == nil {
		base = context.Background()
	}
	wctx, cancel := context.WithCancel(base)
	w := &watch{cancel: cancel, done: make(chan struct{})}

	s.watchMu.Lock()
	defer s.watchMu.Unlock()
	if s.closed {
		cancel()
		return nil, errClosed
	}
	s.watching.stop()
	s.watching = w
	go func() {
		defer close(w.done)
		s.poll(wctx, call, last, interval)
	}()
	return report, nil
}

func (s *Services) poll(ctx context.Context, call rpc.Call, last []byte, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
		report, err := s.activity.Read(ctx)
		if err != nil {
			continue // a failed read is retried on the next tick; the shell keeps its last report
		}
		encoded, err := json.Marshal(report)
		if err != nil || bytes.Equal(encoded, last) {
			continue
		}
		last = encoded
		if ctx.Err() == nil {
			call.Notify("activity/report", report)
		}
	}
}

func (s *Services) activityUnsubscribe(_ context.Context, _ none) (struct{}, error) {
	s.watchMu.Lock()
	w := s.watching
	s.watching = nil
	s.watchMu.Unlock()
	w.stop()
	return struct{}{}, nil
}
