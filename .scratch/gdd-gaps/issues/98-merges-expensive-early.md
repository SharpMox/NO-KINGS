# 98 — Merges cost Gold, priced to be scarce at the start of a run

Status: todo (planned 2026-09-01)

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
