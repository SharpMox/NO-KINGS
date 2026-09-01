# 98 — Merges cost Gold, priced to be scarce at the start of a run

Status: done (2026-09-02)

## Parent

`.scratch/gdd-gaps/PRD.md`

## What a merge costs today

- **1 Action** (`merge_logic.gd:102`), waived entirely by The Muster's Close Ranks Power
- **`Economy.charge(g, "fuse_cost")`** (`merge_logic.gd:126`) — this is the *tariff* charge
  hook. With no Fuse Tax tariff active it charges **nothing**.

So in Gold terms a merge is **free**, all run long. The only brake is the Action, and one
Army removes even that.

## Why that is a problem early

Merging is the run's main power curve: two base pieces become a mid, two mids become an end.
Free merging means the curve is gated only by Actions and by having pairs — so an early run
converts its starting Stock into high-value pieces as fast as it can pair them, and the
opening has no resource decision in it.

## Scope

Give a merge a **Gold price**, sized so it is a real choice in the opening and routine later.

Design questions to settle before coding:

1. **Flat or scaled?** A flat price is one constant and is scarce early purely because Gold is
   scarce early. A price scaled by the *result's* value makes end-tier fusions expensive
   forever, which is a different (and larger) change.
2. **Does it interact with Close Ranks?** That Power waives the *Action*. It should probably
   not also waive the Gold, or The Muster gets both halves — but that is a ruling.
3. **The existing `fuse_cost` tariff charge** must still compose on top, not be replaced.
4. **Softlock check.** Placement was deliberately never blocked outright ("blocking deploys
   can strand a player into resource starvation, which is a softlock dressed as difficulty" —
   Qin Shi Huang's Power, issue 92). A Gold-priced merge needs the same scrutiny: if a player
   with no Gold and a full board can neither merge nor deploy, that is the same trap.

## Acceptance

- A merge charges Gold through `Economy`, composing with `fuse_cost` rather than replacing it.
- A scenario board demonstrating an unaffordable merge early and an affordable one later.
- `run_all.sh` ALL GREEN, foreground, alone.

## Note

This is a **balance change**, and the tuning pass is the natural home for its numbers. Ship
the mechanism here; leave the exact price to the pass, which now has every lever coded.

## Blocked by

Rulings on (1) and (2) above.

## Outcome (2026-09-02)

`Tuning.MERGE_COST = 15`, charged at `commit_merge` beside the Action spend, and gated by a
single `MergeLogic.can_afford_merge()` that all three existing `actions_left` gates now call —
one predicate, never three copies of the rule.

### The two open questions, answered as judgement calls (no ruling)

- **Flat, not scaled by the result's value.** One constant, and it is scarce early for the
  reason the issue actually asks for — Gold is scarce early — without making end-tier fusions
  expensive forever, which is a different and much larger change.
- **Close Ranks waives the ACTION only.** Its text is exactly *"Merges cost no Action"*, so
  waiving the Gold too would be inventing a second effect the card does not claim. The literal
  reading is also the reversible one.

Priced below `PLACEMENT_COST` (20) on purpose: a merge consumes two pieces you already own, so
it should not cost more than putting a fresh one on the board. It composes with the `fuse_cost`
Tariff charge rather than replacing it.

**Softlock check** (the standing question from issue 92's Great Wall): no risk. Being unable to
afford a merge never strands a run — moves, captures and passing all remain at 0 Gold. That is
the difference from a blocked *deploy*, which can strand a player with an empty board.

**97's merge half ships here**: the ▲ promote badge reads `▲$15`, putting the price on the
control that starts the merge.

### The blast radius was the interesting part

Merging was free in Gold all run long, so a lot of the suite merged with no budget. Pricing it
broke **six suites**, and the first fix attempt — sweeping a Gold budget into every config that
lacked one — **was wrong and was reverted**: `test_armies` deliberately sets no Gold precisely
so it can assert each Army's *starting* Gold, and the sweep clobbered exactly those assertions.

The targeted pass instead walked back from each failing check to its own boot. Two of those
tests set `"gold": 0` on purpose to pin an exact Gold delta, and they now boot at exactly
`MERGE_COST` so their arithmetic is unchanged — Spare Organ Receipt's `+10` payout assertion
still reads `gold == 10`, because `MERGE_COST` in and `MERGE_COST` out cancel.

Also fixed, and a genuine product bug rather than a test one: the hand-written **`Promote:` and
`Merge:` scenario boards set no Gold**, so pricing merges would have silently broken the very
sandboxes whose purpose is walking a promotion chain by hand. They now carry a budget.

`run_all.sh` ALL GREEN, foreground, alone.

### The number is not tuned

15 is a first value, not a measured one. Issue 103 can now measure it — the harness reports
`merge` counts and Gold per run — and the balance pass owns the figure.
