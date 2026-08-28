## Items + Artefact Effects, from the Notion GDD catalogs (STATUS triage
## synced 2026-07-14: only KEEP items ship; REWORK/REMOVE entries deleted).
## Exclusions and their reasons are listed at the bottom.
##
## The Notion Items DB is the source of truth for names, tiers and effects —
## when it disagrees with this file, Notion wins and this file changes (user
## call 2026-08-27; last name+effect audit 2026-08-27, Blitz and Demote resynced).
##
## Item fields: key, name, tier, description, target:
##   "" (instant) · "tile" (pick one tile) · "pair" (pick a piece, then a destination)

const ITEMS: Array = [
	{"key": "blitz", "name": "Blitz", "tier": "Tactical", "target": "tile",
		"description": "Target Piece can move a second time this turn."},
	{"key": "asset_recovery", "name": "Asset Recovery", "tier": "Tactical", "target": "tile",
		"description": "Duplicate a piece on the board to your Stock."},
	{"key": "demote", "name": "Demote", "tier": "Tactical", "target": "tile",
		"description": "Convert a target piece (ally or enemy) to its base chain piece. No effect if it has none."},
	{"key": "promote", "name": "Promote", "tier": "Tactical", "target": "tile",
		"description": "Advance a target ally piece to its next tier. No effect if it has none."},
	{"key": "invert", "name": "Inversion", "tier": "Tactical", "target": "tile",
		"description": "Invert a target piece's move/capture pattern (only pieces with a defined inverse)."},
	{"key": "extraction", "name": "Extraction", "tier": "Tactical", "target": "multi",
		"description": "Return any number of your pieces from the board to your Stock."},
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
	{"key": "buff_box", "name": "Buff Box", "tier": "Strategic", "target": "tile",
		"description": "Choose 1 of 3 random Piece Buffs, then apply it to a target piece (ally or enemy)."},
]

## Piece Buffs — one-shot effects that ride on a single board piece, delivered
## by the Buff Box item (GDD Piece Buffs DB). Two models:
##   dormant  — sits on the piece until its trigger fires, then resolves and is
##              consumed. No expiry: it can wait forever.
##   timed    — activates on application and runs for a fixed window.
## "Reduced movement range" (Slow, Smog) means the piece moves and captures
## exactly like a Pawn — ruled 2026-08-28, see the Notion Piece Buffs pages.
## `turns` on a timed buff is its life in player turns.
const PIECE_BUFFS: Array = [
	{"key": "shield", "name": "Shield", "tier": "Tactical", "model": "dormant",
		"description": "Prevents the next capture attempt on this piece. Both pieces stay put."},
	{"key": "critical", "name": "Critical", "tier": "Tactical", "model": "dormant",
		"description": "The next capture by this piece scores double."},
	{"key": "multicapture", "name": "Multicapture", "tier": "Strategic", "model": "dormant",
		"description": "The next capture by this piece also takes one enemy standing beside the piece it captured."},
	{"key": "taunt", "name": "Taunt", "tier": "Tactical", "model": "dormant",
		"description": "The next enemy capture attempt is forced to target this piece."},
	{"key": "stun", "name": "Stun", "tier": "Tactical", "model": "dormant",
		"description": "The next piece that captures this one loses its following 2 turns."},
	{"key": "bomb", "name": "Bomb", "tier": "Decisive", "model": "dormant",
		"description": "On capturing or being captured, destroys itself, the other piece, and everything within 1 square."},
	{"key": "trap", "name": "Trap", "tier": "Decisive", "model": "dormant",
		"description": "When this piece is captured, the attacking piece is captured too."},
	{"key": "range", "name": "Range", "tier": "Tactical", "model": "dormant",
		"description": "Until this piece captures, it can also capture any enemy standing beside an enemy it could already take."},
	{"key": "reflect", "name": "Reflect", "tier": "Decisive", "model": "dormant",
		"description": "Stops the next capture attempt, then takes the attacker's tile and captures it."},
	{"key": "slow", "name": "Slow", "tier": "Tactical", "model": "timed", "turns": 1,
		"description": "This piece moves and captures like a Pawn until the end of the next enemy turn."},
	{"key": "aura", "name": "Aura", "tier": "Strategic", "model": "timed", "turns": 2,
		"description": "For 2 player turns, adjacent allies score double on their captures."},
	{"key": "smog", "name": "Smog", "tier": "Strategic", "model": "timed", "turns": 2,
		"description": "For 2 player turns, adjacent enemies move and capture like a Pawn."},
]

const ARTEFACT_EFFECTS: Array = [
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
## - Capture Everything (Artefact): scope TBD upstream.
## - Obstacle (Artefact): no obstacle system in MVP.
