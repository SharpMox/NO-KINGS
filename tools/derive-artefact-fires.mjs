// Derives, for every Artefact, which hooks its handler CAUSES TO FIRE — the
// half of the hook graph that has never been written down.
//
// `ArtefactHooks.REGISTRY` says what each Artefact LISTENS to. Nothing said
// what one FIRES, so Artefact -> Artefact cascades were invisible: Aztec
// Calendar Battery adds Clock, which fires on_clock_change, which the Clock
// listeners then see. That is a real interaction and nothing could see it.
//
// Derived rather than hand-written (issue 94, grilled 2026-09-01): 180 rows of
// hand judgement would have dominated the slice, and a derived map describes
// what the code DOES rather than what someone remembers it doing. Same rule as
// every other generated file here — `game/data/artefact_fires.json` is
// GENERATED, never hand-edited. Re-run this after touching _dispatch:
//
//   node tools/derive-artefact-fires.mjs
//
// ---------------------------------------------------------------------------
// THE TABLE IS EVIDENCE, NOT INTUITION
// ---------------------------------------------------------------------------
// Every entry below was verified to a real `ArtefactHooks.run(...)` call site.
// The first draft of this table was written from memory during grilling and
// TWO of its entries were wrong — both are in the exclusion list, because a
// wrong entry here invents combos that cannot happen.
const FIRES = {
  "Economy.add_clock": ["on_clock_change"], // economy.gd:167
  "g._apply_buff": ["on_buff_apply"], // game.gd:2478
  "WaveLogic.queue": ["on_wave_roster", "on_clock_refill", "on_wave_spawn"], // wave_logic.gd:59,80,91
  "Shop.price": ["on_price"], // shop.gd:164
  "Shop.buy": ["on_purchase", "on_gold_zero"], // shop.gd:329,312
};

// Deliberately NOT producers, each for a checked reason:
//
//   ctx.gold_bonus / ctx.score_bonus — `Economy.earn` applies these with a
//     direct `g.gold +=` / `g.score +=` (economy.gd:111-114). They do NOT
//     re-enter the dispatch. on_gold_change fired because somebody called
//     earn(), not because this handler set a bonus, so counting it would pair
//     every converter artefact with every Gold listener for no reason.
//   ItemLogic.grant — appends to `g.items` (item_logic.gd:41-45). Fires
//     nothing; on_item_consume fires on USE, not on grant.
//   g._open_box_pick / g._open_yalta_pick — `on_box_open` is declared in HOOKS
//     but is never fired anywhere in game/scripts (nor is on_shop_restock).
//     Dead vocabulary, and no artefact listens on either.
//   Economy.earn / Economy.gain — never called from a handler body at all; the
//     ctx contract in artefact_hooks.gd's header forbids it.

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const src = readFileSync(join(root, "game/scripts/artefact_hooks.gd"), "utf8").split("\n");

// _dispatch's arms are `match [key, hook]:` cases at exactly two tabs, with
// bodies indented deeper. That labelling is what makes attribution exact —
// every line of every body belongs to a known artefact key.
const start = src.findIndex((l) => l.startsWith("static func _dispatch"));
if (start < 0) throw new Error("could not find _dispatch in artefact_hooks.gd");
let end = src.length;
for (let i = start + 1; i < src.length; i++) {
  if (/^(static )?func /.test(src[i])) {
    end = i;
    break;
  }
}

const fires = {};
let keys = [];
let armLines = 0;
for (const line of src.slice(start, end)) {
  if (/^\t\t\[/.test(line)) {
    // One arm can carry several [key, hook] pairs (the on_charge tariffs do).
    keys = [...line.matchAll(/\["([^"]+)",\s*"([^"]+)"\]/g)].map((m) => m[1]);
    armLines++;
    continue;
  }
  if (!keys.length) continue;
  if (line.trim() !== "" && !/^\t\t\t/.test(line)) {
    keys = []; // dedented out of the body
    continue;
  }
  for (const [call, hooks] of Object.entries(FIRES)) {
    if (!line.includes(call + "(")) continue;
    for (const key of keys) {
      fires[key] ??= new Set();
      for (const h of hooks) fires[key].add(h);
    }
  }
}

const out = {};
for (const key of Object.keys(fires).sort()) out[key] = [...fires[key]].sort();

writeFileSync(
  join(root, "game/data/artefact_fires.json"),
  JSON.stringify(out, null, "\t") + "\n",
);

const total = Object.values(out).reduce((n, hs) => n + hs.length, 0);
console.log(`${armLines} dispatch arms scanned`);
console.log(`${Object.keys(out).length} keys fire something (${total} key->hook edges)`);
for (const [k, hs] of Object.entries(out)) console.log(`  ${k}: ${hs.join(", ")}`);
