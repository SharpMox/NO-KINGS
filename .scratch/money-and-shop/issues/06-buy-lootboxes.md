# 06 — Buy lootboxes

Status: done

## Parent

`.scratch/money-and-shop/PRD.md`

## What to build

Enable the lootbox row in the shop modal. Buying a box (flat 50, plus 1 action, SOLD) immediately opens the existing 3-option roll modal (item 40% / trinket 30% / score 30%). The "+N score" option follows the global earn rule from issue 01: raw score up, Inflation-taxed money up.

## Acceptance criteria

- [ ] Buying a lootbox debits $50 + 1 action, marks SOLD, and opens the 3-option roll modal
- [ ] Picking the score option raises ★ raw and $ taxed
- [ ] Shop suite extended for the box purchase path
- [ ] `game/tests/run_all.sh` all green

## Blocked by

- 04 — shop skeleton
