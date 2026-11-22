/**
 * The app screens the page shows. The real ones are crops of dark captures of the SwiftUI app
 * (`SPACEVIBE_REDESIGN=1 SPACEVIBE_SHOT_SCREEN=<page> scripts/dev-fixture.sh --shots <dir>`, 2x, the
 * `solid-dark` variants, captured 2026-11-22): the whole Inbox window for the hero, the page without its
 * sidebar for Clean, Skills and Rules, and the inspector alone for a limit window and a session. Their
 * rows are the app's synthetic illustration data, never a real home. `previewTokens` is a render of the
 * tracked mock in `mocks/` for a page that is still in development; the page labels it a design preview.
 */
export interface Shot {
  readonly src: string;
  readonly width: number;
  readonly height: number;
  readonly alt: string;
}

export const SHOTS = {
  inbox: {
    src: "/landing/app/inbox.webp",
    width: 2560,
    height: 1800,
    alt: "SpaceVibe Inbox: 12 need you. Seven rows to clean up, among them skills and a subagent that never ran and hooks whose script is gone, three rows to control and two to watch. The selected skill shows Keep and Remove from Claude Code and Codex, and its files in the inspector.",
  },
  clean: {
    src: "/landing/app/clean.webp",
    width: 2112,
    height: 1400,
    alt: "Clean: 780 MB can be cleaned. Seven never-ran or dead skills, subagents and hooks are ticked with their size, Codex session logs older than 90 days are ticked, and Claude Code session logs are locked because one session uses them.",
  },
  skills: {
    src: "/landing/app/skills.webp",
    width: 2112,
    height: 1240,
    alt: "Skills: 5 never ran. Each row has the CLIs that carry the skill, a bar and a session count, and when it last ran; the selected skill shows its files and a Remove button.",
  },
  rules: {
    src: "/landing/app/rules.webp",
    width: 2112,
    height: 1180,
    alt: "Rules for Claude Code: six capabilities, each Allow, Ask, Deny or mixed, above the list of rules. The selected rule allows every call of Bash, and the inspector offers Change to Ask and Remove Rule.",
  },
  limits: {
    src: "/landing/app/limits.webp",
    width: 672,
    height: 340,
    alt: "A Codex 5-hour window: 77% left on a bar with a marker for the time left, the reset time, and the source, the last Codex turn two minutes ago.",
  },
  activity: {
    src: "/landing/app/activity.webp",
    width: 672,
    height: 680,
    alt: "A Claude Code session waiting for an answer: project, process id, age, estimated cost and the question it asked, with Show Terminal and Copy Session Id.",
  },
  previewTokens: {
    src: "/landing/app/preview-tokens.webp",
    width: 1440,
    height: 900,
    alt: "Design preview of the Tokens page: estimated cost for Claude Code and Codex over 30 days, a bar chart by day, cache reuse and an estimated cost table.",
  },
} as const satisfies Record<string, Shot>;

export type ShotKey = keyof typeof SHOTS;
