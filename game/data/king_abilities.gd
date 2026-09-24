## King Abilities — the catalog issue 66 renamed from "Tariff" (2026-08-30).
##
## An entry here is a King Ability that a King's kit draws on (kings.gd). Only
## Donald Trump draws on it: his Power stacks the Tariffs below during his Wave
## (power_catalog_escalation) and his Ability is JD Vance (ability_catalog_key).
## Nothing else activates an entry — the old every-10-Waves schedule was deleted
## in NO-95.
##
## NO-95 (Max, 2026-09-15) removed the ten entries no real run could reach
## (Sanctions, Regulation, Austerity, Recession, Forced Audit, Hostile Takeover,
## Trade War, Filibuster, Asset Seizure, Asset Freeze). They are kept as design
## stock on the Notion page "Parked King Abilities"; the Tariffs Catalog
## database mirrors this file row for row.
##
## Renamed 2026-09-09: the file (data/tariffs.gd -> data/king_abilities.gd), its
## preload const (Tariffs -> KingAbilities) and this catalog (TARIFFS ->
## ABILITIES). Entry "key" values are save identifiers and stay as they are —
## "inflation" is Tariff on Gold Gain's key.
##
## Cost note (issue 62): the Notion catalog's Cost column is design intent, not
## shipped values — it is denominated in SCORE and a 200/500/1000 ladder, while
## this file charges a flat GOLD Tuning.KING_ABILITY_ACTION_COST. Not reconciled
## on purpose; that belongs to the balance pass (NO-6).
##
## kind: "action" (gold cost when the action happens) · "persistent" (rule
## modifier while it is held) · "oneoff" (applies instantly).

## NO-100 (Max review): descriptions are terse and state the real amount —
## "Sell Rook +$25" style — instead of the old vague "extra $". The four
## percentage-of-a-variable-base ones (move/capture/item/long-range: see
## Tuning.TARIFF_*_PCT) state the rate itself, since it — not a dollar figure
## for one specific piece — is the number that stays true for every action.
## deploy_cost/fuse_cost/pass_cost are flat (their base is a Tuning constant,
## not a piece value), so their dollar figure IS constant: shown pre-computed
## here. Economy.ability_desc() is what the overlay and the King info panel
## actually render (NO-100: hides banners/feed too) — it returns this text
## unchanged for every key except "inflation", where it substitutes the live
## stacked total (economy.gd has the multiplicative-stacking math).
const ABILITIES: Array = [
	{"key": "move_cost", "name": "Tariff on Move", "tier": "Mild", "kind": "action",
		"description": "Moves cost 10% value"},
	{"key": "ability_cost", "name": "Tariff on Item", "tier": "Mild", "kind": "action",
		"description": "Items cost 60% price"},
	{"key": "capture_cost", "name": "Tariff on Capture", "tier": "Mild", "kind": "action",
		"description": "Captures cost 10% value"},
	{"key": "pass_cost", "name": "Tariff on Pass", "tier": "Mild", "kind": "action",
		"description": "Pass costs $10"},
	{"key": "long_range_cost", "name": "Tariff on Long-Range", "tier": "Mild", "kind": "action",
		"description": "Bishop/Rook: 3% per sq"},
	{"key": "inflation", "name": "Tariff on $ Gain", "tier": "Mild", "kind": "persistent",
		"description": "Gold gains −10% (stacks)"},
	{"key": "deploy_cost", "name": "Tariff on Deploy", "tier": "Moderate", "kind": "action",
		"description": "Deploy costs $12"},
	{"key": "fuse_cost", "name": "Tariff on Fuse", "tier": "Moderate", "kind": "action",
		"description": "Merge costs $9"},
	{"key": "jd_vance", "name": "Diplomatic Visit – JD Vance", "tier": "Severe", "kind": "oneoff",
		"description": "Destroys best piece"},
]
