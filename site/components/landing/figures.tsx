import type { CSSProperties } from "react";

import { FIGURES } from "./content";

/**
 * L28, in place of "Private by construction": left a short block of words, right three large light figures, each with a
 * tiny uppercase label over a hairline (the reference's "11 Billion / 35+ / 4100+"). They are facts about the product
 * that hold on every Mac (PRODUCT.md), so none is a count of users and none repeats a demo reading (a number shows once).
 * Every figure is a zero, so none counts up.
 */
export function Figures() {
  return (
    <section id={FIGURES.id} className="band relative isolate overflow-clip border-t border-edge">
      <div aria-hidden="true" className="dot-grid absolute inset-0 -z-10 opacity-60" />
      <div className="shell grid gap-x-16 gap-y-14 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)] lg:items-center">
        <div className="grid max-w-[460px] content-start justify-items-start gap-6">
          <p className="inline-flex items-center rounded-full border border-edge-strong bg-glass px-3.5 py-1 text-label uppercase text-ink-1" data-slide>
            {FIGURES.label}
          </p>
          <h2 className="display text-h2 text-ink-0" data-mask>
            <span className="block">{FIGURES.heading}</span>
          </h2>
          <p className="text-body text-ink-1" data-reveal style={{ "--d": "120ms" } as CSSProperties}>
            {FIGURES.line}
          </p>
        </div>

        <dl className="grid">
          {FIGURES.items.map((item, index) => (
            <div key={item.label} className="grid gap-3 border-t border-line py-8 first:border-t-0 first:pt-0 last:pb-0" data-reveal style={{ "--d": `${index * 140}ms` } as CSSProperties}>
              <dt className="text-label uppercase text-ink-2">{item.label}</dt>
              {/* The number, then its note on its own line below md:, so the three notes sit at the same place on a phone. */}
              <dd className="grid gap-3 md:flex md:items-baseline md:gap-x-6">
                <span className="display tnum text-figure text-ink-0">{item.value}</span>
                <span className="max-w-[360px] text-sec text-ink-1">{item.note}</span>
              </dd>
            </div>
          ))}
        </dl>
      </div>
    </section>
  );
}
