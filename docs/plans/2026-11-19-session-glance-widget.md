# SpaceVibe: session glance widget, build plan

Started 2026-11-19. Status: approach written, waiting for the owner's go before code (D10).
Spec: [2026-11-19-session-glance-widget](../specs/2026-11-19-session-glance-widget.md) (GW1 to GW21, GW-R1 to GW-R11). This plan does not repeat the requirements; each task names the IDs it serves.
Checkout: `spacevibe-reins` on `main`, shared with other sessions. Commit with `git commit -- <paths>` only; never `git stash` (build baselines from `git archive`).
Mock: `~/scratch/spacevibe-reins/session-glance-widget.html`, pruned to the GW20 pick.

## Approach

- **No core change.** The widget is a second `CoreActivitySink` on the shell's existing `CoreConnection` (`addSink` / `subscribe` already support several subscribers and unsubscribe only when the last one leaves). The Activity page keeps its own sink.
- **Pure logic first, window last.** Everything that can be decided without a window (entry mapping, order, `+N`, slot geometry, nearest slot, host-app walk) lives in plain types with swift-testing tests. The AppKit panel only draws them.
- **One non-activating `NSPanel`.** It never becomes key or main. It joins all Spaces and sits beside full-screen apps (`canJoinAllSpaces`, `fullScreenAuxiliary`, `stationary`). Its level stays above normal windows and below the menu bar. Its content is SwiftUI composed from `Components` and `Tokens`, so `StyleBoundaryTests` applies.
- **Host app without a process.** `sysctl(KERN_PROC_PID)` reads each parent pid in process, and the walk stops at the first pid that `NSRunningApplication` reports as a `.regular` app. S-R4 holds: nothing is started and nothing is signalled.
- **Phosphor Bold as its own generated set.** The app's content glyphs are Phosphor Duotone (two layers). The four state glyphs are Bold (one layer), so `generate-icons.mjs` gets a third source rather than mixing weights in one enum.

## Tasks

| ID | Task | Serves | Done when |
| --- | --- | --- | --- |
| GL-T1 | `generate-icons.mjs`: third source, Phosphor Bold (`-bold`, one layer) → `Components/StateIconData.swift` with `StateGlyph` (`circleNotch`, `chatCircleDots`, `checkCircle`, `circleDashed`). `IconPolicyTests.sets` gains the set. The Phosphor credit is already in `Credits`. | GW-R2, GW19, GW20 | A rerun gives no diff, and `IconPolicyTests` passes |
| GL-T2 | `Palette`: three state tokens (working, waiting, done) from the mock's muted values. Extend `HuePolicyTests` and `ContrastTests`, and shift a hue slightly if a test fails, recording the change in the handoff. Add one line to `docs/DESIGN-LANGUAGE.md` naming them. | GW-R2, GW19 | Both tests pass, and the values are in the handoff |
| GL-T3 | `Glance/GlanceEntries.swift`: `CoreActivityReport` → ordered entries (state mapping, done ≤ 10 min, no `ended`, waiting-first order, 6 plus `+N`). Tests use synthetic reports. | GW-R2, GW-R3, GW-R4, GW8–GW12 | Tests cover each state, the 10-min edge, 0, 6, 7 and 12 sessions |
| GL-T4 | `Glance/GlanceSlots.swift`: 8 slots for a screen's `visibleFrame`, nearest-slot pick, axis per slot, list direction toward the centre, and saved slot (screen id plus slot) with a main-screen fallback. Tests use fake screen frames, including two screens and a removed screen. | GW-R7, GW13, GW14, GW16 | Tests pass for all 8 slots on 1 and 2 screens |
| GL-T5 | `Glance/HostAppResolver.swift`: parent-pid walk behind a protocol, so tests inject a process table. Live implementation: `sysctl` plus `NSRunningApplication`. With no app it returns nil, and the caller opens Activity at that session through `ShellModel`. | GW-R6, GW5, GW6 | Tests cover the direct parent, a deep chain, a tmux-like chain (nil) and a loop guard |
| GL-T6 | `Glance/GlanceFeed.swift`: owns the widget sink while the switch is on, re-subscribes when the core restarts, and leaves when the switch turns off. | GW-R1, GW-R10 | A test with the fixture core sees the snapshot, and no poll runs after the switch turns off |
| GL-T7 | `Glance/GlancePanel.swift` and `GlanceView.swift`: the panel, the collapsed row or column, the hover list (opens toward the centre, scrolls past a fixed height, closes on Esc or when the pointer leaves), the empty mark, and the rotating ring that stops under Reduce Motion and while hidden. The panel is never key, and clicks outside its frame pass through. | GW-R2–GW-R5, GW-R8, GW-R11 | Headless shots of every mock preset, and `StyleBoundaryTests` passes |
| GL-T8 | Drag: while dragging, an overlay window per screen shows its 8 slots. On release the widget snaps to the nearest slot, and the slot is saved. | GW-R7, GW13 | Manual check on two screens. Placement logic is covered by GL-T4 |
| GL-T9 | App lifecycle and Settings. An `NSApplicationDelegateAdaptor` keeps the app alive when the main `Window` closes (a lone `Window` scene quits by default), and a Dock click reopens the window. Settings gets one `SpaceVibeSwitch`, on by default, stored under a `UserDefaults` key in the `dev.spacevibe.app` domain. | GW-R9, GW-R10, GW17, GW18 | `SettingsTests` covers the default and the toggle. Manual check: close the window and the widget stays |
| GL-T10 | Launch modes: `SPACEVIBE_TEST=1` and fixture shot runs never show the live panel. `SPACEVIBE_SHOT_SCREEN=glance` renders the view headless from synthetic reports. | S-R1, S-R2 | `LaunchModeTests` covers it, and the shots come from the fixture only |
| GL-T13 | Countdown chip and the hover list's Limits group, after the [limit-reset-countdown](../specs/2026-11-19-limit-reset-countdown.md) page work lands (LC8). Draw it into the widget mock first. Reuse that work's window selection and clock text; add a 60 s `limits.read` to `GlanceFeed`, stopped by the switch. | GW21, LC-R5 to LC-R8 | Widget shots of each LC-R5/LC-R6 case beside the mock, and no read with the switch off |
| GL-T11 | Docs: a "Glance widget" section in [activity.md](../internals/activity.md) covering the second sink, the panel that is never key, and the in-process host walk (S-R4). Add the `glance` shot screen to `DESIGN-LANGUAGE.md`. Update `README.md` where it lists features (D12; the repo has no `CHANGELOG.md`). | D9, D12 | `docs-anchors.sh` passes |
| GL-T12 | Verify and hand over (see Verification). `build-review` runs before the owner looks (W24, GW5). The owner's eye approval is the last step, in one batch. | all | Every acceptance row in the spec is checked and reported |

Order: GL-T1, GL-T2 and GL-T3 to GL-T5 are independent. GL-T6 needs GL-T3. GL-T7 needs GL-T1 to GL-T4 and GL-T6. GL-T8 needs GL-T7. GL-T9 and GL-T10 can run beside GL-T7. GL-T13 needs GL-T7 and the countdown page work (LC8). GL-T11 and GL-T12 come last.

## Verification

- `scripts/test.sh`: Go then Swift, `Test run with N tests ... passed` with N above 0. Includes `IconPolicyTests`, `HuePolicyTests`, `ContrastTests`, `StyleBoundaryTests` and `PointerCursorPolicyTests`.
- `scripts/build-app.sh`: `minos 15.0` for the app (B1).
- Headless shots: `SPACEVIBE_SHOT_SCREEN=glance scripts/dev-fixture.sh --shots <scratch>` for every mock preset, placed beside the mock per surface (FE-P4).
- Break test (FE-P3): 12 sessions, the longest titles, Greek and CJK text, no session, all `unmeasurable`.
- The owner's runtime: stop older instances, run `scripts/dev.sh` on this checkout, and test with 2 to 3 real Claude Code and Codex sessions in iTerm, Ghostty and VS Code, plus one inside tmux. Check every spec acceptance row: the 3 s update, the click target, a second screen, a full-screen Space, Reduce Motion, the switch off, and the window closed.
- `build-review` (W24) on the finished branch state, before the owner is asked to look.

## Handoff

2026-11-19: spec decided (GW1 to GW20), mock pruned to the pick, plan written. No code yet. Waiting for the owner's go on the approach.

/goal Build the SpaceVibe session glance widget per docs/plans/2026-11-19-session-glance-widget.md: GL-T1 to GL-T12 done, scripts/test.sh passes with N > 0, every acceptance row in docs/specs/2026-11-19-session-glance-widget.md checked in the owner's runtime with real sessions, build-review passed, owner eye approval recorded.
