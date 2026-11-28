import type { CSSProperties } from "react";

import { AgentMark, FIVE, Strip, TWO, type AgentName } from "./agents";
import { Icon } from "./icons";
import { HOOKS, RULE_FILES, SKILLS, SKILLS_HERO_ROWS, SKILLS_IDLE_FROM, SUBAGENTS, type RankRow } from "./data";

/**
 * The regions of the Kanu renders that the landing shows, drawn as live markup (2026-11-27). The data is the renders'
 * own (`data.md`; the pages' tables), so every name, count and state is what the render draws. Each stage is the part of its
 * 1440 x 900 render that the earlier crops cut (x 266 to 862), at 1x: a 584 px card inside 6 px of the window.
 */

/** `select: false` draws the list with no row selected (the window's idle state, L41). */
export function RankList({ rows, agents, max, first = 0, ranked, select = true }: { readonly rows: readonly RankRow[]; readonly agents: readonly AgentName[]; readonly max: number; readonly first?: number; readonly ranked: number; readonly select?: boolean }) {
  return (
    <ol className="all">
      {rows.map((row, i) => {
        const place = first + i + 1;
        const isRanked = place <= ranked;
        const cls = [select && row.selected ? "on" : "", isRanked ? "" : "idle", row.worth ? "worth" : ""].join(" ").trim();
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
        <RankList rows={SKILLS.slice(0, SKILLS_HERO_ROWS)} agents={FIVE} max={67} ranked={SKILLS_IDLE_FROM} />
      </section>
    </div>
  );
}

/** Skills band: the idle rows at the bottom of the list, from pdf-extract to checkout-flows, down to the card's end. */
export function SkillsIdleStage() {
  return (
    <div className="ak" style={{ paddingTop: 0, paddingBottom: 4 }}>
      <section className="kcard all-card cut-top" style={{ paddingBottom: 25 }}>
        <RankList rows={SKILLS.slice(SKILLS_IDLE_FROM)} agents={FIVE} max={67} first={SKILLS_IDLE_FROM} ranked={SKILLS_IDLE_FROM} />
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

/* ------------------------------------------------------------------ Hooks */

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

/* ------------------------------------------------------------------ Rules */

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
