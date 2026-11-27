import type { AgentName } from "./agents";

/**
 * The data of the drawn stages, the Kanu renders' own (`data.md`; the pages' tables), apart from the markup so the facts
 * test (tests/landing-facts.test.mjs) can read it: plain TypeScript with no JSX and no imports but types. Every count a
 * band reads out (its figure, its drawing's description) is derived here, so a row that changes cannot leave a stale number.
 */

export type Has = readonly (0 | 1)[];

export interface RankRow {
  readonly name: string;
  readonly has: Has;
  /** Sessions in 24 days; null = not known. */
  readonly sessions: number | null;
  readonly worth?: boolean;
  readonly selected?: boolean;
  readonly mark?: { readonly icon: "lock" | "clock"; readonly title: string };
}

/** Skills, from `build.mjs` (SK, after the reach of D25) in the order of the list: ranked by sessions, then the idle ones. */
export const SKILLS: readonly RankRow[] = [
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
export const SUBAGENTS: readonly RankRow[] = [
  { name: "typescript-reviewer", has: [1, 0], sessions: 34 },
  { name: "react-reviewer", has: [1, 0], sessions: 19 },
  { name: "database-reviewer", has: [1, 0], sessions: 6 },
  { name: "security-reviewer", has: [1, 1], sessions: 4, selected: true },
  { name: "architect", has: [1, 0], sessions: 0 },
  { name: "migration-reviewer", has: [1, 0], sessions: 0, mark: { icon: "lock", title: "Project subagent (spacevibe-bench): read-only. It can be copied, not removed" } },
];

/** The hero shows the top of the Skills list; the band shows the rest from the first idle row. */
export const SKILLS_HERO_ROWS = 8;
export const SKILLS_IDLE_FROM = 9;

/* ------------------------------------------------------------------ Hooks */

export interface HookRow {
  readonly cmd: string;
  readonly matcher?: string;
  readonly cli: AgentName;
  /** null = unmeasurable (Codex does not log hook runs). */
  readonly runs: number | null;
  readonly errors?: number;
  readonly state?: "dead" | "project";
  readonly selected?: boolean;
}

export const HOOKS: readonly { readonly event: string; readonly rows: readonly HookRow[] }[] = [
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

/* ------------------------------------------------------------------ Rules */

export const RULE_FILES = [
  { name: "Global", scope: "all projects", rules: 11, allow: 6, ask: 2, deny: 3, wide: 1 },
  { name: "spacevibe-bench", scope: "shared", rules: 2, allow: 2, ask: 0, deny: 0, wide: 0 },
  { name: "spacevibe-api", scope: "shared", rules: 1, allow: 0, ask: 0, deny: 1, wide: 0 },
  { name: "spacevibe-academy", scope: "shared", rules: 6, allow: 2, ask: 3, deny: 1, wide: 2, selected: true },
  { name: "spacevibe-academy", scope: "local", rules: 1, allow: 1, ask: 0, deny: 0, wide: 0 },
] as const;

/** What the bands' figures and drawing descriptions say, counted from the rows above. */
export const STAGE_FACTS = {
  skillsNeverRan: SKILLS.filter((row) => row.sessions === 0).length,
  skillsHeroRows: SKILLS_HERO_ROWS,
  skillsIdleShown: SKILLS.slice(SKILLS_IDLE_FROM).length,
  skillsIdleAtZero: SKILLS.slice(SKILLS_IDLE_FROM).filter((row) => row.sessions === 0).length,
  skillsIdleUnknown: SKILLS.slice(SKILLS_IDLE_FROM).filter((row) => row.sessions === null).length,
  skillsIdleMarked: SKILLS.slice(SKILLS_IDLE_FROM).filter((row) => row.mark).length,
  subagents: SUBAGENTS.length,
  subagentsNeverRan: SUBAGENTS.filter((row) => row.sessions === 0).length,
  hooks: HOOKS.reduce((sum, group) => sum + group.rows.length, 0),
  hooksWithErrors: HOOKS.flatMap((group) => group.rows).filter((row) => row.errors).length,
  hooksUnmeasurable: HOOKS.flatMap((group) => group.rows).filter((row) => row.runs === null).length,
  ruleFiles: RULE_FILES.length,
  ruleFilesWithWideAllow: RULE_FILES.filter((file) => file.wide > 0).length,
} as const;
