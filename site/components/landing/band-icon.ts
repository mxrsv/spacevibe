import { Activity, Gauge, Puzzle, Shield, Trash2, type LucideIcon } from "lucide-react";

import type { BandId } from "./content";

/** One icon per screen, shared by the band headers and the hero. */
export const BAND_ICON: Record<BandId, LucideIcon> = {
  clean: Trash2,
  skills: Puzzle,
  rules: Shield,
  limits: Gauge,
  activity: Activity,
};
