import { CliBands } from "@/components/landing/cli-bands";
import { DownloadBand } from "@/components/landing/download-band";
import { FaqSection } from "@/components/landing/faq-section";
import { Hero } from "@/components/landing/hero";
import { PrivateSection } from "@/components/landing/private-section";
import { LANDING_ROOT_ID, ScrollReveal } from "@/components/landing/scroll-reveal";
import { SiteFooter } from "@/components/landing/site-footer";
import { SiteHeader } from "@/components/landing/site-header";
import { Upcoming } from "@/components/landing/upcoming";

/**
 * spacevibe.dev, one page: the hero with the planet scene, the CLI marks and one reading per screen, one band per screen
 * with what differs between the two CLIs, the page still in development, the privacy guarantees, the questions
 * left open and the download band (landing spec, L13 as amended on 2026-11-22).
 */
export default function LandingPage() {
  return (
    <div id={LANDING_ROOT_ID} className="min-h-dvh bg-bg">
      <SiteHeader />
      <main id="main">
        <Hero layout="b" headline={1} />
        <CliBands />
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
