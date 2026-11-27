import { ButtonLink } from "./button-link";
import { DOWNLOAD } from "./content";

/** The one download panel (replaced by the ending cards in LR-T5). */
export function DownloadBand() {
  return (
    <section id={DOWNLOAD.id} className="border-t border-edge band">
      <div className="shell">
        <div className="relative isolate overflow-clip rounded-panel border border-edge bg-s1 px-8 py-16 text-center max-md:px-5 max-md:py-10">
          <div className="mx-auto grid max-w-[520px] justify-items-center gap-4">
            <h2 className="text-h2 font-medium" data-reveal>
              {DOWNLOAD.heading}
            </h2>
            <p className="max-w-[430px] text-body text-ink-1" data-reveal>
              {DOWNLOAD.body}
            </p>
            <div className="mt-2 flex flex-wrap items-center justify-center gap-2" data-reveal>
              <ButtonLink href={DOWNLOAD.cta.href} size="md" external>
                {DOWNLOAD.cta.label}
              </ButtonLink>
              <ButtonLink href={DOWNLOAD.secondary.href} variant="ghost" size="md" external>
                {DOWNLOAD.secondary.label}
              </ButtonLink>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
