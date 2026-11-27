import { ArrowRight } from "lucide-react";
import Image from "next/image";
import type { CSSProperties } from "react";

import { BandIcon } from "./band-icon";
import { ButtonLink } from "./button-link";
import { HERO } from "./content";

const rise = (ms: number) => ({ "--rise": `${ms}ms` }) as CSSProperties;

/**
 * The first viewport (owner's pick, 2026-11-23; redone in LR-T3): words left, under the heading the marks of
 * the CLIs the core reads, and right one legible panel, a reading per screen, each a link to its band.
 * First glance, second glance: the readings, then the heading.
 */
export function Hero() {
  const words = (
    <div className="flex flex-col items-start max-w-[600px]">
      <p className="mb-5 text-sec text-ink-1" data-rise style={rise(40)}>
        {HERO.eyebrow}
      </p>
      <h1 className="grid font-semibold text-ink-0 text-h1-split" data-rise style={rise(80)}>
        {HERO.headline.map((line) => (
          <span key={line}>{line} </span>
        ))}
      </h1>
      <p className="mt-5 flex flex-wrap items-center gap-x-4 gap-y-2 text-sec text-ink-1" data-rise style={rise(130)}>
        {HERO.support.lead}
        {HERO.support.clis.map((cli) => (
          <span key={cli.name} translate="no" className="inline-flex items-center gap-2 font-medium text-ink-0">
            <Image src={cli.mark} alt="" width={18} height={18} className="size-[18px]" />
            {cli.name}
          </span>
        ))}
      </p>
      <p className="mt-6 max-w-[520px] text-body text-ink-1" data-rise style={rise(180)}>
        {HERO.ledeShort}
      </p>
      <div className="mt-8 flex flex-wrap items-center gap-x-5 gap-y-3" data-rise style={rise(280)}>
        <ButtonLink href={HERO.cta.href} size="md" external>
          {HERO.cta.label}
        </ButtonLink>
        <span className="text-sec text-ink-2">{HERO.cta.note}</span>
      </div>
    </div>
  );

  return (
    <section id="top" className="relative isolate overflow-clip bg-bg pt-28 pb-24 max-md:pt-20 max-md:pb-14">
      <div className="shell grid items-center gap-12 max-md:gap-10 lg:grid-cols-[minmax(0,1fr)_minmax(0,520px)]">
        {words}
        <div data-rise style={rise(380)}>
          <Readings />
        </div>
      </div>
    </section>
  );
}

/** The state colour of a reading: its figure and the fill of its meter. The page icon stays neutral (PRODUCT.md, Colour). */
const TONE = {
  ok: { figure: "text-ok", fill: "bg-ok" },
  warn: { figure: "text-warn", fill: "bg-warn" },
} as const;

/** Layout B: one panel, one reading per screen. The figure leads and carries the state colour; the page icon is neutral. */
function Readings() {
  return (
    <figure className="grid gap-3">
      <ul className="glass grid overflow-hidden rounded-panel p-2">
        {HERO.readings.map((reading) => {
          const tone = TONE[reading.tone];
          return (
            <li key={reading.band}>
              <a
                href={`#${reading.band}`}
                className="group grid grid-cols-[auto_5.5rem_minmax(0,1fr)_auto] items-center gap-x-4 rounded-card px-4 py-3.5 no-underline transition-colors duration-150 hover:bg-s3 max-sm:grid-cols-[auto_minmax(0,1fr)_auto] max-sm:gap-y-1.5"
              >
                <BandIcon band={reading.band} size={18} className="text-ink-1 max-sm:row-start-1" />
                <span className={`tnum text-stat font-semibold ${tone.figure} max-sm:col-start-2 max-sm:row-start-1`}>
                  {reading.figure}
                  {reading.unit ? <span className="ml-0.5 text-sec font-medium text-ink-1">{reading.unit}</span> : null}
                </span>
                <span className="grid gap-1.5 text-sec text-ink-1 max-sm:col-start-2 max-sm:row-start-2">
                  {reading.label}
                  {"meter" in reading ? (
                    <span aria-hidden="true" className="h-1 w-full max-w-[180px] overflow-hidden rounded-full bg-s3">
                      <span className={`block h-full rounded-full ${tone.fill}`} style={{ width: `${reading.meter * 100}%` }} />
                    </span>
                  ) : null}
                </span>
                <ArrowRight size={14} aria-hidden="true" className="text-ink-2 transition-transform duration-150 ease-out group-hover:translate-x-0.5 max-sm:col-start-3 max-sm:row-span-2 max-sm:row-start-1" />
              </a>
            </li>
          );
        })}
      </ul>
      <figcaption className="text-tiny text-ink-2">{HERO.readingsCaption}</figcaption>
    </figure>
  );
}
