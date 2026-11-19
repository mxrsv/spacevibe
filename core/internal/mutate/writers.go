package mutate

import (
	"strings"

	"spacevibe.dev/core/internal/clis"
	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/roots"
	"spacevibe.dev/core/internal/usage"
)

// cliWriter is how SpaceVibe writes one CLI's files, beyond the folders its registry layout names (skills, agents,
// hook file), which every write uses the same way.
type cliWriter interface {
	// agentFile is the file extension and text of a new agent in the CLI's own format.
	agentFile(name, description, instructions string) (ext, text string)
	// takesCopiedHooks is true when a hook copied from another CLI may be written into this CLI's hook file.
	takesCopiedHooks() bool
	// configFiles are the CLI's configuration files an Undo may edit. They are matched by real path, so a file that
	// is a link out of the CLI folder (a dotfiles setup) is still accepted.
	configFiles(cli roots.CLIRoots) []string
}

// writers is the mutate adapter of every CLI with the mutate concept. A CLI without one is never written: a write
// naming it is refused with an error wrapping clis.ErrUnknownCLI or clis.ErrConceptAbsent, never sent to another
// CLI's folders.
var writers = clis.NewAdapters(clis.Mutate, map[clis.ID]cliWriter{
	clis.Claude: claudeWriter{},
	clis.Codex:  codexWriter{},
})

// writerOf is the writer and folders of a CLI SpaceVibe writes.
func (tx *Tx) writerOf(cli usage.CLI) (cliWriter, roots.CLIRoots, error) {
	w, err := writers.For(cli)
	if err != nil {
		return nil, roots.CLIRoots{}, err
	}
	folders, err := tx.r.CLI(cli)
	if err != nil {
		return nil, roots.CLIRoots{}, err
	}
	return w, folders, nil
}

// cliRoots is the folders of a CLI SpaceVibe writes; see writerOf.
func (tx *Tx) cliRoots(cli usage.CLI) (roots.CLIRoots, error) {
	_, folders, err := tx.writerOf(cli)
	return folders, err
}

// label is the CLI's product name from the registry; an id with no entry is shown as it is.
func label(cli usage.CLI) string {
	if d, err := clis.Lookup(cli); err == nil {
		return d.Label
	}
	return string(cli)
}

func labels(targets []usage.CLI) string {
	parts := make([]string, len(targets))
	for i, cli := range targets {
		parts[i] = label(cli)
	}
	return strings.Join(parts, " and ")
}

// copyTarget is the CLI CopyToOther writes to: the one other CLI SpaceVibe writes. With more than one candidate the
// target is ambiguous, because the request names none, and the copy is refused.
func copyTarget(source usage.CLI) (usage.CLI, error) {
	var others []usage.CLI
	for _, w := range writers.InOrder() {
		if w.ID != source {
			others = append(others, w.ID)
		}
	}
	if len(others) != 1 {
		return "", fail("SpaceVibe cannot tell which CLI to copy this to.", coreerr.StatusConflict)
	}
	return others[0], nil
}

// writableIDs is "claude or codex": the ids of the CLIs SpaceVibe writes, for the refusal of any other id.
func writableIDs() string {
	var ids []string
	for _, w := range writers.InOrder() {
		ids = append(ids, string(w.ID))
	}
	return strings.Join(ids, " or ")
}
