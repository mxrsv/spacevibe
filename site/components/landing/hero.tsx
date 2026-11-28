import Image from "next/image";
import type { CSSProperties } from "react";

import { StageWindow } from "./app-stage/stage-window";
import { SkillsTopStage } from "./app-stage/stages";
import { SkillsWindowStage } from "./app-stage/window";
import { BandIcon } from "./band-icon";
import { ButtonLink } from "./button-link";
import { GITHUB_URL, HERO, HERO_LINE, HERO_WINDOW_LABEL, PREVIEW_CAPTION, TILES, TILE_LINKS } from "./content";

const rise = (ms: number) => ({ "--rise": `${ms}ms` }) as CSSProperties;

/** A tile's centre as a share of the hero's words block. */
const at = (tile: (typeof TILES)[number]) =>
  ({ "--x": `${tile.x}%`, "--y": `${tile.y}%`, "--x-lg": `${(tile.lg ?? [tile.x, tile.y])[0]}%`, "--y-lg": `${(tile.lg ?? [tile.x, tile.y])[1]}%` }) as CSSProperties;

/**
 * L25, L41: centered. A pill eyebrow, a large light-weight headline in the display face, one
 * dim line, two buttons, the "Works with" row of the CLI marks, then the app drawn in a window (a design preview) that
 * starts inside the first viewport. L24, L30: the dot grid behind, and faint tiles with the app's own icons joined by thin lines.
 */
export function Hero() {
  return (
    <section id="top" className="relative isolate overflow-clip pt-12 md:pt-16">
      <div aria-hidden="true" className="dot-grid absolute inset-x-0 top-0 -z-10 h-[820px]" />

      <div className="shell relative">
        <Tiles />

        <div className="relative mx-auto flex max-w-[880px] flex-col items-center text-center">
          <p
            className="inline-flex items-center rounded-full border border-edge-strong bg-glass px-4 py-1.5 text-label uppercase text-ink-1 max-[380px]:rounded-2xl max-sm:px-3 max-sm:text-[10px] max-sm:tracking-[0.06em]"
            data-rise
            style={rise(40)}
          >
            {HERO.eyebrow}
          </p>

          <h1 className="display mt-7 text-h1 text-ink-0" data-rise style={rise(120)}>
            {HERO.headline.map((line) => (
              <span key={line} className="block">
                {line}{" "}
              </span>
            ))}
          </h1>

          <p className="mt-6 max-w-[760px] text-body text-ink-1" data-rise style={rise(220)}>
            {HERO_LINE}
          </p>

          <div className="mt-9 flex flex-wrap items-center justify-center gap-3" data-rise style={rise(320)}>
            <ButtonLink href={HERO.cta.href} size="md" external>
              {HERO.cta.label}
            </ButtonLink>
            <ButtonLink href={GITHUB_URL} variant="ghost" size="md" external>
              GitHub
            </ButtonLink>
          </div>
          <p className="mt-4 text-tiny text-ink-2" data-rise style={rise(380)}>
            {HERO.cta.note}
          </p>

          <div className="mt-12 flex flex-wrap items-center justify-center gap-x-10 gap-y-4 max-sm:gap-x-8">
            <p className="text-label uppercase text-ink-2 max-sm:w-full" data-rise style={rise(460)}>
              {HERO.support.lead}
            </p>
            {HERO.support.clis.map((cli, index) => (
              <span
                key={cli.name}
                translate="no"
                className="inline-flex items-center gap-2.5 text-sec font-medium text-ink-1 opacity-80"
                data-rise
                style={rise(540 + index * 90)}
              >
                <Image src={cli.mark} alt="" width={20} height={20} className="size-5" />
                {cli.name}
              </span>
            ))}
          </div>
        </div>
      </div>

      {/* L41: from 1280 px the whole app window; narrower, the top of the Skills list at 1x, where the window's text would be
          near 8 px. The window has its own traffic lights in its sidebar, so its frame has no title bar. */}
      <div className="shell mt-14 max-xl:hidden" data-rise style={rise(760)}>
        <figure className="mx-auto grid w-fit gap-3">
          <div className="overflow-hidden rounded-panel border border-dashed border-edge-hover bg-stage-bg shadow-panel">
            <div className="ak-fit" role="img" aria-label={HERO_WINDOW_LABEL}>
              <SkillsWindowStage />
            </div>
          </div>
          <figcaption className="text-right text-tiny text-ink-2">{PREVIEW_CAPTION}</figcaption>
        </figure>
      </div>

      <div className="shell mt-14 xl:hidden" data-rise style={rise(760)}>
        <div className="relative mx-auto max-w-[720px]">
          <StageWindow label="Design preview of Skills: the top of the list, eight skills most used first, lint-fixer selected, each with the agents that carry it, a bar and its sessions in 24 days." lights caption={PREVIEW_CAPTION}>
            <SkillsTopStage />
          </StageWindow>
        </div>
      </div>
    </section>
  );
}

/** One tile: a dim icon of the app's own, no name. */
function Tile({ kind }: { readonly kind: (typeof TILES)[number]["kind"] }) {
  return (
    <div className="grid size-14 place-items-center rounded-tile border border-edge bg-s1 text-ink-2 xl:size-[76px]">
      <BandIcon band={kind} size={26} />
    </div>
  );
}

/** A tile by id; a link that names a tile `TILES` does not have is a content error, so it stops the build. */
function tileById(byId: ReadonlyMap<string, (typeof TILES)[number]>, id: string) {
  const tile = byId.get(id);
  if (!tile) throw new Error(`TILE_LINKS names the unknown tile ${id}`);
  return tile;
}

/** From `lg:` up: the tiles stand around the words, still, and appear in turn. The lines run beneath them. */
function Tiles() {
  const byId = new Map(TILES.map((tile) => [tile.id, tile]));
  return (
    <div aria-hidden="true" className="pointer-events-none absolute inset-0 hidden lg:block">
      {/* The lines follow the tiles: one set for 1024 to 1279 px, one from 1280 px. */}
      {(["lg", "xl"] as const).map((size) => (
        <svg key={size} className={`absolute inset-0 size-full ${size === "lg" ? "xl:hidden" : "max-xl:hidden"}`} viewBox="0 0 100 100" preserveAspectRatio="none" fill="none" data-rise style={rise(380)}>
          {TILE_LINKS.map(([from, to]) => {
            const a = tileById(byId, from);
            const b = tileById(byId, to);
            const [ax, ay] = size === "lg" ? (a.lg ?? [a.x, a.y]) : [a.x, a.y];
            const [bx, by] = size === "lg" ? (b.lg ?? [b.x, b.y]) : [b.x, b.y];
            return <path key={`${from}-${to}`} d={`M${ax} ${ay} H${bx} V${by}`} stroke="var(--color-line)" strokeWidth="1" vectorEffect="non-scaling-stroke" />;
          })}
        </svg>
      ))}
      {TILES.map((tile, index) => (
        <div key={tile.id} className="absolute [top:var(--y-lg)] [left:var(--x-lg)] [translate:-50%_-50%] xl:[left:var(--x)] xl:[top:var(--y)]" style={at(tile)}>
          <div data-rise style={rise(420 + index * 70)}>
            <Tile kind={tile.kind} />
          </div>
        </div>
      ))}
    </div>
  );
}
