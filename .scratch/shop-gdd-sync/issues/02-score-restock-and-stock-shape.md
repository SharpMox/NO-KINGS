# 02 — Score-driven restock and the new stock shape

Status: done — shipped 2026-08-27 in `3abf75e`; the restock half was later superseded

## Parent

`.scratch/shop-gdd-sync/PRD.md`

## What to build

Three GDD divergences in the shop's pure logic:

1. **Restock on cumulative Score, not waves.** Track the next threshold as run state, starting at 1000 and stepping **+500** after each restock (1000 · 2500 · 4500 · 7000 …). Crossing it rerolls all four areas and clears SOLD. Remove the 10-wave reroll from `wave_logic.gd`; the reroll stays a plain callable for artefact/tariff use. Persist the threshold marker so reloading cannot reroll-scum.
2. **Typed boxes.** The box row becomes 6 slots — 2 Item, 2 Artefact, 2 Score — each carrying its type, and buying one opens the roll modal restricted to that type. Price stays flat 50 for all three.
3. **Slot counts stay literal.** The GDD's "base + modifiers" (pieces 8, up to 10 via effects) is **deferred**: no Artefact in the game adds slots, so the modifier pass would have no caller. `ROWS` keeps base counts; the seam lands with the first slot-adding Artefact.

Unchanged: prices, the 1/value piece weighting, the base-piece pool and its exclusions, sell-out, 1 action per purchase.

## Acceptance criteria

- [ ] Restock fires exactly when cumulative Score crosses the threshold, not before
- [ ] Thresholds step +500 each time; a single huge gain does not skip past several
- [ ] SOLD flags clear on restock
- [ ] Stock shape is 8 pieces / 4 artefacts / 4 items / 6 boxes, boxes typed 2/2/2
- [ ] Buying a typed box opens a roll of that type only
- [ ] ~~Slot modifiers change the rolled counts~~ — deferred, no caller
- [ ] The threshold marker survives save/load
- [ ] No reroll happens on the 10-wave milestone any more
- [ ] `game/tests/run_all.sh` all green

## Blocked by

- 01 — rename

## Outcome

Shipped 2026-08-27 in `3abf75e` *feat(shop): restock on score thresholds and sell typed
boxes* (11 files, +110/−35). This file's `Status: todo` was never updated, which made an
instruction audit on 2026-09-17 read it as unstarted work and nearly migrate it into Linear
as a Backlog issue.

**Typed boxes shipped and are live:** `shop.gd:21` is
`const ROWS := {"box": 6, "artefact": 4, "item": 4, "piece": 8}` — 6 box slots, typed 2/2/2.
The slot-modifier deferral above still holds: no Artefact adds slots, so the seam has no
caller.

**The Score-threshold restock is SUPERSEDED — do not reimplement it from this file.** The
1000/+500 ladder was replaced entirely by the issue-64 two-lane restock: Lane A every
`Tuning.SHOP_RESTOCK_WAVES` (5) waves in `wave_logic.gd:49`, Lane B every 10,000 banked
Score, reset by Lane A (`shop.gd:216-242`). `economy.gd:21-22` records the reason — the
thresholds were unreachable, since a median Crown run ends near Score 300 against a first
threshold of 1000. Linear NO-16 (Done) carries the user ruling: keep Lane A at every 5
waves, revisit the 10,000 Score threshold.
