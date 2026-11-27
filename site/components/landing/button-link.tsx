import { ArrowRight, ArrowUpRight } from "lucide-react";
import type { ReactNode } from "react";

type Variant = "solid" | "ghost" | "light";

interface ButtonLinkProps {
  readonly href: string;
  readonly variant?: Variant;
  readonly external?: boolean;
  readonly size?: "sm" | "md";
  /** Below `sm:` a tighter padding and no arrow, for a row that must hold several buttons in a 280 px frame. */
  readonly phoneCompact?: boolean;
  readonly className?: string;
  readonly children: ReactNode;
}

const BASE =
  "group inline-flex items-center gap-2 rounded-ctl whitespace-nowrap font-medium leading-none tracking-[-0.005em] no-underline transition-[background-color,border-color,color] duration-150 ease-out";

const VARIANT: Record<Variant, string> = {
  solid: "bg-accent text-on-accent border border-transparent hover:bg-accent-hover active:bg-accent-pressed",
  light: "bg-ink-0 text-bg border border-transparent hover:bg-ink-1 active:bg-ink-1",
  ghost: "bg-transparent text-ink-1 border border-edge-strong hover:border-edge-hover hover:text-ink-0 active:bg-s2",
};

const SIZE = {
  sm: "h-9 px-4 text-sec",
  md: "h-11 px-5 text-body",
} as const;

/** One link styled as a button. The arrow slides 2px on hover; nothing else moves. */
export function ButtonLink({ href, variant = "solid", external = false, size = "sm", phoneCompact = false, className = "", children }: ButtonLinkProps) {
  const Arrow = external ? ArrowUpRight : ArrowRight;
  return (
    <a
      href={href}
      className={`${BASE} ${VARIANT[variant]} ${SIZE[size]} ${phoneCompact ? "max-sm:px-3" : ""} ${className}`}
      {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
    >
      <span>{children}</span>
      {external ? <span className="sr-only">(opens in a new tab)</span> : null}
      <Arrow
        size={14}
        aria-hidden="true"
        className={`transition-transform duration-150 ease-out group-hover:translate-x-0.5 ${phoneCompact ? "max-sm:hidden" : ""}`}
      />
    </a>
  );
}
