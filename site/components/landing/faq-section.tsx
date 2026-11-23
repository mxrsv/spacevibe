import { Plus } from "lucide-react";

import { FAQ } from "./content";

/**
 * The questions the bands and the privacy panel leave open, as native disclosures: no script, the
 * whole row is the target, and the browser handles keyboard and search-in-page. The heading stays put
 * on the left so the list reads as one column of answers.
 */
export function FaqSection() {
  return (
    <section id={FAQ.id} className="band border-t border-edge">
      <div className="shell grid gap-10 md:grid-cols-[minmax(0,1fr)_minmax(0,720px)] md:items-start">
        <h2 className="text-h2 font-medium" data-reveal>
          {FAQ.heading}
        </h2>
        <div className="grid gap-2" data-reveal>
          {FAQ.items.map((item) => (
            <details key={item.q} className="group rounded-card bg-s1 transition-colors duration-150 open:bg-s2 hover:bg-s2">
              <summary className="flex min-h-14 cursor-pointer list-none items-center justify-between gap-6 px-5 py-3.5 text-h3 font-medium text-ink-0 [&::-webkit-details-marker]:hidden">
                {item.q}
                <Plus
                  size={16}
                  strokeWidth={2}
                  aria-hidden="true"
                  className="shrink-0 text-ink-1 transition-transform duration-150 ease-out group-open:rotate-45"
                />
              </summary>
              <p className="max-w-[600px] px-5 pb-5 text-body text-ink-1">{item.a}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
