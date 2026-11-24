# SpaceVibe: Skills and Subagents rework, and the base rules it brings

Date: 2026-11-24
Status: decided, 2026-11-24. The owner approved the mock as a whole ("ok approve tất cả") and the five choices its review left open ("nhận hết"). Nothing is built; the app still draws the round-6 pages of the redesign spec.
Parent: [app-wide redesign spec](2026-11-20-spacevibe-redesign.md) and its [design-system spec](2026-11-21-spacevibe-design-system.md); where this spec differs from either, this spec wins for what it names (see "Decisions this spec replaces"). Plan: tasks are not written yet; the mock's history is in the [redesign build plan](../plans/2026-11-21-spacevibe-redesign-build.md) (Handoff, the Skills-mock entries of 2026-11-22 to 2026-11-24).

- **Reference mock:** `~/scratch/spacevibe-reins/2026-11-22-skills-hierarchy/mock.html` (its own git history; commit `5a166a1`). The rail's `Bản` switch puts the approved design beside the app as built. It draws Skills, Subagents and `Gallery UI base` (`?page=tokens`). Checks: `check-mock-shell.sh`, `node src/clicktest.js` (42 of 42), `node src/sweep.js` (all 2,592 combinations), `python3 src/token-audit.py`.
- **Reviews:** an outside visual review of the mock and the built app (the `agy` CLI, 2026-11-23; reports and images in `~/scratch/spacevibe/2026-11-23-agy-ui-review/`) and a mock-review by a read-only agent that did not draw it (W24, 2026-11-24). Their confirmed defects are fixed in the mock; what they left open is decided below (SK13 to SK17).

## Intent

- **Outcome:** on Skills and Subagents the thing to clean up is the first block on the page, not a count above one long table; and every page gets base rules that stop status text from sitting bare on a surface.
- **User:** the owner, who looked at the built Skills page on 2026-11-22, asked what was wrong with it and reworked it on a mock.
- **Success:** the owner approves the built Skills and Subagents pages by eye, side by side with the reference mock, per surface (W20 "make it like X").

## Decisions and traceability (W20)

| ID | Decision | Owner's words | Req | Acceptance |
| --- | --- | --- | --- | --- |
| SK1 | Status text never sits bare on a surface: a zone name or a state is a Tag, a fact about one item is a chip, the inspector is a stack of filled blocks. | "yes chính xác" (2026-11-22), after "tôi không thích text kiểu đứng riêng lẻ, cảm giác không có thiết kế" | SK-R1, SK-R7 | SK-A1, SK-A2 |
| SK2 | Five base rules for every page: a neutral Tag is outlined, not filled; every pressable control takes the look's radius and static labels stay rectangular (Tag 8, chip 6); a selected row is one background step up (`data-2`); switch and checkbox on-states use ink, blue stays on the primary button and links; the page-opening big figure stays only on Clean and Limits. | "nhận hết" (2026-11-22) | SK-R1 | SK-A2 |
| SK3 | Not wanted: a boxed CLI tile, a metric cluster in the page head, a bare figure or bare text. | "phần box này vẫn xấu"; "tôi không thích cụm head metric ở heading page"; "trông rất tạm thời" (2026-11-22) | SK-R2, SK-R7 | SK-A1 |
| SK4 | The app follows this mock for Skills and Subagents. | "tôi đang muốn đi theo mock này" (2026-11-23) | all | SK-A1 |
| SK5 | In the inspector an off switch is quieter than an on one, and a CLI that cannot be turned off there is a lock with its reason in a chip, not a dimmed switch. | "chốt", then "nhận" (2026-11-23) | SK-R7 | SK-A3 |
| SK6 | The Unused head says in chips which rows are not offered for removal; a read-only row names its owner and a row added in the last day says New. | "chốt", then "nhận" (2026-11-23) | SK-R3 | SK-A3 |
| SK7 | A row keeps one description line when no inspector is docked beside the list. | "chốt", then "nhận" (2026-11-23) | SK-R5 | SK-A4 |
| SK8 | A row's CLI logos stay on one line up to six CLIs and split into two even lines from seven. | "chốt", then "nhận" (2026-11-23) | SK-R5 | SK-A4 |
| SK9 | No SF Mono anywhere: paths, commands, rule text and Hook labels are SF Pro. | "bỏ SF Mono" (2026-11-23) | SK-R1 | SK-A2 |
| SK10 | Two zones, Unused then Used, replace the hero and the one table. | "ok approve tất cả" (2026-11-24) | SK-R2 to SK-R4 | SK-A1 |
| SK11 | The words are `Unused`, `Used` and `Last used`, and the labels `Select N to Remove`, `Remove Selected`, `Installed in`, `Added by`, `Folder`. | "ok approve tất cả" (2026-11-24), after "tôi thấy cứ từ never ran không được dev sử dụng mấy" (2026-11-22) | SK-R8 | SK-A5 |
| SK12 | The Skills icon is a slash in a square and the Subagents icon a tree; category icons are neutral; the inspector's CLI block is one row per CLI with a switch; rows carry no kind icon and, while the inspector is docked, no description; the sidebar toggle sits in the sidebar; sidebar counts carry a severity glyph. Also the mock's own inferred lines of that day: the order inside Unused, no header checkbox on Used, a Show in Finder per path, 12/16 for paths. | "ok approve tất cả" (2026-11-24) | SK-R1, SK-R3 to SK-R7, SK-R9, SK-R10 | SK-A1 |
| SK13 | With rows ticked, a selection bar floats at the top of the list and stays there while the list scrolls. | "nhận hết" (2026-11-24) | SK-R6 | SK-A6 |
| SK14 | After `Select N to Remove` the per-CLI sheet opens with every CLI that holds a ticked item ticked; a selection ticked by hand still opens it with nothing ticked. | "nhận hết" (2026-11-24) | SK-R6 | SK-A6 |
| SK15 | With rows ticked, the inspector draws no `Remove…` of its own. | "nhận hết" (2026-11-24) | SK-R6 | SK-A6 |
| SK16 | Skills and Subagents have no `All / Unused` filter. | "nhận hết" (2026-11-24) | SK-R2 | SK-A1 |
| SK17 | Rows that share a name carry one line saying where each lives. | "nhận hết" (2026-11-24) | SK-R5 | SK-A4 |

## Requirements

- **SK-R1. Base rules (SK1, SK2, SK9), for every page.**
  - **Tag:** 26 high, radius 8, a glyph, the label and, where it counts rows, the count in a cell of its own. Tones: neutral (outlined, no fill), attention, critical, ok. A Tag is not a button.
  - **Chip:** the existing block (20 high, radius 6): one fact about one item.
  - **Shape says pressable:** a pressable control takes the look's control radius; a Tag and a chip keep their own radius in both looks.
  - **Selection:** a selected row is `data-2`, one step above hover.
  - **Blue:** only the primary button and links. Switch and checkbox on-states are `ink` on the group surface.
  - **Page-opening figure:** only Clean and Limits open with the 40 pt figure.
  - **Type:** no monospaced face. The former `mono` role keeps its 12 / 16 size in SF Pro for paths, commands, rule text and Hook labels.
- **SK-R2. Page structure (SK3, SK10, SK16).** No hero and no metric cluster. The page is a stack of zones, each one block with its head inside: Unused, then Used, then Unmeasurable when a row cannot be counted. A zone with no rows is not drawn; with nothing unused the first zone is one quiet Tag `No unused Skills`. The toolbar holds the `All CLIs` menu, the search and the destructive slot; there is no `All / Unused` control. While the usage scan runs every row sits in one zone named by its kind (`Skills N`) with pending counts; the empty and failed states stand without a figure.
- **SK-R3. Unused zone (SK6, SK12).**
  - **Head:** the Tag `Unused N`, amber with the warning glyph only when something in it is suggested for removal (RD70); then one chip per reason a row is not offered: `N new`, `N read-only`, `N Unmeasurable`; then `Select N to Remove` at the trailing edge, where N is the suggested rows shown.
  - **Columns:** the name, `Installed in` with the legend glyph (RD63), `Added`.
  - **Order:** rows that can be removed first, then rows added in the last day, then read-only rows; the oldest first in each.
  - **Rows:** a read-only row has a lock where the checkbox would be and its owner in the Added column (`design-kit plugin`, `Project payments-web`); a row added in the last day reads `New · 2 hours ago`.
- **SK-R4. Used zone (SK12).** The Tag `Used N`; columns name, `Installed in`, `Sessions` with its bar (most first), `Last used`; no checkbox in the column head.
- **SK-R5. Rows (SK7, SK8, SK12, SK17).** A name and data: no kind icon. While the inspector is docked a row has one line; below 1100 pt, where it is not, each row adds one line of its description. Rows that share a name add one line saying where each lives (its folder, project or plugin), unless the Added column already names the owner. A logo is still the toggle of RD14 and draws only on or off: the Never ran dot, the lock and the link mark are not drawn on it. Up to six CLIs sit on one line; from seven they split into two even lines (7 is 4 and 3, 10 is 5 and 5).
- **SK-R6. Selection and removal (SK13 to SK15).**
  - **Bar:** with rows ticked, a bar with the Tag `Selected N`, `Add to…` and `Clear Selection` sits over the first zone head's action side and stays under the toolbar while the list scrolls.
  - **Toolbar:** `Remove N Selected…` is the one bulk removal; with rows ticked the inspector shows no `Remove…`.
  - **Sheet:** opened after `Select N to Remove` with no tick changed by hand, it starts with every CLI that holds a ticked item ticked; from any other selection it starts with nothing ticked (RD-R11). It names each folder and who else reads it either way.
- **SK-R7. Inspector (SK1, SK3, SK5, SK12).** Three blocks on `data-1`, radius 10.
  - **Answer:** for an unused item the Tag `Unused`, a chip with when it was added, and `Remove…` in the destructive tint when it is suggested; for a used one the session count as a figure with its unit, a chip with when it was last used, and the 24-day strip.
  - **Installed in:** one row per CLI: logo, name, the sessions bar with its count or a word, and a switch. A CLI that cannot be turned off here (the only copy, read through another CLI's folder, read-only) shows a lock, and a chip with the reason (`Only copy`, `via Claude Code`, `via 2 CLIs`, `Read-only`) where no count is drawn; with a count the reason is the lock's tooltip. In dark an off switch's knob is `ink3`.
  - **Facts:** who added it, each folder with its own Show in Finder and who reads it when more than one CLI does, and when it was added.
  - A used item's `Remove…` sits under the blocks, neutral.
- **SK-R8. Words (SK11).** `Unused`, `Used`, `Last used`; `Select N to Remove`; `Remove Selected` and `Remove N Selected…`; `Installed in`; `Added by`; `Folder`. The glossary's `Never ran` becomes `Unused` on every surface in the same build (Inbox, Clean, Hooks, the site), so one word keeps one meaning.
- **SK-R9. Icons (SK12).** Skills: a slash in a square. Subagents: a tree. Both are drawn in SpaceVibe's own Bold set (RD23). Category icons are neutral on the sidebar, in rows and in the inspector title.
- **SK-R10. Sidebar (SK12).** The sidebar toggle sits inside the sidebar. A page's count carries a severity glyph under the rule of its page's first Tag: on Skills and Subagents, amber only when something is suggested for removal.

## Acceptance

- **SK-A1.** Side by side with the reference mock, Skills and Subagents match in structure, content and look, in dark and light, Glass and Solid, at 1000, 1280 and 1600, for the states the mock draws: open, a used and an unused row selected, rows ticked, nothing unused, empty, scanning, a CLI folder unreadable, worst-case data at 6 and 10 CLIs.
- **SK-A2.** No screen draws a monospaced face; a neutral Tag has no fill; a switch or checkbox that is on is not blue; no page but Clean and Limits opens with the 40 pt figure. `StyleBoundaryTests` stays green, and the gallery in the app shows Tag, the inspector block, the zone and the selection bar (DS-R12).
- **SK-A3.** With a fixture where an item is the only copy, one is read through another CLI's folder and one is plugin-owned: each shows the lock and its reason, none shows a dimmed switch; the Unused head's chips add up to its count less the button's.
- **SK-A4.** At 1000 pt every row shows its description line and none does at 1280 with the inspector docked, except rows that share a name; at 6 CLIs every row is one line of logos, at 10 two lines of five.
- **SK-A5.** No label on any page, and no line of the site, reads `Never ran`; `GLOSSARY.md` defines `Unused`.
- **SK-A6.** With a row ticked in Used under an Unused zone longer than the window, the selection bar is on screen; `Select N to Remove` then the toolbar's button opens the sheet with its CLIs ticked, and one Remove removes them with one Undo (RD56); a row ticked by hand opens the sheet with nothing ticked; with rows ticked the inspector shows no `Remove…`.
- **SK-A7.** `build-review` passes before the owner is asked to look (W24): the pre-ticked sheet removes files.

## Decisions this spec replaces

The owner's "ok approve tất cả" (2026-11-24) covered the mock, whose notes name each of these; the earlier decision stands everywhere this spec does not reach.

| Decision | What it said | Replaced by | Reach |
| --- | --- | --- | --- |
| D63, GLOSSARY `Never ran` | The state word is Never ran | `Unused` (SK11) | every surface |
| RD12 | A category tone on sidebar, row and inspector title icons | Neutral icons (SK12) | every page |
| RD15, RD-R12, RD-A6, the tile of RD60 | A grid of heat tiles in the inspector | One row per CLI with a switch (SK12) | Skills, Subagents |
| RD-R2 (Skills, Subagents) | The page opens with `N never ran` | A zone with a Tag (SK2, SK10) | Skills, Subagents; the other list pages when they are redrawn |
| RD-R9 | Switch and checkbox on-states use the primary | Ink (SK2) | every page |
| RD-R11 | Logos wrap at 5 per line; the Never ran dot, lock and link on the logo; `Remove from…` among the selection actions; the sheet always opens with nothing ticked | SK8, SK-R5, SK-R6, SK14 | Skills, Subagents |
| RD22 | One table by Sessions, with `All / Never ran` | Zones; Unused by kind then age, Used by Sessions; no filter (SK10, SK16) | Skills, Subagents |
| RD41 | The head's label `Select N Suggested` | `Select N to Remove` (SK11) | every page that has it |
| RD63 | The legend lists the via link glyph | It lists none: the inspector says via in a chip | Skills, Subagents |
| DS-R2 | SF Mono for paths, commands, rule text and Hook labels | SF Pro (SK9) | every page |
| DS-R10 | The block inventory | Adds Tag, the inspector block, the zone and the selection bar | every page |

RD14 (a logo is a toggle), RD31, RD44, RD56, RD57, RD58 (where a page has a hero), RD70 and D53 stand.

## Inferred, not decided

Each line comes from the mock or from an agent's choice; none has an owner decision of its own.

- **The Unmeasurable zone** for rows that cannot be counted, with `Unmeasurable` in the Sessions cell. Source: the mock-review fix; an unknown is never a zero.
- **One zone while scanning,** which becomes two when the counts arrive: the page changes shape once (RD-R13 asks that it never does). Source: the mock-review fix.
- **The selection bar's surface** (group ground, hairline, the float shadow, the look's radius) and that it covers the trailing end of the row under the toolbar while the list is scrolled. Source: agent's choice.
- **The pre-ticked sheet** applies only while the ticks are exactly those of `Select N to Remove`. Source: agent's choice within SK14.
- **In the inspector the Unused Tag is paired with the Added chip.** Added is when SpaceVibe first saw the item, not how long it went unused. Source: the mock.
- **Other list pages** (Inbox, Hooks, Rules, Activity) take a zone with a Tag in place of their hero when they are redrawn. Source: SK2 as the mock reads it; not drawn.
- **Inbox's item inspector** draws the same CLI block as Skills today, so it takes the rows with a switch too. Source: one shared block; not drawn.
- **Two icons** (the slash and the tree) are Phosphor or hand-drawn stand-ins in the mock and are redrawn in the own set. Source: RD23.

## Not verified against the engine

- How many days of `days` the core keeps per cell: the inspector draws 24.
- Whether the scanned logs reach back as far as an item's Added date; if not, "Unused" is only as old as the oldest log.
- `Last used` reads the engine's UTC day, so "today" can be a day off near midnight.
- Whether `loadout.rows` can return two rows with one name (a user copy beside a project or plugin copy); SK17 only matters if it can.

## Out of scope

- Redrawing Inbox, Hooks, Rules, Activity, Clean, Limits and Settings under the base rules: the rules are decided for every page (SK2), but no mock draws those pages yet, and each needs one before it is built.
- The toolbar across the window and the top-aligned hero (RD57, RD58): decided in the redesign spec, drawn in neither mock, already built.
- The fixes on branch `fix/redesign-eye-readiness` (its plan, `docs/plans/2026-11-23-redesign-eye-readiness.md`, is on that branch until it merges): they are on the round-6 pages. Two of them, `Clear Selection` in the `N selected` head and the empty-filter sentence on Skills, are redrawn by this spec.
