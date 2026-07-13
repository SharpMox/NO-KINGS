# 07 — Shop reroll cadence

Status: done

## Parent

`.scratch/money-and-shop/PRD.md`

## What to build

Reroll the shop's 19-slot stock every 10th wave (aligned with the existing milestone cadence), clearing SOLD flags. Expose the reroll as a plain callable on the shop module so future effects (items, tariffs) can trigger it without rework — no effects use it yet. Persist the reroll marker in the mid-run save so reloading can't reroll-scum. Add a shop scenario to the scenario catalog (manual sandbox + auto-swept).

## Acceptance criteria

- [ ] Stock rerolls at every 10th wave; SOLD slots refresh
- [ ] Reroll is a single callable usable outside the wave hook
- [ ] Reroll marker survives save/load; reloading mid-decade does not reroll
- [ ] Shop scenario added to the catalog and green in the scenario sweep
- [ ] `game/tests/run_all.sh` all green

## Blocked by

- 04 — shop skeleton
