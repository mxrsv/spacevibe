// The landing copy against the app's own facts. No network.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const path = (rel) => fileURLToPath(new URL(rel, import.meta.url));
const content = readFileSync(path("../components/landing/content.ts"), "utf8");
const bands = readFileSync(path("../components/landing/bands.tsx"), "utf8");

test("no copy makes the status line the source of a limit", () => {
  assert.doesNotMatch(content, /status-line snapshot/i);
});

// LR-T4 stopgap: LR-T7 rewrites this file for the redesign.
test("every band has a drawing and a line per CLI", () => {
  const start = content.indexOf("export const BANDS");
  const section = content.slice(start, content.indexOf("\nexport const ", start + 10));
  const ids = [...section.matchAll(/\n    id: "(\w+)",\n    label:/g)].map((m) => m[1]);
  assert.deepEqual(ids, ["skills", "subagents", "hooks", "rules"], "the four bands were not found in content.ts");
  const stages = bands.match(/const STAGES = \{([^}]*)\}/)?.[1] ?? "";
  ids.forEach((id, i) => {
    assert.match(stages, new RegExp(`\\b${id}:`), `band ${id} has no drawing in bands.tsx`);
    const block = section.slice(section.indexOf(`id: "${id}"`), i + 1 < ids.length ? section.indexOf(`id: "${ids[i + 1]}"`) : undefined);
    for (const cli of ["claude", "codex"]) {
      assert.match(block, new RegExp(`${cli}: \\{[^}]*reach: "(full|partial|readonly)",[^}]*verdict: "[^"]+",[^}]*detail: "[^"]+"`), `band ${id} has no line for ${cli}`);
    }
  });
});

test("the colours the page copies as literals follow the tokens", () => {
  const css = readFileSync(path("../app/globals.css"), "utf8");
  const layout = readFileSync(path("../app/layout.tsx"), "utf8");
  const bg = css.match(/--color-bg: (#[0-9a-f]{6});/)?.[1];
  assert.ok(bg, "--color-bg was not found in globals.css");
  assert.match(layout, new RegExp(`themeColor: "${bg}"`), "themeColor in layout.tsx must equal --color-bg");
  for (const file of ["../app/globals.css", "../components/landing/site-header.tsx"]) {
    assert.doesNotMatch(readFileSync(path(file), "utf8"), /rgb\(65 100 237|rgb\(13 15 18|rgb\(13_15_18/, `${file} copies an old token as a raw colour`);
  }
});
