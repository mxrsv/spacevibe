# SpaceVibe: Session glance widget

Date: 2026-11-19
Status: decided. Decisions settled in the intent interview and grilling, 2026-11-19; the owner picked the direction on the [mock](#mock) the same day (GW20). Plan: [2026-11-19-session-glance-widget](../plans/2026-11-19-session-glance-widget.md).
Parent: [PRODUCT.md](../../PRODUCT.md) job 4 (Watch: sessions running). Reads the report described in [activity.md](../internals/activity.md).

## Intent

- **Outcome:** a tiny widget that floats over every app and shows, per live Claude Code and Codex session, what state it is in, so the owner can glance at it without opening SpaceVibe.
- **User:** the owner, running several sessions in parallel while working in a browser or editor.
- **Success:** with 2-3 real sessions running and another app in front, the widget changes a session's icon within one poll (3 s) of the state change, and a click brings forward the app that hosts the session. The owner checks it by eye against the mock.
- **Constraint:** the widget reads only the existing `ActivityReport` (`activity.subscribe`), plus `limits.read` for the countdown (GW21). It adds no request (S-R5) and starts no process (S-R4). It never takes focus, and outside its own frame it never blocks clicks.

## Decisions

| ID | Decision | Owner's words |
| --- | --- | --- |
| GW1 | The root above: a floating glance layer over all apps. Out of scope: `Stop` in the widget, an in-session timeline, Gemini CLI, the notch (owned by `spacevibe-board`). | "yes" to the intent restate |
| GW2 | No toast. The widget is the only surface. | "không cần toast" |
| GW3 | One state icon per session, with the CLI logo (Claude or Codex). | "mỗi session và thêm logo agent vào" |
| GW4 | Hover opens a short list in place. Each row shows the CLI logo, title, state and running tool. | "Mở danh sách tại chỗ" |
| GW5 | A click on a session brings forward the app that hosts it (iTerm, Ghostty, VS Code, Deck…). No exact tab, no Automation permission. | "tôi muốn mở app mà agent đang chạy trên app đó", then "Đưa app lên trước" |
| GW6 | When no host app is found (tmux, ssh, dead parent), the click opens SpaceVibe's Activity at that session. | "Mở Activity đúng session" |
| GW7 | The icon set follows Orca, for both the state groups and the glyphs ([Orca reference](#orca-reference)). | "dùng bộ icon giống orca", then "Cả trạng thái lẫn hình icon" |
| GW8 | Done means `idle` with a log write in the last 10 minutes. After that the session reads as idle. | "Xong = vừa rảnh trong 10 phút" |
| GW9 | An `unmeasurable` session keeps a faint grey icon. Hover gives the reason. | "Icon xám mờ" |
| GW10 | An `ended` session leaves the widget at the next poll. | "Bỏ khỏi widget ngay" |
| GW11 | With no live session, a faint mark stays on screen. | "Giữ một dấu mờ" |
| GW12 | At most 6 icons, then `+N`. Waiting sessions first, then running. | "Tối đa 6 chấm + '+N'" |
| GW13 | The widget is dragged between preset drop slots: 8 per screen (4 corners and the middle of each edge), on any connected screen. | "đặt sẵn các vị trí có thể thả vào", "có thể drag qua lại giữa các màn hình", "8 ô: góc + giữa 4 cạnh" |
| GW14 | In the left and right edge slots the icons stack vertically, and horizontally everywhere else. The hover list opens toward the screen centre. | "Cạnh trái/phải dọc, mở vào giữa" |
| GW15 | The widget shows on every Space, full-screen apps included. | "Mọi Space, kể cả full screen" |
| GW16 | On by default, in the bottom-right slot. | "Bật sẵn, góc dưới phải" |
| GW17 | Closing the main window keeps the app running with its Dock icon, so the widget stays. | "App vẫn chạy, giữ Dock" |
| GW18 | Settings holds only the widget on/off switch. The position is chosen by dragging. | "đặt sẵn các vị trí để có thể drag vào" |
| GW19 | GW7 keeps Orca's shapes, not its look: the glyphs come from another icon library with the same shapes, and the state colours are more muted or brighter than Orca's, so the widget does not read as a copy. | "sử dụng một số thư viện icon khác nhưng vẫn dùng icon same same như vậy, với màu sắc cho màu hơi trầm hoặc sáng đi để không bị trông giống hoàn toàn orca" |
| GW20 | Picked on the mock: collapsed form A (state glyph beside the CLI logo), Phosphor Bold glyphs, the muted tone ("Trầm"). | "ok theo đề xuất chọn thư viện Phosphor" |
| GW21 | The widget also shows the limit reset countdown of the [limit-reset-countdown spec](2026-11-19-limit-reset-countdown.md) (LC1). It sits in a pill of its own beside the widget (LC10), so the widget's size is unchanged. This widens GW18 (Settings also holds the weekly countdown lead, LC3), GW-R1, GW-R5 and GW-R11 as marked below. | "thêm vào đếm ngược trong widget và cả app main" (2026-11-19) |

## Orca reference

Scouted from `stablyai/orca` at `bee13305` (2026-11-18, MIT): `src/renderer/src/components/agent/status/AgentStateDot.tsx`, `AgentWorkingSpinner.tsx`, `AgentQuestionIcon.tsx`, and the tokens in `src/renderer/src/assets/main.css`.

| Orca state | Glyph | Colour | SpaceVibe source |
| --- | --- | --- | --- |
| Working | A ring with its top quarter open, rotating. Under reduced motion the ring is closed and still | `--agent-working` = yellow-500 | `running` |
| Waiting / needs attention | Speech bubble with a question mark (lucide `MessageCircleQuestion`) | `--agent-question` = orange-500 dark, orange-600 light | `waiting` |
| Done | Circle with a check (lucide `CircleCheck`) | emerald-500 | `idle` and written within 10 min (GW8) |
| Idle | A small filled dot | neutral-500 at 40% | `idle` otherwise |
| No recent update / couldn't confirm | Dashed circle (lucide `CircleDashed`) | amber-500 | `unmeasurable`, but grey per GW9 |

Orca keeps the agent's brand icon separate from the state glyph, so the two sit side by side.

## Requirements

- **GW-R1. Source (GW1, GW21).** The widget's inputs are the `ActivityReport` the shell already receives and, for the countdown only, `limits.read` every 60 s (LC-R8). The shell keeps one `activity.subscribe` open while the widget is on, whether or not the main window is open.
- **GW-R2. One entry per live session (GW3, GW7, GW8, GW9, GW10).**
  - Each entry shows the state glyph from the [Orca reference](#orca-reference) and the CLI logo (`Resources/Brand`).
  - Mapping: `running` → working, `waiting` → waiting, `idle` with `lastWriteAgoMs` ≤ 10 min → done, other `idle` → idle, `unmeasurable` → dashed circle in faint grey.
  - An `ended` session has no entry.
  - Layout (GW20): each entry is the state glyph, then the CLI logo.
  - Glyphs (GW19, GW20): Phosphor Bold. Working `circle-notch-bold` (rotating), waiting `chat-circle-dots-bold`, done `check-circle-bold`, unmeasurable `circle-dashed-bold`, idle a small filled dot. The app's other Phosphor glyphs are Duotone, so these form their own generated set with its `IconPolicyTests` entry.
  - Colours (GW19, GW20): the muted tone, added to `Palette` as three state tokens. Built values (`sessionWorking`, `sessionWaiting`, `sessionDone`): working `#C4A867` dark / `#8F7638` light, waiting `#C48654` / `#A16129`, done `#7BA98F` / `#4A7D62`. Waiting moved from the mock's `#C98260` / `#A65C3A` because it sat 6-7° of hue from Claude's clay, beside the Claude logo, and failed `HuePolicyTests` (20° minimum); only the hue changed.
- **GW-R3. Count and order (GW12).** Up to 6 entries are shown, ordered waiting, running, done, unmeasurable, idle, then by newest write. Any more show as one `+N`. The widget never grows past the size of 6 entries plus `+N`.
- **GW-R4. Empty (GW11).** With no live session the widget shows the SpaceVibe mark in a faint tone. Hover says there is no session.
- **GW-R5. Hover list (GW4, GW14, GW21).** Hover opens the list in place, toward the screen centre; hovering the countdown pill opens the same list, which ends with the Limits group of LC-R6. Each row shows the CLI logo, the title, the state glyph and label, and the running tool (`currentTool`) when there is one. The list lists every live session, scrolls past a fixed height, and closes when the pointer leaves or Esc is pressed.
- **GW-R6. Click (GW5, GW6).** Clicking an entry or a row activates the GUI app that is the nearest ancestor of the session's pid. With no such app, the click brings SpaceVibe forward on Activity with that session selected. A click never sends a signal and never starts a process.
- **GW-R7. Placement (GW13, GW14, GW15, GW16).**
  - Dragging the widget shows the 8 drop slots of every connected screen. Releasing snaps it to the nearest slot.
  - The slot (screen and position) is remembered across launches.
  - The widget joins every Space, including full-screen ones.
  - The first launch places it bottom-right on the main screen.
- **GW-R8. Never in the way (GW1).** The widget panel never becomes key or main, never takes focus, and never covers the menu bar or the Dock. Clicks outside its frame reach the app below.
- **GW-R9. Lifecycle (GW17).** Closing the main window does not quit the app. Quitting the app removes the widget.
- **GW-R10. Settings (GW18, GW21).** One switch, on by default, shows or hides the widget. The weekly countdown lead (LC-R4) sits in its own Settings group. Turning the switch off also ends the subscription that GW-R1 opened for the widget.
- **GW-R11. Motion.** The working ring is the only animation; the countdown's digits changing each second is not one (LC7). The ring stops under Reduce Motion and whenever the widget is hidden.

## Acceptance

| Check | Requirement |
| --- | --- |
| A fixture report with one session in each state renders the matching glyph and logo for each, and no entry for `ended`. | GW-R2 |
| A fixture with 12 live sessions shows 6 entries plus `+6`, waiting first. The widget frame matches the 6-entry size. | GW-R3 |
| A fixture with no session shows the faint mark. | GW-R4 |
| In each of the 8 slots, the hover list opens toward the centre and stays fully on screen, with the longest fixture title. | GW-R5, GW-R7 |
| With real sessions in iTerm (or Ghostty) and VS Code, a click brings that app forward. A session inside tmux opens Activity at that session. | GW-R6 |
| Drag to a second screen, quit and relaunch: the widget is back in the same slot. With that screen disconnected, it falls back to the main screen (see Inferred). | GW-R7 |
| A full-screen app on its own Space still shows the widget. Typing in the front app is never interrupted while the widget updates. | GW-R7, GW-R8 |
| With the window closed, a session changing state changes its icon within 3 s. | GW-R1, GW-R9 |
| With the switch off, nothing floats and the core is not polling. | GW-R10 |
| With Reduce Motion on, the ring is still. | GW-R11 |
| `scripts/test.sh` passes, including the style boundary, icon policy and hue policy tests. | all |
| `build-review` passes before the owner looks (W24: GW5 changes how a task is reached), then the owner approves by eye beside the mock. | all |

## Inferred, not decided

- **Waiting glyph.** Phosphor has no speech bubble with a question mark, so waiting uses the bubble with dots, as shown on the mock. Source: agent's choice under GW20.
- **The muted working colour sits near amber `warn`.** The state tokens may need a small hue shift to pass `HuePolicyTests`. Source: agent's concern under GW19.
- **Dashed-circle shape for `unmeasurable`**, from Orca, in the grey of GW9. Source: agent's reconciliation of GW7 and GW9.
- **A disconnected screen** sends the widget to the same slot on the main screen. Source: agent's choice.
- **Host app lookup.** The shell walks parent pids in process with `sysctl(KERN_PROC_PID)` and stops at the first pid that `NSRunningApplication` knows as a regular app. This starts no process (S-R4). Source: agent's choice.
- **Faint mark** = the SpaceVibe mark from `Resources/AppIcon.svg`. Source: agent's choice.

## Mock

`~/scratch/spacevibe-reins/session-glance-widget.html` (outside the repo, F4). After the GW20 pick it draws only the picked form, glyphs and tone: every state of GW-R2 to GW-R5, all 8 slots, the drag overlay and worst-case data.

## Out of scope

- A toast or system notification (GW2).
- `Stop`, or any other write, from the widget.
- Focusing the exact terminal tab or window.
- Gemini CLI, and the notch.
