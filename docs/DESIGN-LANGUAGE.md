# SpaceVibe design language

The shipped interface is the v5 shell: three pages, Agents (Skills, Subagents, Hooks, Rules), Activity and Limits, plus Settings and the session glance widget. It is the same in development and distribution builds; no UI environment switch is required. [Registry](../Sources/SpaceVibe/Shell/TabRegistry.swift), [app shell](../Sources/SpaceVibe/Shell/AppShell.swift), [design decisions](specs/2026-11-06-reins-design-language-v5.md).

## Screens compose shared components

Visual decisions belong in [Tokens](../Sources/SpaceVibe/Tokens) and [Components](../Sources/SpaceVibe/Components). Agents, Skills, Subagents, Hooks, Rules, Activity, Limits, Shell and Settings only compose them. [StyleBoundaryTests](../Tests/SpaceVibeTests/StyleBoundaryTests.swift) rejects local fonts, colours, spacing and paint; [PointerCursorPolicyTests](../Tests/SpaceVibeTests/PointerCursorPolicyTests.swift) requires shared controls to own the pointer. Inventory models remain shared under [Agents](../Sources/SpaceVibe/Agents).

## Type and colour

Inter is the only bundled font. Each [text role](../Sources/SpaceVibe/Tokens/SpaceVibeType.swift) owns its size, weight, line box, tracking and font features; [TypeScale](../Sources/SpaceVibe/Tokens/TypeScale.swift) applies the Settings font-size choice. Screen code chooses a semantic role rather than supplying a size.

[Palette](../Sources/SpaceVibe/Tokens/Palette.swift) owns dark and light colours. Green, amber and red communicate state; category identity and CLI identity remain distinct from state. `sessionWorking`, `sessionWaiting` and `sessionDone` in [Palette](../Sources/SpaceVibe/Tokens/Palette.swift) are state colours too: they belong to Activity's session states as the glance widget draws them, and unmeasurable or idle sessions use `mute`. [ContrastTests](../Tests/SpaceVibeTests/ContrastTests.swift) checks composite surfaces and visible focus; [HuePolicyTests](../Tests/SpaceVibeTests/HuePolicyTests.swift) checks category and state separation.

## Colour tokens

What each colour token is for. The values, dark and light, live only in [Palette](../Sources/SpaceVibe/Tokens/Palette.swift), so this page never drifts from the code. A token marked † departs from the frozen v5 mock, for contrast or for hue separation; the reason and the mock's value are on its line in `Palette.swift`. The ink twins (`cat*Ink`, `cat*CountInk`, `accentInk`, `accentCountInk`, `successInk`, `warnInk`, `dangerInk`, `claudeInk`), the shadows and the product mark's colours are in `Palette.swift` only. What was specified, and the accent and category candidates that were not built, are in the [v5 spec](specs/2026-11-06-reins-design-language-v5.md#token-table).

### Surfaces and lines

| Token | Job |
| --- | --- |
| `bgSide` | Sidebar and window |
| `bgApp` | Search field ground |
| `bgPanel` | Content panel, the Skills list and pane |
| `bgRaise` | Cards, buttons, meters, chips |
| `bgSunk` | Verdict box |
| `bgPop` | Menu, popover, toast, bottom bar, palette, dialog |
| `bgBand` | Band header |
| `bgBandHover` † | Hovered band header |
| `bgBandFocus` | Focused band header; hovered and focused together take this one fill |
| `hair` | Hairline border of cards and panels |
| `hair2` | Control outline, overlay edge, chart base |
| `rowDivider` | Divider between rows |
| `hi` | 1 px top-edge highlight of panels, cards, buttons and overlays |
| `hover` | Hover fill |
| `sel` | Current row, current sidebar item, and the focus fill |
| `track` | Meter and bar track |
| `trackHi` | Stronger track |
| `kbdBg` | Key cap fill |
| `kbdBorder` | Key cap edge |
| `kbdOnSolidBorder` † | Key cap edge on a solid button |
| `hiOnSolid` | Top-edge highlight of a solid button |
| `scrim` | Ground behind a dialog |

### Text

| Token | Job |
| --- | --- |
| `fg` | Primary text |
| `fg2` † | Secondary text |
| `fg3` † | Tertiary text |
| `fg4` | Disabled and separators; never text a user must read |

### Accent, state and identity

| Token | Job |
| --- | --- |
| `accent` | Indicators and fills: the current row's bar, a picked checkbox, Activity's active tab, the system tint |
| `accentText` † | The accent as text: links, `Show more`, `Clear`, the toast's `Undo` |
| `accentSolid` † | Solid accent fill under white text: primary button, switch, the product mark |
| `accentBg` | Picked row and filter count |
| `accentCountText` † | Count of picks beside a field in the Filter menu |
| `onAccent` | Text on a solid accent fill |
| `ok` † | State: fine |
| `warn` † | State: needs attention |
| `bad` † | State: danger |
| `badSolid` † | Solid danger button fill under white text (Stop) |
| `badText` † | Danger button text while hovered |
| `mute` | Off dot of a CLI status row; unmeasurable and idle sessions |
| `onVerdict` | Cut-out inside a verdict glyph |
| `sessionWorking` | Session state: running (glance widget) |
| `sessionWaiting` † | Session state: waiting for the user (glance widget) |
| `sessionDone` | Session state: idle and written to within the last 10 minutes (glance widget) |
| `claude` | Claude Code identity (clay) |
| `codex` | Codex identity: the text colour |

### Category colours

| Token | Job |
| --- | --- |
| `catSkill` | Skills |
| `catSubagent` | Subagents |
| `catHook` | Hooks |
| `catRule` † | Rules |

A tab chip's fills are shares of one colour, `fg` for an inactive tab and the category (the accent on Activity) for the active one (`TabChipAlpha` in `Palette.swift`): 7% at rest, 12% hovered, 26% active, 34% active and focused; the count circle is 12% inactive and 40% active. The active tab's text and count use the category's ink twins.

## Layout and interaction

[AppShell](../Sources/SpaceVibe/Shell/AppShell.swift) keeps inactive pages mounted, but hides them from input and accessibility. Settings covers the page, while the command palette and confirmations occupy the window overlay. [TabRegistry](../Sources/SpaceVibe/Shell/TabRegistry.swift) owns sidebar order and Command-number navigation; Limits is a regular tab.

[Metrics](../Sources/SpaceVibe/Tokens/Metrics.swift) owns component dimensions. [SplitCanvas](../Sources/SpaceVibe/Components/SplitCanvas.swift) shares available height between summary cards and the main list and stacks them at narrow widths. [ListPaneLayout](../Sources/SpaceVibe/Components/ListPaneLayout.swift) owns the Skills list and detail pane. These layouts remain distinct.

[LogoToggle](../Sources/SpaceVibe/Components/LogoToggle.swift) still represents per-CLI installation and guarded add/remove actions. [WarningSlot](../Sources/SpaceVibe/Components/WarningSlot.swift) exposes the explanation and related actions through its popover. [FocusFill](../Sources/SpaceVibe/Components/FocusFill.swift) keeps focus visible on selected rows. These are shared contracts, not per-screen styling choices.

[ToastHost](../Sources/SpaceVibe/Shell/ToastHost.swift) owns the toast placement and Undo key. The newest journal write can be undone after its toast disappears; Activity dismissal has its own in-memory Undo. Stop uses [StopSessionPanel](../Sources/SpaceVibe/Activity/ActivityStopConfirmation.swift), identifies the process and consequence, and has no Undo.

Settings composes the same blocks as the other pages ([Tile](../Sources/SpaceVibe/Components/Tile.swift), [ListRow](../Sources/SpaceVibe/Components/ListRow.swift), [ActionButtonStyle](../Sources/SpaceVibe/Components/ActionButtonStyle.swift), [StatusBar](../Sources/SpaceVibe/Components/StatusBar.swift)) plus its own [RailTab](../Sources/SpaceVibe/Components/RailTab.swift), [ThemeTile](../Sources/SpaceVibe/Components/ThemeTile.swift), [SegmentedControl](../Sources/SpaceVibe/Components/SegmentedControl.swift) and [SpaceVibeSwitch](../Sources/SpaceVibe/Components/SpaceVibeSwitch.swift) on the same tokens. Icons come from two sets and one drawn set ([IconPolicyTests](../Tests/SpaceVibeTests/IconPolicyTests.swift)): MingCute Line for the categories, Phosphor for the sidebar, content and Settings (Duotone) and for the glance widget's session states (Bold), plus SpaceVibe's own [verdict glyphs](../Sources/SpaceVibe/Components/VerdictGlyph.swift). This is SpaceVibe's recorded exception to the global one-icon-library rule (FE-K3 of `~/.claude/rules/frontend.md`; [D72](specs/2026-11-06-reins-linear-identity-decisions.md)); moving to one library would be its own code task.

## Building a page

The conventions every page follows, moved here from the UI v5 build plan's handoff on 2026-11-20. A new page that needs something else gets a new shared component first, never a local variant.

- **A page is a tab.** A page conforms to [SpaceVibeTab](../Sources/SpaceVibe/Shell/SpaceVibeTab.swift): its `content` draws its own [TabHead](../Sources/SpaceVibe/Components/TabChips.swift), an optional [FilterChipRow](../Sources/SpaceVibe/Components/FilterChip.swift) and its canvas, and its `hints` and `source` fill the status bar. A confirmation that must cover the whole window is the tab's `modal`, drawn by the shell (Stop uses it).
- **Model, query, wording.** A tab keeps its state and writes in a model, its filtering and ranking in a pure query file, and every sentence in a wording file ([Skills](../Sources/SpaceVibe/Skills) and [Subagents](../Sources/SpaceVibe/Subagents) are the examples). A small card that drops when it has no row builds its list in the query file and the view only tests whether it is empty.
- **Cards, rows, bands.** Cards are [Tile](../Sources/SpaceVibe/Components/Tile.swift) or [AnswerCard](../Sources/SpaceVibe/Components/AnswerCard.swift), rows are `ListRows { ListRow }` ([ListRow](../Sources/SpaceVibe/Components/ListRow.swift)), bands are `BandStack { Band }` ([Band](../Sources/SpaceVibe/Components/Band.swift)) with their open state from the `openStateStore` environment value, keyed by page and band id. Header actions and Answer fixes are slots that take the shared buttons.
- **Split pages.** A split page is a [SplitCanvas](../Sources/SpaceVibe/Components/SplitCanvas.swift): small cards on one side, each with a `maxHeight` so its body scrolls, and one spine `Tile` with `Metrics.Tile.spineMaxHeight` that stretches. A spine moved with `j`/`k` needs `scrollTarget` and an `.id` on each row.
- **Overlays.** `overlayHost()` sits once at the window's root ([OverlayHost](../Sources/SpaceVibe/Components/OverlayHost.swift)). Menus and popovers come from [ToolbarMenuButton](../Sources/SpaceVibe/Components/ToolbarMenu.swift), [WarningSlot](../Sources/SpaceVibe/Components/WarningSlot.swift) and `anchoredOverlay(isPresented:id:placement:)` with a [PopoverSurface](../Sources/SpaceVibe/Components/PopoverSurface.swift); a row's detail popover belongs to the page, which gives the focus back to the row when it closes. Menu, popover, toast and dialog surfaces use `blockSurface(Palette.bgPop, edge: Palette.hair2)` ([BlockSurface](../Sources/SpaceVibe/Components/BlockSurface.swift)) plus their shadow.
- **Glyphs.** [SpaceVibeIcon](../Sources/SpaceVibe/Components/SpaceVibeIcon.swift) draws a category or content glyph and [VerdictGlyph](../Sources/SpaceVibe/Components/VerdictGlyph.swift) a verdict; a block that takes an icon takes `any GlyphSource`.
- **Focus.** A row that is both current and focused takes one `sel` fill, never two stacked.
- **Writes.** A write made of several journal entries is one `performBatchWithUndo` on [AppEnvironment](../Sources/SpaceVibe/App/AppEnvironment.swift): one toast, one Undo, newest first, all or nothing. A change kept only in memory (Activity's dismissals) shows its toast through [ToastCenter](../Sources/SpaceVibe/Shell/ToastCenter.swift) with an `undo` closure that restores the old value.

## Departures from the frozen mock

Where the build differs from the frozen v5 mock on purpose. The build lead approved these on 2026-11-07 and 2026-11-08; the owner's eye approval of the whole build is still open (V5-A14 of the [v5 spec](specs/2026-11-06-reins-design-language-v5.md)).

- Colour: the tokens marked † under "Colour tokens".
- A menu opens 4 pt below its button (`Metrics` menu `gap`), where the spec's text gave a fixed 52 from the tab head's top.
- An inactive tab that is hovered or focused draws its label, glyph and count in `fg`; the mock keeps the count `fg2`, which reads 3.89:1 on the hovered circle ([TabChips](../Sources/SpaceVibe/Components/TabChips.swift)).
- The active tab's glyph takes the label's ink in both appearances.
- The white check in a lit logo's badge is decorative and not counted for contrast; the badge's fill against its ring carries the state ([LogoToggle](../Sources/SpaceVibe/Components/LogoToggle.swift)).

## Gallery and verification

[ComponentGallery](../Sources/SpaceVibe/Gallery/ComponentGallery.swift) renders current containers, controls, glyphs, the Skills pane and Settings specimens. Gallery and screenshot launch modes remain development-only through [LaunchMode](../Sources/SpaceVibe/App/LaunchMode.swift); promoting the UI does not enable those modes in distributed builds.

Use `SPACEVIBE_SHOT_SCREEN=<screen> scripts/dev-fixture.sh --shots <dir>` with `shell`, `skills`, `subagents`, `hooks`, `rules`, `activity`, `limits`, `settings` or `glance`; with `SPACEVIBE_REDESIGN=1` (development builds only, like the gallery) the window keys draw the redesign's [frame](../Sources/SpaceVibe/Shell/AppFrame.swift) instead ([`framePages`](../Sources/SpaceVibe/Gallery/ShotRenderer.swift)), in both looks (`frame-<page>-<glass|solid>-<appearance>.png`), and `settings` draws its separate [Settings window](../Sources/SpaceVibe/Shell/SettingsWindowFrame.swift). The [fixture wrapper](../scripts/dev-fixture.sh) supplies synthetic roots, and the [renderer](../Sources/SpaceVibe/Gallery/ShotRenderer.swift) rejects real-screen shots without the test guard. Static checks and headless shots do not establish live keyboard, VoiceOver or owner visual acceptance.
