# 96 — Captured Stock reads as its own pool, not a tinted tail

Status: done (2026-09-02) — shipped with 97

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

## Outcome (2026-09-02) — shipped together, one branch

**96 — the Captured section.** `_rebuild_pool_strip` now emits a `VSeparator` and a
two-line label at the Stock -> Captured boundary (`_stacks()` already returned stock first,
so the first captured stack *is* the boundary). The label reads **"CAPTURED / no deploy"** —
it carries the RULE, not just the name, because the constraint is the reason the section
exists and a label saying only "Captured" would leave the player to discover the rule by
being refused.

Before this, the only signals were a warm tint and a `" (captured)"` **tooltip** — and this
is a portrait touch game, so on the target platform the tooltip does not exist. A player
could not tell which of their pieces were placeable.

**97 — prices on the entries.** Every pool entry carries its own price badge: deploy cost for
a Stock piece, conversion cost for a Captured one. Shown as **base -> effective when they
differ**, per the ruling:

```
Crown:  btn$20    btn$20   | [CAPTURED/no deploy] btn$22
Horde:  btn$20>0  btn$20   | [CAPTURED/no deploy] btn$22
```

The Horde row is the proof the number is computed rather than hardcoded: Endless Ranks makes
its **pawn** free while the rook beside it still costs 20. Read from the live calls
(`Economy.deploy_cost`, `Shop.convert_price`), never re-derived in the HUD — a second copy of
the modifier rules would drift. Unaffordable prices render red.

**The rate split.** `Tuning.CONVERT_RATE = 0.75` against `SELL_RATE = 0.5`, with
`Shop.convert_price()` split out of `sell_price()`. The direction is the safety property, not
the value: convert-above-sell is safe, convert-below-sell is the money pump issue 68 closed by
keeping the rates equal.

### Three existing tests encoded the old equal-rate world

- **`test_shop`: "convert (-50%) then sell (+50%) nets exactly zero"** — the arbitrage test.
  It now asserts the loop **loses** money, which is a *stronger* invariant than the wash it
  replaces, and it pins the direction rather than the numbers so tuning cannot silently
  invert it.
- **`test_armies`: Insider Rates must not discount a conversion.** The number moved; the
  property did not. Re-pinned against `CONVERT_RATE`.
- **`test_game_clicks`** hardcoded `"Convert ($5)"` and a `- 5` debit. Both now read the live
  price, so a future tuning pass does not break the probe.

Three positional `pool_box.get_child(0)` lookups also assumed a buttons-only strip and now
take the first **Button** via a helper — 96 put a separator in front of them.

`run_all.sh` ALL GREEN, foreground, alone.

### Not done here

The **merge** price. `Economy.charge(g, "fuse_cost")` is a tariff hook that charges 0 Gold
unless a Fuse Tax is live, so there is no merge price to display until **98** gives it one.
