package usage

import (
	"fmt"

	"spacevibe.dev/core/internal/clis"
)

// The wire objects Totals, Windows and Sessions still have one fixed member per CLI ("claude", "codex"). This file is
// the only place that maps a CLI id to its member. A CLI with no member is an error wrapping clis.ErrUnknownCLI,
// never another CLI's member; a CLI added to the registry with the usage concept fails here (and in
// TestEveryUsageCLIHasAWireSlot) until the wire carries a map keyed by CLI id.

func errNoSlot(cli CLI) error {
	return fmt.Errorf("%w %q: the usage wire has no member for it", clis.ErrUnknownCLI, cli)
}

func (t *Totals) slot(cli CLI) (*CLITotals, error) {
	switch cli {
	case clis.Claude:
		return &t.Claude, nil
	case clis.Codex:
		return &t.Codex, nil
	}
	return nil, errNoSlot(cli)
}

// For returns the totals of one CLI.
func (t Totals) For(cli CLI) (CLITotals, error) {
	s, err := t.slot(cli)
	if err != nil {
		return CLITotals{}, err
	}
	return *s, nil
}

func (w *Windows) slot(cli CLI) (*LogWindow, error) {
	switch cli {
	case clis.Claude:
		return &w.Claude, nil
	case clis.Codex:
		return &w.Codex, nil
	}
	return nil, errNoSlot(cli)
}

// For returns the window of one CLI.
func (w Windows) For(cli CLI) (LogWindow, error) {
	s, err := w.slot(cli)
	if err != nil {
		return LogWindow{}, err
	}
	return *s, nil
}

func (s *Sessions) slot(cli CLI) (*int, error) {
	switch cli {
	case clis.Claude:
		return &s.Claude, nil
	case clis.Codex:
		return &s.Codex, nil
	}
	return nil, errNoSlot(cli)
}
