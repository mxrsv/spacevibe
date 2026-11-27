import type { ReactNode } from "react";

interface StageWindowProps {
  /** One sentence for a reader who does not see the drawing; the markup inside is a picture of the app. */
  readonly label: string;
  readonly children: ReactNode;
  /** The title bar with the three macOS window buttons (L25). */
  readonly lights?: boolean;
  readonly caption?: string;
  readonly className?: string;
}

/**
 * A drawn app stage in a window of the landing: a dashed frame (L7: a render of the unshipped look), an optional title bar,
 * the stage at 1x. The stage is 596 px wide and never scales: where the page is narrower, the window pans sideways (focusable,
 * so the keyboard can pan it), so no text is ever drawn smaller than the render draws it.
 */
export function StageWindow({ label, children, lights = false, caption, className = "" }: StageWindowProps) {
  return (
    <figure className={`mx-auto grid w-fit min-w-0 max-w-full grid-cols-[minmax(0,1fr)] gap-3 ${className}`}>
      <div className="relative max-w-full">
        <div className="relative overflow-hidden rounded-panel border border-dashed border-edge-hover bg-stage-bg shadow-panel">
          {lights ? (
            <div aria-hidden="true" className="flex h-9 items-center gap-2 border-b border-edge px-4">
              <span className="size-3 rounded-full bg-light-close" />
              <span className="size-3 rounded-full bg-light-min" />
              <span className="size-3 rounded-full bg-light-zoom" />
            </div>
          ) : null}
          {/* One name, on the picture: the drawing is a single image for a screen reader. The scroller is a tab stop so a
              keyboard can pan it where the page is narrower than the stage; its focus ring is drawn inside the frame,
              because the frame clips anything outside it. */}
          <div className="overflow-x-auto overflow-y-hidden rounded-b-[13px] focus-visible:outline-offset-[-2px]" tabIndex={0} role="img" aria-label={label}>
            <div className="w-[596px]">{children}</div>
          </div>
        </div>
        <span aria-hidden="true" className="pointer-events-none absolute inset-y-px right-px w-10 rounded-r-panel bg-linear-to-l from-stage-bg to-transparent md:hidden" />
      </div>
      {caption ? <figcaption className="text-tiny text-ink-2">{caption}</figcaption> : null}
    </figure>
  );
}
