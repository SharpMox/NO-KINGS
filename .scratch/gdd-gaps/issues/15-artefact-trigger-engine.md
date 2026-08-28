# 15 — Artefact trigger engine

Status: todo

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

- [ ] A hook registry with the trigger points above, and artefacts registering against it
- [ ] The 7 existing effects migrated onto it with no behaviour change
- [ ] Stacking rule chosen, documented, and covered by a test with 2 copies of one artefact
- [ ] Modifier order is independent of acquisition order — asserted by a test
- [ ] Slice 13 closed or reduced, with the decision recorded
- [ ] `run_all.sh` all green

## Blocked by

- 14 — catalog pipeline
