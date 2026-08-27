# 01 — Run seed & deterministic resume

Status: done

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

The GDD [Game Flow — Run](https://app.notion.com/p/367f1559c99b81f2a444f2f88e68ad8d)
specs a **Game Seed System**: every run is generated from a seed that drives the RNG
stream behind wave rolls, box-pick contents and AI decisions, and *"the seed is captured
with the run so a mid-run save can resume deterministically."*

The prototype calls `rng.randomize()` (`game.gd`) and never stores the result, so a
resumed save re-rolls every future random decision. This is not on the divergence list —
it is an unimplemented spec, and it silently makes saves non-reproducible.

1. **Capture the seed.** Roll one at run start, keep it as run state, and seed `rng`
   from it instead of `randomize()`.
2. **Persist it** through `save_config.gd` alongside the rest of the run state, and
   restore it on load.
3. **Persist the stream position too.** A seed alone is not enough — resuming must
   continue the stream, not restart it. `RandomNumberGenerator.state` is the cheap way;
   save and restore it with the seed.
4. **Scenarios stay deterministic on demand.** A scenario config may pin a seed so a
   bug can be replayed exactly; without one it rolls as usual.

## Acceptance criteria

- [ ] A run has a seed in its state, set once at start
- [ ] `rng` is seeded from it — no bare `randomize()` on the run path
- [ ] Seed and stream state round-trip through save/load
- [ ] Saving mid-run, reloading, and playing on produces the same rolls as not reloading
- [ ] A scenario may pin a seed; unpinned scenarios still vary
- [ ] `game/tests/run_all.sh` all green

## Blocked by

- nothing
