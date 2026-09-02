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

Items marked **[+]** were added 2026-09-01 on top of the user's original list.

**Tier 1 — economic (the whole missing axis)**

1. **Buy from the Shop.** Pieces when Stock is thin, Items/Artefacts when affordable. This
   alone may move every "resource starvation" loss.
2. **Sell to afford better.** Substitution — dump a weak holding when a strong one is on
   offer and the caps are full (Items 3, Artefacts 5).
3. **Convert Captured -> Stock** when deployables run low. It costs Gold (`_convert_captured`)
   and turns dead material into placeable material.
4. **Time purchases around restocks** — Lane A every 5 waves, Lane B on banked Score.
5. **[+] Sell to make ROOM before a grant lands.** A grant arriving at a full cap is
   **silently dropped** — FLAGS records exactly this for Fort Knox IOU at the 3-Item cap.
   Selling ahead of a wave-clear grant converts a dropped reward into a kept one. Pure profit
   and completely invisible to a bot that never sells.
6. **[+] Hold duplicates on purpose.** Stacking is **additive per held copy** and `run()`
   key-sorts so order never matters (`artefact_hooks.gd` header). Two copies of a percentage
   Artefact is a real, documented build — not a wasted slot.
   **CAUTION — under review.** The user flagged this as *"suspicious, feels like a bug"* on
   2026-09-01 (see FLAGS). It is deliberate and tested today, but if it is later bounded or
   removed, a bot taught to lean on it would silently become a bot tuned for a rule that no
   longer exists. **Instrument it, do not optimise into it** until the question is settled:
   count duplicate holdings, and leave duplicate-seeking out of the buy heuristic for now.
7. **[+] Buy Boxes as a distinct decision.** Boxes are their own Shop kind (9 typed, issue 47)
   priced by size — a gamble with a different expected value from buying the thing directly.
8. **[+] Reroll economics.** Restocks are capped and deliberately not reroll-scummable
   (`shop_restocks`). Knowing when to reroll versus buy the visible option is a real choice.

**Tier 2 — tempo and Actions**

9. **Early-clear bonus** — clear inside the cadence for the Score bonus.
10. **[+] Clear within the *specific* turn count, not just "early".** The big early-clear
    Artefacts are threshold effects: Naruto Run Manual needs `turns_since_wave <= 3`, Moon
    Landing Slate `<= 2` (a x10 Score payout). "Fast" is not the strategy; **3 turns** is.
11. **Artefact activation is 0 Actions** — press it whenever it does anything; never a coin flip.
12. **Army Ability (1 Action)** — fire when it returns more than one Action of value, not on a
    15% roll.
13. **Free-action effects** — Blitz, Close Ranks, Blood in the Air; sequence to bank Actions.
14. **[+] The Clock is a resource, and several Artefacts are clock-CONDITIONAL.** Daylight
    Savings Jar pays above 90s and *penalises* below 30s; The Red Phone doubles Score below
    30s; Bermuda Triangulation pays below 60s. So spending or preserving Clock deliberately
    changes payouts — a player holding The Red Phone wants to be in the danger band, which is
    the opposite of playing safe.

**Tier 3 — material and board**

15. **Bait with cheap deploys** — a pawn placed to be taken, pulling an enemy off its line.
16. **Trap/Bomb bait** — put Trap or Bomb on the cheap piece you *want* captured.
17. **Trade discipline** — take captures that gain material; refuse the ones that lose it.
18. **Merge to climb the chain** (and, once 98 lands, weigh its Gold cost).
19. **[+] Use Demote and Inversion on ENEMIES.** Demote's own text is "ally **or enemy**" —
    demoting an enemy end-tier piece to its chain base is a large tempo swing, and Inversion
    neuters an enemy's movement pattern. The bot only ever targets randomly, so hostile use of
    "buff-shaped" items is entirely unexplored.
20. **[+] Extraction as damage control.** Pulling pieces off the board before a losing wave
    returns them to Stock intact — no `on_piece_lost`, no material lost. A retreat option the
    bot has never once used.
21. **[+] Defend the back row.** The one Tier-5 loss that was *not* resource starvation was a
    back-row breach at wave 11, so this is a measured failure mode, not a theory.
22. **[+] Merge Captured entries instead of converting them.** Captured pieces can merge but
    never deploy (issue 60). Merging is the **free** way to use them; conversion costs Gold.
    Two routes to the same material at very different prices.

**Tier 4 — buff and item combos**

23. **Shield** the piece about to be attacked; **Critical** before a high-value capture.
24. **Multicapture** when two enemies are adjacent; **Aura** before a big capture turn.
25. **Destruction items** on the highest-value threat, or to break a stalled line.
26. **Taunt** to choose what the enemy attacks; **Reflect** on what it wants most.
27. **[+] Put the Buff on the right carrier.** Buffs ride the piece (ADR-0002) and travel with
    it through Stock. Shield on the piece actually under threat, Critical on the one that will
    swing next — placement is the decision, and with the cap at 2 (issue 99) it is a scarce one.

**Tier 5 — King waves and Tariffs**

28. **Bank burst** — hold destruction items and the Ability for the King wave.
29. **Play around the live Power** — do not plan merges against Genghis, do not bank on the
    Shop against Kim Jong Un, expect the extra enemy Action against Xerxes.
30. **[+] Segment 1 is a preparation phase.** A King wave is **two segments** (issue 90):
    `KING_SEGMENT_TURNS` of buffed enemies with **no King on the board**, and the King's Power
    is **already live** through it. That is a known-length window to set up in, with the
    Power's constraint already applying — quite different from fighting the King itself.
31. **[+] Play around active Tariffs.** Persistent Tariffs are rule modifiers for the rest of
    the run, and Counter-Intel suppresses every held one for the wave. Timing that suppression
    against the wave where the Tariffs hurt most is a decision nothing currently makes.

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

---

## Phase 1 outcome (2026-09-01) — telemetry, and what it immediately caught

**Shipped**: a per-run counter Dictionary on `g` (`tally()`), a `PLAYTEST,...` CSV line at run
end, `tools/playtest.sh` (serial batch runner) and `tools/playtest-summary.py`.

Two design choices worth keeping:

- **Counting happens at `ArtefactHooks.run`.** Every hook event passes through it exactly
  once, so captures, deploys, merges, item uses, purchases and buff grants all became counters
  from a single line, with no call sites touched.
- **The CSV header is printed BY THE GAME** (`tests/print_telemetry_header.gd`), so the column
  names cannot drift from what `_telemetry_csv()` emits. A hand-copied header would mislabel
  every row from the day they diverged, and the batch file spans hundreds of runs.

### The telemetry caught its own bug before it could mislead anyone

The first counter for the Army Ability was placed at `_army_ability_confirmed`, and read
**0** for a Crown run. The obvious conclusion — "the bot never uses its Ability" — was wrong.
There are **three** commit points: `_army_ability_confirmed` (untargeted: Wild Hunt, Old
Guard, Horde), `_army_target_stock` (Crown's Stock pick) and `_army_board_target_click`
(Syndicate, Cult). Counting at the first would have silently under-reported **four of the six
Armies**.

All three call `_log_action("army_ability")`, so the counter moved there. The same run then
read **52**. This is the issue's own rule working: a leverage that looks unused has to be
proven unused, because the counter is as likely to be wrong as the bot.

### The single measured run that justifies the slice

```
Tier 1, Crown, seed 7:
LOSS — Resource starvation (wave 83, score 184700, 1101 turns)
gold_left=13988
shop_open=0  shop_buy=0  sell=0  convert=0
item_use=0   artefact_activate=0  buff_apply=0
army_ability=52  merge=231  deploy=224  capture=371  piece_lost=185
```

**It starved of material holding 13,988 unspent Gold**, having never opened the Shop, which
sells pieces. `item_use=0` despite The Muster starting with a Promote is its own finding: the
bot's `use_item` **discards** an item it cannot immediately target rather than keeping it for
a turn when it could be used, so items leave the inventory without ever being consumed.

Resource starvation is the cause of *every Tier-5 loss but one* in the FLAGS balance table.
That table cannot be used for tuning until this is fixed.

### A second harness bug, found by reading the item path

`item_use=0` is not only "the bot discards items". The bot's item path **bypasses the
consumption choke point entirely**:

```gdscript
# autoplay.gd — the bot
g.items.remove_at(index)          # raw removal, no hook
g._item_apply(it, a, target)

# game.gd — the real UI path
_consume_item(item_active, it)    # fires on_item_consume, honours the ctx.cancel veto
_item_reset()
_item_apply(it, a, tile)
```

So in **every balance run this project has ever measured**:

- `on_item_consume` never fired, so its **7 listening Artefacts were silently inert**
- the **"the Item is not consumed" veto** (Dihydrogen Monoxide Battery, Wardenclyffe AAA
  Batteries) could never trigger — those Artefacts have never once worked under the bot

This is not a balance question, it is a fidelity bug in the measurement instrument, and it is
exactly the class of thing this slice exists to surface. The fix is to route the bot through
`_consume_item` like the UI does, and to stop discarding items it cannot immediately target.

### A third harness bug, found by the improved bot

The first post-change batch showed **19 of 51 runs producing no telemetry at all**. Cause: a
run that outlives `autoplay_cap` exits through `AUTOPLAY CAP` and never reaches `_game_over`,
so it never emitted a row.

That was harmless while the bot was weak — the baseline's 90 runs all died before the cap, so
**0** rows were lost. It became severe the moment the bot got stronger: the runs being dropped
were the ones that had survived longest, so the batch was **biased against the bot's best
play** — the exact opposite of what the harness is for, and invisible unless you compare the
row count to the run count.

Fixed twice over: a capped run now emits its row as its own result (`CAP` — never a `LOSS`,
which would file the strongest runs as failures), and batch runs get `--steps 8000` so the cap
stops deciding when runs end. `playtest.sh` also prints `NO ROW` per dropped run, so a future
silent drop is loud.

**The baseline is unaffected and the comparison stays fair**: it lost 0 rows, so no baseline
run ever reached its cap and raising it would not have changed a single one.

## Phase 2 outcome — the bot got an economy, and the balance table moved

`try_shop` (buys through `Shop.buy`, the same function the panel calls — boxes skipped,
because their grant is the roll modal) and `try_convert` (Captured -> Stock when Stock is
empty), plus the two item-path fixes above.

**90 runs before, 90 after, same seeds, tiers and armies, both serial on an idle machine.**

| | baseline | after |
| --- | --- | --- |
| wins | **5** | **55** (+3 unresolved at the cap) |
| FULL CLEARs | 0 | **15** |
| resource-starvation deaths | 83 / 90 | 27 / 90 |
| median Gold unspent at death, starved runs | 1640 | **0** |
| runs that ever bought anything | **0%** | 100% (median 250 purchases) |
| runs that ever converted Captured Stock | **0%** | 100% (median 148) |
| runs that ever used an Item | 16.7% | 95.6% |

| tier | wins before | wins after | median wave before | after |
| --- | --- | --- | --- | --- |
| Tier 1 | 0 | 15 | 37.0 | 77.5 |
| Tier 2 | 0 | 15 | 37.0 | 77.5 |
| Tier 3 | 3 | 13 (+2 cap) | 36.0 | 98.5 |
| Tier 4 | 1 | 13 (+1 cap) | 21.0 | 120.5 |
| **Tier 5** | **0** | **0** | **8.0** | **9.5** |

### The headline for the balance pass

**Tier 5 barely moved: 8.0 -> 9.5 median wave, still 0 wins in 18.** Every other tier
transformed. So Tier 5's difficulty is REAL, and the rest of the ladder's apparent difficulty
was mostly the bot refusing to use its economy. The FLAGS table ("Tier 1 wins 4/6, Tier 5
0/24 at median wave 7.5") was measuring the instrument.

### Two anomalies the balance pass should look at, not conclusions

- **Tier 1 and Tier 2 are byte-identical** in both batches (77.5 / 194970 after; 37.0 / 50000
  before). Not a coincidence and not a bug: Tier 2's ONLY lever is `clock_never_pauses` —
  "the Clock never pauses (menu/win/Shop/drawers/preview all keep ticking)" — and the bot
  never opens a menu, panel, drawer or preview. **Tier 2 is unmeasurable by autoplay by
  construction**, so no autoplay result can say anything about it. Note also that no run in
  either batch ended on the Clock at all.
- **Tier 4 now runs DEEPER than Tier 1** (median wave 120.5 vs 77.5), which inverts the
  ladder. 18 runs per tier is a small sample and this is recorded as an observation, not a
  diagnosis.

### Still not done — `sell` is 0%

Selling remains unimplemented, so cap-aware substitution (leverage 2 and 5) is untested. It
is the obvious next increment, and it matters most exactly where the bot is now failing: at
the caps, where a grant that arrives with no room is silently dropped.
