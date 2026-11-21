# Shell data flow (redesign frame)

How the redesign's frame gets its data, derives what each page shows, writes and routes. It exists only while `SPACEVIBE_REDESIGN=1` is on in a development build ([`LaunchMode`](../../Sources/SpaceVibe/App/LaunchMode.swift)); the v5 pages keep their own per-page reads ([overview.md](overview.md#data-flow)). The requirements are the [redesign spec](../specs/2026-11-20-spacevibe-redesign.md); the behaviour reference for every derivation is the mock's pure model `world` (`src/m-model.js`, outside git).

## Decisions

- **One store, one talker.** [`FrameStore`](../../Sources/SpaceVibe/Shell/FrameStore.swift) holds the latest `clis.registry`, `inventory.read`, `loadout.rows`, `rules.snapshot` (global plus the Shared and Local file of every project the global reading lists), `limits.read`, the `activity.subscribe` reports and `journal.history`. It is the only object of the frame that calls `CoreService`. [`AppFrame`](../../Sources/SpaceVibe/Shell/AppFrame.swift) creates it, so a v5 launch never has one.
- **When it reads.** Everything at first appearance; again on app activation, skipped inside `FrameStore.refreshInterval` (10 s, the v5 interval); everything on ⌘R. A write re-reads only the sources it names, plus the journal.
- **Pure derivations.** [`FrameWorld`](../../Sources/SpaceVibe/Shell/FrameWorld.swift) is a value built from the store's snapshot, `FrameFacts` and the clock: rows, the Never ran / Dead set, Inbox findings and groups, pace and the Limits hero, Clean's rows and locks, and one `figure(for:)` per page. A page's hero and its sidebar item both call `figure(for:)`, so they cannot disagree. Selection, ticks, filters, scope pickers and popovers are page state and never enter the store or the world.
- **One write path.** [`FrameWrites`](../../Sources/SpaceVibe/Shell/FrameWrites.swift) marks the control pending, calls the core, shows the toast (Undo on the returned journal id, or the core's refusal in a danger toast), then re-reads. Nothing changes on screen before the core answers. Undo goes through `ToastCenter`'s one session stack, which the toast button, ⌘Z and Z all pop (RD39). [`FrameToastHost`](../../Sources/SpaceVibe/Shell/FrameToastHost.swift), mounted once at the frame root, draws the center's toast as `WriteToast` or `RefusedWriteToast` (a refusal stays until dismissed) and, while mounted, takes over the announcement from the center so a refusal is announced at high priority (RD-R16).
- **One route value.** [`FrameRoute`](../../Sources/SpaceVibe/Shell/FrameRoute.swift) is page + selected id + scope. Selecting a row never changes the page; opening another page clears the selection (nothing is pre-selected) and keeps the scope. Window ids are `cli:windowID` and session ids `cli:sessionID`, the ids the countdown pill and the glance widget already use.

## Constraints

- **Never invent a figure (FE-D3).** Data the engine does not report yet is a `FrameFacts` input that starts empty: hook errors in the last 7 days, the Keep list and Balance pins give no finding; without `clean.scan`, Clean's figure is `notMeasured`, never 0. Lifetime hook errors never stand in for the 7-day count.
- **Via, losers and files come from the readers map, not from a rule in the shell.** [`ItemReaders`](../../Sources/SpaceVibe/Shell/ItemReaders.swift) applies the rules of [inventory.md](inventory.md#readers-map) to `loadout.rows`' `folders` and each member's `folder` and `realPath`; a row with a member the table does not name answers `ReadersAnswer.unknown`, never a guess. Whether a rule allows a whole tool is the core's `wide` flag; the shell only keeps the allow ones.
- **The new frame reads `items` and `extraItems` together.** The Codex skills of `~/.agents/skills` are only in `extraItems` (and their problems only in `extraProblems`), because the v5 shell must not see them; a row's members are both lists grouped by key.
- **Never ran is judged over measured CLIs only.** A row is Never ran only when every counted `cliCells` cell is zero and none is unknown; unmeasurable and scanning cells never count. A registry CLI with no cell on a row reads as unknown, never as Missing.
- **Counts that look alike are not the same set.** The Skills, Subagents and Hooks heroes count every Never ran row, plugin and project rows included. Inbox's Clean up and `Select N Suggested` take only the suggested ones: not added in the last day (a counted zero carrying the core's D63 note), not plugin-owned, not a project item, not kept. Clean's Agents section lists every candidate and lets only the writable ones be selected.
- **A hidden CLI still counts where files and locks are concerned.** Show (Settings › CLIs) removes a CLI's rows and sessions from the lists; losers of a removal and Clean's locks still count it. At least one CLI stays shown.
- **Locks fail closed.** Clean locks a CLI's logs while it has a running or waiting session and its caches while any of its sessions is not ended. With no activity report yet, or with `codex-process-unknown`, every affected CLI is locked. The core enforces the same locks on its own move; the shell's copy only says so before the click.
- **The registry is the one list of CLIs.** `limits.read` still carries the v5 `gemini` entry; the world drops every CLI the registry does not list.

## Traps

- **Activity has one source at a time.** While the subscription is live the store never calls `activity.read`, because a read that returns late would overwrite a newer push. When the stream fails, a read stands in and the next refresh subscribes again.
- **The scan's follow-up read never starts another scan.** A core that restarted answers `loadout.rows` with `scanning` and no scan running, which starts one; the read that follows a finished scan is excluded, or a core that keeps answering `scanning` would loop.
- **A late answer loses.** Each source has a generation; an answer for an older request is dropped. A failed refresh keeps the last reading (`failed` with data); only a source never read is `failedEmpty`, which makes its page's figure `failed`.
- **Rules ids repeat across files.** A rule id is `<scope>:<verdict>:<rule>`, so the same rule in two projects has the same id; finding ids add the project folder. The core reads an unknown project as global; such a reading is ignored for the project it was asked for.

## Verification

`scripts/test.sh` runs the model's swift-testing suites (fakes and the fixture home, never the real config; S-R1).
