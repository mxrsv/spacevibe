import { ArrowRight } from "lucide-react";

import { ButtonLink } from "./button-link";
import { ANNOUNCE, HEADER, NAV, SITE } from "./content";
import { SpaceVibeMark } from "./spacevibe-mark";

/**
 * L31: a thin announcement bar, then a 64px sticky header: the brand, the four band links grouped in one outlined
 * pill (L39), then GitHub (outlined) and the download (violet). The links show from `lg:`: below it the row holds the brand,
 * GitHub and the download button, tightened on a phone (no arrows, "Download") as before.
 */
export function SiteHeader() {
  return (
    <>
      <div className="border-b border-edge bg-s1">
        <p className="shell flex min-h-9 flex-wrap items-center justify-center gap-x-2 py-1.5 text-center text-tiny text-ink-1">
          <span>{ANNOUNCE.text}</span>
          <span aria-hidden="true" className="text-ink-2">
            ·
          </span>
          <a
            href={ANNOUNCE.link.href}
            target="_blank"
            rel="noopener noreferrer"
            className="group inline-flex items-center gap-1 font-medium text-accent-text no-underline hover:text-ink-0"
          >
            {ANNOUNCE.link.label}
            <ArrowRight size={12} aria-hidden="true" className="transition-transform duration-150 ease-out group-hover:translate-x-0.5" />
            <span className="sr-only">(opens in a new tab)</span>
          </a>
        </p>
      </div>
      <header className="sticky top-0 z-20 border-b border-edge bg-glass-header backdrop-blur-[16px]">
        <div className="shell grid h-16 grid-cols-[auto_auto] items-center justify-between gap-3 lg:grid-cols-[1fr_auto_1fr]">
          <a href="#top" className="inline-flex min-h-6 items-center gap-2.5 justify-self-start text-sec font-medium tracking-[-0.01em] text-ink-0 no-underline" aria-label={SITE.brand}>
            <SpaceVibeMark className="size-[22px] shrink-0" />
            <span aria-hidden="true" translate="no">
              {SITE.brand}
            </span>
          </a>

          <nav className="hidden items-center gap-1 rounded-full border border-edge-strong bg-glass p-1 lg:flex" aria-label="Sections">
            {NAV.map((link) => (
              <a
                key={link.href}
                href={link.href}
                className="inline-flex min-h-8 items-center rounded-full px-4 text-sec text-ink-1 no-underline transition-colors duration-150 hover:bg-tile hover:text-ink-0"
              >
                {link.label}
              </a>
            ))}
          </nav>

          <div className="flex items-center gap-2 justify-self-end">
            <ButtonLink href={HEADER.github.href} variant="ghost" external phoneCompact>
              {HEADER.github.label}
            </ButtonLink>
            <ButtonLink href={HEADER.cta.href} external phoneCompact>
              {HEADER.cta.label}
              <span className="max-sm:sr-only">{HEADER.cta.rest}</span>
            </ButtonLink>
          </div>
        </div>
      </header>
    </>
  );
}
