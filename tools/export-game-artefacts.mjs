// Exports the 180-artefact reference-site catalog into game/data/artefacts.json
// for the Godot game. The site data has no key field (only `name`), so this
// derives a stable kebab-case key per artefact and asserts uniqueness — a
// silent collision would merge two artefacts.
//
// `implemented` is false for all 180: none of them have game mechanics yet
// (that's slices 15-20 — the trigger engine, then the catalog rollout). The 7
// keys already shipped in game/data/items.gd (ARTEFACT_EFFECTS_CORE) pre-date
// this catalog and have no Notion/site equivalent, so they are not in this
// export; items.gd merges them with whatever catalog entries later flip to
// implemented: true, so the shop/box roll pool never needs re-plumbing.
//
// Run manually after editing data/artefacts.js:
//   node tools/export-game-artefacts.mjs
import { createRequire } from "node:module";
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const ARTEFACTS = require(join(root, "data/artefacts.js"));

// Reserved: the 7 game-native keys in items.gd. A catalog key colliding with
// one of these would silently shadow a shipped effect — assert it can't.
const RESERVED_KEYS = new Set([
  "first_capture_extra", "greed", "move", "lifesteal", "score", "timer", "bounty",
]);

function slugify(name) {
  return name
    .toLowerCase()
    .normalize("NFKD").replace(/[̀-ͯ]/g, "") // strip accents
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

const seen = new Map(); // key -> name, to report collisions with both sides
const out = [];
for (const a of ARTEFACTS) {
  const key = slugify(a.name);
  if (seen.has(key)) {
    throw new Error(`key collision: "${a.name}" and "${seen.get(key)}" both slugify to "${key}"`);
  }
  if (RESERVED_KEYS.has(key)) {
    throw new Error(`"${a.name}" slugifies to "${key}", which collides with a shipped items.gd key`);
  }
  seen.set(key, a.name);
  out.push({
    key,
    name: a.name,
    rarity: a.rarity,
    type: a.type,
    bonus: a.bonus,
    effect: a.effect,
    conspiracy: a.conspiracy,
    implemented: false,
  });
}

if (out.length !== 180) throw new Error(`expected 180 artefacts, got ${out.length}`);

writeFileSync(join(root, "game/data/artefacts.json"), JSON.stringify(out, null, 1) + "\n");
console.log(`wrote game/data/artefacts.json (${out.length} artefacts, 0 implemented, keys unique)`);
