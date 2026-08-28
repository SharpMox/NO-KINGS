# 04 — Piece Buffs: the remaining 9

Status: in progress — timed model + Reflect done, 6 dormant buffs left

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

With the delivery path proven in 03, fill the catalog. Each drops into the model 03
established — dormant-until-trigger, or immediate-and-timed.

**Dormant:** Range (+2 squares on the next move) · Taunt (next enemy capture is forced
onto this piece) · Stun (the next enemy that captures this piece is stunned 1 turn) ·
Multicapture (next capture hits every enemy along the move's line, in sequence) · Trap
(when this piece is captured, the attacker dies too) · Reflect (prevents the next capture
attempt; this piece instead takes the attacker's tile and captures it) · Bomb (on capturing
or being captured, destroys itself, the other piece, and everything within 1 square).

**Immediate + timed:** Slow (movement range −1, expires end of next enemy turn) · Aura
(adjacent allies buffed, 2 player turns) · Smog (adjacent enemies debuffed, 2 player
turns). Slow moved here from slice 03 — see that issue's Outcome.

⚠️ **Settle the magnitudes before building these three.** None are defined in the
catalog, and slice 03 stopped rather than guess:

- **"Movement range reduced by 1"** is undefined for most pieces. `moves_for` only has a
  range limit for *rides*, and an unbounded rider has no "range − 1"; read as Chebyshev
  distance, a Knight loses every legal move. Needs a rule that works for leapers, bounded
  riders and unbounded riders alike.
- **Aura's "bonus movement and/or score gain"** and **Smog's "reduced movement range and
  capture power"** have no numbers, and "capture power" is not a stat the game has.

Aura and Smog need a value for "buffed"/"debuffed" — the catalog says *bonus movement
and/or score gain* and *reduced movement range and capture power* without numbers. Pick
concrete values and record them back on the Notion page.

## Acceptance criteria

- [ ] All 12 buffs implemented and rollable
- [ ] Each dormant buff fires exactly once and is consumed
- [ ] Aura/Smog apply while adjacent and expire after 2 player turns
- [ ] Bomb and Reflect resolve correctly when they chain into another capture
- [ ] Aura/Smog numbers chosen and written back to Notion
- [ ] `run_all.sh` all green

## Progress (2026-08-28)

**The magnitude blocker is resolved.** User ruling: *"reduced movement range should
basically make the piece with that debuff move and capture like a pawn."* Written onto
the Slow and Smog pages in Notion; the code follows it.

Shipped this round:

- **Slow** (timed, 1 turn) — the piece moves and captures like a Pawn.
- **Smog** (timed, 2 turns) — projects the same Pawn downgrade onto *adjacent enemies*,
  not onto its own carrier.
- **Aura** (timed, 2 turns) — adjacent allies score double on captures. ⚠️ **Provisional.**
  The catalog said "bonus movement and/or score gain" with no numbers, and the Pawn ruling
  has no clean inverse (there is no "upgrade a piece" that isn't a promotion), so Aura took
  the score half and reuses Critical's multiplier seam. Confirm or replace.
- **Reflect** (dormant) — stops the capture attempt, then takes the attacker's tile and
  captures it. Dropped straight into the `repels_capture` seam slice 03 built, on both the
  player and the AI path.
- Timed buffs carry `turns` and tick down at the start of each player turn.
  `Rules.moves_for` now asks `BuffLogic.moves_of` for the move set, which is the single
  place the Pawn downgrade lives.

### Left to build — 6 dormant buffs

**Range** ⚠️ still undefined. "+2 extra squares beyond its normal range" has the same hole
the Pawn ruling just closed for reduction: `moves_for` only limits *rides*, an unbounded
rider is already infinite, and a leaper has no "range" to extend. Needs its own ruling —
the obvious candidate is the inverse of Slow (the piece moves as the *next* piece up its
promotion chain), but that is a guess, not the catalog.

**Taunt** — the next enemy capture attempt is forced onto this piece. Needs `ai_action`
to prefer a taunted target over its normal highest-value/lowest-attacker pick.

**Stun** — the enemy that captures this piece loses its next turn. Needs a stunned marker
the AI skips, and a tick at the end of the enemy turn.

**Multicapture** — the next capture hits every enemy along the move's line in sequence.
Rides stop at the first occupied square today, so this sweeps on past it.

**Trap** — when this piece is captured, the attacker dies too.

**Bomb** — on capturing or being captured, destroys itself, the other piece, and
everything within 1 square. Interacts with Trap and Reflect; settle precedence.

## Blocked by

- 03 — delivery path (done)
