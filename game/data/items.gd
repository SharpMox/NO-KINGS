## Items + Artefact Effects, from the Notion GDD catalogs (STATUS triage
## synced 2026-07-14: only KEEP items ship; REWORK/REMOVE entries deleted).
## Exclusions and their reasons are listed at the bottom.
##
## The Notion Items DB is the source of truth for names, tiers and effects —
## when it disagrees with this file, Notion wins and this file changes (user
## call 2026-08-27; last name+effect audit 2026-08-27, Blitz and Demote resynced).
##
## Item fields: key, name, tier, description, target, action_cost (default 1
##   if omitted — the Actions it costs to USE the item itself; separate from
##   whatever effect it grants on its target):
##   "" (instant) · "tile" (pick one tile) · "pair" (pick a piece, then a destination)

const ITEMS: Array = [
	{"key": "blitz", "name": "Blitz", "tier": "Tactical", "target": "tile", "action_cost": 0,
		"description": "Target Piece: its next move or capture this Turn costs no action."},
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
		"self_harming": true, # a DEBUFF on its own holder (ruled 2026-08-28) — a
			# RANDOM artefact grant must never hand a piece this by accident (see
			# artefact_hooks.gd's _random_buff_key); the player's own Buff Box
			# pick still offers it (game.gd _open_buff_pick reads PIECE_BUFFS
			# directly), since choosing Slow deliberately (e.g. onto an enemy)
			# is legitimate. Smog debuffs *adjacent enemies*, not its holder, so
			# it stays a genuine buff and carries no flag.
		"description": "This piece moves and captures like a Pawn until the end of the next enemy turn."},
	{"key": "aura", "name": "Aura", "tier": "Strategic", "model": "timed", "turns": 2,
		"description": "For 2 player turns, adjacent allies score double on their captures."},
	{"key": "smog", "name": "Smog", "tier": "Strategic", "model": "timed", "turns": 2,
		"description": "For 2 player turns, adjacent enemies move and capture like a Pawn."},
	{"key": "piece_bounty", "name": "Bounty", "tier": "Decisive", "model": "dormant",
		# Keyed "piece_bounty", NOT "bounty" — a legacy core Artefact holds
		# that key (ARTEFACT_EFFECTS_CORE below). User ruling (issue 48,
		# 2026-08-29): the Buff takes the NAME "Bounty". Issue 50 renamed
		# the Artefact's display name to free it up for good.
		"description": "When this piece is captured — by you or from you — choose 1 of 3 random Boxes, then open it."},
]

## The 7 game-native artefact effects — pre-date the 180-entry reference-site
## catalog (game/data/artefacts.json, exported by tools/export-game-artefacts.mjs
## from data/artefacts.js) and have no Notion/site equivalent, so they are not
## in that export. Keys are load-bearing: saves, scenarios (data/scenarios.gd)
## and the shop match on them directly.
const ARTEFACT_EFFECTS_CORE: Array = [
	{"key": "first_capture_extra", "name": "First-Capture Extra Action",
		"description": "If your first action of a turn is a capture, gain an extra action."},
	{"key": "greed", "name": "Greed",
		"description": "+100 score per Pawn captured."},
	{"key": "move", "name": "Move",
		"description": "+1 action per turn."},
	{"key": "lifesteal", "name": "Lifesteal",
		"description": "Captures restore 2s of clock."},
	{"key": "score", "name": "Score",
		"description": "+100 score on every capture."},
	{"key": "timer", "name": "Timer",
		"description": "Milestone clock refills give +5s more."},
	{"key": "bounty", "name": "Skip Tracer's Rolodex",
		# Renamed from "Bounty" (issue 50): the new Piece Buff took that name
		# (issue 48, user ruling 2026-08-29). Display name only — the key
		# stays "bounty" because it is load-bearing (saves, data/scenarios.gd,
		# the shop all match on it directly) and no player ever sees the key,
		# so a rename there would trade real save-migration risk for zero
		# visible benefit. See save_config.gd's SAVE_VERSION/_MIGRATIONS
		# header: this was a candidate for that table and was judged not to
		# need it.
		"description": "+300 score when capturing a piece worth 50+."},
]

## The full reference-site catalog, regenerated by
## tools/export-game-artefacts.mjs — do not hand-edit game/data/artefacts.json.
## `implemented` is true for all 180 as of 2026-08-29 (slices 15-20 built the
## trigger engine and wired every mechanic). The flag is a safety property,
## not an active gate: an inert artefact must never be offered, so only
## ARTEFACT_EFFECTS below is ever rolled, sold or granted — if a catalog
## entry is ever flagged back to `implemented: false`, this filter keeps it
## out automatically.
static func _load_artefact_catalog() -> Array:
	var text := FileAccess.get_file_as_string("res://data/artefacts.json")
	return JSON.parse_string(text)

static var ARTEFACT_CATALOG: Array = _load_artefact_catalog()

## Rollable/sellable/grantable pool: the core 7 plus whichever catalog entries
## are flagged implemented — grows as slices 16-20 land, with no re-plumbing
## here or in shop.gd/box.gd/economy.gd.
## `rarity` rides along (issue 18: Sub-Antarctic Visa's hidden Shop slot biases
## its roll toward higher-rarity Artefacts) — "" for the 7 core keys, which
## predate the catalog and carry no rarity at all.
static func _build_artefact_effects() -> Array:
	var out := ARTEFACT_EFFECTS_CORE.duplicate()
	for e in ARTEFACT_CATALOG:
		if e.get("implemented", false):
			out.append({"key": e.key, "name": e.name, "description": e.effect,
				"rarity": e.get("rarity", "")})
	return out

static var ARTEFACT_EFFECTS: Array = _build_artefact_effects()

## Excluded (reason):
## - REWORK/REMOVE items (STATUS triage 2026-07-14): deleted here; the Notion
##   Items DB is the source of truth for their return.
## - Capture Everything (Artefact): scope TBD upstream.
## - Obstacle (Artefact): no obstacle system in MVP.
