# 76 — "Family" -> "Army"; "Family" becomes the word for a piece chain

Status: todo — SPECCED (user ruling 2026-08-31) · ready

## Parent

`.scratch/gdd-gaps/PRD.md`

## The ruling

Two swaps, in opposite directions:

1. **What we shipped as a "Family" is an Army.** Revert the display term: Family -> **Army**,
   Family Power -> **Army Power**, Family Ability -> **Army Ability**.
2. **"Family" is reassigned to mean a piece chain** — a promotion line (Pawn -> Ranger -> ...)
   is a **Family** of pieces.

## This is cheap, and the reason is worth noting

**The code never stopped calling them Armies.** `Tuning.ARMIES` kept its name, the save key
stayed `army`, and the ids stayed `Crown` / `Wild Hunt` / `Old Guard` / `Syndicate` / `Cult` /
`Horde` — because of the standing convention that **ids are load-bearing and display names are
not**. Issues 50, 65 and 67 all followed it (`bounty` kept its key through a rename, Apocrypha
kept `bible-gag-reel-scroll`, The Muster kept `Crown`).

So this rename touches **display strings and the `families.gd` symbol names**, not data, not
saves, and not a single id. The convention that felt pedantic three times over is the reason
today's reversal is a morning's work instead of a migration.

### Scope

- Rename `game/scripts/families.gd` -> `armies.gd`, and its `Families` symbol -> `Armies`,
  everywhere it is preloaded. Same for `game/tests/test_families.gd` -> `test_armies.gd` —
  **note a `test_armies.gd` already exists** (it holds the army-composition balance rules), so
  these must be **merged**, not clobbered. That older file was rescoped in issue 68; keep both
  sets of assertions.
- `run_all.sh`'s suite list follows the file rename.
- Display strings: "Choose your Family" -> "Choose your Army", the chips, the confirm dialogs,
  `guide_text.gd` if it mentions Families, and the Games History labels.
- Run-state and save fields named `family_*` (e.g. `family_ability_used_this_wave`,
  `family_targeting`) — **renaming a persisted field is NOT additive.** Either keep the save
  key and rename only the in-memory symbol, or bump `SAVE_VERSION` with a migration. **Keeping
  the save key is strongly preferred** — it is exactly what the convention above exists for,
  and slice 69 is already spending the migration table's first entry. Say which you chose.

### The second half: "Family" as a piece chain

Reassign the freed word. A promotion chain is now a **Family** of pieces.

- Update `data/promotions.js`, the codex/promotion pages that say "chain", and `guide_text.gd`.
- **Do not rename the code's `next` field or the `base_piece_pool` logic** — that is internal
  and load-bearing in the same way.
- Notion: the **Promotions** page and any page describing chains. Retitle where it reads
  naturally; add a `> Reconciled <date>` note recording the term change.
- The Notion **Families** page (created for the Army concept) must be **retitled to Armies**,
  and a *new* Families page created for chains — or the old one repurposed and the Army content
  moved. Decide, and do not leave two pages both called Families.

## Acceptance

- No player-visible "Family" refers to an Army; no player-visible "chain" where "Family" now
  reads better.
- **No id, save key or catalog key changed** — assert an existing save still loads.
- `test_armies.gd` holds both the old composition rules and the new Army Power/Ability tests.
- `run_all.sh` ALL GREEN (`timeout: 600000`, blocking, alone).

## Blocked by

- nothing (but sequence after slice 69 — both touch `test_families.gd` fixtures)
