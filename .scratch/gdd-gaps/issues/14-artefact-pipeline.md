# 14 — Artefact catalog pipeline

Status: done

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

The reference site knows all **180 artefacts** (`data/artefacts.js`, generated from the
Notion [Artefacts](https://app.notion.com/p/dcfc4879530547c785278f198b85f3cb) DB). The
game hand-writes **7** in `items.gd` as `ARTEFACT_EFFECTS`. There is no pipeline between
them, so the two drift by construction — exactly the failure mode slices 01–02 spent
their time cleaning up, and at 180 rows it will be far worse.

1. **Export, don't retype.** A `tools/export-game-artefacts.mjs` beside the existing
   `export-game-pieces.mjs`, writing `game/data/artefacts.json` from `data/artefacts.js`:
   key, name, rarity, bonus tags, type (Passive/Trigger), effect text, and the
   conspiracy name for flavour.
2. **Stable keys.** The site data has no key field — only `name`. Derive a kebab-case key
   and **assert uniqueness at export time**; a silent collision would merge two artefacts.
3. **`implemented` flag.** 173 of the 180 have no code behind them. The catalog carries a
   flag, and only implemented artefacts are rollable, sellable or grantable. An artefact
   that does nothing when bought is worse than one that isn't offered — the pool grows as
   slices 16–20 land, and nothing has to be re-plumbed.
4. **Retire the hand-written list.** The 7 existing effects keep their keys so saves,
   scenarios and the shop keep working, but their definitions come from the export.

Nothing changes mechanically this slice. It is the seam everything after it hangs off.

## Acceptance criteria

- [ ] `game/data/artefacts.json` generated from `data/artefacts.js`, 180 entries
- [ ] Keys are unique, stable across re-runs, and asserted at export time
- [ ] The 7 shipped effects keep their current keys — no save or scenario breakage
- [ ] Only `implemented` artefacts can be rolled, sold or granted
- [ ] `test_assets.gd` (or a new check) fails if the catalog and the code disagree about
      which keys are implemented
- [ ] `game/tests/run_all.sh` all green

## Blocked by

- nothing

## Outcome

Shipped as specced. `tools/export-game-artefacts.mjs` (mirrors `export-game-pieces.mjs`)
derives a kebab-case key per artefact name, asserts uniqueness and asserts no collision
with the 7 shipped keys, then writes `game/data/artefacts.json`: 180 entries, each
`{key, name, rarity, type, bonus, effect, conspiracy, implemented}`.

`game/data/items.gd`: the 7 hand-written effects are unchanged content but renamed to
`ARTEFACT_EFFECTS_CORE` (keys untouched — saves/scenarios/shop are unaffected).
`ARTEFACT_CATALOG` loads the 180-entry JSON (same `FileAccess` + `JSON.parse_string`
pattern as `Rules.load_pieces()`). `ARTEFACT_EFFECTS` — the pool `shop.gd`/`box.gd`/
`economy.gd` actually roll, sell and grant from — is `ARTEFACT_EFFECTS_CORE` plus
whichever catalog entries are flagged `implemented`. No other `.gd` file changed.

**Decision (ambiguity call):** none of the 180 catalog effect texts correspond to the 7
shipped mechanics (checked by grep on distinctive phrases — no overlap), so all 180
start `implemented: false`. The 7 core effects predate the Notion Artefacts DB and have
no catalog row; they are not force-mapped onto unrelated flavour entries, since that
would make an artefact's displayed effect text lie about what it does. The seam is real
today: slices 16-20 flip a catalog entry's flag and add its `economy.gd` case, and the
roll pool picks it up with no shop/box changes.

`game/tests/test_assets.gd` extended: asserts the catalog has exactly 180 unique keys,
no catalog key collides with a core key, and every `implemented: true` catalog entry has
a matching `ARTEFACT_EFFECTS` entry (catalog/code agreement, per acceptance criteria).

`game/tests/run_all.sh` — ALL GREEN (click probes + full headless suite + autoplay).
