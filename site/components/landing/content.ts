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
  title: "SpaceVibe — see what Claude Code and Codex carry",
  description:
    "A local Mac app that shows every skill, subagent and hook Claude Code and Codex carry, how often each ran, what each may do, and what it cost. Nothing leaves the machine.",
  // The first viewport at 1200 x 630 without the header, saved from the built page; retake it when the hero changes.
  ogImage: {
    src: "/og.jpg",
    width: 1200,
    height: 630,
    alt: "SpaceVibe: Which of your skills actually run? Above the app's Inbox with 12 rows that need you.",
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

export const HERO = {
  headingLines: ["Which of your skills", "actually run?"] as const,
  lede: "SpaceVibe is a local Mac app for Claude Code and Codex CLI. It counts, from your own session logs, how often every skill, subagent and hook ran, puts what never ran in one inbox, and says plainly when a CLI logs nothing to count.",
  cta: { note: "macOS 15 or later · Apple silicon", label: "Download for macOS", href: DOWNLOAD_URL },
  shot: "inbox",
} as const satisfies { readonly shot: ShotKey; readonly [key: string]: unknown };

/* ---------------------------------------------------------------- the bands */

export type BandId = "clean" | "skills" | "rules" | "limits" | "activity";

export interface Band {
  readonly id: BandId;
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
    question: "What can go, and how much does it free?",
    answer:
      "Skills, subagents and hooks that never ran, hooks whose script is gone, and old session logs and caches, each with its size. Tick what goes and remove it in one step; Undo brings it back.",
    shot: "clean",
    caption: `Clean · ${DEMO}`,
  },
  {
    id: "skills",
    question: "What is installed, and how often did it run?",
    answer:
      "One list across both CLIs, joined to usage counted from your local session logs: never ran, ran often, present in one CLI and missing in the other. Subagents and hooks have the same page of their own.",
    shot: "skills",
    caption: `Skills · ${DEMO}`,
  },
  {
    id: "rules",
    question: "What is each CLI allowed to do?",
    answer:
      "Claude Code’s rules as Allow, Ask or Deny per capability, with the rule behind each one and a warning on a rule that allows a whole tool. Codex’s sandbox and approvals are shown in its own words.",
    shot: "rules",
    caption: `Rules · ${DEMO}`,
  },
  {
    id: "limits",
    question: "How much of my limit is left?",
    answer:
      "Read from Claude Code’s own usage cache, or optionally its status-line capture, and from Codex’s session logs, with no login and no API call. A CLI that keeps no usage file reads as not measurable; SpaceVibe never guesses.",
    shot: "limits",
    narrow: true,
    caption: `A limit window · ${DEMO}`,
  },
  {
    id: "activity",
    question: "What is running, and what is waiting for me?",
    answer:
      "Running, waiting and idle sessions with their current tool and estimated cost, and failed commands grouped with a count. Stop a session from here. Where a CLI cannot be read, SpaceVibe says so instead of guessing.",
    shot: "activity",
    narrow: true,
    caption: `A session · ${DEMO}`,
  },
];

/** What differs between the two CLIs on each screen, in the app's own words. */
export const DIFFS: Record<BandId, Record<CLI, string>> = {
  clean: {
    claude: "Old session logs, shell snapshots and the debug cache go to the macOS Trash. Logs a running session holds stay locked.",
    codex: "Old session logs and the cache go the same way, by the age you pick: 30, 90 or 180 days.",
  },
  skills: {
    claude: "Counts how often each skill, subagent and hook ran, and which hook commands fire on each event.",
    codex: "Counts skills and subagents. Codex does not log hook runs, so a hook reads not measurable, never 0.",
  },
  rules: {
    claude: "Allow, Ask or Deny for each capability, editable, with the concrete rules behind each one.",
    codex: "Sandbox and approval settings in Codex’s own words, shown read only.",
  },
  limits: {
    claude: "Reads the share left in each window from Claude Code’s own usage cache, or from its status-line capture when that is installed.",
    codex: "Reads it from the last Codex turn, and shows how old that reading is.",
  },
  activity: {
    claude: "Claude Code does not record permission prompts, so a long tool run and a wait for approval look the same.",
    codex: "Codex logs nothing while a tool runs and writes no log until the first prompt is sent.",
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
      body: "Writes go only to the skill, agent, hook and permission locations of each CLI, and each one keeps a restorable copy. Undo is one click.",
    },
    {
      lead: "Secrets stay unread.",
      body: "Values that may be secrets are never read into the interface or logged. Plugin-owned items are read-only.",
    },
  ],
} as const;

export const DOWNLOAD = {
  id: "download",
  heading: "Download SpaceVibe for macOS",
  body: "Free. macOS\u00A015 or later on Apple\u00A0silicon. SpaceVibe checks for updates once a day; installing one takes a click.",
  cta: { href: DOWNLOAD_URL, label: "Download for macOS" },
  secondary: { href: GITHUB_URL, label: "GitHub" },
} as const;

export const FOOTER = {
  brand: "SpaceVibe",
  by: "SpaceVibe",
  nav: NAV,
  github: { href: GITHUB_URL, label: "GitHub" },
} as const;
