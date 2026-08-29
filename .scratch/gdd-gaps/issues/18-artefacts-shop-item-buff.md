# 18 — Artefacts: Shop, Item & Buff

Status: closed (2026-08-29) — remainder redistributed to issues 52-55
slice; see Outcome)

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

Three tags that hang off systems built in earlier slices: **Shop (13)**, **Item (12)**,
**Buff (19)**.

- **Shop** — price modifiers, extra slots, forced rerolls. The GDD Shop page already names
  several by name (Chocolate Key Cake +2 Item slots, Alleged Weather Balloon +1 Item slot,
  Sub-Antarctic Visa +1 hidden Artefact slot, Denazification Visa −50% on Tactical Items,
  Hollow Moon Cross-Section −25% on Artefacts, Shrinkflation Cereal Box +50% on
  everything, Skull and Bones Coffin +5% while rich, Jet Fuel Vial forces a reroll).
  ⚠️ This is the slice that finally needs the **"base + modifiers" slot pass** that slice
  02 of the shop work deliberately deferred "until an Artefact needs it". One does now.
- **Item** — held-item capacity, extra rolls, tier upgrades.
- **Buff** — **unblocked by slice 04**: these grant Piece Buffs directly. *Crop Circle
  Plank* gives 2 random allied pieces +1 buff on a 5-Wave milestone; *MK-Ultra Sugar Cube*
  buffs the piece you deploy. `BuffLogic.add` is the whole API they need.

Note the GDD's own vocabulary ruling: **"Shop visit" is not a term.** Six artefact texts
used it before the Shop page existed and were re-texted onto **per restock**. Anything
still saying "visit" is stale text, not a mechanic.

## Acceptance criteria

- [x] Every no-prerequisite Shop/Item/Buff artefact implemented and flagged
      — 15 of 23 no-needs-note Shop/Item/Buff artefacts, +3 whose "needs:
      shop layout change" note this slice itself resolved, +2 Score-tagged
      artefacts the issue named explicitly; see Outcome for the 8 held back
- [x] Shop slot counts become base + modifiers; the stock still fits without scrolling
- [x] Price modifiers compose per the slice 15 stacking rule
- [x] Buff-granting artefacts go through `BuffLogic.add`, not a parallel path
- [x] No implemented artefact text says "Shop visit"
- [x] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine
- 04 — Piece Buffs (done) for the Buff tag
- 08 — Shop drawer UI, if the slot changes need the new layout

## Outcome (2026-08-28)

**20 artefacts flipped to `implemented: true`** this slice, key-for-key via
`tools/export-game-artefacts.mjs`'s slugify, wired into
`game/scripts/artefact_hooks.gd`:

**Shop (8):** Denazification Visa, Hollow Moon Cross-Section, Shrinkflation
Cereal Box, Skull and Bones Coffin, Chocolate Key Cake, Alleged Weather
Balloon, Sub-Antarctic Visa, Silk Road Coupon.
**Buff (8):** Crop Circle Plank, MK-Ultra Sugar Cube, Obedience-Flavored Tap
Water, Holy Lint, Scientology E-Meter, Xenu OT III Season Pass, Sugar Free
Chemtrail Can, Sleeper Agent Pillow.
**Item (4):** Frame 25, Manna Vending Machine, Mao's Loyalty Badge, Majestic
12 Secret Handshake Diagram.

Of the 44 Shop(13)/Item(12)/Buff(19)-tagged artefacts: 1 was already
implemented pre-slice (Putin's Golden Toilet Brush, slice 16 — it also
carries the Shop tag), 18 of the above 20 carry one of these three tags
(**19 of 44 now implemented**), and 2 (Shrinkflation Cereal Box,
Skull and Bones Coffin) are tagged Score/Gold/Time — outside that count —
but the issue explicitly named both as Shop price-modifier artefacts to
land this slice, so they're included in the 20.

### The two things this slice specifically had to build

1. **Shop "base + modifiers" slot pass** (shop-drawer-ui/08's deferral).
   `Shop.roll()` still starts from `ROWS`' base counts, then adds
   `_extra_item_slots(g)` (Chocolate Key Cake +2, Alleged Weather Balloon +1
   Tactical-only — additive per held copy) and `_extra_artefact_slots(g)`
   (Sub-Antarctic Visa +1 hidden, `biased: true`, +50% price). The hidden
   slot's "one rarity higher" reads as: exclude the lowest rarity present in
   the rollable pool, sample the rest — the normal 4-slot roll isn't
   rarity-weighted at all, so there's no baseline roll to be "one higher"
   than; `game/data/items.gd` now carries `rarity` on every
   `ARTEFACT_EFFECTS` entry to make this possible (empty string for the 7
   core keys, which predate rarity entirely).
   **Verified with a screenshot** at max stacking (2x Chocolate Key Cake + 1x
   Alleged Weather Balloon = +5 Item slots, 2x Sub-Antarctic Visa = +2 hidden
   Artefact slots): all 9 Item tiles and 6 Artefact tiles render fully inside
   the drawer with the detail dock still visible — no clipping, no scrolling
   (slice 08's grouping is generic by `slot.kind`, so it absorbed the extra
   rows with no UI code changes).
2. **Shop price modifiers.** `Shop.price()` computes the row's base price,
   then runs a new `on_price` hook (ctx = `{base, amount, kind, tier}`) —
   same immutable-base/additive-amount contract as `on_score_change` (slice
   15/16), so two Denazification Visas stack to -100% (item free, not
   -75%), and two different artefacts' modifiers (Hollow Moon -25%,
   Shrinkflation +50%) compose off the same base too. Skull and Bones
   Coffin's own +5% recomputes live off `g.gold` each call, so its "while
   holding 200+ Gold" score bonus and its price both track the run's current
   gold with no extra state.

### Engine additions (each a single call site, REGISTRY + `match` case only
after this)

- `on_deploy` (`game.gd:_place`, PLAYER_TURN branch only — not SETUP
  placement) and `on_turn_end` (`game.gd:_on_pass`, mirrors the existing
  `on_turn_start` call) are new hooks with real call sites.
- `on_capture` ctx grew `attacker_pos` (`Economy.capture_score`'s new 4th
  param, `Vector2i(-1,-1)` default) — the attacker's board position while
  still intact, so a handler can grant something to the actual attacking
  piece (Obedience-Flavored Tap Water, Holy Lint) instead of just reading
  its id.
- **"5-Wave Milestone" is a different cadence than the engine's own
  `on_milestone` hook**, which fires every `Tuning.MILESTONE_WAVES` (10)
  waves — a real mismatch the GDD text (12 effect texts) doesn't share.
  Rather than touch that tuning value (a balance change well outside this
  slice), every "5-Wave Milestone" artefact here (Crop Circle Plank, Silk
  Road Coupon, Sugar Free Chemtrail Can, Manna Vending Machine) hooks
  `on_wave_clear` (already wired, slice 16) and checks `g.wave % 5 == 0`
  itself, reading the just-cleared wave number before `WaveLogic.queue`
  overwrites it.
- Buff grants all route through a shared `_grant_buff`/`_grant_buff_to` pair
  in `artefact_hooks.gd` — `BuffLogic.add(piece, random_key, turns)` — never
  a parallel path. `_grant_buff_to` takes a raw Dictionary so it also works
  on Sleeper Agent Pillow's not-yet-placed piece (see below).
- `Economy.capture_score`, `Box.roll_options` (new `allowed_tiers` param for
  Majestic 12) and `game.gd:_box_options` (reads `g.artefacts` directly,
  same pattern as `Shop.buy` reading `slot.kind`) all stayed additive —
  every existing caller works unchanged.

### Notable implementation calls

- **Sleeper Agent Pillow** — the bought piece is a plain id string appended
  to `g.stock` by `Shop.buy` a line before `on_purchase` fires. The handler
  replaces that last stock entry with a `{"id": ...}` Dictionary carrying
  the buff; `_place`'s existing `entry is Dictionary` branch already merges
  extra fields onto the board piece, so no new code path was needed there.
- **Scientology E-Meter / Xenu OT III Season Pass** — "the piece" gets a
  Piece Buff at Wave clear, but Wave clear has no single trigger piece.
  Read as a random ally (documented in the handler); Xenu's "+3 Piece
  Buffs" is 3 independent random-ally picks, which may repeat a piece.

### Held back (8) — Shop/Item/Buff, no needs-note, still not shipped

- **Buff Box choice-count changes** (Numbers Station Sudoku: 4 choices for
  5 Gold each instead of 3; Bohemian Grove Friendship Bracelet: 5 choices) —
  `_open_buff_pick` hardcodes "3" and has no gold-per-pick concept; a real
  UI + logic change, not a hook case.
- **"On Rank Up"** (Holy Grail Coaster) — no hook exists for the Promote
  item resolving; would be a 15th hook for one artefact.
- **Hooking `BuffLogic.consume`** (Youth Fountain Martini: re-apply the
  first buff consumed each Wave) — consume() has many scattered call sites
  (every dormant buff's resolution), no single choke point, same shape as
  slice 16's `on_piece_lost` gap.
- **`on_piece_lost`** (Flight 19 Blackbox: +1 Item on losing a piece) — the
  same unresolved gap slice 16 documented (~5 scattered sites in `game.gd`).
- **"First Item use each Wave, not consumed"** (Dihydrogen Monoxide
  Battery, Wardenclyffe AAA Batteries) — `items.remove_at` has 3 call sites
  in `game.gd` (instant items, and two for targeted items), no single choke
  point; would also need a new per-wave "already used free" flag.
- **Mar-a-Lago Toilet Papers** ("a random Shop item becomes free; all other
  Shop prices +10%") — genuinely stateful (which slot stays free across a
  restock?) and underspecified whether the +10% stacks per milestone,
  forever, or resets — held back rather than guess, per slice 16's
  no-half-implementation precedent.

Still `(needs: ...)`-flagged, unchanged, deferred to slice 19 (17 more
Shop/Item/Buff artefacts): Area 51 Parking Permit, Fort Knox IOU,
Pre-Scratched Lottery Ticket, Frog Pride Flag, Pandemic Toilet Paper Pallet,
mRNA Firmware Update, Jet Fuel Vial, Denver Bunker Timeshare, Zodiac
Crossword Puzzle, KGB Photo Eraser, Antikythera Warranty Card, 33rd Degree
Fidelity Card, Agartha Welcome Mat, Pied Piper's Rat Census, Abduction
Probe, Defense Lobbyist Business Card, Templar Debit Card.

### "Shop visit" check

None of the 20 implemented artefacts use the retired "Shop visit" term
(verified by scanning `data/artefacts.js` for `implemented: true` entries).
Two still-unimplemented artefacts still carry it in stale text (Pandemic
Toilet Paper Pallet, Jet Fuel Vial) — both already `(needs: ...)`-flagged
and out of this slice's scope; re-text when their prerequisite lands.

### Tests

`game/tests/test_shop.gd` gained coverage for the slot pass (2x Chocolate
Key Cake + 1x Alleged Weather Balloon + 1x Sub-Antarctic Visa: exact extra
counts, the hidden slot's `biased` flag and +50% price) and price
composition (two Denazification Visas clamp a Tactical Item to 0 gold and
leave other tiers alone; Hollow Moon + Shrinkflation compose additively on
an Artefact). `game/tests/test_items.gd` gained coverage for Crop Circle
Plank (fires at wave 5, not wave 6; grants exactly 2 buffs; -10 Gold), MK-
Ultra Sugar Cube (on_deploy grants a Tactical buff), Holy Lint (a real
board capture threads `attacker_pos` end to end), Frame 25, Sleeper Agent
Pillow (buy → stock Dictionary → deploy, buff survives both hops),
Shrinkflation Cereal Box's new `on_turn_end` hook, Skull and Bones Coffin's
gold-gated Score bonus, and Majestic 12's Item Box tier filter (mixed Box
Pick unaffected). `game/data/scenarios.gd` gained "Artefacts: Shop/Item/Buff
batch (issue 18)" holding 8 of the 20, swept by `test_scenarios`.

`game/tests/run_all.sh` (full, with the windowed click probes) is ALL
GREEN. Two headless-only runs flaked under heavy concurrent-agent CPU
contention on this machine (a different check failed each time, always
passed in isolation); with a quiet system the full suite passed twice
consecutively, including the click probes.

## Closed 2026-08-29

This was an umbrella tracking slice (19 of 44 at its last count). Every Artefact it still listed
as outstanding now has a specific home in issues **52-55**, which between them cover all 22
remaining unimplemented Artefacts with the user's rulings attached.

Tracking progress by these thematic umbrellas stopped being useful once the remainder was
small enough to enumerate directly. Kept for history; do not work from this file.
