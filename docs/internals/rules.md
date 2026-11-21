# Rules

The permission Rules of the CLIs: for Claude Code the `allow`, `ask` and `deny` entries of `settings.json` (list, add, remove, change verdict, and a capability grid derived from them, with a cell write), and for Codex a read-only summary of its permission keys. The Rules tab reads one `rules.snapshot` per scope and writes through the other `rules.*` methods. A Rule here is a permission entry (see [GLOSSARY.md](../../GLOSSARY.md)); `CLAUDE.md` and `AGENTS.md` are Instructions and no code under `core/internal` reads or writes them, so there is no import, size or token handling to document.

Code: [`core/internal/rules`](../../core/internal/rules); the eight `rules.*` handlers are wired in [`core/internal/rpc/methods`](../../core/internal/rpc/methods), which shares one project list with inventory. In the shell, `isEditable` in [RulesSnapshot.swift](../../Sources/SpaceVibe/Rules/RulesSnapshot.swift) decides whether a cell may be edited, and [RuleFamilies.swift](../../Sources/SpaceVibe/Rules/RuleFamilies.swift) holds the tool families judged by wide rules. The wire shape of each method is in [core-protocol.md](core-protocol.md); this page does not repeat it.

## Where each fact comes from

| Fact | Read from |
| --- | --- |
| Claude Code rules, global | `permissions.allow`, `.ask`, `.deny` in `<claude root>/settings.json` (`Roots.Claude.HookFile`); a link is followed |
| Claude Code rules, project and local | `<project>/.claude/settings.json` and `settings.local.json`; the folder must be in the discovered project list ([inventory.md](inventory.md)) |
| Claude Code managed settings, imports | Not read |
| Any other settings key (`env`, `defaultMode`, ...) | Not read or returned |
| Capability grid | The rules of the one selected file only; nothing is merged across scopes |
| Codex permission keys | `<codex root>/config.toml`, only the keys [codex.go](../../core/internal/rules/codex.go) names; global only, there is no project file |
| Codex rule counts | `<codex root>/rules/*.rules`, a count per decision, never the patterns |

## Runtime path

Read (`rules.snapshot`):

1. `Service.Snapshot` checks the scope params, then takes the process's project list (rediscovered only on `refreshProjects` or when empty).
2. A project or local scope whose folder is not in the list becomes global; the result's `scope` says what was read.
3. `ListRules` reads the global file, then the selected one: locate, folder state, inside-project check, presence, read (16 MiB cap), parse, rules in the order allow, ask, deny.
4. The grid is derived from the selected file's rules, `ReadCodexPermissions` is attached, and every problem has the settings-file path swapped for the scope's label.

Write (`rules.add`, `remove`, `changeVerdict`, `changeVerdicts`, `removeMany`, `setCapability`):

1. `Service.begin` looks at the cancel, checks the params and takes the project list without rediscovering; the store builds the journal label.
2. `Store.edit` takes the write lock and checks the cancel again, then refuses in this order: scope (400, 404), folder (409), link out of the project (409).
3. `tx.EditJSON` refuses a corrupt journal, reads the file, and runs the change on the document it just read: it re-checks the rule, or re-plans the cell, then `editRules` edits the lists.
4. A byte re-check just before the rename guards against another writer; then one journal entry. No change at all means no write and no entry. Lock, journal and Undo are in [mutations.md](mutations.md).

## Rules that are easy to get wrong

- **A grid or list describes one file, never the effective permissions.** `CapabilityGrid` gets the selected scope's rules only, and managed settings and the other scopes are not read, so a project cell of `none` does not mean "unrestricted". Never label a cell as what Claude Code will do. [service.go](../../core/internal/rules/service.go) `Snapshot`.
- **A cell write replaces wide rules only.** `Read`, `Edit`, `Run` and `Network` replace bare or `*` rules of that cell; `Push and deploy` and `Secrets` replace their own rules; path or command rules are never touched, and a `mixed` cell is refused (409). A bare `Bash` is wide for both Run and Push, and a bare `Read` for both Read and Secrets, so `Preview.Resulting` can differ from the asked verdict. Push and deploy is a text heuristic (`git push`, `vercel` and the like at the start, or the word `deploy` anywhere), not a parse. [grid.go](../../core/internal/rules/grid.go), [parse.go](../../core/internal/rules/parse.go) `pushPattern`.
- **`wide` is the grid's wide test on a tool that takes a specifier.** Every `Rule` (list and grid cells, every scope, any verdict) carries `wide`: true for a bare `Tool`, `Tool()`, a blank `Tool(  )` or a specifier that trims to `*`, and only for `Bash`, `Read`, `Edit`, `Write`, `MultiEdit`, `NotebookEdit`, `WebFetch` and `WebSearch` (RD-R17). An MCP name, any other tool, another spelling of a name (`bash`) and a string that is not a rule are never wide. A specifier a person reads as "everything" (`Bash(:*)`, `Read(**)`, `WebFetch(domain:*)`) is not wide, because the grid and a cell write treat it as narrow and the flag must name the same rules a cell write replaces. [parse.go](../../core/internal/rules/parse.go) `coversWholeTool`.
- **A preview is advice; the write plans again.** `plan` lists the file without the lock. `SetCapability` plans from the document read inside the lock, so a rule that appeared in between changes what is replaced, or makes the cell mixed and the write 409. Show `rules.preview` as a forecast, not a promise. [capability-write.go](../../core/internal/rules/capability-write.go).
- **`rules.removeMany` reads rule ids, which do not name a project.** A rule id is `<scope>:<verdict>:<rule>` with no folder, so the call carries `scope` and `dir` like every other write and refuses (400) an id of another scope kind; the rule is everything after the second colon, so `Bash(npm run:*)` reads whole. Every rule is checked in the document read under the lock and all go in one edit, or none. [remove-many.go](../../core/internal/rules/remove-many.go)
- **Staleness is checked by content, not by a revision.** There is no version token. Remove and change check that the rule is still under the verdict the caller saw (409 "already changed"), add refuses a rule that exists under any verdict, and a final byte comparison before the rename catches Claude Code, which never takes our lock (409 "changed while SpaceVibe was editing it"). [store.go](../../core/internal/rules/store.go) `requireRule`, [file-edit.go](../../core/internal/mutate/file-edit.go) `BeforeRename`.
- **Edits keep everything but the touched lists.** Other keys, indent and line endings stay. A removed rule leaves every duplicate; non-string items stay; a changed or added rule goes to the end of its list and is not added twice. A no-op becomes 409 "Nothing to change" for add, remove and change, and a `null` entry for `setCapability`. [settings-file.go](../../core/internal/rules/settings-file.go) `editRules`.
- **Only the global file may be a link.** A project or local file must really be `<project>/.claude/settings*.json`: a `.claude` that resolves elsewhere or a settings file that is a link is refused (409), because a hostile repo could point it at another JSON file. Listing reports it as a problem, not as `notReadable`. [store.go](../../core/internal/rules/store.go) `requireInsideProject`.
- **The scrub covers the settings-file path, nothing else.** `scrub` swaps that path (and its resolved spelling) for the scope's label. The folder-link messages still name the project folder, and journal labels carry it. A new message that names another path reaches the shell as written. [service.go](../../core/internal/rules/service.go) `scrub`.
- **Codex facts are partial and `model` is not "unknown"-aware.** `Model` is `legacy` whenever no `default_permissions` is read, including with no `config.toml` or an unreadable one, so read `present`, `notReadable`, `skippedLines` and `warnings` first. `.rules` counts come from a text scan: a `prefix_rule(` without `decision` counts as allow, and a `#` after code is not a comment. `unrestricted` means `sandbox_mode = "danger-full-access"` only. [codex.go](../../core/internal/rules/codex.go), [codex-rules.go](../../core/internal/rules/codex-rules.go).
- **`rules.check` is not the write's check.** `Check` trims and counts newlines the Foundation way (U+0085 yes, U+FEFF no; `\v`, `\f`, U+2028 are newlines); the write only refuses `\n` and `\r` and trims the JavaScript way. Both cap a rule at 1000 UTF-16 units. Keep the write's check authoritative. [parse.go](../../core/internal/rules/parse.go) `Check`.

## Failure behavior

- **Unreadable is not empty.** A settings file or project folder that cannot be looked at, or a file over 16 MiB, sets `notReadable` with a fixed sentence in `problems`; Codex does the same in `warnings` (`config.toml`, the rules folder, a `.rules` file over 1 MiB). The core refuses writes through the write path; whether a cell is editable is decided by the shell (`RulesSnapshot.isEditable`: no problems, not unreadable, not mixed).
- **Invalid or wrong-shaped settings.** Not JSON, not an object, `permissions` not an object or a verdict list not an array: a problem when listing, 409 on every write and on a preview; the file is not touched and no message quotes content. A blank file lists as empty and a write treats it as `{}`.
- **Not UTF-8.** Listing repairs the text; a write refuses (409).
- **Project folder gone or unknown.** Unknown is 404 on every method except `rules.snapshot`, which reads global. A discovered folder deleted since is 404 when selected and a problem line when listed among several scopes. An undiscovered folder never gets a `.claude` created.
- **Cancelled or queued.** A cancel while waiting for the lock changes nothing; once the body runs it is ignored ([core-protocol.md](core-protocol.md#notifications-and-cancellation)).
- **Under `SPACEVIBE_TEST=1`** this package changes nothing itself. The roots refuse a real home and the write guard refuses any write under it ([guard.go](../../core/internal/roots/guard.go), [startup.go](../../core/cmd/spacevibe/startup.go)); a write outside the temp home is 500.

## Verification

`cd core && SPACEVIBE_TEST=1 go test -count=1 ./internal/rules/...` runs against temporary homes or the fixture home. [`scripts/rules-shots.sh`](../../scripts/rules-shots.sh) writes screenshots of the Rules tab on a synthetic home; it is not a test.
