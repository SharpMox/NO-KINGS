# What the playtest harness can and cannot tell you

Audited 2026-09-07 (NO-15), before the balance pass leans on these numbers.

The harness is `tools/playtest.sh` + `tools/playtest-summary.py`, driving
`scripts/autoplay.gd`. It is cheap, deterministic and zero-token, and its numbers are
good — for the questions it can actually answer. This document is the list of questions
it cannot, so the balance pass does not quietly answer one of those with a number.

The summary tool already asks the right question first — *is the bot using its levers?* —
because a lever with a zero rate means every number below it describes a bot that refuses
to use that tool, not a property of the game. This audit is that principle applied to the
harness itself.

## 1. Tier 2 is unmeasurable by autoplay, and the data proves it

**Every Tier 1 and Tier 2 run in a batch is byte-identical.** Not similar — identical, in
every column.

Measured on the 60-run sweep `.scratch/playtest/2026-09-06-reinforcement-beat.csv`:
12 of 12 (army, seed) pairs matched across every field.

The mechanism, which is why this is structural rather than a fluke: **Tier 2's only lever
is `clock_never_pauses`.** The bot never opens anything that would pause the clock at
Tier 1 — it buys through `Shop.buy` without opening the panel, activates Artefacts and
Army Abilities through their own autoplay bypasses, and never opens a menu, drawer or
preview. So the Clock never pauses for the bot *at either tier*, and the one difference
between them never manifests.

**Consequence:** any Tier 2 row in any sweep is a Tier 1 row wearing a different label.
Do not read a Tier 1 → Tier 2 difficulty step off this harness; there isn't one to read.
Tier 2 needs a human or a bot taught to open panels.

## 2. `sell` reads 0% because the bot cannot sell

`sell` has fired in **0 of 60 runs**. That is not the bot declining to sell — it is a
capability gap. `autoplay.gd` contains no sell path at all; the single occurrence of the
word is prose in a comment about the Shop.

So the sell mechanic (issue 60) is **unexercised by every balance number this project
has produced.** Anything the balance pass concludes about Gold scarcity, inventory
pressure or the Item/Artefact caps is drawn from runs where the player could never
convert held goods back into Gold.

This one is worth fixing before the balance pass rather than annotating, because selling
is precisely a pressure valve for the resource starvation that dominates the death table.

## 3. What is genuinely covered

Reachable and exercised, contrary to what a quick grep of lever names suggests — the bot
reaches these through differently-named helpers:

| Lever | Path |
|---|---|
| `shop_buy` | `try_shop` → `Shop.buy` (respects `SHOP_UNLOCK_WAVE`, so it cannot shop earlier than a player) |
| `artefact_activate` | `try_activate_artefact`, tried up front because it costs 0 Actions |
| `army_ability` | `try_activate_army_ability`, inside the `actions_left` gate because it costs 1 |
| `convert`, `merge`, `deploy`, `item_use`, `capture` | direct paths in `step()` |
| Box Picks, choice modals, the reinforcement pick | auto-resolved through each modal's own autoplay bypass, so the bot never stalls on one |

`shop_open` reads 0 by design and is already annotated as such in the summary — the bot
buys without opening the panel. That zero is not an alarm, and the tool is right to say so.

## 4. Strategy caveats that are not bugs

The bot plays a deliberately crude game, and its numbers are a **floor**, not a difficulty
measurement:

- Moves are random legal actions with a greedy capture preference — no threat evaluation,
  no piece protection, no positional play.
- Shop buying is cheapest-first, with a piece-priority only when Stock is thin. It never
  saves for an expensive slot, and never reasons about what an Artefact would combo with.
- Items fire at a flat 30% chance when held, Artefact activation at 25%, Army Ability at
  15%. These rates are arbitrary — a real player uses an effect when it is *good*, and the
  difference is invisible in aggregate.

The sharpest existing tell remains the one already in the tooling: *a bot that dies of
resource starvation while holding Gold has not run out of resources, it has run out of
ideas.*

## 5. How to read a sweep, given all that

- **Trust**: relative movement across a change (before/after the same batch shape),
  death-cause distribution, whether a lever fires at all, and Tier 3-5 separation.
- **Distrust**: any Tier 1 vs Tier 2 comparison; absolute win rates as "the game's
  difficulty"; and any conclusion about Gold pressure until `sell` is reachable.
- **Never**: compare Score across a commit that changed Score payouts — the 10-Wave beat
  merge removed a per-beat Score chunk, so scores are not comparable across it.
- **Batches are not interleaved.** `playtest.sh` runs serially by design (the Clock drains
  on frame time), but a before-batch and an after-batch still ran at different times under
  different load. For a suspected regression, interleave; CLAUDE.md has the full reasoning
  and the 2026-08-29 false conclusion that motivated it.
