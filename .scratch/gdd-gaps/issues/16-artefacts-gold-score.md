# 16 — Artefacts: Gold & Score

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

The two largest bonus tags and the most mechanical: **Gold (53)** and **Score (43)**.
Mostly arithmetic on numbers that already exist, which makes them the right first real
batch — they exercise the slice 15 engine hard without needing new game systems.

Representative of the shape:

- *Tinfoil Hat* — +15% Score gain; −5% Gold gain
- *Tungsten-Filled Gold Bar* — Gold gains also add 2× their amount as Score
- *Zurich Gnome Figurine* — at Wave end, refund 10% of Gold spent in the Shop
- *Nero's Marshmallow Stick* — each capture in a turn gives +25% more Score and Gold than
  the previous one; resets at turn end

Work through the **94 artefacts with no `(needs: …)` prerequisite** first, taking the
Gold- and Score-tagged ones. Anything whose text carries a `needs:` note belongs to slice
19 until its prerequisite exists.

Watch for: several of these are *negative* trade-offs (−5% Gold, −50 Score), and Score is
now an up-only number. A Score **penalty** has to be reconciled against that rule before
it can ship — either it debits Gold instead, or the up-only rule gets an explicit
exception. Settle it here, once, and record it.

## Acceptance criteria

- [ ] Every no-prerequisite Gold/Score artefact implemented and flagged `implemented`
- [ ] Percentage modifiers stack per the slice 15 rule
- [ ] The Score-penalty question settled and written back to Notion
- [ ] A scenario holding a representative handful, swept by `test_scenarios`
- [ ] `run_all.sh` all green

## Decision: Score penalties debit Gold (2026-08-28)

Only **4 of 180** artefacts collide with the up-only Score rule, and two of those are rate
reductions (*Daylight Savings Jar*, *45.5 Carat Curse*: "−20% Score gain") — a smaller gain
is still a gain, so Score never falls and they need no change.

That leaves exactly two real subtractions: *27 Club Punch Card* (−50 Score) and *Social
Credit Report Card* (−10 Score).

**Ruling: those two debit Gold instead.** The up-only rule is load-bearing and stated on
three GDD pages (Score, Shop, Reward Economy) — it is why the final Score is an honest
leaderboard number. Two artefacts do not overturn it, and Gold is where every other
penalty in the game already lands. Re-text both on Notion when implementing.


## Blocked by

- 15 — trigger engine
