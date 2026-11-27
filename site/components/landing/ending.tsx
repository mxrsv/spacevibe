import type { CSSProperties } from "react";

import { ButtonLink } from "./button-link";
import { ENDING } from "./content";

/**
 * L29: two cards side by side after the FAQ. Left, dark: Watch releases on GitHub, which also says Tokens is in
 * development (L8). Right, solid violet: Download for macOS, with the free, macOS 15 and Apple silicon line (L14, L15).
 * No form and no email field (L9). The line drawings are decoration.
 */
export function Ending() {
  return (
    <section id="download" className="band border-t border-edge">
      <div className="shell grid gap-5 lg:grid-cols-2">
        <article className="card relative isolate flex min-h-[420px] flex-col justify-between gap-12 overflow-clip p-8 md:p-10" data-reveal>
          <div aria-hidden="true" className="dot-grid-flat dot-grid-corner absolute inset-0 -z-10 opacity-60" />
          <div className="grid max-w-[420px] justify-items-start gap-5">
            <span className="rounded-full border border-dashed border-edge-strong px-3 py-1 text-label uppercase text-ink-2">{ENDING.watch.label}</span>
            <h2 className="display text-h2 text-ink-0">{ENDING.watch.heading}</h2>
            <p className="text-body text-ink-1">{ENDING.watch.body}</p>
          </div>
          <div>
            <ButtonLink href={ENDING.watch.cta.href} variant="ghost" size="md" external>
              {ENDING.watch.cta.label}
            </ButtonLink>
          </div>
        </article>

        <article className="relative isolate flex min-h-[420px] flex-col justify-between gap-12 overflow-clip rounded-panel bg-accent p-8 md:p-10" data-reveal style={{ "--d": "140ms" } as CSSProperties}>
          <LineDrawing />
          <div className="grid max-w-[420px] justify-items-start gap-5">
            <h2 className="display text-h2 text-on-accent">{ENDING.download.heading}</h2>
            <p className="text-body text-on-accent">{ENDING.download.note}</p>
          </div>
          <div>
            <ButtonLink href={ENDING.download.cta.href} variant="light" size="md" external>
              {ENDING.download.cta.label}
            </ButtonLink>
          </div>
        </article>
      </div>
    </section>
  );
}

/**
 * A large thin line drawing on the violet card, after the reference's: the app's skill tile (a rounded square with the
 * four-point spark) stood on its corner and repeated outwards as nested outlines, crossed by two guide lines.
 * Pure SVG, hairline stroke, decorative.
 */
function LineDrawing() {
  const steps = [0, 1, 2, 3, 4, 5, 6];
  return (
    <svg
      aria-hidden="true"
      className="absolute -right-24 -bottom-28 -z-10 size-[560px] max-md:-right-32 max-md:-bottom-24 max-md:size-[420px]"
      viewBox="-300 -300 600 600"
      fill="none"
      stroke="var(--color-accent-line)"
      strokeWidth="1"
    >
      <g transform="rotate(45)">
        {steps.map((i) => {
          const size = 70 + i * 36;
          return <rect key={i} x={-size} y={-size} width={size * 2} height={size * 2} rx={26 + i * 8} strokeOpacity={1 - i * 0.12} />;
        })}
      </g>
      <path d="M-300 0H300M0 -300V300" strokeDasharray="2 6" />
      <path d="M0 -62c4 36 22 54 62 62c-40 8-58 26-62 62c-4-36-22-54-62-62c40-8 58-26 62-62Z" strokeWidth="1.4" />
      <circle r="12" cx="0" cy="0" />
    </svg>
  );
}
