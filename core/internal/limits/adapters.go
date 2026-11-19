package limits

import (
	"context"

	"spacevibe.dev/core/internal/clis"
	"spacevibe.dev/core/internal/config"
	"spacevibe.dev/core/internal/roots"
)

// readInput is what a reader may look at: the configuration, every root (the data folder holds the status line
// snapshots), the CLI's own folders and the clock in seconds.
type readInput struct {
	cfg   config.Config
	roots roots.Roots
	cli   roots.CLIRoots
	now   float64
}

// reader reads one CLI's usage-limit windows from its own files.
type reader interface {
	// read is the CLI's entry. The only error is the context's.
	read(ctx context.Context, in readInput) (Entry, error)
}

// readers is the limits adapter of every CLI with the limits concept. A CLI without one is left out of the result,
// never reported with another CLI's reading.
var readers = clis.NewAdapters(clis.Limits, map[clis.ID]reader{
	clis.Claude: claudeReader{},
	clis.Codex:  codexReader{},
	clis.Gemini: geminiReader{},
})
