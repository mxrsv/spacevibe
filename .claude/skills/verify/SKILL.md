---
name: verify
description: Prove a SpaceVibe change works, in the background and against the synthetic fixture home — tests, headless screen renders of the SwiftUI app, the Go core CLI, and the site gates. Use before reporting a change done, before a commit or PR, or when the owner asks whether something works. Never opens a window and never reads the real ~/.claude or ~/.codex.
---

# Verify SpaceVibe

Run everything in the background. No window on the owner's screen, no real config (S-R1), no Keychain. A check that can only run in a window → stop and ask the owner first.

## Never, unless the owner asks

- `scripts/dev.sh`: opens a window, reads the real `~/.claude` and `~/.codex`, and `pkill`s the owner's running SpaceVibe.
- `scripts/dev-fixture.sh` with no flag (run mode opens a window); `open build/SpaceVibe.app`.
- `scripts/build-app.sh --distribution`, `scripts/test-update.sh`, `scripts/release.sh`, `scripts/generate-update-feed.sh`, Sparkle `generate_keys` (Keychain, signing; B8, B9).
- Bare `swift test` (B2), or writing into `/private/tmp/spacevibe-fixture-home` (shared, read-only; B6).

## 1. Cheap checks first

Pick by what the change touches; run all of them before a commit.

| Change touches | Command | Pass when |
| --- | --- | --- |
| `core/` only | `cd core && go vet ./... && SPACEVIBE_TEST=1 go test -count=1 ./...` | exit 0 |
| `Sources/`, `Tests/`, or both | `scripts/test.sh` | exit 0 and `Test run with N tests ... passed` with N > 0 |
| `site/` | `cd site && npm ci && npm run lint && npm run build && cd .. && node --test site/tests/*.test.mjs` | exit 0 |

A failure in files the change did not touch is pre-existing: report it, leave it. Never `git stash` or reset to find out.

## 2. Drive the app without a window (screen renders)

`--shots` builds a debug app, generates a synthetic home in `$TMPDIR`, renders the chosen screens with `ImageRenderer` and exits: no window, no Dock icon, fake process list. The fixture is deleted on exit.

```bash
OUT=$(mktemp -d "${TMPDIR:-/tmp}/spacevibe-verify.XXXXXX")
SPACEVIBE_SHOT_SCREEN=<screen> scripts/dev-fixture.sh --shots "$OUT" > "$OUT.log" 2>&1; echo "exit=$?"
tail -20 "$OUT.log"; ls "$OUT"   # <name>-dark.png and <name>-light.png per image
```

- Pass: `exit=0` and PNGs in `$OUT`. Never pipe the run into `tail` or `head` directly: the pipe hides a failed build behind exit 0 and an empty folder.
- `error: no such module 'Sparkle'` (or another missing package module) comes from a stale shared build folder `/tmp/spacevibe-build-dev-fixture`, not from the change: rerun with a fresh one, `SPACEVIBE_BUILD_PATH=$(mktemp -d)` (a cold build, a few minutes). Do not delete the shared folder; another session may be using it.
- One screen key renders several images (`shell` gives the panes, palette, settings and toasts).

- Screens: `shell`, `skills`, `subagents`, `hooks`, `rules`, `activity`, `limits`, `settings`, `glance`. With `SPACEVIBE_REDESIGN=1`, more keys (inbox, clean, frame pages, gallery); `SPACEVIBE_SHOT_STATE` picks a state. Full list: `Sources/SpaceVibe/Gallery/ShotRenderer.swift`.
- Rules page in dark and light plus Codex variants: `scripts/rules-shots.sh "$OUT"`.
- Read each PNG yourself (Read tool) and compare it with the expected result below and with the page's mock or spec.
- Limit: `ImageRenderer` runs no `.task` and draws no `TextField` or system popover. A change that lives there (typing, the command palette, a popover, async loading) cannot be proven by a render: say so in the report and cover its logic with a test in `Tests/SpaceVibeTests` (uses `CoreFixtureHome`).

## 3. Drive the Go core like a client (backend check)

```bash
scripts/dev-fixture.sh --prepare        # builds, creates the fixture, prints the exports; keeps the fixture
# paste the printed exports into the same shell, then:
"$SPACEVIBE_CORE_BINARY" inventory --json | head -c 2000
"$SPACEVIBE_CORE_BINARY" rules --json
```

- One-shots: `inventory`, `usage`, `activity`, `limits`, `rules`, each `--json [--dir <path>]`; exit 0 ok, 1 or 2 error. `usage` may write the usage cache only.
- RPC: `"$SPACEVIBE_CORE_BINARY" rpc` speaks NDJSON JSON-RPC 2.0; the first call must be `initialize` with protocol version 1 (`docs/internals/core-protocol.md`).
- Check the JSON for the field or row the change adds, and that no real home path or user name appears (S-R2).
- `--prepare` leaves the fixture in `$TMPDIR/spacevibe-fixture.*`: delete the one this run made when done.

## 4. Feature map

| Flow | How | Expected result |
| --- | --- | --- |
| App shell and sidebar | render `shell` | every page in the sidebar, fixture names, no empty or error state |
| Inventory pages | render `skills`, `subagents`, `hooks`, `rules` | rows from the fixture home, Claude and Codex both present where the page shows both |
| Activity and limits | render `activity`, `limits` | sessions from the fake process list, limit bars drawn, no real process |
| Settings | render `settings` | every section drawn, values from the fixture |
| Glance widget | render `glance` | state glyphs per session |
| Core contract | `scripts/test.sh` runs `core/cmd/spacevibe/contract*_test.go`; one-shot JSON above | JSON shape the Swift `CoreClient` expects |
| Statusline | `scripts/test-statusline.sh` | exit 0 (synthetic homes only) |
| Site landing | site gates above | `landing-facts` and `redirects` tests pass; do not deploy (landing spec deploy gates) |

Always run the flows the change touches, plus `shell` and `scripts/test.sh` whenever `Sources/` changed.

## 5. Report and clean up

- Per flow: command, pass or fail, what the render or JSON showed, and any part a render cannot prove.
- Three fix rounds still failing → stop and report what was tried.
- Do not edit the checks that judge this change (tests, goldens, this skill, `landing-facts.test.mjs`) to make it pass; a wrong check is fixed in its own change, named to the owner.
- Renders from the fixture can be committed only where the repo already keeps them; anything else goes in the gitignored `shots/` or is deleted. Delete `$OUT` unless the report links images for the owner to look at.
- Commit trailer: `Verified: <what ran>`, e.g. `Verified: scripts/test.sh + renders skills,rules`.
