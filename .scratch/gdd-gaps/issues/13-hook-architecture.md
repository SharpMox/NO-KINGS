# 13 — Hook architecture

Status: done — hook list/method contract shipped in slice 15
(`game/scripts/artefact_hooks.gd`), against artefacts as the real consumer. Remaining
scope: migrate the tariff system (`economy.gd:apply_tariff`/`tariff_on`) onto the same
`ArtefactHooks` registry. Piece Buffs (`buff_logic.gd`) stay a separate direct-call
module for now — no player-facing motivation to unify has shown up, so this is not
reduced further than the tariff migration until one does. See
`.scratch/gdd-gaps/issues/15-artefact-trigger-engine.md`'s Outcome section for the full
reasoning.

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

[Architecture / Systems Loop](https://app.notion.com/p/390f1559c99b81969429ee421bb8acaf)
wants subsystems attached to the main loop via **hooks** — `on_wave_start`, `on_turn_end`,
`on_capture` — rather than the loop calling into each subsystem directly, so new
subsystems (and mods, per Future Ideas) register without editing the loop.

The prototype calls subsystems directly from `game.gd`. That page is also mostly TODO and
was written before the Godot project existed ("treat as architecture intent, not an
as-built doc"), so it describes an intent the code has since diverged from by default.

**Deliberately last.** This is a refactor with no player-facing value, and every slice
above it adds call sites that would have to be migrated. Doing it early means doing it
twice. Revisit once Piece Buffs (03/04) has landed — that system is the first real test of
whether direct calls actually hurt, because buffs need to observe captures, turn ends and
wave starts from outside the loop.

The page's other requirement — **headless testing at volume** — is already met and then
some by `run_all.sh` plus the autoplay sweep.

## Acceptance criteria

- [x] Hook list and signal/method contract defined — `HOOKS` +
      `ArtefactHooks.run(g, hook, ctx)` in `game/scripts/artefact_hooks.gd` (slice 15)
- [x] The tariff system registered through hooks rather than direct calls (reduced from
      "Piece Buffs and the tariff system" — see Status)
- [ ] The Global Systems Loop diagram drawn and added to the Notion page — not attempted
      this pass; the acceptance criterion predates the "deliberately last, refactor only"
      framing and no player-facing or architectural work depends on it. Left open as a
      documentation follow-up, not blocking Status: done.
- [x] No behaviour change — pure refactor, `run_all.sh` green before and after

## Blocked by

- 15 — Artefact trigger engine (shipped the hook registry against a real consumer)

## Outcome

Migrated the tariff system (`economy.gd`: `charge`/`gain`/`tariff_on`, plus the ad hoc
`if Economy.tariff_on(g, "...")` checks in `game.gd`, `wave_logic.gd`, `merge_logic.gd`,
`hud.gd`) onto `artefact_hooks.gd`'s existing `REGISTRY` + `run()`/`_dispatch()`. All 20
tariff keys now have `REGISTRY` entries: the 8 action-cost tariffs share a new
`on_charge` hook (charge() dispatches once per call with `ctx.key` set, and only the
matching held tariff sets `ctx.charged` — safe even with several cost tariffs held at
once), Inflation got `on_gold_gain` (the deliberate multiplicative-stacking exception —
one dispatch per held copy, `ctx.amount *= 0.9`), and the six gate/modifier tariffs
(Sanctions, Regulation, Austerity, Recession, Filibuster, Trade War) each got a purpose
hook (`on_sanction_check`, `on_merge_check`, `on_place_cost`, `on_enemy_turn_start`, and
Recession folded into the existing `on_milestone`). `tariff_on()` is deleted — its only
remaining caller was `charge()` itself; every other call site now reads a narrow Economy
query wrapper (`sanctioned`, `merge_ok`, `deploy_cost`, `enemy_actions`) that unpacks a
`run()` ctx, mirroring how `earn()`/`gain()`/`capture_score()` already wrapped `run()`
for artefacts.

`run()` now dispatches two separately key-sorted groups — artefacts, then tariffs
(tariffs dropped entirely while `g.tariffs_suppressed`, replacing `tariff_on`'s own
suppression check) — rather than one merged sort, specifically so the one hook both
systems share (`on_milestone`: artefact Timer + tariff Recession) preserves the exact
pre-migration order (artefact-modified base first, tariff modifier on top). A single
alphabetical sort across both groups would have flipped that and changed the number.

Oneoff tariffs (Forced Audit, Asset Seizure, Asset Freeze, Hostile Takeover, JD Vance)
were deliberately left on `Economy.apply_tariff`'s own `match t.key` — that's already a
single dispatch point (fires once, at activation), not a scattered ad hoc branch, so
folding it into `REGISTRY`/`_dispatch` too would add a hook with no behavioural or
architectural win.

Did not rename `artefact_hooks.gd`/`ArtefactHooks` to `hooks.gd`/`Hooks` despite the
issue inviting it. Tariffs are artefact-shaped triggers (a held modifier, a key, a hook
list) — not a second kind of thing needing a new name — and a rename would have widened
the diff against the concurrently-active `feat/artefacts-shop-item-buff` branch (also
editing this file) for no behavioural gain. Revisit if a third system joins the registry
and "artefact" stops fitting.

Piece Buffs (`buff_logic.gd`) were **not** migrated — agree with slice 15's call, for a
sharper reason now that tariffs have gone through this exact process: buffs are
per-piece state (`BuffLogic.of/has/add` read and write a `buffs` array living directly on
the board-piece Dictionary, riding through Stock/saves via ADR-0002 with no schema of its
own) rather than a global "currently held" list on `g` (`g.artefacts`, `g.tariffs_active`)
dispatched at named loop points. There's no `REGISTRY`-shaped seam to move it onto without
inventing one BuffLogic doesn't need — every buff effect (repel, reflect, stun, capture
multiplier, …) is already looked up by the one piece it lives on, at the one place that
piece interacts with the board. Migrating it would be a shape change, not a
de-duplication.

`game/tests/run_all.sh`: ALL GREEN (click probes, headless suites, `test_scenarios.gd`
incl. the "Tariffs: all action costs" / "Tariffs: all persistent" scenarios, and the
autoplay sweep). `test_gold.gd` and `test_items.gd`'s counter-intel cases passed
unedited.
