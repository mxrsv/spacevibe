package inventory

import (
	"context"

	"spacevibe.dev/core/internal/clis"
	"spacevibe.dev/core/internal/roots"
)

// cliInventory is one CLI's side of an inventory read, beyond what its registry layout already says (the skills
// and agents folders and the hook file, which Read handles the same way for every CLI).
type cliInventory interface {
	// events are the hook events the CLI documents, in its own order.
	events() []string
	// unloggedHooks is why the CLI's hook runs cannot be counted (the cell is unmeasurable), or "" when its logs
	// record them.
	unloggedHooks() string
	// readExtras adds what the CLI keeps outside its root folders (Claude Code: plugins and skill overrides). Read
	// calls it after every CLI's root folders were read.
	readExtras(ctx context.Context, cli roots.CLIRoots, acc *readAcc)
}

// cliProjects is one CLI's side of project discovery.
type cliProjects interface {
	// projectCandidates are the project paths the CLI's own files record, newest first where it knows.
	projectCandidates(ctx context.Context, cli roots.CLIRoots) []string
	// projectFolder is the configuration folder the CLI reads inside a project; false when it reads none.
	projectFolder() (projectFolder, bool)
}

// inventoryAdapter is everything one CLI contributes to Read.
type inventoryAdapter interface {
	cliInventory
	cliProjects
}

// projectFolder is the per-project configuration of a CLI: <project>/<Name>/skills, <project>/<Name>/agents and the
// hook files listed. A path containing Worktrees is a copy of a project already listed and is skipped.
type projectFolder struct {
	Name      string
	HookFiles []string
	Worktrees string
}

// adapters is the inventory adapter of every CLI with the inventory concept. A CLI without one has no skills,
// agents or hooks to show: it is left out of Read, never read as another CLI.
var adapters = clis.NewAdapters(clis.Inventory, map[clis.ID]inventoryAdapter{
	clis.Claude: claudeInventory{},
	clis.Codex:  codexInventory{},
})

// boundAdapter is an adapter with its CLI's id and folders.
type boundAdapter struct {
	id      CLI
	adapter inventoryAdapter
	roots   roots.CLIRoots
}

// bind pairs every inventory adapter with its CLI's folders, in wire order. A CLI r has no folders for is an error
// wrapping clis.ErrUnknownCLI (a Roots not built by roots.Resolve).
func bind(r roots.Roots) ([]boundAdapter, error) {
	var out []boundAdapter
	for _, a := range adapters.InOrder() {
		cli, err := r.CLI(a.ID)
		if err != nil {
			return nil, err
		}
		out = append(out, boundAdapter{a.ID, a.Adapter, cli})
	}
	return out, nil
}

// Events are the hook events each CLI with the inventory concept documents, keyed by CLI id.
func Events() map[string][]string {
	out := map[string][]string{}
	for _, a := range adapters.InOrder() {
		out[string(a.ID)] = a.Adapter.events()
	}
	return out
}

// EventsOf is the hook events of one CLI, or an error wrapping clis.ErrUnknownCLI or clis.ErrConceptAbsent.
func EventsOf(cli CLI) ([]string, error) {
	a, err := adapters.For(cli)
	if err != nil {
		return nil, err
	}
	return a.events(), nil
}

// UnloggedHooks is why the hook runs of cli cannot be counted, "" when its logs record them.
func UnloggedHooks(cli CLI) (string, error) {
	a, err := adapters.For(cli)
	if err != nil {
		return "", err
	}
	return a.unloggedHooks(), nil
}
