# 35 — Clock-gain choke point & run-long turn counter

Status: done (2026-08-29)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Found by

Slice 30, which set out to implement Black Knight Morse Code and discovered it needs two
seams that do not exist. Both are worth building on their own merits, independently of the
one artefact that surfaced them.

## 1. There is no Clock-gain choke point

`clock_ms` is mutated **directly at ~20 sites** across the scripts — milestone refills, King
refills, the Continue bonus, box rewards, artefact handlers, the per-frame tick. Gold and
Score both route through `Economy.earn` / `Economy.gain`, which is precisely why they were
easy to hook: the artefact engine got `on_gold_change` and `on_score_change` for free.

The Clock has no equivalent, so **nothing can modify time**. That is a structural gap, not a
missing feature — the same one Gold and Score would have had if `Economy.earn` had never
existed.

Build `Economy.add_clock(g, ms, reason)` (mirroring `earn`), route every *gain* site through
it, and fire an `on_clock_change` hook with the same immutable-base ctx contract the other
two use. Leave the per-frame tick alone — that is a drain, not a gain, and hooking it would
fire every frame.

## 2. There is no run-long turn counter

Only `turns_since_wave` exists, and it resets on every Wave spawn. Anything phrased "every
Nth Turn" therefore cannot be written.

Add a run-long counter incremented at the single `_begin_player_turn` site, round-tripped
through `save_config.gd`.

## Then: Black Knight Morse Code

*"Every 3rd Turn: your Score and Clock gains that Turn are doubled."* With both seams above
it becomes an ordinary two-hook artefact.

## Acceptance criteria

- [ ] `Economy.add_clock` exists; every clock **gain** site routes through it
- [ ] `on_clock_change` hook, following the ctx contract in `artefact_hooks.gd`'s header
- [ ] The per-frame drain is deliberately NOT hooked, and says so in a comment
- [ ] Run-long turn counter, persisted through save/load
- [ ] Black Knight Morse Code implemented
- [ ] `run_all.sh` all green

## Blocked by

- nothing

## Outcome

Shipped in `a3b0261` (PR #145). Both seams built as their own thing, not as scaffolding
for one artefact:

- **`Economy.add_clock`** is now the single choke point for Clock gain, matching the
  shape `earn`/`gain` already had for Gold and Score. The ~15 direct `clock_ms` mutations
  named in FLAGS.md route through it, so any future effect that wants to modify time
  hooks one function instead of chasing call sites.
- **A run-long Turn counter** now rides in the run state and the save, alongside the
  existing `turns_since_wave` (which resets every Wave and could not answer "how long has
  this run been going").

`test_clock.gd` (96 lines) covers both. This unblocks Black Knight Morse Code; the two
FLAGS.md entries that named these gaps are now closed.
