# Inventory

What is installed for Claude Code and Codex: skills, subagents and hooks, read from disk without running anything, then joined to usage so each row can say whether it ran. The Agents page, the filter counts and the delete and warning actions all read this snapshot. Terms follow [GLOSSARY.md](../../GLOSSARY.md).

Code: [`core/internal/inventory`](../../core/internal/inventory), [`core/internal/roots`](../../core/internal/roots) (where each CLI's config, logs and SpaceVibe's own data live; it refuses a real home under `SPACEVIBE_TEST=1`, S-R1) and [`core/internal/hashes`](../../core/internal/hashes).

## Where each fact comes from

| Fact | Read from |
| --- | --- |
| Skills | `<cli root>/skills/<name>/SKILL.md`; for Codex also `~/.agents/skills/<name>/SKILL.md` ([readers map](#readers-map)); plugin skills under the plugin's install folder |
| Subagents | `<cli root>/agents/*.md` (Claude) and `*.toml` (Codex; `name` and `description` only) |
| Hooks | Claude `settings.json`, Codex `hooks.json`, a plugin's `hooks/hooks.json`, a project's `settings.json` and `settings.local.json` |
| Plugins | `plugins/installed_plugins.json` joined to `enabledPlugins` in `settings.json`; a plugin whose install folder is gone is skipped |
| Projects | The `cwd` in the head of the newest Claude session logs, and `[projects."<path>"]` in Codex `config.toml` |
| Skill override | `skillOverrides` in Claude `settings.json`, global skills only |

Settings are read only for hooks, plugin flags and skill overrides. No other value, `env` in particular, is kept or returned (S-R3).

## Runtime path

1. [`roots.Resolve`](../../core/internal/roots/roots.go) fixes the folders from `HOME`, `CLAUDE_CONFIG_DIR`, `CODEX_HOME` and `SPACEVIBE_HOME`. The shared `~/.agents/skills` follows `HOME`, not `CODEX_HOME`, and the real-home guard covers it like every other root.
2. [`inventory.Read`](../../core/internal/inventory/reader.go) lists each CLI, then enabled plugins, then each discovered project. It reads the disk synchronously.
3. [`AttachUsage`](../../core/internal/inventory/attach-usage.go) takes a `usage.Input` from the usage scan ([usage.md](usage.md)) and fills `cells` on every row and `usage` on every Claude hook.
4. [`FilterCountsOf`](../../core/internal/inventory/filter-counts.go) turns rows into chip counts.

## Rules that are easy to get wrong

- **Row identity.** An item's `key` is kind, project and bare name, so the same skill in both CLIs is one matrix row. A hook's `key` is project and hash. Its `id` differs: a global hook id hashes owner, event, matcher and command; a project hook id also hashes its file, so the same hook in two files has two ids but one `key`.
- **Split rows.** The core's `key` can hold two members of one CLI (a user skill and a plugin skill of one name; two hooks of one hash with different matchers). The core still builds `cells` and `rowFlags` per `key`, last member wins. The shell ([`LoadoutRows.build`](../../Sources/SpaceVibe/Agents/LoadoutRows.swift)) therefore splits such a group by owner class (`user` and `link` together, else the plugin name; for hooks also the matcher): the first part keeps the core `key`, later parts are `<key>#<n>`, and a duplicate inside one part takes the next number. A split row reads `missing` for a CLI it has no member in, takes `rowFlags` from the core `key`, and a group with at most one member per CLI is unchanged. `globalCount` is the number of built global rows. These initial numbered keys are not stable identities: after a reload, `LoadoutData.build` matches surviving core member ids to the previous rows and reserves their display keys before naming new rows. This keeps the current row, multi-selection and open details on the same surviving member when a sibling is removed or reordered; core usage and flags still use the original core key.
- **Hook hash is event plus command.** Hashing the command alone inflates run counts, because the same command is often wired to several events ([hashes.go](../../core/internal/hashes/hashes.go)). The logs do not say which file a hook came from, so a hook in a global and a project file shares one count.
- **Dead hook.** A hook is dead only when its command names at least one script path and every path is missing. A path SpaceVibe cannot stat is not "missing": the hook is not marked dead and a problem sentence says so.
- **Plugin names.** A plugin-qualified name (`plugin:skill`) is matched by its part after the last `:` ([`hashes.Bare`](../../core/internal/hashes/hashes.go)).
- **Project discovery is bounded.** At most `MaxProjects` (300, [types.go](../../core/internal/inventory/types.go)) folders, newest first, 3 logs per folder, 64 KB per log. A project never opened with either CLI is not found, and a `cwd` that falls outside the first 64 KB is missed. The home folder and paths under `.claude/worktrees/` are skipped.
- **Frontmatter is not YAML.** Only flat `key: value` lines are read, for the `name` and `description` of a `SKILL.md` or a subagent `.md` ([frontmatter.go](../../core/internal/inventory/frontmatter.go)).
- **Unreadable is not empty.** An unreadable CLI root, folder or settings file adds a sentence to `problems` and keeps going; it never reads as "nothing installed". The UI shows `problems`.
- **Item ownership.** `owner` is `user`, `link` (a symlink) or the plugin name. Only user-level items outside any project are `removable`; plugin items are read-only, and so are the Codex skills read from `~/.agents/skills`, which only `loadout.rows`' `extraItems` carries ([readers map](#readers-map)).
- **Hook events.** `Events` in [types.go](../../core/internal/inventory/types.go) lists the events each CLI documents. Claude's list comes from its docs, Codex's from observation only.

## Usage cell states

`AttachUsage` gives each row one `Cell` per CLI, whose state is counted, pending, unmeasurable or missing. `pending` is current behaviour of the core. [D63](../specs/2026-11-06-spacevibe-linear-identity-decisions.md) decided that it stops being a state and becomes a note on `Never ran`: the shell already shows it that way ([`SkillCell`](../../Sources/SpaceVibe/Agents/LoadoutRows.swift) maps an "Added…" reason to Never ran with the note, "No logs scanned" to unmeasurable and an unfinished scan to loading), and the core's state has not been removed.

- **Missing**: the row is not installed in that CLI.
- **Unmeasurable**: a Codex hook; Codex logs no hook runs.
- **Pending**: zero runs and no scanned log can have covered the row: its CLI has no scanned logs, its file changed in the last 24 hours, or it changed after the newest log. The scan not having finished also yields pending.
- **Counted**: otherwise, with the run count. For a skill or subagent the count is sessions that used it; for a hook it is runs. A skill is looked up under its name and under its folder name (Codex logs the folder name, which can differ from the frontmatter `name`); the larger session count wins, they are not added, because one session can match both.

"Added" is the first time SpaceVibe saw the row's `id`, kept in `<data>/first-seen.json` (see [first-seen.go](../../core/internal/inventory/first-seen.go)). The pure builders `AttachUsage` and `BuildLoadoutRows` take no store: they read the file's modification time (`SKILL.md`, the subagent file, or the settings file holding the hook, which any edit moves). Only `Service.Rows` (`loadout.rows`) passes the store's times in. This is a heuristic either way (see `pendingReason`). `loadout.rows` writes that same time on every item, extra item and hook as `firstSeen` (the "added N ago" line), from the one `addedAt` lookup the pending rule uses, so the line and the D63 note cannot disagree; an id with no store entry and no readable file has none.

- **Seeding.** With no store yet, each id is recorded with its file's modification time, so the first run reads as the modification-time rule did. An id that appears after the store exists is recorded as "now", whatever its file's date: a skill unzipped with a 90-day-old date still reads "Added in the last 24 hours".
- **Kept ids.** An id missing from one read stays in the store, so a Remove and its Undo keep the original time. An entry is dropped only when the id has been absent for 90 days. "Last seen" is written again at most once a day, so a read that changes nothing does not write the file.
- **Never fails the read.** A corrupt, oversized, unreadable or newer-version file is left as it is and `loadout.rows` answers from modification times (delete the file to start over). A data folder that cannot be created or written does the same. The write goes through the guarded atomic write, file 0600 in a 0700 folder.

## CLI cells

`loadout.rows` also gives every row a `cliCells` map, one cell per CLI of the [registry](../../core/internal/cliregistry/registry.go), built in [`attachUsage`](../../core/internal/inventory/attach-usage.go) from the same reading as the cells above ([cli-cells.go](../../core/internal/inventory/cli-cells.go); wire shape in [core-protocol.md](core-protocol.md#wire-types)). The first rule that holds decides the cell:

1. **Not supported**: the registry says the CLI has no such kind.
2. **Unknown** or **Missing**: the CLI has no member in the row. It is unknown when the reader could not use what would have listed one: the CLI root (every kind), its `skills` or `agents` folder (for Codex skills also `~/.agents/skills`), its hook file (not valid JSON, too large or unreadable), and for Claude also `plugins/installed_plugins.json`, the `settings.json` that enables listed plugins, or a plugin's own skills, agents or `hooks.json`, since a plugin item joins a row by its bare name. Otherwise missing.
3. **Unmeasurable**: a Codex hook (Codex logs no hook runs), or a CLI whose registry entry has no `logs`.
4. **Scanning**: no usage scan has finished in this process.
5. **Unmeasurable** with "No logs scanned for this CLI yet": the CLI has no scanned log at all, so a zero would be a guess (RD-R10: Never ran is judged over measured CLIs only).
6. **Counted**: sessions and days for a skill or subagent, runs and errors for a hook. A zero carries D63's note when `pendingReason` gives an "Added…" sentence. A hook also lists `last7Days` (the seven days ending on the UTC date of `now`, oldest first, zeros included) and `errorsLast7Days`, from the usage scan's per-day hook counts (`CLITotals.HookDays`, [usage.md](usage.md)). RD26's failing Hook is `errorsLast7Days > 0`; the lifetime `errors` never stands in. A dead Hook is counted like any other, so it shows the runs the logs hold.

What a maintainer would get wrong:

- **Unknown is per kind and user-level only.** A denied `~/.claude/skills` makes the Claude skill cells unknown and leaves Claude agent cells missing. Project rows hold Claude members only (Codex project folders are not read), so a project row's Codex cell stays missing. A single `SKILL.md` or agent file that cannot be read is a problem line but not unknown: its name, and so its row, cannot be known.
- **The two-CLI `cells` never take these states.** They stay as the v5 shell decodes them: an unreadable folder still reads missing there.

## Readers map

`loadout.rows` says, per item and hook, which folder it was read from and which CLIs read that folder, so the shell derives "via" (RD31), the number of files of a row (D53) and who loses an item (RD-R11) without guessing ([readers-map.go](../../core/internal/inventory/readers-map.go); wire shape in [core-protocol.md](core-protocol.md#wire-types)). The table `folders` lists each installed CLI's own skills folder, agents folder and hook file, the shared `~/.agents/skills`, and every plugin or project folder a row lives in. A reader is listed only for what was checked: Codex 0.170.0 lists skills from `$CODEX_HOME/skills` and `~/.agents/skills` (plan RB-T0a); Claude Code is taken to read `~/.claude/skills` only.

What the shell computes, all from the wire:

- **Readers of a member**: the `readBy` of its `folder`, together with the `readBy` of every folder with the same `realPath` (a folder that is a link to another is the same folder on disk).
- **Files of a row**: the distinct `realPath` of its items. D53's last copy is the last file, not the last lit logo.
- **What a removal takes**: removing a member whose `owner` is `link` takes only that link; removing any other member takes its file, so every member with the same `realPath` goes with it (a link to it would dangle).
- **Losers**: a CLI loses the item when it reads at least one member and every member it reads is gone. Every registry CLI counts, shown or hidden.
- **Via**: a CLI reads a row "via" others when none of the folders it reads the row from has `ownedBy` equal to it; the owners of those folders are the "via" names. With Claude Code and Codex nobody is via: each reads only folders it owns.

What a maintainer would get wrong:

- **v5 fields exclude `~/.agents/skills` until RB-X1.** The v5 shell splits a key with two members of one CLI into two rows, so a skill in both Codex folders would show twice, and a skill only in `~/.agents/skills` would appear as a new row (FE-P9, plan AR1). So `inventory.read` and the v5 members of `loadout.rows` (`items`, `hooks`, `cells`, `inOther`, `countsByScope`, `rowFlags`, `problems`) are exactly what they were without that folder (`TestV5FieldsIgnoreAgentsSkills`). Its skills go to `extraItems`, the lines about it to `extraProblems`, and they count in every row's `cliCells`: the Codex cliCell of a Claude skill whose only Codex copy is there reads present while its v5 `cells.codex` stays missing. The new frame reads `items` and `extraItems` together.
- **`~/.agents/skills` is Codex's second skills folder, read only while the Codex root exists.** Without `~/.codex` nothing says Codex is installed, so the folder is not read. Its skills are Codex items with the id tag `agents` (`codex:skill:agents:<entry>`), so a skill in both Codex folders has two ids in one row; an extra item carries `cliCells` but no `cells`. A denied `~/.agents/skills` makes absent Codex skills unknown in `cliCells`, like a denied `~/.codex/skills`. In `loadout.rows` they are not `removable`, and the v5 write methods look ids up through `inventory.Read`, which leaves them out, so `loadout.removeItem` and `loadout.copyToOther` answer 404 for them. `loadout.copyTo`, `removeFrom` and `removeMany` read [`ReadMembers`](../../core/internal/inventory/write-members.go) instead: the same items and folder table, with the shared skills `Removable` (they are user files), so they can be removed with their readers named ([mutations.md](mutations.md#rules-that-are-easy-to-get-wrong)). `copyTarget` is false there: a copy into Codex writes into `~/.codex/skills`.
- **`.system` is not listed.** `$CODEX_HOME/skills/.system` holds the skills Codex ships and manages; like every dot-named entry it is skipped, so it is neither a row nor a folder of the table.
- **Project folders other than `.claude` are not read.** Codex also lists `<repo>/.codex/skills` and `<repo>/.agents/skills`; project reading stays as it was, so those folders and their readers are not in the map.
- **`inventory.read` has none of this.** `folder`, `realPath`, `folders`, `extraItems` and `extraProblems` are written by `loadout.rows` only, so the v5 decode and the frozen inventory golden are unchanged; the readers map has its own golden, `readers-map.json`.

## Verification

`cd core && SPACEVIBE_TEST=1 go test -count=1 ./internal/inventory/... ./internal/cliregistry/... ./internal/roots/... ./internal/hashes/...` runs against temporary homes or the fixture home, never the real config; `scripts/test.sh` runs it first. The goldens are frozen (SV5).
