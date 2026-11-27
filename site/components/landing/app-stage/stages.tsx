import type { CSSProperties } from "react";

import { FIVE, Strip, type AgentName } from "./agents";
import { Icon } from "./icons";

/**
 * The regions of the Kanu renders that the landing shows, drawn as live markup (2026-11-27). The data is the renders'
 * own (`data.md`; the pages' tables), so every name, count and state is what the render draws. Each stage is the part of its
 * 1440 x 900 render that the earlier crops cut (x 266 to 862), at 1x: a 584 px card inside 6 px of the window.
 */

type Has = readonly (0 | 1)[];

interface RankRow {
  readonly name: string;
  readonly has: Has;
  /** Sessions in 24 days; null = not known. */
  readonly sessions: number | null;
  readonly worth?: boolean;
  readonly selected?: boolean;
  readonly mark?: { readonly icon: "lock" | "clock"; readonly title: string };
}

/** Skills, from `build.mjs` (SK, after the reach of D25) in the order of the list: ranked by sessions, then the idle ones. */
const SKILLS: readonly RankRow[] = [
  { name: "lint-fixer", has: [1, 1, 1, 1, 1], sessions: 67, selected: true },
  { name: "commit-helper", has: [1, 1, 1, 1, 1], sessions: 43 },
  { name: "test-scaffold", has: [1, 0, 0, 1, 1], sessions: 36, worth: true },
  { name: "tidy-imports", has: [1, 1, 0, 1, 1], sessions: 27, worth: true },
  { name: "review-pr", has: [1, 0, 1, 1, 1], sessions: 24, worth: true },
  { name: "screenshot-diff", has: [0, 1, 0, 1, 0], sessions: 11 },
  { name: "db-seed", has: [1, 1, 1, 1, 1], sessions: 8 },
  { name: "api-docs", has: [1, 1, 0, 1, 1], sessions: 6 },
  { name: "sql-explain", has: [1, 1, 1, 1, 1], sessions: 4 },
  { name: "pdf-extract", has: [1, 1, 0, 1, 1], sessions: 0 },
  { name: "changelog-writer-for-monorepos-with-conventional-commits", has: [1, 0, 0, 1, 1], sessions: 0 },
  { name: "release-notes", has: [1, 1, 1, 1, 1], sessions: 0, mark: { icon: "clock", title: "Added 2 hours ago, too new to judge" } },
  { name: "brand-voice", has: [1, 1, 0, 0, 0], sessions: 0, mark: { icon: "lock", title: "From a plugin, open only" } },
  { name: "checkout-flows", has: [1, 1, 0, 0, 0], sessions: null, mark: { icon: "lock", title: "From a plugin, open only" } },
];

function RankList({ rows, agents, max, first = 0, ranked }: { readonly rows: readonly RankRow[]; readonly agents: readonly AgentName[]; readonly max: number; readonly first?: number; readonly ranked: number }) {
  return (
    <ol className="all">
      {rows.map((row, i) => {
        const place = first + i + 1;
        const isRanked = place <= ranked;
        const cls = [row.selected ? "on" : "", isRanked ? "" : "idle", row.worth ? "worth" : ""].join(" ").trim();
        return (
          <li key={row.name} className={cls || undefined} title={row.name}>
            <span className={`num${isRanked ? (place <= 3 ? ` r${place}` : "") : " none"}`}>{isRanked ? place : ""}</span>
            <span className="r-name">
              <span className="nm">{row.name}</span>
              {row.mark ? (
                <span className="mk" title={row.mark.title}>
                  <Icon name={row.mark.icon} size={13} />
                </span>
              ) : null}
            </span>
            <Strip agents={agents} has={row.has} />
            <span className="r-bar">{isRanked && row.sessions ? <i style={{ width: `${(row.sessions / max) * 100}%` } as CSSProperties} /> : null}</span>
            <b title={row.sessions === null ? "Sessions not known" : undefined}>{row.sessions === null ? "–" : row.sessions}</b>
          </li>
        );
      })}
    </ol>
  );
}

/** Hero: the top of the Skills list, rows 1 to 8, lint-fixer selected. The card goes on below the stage's edge. */
export function SkillsTopStage() {
  return (
    <div className="ak">
      <section className="kcard all-card cut-bottom">
        <div className="card-head">
          <h4>All skills · most used first</h4>
          <span>Sessions · last 24 days</span>
        </div>
        <RankList rows={SKILLS.slice(0, 8)} agents={FIVE} max={67} ranked={9} />
      </section>
    </div>
  );
}
