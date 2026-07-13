# 01 — Money counter: earn, display, persist

Status: done

## Parent

`.scratch/money-and-shop/PRD.md`

## What to build

Introduce the per-run Money currency end-to-end: a `money` value on the game node (starts 0, dies with the run), earned alongside every score gain via a single economy `earn()` helper — score goes up by the raw amount, money by the Inflation-taxed amount. Money displays in the HUD top bar as a green `$%d` right after the score; the foes counter is removed (top bar becomes clock · ★score · $money · wave). Money survives the mid-run save/load round-trip.

Gain sites to route through `earn()`: captures, early-clear bonus, win bonus, lootbox "+N score" option, box-skip consolation.

## Acceptance criteria

- [ ] Capturing a piece raises ★ by the raw amount and $ by the Inflation-taxed amount (with no Inflation active, both rise equally)
- [ ] With Inflation stacked, score gains are unreduced; only money is taxed
- [ ] All five gain sites go through the shared `earn()` helper — no direct `score +=` remains at a gain site
- [ ] Top bar shows `$%d` after the score; foes counter is gone
- [ ] Save/load round-trips money (extend the save suite)
- [ ] `game/tests/run_all.sh` all green

## Blocked by

None - can start immediately
