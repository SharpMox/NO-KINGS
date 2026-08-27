# 11 — Enemy AI parity

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

Two halves of [Enemy AI Behaviors](https://app.notion.com/p/367f1559c99b81a8958edbf4a0f30762)
that the prototype only partly honours.

1. **"Protect the King at all cost" on King waves.** Rule 1 (highest-value target,
   lowest-value attacker) is implemented exactly in `rules.gd:_best_capture`. Rule 2 is
   not: the King simply never advances voluntarily, and check is resolved when it happens.
   There is no defending, blocking, or moving the King out of danger before it is in it.
2. **Enemy actions per turn: 2, not 1.** The GDD says 2; `tuning.gd` halves it as a
   playtest override from 2026-07-02 and it is divergence #2. **Revisit rather than assume
   either way** — the override predates the wave-catalog rebalance, the tariff system and
   the unified action economy, so the number was never actually tried under the current
   game. Run the fleet/autoplay data at 1 and 2 and let that decide.

If 2 proves right, the override comes out and the divergence entry is deleted. If 1 is
still right, the entry stays but gets a fresh date and reason.

## Acceptance criteria

- [ ] The AI actively defends its King on King waves, not just refuses to advance it
- [ ] Fleet data compared at 1 vs 2 enemy actions, decision recorded with numbers
- [ ] Divergence #2 either removed or re-justified on the Notion page
- [ ] King-wave scenarios still winnable
- [ ] `run_all.sh` all green

## Blocked by

- nothing
