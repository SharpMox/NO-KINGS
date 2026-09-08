## King Abilities — the catalog issue 66 renamed from "Tariff" (2026-08-30).
##
## RENAMED 2026-09-09 (user ruling), superseding this header's own instruction
## to wait. It used to say identifiers were deliberately left as "tariff"
## because the coming Kings + Tariffs rework would restructure the catalog and
## renaming twice would be wasted work. The user ruled the naming rename should
## reach the file now: issue 66 retired the name in the code and NO-24 fixed it
## in Notion, so the file was the last place still calling it a Tariff — and
## reading this file cost every newcomer the same explanation.
##
## Renamed: the file (data/tariffs.gd -> data/king_abilities.gd), its preload
## const (Tariffs -> KingAbilities) and this catalog (TARIFFS -> ABILITIES).
##
## NOT renamed, deliberately: the RUNTIME and SAVE identifiers — g.tariffs_active,
## g.king_power_tariff, Economy.activate_tariff, entry "key" values, and
## Tuning.TARIFFS_SCHEDULED. Those are game state that save_config.gd persists,
## and a reshaped save field read with a default is a silent corruption rather
## than a rename (see save_config.gd's header). They move with the rework, which
## has NOT landed: TARIFFS_SCHEDULED is still false and exactly one King draws
## on this catalog (kings.gd — Donald Trump's power_tariff/ability_tariff).
##
## Tariffs Catalog, from the Notion GDD (fetched 2026-07-02). Penalties on the
## player, activated on every 10th wave per the Wave Catalog schedule.
##
## Cost note (corrected 2026-08-30, issue 62): the upstream Notion catalog's
## Cost column is design intent, not shipped values, and diverges three ways —
## it is denominated in SCORE while this file charges GOLD; it is a three-step
## ladder (200/500/1000) while tuning.gd has a single flat per-action constant;
## and the ratio is ~/20, NOT the ~/100 this header claimed for months
## (TARIFF_ACTION_COST = 10 against an upstream 200, after the 2026-07-06
## halving). Issue 57's Score x10 did not move that target — it scales Score at
## the point of scoring and leaves Gold untouched. Not reconciled on purpose:
## picking a currency or a ladder belongs to the coming Tariff rework, and
## Tariffs are switched off (Tuning.TARIFFS_SCHEDULED) until it lands.
##
## kind: "action" (gold cost when the action happens) · "persistent" (rule
## modifier for the rest of the run) · "oneoff" (applies instantly).

const ABILITIES: Array = [
	{"key": "move_cost", "name": "Tariff on Move", "tier": "Mild", "kind": "action",
		"description": "Each piece move costs extra gold."},
	{"key": "ability_cost", "name": "Tariff on Ability", "tier": "Mild", "kind": "action",
		"description": "Activating an Item costs extra gold."},
	{"key": "capture_cost", "name": "Tariff on Capture", "tier": "Mild", "kind": "action",
		"description": "Each capture costs extra gold."},
	{"key": "pass_cost", "name": "Tariff on Pass", "tier": "Mild", "kind": "action",
		"description": "Ending your turn costs extra gold."},
	{"key": "long_range_cost", "name": "Tariff on Long-Range", "tier": "Mild", "kind": "action",
		"description": "Moving a Bishop or Rook costs extra gold per square."},
	{"key": "inflation", "name": "Inflation", "tier": "Mild", "kind": "persistent",
		"description": "All gold gains reduced 10% (stacks)."},
	{"key": "deploy_cost", "name": "Tariff on Deploy", "tier": "Moderate", "kind": "action",
		"description": "Placing a piece costs extra gold."},
	{"key": "fuse_cost", "name": "Tariff on Fuse", "tier": "Moderate", "kind": "action",
		"description": "Each merge costs extra gold."},
	{"key": "sanctions", "name": "Sanctions", "tier": "Moderate", "kind": "persistent",
		"description": "One random piece type can no longer be placed."},
	{"key": "regulation", "name": "Regulation", "tier": "Moderate", "kind": "persistent",
		"description": "Pawns can no longer be merged."},
	{"key": "austerity", "name": "Austerity", "tier": "Moderate", "kind": "persistent",
		"description": "Placing pieces costs double gold."},
	{"key": "recession", "name": "Recession", "tier": "Moderate", "kind": "persistent",
		"description": "Milestone clock refills halved."},
	{"key": "forced_audit", "name": "Forced Audit", "tier": "Moderate", "kind": "oneoff",
		"description": "Lose your entire Captured Stock."},
	{"key": "hostile_takeover", "name": "Hostile Takeover", "tier": "Moderate", "kind": "oneoff",
		"description": "One of your board pieces defects to the enemy."},
	{"key": "trade_war", "name": "Trade War", "tier": "Severe", "kind": "persistent",
		"description": "Every wave spawns +1 piece."},
	{"key": "filibuster", "name": "Filibuster", "tier": "Severe", "kind": "persistent",
		"description": "The enemy gains +1 action per turn."},
	{"key": "asset_seizure", "name": "Asset Seizure", "tier": "Severe", "kind": "oneoff",
		"description": "Lose every piece in your Stock."},
	{"key": "jd_vance", "name": "Diplomatic Visit – JD Vance", "tier": "Severe", "kind": "oneoff",
		"description": "Your highest-value piece is destroyed."},
	{"key": "asset_freeze", "name": "Asset Freeze", "tier": "Severe", "kind": "oneoff",
		"description": "Lose half your current gold."},
]

## Tariff on Promotion was the one catalog entry with no code here. It was
## excluded for the MVP (last-rank promotion is cut; merges are covered by
## Tariff on Fuse) and then held pending the rework. Ruled OBSOLETE and deleted
## from the Notion catalog 2026-09-09, so the two sides now hold the same 19
## entries and the drift checker has nothing to report here.

## Tariff slots for waves 1-150 (GDD Wave Catalog cycles 1-3, escalating). T0
## fires when wave 2 arrives and is always Inflation. Mild slots may repeat a
## tariff; Moderate and Severe picks are run-unique.
const SCHEDULE := {
	10: "Mild", 20: "Mild", 30: "Mild", 40: "Moderate", 50: "Severe",
	60: "Mild", 70: "Mild", 80: "Moderate", 90: "Moderate", 100: "Severe",
	110: "Mild", 120: "Moderate", 130: "Moderate", 140: "Severe", 150: "Severe",
}

## Severity order the SCHEDULE draws from. Identical at every difficulty
## tier (07-difficulty-ranks rework) — Economy.activate_tariff() no longer
## shifts it.
const TIER_ORDER := ["Mild", "Moderate", "Severe"]
