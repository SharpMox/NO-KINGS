# 30 — Action-type tracking

Status: done (partial — see Outcome)

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

## Outcome (2026-08-28)

Shipped: a per-turn `action_log` on the game node, cleared at `_begin_player_turn` and
populated by a single new `_log_action(kind)` choke point that replaced all 7 existing
`turn_action_count += 1` sites (6 in `game.gd`, 1 in `merge_logic.gd`) — no new call site
added. New `on_action` hook with `{kind, first}` ctx.

**Elvish Hard Hat** implemented. The auto-pass trap was real and is covered by a test: the
grant lands inside `_log_action` *before* the call site's own `actions_left == 0` check, so
a single-action turn spent on an Item never passes — the same ordering Stargate Divination
Crystal already relies on.

**Black Knight Morse Code NOT implemented — this issue's own brief was wrong about it.**
Its real catalog text is *"Every 3rd Turn: your Score and Clock gains that Turn are doubled"*,
which needs two things the action log does not provide: a run-long **turn counter** (only
`turns_since_wave` exists, and it resets every Wave) and a **Clock-gain hook** (`clock_ms` is
mutated directly at ~15 scattered sites, unlike Gold/Score which route through
`Economy.earn`/`gain`). The Clock-gain choke point is the interesting half — it would unblock
any future artefact that wants to modify time, the way `Economy.earn` did for Gold and Score.

Zapruder's Director's Cut and Y2K Patch Floppy Disk left alone as planned.

## Blocked by

- nothing
