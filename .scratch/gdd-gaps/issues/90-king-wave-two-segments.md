# 90 — A King wave is two segments

Status: done (2026-09-01)

## Parent

`.scratch/gdd-gaps/KINGS-DESIGN-WORKSHEET.md` (rulings 3 and 7)

## The ruling

> *"only during that kings wave but we will describe a King wave later. It is by design longer:
> in 2 segments, 15 turns of some buffed enemies before the King appears."* — user, 2026-08-31

Plus ruling 7: **"buffed" means Piece Buffs on the spawns.**

## Outcome

**Segment 1 is `Tuning.KING_SEGMENT_TURNS` (15) turns of buffed enemies with no King on the
board; the King is held and released for segment 2.**

`WaveLogic.queue()` diverts the King out of `pending_spawn` into `g.pending_king`;
`release_king_if_due()` puts it back once `turns_since_wave` reaches the threshold. This is
what makes a **wave-scoped King Power** (ruling 4) worth having — a Power that lasted one
ordinary wave would barely register.

**Buffs reuse the 12 shipped Piece Buffs** rather than inventing an enemy-only stat line: the
player already knows what each does, and *which* buffs appear is a per-King flavour lever for
free. Applied through `BuffLogic.add()`, **not** `g._apply_buff()` — the latter is the
*player's* grant choke point and fires `on_buff_apply`, which would run the player's Artefacts
on an enemy spawn.

### Two hazards this slice created, both closed

**1. The wave would have walked past its own King.** Through segment 1 there is no King on the
board, so `_king_alive()` is false — and the cadence check would have queued the *next* wave
while the King was still pending. The advance guard now also requires `pending_king.is_empty()`.
Without it a King wave could complete without ever producing a King.

**2. The King could not land.** Ordinary spawns spill to the next player turn when the row is
full of enemies, which is harmless because the wave advances anyway. A King **cannot** spill:
the wave is barred from advancing while it is pending, and segment 1 *deliberately fills the
row with buffed enemies*. "Wait for space" was therefore a stall the player might not be able
to clear. A King arrival now displaces one of its own; the displaced enemy is **absorbed, not
captured**, so it does not score, pay Gold or fire `on_capture`.

Both were found by the tests rather than reasoned about in advance — the second surfaced as
"segment 2: the King arrives" failing with the King already released.

### Save

`pending_king` round-trips. Additive, but not cosmetic: **a save taken mid-segment-1 and
restored without it would reach segment 2 with no King and could not be won.**

### Verification

`test_kings.gd`: no King during segment 1, the King held *with its identity*, not released one
turn early (14 of 15), every segment-1 enemy arrives buffed (8/8), the King arrives once
segment 1 is over, lands despite a contested row, and a pending King survives
`SaveConfig.to_config()`.

Live autoplay sanity sweep — **runs now pass wave 50 and continue into Endless**
(Crown/Tier 1 ended at wave 58, Crown/Tier 3 at 51), which is the first end-to-end evidence
that the two-segment wave resolves in a real run rather than only in fixtures.

`run_all.sh` **155.7s ALL GREEN**, foreground, alone.
