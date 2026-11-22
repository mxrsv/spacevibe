"use client";

import { useSyncExternalStore } from "react";

import { HERO_HEADLINES, type HeroLayout } from "./content";
import { Hero } from "./hero";

const LAYOUTS: readonly HeroLayout[] = ["now", "a", "b", "c"];
const subscribe = () => () => {};

/** Reads the option from the query string on the client; the static export has no server to read it. */
export function HeroLab() {
  const search = useSyncExternalStore(subscribe, () => window.location.search, () => "");
  const params = new URLSearchParams(search);
  const layout = LAYOUTS.find((value) => value === params.get("layout")) ?? "now";
  const headline = Number(params.get("headline") ?? 0);
  return <Hero layout={layout} headline={headline >= 0 && headline < HERO_HEADLINES.length ? headline : 0} />;
}
