import type { CSSProperties } from "react";

import { AgentMark, FIVE, Strip, TWO, type AgentName } from "./agents";
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

/** Subagents, from `pages/subagents.mjs`: only Claude Code and Codex carry subagents. */
const SUBAGENTS: readonly RankRow[] = [
  { name: "typescript-reviewer", has: [1, 0], sessions: 34 },
  { name: "react-reviewer", has: [1, 0], sessions: 19 },
  { name: "database-reviewer", has: [1, 0], sessions: 6 },
  { name: "security-reviewer", has: [1, 1], sessions: 4, selected: true },
  { name: "architect", has: [1, 0], sessions: 0 },
  { name: "migration-reviewer", has: [1, 0], sessions: 0, mark: { icon: "lock", title: "Project subagent (spacevibe-bench): read-only. It can be copied, not removed" } },
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

/** Skills band: the idle rows at the bottom of the list, from pdf-extract to checkout-flows, down to the card's end. */
export function SkillsIdleStage() {
  return (
    <div className="ak" style={{ paddingTop: 0, paddingBottom: 4 }}>
      <section className="kcard all-card cut-top" style={{ paddingBottom: 25 }}>
        <RankList rows={SKILLS.slice(9)} agents={FIVE} max={67} first={9} ranked={9} />
      </section>
    </div>
  );
}

export function SubagentsStage() {
  return (
    <div className="ak">
      <section className="kcard all-card cut-bottom sub" style={{ paddingBottom: 14 }}>
        <div className="card-head">
          <h4>All subagents · most used first</h4>
          <span>Sessions · last 24 days</span>
        </div>
        <RankList rows={SUBAGENTS} agents={TWO} max={34} ranked={4} />
      </section>
    </div>
  );
}

/* ------------------------------------------------------------------ Hooks */

interface HookRow {
  readonly cmd: string;
  readonly matcher?: string;
  readonly cli: AgentName;
  /** null = unmeasurable (Codex does not log hook runs). */
  readonly runs: number | null;
  readonly errors?: number;
  readonly state?: "dead" | "project";
  readonly selected?: boolean;
}

const HOOKS: readonly { readonly event: string; readonly rows: readonly HookRow[] }[] = [
  { event: "SessionStart", rows: [{ cmd: "load-context.sh", cli: "Claude Code", runs: 58 }] },
  {
    event: "PreToolUse",
    rows: [
      { cmd: "guard-destructive.sh", matcher: "Bash", cli: "Claude Code", runs: 412 },
      { cmd: "block-env-edit.sh", matcher: "Edit|Write", cli: "Claude Code", runs: 96, errors: 3 },
    ],
  },
  {
    event: "PostToolUse",
    rows: [
      { cmd: 'prettier --write "$FILE"', matcher: "Edit|Write", cli: "Claude Code", runs: 1204, errors: 17, selected: true },
      { cmd: "tools/tsc-watch.sh", matcher: "Edit", cli: "Claude Code", runs: 0, state: "dead" },
      { cmd: "echo checked", matcher: "Edit", cli: "Claude Code", runs: 0, state: "project" },
    ],
  },
  {
    event: "Stop",
    rows: [
      { cmd: "notify-done.sh", cli: "Claude Code", runs: 203 },
      { cmd: "notify-done.sh", cli: "Codex", runs: null },
      { cmd: "old-dotfiles/notify.sh", cli: "Claude Code", runs: 0, state: "dead" },
    ],
  },
];

export function HooksStage() {
  return (
    <div className="ak">
      <section className="kcard all-card cut-bottom hk" style={{ paddingBottom: 21 }}>
        <div className="card-head">
          <h4>All hooks · by event</h4>
          <span>Runs · errors</span>
        </div>
        <ol className="all">
          {HOOKS.flatMap((group) => [
            <li key={group.event} className="grp">
              <span>
                {group.event} · {group.rows.length}
              </span>
            </li>,
            ...group.rows.map((h) => (
              <li key={`${group.event}-${h.cmd}-${h.cli}`} className={[h.selected ? "on" : "", h.runs === 0 ? "idle" : ""].join(" ").trim() || undefined}>
                <AgentMark name={h.cli} />
                <span className="cm">
                  <code>{h.cmd}</code>
                  {h.state === "dead" ? (
                    <span className="mk dead" title="Script missing: the command points at a file that no longer exists">
                      <Icon name="unlink" size={13} />
                    </span>
                  ) : h.state === "project" ? (
                    <span className="mk" title="Project hook (spacevibe-bench): read-only">
                      <Icon name="lock" size={13} />
                    </span>
                  ) : null}
                  {h.matcher ? (
                    <i className="hk-m" title="Matcher">
                      {h.matcher}
                    </i>
                  ) : null}
                </span>
                {h.runs === null ? (
                  <span className="um" title="Codex does not log hook runs, so runs and errors cannot be measured">
                    unmeasurable
                  </span>
                ) : (
                  <>
                    <b>{h.runs.toLocaleString("en-US")}</b>
                    <span className="er">
                      {h.errors ? (
                        <span className="e" title={`${h.errors} errors`}>
                          <Icon name="alert" size={12} />
                          {h.errors}
                        </span>
                      ) : null}
                    </span>
                  </>
                )}
              </li>
            )),
          ])}
        </ol>
      </section>
    </div>
  );
}

/* ------------------------------------------------------------------ Rules */

const RULE_FILES = [
  { name: "Global", scope: "all projects", rules: 11, allow: 6, ask: 2, deny: 3, wide: 1 },
  { name: "spacevibe-bench", scope: "shared", rules: 2, allow: 2, ask: 0, deny: 0, wide: 0 },
  { name: "spacevibe-api", scope: "shared", rules: 1, allow: 0, ask: 0, deny: 1, wide: 0 },
  { name: "spacevibe-academy", scope: "shared", rules: 6, allow: 2, ask: 3, deny: 1, wide: 2, selected: true },
  { name: "spacevibe-academy", scope: "local", rules: 1, allow: 1, ask: 0, deny: 0, wide: 0 },
] as const;

export function RulesStage() {
  const fig = (n: number) => <span className={`rl-fig${n ? "" : " zero"}`}>{n}</span>;
  return (
    <div className="ak">
      <section className="kcard all-card rl-card cut-bottom" style={{ paddingBottom: 16 }}>
        <div className="card-head">
          <h4>Rule files</h4>
          <span>Each file stands alone</span>
        </div>
        <div className="rl-head">
          <span>File</span>
          <span>Rules</span>
          <span>Allow</span>
          <span>Ask</span>
          <span>Deny</span>
          <span />
        </div>
        <ol className="rl-list">
          {RULE_FILES.map((f) => (
            <li key={`${f.name}-${f.scope}`} className={"selected" in f && f.selected ? "on" : undefined} title={`${f.name} · ${f.scope} · ${f.rules} rules`}>
              <span className="f-name">
                <span className="nm">{f.name}</span>
                <span className="sc">{f.scope}</span>
              </span>
              <b className="f-n">{f.rules}</b>
              {fig(f.allow)}
              {fig(f.ask)}
              {fig(f.deny)}
              <span className="f-wide" title={f.wide ? `${f.wide} wide ${f.wide === 1 ? "allow" : "allows"}` : undefined}>
                {f.wide ? (
                  <>
                    <Icon name="unlock" size={13} />
                    {f.wide}
                  </>
                ) : null}
              </span>
            </li>
          ))}
        </ol>
        <ol className="rl-list rl-codex-list">
          <li title="Codex · read-only summary">
            <span className="f-name">
              <AgentMark name="Codex" />
              <span className="nm">Codex</span>
              <span className="mk" title="Read-only summary">
                <Icon name="lock" size={13} />
              </span>
            </span>
          </li>
        </ol>
      </section>
    </div>
  );
}
