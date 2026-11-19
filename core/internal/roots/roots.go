// Package roots finds the folders of the CLIs SpaceVibe reads and SpaceVibe's own data folder, and refuses
// any of them under the real home when SPACEVIBE_TEST=1 (AC3).
// Ported from Sources/ReinsCore/Roots.swift and FileEdit.refuseRealHomeUnderTest
// (Node inventory roots(), git b58269d).
package roots

import (
	"fmt"
	"path/filepath"
	"strings"

	"spacevibe.dev/core/internal/clis"
	"spacevibe.dev/core/internal/config"
	"spacevibe.dev/core/internal/identity"
)

// CLIRoots are the folders of one CLI that SpaceVibe reads, resolved from its registry layout (clis.Layout). A path
// the layout does not name is empty: that CLI has no such file.
type CLIRoots struct {
	Root   string
	Skills string
	Agents string
	// HookFile is Claude Code's settings.json, Codex's hooks.json.
	HookFile string
	// Logs holds the session logs: Claude projects/, Codex sessions/.
	Logs string
	// State is the CLI's global state file beside its root: Claude Code's .claude.json in CLAUDE_CONFIG_DIR when
	// that is set, otherwise in HOME beside .claude. Limits reads its usage cache and nothing else from it.
	State string
}

// Roots is where the config, the logs and SpaceVibe's own data live.
type Roots struct {
	// CLIs holds the folders of every CLI in the registry, keyed by id. Read it through CLI, which refuses an id
	// that has no entry instead of answering with empty paths.
	CLIs map[clis.ID]CLIRoots
	// Data is SpaceVibe's own data: journal, trash, caches.
	Data string
}

// CLI is the folders of one CLI, or an error wrapping clis.ErrUnknownCLI.
func (r Roots) CLI(id clis.ID) (CLIRoots, error) {
	if c, ok := r.CLIs[id]; ok {
		return c, nil
	}
	return CLIRoots{}, fmt.Errorf("%w %q: no folders resolved", clis.ErrUnknownCLI, id)
}

// UnderRealHomeError means SPACEVIBE_TEST=1 and a root sits under the real home.
type UnderRealHomeError struct {
	// Label is a CLI id (claude, codex, gemini), "<id> state" for a state file, or spacevibe.
	Label string
	// Path is the offending root, as configured.
	Path string
}

func (e *UnderRealHomeError) Error() string {
	return fmt.Sprintf("%s=1: the %s root %s is under the real home. Point %s at a temporary folder.",
		envTest, e.Label, e.Path, overrideNames())
}

// overrideNames is "HOME, CLAUDE_CONFIG_DIR, CODEX_HOME and SPACEVIBE_HOME": every variable that moves a root.
func overrideNames() string {
	names := []string{"HOME"}
	for _, d := range clis.All() {
		if d.Layout.RootEnv != "" {
			names = append(names, d.Layout.RootEnv)
		}
	}
	return strings.Join(names, ", ") + " and " + envHome
}

const (
	envTest = identity.EnvPrefix + "TEST"
	envHome = identity.EnvPrefix + "HOME"
)

// Resolve derives every root from cfg and the registry. An empty value counts as unset; HOME falls back to
// realHome. realHome is the account's real home folder from RealHome; tests pass a stand-in.
// With cfg.Test set it returns *UnderRealHomeError when a root, or the real path behind it, is
// under realHome. The roots are checked in this order: each CLI's root, the data folder, each CLI's state file.
func Resolve(cfg config.Config, realHome string) (Roots, error) {
	home := orDefault(cfg.UserHome, realHome)
	dataRoot := orDefault(cfg.Home, filepath.Join(home, identity.DataDir))
	resolved := make(map[clis.ID]CLIRoots, len(clis.All()))
	var rootsFirst, statesLast []labelled
	for _, d := range clis.All() {
		c := resolveCLI(d.Layout, home, cfg.RootOverrides[d.ID])
		resolved[d.ID] = c
		rootsFirst = append(rootsFirst, labelled{string(d.ID), c.Root})
		if c.State != "" {
			statesLast = append(statesLast, labelled{string(d.ID) + " state", c.State})
		}
	}
	if cfg.Test {
		checked := append(append(rootsFirst, labelled{"spacevibe", dataRoot}), statesLast...)
		if err := assertNotUnderRealHome(realHome, checked); err != nil {
			return Roots{}, err
		}
	}
	return Roots{CLIs: resolved, Data: dataRoot}, nil
}

// resolveCLI places a layout under its root: override when set, otherwise the layout's folder under home.
func resolveCLI(l clis.Layout, home, override string) CLIRoots {
	root := orDefault(override, filepath.Join(home, l.Folder))
	in := func(name string) string {
		if name == "" {
			return ""
		}
		return filepath.Join(root, name)
	}
	c := CLIRoots{Root: root, Skills: in(l.Skills), Agents: in(l.Agents), HookFile: in(l.HookFile), Logs: in(l.Logs)}
	if l.StateFile != "" {
		c.State = filepath.Join(orDefault(override, home), l.StateFile)
	}
	return c
}

func orDefault(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}
