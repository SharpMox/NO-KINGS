# 17 — Artefacts: Action, Time & Piece

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

Three mid-sized tags whose effects reach into the turn loop rather than into arithmetic:
**Action (12)**, **Time (11)**, **Piece (13)**.

- **Action** — extra actions per turn, conditional actions, action refunds. The `move`
  artefact already shipped is one of these, so the seam exists; the rest generalise it.
- **Time** — clock refills, tick-rate changes, bonus time on triggers. All land on the
  single clock in `game.gd`, which only ticks on the player's turn.
- **Piece** — grants, promotions, conversions, protection. These touch Stock and the
  board, so ADR-0002's opaque piece state matters: anything that puts a piece into Stock
  must carry its state the way Extraction does.

Take only the no-prerequisite ones; anything carrying `(needs: …)` waits for slice 19.

Watch for: **Action artefacts interact with Blitz and the auto-pass.** The turn
auto-passes when the last action is spent, so an artefact that grants an action *during*
resolution can un-end a turn that already ended. Blitz hit exactly this and had to refund
its own action. Test the interaction rather than assuming.

## Acceptance criteria

- [ ] Every no-prerequisite Action/Time/Piece artefact implemented and flagged
- [ ] Action grants never resurrect an already-passed turn — covered by a test
- [ ] Piece grants into Stock carry state per ADR-0002
- [ ] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine
