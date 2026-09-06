# 01 — Rename money → Gold, trinket → Artefact

Status: done (verified 2026-09-06) — every acceptance criterion below was already
met; the file had simply never been closed. Audited across `game/`, `data/`,
`tools/` and the site: **zero** legacy identifiers, **zero** legacy save keys.
`g.gold`, `g.artefacts`, `Items.ARTEFACT_EFFECTS` and `ArtefactHooks` are the
live names; `TRINKET_EFFECTS` does not exist. The save keys are `"gold"` and
`"artefacts"` in both directions — there was never a `"money"` or `"trinkets"`
key to migrate.

The 32 surviving occurrences of "trinket" and 45 of "money" are all
non-load-bearing: prose in `CONTEXT.md` (a deliberate historical note), old PRD
text under `.scratch/`, the `money-and-shop` **directory name** cited in ~20 code
comments as design provenance, the Notion catalog key
`money-printer-service-manual`, and the English phrase "money printer" in balance
comments. None is a rename target.

The one legacy-shaped save key that does survive is unrelated to this issue:
`"family_ability_used_this_wave"` (issue 76), deliberately kept because renaming a
persisted key is not additive.

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
