# SpaceVibe: app-wide redesign (macOS frame, v2), build plan

Started 2026-11-21. Status: waiting for gate G-0 (the mock passes the owner's five readiness questions; on 2026-11-21 none of the five is a clear yes) and then G-1 (track approval) before RB-T1.
Spec: [app-wide redesign](../specs/2026-11-20-spacevibe-redesign.md) (RD1–RD31, RD-R1–RD-R17, RD-A1–RD-A11; it absorbs the [Clean spec](../specs/2026-11-18-clean.md), CL1–CL4 and CL-R1–CL-R8). This plan does not repeat the requirements.
Reference: the eye-approved mock round 5, `~/scratch/spacevibe-reins/2026-11-20-redesign-v2/mock.html` (outside git, F4), built from `src/` with `python3 src/build.py`; its pure model `src/m-model.js` and checks `src/consistency.js` are the behaviour reference for the shell models. Round 4 stays as `mock-r4.html` for comparison only.
Checkout: `spacevibe-reins` on `main`, shared with other sessions (an untracked `docs/research/` belongs to another session and stays out of every commit); commit with `git commit -- <paths>` only (W11).

## Relation to other plans (D0)

| Plan | Relation |
| --- | --- |
| [UI v5 build](2026-11-07-reins-ui-v5-build.md) | Its built surfaces are what this plan replaces. Its open U14 (eye approval of v5) is overtaken by this redesign; its U13 live accessibility checks move to RB-V2 here. Marked in Handoff as an owed edit. |
| [Go core and SpaceVibe identity](2026-11-07-go-core-and-spacevibe-identity.md) | The engine tasks RB-E1 to RB-E7 are new protocol surface; they do not change its release gates. Engine support for CLIs beyond Claude Code and Codex stays out of scope (spec "Out of scope"). |
| [Settings](2026-11-04-reins-settings.md) | Its full-window Settings is replaced by the separate Settings window (RD4, RB-R8). |
| [Session glance widget](2026-11-19-session-glance-widget.md) | Takes the new tokens only; no flow change (mock `notShown`). |
| [Tokens page](2026-11-03-reins-tokens.md) | The redesign has no Tokens page; PRODUCT.md's cost-history promise stays open (raised 2026-11-21, not decided). |
| [Agents settings panels](2026-11-05-reins-agents.md) | On hold; nothing here builds it. |

## Approach

### FE-P9 shape

- Built on `main`, region by region, behind one dev switch `SPACEVIBE_REDESIGN=1`, read once in [`LaunchMode`](../../Sources/SpaceVibe/App/LaunchMode.swift) and honoured only when `LaunchMode.isDevelopmentBuild` is true. Off by default: the shipped app stays the v5 app and `main` stays releasable.
- With the switch on, the window uses the new frame (RB-S3) and every region built so far; a region not built yet shows an `EmptyState` "Not built yet".
- Regions: frame and Settings window, Inbox, Skills and Subagents, Hooks, Rules, Clean, Limits, Activity. The shared blocks (RB-S1 to RB-S5) land first, each as its own small change; no region writes its own copy of a shared block (FE-P9).
- Cut-over is one change (RB-X1) after the owner's eye approval (RB-A1): the navigation changes for every page at once (Agents tabs become four pages, Inbox and Clean are new), so no single region can switch alone.
- Push and merge: once the owner approves this track (G-1), each small verified change is committed, pushed and merged without asking (CLAUDE.md `<branching>`, FE-P9 exception). RB-X1 deletes code and asks first; release and deploy always ask.

### Engine first where a region needs new data

The spec's "Needs new engine data" list becomes RB-E1 to RB-E7 in `core/`. Each lands with its tests, its golden update (B6: the fixture path stays `/private/tmp/reins-fixture-home`) and its page in `docs/internals/` (core-protocol.md method table, mutations.md for writes) in the same change (AGENTS.md "A change to a documented … interface"). A region that needs one waits for it; until then its view model reads a synthetic source behind the switch, never invented numbers in a shipped path (FE-D3).

### Models before views

The mock's `world(S, pick)` is the reference for one shell-side model that every page and the sidebar read (RB-S5): findings, counts, pace, who loses an item, what can be cleaned. It is pure and tested with swift-testing; the mock's `consistency.js` rules become test cases (hero = sidebar, one Never ran set, losers, locks). Views read models only, never `CoreClient` directly.

### Files (F2)

- The repo's layout wins: one folder per screen under `Sources/SpaceVibe`, blocks in `Components`, values in `Tokens`; `StyleBoundaryTests` keeps screens free of literals (RD-A3).
- New screen folders: `Sources/SpaceVibe/Inbox/`, `Sources/SpaceVibe/Clean/`; Skills, Subagents, Hooks get their own folders (today they are tabs inside `Agents/`, which RB-X1 removes). Limits, Activity, Rules, Settings, Shell take new views beside the old files; RB-X1 deletes the old ones.
- No generation suffix in names (F3); named by function (F5). F1 before every new file.
- New tokens sit beside the v5 ones; v5 values stay for the old screens until RB-X1 deletes what nothing uses ("changed N of M", FE-SP3).

### Evidence outside the repo (F4)

Shots, crops, side-by-side sheets and contrast output go to `/tmp/spacevibe-redesign/<task>/`. Screenshots from a real config stay out of git (S-R2).

### Standard checks

```
TEST   scripts/test.sh
       → "Test run with N tests … passed", N > 0; N recorded before and after; a change in N explained
GO     cd core && go vet ./... && SPACEVIBE_TEST=1 go test -count=1 ./...      (engine tasks)
BUILD  scripts/build-app.sh            → "minos 15.0" for the app, "minos 12.0" for the core (B1)
SHOTS  SPACEVIBE_REDESIGN=1 SPACEVIBE_SHOT_SCREEN=<key> scripts/dev-fixture.sh --shots /tmp/spacevibe-redesign/<task>/<key>
MOCK   the same state rendered from the reference mock (query string recorded), placed beside the shot
```

A task is done when its checks ran and their output is pasted in Handoff (W4), not when the code compiles.

## Gates before code

- **G-0. The mock is ready** (the owner's five questions, 2026-11-21). The mock is enough when whoever checks the build has nothing to guess. All five must be yes; RB-M1 to RB-M5 close them.
  1. Every screen a user meets has a place: each page × each state of RD-R13 is drawn, or listed in the mock's "not shown" with its intended behaviour. No empty cell.
  2. It can be broken without breaking: empty, very long, very large, one item and many items cut no information and move no layout.
  3. Everything visible has a real source: each icon is a real name in the icon sets the repo uses (Phosphor Bold and SpaceVibe's own set, D72 and RD23; the mock's build reports names it cannot find), each block is an existing app component or is marked new, each figure is one the app can compute; what is only illustration is labelled.
  4. Every settled decision traces both ways: each owner sentence has a spec row, each row has a place in the mock; lines the agent inferred sit in "Inferred, not decided".
  5. A reviewer who never saw it finds no major hole: one read-only pass by an agent that did not draw the mock ends with no finding of high severity.
- **G-1. Track approval.** The owner approves this plan; until then nothing under `Sources/` or `core/` changes.
- **G-2. Checks that can change the design** (RB-T0). A failed check is reported to the owner before the dependent task starts.

## Tasks

Each task is one small change on `main` unless it says otherwise. "Serves" names spec IDs.

### Phase M: mock readiness (scratch folder, no repo code)

State on 2026-11-21, measured, per question of G-0:

| # | State | Evidence |
| --- | --- | --- |
| 1 | No | Rendering every page × state at 2 CLIs and comparing with "normal": the confirmation state is not drawn on Inbox, Rules, Clean, and on Skills and Subagents at 2 CLIs; Activity has no "just written" after Stop; the Settings window draws none of empty, scanning, error, worst, write, refused write; Hooks and Limits do not say in "not shown" that they have no confirmation or no write. |
| 2 | Partly | Break-ui ran on round 4 and its findings were fixed; round 5 was swept only for `undefined` / `NaN` / `null` (648 renders), not for cut text or layout shift. |
| 3 | Partly | Icons: the build reports "not in Phosphor Bold: none" for all 65 names. Blocks: no table maps each mock block to an existing component in `Sources/SpaceVibe/Components` or marks it new. Figures: the spec's "Needs new engine data" lists the new ones; the mock does not label which figures are illustration. |
| 4 | Partly | RD1–RD31 carry quotes and requirement ids; no column says where each one shows in the mock. |
| 5 | No | Round 5's fixes have not been reviewed by an agent that did not draw them. |

- **RB-M1. Fill the page × state grid.** Draw the missing states (confirmation on Inbox, Rules, Clean, Skills and Subagents at 2 CLIs; Activity after Stop; the Settings window's states) or add a "not shown" line with the intended behaviour (Hooks: no confirmation, Undo; Limits: no writes). Add the grid check to `src/consistency.js` so a new hole fails it.
- **RB-M2. Break pass on round 5.** Run skill `break-ui` again (fresh agent) on round 5 with the `data` axis datasets; fix or list every break.
- **RB-M3. Source table.** A table in `design-notes.md`: each mock block → the existing component it maps to, or "new"; each figure → its engine field or "needs new data" (spec list) or "illustration"; the icon names checked by the build.
- **RB-M4. Trace column.** Add a "Where in the mock" column (page, state, preset) to the spec's decision tables RD1–RD31; move any mock behaviour without a row to "Inferred, not decided".
- **RB-M5. Fresh review.** Skill `mock-review` by an agent that did not draw the mock, on round 5 with RB-M1 to RB-M4 done. G-0 passes when it reports no high-severity finding; otherwise fix and run it again.

### Phase 0: checks and switch

- **RB-T0. Settle four facts that the build depends on.** Serves RD-R11, CL-R5, RD-R16, RD-R1.
  - (a) Codex skill path: install a test Skill only in `~/.agents/skills` on a scratch HOME and see whether Codex lists it (spec "Open item to verify"). Decides RB-E2's reader map.
  - (b) macOS Trash from the core: from a test app with no Full Disk Access, move a temp file into `~/.Trash` through the core (built `CGO_ENABLED=0`), then list it. Decides whether RB-E7 moves files itself or asks the shell to call `FileManager.trashItem`.
  - (c) Keyboard: a SwiftUI `Table` with buttons in cells, Full Keyboard Access on: does Tab reach them? Decides how RB-S4 rows expose actions (RD-R16 already asks for menu commands and accessibility actions either way).
  - (d) Liquid Glass with the macOS 15 deployment target (B1): `glassEffect` behind `if #available(macOS 26, *)`, Solid otherwise, with the SDK in use (26.5 on 2026-11-21). Decides RB-S3's fallback shape.
  - Done when: each answer and its command output are in Handoff. No product code.
- **RB-T1. Dev switch.** `SPACEVIBE_REDESIGN=1` in `LaunchMode` (dev builds only), the shell picks the frame, shot keys shoot the new surfaces when the switch is on. Serves the FE-P9 shape. Done when: TEST green; a test shows a distribution build ignores the switch.

### Phase 1: engine (Go core)

- **RB-E1. CLI registry.** String ids, fixed order, a `supports` map (Skills, Subagents, Hooks, Rules, logs, limits) for Claude Code and Codex; `loadout.rows` cells keyed by registry id, with the cell kinds Not supported and Unmeasurable (loaded, no log) besides counted, missing and unknown. Serves RD-R10, RD13. Done when: GO green, goldens updated, core-protocol.md updated.
- **RB-E2. Readers map.** Per item: the folders it lives in and which CLIs read each folder (`~/.agents/skills` from RB-T0a). The shell derives "via" (RD31) and who loses an item from it; the core never guesses. Serves RD-R11, RD31.
- **RB-E3. Per-CLI copy and remove.** `loadout.copyTo {id, targets[]}` and `loadout.removeFrom {id, clis[]}` replace `loadout.copyToOther`; one Journal entry per call; a shared file is removed only when the caller passes every reader. Serves RD-R11, RD14.
- **RB-E4. Batch removal.** `loadout.removeMany {ids[]}` across Skills, Subagents and Hooks, and `rules.removeMany`, each one Journal entry so one Undo restores the whole selection. Serves RD-R4, RD-A6.
- **RB-E5. Small facts.** Hook errors per day (the last 7 days, RD26); `firstSeen` on every item (the "added N ago" line); the age of the last status-line snapshot (Settings › Limits, RD24); a Keep list in the app's data folder (`findings.keep` / `findings.unkeep`, journaled). Serves RD26, RD-R17, RD-R15.
- **RB-E6. Rules `wide` flag.** A bare or `*` rule is wide only for tools that take a specifier (RD-R17 list); MCP tool names are never wide. Serves RD-R17, RD26.
- **RB-E7. Clean.** `clean.scan` (logs by CLI and age 30/90/180 days with file counts and bytes; caches from a verified allowlist, CL-R4; real item sizes, CL-R6) and `clean.move` (to SpaceVibe's trash or the macOS Trash per RB-T0b, with progress notifications and a cancel that stops before the next file); usage archived before a log moves (CL-R3); a CLI's logs and caches locked only while it has a running or waiting session (RD27). Ships the CL-R8 doc edits (PRODUCT.md write limit, S-R rules in AGENTS.md, mutations.md). Serves CL-R1 to CL-R8, RD18, RD27. Needs `build-review` (W24) on its own before RB-R5 starts.

### Phase 2: shared base (Swift)

- **RB-S1. Tokens.** Graphite surfaces, state and category tones, primary `#0B6FE4`, link, the neutral data steps, the 3:1 light amber; type scale 11/12/13/15/22/40 pt, SF Pro text, SF Pro Rounded figures, weights 400 and 500 (600 for sidebar labels, RD23); radii and spacing of the mock's Tokens page; meter heights (RD7). Serves RD-R3, RD-R5 to RD-R9, RD6, RD9 to RD12, RD23. Done when: the Tokens + base specimen exists as a debug screen in the gallery (RD-A3) and its shot sits beside the mock's Tokens page.
- **RB-S2. Formatters.** Bytes (TB above 1,000 GB, unit chosen after rounding), money (2 decimals), plurals, compact counts, milliseconds, day-level "last ran", middle truncation, `hookLabel` (the script a Hook runs, one rule everywhere). Unit tests with the break-ui extremes. Serves RD-R17.
- **RB-S3. Frame.** Window with the floating Liquid Glass sidebar (macOS 26) and Solid fallback (macOS 15, Reduce Transparency); one solid window surface with only the sidebar's own shape showing the desktop (the 2026-11-21 fix); toolbar with a fixed-width primary slot; trailing inspector that becomes an overlay below 1100 pt and narrows the list; the separate Settings window scene; menu-bar commands for every toolbar and row action; arrow-key selection with the 3 pt focus bar (RD29); Esc closes every overlay. Serves RD-R1, RD4, RD29, RD-R16, RD-A10.
- **RB-S4. Blocks.** Hero; group head with glyph severity; row (28 pt checkbox cell, focus bar, row actions also as context menu and accessibility actions); CLI logo toggle (on, off, via, last copy, Unmeasurable, Not supported, plugin); CLI tile grid (≤ 3 rows, heat steps, check); meters with the pace tick; toast (wraps, Undo in reach) and refused-write toast (3 lines, Details); per-CLI sheet; remove confirmation; Stop alert (Cancel default, list capped at 5); scanning, empty and error states; menus (All CLIs, CLI picker, project picker); legend popover. Each block in the gallery in every state, dark and light. Serves RD-R3, RD-R11 to RD-R13, RD-R16, RD21.
- **RB-S5. Shell model.** One pure model ported from the mock's `world`: findings (RD26) with Keep, sidebar values, pace and the hero Window (RD30), Never ran over measured CLIs, losers and via (RD31), what can be cleaned and what is locked, removal sets limited to the rows shown. The mock's `consistency.js` rules ported as swift-testing cases. Serves RD-R4, RD-R10, RD-R11, RD26, RD30, RD31.

### Phase 3: regions (behind the switch)

Each region: views from RB-S4 only; shots for normal, empty, scanning, error, worst, write, refused write and its dialog states, dark and light, Glass and Solid, 1000 / 1280 / 1600, beside the mock's same state; the break-ui datasets through the shot harness (RD-A11).

- **RB-R1. Inbox.** Groups by job, Select N Suggested, Remove N selected, Keep, Show Kept, zero state. Serves RD3, RD-R4, RD26, RD-A9.
- **RB-R2. Skills and Subagents.** Toggle grid, tiles, per-CLI sheet, shared-file popover, Never ran group, pending rows during the first scan. Needs RB-E1 to RB-E4. Serves RD14 to RD16, RD31, RD-R11, RD-R12, RD-A6.
- **RB-R3. Hooks.** Lifecycle strip by stage, rows grouped by stage at every CLI count, No Hooks / Not supported lines, Claude Code-only writes. Serves RD-R10, RD-R17.
- **RB-R4. Rules.** CLI picker; Claude Code page editable (capability preview through `rules.preview`, permission change, Add Rule sheet from the mock's notShown, project picker, Shared / Local file); other CLIs read-only in their own terms. Needs RB-E6. Serves RD-R10, RD26.
- **RB-R5. Clean.** Hero = what can be cleaned, one bar, sections, lock popover, moving progress at the control, refused partial move. Needs RB-E7. Serves RD18, RD27, CL-R1 to CL-R7.
- **RB-R6. Limits.** Fixed CLI order, pace tick, 7-hour-old readings shown not judged, over the limit, no window length, Unmeasurable line, Copy Install Command. Serves RD30, RD24, RD-R10.
- **RB-R7. Activity.** Sessions (waiting first) and Failures with its own inspector, Stop from row or selection, Show Terminal. Serves RD21 (no Files tab), RD-R16.
- **RB-R8. Settings window.** General (theme switch, RD21), CLIs (Show, Balance pins), Limits (copy commands), Data (`~/.spacevibe`, Journal, SpaceVibe trash without Empty), Updates. Serves RD4, RD21, RD24, RD25.
- **RB-R9. Glance widget.** New tokens only. Serves RD-R3.

### Phase 4: review, approval, cut-over

- **RB-V1. build-review.** Skill `build-review` on the whole switch-on app (W24, RD-A7): writes, removals, shared files, Undo, Stop, Clean moves. Findings fixed or recorded before RB-V2.
- **RB-V2. Acceptance pass.** The same five questions of G-0, asked of the built app: every page × state exists in the build or behaves as the mock's "not shown" line says; the break-ui datasets cut nothing; every icon, block and figure comes from the app's own sets and the engine; every RD row has its place in the build; RB-V1 left no high-severity finding. Then, in the owner's runtime (FE-P4: stop older instances, `scripts/dev.sh` with `SPACEVIBE_REDESIGN=1` on a synthetic HOME), every page beside the mock: structure (RD-A1), first glance (RD-A2), type and meters (RD-A4), contrast (RD-A5), 2/6/10-CLI fixtures (RD-A6), retired controls (RD-A8), Inbox zero (RD-A9), Full Keyboard Access (RD-A10), break-ui datasets (RD-A11). A report per surface: matches / differs, with the shot pair.
- **RB-A1. Owner's eye approval.** One batch, after RB-V2 (D-rule D4, FE-P7). A region the owner does not approve is fixed and shown again; it blocks RB-X1 unless the owner says otherwise.
- **RB-X1. Cut-over.** Asks first. Deletes the v5 surfaces, the `Agents` tab page, the components and tokens only they use, and the switch; updates [DESIGN-LANGUAGE.md](../DESIGN-LANGUAGE.md) (the spec supersedes its v5 content), the [docs map](../README.md), PRODUCT.md ("Balance the pinned CLIs", owner wording first), GLOSSARY ("Not supported", "via"), the internals pages touched, README and CHANGELOG (D-rule D12). Done when: TEST, BUILD, StyleBoundaryTests green and the "changed N of M" count of removed tokens is in Handoff.

## Verification map

| Acceptance | Checked in |
| --- | --- |
| RD-A1, RD-A2, RD-A4, RD-A5 | RB-V2 (shots beside the mock), RB-S1 (specimen) |
| RD-A3 | every task (StyleBoundaryTests in TEST), RB-S1 |
| RD-A6 | RB-S5 tests, RB-R2 shots at 2/6/10 CLIs |
| RD-A7 | RB-V1, plus RB-E7's own build-review |
| RD-A8 | RB-V2, RB-R7, RB-R8 |
| RD-A9 | RB-S5 tests, RB-R1 |
| RD-A10 | RB-S3, RB-V2 |
| RD-A11 | RB-S2 tests, every region's break-ui shots |
| CL-R1 to CL-R8 | RB-E7, RB-R5 |

## Risks

- **R1. Engine scope.** RB-E1 to RB-E7 are larger than the views; the regions that wait on them (RB-R2, RB-R4, RB-R5) can slip. The other regions do not wait.
- **R2. Trash access** (RB-T0b). If the core cannot use the macOS Trash, Clean's move goes through the shell, which changes S-R4's list of processes and writes: owner decision before RB-E7.
- **R3. Keyboard in tables** (RB-T0c). If SwiftUI tables keep cell buttons out of Tab, menu commands and accessibility actions carry RD-A10.
- **R4. Two shells at once.** Until RB-X1 the app holds v5 and the new frame; a fix to a shared component must keep both building.
- **R5. Real data.** The mock's numbers are synthetic; FE-D3 needs RB-V2 on the owner's real config too, with shots kept out of git (S-R2).

## Handoff

- 2026-11-21: plan written. Nothing built. The owner set the five readiness questions (G-0); the measured state is in Phase M. Owed edits: point the UI v5 plan's U13 and U14 at this plan; add "Keep is stored in the app's data folder" to the spec's "Inferred, not decided" list (RB-E5 assumes it). Waiting for G-1.

/goal Pass G-0 on the mock, then build the redesign behind SPACEVIBE_REDESIGN=1 until every page matches the mock (RD-A1 to RD-A11) and answers yes to the same five questions, build-review passes and the owner approves it by eye, then cut over.
