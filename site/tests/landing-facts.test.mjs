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
  assert.ok(sources.length >= 6, "the shot list was not found in shots.ts");
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
