import type { Metadata } from "next";

import { CliBands } from "@/components/landing/cli-bands";
import { HeroLab } from "@/components/landing/hero-lab";
import { LANDING_ROOT_ID, ScrollReveal } from "@/components/landing/scroll-reveal";
import { SiteHeader } from "@/components/landing/site-header";

export const metadata: Metadata = { title: "Hero lab · SpaceVibe", robots: { index: false } };

/**
 * Review scaffolding, not a public page: the hero layouts and headlines side by side with the real header
 * and the first bands under them, chosen by `?layout=now|a|b|c&headline=0|1|2`. Deleted with the unpicked
 * options once the owner has picked (landing spec, "Hero round").
 */
export default function HeroLabPage() {
  return (
    <div id={LANDING_ROOT_ID} className="min-h-dvh bg-bg">
      <SiteHeader />
      <main id="main">
        <HeroLab />
        <CliBands />
      </main>
      <ScrollReveal />
    </div>
  );
}
