# One-pass layout: the board absorbs slack, and the whole stack solves in closed form

Design C (issue 106) made the stock strip the slack absorber — `SIZE_EXPAND_FILL`
under a board pinned flush to the top — so that leftover height would land in one
place rather than splitting into two gaps. That worked on the three phone formats
it was prototyped against and fails elsewhere, because a strip built from
fixed-size icon rows absorbs a *continuous* quantity in *discrete* 57px steps: the
remainder is dead by construction, and a wider strip fits more icons per row, needs
fewer rows, and therefore wastes more. NO-25 measured the result on a 3:4 tablet.

Decision (grilled 2026-09-08): the **board** absorbs leftover height, not the strip.
`HUD_DECK` stops being the hardcoded `268.0` and becomes the deck's real requirement,
**computed from the constants the deck is built from and never measured at runtime**.
The stock strip is frozen at exactly one icon row. `ICON` stops being the literal `52`
and becomes `tile - 7`, so the deck can never read as larger than the board.

Those last two are mutually dependent — the strip's height is `ICON + 22`, so the deck
needs ICON, ICON needs the tile, and the tile needs the deck — but the dependency is
linear and solves in one line rather than a second layout pass:

```
vp.y = HUD_TOP + BOARD_H*tile + 6 + (ICON + 22) + REST      with ICON = tile - 7

  tile = min( (vp.x - 8) / BOARD_W , (vp.y - 65 - REST) / 13 )
  ICON = tile - 7
```

`BOARD_H` is 12 and the strip is one more icon row, which is where the **13** comes
from. `REST` is the sum of the deck's other four rows plus separations — a constant,
computed the same way.

## Consequences

- The formula reproduces the shipped numbers on the format design C was tuned
  against: a 9:20 phone is width-limited at `tile` 59, giving `ICON` 52, today's
  literal. That correspondence is the evidence the `- 7` is the real relationship
  rather than a fitted number, and it is worth re-checking if either constant moves.
- `ICON` falls to roughly 36 on narrow shapes, below the conventional 44pt minimum
  touch target. This is safe *only* because no icon in the stock strip is
  individually tappable — every button in it, and the panel behind them, run the
  same `set_drawer("stock")`. The strip is one button wearing a shelf's clothes. If
  a future change makes strip icons individually actionable, this ADR is void and
  `ICON` needs its own floor.
- `REST` is a hand-maintained sum, so it can drift from the deck it claims to
  describe. A test asserts the computed constant equals the built deck's real
  height, and is the thing that fails when someone adds a deck row.
- NO-36 pinned "one icon size" as the literal 52 across all three strips. That test
  becomes a relationship — all three strips agree with each other, and stay under
  the board tile — rather than a value.

## Rejected

- **Measuring the deck and re-laying the board.** Always accurate and never drifts,
  but it needs a two-pass layout and reintroduces measure-before-layout, the exact
  shape that cached nonsense at 13px wide and made `resized` a feedback loop costing
  a scenario run 2.7 million error lines (CLAUDE.md, layout traps).
- **Keeping the strip as absorber but scaling icons to fill the remainder.** Removes
  the dead band without moving `HUD_DECK`, but makes icon size a function of leftover
  space, which is precisely the single-`ICON` invariant NO-36 had just pinned.
- **Deleting the strip** and moving its count onto the nav `Stock` button. The
  cheapest fix by a wide margin — the strip duplicates a button that already exists
  two rows below it — and rejected deliberately: seeing *which* pieces you hold
  without opening a drawer was half of what design C's prototypes were judging.
