/**
 * The app screens the page shows. The real ones are crops of dark captures of the SwiftUI app
 * (`SPACEVIBE_REDESIGN=1 SPACEVIBE_SHOT_SCREEN=<page> scripts/dev-fixture.sh --shots <dir>`, 2x, the
 * `solid-dark` variants, captured 2026-11-22): the page without its sidebar for Clean, Skills and Rules, and
 * the inspector alone for a limit window and a session. Their
 * rows are the app's synthetic illustration data, never a real home. A page that is still in development
 * has no capture here: it gets one when a render in the app's current look exists.
 */
export interface Shot {
  readonly src: string;
  readonly width: number;
  readonly height: number;
  readonly alt: string;
  /**
   * On a phone a whole capture shrinks until its text cannot be read, so it is shown at about twice the
   * frame's width, and the frame scrolls sideways to the rest. This is how far it also starts to the left,
   * as a share of its own width, to skip what matters less (the sidebar). Leave it out for a capture that is
   * already narrow.
   */
  readonly phoneShift?: number;
}

export const SHOTS = {
  clean: {
    src: "/landing/app/clean.webp",
    width: 2112,
    height: 1400,
    phoneShift: 0,
    alt: "Clean: 780 MB can be cleaned. Seven skills, subagents and hooks that never ran or whose script is gone are ticked, Codex session logs older than 90 days are ticked, and Claude Code session logs are locked because one session uses them.",
  },
  skills: {
    src: "/landing/app/skills.webp",
    width: 2112,
    height: 1240,
    phoneShift: 0,
    alt: "Skills: 5 never ran. Each row has the CLIs that carry the skill, a bar and a session count, and when it last ran; the selected skill shows its files and a Remove button.",
  },
  rules: {
    src: "/landing/app/rules.webp",
    width: 2112,
    height: 1180,
    phoneShift: 0,
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
    alt: "A Claude Code session waiting for an answer: project, process id, age, estimated cost and the question it asked, with a note to answer in the terminal.",
  },
} as const satisfies Record<string, Shot>;

export type ShotKey = keyof typeof SHOTS;
