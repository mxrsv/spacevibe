/**
 * Every word and number on the landing page. Product truth comes from `../../PRODUCT.md` and the
 * landing spec in `docs/specs/` (ledger L1 to L39); every claim below
 * is one the app shows on its own screen or PRODUCT.md states, and nothing here is a number about
 * real users. `site/tests/landing-facts.test.mjs` checks that every band has a drawing and a line per CLI.
 */

// The same `mxrsv/spacevibe` as GITHUB_REPO in scripts/release.sh (settled by the owner on 2026-11-21,
// SV ledger D-1). Change both together.
export const GITHUB_URL = "https://github.com/mxrsv/spacevibe";
export const DOWNLOAD_URL = `${GITHUB_URL}/releases/latest`;
export const WATCH_URL = `${GITHUB_URL}/releases`;

export const SITE = {
  brand: "SpaceVibe",
  url: "https://spacevibe.dev",
  title: "SpaceVibe — see what your coding agents carry",
  description:
    "A local Mac app that shows every skill, subagent and hook Claude Code and Codex carry, how often each ran, what each may do, and what it cost. Nothing leaves the machine.",
  // The first viewport at 1200 x 630 without the announcement bar and the header, saved from the built page (headless Chrome, header and bar removed, 1200 wide); retake it when the hero changes.
  ogImage: {
    src: "/og.jpg",
    width: 1200,
    height: 630,
    alt: "SpaceVibe: See what your coding agents carry. Under the headline, the Download for macOS button and GitHub, the line \"Free, macOS 15 or later, Apple silicon\", Claude Code and Codex under \"Works with\", and the top of the Skills list drawn in a window, between icon tiles for skills, subagents and hooks.",
  },
} as const;

export type CLI = "claude" | "codex";

export const CLI_LABEL: Record<CLI, string> = {
  claude: "Claude Code",
  codex: "Codex",
};

/** The marks the app itself ships in `Resources/Brand`, for the ledger rows. */
export const CLI_MARK: Record<CLI, string> = {
  claude: "/landing/brand/claude-spark-clay.svg",
  codex: "/landing/brand/codex-blossom-white.svg",
};

export interface NavLink {
  readonly href: string;
  readonly label: string;
}

/** The header pill and the footer's Screens column (L31, L39): the four screens the page's bands draw. */
export const NAV = [
  { href: "#skills", label: "Skills" },
  { href: "#subagents", label: "Subagents" },
  { href: "#hooks", label: "Hooks" },
  { href: "#rules", label: "Rules" },
] as const;

/** The header button reads `label` on a phone and `label` + `rest` from `sm:` up; `rest` stays in the accessible name. */
export const HEADER = {
  github: { href: GITHUB_URL, label: "GitHub" },
  cta: { href: DOWNLOAD_URL, label: "Download", rest: " for macOS" },
} as const;

/** The hero (L25): the eyebrow, the headline, the "Works with" row and the download note; HERO_LINE is the one dim line. */
export const HERO = {
  headline: ["See what your", "coding agents carry."],
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
  cta: { note: "Free · macOS 15 or later · Apple silicon", label: "Download for macOS", href: DOWNLOAD_URL },
} as const;

/* ---------------------------------------------------------------- the bands */

/** L39: the four screens the Kanu renders cover, in the order of PRODUCT.md's equipment. Clean, Limits and Activity have no band yet. */
export type BandId = "skills" | "subagents" | "hooks" | "rules";
export type ReadingTone = "ok" | "warn" | "plain";

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

export interface Band {
  readonly id: BandId;
  /** The screen's name in the app's sidebar. */
  readonly label: string;
  readonly question: string;
  readonly answer: string;
  /** The sentence that stands for the drawn stage (components/landing/app-stage) for a reader who does not see it. */
  readonly stageLabel: string;
  /** The band's one figure: a reading that is true in the render and whose evidence is in the crop. */
  readonly reading: { readonly figure: string; readonly unit: string; readonly label: string; readonly tone: ReadingTone };
  readonly ledger: Record<CLI, CliLine>;
}

/**
 * Skills and Rules keep the words the page had before the redesign. Subagents and Hooks are INFERRED wording built from
 * the Skills band's answer, PRODUCT.md (Mechanism) and the ledger. The figures are those of the render's own tiles; the
 * cards read "never ran" where the render's tile reads "Never used" (GLOSSARY.md: Never ran).
 */
export const BANDS: readonly Band[] = [
  {
    id: "skills",
    label: "Skills",
    question: "What is installed, and how often did it run?",
    answer:
      "One list across both CLIs, joined to usage counted from your local session logs: never ran, ran often, present in one CLI and missing in the other, with an action to add it there.",
    stageLabel: "Design preview of Skills, the bottom of the list: five skills with no sessions in 24 days, four at 0 and one not known, each with the agents that carry it; three are marked with a lock or a clock.",
    reading: { figure: "4", unit: "", label: "skills never ran", tone: "warn" },
    ledger: {
      claude: { reach: "full", verdict: "Counted", detail: "Counts how often each skill ran, from Claude Code’s session logs." },
      codex: { reach: "full", verdict: "Counted", detail: "Counts how often each skill ran, from Codex’s session logs." },
    },
  },
  {
    id: "subagents",
    label: "Subagents",
    question: "Which subagents do I have, and which ever ran?",
    answer:
      "The same list for subagents, joined to usage counted from your local session logs: ran often, never ran, and present in one CLI and missing in the other.",
    stageLabel: "Design preview of Subagents: six subagents most used first with a bar and a session count for each; the last two, architect and migration-reviewer, have 0 sessions.",
    reading: { figure: "2", unit: "", label: "subagents never ran", tone: "warn" },
    ledger: {
      claude: { reach: "full", verdict: "Counted", detail: "Counts how often each subagent ran, from Claude Code’s session logs." },
      codex: { reach: "full", verdict: "Counted", detail: "Counts how often each subagent ran, from Codex’s session logs." },
    },
  },
  {
    id: "hooks",
    label: "Hooks",
    question: "Which commands fire on each event?",
    answer:
      "Every hook under the event it fires on, with how often it ran. A hook whose script is gone is marked, and a hook of Codex, which does not log hook runs, reads not measurable, never 0.",
    stageLabel: "Design preview of Hooks: nine hooks grouped by the event they fire on, each with its command, a run count and, for two, an error count; one hook of Codex reads unmeasurable.",
    reading: { figure: "9", unit: "", label: "hooks, each under the event it fires on", tone: "plain" },
    ledger: {
      claude: { reach: "full", verdict: "Counted", detail: "Counts how often each hook ran and which hook commands fire on each event." },
      codex: { reach: "partial", verdict: "Hooks not measurable", detail: "Codex does not log hook runs, so a hook reads not measurable, never 0." },
    },
  },
  {
    id: "rules",
    label: "Rules",
    question: "What is each CLI allowed to do?",
    answer:
      "Claude Code’s rules as Allow, Ask or Deny per capability, with the rule behind each one and a warning on a rule that allows a whole tool. Codex’s sandbox and approvals are shown in its own words.",
    stageLabel: "Design preview of Rules: five rule files, each with its counts of rules, allow, ask and deny, and an open-lock icon on the files that hold a wide allow; Codex below, read only.",
    reading: { figure: "5", unit: "", label: "rule files, each one standing alone", tone: "plain" },
    ledger: {
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
  },
];

export const FAQ = {
  id: "faq",
  heading: "Before you download.",
  /** Only what the bands and the figures band do not already answer; every answer is a fact from PRODUCT.md. */
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

export const FOOTER = {
  /** Goes with the CLI marks in the hero: naming a product is not a claim of a tie to its maker. */
  disclaimer: "SpaceVibe is not affiliated with the makers of the agents it shows. Claude\u00A0Code, Codex, Gemini\u00A0CLI, Cursor and OpenCode are trademarks of their owners.",
  brand: "SpaceVibe",
  by: "SpaceVibe",
} as const;

/** The bar above the header (L31). It repeats the left card of the ending on purpose. */
export const ANNOUNCE = {
  text: "Tokens is in development",
  link: { href: WATCH_URL, label: "Watch releases" },
} as const;

/** Footer columns (reference): only links and words the page already has. */
export const FOOTER_COLUMNS = [
  { title: "Screens", links: NAV },
  {
    title: "SpaceVibe",
    links: [
      { href: DOWNLOAD_URL, label: "Download for macOS" },
      { href: WATCH_URL, label: "Watch releases" },
      { href: GITHUB_URL, label: "GitHub" },
      { href: `#${FAQ.id}`, label: "Questions" },
    ],
  },
] as const;

/** The one dim line under the hero heading (L25): the first clause of the old lede; the manifesto says the rest. */
export const HERO_LINE = "SpaceVibe counts, from your own session logs, how often every skill, subagent and hook ran.";

/**
 * The hero's window (L41) for a reader who does not see it. Its counts are the window's own (`WINDOW_FACTS` in
 * app-stage/data.ts); the facts test keeps them equal.
 */
export const HERO_WINDOW_LABEL =
  "Design preview of the whole SpaceVibe window on the Skills page: the sidebar with every page, four tiles (14 skills installed, 9 in use, 4 never used, 3 worth adding), the ranked list of 14 skills, and beside it the 4 skills never used, two of them with Keep and Remove, and the 3 skills worth adding, each with Add to.";

/** The caption of every frame that shows a render of the unshipped look (L7, LP-R5 wording). */
export const PREVIEW_CAPTION = "Design preview · not in the current download";

/**
 * The tiles around the hero (L30), icons only: the app's own skill, subagent and hook icons.
 * `x` and `y` are the tile's centre as a share of the hero's width and height; `lg` is where it stands from 1024 to 1279 px, where the words are wider than the room beside them.
 */
export type TileKind = "skills" | "subagents" | "hooks";
export const TILES: readonly { readonly id: string; readonly kind: TileKind; readonly x: number; readonly y: number; readonly lg?: readonly [number, number] }[] = [
  { id: "t1", kind: "skills", x: 6, y: 13 },
  { id: "t2", kind: "hooks", x: 15, y: 40, lg: [11, 28] },
  { id: "t3", kind: "skills", x: 5, y: 68 },
  { id: "t4", kind: "subagents", x: 94, y: 12 },
  { id: "t5", kind: "skills", x: 85, y: 40, lg: [89, 28] },
  { id: "t6", kind: "hooks", x: 95, y: 68 },
  { id: "t7", kind: "hooks", x: 22, y: 90 },
];
/** Pairs of tiles joined by a thin line. */
export const TILE_LINKS: readonly (readonly [string, string])[] = [
  ["t1", "t2"],
  ["t2", "t3"],
  ["t4", "t5"],
  ["t5", "t6"],
  ["t3", "t7"],
];

/**
 * The manifesto (L26): PRODUCT.md's Mechanism sentence, word for word. A string is words; an object is a bare icon set
 * in the sentence.
 */
export type ChipKey = "skills" | "subagents" | "hooks";
export const MANIFESTO = {
  label: "How it works",
  parts: [
    "One inventory across both CLIs, joined to usage counted from local session logs: installed but never invoked, invoked often, present in one CLI and missing in the other, and exactly which hook",
    { chip: "hooks" },
    "commands fire on each event.",
  ],
} as const satisfies { readonly label: string; readonly parts: readonly (string | { readonly chip: ChipKey })[] };

/**
 * The band of large figures (L28), "Private by construction.": what the app does not do, each a zero that holds on
 * every Mac. Each note restates PRODUCT.md and AGENTS.md (S-R3 to S-R5). No figure here is a count of users and none
 * repeats a demo reading (a number shows once). Every figure is a zero, so none counts up.
 */
export const FIGURES = {
  id: "private",
  label: "On every Mac",
  heading: "Private by construction.",
  line: "The only requests the app makes are its daily update check and the download you click. No user data passes through the site either.",
  items: [
    { value: 0, label: "Network listeners", note: "The app opens no port; it only checks for updates and downloads the one you click." },
    { value: 0, label: "Hooks or recorded commands the app starts", note: "The app never executes a hook or a recorded command; Claude Code, not the app, starts the status-line capture once you install it." },
    { value: 0, label: "Secret values from settings read into the interface", note: "Secret values in settings are never read into the interface or logged; in the commands shown, recognisable credentials are masked." },
  ],
} as const;

/** The two cards that end the page (L29): Tokens in development (L8), then the download (L14, L15). */
export const ENDING = {
  watch: {
    label: "In development",
    heading: "Watch releases on GitHub",
    body: "Tokens is in development. Tokens and estimated cost per day, model and project for both CLIs, kept as a local history. Not in the current download.",
    cta: { href: WATCH_URL, label: "Watch releases" },
  },
  download: {
    heading: "Download for macOS",
    note: HERO.cta.note,
    cta: { href: DOWNLOAD_URL, label: "Download" },
  },
} as const;
