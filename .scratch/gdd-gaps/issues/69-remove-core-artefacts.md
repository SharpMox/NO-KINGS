# 69 — Remove the six legacy core Artefacts

Status: todo — SPECCED (user ruling 2026-08-30) · **after 67 lands** · one question open

## Parent

`.scratch/gdd-gaps/PRD.md`

## The ruling

> User, 2026-08-30, on the six game-native core Artefacts absent from Notion
> (`first_capture_extra`, `greed`, `move`, `lifesteal`, `score`, `timer`):
> **"remove them entirely please"**

This completes the original slice-50 principle — *only what the Notion DB describes
remains* — for six of the seven. The catalog becomes exactly the 180.

**Open question — the seventh.** `bounty` / **"Skip Tracer's Rolodex"** is the same
category (game-native, not in Notion) but was not in the list the user answered, and it was
*renamed* only yesterday. Remove it too, or does the rename mean it stays? One word
settles it; do not remove it without that word.

## Why this is the first real save-migration customer

These keys are load-bearing and REMOVAL is not additive:

- An old save can hold copies of the removed keys in `artefacts`. Loading them would create
  held effects with no handler — inert entries occupying Artefact-cap slots.
- **Bump `SAVE_VERSION` to 2** and write the first `_MIGRATIONS` entry: filter the removed
  keys out of `artefacts` (and `ecdysis_copy_key`, if it names one) on load. Assert an old
  v1 save containing `greed` loads cleanly with the entry gone.

## Everything that references them (verify, don't trust)

- `game/data/items.gd` — the six `ARTEFACT_EFFECTS_CORE` entries and the header prose about
  the seven; `_build_artefact_effects` keeps working (pool = catalog only + any survivor).
- `artefact_hooks.gd` — their REGISTRY entries and `_dispatch` cases.
- `data/scenarios.gd` — TEST scenarios use these as simple fixtures; re-fixture to catalog
  equivalents.
- **Tests** — many fixtures use `greed`/`move` as the "simple artefact" (the stacking tests
  "two Greeds stack additively" / "Greed+Score order", `test_save.gd`'s rich fixture holding
  `["greed","greed","move"]` with `ecdysis_copy_key: "greed"`, and others). Re-fixture to
  catalog artefacts with the same shapes (flat +Score on capture, +1 Action, etc.). The
  stacking/ORDERING invariants those tests prove must survive — repoint, never delete.
- **⚠ Slice 67 (in flight) asserts Wild Hunt's Power stacks with `first_capture_extra`.**
  After removal, repoint that pair-test at a surviving refund artefact — Stargate
  Divination Crystal is the natural choice. This is why the slice waits for 67.
- Notion — the Artefacts page "Known gap: 7 game-native Artefacts" section becomes a
  resolution note: six removed (date, ruling), one renamed/pending the question above.

## Acceptance

- The six are gone from every pool: never rolled, sold, granted, or loadable.
- v1 save with removed keys migrates cleanly; **assert the restored state**, not identity.
- All repointed tests still prove their original invariants.
- Split suites intact; `run_all.sh` ALL GREEN (`timeout: 600000`, blocking, alone).

## Blocked by

- slice 67 (shares fixtures and the stacking test)
- the Skip Tracer's Rolodex question
