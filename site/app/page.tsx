import { Bands } from "@/components/landing/bands";
import { Ending } from "@/components/landing/ending";
import { FaqSection } from "@/components/landing/faq-section";
import { Figures } from "@/components/landing/figures";
import { Hero } from "@/components/landing/hero";
import { Manifesto } from "@/components/landing/manifesto";
import { LANDING_ROOT_ID, Motion } from "@/components/landing/motion";
import { SiteFooter } from "@/components/landing/site-footer";
import { SiteHeader } from "@/components/landing/site-header";

/**
 * spacevibe.dev, one page, redesigned after the Dstudio reference (landing spec L21 to L32): the centred hero with a
 * real app window, the manifesto, one "Your Gateway" band per screen, the band of large figures, the questions, and the
 * two ending cards.
 */
export default function LandingPage() {
  return (
    <div id={LANDING_ROOT_ID} className="min-h-dvh bg-bg">
      <SiteHeader />
      <main id="main">
        <Hero />
        <Manifesto />
        <Bands />
        <Figures />
        <FaqSection />
        <Ending />
      </main>
      <SiteFooter />
      <Motion />
    </div>
  );
}
