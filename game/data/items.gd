## Items + Trinket Effects, from the Notion GDD catalogs (fetched 2026-07-02).
## Only entries implementable against current systems are included; exclusions
## and their reasons are listed at the bottom.
##
## Item fields: key, name, tier, description, target:
##   "" (instant) · "tile" (pick one tile) · "pair" (pick a piece, then a destination)

const ITEMS: Array = [
	{"key": "blitz", "name": "Blitz", "tier": "Tactical", "target": "",
		"description": "Gain an additional move action this turn."},
	{"key": "asset_recovery", "name": "Asset Recovery", "tier": "Tactical", "target": "",
		"description": "Duplicate a random piece in your Captured Stock."},
	{"key": "field_orders", "name": "Field Orders", "tier": "Tactical", "target": "",
		"description": "Your next 2 piece placements cost no score."},
	{"key": "demote", "name": "Demote", "tier": "Tactical", "target": "tile",
		"description": "Convert a target piece (ally or enemy) to a Pawn."},
	{"key": "air_strike", "name": "Air Strike", "tier": "Strategic", "target": "tile",
		"description": "Destroy a target enemy piece; no score, no capture. Not the King."},
	{"key": "sniper", "name": "Sniper", "tier": "Strategic", "target": "tile",
		"description": "Destroy an enemy piece one of your pieces could capture. Not the King."},
	{"key": "extraction", "name": "Extraction", "tier": "Tactical", "target": "tile",
		"description": "Return one of your board pieces to your Stock."},
	{"key": "cease_fire", "name": "Cease Fire", "tier": "Tactical", "target": "",
		"description": "Pause the chess clock for your next 2 player turns."},
	{"key": "surprise_attack", "name": "Surprise Attack", "tier": "Decisive", "target": "",
		"description": "The enemy skips its next turn."},
	{"key": "suppressing_fire", "name": "Suppressing Fire", "tier": "Strategic", "target": "",
		"description": "Push the next wave's spawn back 3 turns."},
	{"key": "tactical_reposition", "name": "Tactical Reposition", "tier": "Tactical", "target": "pair",
		"description": "Move any piece (ally or enemy) 1 square to an empty tile."},
	{"key": "drone_strike", "name": "Drone Strike", "tier": "Decisive", "target": "tile",
		"description": "Destroy all pieces in a 2x2 area (allies too). Kings unaffected."},
	{"key": "cluster_bomb", "name": "Cluster Bomb", "tier": "Decisive", "target": "",
		"description": "Destroy 3 random enemy pieces. Not the King."},
	{"key": "conscription", "name": "Conscription", "tier": "Strategic", "target": "",
		"description": "All your Pawns advance 1 square (where empty)."},
	{"key": "bombing_run", "name": "Bombing Run", "tier": "Decisive", "target": "tile",
		"description": "Destroy every piece in a target row (allies too). Kings unaffected."},
	{"key": "rapid_deployment", "name": "Rapid Deployment", "tier": "Strategic", "target": "pair",
		"description": "Move one of your pieces to any empty tile."},
	{"key": "decoy_swap", "name": "Decoy Swap", "tier": "Strategic", "target": "pair",
		"description": "Swap the positions of any two pieces."},
	{"key": "resupply_drop", "name": "Resupply Drop", "tier": "Tactical", "target": "",
		"description": "Refund the score cost of your last 3 placements."},
	{"key": "forced_march", "name": "Forced March", "tier": "Strategic", "target": "pair",
		"description": "Move any piece up to 3 squares in a straight clear line."},
]

## Trinkets: run-long passives. `key` is matched in game.gd hooks.
## Vague upstream Notes are pinned to concrete MVP behavior here — amounts are
## assumptions to tune, noted per entry.
const TRINKET_EFFECTS: Array = [
	{"key": "first_capture_extra", "name": "First-Capture Extra Action",
		"description": "If your first move of a turn is a capture, gain an extra move."},
	{"key": "greed", "name": "Greed",
		"description": "+1 score per Pawn captured."},
	{"key": "move", "name": "Move",
		"description": "+1 move per turn."},
	{"key": "lifesteal", "name": "Lifesteal",
		"description": "Captures restore 2s of clock."},
	{"key": "score", "name": "Score",
		"description": "+1 score on every capture."},
	{"key": "timer", "name": "Timer",
		"description": "Milestone clock refills give +5s more."},
	{"key": "bounty", "name": "Bounty",
		"description": "+3 score when capturing a piece worth 5+."},
]

## Excluded from MVP (reason):
## - Promote (Item): placeholder Description upstream in Notion — no effect defined.
## - Buff Box (Item): depends on the Piece Buffs system, cut from MVP.
## - Radar Jamming (Item): enemies have no abilities in MVP — dead effect.
## - Counter-Intel (Item): lands with the Tariffs PR (disables tariffs 2 turns).
## - Capture Everything (Trinket): scope TBD upstream.
## - Obstacle (Trinket): no obstacle system in MVP.
