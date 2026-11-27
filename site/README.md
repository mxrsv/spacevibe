# SpaceVibe site

The public page for `spacevibe.dev`: Next.js 16 (App Router, static export) and Tailwind CSS 4. It has no server, no data fetching and no form; `next build` writes `out/`, which any static host serves as-is.

| Command         | Purpose                                                   |
| --------------- | --------------------------------------------------------- |
| `npm run dev`   | Dev server on `http://localhost:3000`                     |
| `npm run build` | Static export into `out/` (also the typecheck)            |
| `npm run lint`  | ESLint                                                    |
| `node --test tests/*.test.mjs` | `vercel.json` redirects (live family, old Hub routes, no shadowing) and the landing facts |

Layout: `app/` (layout, page, `globals.css` tokens), `components/landing/` (one file per section; `content.ts` holds every word of `/`, `shots.ts` the app captures and how they were taken, `band-icon.tsx` a hand copy of the app's five page icons from [`Resources/PageIcons.json`](../Resources/PageIcons.json): no script writes it, so a page icon that changes is changed in both), `public/landing/` (`app/` holds the captures, `brand/` the CLI marks).

The app captures show the app's synthetic illustration data, never a real `~/.claude`; every caption says "demo data".

`vercel.json` holds the redirects (`output: "export"` rules out `next.config` ones): the `/live` family goes to `https://active.spacevibe.dev`, every other old Hub route goes to the same path on `https://kyant.dev`. Hub's own `/` is not redirected; this site serves it.

Deploy: the Vercel project is `spacevibe` in the team `mxrsv-dev` (Next.js preset, Root Directory `site`, Node 24.x), created 2026-11-24 and not connected to Git, so a push deploys nothing. A deployment is made with `vercel deploy` from the repository root of a clean export of the commit (`git archive <commit> | tar -x -C <folder>`, then `vercel link --yes --team mxrsv-dev --project spacevibe` there, which keeps `.vercel/` and the `.env.local` it writes out of this checkout). Two traps: the first deployment of a project becomes its production deployment even without `--prod`, and Vercel then adds a `*.vercel.app` address that is public, because the project's protection covers every address except the project's own domains; that address was removed, and `vercel curl <url>` reads a protected deployment (it adds a bypass secret to the project: remove it afterwards). The gates before `spacevibe.dev` points here are in the landing spec.

Routes: `/` only, plus the dark `404.html` from `app/not-found.tsx`. It is the Two CLIs direction the owner picked (L16), with the hero picked on 2026-11-23 (L17); requirements, what is inferred and the deploy gates are in the [landing spec](../docs/specs/2026-11-05-spacevibe-landing.md#deploy-gates).
