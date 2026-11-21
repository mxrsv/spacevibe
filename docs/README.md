# Docs map

One current document per topic. When two documents disagree, the one named here wins, and the other is fixed or frozen. Rules for writing them are the owner's global D-rules (`~/.claude/rules/core/docs.md`); what is specific to this repo is on this page.

## Where each topic lives

| Topic | Current document |
| --- | --- |
| Purpose, users, jobs in priority order, UX principles | [PRODUCT.md](../PRODUCT.md) |
| Vocabulary: one word, one meaning | [GLOSSARY.md](../GLOSSARY.md) |
| Rules for agents: commands, toolchain rules (B), boundary rules (S-R) | [AGENTS.md](../AGENTS.md) |
| What the repository is and how to build it | [README.md](../README.md) |
| The interface as shipped: tokens, components, page conventions | [DESIGN-LANGUAGE.md](DESIGN-LANGUAGE.md) |
| Interface requirements and acceptance | [design language v5 spec](specs/2026-11-06-reins-design-language-v5.md) |
| Interface and vocabulary decisions (`D<n>`) | [Linear identity ledger](specs/2026-11-06-reins-linear-identity-decisions.md) |
| Core, rename and distribution decisions (`SV<n>`) | [SV ledger](specs/2026-11-07-core-port-and-spacevibe-identity-decisions.md) |
| Product requirements, acceptance criteria AC1 to AC10, SV traceability | [product spec](specs/2026-11-02-reins.md) |
| The Go core, one page per subsystem, and the shell-to-core protocol | [internals index](internals/README.md) |
| Releasing and the update key | [release runbook](operations/release.md) |
| The public site | [site/README.md](../site/README.md); requirements and deploy gates in the [landing spec](specs/2026-11-05-reins-landing.md) |

[DESIGN-LANGUAGE.md](DESIGN-LANGUAGE.md) is this repo's `DESIGN.md` under the owner's global FE-rules (`~/.claude/rules/frontend.md`, skill `kyant-ui-rules`). Where it or [PRODUCT.md](../PRODUCT.md) differs from them, this repo wins; the two icon sets are one such case (D72).

## Specs and plans

A spec owns requirements and acceptance; a plan owns tasks, progress, verification and handoff, and links to its spec instead of copying it. Each record's own `Status` line is the truth; this table only says where to look. File names keep the `reins-` slug of the product's old name: paths are never renamed.

| Feature or track | Spec | Plan | State on 2026-11-20 |
| --- | --- | --- | --- |
| Go core, protocol, rename, release gates | [product spec](specs/2026-11-02-reins.md), [SV ledger](specs/2026-11-07-core-port-and-spacevibe-identity-decisions.md) | [go-core](plans/2026-11-07-go-core-and-spacevibe-identity.md) | active: built, the owner's checks and gates open |
| Interface v5 | [v5 spec](specs/2026-11-06-reins-design-language-v5.md) | [UI v5 build](plans/2026-11-07-reins-ui-v5-build.md) | active: built and cut over, eye approval open |
| Settings | [spec](specs/2026-11-04-reins-settings.md) | [plan](plans/2026-11-04-reins-settings.md) | active: built, eye approval open |
| Session glance widget | [spec](specs/2026-11-19-session-glance-widget.md) | [plan](plans/2026-11-19-session-glance-widget.md) | active |
| Limit reset countdown | [spec](specs/2026-11-19-limit-reset-countdown.md) | the widget plan (its task GL-T13) | active |
| App-wide redesign (macOS frame, v2) | [spec](specs/2026-11-20-spacevibe-redesign.md) | [build plan](plans/2026-11-21-spacevibe-redesign-build.md) | mock round 5 eye-approved 2026-11-21; mock readiness (G-0) open, nothing built |
| Clean | [spec](specs/2026-11-18-clean.md), absorbed by the redesign spec | none | draft |
| Tokens page | [product spec, "Tab: Tokens"](specs/2026-11-02-reins.md#tab-tokens) | [plan](plans/2026-11-03-reins-tokens.md) | active: not built |
| Landing page | [spec](specs/2026-11-05-reins-landing.md) | none | draft, direction picked |
| Internals pages | none | [plan](plans/2026-11-07-reins-internals-docs.md) | active: the owner's check open |
| Agents settings panels | [spec](specs/2026-11-05-reins-agents.md) | [plan](plans/2026-11-05-reins-agents.md) | on hold, partly superseded, not built |

Frozen or historical, kept as records and not maintained: the [2026-11-03 design-language spec](specs/2026-11-03-reins-design-language.md) (superseded by v5, D73) and the plans [Electron](plans/2026-11-02-reins-electron.md), [SwiftUI](plans/2026-11-02-reins-swiftui.md), design language [v2](plans/2026-11-03-reins-design-language.md), [v3](plans/2026-11-04-reins-design-language-v3.md) and [v4](plans/2026-11-05-reins-design-language-v4.md), [Limits](plans/2026-11-03-reins-limits.md), [site landing](plans/2026-11-03-reins-site-landing.md), [launch](plans/2026-11-03-reins-launch.md), [review fixes](plans/2026-11-10-review-fixes.md), [Swift review fixes](plans/2026-11-11-swift-review-fixes.md) and [docs normalization](plans/2026-11-19-docs-normalization.md). A frozen record describes its own date, not the app today.

## Templates

A new spec, in `docs/specs/YYYY-MM-DD-<slug>.md`:

```markdown
# SpaceVibe: <topic>

Date: YYYY-MM-DD
Status: <draft | decided | built | frozen>, YYYY-MM-DD. <What is and is not built or accepted; for a frozen spec, what replaced it.>
Parent: <PRODUCT.md job or parent spec>. Plan: <link, once one exists>.

## Intent
## Decisions              | ID | Decision | Owner's words |
## Requirements           <PREFIX>-R1 …, each naming the decision IDs it serves
## Acceptance             | Check | Requirement |
## Traceability (W20)     | Decision, quoted | Requirement | Acceptance check |
## Inferred, not decided  lines with no owner decision behind them, each with its source
## Out of scope
```

A new plan, in `docs/plans/YYYY-MM-DD-<slug>.md`:

```markdown
# SpaceVibe: <topic>, build plan

Started YYYY-MM-DD. Status: <in progress | waiting for … | historical: completed YYYY-MM-DD, commits …>.
Spec: <link> (<IDs>). This plan does not repeat the requirements.
Checkout: `spacevibe-reins` on `main`, shared with other sessions; commit with `git commit -- <paths>` only.

## Approach
## Tasks          each task names the requirement IDs it serves; the owner's eye approval is one final task
## Verification
## Handoff        dated entries: progress, commits, observed verification, what is left

/goal <one line built from the acceptance criteria>
```

The status is two lines at most, the date line and the `Status` line, and it is rewritten when the state changes, not appended to. A record that is superseded says so in its `Status` line with a link to what replaced it; it is never deleted.

## ID namespaces

Short ids repeat across documents. Cite an id together with its document unless it is in the first three rows.

| Id | Owner |
| --- | --- |
| `D<n>` (no hyphen), from `D1` | [Linear identity ledger](specs/2026-11-06-reins-linear-identity-decisions.md) |
| `SV<n>` | [SV ledger](specs/2026-11-07-core-port-and-spacevibe-identity-decisions.md) |
| `B<n>`, `S-R<n>` | [AGENTS.md](../AGENTS.md) |
| `D-<n>` (with a hyphen) | open owner decisions of the [go-core plan](plans/2026-11-07-go-core-and-spacevibe-identity.md) |
| `AC<n>`, `RQ-SV<n>` | [product spec](specs/2026-11-02-reins.md) |
| `V5-R<n>`, `V5-A<n>`, and inside it `S<n>` (mock substitutions), `C<n>` (conflicts), `G<n>` (data gaps) | [v5 spec](specs/2026-11-06-reins-design-language-v5.md) |
| `ST<n>`, `AG<n>`, `CL-…`, `GW…`, `LC…`, `DL<n>` | the Settings, Agents, Clean, glance widget, countdown and frozen design-language specs |
| `RD<n>`, `RD-R<n>`, `RD-A<n>` | [redesign spec](specs/2026-11-20-spacevibe-redesign.md) |
| `L<n>` | three owners: the landing spec's ledger, the launch plan's tasks, the Limits plan's tasks |
| `C1` to `C3` | three owners: v5 conflicts, go-core conflicts, the review-fixes plan's owner calls |
| `X1` | three owners: the UI v5 cut-over, the go-core cross-platform task, the workspace rule "one session, one repo" |
| `G1` | two owners: a v5 data gap, a go-core phase |
| `FE-…`, `W<n>`, `F<n>`, and `D0` to `D15` written as "D-rule" | the owner's global rules in `~/.claude`, not this repo |

Write "v5 C1", "go-core plan D-1", "launch plan L8". The global doc rules share the letter D with the ledger: in this repo a bare `D<n>` is always a ledger decision, and a global rule is cited as "D-rule D9" or by its file.
