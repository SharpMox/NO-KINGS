# 11 — Enemy AI parity

Status: done

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

## Outcome

**King protection (`rules.gd`).** Added a priority tier between "resolve check"
and "best trade": `_king_threats` flags player pieces already covering a square
in the King's 8-neighborhood (one reposition-then-capture combo away — the
enemy would get no intervening turn to react, since the player can spend
multiple actions in one turn). `_defend_king` captures a threat if a legal move
can, else retreats the King to whichever legal square leaves the fewest threats
standing. Scoped to capture-the-threat + retreat only — no path interposition/
blocking, called out in-code as the simplest defensible slice. Covered by 3 new
assertions in `test_rules.gd` (defends over a bigger safe trade; retreats when
no capture is available; the retreat square is verifiably out of range).

**Enemy actions per turn — fleet sweep numbers.** 60-run sweep per setting
(Crown / Wild Hunt / Old Guard × 20 runs, `godot --headless --path game --
--autoplay --army <name>`), with the King-protection change already in place:

| actions/turn | win rate | mean wave | median wave | mean turns | median turns |
|---|---|---|---|---|---|
| 1 (current)  | 2/60 (3.3%) | 26.3 | 17.5 | 375 | 290.5 |
| 2 (GDD)      | 0/60 (0%)   | 9.7  | 8.0  | 145 | 125.5 |

At 2 actions/turn every single run lost, almost entirely to Resource
starvation, at roughly a third of the survival depth. **Decision: keep
`ENEMY_ACTIONS_PER_TURN = 1`.** The 2026-07-02 number predated the wave-catalog
rebalance, tariffs, and the unified action economy, so it had never actually
been tried under the current game — re-tested rather than assumed, per the
issue. 2 is decisively too strong now; divergence #2 on the Fable Prototype
Test Notion page re-justified with these numbers and dated 2026-08-28 (not
deleted).

King-wave scenarios (indices 9-12 in `scenarios.gd`) verified still winnable:
`test_scenarios.gd` bot-plays all 44 configs clean, and the fleet sweep itself
produced 2 real "Wave-50 King checkmated" wins at 1 action — with the harder,
actively-defending King AI in place.

`game/tests/run_all.sh` — ALL GREEN.

**Addendum 2026-08-30 (issue 59).** This issue's remaining open thread was "re-test the
enemy-action count with fleet data if the answer might change" — implicitly, at the single
global constant this issue was scoped to. The user's 2026-08-30 ruling on divergence #2
resolved it a different way: not a single global pick between 1 and 2, but a difficulty
rank, baseline 1 / Tier 5 restores 2 (issue 59). That answers the question this issue was
tracking in a way a fleet re-test can't improve on — there is no longer a single "the"
enemy-action count to re-test. Fully closed; no further action here.
