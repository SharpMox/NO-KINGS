# 53 — Two base-game caps, and four resolved ambiguities

Status: done (2026-08-29)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

Six Artefacts, each blocked on a one-line question rather than on machinery. The user
answered all six on 2026-08-29. **Two of them introduce base-game restrictions that do not
exist today** — those are the risky half of this slice and are listed first.

---

## The two new base-game caps

### Item held capacity — base 3

There is **no Item cap today**; the player can hold unlimited Items. Introduce one, base
**3** (user ruling).

- **Area 51 Parking Permit** (Common) — *"+3 Item held capacity"* — takes it to 6.
- **Denver Bunker Timeshare** (Uncommon) — *"While all your Item slots are full: +30% Gold
  gain"* — now has a reachable condition.

Decide and document what happens when a full inventory would gain another Item (Box pick,
Artefact grant, Shop purchase): refuse the acquisition, or force a discard? Refusing is
simpler and matches "capacity"; whichever you pick, the Shop must not let you *buy* an Item
you cannot hold.

### Piece Buff capacity — base 2

There is **no buff cap today**; `buff_logic.gd` appends freely. Introduce one, base **2**.

- **Abduction Probe** (Rare) takes it to **3**.

**Re-text Abduction Probe.** Its catalog line — *"Your pieces can carry 2 Piece Buffs at
once"* — was written assuming a base of 1. Under the user's ruling the base *is* 2, so the
text must become **"+1 Piece Buff capacity"** (2 → 3) or it describes the base game and does
nothing.

This is the one change here that **nerfs the existing game**: Buff Box, Holy Lint, Pied
Piper's Rat Census and every random grant can currently stack without limit. Applying a
3rd buff must fail cleanly and visibly — not silently no-op, and not crash. Check every
grant path, not just the Buff Box.

---

## The four resolved ambiguities

All four rulings are the user's; each was previously parked in `NOTION-QUESTIONS.md`.

### Spare Organ Receipt — Common

> On Fuse: refund 50% of the consumed piece's value as Gold

A Fuse consumes **two** pieces. Ruling: **50% of both combined**.

`merge_logic.gd`'s `commit_merge` has both ids in scope and `g.defs[id].value` gives each
value, so this needs a small hook at that point — the only new call site in this slice.

### 'Definitely Not Russia' Patch — Rare

> The first piece you lose each Wave doesn't count as a loss for your Artefacts and penalties

Ruling: it masks the loss from **everything** — one flag, no carve-outs. Every effect
reading `on_piece_lost` (Nibiru Hide-and-Seek Trophy's streak collapse, Frog Pride Flag's
arming, `lost_player`, `wave_lost_ids`) sees no loss.

**The piece is still lost** — this is *not* Fireproof Pajamas' `ctx.cancel`, which saves the
piece. It needs a second, distinct flag meaning "lost, but uncounted". Do not overload
`cancel`.

### Alien Pet Rocks — Common

> At Wave end: +2 Gold per allied piece that did not move this Wave

Ruling: **only moves you spent an Action on count as moving.** A piece that was Deployed
this Wave, or shoved by an effect (Royal Fiat's forced retreat, Tactical Reposition, Decoy
Swap, Rapid Deployment), still counts as "did not move" and still pays.

Needs a per-Wave "moved under its own steam" set, cleared on Wave clear.

## Acceptance

- All 6 `implemented: true` in `data/artefacts.js`; **Abduction Probe re-texted**; exported
  via `node tools/export-game-artefacts.mjs`.
- Item cap 3 enforced on every acquisition path, and unbuyable Items are not purchasable.
- Buff cap 2 enforced on every grant path — Buff Box, random grants, artefact grants — and
  a refused 3rd buff fails cleanly and visibly.
- Assert the caps **bind**: a 4th Item and a 3rd buff are actually refused, and the
  Artefacts genuinely raise them.
- Alien Pet Rocks: assert a deployed piece and a force-moved piece both still pay.
- 'Definitely Not Russia' Patch: assert the piece is gone **and** that a loss-reading effect
  (Nibiru's streak) did not react.
- Tests in the split suites, seeds pinned. `run_all.sh` ALL GREEN, foreground.

## Blocked by

- nothing

## Outcome

All 6 shipped `implemented: true`, exported via `tools/export-game-artefacts.mjs`.

**Item capacity (base 3, `Tuning.ITEM_CAP_BASE`).** `item_logic.gd` gained `cap(g)`
(base + 3 per held Area 51 Parking Permit, additive), `has_room(g)`, and `grant(g, item)` —
the single choke point every acquisition path now routes through. **A full inventory
refuses the acquisition** (drops it, no discard prompt) — simpler and matches "capacity",
per the issue's own steer. Audited and converted every `g.items.append(...)` site: Box pick
(`game.gd _box_choose`), Yalta Cocktail Napkin's own pick, and 8 artefact grants in
`artefact_hooks.gd` (Frame 25, Manna Vending Machine, Mao's Loyalty Badge, Flight 19
Blackbox, 33rd Degree Fidelity Card x2, Defense Lobbyist Business Card, Fort Knox IOU).
Left untouched, deliberately: `shop.gd`'s own `g.items.append` (now provably unreachable at
capacity — `Shop.can_buy` gates every item-kind slot on `ItemLogic.has_room`, so **the Shop
never sells an Item you can't hold**) and `save_config.gd`'s load path (restoring saved/
scenario state is not an "acquisition").

**Piece Buff capacity (base 2, `Tuning.PIECE_BUFF_CAP_BASE`).** `buff_logic.gd` gained
`cap(probes)` and `catalogued_count(piece)` (counts only `Items.PIECE_BUFFS` entries —
excludes `stunned`, the debuff riding the same list). Every Piece Buff grant already funneled
through one choke point (`game.gd _apply_buff`, built in issue 23) except the 2 `stunned`
call sites, which correctly stay outside the cap. A refused 3rd buff **fails cleanly and
visibly**: `_apply_buff` returns before `BuffLogic.add` and before `on_buff_apply` fires (no
partial state, no hook to react to nothing), and floats a "Buffs full" label at the piece's
tile — the same `_add_float` idiom as "Blocked"/"Stunned!" (silent only when the grant target
has no tile, e.g. a Stock landing; still refused cleanly either way).

**'Definitely Not Russia' Patch** masks via a *second* flag, `ctx.uncounted`, decided
**before** `on_piece_lost` dispatches (a structural read in `_lose_player_piece`, not a
REGISTRY-dispatched handler) — because the hook's handlers run in one key-sorted pass, a
flag set *during* dispatch would only be visible to whichever handlers happen to sort after
it. Audited and gated all 12 other `on_piece_lost` listeners on `not ctx.uncounted`
(satoshi's-private-key, lusitania-hardtack-crate, templar-severance-gold-one-pile,
d-b-cooper's-parachute, nibiru-hide-and-seek-trophy, flight-19-blackbox, backmasked-vinyl,
tutankhamun's-death-thong, kgb-photo-eraser, hoffa's-cement-shoes, 27-club-punch-card,
frog-pride-flag) — every one **except** fireproof-pajamas, whose `ctx.cancel` decides
whether there's a loss at all, a question upstream of masking an already-real one (per the
ruling: this is NOT `cancel`, the piece is still gone).

**Spare Organ Receipt** added the slice's one new call site: `on_fuse`, fired from
`merge_logic.gd`'s `commit_merge` for every merge (Rank Up or Fusion alike — "a Fuse
consumes two pieces" draws no distinction, and both ids are in scope regardless of which
branch ran).

**Alien Pet Rocks** stamps `moved_wave` on a piece at the exact 2 sites `game.gd
_move_player` already marks `moved_this_turn` — the only places an Action was genuinely
spent moving/capturing. A Deploy (`_place`) and the 3 shove items (Tactical Reposition,
Decoy Swap, Rapid Deployment — all resolved in `_item_apply`, never through `_move_player`)
never reach those sites, so they correctly still pay; Royal Fiat's forced retreat rides the
same `_move_player` call as the capture that already earned the piece its stamp.

**Existing-game fallout from the new caps** (found by running the full suite, not guessed):
`mRNA Firmware Update`'s test applied 3 "shield" buffs to the *same* piece to test its
"every 3rd apply Ranks Up" counter — now capped at 2, so it was rewritten to apply to 3
*different* pieces (the counter is run-wide, not per-piece, so the mechanic itself is
unchanged). A 5-Wave-Milestone timing test used Manna Vending Machine's Item grants (2 per
copy, 2 copies = 4 total) as a countable side effect; 4 now exceeds the base Item cap, so
the test holds Area 51 Parking Permit too (cap 6) — a scope fix to the test's own
instrumentation, not to the milestone logic it's actually testing.

**Holy Lint's pinned seed (test_items_artefacts_1.gd) did NOT move.** The buff cap check
runs in `_apply_buff`, after `_random_buff_key` has already drawn its key — a refusal never
re-rolls, so the RNG stream is untouched regardless of whether the grant lands. Verified by
running the suite: the seed-4 assertion ("shield") passed unchanged.

`run_all.sh` (click probes + all 27 headless suites + full autoplay), foreground, final
line: `ALL GREEN`.
