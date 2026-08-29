# 47 — Box system rework: 9 typed Boxes, rolled at stock time

Status: done (2026-08-29) · **foundation for 48/49**

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
- **Price by size only**, ignoring theme.

`SHOP_BOX_PRICE := 50` is currently a single flat value and becomes a size curve. Use the
**doubling shape the file already uses everywhere else** — `SHOP_ITEM_PRICE` is
30/60/120, `SHOP_ARTEFACT_PRICE` is 50/100/200/400 — so:

```gdscript
const SHOP_BOX_PRICE := {"small": 50, "big": 100, "huge": 200}
```

Small keeps today's 50, so nothing gets cheaper. That prices a Huge (7 choices, 2 picks) at
the same 200 as two Smalls (6 choices, 2 picks) — you pay the same for picks and buy
better selection, which is a sane starting shape. **The user expects to tune these
shortly**; the point is to start from the file's own idiom rather than an invented curve.

`SCORE_BOX_CHUNKS` loses its only consumer when Score Boxes go — delete it rather than
leaving it orphaned, and check nothing else reads it first.

`BOX_SKIP_CONSOLATION := 20` still applies on decline and is unaffected; Cicada Rejection
Letter (issue 49) pays *on top of* it.

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

## Outcome

Shipped in PR #TBD.

- **9 Boxes.** `box.gd`'s `SIZES` ({choices, picks}: small 3/1, big 5/1, huge 7/2) x
  `THEMES` (piece/artefact/item) replace `Shop.BOX_TYPES := ["item","artefact","score"]`
  (now `Shop.BOX_THEMES := ["piece","artefact","item"]`, still 2 slots each; each slot's
  size is rolled independently in `Shop.roll`). `SHOP_BOX_PRICE` became
  `{"small":50,"big":100,"huge":200}`, priced by size only.
- **Rolled at stock time, stored, revealed unchanged on open.** `Shop.roll` now calls
  `Box.roll_options(g, theme, size)` per Box slot and stores the result as an additive
  `contents` field (alongside a new `size` field) on the JSON-safe shop_stock slot.
  `game.gd`'s `_open_box_pick(slot: Dictionary)` sets `box_offer = slot.contents.duplicate(true)`
  — never a fresh roll. Proven directly in `test_shop.gd`: capture `shop_stock[bi].contents`
  before buying, buy, assert `game.box_offer == stocked_contents`; `test_save.gd` proves the
  same fields round-trip a save (additive, no migration, per `save_config.gd`'s policy).
- **Score Box and the mixed Box are gone.** `Tuning.SCORE_BOX_CHUNKS` deleted (its only
  reader was the old mixed-offer branch, which no longer exists). The untyped
  `_open_box_pick()`/`_box_options()` paths are gone too — every caller now passes a
  theme+size (a slot, or `Box.random_slot(g)` for a grant that just says "a Box" — Trojan
  Horse Assembly Manual's "open a free Box" hook in `artefact_hooks.gd`, which was calling
  the now-removed no-arg `_open_box_pick()` and needed fixing here to stay correct).
- **Carrier removed, all six call sites gone:** `wave_logic.gd`'s `entry.buff = true` +
  the board-spawn transfer, `game.gd`'s `boxed = victim.get("buff", false)` +
  `if boxed: return _open_box_pick()`, the `radar_jamming` item's `board[b].erase("buff")`,
  and the gold-badge `_draw` circle. `data/waves.gd`'s now-orphaned `BUFFS` dict (the data
  driving the carrier assignment) went with it, and `pass_after_box` (only ever set by the
  removed carrier-capture branch) is gone too. `item_logic.gd`'s radar_jamming targeting
  rule dropped its `buff` half (only real Piece Buffs are valid targets now) — not one of
  the six, but a direct, necessary consequence of removing the erase it used to promise.
  `save_config.gd`'s legacy `"buff"`-string board-config parse is deliberately UNTOUCHED —
  out of the six sites, harmless read-compat for an old save/scenario, and still exercised
  by `test_items.gd`'s ADR-0002 opaque-state test and `test_save.gd`'s round-trip.
- **Nostradamus Mad Libs and Huge compose.** `box_picks_left` now starts at
  `(native_picks - 1) + nostradamus_count`, so Huge (2 native) + 1 held copy = 3 total
  picks, asserted directly in `test_items_artefacts_3.gd` and `test_game_clicks.gd`.
- **`box_cost` still exactly once.** Unchanged single `Economy.charge` call site in
  `_open_box_pick`; `_box_reroll` never touches `Economy`. Same Tariff-held proof as
  issue 46, re-verified green.
- **Autoplay.** The bot never actually shops (no Shop-buying logic in `autoplay.gd`), so
  the full `--autoplay` CLI leg never opens a Box at all — completed clean (LOSS, wave 50,
  resource starvation, unrelated to this change). The modal-free resolution branch inside
  `_open_box_pick` is exercised directly instead: `test_items_artefacts_3.gd` boots with
  `autoplay=true` across many seeds for the extra-pick, reroll, and Huge-native-2-picks
  paths and asserts each resolves with `box_open == false` and no modal.
- **RNG-stream ripple, expected and handled.** Rolling every Box's contents at stock time
  means `Shop.roll` (called on every fresh boot) now consumes materially more of the RNG
  stream than before, shifting every downstream seeded draw. Caught by a full headless
  sweep of all 24 suites: two pinned assertions had to move to match the new deterministic
  output — `test_items_artefacts_1.gd`'s Holy Lint seed-4 roll (stun -> reflect, still a
  safe non-self-triggering pick, same reasoning as the original comment) and
  `test_tiers.gd`'s Tier-3+ box-grouping check (relabelled from the old item/artefact/score
  vocabulary to piece/artefact/item). No other suite was affected.
- **Split suites untouched** — all 7 `test_items*` files still present, still wired in
  `run_all.sh`, all green.
- **Verification:** `game/tests/run_all.sh` — windowed click probes (rewritten: Box UI is
  now reached via a Shop purchase, `test_game_clicks.gd`'s new `_buy_a_box` helper), all 24
  headless suites, and the autoplay leg — ALL GREEN, re-run alone (no contending Godot
  process) to rule out the contention flake CLAUDE.md warns about.

**Deferred, per spec:** subtheme Boxes (strategic-items, rarity-tier) — noted, not built.
