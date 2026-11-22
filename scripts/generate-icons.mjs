#!/usr/bin/env node
// Writes the app's icons as SwiftUI path code into Sources/SpaceVibe/Components, from two icon packages in their Iconify JSON form
// and SpaceVibe's own page icons in Resources/PageIcons.json. No SVG is shipped or parsed at run time (spec
// docs/specs/2026-11-03-spacevibe-design-language.md, v3 "Icons"; v5 spec V5-R9, V5-R10, V5-R12; redesign spec RD23, RD37, RD38).
//
//   The v5 frame (kept as it is until the cut-over RB-X1 deletes what no screen uses):
//   CategoryIconData.swift  MingCute Line (MingCute Design, Apache-2.0): the category glyphs
//   ContentIconData.swift   Phosphor Duotone (Phosphor Icons, MIT): the sidebar, content and Settings glyphs
//   StateIconData.swift     Phosphor Bold (Phosphor Icons, MIT): the session state glyphs of the glance widget, also drawn by
//                           the new frame
//   The new frame (redesign, behind SPACEVIBE_REDESIGN=1):
//   PageIconData.swift      SpaceVibe's own Bold set (Resources/PageIcons.json): the 8 page icons (RD23)
//   InterfaceIconData.swift Phosphor Bold: the content glyphs (RD37)
//   SeverityIconData.swift  Phosphor Fill: the state glyphs, one per severity (RD37)
//   FrameIcon.swift         every icon the new frame draws, by the name the reference mock gives it, and the glyph it takes
//
//   cd <scratch folder outside the repo; never commit it>
//   npm pack @iconify-json/mingcute@1.2.10 @iconify-json/ph@1.2.2
//   for f in *.tgz; do mkdir "${f%.tgz}" && tar xzf "$f" -C "${f%.tgz}"; done
//   node scripts/generate-icons.mjs <mingcute>/package/icons.json <ph>/package/icons.json
//
// Two arguments, one per package: the Phosphor sets read the same icons.json. Each glyph becomes one or two filled layers in its
// 24 x 24 box (Phosphor and the own set are scaled down from their 256 grid): the solid layer and, for the duotone sets, the
// lighter one. The own set adds stroked lines (round caps and joins, drawn by SpaceVibeIcon as the mock's SVG strokes them);
// its dots are the solid layer. All take one colour in the app. Every path is reduced to absolute move, line, cubic and close:
// H and V become lines, Q, T and S become cubics, and arcs are split into cubics of at most 90 degrees. Numbers are rounded to
// 3 decimals, glyphs are sorted by name, so a rerun on the same input writes the same files. Each file's header names the
// package version or the file it was made from, and the licence notices live in Credits.swift (V5-R15).
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const OUT_DIR = join(REPO, 'Sources/SpaceVibe/Components');
const PAGE_ICONS = 'Resources/PageIcons.json';

// MARK: SVG body

/** The filled elements of an icon body, each with its own opacity and fill rule. Refuses anything it does not draw. */
export function elements(body) {
  const out = [];
  const stack = [{ opacity: 1, evenOdd: false }];
  const tag = /<(\/?)([a-zA-Z]+)((?:\s+[a-zA-Z:-]+="[^"]*")*)\s*(\/?)>/g;
  let index = 0;
  for (let match = tag.exec(body); match; match = tag.exec(body)) {
    if (body.slice(index, match.index).trim()) throw new Error(`text between tags at ${index}`);
    index = tag.lastIndex;
    const [, closing, name, rawAttrs, selfClosing] = match;
    if (closing) {
      if (name !== 'g' || stack.length === 1) throw new Error(`unexpected </${name}>`);
      stack.pop();
      continue;
    }
    const attrs = Object.fromEntries([...rawAttrs.matchAll(/([a-zA-Z:-]+)="([^"]*)"/g)].map((m) => [m[1], m[2]]));
    for (const key of Object.keys(attrs)) {
      if (!['d', 'fill', 'opacity', 'fill-rule', 'clip-rule', 'cx', 'cy', 'r', 'rx', 'ry', 'x', 'y', 'width', 'height'].includes(key)) {
        throw new Error(`attribute ${key} on <${name}> is not drawn`);
      }
    }
    if (attrs.fill && attrs.fill !== 'currentColor') throw new Error(`fill ${attrs.fill}`);
    const parent = stack[stack.length - 1];
    const state = {
      opacity: parent.opacity * (attrs.opacity === undefined ? 1 : Number(attrs.opacity)),
      evenOdd: attrs['fill-rule'] === undefined ? parent.evenOdd : attrs['fill-rule'] === 'evenodd',
    };
    if (name === 'g') {
      if (!selfClosing) stack.push(state);
      continue;
    }
    if (!selfClosing) throw new Error(`<${name}> with children`);
    out.push({ ...state, commands: shapeCommands(name, attrs) });
  }
  if (body.slice(index).trim() || stack.length !== 1) throw new Error('unbalanced body');
  return out;
}

function shapeCommands(name, a) {
  const n = (key, fallback) => (a[key] === undefined ? fallback : Number(a[key]));
  switch (name) {
    case 'path':
      return pathCommands(a.d);
    case 'circle':
      return ellipseCommands(n('cx', 0), n('cy', 0), n('r'), n('r'));
    case 'ellipse':
      return ellipseCommands(n('cx', 0), n('cy', 0), n('rx'), n('ry'));
    case 'rect': {
      const [x, y, w, h] = [n('x', 0), n('y', 0), n('width'), n('height')];
      const rx = Math.min(n('rx', n('ry', 0)), w / 2);
      const ry = Math.min(n('ry', n('rx', 0)), h / 2);
      if (!rx || !ry) return [['M', x, y], ['L', x + w, y], ['L', x + w, y + h], ['L', x, y + h], ['Z']];
      return pathCommands(`M${x + rx} ${y}H${x + w - rx}A${rx} ${ry} 0 0 1 ${x + w} ${y + ry}V${y + h - ry}A${rx} ${ry} 0 0 1 ${x + w - rx} ${y + h}H${x + rx}A${rx} ${ry} 0 0 1 ${x} ${y + h - ry}V${y + ry}A${rx} ${ry} 0 0 1 ${x + rx} ${y}Z`);
    }
    default:
      throw new Error(`<${name}> is not drawn`);
  }
}

function ellipseCommands(cx, cy, rx, ry) {
  return pathCommands(`M${cx - rx} ${cy}A${rx} ${ry} 0 1 0 ${cx + rx} ${cy}A${rx} ${ry} 0 1 0 ${cx - rx} ${cy}Z`);
}

// MARK: Path data

/** Tokens of path data: command letters and numbers, with packed forms ("1.5.5", "1-2", arc flags "01") split. */
function tokens(d) {
  const out = [];
  const re = /([MmLlHhVvCcSsQqTtAaZz])|([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)|([\s,]+)/y;
  let at = 0;
  while (at < d.length) {
    re.lastIndex = at;
    const match = re.exec(d);
    if (!match) throw new Error(`cannot read path data at ${at}: ${d.slice(at, at + 12)}`);
    if (match[1]) out.push(match[1]);
    else if (match[2]) out.push(match[2]);
    at = re.lastIndex;
  }
  return out;
}

const ARITY = { M: 2, L: 2, H: 1, V: 1, C: 6, S: 4, Q: 4, T: 2, A: 7, Z: 0 };

/** Absolute M, L, C and Z only. */
export function pathCommands(d) {
  const list = tokens(d);
  const out = [];
  let i = 0;
  let command = null;
  let x = 0, y = 0, startX = 0, startY = 0;
  let lastCubic = null, lastQuad = null;

  const number = () => {
    const value = list[i++];
    if (value === undefined || /[a-zA-Z]/.test(value)) throw new Error(`missing number for ${command}`);
    return Number(value);
  };
  // An arc flag may be packed against the next number: "a1 1 0 01.5 2" holds flags 0 and 1, then .5.
  const flag = () => {
    const value = list[i];
    if (value === '0' || value === '1') { i++; return Number(value); }
    if (/^[01]/.test(value)) { list[i] = value.slice(1); return Number(value[0]); }
    throw new Error(`bad arc flag ${value}`);
  };

  while (i < list.length) {
    if (/[a-zA-Z]/.test(list[i])) command = list[i++];
    else if (!command) throw new Error('path data starts with a number');
    const upper = command.toUpperCase();
    const relative = command !== upper;
    const ox = relative ? x : 0, oy = relative ? y : 0;
    let cubic = null, quad = null;
    switch (upper) {
      case 'M': {
        x = ox + number(); y = oy + number();
        startX = x; startY = y;
        out.push(['M', x, y]);
        command = relative ? 'l' : 'L'; // pairs after a move are lines
        break;
      }
      case 'L': x = ox + number(); y = oy + number(); out.push(['L', x, y]); break;
      case 'H': x = ox + number(); out.push(['L', x, y]); break;
      case 'V': y = oy + number(); out.push(['L', x, y]); break;
      case 'C': {
        const c = [ox + number(), oy + number(), ox + number(), oy + number(), ox + number(), oy + number()];
        out.push(['C', ...c]);
        cubic = [c[2], c[3]]; x = c[4]; y = c[5];
        break;
      }
      case 'S': {
        const [rx1, ry1] = lastCubic ? [2 * x - lastCubic[0], 2 * y - lastCubic[1]] : [x, y];
        const c = [ox + number(), oy + number(), ox + number(), oy + number()];
        out.push(['C', rx1, ry1, ...c]);
        cubic = [c[0], c[1]]; x = c[2]; y = c[3];
        break;
      }
      case 'Q': {
        const q = [ox + number(), oy + number(), ox + number(), oy + number()];
        out.push(quadToCubic(x, y, ...q));
        quad = [q[0], q[1]]; x = q[2]; y = q[3];
        break;
      }
      case 'T': {
        const [qx, qy] = lastQuad ? [2 * x - lastQuad[0], 2 * y - lastQuad[1]] : [x, y];
        const end = [ox + number(), oy + number()];
        out.push(quadToCubic(x, y, qx, qy, ...end));
        quad = [qx, qy]; [x, y] = end;
        break;
      }
      case 'A': {
        const rx = number(), ry = number(), rotation = number(), large = flag(), sweep = flag();
        const ex = ox + number(), ey = oy + number();
        out.push(...arcToCubics(x, y, rx, ry, rotation, large, sweep, ex, ey));
        x = ex; y = ey;
        break;
      }
      case 'Z':
        out.push(['Z']);
        x = startX; y = startY;
        break;
      default:
        throw new Error(`unknown command ${command}`);
    }
    lastCubic = cubic; lastQuad = quad;
    if (ARITY[upper] === 0 && i < list.length && !/[a-zA-Z]/.test(list[i])) throw new Error('number after Z');
  }
  return out;
}

function quadToCubic(x0, y0, qx, qy, x, y) {
  return ['C', x0 + (2 / 3) * (qx - x0), y0 + (2 / 3) * (qy - y0), x + (2 / 3) * (qx - x), y + (2 / 3) * (qy - y), x, y];
}

/** SVG arc (endpoint form) as cubics, per the SVG 1.1 implementation notes (F.6.5 and F.6.6). */
function arcToCubics(x1, y1, rxIn, ryIn, angle, large, sweep, x2, y2) {
  if (x1 === x2 && y1 === y2) return [];
  let rx = Math.abs(rxIn), ry = Math.abs(ryIn);
  if (!rx || !ry) return [['L', x2, y2]];
  const phi = (angle * Math.PI) / 180;
  const cos = Math.cos(phi), sin = Math.sin(phi);
  const dx = (x1 - x2) / 2, dy = (y1 - y2) / 2;
  const x1p = cos * dx + sin * dy, y1p = -sin * dx + cos * dy;
  const lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
  if (lambda > 1) { rx *= Math.sqrt(lambda); ry *= Math.sqrt(lambda); }
  const sign = large === sweep ? -1 : 1;
  const num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
  const den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
  const coef = sign * Math.sqrt(Math.max(0, num / den));
  const cxp = (coef * rx * y1p) / ry, cyp = (-coef * ry * x1p) / rx;
  const cx = cos * cxp - sin * cyp + (x1 + x2) / 2, cy = sin * cxp + cos * cyp + (y1 + y2) / 2;
  const vecAngle = (ux, uy, vx, vy) => Math.atan2(ux * vy - uy * vx, ux * vx + uy * vy);
  const theta1 = vecAngle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
  let delta = vecAngle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry);
  if (!sweep && delta > 0) delta -= 2 * Math.PI;
  if (sweep && delta < 0) delta += 2 * Math.PI;
  const segments = Math.max(1, Math.ceil(Math.abs(delta) / (Math.PI / 2) - 1e-9));
  const step = delta / segments;
  const k = (4 / 3) * Math.tan(step / 4);
  const point = (t) => [cx + rx * Math.cos(t) * cos - ry * Math.sin(t) * sin, cy + rx * Math.cos(t) * sin + ry * Math.sin(t) * cos];
  const tangent = (t) => [-rx * Math.sin(t) * cos - ry * Math.cos(t) * sin, -rx * Math.sin(t) * sin + ry * Math.cos(t) * cos];
  const out = [];
  for (let s = 0; s < segments; s++) {
    const t1 = theta1 + s * step, t2 = t1 + step;
    const [p1x, p1y] = point(t1), [p2x, p2y] = s === segments - 1 ? [x2, y2] : point(t2);
    const [d1x, d1y] = tangent(t1), [d2x, d2y] = tangent(t2);
    out.push(['C', p1x + k * d1x, p1y + k * d1y, p2x - k * d2x, p2y - k * d2y, p2x, p2y]);
  }
  return out;
}

// MARK: Sources

/** [Swift case, MingCute icon without the "-line" suffix, what it stands for]. The category glyphs (spec V5-R10, D32). */
const CATEGORY_GLYPHS = [
  ['hook', 'fish-symbol', 'a hook (Hooks category)'],
  ['skill', 'flash', 'a skill (Skills category)'],
  ['subagent', 'robot', 'a subagent (Subagents category)'],
];

/** [Swift case, Phosphor icon without the "-duotone" suffix, what it stands for]. The mock's sidebar and content glyphs
 *  (system/shared.js sprite), plus the stop, copy and bug glyphs Activity drew page-locally, and the Settings and Undo glyphs
 *  that were Solar until Settings moved to the v5 blocks (2026-11-16). */
const CONTENT_GLYPHS = [
  ['bug', 'bug', 'a failed command (Activity: Failed tab); the mock draws its own bug, this is Phosphor\'s nearest'],
  ['caretDown', 'caret-down', 'a disclosure or menu chevron'],
  ['caretLeft', 'caret-left', 'back (Settings)'],
  ['check', 'check', 'done, chosen'],
  ['clock', 'clock', 'a time, a stale or unknown reading, a newly added item'],
  ['close', 'x', 'dismiss, clear, remove a filter chip'],
  ['copy', 'copy', 'copy'],
  ['download', 'arrow-circle-down', 'an update is available (Settings)'],
  ['enter', 'arrow-elbow-down-left', 'Return, and refresh in the mock'],
  ['file', 'file', 'a file (Activity: Files tab, file rows)'],
  ['filter', 'funnel', 'the Filter button and its menu'],
  ['gauge', 'gauge', 'Limits (sidebar)'],
  ['info', 'info', 'a note (Settings: why this build cannot update)'],
  ['lock', 'lock', 'owned by a plugin, read-only; Codex read-only'],
  ['monitor', 'monitor', 'the System theme, which follows macOS (Settings)'],
  ['moon', 'moon', 'switch to the dark appearance'],
  ['open', 'arrow-square-out', 'open a file or a session'],
  ['palette', 'palette', 'the Appearance section (Settings)'],
  ['plus', 'plus', 'add'],
  ['pulse', 'pulse', 'Activity (sidebar, Running tab)'],
  ['rank', 'chart-bar', 'the Rank field of the filter menu; the mock draws three bars, this is Phosphor\'s nearest'],
  ['refresh', 'arrows-clockwise', 'the Update section, checking for an update (Settings)'],
  ['rule', 'list-checks', 'Rules category glyph (the mock\'s checklist; D32 names none)'],
  ['search', 'magnifying-glass', 'search (sidebar, fields)'],
  ['sliders', 'sliders-horizontal', 'Settings (sidebar), the View button'],
  ['stack', 'stack', 'Agents (sidebar), the CLI filter group'],
  ['stop', 'stop-circle', 'stop a session; the mock fills a rounded square, this is Phosphor\'s outlined one'],
  ['sun', 'sun', 'switch to the light appearance'],
  ['terminal', 'terminal-window', 'a CLI (the CLI field of the filter menu)'],
  ['trash', 'trash', 'remove'],
  ['undo', 'arrow-counter-clockwise', 'Undo (the palette\'s Undo entry)'],
  ['warning', 'warning', 'a warning (never ran, can\'t run)'],
];

/** [Swift case, Phosphor icon without the "-bold" suffix, what it stands for]. The session state glyphs of the glance widget
 *  (spec docs/specs/2026-11-19-session-glance-widget.md GW-R2, GW19, GW20): Orca's shapes from another library. */
const STATE_GLYPHS = [
  ['chatCircleDots', 'chat-circle-dots', 'a session waiting for the user; Phosphor has no bubble with a question mark, this is the mock\'s pick'],
  ['checkCircle', 'check-circle', 'a session that finished its turn (done)'],
  ['circleDashed', 'circle-dashed', 'a session whose state cannot be measured'],
  ['circleNotch', 'circle-notch', 'a working session (the ring the widget rotates)'],
];

const camel = (icon) => icon.replace(/-([a-z0-9])/g, (_, c) => c.toUpperCase());

/** [Phosphor icon without the "-bold" suffix, what it stands for in the reference mock]. The new frame's content glyphs (RD37):
 *  every Phosphor Bold name the mock draws (`src/icons.js`), except the four session state glyphs `StateGlyph` already holds.
 *  The Swift case is the icon name in camel case, so a mock name maps to one case without a table. */
const INTERFACE_GLYPHS = [
  ['arrow-clockwise', 'reload, try again, scan again; a scan in progress'],
  ['arrow-counter-clockwise', 'Undo'],
  ['arrow-up', 'an ascending sort column; the Push and deploy capability of a rule'],
  ['caret-down', 'a menu or sort chevron'],
  ['check', 'a ticked box, a chosen menu entry, an allowed rule'],
  ['clock', 'when an item was added'],
  ['clock-counter-clockwise', 'the Journal (Settings: Show Journal)'],
  ['copy', 'copy; a gap between CLIs (an Inbox finding)'],
  ['eye', 'the Read files capability of a rule'],
  ['file-text', 'the Edit files capability of a rule'],
  ['folder-open', 'Show in Finder'],
  ['folder-simple', 'the project picker (Rules)'],
  ['gear', 'Settings (sidebar foot)'],
  ['hard-drives', 'the Data section (Settings)'],
  ['info', 'the legend of the CLI logos'],
  ['link', 'an item a CLI reads through another folder (via)'],
  ['lock-key', 'the Secrets capability of a rule'],
  ['lock-simple', 'read-only: owned by a plugin or not writable'],
  ['magnifying-glass', 'search'],
  ['minus', 'a partly ticked box; nothing set'],
  ['plugs-connected', 'the Network capability of a rule'],
  ['plus', 'add (Add Rule)'],
  ['prohibit', 'a denied rule; a dead item to clean'],
  ['push-pin', 'the kept findings (Inbox)'],
  ['question', 'a page\'s help; an unmeasurable reading'],
  ['shield-warning', 'an open rule (an Inbox finding)'],
  ['sidebar-simple', 'hide the sidebar, show the inspector; the inspector\'s empty state'],
  ['sliders-horizontal', 'the General section (Settings)'],
  ['stop-circle', 'stop a session'],
  ['terminal-window', 'a CLI; Show Terminal; the Run commands capability; the CLIs section (Settings)'],
  ['trash', 'remove'],
  ['warning', 'a finding about what a CLI may do (Inbox)'],
  ['x', 'close, dismiss'],
].map(([icon, meaning]) => [camel(icon), icon, meaning]);

/** [Phosphor icon without the "-fill" suffix, what it stands for]. The new frame's state glyphs, one per severity (RD37, RD10:
 *  shown once per group). */
const SEVERITY_GLYPHS = [
  ['check-circle', 'the ok severity'],
  ['info', 'the note severity (information, no action)'],
  ['warning', 'the warning severity (needs attention)'],
  ['x-circle', 'the critical severity'],
].map(([icon, meaning]) => [camel(icon), icon, meaning]);

/** [Swift case and key in Resources/PageIcons.json, the Phosphor name the mock stores it under, what it stands for]. SpaceVibe's
 *  own page icons (RD23); the mock keeps the Phosphor names they replaced (its apply-icon-set.py), so they are the frame's names. */
const PAGE_GLYPHS = [
  ['activity', 'pulse', 'the Activity page; its empty state'],
  ['clean', 'broom', 'the Clean page'],
  ['hooks', 'anchor-simple', 'the Hooks page; a hook'],
  ['inbox', 'tray', 'the Inbox page'],
  ['limits', 'gauge', 'the Limits page; a Window finding (Inbox)'],
  ['rules', 'shield-check', 'the Rules page'],
  ['skills', 'book-open-text', 'the Skills page; a skill'],
  ['subagents', 'users-three', 'the Subagents page; a subagent'],
];

const PHOSPHOR_CREDIT = 'Phosphor Icons, Copyright (c) 2023 Phosphor Icons, MIT (https://github.com/phosphor-icons/core/blob/main/LICENSE).\n// Changed from the original: the SVG path data is rewritten as absolute move, line and cubic commands and scaled from the 256 grid to 24.';

/**
 * One icon set and the Swift enum it becomes. `sourceOpacity` is the opacity the set gives its light layer, `layerOpacity`
 * the one the app draws it at; `outline` is the stroke the mock adds to a glyph (system/shared.css `.ico`, in the set's own
 * box units), reproduced so the app's glyphs weigh the same.
 */
const SOURCES = [
  {
    key: 'mingcute', label: 'MingCute', prefix: 'mingcute', pkg: '@iconify-json/mingcute', license: 'Apache-2.0', box: 24, suffix: '-line',
    glyphs: CATEGORY_GLYPHS, out: 'CategoryIconData.swift', type: 'CategoryGlyph', light: false, sourceOpacity: 1, layerOpacity: 1, outline: 0,
    credit: 'MingCute by MingCute Design, Apache-2.0 (https://www.apache.org/licenses/LICENSE-2.0).\n// Changed from the original: the SVG path data is rewritten as absolute move, line and cubic commands (Apache-2.0 section 4(b)).',
    doc: ['The category glyphs (spec V5-R10), from MingCute Line: one layer in a 24 x 24 box, drawn in one colour.'],
  },
  {
    key: 'phosphor', label: 'Phosphor', prefix: 'ph', pkg: '@iconify-json/ph', license: 'MIT', box: 256, suffix: '-duotone',
    glyphs: CONTENT_GLYPHS, out: 'ContentIconData.swift', type: 'ContentGlyph', light: true, sourceOpacity: 0.2, layerOpacity: 0.25, outline: 8,
    credit: 'Phosphor Icons, Copyright (c) 2023 Phosphor Icons, MIT (https://github.com/phosphor-icons/core/blob/main/LICENSE).\n// Changed from the original: the SVG path data is rewritten as absolute move, line and cubic commands and scaled from the 256 grid to 24.',
    doc: ['The sidebar and content glyphs, from Phosphor Duotone, scaled from its 256 grid to a 24 x 24 box. Each has a solid layer and a lighter',
      'one (`SpaceVibeIcon` draws them in one colour, the lighter at `layerOpacity`, both with the kit\'s thin outline `outlineWidth`).'],
  },
  {
    key: 'phosphor-bold', label: 'Phosphor', prefix: 'ph', pkg: '@iconify-json/ph', license: 'MIT', box: 256, suffix: '-bold',
    glyphs: STATE_GLYPHS, out: 'StateIconData.swift', type: 'StateGlyph', light: false, sourceOpacity: 1, layerOpacity: 1, outline: 0,
    credit: 'Phosphor Icons, Copyright (c) 2023 Phosphor Icons, MIT (https://github.com/phosphor-icons/core/blob/main/LICENSE).\n// Changed from the original: the SVG path data is rewritten as absolute move, line and cubic commands and scaled from the 256 grid to 24.',
    doc: ['The session state glyphs of the glance widget (spec GW-R2), from Phosphor Bold, scaled from its 256 grid to a 24 x 24 box:',
      'one layer, drawn in one colour (the state\'s), with no outline; the Bold weight is already the mock\'s.'],
  },
  {
    key: 'phosphor-interface', label: 'Phosphor', prefix: 'ph', pkg: '@iconify-json/ph', license: 'MIT', box: 256, suffix: '-bold',
    glyphs: INTERFACE_GLYPHS, out: 'InterfaceIconData.swift', type: 'InterfaceGlyph', light: false, sourceOpacity: 1, layerOpacity: 1, outline: 0,
    credit: PHOSPHOR_CREDIT,
    doc: ['The content glyphs of the new frame (spec RD37), from Phosphor Bold, scaled from its 256 grid to a 24 x 24 box: one layer,',
      'drawn in one colour, with no outline. `FrameIcon` is how a view picks one.'],
  },
  {
    key: 'phosphor-severity', label: 'Phosphor', prefix: 'ph', pkg: '@iconify-json/ph', license: 'MIT', box: 256, suffix: '-fill',
    glyphs: SEVERITY_GLYPHS, out: 'SeverityIconData.swift', type: 'SeverityGlyph', light: false, sourceOpacity: 1, layerOpacity: 1, outline: 0,
    credit: PHOSPHOR_CREDIT,
    doc: ['The state glyphs of the new frame, one per severity (spec RD37), from Phosphor Fill, scaled from its 256 grid to a',
      '24 x 24 box: one layer, drawn in one colour (the severity\'s), with no outline. `FrameIcon` is how a view picks one.'],
  },
];

/** SpaceVibe's own set: not a package, a file of the repo with lines to stroke and dots to fill. */
const PAGE_SOURCE = {
  key: 'page', label: 'SpaceVibe', box: 256, suffix: '', glyphs: PAGE_GLYPHS, out: 'PageIconData.swift', type: 'PageGlyph',
  light: false, lines: true, layerOpacity: 1, outline: 0,
  credit: 'SpaceVibe\'s own drawing (owner pick 2026-11-20); no third-party licence.',
  doc: ['The page icons of the new frame (spec RD23), SpaceVibe\'s own Bold set, scaled from its 256 grid to a 24 x 24 box: lines',
    'stroked at `lineWidth` with round caps and joins, and dots in the solid layer, all in one colour (the page\'s identity tone',
    'or ink). `FrameIcon` is how a view picks one.'],
};

/** The packages the generator reads, in argument order. A set names its package; two sets may share one. */
const PACKAGES = [...new Set(SOURCES.map((source) => source.pkg))];

// MARK: Glyphs

const DRAW_BOX = 24;

/** Scales path commands from the set's own box to the 24 box the app draws in. */
function scaled(commands, k) {
  return commands.map(([op, ...args]) => [op, ...args.map((v) => v * k)]);
}

/** The layers of one icon: commands and fill rule each. Throws on anything the source's layers cannot hold. */
export function glyphLayers(set, name, source) {
  const icon = set.icons[name];
  if (!icon) throw new Error(`${name}: not in the set`);
  if ((icon.width ?? set.width ?? DRAW_BOX) !== source.box || (icon.height ?? set.height ?? DRAW_BOX) !== source.box) {
    throw new Error(`${name}: not a ${source.box} box`);
  }
  if (icon.left || icon.top || icon.rotate || icon.hFlip || icon.vFlip) throw new Error(`${name}: transformed`);
  const k = DRAW_BOX / source.box;
  const layers = { solid: { commands: [], evenOdd: null }, light: { commands: [], evenOdd: null } };
  for (const element of elements(icon.body)) {
    const key = Math.abs(element.opacity - 1) < 1e-9 ? 'solid' : source.light && Math.abs(element.opacity - source.sourceOpacity) < 1e-9 ? 'light' : null;
    if (!key) throw new Error(`${name}: opacity ${element.opacity}`);
    const layer = layers[key];
    layer.commands.push(...scaled(element.commands, k));
    // One fill rule per layer. A layer that mixes them takes even-odd, which matches as long as its non-zero parts do not
    // overlap anything; check the result against the source (the plan's verification renders both).
    layer.evenOdd = (layer.evenOdd ?? false) || element.evenOdd;
  }
  for (const [key, layer] of Object.entries(layers)) {
    if (key === 'light' && !source.light) {
      if (layer.commands.length) throw new Error(`${name}: a light layer in a single-layer set`);
    } else if (!layer.commands.length) throw new Error(`${name}: no ${key} layer`);
    layer.evenOdd = Boolean(layer.evenOdd);
  }
  return layers;
}

// MARK: Swift

const num = (v) => {
  const s = String(Number(v.toFixed(3)));
  return s === '-0' ? '0' : s;
};

function swiftLines(commands) {
  const lines = [];
  let line = [];
  for (const [op, ...args] of commands) {
    if (op === 'M' && line.length) { lines.push(line.join('; ')); line = []; }
    line.push(`p.${op.toLowerCase()}(${args.map(num).join(', ')})`);
  }
  if (line.length) lines.push(line.join('; '));
  return lines;
}

/** The glyphs of a package set, each with its layers. */
export function packageGlyphs(source, set) {
  return source.glyphs.map(([name, icon, meaning]) => ({ name, icon: icon + source.suffix, meaning, layers: glyphLayers(set, icon + source.suffix, source) }));
}

/** The glyphs of SpaceVibe's own set (Resources/PageIcons.json): dots in the solid layer, lines stroked at the file's width. */
export function pageGlyphs(source, file) {
  if (file.grid !== source.box) throw new Error(`${PAGE_ICONS}: not a ${source.box} grid`);
  if (!(file.stroke > 0)) throw new Error(`${PAGE_ICONS}: no stroke width`);
  const held = Object.keys(file.icons).sort().join(', ');
  const listed = source.glyphs.map(([name]) => name).sort().join(', ');
  if (held !== listed) throw new Error(`${PAGE_ICONS} holds ${held}; the generator lists ${listed}`);
  const k = DRAW_BOX / source.box;
  const glyphs = source.glyphs.map(([name, , meaning]) => {
    const { lines, dots } = file.icons[name];
    if (!lines?.length) throw new Error(`${name}: no lines`);
    for (const dot of dots) if (dot.length !== 3 || !(dot[2] > 0)) throw new Error(`${name}: a dot is [cx, cy, r]`);
    return {
      name, icon: name, meaning,
      layers: {
        solid: { commands: scaled(dots.flatMap(([cx, cy, r]) => ellipseCommands(cx, cy, r, r)), k), evenOdd: false },
        light: { commands: [], evenOdd: false },
        lines: { commands: scaled(lines.flatMap((d) => pathCommands(d)), k) },
      },
    };
  });
  return { glyphs, lineWidth: file.stroke * k };
}

/** One set as a Swift enum. `from` is what the header names (a package and its version, or a repo file); `lineWidth` is the
 *  stroke of a set with lines, in the 24 box. */
export function swiftSource(source, glyphs, from, lineWidth = 0) {
  const built = [...glyphs].sort((a, b) => a.name.localeCompare(b.name, 'en'));
  const cap = (s) => s[0].toUpperCase() + s.slice(1);
  const layerKeys = source.light ? ['solid', 'light'] : ['solid'];
  const drawn = (g, key) => g.layers[key].commands.length > 0;
  const out = [];
  out.push(`// Generated by scripts/generate-icons.mjs from ${from}. Do not edit; rerun the script.`);
  out.push(`// ${source.credit}`);
  out.push('import CoreGraphics');
  out.push('');
  for (const line of source.doc) out.push(`/// ${line}`);
  out.push(`enum ${source.type}: CaseIterable, GlyphSource {`);
  for (const g of built) out.push(`    /// ${cap(g.meaning)}.`, `    case ${g.name}`);
  out.push('', `    /// The ${source.label} icon the glyph is drawn from.`);
  out.push('    var iconName: String {', '        switch self {');
  for (const g of built) out.push(`        case .${g.name}: "${g.icon}"`);
  out.push('        }', '    }', '');
  out.push(`    var hasLightLayer: Bool { ${source.light} }`);
  out.push(`    var layerOpacity: Double { ${source.layerOpacity} }`);
  out.push(`    var outlineWidth: CGFloat { ${num(source.outline * DRAW_BOX / source.box)} }`);
  if (source.lines) out.push(`    var lineWidth: CGFloat { ${num(lineWidth)} }`);
  out.push('');
  out.push('    /// Whether a layer fills even-odd, where the source cuts a hole.');
  out.push('    func evenOdd(_ layer: GlyphLayer) -> Bool {', '        switch layer {');
  for (const key of ['solid', 'light']) {
    const names = built.filter((g) => g.layers[key].evenOdd).map((g) => `.${g.name}`);
    out.push(`        case .${key}: ${names.length ? `[${names.join(', ')}].contains(self)` : 'false'}`);
  }
  out.push('        }', '    }', '');
  out.push('    func draw(_ layer: GlyphLayer, into p: inout GlyphPen) {', '        switch (self, layer) {');
  for (const g of built) for (const key of layerKeys) if (drawn(g, key)) out.push(`        case (.${g.name}, .${key}): Self.${g.name}${cap(key)}(&p)`);
  if (built.some((g) => !drawn(g, 'solid'))) out.push('        case (_, .solid): break');
  if (!source.light) out.push('        case (_, .light): break');
  out.push('        }', '    }');
  if (source.lines) {
    out.push('', '    func drawLines(into p: inout GlyphPen) {', '        switch self {');
    for (const g of built) out.push(`        case .${g.name}: Self.${g.name}Lines(&p)`);
    out.push('        }', '    }');
  }
  for (const g of built) {
    for (const key of [...layerKeys, ...(source.lines ? ['lines'] : [])]) {
      if (!drawn(g, key)) continue;
      out.push('', `    private static func ${g.name}${cap(key)}(_ p: inout GlyphPen) {`);
      for (const line of swiftLines(g.layers[key].commands)) out.push(`        ${line}`);
      out.push('    }');
    }
  }
  out.push('}', '');
  return out.join('\n');
}

/**
 * The lookup of the new frame: one case per icon the reference mock draws, its raw value the mock's name, and the glyph it takes
 * from the set its role names (RD23, RD37). The session state glyphs come from `StateGlyph`, which the glance widget and
 * `SessionStateGlyph` share; nothing reaches the v5 MingCute or Duotone sets.
 */
export function frameSource() {
  const entries = [
    ...PAGE_GLYPHS.map(([name, mock, meaning]) => ({ name, raw: mock, glyph: `${PAGE_SOURCE.type}.${name}`, meaning, role: 'own page icon' })),
    ...INTERFACE_GLYPHS.map(([name, icon, meaning]) => ({ name, raw: icon, glyph: `InterfaceGlyph.${name}`, meaning, role: 'Phosphor Bold' })),
    ...SEVERITY_GLYPHS.map(([name, icon, meaning]) => ({ name: camel(`${icon}-fill`), raw: `${icon}-fill`, glyph: `SeverityGlyph.${name}`, meaning, role: 'Phosphor Fill' })),
    ...STATE_GLYPHS.map(([name, icon, meaning]) => ({ name, raw: icon, glyph: `StateGlyph.${name}`, meaning, role: 'Phosphor Bold, shared with the glance widget' })),
  ].sort((a, b) => a.name.localeCompare(b.name, 'en'));
  for (const key of ['name', 'raw']) {
    const seen = new Set();
    for (const e of entries) {
      if (seen.has(e[key])) throw new Error(`FrameIcon: ${key} ${e[key]} twice`);
      seen.add(e[key]);
    }
  }
  const cap = (s) => s[0].toUpperCase() + s.slice(1);
  const out = [];
  out.push('// Generated by scripts/generate-icons.mjs from its glyph lists. Do not edit; rerun the script.');
  out.push('');
  out.push('/// Every icon the new frame draws (spec RD23, RD37, RD38), by the name the reference mock gives it (`src/icons.js`): the 8 page');
  out.push('/// icons from SpaceVibe\'s own set (`PageGlyph`, under the Phosphor names the mock keeps for them), content glyphs from');
  out.push('/// Phosphor Bold (`InterfaceGlyph`, and the session state glyphs `StateGlyph` shares with the glance widget), state glyphs');
  out.push('/// from Phosphor Fill (`SeverityGlyph`). It never returns a v5 MingCute or Duotone glyph.');
  out.push('enum FrameIcon: String, CaseIterable, Sendable {');
  for (const e of entries) out.push(`    /// ${cap(e.meaning)} (${e.role}).`, `    case ${e.name}${e.name === e.raw ? '' : ` = "${e.raw}"`}`);
  out.push('', '    /// The glyph `SpaceVibeIcon` draws for this icon.');
  out.push('    var glyph: any GlyphSource {', '        switch self {');
  for (const e of entries) out.push(`        case .${e.name}: ${e.glyph}`);
  out.push('        }', '    }', '}', '');
  return out.join('\n');
}

function main() {
  const paths = process.argv.slice(2);
  if (paths.length !== PACKAGES.length) {
    console.error('usage: node scripts/generate-icons.mjs <mingcute icons.json> <phosphor (ph) icons.json>');
    process.exit(2);
  }
  const outputs = SOURCES.map((source) => {
    const i = PACKAGES.indexOf(source.pkg);
    const set = JSON.parse(readFileSync(paths[i], 'utf8'));
    const pkg = JSON.parse(readFileSync(join(dirname(paths[i]), 'package.json'), 'utf8'));
    if (set.prefix !== source.prefix || pkg.name !== source.pkg) throw new Error(`argument ${i + 1} is not ${source.pkg}`);
    if (pkg.license !== source.license) throw new Error(`${source.pkg}: licence changed to ${pkg.license}; check it before shipping`);
    return [join(OUT_DIR, source.out), swiftSource(source, packageGlyphs(source, set), `${source.pkg} ${pkg.version}`)];
  });
  const page = pageGlyphs(PAGE_SOURCE, JSON.parse(readFileSync(join(REPO, PAGE_ICONS), 'utf8')));
  outputs.push([join(OUT_DIR, PAGE_SOURCE.out), swiftSource(PAGE_SOURCE, page.glyphs, PAGE_ICONS, page.lineWidth)]);
  outputs.push([join(OUT_DIR, 'FrameIcon.swift'), frameSource()]);
  // Nothing is written until every set has been read and checked.
  for (const [file, text] of outputs) {
    writeFileSync(file, text);
    console.log(file);
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) main();
