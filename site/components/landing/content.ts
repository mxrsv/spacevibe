/**
 * Every word and number on the landing page. Product truth comes from `../../PRODUCT.md` and the
 * landing spec in `docs/specs/` (ledger L1 to L16 and its 2026-11-22 amendments); every claim below
 * is one the app shows on its own screen or PRODUCT.md states, and nothing here is a number about
 * real users. `site/tests/landing-facts.test.mjs` checks the Limits wording and that every screen
 * named here exists.
 */

import type { ShotKey } from "./shots";

// The same `mxrsv/spacevibe` as GITHUB_REPO in scripts/release.sh (settled by the owner on 2026-11-21,
// SV ledger D-1). Change both together.
export const GITHUB_URL = "https://github.com/mxrsv/spacevibe";
export const DOWNLOAD_URL = `${GITHUB_URL}/releases/latest`;

export const SITE = {
  brand: "SpaceVibe",
  url: "https://spacevibe.dev",
  title: "SpaceVibe — see what your coding agents carry",
  description:
    "A local Mac app that shows every skill, subagent and hook Claude Code and Codex carry, how often each ran, what each may do, and what it cost. Nothing leaves the machine.",
  // The first viewport at 1200 x 630 without the header, saved from the built page; retake it when the hero changes.
  ogImage: {
    src: "/og.jpg",
    width: 1200,
    height: 630,
    alt: "SpaceVibe: See what your coding agents carry. Beside the headline, five readings: 780 MB can be cleaned, 5 skills never ran, 2 rules allow a whole tool, 77% left in the Codex 5-hour window, 1 session waiting for you.",
  },
} as const;

export type CLI = "claude" | "codex";

export const CLI_LABEL: Record<CLI, string> = {
  claude: "Claude Code",
  codex: "Codex",
};

export interface NavLink {
  readonly href: string;
  readonly label: string;
}

export const NAV = [
  { href: "#clean", label: "Clean" },
  { href: "#skills", label: "Skills" },
  { href: "#rules", label: "Rules" },
  { href: "#limits", label: "Limits" },
  { href: "#activity", label: "Activity" },
] as const;

export const HEADER = {
  github: { href: GITHUB_URL, label: "GitHub" },
  cta: { href: DOWNLOAD_URL, label: "Download for macOS" },
} as const;

/**
 * The hero is under review (owner, 2026-11-22: a visitor cannot tell at a glance what the app is for).
 * The owner picked the logo row on 2026-11-22. `/` shows layout `b` with the second headline, the
 * recommendation, until the owner confirms layout and headline on `/hero-lab`; the unpicked ones are then deleted.
 */
export type HeroLayout = "now" | "a" | "b" | "c";

export const HERO_HEADLINES = [
  ["Which of your skills", "actually run?"],
  ["See what your", "coding agents carry."],
  ["Clean up what your", "agents never use."],
] as const;

export const HERO = {
  // The app is for agent CLIs in general (RD13), so this line names the category; the row under the heading says which CLIs.
  eyebrow: "A local Mac app for AI coding agents",
  /**
   * The CLIs the core reads today (`core/internal/cliregistry`), with the marks the app itself ships in
   * `Resources/Brand`. A CLI joins this row in the release that reads it, never before.
   */
  support: {
    lead: "Works with",
    clis: [
      { name: "Claude\u00A0Code", mark: "/landing/brand/claude-spark-clay.svg" },
      { name: "Codex", mark: "/landing/brand/codex-blossom-white.svg" },
    ],
  },
  lede: "SpaceVibe is a local Mac app for Claude Code and Codex CLI. It counts, from your own session logs, how often every skill, subagent and hook ran, puts what never ran in one inbox, and says plainly when a CLI logs nothing to count.",
  /** The lede without its first sentence, for the layouts whose eyebrow already says what the app is. */
  ledeShort: "SpaceVibe counts, from your own session logs, how often every skill, subagent and hook ran, puts what never ran in one inbox, and says plainly when a CLI logs nothing to count.",
  cta: { note: "macOS 15 or later · Apple silicon", label: "Download for macOS", href: DOWNLOAD_URL },
  shot: "inbox",
  rowsShot: "inboxRows",
  /** Layout A: the three jobs from PRODUCT.md, each a link to its band. */
  jobs: [
    { href: "#clean", verb: "Clean up", rest: "what never ran" },
    { href: "#rules", verb: "Control", rest: "what each CLI may do" },
    { href: "#limits", verb: "Watch", rest: "limits and sessions" },
  ],
  /** Layout B: one reading per screen, the figures of the captures below (the app's illustration data). */
  readingsCaption: "What SpaceVibe shows · demo data",
  readings: [
    { band: "clean", figure: "780", unit: "MB", label: "can be cleaned", tone: "warn" },
    { band: "skills", figure: "5", unit: "", label: "skills never ran", tone: "warn" },
    { band: "rules", figure: "2", unit: "", label: "rules allow a whole tool", tone: "warn" },
    { band: "limits", figure: "77", unit: "%", label: "left in the Codex 5-hour window", tone: "warn", meter: 0.77 },
    { band: "activity", figure: "1", unit: "", label: "session waiting for you", tone: "warn" },
  ],
} as const satisfies {
  readonly shot: ShotKey;
  readonly rowsShot: ShotKey;
  readonly readings: readonly { readonly band: BandId; readonly tone: "ok" | "warn"; readonly meter?: number; readonly [key: string]: unknown }[];
  readonly [key: string]: unknown;
};

/* ---------------------------------------------------------------- the bands */

export type BandId = "clean" | "skills" | "rules" | "limits" | "activity";

export interface Band {
  readonly id: BandId;
  /** The screen's name in the app's sidebar. */
  readonly label: string;
  readonly question: string;
  readonly answer: string;
  readonly shot: ShotKey;
  /** The shot is the inspector alone, so it sits beside the words instead of under them. */
  readonly narrow?: boolean;
  readonly caption: string;
}

const DEMO = "demo data";

/** In the order of the jobs in PRODUCT.md: clean up, balance and control, then watch. */
export const BANDS: readonly Band[] = [
  {
    id: "clean",
    label: "Clean",
    question: "What can go, and how much does it free?",
    answer:
      "Skills, subagents and hooks that never ran, hooks whose script is gone, and old session logs and caches, each with its size. Tick what goes and remove it in one step; Undo brings it back.",
    shot: "clean",
    caption: `Clean · ${DEMO}`,
  },
  {
    id: "skills",
    label: "Skills",
    question: "What is installed, and how often did it run?",
    answer:
      "One list across both CLIs, joined to usage counted from your local session logs: never ran, ran often, present in one CLI and missing in the other, with an action to add it there. Subagents have a page like it; Hooks lists which commands fire on each event.",
    shot: "skills",
    caption: `Skills · ${DEMO}`,
  },
  {
    id: "rules",
    label: "Rules",
    question: "What is each CLI allowed to do?",
    answer:
      "Claude Code’s rules as Allow, Ask or Deny per capability, with the rule behind each one and a warning on a rule that allows a whole tool. Codex’s sandbox and approvals are shown in its own words.",
    shot: "rules",
    caption: `Rules · ${DEMO}`,
  },
  {
    id: "limits",
    label: "Limits",
    question: "How much of my limit is left?",
    answer:
      "Read from Claude Code’s own usage cache, or optionally its status-line capture, and from Codex’s session logs, with no login and no API call. A CLI that keeps no usage file reads as not measurable; SpaceVibe never guesses.",
    shot: "limits",
    narrow: true,
    caption: `A limit window · ${DEMO}`,
  },
  {
    id: "activity",
    label: "Activity",
    question: "What is running, and what is waiting for me?",
    answer:
      "Running, waiting and idle sessions with their current tool and their own estimated cost, and failed commands grouped with a count. Cost per day and model is Tokens, in development. Stop a session from here. Where a CLI cannot be read, SpaceVibe says so instead of guessing.",
    shot: "activity",
    narrow: true,
    caption: `A session · ${DEMO}`,
  },
];

/**
 * How much of a screen one CLI lets the app do. `full`: read (and where the screen writes, written) in
 * full. `partial`: the CLI logs nothing for part of it, so that part reads not measurable. `readonly`:
 * shown, never edited.
 */
export type Reach = "full" | "partial" | "readonly";

export interface CliLine {
  readonly reach: Reach;
  /** Two or three words for the reach on this screen, in the app's own vocabulary. */
  readonly verdict: string;
  readonly detail: string;
}

/** What differs between the two CLIs on each screen, in the app's own words. */
export const DIFFS: Record<BandId, Record<CLI, CliLine>> = {
  clean: {
    claude: {
      reach: "full",
      verdict: "Moved, with Undo",
      detail: "Old session logs, shell snapshots and the debug cache go to the macOS Trash. Logs a running session holds stay locked.",
    },
    codex: {
      reach: "full",
      verdict: "Moved, .jsonl.zst too",
      detail: "Old session logs, plain or compressed, and the cache go the same way, by the age you pick: 30, 90 or 180 days. Logs a running session holds stay locked.",
    },
  },
  skills: {
    claude: {
      reach: "full",
      verdict: "All three counted",
      detail: "Counts how often each skill, subagent and hook ran, and which hook commands fire on each event.",
    },
    codex: {
      reach: "partial",
      verdict: "Hooks not measurable",
      detail: "Counts skills and subagents. Codex does not log hook runs, so a hook reads not measurable, never 0.",
    },
  },
  rules: {
    claude: {
      reach: "full",
      verdict: "Editable",
      detail: "Allow, Ask or Deny for each capability, with the concrete rules behind each one.",
    },
    codex: {
      reach: "readonly",
      verdict: "Read only",
      detail: "Sandbox and approval settings in Codex’s own words, shown and never edited.",
    },
  },
  limits: {
    claude: {
      reach: "full",
      verdict: "Usage cache",
      detail: "The share left in each window, from Claude Code’s own usage cache or, once installed, its status-line capture.",
    },
    codex: {
      reach: "full",
      verdict: "Last turn",
      detail: "The share left, read from the last Codex turn, with how old that reading is.",
    },
  },
  activity: {
    claude: {
      reach: "partial",
      verdict: "Prompts not logged",
      detail: "Claude Code does not record permission prompts, so a long tool run and a wait for approval look the same.",
    },
    codex: {
      reach: "partial",
      verdict: "Silent while a tool runs",
      detail: "Codex logs nothing while a tool runs and writes no log until the first prompt is sent.",
    },
  },
};

export const UPCOMING = {
  id: "next",
  heading: "Tokens is in development.",
  label: "In development",
  body: "Tokens and estimated cost per day, model and project for both CLIs, kept as a local history. Not in the current download.",
  watch: { href: `${GITHUB_URL}/releases`, label: "Watch releases on GitHub" },
} as const;

export const PRIVATE = {
  id: "private",
  heading: "Private by construction.",
  items: [
    {
      lead: "No network listener, no account, no telemetry.",
      body: "The only requests the app makes are its daily update check and the download you click. No user data passes through the site either.",
    },
    {
      lead: "Nothing is executed.",
      body: "A hook is shown and written, never run by the app. Session logs are read-only.",
    },
    {
      lead: "Every write has a way back.",
      body: "Writes go only to the skill, subagent, hook and permission locations of each CLI, and each one keeps a restorable copy. Undo is one click.",
    },
    {
      lead: "Secrets stay unread.",
      body: "Values that may be secrets are never read into the interface or logged. Plugin-owned items are read-only.",
    },
  ],
} as const;

export const FAQ = {
  id: "faq",
  heading: "Before you download.",
  /** Only what the bands and the privacy panel do not already answer; every answer is a fact from PRODUCT.md. */
  items: [
    {
      q: "Is it free?",
      a: "Yes. The download is free and needs no account.",
    },
    {
      q: "Which CLIs does it read?",
      a: "Claude Code and Codex. Gemini CLI keeps no usage file, so its limit reads as not measurable instead of a guess.",
    },
    {
      q: "Do I have to sign in to Claude or OpenAI?",
      a: "No. Everything is read from files the CLIs already keep on your Mac: no login, no API key, no API call.",
    },
    {
      q: "What does it change in my setup?",
      a: "Only what you ask for, in the skill, subagent, hook and permission locations of each CLI. MCP servers, the model, CLAUDE.md and AGENTS.md are never written, and plugin-owned items are read only.",
    },
    {
      q: "How exact is the cost?",
      a: "It is an estimate at API-equivalent rates and says so. A model with no known price reads as not measurable, never as 0.",
    },
    {
      q: "Does Clean change my usage counts?",
      a: "No. A moved log keeps only its usage totals, which the counts on Skills, Subagents and Hooks still include.",
    },
    {
      q: "How do updates work?",
      a: "SpaceVibe checks once a day and installing takes a click. The check can be turned off in Settings.",
    },
  ],
} as const;

export const DOWNLOAD = {
  id: "download",
  heading: "Download SpaceVibe for macOS",
  body: "Free. macOS\u00A015 or later on Apple\u00A0silicon.",
  cta: { href: DOWNLOAD_URL, label: "Download for macOS" },
  secondary: { href: GITHUB_URL, label: "GitHub" },
} as const;

export const FOOTER = {
  /** Goes with the CLI marks in the hero: naming a product is not a claim of a tie to its maker. */
  disclaimer: "SpaceVibe is not affiliated with Anthropic or OpenAI. Claude\u00A0Code and Codex are trademarks of their owners.",
  brand: "SpaceVibe",
  by: "SpaceVibe",
  nav: NAV,
  github: { href: GITHUB_URL, label: "GitHub" },
} as const;
