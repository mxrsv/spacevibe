# Reins: internals reference pages

Requirements: agreed in chat on 2026-11-07, no spec. Scope: one reference page per `ReinsCore` subsystem, so an agent reads only the page for the code it touches. Model: magpie's `docs/subsystems/` (a page per subsystem with a responsibilities and sources-of-truth table, an index, "update the page in the same PR") and orca's "read only when the task touches it" index.
Checkout: `spacevibe-reins` on `main`. Commit with `git commit -- <paths>` only.
Status: T1 to T8 written and committed (T1, T2 on 2026-11-07; T3 to T8 on 2026-11-15). Open: the owner's check in Acceptance that each page lets an agent skip unrelated code. Approved so far: the model above and the `AGENTS.md` read-when list (done 2026-11-07).

## Directory (D3)

`docs/internals/` was approved by the owner on 2026-11-07 (D64).

## Page shape

Each page, English, under `docs/internals/<subsystem>.md`:

1. One paragraph: what the subsystem is for.
2. Table: part, responsibility, source (link to file or named symbol).
3. Source of truth: which file or log each fact is read from.
4. Main runtime paths and state transitions (usage cell states, journal write, lock).
5. Constraints and traps that code does not show (for example the hook identity hash, `.jsonl.zst` rollouts).
6. Failure behavior, compatibility, and the test command that exercises it.

Link to symbols, do not copy implementation. Use the terms of [GLOSSARY.md](../../GLOSSARY.md).

## Tasks

| Task | Page | Source area |
| --- | --- | --- |
| T1 | `docs/internals/README.md`: index table (subsystem to page), maintenance rule | none |
| T2 | `inventory.md` | `core/internal/inventory`, `core/internal/roots`, `core/internal/hashes` |
| T3 | `usage.md` | `core/internal/usage`, `core/internal/logs`, `core/internal/pricing` |
| T4 | `mutations.md` | `core/internal/mutate`, `core/internal/fsx`, `core/internal/ojson`, `core/internal/toml` |
| T5 | `limits.md` | `core/internal/limits`, `core/internal/statusline` |
| T6 | `activity.md` | `core/internal/activity`, `core/internal/proc`, `core/internal/textjs`, `core/internal/redact` |
| T7 | `rules.md` | `core/internal/rules` |
| T8 | Move "Known traps" from `AGENTS.md` into the matching pages and link back; run the doc scripts | `AGENTS.md` |

Each of T2 to T7 is one commit. Write from the code and the Node oracle's behavior, not from memory; a claim a page cannot link to is left out (D6). Pages describe current behavior only; planned work stays in specs and plans.

## Verification

- `bash ~/.claude/scripts/docs-compliance.sh` and `bash ~/.claude/scripts/docs-anchors.sh` pass with no new warning.
- Every source link in a page resolves.
- T8: each trap exists in exactly one place.

## Acceptance

- Every `ReinsCore` file belongs to one page's source column or is named as out of scope in the index.
- `AGENTS.md` points to the index, and no fact in a page is duplicated in `AGENTS.md`.
- Owner agrees the pages let an agent skip unrelated code, on one sample task per page.

## Handoff

2026-11-07: plan written. T1 (`README.md`) and T2 (`inventory.md`) written and committed. Next: T3, `usage.md`.

2026-11-15: T3 to T8 done on `main`, one commit each: `744c13a` usage, `05ca4fc` mutations, `4afebb6` limits, `2ce4d0c` activity, `3898208` rules, then T8. The engine is the Go core now, so the task table names Go packages instead of the Swift files it listed. Each page was written by a subagent from the code and its tests, then checked here against the source for its limits, timeouts and merge rules.

- `rules.md` documents permission Rules, as GLOSSARY.md defines the word. No code under `core/internal` reads or writes `CLAUDE.md` or `AGENTS.md`, so there is no Instructions page to write.
- T8: the two "Known traps" in `AGENTS.md` are pointers now (`usage.md` for `.jsonl.zst`, `inventory.md` for hook identity). `overview.md` said log lines go up to 32 MiB; that holds for the usage scan only, and the line now names the 16 MiB cap of the tail readers too.
- The index lists the four packages with no page (`cmd/spacevibe`, `config`, `coreerr`, `identity`) and puts `hashes` under `inventory.md`, which covers Acceptance line 1.
- Found and left as they are, outside this plan: PRODUCT.md names status-line snapshots as the only Claude Code source of limits, while the core reads Claude's own usage cache first (`core/internal/limits/claude-cache.go`); 22 Go files still carry "ported from `Sources/ReinsCore/...`" comments that point at files no longer in the repo.
- Verification on 2026-11-15: `docs-compliance.sh` and `docs-anchors.sh` exit 0; the Go tests of every documented package pass under `SPACEVIBE_TEST=1`.
- Remaining: Acceptance line 3, the owner's check on one sample task per page.

/goal Write the Reins internals reference per docs/plans/2026-11-07-reins-internals-docs.md: tasks T1 to T8 in order, one commit each. Done means every ReinsCore file is covered by one docs/internals page, the docs-compliance and docs-anchors scripts print no new warning, every source link resolves, and the AGENTS.md "Known traps" live only in their pages.
