# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

`AGENTS.md` above is the source of truth: commands, toolchain rules (B1–B10) and boundary rules (S-R1–S-R6). This file adds only what it does not say.

## Running one test

- **Go, one package or test:** `cd core && SPACEVIBE_TEST=1 go test -count=1 -run TestName ./internal/usage/`. Without `SPACEVIBE_TEST=1` the real-home guard is off (S-R1).
- **Swift, one suite or test:** `scripts/test.sh --filter StyleBoundaryTests` (the struct name). The script passes its arguments to `swift test`, but it still runs the whole Go core first and builds the core binary the Swift tests spawn, so even one suite takes about a minute.
- **Contract tests** (`core/cmd/spacevibe/contract*_test.go`) build the core twice, as shipped and with `-tags contracttest` (debug methods), and compare against `core/testdata/rpc/*.jsonl`. `cd core && SPACEVIBE_TEST=1 go test -count=1 ./cmd/spacevibe -update` rewrites those transcripts. `internal/inventory` and `internal/rules` have their own `-update-*` flags for a few golden files. `scripts/test.sh` checks the frozen goldens against `core/testdata/fixtures/SHA256SUMS` (SV5).
- **UI by hand or as screenshots:** `scripts/dev-fixture.sh` runs the app on a synthetic home; `--shots <dir>` writes headless screenshots, `SPACEVIBE_SHOT_SCREEN` picks the screen. Never test a write with `scripts/dev.sh`, which reads the real config.

## Architecture in one pass

Details: [docs/internals/overview.md](docs/internals/overview.md), then the page per subsystem in [docs/internals/README.md](docs/internals/README.md).

- **Two processes.** The shell (`Sources/SpaceVibe`) spawns the core as a child, `spacevibe rpc`, and talks JSON-RPC 2.0 over stdio. Everything goes through one client in `Sources/SpaceVibe/Core` (`CoreClient`, `CoreConnection`, DTOs in `CoreTypes*.swift`). The shell links no engine code; the wire contract is [core-protocol.md](docs/internals/core-protocol.md).
- **The core owns every read and write.** `core/cmd/spacevibe` is the entry point and RPC wiring, and `core/internal/<subsystem>` holds the logic (`inventory`, `usage`, `activity`, `limits`, `rules`, `mutate`, `clean`, …). Unreadable files come back as `problems`, never as an empty result.
- **Every write is journaled.** It takes the write lock (an in-process mutex plus `flock` on `<data>/write.lock`), edits through the atomic-write path in `fsx` and returns a journal reference. Undo is `journal.undo` on that reference. Stop is the one action outside the journal.
- **Usage is streamed, Activity is a subscription.** `usage.scan` sends `usage/progress`, and the core keeps the result for `loadout.rows`. Activity sends one full report, then a new full report only when something changed.
- **Two UIs live side by side.** The shipped v5 UI has one folder per page (`Agents`, `Activity`, `Limits`, `Settings`, `Glance`, …), and each page reads its own data. The redesign, behind `SPACEVIBE_REDESIGN=1` in a development build (FE-P9), is the frame in `Sources/SpaceVibe/Shell` (`AppFrame`, `Frame*.swift`), with one `FrameStore` for the whole window ([shell-data-flow.md](docs/internals/shell-data-flow.md)). Before editing a screen, check which of the two it belongs to.
- **The Go code ports a deleted Swift/Node engine.** The goldens were recorded from that engine, so JSON, text trimming and sorting, regex, paths and float printing must match it, not Go's defaults. The list of traps is in [overview.md](docs/internals/overview.md#swift-to-go-traps). Config JSON goes through `ojson`, never a struct.

## Docs layout

Requirements are in `docs/specs/`, execution and handoffs in `docs/plans/`, and the backlog in `docs/BACKLOG.md` (B10). [docs/README.md](docs/README.md) names the one current page per topic. Owner decisions are cited by id (`D…`, `SV…`, `RD…`, `SK…`) and are never narrowed.
