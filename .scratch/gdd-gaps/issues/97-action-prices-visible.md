# 97 — Every priced action shows its price, and conversion costs more

Status: todo — **RULED 2026-09-01** (was "conversion should cost Gold", which already shipped)

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
