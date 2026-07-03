// Exports ALL codex pieces (38) + the King into game/data/pieces.json for the
// Godot game, plus the full fusion table.
// Run manually after editing data/pieces-codex.js or data/promotions.js:
//   node tools/export-game-pieces.mjs
import { createRequire } from "node:module";
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const PIECES = require(join(root, "data/pieces-codex.js"));
const CHAINS = require(join(root, "data/promotions.js"));
const FUSIONS = require(join(root, "data/fusions.js"));


// Game-side point values (codex has none). Used for capture score, AI trade
// decisions, and the 3-different-merge "lowest value" rule.
// x10 economy (2026-07-03): room for percentage effects like Inflation.
const VALUES = {
  pawn: 10, sergeant: 20, "arrow-pawn": 30,
  ferz: 20, "elephant-modern": 30, "high-priestess": 50,
  wazir: 20, "war-machine": 30, champion: 50,
  bishop: 30, "dragon-horse": 50, archbishop: 70,
  rook: 50, "dragon-king": 70, chancellor: 80,
  knight: 30, gnu: 50, buffalo: 70,
  kirin: 30, "kirin-plus": 50, "kirin-plus-plus": 80,
  alibaba: 20, bodyguard: 50, queen: 90,
  squirrel: 50, "crown-princess": 80, amazon: 120,
  // full-set additions (2026-07-03): void pieces + riders and bent-riders
  berolina: 10, "inv-sergeant": 20, "inv-arrow-pawn": 30,
  "inv-kirin-plus": 50, "inv-kirin-plus-plus": 80,
  gryphon: 60, manticore: 60, godzilla: 110,
  banshee: 80, raven: 90, amazonrider: 140,
  king: 40,
};

// Codex `moves` are movement-diagram data; kinds map mechanically to game moves
// (dots→leap/both, rays→ride, rings→leap/move-only, xs→leap/capture-only) except
// where diagram squares differ from move semantics:
const OVERRIDES = {
  // mfWcfFimfnD: MVP drops the initial double-step (and en passant with it).
  pawn: [
    { type: "leap", dirs: [[0, 1]], mode: "move" },
    { type: "leap", dirs: [[1, 1], [-1, 1]], mode: "capture" },
  ],
  // mW2cF: the W2 step slides (can't jump), so it's a range-2 ride, not leaps.
  "arrow-pawn": [
    { type: "ride", dirs: [[1, 0], [-1, 0], [0, 1], [0, -1]], range: 2, mode: "move" },
    { type: "leap", dirs: [[1, 1], [-1, 1], [1, -1], [-1, -1]], mode: "capture" },
  ],
  // mfFcfWimfnA: the Pawn's mirror; drop the double-step like the pawn's.
  berolina: [
    { type: "leap", dirs: [[1, 1], [-1, 1]], mode: "move" },
    { type: "leap", dirs: [[0, 1]], mode: "capture" },
  ],
  // mF2cW: the Void Archer's F2 slides diagonally (can't jump).
  "inv-arrow-pawn": [
    { type: "ride", dirs: [[1, 1], [-1, 1], [1, -1], [-1, -1]], range: 2, mode: "move" },
    { type: "leap", dirs: [[1, 0], [-1, 0], [0, 1], [0, -1]], mode: "capture" },
  ],
};

const KIND_TO_MODE = { dots: "both", rings: "move", xs: "capture" };

function convertMoves(piece) {
  if (OVERRIDES[piece.id]) return OVERRIDES[piece.id];
  return piece.moves.map((m) => {
    if (m.kind === "rays") {
      return { type: "ride", dirs: m.dirs, range: m.maxRange ?? 0, mode: "both" };
    }
    if (m.kind === "rider") { // nightrider chains: a ride whose step is a leap
      return { type: "ride", dirs: [m.step], range: 0, mode: "both" };
    }
    if (m.kind === "bent-rider") { // one step to pivot, then ride outward
      return { type: "bent", pivot: m.pivot, dir: m.dir, mode: "both" };
    }
    const mode = KIND_TO_MODE[m.kind];
    if (!mode) throw new Error(`${piece.id}: unhandled move kind "${m.kind}"`);
    return { type: "leap", dirs: m.squares, mode };
  });
}

const next = {}; // chain successor per id
for (const chain of CHAINS) {
  const [base, mid, end] = chain.ids;
  next[base] = mid;
  next[mid] = end;
}

const out = {};
for (const p of PIECES) {
  out[p.id] = {
    id: p.id,
    name: p.name,
    glyph: p.glyph || p.letter,
    value: VALUES[p.id],
    next: next[p.id] ?? null,
    moves: convertMoves(p),
  };
}
out.king = { // not in the codex (the game is NO-KINGS; only the enemy fields one)
  id: "king", name: "King", glyph: "♚", value: VALUES.king, next: null,
  moves: [{ type: "leap", dirs: [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, 1], [1, -1], [-1, -1]], mode: "both" }],
};

const missing = Object.values(out).filter((p) => p.value == null);
if (missing.length) throw new Error("missing values: " + missing.map((p) => p.id));
if (Object.keys(out).length !== 39) throw new Error(`expected 39 defs, got ${Object.keys(out).length}`);

writeFileSync(join(root, "game/data/pieces.json"), JSON.stringify(out, null, 1) + "\n");
console.log(`wrote game/data/pieces.json (${Object.keys(out).length} pieces)`);

// Fusions: unordered pair -> result, filtered to pieces the game defines.
// Key = the two ids sorted and joined with "+".
const fusions = {};
let skipped = 0;
for (const f of FUSIONS.additive.concat(FUSIONS.synergistic)) {
  if (out[f.lhs] && out[f.rhs] && out[f.out]) {
    fusions[[f.lhs, f.rhs].sort().join("+")] = f.out;
  } else {
    skipped++;
  }
}
writeFileSync(join(root, "game/data/fusions.json"), JSON.stringify(fusions, null, 1) + "\n");
console.log(`wrote game/data/fusions.json (${Object.keys(fusions).length} fusions, ${skipped} skipped: inputs/results outside the game set)`);
