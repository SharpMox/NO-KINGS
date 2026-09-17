# A Tariff bills a percentage of what it taxes, not a flat fee

Every tariffed action — Move, Capture, Long-Range, Deploy, Fuse, Item — charged the
same flat `KING_ABILITY_ACTION_COST` (10 gold) regardless of tier or of what it
taxed, while the Notion GDD's Cost column carried a Score-denominated 200/500/1000
ladder that was never built. It could not have been: Score only accumulates and is
never spendable (CLAUDE.md), so a Score-denominated cost was stale by construction.
`king_abilities.gd`'s header had recorded this gap as unreconciled, pending issue 6.

Decision (user ruling 2026-09-17): a tariff takes a cut of a reference value
belonging to the thing being taxed, rounded down with a floor of 1 (`Economy.
tariff_cut`, `tuning.gd`'s `TARIFF_*_PCT`). Mild tariffs bill a percentage of an
asset's Shop value — Move 10% of the mover, Capture 10% of the captured piece,
Long-Range 3% of the mover per square, Item 60% of the Shop price for its tier.
Moderate tariffs bill a percentage of the action's own existing cost instead —
Deploy 60% of `PLACEMENT_COST`, Fuse 60% of `MERGE_COST`. Pass has no reference
value to tax and stays flat at 10.

The two tariff classes use different bases because the same percentage does not
read the same against both: 60% of an action's cost is sane (Deploy 12, Fuse 9 —
close to the old flat 10), but 60% of an asset's *value* is not (60% of a Valkyrie
is 84 gold to move it once, which makes fielding your best pieces irrational). 10%
of value keeps Mild tariffs mild instead — 1 gold for a pawn, 14 for a Valkyrie.

A long-range move pays the Long-Range Tariff **instead of** the Move Tariff, not
both, **but only when Long-Range is actually held** (and not suppressed — user
ruling 2026-09-17, narrowed). Holding Move alone still taxes a slider's move: the
first implementation skipped on piece type alone, which exempted every rook,
bishop and queen from a held Move Tariff — the move dispatched
`"long_range_cost"`, matched nothing held, and cost nothing. Caught by a test that
had to swap its fixture piece to keep asserting anything, because the queen it
used was moving free. Suppression is part of the same condition: while
Counter-Intel suppresses tariffs, none charge, so Long-Range cannot be the one
that fires.

## Consequences

- The Notion Tariffs Cost column (200/500/1000) is superseded by these values
  rather than reconciled with them; it was unbuildable as written.
- With both Move and Long-Range held, a long-range piece moving one square pays
  3% of its value rather than 10%, so a one-square rook or bishop step is
  cheaper than the same step with a knight. Accepted deliberately for
  simplicity — the alternative was a "greater of the two" floor between the
  Move and Long-Range tariffs.
- The blocked/reflected move charge (`game.gd` ~2130) still bills the flat
  default. That move never lands, so rebasing it was out of scope; it is a known,
  deliberate inconsistency, not an oversight.

## Rejected

- **A "greater of Move or Long-Range" floor** for long-range moves, so short steps
  never got cheaper than an equivalent Move charge. Rejected for the extra branch
  it adds to every long-range move for a case (a one-square long-range step) that
  is rare and cheap either way.
