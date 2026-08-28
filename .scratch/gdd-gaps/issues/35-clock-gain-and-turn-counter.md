# 35 — Clock-gain choke point & run-long turn counter

Status: todo — INDEPENDENT (no design decision needed)

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
