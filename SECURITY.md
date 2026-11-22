# Security policy

SpaceVibe reads and edits the local configuration of Claude Code and Codex, and can stop a running
session. The boundaries it keeps are written down as rules in [AGENTS.md](AGENTS.md); a way around
one of them is a security problem, not an ordinary bug.

## Reporting a vulnerability

Report it privately through GitHub:
[report a vulnerability](https://github.com/mxrsv/spacevibe/security/advisories/new). Only the
maintainer sees it. Do not open a public issue for a problem that is not fixed yet.

Include what you can of:

- the SpaceVibe version (About panel) or the commit you built from;
- the macOS version;
- the exact steps, with a temporary home folder rather than your real `~/.claude` or `~/.codex`
  (set `HOME`, `CLAUDE_CONFIG_DIR`, `CODEX_HOME` and `SPACEVIBE_HOME`, rule S-R1);
- what was written, read, run or sent that should not have been.

## What counts

- A write outside what the app manages: anything beyond the skills, subagents, hooks, permission
  rules and status line entry of the two CLIs and the app's own data folder
  ([where each write lands](docs/internals/mutations.md#where-each-write-lands)), or a Clean move
  that does not end in the Trash ([what moves where](docs/internals/clean.md#what-moves-where)).
- The app executing a hook or a recorded command (S-R4), or signalling a process other than the
  session the user chose to stop (S-R6).
- A secret value from a settings file shown in the interface or written to a log (S-R3).
- Any network request other than the update check and download, or any listening socket (S-R5).
- An update that installs something not signed with the project's update key (B8).

A wrong count, a missing row or a crash that changes nothing on disk is a normal bug:
[open an issue](https://github.com/mxrsv/spacevibe/issues/new/choose).

## What to expect

SpaceVibe has one maintainer, so these are best-effort, and security reports come before other work.

- An acknowledgement within 7 days.
- A status update within 30 days when a fix or mitigation is not ready by then.
- A fix shipped as a new version, with credit to you in its release notes unless you prefer none.

## Supported versions

SpaceVibe is pre-release: fixes go into the `main` branch and the next build. `v0.1.0`, shipped
under a former product name, is deprecated and receives none.
