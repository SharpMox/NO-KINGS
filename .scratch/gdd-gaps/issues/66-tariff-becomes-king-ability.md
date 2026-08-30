# 66 — Retire "Tariff": the mechanic is now "King Ability"

Status: done (2026-08-30)

## Parent

`.scratch/gdd-gaps/PRD.md`

## The ruling

The Kings + Tariffs rework begins with terminology:

- The generic mechanic — a King imposing effects on the player — is now called a
  **King Ability**.
- **"Tariff" survives only as the name of Donald Trump's King Power** (`donald_trump`,
  Suit tier, verified in `data/kings.gd:43`).
- Each King will eventually carry one **King Power** (static, always active) and **2-3
  King Abilities** (active effects). Mirrors the new Family structure. That content design
  is a LATER pass — this slice is names and documents only.

## Scope split: player-facing now, code identifiers at the rework

**Rename now** — everything a player or designer reads:
- The 10 Artefact card texts naming Tariffs (Panama Papers Shredder, Merchants of Death
  Sample Case, Amber Room Bubble Wrap, Tunguska Toothpicks, Antikythera Warranty Card,
  Salvation Gift Card, SETI's Red Marker, Fireproof Pajamas, Ark Grounding Cable,
  Exhibit 399) + **Counter-Intel** in `game/data/items.gd`. Mechanical retext
  "Tariff" -> "King Ability", via `data/artefacts.js` + the exporter.
- **Tier adjectives stay for now** ("Mild King Abilities don't affect you") — whether the
  Mild/Moderate/Severe ladder survives the Kings redesign is that pass's decision, and
  guessing it here would just churn the cards twice.
- UI strings: `modals.gd:849` "Active tariffs", the two "Tariffs seen" stats lines
  (`modals.gd:152,193`). **Check the windowed click probes** — they exercise the tariff
  overlay and may match on text.
- Notion: retitle **King Tariffs (concept)** -> **King Powers & Abilities**. Keep the old
  cadence math as a clearly-marked legacy section (it was recomputed twice this session —
  do not delete it, mark it superseded-pending-rework). Update the Tariffs Catalog DB
  title/description to say these entries are now the **design pool for King Abilities**,
  to be assigned per-King in the design pass, not auto-drawn every 10 waves.

**Deliberately NOT renamed** — code identifiers and save fields (`tariffs_active`,
`on_tariff_apply`, `tariffs`, `tariffs_off`, `tariffs_seen`, ~145 files):
the system is switched off (`TARIFFS_SCHEDULED := false`) and the rework will
**restructure** this code, not just rename it. Renaming 145 files now means renaming them
twice. Instead, add a prominent header note to `tariffs.gd`, `artefact_hooks.gd` and
`economy.gd`: **code "tariff" = design "King Ability"; identifier rename lands with the
rework.** This is the coordinator's recommendation, flagged for the user to overrule.

## Also: scaffold the two new feature docs

Create in Notion, structure only, content marked as design-in-progress:

1. **Families** page: choosing a Family determines Starting Stock, Starting Gold,
   Starting Artefacts, Starting Items, plus a **Family Power** (static, always on) and a
   **Family Ability** (once per Wave, costs 1 Action to activate — note the deliberate
   contrast with Artefact activation, which costs 0). The three existing Armies (Crown,
   Wild Hunt, Old Guard — `tuning.gd:ARMIES`) are the seed Families; target 5-10 total.
2. **King Powers & Abilities** page (the retitled one): 16 Kings, each to get a Power +
   2-3 Abilities; Tariff = Trump's Power. Design pending.

## Acceptance

- No player-visible "Tariff" outside Trump-specific contexts; cards re-texted via the
  exporter; UI strings and probes updated; suite ALL GREEN (`timeout: 600000`, alone).
- Notion pages retitled/created as above; nothing deleted, legacy marked as legacy.
- Header notes in the three code files mapping the terms.

## Blocked by

- nothing

## Outcome (2026-08-30)

Renamed everywhere a player or designer reads "Tariff":

- The 10 Artefact effect texts (Panama Papers Shredder, Merchants of Death Sample Case,
  Amber Room Bubble Wrap, Tunguska Toothpicks, Antikythera Warranty Card, Salvation Gift
  Card, SETI's Red Marker, Fireproof Pajamas, Ark Grounding Cable, Exhibit 399) in
  `data/artefacts.js`, re-exported to `game/data/artefacts.json` via
  `tools/export-game-artefacts.mjs`. Tier adjectives kept ("Mild King Abilities...").
- Counter-Intel's item description in `game/data/items.gd`.
- UI strings: `modals.gd`'s "Active tariffs" overlay title -> "Active King Abilities"; the
  two "Tariffs seen" stat lines -> "King Abilities seen" (still reading `g.tariffs_seen`,
  the field itself is unrenamed by design).
- Beyond the issue's list: the in-game Guide/rules text (`game/data/guide_text.gd`, the
  "Tariffs" section header + body) and the Games History row label in `game/scripts/menu.gd`
  ("%d tariff%s" -> "%d king abilit%s", still reading the `tariffs` history field).
- Header notes added to `game/data/tariffs.gd`, `game/scripts/artefact_hooks.gd`,
  `game/scripts/economy.gd` mapping code "tariff" -> design "King Ability", identifier
  rename deferred to the Kings + Tariffs rework.
- Checked the windowed click probes (`test_game_clicks.gd`, `test_menu_clicks.gd`): none
  matched on the renamed strings (they match on button text like "Close"/"⚠1", or on
  unrelated labels like "Objective"/"77") — no probe edits were needed.
- Notion: retitled **King Tariffs (concept)** -> **King Powers & Abilities**
  (https://app.notion.com/p/367f1559c99b8196910ccbf10bb56c7c), added the new King
  Power/Abilities structure at the top, wrapped the old cadence math in a clearly marked
  `LEGACY: King Tariffs cadence math (superseded, pending rework)` section — nothing
  deleted. Updated the **Tariffs Catalog** DB's description
  (https://app.notion.com/p/8906ed7b41da4b64a800f30af3494c8d) to say it's now the design
  pool for King Abilities, assigned per-King in the later pass (title left as "Tariffs
  Catalog" — same "rename lands with the rework" treatment as the code file it mirrors).
  Created **Families** (https://app.notion.com/p/3ccf1559c99b81a584fec27dd061de2c) under
  the GDD root: Family Power (static) + Family Ability (once/Wave, 1 Action — contrast
  with Artefacts' 0), Starting Stock/Gold/Artefacts/Items, seeded with Crown/Wild
  Hunt/Old Guard from `tuning.gd:ARMIES`, rest marked TBD/design-in-progress.
- No mechanic change: `TARIFFS_SCHEDULED` untouched, no code identifiers renamed
  (`tariffs_active`, `on_tariff_apply`, `tariffs_seen`, etc. all left alone per scope).
- `game/tests/run_all.sh` (alone, `timeout: 600000`): first full run showed one
  `game-clicks` failure ("a drop inside the open drawer places nothing"), unrelated to any
  renamed string; re-ran the probe alone (no other Godot process) and it passed clean,
  consistent with the documented windowed-probe contention flake from parallel agents
  sharing the display. A second full solo run came back **ALL GREEN**.
