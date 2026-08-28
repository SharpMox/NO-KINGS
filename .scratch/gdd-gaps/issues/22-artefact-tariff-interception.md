# 22 — Artefacts: Tariff interception (filter / scale / choose / cancel / invert)

Status: done

## Parent

`.scratch/gdd-gaps/PRD.md`

## Split out of

19 — that slice added `on_tariff_apply` (economy.gd `apply_tariff`) and
`on_tariff_charge` (economy.gd `charge`), both reactive hooks that fire
*after* a Tariff has already taken effect. Everything left needing a Tariff
hook wants to change *whether or how* the Tariff applies, which those two
reactive hooks can't express — see issue 19's Outcome.

## What to build

| Artefact | Needs | Note |
| --- | --- | --- |
| Panama Papers Shredder | tariff filtering | "Mild Tariffs don't affect you" — `Economy.tariff_on(g, key)` would need to consult `g.artefacts` and the tariff's own `tier`, not just match on `key`; every one of `tariff_on`'s ~10 call sites would then silently start returning false for Mild tariffs while this Artefact is held |
| Ark Grounding Cable | tariff scaling | "Tariff penalties reduced by 50%" — same shape, but a multiplier on `charge()`'s `amount` rather than a boolean |
| Exhibit 399 | tariff choice | "when a Tariff would be applied: you choose between 2 options" — a UI decision point mid-`apply_tariff`, not a passive hook at all |
| Salvation Gift Card | tariff cancel | "when a Tariff would be applied: it is cancelled; recharges every 5-Wave Milestone" — needs `apply_tariff` to support a veto (mirrors on_item_consume's `ctx.cancel`, issue 19) plus a recharge-state field |
| SETI's Red Marker | tariff inversion | "on acquiring this Artefact: one random active Tariff is inverted into its equivalent bonus" — needs an "equivalent bonus" defined per Tariff (doesn't exist in `data/tariffs.gd`) before this is anything but a guess |
| Amber Room Bubble Wrap | (no needs-note, held back issue 16) | "ignore Inflation and other gold-reducing Tariffs" — issue 16 called this "a bespoke branch inside Economy.gain() outside the hook system entirely"; still true, and it's the same shape as Panama Papers Shredder's filter, so triage it alongside that one rather than alone |

## Design note

`tariff_on()` is read very often (every `charge()` call plus assorted direct
checks). Panama Papers Shredder / Amber Room Bubble Wrap both want it to
start lying about which tariffs are "on" while held — cheap to write, easy
to get subtly wrong (e.g. `Economy.gain()`'s Inflation loop doesn't go
through `tariff_on()` at all, it walks `g.tariffs_active` directly, so Amber
Room Bubble Wrap needs its own check there, not a `tariff_on()` patch).
Worth designing both together rather than two near-identical special cases.

## Acceptance criteria

- [x] `apply_tariff` supports a cancel/veto path (Salvation Gift Card) with
      the same immutable-base-ctx contract the other hooks use
- [x] `tariff_on`/`Economy.gain` support a filter/scale path (Panama Papers
      Shredder, Ark Grounding Cable, Amber Room Bubble Wrap) without every
      one of their call sites needing a bespoke edit
- [x] SETI's Red Marker needs an "equivalent bonus" table before it's
      triaged further — Notion question, not a guess (raised, not built)
- [x] Exhibit 399's choice UI is a design question (does it block input like
      the Buff Pick modal?) before any code — Notion question (raised, not built)
- [x] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine
- 19 — Special + prereq triage (this file is one of its splits)

## Outcome

4 of 6 artefacts shipped (`implemented: true`), 2 left unimplemented as
genuine Notion questions rather than guesses.

**Shipped:**

- **Panama Papers Shredder** (filter) — `on_charge`'s 6 Mild-tier action-cost
  keys (move_cost/ability_cost/capture_cost/pass_cost/long_range_cost/
  box_cost) were split from the 2 Moderate keys (deploy_cost/fuse_cost) into
  their own match case, gated on a new `ctx.mild_blocked` flag Panama sets
  (artefacts dispatch before tariffs in `run()`, so the flag is set before
  the gated tariff's own case reads it — same ordering `on_milestone`
  already relied on). `inflation` (the one Mild `on_gold_gain` tariff) is
  gated the same way via `ctx.gain_immune`. No `tariff_on()`-style call-site
  sweep was needed — issue 13 already replaced it with narrow query
  wrappers, and Mild tariffs turn out to only ever reach the game through
  `on_charge`/`on_gold_gain`, both hooks already shared with tariffs.
- **Amber Room Bubble Wrap** (filter) — designed together with Panama per
  the issue's own note: shares `ctx.gain_immune` on `on_gold_gain`. The
  "bespoke branch in `Economy.gain()`" the issue worried about no longer
  exists post-issue-13 — `Economy.gain()` already dispatches Inflation
  through this same hook, so both artefacts are one shared ctx flag, not a
  new call site.
- **Ark Grounding Cable** (scale) — `Economy.charge()` grew `base`/`amount`
  ctx fields (mirroring `on_score_change`); Ark does `ctx.amount -= ctx.base
  * 0.5`, off the immutable base like every other percentage handler, so
  the charged amount is halved and `on_tariff_charge` reports the actual
  (reduced) amount.
- **Salvation Gift Card** (cancel) — `Economy.apply_tariff()` grew
  `ctx.cancel`, checked right after the `on_tariff_apply` dispatch; a veto
  skips the oneoff match / persistent append entirely. Same-hook reward
  handlers (Merchants of Death Sample Case) still fire regardless of
  key-sort order — this mirrors the existing on_piece_lost/Fireproof
  Pajamas precedent (issue 24) rather than reordering dispatch to favor one
  handler. Recharge state is a new `g.salvation_charged` field (starts
  `true`, consumed on veto, restored `on_wave_clear` at `wave % 5 == 0`,
  the same cadence Silk Road Coupon already established in issue 18).

**Left unimplemented — Notion questions, not guesses (matches the
acceptance criteria verbatim):**

1. **Exhibit 399** ("choose between 2 options") — needs a design ruling on
   whether the choice blocks input like the Buff Pick modal, before any
   code. Not attempted.
2. **SETI's Red Marker** ("inverted into its equivalent bonus") — needs an
   "equivalent bonus" table per Tariff that doesn't exist in
   `data/tariffs.gd` today (e.g. what's Sanctions' inverse? Filibuster's?).
   Guessing one in code would be exactly the kind of guess this issue's
   acceptance criteria rules out. Not attempted.

### Tests

`game/tests/test_items.gd` gained 8 checks covering all 4 shipped
artefacts: Panama Papers Shredder blocking a Mild action-cost charge while
leaving a Moderate one untouched, Panama Papers Shredder and Amber Room
Bubble Wrap each independently neutralizing Inflation, Ark Grounding
Cable's 50% charge reduction, and Salvation Gift Card's cancel-then-spent-
then-recharge lifecycle across two tariff activations and a wave clear.
`game/data/scenarios.gd` gained "Artefacts: slice 22 (tariff interception)"
holding all 4 shipped keys against a Mild/Moderate/persistent tariff mix,
swept by `test_scenarios`. `game/tests/run_all.sh` — ALL GREEN (existing
`test_gold.gd` tariff assertions and `test_items.gd`'s Counter-Intel cases
both still pass unmodified — the new ctx fields are additive and default
away when nothing new is held).
