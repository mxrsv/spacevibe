package clean

// Cache is one folder of the fixed allowlist (CL-R4): a folder under a CLI root whose meaning was checked against the
// CLI's own docs or source, as a cache that the CLI rebuilds and whose loss costs nothing the user made. Clean moves
// the entries directly inside it; the folder itself stays, so a CLI that does not create it again still finds it.
//
// The evidence for each path, and the candidates that were left out with the reason, are in
// docs/internals/clean.md#cache-allowlist. A path joins only with a primary source (the CLI's docs, its source code,
// or its shipped binary for behaviour), never on its name.
type Cache struct {
	// ID is "<cli>:<rel>", the selection id clean.move takes.
	ID string
	// CLI is the registry id.
	CLI string
	// Rel is the folder under the CLI root.
	Rel string
}

// allowlist is every cache Clean may offer, in display order per CLI. Checked 2026-11-21 against Claude Code 2.1.330
// (code.claude.com/docs/en/claude-directory, "Application data") and Codex at openai/codex 1145028.
var allowlist = []Cache{
	// Claude Code: "Delete → you lose: Nothing user-facing" or "Nothing" in the Application data table.
	{ID: "claude:cache", CLI: "claude", Rel: "cache"},
	{ID: "claude:shell-snapshots", CLI: "claude", Rel: "shell-snapshots"},
	{ID: "claude:session-env", CLI: "claude", Rel: "session-env"},
	{ID: "claude:debug", CLI: "claude", Rel: "debug"},
	{ID: "claude:image-cache", CLI: "claude", Rel: "image-cache"},
	{ID: "claude:statsig", CLI: "claude", Rel: "statsig"},
	{ID: "claude:todos", CLI: "claude", Rel: "todos"},
	// Codex: caches the source refetches or rebuilds (connectors, plugin catalog with a 3 h TTL, shell snapshots kept 3 days).
	{ID: "codex:cache", CLI: "codex", Rel: "cache"},
	{ID: "codex:shell_snapshots", CLI: "codex", Rel: "shell_snapshots"},
}

func cacheByID(id string) (Cache, bool) {
	for _, c := range allowlist {
		if c.ID == id {
			return c, true
		}
	}
	return Cache{}, false
}
