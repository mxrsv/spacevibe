import { ButtonLink } from "./button-link";
import { HEADER, NAV, SITE, type NavLink } from "./content";
import { SpaceVibeMark } from "./spacevibe-mark";

/**
 * A thin 60px band across the full width, split from the page by a hairline.
 * Sticky, does not grow or recolour on scroll. The anchors are the page's bands.
 * The section links show from `lg:`. On a phone the buttons are tightened (no arrows, "Download")
 * so the row fits a 280 px frame.
 */
export function SiteHeader({ nav = NAV }: { readonly nav?: readonly NavLink[] }) {
  return (
    <header className="sticky top-0 z-20 border-b border-edge bg-[rgb(13_15_18/78%)] backdrop-blur-[16px]">
      <div className="shell grid h-[60px] grid-cols-[auto_auto] items-center justify-between gap-3 lg:gap-8 lg:grid-cols-[auto_1fr_auto]">
        <a href="#top" className="inline-flex min-h-6 items-center gap-2.5 text-sec font-medium tracking-[-0.01em] text-ink-0 no-underline" aria-label={SITE.brand}>
          <SpaceVibeMark className="size-[22px] shrink-0" />
          <span aria-hidden="true" translate="no">
            {SITE.brand}
          </span>
        </a>

        <nav className="hidden lg:flex justify-center gap-8" aria-label="Sections">
          {nav.map((link) => (
            <a key={link.href} href={link.href} className="inline-flex min-h-6 items-center text-sec text-ink-1 no-underline transition-colors duration-150 hover:text-ink-0">
              {link.label}
            </a>
          ))}
        </nav>

        <div className="flex items-center gap-2">
          <span className="hidden sm:contents">
            <ButtonLink href={HEADER.github.href} variant="ghost" external>
              {HEADER.github.label}
            </ButtonLink>
          </span>
          <ButtonLink href={HEADER.cta.href} external phoneCompact>
            {HEADER.cta.label}
            <span className="max-sm:sr-only">{HEADER.cta.rest}</span>
          </ButtonLink>
        </div>
      </div>
    </header>
  );
}
