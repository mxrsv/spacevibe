package activity

import (
	"context"

	"spacevibe.dev/core/internal/logs"
	"spacevibe.dev/core/internal/pricing"
)

// tokenLineCap is the longest line LogTokens folds, the cap the engine's tail reads use.
const tokenLineCap = 16 << 20

// tokenCancelLines is how many lines LogTokens reads between looks at the context.
const tokenCancelLines = 4096

// ModelTokens is one model's tokens in one log.
type ModelTokens struct {
	Model string
	Usage pricing.Usage
}

// LogTokens folds a whole log from its first line, the same fold a session read uses, and returns its tokens per model
// in the order the models first appeared. Clean archives them before the log moves (CL-R3). ok is false when the log
// cannot be read to the end; the error is only the context's. The log text never leaves this function (S-R3).
func LogTokens(ctx context.Context, path string, cli CLI) (tokens []ModelTokens, ok bool, err error) {
	st := newLogState(cli)
	lines := 0
	_, readErr := logs.ForEachLine(path, tokenLineCap, func(line []byte) error {
		if lines++; lines%tokenCancelLines == 0 {
			if err := ctx.Err(); err != nil {
				return err
			}
		}
		fold(st, line)
		return nil
	})
	if readErr != nil {
		return nil, false, ctx.Err()
	}
	for _, m := range st.metrics.Entries() {
		tokens = append(tokens, ModelTokens{Model: m.Key, Usage: m.Value})
	}
	return tokens, true, nil
}
