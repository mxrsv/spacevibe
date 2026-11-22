import { ButtonLink } from "./button-link";
import { UPCOMING } from "./content";

/**
 * The page that is not in the download: named, labelled "In development", with no date and no version
 * (ledger L8). It shows no screen until a render in the app's current look exists, because a mock in an
 * older look reads as the app itself (owner, 2026-11-22).
 */
export function Upcoming() {
  return (
    <section id={UPCOMING.id} className="band relative border-t border-edge bg-bg">
      <div className="shell flex flex-wrap items-end justify-between gap-x-10 gap-y-6">
        <div className="grid max-w-[560px] gap-4" data-reveal>
          <span className="justify-self-start rounded-full border border-dashed border-edge-strong px-2.5 py-0.5 text-tiny text-ink-2">
            {UPCOMING.label}
          </span>
          <h2 className="text-h2 font-medium">{UPCOMING.heading}</h2>
          <p className="text-body text-ink-1">{UPCOMING.body}</p>
        </div>
        <div data-reveal>
          <ButtonLink href={UPCOMING.watch.href} variant="ghost" external>
            {UPCOMING.watch.label}
          </ButtonLink>
        </div>
      </div>
    </section>
  );
}
