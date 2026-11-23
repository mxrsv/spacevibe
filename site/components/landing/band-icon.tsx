import type { BandId } from "./content";

/**
 * SpaceVibe's own page icons, style Bold (RD23), one per screen, shared by the band headers and the hero.
 * The shapes are the five entries of `Resources/PageIcons.json` of the app, same key as the band id: drawn on a
 * 256 grid, each line stroked at 24 with round caps and joins, each dot `[cx, cy, r]` filled. The view box is the
 * live area (40 to 216) plus half a stroke, so the glyph fills the box it is sized to.
 */
interface PageIconShape {
  readonly lines: readonly string[];
  readonly dots: readonly (readonly [number, number, number])[];
}

const STROKE = 24;
const VIEW_BOX = "28 28 200 200";

const PAGE_ICON: Record<BandId, PageIconShape> = {
  clean: {
    lines: ["M212 44l-68 68", "M124 92l40 40-48 80-72-72Z", "M84 116l56 56", "M64 40v40", "M44 60h40"],
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
  limits: {
    lines: ["M68.6 187.4A84 84 0 1 1 187.4 187.4", "M128 128l42-42"],
    dots: [[128, 128, 18]],
  },
  activity: {
    lines: ["M168 88a56 56 0 0 1 0 80", "M196 60a96 96 0 0 1 0 136", "M88 88a56 56 0 0 0 0 80", "M60 60a96 96 0 0 0 0 136"],
    dots: [[128, 128, 22]],
  },
};

interface BandIconProps {
  readonly band: BandId;
  readonly size: number;
  readonly className?: string;
}

export function BandIcon({ band, size, className }: BandIconProps) {
  const { lines, dots } = PAGE_ICON[band];
  return (
    <svg width={size} height={size} viewBox={VIEW_BOX} fill="none" aria-hidden="true" className={className}>
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
