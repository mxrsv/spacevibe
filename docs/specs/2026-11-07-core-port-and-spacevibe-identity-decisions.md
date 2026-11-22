# Standalone Go core and SpaceVibe identity, decision ledger

Date: 2026-11-07
Status: active ledger. SV1 to SV17 settled on 2026-11-07; the owner's later answers are in the dated sections below (2026-11-07, 2026-11-08, 2026-11-20, 2026-11-21). Open items are under "Open (not assumed)" and "Still open".
ID namespace: `D<n>` without a hyphen is a decision of the Linear identity ledger; `SV<n>` is a decision of the SV ledger; `D-<n>` with a hyphen is an open item of the go-core plan. Other documents reuse short ids (`C1` to `C3`, `X1`, `G1`): cite those with their document, for example "v5 C1" or "go-core plan D-1" ([docs/README.md](../README.md#id-namespaces)).

Source: grilling session 2026-11-07. Owner's words are quoted (Vietnamese originals kept where the wording matters; "approve đủ" means the owner accepted every recommended answer in the round).
Every later artifact (spec, plan, build prompt, subagent brief) cites these IDs (W20). Status: all rounds settled 2026-11-07 except the items under "Open", which are not assumed.

## Problem

Owner: "gần đây chúng ta gần như chỉ tập trung về build UI, tính năng core chưa có nhiều, tôi cần review nhiều thứ, và có cần thiết làm một CLI core hay engine core không ?"
The 2026-11-02 spec made the engine a Swift library (`SpaceVibeCore`). Owner on that choice: "tôi chọn SwiftUI nó chỉ dành cho UI thôi hiểu không ? có lẽ do hôm đó tôi không nói rõ ràng".

## Decisions

| ID | Decision | Owner's words |
| --- | --- | --- |
| SV1 | The core is a standalone engine in Go. SwiftUI is the macOS UI layer only. Supersedes the spec line "the engine is rewritten in Swift as a library". | "yes chuyển sang Go đi" |
| SV2 | Windows and Linux shells are committed within about 3-6 months, which is the reason for SV1. | "yes chuyển sang Go đi" (answer to the commitment question) |
| SV3 | Shell-to-core protocol: JSON-RPC over stdio, a child process owned by the GUI. The protocol version is sent in `initialize` and a mismatch is refused. Stdout carries protocol only, logs go to stderr, the core exits on stdin EOF, spawn uses an argv array (no shell). No network listener (S-R5). A one-shot `<cli> <command> --json` stays for debugging. | "approve đủ" |
| SV4 | The macOS app calls the core only through the child process, via one `CoreClient` in Swift. `SpaceVibeCore` is no longer linked by the UI. Migration is one screen at a time. | "approve đủ" |
| SV5 | NARROWED with the owner's explicit yes on 2026-11-20 ("byte for byte" reads as canonical bytes of the named projections; see "Owner answer on SV5"). Parity oracle: the existing `Tests/SpaceVibeCoreTests/Fixtures/golden/*.json` are frozen as committed files. The Node generator and Node `core/` are deleted as plan S8.3 intended. The Go core must match the goldens byte for byte. A wrong golden is fixed together with its Swift test in one commit. | "approve đủ" |
| SV6 | The Go core lives in this repository, in a new directory whose name is chosen after reading `~/.claude/templates/project-structure.md`. | "approve đủ" |
| SV7 | Order: the Go port comes before the first macOS publish, so S0.5, S0.4 and S0.3 are verified once, on the Go core. | "approve đủ" |
| SV8 | Pre-publish core review order: real-CLI acceptance (S0.5), then write safety and Stop (S0.4), then TCC (S0.3), then S8.1 and S8.2, then feature gaps against the spec. Output is a severity-ranked read-only report on the core whose findings become tasks in an existing plan. The goal is trust for a macOS release, not cross-platform preparation. | "approve đủ" |
| SV9 | The product takes the name SpaceVibe in place of its former name. No visible or identifying reference to the former name remains. | "không còn [tên cũ] name nữa, spacevibe là một domain xuất sắc dành cho dự án này" and "tôi sẽ chuyển hết sang thành spacevibe.dev không còn liên quan nào đến [tên cũ] nữa" |
| SV10 | `spacevibe.dev` becomes this product's landing page. `spacevibe-hub` is retired and its content moves to `kyant.dev`. | "lấy luôn domain spacevibe.dev làm landing cho repo này", "không còn dùng hub nữa", "hub đổi sang thành kyant.dev" |
| SV11 | All identifiers are renamed too, including the bundle id, the repo name and the appcast URL. Installed `v0.1.0` copies are not kept updating. | "chọn (b) đổi hết" |
| SV12 | New names: bundle id `dev.spacevibe.app`, CLI `spacevibe`, env prefix `SPACEVIBE_*`, data folder `~/.spacevibe`. The binary name, env prefix and data folder are one constant each. `initialize` returns the core's name and version so a shell never depends on the binary name. | "approve đủ" |
| SV13 | Sparkle gets a new key pair and a new Keychain account for the new bundle id, with a new `SUPublicEDKey`. B8 is rewritten for the new key. | "approve đủ" |
| SV14 | The `v0.1.0` release stays, marked deprecated in its description with a pointer to the new download page. No bridge release (3 downloads at 2026-11-07). Deleting it is not part of this decision. | "approve đủ" |
| SV15 | No data migration from `~/.reins` to `~/.spacevibe`. The owner copies the folder by hand; the release notes say so. | "approve đủ" |
| SV16 | Deploy host is Vercel. Old Hub routes redirect to the same path on `kyant.dev`. The `/live` family (`/live`, `/en/live`, `/vi/live`, `/live/<slug>`) keeps its 308 to `https://active.spacevibe.dev` (U4). Order: build Hub on `kyant.dev`, verify, then repoint `spacevibe.dev`. The retired product subdomain did not answer HTTP on 2026-11-07, so it needs no redirect unless DNS for it exists. Every DNS and deploy step needs the owner's approval when it runs. | "approve đủ" |
| SV17 | The other products (Deck, Bench, Academy, Active) keep their own names. "SpaceVibe" names this app. Workspace-level records move to a separate workspace session (X1). | "approve đủ" |
| SV18 | The repository is open source under GPL-3.0-only. The SpaceVibe name and app icon stay reserved by a trademark policy. | Picked "GPL-3.0-only" in the agent's question dialog, 2026-11-22 |

## Open (not assumed)

The list as it stood on 2026-11-07. Items settled since are in "Owner answers at plan execution", "Status 2026-11-08" and "Owner answer on the repo name (2026-11-21)".

- Repo name (go-core plan D-1). The recommendation was `mxrsv/spacevibe`, with `spacevibe-app` named as safer because the workspace uses `spacevibe-<product>` and `spacevibe-workspace` exists. The owner has not picked between them. Until then `mxrsv/spacevibe` is only a working value kept in one constant; gate GH1 still needs explicit approval, and the owner may pick `spacevibe-app`.
- Spike (fact, not a decision): Go reads a `.jsonl.zst` rollout, parses TOML and cross-compiles to Windows before any port starts.
- Windows and Linux UI technology (native per OS or a shared web UI). Needed only when the second shell starts.
- Module order of the Go port.
- `SpaceVibeStatusline` becomes a subcommand of the Go core (it uses `posix_spawn` of `/bin/sh`, unavailable on Windows). Not asked yet.
- Whether the core may run `claude --version` and `codex --version` (S-R4 would list them as fixed commands). Not asked since the Go decision.
- Whether new UI work pauses until the core review and the first CLI exist.
- Windows tests run on a real Windows machine, not only compiled in CI (lesson from the magpie repo).
- Fate of the Hub `/vote` route (Postgres and Neon Auth), the marketing strategy and the workspace `AGENTS.md` map. These belong to a workspace session.

## Owner answers at plan execution (2026-11-07)

Owner, after seeing the W20 table and the open decisions with recommendations: "tiếp tục hết tất các phase". Read as: take the plan's recommendation for every open item below. Each is reversible until the gate that publishes it. The repo name (D-1) is not in this table: the owner did not decide it, so it stays under "Open (not assumed)".

| Item | Taken | Note |
| --- | --- | --- |
| D-2 port order | the plan's order | |
| D-7 directory and module | `core/`, `spacevibe.dev/core` | |
| C1/Q1 "byte for byte" | canonical bytes of the named projections, case counts asserted | narrows SV5 as the plan proposes; explicit yes given on 2026-11-20 (see "Owner answer on SV5") |
| C3/Q2 fixtures | kept as named skipped sites in the rename report | |
| C2/Q8 | after the Swift tests are deleted, "with its Go test" | |
| D-3 statusline | `spacevibe statusline install\|undo\|capture` in the Go core | |
| D-4 `--version` of the CLIs | the core does not run them | |
| D-5 new UI work | UI-only work continues; engine tasks of the Agents and Tokens plans move to Go after G1 | |
| D-6 Windows hardware | yes, X2 needs real hardware | |

Still the owner's alone: every outward-facing gate (GH1, REL1, GH2, WEB1 to WEB3), the Sparkle key creation in R2, the runtime checks A1 to A5, X2, F1.

### Status 2026-11-08

Settled or taken, no further owner input needed (all still reversible until the gate that publishes them):

- D-2 port order: followed; the Go port is built and every golden passes.
- D-7 `core/`, `spacevibe.dev/core`: in use.
- C1/Q1, C2/Q8: in use (canonical bytes with asserted case counts; the Go test owns the golden after the Swift tests were deleted).
- C3/Q2: the frozen fixtures are named skipped sites in the rename report (plan, Verification evidence).
- D-3: `spacevibe statusline install|undo|capture` is built; `SpaceVibeStatusline` is deleted.
- D-4: the core does not run `claude --version` or `codex --version`.
- D-5: UI-only work continued (UI v5 track); re-targeting the engine tasks of the Agents and Tokens plans is for those plans' owners (not checked here).
- Spike item: no longer open; the Go port reads `.jsonl.zst` fixtures, parses TOML and cross-builds (plan, Verification evidence).

Still open:

- D-1 repo name: settled on 2026-11-21, see "Owner answer on the repo name" below.
- D-6 and X2: Windows hardware run, not done.
- New Sparkle key pair and the account flip (R2), then AC7 and the H7 check.
- Runtime checks A1 to A5, F1 eye approval, and every outward gate still to run (REL1, GH2, WEB1 to WEB3; GH1 ran on 2026-11-21).
- Windows and Linux UI technology; Hub `/vote`, marketing and the workspace map (workspace session).

## Owner answer on SV5 (2026-11-20)

The [product spec](2026-11-02-spacevibe.md) (RQ-SV5) said that narrowing SV5's "byte for byte" needed the owner's explicit yes, and "tiếp tục hết tất các phase" had only been read as one. Asked directly as DN-Q3 of the docs-normalization plan (record removed 2026-11-22, in git history) with the recommendation "record an explicit yes to the narrowing", the owner answered: "ok" (2026-11-20).

So SV5 reads: the Go core matches the frozen goldens as canonical bytes of the named projections, with the case counts asserted (row C1/Q1 above). The goldens have been frozen on that reading since 2026-11-07. Nothing else in SV5 changes.

## Owner answer on the repo name (2026-11-21)

Owner, in chat: "tôi muốn chuyển đổi repo này chỉ tên là spacevibe, không còn [tên cũ] nữa, và repo nó sẽ có domain là spacevibe.dev luôn, tôi đã mua domain này rồi".

- D-1 is settled: the repository is `mxrsv/spacevibe`, not `spacevibe-app`. `GITHUB_REPO` in `scripts/release.sh` and `GITHUB_URL` in `site/components/landing/content.ts` already held that value and are no longer working values.
- Gate GH1 ran the same day on those words: the GitHub repository was renamed to `mxrsv/spacevibe`. GitHub redirects the old URL, so a `v0.1.0` copy still reaches the `v0.1.0` feed until REL1 publishes a newer one (H7 of the go-core plan stays open until then).
- `spacevibe.dev` as this repo's domain restates SV10 and SV16. It does not waive the deploy gates: WEB0 to WEB3 of the [landing spec](2026-11-05-spacevibe-landing.md#deploy-gates) still stand, and on 2026-11-21 the domain still served the Hub.
- Not decided here: the name of the local checkout folder (`spacevibe-reins` in the workspace) and the workspace `AGENTS.md` row, which belong to a workspace session.

## Owner answer on the former name (2026-11-22)

The owner asked, in chat on 2026-11-22, that nothing related to the former product name remain in the repo, records and fixtures included (paraphrased, because the words name it). Asked first whether the fixture path, the fixture data folder, the old update account and the legacy status-line wrapper should stay, the owner answered that everything goes. This lifts the exceptions SV9 was read with (dated records, frozen fixtures) and the docs-map rule that paths are never renamed, for this one change.

Done that day:

- The twelve frozen or historical records were removed from the tree (list in the [docs map](../README.md#specs-and-plans)); the eleven living specs and plans took the `spacevibe` slug, and every link, comment and body text followed.
- The fixture root is `/private/tmp/spacevibe-fixture-home` and the fixture data folder is `.spacevibe`. SV5's freeze was opened once for it: path-hashed ids in five goldens, `manifest.json` and `SHA256SUMS` changed, nothing else ([how](../internals/overview.md)).
- Owner quotes that held the former name carry a bracketed substitution.

Still holding the former name, each waiting on a step outside the repo:

| Site | Why it stays | What retires it |
| --- | --- | --- |
| `dev.spacevibe.reins` in `generate-update-feed.sh`, `test-update.sh`, `Info.plist`'s comment, AGENTS.md B3 and B8, the release runbook | It is the Keychain account of the only update key that exists, and the bundle id of the shipped `v0.1.0` | The owner creates the new key (runbook, "Before the first SpaceVibe release"), then the account flips and the lines go |
| `reins-statusline` and the old data folder in `core/internal/statusline` (`quote.go`, `install_test.go`), `scripts/test-statusline.sh`, `docs/internals/limits.md` | The owner's own `~/.claude/settings.json` still runs that wrapper (seen 2026-11-22, read only); without the unwrap an install would wrap it a second time | The owner reinstalls the capture from the app once, then the recognition and its tests are deleted |
| The local folder name in `Checkout:` lines and `~/scratch/` paths | The folders on disk still have that name; other sessions and the agent memory path depend on it | A workspace session renames the checkout and the scratch folder, then the lines follow |

## Owner answer on the licence (2026-11-22)

Asked which licence SpaceVibe takes, with GPL-3.0-only, MIT, Apache-2.0 and "not yet" offered, the owner picked "GPL-3.0-only" in the agent's question dialog. The offered line read: the same as the owner's TinySift engine; a redistributed change must stay open; a `TRADEMARK.md` keeps the name and logo.

- SV18 is recorded above. [`LICENSE`](../../LICENSE) holds the GPL version 3 text; "only" means no "or any later version" grant, stated in the [README](../../README.md#licence).
- Shipped dependencies were checked for compatibility the same day from [`Resources/Licenses`](../../Resources/Licenses): Sparkle (MIT), `klauspost/compress` and Go (BSD-3-Clause), MingCute (Apache-2.0); Phosphor is MIT and Inter is OFL ([`Credits.swift`](../../Sources/SpaceVibe/App/Credits.swift)).
- Added with it, as the agent's choice and not the owner's wording: [`TRADEMARK.md`](../../TRADEMARK.md) including the line that SpaceVibe is not affiliated with Anthropic or OpenAI, [`CONTRIBUTING.md`](../../CONTRIBUTING.md), [`SECURITY.md`](../../SECURITY.md), the issue forms and the pull request template.
- Not done: L14 and LP-R6 of the [landing spec](2026-11-05-spacevibe-landing.md) say the page names no licence and labels the link "GitHub" until a `LICENSE` exists. One exists now; the page's wording is a site change with its own gates.
- SV18 has no row yet in the product spec's SV traceability table.

## Out of scope for this ledger

Building the Windows or Linux shell, the visual design of the `spacevibe.dev` landing, and any edit outside this repository.

## Traceability (W20)

Done: the [product spec](2026-11-02-spacevibe.md#decision-traceability-w20) maps SV1 to SV17 to a requirement ID and an acceptance check. The acceptance for the port is SV5 as the owner narrowed it (canonical bytes of the named projections, see "Owner answer on SV5"). "No reference to the former name remains" (SV9, SV11) is a repo-wide search ending in "changed N of M, each skipped site named", with the fixtures and the `v0.1.0` release text reported separately; the go-core plan's task R6 holds that report.
