# SpaceVibe design language

The shipped interface is the v5 shell: three pages, Agents (Skills, Subagents, Hooks, Rules), Activity and Limits, plus Settings and the session glance widget. It is the same in development and distribution builds; no UI environment switch is required. [Registry](../Sources/SpaceVibe/Shell/TabRegistry.swift), [app shell](../Sources/SpaceVibe/Shell/AppShell.swift), [design decisions](specs/2026-11-06-reins-design-language-v5.md).

## Screens compose shared components

Visual decisions belong in [Tokens](../Sources/SpaceVibe/Tokens) and [Components](../Sources/SpaceVibe/Components). Agents, Skills, Subagents, Hooks, Rules, Activity, Limits, Shell and Settings only compose them. [StyleBoundaryTests](../Tests/SpaceVibeTests/StyleBoundaryTests.swift) rejects local fonts, colours, spacing and paint; [PointerCursorPolicyTests](../Tests/SpaceVibeTests/PointerCursorPolicyTests.swift) requires shared controls to own the pointer. Inventory models remain shared under [Agents](../Sources/SpaceVibe/Agents).

## Type and colour

Inter is the only bundled font. Each [text role](../Sources/SpaceVibe/Tokens/SpaceVibeType.swift) owns its size, weight, line box, tracking and font features; [TypeScale](../Sources/SpaceVibe/Tokens/TypeScale.swift) applies the Settings font-size choice. Screen code chooses a semantic role rather than supplying a size.

[Palette](../Sources/SpaceVibe/Tokens/Palette.swift) owns dark and light colours. Green, amber and red communicate state; category identity and CLI identity remain distinct from state. `sessionWorking`, `sessionWaiting` and `sessionDone` in [Palette](../Sources/SpaceVibe/Tokens/Palette.swift) are state colours too: they belong to Activity's session states as the glance widget draws them, and unmeasurable or idle sessions use `mute`. [ContrastTests](../Tests/SpaceVibeTests/ContrastTests.swift) checks composite surfaces and visible focus; [HuePolicyTests](../Tests/SpaceVibeTests/HuePolicyTests.swift) checks category and state separation.

## Colour tokens

The values [Palette](../Sources/SpaceVibe/Tokens/Palette.swift) holds, in dark and light. `Palette.swift` is the source: a change there changes this table in the same commit. A token marked † departs from the frozen v5 mock, for contrast or for hue separation; the reason and the mock's value are on its line in `Palette.swift`. The ink twins (`cat*Ink`, `cat*CountInk`, `accentInk`, `accentCountInk`, `successInk`, `warnInk`, `dangerInk`, `claudeInk`), the shadows and the product mark's colours are in `Palette.swift` only. What was specified, and the accent and category candidates that were not built, are in the [v5 spec](specs/2026-11-06-reins-design-language-v5.md#token-table).

### Surfaces and lines

| Token | Dark | Light | Job |
| --- | --- | --- | --- |
| `bgSide` | `#0B0C0D` | `#F4F4F5` | Sidebar and window |
| `bgApp` | `#0F1011` | `#F4F4F5` | Search field ground |
| `bgPanel` | `#131416` | `#FFFFFF` | Content panel, the Skills list and pane |
| `bgRaise` | `#191A1D` | `#FBFBFB` | Cards, buttons, meters, chips |
| `bgSunk` | `#0E0F10` | `#F6F6F7` | Verdict box |
| `bgPop` | `#1B1C1F` | `#FFFFFF` | Menu, popover, toast, bottom bar, palette, dialog |
| `bgBand` | `#1B1C20` | `#EEEFF2` | Band header |
| `bgBandHover` † | `#242528` | `#E8E9EC` | Hovered band header |
| `bgBandFocus` | `#28292D` | `#E6E7EA` | Focused band header; hovered and focused together take this one fill |
| `hair` | white 7.5% | black 8% | Hairline border of cards and panels |
| `hair2` | white 12% | black 14% | Control outline, overlay edge, chart base |
| `rowDivider` | white 5.5% | black 6.5% | Divider between rows |
| `hi` | white 5% | white 90% | 1 px top-edge highlight of panels, cards, buttons and overlays |
| `hover` | white 4% | black 3.5% | Hover fill |
| `sel` | white 6.5% | black 5.5% | Current row, current sidebar item, and the focus fill |
| `track` | white 7% | black 6.5% | Meter and bar track |
| `trackHi` | white 12% | black 10% | Stronger track |
| `kbdBg` | white 6% | black 3.5% | Key cap fill |
| `kbdBorder` | white 10% | black 12% | Key cap edge |
| `kbdOnSolidBorder` † | white 28% | white 28% | Key cap edge on a solid button |
| `hiOnSolid` | white 22% | white 22% | Top-edge highlight of a solid button |
| `scrim` | black 50% | `#141418` 25% | Ground behind a dialog |

### Text

| Token | Dark | Light | Job |
| --- | --- | --- | --- |
| `fg` | `#F2F3F4` | `#1B1C1F` | Primary text |
| `fg2` † | `#A3A7AE` | `#595D65` | Secondary text |
| `fg3` † | `#8D929A` | `#646870` | Tertiary text |
| `fg4` | `#4A4E55` | `#B7BAC0` | Disabled and separators; never text a user must read |

### Accent, state and identity

| Token | Dark | Light | Job |
| --- | --- | --- | --- |
| `accent` | `#4F86F7` | `#2563D9` | Indicators and fills: the current row's bar, a picked checkbox, Activity's active tab, the system tint |
| `accentText` † | `#568EFF` | `#2563D9` | The accent as text: links, `Show more`, `Clear`, the toast's `Undo` |
| `accentSolid` † | `#2A5DCB` | `#1E5CD2` | Solid accent fill under white text: primary button, switch, the product mark |
| `accentBg` | `#4F86F7` 16% | `#2563D9` 10% | Picked row and filter count |
| `accentCountText` † | `#69A3FF` | `#205ED4` | Count of picks beside a field in the Filter menu |
| `onAccent` | `#FFFFFF` | `#FFFFFF` | Text on a solid accent fill |
| `ok` † | `#4CB782` | `#2A9B68` | State: fine |
| `warn` † | `#E2A33C` | `#B26F00` | State: needs attention |
| `bad` † | `#E45C6F` | `#D13F58` | State: danger |
| `badSolid` † | `#B8334C` | `#BE2C49` | Solid danger button fill under white text (Stop) |
| `badText` † | `#ED6476` | `#C5334F` | Danger button text while hovered |
| `mute` | `#8A8F98` | `#7A7F88` | Off dot of a CLI status row; unmeasurable and idle sessions |
| `onVerdict` | `#0F1011` | `#FFFFFF` | Cut-out inside a verdict glyph |
| `sessionWorking` | `#E1B236` | `#9C7802` | Session state: running (glance widget) |
| `sessionWaiting` † | `#EB871B` | `#AF6005` | Session state: waiting for the user (glance widget) |
| `sessionDone` | `#6FBE94` | `#27885D` | Session state: idle and written to within the last 10 minutes (glance widget) |
| `claude` | `#D97757` | `#C65F3E` | Claude Code identity (clay) |
| `codex` | `#F2F3F4` | `#1B1C1F` | Codex identity: the text colour |

### Category colours

| Token | Dark | Light | Job |
| --- | --- | --- | --- |
| `catSkill` | `#A78BFA` | `#7C5CE0` | Skills |
| `catSubagent` | `#D974E0` | `#B83CC8` | Subagents |
| `catHook` | `#35C0DA` | `#0E8BA8` | Hooks |
| `catRule` † | `#E471AC` | `#CC4A91` | Rules |

A tab chip's fills are shares of one colour, `fg` for an inactive tab and the category (the accent on Activity) for the active one (`TabChipAlpha` in `Palette.swift`): 7% at rest, 12% hovered, 26% active, 34% active and focused; the count circle is 12% inactive and 40% active. The active tab's text and count use the category's ink twins.

## Layout and interaction

[AppShell](../Sources/SpaceVibe/Shell/AppShell.swift) keeps inactive pages mounted, but hides them from input and accessibility. Settings covers the page, while the command palette and confirmations occupy the window overlay. [TabRegistry](../Sources/SpaceVibe/Shell/TabRegistry.swift) owns sidebar order and Command-number navigation; Limits is a regular tab.

[Metrics](../Sources/SpaceVibe/Tokens/Metrics.swift) owns component dimensions. [SplitCanvas](../Sources/SpaceVibe/Components/SplitCanvas.swift) shares available height between summary cards and the main list and stacks them at narrow widths. [ListPaneLayout](../Sources/SpaceVibe/Components/ListPaneLayout.swift) owns the Skills list and detail pane. These layouts remain distinct.

[LogoToggle](../Sources/SpaceVibe/Components/LogoToggle.swift) still represents per-CLI installation and guarded add/remove actions. [WarningSlot](../Sources/SpaceVibe/Components/WarningSlot.swift) exposes the explanation and related actions through its popover. [FocusFill](../Sources/SpaceVibe/Components/FocusFill.swift) keeps focus visible on selected rows. These are shared contracts, not per-screen styling choices.

[ToastHost](../Sources/SpaceVibe/Shell/ToastHost.swift) owns the toast placement and Undo key. The newest journal write can be undone after its toast disappears; Activity dismissal has its own in-memory Undo. Stop uses [StopSessionPanel](../Sources/SpaceVibe/Activity/ActivityStopConfirmation.swift), identifies the process and consequence, and has no Undo.

Settings composes the same blocks as the other pages ([Tile](../Sources/SpaceVibe/Components/Tile.swift), [ListRow](../Sources/SpaceVibe/Components/ListRow.swift), [ActionButtonStyle](../Sources/SpaceVibe/Components/ActionButtonStyle.swift), [StatusBar](../Sources/SpaceVibe/Components/StatusBar.swift)) plus its own [RailTab](../Sources/SpaceVibe/Components/RailTab.swift), [ThemeTile](../Sources/SpaceVibe/Components/ThemeTile.swift), [SegmentedControl](../Sources/SpaceVibe/Components/SegmentedControl.swift) and [SpaceVibeSwitch](../Sources/SpaceVibe/Components/SpaceVibeSwitch.swift) on the same tokens. Icons come from two sets and one drawn set ([IconPolicyTests](../Tests/SpaceVibeTests/IconPolicyTests.swift)): MingCute Line for the categories, Phosphor for the sidebar, content and Settings (Duotone) and for the glance widget's session states (Bold), plus SpaceVibe's own [verdict glyphs](../Sources/SpaceVibe/Components/VerdictGlyph.swift). This is SpaceVibe's recorded exception to the global one-icon-library rule (FE-K3 of `~/.claude/rules/frontend.md`; [D72](specs/2026-11-06-reins-linear-identity-decisions.md)); moving to one library would be its own code task.

## Gallery and verification

[ComponentGallery](../Sources/SpaceVibe/Gallery/ComponentGallery.swift) renders current containers, controls, glyphs, the Skills pane and Settings specimens. Gallery and screenshot launch modes remain development-only through [LaunchMode](../Sources/SpaceVibe/App/LaunchMode.swift); promoting the UI does not enable those modes in distributed builds.

Use `SPACEVIBE_SHOT_SCREEN=<screen> scripts/dev-fixture.sh --shots <dir>` with `shell`, `skills`, `subagents`, `hooks`, `rules`, `activity`, `limits`, `settings` or `glance`. The [fixture wrapper](../scripts/dev-fixture.sh) supplies synthetic roots, and the [renderer](../Sources/SpaceVibe/Gallery/ShotRenderer.swift) rejects real-screen shots without the test guard. Static checks and headless shots do not establish live keyboard, VoiceOver or owner visual acceptance.
