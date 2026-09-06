# 73 — A test scenario per Artefact, per piece, per King

Status: SPLIT (2026-08-31) — see 79 / 80 / 81 / 82; this file is now the parent spec

## Parent

`.scratch/gdd-gaps/PRD.md`

## What this is — corrected

**The user means the manual sandbox menu, not executable tests.**

> *"When i say scenarios its the menu with the setups for me to use. You dont have to make
> them executable test for the testing suites."*

So the deliverable is **hand-authored setups the user can load and play** from the in-game
menu, to explore an Artefact, a piece, or a King by hand. Not assertions, not coverage.

That makes this dramatically cheaper than the original spec, and it removes the objection
that killed it: **there is no suite-runtime risk**, because nobody is asserting anything.

**One thing to keep in mind rather than design around:** `test_scenarios.gd` automatically
boots and bot-plays everything in `game/data/scenarios.gd`. So new sandbox entries get a free
smoke test — they must at least *boot and not crash* — but nobody has to write an assertion,
and a scenario that merely sets up an interesting board is a perfectly good scenario.

If the count ever grows enough to slow the suite, that is the moment to split the file into
"swept" and "sandbox-only" sets — not before.

## What to build — (a) + (b), user ruling 2026-08-31

> *"If the boards can be generated it's just a simple setup to see the artefact firing. 180
> setup configs don't seem like a big deal to hold on to even if they are rarely used. At
> least we have a way for you and me to verify interactions."*

The purpose is **verification**, not only play. That is what justifies the full 180: a board
you can load to watch a specific Artefact actually fire is how a disputed interaction gets
settled in seconds instead of by reading dispatch code.

### (a) One per Artefact — generated, and driven by the REGISTRY

The usual reason generated boards are worthless is that the effect never triggers. **That is
solvable here**, because `artefact_hooks.gd`'s `REGISTRY` already maps every Artefact key to
the hooks it listens on — 147 of the 180 have an entry, and the rest are passive reads.

So generate **per trigger family**, not per Artefact:

| hook | how many | the board it needs |
| --- | --- | --- |
| `on_wave_clear` | 34 | a wave one capture from clearing |
| `on_capture` | 21 | a player piece adjacent to a takeable enemy |
| `on_score_change` | 13 | anything that scores — the capture board serves |
| `on_purchase` | 9 | Gold in hand, Shop reachable |
| `on_charge` / `on_piece_lost` | 18 | an enemy poised to take a player piece |
| `on_turn_start` | 7 | trivial — any board |
| `on_item_consume` | 7 | the Artefact plus a usable Item |

Roughly **eight board templates** cover almost everything. Each generated scenario is
template + the Artefact held + a pinned seed. Artefacts with no REGISTRY entry (passive reads
like the zone rules) get a board where their condition is visibly true.

**Where a template genuinely cannot make an Artefact fire, say so in the generated name** —
e.g. a "needs a King present" case. A scenario that silently does nothing is worse than one
labelled as needing manual setup.

### (b) The interesting ones — hand-built

20-30 boards for combos worth *feeling* rather than verifying: the stacking pairs, the
cap interactions, the Army Power/Artefact overlaps. These are where hand-authoring pays,
and they are the ones that will actually get opened twice.

### (c) Per piece — 39, generated

Each piece's movement and its Family chain. Mechanical, and genuinely useful for checking the
exotic pieces behave.

### The menu will need sub-grouping

Slice 77 sections the list by name prefix, which handles 53. At **~250** the "Artefacts"
section alone would be 180 entries. Either sub-group it (by rarity, or by trigger family —
the generator knows both) or make sections collapsible, which slice 77 was deliberately built
to allow later without restructuring.

## Acceptance

- Entries load from the menu and are playable by hand.
- The menu remains navigable at 480x800 — grouped/scrollable, not a flat list.
- Everything still boots under `test_scenarios.gd`'s automatic sweep.
- `run_all.sh` ALL GREEN, and **report what it did to suite runtime**.

## Blocked by

- Kings design (the King set only)
