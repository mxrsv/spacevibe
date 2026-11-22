import { AppWindow } from "./app-window";
import { ButtonLink } from "./button-link";
import { UPCOMING } from "./content";

/**
 * The page that is not in the download. Its frame is dashed and captioned as a design
 * preview, so a visitor cannot take a mock for a shipped screen (ledger L7, L8). No date, no version.
 */
export function Upcoming() {
  return (
    <section id={UPCOMING.id} className="relative border-t border-edge bg-bg band">
      <div className="shell grid gap-12">
        <div className="flex flex-wrap items-end justify-between gap-x-10 gap-y-5">
          <h2 className="max-w-[560px] text-h2 font-medium" data-reveal>
            {UPCOMING.heading}
          </h2>
          <div data-reveal>
            <ButtonLink href={UPCOMING.watch.href} variant="ghost" external>
              {UPCOMING.watch.label}
            </ButtonLink>
          </div>
        </div>

        <div className="grid max-w-[720px] content-start gap-5" data-reveal>
          <AppWindow shot={UPCOMING.item.shot} preview caption={UPCOMING.previewCaption} />
          <div className="grid gap-2">
            <div className="flex items-center gap-3">
              <h3 className="text-h3 font-medium">{UPCOMING.item.name}</h3>
              <span className="rounded-full border border-dashed border-edge-strong px-2.5 py-0.5 text-tiny text-ink-2">{UPCOMING.label}</span>
            </div>
            <p className="max-w-[520px] text-sec text-ink-1">{UPCOMING.item.body}</p>
          </div>
        </div>
      </div>
    </section>
  );
}
