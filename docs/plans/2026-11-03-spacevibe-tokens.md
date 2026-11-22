# SpaceVibe: Tokens history and accounting

Record: Active task plan
Started: 2026-11-03
Updated: 2026-11-12 after the approved TokenTracker scout
Base revision: `b877e3a37dc511eec9e28f2fc37db3b7bde4cee1`

## Requirements reference and delivery scope

Requirements: [Tokens](../specs/2026-11-02-spacevibe.md#tab-tokens), [Board direction](../specs/2026-11-02-spacevibe.md#interface) and [AC3, AC5, AC6, AC8, AC9](../specs/2026-11-02-spacevibe.md#acceptance-criteria).
Architecture: [Go core and SwiftUI shell](../internals/overview.md); vocabulary: [D65](../specs/2026-11-06-spacevibe-linear-identity-decisions.md) and [glossary](../../GLOSSARY.md).
The current [design language](../DESIGN-LANGUAGE.md) supplies shared controls and styling.
This is the existing Tokens execution record, not a new feature proposal. The owner approved the scout shortlist and then its implementation direction on 2026-11-12. No application implementation has landed for this plan.

The accepted Board reference remains [the synthetic mock](../../mocks/tokens-board/index.html), with [dark](../../mocks/tokens-board/shot-dark.png) and [light](../../mocks/tokens-board/shot-light-price.png) targets. `mocks/tokens-board/` stays tracked until the Tokens page is decided in the app-wide layout grilling (owner, 2026-11-20, "ok" to DN-Q6 of the docs-normalization plan (record removed 2026-11-22, in git history)); before that it was to be deleted when T8 passes.
Use its information arrangement inside the current shell; do not restore the obsolete shell or copy old font/spacing literals. Do not redesign other pages.
The spec's excluded features remain excluded; Limits pace, menu-bar additions and pricing network fetches are not tasks here.
Owner eye approval stays at T8 after the implementation, not between tasks.

## Current implementation and scout decisions

| Area | Current target, checked at base revision | Decision |
| --- | --- | --- |
| Accounting | [Claude fold](../../core/internal/activity/fold-claude.go) keeps per-message maxima; [Codex fold](../../core/internal/activity/fold-codex.go) deduplicates totals and subtracts cached input | **Adapt:** extract existing behavior, then correct only independently evidenced cases |
| History | [Usage scanner](../../core/internal/usage/scanner.go) rebuilds its cache from remaining files; [cache](../../core/internal/usage/cache.go) is disposable | **Adapt:** add a separate durable ledger; never reuse the disposable cache as history |
| Coverage | [Activity](../../core/internal/activity/report.go) limits history to 14 days and tails large logs | **Reuse the fold, not Activity reports:** Tokens streams full supported logs through [logs](../../core/internal/logs/log-files.go) |
| Persistence | [Atomic writes](../../core/internal/fsx/atomic-write.go), [write lock](../../core/internal/fsx/write-lock.go), [guarded roots](../../core/internal/roots/guard.go) exist | **Reuse:** no database, daemon or new persistence dependency initially |
| Query and prices | [Pricing](../../core/internal/pricing/pricing.go) embeds [the table](../../core/internal/pricing/pricing.json); unknown price yields no estimate | **Adapt:** query priced subtotal and unpriced coverage separately; preserve Activity's cost contract |
| UI | [TabRegistry](../../Sources/SpaceVibe/Shell/TabRegistry.swift) has Agents, Activity and Limits | **Adapt:** add TokenUsage as the fourth page after core/query integration |
| Reference breadth | Online quotas, cloud and gamification are outside the target's requirements | **Skip:** no runtime architecture or feature expansion from TokenTracker |

Reference revision: TokenTracker `a2483443ee2f1fe8d77955edccc96b21c8ac62ec`, MIT root license; ideas and fixture scenarios only, no copied code.
Source inspection established the following constraints, not measured runtime accuracy:

- [Queue keys](https://github.com/xiufengsun/TokenTracker/blob/a2483443ee2f1fe8d77955edccc96b21c8ac62ec/src/lib/local-api.js#L355) and [reader](https://github.com/xiufengsun/TokenTracker/blob/a2483443ee2f1fe8d77955edccc96b21c8ac62ec/src/lib/async-queue-reader.js#L68) use last-write-wins snapshots; duplicate keys are not additive deltas.
- [Claude normalization](https://github.com/xiufengsun/TokenTracker/blob/a2483443ee2f1fe8d77955edccc96b21c8ac62ec/src/lib/rollout.js#L5438) separates reasoning from output; Codex output already includes reasoning.
- [Compaction handling](https://github.com/xiufengsun/TokenTracker/blob/a2483443ee2f1fe8d77955edccc96b21c8ac62ec/src/lib/codex-usage-record.js#L39) and [tests](https://github.com/xiufengsun/TokenTracker/blob/a2483443ee2f1fe8d77955edccc96b21c8ac62ec/test/codex-token-usage-record.test.js#L211) identify useful cases. They do not make every reference heuristic correct.
- [Claude dedup](https://github.com/xiufengsun/TokenTracker/blob/a2483443ee2f1fe8d77955edccc96b21c8ac62ec/src/lib/rollout.js#L3209) keeps the first usable snapshot. Do not replace the target's maxima with it.
- [UTC half-hour buckets](https://github.com/xiufengsun/TokenTracker/blob/a2483443ee2f1fe8d77955edccc96b21c8ac62ec/src/lib/rollout.js#L4704) still lose local-day boundaries at quarter-hour timezone offsets. Preserve original timestamps instead.
- Reference project aggregates require public-repository verification in that path and do not retain a model dimension. Use local session metadata for SpaceVibe projects; do not import that restriction.
- Queue append and cursor generation commits are separate operations. SpaceVibe should publish rows and scan metadata in one atomic document.

## Approach

### Location and shared accounting

New code follows the existing layout: planned `core/internal/tokens/` for accounting, ledger and query with adjacent Go tests; planned `Sources/SpaceVibe/TokenUsage/` for the screen and its model; planned `CoreTypesTokens.swift` under the existing shell `Core/`; Swift tests under `Tests/SpaceVibeTests/`.
These paths are proposed, not existing implementation. Use small responsibility-named files such as `counts.go`, `fold-claude.go`, `fold-codex.go`, `ledger.go`, `scan.go` and `query.go` only when their task needs them.
The Go tokens package must not import Activity: Activity may consume its pure accounting functions, while its tools, failures and command text stay outside the ledger.
Shared Swift chart primitives belong in the existing `Components/`, not styled inside the screen.

First extract current counting behavior with no change to existing Activity projections or frozen goldens. Keep cache-write-long metadata for pricing even though the UI has four token kinds.
Later accounting corrections get explicit synthetic inputs, expected outputs and dedicated tests; never regenerate frozen fixtures to hide a change.
For unsupported or inconsistent records, expose coverage problems rather than inventing a zero or trusting an inconsistent counter.

### Timestamp, identity and attribution

Persist normalized usage contributions with their source UTC timestamps, CLI, logical source/session identity, model, project identity, counters and completeness/version metadata.
Group by the requested local calendar at query time; no persisted hour/day rollup is the only source of truth.
A repeated response's counters reconcile at its original established timestamp; do not shift old usage to the day a file was rescanned.
Source identity separates a parent session from its child transcript, while query session counts use the parent session identity.

Prefer recorded session/transcript identity, namespaced by CLI. Keep source paths/fingerprints as locations of that identity, not its primary key.
Plain and compressed representations of the same identifiable source merge into one contribution; copies/renames with the same recorded identity do not add usage.
For legacy sources lacking stable identity, use a scoped path identity with normalized log suffix, retain it across encoding changes, and report unresolved relocation/identity conflicts. Never equate unrelated logs solely by basename or matching totals.
Do not introduce global cross-session Claude message dedup or TokenTracker's fork timing heuristic in this slice. The previously accepted cross-session duplication limit remains a documented parity difference; exact copies of one logical source are a separate case.
Codex compaction response identity must be reconciled across related parent/fork records without duplicating independently new responses.
Use cwd plus recorded worktree hints for project identity and the existing [ProjectName behavior](../../core/internal/activity/project-name.go) for display. T3 extracts only the shared naming/worktree logic and its required matchers into a planned lower-level `core/internal/projectname/` package, consumed by Activity and Tokens; Tokens must not import Activity and create a cycle. A display basename is not a project key; private and non-Git projects remain eligible.
Missing or invalid usage timestamps produce incomplete temporal coverage, never a fabricated event date from the file mtime. A repeated response with inconsistent attribution preserves its committed contribution and reports the conflict.

### Ledger transaction and failure behavior

Start with one versioned `token-ledger.json` under resolved `Roots.Data`, mode `0600`. It contains contributions and their scan metadata in one snapshot.
Use streaming log reads and cancellation outside the write lock. At publication, acquire the existing write lock, reread/validate the ledger generation, then merge or retry if another process published. Do not overwrite a concurrent writer with a stale snapshot.
Publish through `fsx.AtomicWrite` with read-back validation; update the in-memory committed view only after success. Return a fixed error on failure, never log file contents.
Keep the old ledger on cancellation, partial decode/decompression, invalid future schema, or conflicting source identity. A skipped oversized line is incomplete coverage, not a successful full read.
Missing/unreadable sources preserve their committed contributions. A changed source is not blindly replaced:
- New proven events and higher observations of an already identified response may add usage.
- Missing events after truncation do not subtract history.
- Conflicting timestamp/model/project attribution, lower corrected counters or an incompatible parser reinterpretation keep the affected committed contribution and surface a problem. Automatic history repair/rewrite is outside this slice.
- A parser-version change refolds available logs into a candidate and applies these same checks; absent logs retain their prior provenance and version.
Do not solve corrections with a fieldwise maximum over whole-file aggregates.

Corrupt history is preserved in place and reported; refuse to overwrite it. A retry may reread repaired history. Do not silently create a fresh empty ledger or discard unavailable historical rows.
Existing files must not become more permissive when rewritten. No app configuration journal entry is created for a scan: this is the app's derived history, not a CLI configuration edit.
Measure synthetic scan time, warm-read time and ledger size before considering a different storage format; do not assert performance from architecture alone.

### Query and protocol boundary

Proposed additive methods: `tokens.scan` with request-correlated `tokens/progress`, and `tokens.query` over the last committed ledger.
Do not change `usage.scan`, which serves inventory counts. Reuse its cancellation/progress pattern.
Query inputs select period and optional day/model/project scope plus an explicit IANA timezone. Reject invalid inputs and support historical DST rules; do not pass only today's UTC offset.
Return period summary independently of the selected scope, scoped series/rankings, per-CLI coverage start, distinct session counts, priced subtotal, unpriced token coverage, source freshness and problems.
One scan at a time; reads during a scan use the last committed generation with a scanning indicator. With no generation, show pending rather than zero.
An additive method set retains the current wire version only if existing initialize/method contracts remain compatible; prove this with old transcript tests and the method-table gate.
The shell owns presentation/filter state only; no token accounting, filesystem reads or pricing arithmetic in SwiftUI.

## Tasks

- [x] **T0 — Historical CI prerequisite**
  - Completed 2026-11-03: run 41500297865 recorded 267 Swift tests, minos 15.0 and 10 screenshots. This is historical evidence, not a current pass.
  - Rechecked 2026-11-12: [Swift workflow](../../.github/workflows/swift.yml) already conditionally renders Tokens when TokenUsage exists; the screenshot renderer still needs its Tokens case. Local macOS verification is available; the old cloud-only restriction is obsolete.

- [ ] **T1 — Accounting fixtures and shared extraction** (AC3, AC8)
  - Files: new `core/internal/tokens/` counting files/tests; existing [Activity folds](../../core/internal/activity), [pricing](../../core/internal/pricing/pricing.go). Depends on: none.
  - Add independent synthetic expected values for the matrix below; separate characterization of existing behavior from proposed compatibility corrections.
  - Extract existing counting without moving Activity UI/session-control logic. Reuse the existing full-log reader for later history scanning.
  - Verify: from `core/`, `SPACEVIBE_TEST=1 go test -count=1 ./internal/tokens ./internal/activity ./internal/pricing`; frozen Activity goldens stay byte-identical. New correction cases remain visibly pending until T1a.

- [ ] **T1a — Evidence-backed compatibility and coverage** (AC3, AC8)
  - Files: T1 accounting files/tests and affected Activity integration tests. Depends on: T1.
  - Resolve compaction counted/not-counted-by-cumulative, response identity and record-only state across read boundaries.
  - For last-only usage, cache-write fields and inconsistent last/total, verify the producer schema at implementation time using primary sources or approved synthetic captures. If a shape cannot be supported safely, preserve known counts and expose incomplete coverage; do not infer a producer contract solely from TokenTracker.
  - Missing identities never all collapse into one synthetic response. Do not replace working interleaved-stream handling without a failing discriminating fixture.
  - Verify: the T1 command plus chunk-boundary, model-change and malformed-input cases; freeze files remain unchanged.

- [ ] **T2 — Durable ledger and scan lifecycle** (AC3, AC5, AC9)
  - Files: new token ledger/scan/identity files/tests; reuse [roots](../../core/internal/roots/roots.go), [logs](../../core/internal/logs/log-files.go) and [fsx](../../core/internal/fsx). Depends on: T1a.
  - Implement the transaction and failure rules above, progress, cancellation and source identity. Do not persist prompts, responses or commands.
  - Verify: `SPACEVIBE_TEST=1 go test -count=1 ./internal/tokens ./internal/logs ./internal/fsx ./internal/roots` from `core/`.
  - Cases: repeat/append; delete; inode replacement; plain→zstd; copy/rename; same basename in unrelated projects; child transcripts; truncated file; partial/oversized line; corrupt zstd/ledger; permission errors; cancellation; failed write; concurrent publication; parser-version conflict. Assert mode 0600 and unchanged committed bytes on failure. Use temporary homes only.

- [ ] **T3 — Local-calendar query and estimated costs** (AC5, AC8, AC9)
  - Files: token query/tests; planned `core/internal/projectname/` extracted from Activity with its naming tests/callers; existing [price table](../../core/internal/pricing/pricing.json). Depends on: T2.
  - Query full period and intersected filters from one ledger, including unknown project/model and priced/unpriced coverage. Count sessions once within each requested scope.
  - Audit coverage of the shipped price table; update only verified vendor rates with source/date, never fetch at runtime. Preserve Activity's unknown-price contract.
  - Verify: from `core/`, `SPACEVIBE_TEST=1 go test -count=1 ./internal/tokens ./internal/projectname ./internal/activity ./internal/pricing`, with fixed time, timezone and prices: UTC+07, +05:30, +05:45, DST, timezone change after log deletion, sessions spanning days/models, missing timestamps, empty data, no price and mixed price coverage. Existing frozen fixture values are not rewritten.

- [ ] **T4 — RPC and Swift contract** (AC3, AC5, AC8, AC9)
  - Files: existing [methods](../../core/internal/rpc/methods), [method list](../../core/internal/rpc/methods.go), [protocol](../internals/core-protocol.md), [CoreService](../../Sources/SpaceVibe/Core/CoreService.swift), [CoreClient](../../Sources/SpaceVibe/Core/CoreClient.swift), [CoreConnection](../../Sources/SpaceVibe/Core/CoreConnection.swift); new token DTOs/tests. Depends on: T3.
  - Wire scan/query, lifecycle shutdown, cancellation, stale/pending/errors and request-correlated progress. Update the method table and test doubles as well as production callers.
  - Add synthetic request/response examples to [RPC transcripts](../../core/testdata/rpc); extend [DTO tests](../../Tests/SpaceVibeTests/CoreTypesTests.swift). Existing transcripts advertise the complete method list during initialize: update those lists for the additive methods and inspect the diff, keeping all other legacy payloads unchanged. These protocol transcripts are distinct from the immutable files under `core/testdata/fixtures/`.
  - Verify: `scripts/test.sh` → Go vet/tests, fixture hashes and a Swift test count above zero. Check compatibility of existing clients/transcripts, not merely new DTO decoding.

- [ ] **T5 — Shared UI primitives** (AC5, AC6)
  - Files: existing [Components](../../Sources/SpaceVibe/Components), [design tokens](../../Sources/SpaceVibe/Tokens), [gallery](../../Sources/SpaceVibe/Gallery). Depends on: T3's query shapes.
  - Reuse CLIMark, FilterChip, current layout/typography and accessible controls. Add only missing shared bar/axis/row primitives; do not import mock code or add Swift Charts.
  - Compose the approved Board arrangement using current design-language roles. New primitives land before the screen consumes them.
  - Verify: `scripts/test.sh` → style boundary, contrast, hue, pointer and relevant state checks pass; synthetic gallery rendering covers new primitives.

- [ ] **T6 — Tokens page and screenshot integration** (AC5, AC6)
  - Files: new `Sources/SpaceVibe/TokenUsage/` and Swift tests; existing [TabRegistry](../../Sources/SpaceVibe/Shell/TabRegistry.swift), [ShotRenderer](../../Sources/SpaceVibe/Gallery/ShotRenderer.swift), [fixture wrapper](../../scripts/dev-fixture.sh), [Swift workflow](../../.github/workflows/swift.yml). Depends on: T4, T5.
  - Build the spec's Board, filter chips, palette/keyboard actions and all pending/empty/partial/error/unpriced states. Add Tokens as the fourth page; preserve existing pages.
  - Register the Tokens screenshot selector and self-contained synthetic cases. New fixtures must not rewrite frozen fixture trees.
  - Run impeccable distill/clarify on the new surface. Update applicable living docs when the feature is actually wired, with code links; no claim of shipped behavior before then.
  - Verify: `scripts/test.sh`, `scripts/build-app.sh` (app minos 15.0), then `SPACEVIBE_SHOT_SCREEN=tokens scripts/dev-fixture.sh --shots /tmp/spacevibe-tokens-shots`. Inspect light/dark, narrow, large/empty/unpriced/error states; no browser or dev server needed.
  - Manually verify keyboard/focus, VoiceOver and reduced motion on synthetic data. Headless screenshots do not establish those gates or owner acceptance.

- [ ] **T7 — Normalized parity and measured scan cost** (AC8)
  - Files: new `scripts/compare-token-usage.py` only if no equivalent exists when this task starts; adjacent synthetic tests and usage documented here. Depends on: T4 (can run before T6 finishes).
  - Tool is read-only, takes explicit input/output paths, uses synthetic data by default and never auto-discovers the real home. Reference queue is data; do not execute reference code.
  - Collapse queue snapshots, normalize four token kinds and timezones as below; compare 30 full local days, with reasoned differences. Persist raw results only in scratch, counts/summary only in this plan.
  - Verify: proposed `python3 scripts/compare-token-usage.py --self-test` covers repeated snapshots, reasoning mapping, zero denominator and timezone-boundary differences before any real-data comparison. The comparison mode requires explicit `--candidate`, `--reference`, `--timezone`, `--from`, `--to` and scratch `--output` arguments; document these when implemented.
  - Real logs remain a separate owner-authorized local acceptance run under S-R1; this scout approval did not authorize reading them. Preserve credentials/config, keep raw data out of git and do not uninstall TokenTracker.
  - Record cold/warm scan elapsed time and ledger size on a declared synthetic corpus; real-corpus measurements only when that acceptance run is authorized. An unavailable gate stays unchecked.

- [ ] **T8 — Owner eye approval and acceptance** (AC6; final gate)
  - Depends on: T1–T7 verification. Present one batch of final synthetic screenshots and the app against the accepted Board reference.
  - Record the owner's approval, outstanding native/parity gates and implementation commits here. A build, merge or test pass is not eye approval.
  - After approval, remove the now-replaced mock and its owning references in the same authorized cleanup; retain the specification and this plan as historical records only when all acceptance gates are met.
  - Push/merge/release and removal of the installed TokenTracker app are not authorized by this plan.

## Accounting and parity checks

| Case | Required discriminator |
| --- | --- |
| Claude duplicate snapshots | One identified response counts once |
| Claude increasing snapshot 10→20 | 20 when the latter is a valid final observation; reference first-seen behavior is not the oracle |
| Missing request/message identity | Supported identity fallback is explicit; unrelated records never merge into undefined |
| Copied source vs separate sessions | Same logical log does not duplicate; cross-session replay policy remains explicit |
| Codex cache/reasoning | input 1000, cached 400, output 50, reasoning 10 → uncached 600, read 400, output 50; test cache-write separately |
| Codex interleaved totals | 100,200,100,250,130 with last 100,200,100,50,30 → 380, not a repeat of 100 |
| Codex last-only or inconsistent total | Producer-supported interpretation or explicit incomplete coverage, never blind preference |
| Compaction omitted from cumulative | Identified RC contributes exactly once |
| Compaction already in cumulative | RC is not added twice |
| Compaction copied into a fork | Replayed response ID not counted twice; new response ID counted |
| Read split at every record boundary | Full and incremental reads agree |
| Record-only vs unfinished record | Final missing count is unmeasurable; unfinished input remains pending |

For AC8, pin reference version and coverage. Use the last queue row per `source/model/hour_start`, not a sum over repeated keys.
Claude output maps to `output_tokens + reasoning_output_tokens`; Codex output maps to `output_tokens` alone.
Align input/cache semantics, timezone, full local-day boundaries and supported CLI sources. Reference half-hour buckets can explain edge differences for some timezones.
Do not compare cost or conversation_count. Preserve the spec's ±1% or stated-cause criterion.

## Verification evidence and historical context

- 2026-11-12: read current source, protocol, wrappers and workflows; target has no Tokens ledger, query RPC or screen. No application tests/build were run for this documentation update.
- Documentation verification on 2026-11-12: all 63 local Markdown links/heading anchors in this plan and the owning spec resolved; `git diff --check` reported no whitespace errors. Proposed implementation paths are marked as new, not linked as existing files.
- Scout read reference source and tests without executing them. An independent Python datetime check passed: UTC 18:20/18:40 share an hour but cross a local date at +05:30; UTC 18:10/18:20 share a half-hour but cross a date at +05:45.
- 2026-11-03 historical measurement: 150 of 76,977 Claude messages repeated across 1,805 files; 20.9M of 15.2B tokens (0.14%). The owner accepted that limited cross-session overcount. It is not a current benchmark or permission to duplicate the same log's alternate encoding.
- Historical comparison reported 15.2B from Claude message maxima versus 21.0B in a TokenTracker queue. Cause remains unverified; the scout does not prove that the old comparison summed snapshots incorrectly.
- All T1–T8 implementation and acceptance gates remain unrun. Preserve [frozen fixture hashes](../../core/testdata/fixtures/SHA256SUMS); there is no supported regeneration step.

## Handoff

Checkout: `/Users/kyantran/Documents/Development/spacevibe-workspace/spacevibe-reins`, branch `main`; no task branch or PR.
Status: scout complete; this plan and the owning Tokens requirements updated in place. Implementation has not started.
Next action: T1's synthetic matrix and behavior-preserving extraction, followed by T1a. Do not reopen the approved Board direction or add scout features outside this scope.
Execution uses the current checkout by default, preserving unrelated work; commit only task paths. A PR requires an explicitly requested branch/worktree. The old cloud branch instruction is obsolete.
Remaining owner-only gates: authorization for the real-data T7 run and final T8 eye approval. No duplicate approval is required for the already accepted approach.
At implementation handoff, replace this status with completed tasks, observed commands, commit IDs, unrun gates and the next task.

`/goal` Implement the Tokens scope of docs/specs/2026-11-02-spacevibe.md through docs/plans/2026-11-03-spacevibe-tokens.md T1–T8: preserve Activity goldens, count Claude/Codex with independent synthetic fixtures, retain timestamped history through log deletion/encoding changes and failed reads/writes, expose local-calendar query RPC and the approved SwiftUI Board, pass scripts/test.sh and build/synthetic visual/native checks, satisfy normalized AC8 in an owner-authorized local run, then obtain one final eye approval; keep real configs untouched, preserve unrelated work, and do not push, merge, release or uninstall TokenTracker without authorization.
