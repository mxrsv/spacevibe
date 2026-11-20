# SpaceVibe: app-wide redesign (macOS frame, v2)

Date: 2026-11-20
Status: draft, 2026-11-20. The direction is set by the mock below. The owner said "giao diện đã tốt hơn rất nhiều nhưng không vì thế mà tôi approve ngay được" (2026-11-20), so the mock is not eye-approved yet. No plan and no code yet.
Parent: [PRODUCT.md](../../PRODUCT.md) (all four jobs). Plan: none yet.

- **Reference mock (checkpoint 2026-11-20):** `~/scratch/spacevibe-reins/2026-11-20-redesign-v2/mock.html`. It is built from `src/` in the same folder (`cd src && python3 build.py`). Its consistency check is `node src/consistency.js`.
- **Design record:** `design-notes.md` in the same folder, sections 1–24. It holds the thesis per page, the token tables with measured contrast, and the needs-new-data list.
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

| ID | Decision | Owner's words | Req | Acceptance |
| --- | --- | --- | --- | --- |
| RD1 | Redesign the whole app, not one page. | "toàn bộ cả app" | RD-R1 | RD-A1 |
| RD2 | Every page has a planned first and second glance. There is one token set and one base block set. | "phải có tính toán khi user vào app nhìn vào đâu đầu tiên rồi vào page thì nhìn UI nào đầu tiên ? rồi phải có design tokens và ui design base" | RD-R2, RD-R3 | RD-A2, RD-A3 |
| RD3 | What needs fixing now is the first thing seen. | "đúng, việc cần xử lý ngay phải nhìn thấy đầu tiên" | RD-R4 | RD-A2 |
| RD4 | Native macOS frame: glass sidebar, toolbar, native lists and tables, trailing inspector, separate Settings window. | "đã thay đổi layout design hoàn toàn, ý tôi là muốn như này, chứ không phải đi chỉnh sửa nhỏ từng tí một" | RD-R1 | RD-A1 |
| RD5 | The design is rebuilt from scratch with the TinySift process: thesis, signature, measured token plan, self-critique. | "ok dựng thử đi" (on that proposal) | RD-R2 | RD-A3 |
| RD6 | Text is SF Pro. Only figures use SF Pro Rounded. | "chỉ sử dụng font rounded cho số liệu" | RD-R5 | RD-A4 |
| RD7 | Meters and progress bars are thin. | "các progress nên cho nhỏ height lại" | RD-R6 | RD-A4 |
| RD8 | State tones: attention is a yellow-leaning amber; ok and critical are kept. | "thử update đi" (on the proposal) | RD-R7 | RD-A5 |
| RD9 | The background is Graphite, neutral with no hue cast. | "chốt graphite" | RD-R7 | RD-A5 |
| RD10 | Colour discipline: severity is shown once per group; big figures are ink; content sits on a solid background; glass is only on the sidebar and toolbar; sidebar counts are neutral. | owner-pasted diagnosis, applied in mock round 3 | RD-R8 | RD-A5 |
| RD11 | The primary is the TinySift button blue `#0B6FE4` with white text, a flat fill with no shadow. | "dùng màu primary giống màu button bên mock này"; "bạn thêm shadow vào làm gì ?" | RD-R9 | RD-A5 |
| RD12 | Data is drawn in neutral greys. Category tones appear on icons only. | "ok" (on that proposal) | RD-R8 | RD-A5 |
| RD13 | The design must hold for many CLIs, not only two. | "nếu sau này có 10 agents thì sao ?" | RD-R10 | RD-A6 |
| RD14 | Each Skill and Subagent row shows its CLIs as logo toggles. A click adds the item to that CLI or removes it. | "logo các agent hiển thị lên có thể click toggle"; "ổn" | RD-R11 | RD-A6 |
| RD15 | The inspector shows a grid of CLI tiles. Fill darkness shows how much each CLI uses the item. Each tile is a toggle with a success check when enabled. The grid has at most 3 rows, with small tiles. | "dạng lưới logo … bọc 1 box … có màu đậm nhạt để tương trưng cho agent đó dùng skill ít hay nhiều"; "thêm icon success vào nếu đang enabled, chỉ cho max là 3 hàng, cho chúng size nhỏ lại" | RD-R12 | RD-A6 |
| RD16 | The "Never ran" amber dot is shown only on the CLI that owns the file. | "ổn" (on that recommendation) | RD-R11 | RD-A6 |
| RD17 | Options the owner did not pick are removed from the mock. | "clean những cái option không đc chọn đi đã" | n/a | n/a |
| RD18 | Clean covers anything AI CLIs leave behind and is one feature group of the app. | "dọn bất kỳ cái gì liên quan đến agent, ai"; "Clean chỉ là một nhóm tính năng nhỏ trong đó" | CL-R1–CL-R8 | Clean spec |

Two earlier owner answers are also carried here. They come from the paused layout-frame grilling of 2026-11-18, recorded in the auto-memory, not in this chat:

| ID | Decision | Owner's words | Req |
| --- | --- | --- | --- |
| RD19 | Skills, Subagents, Hooks and Rules are separate sidebar pages. | taken as guessed (Q1) | RD-R1 |
| RD20 | Every list supports multi-select, and Clean uses the same mechanism. | "a" (Q3) | RD-R11 |

## Requirements

- **RD-R1. Frame.** macOS window with a Liquid Glass sidebar and toolbar (macOS 26); solid surfaces as the macOS 15 and Reduce Transparency fallback.
  - **Sidebar groups:** Triage (Inbox, Clean), Agents (Skills, Subagents, Hooks, Rules), Watch (Limits, Activity), plus Settings, which opens as a separate macOS Settings window.
  - **Content:** native lists and tables on a solid surface, with a trailing inspector. Liquid Glass is never used in the content layer (HIG `materials.md:26`).
- **RD-R2. Eye order per page.** Each page answers one question. The first and second glance are fixed as in `design-notes.md` §1, and corrected in §11–§12: Inbox, then Skills/Subagents, Hooks, Rules, Clean, Limits, Activity, Settings. Each page opens with one large figure that means something, and the one primary action sits in the toolbar carrying the real number (FE-D3).
- **RD-R3. One token and block set.** Every screen is composed only from the shared blocks and tokens shown on the mock's "Tokens + base" page. The existing `StyleBoundaryTests` rule continues to apply.
- **RD-R4. Inbox first.**
  - **Groups:** findings are grouped by job: Clean up, Balance, Control, Watch. Severity is shown once at the group head.
  - **Row actions:** the selected row and the group head carry the full-verb action.
  - **Watch:** limit Windows are judged by pace (share left against share of time left), not by a fixed threshold.
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
  - **Used for:** the one non-destructive primary action, checkbox and switch on-states, links (`#5AA2FF` dark / `#0A64D0` light) and the text-input focus ring.
  - **Not used for:** selection, which stays neutral, and destructive actions, which use a red tint and are never primary (HIG `buttons.md:53`).
- **RD-R10. N CLIs.** Every surface works at 2, 3, 6 and 10 CLIs.
  - **Order and support:** CLIs sit in a fixed order. A concept a CLI lacks shows as "Not supported", distinct from Missing and Unmeasurable.
  - **Toolbar:** an `All CLIs` pop-up with up to 3 pinned CLIs replaces the two-CLI segmented filter. Balance compares pinned CLIs only.
  - **Pages:** Limits, Clean and Activity are grouped by CLI. CLIs without limit data collapse into one "Unmeasurable" line.
- **RD-R11. Row toggles.** A Skill or Subagent row shows one logo toggle per supporting CLI, wrapping at 5 per line.

  | State | Drawn as |
  | --- | --- |
  | On | full logo |
  | Off | dim logo |
  | Not supported | dash, no button |
  | Plugin | lock |
  | Never ran | amber dot on the owning CLI only |

  - **On / off:** turning on copies the item into that CLI's folder. Turning off moves it to SpaceVibe's trash. Every toggle shows Undo.
  - **Shared files:** a file read by several CLIs through a shared folder opens an anchored confirmation that names every reader before removal.
  - **Bulk:** "Add to…" and "Remove from…" open a per-CLI sheet.
- **RD-R12. Inspector tiles.** The Skill/Subagent inspector shows a "CLIs" tile grid of at most 3 rows, with `max(3, ceil(N/3))` columns and tiles of about 72×60 pt.
  - **Tile content:** the logo, the name and the session count.
  - **Fill:** neutral heat in 4 steps relative to the item's top CLI.
  - **Toggle:** the tile is the same toggle as in the row, in sync with it. It shows a green success check when enabled, on a disc so it stays legible.
  - **Contrast:** text on every step reaches 4.5:1.
- **RD-R13. States.** Every page draws normal, empty, scanning, error, worst-case data, just-written (Undo) and confirmation states, as in the mock. The layout never shifts (FE-L1).

## Acceptance

- **RD-A1.** Side by side with the reference mock, for every page and for the Settings window, in dark and light, Glass and Solid, at 1280: the structure (frame, regions, order) matches.
- **RD-A2.** For each page, the element named as the first glance in `design-notes.md` §1 is the largest or highest-contrast element in a screenshot of the built app.
- **RD-A3.** No screen file contains a font, colour, radius or spacing literal (`StyleBoundaryTests` passes). The Tokens + base specimen is implemented as a debug screen.
- **RD-A4.** In a built screenshot, figures render in SF Pro Rounded and text in SF Pro. Meter heights match RD-R6.
- **RD-A5.** Contrast measured on built screenshots meets RD-R7, RD-R8 and RD-R9. The primary blue appears only on the uses listed in RD-R9.
- **RD-A6.** With a fixture of 2, 6 and 10 CLIs, the Skills row toggles and the inspector tiles behave as RD-R11 and RD-R12 describe:
  - toggling adds or removes the item and Undo restores it;
  - a shared file names its readers;
  - the grid never exceeds 3 rows.
- **RD-A7.** `build-review` passes before the owner is asked to look (W24), because the build removes and copies user files.

## Inferred, not decided

Each line comes from the mock or from an agent's choice, not from the owner:

- **Pre-selection:** the default is "nothing pre-selected" (mock axis `preselect`). The alternative is to pre-select dead Hooks only.
- **Row actions:** the default is a group-head button plus the selected row (mock axis `rowact`). The alternative is one button on every row. This conflicts with the earlier "every action visible" answer.
- **Pace thresholds:** amber when the share left is more than 3 points below the share of time left; red above 15 points or at ≤ 5% left.
- **`Remove N selected`:** counts rows, not copies across CLIs.
- **Hero numbers:** the Clean hero shows the selected amount, while the sidebar shows the cleanable amount.
- **Settings:** the `Look` setting is dropped and the app follows the system (HIG `dark-mode.md:24`).
- **Glossary:** "Not supported" is a new GLOSSARY term. "Agents" is used as the sidebar group label.
- **Subagents tone:** `#178082` in light is 28° from ok green, under the 30° target.
- **Focus:** no focus ring except on text inputs (FE-K5). WCAG 2.2 AA asks for a visible focus indicator; the row highlight must serve as it.
- **Many-CLI open questions** from `research-many-clis.md`, each with the research's recommendation:
  - CLI registry first (yes).
  - Pinned Balance; PRODUCT.md "Balance the two CLIs" changes to "pinned CLIs" (owner wording needed).
  - `Add to…` copies by default.
  - "Not supported" joins the glossary.
- **Superseded documents:** this spec, once approved, supersedes `docs/DESIGN-LANGUAGE.md` (v5) and the layout and visual decisions of the 2026-11-06 ledger. The exact D-ids still need to be listed with the owner, so none is narrowed silently.

## Needs new engine data or contracts

- **Clean** (from the Clean spec): `clean.scan` / `clean.move` with byte-accurate results, per-item sizes, `firstSeen` on items, and verified cache paths.
- **Sessions per day per item and CLI:** today only `days[]` (ran / not ran) exists. Hook day data is also missing.
- **N CLIs:**
  - a CLI registry with string ids and a `supports` map;
  - per-CLI readers and log paths;
  - a "which CLIs read which file" map for shared folders such as `~/.agents/skills`;
  - `copyTo {targets[]}` and per-CLI remove, in place of `copyToOther`;
  - limit data for any CLI beyond Claude Code and Codex.
- **Rules:** a `wide` flag for unbounded rules.

## Out of scope

- Building code before the owner approves the mock by eye.
- Restyling the public site `site/`.
- Support for CLIs other than Claude Code and Codex in the engine. The design must allow them (RD13), but adding them is separate work, each with its own spec.

## Rollout (for the plan)

- **Switch:** build on `main` region by region behind a dev-only switch (FE-P9). The old UI stays the default until each region's eye-approved cut-over.
- **Shared blocks first:** the blocks several regions share (row with toggles, inspector tiles, group head, meters, toolbar primary, toast) land first as their own small PRs.

## Open item to verify (out of scope, raised once)

**Codex skill path (hypothesis):** the core reads Codex skills only from `~/.codex/skills` (`core/internal/roots/roots.go`). Current Codex docs name `~/.agents/skills`. If Codex no longer reads `~/.codex/skills`, the Skills page reports wrong "Not in Codex" and "Never ran" values. To check, install a skill only in `~/.agents/skills` and see whether Codex lists it.
