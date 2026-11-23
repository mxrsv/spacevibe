import { ArrowRight } from "lucide-react";
import Image from "next/image";
import type { CSSProperties } from "react";

import { AppWindow } from "./app-window";
import { BAND_ICON } from "./band-icon";
import { ButtonLink } from "./button-link";
import { HERO, HERO_HEADLINES, type HeroLayout } from "./content";
import { Scene } from "./scene";

interface HeroProps {
  readonly layout?: HeroLayout;
  readonly headline?: number;
}

const rise = (ms: number) => ({ "--rise": `${ms}ms` }) as CSSProperties;

/**
 * The first viewport over the planet limb. Four layouts while the owner picks (`/hero-lab`):
 *   now  the question, the lede, the download, the Inbox window rising from the bottom edge.
 *   a    the same stack led by a line that names the app, with the three jobs as links above the window.
 *   b    words left, and right one legible panel: a reading per screen, each a link to its band.
 *   c    words left, and right the Inbox's rows at reading size, cut from the real window.
 * Layouts a, b and c carry, under the heading, the marks of the CLIs the core reads (owner's pick, 2026-11-22).
 * First glance, second glance: now = heading, window; a = heading, jobs; b = the readings, heading;
 * c = the rows and their Remove button, heading.
 */
export function Hero({ layout = "now", headline = 0 }: HeroProps) {
  const lines = HERO_HEADLINES[headline] ?? HERO_HEADLINES[0];
  const split = layout === "b" || layout === "c";

  const words = (
    <div className={`flex flex-col items-start ${split ? "max-w-[600px]" : "max-w-[860px]"}`}>
      {layout === "now" ? null : (
        <p className="mb-5 text-sec text-ink-1" data-rise style={rise(40)}>
          {HERO.eyebrow}
        </p>
      )}
      <h1 className={`grid font-semibold text-ink-0 ${split ? "text-h1-split" : "text-h1"}`} data-rise style={rise(80)}>
        {lines.map((line) => (
          <span key={line}>{line} </span>
        ))}
      </h1>
      {layout !== "now" ? (
        <p className="mt-5 flex flex-wrap items-center gap-x-4 gap-y-2 text-sec text-ink-1" data-rise style={rise(130)}>
          {HERO.support.lead}
          {HERO.support.clis.map((cli) => (
            <span key={cli.name} translate="no" className="inline-flex items-center gap-2 font-medium text-ink-0">
              <Image src={cli.mark} alt="" width={18} height={18} className="size-[18px]" />
              {cli.name}
            </span>
          ))}
        </p>
      ) : null}
      <p className="mt-6 max-w-[520px] text-body text-ink-1" data-rise style={rise(180)}>
        {layout === "now" ? HERO.lede : HERO.ledeShort}
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
    <section id="top" className={`relative isolate overflow-clip bg-void pt-28 max-md:pt-20 ${split ? "pb-24 max-md:pb-14" : ""}`}>
      <Scene variant="hero" />

      {split ? (
        <div className={`shell grid items-center gap-12 max-md:gap-10 ${layout === "c" ? "lg:grid-cols-[minmax(0,1fr)_minmax(0,660px)]" : "lg:grid-cols-[minmax(0,1fr)_minmax(0,520px)]"}`}>
          {words}
          <div data-rise style={rise(380)}>
            {layout === "b" ? <Readings /> : <AppWindow shot={HERO.rowsShot} caption="Inbox · demo data" priority />}
          </div>
        </div>
      ) : (
        <div className="shell grid gap-12 max-md:gap-8">
          {words}
          {layout === "a" ? <Jobs /> : null}
          <div className="mx-auto max-h-[430px] w-full max-w-[1120px] overflow-hidden max-md:max-h-[250px]" data-rise style={rise(380)}>
            <AppWindow shot={HERO.shot} lights priority bleed />
          </div>
        </div>
      )}
    </section>
  );
}

/** Layout A: the three jobs, each a link to the band that shows it. */
function Jobs() {
  return (
    <ul className="grid gap-2 md:grid-cols-3" data-rise style={rise(330)}>
      {HERO.jobs.map((job) => (
        <li key={job.href}>
          <a
            href={job.href}
            className="glass group flex min-h-14 items-center justify-between gap-4 rounded-card px-5 text-sec text-ink-1 no-underline transition-colors duration-150 hover:border-edge-hover hover:text-ink-0"
          >
            <span>
              <span className="font-medium text-ink-0">{job.verb}</span> {job.rest}
            </span>
            <ArrowRight size={14} aria-hidden="true" className="shrink-0 transition-transform duration-150 ease-out group-hover:translate-x-0.5" />
          </a>
        </li>
      ))}
    </ul>
  );
}

/** The state colour of a reading: its text colour and the fill of its meter. */
const TONE = {
  ok: { figure: "text-ok", fill: "bg-ok" },
  warn: { figure: "text-warn", fill: "bg-warn" },
} as const;

/** Layout B: one panel, one reading per screen. The figure leads; the icon carries the state colour. */
function Readings() {
  return (
    <figure className="grid gap-3">
      <ul className="glass grid overflow-hidden rounded-panel p-2">
        {HERO.readings.map((reading) => {
          const Icon = BAND_ICON[reading.band];
          const tone = TONE[reading.tone];
          return (
            <li key={reading.band}>
              <a
                href={`#${reading.band}`}
                className="group grid grid-cols-[auto_5.5rem_minmax(0,1fr)_auto] items-center gap-x-4 rounded-card px-4 py-3.5 no-underline transition-colors duration-150 hover:bg-s3"
              >
                <Icon size={18} strokeWidth={1.8} aria-hidden="true" className={tone.figure} />
                <span className="tnum text-stat font-semibold text-ink-0">
                  {reading.figure}
                  {reading.unit ? <span className="ml-0.5 text-sec font-medium text-ink-1">{reading.unit}</span> : null}
                </span>
                <span className="grid gap-1.5 text-sec text-ink-1">
                  {reading.label}
                  {"meter" in reading ? (
                    <span aria-hidden="true" className="h-1 w-full max-w-[180px] overflow-hidden rounded-full bg-s3">
                      <span className={`block h-full rounded-full ${tone.fill}`} style={{ width: `${reading.meter * 100}%` }} />
                    </span>
                  ) : null}
                </span>
                <ArrowRight size={14} aria-hidden="true" className="text-ink-2 transition-transform duration-150 ease-out group-hover:translate-x-0.5" />
              </a>
            </li>
          );
        })}
      </ul>
      <figcaption className="text-tiny text-ink-2">{HERO.readingsCaption}</figcaption>
    </figure>
  );
}
