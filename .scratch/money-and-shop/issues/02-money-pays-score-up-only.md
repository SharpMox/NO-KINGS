# 02 — Money pays, score is up-only

Status: needs-triage

## Parent

`.scratch/money-and-shop/PRD.md`

## What to build

Move every score cost and penalty to money, leaving score with no decrement path anywhere: the mid-turn placement cost (20), all tariff action charges (pass/deploy/capture/move/ability/fuse/box), and the Asset Freeze tariff (now halves money). Debits floor at 0. The post-wave reinforce panel becomes free — rows lose their price and Buy is always enabled; panel otherwise unchanged. Re-text and re-wire Field Orders ("next 2 placements cost no money") and Resupply Drop ("refund the money cost of your last 3 placements"). Update the autoplay bot for the free reinforce panel. High-score recording stays score-based and unchanged.

## Acceptance criteria

- [ ] Placing a piece mid-turn debits $20, score unchanged
- [ ] Tariff charges and Asset Freeze debit/halve money, never score
- [ ] Score has no decrement site left in the codebase; adjust the score suite to assert it only rises
- [ ] Reinforce panel grants pieces at no cost; autoplay bot still completes runs
- [ ] Field Orders and Resupply Drop operate on money with updated descriptions (item suite adjusted)
- [ ] `game/tests/run_all.sh` all green

## Blocked by

- 01 — money counter must exist
