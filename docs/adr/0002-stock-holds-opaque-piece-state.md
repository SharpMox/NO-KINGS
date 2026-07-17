# Stock entries carry opaque piece state before any ally buff exists

Extraction (grilled 2026-07-17) returns board pieces to Stock, and a general
piece-buff system (ally + enemy) is planned but not yet designed. Nothing in
today's code can buff an ally, so YAGNI argued for keeping Stock an
`Array[String]` of piece ids — but the user chose to preshot the data model so
the buff system won't need a Stock/save migration later.

Decision: a Stock entry is either a bare id `String` (plain piece) or a
`Dictionary` of `{"id": <piece id>, + the piece's remaining board state}`.
Extraction strips board-only fields (position, owner) and stores whatever
state is left; placement merges it back onto the new board piece; **Stock
never interprets the state** — no buff schema, no enumerated kinds. HUD stacks
group by whole-entry equality, so each distinct state combination gets its own
stack. Merging discards input state (the result is a new piece). Old saves
(bare-string stocks) stay valid with no migration.

Rejected: a typed `{"id", "buff": bool}` schema — it encodes exactly one buff
and needs rework per new buff kind; opaque pass-through absorbs any future
state that lives on the board-piece dict, by construction.
