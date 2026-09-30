/* Inversion pairs for codex pieces. 14 pairs, lhs ↔ rhs.
   Used by codex.html (invert relations, list view) and inversion.html. */
var INVERSION_PAIRS = [
  { lhs: "wazir",           rhs: "ferz" },
  { lhs: "bishop",          rhs: "rook" },
  { lhs: "pawn",            rhs: "berolina" },
  { lhs: "sergeant",        rhs: "inv-sergeant" },
  { lhs: "arrow-pawn",      rhs: "inv-arrow-pawn" },
  { lhs: "dragon-horse",    rhs: "dragon-king" },
  { lhs: "kirin",           rhs: "squirrel" },
  { lhs: "elephant-modern", rhs: "war-machine" },
  { lhs: "archbishop",      rhs: "chancellor" },
  { lhs: "kirin-plus",      rhs: "inv-kirin-plus" },
  { lhs: "high-priestess",  rhs: "champion" },
  { lhs: "banshee",         rhs: "raven" },
  { lhs: "kirin-plus-plus", rhs: "inv-kirin-plus-plus" },
  { lhs: "gryphon",         rhs: "manticore" }
];

if (typeof module !== "undefined" && module.exports) module.exports = INVERSION_PAIRS;
