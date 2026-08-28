# 15 — Artefact trigger engine

Status: done

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

**116 of the 180 artefacts are `Trigger` type**, the other 64 `Passive`. Today the game
tests artefacts ad hoc — `for t in artefacts: if t.key == "move"` scattered through
`game.gd` and `economy.gd`. That is fine for 7 and unworkable for 180.

Build the dispatch layer the catalog implies. Reading the effect texts, the trigger points
are roughly:

- `on_capture(attacker, victim)` · `on_piece_lost(piece)` · `on_deploy(piece, tile)`
- `on_wave_clear(wave)` · `on_wave_spawn(wave)` · `on_milestone(wave)`
- `on_turn_start` / `on_turn_end` · `on_shop_restock` · `on_purchase(slot)`
- `on_gold_change` / `on_score_change` · `on_box_open`

Passives are the same mechanism read at the point of use — a `%` modifier collected from
every held artefact rather than a branch per artefact.

⚠️ **This is slice 13 (hook architecture) arriving for a real reason.** Slice 13 was
parked as a refactor with no player-facing value; 180 artefacts are that value. Build the
hook system here, against a real consumer, and either close 13 or reduce it to "migrate
the tariff system onto the same hooks".

Two things to get right early, because they are expensive later:

- **Stacking.** Artefacts stack (the same one can be held twice). Percentage modifiers
  must compose predictably — decide additive vs multiplicative once and write it down.
- **Ordering.** When several artefacts modify the same number, the result must not depend
  on acquisition order. Sort by a stable key inside the dispatcher.

## Acceptance criteria

- [x] A hook registry with the trigger points above, and artefacts registering against it
- [x] The 7 existing effects migrated onto it with no behaviour change
- [x] Stacking rule chosen, documented, and covered by a test with 2 copies of one artefact
- [x] Modifier order is independent of acquisition order — asserted by a test
- [x] Slice 13 closed or reduced, with the decision recorded
- [x] `run_all.sh` all green

## Blocked by

- 14 — catalog pipeline

## Outcome

Built `game/scripts/artefact_hooks.gd`: a static dispatcher over the live game node `g`,
following the existing `economy.gd`/`wave_logic.gd` pattern (no `class_name`, no
Callables — a `REGISTRY` Dictionary of `key -> [hooks]` plus a `match [key, hook]:` body,
which is the idiom this codebase already uses for tariff dispatch). `HOOKS` lists all 13
trigger points from the issue; only the 7 core effects have registry entries + match
cases today — slices 16-20 add one REGISTRY line + one match case per artefact, no call
sites touched again.

**Migrated (no behaviour change):**
- `economy.gd:capture_score` -> `on_capture` (Greed, Score, Bounty, Lifesteal,
  First-Capture Extra)
- `game.gd:_begin_player_turn` -> `on_turn_start` (Move)
- `wave_logic.gd:queue` (milestone branch) -> `on_milestone` (Timer)

**Stacking rule: additive per copy.** Each held copy is its own entry in `g.artefacts`
(save_config.gd, shop.gd already model it that way), and `run()` dispatches once per
held copy, so two Greeds add +10 and +10 = +20, not +10 compounded multiplicatively.
This is exactly how the pre-migration `for t in g.artefacts: match t.key` loop already
behaved — the migration didn't change the rule, it documented and locked in the one
already implicit in the data model. Covered by `test_items.gd` ("two Greeds stack
additively (+10 each), not multiplicatively").

**Ordering rule: `run()` sorts held artefacts by `key` before dispatching**, so a result
touched by several artefacts never depends on acquisition order. For the 7 core effects
this was already true (every handler just adds to a counter, and addition is
commutative), but the sort makes it a structural guarantee for slices 16-20, where a
non-commutative handler (e.g. a "set to X" effect) could otherwise make the bug real.
Covered by `test_items.gd` ("capture score is independent of artefact acquisition
order", comparing `["greed","score","bounty"]` vs `["bounty","score","greed"]`).

**Slice 13 verdict: reduced, not closed.** This slice built the hook registry against
one real consumer (artefacts) as slice 13 asked for, but scope discipline for slice 15
was "build the engine and migrate the 7" — it deliberately did not touch the tariff
system (`economy.gd:apply_tariff`/`tariff_on`, still direct `match t.key` over
`g.tariffs_active`) or Piece Buffs (`buff_logic.gd`, already its own direct-call module,
not registered through `ArtefactHooks`). Slice 13's original acceptance criterion — "at
least Piece Buffs and the tariff system registered through hooks" — is therefore still
open. `.scratch/gdd-gaps/issues/13-hook-architecture.md` Status updated to reflect the
narrower remaining scope: migrate the tariff system onto `ArtefactHooks` (Piece Buffs
left as a separate, already-modular system unless a future slice finds a concrete reason
to unify them — no player-facing motivation for that exists yet, mirroring 13's own
original "no player-facing value" framing).

`run_all.sh`: ALL GREEN (see PR).
