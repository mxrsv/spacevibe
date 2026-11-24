# Core protocol

The contract between the Go core (`spacevibe`) and the SwiftUI shell: how they talk over stdio, which methods exist, the exact JSON each one carries, and the rules that keep stdout, errors and goldens safe. The Swift `CoreClient` decodes these shapes into Codable types, so a change here is a change to both sides. Architecture: [overview.md](overview.md). Decisions: [ledger](../specs/2026-11-07-core-port-and-spacevibe-identity-decisions.md) SV3, SV4, SV12.

**Where the code is.** The transport is in [`core/internal/rpc`](../../core/internal/rpc) (framing, handshake, errors, strict params, cancellation, drain, size caps). Every method of the table is registered by [`core/internal/rpc/methods`](../../core/internal/rpc/methods), which builds the domain services once and registers them on the registry. The entry point is [`core/cmd/spacevibe`](../../core/cmd/spacevibe) (`rpc`, the one-shot `--json` commands, `--version`, the stdout guard, the startup problem, the write guard). The transcripts and contract cases are in [`core/testdata/rpc`](../../core/testdata/rpc) and `TestContract`. `TestDocMethodTable` fails when the table, `AllMethods` and the registered set (with `initialize`) are not the same list; it also refuses any statusline, capture or `Add*` method. Change a shape only together with its Go test and its Swift DTO in [`Sources/SpaceVibe/Core`](../../Sources/SpaceVibe/Core).

## Framing and lifecycle

- **NDJSON, JSON-RPC 2.0.** One object per line, UTF-8, no raw newline inside a message. Request lines are capped at 1 MiB and response lines at 64 MiB. Batches (a JSON array) are refused with -32600. Ids are integers or strings, echoed verbatim; a `null`, fractional, exponent or other non-integer id is -32600 with id `null`. A blank line is ignored. A request whose id is still in flight is refused with -32600 (the first keeps running). Params may be absent or `null` (read as `{}`); any other non-object is -32602. Responses may arrive in any order: requests run concurrently, writes serialize on the write lock.
- **Spawn.** The shell starts `Contents/Helpers/spacevibe` with the argv array `["rpc"]` (no shell) and inherits the environment. The binary lives in `Helpers`, not `MacOS`, because `SpaceVibe` and `spacevibe` collide on a case-insensitive volume.
- **Handshake.** The first request must be `initialize`; its params must be an object, but `client` may be missing (a given `client` is `{name, version}`, unknown members are -32602). Any other request before it gets -32002; notifications before it are dropped. A second `initialize` gets -32600. `protocolVersion` is the integer `1`; any other value gets -32001 with `data: {protocolVersion: 1}`. The shell takes the core's name, version, env prefix and data folder from the result and hard-codes only the helper's path (SV12).
- **Startup problem**. If the environment is refused (`internal/config`, or the real-home guard under `SPACEVIBE_TEST=1`), `initialize` still succeeds, so the shell learns the identity, and every other registered method fails with -32000, status 500 and the startup sentence. An unknown method is -32601 first, and a request before `initialize` is -32002 first. The sentence is the error text of `config.Load`, `roots.RealHome`, `roots.Resolve` or `proc.New` (an unreadable `SPACEVIBE_PROC_FIXTURE` file, only under `SPACEVIBE_TEST=1`): it may name an environment variable (and the offending `SPACEVIBE_TEST` value) or a root path, never file content. A screen shows the sentence instead of reading anything.
- **Shutdown.** On stdin EOF the core stops reading and cancels the context of every in-flight request. A handler stops on cancel, except one inside the write lock, which ignores the context and finishes its write. The core waits at most 5 s for them, then exits 0. A write that outlives the drain is abandoned at exit. A read error other than EOF exits 1. Every write ends in one atomic rename, so a file is old or new, never half; the rare leftover is a `.spacevibe-*.tmp` file.
- **Size overflow**. A request line over the cap is discarded through its newline and answered with -32600 and id `null`; the stream stays usable. A result that would pass 64 MiB is replaced by -32000, status 413, "The result is too large."

## Errors

| Code | Meaning | `data` |
| --- | --- | --- |
| -32700 | Line is not valid UTF-8 JSON. The stream continues. | none |
| -32600 | Not a valid request: batch, oversized line, repeated `initialize`, a `null` or non-integer id, or an id that is still in flight. | none |
| -32601 | Unknown method. | none |
| -32602 | Params are not an object, or have a wrong type or an unknown member. The message names the member, never its value. | none |
| -32603 | A panic inside a handler. Fixed message; the reason goes to stderr only. | none |
| -32000 | The engine refused or failed. The message is a `coreerr` sentence. | `{status, message}` |
| -32001 | `initialize` protocol version mismatch. | `{protocolVersion}` |
| -32002 | Request before `initialize`. | none |
| -32800 | Request cancelled by `$/cancelRequest`. The contract case `cancel_request` asserts this code. | none |

**`status` follows HTTP** ([`coreerr`](../../core/internal/coreerr/coreerr.go)): 400 bad input, 403 refused, 404 gone, 409 conflicts with the current state, 413 too large, 500 the write failed. `message` equals the JSON-RPC `message` and is safe to show: it may name a path or a rule, never file content (S-R3). A parse failure of a settings file becomes a fixed sentence; Go's `encoding/json` and TOML errors quote input and must never be forwarded.

**Settings-file paths are scrubbed by the core.** In every `rules.*` message and problem the absolute settings-file path is swapped for the scope's label before it leaves the core; the shell does no scrubbing of its own. What the scrub covers and what it leaves (the project folder in a journal label, shown in the Undo toast) is in [rules.md](rules.md#rules-that-are-easy-to-get-wrong).

## Notifications and cancellation

Notifications have no `id` and get no response.

| Direction | Name | Params |
| --- | --- | --- |
| core to shell | usage/progress | `{id, done, total}`: `id` is the `usage.scan` request id. Sent after every 20 files and once at the end. |
| core to shell | activity/report | The full `ActivityReport`, see below. |
| core to shell | clean/progress | `{id, phase, done, total, bytes}`: `id` is the `clean.move` request id; `phase` is `reading` (the usage of the picked logs is archived) then `moving`; `bytes` is what has moved so far. Sent after every 20 paths and at the last one of each phase. |
| shell to core | $/cancelRequest | `{id}`. An unknown or finished id is ignored. |

A cancelled read answers -32800. A write is cancellable while it waits for the write lock, in this process or for another core's `flock`; once its body has started, the cancel is ignored and the response is the real result, so a cancel never leaves a half-applied change. Cancelling `usage.scan` leaves `usage-cache.json` as it was and the process's usage state unchanged. Neither a write nor `activity.stop` is ever retried by the core, and a handler never holds the write lock itself: the service takes it around its own write, after looking at the cancel once. `loadout.copyToOther`, `loadout.removeItem`, `loadout.removeDeadHooks`, `loadout.copyTo`, `loadout.removeFrom`, `loadout.removeMany`, `journal.undo` and the `rules.*` writes take the lock with their request context ([`fsx.WithWriteLockContext`](../../core/internal/fsx/write-lock.go)), so one cancelled while it queued stops waiting at once, changes nothing, writes no journal entry and answers -32800; they also look at the context again as the first step inside the lock. `clean.move` is the one write that also stops part way: it looks at the context before each file it moves, so a cancel (or the end of input) after the first file stops before the next one, records one journal entry for what moved, and answers the real result with `cancelled: true`; a cancel before the first file answers -32800 and changes nothing.

## Activity subscription

- **Full snapshot first.** The `activity.subscribe` response is a complete `ActivityReport`. After it the core polls while subscribed, every `intervalMs` (optional, 1000 to 60000, default 3000; the shell asks for 20000, `CoreConnection.activityPollMs`), and pushes `activity/report` only when the encoded report differs from the last one sent to this connection. The baseline is the very report the response carried (the poll does not take a second snapshot of its own), so a change between the two reads cannot be lost. The first possible push is one interval after the response.
- **Resync, not deltas.** Every notification replaces the shell's whole report. There are no sequence numbers and no partial updates. After a core restart the subscription is gone; the shell re-subscribes and gets a fresh snapshot.
- **"Changed" includes the clock**. `ageMs` and `lastWriteAgoMs` are computed from now, so a live session changes the report on every poll and pushes once per interval; with no live session and no log change the core stays silent.
- **One subscription per connection.** A second `activity.subscribe` returns a fresh snapshot and resets the baseline. `activity.unsubscribe` is idempotent and stops the polling; the core reads nothing while unsubscribed. End of input cancels the poll before the 5 s drain (`Call.Session` in `rpc`), so no new report is pushed after it. The poll is the core's own loop over `activity.Service.Read`, and its baseline is the snapshot the response carried, so a change between the response and the first poll is pushed. `activity.read` and the poll share one engine, so folded offsets are not repeated.
- **A refresh is a second subscribe.** The poll is slow because nobody needs the data live; the moments someone looks ask for a read at once (`CoreConnection.refreshActivity`: the app comes forward, the pointer reaches the glance widget). It sends the same `activity.subscribe`, so the answer is the new baseline and goes to every subscriber, inside the same turn as the other subscribes. It starts nothing: with no subscriber or no live core it does nothing, and one within 2 s of the core's last answer is skipped.
- **Several subscribers share the one subscription.** The shell's Activity page and glance widget both subscribe on one connection. [`CoreConnection`](../../Sources/SpaceVibe/Core/CoreConnection.swift) gives each subscribe's snapshot to every other subscriber too, because it is now the baseline: a subscriber that missed it can keep a report the core will never correct (the last live session ended, nothing changes, nothing is pushed). It also sends subscribes and unsubscribes one at a time and decides an unsubscribe inside that turn, so the last reply on the pipe is the baseline and an unsubscribe can never reach the core after a newer subscribe and end it.

## Swift client

[`CoreClient`](../../Sources/SpaceVibe/Core/CoreClient.swift) maps `CoreService` to the methods above; [`CoreConnection`](../../Sources/SpaceVibe/Core/CoreConnection.swift) owns the process, the handshake and the restarts; [`CoreSession`](../../Sources/SpaceVibe/Core/CoreSession.swift) is one process with its reader thread. What a maintainer would get wrong:

- **The write lock spans processes.** Two app instances run two cores on one data folder, so [`fsx.WithWriteLock`](../../core/internal/fsx/write-lock.go) also takes `flock(LOCK_EX)` on `<data>/write.lock` at its outermost depth. The wait is bounded and cancellable: the in-process part is a one-slot semaphore, the `flock` is tried with `LOCK_NB` every 20 ms (doubling to 200 ms), and both give up when the request context is cancelled (`context.Canceled`, -32800) or after 30 s, which answers the fixed 500 "Could not lock the SpaceVibe data folder, so nothing was changed." and runs nothing. `WithWriteLock` without a context uses the same 30 s limit.
- **Read the pipe with `read(2)`.** `FileHandle.read(upToCount:)` waits for the whole count, so a short reply sits unseen and the call hangs.
- **A write is never sent again.** A request in flight when the core dies fails with the fixed "restarted" `CoreError`: the dead core may have applied it. A read in flight is sent once more on the new core. A request that never left (the pipe was already dead) is sent again whatever it is. A method the client does not list as a read counts as a write.
- **Cancel differs by kind.** A cancelled read answers `CancellationError` at once and ignores the late reply. A cancelled write sends `$/cancelRequest` and keeps waiting, because once the core is inside the lock the real result (and its Undo entry) must not be hidden.
- **A request and its cancel keep their order.** [`CoreSession`](../../Sources/SpaceVibe/Core/CoreSession.swift) registers a request and writes its line in one step under `writeLock`, and `$/cancelRequest` writes through the same lock, so a cancel can reach the pipe only after the request line it names. Registering first and writing later let a cancel from another thread overtake the request, and the core ignores a cancel for an id it has not seen.
- **The reader scans only the bytes it just read, and a line has a cap.** [`CoreLineFramer`](../../Sources/SpaceVibe/Core/CoreLineFramer.swift) looks for the newline in each new chunk once (searching the whole buffer again per chunk took 21 s for a 20 MiB line). A line past 64 MiB plus 1 MiB of slack for the envelope (the response cap above) fails the session: every pending request gets the fixed "restarted" `CoreError`, and the next request starts a new core.
- **Loadout scans again after a restart.** A restarted core has no usage result, so `loadout.rows` answers `usage: "scanning"` until someone calls `usage.scan`. When [`LoadoutModel`](../../Sources/SpaceVibe/Agents/LoadoutModel.swift) gets `scanning` while no scan is running and no scan failure needs Retry, it drops the old counts and starts the scan. The running flag is cleared before the post-scan rows read: a restart between these replies must also rescan. A refused scan keeps its failure instead of retrying itself indefinitely.
- **Restarts are lazy.** The next request, or a live Activity subscription, starts the core again; the delay grows 0.25 s to 5 s while it dies without answering a request. A protocol-version mismatch is a stored startup problem, never a restart loop.
- **Dev switches.** `SPACEVIBE_CORE_BINARY` ([`CoreEnvironment`](../../Sources/SpaceVibe/Core/CoreEnvironment.swift)) is honored only in a development build (`LaunchMode.isDevelopmentBuild`: a debug build, or a bundle `scripts/build-app.sh` made without `--distribution`); `SPACEVIBE_TEST=1` does not enable it. The gallery and shot modes (`SPACEVIBE_GALLERY`, `SPACEVIBE_SHOT_DIR`) and the redesign switch (`SPACEVIBE_REDESIGN=1`, [`LaunchMode.surface`](../../Sources/SpaceVibe/App/LaunchMode.swift)) follow the same gate: a distribution build always starts normally on the v5 window. `scripts/test.sh` and `scripts/dev-fixture.sh` build debug. There is no per-screen routing: every screen and every Undo runs on the core. The core's process list under `SPACEVIBE_TEST=1` is the file `SPACEVIBE_PROC_FIXTURE` names, which `scripts/dev-fixture.sh` exports and the core inherits.
- **Tests stop the core with signals.** The shipped binary has no `debug.slow`, so `SIGSTOP` freezes a request in flight and `SIGKILL` ends it.

## Output discipline and security boundaries

- **stdout carries the protocol and nothing else.** One writer goroutine owns it. On darwin the core duplicates fd 1 for the protocol and points fd 1 itself and `os.Stdout` at stderr (`dup`, `dup2`), so a stray `fmt.Println`, a cgo write or a child process lands in the log, not in the stream. Other OSes only repoint `os.Stdout` at the Go level: a write to fd 1 by anything but Go code still reaches the protocol. The contract case `stray_print_on_stderr` holds this.
- **stderr is the log.** Fixed reasons only, no file content, no request params. The shell forwards it to `os.Logger` at debug level. `rpc` asks for SIGPIPE (`signal.Notify`) on Unix, so a log line written after the shell closed the pipe fails with EPIPE, which the logger ignores, instead of Go ending the core (fd 1 and fd 2 are the same pipe after the guard). The contract case `TestCoreSurvivesAClosedStderr` holds this.
- **No listener, no network.** The core opens no socket and `go list -deps ./cmd/spacevibe` shows no `net`, `net/http` or `crypto/tls` (S-R5).
- **No recorded command runs.** The only processes are the fixed `ps`, `lsof` and SIGTERM of Activity, with the pid looked up again from the live system. `activity.stop` takes `{cli, id}` and never a pid (S-R4). `spacevibe statusline capture` (and `install` and `uninstall`) is a command-line subcommand with no RPC route; the case `rpc_cannot_capture` holds that. Each capture is a new process, so it keeps the Claude account key in `<data>/claude-limits/account-key` (mode 0600; a hex hash plus the state file's path, size, mtime in ns and the Claude root it was computed from, never an account id) and returns it without reading `.claude.json` while those match; any mismatch, corruption or write failure falls back to computing it and never fails the capture. The file has no `.json` suffix, so it is not listed as a session snapshot.
- **Recognisable credentials are masked in the commands the core reports**. [`redact.Command`](../../core/internal/redact/redact.go) replaces the value with `•••` in `Authorization: <scheme> <value>` and a bare `Bearer <value>`, `--token`, `--password`, `--passwd`, `--secret`, `--api-key`, `--apikey`, `--access-token` and `--auth` (with `=` or a space), the password of curl `-u` / `--user name:pass`, `NAME=value` where an upper-case NAME holds KEY, TOKEN, SECRET, PASSWORD, PASSWD, CREDENTIAL or AUTH, the password of `scheme://user:password@host`, and the token prefixes `sk-`, `ghp_`, `gho_`, `ghs_`, `github_pat_`, `xox[abpr]-`, `AKIA` and three-part `eyJ` JWTs. A value that starts with `$` is a shell variable and stays. It is best effort: a shape not listed still shows. It is applied only at the wire projection, to `ActivityReport.failures[].title` and `.reason`, `sessions[].currentTool.target`, `InventoryHook.command` and the string values of `CodexPermissions.profiles[].networkFlags` (the userinfo password only). It is never applied inside `inventory.Read`: writes re-read through it and copy or remove a hook by its command text, so a copy writes the raw command, and the failure `key`, `hook.hash` and `Rule.rule` also stay raw. `sessions[].title` (the user's prompt), `stateReason`, `costNote`, `files[]` and `unmeasurable[].text` are not masked. A failure title is masked before its 120-character cut, and a failure reason and a running-tool target before their 160-character cut, so a cut never leaves the first characters of a credential ([activity.md](activity.md#rules-that-are-easy-to-get-wrong)).
- **Environment is read in one place**, [`internal/config`](../../core/internal/config/config.go), fail-closed (`SPACEVIBE_TEST` is `1` or `0`, `SPACEVIBE_HOME` is absolute; `HOME`, `CLAUDE_CONFIG_DIR` and `CODEX_HOME` are absolute when set, else the environment is a startup problem with a fixed sentence that names the variable: `initialize` answers and every other method answers 500 with it). Under `SPACEVIBE_TEST=1` a root under the real home, taken from the password database and not `$HOME`, is refused (S-R1). The fixture process adapter exists only under that flag: `SPACEVIBE_PROC_FIXTURE` (`Config.ProcFixture`) names its process-list file, `proc.New` receives the path as an argument, and an unreadable file is an error sentence. Outside `SPACEVIBE_TEST=1` the variable is ignored.
- **The write guard is a startup requirement.** The entry point calls `fsx.InstallWriteGuard(cfg)` right after `config.Load`, in `rpc` and in every one-shot command, before any method can run. Without it the primitives of [`fsx`](../../core/internal/fsx/write-guard.go) write freely and the real-home refusal (S-R1) is void for writes. The case `write_guard_installed` aims a write at the real home through a debug method that exists only in a binary built with `-tags contracttest` and expects the guard's refusal; the shipped binary has no debug method.
- **Params are strict**. A misspelled `verdict` must not fall back to a default and write something else, so unknown members are -32602.
- **A project folder must be one project discovery found.** The core keeps one discovered list per process, shared by the inventory and rules services: `inventory.read` and `loadout.rows` refresh it, `rules.snapshot` with `refreshProjects: true` refreshes it, every other `rules.*` call reuses it, and discovery runs once if it is empty. A write or preview for a folder outside the list is 404, so no caller can make the core create `<any folder>/.claude/settings.json`; `rules.snapshot` alone reads such a folder as `global` (see "Behavior the table cannot say").

## One-shot `--json`

`spacevibe inventory|usage|activity|limits|rules --json` prints the same result object as the matching read method (`inventory.read`, `usage.scan`, `activity.read`, `limits.read`, `rules.snapshot`), with the same encoder, so a contract test compares bytes (`one_shot_equals_rpc`; `activity` is compared with its clock-driven members masked, because `ageMs` moves). They add no write path: the one file any of them can write is `usage-cache.json`, as `usage.scan` does, and `usage` sends no progress. `rules` prints the global snapshot; `rules --dir <path>` prints the project snapshot for that folder, with the same fallback as the method (a folder discovery did not find reads as global; a relative one is 400, so exit 1). `--dir` is accepted by `rules` only. Exit codes: 0 success, 1 core error (the safe message on stderr, nothing on stdout; also a refused environment), 2 usage (a missing `--json`, an unknown or misplaced flag). There are no write commands among these. The status-line setup is its own subcommand family, never an RPC method: `spacevibe statusline install` wraps Claude's `statusLine.command`, `spacevibe statusline uninstall` is one journaled edit of `settings.json` that sets the command back to the user's original (every SpaceVibe wrapper unwrapped) or removes `statusLine` when that was empty, keeps every other member, and says so and writes nothing when no wrapper is there, and `undo <journal-id>` reverts an install but is refused once the file changed. The app only copies the install and uninstall command lines to the pasteboard from the Limits palette and never runs them (S-R4). No command reaches statusline capture except the collector `spacevibe statusline capture`, which Claude runs.

## Methods

Params and results use the types defined under "Wire types". "Journal entry" is the label pattern and the op kinds recorded; `JournalEntryRef` is what a write returns. Errors list the `data.status` values a caller must handle, besides the generic codes above. Reads touch nothing except where "side effects" says so.

| Method | Params | Result | Errors (status) | Side effects | Journal entry |
| --- | --- | --- | --- | --- | --- |
| `initialize` | `{protocolVersion, client?:{name, version}}` | `{protocolVersion, core:{name, version}, identity:{envPrefix, dataDir}, methods:string[]}` | -32001, -32600 | Starts the session | none |
| `clis.registry` | `{}` | `{clis:RegistryCli[]}` in the fixed CLI order | none | none: reads nothing, the registry is part of the binary | none |
| `inventory.read` | `{}` | `InventorySnapshot`, no `cells`, hook `usage` null | none: unreadable files become `problems` | Refreshes the discovered-project list | none |
| `usage.scan` | `{}` | `UsageResult`; sends `usage/progress`; stores the result as the process's usage state | 409 a scan is already running; -32800 | Reads logs; writes `<data>/usage-cache.json` | none |
| `loadout.rows` | `{}` | `LoadoutRows`; `problems` are the raw sentences; every item and hook carries `cells`, `cliCells`, `folder` and `firstSeen` (omitted when unknown), every item `realPath`; `folders` is the readers map; `extraItems` and `extraProblems` hold what the v5 fields leave out | none | Reads inventory; attaches the stored usage state; writes `<data>/first-seen.json` when a new item id appears (best effort) | none |
| `activity.read` | `{}` | `ActivityReport` | none: the engine reports what it could not read inside the report | none | none |
| `activity.subscribe` | `{intervalMs?}` | `ActivityReport`; later `activity/report` | none | Starts the poll (default 3 s) | none |
| `activity.unsubscribe` | `{}` | `{}` | none | Stops the poll | none |
| `activity.stop` | `{cli, id}` | `{exited:boolean}` | 404 not running; 409 could not be verified (ps, lsof or the sessions folder unreadable, or the start time unknown, or the status file's recorded `procStart` is missing or unreadable as a start time while the pid is alive: nothing is sent; a recorded start that parses and differs is a reused pid, 404); 403 other user; 500 | SIGTERM to the pid found now; waits up to 3 s | none: not undoable, the shell confirms first |
| `loadout.copyToOther` | `{id}` | `{entry:JournalEntryRef}` | 400 a hook Codex cannot take or an event it lacks; 403 a path outside the CLI folder; 404; 409 the other CLI's folder is missing ("<CLI> is not installed on this Mac, so nothing was copied."; nothing is created), a skill folder or agent name that is not lowercase letters, numbers and dashes (the message names the item), the name exists in the other CLI, a source that cannot be read or is not a plain file, an agent with no instructions; 413 a skill file over 16 MiB, a skill over 64 MiB, an agent over 1 MiB; 500 | Creates the skill folder (named after the source folder, not the `name:` in `SKILL.md`), agent file (named after the agent's `name`) or Claude hook in the other CLI; never creates the CLI's own folder | label `Copied skill\|agent <name> to <CLI>` or `Added <event> hook to Claude Code`; ops `created`, `hook-added` |
| `loadout.removeItem` | `{id}` | `{entry:JournalEntryRef}` | 403 plugin or project item; 404 (also an `extraItems` id: this v5 method looks ids up in `inventory.read`; `loadout.removeFrom` and `removeMany` take them); 409; 500 | Moves the item to the data-folder trash; a link keeps its target text | label `Removed skill\|agent <name> from <CLI>` (a Codex skill that `~/.agents/skills` also holds adds `; Codex still reads it from ~/.agents/skills`, since that copy stays) or `Removed <event> hook from <CLI>`; ops `moved`, `link-removed`, `hook-removed` |
| `loadout.removeDeadHooks` | `{cli}` | `{entry:JournalEntryRef}` | 409 none dead; 500 | One write to the CLI's hook file | label `Removed N dead hooks from <CLI>`; ops `hook-removed` |
| `loadout.copyTo` | `{id, targets:string[]}` | `{entry:JournalEntryRef, alsoReaders:string[]}`; `alsoReaders` are the registry ids outside `targets` that read a folder the copy went into ("… read the same folder, so they have it too"), never null | 400 no target, a target that is not a CLI SpaceVibe can write, a hook id; 403 a plugin or project item; 404 (any `items` or `extraItems` id is found); 409 a target already reads the item from any folder, a target not installed, a bad file name, the name exists, an unreadable source, an agent with no instructions; 413 as `copyToOther`; 500 | Copies a Skill or Subagent into each target's own skills or agents folder, every check before the first write; never writes into `~/.agents/skills`, a plugin or a project | label `Copied skill\|agent <name> to <CLIs>`; one op `created` per target |
| `loadout.removeFrom` | `{id, clis:string[]}` | `{entry:JournalEntryRef, lost:string[], stillHave:string[]}`, registry ids in registry order, never null | 400 no CLI, an unknown CLI, a hook id; 403 a plugin or project item, or a plugin copy among the files that would go; 404; 409 a named CLI does not have the item, or a file that a CLI not named also reads ("<name> is one file that <readers> read, so it can only be removed from all of them at once."); 500 | Removes every file each named CLI reads the item from, `~/.agents/skills` included ([readers map](inventory.md#readers-map)): a link is unlinked (its text kept), any other member goes to the data-folder trash once per file | label `Removed skill\|agent <name> from <lost CLIs>`; ops `link-removed`, `moved` |
| `loadout.removeMany` | `{ids:string[]}` | `{entry:JournalEntryRef, lost:string[]}`; `lost` are the CLIs that lost at least one item or hook | 400 empty; 403 a plugin or project member; 404 any id gone; 409 a member whose file another member reaches that is not in `ids` (naming the readers), a hook that changed, a hook file that is not valid JSON; 500 | Each id is one member (a Skill, Subagent or Hook of one CLI), all removed as one change: items as in `removeFrom`, hooks with one edit per hook file; all or nothing | label `Removed <kind> <name> from <CLIs>` for one row, else `Removed N skills, N agents and N hooks from <CLIs>` (`Removed a copy of …` when nobody lost it); ops `link-removed`, `moved`, `hook-removed`; one Undo restores all |
| `journal.undo` | `{id}` | `{label:string}` | 404 gone; 409 already undone, or a target changed or exists again; 400 an entry this version cannot undo or a path outside the managed folders; 500 the undo was rolled back or stopped part way | Reverses all ops last first, all or nothing; marks the entry undone | none: the entry is marked `undone` |
| `journal.history` | `{}` | `{entries:JournalEntryRef[]}`, newest first, at most 200 | 409 the journal exists but is not a JSON array of entries (an element without a string `id` counts): it is refused, never read as empty or with elements dropped | none | none |
| `rules.snapshot` | `{scope, dir, refreshProjects?}` | `RulesSnapshot` | 400 relative dir, a global scope with a `dir`, or an unknown scope; an unknown project is not an error (see below) | May refresh the project list | none |
| `rules.preview` | `{scope, dir, capability, verdict}` | `CapabilityPreview` | 400, 404, 409 | none: writes nothing | none |
| `rules.setCapability` | `{scope, dir, capability, verdict}` | `{entry:JournalEntryRef\|null}`; null = the file already holds that | 400, 404, 409, 500 | Edits the scope's `settings.json` in place | label `Set <capability> to <Verdict> (<scope>)`; op `file-edited` |
| `rules.add` | `{scope, dir, verdict, rule}` | `{entry:JournalEntryRef}` | 400 invalid rule; 404; 409 duplicate, not valid JSON, or a project or local file that is a link (the global file may be one, see [rules.md](rules.md)) | Same | label `Added <verdict> rule <rule> (<scope>)`; op `file-edited` |
| `rules.remove` | `{scope, dir, verdict, rule}` | `{entry:JournalEntryRef}` | 404; 409 the rule already changed | Same | label `Removed <verdict> rule <rule> (<scope>)`; op `file-edited` |
| `rules.changeVerdict` | `{scope, dir, rule, from, to}` | `{entry:JournalEntryRef}` | 400 same verdict; 404; 409 | Same | label `Changed <rule> from <a> to <b> (<scope>)`; op `file-edited` |
| `rules.changeVerdicts` | `{scope, dir, to, rules:RuleMove[]}` | `{entry:JournalEntryRef}` | 400 an empty list, a bad verdict, or a `from` equal to `to`; 404; 409 a rule is no longer under its `from` (nothing is written), not valid JSON, or a project or local file that is a link; 500 | One edit of the scope's `settings.json` under the write lock: every rule is checked, then all move together | label `Changed N rules to <to> (<scope>)` (`Changed 1 rule to ...` for one); one op `file-edited`, so one Undo restores all |
| `rules.removeMany` | `{scope, dir, ids:string[]}` | `{entry:JournalEntryRef}` | 400 an empty list, or an id that is not `<scope>:<verdict>:<rule>` of this scope; 404; 409 a rule is no longer in the file under its verdict (nothing is written), not valid JSON, or a project or local file that is a link; 500 | One edit of the scope's settings file under the write lock | label `Removed N rules (<scope>)` (`Removed 1 rule ...` for one); one op `file-edited`, so one Undo restores all |
| `rules.check` | `{rule}` | `{valid:boolean, message:string\|null}` | none | none | none |
| `limits.read` | `{}` | `LimitsResult`: `{limits:LimitsEntry[], statusline}`, limits in order claude, codex, gemini | none | Reads local files only: no request, no credential, no CLI started | none |
| `findings.kept` | `{}` | `{kept:string[]}`, oldest first; `[]` when there is no list | 409 `<data>/kept-findings.json` exists but is not the list, or is a link: refused, never read as empty | none | none |
| `findings.keep` | `{id}` | `{entry:JournalEntryRef}` | 400 an id that is empty, over 1024 bytes, not UTF-8 or holds a control character; 409 already kept, the list or the journal unreadable, a link in place of the list; 500 | One write of `<data>/kept-findings.json`, the id added last; past 2000 ids the oldest drops | label `Kept a finding`; op `file-edited` |
| `findings.unkeep` | `{id}` | `{entry:JournalEntryRef}` | 400 as `findings.keep`; 409 not kept, or as `findings.keep`; 500 | One write of the list, the id removed | label `Stopped keeping a finding`; op `file-edited` |
| `clean.scan` | `{}` | `CleanScan` | -32800 | Reads the logs folders, the allowlisted caches, the inventory, one Activity report and one process list; writes nothing and caches nothing, so it is called on demand, never on a timer ([clean.md](clean.md#runtime-path)) | none |
| `clean.move` | `{logs?:LogPick[], caches?:string[]}` | `CleanMoveResult`; sends `clean/progress` | 400 nothing picked, a CLI other than `claude` or `codex`, an age other than 30, 90 or 180, a CLI's logs or a cache picked twice, a cache id outside the allowlist; 409 a `clean.move` is already running in this core, every picked row is locked (the lock's sentence, then "Nothing was moved."), nothing is left to move, the CLI folder, the data folder and the Trash are not on one volume, the Trash folder is missing, the journal or the usage archive cannot be read; -32800 cancelled before the first file moved; 500 | Archives the usage of each picked log in `<data>/usage-archive.json`, then writes the list `<data>/clean/<slot>.json` and renames each log or cache entry into a staging folder and that folder into the Trash ([clean.md](clean.md)); a locked row or a live row's log stays with its reason while the rest moves | label `Moved N files to the Trash: <CLI> logs, <CLI> caches`; ops `usage-archived {file, list}`, `system-trash-moved {trash, staging, list}`, which name the list instead of the paths; one Undo puts every file back |

Behavior the table cannot say:

- **`rules.snapshot` and an unknown project.** A `project` or `local` scope whose folder discovery did not find is read as `global`; the result's `scope` and `dir` say what was read, so the shell compares them with what it asked for. A relative `dir` is 400 and a `dir` with the `global` scope is 400. The other `rules.*` methods answer 404 for an unknown project folder, so no call can create `<folder>/.claude/settings.json` anywhere.
- **Unreadable is not empty**. A file or folder the core cannot look at (a macOS privacy denial, an unreadable settings file) is reported as unknown, never as no rules or the Codex defaults: `RulesSnapshot.notReadable` and `globalNotReadable` (the scope is not editable), `CodexPermissions.notReadable`, `skippedLines`, `rules.unreadable` and `rules.folderNotReadable`, each with a fixed sentence in `problems` or `warnings` that names the file and never quotes it. The shell must show it instead of an empty list. Inventory reports a settings file, skills folder, agents folder, `SKILL.md` or agent file, plugin `hooks.json` or `installed_plugins.json` it could not read as a `problems` line, and an invalid Claude `settings.json` adds one saying that enabled plugins and skill overrides are not known. Hooks of a type other than `command` (http, mcp_tool, prompt, agent) are not listed; one line, "N hooks of other types are not shown.", counts them over all files. A Codex `config.toml` or `.rules` file past its read cap adds a `warnings` line ("too large to read completely") instead of passing as complete. The Claude state file has one size cap for the usage cache and the status line account key; past it the Claude limit reads `unreadable`.
- **Other process-wide state.** The inventory and rules services share one discovered-project list: every `inventory.read` and `loadout.rows` hands its list to rules, and `refreshProjects` runs discovery again for both.
- **`usage.scan` owns the usage state.** The core keeps the last `UsageResult` of the process. `loadout.rows` attaches it, or reports `usage: "scanning"` and `pending` cells when no scan has finished in this process. The shell does not send totals back. A core restart forgets the state; `usage-cache.json` makes the next scan fast.
- **`loadout.rows` writes one file.** `<data>/first-seen.json` holds the time each item id was first seen; "Added in the last 24 hours" reads it instead of the file's modification time ([inventory.md](inventory.md)). It is written only when an id is new, dropped or its last-seen time is a day old. A file or folder that cannot be used or written never fails the call: the answer then comes from modification times.
- **`loadout.rows` is three steps in one call**: the inventory read, the usage join and the filter counts (per scope and per row key; [inventory.md](inventory.md#runtime-path)). Grouping rows by `key`, sorting and labels stay in the shell. Problems come back unshortened, with absolute paths; the shell shortens the home folder before showing them.
- **The CLI registry is the one list of CLIs.** [`cliregistry`](../../core/internal/cliregistry/registry.go) holds each CLI's id, name and `supports`, in the fixed order every page uses; `clis.registry` returns it and the keys of every `cliCells` map are exactly its ids. The ids are the `Cli` values the rest of the protocol already uses (`claude`, `codex`; also the keys of `roots` and `events` and the `cli` of `limits.read`), and the engine reads exactly the CLIs it lists (`TestRegistryIDsMatchTheProtocol`). `limits.read` still adds a `gemini` entry that the registry does not hold: that entry is the v5 Limits page's own. A `supports` member that is false is Not supported, a different fact from Missing or Unmeasurable. The v5 shell does not call `clis.registry`; the redesign's store does, and the method is in the read list of [`CoreConnection`](../../Sources/SpaceVibe/Core/CoreConnection.swift), so a restart sends it again like any read.
- **Two cell maps on a `loadout.rows` row.** `cells` is the two-CLI shape the v5 shell decodes and does not change. `cliCells` sits beside it, one `CliCell` per registry id, and is written only by `loadout.rows` (`inventory.read` has neither). Both come from one reading of the logs, so they never disagree on a count. Where they differ: a D63 "added recently" pending is a counted zero with a `note`; "No logs scanned for this CLI yet" is `unmeasurable`; the scan not having finished is `scanning`; Missing becomes `unknown` when the CLI's own folder or file for that kind could not be used (the per-kind rules are in [inventory.md](inventory.md#cli-cells)). A skill or subagent counts `sessions` and lists its `days`; a hook counts `runs` and `errors` (GLOSSARY: Runs are hooks only).
- **Hook errors in the last 7 days are their own count.** A counted hook `CliCell` carries `last7Days`, the seven days ending on the core's today, oldest first and every day present, with the runs and errors of each, and `errorsLast7Days`, their sum. RD26's failing Hook reads `errorsLast7Days`; `errors` (and `usage.errors`) stay lifetime counts inside the scanned logs. A day is the date text of the log line, which both CLIs write in UTC, so "today" is the UTC date of the core's clock, as for every usage day ([usage.md](usage.md#rules-that-are-easy-to-get-wrong)). The days come from the stored scan: the week moves with the clock between scans, but counts only what the last scan read.
- **`firstSeen` is the "added" time.** Every `loadout.rows` item, extra item and hook carries `firstSeen` (ISO text): the time `first-seen.json` holds for its id, or, when the store has no entry or cannot be used, its file's modification time. It is the time that decides the D63 note, so "added N ago" and "Added in the last 24 hours" agree. Omitted when neither is known, and on `inventory.read`.
- **The Keep list is the shell's ids, stored.** `findings.keep` and `findings.unkeep` store opaque finding ids (the shell builds them in [`Findings.swift`](../../Sources/SpaceVibe/Shell/Findings.swift)); the core checks only length and characters and never interprets them, so a kept Window comes back with the next Window because its id changes, not because the core looked. Each call is one journal entry with one `file-edited` op, so `journal.undo` restores the list byte for byte; like every `file-edited` Undo it is refused (409) once a later keep or unkeep changed the file, so undo newest first. Only these two methods write the list, `0600` under the write lock, and a file that cannot be read is never treated as empty ([`findings`](../../core/internal/findings/keep.go)).
- **The readers map is data, not a rule in the shell.** `loadout.rows` lists `folders` (every folder a row lives in, each installed CLI's own global folders and the shared `~/.agents/skills`), each with the registry ids that read it and the CLI that owns it; every item and hook names its `folder` by path, and every item its `realPath`. "Via" (RD31), the files of a row (D53) and who loses an item (RD-R11) are pure functions of these members, defined in [inventory.md](inventory.md#readers-map).
- **Two write families until RB-X1.** The v5 shell calls `loadout.copyToOther` and `loadout.removeItem`, which look ids up in `inventory.read` and so never see `extraItems`. The new frame calls `loadout.copyTo`, `loadout.removeFrom` and `loadout.removeMany`, which look ids up in the same items and readers map as `loadout.rows` (`items` and `extraItems`, [write-members.go](../../core/internal/inventory/write-members.go)) and answer in its terms: who lost the item, who still has it, who reads the folder a copy went into. `removeFrom` takes CLIs and removes every file those CLIs read the row from; `removeMany` takes members exactly as the list holds them, so a row removed for every CLI is all of its member ids. Neither refuses a last copy: D53 (a last lit logo is not a toggle) is the shell's rule, and `Remove…` is the explicit action. Where each write lands and how Undo reverses it: [mutations.md](mutations.md).
- **v5 fields exclude `~/.agents/skills` until RB-X1.** The Codex skills read from `~/.agents/skills` (ids `codex:skill:agents:<entry>`, `removable: false`, `cliCells` but no `cells`) are only in `extraItems`, and the problem lines about that folder only in `extraProblems`. `inventory.read` and the members the v5 DTOs decode (`items`, `hooks`, `cells`, `inOther`, `countsByScope`, `rowFlags`, `problems`) are exactly what they would be without that folder, because the v5 shell would split a key with two Codex members into two rows (FE-P9, plan AR1). Every `cliCells` map counts the extra items, so a new-frame caller reads `items` and `extraItems` together; RB-X1 folds them into `items`.
- **`rules.setCapability` returning null is not an error.** The core reports it; the app turns it into the 409 sentence "Nothing to change: the file already holds that." (`RulesModel.write` does it). `rules.add`, `remove`, `changeVerdict` and `changeVerdicts` never return null: the engine throws that 409 itself.
- **`rules.check`** is the live check of a rule's shape (the Rules model calls it before every add), built on `Rules.checkedRule`: empty text, over 1000 UTF-16 units, a newline, or no `Tool` or `Tool(pattern)` shape. `message` is the same sentence the write would refuse with. The write path checks again; this method is advice.
- **Journal ops are not exposed.** `JournalEntryRef` carries `count` only: ops hold absolute paths and trash names, and the shell uses only the id and the label. The journal file is `<data>/journal.json`, newest first ([retention](mutations.md#journal-retention-and-the-trash-sweep)), and a journal that exists but is not a JSON array of entries (every element needs a string `id`) makes every write 409; an element without an id is never dropped silently.
- **`addSkill` and `addAgent` are not methods.** The app has no caller.
- **Clean's sizes are allocated bytes.** Every `bytes` in `CleanScan` and `CleanMoveResult` is the allocated size of the exact paths a move takes (`st_blocks` × 512, what `du` counts; `du -A` would be the apparent size), so the scan's estimate, the result and the `du` difference of the CLI root agree (CL-R6). The shell's byte formatter shows them as they come.
- **Clean's locks are the core's too.** `clean.scan` reports per CLI the lock on its logs (a running or waiting session, RD27) and on its caches (any live process of the CLI, RD35: `sessions` for a row in any state but ended, `processes` for a process with no row, such as a Codex `app-server`), or `processUnknown` when the process check failed; `clean.move` reads the Activity report again before and after archiving and refuses a locked row whatever the shell sent ([clean.md](clean.md#rules-that-are-easy-to-get-wrong)).
- **The pid is never a parameter.** `activity.stop` finds the live process from the id, so a reused pid cannot be signalled (the checks Stop makes before the signal are in [activity.md](activity.md#rules-that-are-easy-to-get-wrong)). A Codex id before its first prompt is `pid:<n>:<start-ms>`, bound to the process start; an id ending `:unknown` cannot authorize a stop.

## Wire types

Keys are camelCase exactly as written. A nullable member is always present with `null`; the exceptions are marked "omitted". Timestamps are ISO 8601 UTC with milliseconds (`2026-11-07T10:00:00.000Z`), the same text as a journal `at`; Limits is the one exception, below. Counts and ids are integers.

```ts
type Cli = "claude" | "codex"
type Scope = "global" | "project" | "local"      // rules scope; dir is null for "global", absolute otherwise
type Verdict = "allow" | "ask" | "deny"
type Capability = "read" | "edit" | "run" | "network" | "push" | "secrets"
type CapabilityState = "allow" | "ask" | "deny" | "mixed" | "none"
type RuleMove = { rule: string, from: Verdict }  // from: the verdict the caller saw the rule under

type JournalEntryRef = { id: string, at: string, label: string, undone: boolean, count: number }
// ops are left out.

type RegistryCli = {                              // clis.registry; an id is lowercase and stable, a Cli value for the two CLIs read today
  id: string, name: string,                       // name: "Claude Code", "Codex"
  supports: { skill: boolean, agent: boolean, hook: boolean, rule: boolean, logs: boolean, limits: boolean }
}                                                 // skill, agent, hook are the wire kinds; false = Not supported
```

Inventory and usage (Go: [inventory/types.go](../../core/internal/inventory/types.go), [usage/types.go](../../core/internal/usage/types.go); Swift DTOs: [CoreTypesInventory.swift](../../Sources/SpaceVibe/Core/CoreTypesInventory.swift), [CoreTypesUsage.swift](../../Sources/SpaceVibe/Core/CoreTypesUsage.swift)):

```ts
type Cell =
  | { state: "counted", runs: number, last: string | null, errors?: number }   // errors omitted unless a hook
  | { state: "pending", reason: string }
  | { state: "unmeasurable", reason: string }
  | { state: "missing" }
type Cells = { claude: Cell, codex: Cell }
type CliCell =                                    // loadout.rows only
  | { state: "counted", sessions: number, days: string[], last: string | null, note?: string }   // skill or agent; days YYYY-MM-DD, sorted
  | { state: "counted", runs: number, errors: number, errorsLast7Days: number, last7Days: HookDay[], last: string | null, note?: string }   // hook; errors is lifetime
  | { state: "unmeasurable", reason: string }    // installed, nothing SpaceVibe can count: never 0
  | { state: "scanning" }                         // installed; no usage scan has finished in this process
  | { state: "missing" } | { state: "unknown" } | { state: "notSupported" }
// note: omitted unless a counted zero may be too new for the logs (D63: "Added in the last 24 hours", "Added after the newest log")
type HookDay = { day: string, runs: number, errors: number }   // day YYYY-MM-DD; last7Days lists 7, oldest first, ending today (UTC)
type CliCells = { [registryId: string]: CliCell }  // one member per clis.registry entry

type InventoryItem = {                            // a skill or a subagent
  id: string, cli: Cli, kind: "skill" | "agent", name: string, entry: string, description: string,
  owner: string,                                  // "user", "link", or a plugin name
  path: string, file: string, removable: boolean, scope: "global" | "project", project: string | null,
  inOther: boolean, key: string,                  // key = "<kind>:<project or empty>:<bare name>"
  override?: string | null,                       // written on every Claude global skill (null when settings hold no value); omitted on all other items
  cells?: Cells,                                  // omitted until usage is attached
  cliCells?: CliCells,                            // loadout.rows only
  folder?: string, realPath?: string,             // loadout.rows only: the path of its Folder; path with every link followed
  firstSeen?: string                              // loadout.rows only: when it was added as far as SpaceVibe knows; omitted when unknown
}
type HookUsage = { runs: number, avgMs: number | null, totalMs: number, errors: number, last: string | null }
type InventoryHook = {
  id: string, cli: Cli, kind: "hook", event: string, matcher: string | null, command: string /* credentials masked; hash is of the raw text */, timeout: number | null,
  async: boolean, owner: string, removable: boolean, dead: boolean, paths: string[], hash: string, file: string,
  scope: "global" | "project", project: string | null,
  key: string,                                    // "hook:<project or empty>:<hash>"
  cells?: Cells, cliCells?: CliCells,             // cliCells: loadout.rows only
  folder?: string,                                // loadout.rows only: equals file
  firstSeen?: string,                             // loadout.rows only, as on InventoryItem
  usage: HookUsage | null                         // usage is always present; null when unknown or not logged
}
type InventorySnapshot = {
  items: InventoryItem[], hooks: InventoryHook[], problems: string[],
  events: { claude: string[], codex: string[] }, roots: { claude: string, codex: string }
}

type NameUsage = { sessions: number, days: string[], last: string | null }       // days: YYYY-MM-DD, sorted
type HookTotals = { runs: number, ms: number, timed: number, errors: number, last: string | null }
type CliTotals = { skill: { [name: string]: NameUsage }, agent: { [name: string]: NameUsage }, hook: { [hash: string]: HookTotals } }
type LogWindow = { files: number, oldest: string | null, newest: number | null }  // newest: ms since 1970
type UsageResult = {
  totals: { claude: CliTotals, codex: CliTotals }, sessions: { claude: number, codex: number },
  windows: { claude: LogWindow, codex: LogWindow }, files: number,
  problems?: string[]                             // omitted when empty; e.g. the usage archive cannot be read, so the logs Clean moved are not counted
}

type FilterCounts = { all: number, only: { claude: number, codex: number }, neverRan: number, dead: number }
type LoadoutRows = {                              // what the shell's LoadoutData.build and LoadoutRows.build start from
  usage: "scanning" | "ready",
  items: InventoryItem[], hooks: InventoryHook[],  // cells attached, hook usage attached
  problems: string[], events: { claude: string[], codex: string[] }, roots: { claude: string, codex: string },
  countsByScope: { [scope: string]: FilterCounts },   // key "global", or an absolute project folder
  rowFlags: { [rowKey: string]: { one: boolean, neverRan: boolean, dead: boolean } },
  folders: Folder[],                              // the readers map, sorted by path
  extraItems: InventoryItem[],                    // left out of every v5 member until RB-X1: the Codex skills of ~/.agents/skills; cliCells, folder, realPath, no cells
  extraProblems: string[]                         // the problem lines about ~/.agents/skills, left out of problems
}
type Folder = {                                   // a skills or agents folder, or for hooks the file that holds them
  path: string,                                   // the reader's spelling; an item's or hook's folder repeats it exactly
  realPath: string,                               // path with every link followed; folders with one realPath are one folder
  kind: "skill" | "agent" | "hook",
  readBy: string[],                               // registry ids, registry order, never empty
  ownedBy: string,                                // the CLI whose folder it is; reading only others' folders = "via" (RD31)
  copyTarget: boolean                             // loadout.copyToOther and loadout.copyTo write into ownedBy here; false for ~/.agents/skills, plugin and project folders
}
// rowFlags[key].one = (only.claude + only.codex > 0) of filterCounts over that row's members; neverRan and dead are counts > 0.
```

Activity (from `ActivityReport.jsonObject`, the same names as the frozen `activity.json`):

```ts
type ActivityReport = {
  sessions: {
    cli: Cli, id: string, title: string, project: string | null, pid: number,
    state: "running" | "waiting" | "idle" | "ended" | "unmeasurable", stateReason: string,
    reasonCode: string | null,                    // open: known values below under unmeasurable
    currentTool: { name: string, target: string } | null,   // target: credentials masked (see Output discipline)
    ageMs: number | null, lastWriteAgoMs: number | null,
    cost: { usd: number, estimated: true } | null, costNote: string | null
  }[],
  failures: {
    kind: "command" | "hook", cli: Cli, key: string,   // key: hash of the raw command
    title: string, count: number, exit: number | null, reason: string,   // title and reason: credentials masked
    projects: string[], sessions: number, first: string | null, last: string | null, laterPass: string | null,
    hook: { hash: string, event: string } | null
  }[],
  files: { path: string, label: string, edits: number, sessions: number, last: string | null, clis: Cli[], projects: string[] }[],
  unmeasurable: { cli: Cli, code: string, text: string }[],     // code: same values as reasonCode
  // known codes: codex-no-rollout, codex-rollout-unreadable (the rollout exists but could not be read), codex-tool-silent, claude-prompt-vs-busy, claude-unknown-status, codex-hook-runs, codex-process-unknown
  stats: { logs: number, truncated: number }
}
```

`reasonCode` and `unmeasurable[].code` are open strings: a Swift DTO must decode an unknown value without failing and show `stateReason` or `text`. `codex-process-unknown` reads "The system process check failed just now, so Codex sessions cannot be matched to their logs. This is not a log that is missing." It appears on a Codex row, or as one extra `unmeasurable` entry, only while `ps` or `lsof` keeps failing; it is not in the fixed entries.

Rules (`ruleObject` and the preview shapes are the ones the frozen rules golden holds, compared by [golden_test.go](../../core/internal/rules/golden_test.go)):

```ts
type Rule = {                                     // golden ruleObject
  id: string,                                     // "<scope>:<verdict>:<rule>"
  scope: Scope, dir: string | null, file: string, verdict: Verdict, rule: string,
  tool: string | null, specifier: string | null,
  wide: boolean                                   // RB-E6, outside ruleObject: the rule covers a whole tool (rules.md); any verdict
}
type CapabilityCell = { capability: Capability, label: string, state: CapabilityState, editable: boolean, rules: Rule[] }
type VerdictRule = { verdict: Verdict, rule: string }
type CapabilityPreview = {                        // golden preview outcome
  capability: Capability, verdict: Verdict, scopeLabel: string, current: CapabilityState, resulting: CapabilityState,
  replaces: VerdictRule[], writes: VerdictRule[]
}
type CodexPermissions = {                         // flag lists keep file order, which the UI shows
  present: boolean, model: "legacy" | "profiles" | "both", unrestricted: boolean, warnings: string[],
  approvalPolicy: { mode: string } | { granular: { key: string, value: boolean }[] } | null,
  sandboxMode: string | null,
  sandboxWorkspaceWrite: { networkAccess: boolean | null, writableRoots: string[] } | null,
  defaultPermissions: string | null, approvalsReviewer: string | null,
  profiles: { name: string, filesystemEntries: number, networkEntries: number, networkFlags: { key: string, value: boolean | string | number /* a URL's password is masked */ }[] }[],
  projects: { path: string, trustLevel: string | null }[],
  rules: { files: number, allow: number, prompt: number, forbidden: number, other: number,
           unreadable: number, folderNotReadable: boolean },   // .rules files not counted; rules folder not listable
  notReadable: boolean,                           // config.toml could not be read: every setting above is unknown, not the defaults
  skippedLines: number                            // config.toml lines the reader could not understand; `warnings` says so
}
type RulesSnapshot = {                            // no UI-only fields
  projectDirs: string[],                          // discovered; display names are made by the shell
  globalRuleCount: number,
  scope: Scope, dir: string | null,               // the selection actually read; "global" when the asked project is gone
  fileLabel: string, exists: boolean, problems: string[],      // scrubbed
  rules: Rule[], grid: CapabilityCell[], codex: CodexPermissions,
  notReadable: boolean,                           // the scope's file or folder cannot be looked at: rules and grid are unknown, not empty, and not editable
  globalNotReadable: boolean                      // the same for the global file that globalRuleCount counts
}
```

Clean (Go: [clean/types.go](../../core/internal/clean/types.go); no Swift DTO yet, RB-R5 adds it):

```ts
type CleanScan = {
  clis: {                                         // claude, codex, in registry order (RD42)
    cli: Cli,
    logs: { state: "measured" | "missing" | "unreadable",
            buckets: { olderThanDays: 30 | 90 | 180, files: number, bytes: number }[] },   // only ages with a log; a bucket holds every older age
    caches: { id: string, path: string, entries: number, files: number, bytes: number }[], // allowlisted, non-empty only
    locks: { logs: CleanLock | null, caches: CleanLock | null }
  }[],
  items: { key: string, bytes: number }[],        // row key of loadout.rows; a row with no removable Skill or Subagent member is absent
  problems?: string[]                             // omitted when empty; a staging folder of an interrupted move whose list is refused
}
type CleanLock = { reason: "sessions" | "processes" | "processUnknown", sessions: string[], message: string }   // sessions: Activity session ids
type LogPick = { cli: Cli, olderThanDays: 30 | 90 | 180 }
type CleanMoveResult = {
  entry: JournalEntryRef | null,                  // null only if nothing moved, which is answered as an error instead
  moved: { files: number, bytes: number },        // what left the CLI folders
  groups: { id: string, moved: { files: number, bytes: number }, stayed: number, reason: string | null }[],  // id "logs:<cli>" or the cache id
  cancelled: boolean,
  trash: string | null                            // the "SpaceVibe Clean <date>" folder in the Trash
}
```

Limits. The shape follows the projection the frozen [`limits.json`](../../core/testdata/fixtures/golden/limits.json) golden uses, which the Go test compares against; `statusline` sits beside the entries, outside that projection. Its timestamps (`at`, `resetsAt`, `statusline.at`) are seconds since 1970 as numbers (fractions allowed), the one place this protocol does not use ISO text; do not convert them.

```ts
// every nullable member (plan, source, at, minutes, scope) is always present, null when unknown
type LimitsEntry = {
  cli: "claude" | "codex" | "gemini",
  state: "measured" | "notRecorded" | "unreadable" | "notMeasurable" | "notInstalled",
  plan: string | null, source: "claudeCache" | "claudeStatusline" | null,
  at: number | null,                              // when the record was taken; set only when measured
  windows: {
    id: string, minutes: number | null, scope: string | null, usedPercent: number,
    resetsAt: number, active: boolean,            // active: false when the CLI marks it as not applying now
    current: boolean                              // resetsAt is after the core's now
  }[]                                             // [] unless measured, never null
}
type LimitsResult = {
  limits: LimitsEntry[],
  statusline: { at: number | null }               // the newest status-line snapshot of this Claude account; null when none is accepted
}
```

`statusline.at` is what Settings › Limits ages ("Last snapshot 12 min ago", RD24). It is a different fact from the claude entry's `at`, which dates the reading that entry shows and can come from Claude's usage cache: a newer cache wins the entry, and `statusline.at` still dates the snapshot. A snapshot of another account, one dated after the core's now, or any snapshot while the account cannot be identified is not counted, the filter the claude entry applies too.

A window with `current: false` has passed its reset: its `usedPercent` no longer describes the window and reads as unknown, never as 0. The core returns it as recorded. `current: true` is only true at the read time: the shell also compares `resetsAt` with its display clock before showing a share, countdown or recommendation ([`LimitsWording`](../../Sources/SpaceVibe/Limits/LimitsWording.swift)). `usedPercent` can pass 100, and every percentage on the wire is used, never left: only the shell computes the share left ([limits.md](limits.md#rules-that-are-easy-to-get-wrong)). No field carries file content (S-R3).

## Canonical golden writer

Golden tests do not compare wire output. They build a named projection of a Go result and a golden, run both through one writer, and compare bytes. The writer is [`goldentest.Canonical`](../../core/internal/goldentest/canonical.go):

- object keys sorted in UTF-16 code-unit order, as `Array.prototype.sort` does, not Go's byte order;
- numbers printed as JavaScript prints them ([`number.go`](../../core/internal/goldentest/number.go)): shortest round-trip digits, no exponent from 1e-6 up to 1e21; a `json.Number` is parsed and reprinted, so `1.0` becomes `1`;
- 2-space indent, `": "` after a key, `[]` and `{}` for empty containers, one trailing newline;
- no HTML escaping, and U+2028 and U+2029 written raw, as `JSON.stringify` does; invalid UTF-8 written as U+FFFD;
- structs are refused: build a `map[string]any` tree.

Rules around it:

- **Never use it for the wire.** The wire is compact, one line. The RPC and `--json` share one encoder; only tests canonicalize.
- **Never use `encoding/json` output as expected text.** It sorts differently, escapes `<>&` and U+2028, and prints floats its own way.
- **`$HOME` token.** `HomeToken` replaces the fixture root with `$HOME` in keys and values, on both sides, before comparing.
- **Assert the case count.** `AssertCaseCount` fails a golden test that ran zero cases, so an unloaded golden cannot pass.
- **Goldens are frozen.** `SHA256SUMS` covers `golden/*.json`, `manifest.json` and `zst/*`, and `VerifyChecksums` also fails on a file added to a covered folder. A wrong golden is fixed together with its test in one commit (SV5), and its line in `SHA256SUMS` changes in that commit. `cli-cells.json` (the `cliCells` of every fixture row, after a scan and before one) has no Node or Swift origin: `go test ./internal/inventory -run TestGoldenCLICells -update-cli-cells` writes it, under the same freeze. `rules-wide.json` (the `wide` of every rule the rules golden lists, shared fixture HOME and `rules-home/main`) likewise: `go test ./internal/rules -run TestGoldenRulesWide -update-rules-wide`.
- **Leak guard.** `FindLeaks` scans every file under `core/testdata`, and the decompressed `.zst`, for the real home path, user name and temp root (S-R2). It reports file names, never the matched content.
- **On failure, print a unified diff of the canonical text**; on success, log the canonical SHA-256.
