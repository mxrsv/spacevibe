# Backlog

Candidate UI/UX improvements, bug fixes, refactors and feature upgrades for SpaceVibe, grounded in the current SwiftUI shell (`Sources/SpaceVibe`, redesign frame behind `SPACEVIBE_REDESIGN=1`), the Go core (`core/`) and the public page (`site/`). Items here are **uncommitted proposals**, not promises or release dates. Move an approved item into a spec under `docs/specs/` (or a task in the owning plan under `docs/plans/`) before building. The commit that ships an item ticks it here and names it in a `Backlog:` line of its message ([AGENTS.md](../AGENTS.md), B10); a ticked item stays in the file, so its number is not taken again.

## How this file is organised

- **One section per domain.** A domain is a page of the app ([GLOSSARY.md](../GLOSSARY.md) names), a shared layer, or a part of the repo. A request such as "backlog landing" or "check backlog rules" means every open item of that section, and nothing outside it. The table under "Domains" lists each section and the other names it answers to.
- **One item is one change.** It ships and is checked alone, in one PR. An item that needs "and" in its title is two items.
- **Where an item goes.** Under the domain where the user sees the change. A shared building block goes under Components; a change nobody sees goes under Store and performance or Cut-over and wire.
- **Ids are `BL-<DOMAIN>-<n>`.** A number is never reused or renumbered; a new item takes the next number of its section. `from BL4` or `from M1` names the bundle the item was cut from on 2026-11-23, when the file was split by domain.
- **Tags, in this order:** priority, size when it is not small, type, then `decision` or `blocked`.
  - Priority: `P1` quick win, `P2` core upgrade, `P3` big bet, `P4` later or not ranked. The priorities of the Landing section and of every `refactor` item cut from the old housekeeping list are the splitting agent's proposal, not an owner decision.
  - Size: an item is small unless it says `M` or `L`.
  - Type: `bug`, `ui`, `feature`, `copy`, `a11y`, `perf`, `seo`, `test`, `refactor`.
  - `decision`: the owner settles it before anyone builds; the line names the decision id it touches. `blocked`: it waits for the named item or gate.
- **An item has two lines.** The title line, then what is wrong today and, after `→`, what to do. "The audit recorded the fix only" means nobody wrote down what is wrong: confirm it in the code before building.

## Rules for items here

- Follow SpaceVibe's core principles in [PRODUCT.md](../PRODUCT.md), [GLOSSARY.md](../GLOSSARY.md) and [AGENTS.md](../AGENTS.md) (`S-R1`–`S-R6`): local-only data, honest numbers (never `0` for `Unmeasurable`), nothing executed, Undo on every write (except `Stop`), and SwiftUI shell owns presentation while the Go core owns reads, writes and locks.
- Do not duplicate work already shipped on `main`. When an item changes an earlier decision (`D<n>`, `RD<n>`, `DS-R<n>`) or overlaps with an open issue (such as [#8](https://github.com/mxrsv/spacevibe/issues/8)), tag it `decision` so the owner decides before implementation.

## Domains

| Section | Ids | Also called | Covers |
| --- | --- | --- | --- |
| [Frame](#frame) | `BL-FRAME` | shell, toolbar, sidebar, keyboard | The window frame, toolbar, sidebar, keyboard focus and menu commands |
| [Components](#components) | `BL-COMP` | design system, surfaces, controls | Shared controls, surfaces and tokens in `Sources/SpaceVibe/Components` and `Tokens` |
| [Inbox](#inbox) | `BL-INBOX` | findings | The Inbox page and its inspector |
| [Skills and Subagents](#skills-and-subagents) | `BL-SKILLS` | equip, subagents, usage | The two list pages, their inspector, and usage evidence |
| [Hooks](#hooks) | `BL-HOOKS` | | The Hooks page and its inspector |
| [Rules](#rules) | `BL-RULES` | permissions | The Rules page, its grid, sheet and read-only Codex page |
| [Clean](#clean) | `BL-CLEAN` | | The Clean page |
| [Limits](#limits) | `BL-LIMITS` | windows, status line | The Limits page |
| [Activity](#activity) | `BL-ACT` | sessions, failures | The Activity page, sessions and failures |
| [Settings](#settings) | `BL-SET` | | The Settings window |
| [Undo and Journal](#undo-and-journal) | `BL-UNDO` | journal | Undo, the write toast and the Journal window |
| [Glance](#glance) | `BL-GLANCE` | widget | The glance widget |
| [Tokens](#tokens) | `BL-TOKENS` | cost history | The token and estimated cost history, not built yet |
| [Instructions](#instructions) | `BL-INSTR` | `CLAUDE.md`, `AGENTS.md` | Showing instruction files, read-only; not built yet |
| [Store and performance](#store-and-performance) | `BL-PERF` | perf, RPC | The shell's store, the core connection and wasted work in the core |
| [Cut-over and wire](#cut-over-and-wire) | `BL-CUT` | v5 removal, `RB-X1` | Removing the v5 shell and cleaning the wire schema |
| [Landing](#landing) | `BL-LAND` | landing page, site, `spacevibe.dev` | The public page in `site/` |

---

## Frame

- [ ] **BL-FRAME-1** Toolbar spans the full width right of the sidebar (`RD57`) · `P1` `ui` · from BL1
  - [AppFrame.swift](../Sources/SpaceVibe/Shell/AppFrame.swift) and [FrameChrome.swift](../Sources/SpaceVibe/Shell/FrameChrome.swift) place `FrameToolbar` inside the main column: the right toolbar group jumps `28–336 pt` on page switches, and at `960–1099 pt` overlay widths the toolbar is squeezed to `384 pt` with its title hidden. → Span `FrameToolbar` across the area right of the sidebar, start the docked and the overlay `FrameInspector` beneath `toolbarHeight(look)`, and drop `.padding(.trailing, inspectorWidth)` and `hidesTitle` when `.overlay`.
- [ ] **BL-FRAME-2** Inspector button has its own glyph · `P1` `ui` · from BL1
  - [FrameToolbar.swift](../Sources/SpaceVibe/Shell/FrameToolbar.swift) draws the same left-sidebar glyph for Hide Sidebar and for Inspector. → Use a mirrored or right-sidebar Phosphor Bold glyph for Inspector.
- [ ] **BL-FRAME-3** List keeps keyboard focus after a page switch or a closed overlay · `P1` `bug` · from BL3
  - Nested `.focusable()` between [AppFrame.swift](../Sources/SpaceVibe/Shell/AppFrame.swift) and [ListSelection.swift](../Sources/SpaceVibe/Components/ListSelection.swift) leaves `↑/↓/j/k/Space` dead after switching pages or closing a dialog or overlay, until the list is clicked. → Unify list focus coordination so both cases hand focus back to the active list.
- [ ] **BL-FRAME-4** Selected row scrolls into view · `P1` `bug` · from BL3
  - None of the 8 redesign pages wraps its list in `ScrollViewReader`, so arrow traversal and glance widget deep links never bring the selected row into view. → Add `ScrollViewReader` with `scrollTo(selection)` to all 8 lists.
- [ ] **BL-FRAME-5** Glass sidebar cutout animates with the sidebar on `⌃⌘S` · `P1` `ui` · from BL2
  - The audit recorded the fix only. → Sync the Glass sidebar cutout animation with the sidebar toggle.
- [ ] **BL-FRAME-6** No traffic-light clearance in full screen · `P1` `ui` · from BL2
  - The audit recorded the fix only. → Drop the clearance for the window buttons in full screen.
- [ ] **BL-FRAME-7** Sidebar items say what their number means and show `⌘1–⌘8` · `P2` `ui` · from BL7
  - `FrameSidebarItem` in [FrameControls.swift](../Sources/SpaceVibe/Components/FrameControls.swift) renders bare numbers with no tooltip and no shortcut. → Add a tooltip per item and the `⌘1–⌘8` shortcuts.
- [ ] **BL-FRAME-8** Hide `0` counts in the sidebar · `P2` `ui` `decision` (`RD10`) · from BL7
  - The sidebar shows `0` on 6 pages. → Owner call: hide a `0` count or keep it.
- [ ] **BL-FRAME-9** `⌘K`: Command Palette or Inbox `Keep` · `P2` `feature` `decision` (`RD39`, [GLOSSARY.md](../GLOSSARY.md)) · from BL7
  - `AppCommandPalette` is wired only in v5, while `⌘K` triggers Inbox `Keep` in the redesign. → Owner call: port `AppCommandPalette` to redesign tokens and move Inbox `Keep` to `⇧⌘K`, or remove the Command Palette clause from `GLOSSARY.md`.
- [ ] **BL-FRAME-10** Window button observer is released · `P4` `refactor` · from housekeeping
  - The audit recorded the fix only. → Add `deinit { stopObserving() }` to [FrameWindowButtons.swift](../Sources/SpaceVibe/Shell/FrameWindowButtons.swift).

## Components

- [ ] **BL-COMP-1** One `PageHeader`, aligned to the top (`RD58`) · `P1` `ui` · from BL1
  - [CleanList.swift](../Sources/SpaceVibe/Clean/CleanList.swift), [HooksList.swift](../Sources/SpaceVibe/Hooks/HooksList.swift) and [RulesList.swift](../Sources/SpaceVibe/Rules/RulesList.swift) align their heroes `.bottom`. → Extract a shared `PageHeader` built on `HStack(alignment: .top, ...)`.
- [ ] **BL-COMP-2** Hero line height and gap · `P1` `ui` · from BL1
  - The audit recorded the fix only. → Raise `TypeRole.hero` line height from `44` to `48` in [TypeRole.swift](../Sources/SpaceVibe/Tokens/TypeRole.swift) and the `PageHero` gap from `step2` to `step4`.
- [ ] **BL-COMP-3** One surface per popover · `P1` `ui` · from BL2
  - [MenuPanel.swift](../Sources/SpaceVibe/Components/MenuPanel.swift) and [PopoverPanel.swift](../Sources/SpaceVibe/Components/PopoverPanel.swift) apply `.overlayPanelSurface()` (border plus a 17 pt shadow, or glass) while 9 of 10 call sites wrap them in SwiftUI `.popover(...)`, which gives double chrome; only [RulesCapabilityGrid.swift](../Sources/SpaceVibe/Rules/RulesCapabilityGrid.swift) uses `.anchoredOverlay(...)`. → Move every call site to `.anchoredOverlay(...)`, or strip `.overlayPanelSurface()` inside system popovers.
- [ ] **BL-COMP-4** Solid inspector stands on `groupSurface` (`DS-R1`) · `P1` `ui` · from BL2
  - [FrameSurfaces.swift](../Sources/SpaceVibe/Components/FrameSurfaces.swift) paints the Solid-look inspector with `canvasSurface`, so `tileLogoDisc` and `tileCheckDisc` read as mismatched stickers. → Use `ColorRole.groupSurface`.
- [ ] **BL-COMP-5** Glass stays on the sidebar, toolbar and overlays (`DS-R8`) · `P1` `ui` · from BL2
  - [PushButtonStyle.swift](../Sources/SpaceVibe/Components/PushButtonStyle.swift) and [FrameSegmentedControl.swift](../Sources/SpaceVibe/Components/FrameSegmentedControl.swift) gate `.glassEffect` on control size only, which leaks Glass into `DialogSheet`, `PerCLISheet`, `SettingsPanes` and `RulesScopeBar`. → Add `@Environment(\.controlSurface)` (`.toolbar` or `.content`, default `.content`; only `FrameToolbar` sets `.toolbar`) and make `FrameGlassSurface` paint `solid` when `when: false`.
- [ ] **BL-COMP-6** Group surface has an edge under Increase Contrast · `P1` `a11y` · from BL2
  - The audit recorded the fix only. → Add the `controlEdge` hairline to `GroupSurfaceGround`.
- [ ] **BL-COMP-7** Sticky group headers have a bottom hairline · `P1` `ui` · from BL2
  - The audit recorded the fix only. → Add a bottom hairline to sticky `RowGroup` headers.
- [ ] **BL-COMP-8** Search field has a clear button · `P1` `ui` · from BL3
  - [SearchField.swift](../Sources/SpaceVibe/Components/SearchField.swift) has no `×`. → Add it, and give focus back to the list on `Esc`.
- [ ] **BL-COMP-9** Focus bar fits round controls · `P1` `ui` · from BL3
  - [FocusBar.swift](../Sources/SpaceVibe/Components/FocusBar.swift) clips the 3 pt bar into a thin crescent on `.capsule` and circular buttons. → Adjust the `FocusBarMark` geometry for those shapes.
- [ ] **BL-COMP-10** Switch reaches the minimum hit height (`DS-R5`) · `P1` `a11y` · from BL3
  - [FrameSwitch.swift](../Sources/SpaceVibe/Components/FrameSwitch.swift) is `20 pt` tall; the minimum is `24 pt`. → Wrap it in a `28 pt` hit cell with hover and press states.
- [ ] **BL-COMP-11** `StatusBadge` primitive · `P2` `M` `ui` `decision` ([#8](https://github.com/mxrsv/spacevibe/issues/8), `RD15`, `RD-R2`, `RD-R12`, `RD48`, `DS-R10`) · from BL6
  - [LabelChip.swift](../Sources/SpaceVibe/Components/LabelChip.swift) is used in one place (`Whole tool`) and has no `mono` and no semantic tone, so scope, freshness, `Read-only`, `Dead`, `Never ran` and `Unmeasurable` are bare `·`-joined text. → Introduce `StatusBadge` (tones `.neutral`, `.attention`, `.critical`, `.ok`, `.quiet`; outlined or tinted; `isMono`) for metadata and status in rows and inspectors. Settle the unconfirmed mock choices first.
- [ ] **BL-COMP-12** Per-CLI inspector rows replace the boxed tiles · `P2` `M` `ui` `decision` (`RD53`, [#8](https://github.com/mxrsv/spacevibe/issues/8)) · from BL6
  - [CLITileGrid.swift](../Sources/SpaceVibe/Components/CLITileGrid.swift) packs 5 overlapping layers into `72×60 pt` boxes with `2 pt` padding and clips large counts. → Compact rows, `[Logo 16] Name | ShareMeter + full count | Switch/Toggle`, in line with the bar comparison in [PRODUCT.md](../PRODUCT.md).
- [ ] **BL-COMP-13** `CLILegend` explains every mark · `P2` `ui` · from BL9
  - `CLILegend` in [PopoverPanel.swift](../Sources/SpaceVibe/Components/PopoverPanel.swift) explains only `via` and `Unmeasurable`. → Add the amber `Never ran` dot, the read-only lock, the `Not supported` dash, the dimmed `Off` state and the `Last copy` note.
- [ ] **BL-COMP-14** CLI toggle strip grows with its lines · `P3` `ui` · from BL13
  - [CLILogoToggle.swift](../Sources/SpaceVibe/Components/CLILogoToggle.swift) caps the wrapped row at 2 lines (`60 pt`) and clips at 11 or more CLIs. → Compute the `CLIToggleStrip` height from the wrapped line count.
- [ ] **BL-COMP-15** One icon renderer · `P4` `refactor` · from housekeeping
  - [FrameGlyph.swift](../Sources/SpaceVibe/Components/FrameGlyph.swift) duplicates the icon rendering. → Collapse it into `SpaceVibeIcon(frame:size:)` and restore `.accessibilityAddTraits(.isImage)`.
- [ ] **BL-COMP-16** `FrameRowAction` carries a loading state · `P4` `refactor` · from housekeeping
  - `HooksRowActionButtons` and `RulesRowActionButtons` duplicate [FrameRowActions.swift](../Sources/SpaceVibe/Shell/FrameRowActions.swift), and the Activity row `Stop…` gives no loading feedback. → Add `isLoading: Bool = false` to `FrameRowAction`, delete the two duplicates, and use it on `Stop…`.
- [ ] **BL-COMP-17** One `Try Again` button · `P4` `refactor` · from housekeeping
  - 4 `Try Again` buttons differ. → Unify them into `FrameTryAgainButton`.
- [ ] **BL-COMP-18** Shared clipboard, day and path helpers · `P4` `refactor` · from housekeeping
  - The audit recorded the fix only. → Extract `FrameClipboard`, `DayWording.daysAgo` and one tilde-path formatter.
- [ ] **BL-COMP-19** `CleanWording.sentence` lives in shared wording · `P4` `refactor` · from housekeeping
  - The audit recorded the fix only. → Move it out of `Clean/` into the shared wording.
- [ ] **BL-COMP-20** `RowTableHead` on Skills, Subagents, Hooks and Rules · `P4` `refactor` · from housekeeping
  - The audit recorded the fix only. → Adopt `RowTableHead` on those lists.
- [ ] **BL-COMP-21** Same `.rowStripe` parity on every list · `P4` `ui` · from housekeeping
  - Activity stripes differ from Skills, Hooks and Rules. → Normalize the parity.
- [ ] **BL-COMP-22** `.pending` looks the same in both usage cells · `P4` `ui` · from housekeeping
  - [SessionsCell.swift](../Sources/SpaceVibe/Components/SessionsCell.swift) and [RunsCell.swift](../Sources/SpaceVibe/Components/RunsCell.swift) render `.pending` differently. → Align them.
- [ ] **BL-COMP-23** Pace tick lives in `ShareMeter` · `P4` `refactor` · from housekeeping
  - `WindowMeter` draws its own pace tick. → Merge it into [ShareMeter.swift](../Sources/SpaceVibe/Components/ShareMeter.swift).
- [ ] **BL-COMP-24** Button size reaches the label through the environment · `P4` `refactor` · from housekeeping
  - The audit recorded the fix only. → Propagate `PushButtonStyle.Size` into `PushButtonLabel` via `@Environment`.
- [ ] **BL-COMP-25** `StatusBanner` surface and progress · `P4` `bug` · from housekeeping
  - [StatusBanner.swift](../Sources/SpaceVibe/Components/StatusBanner.swift) mishandles `.groupSurface()` and `progress: nil`. → Fix both.
- [ ] **BL-COMP-26** `InspectorFact.id` is unique · `P4` `bug` · from housekeeping
  - The audit recorded the fix only. → Make `InspectorFact.id` unique.
- [ ] **BL-COMP-27** `InspectorTitle` aligns to the top · `P4` `ui` · from housekeeping
  - The audit recorded the fix only. → Align `InspectorTitle` to `.top`.
- [ ] **BL-COMP-28** Text input takes its corner from the look · `P4` `refactor` · from housekeeping
  - The audit recorded the fix only. → Use `RadiusRole.controlCorner(look)` in [TextInputField.swift](../Sources/SpaceVibe/Components/TextInputField.swift).

## Inbox

- [ ] **BL-INBOX-1** Keeping the first Balance finding no longer hides the rest · `P1` `bug` · from BL4
  - [Findings.swift](../Sources/SpaceVibe/Shell/Findings.swift) picks one Balance finding before it filters `facts.kept`, so keeping that one hides every other Balance gap for good. → Filter the kept Balance ids inside `Findings.balance`.
- [ ] **BL-INBOX-2** Selected row does not draw `Keep` over the evidence · `P1` `bug` · from BL4
  - A selected row in [FindingRowContent.swift](../Sources/SpaceVibe/Components/FindingRowContent.swift) draws a transparent `Keep` over the `evidence` column. → Hide `evidence` on a selected row, or back the actions with `selectionFill`.
- [ ] **BL-INBOX-3** `Remove` selects the next row · `P1` `bug` · from BL4
  - `Remove` in [InboxRegion.swift](../Sources/SpaceVibe/Inbox/InboxRegion.swift) jumps the selection back to row 0. → Advance with `CurrentRow.neighbour`.
- [ ] **BL-INBOX-4** Inbox and Skills share one inspector · `P2` `M` `refactor` · from BL9
  - [InboxInspector.swift](../Sources/SpaceVibe/Inbox/InboxInspector.swift) diverges from [EquipInspector.swift](../Sources/SpaceVibe/Skills/EquipInspector.swift): it drops `SharedFileConfirmation` ("Copy first, then remove"), spins every tile on one click, skips description clamping, and omits `Keep` on Clean up and `Remove`/`Keep` on Hooks. → Share one inspector component and one tile-toggle handler.
- [ ] **BL-INBOX-5** `Balance is off` opens Settings · `P2` `ui` · from BL9
  - [InboxList.swift](../Sources/SpaceVibe/Inbox/InboxList.swift) renders "Balance is off" as dead text. → Make it `Open Settings › CLIs`.
- [ ] **BL-INBOX-6** Remove dead `InboxWording.removableMembers` · `P4` `refactor` · from housekeeping
  - Nothing calls it. → Delete it.

## Skills and Subagents

- [ ] **BL-SKILLS-1** `Space` ticks a row · `P1` `bug` · from BL3
  - [EquipList.swift](../Sources/SpaceVibe/Skills/EquipList.swift) lacks `.onKeyPress(.space)`, unlike Inbox and Clean. → Add it.
- [ ] **BL-SKILLS-2** `Clear Selection` is reachable · `P1` `bug` · from BL4
  - `ClearSelectionButton` in [EquipList.swift](../Sources/SpaceVibe/Skills/EquipList.swift) is unreachable once any row is ticked. → Place it in the `N selected` header bar.
- [ ] **BL-SKILLS-3** Empty `Never ran` filter says the right thing · `P1` `copy` · from BL4
  - With no row under `Never ran`, [EquipListModel.swift](../Sources/SpaceVibe/Skills/EquipListModel.swift) states "No Skill is loaded by these CLIs." → Say that every item of that kind has run.
- [ ] **BL-SKILLS-4** `Never ran` count shows once · `P2` `ui` `decision` ([#8](https://github.com/mxrsv/spacevibe/issues/8), `RD15`, `RD-R2`, `RD-R12`, `RD48`) · from BL6
  - Skills and Subagents stack about 234 pt of chrome before row 1, repeat `N never ran` in `PageHero` and in `GroupHead` (against "a number shows once" in [PRODUCT.md](../PRODUCT.md)), and put `Never ran N` right above the most used rows in `All`. → Remove the repeated count on list pages; the 40 pt hero stays on Clean and Limits.
- [ ] **BL-SKILLS-5** `Never ran` count follows the active filter · `P2` `bug` · from BL6
  - The audit recorded the fix only. → Scope the `neverRan` count to the active CLI filter and the search.
- [ ] **BL-SKILLS-6** Scanning banner shows progress · `P2` `ui` · from BL8
  - [FrameStore.swift](../Sources/SpaceVibe/Shell/FrameStore.swift) passes `progress: nil` to `usage.scan`, so the banner is indeterminate. → Wire `usage/progress` (`done / total`) into it.
- [ ] **BL-SKILLS-7** `Never ran` names its evidence window · `P2` `ui` · from BL8
  - `FrameStore` discards `UsageResult` (`sessions`, `windows.oldest/newest`, `files`), so the user cannot see what `Never ran` was counted across. → Show a quiet footnote, for example "Counted across 1,240 sessions since Oct 2025".
- [ ] **BL-SKILLS-8** Daily usage sparkline in the inspector · `P2` `ui` · from BL8
  - [cli-cells.go](../core/internal/inventory/cli-cells.go) already sends `cliCells[].days`; [EquipInspector.swift](../Sources/SpaceVibe/Skills/EquipInspector.swift) never draws it. → Add a compact neutral-bar sparkline. No core change.
- [ ] **BL-SKILLS-9** `Show in Finder` per file · `P2` `ui` · from BL9
  - `Show in Finder` opens only `items.first?.path`. → Offer it for each file.
- [ ] **BL-SKILLS-10** Read-only preview of `SKILL.md` and subagent files · `P2` `M` `feature` · from BL9
  - The user cannot read a skill or subagent file from the app. → Open `item.file`, and add a collapsible local read-only markdown preview.
- [ ] **BL-SKILLS-11** `Missing in pinned` filter · `P3` `feature` `decision` (`RD22`) · from BL13
  - At 100 or more items and 3 to 10 CLIs, Balance is hard to scan: Inbox shows one Balance finding and the lists have no such filter. → Add "Missing in pinned" (or "Missing in <CLI>").
- [ ] **BL-SKILLS-12** Sortable column heads · `P3` `feature` `decision` (`RD22`) · from BL13
  - The `Sessions ▾` head looks sortable and does nothing. → Make `Sessions`, `Last ran` and `Name` sort on click.
- [ ] **BL-SKILLS-13** Hide read-only rows under `Never ran` · `P3` `feature` · from BL13
  - Read-only plugin and project rows clutter the `Never ran` triage. → Add an optional toggle that hides them.

## Hooks

- [ ] **BL-HOOKS-1** Lifecycle strip follows the CLI filter · `P1` `bug` · from BL4
  - [HooksListModel.swift](../Sources/SpaceVibe/Hooks/HooksListModel.swift) computes the `LifecycleStrip` nodes across every CLI whatever the filter. → Filter the nodes by the active CLI.
- [ ] **BL-HOOKS-2** An event with no hook does not open a blank list · `P1` `bug` · from BL4
  - A `count == 0` node can be clicked into a blank header with no empty state and no way out. → Disable `0` nodes, or render an empty state with `Show All Events`.
- [ ] **BL-HOOKS-3** `Script missing` wins over 7-day errors · `P1` `bug` · from BL4
  - `statusLine` lets `errorsLastWeek` hide a `dead` hook. → Check `.dead` first.
- [ ] **BL-HOOKS-4** Sidebar severity matches the rows · `P1` `bug` · from BL4
  - [FrameWorld.swift](../Sources/SpaceVibe/Shell/FrameWorld.swift) marks the sidebar Hooks item `.critical` when the rows are only `neverRan`. → Use `.attention` when no hook is dead.
- [ ] **BL-HOOKS-5** 7-day runs and errors sparkline in the inspector · `P2` `ui` · from BL8
  - `cliCells[].last7Days` is on the wire; [HooksInspector.swift](../Sources/SpaceVibe/Hooks/HooksInspector.swift) never draws it. → Add a compact neutral-bar sparkline. No core change.
- [ ] **BL-HOOKS-6** Reveal a hook's script in Finder · `P2` `ui` · from BL9
  - `hook.paths` is returned by [types.go](../core/internal/inventory/types.go) and not shown, dead paths included. → Show the paths and add `Reveal in Finder`.
- [ ] **BL-HOOKS-7** Inspector shows `timeout`, `async`, `skillOverride` and read-only · `P2` `ui` · from BL9
  - The core returns this metadata; the inspector hides it. → Show it, with a `Read-only (Codex / plugin)` label where it applies.
- [ ] **BL-HOOKS-8** List cleans up when it leaves · `P4` `refactor` · from housekeeping
  - `HooksList` in [HooksList.swift](../Sources/SpaceVibe/Hooks/HooksList.swift) has no `.onDisappear` cleanup. → Add it.

## Rules

- [ ] **BL-RULES-1** Projects with the same folder name are reachable · `P1` `bug` · from BL4
  - [RulesList.swift](../Sources/SpaceVibe/Rules/RulesList.swift) matches projects by basename, so `~/work/web` and `~/personal/web` collide. → Key the Project menu by the full `dir` path.
- [ ] **BL-RULES-2** Capabilities grid stays on an empty scope · `P2` `ui` `decision` (`RD-R13`) · from BL10
  - `RulesList` hides `RulesCapabilityGrid` when a writable project scope has 0 rules, when a newcomer needs it most. → Keep it visible there.
- [ ] **BL-RULES-3** A capability row filters the rules behind it · `P2` `M` `feature` · from BL10
  - A `Mixed` cell explains the conflict as "any: / scoped: / own:" and cannot show the rules that cause it. → Clicking a capability row filters or highlights its rules, with the conflict in plain English.
- [ ] **BL-RULES-4** Add sheet warns before a whole-tool `Allow` · `P2` `ui` · from BL10
  - `RulesAddSheet` in [RulesInspector.swift](../Sources/SpaceVibe/Rules/RulesInspector.swift) does not warn before the write. → Show the `Whole tool` warning live, with clickable pattern examples.
- [ ] **BL-RULES-5** Header CLI summary lines are links · `P2` `ui` · from BL10
  - The `Codex` summary in the header cannot be clicked. → Make each summary line open that CLI.
- [ ] **BL-RULES-6** Project menu flags a project with a wide allow · `P2` `ui` · from BL10
  - "1 in a project" does not say which project. → Flag those projects in the Project dropdown.
- [ ] **BL-RULES-7** Bulk Allow, Ask or Deny · `P2` `M` `feature` · from BL10
  - `rules.changeVerdicts` exists in [methods.go](../core/internal/rpc/methods.go) and [RulesFrame.swift](../Sources/SpaceVibe/Rules/RulesFrame.swift) does not use it. → Wire it: one Journal entry, one Undo.
- [ ] **BL-RULES-8** Codex page shows the full settings · `P2` `ui` · from BL10
  - [codex.go](../core/internal/rules/codex.go) returns `profiles`, `granular`, `writableRoots` and `projects`; [RulesReadOnlyPage.swift](../Sources/SpaceVibe/Rules/RulesReadOnlyPage.swift) shows none of them. → Render them.
- [ ] **BL-RULES-9** `toggleAll` keeps ticks outside the search · `P4` `bug` · from housekeeping
  - `toggleAll` in [RulesPageState.swift](../Sources/SpaceVibe/Rules/RulesPageState.swift) drops the ticks the search hides. → Preserve them.

## Clean

- [ ] **BL-CLEAN-1** Lock popover leads to Activity · `P2` `ui` · from BL9
  - The lock popover in [CleanRowView.swift](../Sources/SpaceVibe/Clean/CleanRowView.swift) renders "Stopping them is in Activity." as dead text and does not scroll. → Add `Open in Activity` and clickable session rows (scrollable, capped at 5).
- [ ] **BL-CLEAN-2** `⌘F` search · `P3` `feature` · from BL13
  - Clean has no search. → Enable `⌘F`.
- [ ] **BL-CLEAN-3** Equipment rows sort by size · `P3` `ui` · from BL13
  - Rows are not ordered by what they free. → Sort by bytes, descending.
- [ ] **BL-CLEAN-4** Clicking a row ticks it · `P3` `ui` · from BL13
  - Only the checkbox ticks. → Let the row body tick too.
- [ ] **BL-CLEAN-5** Log age choice is remembered · `P3` `feature` · from BL13
  - `cleanLogAges` resets. → Persist it in `UserDefaults`.
- [ ] **BL-CLEAN-6** Hero is not `0 B` when only dead hooks remain · `P3` `copy` · from BL13
  - With `cleanable == 0 && hooks > 0` the hero reads `0 B`. → Show "N Hooks to remove".
- [ ] **BL-CLEAN-7** One log age is text, not a control · `P3` `ui` · from BL13
  - With a single age bucket the page still draws a segmented control with one option. → Render static text.

## Limits

- [ ] **BL-LIMITS-1** Install command is visible before it is copied · `P2` `ui` · from BL11
  - [LimitsCardList.swift](../Sources/SpaceVibe/Limits/LimitsCardList.swift) hides the status-line install command behind a blind `Copy Install Command`. → Show a read-only `CommandBlock` above the button; it stays copy-only (`S-R4`, `RD24`).
- [ ] **BL-LIMITS-2** Stale readings do not read `Unmeasurable` · `P2` `ui` `decision` (`RD-R2`, `RD30`) · from BL11
  - When every window is stale (over 6 h) the 40 pt hero shows `? Unmeasurable` right above readable cards. → Show "Last reading Nh ago" and the `/usage` refresh hint.
- [ ] **BL-LIMITS-3** Countdown and pace note agree · `P2` `bug` · from BL11
  - The 1 s countdown (`41:05`) and the 60 s `isBehind` note (`Faster than time · 42m`) duplicate and drift. → Omit the span from the note while the countdown is active.
- [ ] **BL-LIMITS-4** Meter tooltip gives pace figures · `P2` `ui` · from BL11
  - The audit recorded the fix only. → Add concrete pace figures to the meter tooltip.

## Activity

- [ ] **BL-ACT-1** `Show Terminal` on a session row · `P1` `bug` · from BL4
  - [ActivityPage.swift](../Sources/SpaceVibe/Activity/ActivityPage.swift) omits `Show Terminal` (`⇧⌘T`) from `actions(for: ActivitySessionRow)`, so the destructive `Stop…` is the only row, context, Item and overlay action on a `Waiting` session. → Add it, first on `Waiting`.
- [ ] **BL-ACT-2** No blank line under a tool with no target · `P1` `bug` · from BL4
  - `toolBlock` in [ActivityPageData.swift](../Sources/SpaceVibe/Activity/ActivityPageData.swift) appends an empty line when `target` is empty. → Drop it.
- [ ] **BL-ACT-3** Failure rows have a tooltip and `Dismiss` in their menus · `P1` `ui` · from BL4
  - [ActivityFailuresList.swift](../Sources/SpaceVibe/Activity/ActivityFailuresList.swift) has no hover tooltip and no `Dismiss` in the context and Item menus. → Add `.help` and the action.
- [ ] **BL-ACT-4** A hook failure links to Hooks · `P2` `ui` · from BL9
  - A failed hook in Activity is dead text. → Add `Show in Hooks`. `RD46` stands: no `Show in Limits` on Window findings.
- [ ] **BL-ACT-5** Failures has a table head and tab counts · `P2` `ui` `decision` (`RD46`) · from BL11
  - Failures has no `RowTableHead`, oversized `.pageTitle` counts and no count on its tabs. → Add the head and the tab counts.
- [ ] **BL-ACT-6** Dismissed failures can be restored · `P2` `feature` · from BL11
  - Once the toast expires a dismissed failure is gone. → Add an "N dismissed · Restore" footer.
- [ ] **BL-ACT-7** `Copy Command` is honest about a cut command · `P2` `bug` · from BL11
  - On a command truncated at 120 characters the button stays enabled and fails on click. → Disable it and say the command was cut.
- [ ] **BL-ACT-8** Narrow Activity keeps `Current tool` · `P2` `ui` · from BL11
  - The column disappears at narrow widths. → Fold it under the row instead.
- [ ] **BL-ACT-9** Stop alert uses the singular for one session · `P2` `copy` · from BL11
  - [StopAlert.swift](../Sources/SpaceVibe/Components/StopAlert.swift) uses plural copy for 1 session. → Add the singular.

## Settings

- [ ] **BL-SET-1** CLIs pane shows a skeleton while loading · `P2` `ui` · from BL11
  - [SettingsPanes.swift](../Sources/SpaceVibe/Settings/SettingsPanes.swift) flashes "No CLIs yet" before the data arrives. → Show loading skeletons.
- [ ] **BL-SET-2** Disabled `Show` and `Balance` switches say why · `P2` `ui` · from BL11
  - They have no tooltip. → Add one.
- [ ] **BL-SET-3** Copy toast names what was copied · `P2` `copy` · from BL11
  - Install and Remove both answer "Copied to the clipboard". → Name the command in each.
- [ ] **BL-SET-4** `←/→` switch panes · `P2` `a11y` · from BL11
  - The audit recorded the fix only. → Switch panes with `←/→`.
- [ ] **BL-SET-5** Settings and Journal windows drag by their background · `P4` `ui` · from housekeeping
  - The audit recorded the fix only. → Add `.windowBackgroundDragBehavior(.enabled)` to both windows.

## Undo and Journal

- [ ] **BL-UNDO-1** Toasts in the Journal window keep their width · `P1` `bug` · from BL1
  - [JournalWindow.swift](../Sources/SpaceVibe/Settings/JournalWindow.swift) uses the default `windowMargin: 160` inside a `660 pt` window, which crushes toasts to `340 pt`. → Pass `BlockRole.settingsToastWindowMargin` to `FrameToastHost`.
- [ ] **BL-UNDO-2** `Edit › Undo` names the write · `P2` `ui` · from BL7
  - The menu item in [FrameCommands.swift](../Sources/SpaceVibe/Shell/FrameCommands.swift) is a static "Undo" and is never disabled. → Show "Undo: <label>", disabled when there is nothing to undo.
- [ ] **BL-UNDO-3** Write toast shows the shortcut (`RD39`) · `P2` `ui` · from BL7
  - [WriteToast.swift](../Sources/SpaceVibe/Components/WriteToast.swift) has no `Z / ⌘Z` hint. → Add it.
- [ ] **BL-UNDO-4** Journal has a menu item · `P2` `ui` · from BL7
  - Journal is three clicks deep in Settings › Data. → Add `Window/Edit › Journal…` (`⇧⌘J`).
- [ ] **BL-UNDO-5** Journal times stay current · `P2` `bug` · from BL7
  - The timestamps freeze while the window is open. → Wrap `JournalWindow` in a 60 s `TimelineView`.

## Glance

- [ ] **BL-GLANCE-1** Empty strip is clickable and has a menu · `P2` `ui` · from BL11
  - The empty strip in [GlanceStripParts.swift](../Sources/SpaceVibe/Components/GlanceStripParts.swift) cannot be clicked and has no right-click menu. → Make it open the app, with a menu of `Open SpaceVibe`, `Settings…`, `Hide`.
- [ ] **BL-GLANCE-2** Glance icon is Phosphor Bold · `P2` `ui` · from BL11
  - [GlanceListParts.swift](../Sources/SpaceVibe/Components/GlanceListParts.swift) draws a v5 Duotone icon. → Use the Bold set.
- [ ] **BL-GLANCE-3** Router is bound at launch · `P2` `bug` · from BL11
  - Glance binds to `model.router` lazily in `AppFrame.onAppear`. → Bind eagerly in `SpaceVibeFrameApp.init`.

## Tokens

[PRODUCT.md](../PRODUCT.md) promises a local token and estimated cost history for Claude Code and Codex. About 60% of the core foundation exists (`pricing.EstimateCost` in [pricing.go](../core/internal/pricing/pricing.go), `activity.LogTokens` in [log-tokens.go](../core/internal/activity/log-tokens.go), token totals kept in `usage-archive.json` by [archive.go](../core/internal/usage/archive.go)) and a plan is approved ([Tokens plan](plans/2026-11-03-spacevibe-tokens.md)), yet no RPC or page ships in the redesign.

- [ ] **BL-TOKENS-1** Core reads token history · `P3` `L` `feature` · from BL12
  - No `tokens.*` method exists. → Implement `core/internal/tokens/` (`tokens.scan`, `tokens.query`) over the active logs and `usage-archive.json`, so Clean never erases cost history.
- [ ] **BL-TOKENS-2** Tokens page in the redesign · `P3` `L` `feature` `blocked` (BL-TOKENS-1) · from BL12
  - No page shows the history. → Build it under the honesty rules: labelled `Estimated cost`, a model without a price is `Unmeasurable`, never `0`.

## Instructions

- [ ] **BL-INSTR-1** Show which instruction files each CLI loads · `P4` `M` `feature` · from BL15
  - The app does not show `CLAUDE.md` or `AGENTS.md`. → Surface the read-only path and size of the global and project files, with `Show in Finder`; never written ([PRODUCT.md](../PRODUCT.md), `S-R3`). Core (`inventory`) and shell.

## Store and performance

- [ ] **BL-PERF-1** `FrameWorld` is memoized · `P1` `perf` · from BL5
  - [FrameStore.swift](../Sources/SpaceVibe/Shell/FrameStore.swift) builds a fresh `FrameWorld` on every `world(now:)` call, 4 to 7 times per render pass across Skills, Hooks, Rules and Activity. → Memoize by `(snapshotGen, factsGen, minuteBucket)`.
- [ ] **BL-PERF-2** Item lookups are O(N) · `P1` `perf` · from BL5
  - [ItemReaders.swift](../Sources/SpaceVibe/Shell/ItemReaders.swift) scans `loadout.items + extraItems` per row on the main thread: about 540k iterations per search keystroke with 152 skills. → Build `foldersByPath` and `itemsByRealPath` once and pass derived list models from the page containers.
- [ ] **BL-PERF-3** Formatters and calendars are cached · `P1` `perf` · from BL5
  - [ActivityFormat.swift](../Sources/SpaceVibe/Activity/ActivityFormat.swift), [LimitsClockWording.swift](../Sources/SpaceVibe/Limits/LimitsClockWording.swift) and `EquipListModel.utc` allocate them inside hot loops. → Keep `DateFormatter`, `ISO8601DateFormatter` and `Calendar` as statics.
- [ ] **BL-PERF-4** Host app lookup leaves `body` · `P1` `perf` · from BL5
  - [ActivityInspector.swift](../Sources/SpaceVibe/Activity/ActivityInspector.swift) calls `HostAppResolver.hostApp(of:)` synchronously in `body`. → Cache the lookup by `pid`.
- [ ] **BL-PERF-5** Drop the unused `inventory.read` · `P1` `perf` · from BL5
  - `FrameStore` and `FrameWrites` fetch it on every launch and 10 s activation refresh and use nothing from it. → Remove the calls.
- [ ] **BL-PERF-6** Fewer `rules.snapshot` calls · `P1` `perf` · from BL5
  - Each refresh fires `2 × P` `rules.snapshot` RPCs, and each re-parses the global Claude and Codex configs in [service.go](../core/internal/rules/service.go). → Batch or slim the per-project calls. Swift and core.
- [ ] **BL-PERF-7** No cache write on a full cache hit · `P1` `perf` · from BL5
  - [scanner.go](../core/internal/usage/scanner.go) `fsync`s `usage-cache.json` even when no log file changed. → Skip `saveCache` then. Core.
- [ ] **BL-PERF-8** Store is split by domain · `P1` `M` `perf` · from BL5
  - One `FrameSnapshot` makes every 20 s `activity/report` tick invalidate Skills, Hooks and Rules. → Split the `@Observable` fields: `loadout`, `activity`, `limits`, `rules`, `clean`, `journal`.
- [ ] **BL-PERF-9** No `Report.Files` work on polls · `P4` `perf` · from BL16
  - `D70` retired the Activity Files tab, yet [report.go](../core/internal/activity/report.go) still computes and serializes up to 300 modified files on each `activity.subscribe` poll. → Skip it, and show a quiet note when `report.stats.truncated > 0`. Core and shell.
- [ ] **BL-PERF-10** Live sessions return without an extra `Task` · `P4` `refactor` · from housekeeping
  - [CoreConnection.swift](../Sources/SpaceVibe/Core/CoreConnection.swift) wraps the live sessions in a new `Task`. → Return them directly.

## Cut-over and wire

Every item here needs the owner's eye approval (`RB-A1`) and an explicit yes before v5 code is deleted (`RB-X1`). Keeping v5 beside the redesign costs 92 v5-only Swift files (13,825 lines, 28.4% of `Sources/SpaceVibe/`).

- [ ] **BL-CUT-1** Redesign app boots without `ShellModel` · `P3` `M` `refactor` · from BL14
  - [SpaceVibeApp.swift](../Sources/SpaceVibe/App/SpaceVibeApp.swift) boots an unused v5 `ShellModel`. → Decouple `SpaceVibeFrameApp` from it.
- [ ] **BL-CUT-2** Glance reads limits from the store · `P3` `refactor` · from BL14
  - [GlanceLimitsFeed.swift](../Sources/SpaceVibe/Glance/GlanceLimitsFeed.swift) runs a second 60 s `limits.read` poll. → Share the `FrameStore` limits data.
- [ ] **BL-CUT-3** `StatuslineCommand.capture` leaves the v5 file · `P3` `refactor` · from BL14
  - It lives in v5 [LimitsCanvas.swift](../Sources/SpaceVibe/Limits/LimitsCanvas.swift). → Extract it.
- [ ] **BL-CUT-4** Delete the v5 shell (`RB-X1`) · `P3` `L` `refactor` `decision` (`RB-A1`, `RB-X1`) `blocked` (BL-CUT-1, BL-CUT-2, BL-CUT-3) · from BL14
  - v5 and the redesign ship side by side. → Delete the v5-only files, `LaunchMode.Surface` / `SPACEVIBE_REDESIGN`, and `StyleBoundaryTests.v5Files`.
- [ ] **BL-CUT-5** One item list and one cell field on the wire · `P3` `M` `refactor` `blocked` (BL-CUT-4) · from BL14
  - `loadout.rows` keeps both `cells` and `cliCells` and splits `~/.agents/skills` into `extraItems`. → Merge `extraItems` into `items` and drop the v5 field.
- [ ] **BL-CUT-6** Retire the v5-only RPCs · `P3` `refactor` `blocked` (BL-CUT-4) · from BL14
  - `loadout.copyToOther`, `loadout.removeItem` and `loadout.removeDeadHooks` serve v5 only. → Remove them.

## Landing

The public page for `spacevibe.dev`, grounded in the [landing spec](specs/2026-11-05-spacevibe-landing.md) (`L1–L16`, `LP-R1–LP-R7`, `LP-A1–LP-A8`), [PRODUCT.md](../PRODUCT.md) and [GLOSSARY.md](../GLOSSARY.md). Nothing deploys before the gates `WEB0` (eye approval at 1440 and 390) and `WEB0b` (`REL1` replacing the deprecated `v0.1.0` at `releases/latest`).

Checked on 2026-11-23 against the code and the built page (`site/out`, measured from 320 to 1440 px). Four claims of the old bundles did not hold and are not items: the footer nav does not overflow at 320 px; `--color-ink-2` sits only on `bg` and `void`, where it reaches at least 4.68:1; the FAQ line about Gemini CLI is true, since Limits reports it as not measurable ([limits.go](../core/internal/limits/limits.go)); and "coding agents" in the headline was decided by the owner on 2026-11-22 (landing spec, "Hero round"). Items tagged `unmeasured` name an effect nobody has measured yet.

Checked a second time on 2026-11-23, every item against the code, the captures and the page built from `153fafa` in Chromium (320 to 1440 px). BL-LAND-2, 6, 10, 11, 17, 35, 42, 50, 52, 54, 55 and 58 carry what that check changed; the other items held as written. Not checked again: that the redesigned Limits and Activity pages do not render in a headless capture (BL-LAND-14, BL-LAND-15), and `REL1` (BL-LAND-41).

### Layout and responsive

- [ ] **BL-LAND-1** Page does not scroll sideways at 768 px · `P1` `bug` · from M1
  - [site-header.tsx](../site/components/landing/site-header.tsx) overflows its frame from 768 to about 860 px; at 768 the page is 813 px wide (`LP-A3` covers only 1440 and 390). → Show the desktop nav from `lg:`.
- [ ] **BL-LAND-2** Narrow bands keep the reason column · `P1` `bug` · from M1
  - In the Limits and Activity bands of [cli-bands.tsx](../site/components/landing/cli-bands.tsx) the third `Ledger` column is 0 px wide at 768 to 820 px (Limits) and 768 to 900 px (Activity), so the reason is drawn one word per line and spills out of the panel over the capture (Limits at 768: 440 px tall, 89 px past its column). Limits is 9 px at 860 and 49 px at 900; at 960 the two are 109 and 44 px. → Split those bands in two columns from `lg:`. At 1024 the reason column is then 173 px (Limits) and 108 px (Activity): check it reads before closing.
- [ ] **BL-LAND-3** Header button stays inside the gutter at 320 px · `P2` `ui` · from M1
  - The download button runs 16 px past the frame at 320 px; the page does not scroll. → Shorten the label or the padding on phones.
- [ ] **BL-LAND-4** Hero reading labels have room at 320 px · `P2` `ui` · from M1
  - The label column of layout B in [hero.tsx](../site/components/landing/hero.tsx) is 62 px wide at 320 px. → Give the row a phone layout.
- [ ] **BL-LAND-5** One breakpoint · `P2` `refactor` · from M1
  - Media queries use `720 px` ([scene.tsx](../site/components/landing/scene.tsx)), `760 px` ([globals.css](../site/app/globals.css), [scene.css](../site/app/scene.css)) and `768 px` (Tailwind `md:`). → Align on `768 px`, with a tablet `--gutter: 28px`.
- [ ] **BL-LAND-6** FAQ question has vertical padding · `P2` `ui` · from M1
  - `<summary>` in [faq-section.tsx](../site/components/landing/faq-section.tsx) has a minimum height and no vertical padding. At 320 px two questions wrap to two lines and sit 6 px from the row's edges, where a one-line question has 18 px; no question wraps to three lines today. → Add `py-3.5`.
- [ ] **BL-LAND-7** Phone shows the part of a screen that matters · `P2` `ui` `decision` (landing spec, "Inferred, not decided") · from M4
  - [app-window.tsx](../site/components/landing/app-window.tsx) shows a capture at `190%` width on phones and cuts its right 47%: byte totals, session bars, the `Allow / Ask / Deny` pickers and the action buttons of `clean.webp`, `skills.webp` and `rules.webp`. → Owner call: horizontal pan (`max-md:overflow-x-auto`, a right-edge fade, "Swipe to inspect · demo data"), or dedicated `srcMobile` crops.

### Colour and focus

- [ ] **BL-LAND-8** Button hover keeps 4.5:1 · `P1` `a11y` · from M1
  - `--color-accent-hover` `#5274f1` gives white text 4.10:1. → Use a darker hover step, as the app does (`DS2`: `#0A66D2`, 5.46:1).
- [ ] **BL-LAND-9** Focus outline reaches 3:1 · `P1` `a11y` · from M1
  - `:focus-visible` in [globals.css](../site/app/globals.css) is the accent at 75%, 2.57 to 2.73:1 on the page's surfaces (WCAG 1.4.11), and sets a radius on every element that has none. → A 3:1 outline that keeps each element's own corner.
- [ ] **BL-LAND-10** Accent is the app's primary · `P2` `ui` · from M1
  - The page uses the v5 blue `#4164ed`; the redesigned app in the captures uses `primaryAction` `#0B6FE4`. → Adopt the redesign value. Four places copy the blue as a raw `rgb(65 100 237)` and a token change misses them: `::selection` and `:focus-visible` in [globals.css](../site/app/globals.css), `--scene-core-shadow` and `--scene-orbit-wash` in [scene.css](../site/app/scene.css).
- [ ] **BL-LAND-11** Surfaces are Graphite, no hue cast (`RD9`) · `P2` `ui` · from M1
  - The page's surfaces are cool-tinted (`#0d0f12`, `#111318`, `#15181d`); the app's are `canvasSurface` `#111214`, `groupSurface` `#191A1D`, `sidebarSurface` `#141518`. → Take the values from `DS-R1`. The old bundle proposed four hex values; only `#111214` is an app token. `--color-glass` in [globals.css](../site/app/globals.css) and the header background in [site-header.tsx](../site/components/landing/site-header.tsx) copy `--color-s1` as a raw `rgb(13 15 18)`, and `themeColor` in [layout.tsx](../site/app/layout.tsx) copies `--color-bg`: change them with the tokens.

### Captures and Open Graph

- [ ] **BL-LAND-12** Re-shoot `rules.webp` · `P2` `ui` · from M2
  - The capture cuts the top of the `2` hero and the inspector's header. → Retake it with both whole.
- [ ] **BL-LAND-13** Re-shoot `skills.webp` · `P2` `ui` · from M2
  - The capture has no toolbar and no skill title, clips `CLIs` to `C...`, and its selected row is off screen. → Retake it.
- [ ] **BL-LAND-14** Whole-page Limits capture (`LP-R4`) · `P2` `ui` `blocked` (the redesigned Limits page does not render in a headless capture) · from M2
  - `limits.webp` is a 672 px inspector crop, upscaled on Retina. → Capture the page at 2112 px and drop `narrow` on the band.
- [ ] **BL-LAND-15** Whole-page Activity capture (`LP-R4`) · `P2` `ui` `blocked` (the redesigned Activity page does not render in a headless capture) · from M2
  - `activity.webp` is a 672 px inspector crop and shows none of `Stop`, `Show Terminal`, `Copy Session Id`. → Capture the page at 2112 px and drop `narrow` on the band.
- [x] **BL-LAND-16** Activity `alt` describes what the image shows · `P1` `a11y` · from M2
  - The `alt` in [shots.ts](../site/components/landing/shots.ts) names `Show Terminal` and `Copy Session Id`, which the image does not show. → Describe the image as it is, until BL-LAND-15.
- [ ] **BL-LAND-17** Hero `77%` has the app's colour · `P1` `bug` · from M2
  - Layout B shows "77% left in the Codex 5-hour window" in green (`tone: "ok"` in [content.ts](../site/components/landing/content.ts)); `limits.webp` shows that window's bar in amber. → Match the app. The meter fill in [hero.tsx](../site/components/landing/hero.tsx) is `bg-ok` whatever the tone, so the tone alone does not recolour the bar.
- [ ] **BL-LAND-18** Hero icons carry no state colour · `P2` `ui` · from M2
  - The readings in [hero.tsx](../site/components/landing/hero.tsx) put the state colour on the page icon ([PRODUCT.md](../PRODUCT.md), Colour). → Put the state on the figure or a state mark, and keep the page icon neutral.
- [x] **BL-LAND-19** `og.jpg` `alt` matches the image · `P1` `a11y` · from M2
  - `SITE.ogImage.alt` describes the retired hero ("Which of your skills actually run?" above the Inbox); the image shows layout B. → Rewrite it.
- [ ] **BL-LAND-20** `og.jpg` names SpaceVibe · `P2` `ui` · from M2
  - The image carries no name and no mark. The hero is picked (BL-LAND-21), so nothing blocks it. → Retake it from layout B with the brand visible and a clean bottom edge, and rewrite its `alt` with it.

### Hero

- [x] **BL-LAND-21** Pick the hero layout and headline · `P1` `decision` (landing spec, "Hero round") · from M3
  - `/` shows layout B with the second headline, the spec's recommendation; it shows no pixel of the real app above the fold. The audit behind the old bundle proposed layout C instead: a sharp Inbox crop with `Clean up`, `Control`, `Watch` and `Remove` in light window chrome, legible at 1440 and 390, under an action-led headline. → Owner picks on `/hero-lab`. Picked 2026-11-23: layout B with the second headline (landing spec, L17).
- [ ] **BL-LAND-22** Delete the review route and the unpicked options (`LP-A1`) · `P1` `refactor` `blocked` (BL-LAND-21) · from M3
  - [hero-lab/page.tsx](../site/app/hero-lab/page.tsx), [hero-lab.tsx](../site/components/landing/hero-lab.tsx), the unpicked layouts and headlines, and the captures only they use still export into `site/out/`, as the spec allows until the pick. → Delete them so `npm run build` lists `/` and `/_not-found` only.
- [ ] **BL-LAND-23** Lede names SpaceVibe · `P2` `copy` · from M3
  - On layout B the lede opens with "It counts…". → Name the app in it.
- [ ] **BL-LAND-24** Lede does not promise an Inbox the page never shows · `P2` `copy` · from M3
  - The lede says "one inbox"; `/` has no Inbox band and, on layout B, no Inbox screen. → Show the Inbox or change the sentence.
- [ ] **BL-LAND-25** "Free" sits beside the first download button · `P2` `copy` · from M3
  - The hero note says "macOS 15 or later · Apple silicon"; "Free" first appears in the FAQ. → Add it to the note, in the wording of `LP-R6`.
- [ ] **BL-LAND-26** GitHub link on phones · `P2` `ui` · from M3
  - The header hides the GitHub link below `sm:`. → Keep a GitHub link visible in the first viewport on a phone.

### Scene and bands

- [ ] **BL-LAND-27** Idle loops in the scene · `P2` `ui` `decision` (`FE-M1` against `L2`; landing spec, "Inferred, not decided") · from M5
  - [scene.css](../site/app/scene.css) runs 5 infinite animations while the page is idle (`scene-drift`, `star-drift`, `star-twinkle`, `orbit-run`, `scene-breathe` over blurred circles). → Owner call: static, or subtle motion; the audit proposed dropping `scene-breathe` and `scene-drift`.
- [ ] **BL-LAND-28** Planet fades into the first band · `P2` `ui` · from M5
  - The hero's planet arc is cut hard at the bottom edge of `#top`. → Add a 140 px bottom fade from `.scene[data-variant="hero"]` into `--color-bg`.
- [ ] **BL-LAND-29** Download band has a centred backdrop · `P2` `ui` · from M5
  - [download-band.tsx](../site/components/landing/download-band.tsx) draws a dot grid and a veil biased to the left behind centred copy. → Remove the dot grid and use a centred radial veil.
- [ ] **BL-LAND-30** Band icons are SpaceVibe's own page icons (`RD23`) · `P2` `ui` · from M5
  - [band-icon.ts](../site/components/landing/band-icon.ts) uses Lucide icons. → Inline the 5 Bold page icons from [PageIcons.json](../Resources/PageIcons.json).
- [ ] **BL-LAND-31** Ledger rows carry the CLI marks · `P2` `ui` · from M5
  - `Ledger` names each CLI with an 8 px dot and has no row dividers. → Use the 14 px brand marks and `divide-y divide-edge`.

### Copy and FAQ

- [x] **BL-LAND-32** "subagent", not "agent" · `P1` `copy` · from M6
  - The privacy panel in [content.ts](../site/components/landing/content.ts) says "the skill, agent, hook and permission locations". → Say "subagent" ([GLOSSARY.md](../GLOSSARY.md)).
- [x] **BL-LAND-33** Skills verdict does not say "run" · `P1` `copy` · from M6
  - The Claude Code verdict of the Skills band is "Every run counted"; `Runs` is for hooks only, skills and subagents count `Sessions`. → Reword the verdict.
- [x] **BL-LAND-34** One wording for what cannot be measured · `P1` `copy` · from M6
  - The cost FAQ says "not measured"; the rest of the page says "not measurable"; the glossary term is `Unmeasurable`. → Use one wording.
- [x] **BL-LAND-35** "Codex", not "Codex CLI" · `P2` `copy` · from M6
  - The lede and the FAQ say "Codex CLI"; the glossary names the CLI "Codex". On `/` only the FAQ shows it: the long lede is drawn by layout `now` alone, on `/hero-lab`. → Use the glossary name.
- [x] **BL-LAND-36** No "dead" in an `alt` · `P2` `copy` · from M6
  - The Clean `alt` in [shots.ts](../site/components/landing/shots.ts) says "never-ran or dead skills"; the glossary avoids "dead". → Reword it.
- [ ] **BL-LAND-37** Clean ledger says what differs per CLI · `P2` `copy` · from M6
  - Both rows read "Moved, with Undo". → Differentiate them: usage totals are kept, logs of a running session are locked, `.jsonl.zst`.
- [ ] **BL-LAND-38** Limits ledger says what differs per CLI · `P2` `copy` · from M6
  - Both rows read "Read locally". → For example "Usage cache / status line" against "Last turn, with age".
- [ ] **BL-LAND-39** Skills band shows Balance and Hooks · `P2` `copy` · from M6
  - Balance (job 2 in [PRODUCT.md](../PRODUCT.md)) and Hooks get one clause each. → Surface both in the band.
- [ ] **BL-LAND-40** Activity band separates session cost from Tokens · `P2` `copy` · from M6
  - The band mentions estimated cost without saying it is per session, while Tokens history is "In development". → Say which is which.
- [ ] **BL-LAND-41** FAQ covers install and signing · `P2` `copy` `blocked` (`REL1`) · from M6
  - No answer covers installing a notarized build. → Add it once `REL1` has shipped.
- [ ] **BL-LAND-42** FAQ covers what Clean keeps and Undo · `P2` `copy` · from M6
  - No answer says that Clean keeps usage totals. Undo is already in the Clean band ("Undo brings it back", "Moved, with Undo") and in the privacy panel, and the FAQ holds only what those do not answer. → Add the answer about usage totals.
- [ ] **BL-LAND-43** Update check is said once · `P2` `copy` · from M6
  - The privacy panel, the FAQ and `DOWNLOAD.body` each state the daily update check. → Drop it from `DOWNLOAD.body`.

### SEO, loading and tests

- [ ] **BL-LAND-44** Security headers · `P2` `seo` · from M7
  - [vercel.json](../site/vercel.json) holds redirects only. → Add the security headers.
- [ ] **BL-LAND-45** Cache headers for static files · `P2` `perf` · from M7
  - No `Cache-Control` is set for `/landing/**`, `/icon.svg` and `/og.jpg`. → Add it.
- [ ] **BL-LAND-46** Canonical link and touch icon · `P2` `seo` · from M7
  - [layout.tsx](../site/app/layout.tsx) sets neither `canonical` nor `apple-touch-icon`. → Add both.
- [ ] **BL-LAND-47** `robots.txt` and `sitemap.xml` · `P2` `seo` · from M7
  - Neither exists. → Add both.
- [ ] **BL-LAND-48** JSON-LD · `P2` `seo` · from M7
  - The page has no structured data. → Add `SoftwareApplication` and `FAQPage`.
- [ ] **BL-LAND-49** Dark 404 page · `P2` `ui` · from M7
  - There is no `not-found.tsx`. → Add a dark-only one.
- [ ] **BL-LAND-50** Heading paints at once · `P4` `perf` · from M7
  - The hero `<h1>` starts at `opacity: 0` for 80 ms before its entrance. Measured, it does not delay LCP: at 1440 and at 390 the LCP element is the scene raster of [scene.tsx](../site/components/landing/scene.tsx), 7 to 11 times the heading's area. What is left is a heading that appears 80 ms late. → Remove the delay on the heading.
- [ ] **BL-LAND-51** Hero CLI marks load eagerly · `P2` `perf` · from M7
  - The two brand SVGs under the heading render with `loading="lazy"`. → Load them eagerly.
- [ ] **BL-LAND-52** Content already in view is visible at once on a mid-page load · `P4` `perf` · from M7
  - [scroll-reveal.tsx](../site/components/landing/scroll-reveal.tsx) hides in-view `[data-reveal]` nodes until the observer fires. Measured, nothing flashes: after a reload at the FAQ a node in view starts at `opacity: 0` and takes about 0.5 s to fade in; with the script 700 ms late it never leaves `opacity: 1`; on `/#faq` the smooth scroll starts at the top, so the node is hidden only while off screen. → Mark the nodes already in view `.in` before setting `data-motion-ready`.
- [ ] **BL-LAND-53** Plain `<img>` for unoptimized images · `P4` `refactor` · from M7
  - `next/image` runs with `unoptimized: true`. → Replace the wrappers with `<img>`.
- [ ] **BL-LAND-54** "opens in a new tab" reads as separate words · `P4` `a11y` `unmeasured` · from M7
  - The screen-reader span in [button-link.tsx](../site/components/landing/button-link.tsx) and [site-footer.tsx](../site/components/landing/site-footer.tsx) has no leading space. Chromium's accessibility tree already names the links with the space ("Download for macOS (opens in a new tab)", "GitHub (opens in a new tab)"); Safari with VoiceOver is not measured. → Add one.
- [ ] **BL-LAND-55** Tests assert `LP-A1`, `LP-A4` and `LP-A5` · `P2` `test` · from M7
  - [landing-facts.test.mjs](../site/tests/landing-facts.test.mjs) checks none of the three. `LP-A4` and `LP-A5` hold today; an `LP-A1` assertion fails until BL-LAND-22 has removed `/hero-lab`. → Add them.
- [ ] **BL-LAND-56** Tests cover the remaining files and redirects · `P2` `test` · from M7
  - Screens are checked for existence, the brand marks and `og.jpg` are not; [redirects.test.mjs](../site/tests/redirects.test.mjs) checks `/vi/live` and `/vi/deck`, not `/vi/free-tier`, `/vi/vote` and `/vi/vote/privacy`. → Add the missing cases.

### Dead code

- [ ] **BL-LAND-57** Remove the unused `style` prop · `P4` `refactor` · from housekeeping
  - No caller passes `style` to `AppWindow` in [app-window.tsx](../site/components/landing/app-window.tsx). → Remove it.
- [ ] **BL-LAND-58** Remove unused tokens · `P4` `refactor` · from housekeeping
  - `--shadow-lift` and `--font-mono` in [globals.css](../site/app/globals.css) are unused. → Remove them. The `opacity` rules of `.scene__surface`, `.scene__spill` and the download variant in [scene.css](../site/app/scene.css) are not dead: `scene-breathe` overrides them only while it runs, and under `prefers-reduced-motion` they are the values in use (0.7, 0.62, 0.55). Keep them.
- [ ] **BL-LAND-59** Tidy the header markup · `P4` `refactor` · from housekeeping
  - [site-header.tsx](../site/components/landing/site-header.tsx) has a redundant `aria-label` / `aria-hidden` pair and a `sm:contents` wrapper. → Remove them.
- [ ] **BL-LAND-60** Remove the `start` script · `P4` `refactor` · from housekeeping
  - `"start": "next start"` in [package.json](../site/package.json) cannot serve an `output: "export"` build. → Remove it.
- [ ] **BL-LAND-61** Fix stale comments · `P4` `refactor` · from housekeeping
  - Comments in [site-footer.tsx](../site/components/landing/site-footer.tsx) ("the four anchors"; there are five), [globals.css](../site/app/globals.css) and [site/README.md](../site/README.md) describe an older page. → Bring them up to date.
