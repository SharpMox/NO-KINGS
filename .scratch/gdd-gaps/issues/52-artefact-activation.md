# 52 — Artefact activation, and the 7 Artefacts that need it

Status: done (2026-08-30)
inversion, is left)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

Every Artefact in the game today is **passive** — it listens on a hook and modifies a value.
Seven catalog entries instead say "on use" or "you may pay", which needs something that does
not exist: a way for the player to *activate* an Artefact on demand.

This one seam unblocks more Artefacts than any other remaining decision.

## The activation affordance (user rulings)

Three entry points, all reaching the same activation:

1. **Click the Artefact in the list.** The primary route.
2. **A dedicated section in the Items menu for activatable Artefacts** — so an available
   activation is discoverable rather than something you must remember you own.
3. **Jet Fuel Vial gets a Restock button in the Shop**, appearing *only* while it is held.
   It does not belong in the in-run activation UI; it is a Shop control.

**Activation costs no Action** (user ruling). Items cost 1 Action by default; Artefact
activation is free, and each Artefact's own once-per-Turn / once-per-Wave / consumed limit
is what gates it. FIFA Complimentary Yacht is the deliberate exception with no limit at all,
which is what makes it Legendary.

An Artefact with no activation available (already used this Turn, not yet recharged, cannot
afford the cost) must be visibly unavailable rather than silently inert.

### Confirm vs cancel — the rule (user ruling 2026-08-29)

> Confirm when the action has **no target**. When it *does* have a target, the targeting
> step is the pause, and it needs a way to cancel.

So every activation gives the player exactly one chance to back out, but never two:

| Artefact | Has a target step? | Back-out |
| --- | --- | --- |
| Oak Island Wishing Well | no | **Confirm** |
| FIFA Complimentary Yacht | no | **Confirm** |
| Moscovium Glow Stick | no | **Confirm** (also the only consumable) |
| Zapruder's Director's Cut | no | **Confirm** |
| Roanoke Hex Kit | no — it auto-picks the strongest enemy | **Confirm** |
| Jet Fuel Vial | no | **Confirm** (in the Shop) |
| Bovine Tractor Beam | yes | **No confirm** — cancel from targeting |

Note this *overrides* the "no confirm" recommendation in the original mock. The reasoning
that changed it: an untargeted activation resolves the instant you press it, so the press
is the only moment a mis-tap can be caught. A targeted one already has a second beat.

**The Clock keeps running through the confirm**, like every other modal (Buff Box, Box
Pick, the choice seam). Nothing here pauses it.

**Cancelling costs nothing** — no Gold, no charge, no Action. A cancelled activation must
leave the Artefact exactly as it was, including its once-per-Turn/Wave charge. Assert that
explicitly; a cancel that silently burns the charge is the kind of bug players notice and
tests miss.

### The Activate section hides when empty (user ruling 2026-08-29)

Most runs hold none of these seven. An empty "Activate" header would cost a row in a drawer
that deliberately does not scroll, so when the player holds no activatable Artefact the
drawer looks exactly as it does today.

## The seven

| Artefact | Rarity | Effect | Notes |
| --- | --- | --- | --- |
| **Oak Island Wishing Well** | Rare | Once per Turn: you may pay 25 Gold for +400 Score | Simplest — build first |
| **FIFA Complimentary Yacht** | Legendary | You may spend 50 Gold to gain +1 Action, any number of times per Turn | No limit, by design |
| **Moscovium Glow Stick** | Rare | On use: until end of Turn, Score and Gold gains are tripled; this Artefact is consumed | First **consumable** Artefact — it leaves `g.artefacts` on use |
| **Roanoke Hex Kit** | Rare | On use: the strongest enemy piece vanishes, paying no Score or Gold; recharges at every 2nd 5-Wave Milestone | "Vanishes, paying nothing" is `_destroy`-shaped, not a capture |
| **Zapruder's Director's Cut** | Legendary | Once per Wave: repeat your previous Action without spending an Action | Needs a last-Action record |
| **Bovine Tractor Beam** | Legendary | Once per Wave: move one enemy piece anywhere on your side of the Board | Needs two-step targeting |
| **Jet Fuel Vial** | Common | Once per Shop visit: pay 20 Gold to restock the Shop | Shop button, see re-text below |

### Re-text Jet Fuel Vial

Its catalog text — "pay 20 Gold to bring the Shop's whole stock down; it is rebuilt fresh" —
is a convoluted way of saying **restock the Shop** (user, 2026-08-29). Re-text it to
something plain: *"Once per Shop visit: pay 20 Gold to restock the Shop."* Same behaviour,
readable.

## Things that will bite

- **Moscovium Glow Stick is the first consumable Artefact.** Removing an entry from
  `g.artefacts` mid-run is new; check nothing caches the list across the removal, and that
  a held *duplicate* is unaffected. Its "gains tripled until end of Turn" is a multiplier —
  per `artefact_hooks.gd`'s header a multiplicative effect is a **deliberate, called-out
  exception** to additive stacking, so write it as one.
- **Bovine Tractor Beam needs targeting**, which is item-shaped (`"pair"` targets in
  `items.gd`), not artefact-shaped. Reuse the item targeting flow rather than inventing a
  second one.
- **Zapruder's needs to know your previous Action.** `_log_action` exists; check whether it
  records enough to replay, and say so if it does not rather than half-replaying.
- **Roanoke's "recharges at every 2nd 5-Wave Milestone"** rides the per-copy
  `_milestone5_hit` cadence (issue 28) — every *second* hit, counted per held copy.
- **Autoplay** must exercise activation without hanging: the bot should sometimes activate.
  Silent never-activating is a passing test that proves nothing.

## Acceptance

- All 7 `implemented: true` in `data/artefacts.js`, texts corrected, exported with
  `node tools/export-game-artefacts.mjs`. Never hand-edit the JSON.
- Activation reachable from the Artefact list **and** the Items-menu section; Jet Fuel Vial
  only from the Shop.
- Activation costs 0 Actions — assert it directly.
- Each per-Turn / per-Wave / consumed limit enforced, and unavailable states visible.
- **The six untargeted Artefacts confirm; Bovine Tractor Beam does not and cancels from
  targeting instead.** Assert both shapes.
- **A cancelled activation costs nothing** — assert Gold, the charge and the Artefact itself
  are all untouched, for both the confirm path and the targeting path.
- **The Activate section is absent entirely when no activatable Artefact is held** — assert
  the drawer is unchanged from today in that case.
- **Click probes extended** — this is new interactive UI, and Godot headless drops GUI
  picking, which is why `run_all.sh` runs the windowed probes first.
- Tests in the split suites, seeds pinned, asserting observable behaviour.
- `game/tests/run_all.sh` ALL GREEN, run in the **foreground**.

## Suggested split

This is large. If it wants splitting, the seam plus Oak Island Wishing Well and FIFA
Complimentary Yacht (both pure gold-spends, no targeting, no consumption) is a clean first
half; Moscovium, Roanoke, Zapruder, Bovine and Jet Fuel Vial follow on the built seam.

## Blocked by

- nothing

## Outcome

Shipped whole, not split — the seam and all 7 landed together. All 7 flipped to
`implemented: true` in `data/artefacts.js` (172 -> 179/180; only SETI's Red Marker is
left, blocked by issue 22's dormant tariff-inversion question), exported with
`node tools/export-game-artefacts.mjs`.

- **The affordance is deliberately NOT the ArtefactHooks REGISTRY/run() engine.** That
  engine dispatches automatically to every HELD copy on a hook; activation is "the player
  picks WHEN, for one use" — a different shape, and (Moscovium) one that must keep
  working after the artefact consumes itself and leaves `g.artefacts`, when there is no
  held copy left for `run()` to find. All 7 keys (plus Jet Fuel Vial) are documented
  exceptions in `test_items_artefacts_4.gd`'s REGISTRY-coverage guard, same shape as the
  standing-rule reads several passive Artefacts already use. `game.gd` owns the whole
  mechanism: `_artefact_activation_available`/`_activate_artefact`/`_artefact_confirmed`
  for the 6 in-run keys, `_jet_fuel_restock_available`/`_jet_fuel_restock_pressed`/
  `_jet_fuel_restock_confirmed` for the Shop-only 7th.
- **Confirm/cancel** rides the existing generic choice-pick seam (`_open_choice_pick`,
  issue 41) — a 1-option "Confirm" + a "Cancel" that runs an invalid `Callable()` (nothing
  to undo, since the effect body lives entirely in the chosen-callback). Bovine Tractor
  Beam skips it and reuses the Item targeting FLOW instead (staged picks, board-click
  routing via a new `artefact_targeting_key`/`artefact_target_stage_a`/`artefact_targets`
  trio paralleling `item_active`, tap-the-chip-again-mid-targeting to cancel) — not a
  second targeting system.
- **Moscovium Glow Stick's "gains tripled"** is the deliberate multiplicative exception
  the header calls for, applied directly in `Economy.earn()` off a standing
  `g.moscovium_active` flag (reset in `_begin_player_turn`) rather than any hook — scoped
  to each call's own base gain, not the cross-resource `gold_bonus`/`score_bonus`
  converter payments. Verified safe with Ecdysis Sheddings (issue 55): Moscovium has no
  REGISTRY entry, so `REGISTRY.get("moscovium-glow-stick", [])` is empty and Ecdysis's
  meta-trigger mirror of it is an inert no-op — no crash, no double-consume.
- **Roanoke Hex Kit's "every 2nd 5-Wave Milestone"** is computed live, no stored "charged"
  flag: a per-copy `roanoke_used_count` (on the held entry itself, ADR-0002-shaped runtime
  field, not round-tripped through `save_config.gd` — an accepted existing gap, same as
  the other per-artefact run-long counters that already aren't) plus the copy's own
  `acquired_wave` gives a deterministic target wave, `acquired_wave + 10*(used+1) - 1`.
  "Vanishes, paying nothing" reuses `_destroy` (Destruction, not Capture — CONTEXT.md).
- **Zapruder's Director's Cut** — `_log_action` only ever recorded `{kind}` (issue 30),
  not enough to replay a Deploy/Merge/Item. Rather than half-replay those, the plain
  move/capture call site in `_move_player` now also stamps `{from, to}` (`to` = the
  piece's actual final resting tile, not a mid-flight one a repositioning artefact moved
  it off of again); "repeat" extends that same displacement vector once more from the
  piece's current position and replays it through `_move_player` itself, so every rule
  (legality, buffs, bombs, scoring) re-runs normally. `blitz_free_move` (already reused
  once for Pegasus Free Trial) skips the Action cost. Bomb/Trap/blocked-attack captures,
  Deploys, Merges and Items carry no `{from, to}` and so are correctly reported
  unavailable — not a guess, a documented scope line.
- **Jet Fuel Vial** re-texted to "Once per Shop visit: pay 20 Gold to restock the Shop."
  "Shop visit" resolves to the existing `_open_shop()` boundary issue 45 already
  established for Pandemic Toilet Paper Pallet. Its Restock button lives in the Shop
  panel (`modals.gd`), visible only while held, confirm-gated like the other 6.
- **The Activate section** is one new row (`hud.gd`'s `activate_box`) between the held-
  items strip and the (now activatable-keys-excluded) passive Artefact list — the same
  widget satisfies both "click it in the list" and "a dedicated section in the Items
  menu" rulings, since this codebase's single Inventory drawer already holds both Items
  and Artefacts and there is no second menu to put a distinct copy in. Empty, the row has
  zero children and the drawer's `custom_minimum_size` stays at today's height
  (`INV_H_BASE`); holding one, both grow (`INV_H_ACTIVATE`) — resized live in
  `hud.refresh()`, not baked in at `build()` time.
- **Activation costs 0 Actions** — asserted directly. Every once-per-Turn/Wave/Shop-visit
  charge, and every cancel-costs-nothing path (both the confirm shape and the targeting
  shape), is asserted explicitly in `test_items_artefacts_4.gd`.
- **Click probes extended** (`test_game_clicks.gd`): the Activate chip, its confirm modal,
  Bovine's two-stage targeting and its mid-targeting cancel, and the Shop's Restock button
  (including its disabled-once-used state) are all driven with real synthetic clicks.
- **Autoplay** tries a random held activatable key every frame (25% chance, 0 Actions so
  it doesn't compete with the move/item/merge branches) — the 5 confirm-gated keys bypass
  the modal exactly like every other autoplay choice-pick; Bovine drives both targeting
  stages directly, the same way `use_item` already drives a "pair" Item. Verified with a
  pinned-seed direct-`AutoplayBot.step()` loop (not just the CLI smoke run) asserting an
  actual activation happens, plus two new scenarios in `data/scenarios.gd` swept by
  `test_scenarios.gd`.
- Tests split across `test_items_artefacts_4.gd` (all 7 files kept, no new one) + the
  extended click probes; seeds pinned. `game/tests/run_all.sh` ran foreground, alone:
  `ALL GREEN`.

## Outcome

Shipped in PR #190. Catalog **172 -> 179 / 180** — only SETI's Red Marker remains, deferred
on question 10's Tariff-inversion problem.

**Architecture:** activation lives deliberately *outside* `artefact_hooks.gd`'s
REGISTRY/`run()` engine, which exists for "every held copy fires automatically on a hook".
This is player-triggered, so `game.gd` owns its own dispatch
(`_activate_artefact`/`_artefact_confirmed`/`_jet_fuel_restock_*`), recorded as 7 documented
REGISTRY exceptions in `test_items_artefacts_4.gd`'s coverage audit.

**Drawer:** with no activatable Artefact held the Inventory drawer is byte-for-byte today's
`INV_H_BASE = DRAWER_H * 2 + 70` (206px, y=594). Holding one adds an `activate_box` row and
grows it to `INV_H_ACTIVATE = DRAWER_H * 3 + 70` (274px, y=526), resized live in
`hud.refresh()` rather than baked in at build time.

**Cancel costs nothing**, verified on both shapes: the confirm path keeps the entire effect
body inside the Confirm callback, so nothing is paid before the choice; the targeting path
(Bovine) resets `artefact_targeting_key` without ever reaching the line that sets
`bovine_used_this_wave` or touches the board.

### Two scope decisions worth revisiting

**1. "A section in the Items menu" and "click it in the list" collapsed into one widget.**
The user asked for both. This codebase has a single Inventory drawer holding Items *and*
Artefacts, and the only other menu is the pause menu — which **pauses the Clock**, and so
directly contradicts the ruling that nothing about activation pauses it. One Activate row
inside the existing drawer serves both entry points. A narrowing of the request, made
explicitly rather than silently, and cheap to revisit if a second surface is wanted.

**2. Zapruder's Director's Cut only repeats moves and captures.** `_log_action` recorded
only `{kind}` — not enough to replay a Deploy, Merge or Item use. Rather than half-replay
them, the move/capture site now also stamps `{from, to}` and "repeat" extends that same
displacement vector once more through `_move_player` (full legality, buffs and scoring),
with the Action cost skipped via `blitz_free_move`. Deploys, Merges, Items and
Bomb/Trap/blocked captures carry no `{from, to}` and are correctly reported unavailable.

So the card reads "repeat your previous Action" but does nothing after a Deploy or an Item
— a player will notice. Either re-text it, or extend `_log_action` to carry enough state for
the other action kinds. **Not a defect in this slice; a known limitation of an ambiguous
card, chosen over guessing.**

**Moscovium x Ecdysis, closed by construction.** Moscovium's tripled-gain flag is a standing
bool read in `Economy.earn`, not a REGISTRY entry — because the effect has to keep working
after the Artefact consumes itself and leaves `g.artefacts`. Having no REGISTRY entry also
makes Ecdysis Sheddings' mirror of it an inert no-op rather than a crash or double-consume,
which is the interaction issue 55 left live. Asserted directly.
