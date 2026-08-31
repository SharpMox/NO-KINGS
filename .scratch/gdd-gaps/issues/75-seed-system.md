# 75 — Player-facing seeded runs

Status: done (2026-08-31)

## Parent

`.scratch/gdd-gaps/PRD.md`

## The ask

> *"the game's RNG and AI moves will need to be the same in an exactly similar setup. So we
> can do seeded runs with crazy seeds that give perfect RNG."*

## The hard part is already done — audited, not assumed

Three properties that would each normally be weeks of work, all already true:

1. **Nothing bypasses the run's RNG.** A repo-wide grep for bare `randi()` / `randf()` /
   `randomize()` / `randi_range()` / `randf_range()` outside `g.rng` returns **nothing**.
   Every roll — waves, boxes, shop stock, buff grants, artefact procs — goes through the one
   generator.
2. **The AI is pure.** `rules.gd` contains no RNG at all. `ai_action` is a deterministic
   function of the board, so identical state gives an identical move.
3. **Seed *and* stream position are both saved** (`save_config.gd`: `seed` + `rng_state`), so
   a resumed run continues the same stream rather than restarting it.

The suite has depended on this daily for weeks: pinned-seed tests assert *which specific buff*
a roll produces, and when slices 47/48 shifted the stream those assertions moved predictably
rather than randomly. That is determinism demonstrated in production, not theory.

**So "same seed + same setup -> same run" already holds.** This slice is only the surface.

## What to build

1. **`--seed <value>` CLI flag**, alongside the existing `--army` / `--tier` / `--artefacts`
   flags in `game.gd`. Trivial, and it makes the rest testable.
2. **A seed field on the new-run screen.** Empty = random, as today. Accept any string —
   hash it to an int rather than demanding digits, so "crazy seeds" can be words.
3. **Show the seed on the results screen**, so a good run can be shared.

## The caveat that must be stated in-game, not just here

**Seeds are only stable within a build.** Any change to how many rolls happen — a new
Artefact, a reordered draw, a different wave roster — shifts every downstream result. Slices
47 and 48 each did exactly this to a pinned-seed test.

So a seed shared today will not reproduce after a content patch. That is normal for the genre,
but if seeds are shareable, **the build version should be displayed next to the seed** or
players will report "broken seeds" as bugs. Recommend showing `seed @ version`.

## Acceptance

- `--seed` works and is covered by a test: same seed twice -> identical outcome; different
  seeds -> different. **Assert both directions** — a test that only checks "same seed matches"
  passes trivially if the seed is ignored entirely and the game is deterministic by accident.
- The new-run field accepts arbitrary strings; empty stays random.
- Seed visible on the results screen, with the build version beside it.
- `run_all.sh` ALL GREEN (`timeout: 600000`, blocking, alone).

## Blocked by

- nothing

## Outcome — mechanism shipped, UI half remains

`--seed <anything>` (PR #253). Digits used as-is; anything else hashed, so words work.

**Proved end to end rather than asserted:**

```
--seed no-kings-42  ->  WIN, wave 50, score 105500, 666 turns
--seed no-kings-42  ->  WIN, wave 50, score 105500, 666 turns
--seed different    ->  LOSS, wave 47, score 78400
```

Identical to the turn count; a different seed diverges completely.

`test_seed.gd` asserts **both** directions deliberately — same-seed-reproduces alone would pass
even if the seed were ignored entirely, since the game would then be deterministic by accident.

### The UI half, shipped separately

- **Seed field on the difficulty screen** — the last step before a run starts, so it cannot be
  lost by backing out of a later step. Empty means random, exactly as before. `focus_mode` is
  `FOCUS_CLICK` deliberately: a text field that took focus on show would swallow the windowed
  click probes' keystrokes.
- **The results screen shows `seed <x> · build <y>`.** The build is there on purpose — a seed
  only reproduces within the build it was rolled in, since any content change that shifts how
  many rolls happen moves every downstream result (slices 47 and 48 each did exactly that to a
  pinned-seed test). Without the version, a seed that stops working after a patch looks like a
  bug rather than expected behaviour.

  Note `application/config/version` is unset in `project.godot`, so it currently renders
  "dev". Setting a real version is worth doing before seeds are shared publicly.
