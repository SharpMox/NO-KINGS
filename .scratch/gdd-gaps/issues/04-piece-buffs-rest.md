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

**Immediate + timed (2 player turns):** Aura (adjacent allies buffed while adjacent) ·
Smog (adjacent enemies debuffed while adjacent).

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
