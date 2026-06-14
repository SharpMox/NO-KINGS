/* Fusion combinations for codex pieces.
   - additive: A + B = C, where C's movement set equals the union of A's and B's
   - synergistic: A + B = C, where C also gains an emergent movement not in either parent
   Used by graph.html (cross-merge lookup) and potentially fusion.html. */
var FUSIONS = {
  additive: [
    { lhs: "alibaba",      rhs: "war-machine",    out: "champion" },
    { lhs: "knight",       rhs: "elephant-modern",out: "high-priestess" },
    { lhs: "knight",       rhs: "alibaba",        out: "squirrel" },
    { lhs: "rook",         rhs: "kirin",          out: "dragon-king" },
    { lhs: "bishop",       rhs: "knight",         out: "archbishop" },
    { lhs: "bishop",       rhs: "high-priestess", out: "archbishop" },
    { lhs: "knight",       rhs: "rook",           out: "chancellor" },
    { lhs: "bishop",       rhs: "rook",           out: "queen" },
    { lhs: "bishop",       rhs: "dragon-king",    out: "queen" },
    { lhs: "rook",         rhs: "dragon-horse",   out: "queen" },
    { lhs: "dragon-horse", rhs: "dragon-king",    out: "queen" },
    { lhs: "bishop",       rhs: "chancellor",     out: "amazon" },
    { lhs: "knight",       rhs: "queen",          out: "amazon" },
    { lhs: "rook",         rhs: "archbishop",     out: "amazon" },
    { lhs: "archbishop",   rhs: "chancellor",     out: "amazon" },
    { lhs: "archbishop",   rhs: "dragon-king",    out: "amazon" },
    { lhs: "archbishop",   rhs: "queen",          out: "amazon" },
    { lhs: "chancellor",   rhs: "dragon-horse",   out: "amazon" },
    { lhs: "chancellor",   rhs: "queen",          out: "amazon" },
    { lhs: "queen",        rhs: "high-priestess", out: "amazon" },
    { lhs: "knight",       rhs: "dragon-horse",   out: "crown-princess" },
    { lhs: "wazir",        rhs: "archbishop",     out: "crown-princess" },
    { lhs: "archbishop",   rhs: "dragon-horse",   out: "crown-princess" },
    { lhs: "dragon-horse", rhs: "high-priestess", out: "crown-princess" },
    { lhs: "raven",        rhs: "banshee",        out: "amazonrider" }
  ],
  synergistic: [
    { lhs: "ferz",       rhs: "rook",      out: "gryphon" },
    { lhs: "wazir",      rhs: "bishop",    out: "manticore" },
    { lhs: "archbishop", rhs: "knight",    out: "banshee" },
    { lhs: "chancellor", rhs: "knight",    out: "raven" },
    { lhs: "amazon",     rhs: "knight",    out: "amazonrider" },
    { lhs: "manticore",  rhs: "gryphon",   out: "godzilla" }
  ]
};

if (typeof module !== "undefined" && module.exports) module.exports = FUSIONS;
