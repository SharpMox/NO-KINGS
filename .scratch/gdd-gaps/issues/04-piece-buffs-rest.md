# 04 — Piece Buffs: the remaining 9

Status: todo

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

## Blocked by

- 03 — delivery path
