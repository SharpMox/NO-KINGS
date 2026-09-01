# 97 — Every priced action shows its price, and conversion costs more

Status: done (2026-09-02) for deploy + convert; the MERGE price waits on 98

## Parent

`.scratch/gdd-gaps/PRD.md` · ships with **96** (Captured Stock separation) and depends on
**98** for the merge half

## Where this came from

The original ask was "make converting Captured -> Stock cost money". That **already exists** —
`game.gd:3577`, `_convert_captured()` charges `Shop.sell_price(self, "captured", entry)` at the
flat `Tuning.SELL_RATE`. The ruling splits into two real pieces:

1. **Conversion should cost MORE** — a tuning number.
2. **Prices should be visible** — merge, deploy AND conversion, on the confirm screens *and*
   on the piece entries in the Stock / Captured Stock lists. This is the substantial half.

## (1) Conversion costs more

Today conversion and selling share one rate. `armies.gd` and `shop.gd:373` record why:
equal rates deliberately closed a **convert/sell arbitrage**, and issue 68 explicitly refused
to discount conversion for The Syndicate for that reason.

So raising conversion alone means **splitting the two rates**, which reopens the question that
arbitrage closed. Before changing the number, confirm the direction is safe:

- conversion rate **above** sell rate is safe (converting then selling loses money — no loop)
- conversion rate **below** sell rate is the dangerous direction (buy low, sell high)

Raising it is therefore the safe side. The exact value belongs to the balance pass, but the
rate **split** — a `CONVERT_RATE` distinct from `SELL_RATE` — is this slice's mechanism.

## (2) Prices on the actions and on the entries

Three priced actions, three current states:

| Action | Real cost today | Shown? |
| --- | --- | --- |
| **Deploy** | `Economy.deploy_cost(g)` — `PLACEMENT_COST` 20, through the `on_place_cost` hook | no |
| **Convert** (Captured -> Stock) | `Shop.sell_price(g, "captured", entry)`, per entry | only inside the Shop |
| **Merge** | 1 Action + `fuse_cost` tariff charge (**0 Gold** unless a tariff is live) | no — and it has no Gold price until **98** |

### Show BOTH the base price and the computed one (user ruling, 2026-09-01)

Every one of these is modified at runtime:

- deploy cost is **doubled** by Qin Shi Huang's Great Wall and **zeroed for pawns** by The
  Horde's Endless Ranks, and it passes through `on_place_cost`, which Artefacts also modify
- conversion is per-entry (it scales with the piece's value)
- merge, once 98 lands, will compose with `fuse_cost`

So the UI renders **base -> effective**, not one or the other. Showing only the computed
number hides *that* something is modifying it; showing only the constant is a lie (20 Gold for
a Horde pawn that deploys free). Both together make the modifier legible, which is the point —
a player should be able to see their Power working.

Presentation: the base struck through or dimmed beside the effective price, and **shown only
when they differ** — printing "20 -> 20" on every entry is noise on a 480x800 screen.

Source of truth is the live call (`Economy.deploy_cost(g)`, `Shop.sell_price(...)`) for the
effective figure and the `Tuning` constant for the base. Never re-derive the effective price by
reimplementing the modifiers in the UI — that is a second copy of the rules that will drift.

### Where

- **On the entry**, in both the Stock and Captured Stock lists (ships with 96's separation) —
  so the price is visible while choosing, not after committing.
- **On the confirm screen** for each action.
- Affordability should read at a glance: a price the player cannot pay needs to look different
  from one they can.

## Constraints

- Portrait 480x800, touch-first. Prices on small entry buttons are a real layout problem —
  this is the tightest part of the slice, not the plumbing.
- Load `godot-ui`; **click probes first**, windowed (CLAUDE.md's UI-first rule).

## Acceptance

- Deploy, convert and merge each show **base and effective** price before commitment, on the
  entry and on the confirm screen, with the base shown only when it differs.
- A Horde pawn deploy displays `20 -> 0`; a Qin Shi Huang deploy displays `20 -> 40`.
  Asserted, not eyeballed — this is the case that proves the price is read from the live call
  rather than hardcoded or re-derived.
- Unaffordable actions are visually distinct from affordable ones.
- `CONVERT_RATE` exists and is >= `SELL_RATE`, with the arbitrage direction noted at the
  constant.
- Click probes extended; `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

- The merge price half needs **98** (no Gold price to display until then).
- The exact `CONVERT_RATE` value is a balance-pass number; the split can ship with a
  placeholder equal to today's behaviour + the ruling's direction.

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
