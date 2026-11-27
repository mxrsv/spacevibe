# SpaceVibe: landing redesign, build plan

Started 2026-11-27. Status: in progress; the owner approved the build with four bands on 2026-11-27 ("Build with 4 bands", L39).
Spec: [2026-11-05-spacevibe-landing](../specs/2026-11-05-spacevibe-landing.md) (ledger L21 to L38, LP-R9 to LP-R16, LP-A10 to LP-A14; LP-R4, LP-R6, LP-R7 and LP-A6 still hold). This plan does not repeat the requirements.
Mock picked by the owner (L38): `~/scratch/spacevibe/2026-11-27-landing-redesign/mock.html`, its page in `~/scratch/spacevibe/2026-11-27-landing-redesign/site/` (dev server `:3213`). Kanu renders the app drawings follow: `~/scratch/spacevibe-reins/2026-11-27-kanu-redesign/` (read only).
Checkout: this repository on `main` (baseline `9fa2235`), one commit per task, nothing pushed. A branch switch is avoided because other sessions and the owner's dev server (`:3200`) use this checkout. Commit with `git commit -- <paths>`, never `git stash`.

## Approach

- **Port, do not redraw.** The mock's page is already a working copy of `site/`. Each task moves one region from the scratch copy into `site/`, keeping only the picked options (violet, Space Grotesk, tiles with icons, motion on, the drawn app) and deleting every `MOCK ONLY` switch, the `captures=current` path, the blue accent option and the `tiles=names` mode (FE-P1: options not picked are removed).
- **One Inter.** The app drawing uses the landing's own Inter through `--font-inter`; the 352 KB `InterVariable.woff2` the mock added is not ported.
- **Tokens only.** Every colour, including the stage ramp and violet, is a token in `app/globals.css`; `landing-facts.test.mjs` keeps raw colours out of `className`.
- **Nothing deploys.** WEB0 to WEB3 and LP-R7 hold; the branch is pushed or merged only on the owner's word.

## Tasks

| ID | Task | Serves | Done when |
| --- | --- | --- | --- |
| LR-T1 | Tokens in `globals.css` (ground `#0a0a0b`, violet steps, stage ramp, dot grid, tile, line), Space Grotesk through `next/font/google` for display only; delete the planet scene, starfield, `scene.css` and their assets. `AGENTS.md`: Space Grotesk is the one typeface exception, for `site/` only. | LP-R9, L32, L36 | LP-A10 and LP-A14 hold; `npm run build` exits 0 |
| LR-T2 | Header with the announcement bar and the band pill; multi-column footer. | LP-R10, LP-R15 | Shots at 320 and 1440 match the mock |
| LR-T3 | Hero: eyebrow, headline, line, two buttons, "Works with", tiles from `lg:`, and the hero app drawing (Skills ranked list) in its preview frame. | LP-R11 | Shots at 320, 768, 1024, 1440 match the mock; no tile touches text |
| LR-T4 | App drawing components (`components/landing/app-stage/`) for Skills, Subagents, Hooks and Rules, from the mock; then the Gateway bands with floating figures and the slim ledger rows; `content.ts` carries the new band copy. | LP-R13, L37 | Side-by-side of each drawing against its Kanu crop shows only the ramp change; no figure twice |
| LR-T5 | Manifesto, the figures band, the FAQ restyle and the two ending cards; remove the old private, upcoming and download components. | LP-R12, LP-R14, LP-R15 | Shots match the mock; no `<form>` or `<input>` |
| LR-T6 | Motion component: the five once-only effects; final values in the server HTML; reduced motion. | LP-R16 | LP-A13 holds |
| LR-T7 | Tests and metadata: rewrite `landing-facts.test.mjs` for the redesign (it reads the deleted `scene.css` today); keep `redirects.test.mjs` passing; retake `/og.jpg` from the built first viewport; `site/README.md` if a command changed. | LP-A11 | `node --test site/tests/*.test.mjs` passes |
| LR-T8 | Checks: build, tests, break-test with worst-case copy, audit of LP-A8 and LP-A12 at 320/390/768/1024/1440 on the built page, `build-review`-style read of the motion and counters; fix what fails. | LP-A10 to LP-A13 | Every check pasted in the handoff |
| LR-T9 | Owner's eye approval of the built page at 1440 and 390 in their own dev server (`cd site && npx next dev`), beside the mock. | LP-A6 | The owner's words recorded in the spec ledger |

Waves for subagents: LR-T1 alone (shared tokens); then LR-T2 to LR-T6 one after another, because all of them touch `globals.css` and `content.ts`; LR-T7 and LR-T8 after; LR-T9 last.

## Open

- **Clean, Limits and Activity bands** wait for their Kanu renders (L39); the header pill lists the four built bands until then.
- **"Works with" names two CLIs** while the Kanu drawings show five agents. The row follows the core (`core/internal/cliregistry`); the drawings stay as drawn and are captioned as design previews.

## After the landing (L22)

Impeccable's files (`/impeccable doctor`, `document`), and PRODUCT.md's accent (still blue) with the app's redesign.

## Handoff

2026-11-27: plan written; nothing built in `site/`. Spec ledger L21 to L38 and this plan are uncommitted.

/goal Build the landing redesign of docs/specs/2026-11-05-spacevibe-landing.md (L21–L39) into site/ on main per docs/plans/2026-11-27-landing-redesign.md, until LP-A10 to LP-A14 pass with their output pasted in the plan's handoff and the owner has approved the built page by eye (LP-A6); deploy nothing.
