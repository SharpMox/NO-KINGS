// Exports the 25 MVP piece defs (8 promotion chains × 3 stages + King) from the
// canonical codex data into game/data/pieces.json for the Godot game.
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

// Game-side point values (codex has none). Used for capture score, AI trade
// decisions, and the 3-different-merge "lowest value" rule.
const VALUES = {
  pawn: 1, sergeant: 2, "arrow-pawn": 3,
  ferz: 2, "elephant-modern": 3, "high-priestess": 5,
  wazir: 2, "war-machine": 3, champion: 5,
  bishop: 3, "dragon-horse": 5, archbishop: 7,
  rook: 5, "dragon-king": 7, chancellor: 8,
  knight: 3, gnu: 5, buffalo: 7,
  kirin: 3, "kirin-plus": 5, "kirin-plus-plus": 8,
  alibaba: 2, bodyguard: 5, queen: 9,
  king: 4,
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
};

const KIND_TO_MODE = { dots: "both", rings: "move", xs: "capture" };

function convertMoves(piece) {
  if (OVERRIDES[piece.id]) return OVERRIDES[piece.id];
  return piece.moves.map((m) => {
    if (m.kind === "rays") {
      return { type: "ride", dirs: m.dirs, range: m.maxRange ?? 0, mode: "both" };
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

const mvpIds = new Set(CHAINS.flatMap((c) => c.ids));
const out = {};
for (const p of PIECES) {
  if (!mvpIds.has(p.id)) continue;
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
if (Object.keys(out).length !== 25) throw new Error(`expected 25 defs, got ${Object.keys(out).length}`);

writeFileSync(join(root, "game/data/pieces.json"), JSON.stringify(out, null, 1) + "\n");
console.log(`wrote game/data/pieces.json (${Object.keys(out).length} pieces)`);
