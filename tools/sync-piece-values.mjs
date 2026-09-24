// Writes each piece's point Value onto the site's data files, read straight off
// game/data/pieces.json (the source of truth — Max's ruling, NO piece-values ticket).
// game/data/pieces.json is itself exported FROM data/pieces-codex.js by
// tools/export-game-pieces.mjs, so this is a round trip: the VALUES dict that
// lives inside that exporter is the true origin, pieces.json is its output, and
// this script carries that output back onto the two site data files that render
// per-piece cards, so nothing on the site is hand-typed.
//
// Matches by id (data/pieces-codex.js ids equal game ids 1:1 — the codex IS the
// exporter's input). data/pieces-encyclopedia.js is a broader 100-piece Betza
// reference including many non-roster fairy pieces with no game value; only the
// ids that exist in pieces.json get a `value` field there.
//
// Idempotent: re-running updates an existing `value:` line in place rather than
// duplicating it, so it's safe to run after every pieces.json change.
//   node tools/sync-piece-values.mjs
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const pieces = JSON.parse(readFileSync(join(root, "game/data/pieces.json"), "utf8"));
const valueById = Object.fromEntries(Object.values(pieces).map((p) => [p.id, p.value]));

// Rewrites every `id: '<id>',` line's following line into `value: N,`, matching
// that id line's own indent — inserting if absent, replacing if a run already
// wrote one. Returns { text, mapped, unmapped }.
function syncValues(text) {
  const lines = text.split("\n");
  const out = [];
  const mapped = [];
  const unmapped = [];
  const idLine = /^(\s*)id:\s*'([\w-]+)',\s*$/;
  const valueLine = /^\s*value:\s*-?\d+,\s*$/;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const m = line.match(idLine);
    if (!m) {
      out.push(line);
      continue;
    }
    out.push(line);
    const [, indent, id] = m;
    const value = valueById[id];
    if (value === undefined) {
      unmapped.push(id);
      continue;
    }
    mapped.push(id);
    const already = lines[i + 1] && lines[i + 1].match(valueLine);
    out.push(`${indent}value: ${value},`);
    if (already) i++; // consume the stale value line we just replaced
  }
  return { text: out.join("\n"), mapped, unmapped };
}

const codexPath = join(root, "data/pieces-codex.js");
const codexResult = syncValues(readFileSync(codexPath, "utf8"));
if (codexResult.unmapped.length) {
  throw new Error(`data/pieces-codex.js: no game value for id(s): ${codexResult.unmapped.join(", ")}`);
}
writeFileSync(codexPath, codexResult.text);
console.log(`data/pieces-codex.js: wrote value for ${codexResult.mapped.length} pieces`);

const encyPath = join(root, "data/pieces-encyclopedia.js");
const encyResult = syncValues(readFileSync(encyPath, "utf8"));
writeFileSync(encyPath, encyResult.text);
console.log(`data/pieces-encyclopedia.js: wrote value for ${encyResult.mapped.length} pieces, ` +
  `${encyResult.unmapped.length} without a game id (non-roster reference pieces, expected)`);
