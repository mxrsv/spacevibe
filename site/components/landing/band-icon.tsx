import type { BandId } from "./content";

/** Skills, Subagents, Hooks and Rules (L39): the keys of `Resources/PageIcons.json` the page draws. */
export type IconKey = BandId;

/**
 * SpaceVibe's own page icons, style Bold (RD23), one per screen the page draws, shared by the band headers and the hero.
 * The shapes are the entries of `Resources/PageIcons.json` of the app, same key as the band id: drawn on a
 * 256 grid, each line stroked at 24 with round caps and joins, each dot `[cx, cy, r]` filled. The view box is the
 * live area (40 to 216) plus half a stroke, so the glyph fills the box it is sized to. Rules (the shield's two
 * points) reaches about 8 units past it, so the svg must not clip: `overflow-visible`.
 */
interface PageIconShape {
  readonly lines: readonly string[];
  readonly dots: readonly (readonly [number, number, number])[];
}

const STROKE = 24;
const VIEW_BOX = "28 28 200 200";

const PAGE_ICON: Record<IconKey, PageIconShape> = {
  subagents: {
    lines: ["M198.9 115.5A72 72 0 1 1 140.5 57.1"],
    dots: [
      [128, 128, 26],
      [178.9, 77.1, 20],
    ],
  },
  hooks: {
    lines: ["M152 66a22 22 0 1 0 44 0a22 22 0 1 0 -44 0", "M174 88v78a48 48 0 0 1-96 0v-28", "M58 158l20-20 20 20"],
    dots: [],
  },
  skills: {
    lines: [
      "M40 80a40 40 0 0 1 40-40h96a40 40 0 0 1 40 40v96a40 40 0 0 1-40 40H80a40 40 0 0 1-40-40Z",
      "M128 80c4 28 20 44 48 48c-28 4-44 20-48 48c-4-28-20-44-48-48c28-4 44-20 48-48Z",
    ],
    dots: [],
  },
  rules: {
    lines: ["M128 32l80 28v60c0 52-32 84-80 104c-48-20-80-52-80-104V60Z", "M96 108h64", "M96 144h36"],
    dots: [],
  },
};

interface BandIconProps {
  readonly band: IconKey;
  readonly size: number;
  readonly className?: string;
}

export function BandIcon({ band, size, className }: BandIconProps) {
  const { lines, dots } = PAGE_ICON[band];
  return (
    <svg width={size} height={size} viewBox={VIEW_BOX} fill="none" aria-hidden="true" className={`overflow-visible ${className ?? ""}`}>
      <g stroke="currentColor" strokeWidth={STROKE} strokeLinecap="round" strokeLinejoin="round">
        {lines.map((d) => (
          <path key={d} d={d} />
        ))}
      </g>
      {dots.map(([cx, cy, r]) => (
        <circle key={`${cx}-${cy}`} cx={cx} cy={cy} r={r} fill="currentColor" />
      ))}
    </svg>
  );
}
