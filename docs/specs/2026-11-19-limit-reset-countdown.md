# SpaceVibe: Limit reset countdown

Date: 2026-11-19
Status: decided. Intent confirmed and grilled with the owner on 2026-11-19 (chat). No mock yet: the widget chip is drawn into the [widget mock](2026-11-19-session-glance-widget.md#mock) before its code, and the Limits page change follows the page's existing look.
Parent: [PRODUCT.md](../../PRODUCT.md) (Limits). Touches the [session glance widget](2026-11-19-session-glance-widget.md) (GW21) and reads `limits.read` ([core-protocol.md](../internals/core-protocol.md), [limits.md](../internals/limits.md)).

## Intent

- **Outcome:** a countdown to a limit reset, in the session glance widget and on the Limits page.
- **User:** the owner, working in another app, who wants to know when a limit opens again.
- **Why now:** the widget is being designed (GW1 to GW20) and has no code yet, so the countdown joins it before it is built.
- **Success:** with a fixture where a 5-hour window resets in 59 min and a weekly window in 23 h, and the weekly lead set to 24 h, both count; the widget shows the 5-hour one; the Limits page ticks every second. The owner checks it by eye.
- **Constraint:** no new request (S-R5) and no new process (S-R4). `limits.read` reads local files only.

## Decisions

| ID | Decision | Owner's words |
| --- | --- | --- |
| LC1 | A countdown to the reset, both in the widget and in the main app. | "thêm vào đếm ngược trong widget và cả app main" |
| LC2 | It starts by time before the reset, for the 5-hour and the weekly windows only, whatever share is used. | "khi chuẩn bị reset limit 5h hoặc reset limit weekly" |
| LC3 | The weekly lead is the user's choice: 24 h, 12 h, 5 h or 1 h. Default 1 h. | "tuỳ user muốn đếm ngược trước 24h, 12h, 5h, 1h, và mặc định để 1h" |
| LC4 | The 5-hour lead is fixed at 1 h, with no setting. | "limit 5h thì để 1h thôi" |
| LC5 | Main app: on the Limits page, the window's "resets in" line and its "Resets in" fact become a clock that ticks every second while it counts. Outside the lead the page is unchanged. No badge in the sidebar or title bar. | "theo guess" |
| LC6 | Claude Code and Codex. When several windows count, the widget shows the one that resets first; its hover list shows all. At zero the chip leaves. Out of scope: toast or system notification, monthly and model-scoped windows, a sidebar or menu bar badge, a countdown driven by share used. | "yes" to the intent restate |
| LC7 | The widget's clock also ticks every second. A digit change is not an animation under GW-R11. | Grilling Q1, guess taken (no answer) |
| LC8 | The Limits page countdown and its Setting ship first, apart from the widget. The widget chip is built with the widget plan. | Grilling Q2, guess taken (no answer) |
| LC9 | The clock takes the window's existing tone (`LimitsWording.tone`): neutral, then `low`, then `out`. No new colour. | Grilling Q3, guess taken (no answer) |

## Requirements

- **LC-R1. Which windows count (LC2, LC4, LC6).** A window counts when its CLI is Claude Code or Codex, it is `active`, current at the display clock, has no `scope`, and either `minutes == 300` with at most 1 h to the reset, or `minutes == 10080` with at most the chosen weekly lead to the reset. Claude's `five_hour` and `session` both count as 5-hour.
- **LC-R2. Clock text (LC5, LC7).** `H:MM:SS` from 1 h up (`23:12:05`), `MM:SS` below (`42:17`), tabular digits, updated every second while visible.
- **LC-R3. Limits page (LC5, LC9).** While a window counts, its line in the windows list reads "resets in" plus the clock, and the detail's "Resets in" fact shows the clock, both in the window's tone. Only the counting rows tick each second; the rest of the page keeps its 60 s refresh. At zero the row goes back to today's "reset passed" until the CLI writes a new reading.
- **LC-R4. Setting (LC3).** Settings gets a "Limits" group with one control, "Weekly countdown": 24 h, 12 h, 5 h, 1 h, default 1 h, stored in the `dev.spacevibe.app` defaults. A change applies at once on the page and in the widget.
- **LC-R5. Widget chip (LC1, LC6, LC7, LC9).** While any window counts, the widget shows one chip after the entries and `+N` (at the end of the column in a left or right edge slot): the CLI logo, `5h` or `Week`, and the clock of the window that resets first, in that window's tone. The chip also shows beside the faint mark when no session runs. It leaves at zero. The widget may grow by exactly this chip (an exception to GW-R3).
- **LC-R6. Widget hover list (LC6).** A "Limits" group at the end lists every counting window: CLI logo, window name (`5-hour`, `Weekly`), clock and the reset's clock time (`21:12`).
- **LC-R7. Widget click.** Clicking the chip or a Limits row brings SpaceVibe forward on the Limits page with that window selected.
- **LC-R8. Widget data (GW-R1 widened).** While the widget is on, the shell calls `limits.read` every 60 s; the clock counts down locally from `resetsAt`. The widget switch off stops those reads.

## Acceptance

| Check | Requirement |
| --- | --- |
| Pure tests: a 5-hour window at 61 min, 60 min and 59 min; a weekly window at each lead; inactive, scoped, past and Gemini windows never count. | LC-R1 |
| Pure tests: `23:12:05`, `1:00:00`, `59:59`, `00:01`. | LC-R2 |
| Fixture run of the Limits page: a counting row ticks, a non-counting row reads as today, colours follow the tone; at zero the row reads "reset passed". The owner checks it by eye. | LC-R3 |
| `SettingsTests`: default 1 h; choosing 24 h makes a weekly window at 23 h count on the page at once. | LC-R4 |
| Widget shots: a chip with sessions, a chip beside the faint mark, a chip in a vertical slot, two counting windows (the first to reset wins), and no chip outside every lead. Placed beside the widget mock. | LC-R5 |
| Widget shots: the hover list's Limits group with two windows. | LC-R6 |
| Click the chip in the owner's runtime: SpaceVibe opens on Limits with that window selected. | LC-R7 |
| With the widget off, no `limits.read` runs for it. | LC-R8 |
| `scripts/test.sh` passes, including the style boundary tests. | all |

## Traceability

| Decision | Requirement | Acceptance |
| --- | --- | --- |
| LC1 | LC-R3, LC-R5 | Limits page run, widget chip shots |
| LC2 | LC-R1 | LC-R1 pure tests |
| LC3 | LC-R1, LC-R4 | `SettingsTests` |
| LC4 | LC-R1 | LC-R1 pure tests (61, 60, 59 min) |
| LC5 | LC-R2, LC-R3 | LC-R2 tests, Limits page run |
| LC6 | LC-R1, LC-R5, LC-R6 | Gemini excluded in tests; "first to reset wins" shot; hover shot |
| LC7 | LC-R2, LC-R5 | widget shots and runtime tick |
| LC8 | the plan order | the page ships before the widget chip |
| LC9 | LC-R3, LC-R5 | tone check in the page run and shots |

## Inferred, not decided

- **Window selection by `minutes` and `scope`** (LC-R1). Source: agent's choice from the core's window ids.
- **Chip after `+N`, beside the faint mark, label `5h` / `Week`** (LC-R5). Source: agent's choice; the widget mock decides the look.
- **Hover Limits group and the click target** (LC-R6, LC-R7). Source: agent's choice, mirroring GW4 and GW6.
- **A 60 s `limits.read` cadence for the widget** (LC-R8). Source: agent's choice; the clock itself needs no read.
- **Settings group named "Limits", control "Weekly countdown"** (LC-R4). Source: agent's choice.
- **"reset passed" at zero on the page** (LC-R3). Source: the page's current behaviour.

## Out of scope

- A toast or system notification.
- Monthly and model-scoped windows, and Gemini CLI.
- A badge in the sidebar, title bar or menu bar.
- A countdown that starts from share used rather than time.
