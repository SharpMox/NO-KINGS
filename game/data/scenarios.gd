## Test scenarios: each is a plain config Dictionary the game can boot from
## (game.gd/_apply_config). The config shape doubles as the future save format.
##
## Config keys (all optional):
##   board: Array of [piece_id, owner(0/1), x, y]
##   stock / captured: Array of piece ids
##   items / trinkets: Array of catalog keys
##   tariffs: Array of tariff keys (action/persistent, added active)
##   oneoffs: Array of one-off tariff keys, applied after setup
##   wave: int (default = all waves done, so no spawns disturb the sandbox)
##   clock_s: float seconds (default = normal budget)
##   score: int

const ZONE_PAWNS := [["pawn", 0, 1, 0], ["pawn", 0, 4, 0]]


static func _chain(title: String, base: String, mid: String) -> Dictionary:
	return {"name": "Promote: %s" % title, "cfg": {
		"board": ZONE_PAWNS, "stock": [base, base, mid, mid], "score": 500}}


static func all() -> Array:
	return [
		# --- core interactions ---
		{"name": "Movement & drag", "cfg": {
			"board": [["queen", 0, 2, 1], ["knight", 0, 3, 1], ["arrow-pawn", 0, 1, 0], ["kirin", 0, 4, 0]]}},
		{"name": "Captures & highlights", "cfg": {
			"board": [["queen", 0, 2, 2], ["knight", 0, 4, 2], ["pawn", 1, 2, 5], ["bishop", 1, 3, 4], ["rook", 1, 5, 3]]}},
		{"name": "Waves & cadence", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1]], "wave": 1, "stock": ["pawn", "pawn"]}},
		{"name": "Spawn overflow: full top row (friendly capture + spillover)", "cfg": {
			"board": [["queen", 0, 2, 1],
				["pawn", 0, 0, 11], ["pawn", 0, 1, 11], ["pawn", 0, 2, 11], ["pawn", 0, 3, 11],
				["pawn", 0, 4, 11], ["pawn", 0, 5, 11], ["pawn", 0, 6, 11], ["pawn", 0, 7, 11]],
			"wave": 1, "score": 500}},
		{"name": "Captured stock: deploy (money cost) & merge", "cfg": {
			"board": ZONE_PAWNS, "captured": ["rook", "rook", "knight", "pawn"],
			"stock": ["pawn"], "score": 500, "wave": 5}},
		{"name": "Early clear: bonus for beating the cadence", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]],
			"wave": 2, "stock": ["pawn"], "score": 100}},
		{"name": "Shop: browse & buy (money, SOLD, reroll at 10s)", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"wave": 9, "money": 400, "stock": ["pawn"]}},
		{"name": "Reinforcements: post-wave-10 shop", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"wave": 11, "score": 300, "stock": ["pawn"], "pending_reinforce": true}},
		{"name": "Economy: Blitz + First-Capture bonus actions", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4], ["pawn", 1, 4, 4], ["rook", 1, 5, 6]],
			"items": ["blitz"], "trinkets": ["first_capture_extra"], "score": 200, "wave": 3}},
		# win-screen tests: King one queen-move away, capture it to trigger the
		# screen — wave 50 = Continue/End Run, wave >= 150 = FULL CLEAR game over
		{"name": "Win screen: wave 50 (capture King)", "cfg": {
			"board": [["queen", 0, 3, 8], ["king", 1, 3, 10]],
			"wave": 50, "score": 1000}},
		{"name": "Win screen: full clear @ wave 200 (capture King)", "cfg": {
			"board": [["queen", 0, 3, 8], ["king", 1, 3, 10]],
			"wave": 200, "score": 5000}},
		{"name": "Recurring King (wave 100: bonus + refill, run continues)", "cfg": {
			"board": [["queen", 0, 3, 8], ["king", 1, 3, 10], ["rook", 1, 2, 10]],
			"wave": 100, "kings_defeated": 1, "score": 3000}},
		{"name": "King wave (checkmate to win)", "cfg": {
			"board": [["queen", 0, 2, 2], ["rook", 0, 0, 1], ["rook", 0, 5, 1],
				["king", 1, 3, 10], ["rook", 1, 2, 10], ["bishop", 1, 4, 10]],
			"wave": 50, "score": 1000}},
		# --- merging ---
		{"name": "Merge: promotion pair (pool)", "cfg": {
			"board": ZONE_PAWNS, "captured": ["pawn", "pawn", "rook", "rook"]}},
		{"name": "Merge: fusions (bishop+rook, knight+rook, ...)", "cfg": {
			"board": ZONE_PAWNS, "captured": ["rook", "rook", "bishop", "knight", "kirin"],
			"stock": ["alibaba", "wazir"]}},
		{"name": "Merge: on the board", "cfg": {
			"board": ZONE_PAWNS + [["ferz", 0, 2, 1], ["ferz", 0, 3, 1], ["bishop", 0, 4, 1], ["rook", 0, 5, 1]]}},
		_chain("Pawn chain", "pawn", "sergeant"),
		_chain("Seer chain", "ferz", "elephant-modern"),
		_chain("Mage chain", "wazir", "war-machine"),
		_chain("Bishop chain", "bishop", "dragon-horse"),
		_chain("Rook chain", "rook", "dragon-king"),
		_chain("Knight chain", "knight", "gnu"),
		_chain("Kirin chain", "kirin", "kirin-plus"),
		_chain("Wanderer chain", "alibaba", "bodyguard"),
		# --- reward economy ---
		{"name": "Box pick (capture the gold badge)", "cfg": {
			"board": [["queen", 0, 3, 3], ["pawn", 1, 3, 4, "buff"], ["pawn", 1, 1, 5, "buff"], ["knight", 0, 1, 3]]}},
		{"name": "Items: full inventory", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 0, 3, 1], ["pawn", 0, 1, 1],
				["pawn", 1, 2, 6], ["bishop", 1, 4, 6], ["rook", 1, 1, 8], ["knight", 1, 3, 8]],
			"items": ["blitz", "sniper", "air_strike", "demote", "extraction", "cease_fire",
				"surprise_attack", "suppressing_fire", "tactical_reposition", "drone_strike",
				"cluster_bomb", "conscription", "bombing_run", "rapid_deployment", "decoy_swap",
				"forced_march", "field_orders", "asset_recovery", "resupply_drop", "counter_intel"],
			"stock": ["pawn", "pawn"], "score": 500, "wave": 1}},
		{"name": "Trinkets: all active", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 1, 2, 4], ["pawn", 1, 3, 4], ["rook", 1, 4, 5]],
			"trinkets": ["first_capture_extra", "greed", "move", "lifesteal", "score", "timer", "bounty"],
			"wave": 9, "stock": ["pawn"]}},
		# --- tariffs ---
		{"name": "Tariffs: all action costs", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1], ["pawn", 1, 2, 5, "buff"], ["bishop", 1, 4, 5]],
			"tariffs": ["move_cost", "capture_cost", "deploy_cost", "pass_cost",
				"long_range_cost", "ability_cost", "fuse_cost", "box_cost"],
			"items": ["blitz"], "captured": ["pawn", "pawn"], "stock": ["pawn"], "score": 1000}},
		{"name": "Tariffs: all persistent", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 1, 3, 6]],
			"tariffs": ["inflation", "sanctions", "regulation", "austerity", "recession", "trade_war", "filibuster"],
			"stock": ["pawn", "pawn", "rook"], "captured": ["pawn", "pawn"], "wave": 8, "score": 1000}},
		{"name": "One-off: Forced Audit", "cfg": {
			"board": ZONE_PAWNS, "captured": ["rook", "queen", "pawn"], "oneoffs": ["forced_audit"]}},
		{"name": "One-off: Asset Seizure", "cfg": {
			"board": ZONE_PAWNS, "stock": ["rook", "queen", "pawn"], "oneoffs": ["asset_seizure"]}},
		{"name": "One-off: Asset Freeze", "cfg": {
			"board": ZONE_PAWNS, "score": 1000, "oneoffs": ["asset_freeze"]}},
		{"name": "One-off: Hostile Takeover", "cfg": {
			"board": ZONE_PAWNS + [["rook", 0, 2, 1], ["bishop", 0, 3, 1]], "oneoffs": ["hostile_takeover"]}},
		{"name": "One-off: JD Vance", "cfg": {
			"board": ZONE_PAWNS + [["queen", 0, 3, 1]], "oneoffs": ["jd_vance"]}},
		# --- full piece set ---
		{"name": "Showcase: riders & voids", "cfg": {
			"board": [["gryphon", 0, 0, 1], ["manticore", 0, 2, 1], ["godzilla", 0, 4, 1],
				["banshee", 0, 6, 1], ["raven", 0, 1, 0], ["amazonrider", 0, 3, 0],
				["berolina", 0, 5, 0], ["inv-sergeant", 0, 7, 0], ["inv-arrow-pawn", 0, 7, 1],
				["inv-kirin-plus", 0, 6, 0], ["inv-kirin-plus-plus", 0, 0, 0],
				["pawn", 1, 3, 10], ["rook", 1, 5, 10]],
			"captured": ["ferz", "rook", "wazir", "bishop"], "score": 500}},
		# --- loss conditions ---
		{"name": "Loss: clock-out (10s)", "cfg": {
			"board": ZONE_PAWNS, "clock_s": 10.0}},
		{"name": "Loss: starvation (pass twice)", "cfg": {
			"board": [["pawn", 0, 2, 0], ["rook", 1, 2, 9]]}},
		{"name": "Loss: back-row breach", "cfg": {
			"board": [["queen", 0, 3, 3],
				["rook", 1, 0, 0], ["rook", 1, 1, 0], ["rook", 1, 2, 0],
				["rook", 1, 3, 0], ["rook", 1, 4, 0], ["pawn", 1, 5, 1]]}},
	]
