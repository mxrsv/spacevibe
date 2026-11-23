import { ButtonLink } from "@/components/landing/button-link";
import { SITE } from "@/components/landing/content";
import { SpaceVibeMark } from "@/components/landing/spacevibe-mark";

/**
 * The page for an address that does not exist (`404.html` in the static export). Dark only, like the rest of the
 * site: the page ground, the brand mark, one line and one link back to the page.
 */
export default function NotFound() {
  return (
    <main id="main" className="grid min-h-dvh place-items-center bg-bg px-6">
      <div className="flex flex-col items-center gap-6 text-center">
        <span className="inline-flex items-center gap-2.5 text-sec font-medium tracking-[-0.01em] text-ink-0" translate="no">
          <SpaceVibeMark className="size-[22px] shrink-0" />
          {SITE.brand}
        </span>
        <h1 className="text-h2 font-semibold">This page does not exist.</h1>
        <ButtonLink href="/" size="md">
          Back to SpaceVibe
        </ButtonLink>
      </div>
    </main>
  );
}
