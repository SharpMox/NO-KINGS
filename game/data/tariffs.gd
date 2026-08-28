## Tariffs Catalog, from the Notion GDD (fetched 2026-07-02). Penalties on the
## player, activated on every 10th wave per the Wave Catalog schedule.
##
## Cost note: upstream costs (200/500/1000) assume a much larger score economy
## than the MVP's piece-value scale; amounts here live in tuning.gd, scaled
## ~/100 — flagged for a design pass.
##
## kind: "action" (gold cost when the action happens) · "persistent" (rule
## modifier for the rest of the run) · "oneoff" (applies instantly).

const TARIFFS: Array = [
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
	{"key": "box_cost", "name": "Tariff on Box Pick", "tier": "Mild", "kind": "action",
		"description": "Opening a box costs extra gold."},
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

## Excluded: Tariff on Promotion (last-rank promotion is cut from MVP — merges
## are covered by Tariff on Fuse).

## Tariff slots for waves 1-150 (GDD Wave Catalog cycles 1-3, escalating). T0
## fires when wave 2 arrives and is always Inflation. Mild slots may repeat a
## tariff; Moderate and Severe picks are run-unique.
const SCHEDULE := {
	10: "Mild", 20: "Mild", 30: "Mild", 40: "Moderate", 50: "Severe",
	60: "Mild", 70: "Mild", 80: "Moderate", 90: "Moderate", 100: "Severe",
	110: "Mild", 120: "Moderate", 130: "Moderate", 140: "Severe", 150: "Severe",
}

## Severity order the SCHEDULE draws from — Economy.activate_tariff() shifts
## one step up this list for Officer/Autocrat (07-difficulty-ranks).
const TIER_ORDER := ["Mild", "Moderate", "Severe"]
