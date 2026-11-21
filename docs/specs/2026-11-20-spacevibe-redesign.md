# SpaceVibe: app-wide redesign (macOS frame, v2)

Date: 2026-11-20
Status: draft, 2026-11-21. The direction is set by the mock below. The owner said "giao diện đã tốt hơn rất nhiều nhưng không vì thế mà tôi approve ngay được" (2026-11-20), so the mock is not eye-approved yet. On 2026-11-21 four independent mock reviews ran, the owner accepted every recommendation (RD21–RD28) and the mock was rebuilt as round 4; three Opus reviews (accessibility, click paths, break-ui) followed, the owner asked for every fix with a before/after switch (RD29–RD31), and the mock is now round 5. The owner approved round 5 by eye on 2026-11-21 ("ok chốt"), with fixes made the same day: the window is one solid surface and only the floating sidebar's own rounded shape shows the desktop through its glass, so there is no blurred band or stepped corner around the sidebar. The [build plan](../plans/2026-11-21-spacevibe-redesign-build.md) gates code on the mock's readiness (G-0); no code yet.
Parent: [PRODUCT.md](../../PRODUCT.md) (all four jobs). Plan: [build plan](../plans/2026-11-21-spacevibe-redesign-build.md).

- **Reference mock (round 5, 2026-11-21):** `~/scratch/spacevibe-reins/2026-11-20-redesign-v2/mock.html`; round 4 is kept as `mock-r4.html` (built from `src-r4/`), and the "Trước fix / Sau fix" switch at the top left moves between them with the same state. The rail's `Dữ liệu` axis loads the break-ui datasets (Mẫu, Cực đoan, Một mục, Rất nhiều). It is built from `src/` in the same folder (`cd src && python3 build.py`). Its consistency check is `node src/consistency.js`.
- **Design record:** `design-notes.md` in the same folder, sections 1–25 (§25 is round 4). It holds the thesis per page, the token tables with measured contrast, and the needs-new-data list.
- **Many-CLI research:** `research-many-clis.md` in the same folder.
- **Absorbs:** the Clean draft [2026-11-18-clean.md](2026-11-18-clean.md). Its decisions CL1–CL4 and its requirements CL-R1–CL-R8 stay in force and are not copied here.
- **Rules applied:** the owner's UI rulebook (skill `kyant-ui-rules`, FE-*), and the Apple HIG distilled corpus (github.com/justinwetch/HIGAgentSkills, snapshot 2026-09-12).

## Intent

- **Outcome:** a new look and structure for the whole app, so that what needs fixing is seen first on every page. It is built on one token set and one base block set, with Clean as one feature group inside it.
- **User:** the owner, a daily user of Claude Code and Codex. More CLIs are expected later.
- **Why:** the owner rejected the previous mocks as hard to read and boring, and rejected the small-step tweaks made to them ("bản design mock cũ tôi không ưng ý chút nào").
- **Success:** the owner approves the built app by eye against the reference mock, page by page (W20 "make it like X", FE-P7).

## Decisions and traceability (W20)

Owner words are quoted; dates are 2026-11-18 to 2026-11-20.

| ID | Decision | Owner's words | Req | Acceptance | Where in the mock |
| --- | --- | --- | --- | --- | --- |
| RD1 | Redesign the whole app, not one page. | "toàn bộ cả app" | RD-R1 | RD-A1 | every page on the rail axis `Trang` |
| RD2 | Every page has a planned first and second glance. There is one token set and one base block set. | "phải có tính toán khi user vào app nhìn vào đâu đầu tiên rồi vào page thì nhìn UI nào đầu tiên ? rồi phải có design tokens và ui design base" | RD-R2, RD-R3 | RD-A2, RD-A3 | the hero of every page; RD-R2 table |
| RD3 | What needs fixing now is the first thing seen. | "đúng, việc cần xử lý ngay phải nhìn thấy đầu tiên" | RD-R4 | RD-A2 | preset "Đề xuất · Inbox" |
| RD4 | Native macOS frame: glass sidebar, toolbar, native lists and tables, trailing inspector, separate Settings window. | "đã thay đổi layout design hoàn toàn, ý tôi là muốn như này, chứ không phải đi chỉnh sửa nhỏ từng tí một" | RD-R1 | RD-A1 | every page; page `Settings window` |
| RD5 | The design is rebuilt from scratch with the TinySift process: thesis, signature, measured token plan, self-critique. | "ok dựng thử đi" (on that proposal) | RD-R2 | RD-A3 | process only (design-notes §1–§5) |
| RD6 | Text is SF Pro. Only figures use SF Pro Rounded. | "chỉ sử dụng font rounded cho số liệu" | RD-R5 | RD-A4 | page `Tokens + base`, Type; every figure |
| RD7 | Meters and progress bars are thin. | "các progress nên cho nhỏ height lại" | RD-R6 | RD-A4 | page Limits; `Tokens + base` meters |
| RD8 | State tones: attention is a yellow-leaning amber; ok and critical are kept. | "thử update đi" (on the proposal) | RD-R7 | RD-A5 | `Tokens + base` colour roles; Limits Codex 5-hour |
| RD9 | The background is Graphite, neutral with no hue cast. | "chốt graphite" | RD-R7 | RD-A5 | every page; `Tokens + base` |
| RD10 | Colour discipline: severity is shown once per group; big figures are ink; content sits on a solid background; glass is only on the sidebar and toolbar; sidebar counts are neutral. | owner-pasted diagnosis, applied in mock round 3 | RD-R8 | RD-A5 | Inbox group heads |
| RD11 | The primary is the TinySift button blue `#0B6FE4` with white text, a flat fill with no shadow. | "dùng màu primary giống màu button bên mock này"; "bạn thêm shadow vào làm gì ?" | RD-R9 | RD-A5 | Rules `Add Rule…`; `Tokens + base` Primary |
| RD12 | Data is drawn in neutral greys. Category tones appear on icons only. | "ok" (on that proposal) | RD-R8 | RD-A5 | Skills Sessions bars, inspector tiles; `Tokens + base` Data colour |
| RD13 | The design must hold for many CLIs, not only two. | "nếu sau này có 10 agents thì sao ?" | RD-R10 | RD-A6 | axis `Số CLI` 2 / 3 / 6 / 10; preset "Skills · 10 CLI · xấu nhất" |
| RD14 | Each Skill and Subagent row shows its CLIs as logo toggles. A click adds the item to that CLI or removes it. | "logo các agent hiển thị lên có thể click toggle"; "ổn" | RD-R11 | RD-A6 | Skills rows; presets "Skills · 6 CLI", "Undo sau khi bật/tắt" |
| RD15 | The inspector shows a grid of CLI tiles. Fill darkness shows how much each CLI uses the item. Each tile is a toggle with a success check when enabled. The grid has at most 3 rows, with small tiles. | "dạng lưới logo … bọc 1 box … có màu đậm nhạt để tương trưng cho agent đó dùng skill ít hay nhiều"; "thêm icon success vào nếu đang enabled, chỉ cho max là 3 hàng, cho chúng size nhỏ lại" | RD-R12 | RD-A6 | Skills inspector `CLIs` tiles |
| RD16 | The "Never ran" amber dot is shown only on the CLI that owns the file. | "ổn" (on that recommendation) | RD-R11 | RD-A6 | Skills row of screenshot-diff (Codex dot) |
| RD17 | Options the owner did not pick are removed from the mock. | "clean những cái option không đc chọn đi đã" | n/a | n/a | the rail holds picked options only |
| RD18 | Clean covers anything AI CLIs leave behind and is one feature group of the app. | "dọn bất kỳ cái gì liên quan đến agent, ai"; "Clean chỉ là một nhóm tính năng nhỏ trong đó" | CL-R1–CL-R8 | Clean spec | page Clean; presets "Clean · …" |

Decisions of 2026-11-21. Each was a recommendation after the four-agent mock review; the owner's answer to all of them was "nhận hết fix mock đi".

| ID | Decision | Owner's words | Req | Acceptance | Where in the mock |
| --- | --- | --- | --- | --- | --- |
| RD21 | Earlier decisions D53, D57, D69 and D70 stay: the last lit CLI logo is not a toggle (D53); no ring on any input or button, focus is a fill change (D57); Limits has no Refresh and no Gemini card (D69); Activity has no Files tab and Settings keeps the theme switch (D70). | "nhận hết fix mock đi" | RD-R9, RD-R11, RD-R14 | RD-A8 | Settings › General theme; Activity tabs; Limits toolbar; Skills · 2 CLI, review-pr Claude logo |
| RD22 | The redesign supersedes D60 (pace tick on Window bars), D20 (category tone on the sidebar and row icons, RD12), D7 (SF Pro instead of Inter, RD6) and D27, D33–D37 (Filter menu, chips, Group by and Order by give way to `All / Never ran`, the `All CLIs` menu and a Sessions sort, most first, as D33's default). D21 and D31 (badge on a lit logo) give way to RD-R11: a lit logo is the full logo, the tile carries the check. | "nhận hết fix mock đi" | RD-R2, RD-R6, RD-R11 | RD-A1 | Limits pace tick; sidebar icons; Skills toolbar `All / Never ran` + `All CLIs` |
| RD23 | SpaceVibe's own Bold icon set for the 8 page and category icons, sidebar icons at 20 pt, sidebar labels at weight 600 in every state, selection told apart by fill and ink only. Supersedes D72 and D32 for those icons. Picked 2026-11-20 ("chốt", "ok ổn", "ok chốt"), recorded here on 2026-11-21. | "chốt"; "ok chốt"; "nhận hết fix mock đi" | RD-R5 | RD-A4 | sidebar |
| RD24 | Status-line capture stays under S-R4: the app copies the install and remove commands, the owner runs them. | "nhận hết fix mock đi" | RD-R15 | RD-A8 | Limits state `Rỗng` (Copy Install Command); Settings › Limits |
| RD25 | Settings has no "Empty" for SpaceVibe's trash: emptying it would end every pending Undo. | "nhận hết fix mock đi" | RD-R15 | RD-A8 | Settings › Data |
| RD26 | Inbox can reach zero: each finding has Keep; a Hook counts as failing only for errors in the last 7 days; an item added in the last day is not a finding; a Rule that allows a whole tool is a Control finding. | "nhận hết fix mock đi" | RD-R4 | RD-A9 | Inbox: Keep, Show Kept, Control `Bash`; preset "Inbox · không còn gì (Clear)" |
| RD27 | Clean locks a CLI's logs and caches only while that CLI has a running session (running or waiting), as CL2 says. | "nhận hết fix mock đi" | CL-R5 | Clean spec | preset "Clean · Claude có session đang chạy" |
| RD28 | Two CLIs use the same layout as many: installing a third CLI changes no page's shape. | "nhận hết fix mock đi" | RD-R10 | RD-A6 | axis `Số CLI` 2 against 3: same layout |

Decisions of 2026-11-21, after the three Opus reviews. Each was the recommendation offered; the owner's answer was "tôi muốn fix đủ nhưng cần button before after để xem sau khi fix như nào".

| ID | Decision | Owner's words | Req | Acceptance | Where in the mock |
| --- | --- | --- | --- | --- | --- |
| RD29 | Keyboard focus is a 3 pt ink bar inside the focused row, field or control: not a ring, so D57 stands, and it reaches 3:1 and differs from hover and selection. | "tôi muốn fix đủ" | RD-R9, RD-R16 | RD-A10 | arrow keys on any list; `Tokens + base` "Keyboard focus" |
| RD30 | A Window always counts as needing you at 5% left or less; pace ("faster than time") is judged only once a tenth of the Window has passed. | "tôi muốn fix đủ" | RD-R4 | RD-A9 | preset "Cực đoan · Limits" |
| RD31 | A CLI that reads an item only through another CLI's folder (Cursor reading `~/.claude/skills`) shows it as "via" that CLI and is not a toggle; removing it is `Remove…`. | "tôi muốn fix đủ" | RD-R11 | RD-A6 | preset "Skills · 6 CLI" (link badge on Cursor, opencode, Amp) |

Earlier owner answers are also carried here. They come from the paused layout-frame grilling of 2026-11-18, recorded in the auto-memory, not in this chat:

| ID | Decision | Owner's words | Req | Where in the mock |
| --- | --- | --- | --- | --- |
| RD19 | Skills, Subagents, Hooks and Rules are separate sidebar pages. | taken as guessed (Q1) | RD-R1 | sidebar group Agents |
| RD32 | Each page has a click-only `?` beside its title, actions keep full-verb labels, empty states say plainly what is missing; no fixed explainer line. | "b và c" (Q2) | RD-R2 | Toolbar `?` on every page; empty states |
| RD33 | The limit reset countdown carries over unchanged ([countdown spec](2026-11-19-limit-reset-countdown.md), LC1–LC10): a 5-hour Window counts its last hour, a Weekly one counts inside the lead set in Settings › Limits (24 / 12 / 5 / 1 h, default 1 h), the clock in the row's tone. | "thêm vào đếm ngược trong widget và cả app main" (LC1) | RD-R10 | Limits Claude Code 5-hour row; Settings › Limits |
| RD34 | The session glance widget carries over unchanged ([widget spec](2026-11-19-session-glance-widget.md), GW1–GW22): a floating strip over every app in 8 drop slots, its own state colours (GW20, GW22); only its surface and text tokens change. Activity uses the widget's session glyph set (`SessionStateGlyph`). | "yes" to the widget intent (GW1) | RD-R3 | not drawn: the mock's "not shown" line; Activity rows |
| RD20 | Every list supports multi-select, and Clean uses the same mechanism. | "a" (Q3) | RD-R11 | checkboxes on every list; Clean sections |

## Requirements

- **RD-R1. Frame.** macOS window with a Liquid Glass sidebar and toolbar (macOS 26); solid surfaces as the macOS 15 and Reduce Transparency fallback.
  - **Sidebar groups:** Triage (Inbox, Clean), Agents (Skills, Subagents, Hooks, Rules), Watch (Limits, Activity), plus Settings, which opens as a separate macOS Settings window.
  - **Content:** native lists and tables on a solid surface, with a trailing inspector. Liquid Glass is never used in the content layer (HIG `materials.md:26`).
- **RD-R2. Eye order per page.** Each page answers one question and opens with one large figure that means something; the one primary action sits in the toolbar carrying the real number (FE-D3). This table replaces `design-notes.md` §1:

  | Page | First glance | Second glance |
  | --- | --- | --- |
  | Inbox | `11 need you` (or `Clear · Nothing needs you`) | The first group head and its first row |
  | Skills / Subagents | `4 never ran` | The `Never ran` group head with `Select N Suggested`, then rows sorted by Sessions |
  | Hooks | `3 dead or never ran` | The lifecycle strip (red and amber nodes) |
  | Rules | `1 rule allows a whole tool` (Claude Code); the riskiest setting word for a read-only CLI | The other CLIs' one-line summaries beside the figure |
  | Clean | `1.02 GB can be cleaned` (the sidebar figure) | The bar: selected, can be cleaned, locked |
  | Limits | The Window that needs you: over the limit, then furthest behind pace, else the lowest left | The same Window's row and its tick |
  | Activity | `1 waiting for you` (or the running count) | The waiting row |
  | Settings | The first row of the pane | – |
- **RD-R3. One token and block set.** Every screen is composed only from the shared blocks and tokens shown on the mock's "Tokens + base" page. The existing `StyleBoundaryTests` rule continues to apply.
- **RD-R4. Inbox first.**
  - **Groups:** findings are grouped by job: Clean up, Balance, Control, Watch. Severity is shown once at the group head. The hero count equals the rows shown.
  - **Row actions:** the selected row carries the full-verb action and Keep. The group head only selects (`Select N Suggested`); removing goes through the toolbar's `Remove N selected`, so nothing is removed that was not ticked.
  - **What counts (RD26):** Dead and Never ran items not added in the last day, not plugin-owned and not kept; Hooks with errors in the last 7 days; Claude Code Rules that allow a whole tool; Windows behind pace or over the limit; waiting sessions. Kept findings are listed under `N kept · Show` and leave the count.
  - **Watch:** limit Windows are judged by pace (share left against share of time left), not by a fixed threshold. Proposed data, readings older than 6 hours and Windows without a length are shown but never judged.
- **RD-R5. Type.**
  - **Typefaces:** SF Pro for text, SF Pro Rounded for figures only (in SwiftUI, `.fontDesign(.rounded)` on figure `Text`), SF Mono for paths and commands.
  - **Scale:** 11/12/13/15/22/40 pt, weights 400 and 500 only.
  - **Letter-spacing:** never changed (FE-SP4).
- **RD-R6. Meters.** 4 pt meters, 6 pt hero meter, 3 pt progress. The "time" tick on limit Windows stays readable.
- **RD-R7. Colour roles.**

  | Role | Dark | Light |
  | --- | --- | --- |
  | Page / group / sidebar | `#111214` / `#191A1D` / `#141518` | `#F4F4F5` / `#FFFFFF` / `#E9E9EB` |
  | Ok / attention / critical | `#4CC38A` / `#E8B33A` / `#EF6B5E` | `#17784C` / `#8A6200` / `#C42F1D` |
  | Skills / Subagents / Hooks / Rules (icons only) | `#A38BF5` / `#7BDEE0` / `#CF84E0` / `#9AA3B5` | `#6A4FD8` / `#178082` / `#9A3FB0` / `#586273` |

  Every text and icon pair reaches 4.5:1 on its surface; see `design-notes.md` §4, §12, §21, §23 for the measured values.
- **RD-R8. Data colour.**
  - **Data:** bars, meters, tile heat and legends use the neutral steps `--data-1`…`--data-4` (ink mixed into the group surface at 8/16/28/38% in dark and 8/16/28/44% in light).
  - **State colours:** only for state.
  - **Category tones:** only on the sidebar icon, the row kind icon and the inspector title icon.
  - **CLI identity:** only through logos.
- **RD-R9. Primary.**
  - **Fill:** `#0B6FE4` with white text (4.76:1), flat, no gradient, no shadow. Hover is one step lighter, pressed one step darker.
  - **Used for:** the one non-destructive primary action, checkbox and switch on-states and links (`#5AA2FF` dark / `#0A64D0` light). No focus ring anywhere (D57): keyboard focus is the 3 pt ink bar of RD29, on text inputs too.
  - **Not used for:** selection, which stays neutral, and destructive actions, which use a red tint and are never primary (HIG `buttons.md:53`).
- **RD-R10. N CLIs.** Every surface works at 2, 3, 6 and 10 CLIs.
  - **Order and support:** CLIs sit in a fixed order. A concept a CLI lacks shows as "Not supported", distinct from Missing and Unmeasurable.
  - **One shape (RD28):** every page uses the same layout at 2 CLIs as at 10.
  - **Toolbar:** an `All CLIs` pop-up with up to 3 pinned CLIs replaces the two-CLI segmented filter. A CLI without the page's concept is listed disabled as Not supported. Balance compares pinned CLIs only.
  - **Hook events:** the lifecycle strip shows the six common events and any other event (of the 17 Claude Code and 10 Codex events the core reports) that has a Hook, in firing order.
  - **Pages:** Activity is grouped by CLI; Limits lists CLIs in the fixed order and collapses CLIs without limit data into one "Unmeasurable" line; Hooks groups by lifecycle stage at every count, a CLI's own event name shown in the row, and names CLIs with no Hooks and CLIs without Hooks under the table.
  - **Unmeasurable cells:** a CLI that loads an item but keeps no log SpaceVibe can count shows the item as on with Unmeasurable sessions, never 0; Never ran is judged over measured CLIs only. An unreadable CLI folder makes every cell of that CLI unknown, Missing included.
  - **Rules:** a CLI pop-up picks the page; Claude Code's page is editable, every other CLI's page is read-only in its own terms (the owner's 2026-11-04 pick), and the Claude Code page shows each other CLI's one-line summary.
- **RD-R11. Row toggles.** A Skill or Subagent row shows one logo toggle per supporting CLI, wrapping at 5 per line.

  | State | Drawn as |
  | --- | --- |
  | On | full logo |
  | Off | dim logo |
  | Not supported | dash, no button |
  | Plugin | lock |
  | Never ran | amber dot on the owning CLI only |

  - **On / off:** turning on copies the item into that CLI's folder. Turning off moves it to SpaceVibe's trash. Every toggle shows Undo. A logo whose turning off would delete the item's last copy is not a toggle (D53, counted by files, not by lit logos: several CLIs can read one file); `Remove…` is the explicit action. Turning off a CLI removes every file it reads the item from, and the confirmation offers to keep it only for readers whose own folder is not among those files.
  - **Shared files:** a file read by several CLIs through a shared folder opens an anchored confirmation that names every reader before removal. Every other removal path (the per-CLI sheet, Inbox, Clean) names the readers too before it writes.
  - **Bulk and Remove…:** "Add to…", "Remove from…" and an item's `Remove…` open a per-CLI sheet. Nothing is ticked at first; each CLI line names the real source folder and who else reads it, and the button counts every CLI that loses the item.
- **RD-R12. Inspector tiles.** The Skill/Subagent inspector shows a "CLIs" tile grid of at most 3 rows, with `max(3, ceil(N/3))` columns and tiles of about 72×60 pt.
  - **Tile content:** the logo, the name and the session count.
  - **Fill:** neutral heat in 4 steps relative to the item's top CLI.
  - **Toggle:** the tile is the same toggle as in the row, in sync with it. It shows a green success check when enabled, on a disc so it stays legible.
  - **Contrast:** text on every step reaches 4.5:1.
- **RD-R13. States.** Every page draws normal, empty, scanning, error, worst-case data, just-written (Undo), refused write and confirmation states, as in the mock. The layout never shifts (FE-L1). During the first usage scan Skills and Subagents list their rows with pending counts. Below 1100 pt the inspector opens as an overlay from the toolbar button or a row click.
- **RD-R14. Retired from the mock (RD21):** the toolbar `More` button (nothing was designed for it), the Activity Files tab, the Limits Refresh and Gemini card, `Remove from Both`, the static Clean inspector and its live-session banner, summary bars that repeat the hero.
- **RD-R15. Writes the app does not do (RD24, RD25):** install or remove the status-line capture, empty SpaceVibe's trash.
- **RD-R16. Accessibility (WCAG 2.2 AA, from the 2026-11-21 review).**
  - **Keyboard:** arrow keys move the selection and show the RD29 bar; Return or ⌘I opens the overlay inspector below 1100 pt, arrows never do; every row action (Keep, Remove, Add to…, Stop…, Copy Command) is also a menu command with a shortcut, a context-menu item and an accessibility action on the row.
  - **Severity:** shown by glyph and colour (`x-circle-fill` critical, `warning-fill` attention), never by a coloured dot alone; small amber marks in light use the 3:1 amber.
  - **Names and state:** every checkbox, switch, segmented control, logo toggle and Hooks node has a label and its state (on, off, via, only copy, Unmeasurable, Not supported); the sidebar Inbox item reads "N need you, M critical".
  - **Dialogs:** at most 5 listed rows with "and N more"; buttons always in reach; Cancel is the default; Stop is destructive and never the default; Esc closes every overlay; focus moves in and returns.
  - **Announcements:** writes and refusals are announced (refusals at high priority); progress bars carry a label and value.
  - **Targets:** at least 24 pt; a checkbox's whole 28 pt cell toggles it.
  - **Increase Contrast and Reduce Motion:** tracks, control fills and data steps rise to 3:1; tile lift, press scale, count-ups and filling bars are skipped.
- **RD-R17. Robust data (from the 2026-11-21 break-ui review).**
  - **Names:** long names, paths and commands are cut in the middle with the full text in a tooltip; titles keep their own text direction; a Hook is named by the script it runs (`hookLabel`), the same on every surface.
  - **Numbers:** bytes, money and counts use the system formatters (TB above 1,000 GB, two decimals for money, plurals, thousands separators, `4.8M` in narrow cells).
  - **Layout:** the toolbar's destructive or primary button keeps one width; one-line cells end in an ellipsis; toasts wrap and keep Undo in the window; a refused-write toast shows 3 lines with Details.
  - **Honesty:** a session with no project reads "No project"; a bare MCP tool name is not a "whole tool" rule (only tools that take a specifier: Bash, Read, Edit, Write, MultiEdit, NotebookEdit, WebFetch, WebSearch); empty log rows are not offered; the Clean bar's scale is what can be cleaned, and bytes in use are text only.

## Acceptance

- **RD-A1.** Side by side with the reference mock, for every page and for the Settings window, in dark and light, Glass and Solid, at 1280: the structure (frame, regions, order) matches.
- **RD-A2.** For each page, the element named as the first glance in the RD-R2 table is the largest or highest-contrast element in a screenshot of the built app.
- **RD-A3.** No screen file contains a font, colour, radius or spacing literal (`StyleBoundaryTests` passes). The Tokens + base specimen is implemented as a debug screen.
- **RD-A4.** In a built screenshot, figures render in SF Pro Rounded and text in SF Pro. Meter heights match RD-R6.
- **RD-A5.** Contrast measured on built screenshots meets RD-R7, RD-R8 and RD-R9. The primary blue appears only on the uses listed in RD-R9.
- **RD-A6.** With a fixture of 2, 6 and 10 CLIs, the Skills row toggles and the inspector tiles behave as RD-R11 and RD-R12 describe:
  - toggling adds or removes the item and Undo restores it;
  - a shared file names its readers;
  - the grid never exceeds 3 rows.
- **RD-A7.** `build-review` passes before the owner is asked to look (W24), because the build removes and copies user files.
- **RD-A8.** No screen offers a control listed in RD-R14 or RD-R15; Settings has the theme switch; a lone lit logo cannot be clicked off.
- **RD-A9.** With a fixture where every finding is fixed or kept, Inbox shows `Clear` and the sidebar shows 0; a kept finding comes back with Stop Keeping. A Window at 5% left or less is the Limits hero whatever its pace.
- **RD-A10.** With Full Keyboard Access on, every action on every page is reachable without a pointer, and the focus bar is visible at 3:1 in dark and light.
- **RD-A11.** The break-ui datasets (`extreme`, `one`, `huge`) render on every page at 1000 and 1280 with no overflow, no text over another, no `null` or `NaN`, and every dialog's buttons inside the window.

## Inferred, not decided

Each line comes from the mock or from an agent's choice, not from the owner:

- **Pre-selection:** the default is "nothing pre-selected" (mock axis `preselect`). The alternative is to pre-select dead Hooks only. Since round 4 the group head only selects, so pre-selection is the one way a removal starts without a tick.
- **Row actions:** the default is the selected row plus a group-head `Select N Suggested` (mock axis `rowact`). The alternative is one button on every row. This conflicts with the earlier "every action visible" answer.
- **Hero of Clean:** what can be cleaned (equal to the sidebar); the selected amount sits on the button and the bar. Replaces the round-3 "hero = selected".
- **Show in Settings › CLIs:** hides a CLI from every list only; who reads or loses a file always counts every installed CLI, so removing a shared file still names a hidden reader.
- **Project items:** Skills, Subagents and Hooks under `<project>/.claude` are listed with a "Project · <name>" label, read-only (the engine refuses removal, 403), never an Inbox finding, never selectable in Clean.
- **Show Terminal (owner decision pending, recommended: keep):** brings the app that runs the session to the front with the shipped `HostAppResolver` (GW5): no process started, no Automation permission. A session in tmux, screen or ssh has no app, so the button is disabled with "Terminal app not found". A waiting session also shows "Answer in the terminal. SpaceVibe only shows that it is waiting."
- **Content icon weight:** the mock draws content glyphs in Phosphor Bold and state glyphs in Phosphor Fill; D72 has content glyphs in Phosphor Duotone, and RD23 covers only the 8 page icons. Owner decision pending.
- **Refused Undo and a core that will not start:** declared in the mock's "not shown" with the shipped behaviour (error toast naming the reason; last data kept with "The core could not be started." and Try Again).
- **Project rules:** Rules › Project reads and writes the chosen project's own file (`<project>/.claude/settings.json` or `settings.local.json`); the mock draws one synthetic rule set per project.
- **Show guard:** at least one CLI stays shown; a hidden CLI's rows leave every list, its sessions still lock its logs and caches (RD27).
- **Search (⌘F):** filters the page's list by name, description, command and path; no match shows "No <items> match" with Clear Search. Listed in the mock's "not shown"; D49 relies on it.
- **Balance finding:** one finding at most, the most-used item missing in a pinned CLI; none when fewer than two CLIs are pinned.
- **Open at login:** a new Settings switch, not in the shipped app, off by default; it adds a login item that the user approves in System Settings (W24 applies to the build). No owner decision of its own.
- **Icon set (owner decision pending, recommended: keep):** Phosphor plus SpaceVibe's own set (D72, RD23), not SF Symbols.
- **Keys (owner yes pending):** ↑↓ and j/k move the selection (D11), A toggles the focused logo (D69), S stops (asks), Z and ⌘Z undo (GLOSSARY Undo), ⌘1–⌘8 open the pages (grilling Q5, still open). The v5 status-bar hints are retired with the status bar; the Undo hint lives in the toast.
- **Checkboxes (narrows RD20, owner yes pending):** a list has checkboxes where a bulk action exists (remove, stop); Keep and Dismiss act on one row at a time.
- **Limits selection:** a Window row can be selected (highlight only, no inspector); the widget and its popover open Limits with that row selected (LC-R7).
- **Keep is stored:** kept findings survive a restart, in a list in the app's data folder (`~/.spacevibe`); the build plan's RB-E5.
- **Page × state cells drawn as Normal on purpose:** listed in the mock's `MOCK.na` with their behaviour (Moving only on Clean, Hooks never ask, Limits writes nothing, no shared file at 2 CLIs, the Settings window has no scan); the mock's `consistency.js` fails on any other such cell.
- **Settings window states:** empty and error open the Limits pane (no snapshot, Unmeasurable), worst and dialog the CLIs pane, a refused setting shows the error toast.
- **Inbox Remove:** a Skill or Subagent that is not a shared file is removed at once with Undo (`Remove`); a shared one asks with its readers (`Remove…`).
- **Capability write:** follows the engine (rules.md): Read, Edit, Run, Network change the cell's wide rules or add one bare rule; Push and deploy and Secrets change their own rules; the preview says when the cell will still read Mixed; a same-value change is "Nothing to change" and writes nothing.
- **Pinning:** Balance pins live in Settings › CLIs only, two to three, and only for CLIs that hold Skills or Subagents; the All CLIs menu no longer pins.
- **Plugin-owned Never ran items:** counted in the Skills hero (a fact), listed read-only in Clean (CL-R1), never an Inbox finding.
- **Row state icons:** grey inside rows (severity once per group, RD10) except Activity's waiting hand, which stays amber; FE-C3 asks for coloured state icons everywhere.
- **Session state glyphs:** the mock draws play / hand / pause / check / question; the shipped `SessionStateGlyph` uses another set. The build keeps one set; which one is open.
- **Sidebar Activity figure:** the waiting count when a session waits, otherwise the running count.
- **Dead Hook runs:** a dead Hook shows the runs the logs hold (they can be above 0 if the script was deleted after running); unverified against the engine.
- **Keep on watch findings:** a kept Window or waiting session comes back when its state changes (a new Window, a new wait).
- **Unknown in a row:** a CLI whose folder cannot be read draws a dim logo with a `?` badge, distinct from Missing; the Sessions total gets `+?`.
- **Copy for the error state:** "Unmeasurable" is the one word for anything SpaceVibe cannot know (D65); "Unreadable" is retired from labels.
- **Pace thresholds:** amber when the share left is more than 3 points below the share of time left, once a tenth of the Window has passed (RD30); red above 15 points, at ≤ 5% left or over the limit.
- **`Remove N selected`:** counts rows, not copies across CLIs.
- **Settings:** `Look` (Glass or Solid) follows the system; the theme switch stays (D70, RD21).
- **SF Pro on future shells:** SV2 plans Windows and Linux shells; SF Pro is licensed for Apple platforms, so those shells need their own face.
- **Glossary:** "Not supported" is a new GLOSSARY term. "Agents" is used as the sidebar group label.
- **Subagents tone:** `#178082` in light is 28° from ok green, under the 30° target.
- **Many-CLI open questions** from `research-many-clis.md`, each with the research's recommendation:
  - CLI registry first (yes).
  - Pinned Balance; PRODUCT.md "Balance the two CLIs" changes to "pinned CLIs" (owner wording needed).
  - `Add to…` copies by default.
  - "Not supported" joins the glossary.
- **Superseded documents:** this spec, once approved, supersedes `docs/DESIGN-LANGUAGE.md` (v5) and the ledger decisions listed in "Ledger decisions this spec replaces" below; the countdown spec is carried, not superseded (RD33).

## Ledger decisions this spec replaces

From the [2026-11-06 ledger](2026-11-06-reins-linear-identity-decisions.md). Rows marked "owner yes pending" narrow or reverse a decision the owner made and are not in force until the owner says yes (W20). D53, D57, D69 and D70 stay (RD21).

| Ledger | What it said | Replaced by | State |
| --- | --- | --- | --- |
| D3, D4 | Linear desktop app as the one reference | Native macOS 26 frame (RD4, RD5) | recorded (RD4) |
| D7 | Inter stays | SF Pro, figures in SF Pro Rounded (RD6) | recorded (RD22) |
| D17, D45, D54, D56, D61, D67 | List-plus-pane, bento and split layouts | Native lists with a trailing inspector (RD4) | owner yes pending |
| D20 | Sidebar icons white, row icons grey | Category tone on sidebar and row icons (RD12) | recorded (RD22) |
| D21, D31 | Badge on a lit logo | Full logo; the tile carries the check (RD-R11) | recorded (RD22) |
| D23 | No count column in the list | Sessions column with a thin bar (RD-R11) | owner yes pending |
| D26, D43, D46 | Agents page with tabs Skills, Subagents, Hooks, Rules | Four sidebar pages (RD19) | recorded (RD19, owner's guess taken) |
| D27, D33–D37 | Filter menu, chips, Group by, Order by | `All / Never ran`, `All CLIs`, Sessions sort (RD22) | recorded (RD22) |
| D28 | Bottom bar: add the selection to one CLI in one click | Per-CLI sheet `Add to…` / `Remove from…` (RD-R11) | owner yes pending |
| D29, D30 | Tab head and row line styling | New tokens and blocks (RD-R3) | owner yes pending |
| D32, D72 | MingCute category icons; Phosphor Duotone content glyphs | SpaceVibe's own Bold set for page icons (RD23); content glyph weight pending ("Inferred, not decided") | partly recorded (RD23) |
| D51 | Attention queue strip on Agents | Inbox page (RD3) | owner yes pending |
| D59 | Limits: one card, one band per CLI | One card per CLI, fixed order (RD-R10) | owner yes pending |
| D60 | No reset tick on bars | Pace tick (RD22) | recorded (RD22) |
| D66 | Spacing tokens of the mock kit | Spacing of the redesign Tokens page (RD-R3) | owner yes pending |
| D68 | 2026-11-07 frozen mock as build reference | This spec's reference mock | recorded (RD1, RD-A1) |
| D24, D41 | Row-end warning icon with a Remove / Open file popover; the fix within one hover or click | Row actions on the selected row and the inspector (RD-R4), logo toggles in the row (RD-R11) | owner yes pending |
| D58 | Row warning icons keep their state tones | Severity once per group, row icons grey (RD10) | recorded (RD10) |
| D60 (clause 1) | A number appears once | Sidebar values repeat each page's hero (RD10) | recorded (RD10) |
| D11 | `j`/`k` navigation | Kept, with ↑↓ ("Inferred, not decided": keys) | owner yes pending |

PRODUCT.md lines this spec changes, updated at the cut-over (RB-X1), owner yes pending: "primary datum … at 20px; everything else 13px or smaller" (the scale is 11–40 pt, RD-R5); "a number shows once … never repeated in another card" (sidebar values repeat the hero, RD10); "a problem shown in a row offers its fix in the same row … (the warning popover with Remove)" (Skills and Subagents rows fix through their logo toggles; removal of the whole item is the inspector's `Remove…`); "Balance the two CLIs" (pinned CLIs, RD-R10).

## Needs new engine data or contracts

- **Clean** (from the Clean spec): `clean.scan` / `clean.move` with byte-accurate results, per-item sizes, `firstSeen` on items, and verified cache paths.
- **Sessions per day per item and CLI:** today only `days[]` (ran / not ran) exists. Hook day data is also missing.
- **N CLIs:**
  - a CLI registry with string ids and a `supports` map;
  - per-CLI readers and log paths;
  - a "which CLIs read which file" map for shared folders such as `~/.agents/skills`;
  - `copyTo {targets[]}` and per-CLI remove, in place of `copyToOther`;
  - limit data for any CLI beyond Claude Code and Codex.
- **Rules:** a `wide` flag for unbounded rules; a batch remove (`rules.removeMany`) with one Journal entry; read-only permission summaries for CLIs other than Claude Code and Codex.
- **Batch removal:** one method and one Journal entry for a selection that mixes Skills, Subagents and Hooks (Inbox, Skills, Hooks), so one Undo restores it.
- **Hook errors by day:** `HookTotals` holds lifetime errors only; RD26 needs errors in the last 7 days.
- **Clean move progress:** a progress notification for `clean.move` (files and bytes), and a cancel that stops before the next file.
- **Status-line snapshot age:** the time of the last capture, for Settings › Limits.

## Out of scope

- Building code before the owner approves the mock by eye.
- Restyling the public site `site/`.
- Support for CLIs other than Claude Code and Codex in the engine. The design must allow them (RD13), but adding them is separate work, each with its own spec.

## Rollout (for the plan)

- **Switch:** build on `main` region by region behind a dev-only switch (FE-P9). The old UI stays the default until each region's eye-approved cut-over.
- **Shared blocks first:** the blocks several regions share (row with toggles, inspector tiles, group head, meters, toolbar primary, toast) land first as their own small PRs.

## Open item to verify (out of scope, raised once)

**Codex skill path (hypothesis):** the core reads Codex skills only from `~/.codex/skills` (`core/internal/roots/roots.go`). Current Codex docs name `~/.agents/skills`. If Codex no longer reads `~/.codex/skills`, the Skills page reports wrong "Not in Codex" and "Never ran" values. To check, install a skill only in `~/.agents/skills` and see whether Codex lists it.
