// The landing copy against the app's own facts. No network.
import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const path = (rel) => fileURLToPath(new URL(rel, import.meta.url));
const content = readFileSync(path("../components/landing/content.ts"), "utf8");
const shots = readFileSync(path("../components/landing/shots.ts"), "utf8");

test("Limits copy does not make the status line the source", () => {
  assert.doesNotMatch(content, /status-line snapshot/i);
  assert.match(content, /usage cache/);
});

test("every screen the page names is a file in public/", () => {
  const sources = [...shots.matchAll(/src: "([^"]+)"/g)].map((m) => m[1]);
  assert.ok(sources.length >= 5, "the shot list was not found in shots.ts");
  for (const src of sources) assert.ok(existsSync(path(`../public${src}`)), `${src} is missing from public/`);
});

test("every band shows a screen that exists, and has a line per CLI", () => {
  const keys = new Set([...shots.matchAll(/^  (\w+): \{$/gm)].map((m) => m[1]));
  const bands = [...content.matchAll(/id: "(\w+)",\n    label:[\s\S]*?shot: "(\w+)"/g)];
  assert.ok(bands.length >= 5, "the bands were not found in content.ts");
  const diffs = content.slice(content.indexOf("export const DIFFS"), content.indexOf("export const UPCOMING"));
  for (const [, id, shot] of bands) {
    assert.ok(keys.has(shot), `band ${id} names the unknown shot ${shot}`);
    const block = diffs.match(new RegExp(`\\n  ${id}: \\{\\n([\\s\\S]*?)\\n  \\},`))?.[1] ?? "";
    for (const cli of ["claude", "codex"]) {
      assert.match(block, new RegExp(`${cli}: \\{\\n      reach: "(full|partial|readonly)",\\n      verdict: "[^"]+",\\n      detail:\\s+"[^"]+",`), `band ${id} has no line for ${cli}`);
    }
  }
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
