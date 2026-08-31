# 69 — Remove the six legacy core Artefacts

Status: todo — SPECCED (user rulings 2026-08-30/31) · ready

## Parent

`.scratch/gdd-gaps/PRD.md`

## The ruling

> User, 2026-08-30, on the six game-native core Artefacts absent from Notion
> (`first_capture_extra`, `greed`, `move`, `lifesteal`, `score`, `timer`):
> **"remove them entirely please"**

This completes the original slice-50 principle — *only what the Notion DB describes
remains* — for six of the seven. The catalog becomes exactly the 180.

**The seventh goes too** (user, 2026-08-31). `bounty` / **"Skip Tracer's Rolodex"**
(*"+300 score when capturing a piece worth 50+"*) is removed with the rest, so the rule has
no exceptions: **the catalog is exactly the 180 in Notion.**

Its rename yesterday (issue 50) becomes moot work — noted without regret, since the
alternative was leaving a name collision standing while the question was open.

So **all seven** of `ARTEFACT_EFFECTS_CORE` go, and the constant itself should disappear
rather than be left as an empty array. `_build_artefact_effects` collapses to "the catalog
entries flagged implemented" — which is now all 180.

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

- nothing (slice 67 landed 2026-08-31)
