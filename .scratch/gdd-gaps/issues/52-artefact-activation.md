# 52 — Artefact activation, and the 7 Artefacts that need it

Status: todo — SPECCED (user rulings 2026-08-29) · **the biggest remaining unblock**

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
