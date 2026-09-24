// Fails when the site's piece `value` fields have drifted from
// game/data/pieces.json — i.e. someone edited a value by hand, or pieces.json
// changed and tools/sync-piece-values.mjs wasn't re-run. Never writes.
//   node tools/check-piece-values.mjs
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const pieces = require(join(root, "game/data/pieces.json"));
const valueById = Object.fromEntries(Object.values(pieces).map((p) => [p.id, p.value]));

let failed = false;

// Every codex piece must carry the matching value — no exceptions, no non-roster ids.
const codex = require(join(root, "data/pieces-codex.js"));
for (const p of codex) {
  const expected = valueById[p.id];
  if (expected === undefined) {
    console.error(`data/pieces-codex.js: "${p.id}" has no value in game/data/pieces.json`);
    failed = true;
  } else if (p.value !== expected) {
    console.error(`data/pieces-codex.js: "${p.id}" value ${p.value} !== pieces.json ${expected}`);
    failed = true;
  }
}

// The encyclopedia only carries a value for ids that exist in pieces.json (the
// rest are non-roster reference pieces on purpose); those that do must match.
const encyclopedia = require(join(root, "data/pieces-encyclopedia.js"));
for (const p of encyclopedia) {
  const expected = valueById[p.id];
  if (expected === undefined) continue;
  if (p.value !== expected) {
    console.error(`data/pieces-encyclopedia.js: "${p.id}" value ${p.value} !== pieces.json ${expected}`);
    failed = true;
  }
}

if (failed) {
  console.error("\nSite piece values are stale. Run: node tools/sync-piece-values.mjs");
  process.exit(1);
}
console.log(`ok: ${codex.length} codex + ${encyclopedia.filter((p) => valueById[p.id] !== undefined).length} encyclopedia piece values match game/data/pieces.json`);
