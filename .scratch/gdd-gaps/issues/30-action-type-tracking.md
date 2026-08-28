# 30 — Action-type tracking

Status: todo — INDEPENDENT (no design decision needed)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Problem

`game.gd` counts actions (`turn_action_count`, `actions_left`) but never records **what
kind** each action was, or in what order. Four artefacts need that and were skipped:

- **Elvish Hard Hat** — *"If your first Action of a Turn is an Item or ability: +1 Action"*
- **Zapruder's Director's Cut** — needs the last action's shape to replay it
- **Black Knight Morse Code** — needs a per-turn action counter with type
- **Y2K Patch Floppy Disk** — needs a turn-skip hook

## What to build

A per-turn action log on the game node: an ordered list of `{kind, ...}` entries appended
at each action site (move/capture, place, merge, item use), cleared at `_begin_player_turn`.
The action sites already exist and each already does `turn_action_count += 1` — that is the
choke point; do not add a fifth.

Expose it via a hook (`on_action`) so artefacts read it rather than reaching into game state.

Then implement Elvish Hard Hat and Black Knight Morse Code. Zapruder's and Y2K need more
than the log (replay semantics; a turn-skip seam) — leave them, and say so.

⚠️ Careful with Elvish Hard Hat: granting an action mid-turn can un-end a turn that already
auto-passed. Blitz hit exactly this. Test it.

## Acceptance criteria

- [ ] Per-turn action log, populated at the existing action sites, cleared each turn
- [ ] `on_action` hook
- [ ] Elvish Hard Hat + Black Knight Morse Code implemented
- [ ] An action grant cannot resurrect an already-passed turn — asserted by a test
- [ ] `run_all.sh` all green

## Blocked by

- nothing
