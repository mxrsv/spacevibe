package inventory

import (
	"context"
	"path/filepath"

	"spacevibe.dev/core/internal/roots"
	"spacevibe.dev/core/internal/textjs"
	"spacevibe.dev/core/internal/toml"
)

// codexInventory is Codex: skills, agents (.toml) and hooks.json in CODEX_HOME. Codex has no plugins, no project
// configuration folder and logs no hook runs; its config.toml names projects.
type codexInventory struct{}

// CodexHooksReason is why a Codex hook cell is unmeasurable.
const CodexHooksReason = "Codex does not log hook runs"

// codexEvents come from observation only.
func (codexInventory) events() []string {
	return []string{"SessionStart", "UserPromptSubmit", "PreToolUse", "PermissionRequest", "PostToolUse", "SubagentStart", "SubagentStop", "Interrupt", "Stop", "SessionEnd"}
}

func (codexInventory) unloggedHooks() string { return CodexHooksReason }

func (codexInventory) readExtras(context.Context, roots.CLIRoots, *readAcc) {}

// projectCandidates are the [projects."<path>"] tables of config.toml.
func (codexInventory) projectCandidates(_ context.Context, cli roots.CLIRoots) []string {
	return codexProjectKeys(filepath.Join(cli.Root, "config.toml"))
}

func (codexInventory) projectFolder() (projectFolder, bool) { return projectFolder{}, false }

func codexProjectKeys(configFile string) []string {
	data, ok := readData(configFile, maxTextBytes)
	if !ok {
		return nil
	}
	doc := toml.Read(textjs.Repair(string(data)))
	var out []string
	for _, p := range doc.TablePaths([]string{"projects"}) {
		if len(p) >= 2 {
			out = append(out, p[1])
		}
	}
	return out
}
