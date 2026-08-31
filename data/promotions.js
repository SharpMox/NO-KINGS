/* Promotion Families for codex pieces. 8 Families × 3 stages.
   Each entry: { title, ids: [base, mid, end] }.
   Used by graph.html (self-merge lookup) and potentially promotion.html. */
var PROMOTION_FAMILIES = [
  { title: "Pawn",    ids: ["pawn",    "sergeant",        "arrow-pawn"]    },
  { title: "Ferz",    ids: ["ferz",    "elephant-modern", "high-priestess"] },
  { title: "Wazir",   ids: ["wazir",   "war-machine",     "champion"]      },
  { title: "Bishop",  ids: ["bishop",  "dragon-horse",    "archbishop"]    },
  { title: "Rook",    ids: ["rook",    "dragon-king",     "chancellor"]    },
  { title: "Knight",  ids: ["knight",  "gnu",             "buffalo"]       },
  { title: "Kirin",   ids: ["kirin",   "kirin-plus",      "kirin-plus-plus"] },
  { title: "Alibaba", ids: ["alibaba", "bodyguard",       "queen"]         }
];

if (typeof module !== "undefined" && module.exports) module.exports = PROMOTION_FAMILIES;
