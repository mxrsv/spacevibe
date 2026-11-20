# SpaceVibe: docs, rules and instructions normalization

Started 2026-11-19. Status: historical, completed 2026-11-20. The owner accepted batch 1 on 2026-11-20 ("ok") and DN-T1 to DN-T9 were executed the same day. Commits, on `main`, not pushed: `2c3093a` (DN-T1), `2e424f3` (DN-T2), `970adeb` (DN-T3), `95c4327` (DN-T4), `5dc4846` (DN-T6), `2b195b3` (DN-T7), `d620d92` (DN-T9), `c689d31` (DN-T5), and the closing commit that carries this line (DN-T8). The text below is the record of the work and is not maintained; the docs map is [docs/README.md](../README.md).
Spec: none. Requirements are the intent the owner confirmed in conversation on 2026-11-18 ("đúng"), summarized under Scope.
Checkout: `spacevibe-reins` on `main`, shared with other sessions; commit with `git commit -- <paths>` only. The Clean spec is being written in another session: this plan does not edit `docs/specs/2026-11-18-clean.md`.

## Scope

- **Outcome:** every doc, rule and instruction in this repo follows the global D-rules (`~/.claude/rules/core/docs.md`), with exactly one current document per topic.
- **Goals, all three chosen by the owner ("tất cả"):**
  - (a) stale and overlapping text is gone, so agents stop following dead rules;
  - (b) every normative line traces to an owner decision (ledger ID or quote) or to a verified technical fact;
  - (c) one structure and one naming, with SpaceVibe as the product name in living text.
- **Lines with no source:** these are batched with a keep, drop or rewrite recommendation, and the owner approves each batch once (owner: "guess", which is option a).
- **Constraints:**
  - This repo only (workspace X1).
  - No decision changes meaning while it is moved; it is only relocated and linked (W20).
  - Specs and plans stay in English.
  - A renamed file gets every inbound link fixed.
  - Historical specs and plans are frozen with a date and a pointer, never deleted (D1).
- **Out of scope:**
  - code, including the stale strings in `scripts/` and `site/`, which are listed under Raised;
  - global `~/.claude` rules, memory, the workspace `AGENTS.md`;
  - the B6 fixture names (`reins-fixture-home`, `.reins`), because renaming them breaks the goldens.
- **Order:** this plan runs first. The app-wide layout redesign resumes after it, with its grilling Q4 to Q6 still open.

## Audit (2026-11-19, three read-only agents)

The audit covered 16 living files, 9 specs and 16 plans.

**Checked and fine:**
- `docs-compliance.sh` passes (D5).
- All 416 links in living docs resolve.
- The command table in `AGENTS.md` matches the scripts.
- Most constants in `docs/internals/` match the code.

**Defects found:**

- **False claims in living docs:**
  - `PRODUCT.md:36` and `README.md:19` say the app writes MCP servers, model, `CLAUDE.md` and `AGENTS.md`. No code does: `docs/internals/rules.md:3` states this, and a grep of `core/` finds no writer.
  - `PRODUCT.md:30` says "`Agents` are subagents only". D46 and `GLOSSARY.md:23` say Agents is the page name.
  - `GLOSSARY.md:59`, `PRODUCT.md:21` and `inventory.md:53` present D63 (no separate "pending" state) as current, but the code still emits `pending` (`core/internal/inventory/types.go:68`).
- **Stale symbols in living docs:**
  - `core-protocol.md:15,35,146,224` name Swift-era symbols and files that no longer exist (`AppEnvironment.startupProblem`, `RulesStore`, `InventoryTypes.swift`, `RulesGoldenTests.swift`).
  - `inventory.md:45,46` name `Inventory.bare` and `maxProjects`; neither exists.
- **Contradictions inside living docs:**
  - `mutations.md:50` contradicts `mutations.md:60` on whether anything writes TOML.
  - `GLOSSARY.md:11` lists "engine" under _Avoid_, while `GLOSSARY.md:10` and `AGENTS.md:5` use it.
  - `GLOSSARY.md:49` gives Scope two values; Rules has three (global, project, local).
  - `PRODUCT.md:31` names three categories; the code has four.
- **History and backlog inside living docs (D7):**
  - `AGENTS.md:19` (Electron history), `:41` (WEB0 gate and Tokens), `:50-51` (B8/B9 release runbook and to-do), `:61` (mock deletion schedule).
  - Plan task IDs inside internals prose (PR.1-3, G0.1, H10, S.3-S.7, G-fix.13, AC3, H16, C3).
- **D9 file catalogs:**
  - Every internals page carries a file-responsibility table and a test-file list.
  - The two largest plans contain durable content that belongs in living docs: traps in the go-core plan, component conventions in the ui-v5 plan.
- **Specs:**
  - Status lines are stale in 5 specs. v5 still says "Not built", but it was cut over in `b877e3a`.
  - The 2026-11-03 design-language spec is substantially superseded by v5 and not marked.
  - The Agents spec is not marked superseded where D47/D48 and v5 C17 changed it.
  - The v5 spec has 35 links to `Sources/Reins/...`, 23 of which point to files that are gone. It also has no W20 rows for D69 and D70, and its reference mock `~/scratch/spacevibe-reins/linear-directions/` is missing.
  - The linear ledger has 9 reversed decisions whose earlier line is not marked (D8, D9, D21, D24, D27, D29, D35, D36, D50).
  - IDs collide across documents: `C1`-`C3`, `X1` (3 meanings), `G1`, `D-n` vs `Dn`.
- **Plans:**
  - Six plans read "in progress" or "active" although v5 or the go-core plan replaced them.
  - The ui-v5 plan has 40 of 56 links broken, its X1 box is unticked although the cut-over is committed, and it has no owner words for U14.
  - `review-fixes` is complete but not marked historical.
  - The launch plan contradicts the `v0.1.0` tag.
  - Relative dates appear in 7 plans (D13).
- **Global rules the repo cites no longer exist.** On 2026-11-19 the owner replaced the global UI rules with the FE-rules (`~/.claude/rules/frontend.md`, skill `kyant-ui-rules`). `~/.claude/rules/quality/ux.md` and `ui-process.md` are gone, and W16, W17, W18, W21, W22 and W23 left `workflow.md`. W20 and W24 stay where they were.
  - **Dangling citations in living docs:** `PRODUCT.md:28` (`ux.md`, UX1-UX4) and `limits.md:43` (W23).
  - **Dangling citations in active specs:** v5 cites UX1, UP1, UP5, UP6, W17, W21, W22 and W23 (for example l.42, 68, 129, 199, 394-406, 526). The landing spec cites W20, which still exists.
  - **Ledgers:** D42 and D55 quote the old files as the place where the owner's principles live.
  - **Mapping used for the rewrite:** W16 → FE-P8, W17 → FE-P9, W18 → FE-P5, W21 → FE-SP3, W22 → FE-P4, W23 and UP6 → FE-D3, UP1 → FE-K1, UP5 → FE-P4, UP8 → FE-P1, UX3 → FE-C2/FE-C4, UX4 → FE-I1/FE-I4. UX1 and UX2 have no FE counterpart; SpaceVibe keeps them as its own lines in `PRODUCT.md` (the jobs brief) and `GLOSSARY.md` (one word, one meaning).
  - **FE-rules checked against the repo:**
    - FE-K5 (no focus ring) already holds: the system ring is disabled and `FocusFill` shows focus as a fill.
    - FE-S3 names a repo `DESIGN.md`; this repo's equivalent is `docs/DESIGN-LANGUAGE.md`, and nothing says so yet.
    - FE-K3 (one icon library) conflicts with the two sets in use (DN-Q2).
- **Missing living docs:**
  - `docs/README.md`, which D1 lists as a living doc.
  - `docs/operations/` for the release runbook.
  - `CHANGELOG.md`, which D12 requires once behaviour changes; deferred to the next release.

## Batch 1: owner decisions

Each row carries a recommendation. The owner can accept all of them in one answer.

**Owner answer, 2026-11-20: "ok".** Read as: every recommendation below is accepted as written, DN-Q1 to DN-Q6, DN-L1 to DN-L13 and the settled choices DN-S1 to DN-S6. DN-L14 is only raised with the Clean session; this plan does not edit that spec. The answer is recorded where each decision lives: DN-Q1, DN-Q2 and DN-Q5 as D71, D72 and D73 in the [linear ledger](../specs/2026-11-06-reins-linear-identity-decisions.md), DN-Q3 in the [SV ledger](../specs/2026-11-07-core-port-and-spacevibe-identity-decisions.md), and DN-Q4 as a waiver note in each plan whose gate it waives.

| ID | Question | Recommendation | Why |
| --- | --- | --- | --- |
| DN-Q1 | `PRODUCT.md:17,22` says "rows compared by eye on bars beat hero tiles" and "no card grids". D56/D61 approved bento tiles. Which one stands? | Align `PRODUCT.md` with D56/D61: one lead datum per card, bars where the question is a comparison. | The later owner decision wins. The layout redesign may revisit it with its own ledger line. |
| DN-Q2 | `DESIGN-LANGUAGE.md:25` says MingCute plus Phosphor. Ledger D9 says "one thin-stroke set", an older pick says Tabler, and FE-K3 (2026-11-19) says one icon library. | Record the code as a SpaceVibe exception to FE-K3: MingCute for categories, Phosphor for sidebar and content, plus the custom verdict glyphs (D19/D58). Cite the owner's 2026-11-05 ask that sidebar icons are not reused inside pages. Mark D9 and the Tabler pick superseded. Moving to one library would be a separate code task. | The code and `IconPolicyTests` already enforce two sets, the owner asked for the split, and Tabler was never built. |
| DN-Q3 | SV5 "byte for byte" was narrowed under "tiếp tục hết tất các phase". `docs/specs/2026-11-02-reins.md:317` says the narrowing needs an explicit yes. | Record an explicit yes to the narrowing. | The goldens have been frozen on it since 2026-11-07, and three documents disagree today. |
| DN-Q4 | Some eye gates judged screens that no longer exist: Electron 3.3/4.4/5.3/6.4, SwiftUI S3.3-S6, design-language v2 T11, v3 V7, Limits L5. | Waive them all and record the waiver. The live gate is ui-v5 U14. | Approving a screen that is gone has no meaning. |
| DN-Q5 | Should `docs/specs/2026-11-03-reins-design-language.md` be frozen as superseded by v5? | Yes, with DL1 (Inter only) and DL11 (contrast) noted as carried by V5-R4 and V5-A2. | Token values, icons, rows and sidebar all changed in v5, and agents still read this file. |
| DN-Q6 | `mocks/agents/` is kept until Agents A12, after v4 V8, but v4 is superseded and that trigger can never happen. | Delete `mocks/agents/`; git keeps it. Keep `mocks/tokens-board/` until the Tokens page is decided in the layout grilling. | Only `AGENTS.md:61` cites it, and nothing else uses it. |

Unsourced or wrong lines (DN-L). "Rewrite" keeps the meaning and fixes the source or the fact.

| ID | Line | Recommendation |
| --- | --- | --- |
| DN-L1 | `AGENTS.md:21` "Everything in this repo's Swift code, comments and tests is English" (true in the code; no ledger ID) | Keep, recorded as the owner's convention |
| DN-L2 | `AGENTS.md:21` "Command Line Tools only (no Xcode)" | Rewrite: "Xcode is not required" (`scripts/test.sh:14-22` supports both) |
| DN-L3 | `AGENTS.md:47` B3 cites SV15 for preferences and folder consent; SV15 covers only the data folder | Rewrite as a fact: a new bundle id means a new defaults domain and new consent. Cite SV11/SV14 |
| DN-L4 | `PRODUCT.md:23` "(one save for a panel of agent settings)" | Drop: no such panel exists, and the Agents spec owns it |
| DN-L5 | `PRODUCT.md:36` "One can be replaced without being shown." | Drop until the Agents panels ship |
| DN-L6 | `PRODUCT.md:39` "the domain is not repointed yet" | Drop from PRODUCT; status lives in the landing plan |
| DN-L7 | `PRODUCT.md:9` "Today the owner is the only user" | Add the date 2026-11-19. Widening it to newcomers waits for the layout spec |
| DN-L8 | `DESIGN-LANGUAGE.md:19` "scratch HTML proposals of 2026-11-12 have not been adopted" | Drop |
| DN-L9 | `DESIGN-LANGUAGE.md:25` "A component is removed only when no current surface uses it." | Drop |
| DN-L10 | `GLOSSARY.md:11` lists "engine" under _Avoid_ | Rewrite: avoid it in UI labels only |
| DN-L11 | `GLOSSARY.md:25` "_Avoid_: Loadout" | Keep as a tombstone while wire names stay `loadout.*` |
| DN-L12 | `limits.md:43` cites "(W23)", a global rule invisible in the repo | Rewrite: state the rule directly (percent left is derived from used) |
| DN-L13 | Settings spec l.16 "interface stays English only"; Agents spec l.48 panel width 420-720 | Move both to an "Inferred, not decided" list in their spec |
| DN-L14 | Clean spec: CL-R1 "Dead" for Skills and Subagents; the `.cursor`/`.gemini` exclusion narrows CL1 | Raise with the Clean session; this plan does not edit that spec |

Settled without asking (reversible; listed so the owner can correct a line):
- **DN-S1.** File names keep the `reins-*` slug. 78 inbound links, D4 keeps paths, and SV9 allows dated records to keep history. Only the H1 titles of active docs become "SpaceVibe".
- **DN-S2.** The two ledgers are not merged. Merging would renumber 87 IDs that commits and code comments cite. Each ledger gets a namespace line. Colliding citations in living docs and active specs are qualified ("go-core plan D-1", "v5 C1"), never renumbered.
- **DN-S3.** Historical plan bodies are not trimmed (D1 keeps them). Only their status headers, and links in plans that stay active, are fixed.
- **DN-S4.** The spec template is the Clean spec's structure plus a W20 table and a two-line status. It is written into `docs/README.md` rather than as a new file.
- **DN-S5.** Durable content leaves plans:
  - go-core traps go to `docs/internals/overview.md`;
  - ui-v5 component conventions and approved departures go to `docs/DESIGN-LANGUAGE.md`;
  - the B8/B9 release runbook goes to a new `docs/operations/release.md` (a valid D3 directory).
- **DN-S6.** Open items of superseded plans move to the plan that now owns them, mostly the go-core plan, and are not kept in two places.

## Tasks

- [x] **DN-T1 Living facts (no owner needed).** Done 2026-11-20. The four stale symbols of `core-protocol.md` are fixed in the DN-T3 pass over that page.
  - Fix the false write scope in `PRODUCT.md:36` and `README.md:19`.
  - Replace the vocabulary block in `PRODUCT.md:30` with a link to `GLOSSARY.md`.
  - State `pending` as current behaviour, with D63 as the target, in `GLOSSARY.md`, `PRODUCT.md` and `inventory.md`.
  - Add `local` to Scope.
  - Set the category count to four.
  - README and DESIGN-LANGUAGE: say three pages plus Settings.
  - Fix the stale symbols in `core-protocol.md` and `inventory.md`.
  - Fix the TOML contradiction in `mutations.md`.
  - `site/README.md`: `content.ts` does not hold every word; document the `directions/` route.
  - `AGENTS.md`: add the 2026-11-07 ledger to "Read before work"; drop the Electron history; rename R6 to S-R6.
- [x] **DN-T2 Batch 1 applied.** Done 2026-11-20: D71 (DN-Q1), D72 (DN-Q2), D73 (DN-Q5) in the linear ledger; "Owner answer on SV5" (DN-Q3) in the SV ledger; a waiver line (DN-Q4) in the Electron, SwiftUI, design-language v2, v3 and Limits plans; `mocks/agents/` removed (DN-Q6). DN-L1 and DN-L11 keep their lines.
  - Apply DN-Q1 to DN-Q6 and DN-L1 to DN-L13 as the owner answered.
  - Record each owner answer in the ledger it belongs to: DN-Q1, DN-Q2 and DN-Q5 in the linear ledger; DN-Q3 in the SV ledger; DN-Q4 in the plans it waives.
- [x] **DN-T3 Internals pages (D9, D7).** Done 2026-11-20. Each page now opens with one "Code:" line naming its packages in place of the file table; `TestDocMethodTable` (which reads the method table of `core-protocol.md`) still passes.
  - Drop the file-responsibility tables and test-file lists; keep the "where each fact comes from" tables, the traps and one `go test` command.
  - Strip plan IDs and migration history (`core-protocol.md` H10, S.3-S.7, G0.1, G-fix, the Swift history; `overview.md` AC3, C3).
  - Move journal retention, Stop re-validation, settings-file scrub and percent-left to their owning page, and link to them from the others.
- [x] **DN-T4 Release runbook.** Done 2026-11-20: [docs/operations/release.md](../operations/release.md); WEB0 is now the "Deploy gates" section of the landing spec.
  - Create `docs/operations/release.md` from B8/B9.
  - Add the missing precondition: Info.plist 0.1.0 / build 1 equals the `v0.1.0` tag, so `release.sh` refuses until both are bumped.
  - `AGENTS.md` keeps B8/B9 as one-line rules that link to the runbook.
  - The WEB0 gate and the mocks schedule leave `AGENTS.md`: WEB0 goes to the landing spec, the schedule is settled by DN-Q6.
- [x] **DN-T5 `docs/README.md`.** Done 2026-11-20, after DN-T6 and DN-T7 so the map could name each record's state.
  - A map of one current document per topic: product, glossary, design language, decisions, internals, operations, and active specs and plans.
  - The spec and plan templates (DN-S4).
  - The ID namespaces.
- [x] **DN-T6 Specs.** Done 2026-11-20. Differences from the audit's counts: the v5 spec had 36 broken links, of which 16 were relinked and 20 became plain text; the colour tables moved to `DESIGN-LANGUAGE.md` with the values `Palette.swift` holds today, not the spec's (14 tokens had departed); D23 is marked as well as the nine reversed rows.
  - Two-line status headers.
  - Mark parts as superseded with pointers:
    - 2026-11-02: Interface, Scope and Constraints items replaced by v5 and D70.
    - Agents: placement replaced by v5 C17, Codex writes replaced by D47/D48, `⌘1`.
    - Landing: L16 picked, `spacevibe.dev` per SV10.
  - v5:
    - Fix the date and status.
    - Repair 35 links (12 to new paths, 23 to plain text naming the removed file).
    - Add W20 rows for D69 and D70.
    - Mark the D70 changes on V5-R49/R61/R69/R72/A1.
    - Move the hex tables to `DESIGN-LANGUAGE.md`.
    - Name the missing reference mock as missing.
  - Ledgers:
    - Mark the 9 reversed lines.
    - Replace the stale "traceability still owed" stubs.
    - Move SV D-1 to Open.
    - Add namespace lines.
  - Fix the relative dates.
- [x] **DN-T7 Plans.** Done 2026-11-20. Historical: electron, swiftui, design-language v2, v3 and v4, limits, site-landing, review-fixes and launch. On hold: agents. Still active: go-core, ui-v5, settings (S10), tokens, internals-docs (the owner's sample check is not among the gates DN-Q4 waives, so it stays open).
  - Mark historical or superseded, each with date and commits: electron (`6ceaf44`), swiftui, design-language v2/v3/v4, limits, site-landing, review-fixes (complete 2026-11-11).
  - internals-docs: historical after the owner's sample check, or waived by DN-Q4.
  - Move open items to their owners (DN-S6).
  - ui-v5: repair the links, tick X1 with 2026-11-12 and `b877e3a`, put `/goal` last.
  - go-core: add a status line and start date, move the traps to overview, drop the protocol duplicate.
  - `AGENTS.md:19` points to the go-core plan.
  - Relative dates fixed (D13).
- [x] **DN-T9 FE-rules citations.** Done 2026-11-20. The landing spec cites only W20, which still exists, so it needed no change. The two active plans that cite the old ids (ui-v5, go-core) got one mapping note each instead of a rewrite of every task line.
  - Rewrite every citation of the retired global rules using the mapping under Audit:
    - living docs: `PRODUCT.md:28`, `limits.md:43`;
    - active specs: v5 and the landing spec.
  - `PRODUCT.md`'s "UX principles" section points to `~/.claude/rules/frontend.md` and keeps its SpaceVibe lines.
  - `AGENTS.md` and `docs/README.md` say that `docs/DESIGN-LANGUAGE.md` is this repo's `DESIGN.md` under the FE-rules, so where it differs from them, the repo wins.
  - D42 and D55 keep their quoted text. Each gets a note: "the global files were replaced by the FE-rules on 2026-11-19".
  - Historical plans are left as they are.
  - The Clean spec and the session-glance-widget spec and plan belong to other sessions, so their citations (UP6, W23) are raised there instead of edited here.
- [x] **DN-T8 Verify and close.** Done 2026-11-20; output in the Handoff.
  - The checks below pass.
  - Raised items reported once.
  - This plan is marked historical.

## Verification

```bash
bash ~/.claude/scripts/docs-compliance.sh
bash ~/.claude/scripts/docs-anchors.sh
# every relative markdown link in living docs, active specs and active plans resolves (scratch link checker, not committed)
grep -rn "Sources/Reins/\|ReinsCore\|Solar\|⌘L" AGENTS.md PRODUCT.md GLOSSARY.md README.md docs/DESIGN-LANGUAGE.md docs/README.md docs/internals docs/operations   # expect no hits
grep -rnE "ux\.md|ui-process\.md|\b(UX[1-4]|UP[1-8]|W1[678]|W2[123])\b" AGENTS.md PRODUCT.md GLOSSARY.md README.md docs/DESIGN-LANGUAGE.md docs/README.md docs/internals docs/operations docs/specs/2026-11-06-reins-design-language-v5.md   # expect hits only in quoted ledger text with the 2026-11-19 note
```

Plus a per-topic check: for each topic in `docs/README.md`, exactly one document is marked current.

## Raised (out of scope, reported once)

- `Resources/Info.plist` still holds the deprecated Sparkle key, and `scripts/generate-update-feed.sh:21` and `scripts/test-update.sh:21` still use the account `dev.spacevibe.reins` (go-core R2, owner key needed).
- `site/components/landing/content.ts:41,218` and `directions/copy.ts:140` still ship a Tokens section that the app does not have.
- `.github/workflows/swift.yml:2` cites the Tokens plan.
- `scripts/build-app.sh:36` and `scripts/release.sh:34` hard-code a personal signing identity name as the default.
- `core/internal/rules/doc.go:4` mentions `Sources/ReinsCore`.
- Clean spec conflicts (DN-L14).

Added while executing, 2026-11-20:

- Stale rule citations in files this plan may not edit: `docs/specs/2026-11-18-clean.md:40` cites UP6 and `:46` cites W23; both map to FE-D3. The glance widget spec and plan and the countdown spec cite none.
- Code comments still cite retired ids: `Sources/SpaceVibe/Components/SidebarBlocks.swift:4` (UP1) and `Sources/SpaceVibe/Limits/LimitsAnswer.swift:7` (W23).
- `scripts/release.sh` checks that the tree is clean but not that the branch is `main`, which rule B9 asks for; the runbook says so.
- The frozen v5 reference mock `~/scratch/spacevibe-reins/linear-directions/` is gone from the owner's Mac, so V5-A1 (side by side with the mock) cannot run until it is restored or another reference is named.
- No `LICENSE` exists (launch plan L8, now in the go-core plan's Handoff).
- The landing direction is picked (L16) but the spec's "On pick" step is not done, so `/` is still the first-generation page with a Tokens section.
- The owner's sample check of the internals pages (internals-docs plan) is still open; DN-Q4 does not waive it.
- `Metrics.swift` says a dialog's buttons are 28, while the UI v5 handoff records the lead's approval of 32 for the Stop dialog. Which one the app draws was not checked, so that departure was not carried into `DESIGN-LANGUAGE.md`.

## Handoff

2026-11-19: three read-only audits returned. This plan was written, and batch 1 waits for the owner. No doc has been edited.
2026-11-19, later: the owner ran `/kyant-ui-rules`. The FE-rules rewrite was checked against the repo, DN-T9 was added and DN-Q2 now names the FE-K3 conflict.

2026-11-20: executed and closed. The owner's answer to batch 1 was "ok" (2026-11-20).

- Commits, on `main`, nothing pushed: `2c3093a` DN-T1, `2e424f3` DN-T2, `970adeb` DN-T3, `95c4327` DN-T4, `5dc4846` DN-T6, `2b195b3` DN-T7, `d620d92` DN-T9, `c689d31` DN-T5, then the closing commit (DN-T8).
- Where the work departed from this plan, each because the code or the checkout said otherwise:
  - DN-T1: the four stale symbols of `core-protocol.md` were fixed in the DN-T3 commit, in the same pass that removed its history. `pending` is described as it is: the core still emits the wire state, and the shell already shows it as Never ran with a note, so D63 is half landed, not unstarted.
  - DN-T2: the internals-docs plan's open check is not waived, because DN-Q4's text lists eye gates on screens that are gone and that check is not one of them. `mocks/agents` references in frozen records became plain text with a dated note rather than being removed.
  - DN-T3: each page keeps one "Code:" line naming its packages, so a reader still gets from a page to its code without a file table.
  - DN-T6: the v5 spec had 36 broken links, not 35; 16 were relinked and 20 became plain text (the audit expected 12 and 23). The colour tables were moved to `DESIGN-LANGUAGE.md` with the values `Palette.swift` holds, because 14 tokens had departed from the spec's values; the spec keeps the candidates that were not built. D23 is marked beside the nine reversed rows, since D49 amends it in its own words.
  - DN-T7: the launch plan is marked historical too (the `v0.1.0` tag `308a4c3` contradicts its Handoff). The UI v5 plan's `/goal` was rewritten for what is left, not only moved; its 46 broken links were 33 relinked and 13 plain text. The "For U<n> onward" lines stay in that plan's Handoff as a dated record, with a pointer to the living copy. The Stop-dialog departure was not carried over (see Raised).
  - DN-T9: the mapping from old to new rule ids stays in this plan only, so that the verification grep finds nothing in living docs; `docs/README.md` and the v5 spec link here.
  - DN-T5 was done after DN-T6 and DN-T7, so the map could name each record's state.
- Verification, run 2026-11-20 at `c689d31`:
  - `bash ~/.claude/scripts/docs-compliance.sh` printed "tuân thủ D5", exit 0.
  - `bash ~/.claude/scripts/docs-anchors.sh` printed nothing, exit 0.
  - The first grep (`Sources/Reins/`, `ReinsCore`, `Solar`, `⌘L` in living docs): no hits.
  - The second grep (retired rule ids and files in living docs and the v5 spec): no hits.
  - Scratch link checker (`/tmp`, not committed; relative links and heading fragments): living docs 432 links, 0 broken; active specs 104, 0 broken; active plans with this plan 130, 0 broken (re-run on the closing tree). Frozen records, for information: 71 links, 10 broken, all to Swift files deleted since, left as written (DN-S3).
  - `SPACEVIBE_TEST=1 go test -run TestDocMethodTable ./internal/rpc/` passed after the `core-protocol.md` pass (that test reads the page's method table).
  - Per topic: every row of the topic table in `docs/README.md` names one current document.
- Left for the owner or other sessions: everything under Raised. Nothing is pushed.

/goal Normalize SpaceVibe repo docs per docs/plans/2026-11-19-docs-normalization.md: apply owner batch 1, finish DN-T1 to DN-T8, docs-compliance and docs-anchors pass, every link in living docs and active specs/plans resolves, one current document per topic in docs/README.md.
