# 02 — Score-driven restock and the new stock shape

Status: todo

## Parent

`.scratch/shop-gdd-sync/PRD.md`

## What to build

Three GDD divergences in the shop's pure logic:

1. **Restock on cumulative Score, not waves.** Track the next threshold as run state, starting at 1000 and stepping **+500** after each restock (1000 · 2500 · 4500 · 7000 …). Crossing it rerolls all four areas and clears SOLD. Remove the 10-wave reroll from `wave_logic.gd`; the reroll stays a plain callable for artefact/tariff use. Persist the threshold marker so reloading cannot reroll-scum.
2. **Typed boxes.** The box row becomes 6 slots — 2 Item, 2 Artefact, 2 Score — each carrying its type, and buying one opens the roll modal restricted to that type. Price stays flat 50 for all three.
3. **Slot counts as base + modifiers.** `ROWS` becomes a base table resolved through a modifier pass, so an Artefact can add slots (the GDD's Chocolate Key Cake, Alleged Weather Balloon, Sub-Antarctic Visa). Pieces base 8, ceiling 10. No artefact uses the seam yet.

Unchanged: prices, the 1/value piece weighting, the base-piece pool and its exclusions, sell-out, 1 action per purchase.

## Acceptance criteria

- [ ] Restock fires exactly when cumulative Score crosses the threshold, not before
- [ ] Thresholds step +500 each time; a single huge gain does not skip past several
- [ ] SOLD flags clear on restock
- [ ] Stock shape is 8 pieces / 4 artefacts / 4 items / 6 boxes, boxes typed 2/2/2
- [ ] Buying a typed box opens a roll of that type only
- [ ] Slot modifiers change the rolled counts; pieces cap at 10
- [ ] The threshold marker survives save/load
- [ ] No reroll happens on the 10-wave milestone any more
- [ ] `game/tests/run_all.sh` all green

## Blocked by

- 01 — rename
