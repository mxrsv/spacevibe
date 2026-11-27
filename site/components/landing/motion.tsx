"use client";

import { useEffect } from "react";

export const LANDING_ROOT_ID = "spacevibe-landing";

/**
 * The page's motion (landing spec L26), each effect once and none while the page is idle:
 *  - `[data-mask]`, `[data-slide]`, `[data-reveal]` get `.in` the first time they enter the viewport (CSS does the
 *    slide, the rise and the delay in turn);
 *  - `[data-manifesto]` lights its `[data-w]` words and `[data-chip]` icons as the page scrolls past it, and keeps them lit.
 * The hero's rise is CSS only. Renders nothing and runs over the server-rendered DOM, so the page stays a Server
 * Component whose HTML already holds every final state. The root is flagged `data-motion-ready` only when this
 * will animate: not under reduced motion, not without the observer. Before the flag is set, everything already in or
 * above the viewport (a reload mid-page, a restored scroll position) gets its final state, so nothing the reader can
 * see is ever hidden first. No figure counts up: none on the page is 10 or more (spec, "Inferred, not decided").
 */
export function Motion() {
  useEffect(() => {
    const root = document.getElementById(LANDING_ROOT_ID);
    if (!root || typeof IntersectionObserver === "undefined") return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const targets = Array.from(root.querySelectorAll<HTMLElement>("[data-mask], [data-slide], [data-reveal]"));
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          entry.target.classList.add("in");
          observer.unobserve(entry.target);
        }
      },
      { threshold: 0.12, rootMargin: "0px 0px -8% 0px" },
    );

    let frame = 0;
    const paragraphs = Array.from(root.querySelectorAll<HTMLElement>("[data-manifesto]"));
    /** Lights the words the page has scrolled past; true once every word and icon is lit. */
    const light = () => {
      const vh = window.innerHeight;
      let allLit = true;
      for (const p of paragraphs) {
        const marks = Array.from(p.querySelectorAll<HTMLElement>("[data-w], [data-chip]"));
        const rect = p.getBoundingClientRect();
        const start = vh * 0.86;
        const end = vh * 0.42;
        const progress = Math.min(1, Math.max(0, (start - rect.top) / (start - end + rect.height)));
        const lit = Math.round(progress * marks.length);
        marks.forEach((m, i) => {
          if (i < lit) m.classList.add("on"); // lit once, and it stays lit when the page scrolls back
        });
        if (lit < marks.length) allLit = false;
      }
      return allLit;
    };
    const schedule = () => {
      if (frame) return;
      frame = requestAnimationFrame(() => {
        frame = 0;
        if (light()) detach(); // everything is lit: nothing left to listen for
      });
    };
    const detach = () => {
      window.removeEventListener("scroll", schedule);
      window.removeEventListener("resize", schedule);
    };

    // What is already in or above the viewport is final before the flag hides anything below it.
    for (const node of targets) {
      if (node.getBoundingClientRect().top < window.innerHeight) node.classList.add("in");
      else observer.observe(node);
    }
    const done = light();
    root.setAttribute("data-motion-ready", "");
    if (!done) {
      window.addEventListener("scroll", schedule, { passive: true });
      window.addEventListener("resize", schedule);
    }

    return () => {
      observer.disconnect();
      detach();
      if (frame) cancelAnimationFrame(frame);
      root.removeAttribute("data-motion-ready");
    };
  }, []);

  return null;
}
