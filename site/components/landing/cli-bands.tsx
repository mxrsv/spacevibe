import { AppWindow } from "./app-window";
import { CliDot } from "./cli-dot";
import { BANDS, CLI_LABEL, DIFFS, type Band, type CLI } from "./content";

const CLIS: readonly CLI[] = ["claude", "codex"];

/**
 * The picked direction, "Two CLIs" (landing spec L16): the app's one idea is that Claude Code and
 * Codex measure the same thing differently, so every band carries the real screen and one block per
 * CLI on what differs. The honesty about what a CLI does not log is the proof, not a footnote.
 */
export function CliBands() {
  return (
    <div>
      {BANDS.map((band) => (
        <section key={band.id} id={band.id} className="border-t border-edge band">
          <div className={`shell grid gap-10 ${band.narrow ? "md:grid-cols-[minmax(0,1fr)_minmax(0,420px)] md:items-start" : ""}`}>
            <div className="grid content-start gap-10">
              <header className="grid max-w-[680px] gap-4" data-reveal>
                <h2 className="text-h2 font-medium">{band.question}</h2>
                <p className="text-body text-ink-1">{band.answer}</p>
              </header>
              {band.narrow ? <Diffs band={band} stacked /> : null}
            </div>

            {band.narrow ? (
              <div data-reveal>
                <AppWindow shot={band.shot} caption={band.caption} />
              </div>
            ) : (
              <div className="mx-auto grid w-full max-w-[1120px] gap-5" data-reveal>
                <AppWindow shot={band.shot} caption={band.caption} />
                <Diffs band={band} />
              </div>
            )}
          </div>
        </section>
      ))}
    </div>
  );
}

function Diffs({ band, stacked = false }: { readonly band: Band; readonly stacked?: boolean }) {
  return (
    <div className={`grid gap-3 ${stacked ? "max-w-[680px]" : "md:grid-cols-2"}`} data-reveal={stacked ? "" : undefined}>
      {CLIS.map((cli) => (
        <div key={cli} className="grid content-start gap-2 rounded-card bg-s2 p-5">
          <h3 translate="no" className="inline-flex items-center gap-2 text-sec font-medium text-ink-0">
            <CliDot cli={cli} />
            {CLI_LABEL[cli]}
          </h3>
          <p className="text-body text-ink-1">{DIFFS[band.id][cli]}</p>
        </div>
      ))}
    </div>
  );
}
