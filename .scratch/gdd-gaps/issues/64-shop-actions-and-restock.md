# 64 — Shop interactions cost no Action; two-lane restock

Status: todo — SPECCED (user rulings 2026-08-30) · one number open

## Parent

`.scratch/gdd-gaps/PRD.md`

Two changes to the Shop, both user rulings.

---

## 1. No Shop interaction costs an Action

**Every Shop interaction is free.** Buying, selling and Captured-Stock conversion all stop
consuming an Action.

Today they all consume one:
- `Shop.buy` — `g.actions_left -= 1` (`shop.gd:288`), and `can_buy` also gates on
  `actions_left >= 1`
- Selling and converting (issue 60) — pattern-matched to `buy`, so they charge one too

**Remove the spend from all three, and remove the `actions_left >= 1` gate** — a gate that
requires an Action you no longer spend is just a hidden cost with no payment. Keep the
`State.PLAYER_TURN` gate; the Shop is still a turn-time activity.

> The user's exact words: *"shop interactions do not use an action"* and, on selling,
> *"Selling is also free, it was a typo from me"* — confirming both halves after an ambiguous
> first phrasing. No Shop interaction of any kind costs an Action.

**Consequence to keep in mind, not to guard against:** with buying free, the buy/sell loop
around Deep State Yearbook and Mao's Loyalty Badge loses its Action brake. It stays bounded by
the things that actually bound it — `not slot.sold` (4 Artefact slots, 4 Item slots per stock)
and Score-gated restocks — plus the Artefact cap of 5, which makes Deep State Yearbook's
maximum payout 20 Gold against a 50-Gold minimum price, i.e. a guaranteed loss per cycle.
The analysis holds without the Action cost. **Re-assert the no-net-gain tests from issue 60**
so that stays true rather than assumed.

---

## 2. Shop restock becomes two lanes

Currently restocks are purely Score-threshold driven (`Shop.threshold(n)` =
1000 / 2500 / 4500 / 7000), which issue 57 made reachable. The user wants a second, guaranteed
lane so restocking is never purely a function of scoring well.

**Lane A — every 5 Waves, first at Wave 5.** Waves 5, 10, 15, … Guaranteed, independent of
Score.

**Lane B — Score between milestones.** Scoring **X** Score since the last Lane-A restock also
triggers one. **The Lane-B progress resets on every Lane-A restock** — so a wave-5 restock
wipes whatever progress had accumulated toward the score lane.

**Show a progress bar** so the player can see Lane B filling.

### The open number: what is X?

The user wrote "X(?)" — genuinely undecided. **Do not guess silently.** Some grounding, now
that issue 57's ×10 has landed:
- Post-×10 autoplay full runs score **68,700 / 75,200 / 72,800**; a wave-9 loss scored 2,800.
- The existing threshold curve is 1000 / 2500 / 4500 / 7000, i.e. rising.
- Five Waves is a meaningful chunk of a run — a run reaching Wave 45 sees ~9 Lane-A restocks.

X wants to be small enough that a *good* five waves earns a bonus restock, and large enough
that it is not automatic. Propose a value with the arithmetic behind it and get it confirmed
before building — this is a tuning number and the user has been explicit that they want to
tune with real levers in place.

### Also decide

- **Does Lane A replace the existing Score-threshold curve, or sit alongside it?** The user
  described Lane B as "scoring X in between those milestones", which reads as **replacing** the
  old `threshold(n)` curve with a simpler reset-on-milestone counter — not stacking a third
  mechanism on top. Confirm before building; `Shop.threshold`/`maybe_restock`/`shop_restocks`
  and the save field all hang off the current model.
- **What happens to `shop_restocks`**, which currently counts banked thresholds and is
  persisted in the save.

## Acceptance

- No Shop interaction costs or requires an Action; `PLAYER_TURN` gating kept.
- Issue 60's no-net-gain assertions still hold with the Action brake gone.
- Lane A fires at Waves 5, 10, 15…; Lane B fires at X since the last Lane A; Lane B's progress
  resets on every Lane A.
- Progress bar reflects Lane B, and the **windowed click probes** cover it.
- Tests in the split suites, seeds pinned. `run_all.sh` ALL GREEN — run it with
  `timeout: 600000`, blocking, alone.

## Blocked by

- the value of X, and whether Lane A replaces or supplements the existing threshold curve
