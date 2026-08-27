# 10 — Arrow Planning

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

[Arrow Planning](https://app.notion.com/p/367f1559c99b81d2ab98f65c293d72d9) is a
**decorative-only** drawing mode: the player draws arrows on the board to plan their moves
and predict the enemy's. Arrows have **no effect on gameplay**. A dedicated button toggles
the mode.

Nothing exists. It is a small, self-contained slice with no dependencies — the board
already has a custom `_draw` and an animation overlay to hang arrows off.

Decisions the page leaves open, to settle while building: do arrows survive the turn, the
wave, a save? Simplest useful answer is that they clear on turn end and are never saved —
they are a scratchpad, not run state.

## Acceptance criteria

- [ ] A button toggles arrow mode; the board stops selecting pieces while it is on
- [ ] Drag draws an arrow; arrows render over the board
- [ ] A way to clear one and clear all
- [ ] Arrows never affect legality, targeting or the AI
- [ ] Lifetime decided and recorded on the Notion page
- [ ] Click probe covers toggle, draw, clear
- [ ] `run_all.sh` all green

## Blocked by

- nothing
