# 69 — Remove the six legacy core Artefacts

Status: done — PR fix/remove-core-artefacts-69

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

## Outcome

All seven of `ARTEFACT_EFFECTS_CORE` removed from `game/data/items.gd`; the
constant itself is gone (not left empty), and `_build_artefact_effects` is now
just "the catalog entries flagged implemented" — confirmed exactly 180 by
`test_assets.gd` ("ALL 180 ARTEFACTS PRESENT").

**Migration**: `save_config.gd` `SAVE_VERSION` 1 → 2, first real `_MIGRATIONS`
entry (`_migrate_1_to_2`) filters the 7 removed keys out of a loaded save's
`artefacts` and clears `ecdysis_copy_key` if it names one. Proven in
`test_save.gd` two ways — directly against `SaveConfig.migrate()`, and against
a live `_boot()`'s restored state (`ecdysis_copy_key` in particular, since
`apply()` copies that field verbatim with no catalog check of its own) —
empirically verified to fail without the migration (temporarily stubbed the
`match` case to a no-op and re-ran: 3 of 4 targeted assertions failed) before
restoring it.

**Repointed fixtures** (catalog artefact with the closest matching shape,
never deleting the invariant being proved):
- `greed`/`score` (flat +10 on-capture, no other side effect) → mostly
  **Library of Alexandria Matchbox** (`+1 Gold and +10 Score per Stock
  piece`, with 1 piece in Stock — a literal flat +10/+1 per copy, matching
  the removed keys' arithmetic unchanged) and, where a test also asserted an
  exact Gold value that Matchbox's own Gold side-effect would have polluted,
  **Voynich Dictionary** (`double Score/Gold on the Wave's first Capture` —
  pure `ctx.pts`, no Gold write) paired with an empty-Stock Matchbox as an
  inert second "fired" artefact.
- `first_capture_extra` → **Stargate Divination Crystal** (identical
  "first Capture of the Turn refunds its Action" shape) — also the repoint
  for slice 67's Wild Hunt/`first_capture_extra` stacking test
  (`test_families.gd`).
- `move` → **CIA Exploding Cigar** (identical flat +1 action/turn).
- `bounty` (order-independence filler) → **Suspiciously Large Femur**.
- `lifesteal` → no surviving catalog Artefact grants Clock on `on_capture`
  (verified: none), so its one scenario fixture (`data/scenarios.gd`, "slice
  35") was repointed to **2012 Doomsday Party Hat** (`on_gold_change`, still
  exercises the `add_clock()` choke point, just via a different hook) with a
  comment noting the gap.
- `timer` → no surviving catalog Artefact is on `on_clock_refill` either
  (only the Recession tariff remains); `test_items_artefacts_1.gd`'s
  on_clock_refill-rename test was narrowed to prove the hook still fires via
  the tariff alone — the artefact-then-tariff *ordering* it used to also
  prove is no longer exercisable by anything, noted in the test comment.

**Pinned-seed / fixed-layout casualty (not a value drift, a UI one)**: the
"Artefacts: slice 35" scenario's repoint originally also renamed its display
name to mention the new key. That broke `test_menu_clicks.gd` (`Back
restores the main menu` / `scenario list hidden again` / `scenario click
stages its config` — all three, reproducibly, 3/3 with the change vs 2/2
clean without it, bisected by reverting individual scenario edits one at a
time and confirming with `git stash`/`git checkout HEAD -- <file>` against
the same background process load throughout, ruling out contention). Root
cause: a longer scenario-list button label overflows the fixed 480×800
portrait menu's `TEST` `ScrollContainer` enough to misposition the trailing
"← Back" button. Fixed by keeping that one scenario's display name unchanged
(only the artefact key was repointed) with a comment explaining why.

Split suites intact (all 7 `test_items*.gd` files, unchanged entries in
`run_all.sh`). `run_all.sh` final line: `ALL GREEN`.
