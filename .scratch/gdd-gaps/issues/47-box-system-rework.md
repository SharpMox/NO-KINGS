# 47 — Box system rework: 9 typed Boxes, rolled at stock time

Status: todo — SPECCED (user rulings 2026-08-29) · **foundation for 48/49**

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

The prototype's Box (`box.gd`, goal rework 2026-07-06) is a single 3-option offer with
mixed contents — Item 40% / Artefact 30% / Score 30% — and it diverged from the GDD
without the catalog ever being updated. Three Artefacts still describe the older design
(see `NOTION-QUESTIONS.md` question 1). Rather than re-text those rows down to the
prototype, the user specced the Box system upward.

All rulings below are the user's, 2026-08-29.

## The 9 Boxes

Three sizes x three themes. `BOX_TYPES := ["item", "artefact", "score"]` is replaced.

| Size | Choices | Picks |
| --- | --- | --- |
| Small | 3 | 1 |
| Big | 5 | 1 |
| Huge | 7 | 2 |

Themes: **Pieces / Artefacts / Items**. An effect that says only "a Box" rolls one of the
9 at random.

**Score Boxes are removed** — Score is no longer a Box reward at all (`SCORE_BOX_CHUNKS`
loses its consumer). **The mixed-content Box is removed** — every Box is themed.

Subthemes (strategic-items box, rarity-tier boxes) were discussed and explicitly deferred:
note them, do not build them.

## Contents are rolled at STOCK time, not at open time

Today `_box_options` runs inside `_open_box_pick`, so a Box's contents do not exist until
it is opened. That has to change: **a Box rolls its contents when it is stocked/offered,
stores them on the slot, and opening reveals what was already decided.**

Do this **unconditionally**, not only when All-Seeing Eye Contact Lens is held (issue 49).
Unconditional is less code and avoids the edge case where the artefact is acquired *after*
a restock and the already-stocked Boxes have nothing stored to reveal. It also avoids
depending on RNG-stream position, which would desync a peek from the later open.

`shop_stock` slots are `{kind, key, sold}` and JSON-safe; the rolled contents are an
**additive** field, so per `save_config.gd`'s policy this needs no migration.

Boxes that do not come from the Shop (Bounty's 1-of-3 offer, artefact grants) follow the
same rule: roll when offered, store, reveal on open.

## Shop stocking and price

- **6 Box slots, unchanged** — 2 per theme (Pieces / Artefacts / Items), with each slot's
  **size rolled independently**.
- **Price by size only**, ignoring theme. Rising curve Small -> Big -> Huge. The user
  expects to fine-tune these numbers shortly; pick something defensible and say so.

## Piece Box contents

Draw from **the same pool the Shop uses** — `Shop.base_piece_pool`, i.e. every piece
nothing else promotes into (chain entry points), excluding the King and inversions, with
the existing `1 / value` weighting.

This was an explicit choice (user, option 1 of 3): the wider "entire 39-piece catalog"
option would let a Box hand out a chain-*end* piece and bypass the merge/promotion
progression. Boxes feed the chain system rather than skipping it.

Pieces from a Box land in Stock, like a Shop piece purchase.

## Remove the box-carrier enemy

The "enemy carrying a treasure box" design is obsolete (user call). Removing it:

- `wave_logic.gd:53` — `entry.buff = true` on spawn
- `wave_logic.gd:97-98` — carrying the flag onto the board
- `game.gd:1387` — `boxed = victim.get("buff", false)` on capture
- `game.gd:1427` — `if boxed: return _open_box_pick()`
- `game.gd:1784` — `board[b].erase("buff")`
- `game.gd:2152` — the gold badge drawn on a carrier

Do not confuse this `buff` (singular, the carrier flag) with a piece's `buffs` array —
`buff_logic.gd`'s header calls out that collision.

**Consequence, accepted by the user:** this is the only source of Boxes outside the Shop,
so after this change Boxes come from the Shop plus whatever Artefacts grant them
(Loch Ness Stool Sample, Trojan Horse Assembly Manual). Issue 48's Bounty buff is the
intended replacement for the loot-on-capture moment, now player-directed.

Once `boxed` is gone, `_open_box_pick()` with no argument has no caller — every Box is
typed. Remove the untyped path rather than leaving it dead.

## What survives untouched

Slice 46's work is orthogonal and must keep passing: Nostradamus Mad Libs adds picks *on
top of* a Box's native count (so Huge + Nostradamus = 3 picks), and the two reroll
Artefacts re-roll the stored offer. `Economy.charge(self, "box_cost")` must still fire
exactly once per Box.

Majestic 12 Secret Handshake Diagram ("Item Boxes only offer Strategic and Decisive
Items") already ships and now names a real thing.

## Acceptance

- 9 Box types; Score Box and mixed Box gone; carrier removed with all six call sites.
- Contents rolled at stock time, stored, and identical when opened. Assert this directly:
  read a stocked Box's contents, open it, assert the same entries.
- Save round-trips a stocked Box with its contents intact.
- `box_cost` still charged exactly once per Box, including across rerolls.
- Autoplay resolves every Box path without opening a modal — the bot leg must not hang.
- Tests in the split suites, seeds pinned. `game/tests/run_all.sh` ALL GREEN, click probes
  included (Box UI changes).

## Blocked by

- nothing
