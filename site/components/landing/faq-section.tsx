import { Plus } from "lucide-react";

import { FAQ } from "./content";

/**
 * The questions the bands leave open, as native disclosures: no script, the whole row is the target, and the browser
 * handles keyboard and search-in-page. Restyled after the reference: thin rows divided by hairlines, no cards.
 */
export function FaqSection() {
  return (
    <section id={FAQ.id} className="band border-t border-edge">
      <div className="shell grid gap-x-16 gap-y-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)] lg:items-start">
        <div className="grid content-start justify-items-start gap-6">
          <h2 className="display text-h2 text-ink-0" data-mask>
            <span className="block">{FAQ.heading}</span>
          </h2>
        </div>
        <div className="border-t border-edge-strong" data-reveal>
          {FAQ.items.map((item) => (
            <details key={item.q} className="group border-b border-edge-strong">
              <summary className="flex min-h-16 cursor-pointer list-none items-center justify-between gap-6 py-4 text-h3 font-medium text-ink-0 transition-colors duration-150 hover:text-ink-1 [&::-webkit-details-marker]:hidden">
                {item.q}
                <span className="grid size-8 shrink-0 place-items-center rounded-full border border-edge-strong text-ink-1">
                  <Plus size={14} strokeWidth={2} aria-hidden="true" className="transition-transform duration-150 ease-out group-open:rotate-45" />
                </span>
              </summary>
              <p className="max-w-[600px] pb-6 text-body text-ink-1">{item.a}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
