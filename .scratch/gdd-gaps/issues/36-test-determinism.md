# 36 — Test determinism (flaky suite)

Status: todo — INDEPENDENT · **PRIORITY**

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why this is urgent

The suite produces **false failures**, repeatedly, and each one costs a re-run to
disambiguate from a real regression. Observed this session:

- `test_items` "Holy Lint" failed ~1 run in 3 — a genuine nondeterminism, fixed only by
  pinning a seed for that one fixture.
- `game-clicks` failed once in three standalone runs on an otherwise-green branch.
- Several agents reported "ALL GREEN" on branches my own verification then failed, and
  vice versa. **That is the real damage: a flaky suite makes every green claim unfalsifiable**,
  and this project's whole verification discipline rests on those claims.

## Root cause, measured

`game/tests/test_items.gd` makes **171 `_boot()` calls. Exactly 1 pins a seed.** The other
170 fixtures run on `rng.randomize()`. Any assertion downstream of a random roll — a granted
buff, a box roll, a shop stock, a tariff draw, an AI tie-break — is a latent Holy Lint. The
one we found only surfaced because its failure rate happened to be high enough to notice.

Slice 01 already built the mechanism: a run seed that is settable via the scenario/save
config (`"seed"`) and round-trips deterministically. It is simply not used.

## What to build

1. **Seed every test boot by default.** Give each test file's `_boot()` helper a default
   pinned seed, so a fixture is deterministic unless it explicitly opts out. Where a test
   genuinely wants variance (a distribution check), it opts in loudly and says why.
2. **Fix what that surfaces.** Pinning will expose assertions that were passing by luck.
   Those are real bugs in the tests (or the code) — fix them, do not re-randomise to hide
   them. Report anything that turns out to be a product bug rather than a test bug.
3. **Godot import races.** Fresh worktrees intermittently log `Failed loading resource` for
   item SVG icons. Make `run_all.sh` ensure the import step has completed before the first
   suite runs, rather than relying on a warm `.godot/` cache.
4. **Make the windowed probes robust to contention**, or state plainly that they require an
   uncontended machine and have `run_all.sh` say so when it detects other Godot instances.
   Do NOT add a blanket retry — a retry that hides a real intermittent bug is worse than the
   flake. If a retry is used at all it must report that it retried, loudly.

## Acceptance criteria

- [ ] `_boot()` defaults to a pinned seed in every test file; opt-outs are explicit and justified
- [ ] Everything pinning surfaces is fixed, with any product (not test) bugs called out
- [ ] The import race is closed
- [ ] `run_all.sh` run 5 times in a row on an unchanged tree: 5/5 identical results
- [ ] No blanket retry; any retry is reported

## Blocked by

- nothing
