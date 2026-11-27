import { Check, EyeOff, Lock, type LucideIcon } from "lucide-react";
import Image from "next/image";
import type { CSSProperties } from "react";

import { BandIcon } from "./band-icon";
import { BANDS, CLI_LABEL, CLI_MARK, PREVIEW_CAPTION, type Band, type CLI, type CliLine, type Reach } from "./content";
import { StageWindow } from "./app-stage/stage-window";
import { HooksStage, RulesStage, SkillsIdleStage, SubagentsStage } from "./app-stage/stages";

const CLIS: readonly CLI[] = ["claude", "codex"];

/** State colours carry the reach, as in the app: green when all of it is read, amber when a CLI logs nothing for part of it. */
const REACH: Record<Reach, { readonly icon: LucideIcon; readonly tone: string }> = {
  full: { icon: Check, tone: "text-ok" },
  partial: { icon: EyeOff, tone: "text-warn" },
  readonly: { icon: Lock, tone: "text-ink-1" },
};

/** The state colour of a reading's figure. */
const TONE = {
  ok: "text-ok",
  warn: "text-warn",
  plain: "text-ink-0",
} as const;

const STAGES = { skills: SkillsIdleStage, subagents: SubagentsStage, hooks: HooksStage, rules: RulesStage } as const;

/**
 * L27, L37, L39: every screen is the reference's "Your Gateway" block. Words on the left (a pill with the screen's icon, the
 * question, the answer); on the right the app drawn as HTML in a dashed preview frame inside a dark card, with one floating
 * figure card, the screen's own reading; under both, the per-CLI ledger as one slim row. The four stay on the page; none
 * hides behind a click.
 *
 * The drawn stages are 596 px wide and never scale, so a band stacks below `xl:`.
 */
export function Bands() {
  return (
    <>
      {BANDS.map((band) => (
        <BandSection key={band.id} band={band} />
      ))}
    </>
  );
}

function BandSection({ band }: { readonly band: Band }) {
  return (
    <section id={band.id} className="band border-t border-edge">
      <div className="shell grid gap-y-16">
        <div className="grid items-center gap-x-16 gap-y-14 xl:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <Words band={band} />
          <Visual band={band} />
        </div>
        <Ledger ledger={band.ledger} />
      </div>
    </section>
  );
}

function Words({ band }: { readonly band: Band }) {
  return (
    <header className="grid max-w-[520px] content-start justify-items-start gap-6">
      <p className="inline-flex items-center gap-2 rounded-full border border-edge-strong bg-glass px-3.5 py-1 text-label uppercase text-ink-1" data-slide>
        <BandIcon band={band.id} size={13} />
        {band.label}
      </p>
      <h2 className="display text-h2 text-ink-0" data-mask>
        <span className="block">{band.question}</span>
      </h2>
      <p className="text-body text-ink-1" data-reveal style={{ "--d": "120ms" } as CSSProperties}>
        {band.answer}
      </p>
    </header>
  );
}

function Visual({ band }: { readonly band: Band }) {
  const reading = band.reading;
  const Stage = STAGES[band.id];
  return (
    <div className="flex flex-col xl:relative xl:block" data-reveal>
      <div className="card bg-s1 p-3 max-xl:pb-16 md:p-4 xl:pb-10">
        <div className="relative grid grid-cols-[minmax(0,1fr)] place-items-center">
          <StageWindow label={band.stageLabel}>
            <Stage />
          </StageWindow>
        </div>
        {/* The caption stays clear of the floating card: right-aligned where the card sits lower left. The drawn stage pans
            sideways on a phone, so its caption adds the hint there. */}
        <p className="mt-3 text-tiny text-ink-2 xl:text-right">
          {PREVIEW_CAPTION}
          <span className="md:hidden"> · Swipe to inspect</span>
        </p>
      </div>

      {/* The one floating figure of the screen (the reference's "$4,546" card). It hangs over the card's lower edge, under the frame, so it covers no pixel of the drawing and not the caption. */}
      <div className="card relative z-10 -mt-14 ml-4 w-fit min-w-[200px] max-w-[min(300px,calc(100%-2rem))] bg-s2 px-5 py-4 shadow-lift max-xl:self-start xl:absolute xl:-bottom-12 xl:left-8 xl:mt-0 xl:ml-0">
        <p className={`display text-stat tnum ${TONE[reading.tone]}`}>
          {reading.figure}
          {reading.unit ? <span className="ml-1 text-body font-normal text-ink-1">{reading.unit}</span> : null}
        </p>
        <p className="mt-1.5 text-sec text-ink-1">{reading.label}</p>
      </div>
    </div>
  );
}

/** One slim row under the screen: a cell per CLI, its verdict with the state icon first and the reason after. */
function Ledger({ ledger }: { readonly ledger: Record<CLI, CliLine> }) {
  return (
    <dl className="grid divide-y divide-edge border-y border-edge md:grid-cols-2 md:divide-x md:divide-y-0">
      {CLIS.map((cli, index) => {
        const line = ledger[cli];
        const { icon: Icon, tone } = REACH[line.reach];
        return (
          <div key={cli} className="grid content-start gap-2 py-6 md:px-8 md:first:pl-0 md:last:pr-0" data-reveal style={{ "--d": `${index * 120}ms` } as CSSProperties}>
            <dt className="flex flex-wrap items-center gap-x-3 gap-y-1">
              <span translate="no" className="inline-flex items-center gap-2 text-sec font-medium text-ink-0">
                <Image src={CLI_MARK[cli]} alt="" width={14} height={14} className="size-3.5 shrink-0" />
                {CLI_LABEL[cli]}
              </span>{" "}
              <span className="inline-flex items-center gap-1.5 text-sec font-medium text-ink-0">
                <Icon size={14} strokeWidth={2} aria-hidden="true" className={`shrink-0 ${tone}`} />
                {line.verdict}
              </span>
            </dt>
            <dd className="max-w-[560px] text-sec text-ink-1">{line.detail}</dd>
          </div>
        );
      })}
    </dl>
  );
}
