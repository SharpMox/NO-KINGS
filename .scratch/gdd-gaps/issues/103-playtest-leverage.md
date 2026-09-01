# 103 — Make the bot use every leverage, then playtest at scale

Status: todo (planned 2026-09-01) — **gates the balance pass**

## Parent

`.scratch/gdd-gaps/PRD.md`

## The finding: the balance data was produced by a bot that cannot shop

`autoplay.gd` is the only thing that has ever "played" this game at volume, and every balance
number in FLAGS comes from it. Here is what it actually does, per turn:

| Leverage | Bot behaviour |
| --- | --- |
| Move / capture | greedy — prefers captures, **random pick among them** |
| Merge | first legal pair found, in list order |
| Deploy | ≤1 per turn, **random piece to a random tile** |
| Items | 30% roll, **random item at a random legal target** |
| Artefact activation | 25% roll |
| Army Ability | 15% roll |
| **Shop — buy** | **never. Zero `Shop.` calls in the file.** |
| **Shop — sell** | **never** |
| **Captured -> Stock conversion** | **never** |
| Piece Buff placement | never chosen — only whatever lands by grant |

A measured run, just now:

```
AUTOPLAY RESULT: LOSS — Resource starvation (wave 55, score 106600, 675 turns)
```

**It starved of material at wave 55 holding a six-figure Score, having never spent Gold on a
piece.** The Shop sells pieces (`Shop.base_piece_pool`). So "resource starvation" — the cause
of *every Tier-5 loss but one* in the FLAGS measurement — is at least partly an artefact of a
bot that refuses to convert Gold into material, not a property of the game's difficulty.

**Consequence: the Tier 1 = 4/6 wins vs Tier 5 = 0/8, median wave 8.5 table is not a safe
basis for tuning.** It measures the floor of a bot that ignores its economy. The tuning pass
should not start until this slice lands, or the first thing it will do is "fix" a difficulty
problem that is really a bot problem.

## Cost: this is free, and it must stay free

- One headless run: **~5.5s wall clock, 1.7s CPU**. 100 runs ≈ 9 minutes. 500 ≈ 45.
- **Zero LLM tokens.** `autoplay.gd` is GDScript; no model is in the loop, per run or per
  batch. The instinct to "offload it to an algorithm" is already the architecture — the work
  is making the algorithm *good*, not moving it.
- The rule for this slice: **no agent in the measurement loop, ever.** An LLM may write the
  heuristics and read the aggregate CSV; it must never be called per turn or per run.

## Phase 1 — telemetry before behaviour

Cannot assess "is it using all its leverages" without counting. Add per-run counters on `g`,
dumped as **one CSV line at run end**: gold earned/spent/unspent-at-death, shop opens, buys by
kind, sells, conversions, items used vs items held at death, artefact activations, ability
fires, merges, deploys, buffs applied, wave reached, score, cause of death, tier, seed, army.

Then a batch runner (`tools/playtest.sh`) over seeds x tiers x armies appending to one CSV,
and a small aggregator. **Baseline first** — the current bot's numbers are the control, and
several counters will be flat zero, which is the point.

## Phase 2 — the major strats, by expected leverage

**Tier 1 — economic (the whole missing axis)**

1. **Buy from the Shop.** Pieces when Stock is thin, Items/Artefacts when affordable. This
   alone may move every "resource starvation" loss.
2. **Sell to afford better.** Substitution — dump a weak holding when a strong one is on
   offer and the caps are full (Items 3, Artefacts 5).
3. **Convert Captured -> Stock** when deployables run low. It costs Gold (`_convert_captured`)
   and turns dead material into placeable material.
4. **Time purchases around restocks** — Lane A every 5 waves, Lane B on banked Score.

**Tier 2 — tempo and Actions**

5. **Early-clear bonus** — clear inside the cadence for the Score bonus.
6. **Artefact activation is 0 Actions** — press it whenever it does anything; never a coin flip.
7. **Army Ability (1 Action)** — fire when it returns more than one Action of value, not on a
   15% roll.
8. **Free-action effects** — Blitz, Close Ranks, Blood in the Air; sequence to bank Actions.

**Tier 3 — material and board**

9. **Bait with cheap deploys** — a pawn placed to be taken, pulling an enemy off its line.
10. **Trap/Bomb bait** — put Trap or Bomb on the cheap piece you *want* captured.
11. **Trade discipline** — take captures that gain material; refuse the ones that lose it.
12. **Merge to climb the chain** (and, once 98 lands, weigh its Gold cost).

**Tier 4 — buff and item combos**

13. **Shield** the piece about to be attacked; **Critical** before a high-value capture.
14. **Multicapture** when two enemies are adjacent; **Aura** before a big capture turn.
15. **Destruction items** on the highest-value threat, or to break a stalled line.
16. **Taunt** to choose what the enemy attacks; **Reflect** on what it wants most.

**Tier 5 — King waves**

17. **Bank burst** — hold destruction items and the Ability for the King wave.
18. **Play around the live Power** — do not plan merges against Genghis, do not bank on the
    Shop against Kim Jong Un, expect the extra enemy Action against Xerxes.

## Phase 3 — scale

Hundreds of runs across tiers x armies x seeds, serial. **Do not parallelise**: the Clock
drains on `delta` (`game.gd:816`), so runs under contended load are not comparable to runs
under light load — the same load-sensitivity that produced a confident, wrong flake
conclusion on 2026-08-29. Serial is 45 minutes for 500 runs; that is cheap enough that
parallelism buys nothing worth the risk.

## Acceptance

- Every leverage in the Phase-1 table has a **non-zero counter** across a batch — that is the
  literal meaning of "using all leverages", and it is checkable rather than asserted.
- Baseline and post-change aggregates both committed, so the delta is evidence not memory.
- No LLM call anywhere in the run loop.
- `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

Nothing. **This should land before the balance tuning pass**, because it changes what the
tuning pass is measuring.
