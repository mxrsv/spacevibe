# SpaceVibe: landing page standardisation

Date: 2026-11-05
Status: built, 2026-11-22; not accepted. `/` is the picked direction, Two CLIs (L16), with captures of the redesigned app; the owner's eye approval at 1440 and 390 (L10) and every deploy gate are open. Two captures are owed (LP-R4). Backlog round of 2026-11-23: the owner approved the before/after review of the Landing backlog (L17 to L20), and those items are built into `site/` the same day (LP-R8). On 2026-11-24 the owner looked at the built page on the same review, before beside after, and approved it ("ok approve đủ"), which is the eye approval the push of this round needed (FE-P7). It was given on the review, not beside the app, and the lines under "Inferred, not decided" were not gone through one by one, so LP-A6 and WEB0 are not marked closed here. The same day the owner saw the page from the repository on the dev server and accepted it for now ("tạm thời chấp nhận và push"): a provisional acceptance, so both stay open. The page is the landing of `spacevibe.dev` (SV10), so every hostname below reads `spacevibe.dev`.
Redesign opened 2026-11-27 (L21): the structure follows the Dstudio reference; the open questions are settled row by row from L23 on, and `/` stays as built until a new direction is picked.
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
| L17 | Hero: layout B (words left, one panel of five readings right) with the second headline, "See what your coding agents carry.". | "ok chốt toàn bộ" (2026-11-23; see "Backlog round") |
| L18 | On a phone a capture pans sideways instead of being cut on the right (BL-LAND-7, option `pan`). | "ok chốt toàn bộ" (2026-11-23) |
| L19 | Nothing in the scene loops while the page is idle; the planet and the stars stay, at rest (BL-LAND-27, option `static`). | "ok chốt toàn bộ" (2026-11-23) |
| L20 | The backlog items the review showed are accepted as shown: BL-LAND-1 to 11, 16 to 19, 23 to 40, 42, 43 and 49. BL-LAND-22 follows from L17. | "ok chốt toàn bộ" (2026-11-23) |
| L21 | The landing is redesigned in structure after the Dstudio reference (two Dribbble shots of one landing, 2026-11-27: `dribbble.com/shots/24829480`, `dribbble.com/shots/24836502`), not only restyled: the page rhythm, the hero and the bands may change. Product truth, the copy's facts and the deploy gates stay. L17 (hero layout B) and L2 (planet scene) are open again and are settled by later rows of this ledger; until then they hold for the shipped `/`. The surface-only pass (option A, mock `~/scratch/spacevibe/2026-11-27-landing-dstudio/mock.html`) is kept as the comparison. | "tôi chọn B cho grill" (2026-11-27) |
| L22 | Impeccable's project files (`/impeccable doctor`, `document`, the PRODUCT.md record) are updated only after the redesigned landing is done, not during it. | "impeccable nên làm xong landing rồi mới nên updatge" (2026-11-27) |
| L23 | The redesigned landing keeps the app's blue accent (`#0b6fe4`, PRODUCT.md, Colour). From the reference it takes the structure and the restraint (one accent, used sparingly), not the lime; no exception to PRODUCT.md's colour rule or its "neon on black" anti-reference. | "ok giữ xanh dương" (2026-11-27) |
| L24 | The background follows the reference, replacing L2: no planet scene anywhere on the page; a near-black ground with a faint dot grid, and thin lines joining the CLI marks around the hero. Where the reference has a dark 3D illustration, the page shows a real capture of the app. The stars go with the planet. | "theo mẫu" (2026-11-27), answering option B of question 3 |
| L25 | Hero follows the first shot, replacing L17: centered, a pill eyebrow, a large light-weight headline, two CTAs, then the "Works with" row of CLI marks; a real app window shows partly in the first viewport just below. The five readings move to a later band of large figures (the reference's "requests served / chains indexed" block). L5 holds through the window: the first viewport shows the evidence as the app's own rows. | "A" (2026-11-27), answering question 4 |
| L26 | Motion follows the reference's video (`dribbble.com/shots/25138063`), each effect once and never looping: the hero rises in steps on load; the manifesto lights word by word as it scrolls; headings and figures slide up from behind a mask, figures counting up; section headings slide in; logo rows appear in turn. Nothing moves while the page is idle (L19 holds); the reference's auto-advancing list is not taken. Reduced motion shows every element in its final state. | "yes theo A" (2026-11-27), answering question 5 |
| L27 | Each screen band follows the reference's "Your Gateway" block: words left (pill, the question, the answer), right a real capture of that screen in a dark card with one floating figure card taken from the same screen (the reference's "$4,546" card); the per-CLI ledger sits under it as one slim row, like the reference's four-feature row. All five screens stay visible while scrolling; none hides behind a click. | "A" (2026-11-27), answering question 6 |
| L28 | The band of large figures (the reference's "11 Billion / 35+ / 4100+" block) shows facts about the product that hold on every Mac, from PRODUCT.md (for example: CLIs read, accounts and telemetry, clicks to undo), beside a short block of words; it takes the place of "Private by construction". The five demo readings live only on the floating cards of L27, so no figure shows twice (PRODUCT.md); this replaces the part of L25 that moved them to this band. The exact figures are settled on the mock. | "A" (2026-11-27), answering question 7 |
| L29 | The page ends with the reference's two cards side by side, after the FAQ: left a dark card "Watch releases on GitHub" that also says Tokens is in development (the separate "In development" band goes; L8 holds through this card), right a solid blue card "Download for macOS" with "Free · macOS 15 or later · Apple silicon" (L14, L15). No newsletter (L9). A multi-column footer as in the reference. | "A" (2026-11-27), answering question 8 |
| L30 | The faint tiles around the hero (L24) hold what an agent carries: the app's own Bold icons for skill, subagent and hook (`Resources/PageIcons.json`: `skills`, `subagents`, `hooks`), joined by thin lines. They are still and appear in turn on load (L26). How many tiles, and whether a tile also names an item of the synthetic fixture, is settled on the mock. | "c" (2026-11-27), answering question 9 |
| L31 | The header follows the reference: a thin announcement bar on top, "Tokens is in development · Watch releases" linking to GitHub releases; under it the brand, the five band links grouped in one outlined pill, then `GitHub` (outlined) and `Download for macOS` (blue). The bar repeats the left card of L29 on purpose. | "B" (2026-11-27), answering question 10 |
| L32 | Headlines and large figures use a display face "a little unusual, like the reference"; body text stays Inter. The face is picked by eye on the mock from open-licence grotesks (candidates: Space Grotesk, Geist, and a General Sans-like face whose licence is checked before it ships). This is an exception to "Inter is the only typeface" for `site/` only, written into `AGENTS.md` in the build that ships it; the app keeps Inter. | "dùng font khác lạ chút, ví dụ như Dstudio" (2026-11-27), answering question 11 |
| L33 | The owner accepts the redesigned landing's look and layout on the mock of 2026-11-27 (`~/scratch/spacevibe/2026-11-27-landing-redesign/mock.html`), but not the app captures inside it: the app's own screens look poor beside the new page. How the bands show the app is open (next row). | "giao diện landingpage ổn nhưng cho các app stage của chúng ta đang quá xấu nên nhìn ghép trong landing nó không được đẹp mắt" (2026-11-27) |
| L34 | Answer to "how do the bands show the app" (after L33): the app is being redrawn in full (the "Kanu" redesign, renders in `~/scratch/spacevibe-reins/2026-11-27-kanu-redesign/out/`, Skills look approved there as its D12), so the bands show the app in that new look. Read by the agent, not said by the owner: L7 still holds, so a screen the download does not have yet is shown in the "Design preview" frame until the release that ships it; the accent of L23 ("the app's blue") follows the app, which the new look draws in violet, and is asked again. | "app đang vẽ mới lại hoàn toàn rồi" (2026-11-27), with the link to the Kanu renders |
| L35 | The landing's accent is the new app's violet (`#7256F6`, from the Kanu redesign's `system.md`), replacing the blue of L23; L23's restraint stays (one accent, used sparingly). PRODUCT.md still names blue as the accent: it is updated with the app's redesign, after the landing (L22). | "Violet like the app" (2026-11-27) |
| L36 | The display face of L32 is Space Grotesk (OFL), for headlines and large figures; body text stays Inter. Geist and Instrument Sans are dropped. | "Space Grotesk" (2026-11-27) |
| L37 | The app inside the bands and the hero is redrawn as crisp HTML on the page, faithful to the Kanu renders (layout, type, icons, data), not shown as screenshots; its surfaces are retuned to sit on the landing's ground. Read by the agent: until the app ships that look, each drawing keeps the "Design preview" frame (L7, L34); whether drawings or real captures show the app after it ships is asked then. | "phải vẽ lại chuẩn chỉ, và cho màu nền background hợp với landing chút" (2026-11-27) |
| L38 | The owner approves the redesign mock as the direction to build (accent violet, Space Grotesk, the app drawn as HTML on the cool ramp, tiles with icons only, motion on), and asks for the build plan. This is the mock pick before code; the eye approval of the built page (LP-A6) stays open. | "Approve, write plan" (2026-11-27) |
| L39 | Build the redesign with four screen bands (Skills, Subagents, Hooks, Rules), the ones the Kanu renders cover; Clean, Limits and Activity bands are added when their renders exist. Nothing deploys meanwhile. | "Build with 4 bands" (2026-11-27) |

Conflict kept visible: L6 lets the page show screens the app does not have yet. The app's own rule is to say plainly what it cannot measure, and the Limits page once drifted from its mock. L7 and L8 are the guard: a visibly different frame and label for anything unshipped, replaced by a real screenshot in the release that ships it.

## Mock round (ledger L10, first gate)

Built 2026-11-05 in `site/`, viewed with `cd site && npx next dev -p 3100` at `http://localhost:3100/directions` (port 3000 is the hub's dev server). The surface structures were dealt by `impeccable concept-seed` (key `4b19c235`, candidates 4, 6, 5 of a seven-item list); the visual world is fixed by L2 and L13, so the directions differ in composition only. The hero is shared by all three; hero variants wait for the owner's pick.

| Route | Direction | Composition |
| --- | --- | --- |
| `/directions/deck` | Deck | Each screen is a viewport-tall sticky band; the next screen slides over it. |
| `/directions/two-clis` | Two CLIs | The real screen, then one block per CLI on what differs between Claude Code and Codex. |
| `/directions/manual` | Manual | Sticky rail of the four screens; each chapter is question, screen, what SpaceVibe does, what it cannot see. |

Owner feedback on the first round: the four categories looked alike and the options did not differ. The bands now show one signature crop per category instead of the whole window (Loadout's paired bars, Limits' figure and ruler, Activity's two lanes, Rules' Allow/Ask/Deny pickers) with the sidebar tab the category lives behind beside the caption; only the hero keeps a whole window. Real screens are dark captures of the SwiftUI app on the synthetic fixture home (`site/public/landing/app/`); Agents and Tokens are renders of the tracked mocks and are captioned as design previews (L7). On pick (done 2026-11-22): the other two directions, `/directions` and `DirectionSwitcher` are deleted, the copy lives in `site/components/landing/content.ts`, and `/` is the picked direction.


## Hero round (logo row picked 2026-11-22; layout and headline picked 2026-11-23, L17)

The owner, on the built page: "khi vào landing không thể biết nhanh app của chúng ta làm việc về gì, phải có nhận diện gì đó tốt hơn". The first viewport today is a question and a cut window whose text is too small to read, so nothing in it says what the app is.

Three layouts and three headlines are built on the review route `/hero-lab` (`?layout=now|a|b|c&headline=0|1|2`, `noindex`), and shown through the mock `~/scratch/spacevibe-reins/2026-11-22-landing-hero/mock.html` (the stage is the built page on `localhost:4317`). Since the logo pick below, `/` shows layout B with the second headline, the recommendation, so the owner judges it on the real page; it is not yet a pick.

| Layout | First glance, second glance | What changes |
| --- | --- | --- |
| A | the heading under a line that names the app; the three jobs | adds the eyebrow "A local Mac app for AI coding agents · Claude Code and Codex today" and three links (Clean up, Control, Watch) above the window |
| B (recommended) | five readings the app produces; the heading | words left, one panel right with a figure per screen, each a link to its band; no window in the hero |
| C | the Inbox's never-ran rows at reading size with Remove; the heading | words left, a crop of the real rows right |

Headlines: "Which of your skills actually run?" (today), "See what your coding agents carry." (recommended), "Clean up what your agents never use."

Owner, 2026-11-22, on the headlines: "không nên đặt tiêu đề là chỉ claude code, codex ? vì chúng ta support nhiều agent mà". The headline and the page title therefore name the category (coding agents), never a list of CLIs; the line above the headline says which CLIs the core reads today (two, `core/internal/cliregistry`), so the page does not claim more than the download does. The per-CLI ledger in the bands follows the registry when it grows.

Owner, 2026-11-22: "để kiểu tiêu đề xong thêm một list logo vào cùng dòng với text thì sao". Picked the same day: "yes có logo agent vào sự nhận diện đã tốt lên rất rất nhiều". Under the heading, one line "Works with" followed by the mark and name of each CLI the core reads today (two); the line above the heading then names only the category. The marks are the ones the app ships in `Resources/Brand`. The research note of 2026-11-21 lists the use of the Claude Code and Codex logos as an unsettled trademark question (its open decision 3); the footer therefore carries "SpaceVibe is not affiliated with Anthropic or OpenAI. Claude Code and Codex are trademarks of their owners." The text-only variant was removed.

On pick: `/` takes the picked layout and headline; the other layouts, the other headlines, `/hero-lab`, `hero-lab.tsx` and the mock's unpicked options are deleted (FE-P1), and L5 is re-read against the pick.

Picked 2026-11-23 (L17): layout B with the second headline, which `/` already showed. BL-LAND-22 deletes the rest, so the table above and the `/hero-lab` route describe options that are no longer in `site/`. L5 re-read against the pick: the hero leads with what the app reads (five readings, "skills never ran" among them), and Limits is one reading and a later band; no window is in the hero, so the line that made the Inbox the hero window was removed from "Inferred, not decided".

## Backlog round (2026-11-23, L17 to L20)

The open items of the Landing section of the [backlog](../BACKLOG.md#landing) were built in throwaway copies of `site/` and shown to the owner beside the page as it was: the review `~/scratch/spacevibe/2026-11-23-landing-backlog/mock.html`, whose stage is the built page itself ("Trước" from the repository, "Sau" from a copy with the items applied, one copy per group and one with every group merged). It showed 36 items and the hero options; the 24 items it did not show are listed in it with the reason (captures to retake from the app, blocked items, and changes nobody can see on the page).

The owner was asked three things in one batch: the hero layout and headline (B with the second headline is this spec's recommendation), the options of BL-LAND-7 and BL-LAND-27 (recommended: pan, static), and which items go into the real build. The answer was "ok chốt toàn bộ". It is read as: every recommendation, and every item shown. Seven consequences were named to the owner before the answer and are covered by it: every hero figure is amber once the state colour sits on the figure (BL-LAND-17 with 18); the focus outline of BL-LAND-9 goes against the owner's general rule FE-K5 on this public page; at 1024 px the reason column of the Activity band is 108 px wide, and below 1024 px the Limits and Activity captures are drawn wider than their source; `crop` loses the name column, which is why `pan` was recommended; the page ground `#0c0c0d` is derived, not an app token; BL-LAND-37 found one true per-CLI difference only and stays open; at 320 px the header fits with no pixel to spare.

Each item is its own commit in `site/`, named by a `Backlog:` line (AGENTS.md, B10). What an agent chose without the owner naming it is under "Inferred, not decided".

## Requirements

| ID | Requirement | Serves |
| --- | --- | --- |
| LP-R1 | `/` is the Two CLIs direction: every band is a question, the real screen, and one block per CLI on what differs. No other direction, switcher or first-generation section remains in `site/`. | L1, L16 |
| LP-R2 | The planet scene and stars sit behind the hero and the download band only; the page is dark only, English only, Next.js static export with Tailwind, and the CTA goes to GitHub Releases. | L2, L3, L4 |
| LP-R3 | The first viewport says what the app is before anything else: a line naming the category, the heading "See what your coding agents carry.", the marks and names of the CLIs the core reads, and beside them one panel with a reading per screen, each a link to its band (layout B). No other hero layout, headline or review route remains in `site/`. Limits is a later band. | L5, L17 |
| LP-R4 | Every shipped screen is a real capture of the app on synthetic data, captioned "demo data". Owed: the Limits and Activity bands show the inspector of an Inbox row, because the redesigned Limits and Activity pages do not render in a headless capture; whole-page captures replace them once those pages can be captured. | L7 |
| LP-R5 | A page that is not in the download is named and labelled "In development", says it is not in the current download, carries no date and no version, and sits beside a "Watch releases on GitHub" link. It shows no screen until a render in the app's current look exists; that render then takes a dashed frame captioned "Design preview · not in the current download" (L7). The 2026-11-03 Tokens mock was removed from the page on 2026-11-22: the owner pointed at it as "version đã cũ". No form, no email capture. Settings is not on the page. | L6, L8, L9 |
| LP-R6 | The download band says "Free" and names no licence; the repository link reads "GitHub"; the page says "macOS 15 or later" and "Apple silicon". | L14, L15 |
| LP-R7 | Nothing is deployed and no DNS changes without the owner's separate approval; reviews happen locally or on a preview that is not public. | L10, L12 |
| LP-R8 | `/` carries the backlog items of L20 as the review of 2026-11-23 showed them: a phone pans a capture sideways and a keyboard can scroll it (L18), and no animation runs while the page is idle (L19). An item that shipped only in part stays open in the backlog with what is left. | L18, L19, L20 |

## Acceptance

| Check | Requirement |
| --- | --- |
| LP-A1 `cd site && npm run build` lists `/` and `/_not-found` only, and `git grep -n directions -- site` and `git grep -n hero-lab -- site` find no route or component. | LP-R1, LP-R3 |
| LP-A2 `node --test site/tests/*.test.mjs` passes: every screen the page names is a file, every band has a screen and a line per CLI, the Limits copy names the usage cache, no redirect shadows a served route. | LP-R1, LP-R4 |
| LP-A3 At 1440 and at 390 the page has no horizontal scroll and every image loads. | LP-R2, LP-R3 |
| LP-A4 `grep -n "licen" site/components/landing/content.ts` is empty and the download band holds "Free", "macOS 15 or later" and "Apple silicon". | LP-R6 |
| LP-A5 The "In development" band shows no capture in an older look, and says "Not in the current download"; no `<form>` or `<input>` is in `site/out/index.html`. | LP-R5 |
| LP-A6 The owner approves the page by eye at 1440 and at 390, beside the app. | L10 |
| LP-A8 Audit of 2026-11-22 holds: text contrast at least 4.5:1, every link at least 24 px tall, no horizontal scroll at 320, 390 and 1440, a link that opens a new tab says so to a screen reader, headings read as separate words. | LP-R2 |
| LP-A7 No Vercel project, deploy or DNS change is made by an agent unless the owner says so for that step. On 2026-11-24 the owner said so for WEB1 ("ok làm đi"): the agent created the project and one deployment that is not public; no domain and no DNS record was touched. | LP-R7 |
| LP-A9 `/` built from the repository is compared with the review's merged build (`all/`, with the picks of L17 to L19) at 320, 390, 768, 1024 and 1440: the same text and the same layout, surface by surface. At those widths the page has no horizontal scroll; `document.getAnimations()` is empty three seconds after load; every item of L20 is ticked in the backlog except the one that shipped in part. | LP-R3, LP-R8 |

## Redesign requirements (2026-11-27)

The redesign of L21 to L38 replaces, once it ships, LP-R1's band shape, LP-R2's planet scene, LP-R3's layout B and LP-R5's separate band; LP-R4, LP-R6, LP-R7 and the no-idle-motion part of LP-R8 still hold. Mock picked by the owner: `~/scratch/spacevibe/2026-11-27-landing-redesign/mock.html` (L38). Plan: [2026-11-27-landing-redesign](../plans/2026-11-27-landing-redesign.md).

| ID | Requirement | Serves |
| --- | --- | --- |
| LP-R9 | Near-black ground with a faint dot grid and thin lines; no planet scene, no stars, no file of the old scene left in `site/`. Accent violet `#7256F6`, used only on the primary button, the download card, links and focus. | L23, L24, L35 |
| LP-R10 | Header: an announcement bar "Tokens is in development · Watch releases"; the brand, the band links in one outlined pill, `GitHub` outlined and `Download for macOS` in the accent. | L31 |
| LP-R11 | Hero centered: pill eyebrow, the headline in Space Grotesk at light weight, one line, `Download for macOS` and a quiet `GitHub`, the "Works with" row of the CLIs the core reads, faint tiles with the app's own skill, subagent and hook icons from `lg:` up, and the app drawn below, partly in the first viewport. | L25, L30, L36, L5 |
| LP-R12 | A manifesto band with PRODUCT.md's Mechanism sentence, in Inter, lighting word by word once. | L26 |
| LP-R13 | One "Your Gateway" band per screen the app drawing covers: pill, question, answer; the app drawn as HTML faithful to the Kanu renders on the stage ramp, in a dashed frame captioned "Design preview · not in the current download" until the release that ships that look; one floating figure visible as evidence in the drawing; the per-CLI ledger as one slim row. Every figure shows once on the page. | L27, L34, L37, L7 |
| LP-R14 | A figures band "Private by construction." with three zero facts from PRODUCT.md and AGENTS.md S-R3 to S-R5, not counted up. | L28 |
| LP-R15 | After the FAQ, two cards: "Watch releases" (Tokens in development) and the violet "Download for macOS" with "Free · macOS 15 or later · Apple silicon"; no form; a multi-column footer. | L29, L9, L14, L15 |
| LP-R16 | Motion: the five once-only effects of L26; `document.getAnimations()` is empty three seconds after load and after a full scroll; reduced motion shows every element in its final state, with final numbers in the server HTML. | L26, L19 |

| Check | Requirement |
| --- | --- |
| LP-A10 `git grep -n -e scene -e starfield -- site` finds no component, style or asset; `out/index.html` holds no `<form>` or `<input>`. | LP-R9, LP-R15 |
| LP-A11 `node --test site/tests/*.test.mjs` passes with the facts test rewritten for the redesign (every band has a drawing and a line per CLI, no raw colour in a className, no figure twice). | LP-R13, LP-R9 |
| LP-A12 At 320, 390, 768, 1024 and 1440 the built page matches the mock surface by surface (headless shots side by side), with no horizontal scroll; text contrast at least 4.5:1, links at least 24 px tall. | LP-R9 to LP-R15 |
| LP-A13 `document.getAnimations()` is empty three seconds after load and after a full scroll; with reduced motion every figure reads its final value. | LP-R16 |
| LP-A14 `AGENTS.md` names Space Grotesk as the one exception to "Inter is the only typeface", for `site/` only. | L32, L36 |

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
| L17 "ok chốt toàn bộ" (hero: layout B, second headline) | LP-R3 | LP-A1, LP-A9, LP-A6 |
| L18 "ok chốt toàn bộ" (phone captures pan) | LP-R8 | LP-A9, LP-A6 |
| L19 "ok chốt toàn bộ" (no idle loop) | LP-R8 | LP-A9, LP-A6 |
| L20 "ok chốt toàn bộ" (the items shown) | LP-R8 | LP-A9, LP-A6 |
| L21 to L38, quoted in the ledger | LP-R9 to LP-R16 | LP-A10 to LP-A14, LP-A6 |

## Inferred, not decided

Lines with no owner decision behind them. The build follows them; the owner settles them at LP-A6.

- **The captures show the redesigned app** (`SPACEVIBE_REDESIGN=1`), which is built but not cut over or approved by eye. Source: agent's choice, because the owner rejected the earlier look and the page cannot be deployed before the owner's gates anyway. If the redesign changes before cut-over, the captures are retaken.
- **Band order is Clean, Skills, Rules, Limits, Activity**, replacing L13's Loadout, Limits, Activity, Rules. Source: the app's pages today and the job order in `PRODUCT.md`; L13 named pages the app no longer has.
- **"In development" holds Tokens only**, where L8 named Agents and Tokens. Source: the Agents pages (Skills, Subagents, Hooks, Rules) are in the app. L13's "when Agents ships, that release's PR replaces the Rules band" is read as overtaken by the same fact.
- **Below 1024 px the header has no section links**, only the brand, GitHub and the download button; the footer carries them. Source: the first-generation header on a phone; BL-LAND-1 (L20) took it up to 1024 px so the page stops scrolling sideways.
- **Each band opens with the screen's name and an icon, and the two per-CLI text cards are one ledger**: a row per CLI with a verdict (a green check for read in full, an amber eye-off where the CLI logs nothing for part of it, a lock for read only) before the reason. Source: agent's choice (design-direction pass, 2026-11-22), to make what a CLI does not log the page's signature; the verdict words are the agent's.
- **A band of seven questions sits before the download band** (free, which CLIs, sign-in, what is written, how exact the cost is, whether Clean changes the usage counts, updates), as native disclosures. The sixth came with BL-LAND-42. Source: agent's choice, from the landing guide the owner pasted on 2026-11-22; every answer restates `PRODUCT.md`. The guide's other missing elements were not built: user counts, ratings and testimonials do not exist and are never invented, a signup form is ruled out by L9, a display typeface other than Inter by L2, and ShadCN by L4.
- **The Codex mark is neutral, not teal**, as in the app (`PRODUCT.md`, Colour). Source: app convention.

From the backlog round of 2026-11-23. The review showed each of these, old beside new, but the owner was not asked about them one by one; L20 covers them only as "the items as shown".

- **Surface steps**: `s1` is the app's `canvasSurface` `#111214`, `s2` `sidebarSurface` `#141518`, `s3` `groupSurface` `#191A1D`, by rising lightness; `--color-void` `#050608` is kept as the scene's black. Source: agent's choice; BL-LAND-11 names the three tokens, not which step takes which.
- **Two tokens the items did not ask for**: `--color-accent-pressed` `#095dc0` (the app's `primaryActionPressed`), so a pressed button is not lighter than its hover, and `--scene-rim-bright` (the accent mixed with 14% white) for the planet's rim, which used to read the hover step when that was the lighter one. Source: agent's choice.
- **Words the items left open**: the Skills verdict "All three counted", the Limits verdicts "Usage cache" and "Last turn", the Codex verdict of Clean "Moved, .jsonl.zst too", the question "Does Clean change my usage counts?" in sixth place, Balance said as "with an action to add it there", and on the 404 page "This page does not exist." with "Back to SpaceVibe" under the title "Page not found · SpaceVibe". Source: agent's choice; every sentence restates `GLOSSARY.md`, `PRODUCT.md` or a page under `docs/internals/`.
- **Below `sm:`** the header button reads "Download" with no arrow (its accessible name keeps "for macOS"), and a hero reading puts its label under its figure. The tablet gutter of 28 px runs from 768 to 1023 px. Source: agent's choice, to fit the brand, GitHub and the button in 280 px.
- **The scene at rest** draws the halo and the ambient light at opacity 0.54, the middle of the range the removed loop ran through, not the brighter state the old reduced-motion rule fell back to. The download band's veil is a centred ellipse of 62% by 80%. Source: agent's choice.
- **The frame of a capture that pans is focusable at every width**, so a keyboard can scroll it at phone width; from 768 px up it is a tab stop that does not scroll. Source: agent's choice, for L18.
- **The band icons are copied by hand** from [`Resources/PageIcons.json`](../../Resources/PageIcons.json) into `site/components/landing/band-icon.tsx`; `scripts/generate-icons.mjs` does not write them, so a change to a page icon is made in both places. Source: agent's choice (BL-LAND-30 says "inline").

## Deploy gates

Moved here from `AGENTS.md` on 2026-11-20.

- **WEB0, before WEB1.** The owner picks a landing direction (L16) and `/` is replaced with it: done 2026-11-22. What still holds WEB0 open is the owner's eye approval (LP-A6) and the lines under "Inferred, not decided"; until then the page must never be deployed.
- **WEB0b, before WEB1.** `Download for macOS` goes to `releases/latest`, which on 2026-11-22 is still the deprecated `v0.1.0` under the former name (`gh release view -R mxrsv/spacevibe`). The page is deployed only after REL1 of the go-core plan has published a SpaceVibe build as the latest release.
- **WEB1 to WEB3.** Creating the Vercel project, repointing `spacevibe.dev` and the DNS check for the retired product subdomain are the owner's gates, done in that order after WEB0 and after `kyant.dev` is verified. They are tracked in the [go-core plan](../plans/2026-11-07-go-core-and-spacevibe-identity.md) (SV16).
