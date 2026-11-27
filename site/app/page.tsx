import { Bands } from "@/components/landing/bands";
import { DownloadBand } from "@/components/landing/download-band";
import { FaqSection } from "@/components/landing/faq-section";
import { Hero } from "@/components/landing/hero";
import { PrivateSection } from "@/components/landing/private-section";
import { LANDING_ROOT_ID, ScrollReveal } from "@/components/landing/scroll-reveal";
import { SiteFooter } from "@/components/landing/site-footer";
import { SiteHeader } from "@/components/landing/site-header";
import { Upcoming } from "@/components/landing/upcoming";

/**
 * spacevibe.dev, one page, redesigned after the Dstudio reference (landing spec L21 to L39): the centred hero with the
 * app drawn in a window, one "Your Gateway" band per screen (Skills, Subagents, Hooks, Rules), then, until LR-T5 replaces
 * them, the page still in development, the privacy guarantees, the questions left open and the download band.
 */
export default function LandingPage() {
  return (
    <div id={LANDING_ROOT_ID} className="min-h-dvh bg-bg">
      <SiteHeader />
      <main id="main">
        <Hero />
        <Bands />
        <Upcoming />
        <PrivateSection />
        <FaqSection />
        <DownloadBand />
      </main>
      <SiteFooter />
      <ScrollReveal />
    </div>
  );
}
