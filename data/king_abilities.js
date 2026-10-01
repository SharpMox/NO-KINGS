/* King Abilities (Tariffs) catalog — the canonical source. tools/export-game-king-abilities.mjs
   writes game/data/king_abilities.json, which game/data/king_abilities.gd loads (moved out
   of king_abilities.gd's GDScript const 2026-09-29, keys and values unchanged). Run
   `node tools/gen-all.mjs` after editing; CI fails if the JSON is stale.

   The catalog issue 66 renamed from "Tariff" (2026-08-30). An entry here is a King Ability
   that a King's kit draws on (data/kings.js). Only Trumpus draws on it: his Power
   stacks the Tariffs below during his Wave (power_catalog_escalation) and his Ability is
   Diplomatic Visit (ability_catalog_key). Nothing else activates an entry — the old every-10-Waves
   schedule was deleted in NO-95.

   NO-95 (Max, 2026-09-15) removed the ten entries no real run could reach (Sanctions,
   Regulation, Austerity, Recession, Forced Audit, Hostile Takeover, Trade War, Filibuster,
   Asset Seizure, Asset Freeze). They are kept as design stock on the Notion page "Parked
   King Abilities"; the Tariffs Catalog database mirrors this file row for row
   (tools/check-notion-drift.mjs diffs them).

   Renamed 2026-09-09: data/tariffs.gd -> data/king_abilities.gd, its preload const
   (Tariffs -> KingAbilities) and the catalog (TARIFFS -> ABILITIES). Entry `key` values
   are save identifiers and stay as they are — "inflation" is Tariff on Gold Gain's key.
   The one exception, Diplomatic Visit's key, was renamed off a real name with a save
   migration (save_config.gd, v3 -> v4); a key change always needs one.

   Cost note: since NO-105 (docs/adr/0005-tariff-cost-model.md) a Tariff bills a GOLD
   percentage of a reference value (Tuning.TARIFF_*_PCT via Economy.tariff_cut):
   Move/Capture/Long-Range/Item a cut of the asset's value, Deploy a cut of the piece's own
   base deploy cost, Fuse a cut of MERGE_COST. Only Tariff on Pass and the blocked-move
   charge still bill the flat Tuning.KING_ABILITY_ACTION_COST. The Notion Cost column (a
   SCORE-denominated 200/500/1000 ladder) is superseded, not reconciled — ADR-0005.

   Fields: key, name, tier (Mild|Moderate|Severe), kind, description.
   kind: "action" (gold cost when the action happens) · "persistent" (rule modifier while
   it is held) · "oneoff" (applies instantly).

   NO-100 (Max review): descriptions are terse and state the real amount — "Sell Rook +$25"
   style — instead of the old vague "extra $". Economy.ability_desc() is what the overlay
   and the King info panel actually render, never `description` directly — for
   move/capture/item/long-range/deploy (percentage-of-a-variable-base: see
   Tuning.TARIFF_*_PCT — deploy joined this set Max, 2026-09-27) and inflation (the one that
   stacks) it builds the text from the live Tuning constant / held count instead, so the %
   shown can never go stale the way a hardcoded one would. The `description` for those six
   is unreachable through the normal render path; kept as catalog documentation only.
   fuse_cost/pass_cost ARE still flat (their base is a Tuning constant, not a piece value),
   so their dollar figure is genuinely constant and ability_desc reads it straight from here. */
const KING_ABILITIES = [
  { key: "move_cost", name: "Tariff on Move", tier: "Mild", kind: "action",
    description: "Moves: 10% of piece value" },
  { key: "ability_cost", name: "Tariff on Item", tier: "Mild", kind: "action",
    description: "Items: +60% of their price" },
  { key: "capture_cost", name: "Tariff on Capture", tier: "Mild", kind: "action",
    description: "Captures: 10% of the captured piece's value" },
  { key: "pass_cost", name: "Tariff on Pass", tier: "Mild", kind: "action",
    description: "Pass costs $10" },
  { key: "long_range_cost", name: "Tariff on Long-Range", tier: "Mild", kind: "action",
    description: "Sliding moves: 3% of piece value per square" },
  { key: "inflation", name: "Tariff on $ Gain", tier: "Mild", kind: "persistent",
    description: "Gold gains −10% (stacks)" },
  { key: "deploy_cost", name: "Tariff on Deploy", tier: "Moderate", kind: "action",
    description: "Deploys: +60% of their base cost" },
  { key: "fuse_cost", name: "Tariff on Fuse", tier: "Moderate", kind: "action",
    description: "Merge costs $9" },
  { key: "diplomatic_visit", name: "Diplomatic Visit", tier: "Severe", kind: "oneoff",
    description: "Destroys your most valuable piece" },
];

if (typeof module !== "undefined" && module.exports) module.exports = { KING_ABILITIES };
