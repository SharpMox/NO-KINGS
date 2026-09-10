// Generates the Endless tail of game/data/waves.gd — waves 151-199 plus the
// King wave at 200 — and rewrites the marked region of that file in place.
// Run by hand, like the exporters beside it:  node tools/generate-endless-waves.mjs
//
// WHY GENERATED, NOT 49 HAND-PICKED ROWS. The shape of the curve is a design
// decision; the numbers in it are a balance decision, and balance is
// deliberately last in this project. Generating from named constants keeps the
// two apart: the later balance pass turns a knob here and re-runs this, instead
// of rewriting 49 rows and re-deriving the shape from them.
//
// WHAT THE CURVE IS FOR. The 150-wave table plateaus: it uses four enemy types
// (rook 50, knight 30, bishop 30, pawn 10) in at most six slots, so a wave caps
// at 300 and the table has sat at 220-240 since roughly wave 76. That is a
// CEILING, not a choice — it ran out of headroom and marked time for seventy-five
// waves. 34 of the 39 catalogue pieces have never spawned in a wave and all 34
// already ship light/dark art, so the fix is to use built content, not make more.
//
// Difficulty is a VALUE BUDGET that climbs while COMPOSITION shifts from
// mid-tier toward end-tier (user model, 2026-09-10). Piece count is whatever
// the budget buys, so it sawtooths — a phase change spends the same budget on
// fewer, stronger pieces — which is the "varied content on a growing curve"
// the model asks for rather than a bigger pile of the same thing.
//
// KNOWN CONSEQUENCE, deliberately not addressed here: `value` is BOTH the
// threat proxy and the price. economy.gd:28 — "which is ALSO the Gold/Shop-price
// number" — and capture Gold comes straight off it (economy.gd:201) with Score
// at value x10. So a richer wave is harder AND pays proportionally more. That
// coupling is real, it is why these constants are provisional, and decoupling
// it is a balance-pass question, not this slice's.
import { readFileSync, writeFileSync } from "node:fs";

// ---- PROVISIONAL. Every number below is a balance knob, not a settled value.
// They were chosen to be continuous with wave 150 and to climb; none of them
// has been playtested. The balance pass owns them. ---------------------------
const FIRST = 151;
const KING_WAVE = 200;          // the 4th King wave — also what makes order[3]
                                // reachable at last (Kings._ordinal returns 3)
const BUDGET_START = 240;       // wave 150's own ceiling, so 151 has no seam
const BUDGET_STEP = 9;          // per wave; 240 -> 672 by wave 199
const COUNT_MIN = 3;
const COUNT_MAX = 8;            // BOARD_W is 8 and SPAWN_ROW spills overflow to
                                // the next turn, so 8 is the widest honest wave

// Budget weights per band, walked once across 151-199. This picks up where the
// existing table leaves off — wave 150 is pure mid (bishop/knight/rook) — and
// ends on end-tier only, immediately before the King. The early
// simple-and-simple+mid phases of the user's full progression live in waves
// 1-150, which are NOT regenerated here (deferred: retroactive regeneration
// would invalidate the NO-6 baseline and change runs already in flight).
const PHASES = [
  [0.15, 0.85, 0.00],
  [0.15, 0.70, 0.15],
  [0.10, 0.60, 0.30],
  [0.10, 0.45, 0.45],
  [0.05, 0.35, 0.60],
  [0.05, 0.15, 0.80],
  [0.00, 0.00, 1.00],
];

const BANDS = [[10, 20], [30, 50], [60, 140]]; // simple / mid / end
// ---------------------------------------------------------------------------

const pieces = JSON.parse(readFileSync("game/data/pieces.json", "utf8"));
const all = Array.isArray(pieces) ? pieces : Object.values(pieces);

// `king` is the boss, never chaff. `inv-*` are what game.gd:2568 turns a piece
// INTO — a transformation result, not something that marches on from the top row.
const palette = all.filter(p => p.id !== "king" && !p.id.startsWith("inv-"));
const band = BANDS.map(([lo, hi]) =>
  palette.filter(p => p.value >= lo && p.value <= hi).sort((a, b) => a.value - b.value));

// Deterministic per wave: committed generated data has to regenerate identically.
function rand(seed) {
  let s = seed * 2654435761 % 2147483647;
  return () => (s = s * 48271 % 2147483647) / 2147483647;
}

function wave(n) {
  const budget = BUDGET_START + (n - FIRST) * BUDGET_STEP;
  const phase = PHASES[Math.min(PHASES.length - 1,
    Math.floor((n - FIRST) / ((KING_WAVE - FIRST) / PHASES.length)))];
  const rnd = rand(n);
  const out = [];
  const copies = id => out.filter(p => p.id === id).length;
  // Spend each band's slice on pieces FROM THAT BAND, biased to the strong end
  // of what still fits. Biasing strong is what makes the piece count fall as
  // the mix shifts toward end-tier: the same budget buys fewer, bigger threats.
  // Picking uniformly instead pins every wave at COUNT_MAX, because cheap
  // pieces always fit and there are more of them — which flattens the sawtooth
  // the whole model exists to produce.
  phase.forEach((w, b) => {
    let left = budget * w;
    const pool = band[b];
    if (!pool.length) return;
    while (out.length < COUNT_MAX) {
      // At most two of a kind: a wave of five identical pieces reads as a bug,
      // and variety is half the point of the model.
      const fits = pool.filter(p => p.value <= left && copies(p.id) < 2);
      if (!fits.length) break;
      const from = Math.floor(fits.length * 2 / 3); // strong end, still varied
      const pick = fits[from + Math.floor(rnd() * (fits.length - from))];
      out.push(pick);
      left -= pick.value;
    }
  });
  // Leftover budget buys an upgrade rather than a ninth piece: BOARD_W is 8 and
  // a wider roster only spills into the next turn, which reads as a slower wave
  // rather than a harder one.
  let spent = out.reduce((s, p) => s + p.value, 0);
  for (let i = 0; i < out.length && spent < budget; i++) {
    const room = budget - spent;
    const up = palette.filter(p => p.value > out[i].value
      && p.value - out[i].value <= room && copies(p.id) < 2);
    if (!up.length) continue;
    const best = up[up.length - 1];
    spent += best.value - out[i].value;
    out[i] = best;
  }
  while (out.length < COUNT_MIN) out.push(band[1][0]);
  return out.map(p => p.id);
}

const rows = [];
for (let n = FIRST; n < KING_WAVE; n++) rows.push({ n, ids: wave(n) });
// The King wave itself: end-tier escort, same shape as the other three (the
// King plus five). Generated from the same palette so it moves with the curve.
// The King wave: the King plus an end-tier escort, the same five-or-six shape
// the other three King waves use. Budgeted like a normal wave so it does not
// dip below its neighbours, then trimmed to leave room for the King itself.
rows.push({ n: KING_WAVE, ids: ["king", ...wave(KING_WAVE).slice(0, 5)] });

const width = Math.max(...rows.map(r => r.ids.map(i => `"${i}"`).join(", ").length));
const body = rows.map(r => {
  const list = r.ids.map(i => `"${i}"`).join(", ");
  const note = r.n === KING_WAVE ? ` — King wave (the 4th)` : "";
  return `\t[${list}],${" ".repeat(width - list.length)} # ${r.n}${note}`;
}).join("\n");

const START = "\t# ---- GENERATED by tools/generate-endless-waves.mjs — do not edit by hand ----";
const END = "\t# ---- end generated ----";
const src = readFileSync("game/data/waves.gd", "utf8");
const i = src.indexOf(START);
const block = `${START}\n${body}\n${END}`;
const next = i === -1
  ? src.replace(/^\]$/m, `${block}\n]`)
  : src.slice(0, i) + block + src.slice(src.indexOf(END) + END.length);
writeFileSync("game/data/waves.gd", next);

const vals = Object.fromEntries(palette.map(p => [p.id, p.value]));
const b = rows.filter(r => r.n !== KING_WAVE);
console.log(`waves ${FIRST}-${KING_WAVE} written (${rows.length} entries)`);
console.log(`  value  ${b[0].ids.reduce((s,i)=>s+vals[i],0)} -> ${b[b.length-1].ids.reduce((s,i)=>s+vals[i],0)}`);
console.log(`  count  min ${Math.min(...b.map(r=>r.ids.length))}, max ${Math.max(...b.map(r=>r.ids.length))}`);
console.log(`  distinct pieces used: ${new Set(rows.flatMap(r=>r.ids)).size}`);
