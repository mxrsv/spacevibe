# SpaceVibe: design system for the redesign

Date: 2026-11-21
Status: decided, 2026-11-21. The owner approved the specimen and the round-6 mock ("ok cần prompt để build"); nothing in `Sources/` yet.
Parent: [app-wide redesign spec](2026-11-20-spacevibe-redesign.md) (RD2, RD-R3 to RD-R9, RD-R16). Plan: [redesign build plan](../plans/2026-11-21-spacevibe-redesign-build.md), tasks RB-S1 and RB-S4.

- **Specimen (the preview):** the mock's `Tokens + base` page, `~/scratch/spacevibe-reins/2026-11-20-redesign-v2/mock.html?page=tokens` (rail: theme, look, Increase Contrast). Every token and every shared block is drawn there, read live from the same CSS variables the screens use.
- **Before / after:** the mock's pill switches between round 5 (`mock-r5.html`, the eye-approved screens before this pass) and round 6 (`mock.html`, the same screens on this token set).
- **Measured adherence:** `python3 src/token-audit.py` in the mock folder counts hand-typed spacing, radius, font-size and opacity values outside the token blocks. Round 5: 214 spacing, 48 radius, 5 font-size, 23 opacity in the CSS, plus 70 spacing, 5 radius and 3 font-size in the page files. Round 6: 0 in each.
- **Audit this answers:** the read-only `/design-system` audit of round 5 (2026-11-21): 20 findings, scores 4 to 8 out of 10.

## Intent

Before the redesign is built, one design system exists: every value a screen may use is a named token, every shared block has one size and one set of states, and the build ports that system instead of copying values out of screens. The mock follows the system exactly, so a side-by-side check against it compares like with like.

## Decisions

| ID | Decision | Owner's words | Req |
| --- | --- | --- | --- |
| DS1 | The redesign gets a design system before any screen is built. | "chuẩn bị build phần giao diện mới này thì phải có design-system ấy" (2026-11-21) | DS-R1 to DS-R12 |
| DS2 | Three gaps found when the tokens were ported (RB-S1) close as recommended: the inspector is 336 wide on Skills, Subagents and Inbox and 308 on every other page, as the mock draws it; the 12 pt `quiet` role takes weight 500 on small buttons, sidebar group heads and inspector section heads, as the mock draws it; a pair whose value misses the ratio this spec promises gets the smallest value change that meets it, hue kept, and icons and other non-text marks are measured at 3:1 (WCAG 1.4.11), text at 4.5:1. | "Nhận hết" (2026-11-21, on the three recommendations) | DS-R1, DS-R2, DS-R3 |

Carried, not re-decided here: RD6 (SF Pro Rounded for figures only, "chỉ sử dụng font rounded cho số liệu"), RD9 (Graphite surfaces, no hue cast), RD10 (severity once per group), RD23 (600 for sidebar labels only, SpaceVibe's own page icons), RD29 and D57 (focus is a 3 pt bar, never a ring), RD37 and RD38 (Phosphor Bold content glyphs, Fill state glyphs), D12 (no gradients), RD-R3 to RD-R9 and RD-R16 of the redesign spec.

## Requirements

### Foundations

- **DS-R1. Colour roles.** Screens use only these names; values per theme. Increase Contrast overrides the marked rows so tracks, hairlines, control fills and data steps reach 3:1 on the group surface.

  | Role | Dark | Light | Job |
  | --- | --- | --- | --- |
  | `canvas` | `#111214` | `#F4F4F5` | window |
  | `group` | `#191A1D` | `#FFFFFF` | cards, inspector, menus in Solid |
  | `side` | `#141518` | `#E9E9EB` | Solid sidebar |
  | `ink` / `ink2` / `ink3` | `#F5F6F8` / `#D6D9DF` / `#A9AEB8` | `#14171D` / `#434955` / `#5C6270` (DS2; was `#616775`) | text, secondary, quiet (IC: `ink3` `#BCC1CA` / `#4E5462`) |
  | `faint` | `#3A404C` | `#C9CFDA` | empty track (IC: `#6B717D` / `#8A909C`) |
  | `ok` / `warn` / `crit` | `#4CC38A` / `#E8B33A` / `#EF6B5E` | `#17784C` / `#8A6200` / `#C42F1D` | state text and glyphs |
  | `warn-bar` / `crit-bar` | `#E8B33A` / `#EF6B5E` | `#A37100` (DS2; was `#B07E00`) / `#D9402F` | state fills, 3:1 |
  | `crit-ink` | `#FF8A7D` | `#9E1D0F` | text on the destructive tint |
  | `primary`, `-h`, `-p`, `on-primary` | `#0B6FE4`, `#0A66D2` (+8% black, DS2: +14% white gave white text 3.80:1), +16% black, white | same | the one primary action, checkbox and switch on, link |
  | `link` | `#5AA2FF` | `#0A64D0` | links |
  | `clay`, `logo-codex` | `#E08463`, `#E9E9ED` | `#AD4A28`, `#2A2B30` | the two CLI logos only |
  | `c-skills` / `c-subs` / `c-hooks` / `c-rules` | `#A38BF5` / `#7BDEE0` / `#CF84E0` / `#9AA3B5` | `#6A4FD8` / `#178082` / `#9A3FB0` / `#586273` | one identity tone per category, icons only |
  | `s-work` / `s-wait` / `s-done` | `#E1B236` / `#EB871B` / `#6FBE94` | `#9C7802` / `#AF6005` / `#27885D` | session glyph inks (`SessionStateGlyph`, unchanged) |
  | `data-1` to `data-4`, `data-bar` | `ink` at 8 / 16 / 28 / 38 / 55 % over `group` | 8 / 16 / 28 / 44 / 55 % | data, never a state (IC: `#6B717D` `#858B96` `#A3A8B1` `#C4C8CE` `#E3E5E8` / `#8A909C` `#6E7480` `#545A66` `#3B404B` `#22262E`) |
  | `hair`, `alt`, `hover`, `sel` | white at 8 / 3 / 6 / 9 % | black at 9 / 2 / 5 / 7 % | lines, zebra, hover, selection (IC `hair` = IC `faint`) |
  | `ctl`, `ctl-h`, `ctl-a` | white at 9 / 15 / 20 % | black at 5 / 9 / 13 % | control fills (IC, DS2: white 33 / 38 / 36 % and black 42 / 45 / 48 % for rest / hover / pressed, so each reaches 3:1 on `group` and `ink` keeps 4.5:1 on it, plus a `hair` outline; labels on IC fills use `ink`) |
  | `scrim` | black 50 % | black 30 % | behind sheets and alerts |

  DS2 also sets two derived rules: primary hover is one step darker, not lighter (a lighter step that keeps white text at 4.5:1 does not read as hover), which narrows RD-R9; under Increase Contrast, text on a tile heat step is `ink` on step 1 and the `group` colour on steps 2 to 4, so it reaches 4.5:1 on every step.

- **DS-R2. Type roles.** SF Pro for text; SF Pro Rounded only on figures (hero, figure, counts in tables and tiles, sizes, sidebar values); SF Mono only for paths, commands, rule text and Hook labels. Weights 400 and 500; 600 only for sidebar labels. Letter-spacing and line-height are never changed per screen.

  | Role | Size / line | Weight | Use |
  | --- | --- | --- | --- |
  | `hero` | 40 / 44 | 500, Rounded | the page's one answer |
  | `figure` | 22 / 26 | 500, Rounded | a Window's share left |
  | `title` | 15 / 20 | 500 | page title, empty-state title |
  | `body` | 13 / 18 | 400, 500 | rows, buttons, names |
  | `quiet` | 12 / 16 | 400 | sub-lines, notes, sidebar values |
  | `hero unit` | 15 / 20 | 400 | the unit beside the hero figure (RB-S4 integration, from the mock's `.hero .fg small`) |
  | `quiet` medium | 12 / 16 | 500 | small-button labels, sidebar group heads, inspector section heads, run and session counts in table cells (DS2) |
  | `caption` | 11 / 14 | 400 | chart axes, legends, tile captions only |
  | `mono` | 12 / 16 | 400, SF Mono | paths, commands, rule text, Hook labels |

- **DS-R3. Space.** Steps 2, 4, 6, 8, 10, 12, 16, 20, 24. Layout metrics, named: content clears the toolbar by 68 (Glass) or 64 (Solid) and the title bar by 36; an empty state starts 72 down; the inspector is 336 wide on Skills, Subagents and Inbox and 308 on every other page (DS2). Frame metrics, read from the mock's `style.css` when the frame was built (RB-S3, `FrameRole`): sidebar 240 (Glass) / 224 (Solid) wide, items 32 / 30 high with corner 10 / 6; toolbar 60 / 52 high, its primary slot 196 wide; traffic-light clearance 52; help popover 300 wide; Settings window 660 wide with a body at least 380 high and pane tabs at least 74 wide. Nothing else in a screen is a number.
- **DS-R4. Radius.** Steps 4, 6, 8, 10, 14, 18 and capsule. By look: window 26 / 12, sidebar 18 / 0 (with an 8 inset in Glass), group 14 / 10, controls capsule / 6, popovers 14 / 10. Meters, ticks and dots are capsules.
- **DS-R5. Sizes.** Controls 32 regular, 26 small, 20 mini; a checkbox, toggle or logo toggle sits in a 28 hit cell; no hit target under 24. Rows 48 in tables (60 when a row's logo toggles wrap to a second line, from 7 CLIs), 44 in lists. Segmented controls come in two sizes only: regular 32 (inner 28) and small 26 (inner 22). Meters: 4 in rows, 6 for the hero and Limits, 3 for progress; the pace tick is 2.
- **DS-R6. Icons.** Sizes 12, 14, 16, 20, 40; CLI logos 16 and 20. Content glyphs Phosphor Bold, state glyphs Phosphor Fill, page icons SpaceVibe's own set (RD23, RD37). Icons are never boxed.
- **DS-R7. Opacity.** Disabled .42, dim .55 (an off logo), ghost .35 (Not supported). No other opacity in a screen.
- **DS-R8. Depth and material.** Glass is the system material (`glassEffect`) on the sidebar, toolbar controls and the overlay layer (toast, menu, popover) on macOS 26; Solid on macOS 15 and with Reduce Transparency. The sidebar's Glass carries `sidebarSurface` at 0.6 (`ColorRoleValues.sidebarGlassTintShare`, picked by the owner's eye 2026-11-23 from 0, 0.35, 0.6, 0.85), because plain Glass over a coloured desktop left its labels unreadable. Menus, alerts, popovers and the window take the system's own shadow; in-content popovers in Solid use one `float` shadow. The mock's white sheens and edge fades only imitate the material and are not ported (D12).
- **DS-R9. Motion.** The switch knob, a 1 pt tile lift on hover and a press scale; no loops, no shimmer, no scroll-bound effects. Reduce Motion removes the lift and the scale.

### Blocks

- **DS-R10. Block inventory.** Each block has one size per variant and draws normal, hover, pressed, disabled and, where async, loading. The specimen shows each one in dark and light.

  | Block | Variants and sizes | States drawn | App component (RB-S4) |
  | --- | --- | --- | --- |
  | Primary button | regular 32 | normal, hover, pressed, disabled | adapt `ActionButtonStyle` |
  | Control button, icon button | regular 32 | normal, hover, disabled | adapt `ActionButtonStyle` |
  | Small button | 26; quiet (link-like) variant | normal, hover, disabled, loading | adapt `ActionButtonStyle` |
  | Destructive button | regular 32 and small 26, red tint only | normal, disabled | adapt `ActionButtonStyle` |
  | Segmented control | regular 32, small 26 | selected, hover, focus bar | adapt `SegmentedControl` |
  | Checkbox | 28 hit cell | on, off, disabled, mixed | new |
  | Switch | system size | on, off, disabled | adapt `SpaceVibeSwitch` |
  | Search field | regular 32 | normal, focused (bar) | new |
  | Chip | mini 20; mono variant | normal | new (`FilterChip` is retired) |
  | Row | table 48, list 44 | plain, hover, selected, focus bar, disabled | adapt `ListRow` |
  | Group head | severity glyph once, count, one small action | r, w, none | adapt `Band` |
  | Hero | hero figure plus quiet label | normal, zero | adapt `StatFigures` |
  | Meter | 4, 6, 3; fill plus pace tick | ok, attention, critical, Unmeasurable | adapt `Cells` |
  | CLI logo toggle and tile | 28 cell; tile grid | on, Never ran, off, via, last copy, Not supported, Unmeasurable | adapt `LogoToggle`, `Tile` |
  | Toast | wraps; Undo in reach | done, refused (what did not change first) | adapt `Toast` |
  | Menu, popover, sheet, alert | system surfaces | open; Esc and outside click close | adapt `PopoverSurface`, `ConfirmationDialog`; Stop uses a system alert with a destructive role |
  | Empty, scanning, error | one layout each | as drawn | adapt `EmptyState` |
  | Inspector | trailing 308 / 336; an overlay below 1100 pt that covers the list and repeats the selected row's actions at its top | open, closed, overlay | adapt `DetailPane` |

- **DS-R11. Usage rules.** One primary action per surface. Destructive actions use the red tint, never a solid red fill. Colour goes on state, data and the category tone, never on a control or a surface (FE4). The selected part of a bar is data (`data-bar`), not `primary`. A card uses at most two text styles besides its figure (FE3). Overlay surfaces are graphite; no blue cast.
- **DS-R12. One source in the build.** RB-S1 ports DS-R1 to DS-R9 into `Sources/SpaceVibe/Tokens` by role name (never by nearest value: the category tones swap against today's Palette), with Increase Contrast values; `StyleBoundaryTests` also fails on `.opacity(`, `.tracking(`, `.kerning(` and frame sizes with a literal in a screen folder. The gallery shows the same specimen as the mock's page.

## Acceptance

| Check | Requirement |
| --- | --- |
| The owner approves the specimen page by eye, dark and light, Glass and Solid, with and without Increase Contrast | DS1 |
| `python3 src/token-audit.py` reports 0 hand-typed spacing, radius, font-size and opacity values in the mock | DS-R3 to DS-R7 |
| Rounded digits appear only in figure roles; SF Mono renders on paths and commands (computed-style check in Chrome) | DS-R2 |
| Every IC data step and `faint` reaches 3:1 on `group` (measured: dark 3.55 to 13.79, light 3.21 to 15.17) | DS-R1 |
| At 1000 pt with the inspector open, every row keeps its name and the selected row's actions sit in the overlay | DS-R10 |
| RB-S1: the gallery specimen beside the mock's page, per theme and look; `StyleBoundaryTests` green with the added checks | DS-R12 |

## Inferred, not decided

Values the agent chose from the round-5 audit, shown on the specimen the owner approved on 2026-11-21:

- **Spacing step 10:** kept as a step (control inset, 22 uses) rather than a one-off metric. Source: audit, agent's choice.
- **Increase Contrast values** in DS-R1. Source: agent's choice, measured.
- **Limits card names in body 500** instead of title 15 for the CLI name, so the card has two text styles besides its figures. Source: FE3, agent's choice.
- **Sidebar values at 400.** Source: audit (RD23 keeps 600 for labels), agent's choice.
- **The light Off switch knob is white.** Source: audit, agent's choice.
- **The overlay inspector repeats the selected row's actions.** Source: audit, agent's choice.
- **One float shadow; the rest are the system's.** Source: audit, agent's choice.
- **The Stop alert uses the destructive tint in the mock and a system alert with a destructive role in the build.** Source: RD-R9, agent's choice.

## Out of scope

- Restyling `site/`.
- Changing any owner-decided value of the redesign spec (scale, primary, tones); this spec only names and completes them.
