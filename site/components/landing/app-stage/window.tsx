import type { ReactNode } from "react";

import { AgentMark, FIVE, Strip } from "./agents";
import { SKILLS, SKILLS_IDLE_FROM, STAGE_FACTS, SUBAGENTS, WINDOW, WINDOW_FACTS } from "./data";
import { Icon, type IconName } from "./icons";
import { RankList } from "./stages";

/**
 * The hero's window (L41): the whole Kanu render `skills-c-idle` (1440 x 900) as markup, the sidebar with every page beside
 * the Skills page with nothing selected. Its markup and class names follow `build.mjs` (`sidebar`, `bodyC`, `railIdle`); the
 * render's semantic tags (nav, aside, h1) are plain elements here, because the drawing is one picture inside the page. Every
 * count of the four drawn pages is counted from `data.ts`; the other pages' counts are the render's words (`WINDOW`).
 */

function NavItem({ icon, label, count, on = false, children }: { readonly icon: IconName; readonly label: string; readonly count: string; readonly on?: boolean; readonly children?: ReactNode }) {
  return (
    <span className={`it${on ? " on" : ""}`}>
      <Icon name={icon} size={17} />
      <span>{label}</span>
      <em>{count}</em>
      {children}
    </span>
  );
}

function Side() {
  return (
    <div className="side">
      <div className="lights">
        <i className="l1" />
        <i className="l2" />
        <i className="l3" />
      </div>
      <div className="brand">
        <span className="logo">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" aria-hidden="true">
            <circle cx="12" cy="12" r="3.2" fill="currentColor" stroke="none" />
            <path d="M4.5 16.5c-2-3.5 1-9 6-11.5" />
            <path d="M19.5 7.5c2 3.5-1 9-6 11.5" />
          </svg>
        </span>
        <span className="brand-name">SpaceVibe</span>
        <span className="brand-toggle">
          <Icon name="panel" size={16} />
        </span>
      </div>
      <div className="side-search">
        <Icon name="search" size={15} />
        <span>Search…</span>
        <kbd>⌘K</kbd>
      </div>
      <div className="navl">
        <NavItem icon="inbox" label="Inbox" count={WINDOW.inbox} />
        <div className="nav-label">Equipment</div>
        <NavItem icon="layers" label="Skills" count={String(WINDOW_FACTS.installed)} on />
        <NavItem icon="bot" label="Subagents" count={String(SUBAGENTS.length)} />
        <NavItem icon="plug" label="Hooks" count={String(STAGE_FACTS.hooks)} />
        <NavItem icon="book" label="Rules" count={String(WINDOW_FACTS.rules)} />
        <div className="nav-label">Upkeep</div>
        <NavItem icon="sparkle" label="Clean" count={WINDOW.clean} />
        <NavItem icon="gauge" label="Limits" count={WINDOW.limits} />
        <NavItem icon="activity" label="Activity" count={WINDOW.activity}>
          <b className="dot g" />
        </NavItem>
        <div className="nav-label">Setup</div>
        <NavItem icon="terminal" label="Agents" count={WINDOW.agents} />
      </div>
      <div className="side-foot">
        <div className="side-status">
          <Icon name="clock" size={16} />
          <span>Usage · last 24 days</span>
          <b className="dot g" />
        </div>
        <div className="ws">
          <span className="ws-text">
            <span className="strip">
              {FIVE.map((name) => (
                <AgentMark key={name} name={name} />
              ))}
            </span>
            <small>{WINDOW.agentsFoot}</small>
          </span>
          <Icon name="chevrons" size={14} />
        </div>
      </div>
    </div>
  );
}

function Tile({ icon, label, value, unit, sub, tone }: { readonly icon: IconName; readonly label: string; readonly value: number; readonly unit: string; readonly sub: string; readonly tone?: "v" }) {
  return (
    <div className="tile stack">
      <small>
        <Icon name={icon} size={15} />
        {label}
      </small>
      <p>
        <strong>{value}</strong>
        <span>{unit}</span>
      </p>
      <em className={tone}>{sub}</em>
    </div>
  );
}

function SmallButton({ label, icon, caret = false }: { readonly label: string; readonly icon?: IconName; readonly caret?: boolean }) {
  return (
    <span className="btn sm">
      {icon ? <Icon name={icon} size={14} /> : null}
      <span>{label}</span>
      {caret ? <Icon name="chevDown" size={13} /> : null}
    </span>
  );
}

function Badge({ icon, label }: { readonly icon: IconName; readonly label: string }) {
  return (
    <span className="badge grey">
      <Icon name={icon} size={12} />
      {label}
    </span>
  );
}

/** The right panel with nothing selected (S28): the skills never used, each with its decision, then the ones worth adding. */
function IdlePanel() {
  const never = SKILLS.filter((row) => row.sessions === 0);
  const worth = SKILLS.filter((row) => row.worth);
  return (
    <div className="rail one">
      <div className="kcard">
        <div className="sec">
          <div className="card-head">
            <h4>Never used</h4>
            <span>{WINDOW_FACTS.neverUsed} skills</span>
          </div>
          <ul className="acts">
            {never.map((row) => (
              <li key={row.name} title={row.name}>
                <div className="a-text">
                  <strong>{row.name}</strong>
                  <small>
                    <Strip agents={FIVE} has={row.has} />
                    {WINDOW.added[row.name] ? <span>{WINDOW.added[row.name]}</span> : null}
                  </small>
                </div>
                <div className="a-right">
                  {row.mark?.icon === "clock" ? (
                    <Badge icon="clock" label="Too new" />
                  ) : row.mark?.icon === "lock" ? (
                    <Badge icon="lock" label="Open only" />
                  ) : (
                    <>
                      <SmallButton label="Keep" />
                      <SmallButton label="Remove" />
                    </>
                  )}
                </div>
              </li>
            ))}
          </ul>
        </div>
        <div className="sec">
          <div className="card-head">
            <h4>Worth adding</h4>
            <span>
              {WINDOW_FACTS.worthAdding} of {WINDOW_FACTS.missingSomewhere} missing somewhere
            </span>
          </div>
          <ul className="acts worth">
            {worth.map((row) => (
              <li key={row.name} title={row.name}>
                <div className="a-text">
                  <strong>{row.name}</strong>
                  <small>
                    <Strip agents={FIVE} has={row.has} />
                    <span>{row.sessions} sessions</span>
                  </small>
                </div>
                <div className="a-right">
                  <SmallButton label="Add to" icon="plus" caret />
                </div>
              </li>
            ))}
          </ul>
          <ul className="links tail seeall">
            <li>
              <span>See all {WINDOW_FACTS.missingSomewhere} skills that are missing somewhere</span>
              <Icon name="chevRight" size={14} />
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}

export function SkillsWindowStage() {
  const f = WINDOW_FACTS;
  return (
    <div className="ak win">
      <div className="app">
        <Side />
        <div className="main">
          <div className="head">
            <div>
              <p className="h1">
                <span className="kind-ic">
                  <Icon name="layers" size={18} />
                </span>
                Skills
              </p>
              <p className="hsub">Every skill you have, which agents carry it, and how many sessions used it in 24 days</p>
            </div>
            <div className="tools">
              <span className="field">
                <Icon name="search" size={16} />
                <span>Search skills</span>
              </span>
              <span className="btn">
                <Icon name="listChecks" size={16} />
                <span>Select</span>
              </span>
            </div>
          </div>
          <div className="tiles">
            <Tile icon="layers" label="Installed" value={f.installed} unit="skills" sub={`Across ${FIVE.length} pinned agents`} />
            <Tile icon="activity" label="In use" value={f.inUse} unit={`of ${f.installed}`} sub={`${f.neverUsed} never used · ${f.notKnown} not known`} />
            <Tile icon="moon" label="Never used" value={f.neverUsed} unit="skills" sub={`${f.readyToDecide} ready to decide`} />
            <Tile icon="copyPlus" label="Worth adding" value={f.worthAdding} unit="skills" sub="20+ sessions, missing somewhere" tone="v" />
          </div>
          <div className="filters">
            <span className="pill on">All · {f.installed}</span>
            <span className="pill">In use · {f.inUse}</span>
            <span className="pill">Never used · {f.neverUsed}</span>
            <span className="pill">Worth adding · {f.worthAdding}</span>
            <span className="gap" />
            <span className="pill drop">
              All agents
              <Icon name="chevDown" size={14} />
            </span>
          </div>
          <div className="split-c">
            <section className="kcard all-card">
              <div className="card-head">
                <h4>All skills · most used first</h4>
                <span>Sessions · last 24 days</span>
              </div>
              <RankList rows={SKILLS} agents={FIVE} max={67} ranked={SKILLS_IDLE_FROM} select={false} />
            </section>
            <IdlePanel />
          </div>
        </div>
      </div>
    </div>
  );
}
