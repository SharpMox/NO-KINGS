# 43 — The three economy Artefacts with no prerequisites

Status: todo — INDEPENDENT (no design decision needed)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why this slice exists

Of the 38 Artefacts still `implemented: false`, exactly four carry **no `(needs: …)`
note** — the audit judged them buildable on hooks that already exist. One of those four
(Pegasus Free Trial) turned out to belong to the parked group in issue 33, because it
redefines `moved_this_turn` and Blitz now depends on that. The other three are this
slice.

All three land on hooks the engine already dispatches, so **no new call sites**:
`on_price` and `on_purchase` (both `shop.gd`), `on_milestone`, `on_gold_change`.

## Scope

### 1. Mar-a-Lago Toilet Papers — Common

> On 5-Wave Milestone: a random Shop item becomes free; all other Shop prices +10%

Hook: `on_milestone` to choose, `on_price` to apply.

**The one thing to get right:** which slot is free must be picked **once, at the
milestone**, and stored in run state — not re-rolled inside `Shop.price()`. `price()` is
called per slot on every redraw, so rolling there would make the free slot flicker
between frames and change which slot is free between the UI and the actual charge. Pick
the slot index on `on_milestone`, keep it until the next milestone or restock, and have
the `on_price` handler compare against the stored index.

Remember the per-artefact milestone cadence (issue 28): each copy counts its own 5 waves
from `acquired_wave` via `_milestone5_hit`, not `g.wave % 5`.

The +10% is a normal additive percentage off the immutable base, per the `on_price`
contract.

### 2. Deep State Yearbook — Uncommon

> On buying an Artefact: each other Artefact you own pays +5 Gold

Hook: `on_purchase`, scoped to `ctx.kind == "artefact"`. Pays `5 * (held artefacts - 1)`
— "each **other** Artefact", so the one just bought does not pay itself. Decide against
the artefact list as it stands when the hook fires and say in a comment which side of the
append that is.

### 3. New World Order Gerrymandering — Rare

> Gold paid by other Artefacts is increased by 25%

Hook: `on_gold_change`, **and this one is a deliberate exception to the ORDERING rule** —
call it out in the handler exactly as `artefact_hooks.gd`'s header says a multiplicative
artefact must be.

It cannot size itself off `ctx.base`, because the thing it multiplies is precisely
*"everything the other artefact handlers added"* — i.e. `ctx.amount - ctx.base` — which
is only correct once every other handler has run. A handler that reads the running
`amount` mid-dispatch is the order-dependence bug issue 20 was raised to kill, so **do
not** implement this as an ordinary handler that happens to sort last.

Implement it as an explicit **post-pass in `run()`**: after the normal key-sorted
dispatch completes, if the key is held, add `0.25 * (amount - base)` per held copy.
`ctx.gold_bonus` (the Gold paid out by Score→Gold converters like El Dorado Body Glitter)
is also "Gold paid by other Artefacts" and gets the same 25%.

Held twice = +50%, additive, consistent with the stacking rule.

## Acceptance

- All three flip to `implemented: true` **via the exporter**, never by hand-editing
  `game/data/artefacts.json` — edit `data/artefacts.js` and re-run
  `node tools/export-game-artefacts.mjs`.
- Tests in the split item suites (issue 37), not in one lump: the two Shop-facing ones
  belong with the Shop/price cluster, Gerrymandering with the Gold/Score cluster.
- Cover, at minimum: the free slot is stable across repeated `price()` calls; the +10%
  does not apply to the free slot; Yearbook pays nothing when it is your only Artefact;
  Gerrymandering does not multiply the base gain, only the artefact-added part; and two
  Gerrymanderings add to +50% rather than compounding to +56.25%.
- `game/tests/run_all.sh` ALL GREEN.

## Blocked by

- nothing
