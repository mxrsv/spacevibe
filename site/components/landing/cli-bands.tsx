import { Check, EyeOff, Lock, type LucideIcon } from "lucide-react";

import { AppWindow } from "./app-window";
import { BAND_ICON } from "./band-icon";
import { CliDot } from "./cli-dot";
import { BANDS, CLI_LABEL, DIFFS, type Band, type CLI, type Reach } from "./content";

const CLIS: readonly CLI[] = ["claude", "codex"];

/** State colours carry the reach, as in the app: green when all of it is read, amber when a CLI logs nothing for part of it. */
const REACH: Record<Reach, { readonly icon: LucideIcon; readonly tone: string }> = {
  full: { icon: Check, tone: "text-ok" },
  partial: { icon: EyeOff, tone: "text-warn" },
  readonly: { icon: Lock, tone: "text-ink-1" },
};

/**
 * The picked direction, "Two CLIs" (landing spec L16): the app's one idea is that Claude Code and
 * Codex measure the same thing differently, so every band carries the real screen and a ledger with one
 * row per CLI: what the app can do with it there, as a verdict first and the reason after. The honesty
 * about what a CLI does not log is the proof, not a footnote.
 */
export function CliBands() {
  return (
    <div>
      {BANDS.map((band) => (
        <section key={band.id} id={band.id} className="band border-t border-edge">
          <div className={`shell grid gap-10 ${band.narrow ? "md:grid-cols-[minmax(0,1fr)_minmax(0,420px)] md:items-start" : ""}`}>
            <div className="grid content-start gap-10">
              <BandHeader band={band} />
              {band.narrow ? <Ledger band={band} /> : null}
            </div>

            {band.narrow ? (
              <div data-reveal>
                <AppWindow shot={band.shot} caption={band.caption} />
              </div>
            ) : (
              <div className="mx-auto grid w-full max-w-[1120px] gap-5">
                <div data-reveal>
                  <AppWindow shot={band.shot} caption={band.caption} />
                </div>
                <Ledger band={band} />
              </div>
            )}
          </div>
        </section>
      ))}
    </div>
  );
}

function BandHeader({ band }: { readonly band: Band }) {
  const Icon = BAND_ICON[band.id];
  return (
    <header className="grid max-w-[680px] gap-4" data-reveal>
      <p className="inline-flex items-center gap-2 text-sec text-ink-1">
        <Icon size={14} strokeWidth={1.8} aria-hidden="true" />
        {band.label}
      </p>
      <h2 className="text-h2 font-medium">{band.question}</h2>
      <p className="text-body text-ink-1">{band.answer}</p>
    </header>
  );
}

/** One panel, one row per CLI: the name, the verdict with its state icon, then the reason. */
function Ledger({ band }: { readonly band: Band }) {
  return (
    <dl className="grid gap-x-8 gap-y-5 rounded-card bg-s2 p-5 md:grid-cols-[auto_auto_minmax(0,1fr)] md:items-baseline" data-reveal>
      {CLIS.map((cli) => {
        const line = DIFFS[band.id][cli];
        const { icon: Icon, tone } = REACH[line.reach];
        return (
          <div key={cli} className="grid gap-y-1 md:col-span-3 md:grid-cols-subgrid md:gap-y-0">
            <dt translate="no" className="inline-flex items-center gap-2 text-sec font-medium text-ink-0">
              <CliDot cli={cli} />
              {CLI_LABEL[cli]}
            </dt>
            <dd className="inline-flex items-center gap-1.5 text-sec font-medium text-ink-0">
              <Icon size={14} strokeWidth={2} aria-hidden="true" className={`shrink-0 ${tone}`} />
              {line.verdict}
            </dd>
            <dd className="text-sec text-ink-1">{line.detail}</dd>
          </div>
        );
      })}
    </dl>
  );
}
