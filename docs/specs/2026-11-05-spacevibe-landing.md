# SpaceVibe: landing page standardisation

Date: 2026-11-05
Status: built, 2026-11-22; not accepted. `/` is the picked direction, Two CLIs (L16), with captures of the redesigned app; the owner's eye approval at 1440 and 390 (L10) and every deploy gate are open. Two captures are owed (LP-R4). The page is the landing of `spacevibe.dev` (SV10), so every hostname below reads `spacevibe.dev`.
Status as written on 2026-11-05: draft. Decision ledger only, from the owner's grilling on 2026-11-05; the owner confirmed it the same day ("ok") and asked for the mock directions to be built directly in the `site/` dev server. Requirements, acceptance criteria and the traceability table (W20) are added once the owner has picked a direction.
Handoff 2026-11-05: the owner accepted the layout of the mock round ("layout tạm ổn") and named the app's own screens as the remaining problem ("app stage chưa tốt"): the four categories look alike. The design language v4 that restyles them is not built (its plan says "no Swift written yet") and the palette is still changing (`ec27b4a`, 15:51, after the captures at about 15:15), so the captures in `site/public/landing/app/` are placeholders. (Update 2026-11-20: v4 was replaced by v5, which is built; the shot command is now `SPACEVIBE_SHOT_SCREEN=<screen> scripts/dev-fixture.sh --shots <dir>`, with the screen names listed in [DESIGN-LANGUAGE.md](../DESIGN-LANGUAGE.md#gallery-and-verification).) After v4 lands, re-shoot with `SPACEVIBE_SHOT_SCREEN=<loadout|limits|activity|rules> scripts/dev-fixture.sh --shots <dir>` (limits with `SPACEVIBE_FIXTURE_LIMITS=typical`) and redo the crops by eye from the 2880x1800 captures; the layout code does not change.
Parent: [SpaceVibe](2026-11-02-spacevibe.md). Earlier record of the first build: site landing plan (record removed 2026-11-22, in git history).

## Scope

The page in [`site/`](../../site/README.md) was generated once on 2026-11-03 and never polished or reviewed ("chỉ generate 1 lần từ agent chưa polish hay qua các vòng review"). This work makes it fit SpaceVibe: its claims match what the download does, and the parts that present the app match the app.

Out of scope: the app itself, DNS and production hosting for `spacevibe.dev`, the hub card, a `LICENSE` and root `README.md` (launch plan L8), building Agents or Tokens.

## Decision ledger

Quotes are the owner's words. "No objection" means the owner was told a recommendation stands unless a question number is named, and named none.

| ID | Decision | Owner's words |
| --- | --- | --- |
| L1 | Goal: standardise the landing page for SpaceVibe; the current page is a temporary frame. | "với landing page tôi muốn chuẩn hoá phù hợp dành cho [SpaceVibe]" |
| L2 | Look is option C: the planet scene and stars stay behind the hero and the download band; the bands between follow the app's design language (real app screenshots in a window frame, Inter, tonal layers, CTA in the app's accent token). | "giữ hành tinh" then "ok ânậnận" (accepts C) |
| L3 | The page is dark only. | "ok ânậnận" (accepts Q11) |
| L4 | Stack (Next.js static export + Tailwind in `site/`), English only, CTA to GitHub Releases stay. | No objection |
| L5 | The hero leads with evidence (which skills, agents and hooks actually ran); Limits is the secondary beat. | No objection |
| L6 | The page may describe the next version, with "coming soon" marks. | "q4-b" |
| L7 | Shipped features are shown with real screenshots from the fixture home. Features in development are shown with a mock render in a different frame, labelled "Design preview, not in the current download". | "nhận cả 3" |
| L8 | "Coming soon" covers Agents and Tokens only, labelled "In development", no date and no version. Settings is not on the page. | "nhận cả 3" |
| L9 | Interested visitors get a "Watch releases on GitHub" link; no form and no email capture. | "nhận cả 3" |
| L10 | The owner's gates: at least three mock directions, the owner picks one before code; then the owner's eye approval at 1440 and 390 in their own dev server. | "q6-1 và 5" |
| L11 | `impeccable` (build, `distill`, `clarify`) runs unattended. The `frontend-design-bar` screenshot gate and `review-experience` at 375/768/1440 are skipped. | "cổng ảnh frontend-design-bar và review-experience ở 375/768/1440 thì bỏ qua" |
| L12 | Reviews happen on a Vercel preview that is not public; no DNS for `spacevibe.dev` until the owner approves it separately. | No objection |
| L13 | Section order: hero, Loadout, Limits, Activity, Rules, In development (Agents, Tokens), Private by construction, Download. When Agents ships, that release's PR replaces the Rules band. | "ok ânậnận" (accepts Q12) |
| L14 | The download band says "Free"; no licence is named until the owner picks one. The "Source on GitHub" label becomes "GitHub" until a `LICENSE` exists (the label change is derived: "open source" is claimed only with a licence). | "ok ânậnận" (accepts Q13 b) |
| L15 | The page says "macOS 15 or later, Apple silicon". The local build is `arm64`; the published DMG is checked at build time. | Derived from a verified fact, not an owner quote |
| L16 | Direction picked at the first gate: the second option in the switcher, Two CLIs (`/directions/two-clis`). | "tôi chọn option B" (read as the second of Deck, Two CLIs, Manual) |

Conflict kept visible: L6 lets the page show screens the app does not have yet. The app's own rule is to say plainly what it cannot measure, and the Limits page once drifted from its mock. L7 and L8 are the guard: a visibly different frame and label for anything unshipped, replaced by a real screenshot in the release that ships it.

## Mock round (ledger L10, first gate)

Built 2026-11-05 in `site/`, viewed with `cd site && npx next dev -p 3100` at `http://localhost:3100/directions` (port 3000 is the hub's dev server). The surface structures were dealt by `impeccable concept-seed` (key `4b19c235`, candidates 4, 6, 5 of a seven-item list); the visual world is fixed by L2 and L13, so the directions differ in composition only. The hero is shared by all three; hero variants wait for the owner's pick.

| Route | Direction | Composition |
| --- | --- | --- |
| `/directions/deck` | Deck | Each screen is a viewport-tall sticky band; the next screen slides over it. |
| `/directions/two-clis` | Two CLIs | The real screen, then one block per CLI on what differs between Claude Code and Codex. |
| `/directions/manual` | Manual | Sticky rail of the four screens; each chapter is question, screen, what SpaceVibe does, what it cannot see. |

Owner feedback on the first round: the four categories looked alike and the options did not differ. The bands now show one signature crop per category instead of the whole window (Loadout's paired bars, Limits' figure and ruler, Activity's two lanes, Rules' Allow/Ask/Deny pickers) with the sidebar tab the category lives behind beside the caption; only the hero keeps a whole window. Real screens are dark captures of the SwiftUI app on the synthetic fixture home (`site/public/landing/app/`); Agents and Tokens are renders of the tracked mocks and are captioned as design previews (L7). On pick (done 2026-11-22): the other two directions, `/directions` and `DirectionSwitcher` are deleted, the copy lives in `site/components/landing/content.ts`, and `/` is the picked direction.


## Requirements

| ID | Requirement | Serves |
| --- | --- | --- |
| LP-R1 | `/` is the Two CLIs direction: every band is a question, the real screen, and one block per CLI on what differs. No other direction, switcher or first-generation section remains in `site/`. | L1, L16 |
| LP-R2 | The planet scene and stars sit behind the hero and the download band only; the page is dark only, English only, Next.js static export with Tailwind, and the CTA goes to GitHub Releases. | L2, L3, L4 |
| LP-R3 | The hero asks which skills actually run and shows a real app window; Limits is a later band. | L5 |
| LP-R4 | Every shipped screen is a real capture of the app on synthetic data, captioned "demo data". Owed: the Limits and Activity bands show the inspector of an Inbox row, because the redesigned Limits and Activity pages do not render in a headless capture; whole-page captures replace them once those pages can be captured. | L7 |
| LP-R5 | A page that is not in the download is named and labelled "In development", says it is not in the current download, carries no date and no version, and sits beside a "Watch releases on GitHub" link. It shows no screen until a render in the app's current look exists; that render then takes a dashed frame captioned "Design preview · not in the current download" (L7). The 2026-11-03 Tokens mock was removed from the page on 2026-11-22: the owner pointed at it as "version đã cũ". No form, no email capture. Settings is not on the page. | L6, L8, L9 |
| LP-R6 | The download band says "Free" and names no licence; the repository link reads "GitHub"; the page says "macOS 15 or later" and "Apple silicon". | L14, L15 |
| LP-R7 | Nothing is deployed and no DNS changes without the owner's separate approval; reviews happen locally or on a preview that is not public. | L10, L12 |

## Acceptance

| Check | Requirement |
| --- | --- |
| LP-A1 `cd site && npm run build` lists `/` and `/_not-found` only, and `git grep -n directions -- site` finds no route or component. | LP-R1 |
| LP-A2 `node --test site/tests/*.test.mjs` passes: every screen the page names is a file, every band has a screen and a line per CLI, the Limits copy names the usage cache, no redirect shadows a served route. | LP-R1, LP-R4 |
| LP-A3 At 1440 and at 390 the page has no horizontal scroll and every image loads. | LP-R2, LP-R3 |
| LP-A4 `grep -n "licen" site/components/landing/content.ts` is empty and the download band holds "Free", "macOS 15 or later" and "Apple silicon". | LP-R6 |
| LP-A5 The "In development" band shows no capture in an older look, and says "Not in the current download"; no `<form>` or `<input>` is in `site/out/index.html`. | LP-R5 |
| LP-A6 The owner approves the page by eye at 1440 and at 390, beside the app. | L10 |
| LP-A8 Audit of 2026-11-22 holds: text contrast at least 4.5:1, every link at least 24 px tall, no horizontal scroll at 320, 390 and 1440, a link that opens a new tab says so to a screen reader, headings read as separate words. | LP-R2 |
| LP-A7 No Vercel project, deploy or DNS change was made by an agent. | LP-R7 |

## Traceability (W20)

| Decision, quoted | Requirement | Acceptance check |
| --- | --- | --- |
| L1 "với landing page tôi muốn chuẩn hoá phù hợp dành cho [SpaceVibe]" | LP-R1 | LP-A1, LP-A6 |
| L2 "giữ hành tinh", L3 and L4 | LP-R2 | LP-A3, LP-A6 |
| L5 (no objection) | LP-R3 | LP-A6 |
| L6 "q4-b", L8 and L9 "nhận cả 3" | LP-R5 | LP-A5 |
| L7 "nhận cả 3" | LP-R4 | LP-A2, LP-A6 |
| L10 "q6-1 và 5", L12 | LP-R7 | LP-A6, LP-A7 |
| L11 (which review gates run) | process only | none |
| L13 "ok" (accepts Q12) | LP-R1, as amended under "Inferred, not decided" | LP-A6 |
| L14, L15 | LP-R6 | LP-A4 |
| L16 "tôi chọn option B" | LP-R1 | LP-A1 |

## Inferred, not decided

Lines with no owner decision behind them. The build follows them; the owner settles them at LP-A6.

- **The captures show the redesigned app** (`SPACEVIBE_REDESIGN=1`), which is built but not cut over or approved by eye. Source: agent's choice, because the owner rejected the earlier look and the page cannot be deployed before the owner's gates anyway. If the redesign changes before cut-over, the captures are retaken.
- **Band order is Clean, Skills, Rules, Limits, Activity**, replacing L13's Loadout, Limits, Activity, Rules. Source: the app's pages today and the job order in `PRODUCT.md`; L13 named pages the app no longer has.
- **"In development" holds Tokens only**, where L8 named Agents and Tokens. Source: the Agents pages (Skills, Subagents, Hooks, Rules) are in the app. L13's "when Agents ships, that release's PR replaces the Rules band" is read as overtaken by the same fact.
- **The hero window is the Inbox**, not a usage list. Source: agent's choice; the Inbox is where "never ran" is shown first in the redesign, which is the evidence L5 asks the hero to lead with.
- **The scene's stars and planet keep moving while the page is idle** (loops of 7 to 96 s, off under reduced motion). The owner's rule FE-M1 says nothing loops while idle; L2 keeps the scene. Source: carried over with the scene; left as is until the owner says which wins.
- **A phone has no section links in the header**, only the brand and the download button; the footer carries them. Source: the first-generation header, unchanged.
- **On a phone a whole capture is shown at about twice the frame's width and cut on the right**, so its text can be read. Source: agent's choice (audit 2026-11-22).
- **Each band opens with the screen's name and an icon, and the two per-CLI text cards are one ledger**: a row per CLI with a verdict (a green check for read in full, an amber eye-off where the CLI logs nothing for part of it, a lock for read only) before the reason. Source: agent's choice (design-direction pass, 2026-11-22), to make what a CLI does not log the page's signature; the verdict words are the agent's.
- **The Codex dot is neutral, not teal**, as in the app (`PRODUCT.md`, Colour). Source: app convention.

## Deploy gates

Moved here from `AGENTS.md` on 2026-11-20.

- **WEB0, before WEB1.** The owner picks a landing direction (L16) and `/` is replaced with it: done 2026-11-22. What still holds WEB0 open is the owner's eye approval (LP-A6) and the lines under "Inferred, not decided"; until then the page must never be deployed.
- **WEB0b, before WEB1.** `Download for macOS` goes to `releases/latest`, which on 2026-11-22 is still the deprecated `v0.1.0` under the former name (`gh release view -R mxrsv/spacevibe`). The page is deployed only after REL1 of the go-core plan has published a SpaceVibe build as the latest release.
- **WEB1 to WEB3.** Creating the Vercel project, repointing `spacevibe.dev` and the DNS check for the retired product subdomain are the owner's gates, done in that order after WEB0 and after `kyant.dev` is verified. They are tracked in the [go-core plan](../plans/2026-11-07-go-core-and-spacevibe-identity.md) (SV16).
