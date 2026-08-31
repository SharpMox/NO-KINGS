# 89 — One costume tier per run: the King line-up

Status: done (2026-08-31)

## Parent

`.scratch/gdd-gaps/KINGS-DESIGN-WORKSHEET.md` (ruling 1)

## The ruling

> *"We have 4 tiers of King with 4 in each tier. Starting a game will select a tier (randomly
> by default but we can add that selection with the difficulty choice) and randomize the order
> of the kings."* — user, 2026-08-31

| Wave | Boss |
| --- | --- |
| 50 | King 1 of the run's tier |
| 100 | King 2 |
| 150 | King 3 |
| 200 | King 4 |
| 201 | Larry — **parked** |

Wave 50 remains the win condition with its end screen unchanged; 51-200 are Endless, so
Kings 2-4 are post-win content.

## Outcome

**`Kings.roll_run(rng)` returns `{tier, order}`; the run stores and saves both.**

This replaces the tier-ordered-by-depth rule (Laurel@50, Hat@100, Uniform@150, Suit
unreachable). Under the old rule **three quarters of the cast could never appear in a single
run and Suit never appeared at all**; under this one a run meets a coherent set of four.

### Rolled once at run start and SAVED, never re-derived

This is the load-bearing decision. Deriving the line-up at each King wave would **re-roll on
load and hand a resumed run a different King than the one it was about to fight** — the same
class of bug as issue 55's silently-restarting Lane-B progress and issue 64's Shop lane. So
`king_tier` and `king_order` join the save (additive; a pre-89 save gets an empty line-up and
`Kings.select()` rolls one rather than leaving a King wave with no King, which would be a
softlock rather than a cosmetic gap).

### The shuffle draws from the RUN's RNG, not the global one

`Array.shuffle()` uses the **global** RNG. Using it would have made the line-up unreproducible
from a seed and silently broken the guarantee issue 75 shipped — for the endgame specifically,
which is the part a seeded leaderboard (issue 85) would most want to compare. Fisher-Yates off
`rng` instead, and asserted: same seed -> same line-up, different seeds -> able to differ.

### Tests

`test_kings.gd`'s two old assertions encoded the retired rule (wave 50 is Laurel by
construction) and were rewritten rather than deleted: a run rolls one of four tiers, meets all
four of its Kings, the line-up is a **permutation rather than a sample with repeats**, the Nth
King wave takes the Nth entry, past the line-up there is no King (wave 201 is Larry, parked),
and the spawned wave-50 King is **the first of the run's line-up** whatever tier it rolled.

`run_all.sh` **156.6s ALL GREEN**, foreground, alone.
