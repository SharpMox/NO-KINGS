# 22 — Artefacts: Tariff interception (filter / scale / choose / cancel / invert)

Status: todo

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

- [ ] `apply_tariff` supports a cancel/veto path (Salvation Gift Card) with
      the same immutable-base-ctx contract the other hooks use
- [ ] `tariff_on`/`Economy.gain` support a filter/scale path (Panama Papers
      Shredder, Ark Grounding Cable, Amber Room Bubble Wrap) without every
      one of their call sites needing a bespoke edit
- [ ] SETI's Red Marker needs an "equivalent bonus" table before it's
      triaged further — Notion question, not a guess
- [ ] Exhibit 399's choice UI is a design question (does it block input like
      the Buff Pick modal?) before any code — Notion question
- [ ] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine
- 19 — Special + prereq triage (this file is one of its splits)
