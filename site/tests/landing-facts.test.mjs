// The landing page against its spec (LP-A11) and the app's own facts. No network, no build: it reads the sources.
import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";

const path = (rel) => fileURLToPath(new URL(rel, import.meta.url));
const read = (rel) => readFileSync(path(rel), "utf8");
const content = read("../components/landing/content.ts");
const bands = read("../components/landing/bands.tsx");
// content.ts and the stage data are plain TypeScript (no JSX), so Node reads them as they are.
const { BANDS, FOOTER } = await import("../components/landing/content.ts");
const { STAGE_FACTS } = await import("../components/landing/app-stage/data.ts");

/** Every .tsx and .css file the page is made of, except the token file itself (globals.css is where raw colours belong). */
function sources(dir = path("../components/")) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = `${dir}${entry.name}`;
    if (entry.isDirectory()) return sources(`${full}/`);
    return /\.(tsx|css)$/.test(entry.name) ? [full] : [];
  });
}
// layout.tsx is left out: its `themeColor` is the one literal, and the next test keeps it equal to `--color-bg`.
const files = [...sources(), path("../app/page.tsx"), path("../app/not-found.tsx")];
const stripComments = (text) => text.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:"'`])\/\/.*$/gm, "$1");

/** The text between `export const NAME` and the next `export`, so a test reads one block of content.ts. */
function block(name) {
  const start = content.indexOf(`export const ${name}`);
  assert.notEqual(start, -1, `export const ${name} was not found in content.ts`);
  const end = content.indexOf("\nexport ", start + 10);
  return content.slice(start, end === -1 ? undefined : end);
}

test("every band has a drawing and a ledger line per CLI", () => {
  const section = block("BANDS");
  const ids = [...section.matchAll(/\n    id: "(\w+)",\n    label:/g)].map((m) => m[1]);
  assert.deepEqual(ids, ["skills", "subagents", "hooks", "rules"], "the four bands (L39) were not found in content.ts");
  const stages = bands.match(/const STAGES = \{([^}]*)\}/)?.[1] ?? "";
  ids.forEach((id, i) => {
    assert.match(stages, new RegExp(`\\b${id}:`), `band ${id} has no drawing in bands.tsx`);
    const part = section.slice(section.indexOf(`id: "${id}"`), i + 1 < ids.length ? section.indexOf(`id: "${ids[i + 1]}"`) : undefined);
    for (const cli of ["claude", "codex"]) {
      assert.match(part, new RegExp(`${cli}: \\{[^}]*reach: "(full|partial|readonly)",[^}]*verdict: "[^"]+",[^}]*detail: "[^"]+"`), `band ${id} has no line for ${cli}`);
    }
    assert.match(part, /stageLabel: "Design preview of/, `band ${id}'s drawing has no accessible description`);
  });
});

test("the page says each drawing is a design preview", () => {
  assert.match(content, /PREVIEW_CAPTION = "Design preview · not in the current download"/);
  assert.match(bands, /PREVIEW_CAPTION/);
});

test("no copy makes the status line the source of a limit", () => {
  assert.doesNotMatch(content, /status-line snapshot/i);
});

test("every colour is a token: no raw colour in a className, a style or a component stylesheet", () => {
  const bad = [];
  for (const file of files) {
    const text = stripComments(readFileSync(file, "utf8"));
    for (const [pattern, what] of [
      [/#[0-9a-fA-F]{3,8}\b(?![\w-])/g, "hex colour"],
      [/\b(?:rgba?|hsla?|oklch|oklab|lab|lch)\(/g, "colour function"],
      [/\b(?:bg|text|border|fill|stroke|from|via|to|ring|shadow|outline|divide|decoration|accent|caret)-(?:white|black|\[#|\[rgb)/g, "colour utility"],
      [/\b(?:bg|text|border|ring|fill|stroke|from|via|to|outline|divide|shadow|decoration|accent|caret)-(?:slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-\d{2,3}\b/g, "Tailwind default palette class"],
    ]) {
      for (const m of text.matchAll(pattern)) bad.push(`${file.split("/site/")[1]}: ${what} ${m[0]}`);
    }
  }
  assert.deepEqual(bad, [], "use a token from app/globals.css instead");
});

test("the colours the page copies as literals follow the tokens", () => {
  const css = read("../app/globals.css");
  const layout = read("../app/layout.tsx");
  const bg = css.match(/--color-bg: (#[0-9a-f]{6});/)?.[1];
  assert.ok(bg, "--color-bg was not found in globals.css");
  assert.match(layout, new RegExp(`themeColor: "${bg}"`), "themeColor in layout.tsx must equal --color-bg");
  assert.match(css, /--color-accent: #7256f6;/, "the accent is the app's violet (L35)");
  assert.doesNotMatch(css + layout, /#0b6fe4/i, "the old blue accent is gone");
});

test("no figure shows twice", () => {
  const readings = [...block("BANDS").matchAll(/reading: \{ figure: "([^"]+)", unit: "[^"]*", label: "([^"]+)"/g)].map((m) => `${m[1]} ${m[2]}`);
  const figures = [...block("FIGURES").matchAll(/\{ value: (\d+), label: "([^"]+)"/g)].map((m) => `${m[1]} ${m[2]}`);
  assert.equal(readings.length, 4, "each band has one reading");
  assert.equal(figures.length, 3, "the figures band has three figures");
  const all = [...readings, ...figures];
  assert.equal(new Set(all).size, all.length, `a figure repeats: ${all.join("; ")}`);
  const labels = all.map((s) => s.replace(/^\d+ /, ""));
  assert.equal(new Set(labels).size, labels.length, "a figure label repeats");
});

test("the download card holds the three facts, and the ending links to the releases", () => {
  const note = block("HERO").match(/note: "([^"]+)"/)?.[1] ?? "";
  for (const fact of ["Free", "macOS 15 or later", "Apple silicon"]) assert.ok(note.includes(fact), `the download note lacks "${fact}"`);
  assert.match(block("ENDING"), /note: HERO\.cta\.note/, "the ending's download card must show the hero's note");
  assert.match(content, /export const DOWNLOAD_URL = `\$\{GITHUB_URL\}\/releases\/latest`/);
  assert.match(content, /export const WATCH_URL = `\$\{GITHUB_URL\}\/releases`/);
  assert.match(block("ANNOUNCE"), /href: WATCH_URL/, "the announcement bar links to the releases");
  assert.match(block("ENDING"), /cta: \{ href: WATCH_URL/, "the Watch card links to the releases");
  assert.match(block("ENDING"), /cta: \{ href: DOWNLOAD_URL/, "the download card links to the latest release");
});

test("the page names no licence and holds no form", () => {
  assert.doesNotMatch(content, /licen/i);
  for (const file of files.filter((f) => f.endsWith(".tsx"))) {
    assert.doesNotMatch(stripComments(readFileSync(file, "utf8")), /<form\b|<input\b/, `${file.split("/site/")[1]} holds a form control (L9)`);
  }
});

test("nothing of the old planet scene is left", () => {
  for (const gone of ["../app/scene.css", "../components/landing/scene.tsx", "../components/landing/starfield.tsx", "../public/landing/star-tile-far.svg"]) {
    assert.equal(existsSync(path(gone)), false, `${gone} should be deleted (LP-R9)`);
  }
});

test("the open-graph image is the one the content says", () => {
  const { src, width, height } = { src: content.match(/src: "(\/og\.jpg)"/)?.[1], width: content.match(/width: (\d+)/)?.[1], height: content.match(/height: (\d+)/)?.[1] };
  assert.equal(src, "/og.jpg");
  assert.deepEqual([width, height], ["1200", "630"]);
  assert.ok(existsSync(path(`../public${src}`)));
  const jpeg = readFileSync(path("../public/og.jpg"));
  const sof = jpeg.indexOf(Buffer.from([0xff, 0xc0])) !== -1 ? jpeg.indexOf(Buffer.from([0xff, 0xc0])) : jpeg.indexOf(Buffer.from([0xff, 0xc2]));
  assert.ok(sof > 0, "og.jpg is not a JPEG");
  assert.deepEqual([jpeg.readUInt16BE(sof + 7), jpeg.readUInt16BE(sof + 5)], [1200, 630], "og.jpg must be 1200 x 630");
});

test("every figure and drawing description says what the drawn rows hold", () => {
  const band = Object.fromEntries(BANDS.map((b) => [b.id, b]));
  const f = STAGE_FACTS;
  const words = { 1: "one", 2: "two", 3: "three", 4: "four", 5: "five", 6: "six", 7: "seven", 8: "eight", 9: "nine" };
  const says = (id, phrase) => assert.ok(band[id].stageLabel.includes(phrase), `${id}: the description should say "${phrase}", it says "${band[id].stageLabel}"`);
  // the band's one figure is counted from the rows, not typed
  assert.equal(band.skills.reading.figure, String(f.skillsNeverRan));
  assert.equal(band.subagents.reading.figure, String(f.subagentsNeverRan));
  assert.equal(band.hooks.reading.figure, String(f.hooks));
  assert.equal(band.rules.reading.figure, String(f.ruleFiles));
  // the drawing descriptions
  says("skills", `${words[f.skillsIdleShown]} skills with no sessions in 24 days, ${words[f.skillsIdleAtZero]} at 0 and ${words[f.skillsIdleUnknown]} not known`);
  says("skills", `${words[f.skillsIdleMarked]} are marked with a lock or a clock`);
  says("subagents", `${words[f.subagents]} subagents most used first`);
  says("subagents", `the last ${words[f.subagentsNeverRan]}`);
  says("hooks", `${words[f.hooks]} hooks grouped by the event`);
  says("hooks", `for ${words[f.hooksWithErrors]}, an error count`);
  says("hooks", `${words[f.hooksUnmeasurable]} hook of Codex reads unmeasurable`);
  says("rules", `${words[f.ruleFiles]} rule files`);
  assert.ok(f.ruleFilesWithWideAllow > 0 && band.rules.stageLabel.includes("open-lock icon"), "Rules: the wide-allow mark is an open-lock icon");
  // the hero's window shows the top rows
  assert.ok(read("../components/landing/hero.tsx").includes(`${words[f.skillsHeroRows]} skills most used first`), "the hero's drawing description names the rows it shows");
});

test("the footer disclaimer names every agent the drawings show", () => {
  for (const name of ["Claude\u00A0Code", "Codex", "Gemini\u00A0CLI", "Cursor", "OpenCode"]) assert.ok(FOOTER.disclaimer.includes(name), `the disclaimer lacks ${name}`);
});
