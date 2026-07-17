## Items + Trinket Effects, from the Notion GDD catalogs (STATUS triage
## synced 2026-07-14: only KEEP items ship; REWORK/REMOVE entries deleted).
## Exclusions and their reasons are listed at the bottom.
##
## Item fields: key, name, tier, description, target:
##   "" (instant) · "tile" (pick one tile) · "pair" (pick a piece, then a destination)

const ITEMS: Array = [
	{"key": "blitz", "name": "Blitz", "tier": "Tactical", "target": "",
		"description": "Gain an additional move action for the turn."},
	{"key": "asset_recovery", "name": "Asset Recovery", "tier": "Tactical", "target": "tile",
		"description": "Duplicate a piece on the board to your Stock."},
	{"key": "demote", "name": "Demote", "tier": "Tactical", "target": "tile",
		"description": "Convert a target piece (ally or enemy) to a Pawn."},
	{"key": "promote", "name": "Promote", "tier": "Tactical", "target": "tile",
		"description": "Advance a target ally piece to its next tier. No effect if it has none."},
	{"key": "invert", "name": "Inversion", "tier": "Tactical", "target": "tile",
		"description": "Invert a target piece's move/capture pattern (only pieces with a defined inverse)."},
	{"key": "tactical_reposition", "name": "Tactical Reposition", "tier": "Tactical", "target": "pair",
		"description": "Move target ally or enemy piece 1 square."},
	{"key": "air_strike", "name": "Air Strike", "tier": "Strategic", "target": "tile",
		"description": "Destroy a target enemy piece on the board. No score awarded. Cannot target the King."},
	{"key": "sniper", "name": "Sniper", "tier": "Strategic", "target": "tile",
		"description": "Destroy a target enemy piece that could be captured by one of your pieces. Cannot target the King."},
	{"key": "radar_jamming", "name": "Radar Jamming", "tier": "Strategic", "target": "tile",
		"description": "Remove target's piece Buffs and/or Debuffs."},
	{"key": "rapid_deployment", "name": "Rapid Deployment", "tier": "Strategic", "target": "pair",
		"description": "Move a target ally piece to any Deploy tile on the board."},
	{"key": "decoy_swap", "name": "Decoy Swap", "tier": "Strategic", "target": "pair",
		"description": "Swap the positions of any two pieces on the board (ally or enemy, in any combination)."},
	{"key": "counter_intel", "name": "Counter-Intel", "tier": "Strategic", "target": "",
		"description": "Disable all tariffs until the next Wave."},
	{"key": "drone_strike", "name": "Drone Strike", "tier": "Decisive", "target": "area",
		"description": "Destroy all pieces (ally and enemy) within a 3x3 target area. The King is unaffected."},
	{"key": "surprise_attack", "name": "Surprise Attack", "tier": "Decisive", "target": "",
		"description": "Take an additional player turn immediately after this one. The AI skips its intervening turn."},
]

const TRINKET_EFFECTS: Array = [
	{"key": "first_capture_extra", "name": "First-Capture Extra Action",
		"description": "If your first action of a turn is a capture, gain an extra action."},
	{"key": "greed", "name": "Greed",
		"description": "+10 score per Pawn captured."},
	{"key": "move", "name": "Move",
		"description": "+1 action per turn."},
	{"key": "lifesteal", "name": "Lifesteal",
		"description": "Captures restore 2s of clock."},
	{"key": "score", "name": "Score",
		"description": "+10 score on every capture."},
	{"key": "timer", "name": "Timer",
		"description": "Milestone clock refills give +5s more."},
	{"key": "bounty", "name": "Bounty",
		"description": "+30 score when capturing a piece worth 50+."},
]

## Excluded (reason):
## - REWORK/REMOVE items (STATUS triage 2026-07-14): deleted here; the Notion
##   Items DB is the source of truth for their return.
## - Capture Everything (Trinket): scope TBD upstream.
## - Obstacle (Trinket): no obstacle system in MVP.
