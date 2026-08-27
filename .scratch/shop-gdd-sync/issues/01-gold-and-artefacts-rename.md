# 01 — Rename money → Gold, trinket → Artefact

Status: todo

## Parent

`.scratch/shop-gdd-sync/PRD.md`

## What to build

A total, behaviour-neutral rename bringing the code in line with the GDD's ratified vocabulary. `money` becomes `gold` and `trinket`/`trinkets` become `artefact`/`artefacts` everywhere: run state on the game node, `economy.gd`, `shop.gd`, `save_config.gd` keys, HUD labels and the inventory drawer, item descriptions that mention money, tuning constant names, comments, and the test suites (`test_money.gd` → `test_gold.gd`).

Save keys change with no back-compat shim (repo rule: no defensive code) — an old mid-run save simply starts Gold at 0 and holds no Artefacts.

## Acceptance criteria

- [ ] No occurrence of `money` or `trinket` remains in `game/` outside a deliberate historical note
- [ ] HUD shows Gold; the inventory drawer names Artefacts
- [ ] Save round-trip preserves `gold` and `artefacts`
- [ ] `test_money.gd` renamed to `test_gold.gd` and passing
- [ ] Behaviour unchanged: every other suite passes without edits beyond renamed identifiers
- [ ] `game/tests/run_all.sh` all green

## Blocked by

Nothing.
