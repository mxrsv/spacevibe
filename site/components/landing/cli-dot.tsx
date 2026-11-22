import type { CLI } from "./content";

/** Small coloured dot that names a CLI wherever the two are side by side. */
export function CliDot({ cli, className = "" }: { readonly cli: CLI; readonly className?: string }) {
  return (
    <span
      className={`inline-block size-2 shrink-0 rounded-full ${cli === "claude" ? "bg-claude" : "bg-codex"} ${className}`}
      aria-hidden="true"
    />
  );
}
