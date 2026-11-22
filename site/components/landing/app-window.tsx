import Image from "next/image";
import type { CSSProperties } from "react";

import { SHOTS, type Shot, type ShotKey } from "./shots";

/** macOS window buttons at the app's own place, as fractions of the window width (a 1440 pt window). */
const LIGHTS = [
  "left-[1.67cqw] bg-light-close",
  "left-[3.06cqw] bg-light-min",
  "left-[4.44cqw] bg-light-zoom",
] as const;

interface AppWindowProps {
  readonly shot: ShotKey;
  /** Draw the window buttons the headless capture leaves out. Only for a whole window; hidden where a phone shows the capture cut. */
  readonly lights?: boolean;
  readonly caption?: string;
  readonly priority?: boolean;
  /** The section cuts the window's bottom edge: no bottom corners and no bottom border. */
  readonly bleed?: boolean;
  readonly className?: string;
  /** Only for a value that depends on data, such as a max width derived from the image's shape. */
  readonly style?: CSSProperties;
}

/**
 * One app screen, or one region of it, in a frame. The frame is only an edge and a shadow: the pixels
 * are the app's. The caption sits under the frame so it never covers the screen.
 */
export function AppWindow({ shot, lights = false, caption, priority = false, bleed = false, className = "", style }: AppWindowProps) {
  const { src, width, height, alt } = SHOTS[shot];
  const phoneShift: number | undefined = (SHOTS[shot] as Shot).phoneShift;
  return (
    <figure className={`grid gap-3 ${className}`} style={style}>
      <div
        className={`@container relative overflow-hidden rounded-panel border border-edge-strong bg-s2 shadow-panel ${bleed ? "rounded-b-none border-b-0" : ""}`}
      >
        <Image
          src={src}
          alt={alt}
          width={width}
          height={height}
          priority={priority}
          sizes="(min-width: 1280px) 1120px, 100vw"
          className={`block h-auto w-full ${phoneShift === undefined ? "" : "max-md:w-[190%] max-md:max-w-none max-md:-translate-x-(--phone-shift)"}`}
          style={phoneShift === undefined ? undefined : ({ "--phone-shift": `${phoneShift * 100}%` } as CSSProperties)}
        />
        {lights
          ? LIGHTS.map((place) => (
              <span key={place} aria-hidden="true" className={`absolute top-[1.04cqw] size-[0.84cqw] rounded-full ${place} ${phoneShift === undefined ? "" : "max-md:hidden"}`} />
            ))
          : null}
      </div>
      {caption ? <figcaption className="text-tiny text-ink-2">{caption}</figcaption> : null}
    </figure>
  );
}
