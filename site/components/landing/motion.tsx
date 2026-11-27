"use client";

import { useEffect } from "react";

export const LANDING_ROOT_ID = "spacevibe-landing";

const COUNT_MS = 1300;

/**
 * The page's motion (landing spec L26), each effect once and none while the page is idle:
 *  - `[data-mask]`, `[data-slide]`, `[data-reveal]` get `.in` the first time they enter the viewport (CSS does the
 *    slide, the rise and the delay in turn);
 *  - `[data-count]` counts up to its own text once, when it enters, never through 0, and only a figure of 10 or more;
 *  - `[data-manifesto]` lights its `[data-w]` words and `[data-chip]` icons as the page scrolls past it, and keeps them lit.
 * The hero's rise is CSS only. Renders nothing and runs over the server-rendered DOM, so the page stays a Server
 * Component whose HTML already holds every final state. The root is flagged `data-motion-ready` only when this
 * will animate: not under reduced motion, not without the observer.
 */
export function Motion() {
  useEffect(() => {
    const root = document.getElementById(LANDING_ROOT_ID);
    if (!root || typeof IntersectionObserver === "undefined") return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const counters = Array.from(root.querySelectorAll<HTMLElement>("[data-count]"));
    const finals = counters.map((node) => node.textContent?.trim() ?? "");

    // A figure is never shown as 0 unless it is 0: the count starts at a third of the target and only a figure of
    // 10 or more counts at all. A small figure (5, 2, 1) appears with its card. The digits are aria-hidden; the
    // final value is the label of their wrapper (bands.tsx), so a screen reader never hears the steps.
    const countUp = (node: HTMLElement, index: number) => {
      const target = Number(node.dataset.count);
      if (!Number.isFinite(target) || target < 10) return;
      const from = Math.max(1, Math.floor(target / 3));
      const started = performance.now();
      const step = (now: number) => {
        const t = Math.min(1, (now - started) / COUNT_MS);
        const eased = 1 - Math.pow(1 - t, 4);
        node.textContent = t >= 1 ? finals[index] : String(Math.round(from + (target - from) * eased));
        if (t < 1) requestAnimationFrame(step);
      };
      node.textContent = String(from);
      requestAnimationFrame(step);
    };

    const targets = Array.from(root.querySelectorAll<HTMLElement>("[data-mask], [data-slide], [data-reveal]"));
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          const node = entry.target as HTMLElement;
          // The count is set before the card fades in, so the final value never flashes first.
          node.querySelectorAll<HTMLElement>("[data-count]").forEach((c) => countUp(c, counters.indexOf(c)));
          node.classList.add("in");
          observer.unobserve(node);
        }
      },
      { threshold: 0.12, rootMargin: "0px 0px -8% 0px" },
    );

    let frame = 0;
    const paragraphs = Array.from(root.querySelectorAll<HTMLElement>("[data-manifesto]"));
    const light = () => {
      frame = 0;
      const vh = window.innerHeight;
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
      }
    };
    const schedule = () => {
      if (!frame) frame = requestAnimationFrame(light);
    };

    for (const node of targets) observer.observe(node);
    root.setAttribute("data-motion-ready", "");
    light();
    window.addEventListener("scroll", schedule, { passive: true });
    window.addEventListener("resize", schedule);

    return () => {
      observer.disconnect();
      window.removeEventListener("scroll", schedule);
      window.removeEventListener("resize", schedule);
      if (frame) cancelAnimationFrame(frame);
      counters.forEach((c, i) => {
        c.textContent = finals[i];
      });
      root.removeAttribute("data-motion-ready");
    };
  }, []);

  return null;
}
