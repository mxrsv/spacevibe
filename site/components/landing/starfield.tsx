import type { CSSProperties } from "react";

/**
 * Layer 1.5 of the scene: three seamless star tiles of three sizes and opacities,
 * so depth comes from scale, not blur. Zero JS, nothing moves: three repeating
 * backgrounds.
 *
 * The star system and the named glints exist only in the hero; the download band
 * repeats the scene at lower intensity and keeps just the three layers.
 */
const GLINTS = [
  { x: "46%", y: "12%", size: 3 },
  { x: "73%", y: "15%", size: 2.2 },
  { x: "52%", y: "46%", size: 2.6 },
  { x: "39%", y: "72%", size: 2 },
] as const;

export type SceneVariant = "hero" | "download";

interface GlintStyle extends CSSProperties {
  readonly "--glint-x": string;
  readonly "--glint-y": string;
  readonly "--glint-size": string;
}

function glintStyle(glint: (typeof GLINTS)[number]): GlintStyle {
  return {
    "--glint-x": glint.x,
    "--glint-y": glint.y,
    "--glint-size": `${glint.size}px`,
  };
}

export function Starfield({ variant }: { readonly variant: SceneVariant }) {
  return (
    <div className="scene__stars">
      <span className="scene__layer scene__layer--far" />
      <span className="scene__layer scene__layer--mid" />
      <span className="scene__layer scene__layer--near" />

      {variant === "hero" ? (
        <>
          <span className="scene__system">
            <span className="scene__system-wash" />
            <span className="scene__orbit">
              <span className="scene__orbit-body" />
            </span>
            <span className="scene__glint scene__glint--anchor" />
          </span>

          {GLINTS.map((glint) => (
            <span className="scene__glint" key={`${glint.x}-${glint.y}`} style={glintStyle(glint)} />
          ))}
        </>
      ) : null}
    </div>
  );
}
