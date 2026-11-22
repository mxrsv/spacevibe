# SpaceVibe

[![core](https://github.com/mxrsv/spacevibe/actions/workflows/core.yml/badge.svg)](https://github.com/mxrsv/spacevibe/actions/workflows/core.yml)
[![swift](https://github.com/mxrsv/spacevibe/actions/workflows/swift.yml/badge.svg)](https://github.com/mxrsv/spacevibe/actions/workflows/swift.yml)
[![License: GPL-3.0-only](https://img.shields.io/badge/license-GPL--3.0--only-blue)](LICENSE)
[![macOS 15+](https://img.shields.io/badge/macOS-15+-black?logo=apple)](#build-from-source)

A native macOS app that shows and edits what Claude Code and Codex CLI are equipped with: every skill, subagent, hook and rule, joined to how often each one actually ran according to local logs. It answers three questions a pile of installed extras never does: what is never used, what one CLI has and the other lacks, and which hook command fires on which event. The full product record is [PRODUCT.md](PRODUCT.md).

**Status: pre-release.** No public build exists yet. `v0.1.0` shipped under a former product name and is deprecated; it does not update to SpaceVibe ([B3, B9](AGENTS.md)).

## What is in the app

The shipped interface is described in the [design language](docs/DESIGN-LANGUAGE.md): three pages (Agents, Activity, Limits) plus Settings and the session widget, the same in development and distribution builds.

- **Agents**: Skills, Subagents, Hooks and Rules for both CLIs in one inventory, each row with its usage. Adding or removing is one step with Undo.
- **Activity**: the Claude Code and Codex sessions running now, and `Stop` for one of them.
- **Limits**: how much of each subscription usage limit window is left, from local data only, with a countdown before a 5-hour or weekly reset (lead for the weekly one in Settings > Limits).
- **Session widget**: a small strip over every app, in a corner or edge slot you drag it to, with one state icon and CLI logo per live session; hover lists them, a click brings forward the app that runs the session. A pill beside it counts down to a limit reset. On by default, switched in Settings > Appearance.

## What it does not do

- It opens no network listener, and its only requests check for and download updates ([S-R5](AGENTS.md)). No account, no telemetry.
- It never executes a hook or a recorded command ([S-R4](AGENTS.md)).
- It writes only to the skills, subagents, hooks, permission rules and status line entry of the two CLIs' configuration and to its own data folder ([where each write lands](docs/internals/mutations.md#where-each-write-lands)); it never writes MCP servers, the model, `CLAUDE.md` or `AGENTS.md`, and never reads secret values into the UI or a log ([S-R3](AGENTS.md), [PRODUCT.md](PRODUCT.md)).

## Build from source

Requirements: macOS 15 or later, the Xcode Command Line Tools (Xcode itself is not needed) and Go 1.26.

| Command | Purpose |
| --- | --- |
| [`scripts/test.sh`](scripts/test.sh) | Go tests, then Swift tests, all against temporary folders. Never run bare `swift test` (B2) |
| [`scripts/dev.sh`](scripts/dev.sh) | Build, sign and relaunch. It reads the real `~/.claude` and `~/.codex` unless the environment points elsewhere |
| [`scripts/build-app.sh`](scripts/build-app.sh) | Release build into `build/SpaceVibe.app` |

Every other command and the toolchain rules are in [AGENTS.md](AGENTS.md); the release steps are in the [release runbook](docs/operations/release.md).

## Repository

| Path | Holds |
| --- | --- |
| [`core/`](core) | The core: the Go engine, built as the `spacevibe` binary |
| [`Sources/SpaceVibe`](Sources/SpaceVibe) | The shell: the SwiftUI app, UI only |
| [`Tests/SpaceVibeTests`](Tests/SpaceVibeTests) | Swift tests for app logic that needs no window |
| [`site/`](site/README.md) | The public page for `spacevibe.dev`, independent of the Swift build |
| [`docs/`](docs/README.md) | [Internals](docs/internals/README.md), the design language, the release runbook, specs and plans |

Terms are fixed in [GLOSSARY.md](GLOSSARY.md): a CLI is Claude Code or Codex, and is never called an agent.

## Contributing

A bug or an idea: [open an issue](https://github.com/mxrsv/spacevibe/issues/new/choose). A question: [Discussions](https://github.com/mxrsv/spacevibe/discussions). A security problem goes privately, as the [security policy](SECURITY.md) describes. Pull requests are welcome; read [CONTRIBUTING](CONTRIBUTING.md) first, because the interface follows recorded decisions and the tests must never touch a real configuration.

## Licence

SpaceVibe is open source under [GPL-3.0-only](LICENSE) (SV18). The code is open; the SpaceVibe name and app icon are not, see the [trademark policy](TRADEMARK.md). Third-party notices are in [`Resources/Licenses`](Resources/Licenses) and in the app's About panel ([`Credits.swift`](Sources/SpaceVibe/App/Credits.swift)).

SpaceVibe is an independent project. It is not affiliated with, endorsed by or sponsored by Anthropic or OpenAI; Claude Code and Codex are their products.
