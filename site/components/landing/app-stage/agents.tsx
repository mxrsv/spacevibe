/**
 * The agent logo tile of the renders (system.md, "Agent logo tile"): 20 x 20, one-colour mark, no brand colours. Marks are
 * Simple Icons paths (CC0) from the renders' `vendor/marks.json`; Codex has none, so it is a first-letter tile. The names
 * are in `title` and in the accessible label of the row, because the tile is a picture.
 */
const MARKS = {
  "Claude Code":
    "M21 10.5h3v3h-3v3h-1.5v3H18v-3h-1.5v3H15v-3H9v3H7.5v-3H6v3H4.5v-3H3v-3H0v-3h3v-6h18Zm-15 0h1.5v-3H6Zm10.5 0H18v-3h-1.5z",
  "Gemini CLI":
    "M11.04 19.32Q12 21.51 12 24q0-2.49.93-4.68.96-2.19 2.58-3.81t3.81-2.55Q21.51 12 24 12q-2.49 0-4.68-.93a12.3 12.3 0 0 1-3.81-2.58 12.3 12.3 0 0 1-2.58-3.81Q12 2.49 12 0q0 2.49-.96 4.68-.93 2.19-2.55 3.81a12.3 12.3 0 0 1-3.81 2.58Q2.49 12 0 12q2.49 0 4.68.96 2.19.93 3.81 2.55t2.55 3.81",
  Cursor:
    "M11.503.131 1.891 5.678a.84.84 0 0 0-.42.726v11.188c0 .3.162.575.42.724l9.609 5.55a1 1 0 0 0 .998 0l9.61-5.55a.84.84 0 0 0 .42-.724V6.404a.84.84 0 0 0-.42-.726L12.497.131a1.01 1.01 0 0 0-.996 0M2.657 6.338h18.55c.263 0 .43.287.297.515L12.23 22.918c-.062.107-.229.064-.229-.06V12.335a.59.59 0 0 0-.295-.51l-9.11-5.257c-.109-.063-.064-.23.061-.23",
  OpenCode: "M22 24H2V0h20zM17 4.8H7v14.4h10z",
} as const;

export type AgentName = "Claude Code" | "Codex" | "Gemini CLI" | "Cursor" | "OpenCode";

/** `on`: installed (or neutral). Off: the same mark dimmed. */
export function AgentTile({ name, on }: { readonly name: AgentName; readonly on: boolean }) {
  const path = name === "Codex" ? null : MARKS[name];
  return (
    <i className={`ag${on ? " on" : ""}`} title={`${name}${on ? ", installed" : ", not installed"}`}>
      {path ? (
        <svg viewBox="0 0 24 24" width="13" height="13" fill="currentColor" aria-hidden="true">
          <path d={path} />
        </svg>
      ) : (
        "C"
      )}
    </i>
  );
}

export const FIVE: readonly AgentName[] = ["Claude Code", "Codex", "Gemini CLI", "Cursor", "OpenCode"];

export function Strip({ agents, has }: { readonly agents: readonly AgentName[]; readonly has: readonly (0 | 1)[] }) {
  return (
    <span className="strip">
      {agents.map((name, i) => (
        <AgentTile key={name} name={name} on={has[i] === 1} />
      ))}
    </span>
  );
}
