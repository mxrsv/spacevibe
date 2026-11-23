# SpaceVibe site

The public page for `spacevibe.dev`: Next.js 16 (App Router, static export) and Tailwind CSS 4. It has no server, no data fetching and no form; `next build` writes `out/`, which any static host serves as-is.

| Command         | Purpose                                                   |
| --------------- | --------------------------------------------------------- |
| `npm run dev`   | Dev server on `http://localhost:3000`                     |
| `npm run build` | Static export into `out/` (also the typecheck)            |
| `npm run lint`  | ESLint                                                    |
| `node --test tests/*.test.mjs` | `vercel.json` redirects (live family, old Hub routes, no shadowing) and the landing facts |

Layout: `app/` (layout, page, `globals.css` tokens, `scene.css` planet scene), `components/landing/` (one file per section; `content.ts` holds every word of `/`, `shots.ts` the app captures and how they were taken, `band-icon.tsx` a hand copy of the app's five page icons from [`Resources/PageIcons.json`](../Resources/PageIcons.json): no script writes it, so a page icon that changes is changed in both), `public/landing/` (the deep-space raster and three star tiles, shared with the Academy landing; `app/` holds the captures).

The app captures show the app's synthetic illustration data, never a real `~/.claude`; every caption says "demo data".

`vercel.json` holds the redirects (`output: "export"` rules out `next.config` ones): the `/live` family goes to `https://active.spacevibe.dev`, every other old Hub route goes to the same path on `https://kyant.dev`. Hub's own `/` is not redirected; this site serves it.

Routes: `/` only, plus the dark `404.html` from `app/not-found.tsx`. It is the Two CLIs direction the owner picked (L16), with the hero picked on 2026-11-23 (L17); requirements, what is inferred and the deploy gates are in the [landing spec](../docs/specs/2026-11-05-spacevibe-landing.md#deploy-gates).
