# 28 — Milestone wiring gaps and two grant-pool leftovers

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## Found by

The agent implementing `fix/artefact-rulings` (2026-08-28), while making the 5-Wave
Milestone per-artefact. It surfaced these, correctly declined to fix them as out of scope,
and documented them — filed here so they do not rot in a PR body.

## 1. Only 8 of the 12 "5-Wave Milestone" artefacts were actually wired

The per-artefact milestone fix replaced 8 in-code `% 5` checks. The other four were never
on that beat at all:

- **John Titor's Crypto Wallet** — wired to the **global `on_milestone` hook**, which fires
  every **10** waves. Its text says 5-Wave Milestone. This is a pre-existing bug, not
  something the milestone rework introduced, and it means the artefact has been paying out
  at half the intended rate.
- **Mar-a-Lago Toilet Papers**, **Yalta Cocktail Napkin**, **Roanoke Hex Kit** — no REGISTRY
  wiring at all. They are catalogued and (per their Outcomes) deliberately unimplemented,
  but worth confirming they are still flagged `implemented: false` so nothing offers them.

## 2. Holy Lint's grant pool still spans every tier

Issue 27 fixed the `critical` / `range` self-consumption for grant-on-capture. The same
class remains for the Decisive buffs: a randomly granted **Bomb** can detonate on the very
capture that granted it, and **Trap** / **Multicapture** have adjacent timing questions.
Not named in issue 27's brief, so deliberately left alone.

Worth deciding alongside: should random grants be restricted by *tier* (Tactical only, the
way MK-Ultra Sugar Cube already is), rather than the whole 12?

## 3. The echo layer loses the per-copy acquisition stamp

`artefact_hooks`' echo/meta-trigger layer (Polybius Cartridge, Max Headroom Mask, CERN
Ctrl+Z Shortcut…) dispatches by **bare key**, so when it re-fires a 5-Wave Milestone
artefact the handler falls back to `acquired_wave = 1` instead of that specific copy's real
stamp. Two copies acquired on different waves would echo on the wrong beat.

No test exercises echo + milestone together, which is why it was invisible.

## Acceptance criteria

- [x] John Titor's Crypto Wallet moved onto the per-artefact 5-wave helper
      (`fix/blitz-and-crypto-wallet`, 2026-08-28 — user-reported; registered
      on `on_wave_clear` + `_milestone5_hit`, same as silk-road-coupon /
      crop-circle-plank / ark-s-bunkbed)
- [x] The three unwired artefacts confirmed `implemented: false`, or wired
      (`fix/issue-28-wiring`, 2026-08-28 — all three still `false` in
      `data/artefacts.js`/`game/data/artefacts.json`; no live bug. Audit also
      added a general regression test: every `implemented: true` artefact
      must have a REGISTRY entry or be a documented standing-rule exception —
      see test_items.gd's issue 28 section)
- [ ] Decision recorded on whether random grants are tier-restricted — open
      question below, not decided by this fix
- [x] Echo layer carries the artefact entry (not just its key) so `acquired_wave` survives
      (`fix/issue-28-wiring`, 2026-08-28 — `run()`'s `fired` array now holds
      the held-copy entry, not the bare key; `_run_meta_triggers` reads
      `entry.get("acquired_wave", 1)` off it instead of the `_dispatch`
      default. The re-entrancy guard (`fired`/`_run_meta_triggers` never
      re-entering `run()`, backstopped by `artefact_echo_depth`) is untouched)
- [x] A test covering echo + a milestone artefact together
      (`fix/issue-28-wiring`, 2026-08-28 — test_items.gd: John Titor's Crypto
      Wallet (acquired wave 2) + Max Headroom Mask; before the fix the echo
      dispatch defaulted to `acquired_wave=1` and paid nothing on this copy's
      real beat (wave 6), so the held copy under-paid by half on every echo)
- [x] `run_all.sh` all green

## Outcome

Items 1 and 3 are fixed on `fix/issue-28-wiring` (PR pending). Item 2's tier-restriction
question is **not decided here** — it needs your call, not an agent's:

> **Should randomly-granted buffs (Holy Lint, Crop Circle Plank, Sugar Free Chemtrail
> Can, Xenu OT III Season Pass, Scientology E-Meter, MK-Ultra Sugar Cube, etc.) be
> restricted to drawing from the Tactical tier only — the way MK-Ultra Sugar Cube
> already is — instead of drawing from all 12 Piece Buffs including the Decisive ones
> (Bomb, Trap, Multicapture, Reflect)?**

If the answer is yes, that's the natural place to also close out the Bomb/Trap/
Multicapture self-consumption timing questions issue 27 left open for item 2 above —
restricting the pool sidesteps them rather than requiring separate per-buff timing
fixes. Left alone pending your answer.
