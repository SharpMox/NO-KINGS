# 96 — Captured Stock reads as its own pool, not a tinted tail

Status: todo (planned 2026-09-01)

## Parent

`.scratch/gdd-gaps/PRD.md`

## What exists today

Captured Stock and Stock share **one strip**. `hud.gd:378-384` builds the pool as "stock
stacks first, then captured", and the only differences are:

- `hud.gd:556` — a warm tint, `Color(1.0, 0.8, 0.8)`
- `hud.gd:548` — a tooltip suffix, `" (captured)"`

That is the whole separation. **On the target platform the tooltip does not exist** — this is
a portrait 480x800 touch game, and hover tooltips are unreachable on a phone. So the only
real signal a player gets is a slightly pinker button.

This matters more than cosmetics because the two pools obey **different rules** (issue 60):
Captured entries can be merged, converted and sold, but **never deployed**. A player who
cannot tell the pools apart cannot predict which of their pieces are placeable.

## Scope

Make Captured Stock a visually distinct section of the pool strip — its own labelled group
with a count, not a colour shift inside a shared run of buttons. The label carries the rule
that makes it different ("cannot deploy"), so the constraint is legible without a tooltip.

Include the **conversion cost on the entry itself** (see 97: converting already costs Gold,
and that cost is currently invisible until the Shop is open).

## Constraints

- Portrait 480x800 is the design target; the strip is already tight. A second labelled group
  must not push the board or cost a scroll.
- Touch-first: every affordance readable without hover.
- Load the `godot-ui` skill before writing UI code, and run the **click probes first**
  (`test_menu_clicks` / `test_game_clicks`, windowed) — CLAUDE.md's UI-first rule. The CLI
  bypasses once green-lit a fully dead main menu.

## Acceptance

- Stock and Captured Stock are distinguishable at a glance on a phone, with no hover.
- "Cannot be deployed" is discoverable from the UI itself.
- Click probes extended to cover the new grouping; `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

Nothing.
