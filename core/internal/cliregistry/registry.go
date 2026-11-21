// Package cliregistry is the one list of CLIs SpaceVibe knows: each CLI's string id, its display name, its
// place in the fixed order every page uses, and which concepts it has (the `supports` map). It is the result
// of the `clis.registry` method and the set of keys of every `cliCells` map in `loadout.rows`
// (docs/internals/core-protocol.md).
//
// The engine reads Claude Code and Codex only, so the registry lists those two. Another CLI joins by adding
// an entry here together with its readers (spec 2026-11-20-spacevibe-redesign "Out of scope"); the shape of
// the wire already allows any number of entries and any string id. The package has no imports, so every
// other package can use it.
package cliregistry

// ID is a CLI's registry id: lowercase, stable, the same string the rest of the protocol uses for that CLI
// (`Cli` in core-protocol.md, usage.CLI, the keys of `roots` and `events`).
type ID string

// The ids of the CLIs the engine reads.
const (
	Claude ID = "claude"
	Codex  ID = "codex"
)

// Supports says which concepts a CLI has. False means "Not supported": the CLI has no such concept, which is
// not the same as Missing (the concept exists, the item is not installed) or Unmeasurable (installed, but
// nothing SpaceVibe can count). Skill, Agent and Hook are named after the wire `kind` values, so a caller
// can look up an item's kind directly.
type Supports struct {
	// Skill: the CLI loads skills (a folder with SKILL.md).
	Skill bool `json:"skill"`
	// Agent: the CLI loads subagents.
	Agent bool `json:"agent"`
	// Hook: the CLI runs hook commands on its events.
	Hook bool `json:"hook"`
	// Rule: the CLI has permission settings SpaceVibe can read (rules.snapshot; only Claude Code's are written).
	Rule bool `json:"rule"`
	// Logs: the CLI keeps session logs SpaceVibe can count usage from. Without them every installed item of
	// the CLI is Unmeasurable, never 0.
	Logs bool `json:"logs"`
	// Limits: the CLI leaves usage-limit records on this Mac (limits.read).
	Limits bool `json:"limits"`
}

// CLI is one registry entry.
type CLI struct {
	ID       ID       `json:"id"`
	Name     string   `json:"name"`
	Supports Supports `json:"supports"`
}

// Result is the `clis.registry` result: every CLI, in the fixed order.
type Result struct {
	CLIs []CLI `json:"clis"`
}

// all is the registry in the fixed order. Never handed out: All returns a copy.
var all = [...]CLI{
	{ID: Claude, Name: "Claude Code", Supports: Supports{Skill: true, Agent: true, Hook: true, Rule: true, Logs: true, Limits: true}},
	{ID: Codex, Name: "Codex", Supports: Supports{Skill: true, Agent: true, Hook: true, Rule: true, Logs: true, Limits: true}},
}

// All is every CLI in the fixed order, as a new slice the caller may change.
func All() []CLI {
	out := make([]CLI, len(all))
	copy(out, all[:])
	return out
}

// Read is the `clis.registry` result. It reads nothing: the registry is part of the binary.
func Read() Result { return Result{CLIs: All()} }

// Lookup is the entry of one id; false for an id the registry does not hold.
func Lookup(id ID) (CLI, bool) {
	for _, c := range all {
		if c.ID == id {
			return c, true
		}
	}
	return CLI{}, false
}
