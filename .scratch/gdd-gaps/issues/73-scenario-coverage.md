# 73 — A test scenario per Artefact, per piece, per King

Status: todo — RESPECCED 2026-08-31 (user clarification) · sandbox menu, not tests

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

## What to build

Sandbox entries grouped so the menu stays navigable at 480x800 (the Family menu just needed
tightening at six entries — a flat list of 200+ will not work):

- **Per Artefact** — board + the Artefact held, set up so its effect can actually fire.
  Generating these from `artefacts.json` is still the sane approach for coverage, but they
  are for *playing*, so a generated stub that never triggers the effect is worthless. Prefer
  a smaller set of genuinely useful setups over 180 mechanical ones.
- **Per piece** — a board showing that piece's movement and its promotion chain.
- **Per King** — **blocked**: Kings have no mechanics yet.

## Acceptance

- Entries load from the menu and are playable by hand.
- The menu remains navigable at 480x800 — grouped/scrollable, not a flat list.
- Everything still boots under `test_scenarios.gd`'s automatic sweep.
- `run_all.sh` ALL GREEN, and **report what it did to suite runtime**.

## Blocked by

- Kings design (the King set only)
