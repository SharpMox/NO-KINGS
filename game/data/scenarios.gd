## Test scenarios: each is a plain config Dictionary the game can boot from
## (game.gd/_apply_config). The config shape doubles as the future save format.
##
## Config keys (all optional):
##   board: Array of [piece_id, owner(0/1), x, y]
##   stock / captured: Array of piece ids
##   items / artefacts: Array of catalog keys
##   tariffs: Array of tariff keys (action/persistent, added active)
##   oneoffs: Array of one-off tariff keys, applied after setup
##   wave: int (default = all waves done, so no spawns disturb the sandbox)
##   clock_s: float seconds (default = normal budget)
##   score: int

const ZONE_PAWNS := [["pawn", 0, 1, 0], ["pawn", 0, 4, 0]]

## issue 79: the 180 generated per-Artefact sandboxes are appended by all(),
## not listed here — see scenarios_artefacts.gd for why they are derived from
## ArtefactHooks.REGISTRY rather than hand-written.
const Generated := preload("res://data/scenarios_artefacts.gd")

## issue 80: likewise one per piece, derived from data/pieces.json.
const GeneratedPieces := preload("res://data/scenarios_pieces.gd")

## issue 82: likewise one per King, derived from Kings.ROSTER.
const GeneratedKings := preload("res://data/scenarios_kings.gd")

## issue 94: the Combo boards, derived from the fires/listens hook graph.
const GeneratedCombos := preload("res://data/scenarios_combos.gd")

## issue 95: the STAGED combo boards — hand-built, one per question, picked
## from 94's graph for disputability rather than derived from it.
const StagedCombos := preload("res://data/scenarios_staged.gd")


static func _chain(title: String, base: String, mid: String) -> Dictionary:
	# issue 98: merging now costs Gold, so a chain sandbox needs a budget or it
	# demonstrates nothing — the board exists to walk a promotion chain by hand.
	return {"name": "Promote: %s" % title, "cfg": {
		"board": ZONE_PAWNS, "stock": [base, base, mid, mid], "score": 500,
		"gold": 300}}


static func all() -> Array:
	return _hand_written() + Generated.all() + GeneratedPieces.all() \
		+ GeneratedKings.all() + GeneratedCombos.all() + GeneratedCombos.anti_all() \
		+ StagedCombos.all()


static func _hand_written() -> Array:
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
		{"name": "Captured stock: deploy (gold cost) & merge", "cfg": {
			"board": ZONE_PAWNS, "captured": ["rook", "rook", "knight", "pawn"],
			"stock": ["pawn"], "score": 500, "wave": 5}},
		{"name": "Early clear: bonus for beating the cadence", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]],
			"wave": 2, "stock": ["pawn"], "score": 100}},
		{"name": "Shop: browse & buy (gold, SOLD, reroll at 10s)", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"wave": 9, "gold": 400, "stock": ["pawn"]}},
		{"name": "Reinforcements: post-wave-10 shop", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"wave": 11, "score": 300, "stock": ["pawn"], "pending_reinforce": true}},
		{"name": "Economy: Blitz + First-Capture bonus actions", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4], ["pawn", 1, 4, 4], ["rook", 1, 5, 6]],
			"items": ["blitz"], "artefacts": ["stargate-divination-crystal"], "score": 200, "wave": 3}},
		# win-screen tests: King one queen-move away, capture it to trigger the
		# screen — wave 50 = Continue/End Run, wave >= 150 = FULL CLEAR game over
		{"name": "Win screen: wave 50 (capture King)", "cfg": {
			"board": [["queen", 0, 3, 8], ["king", 1, 3, 10]],
			"wave": 50, "score": 1000}},
		{"name": "Win screen: named King (identity, issue 09)", "cfg": {
			"board": [["queen", 0, 3, 8], ["king", 1, 3, 10, {"king_id": "nero"}]],
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
			"board": ZONE_PAWNS, "captured": ["pawn", "pawn", "rook", "rook"], "gold": 300}},
		{"name": "Merge: fusions (bishop+rook, knight+rook, ...)", "cfg": {
			"board": ZONE_PAWNS, "captured": ["rook", "rook", "bishop", "knight", "kirin"],
			"stock": ["alibaba", "wazir"], "gold": 300}},
		{"name": "Merge: on the board", "cfg": {
			"board": ZONE_PAWNS + [["ferz", 0, 2, 1], ["ferz", 0, 3, 1], ["bishop", 0, 4, 1], ["rook", 0, 5, 1]], "gold": 300}},
		_chain("Pawn chain", "pawn", "sergeant"),
		_chain("Seer chain", "ferz", "elephant-modern"),
		_chain("Mage chain", "wazir", "war-machine"),
		_chain("Bishop chain", "bishop", "dragon-horse"),
		_chain("Rook chain", "rook", "dragon-king"),
		_chain("Knight chain", "knight", "gnu"),
		_chain("Long Ma chain", "kirin", "kirin-plus"),
		_chain("Duchess chain", "alibaba", "bodyguard"),
		# --- reward economy ---
		{"name": "Boxes (Shop, issue 47: 9 typed Boxes)", "cfg": {
			"board": [["queen", 0, 3, 3], ["knight", 0, 1, 3]], "wave": 3, "gold": 2000}},
		{"name": "Items: full inventory", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 0, 3, 1], ["pawn", 0, 1, 1],
				["pawn", 1, 2, 6], ["bishop", 1, 4, 6], ["rook", 1, 1, 8], ["knight", 1, 3, 8]],
			"items": ["blitz", "sniper", "air_strike", "demote", "promote", "invert",
				"surprise_attack", "tactical_reposition", "rapid_deployment",
				"decoy_swap", "asset_recovery", "radar_jamming", "counter_intel",
				"drone_strike", "extraction"],
			"stock": ["pawn", "pawn"], "score": 500, "wave": 1}},
		{"name": "Piece Buffs (Buff Box: pick, target, Shield/Critical)", "cfg": {
			"board": [["queen", 0, 2, 1, {"buffs": [{"key": "critical"}]}],
				["pawn", 0, 3, 1], ["rook", 1, 2, 6, {"buffs": [{"key": "shield"}]}],
				["bishop", 1, 4, 6], ["knight", 1, 3, 8]],
			"items": ["buff_box", "buff_box", "radar_jamming"],
			"stock": ["pawn"], "score": 500, "wave": 1}},
		{"name": "Piece Buffs: timed (Slow/Aura/Smog) + Reflect", "cfg": {
			"board": [["queen", 0, 2, 1, {"buffs": [{"key": "aura", "turns": 2}]}],
				["knight", 0, 3, 1], ["bishop", 0, 1, 1, {"buffs": [{"key": "slow", "turns": 1}]}],
				["rook", 1, 2, 5, {"buffs": [{"key": "reflect"}]}],
				["rook", 1, 4, 6, {"buffs": [{"key": "smog", "turns": 2}]}],
				["knight", 1, 3, 8]],
			"items": ["buff_box"], "stock": ["pawn"], "score": 500, "wave": 1}},
		{"name": "Piece Buffs: Range / Trap / Taunt / Stun", "cfg": {
			"board": [["rook", 0, 2, 1, {"buffs": [{"key": "range"}]}],
				["pawn", 0, 3, 1, {"buffs": [{"key": "taunt"}]}],
				["pawn", 0, 1, 1, {"buffs": [{"key": "stun"}]}],
				["queen", 0, 4, 1, {"buffs": [{"key": "trap"}]}],
				["knight", 0, 5, 1, {"buffs": [{"key": "multicapture"}]}],
				["pawn", 0, 6, 1, {"buffs": [{"key": "bomb"}]}],
				["rook", 1, 2, 5], ["pawn", 1, 3, 5], ["knight", 1, 3, 8]],
			"items": ["buff_box"], "stock": ["pawn"], "score": 500, "wave": 1}},
		{"name": "Artefacts: mixed simple triggers", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 1, 2, 4], ["pawn", 1, 3, 4], ["rook", 1, 4, 5]],
			"artefacts": ["stargate-divination-crystal", "library-of-alexandria-matchbox",
				"cia-exploding-cigar", "2012-doomsday-party-hat", "voynich-dictionary",
				"suspiciously-large-femur", "nero-s-marshmallow-stick"],
			"wave": 9, "stock": ["pawn"]}},
		{"name": "Artefacts: Gold/Score batch (issue 16)", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 1, 2, 4], ["pawn", 1, 3, 4], ["rook", 1, 4, 5]],
			"artefacts": ["tinfoil-hat", "tungsten-filled-gold-bar", "zurich-gnome-figurine",
				"nero-s-marshmallow-stick", "suspiciously-large-femur",
				"social-credit-report-card", "john-titor-s-crypto-wallet"],
			"gold": 100, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: slice 17 (Action/Time/Piece)", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1], ["bishop", 0, 1, 1], ["knight", 0, 4, 1],
				["pawn", 0, 0, 1], ["pawn", 0, 5, 1], ["pawn", 0, 6, 1], ["pawn", 0, 7, 1],
				["pawn", 1, 2, 5], ["rook", 1, 4, 6]],
			"items": ["blitz", "sniper", "demote"],
			"artefacts": ["cia-exploding-cigar", "i-am-not-a-robot-checkbox", "seed-vault-secret-hatch",
				"super-soldier-multivitamins", "stargate-divination-crystal", "5g-microchips",
				"terracotta-draft-card", "charlemagne-s-birth-certificate"],
			"wave": 3, "score": 200, "stock": ["pawn"]}},
		{"name": "Artefacts: Shop/Item/Buff batch (issue 18)", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 1, 2, 4], ["pawn", 1, 3, 4], ["rook", 1, 4, 5]],
			"artefacts": ["denazification-visa", "hollow-moon-cross-section", "chocolate-key-cake",
				"sub-antarctic-visa", "crop-circle-plank", "mk-ultra-sugar-cube",
				"frame-25", "sleeper-agent-pillow"],
			"gold": 200, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: slice 19 (Special + prereqs)", "cfg": {
			"board": [["pawn", 0, 2, 1], ["pawn", 0, 3, 1], ["queen", 0, 4, 1],
				["pawn", 1, 2, 5], ["pawn", 1, 3, 5], ["rook", 1, 4, 6]],
			"items": ["air_strike", "drone_strike", "buff_box"],
			"artefacts": ["satoshi-s-private-key", "flight-19-blackbox",
				"arms-fair-goodie-bag", "dihydrogen-monoxide-battery",
				"witness-protection-mustache", "cia-heart-attack-gun",
				"dyatlov-geiger-counter", "merchants-of-death-sample-case",
				"tunguska-toothpicks"],
			"tariffs": ["move_cost"], "gold": 100, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: issue 25 (per-piece capture ledger)", "cfg": {
			"board": [["queen", 0, 2, 1, {"captures": 2, "wave_captures": 1}],
				["pawn", 0, 3, 1], ["pawn", 1, 2, 5], ["pawn", 1, 3, 5, {"captures": 1}],
				["rook", 1, 4, 6]],
			"artefacts": ["chupacabra-chew-toy", "zodiac-crossword-puzzle", "alien-rocket-toy"],
			"gold": 50, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: slice 22 (tariff interception)", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1], ["pawn", 1, 2, 5], ["bishop", 1, 4, 5]],
			"artefacts": ["panama-papers-shredder", "amber-room-bubble-wrap",
				"ark-grounding-cable", "salvation-gift-card"],
			"tariffs": ["move_cost", "inflation", "deploy_cost"],
			"gold": 200, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: economy & Box batch (issue 26)", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 1, 2, 4], ["pawn", 1, 3, 4], ["rook", 1, 4, 5]],
			"artefacts": ["haarp-volume-knob", "wuhan-vial-label", "pigeon-charging-cable",
				"pre-scratched-lottery-ticket", "hitler-s-argentinian-passport",
				"nazca-boarding-pass", "nuclear-football-menu", "ark-s-bunkbed",
				"trojan-horse-assembly-manual", "jon-burrows-fake-id",
				"walt-s-cryonic-capsule", "27-club-punch-card",
				"doomsday-clock-snooze-button", "zero-point-energy-drink",
				"agartha-welcome-mat"],
			"items": ["counter_intel"],
			"gold": 200, "wave": 4, "stock": ["pawn"], "clock_s": 40.0}},
		{"name": "Artefacts: issue 31 (capture-context effects)", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 1, 2, 4], ["pawn", 1, 3, 4],
				["pawn", 1, 4, 4], ["rook", 1, 5, 6]],
			"artefacts": ["curtain-rods-bag-rifle-shaped", "templar-debit-card",
				"2-3-trillion-receipt"],
			"items": ["drone_strike"], # destroy a pawn for the Receipt; capture the
				# other two for Curtain Rods Bag's first-Capture-each-Wave bonus
			"score": 200, "gold": 20, "wave": 4, "stock": ["pawn"]}}, # low Gold, enough
			# Score to test Templar Debit Card paying a Shop cost's shortfall
		{"name": "Artefacts: slice 21 (echo and meta-triggers)", "cfg": {
			"board": [["pawn", 0, 2, 1], ["pawn", 0, 3, 1], ["queen", 0, 4, 1],
				["pawn", 1, 2, 5], ["pawn", 1, 3, 5], ["rook", 1, 4, 6]],
			"artefacts": ["voynich-dictionary", "zurich-gnome-figurine", "d-b-cooper-s-parachute",
				"polybius-cartridge", "max-headroom-mask", "red-diary-s-missing-pages",
				"cern-ctrl-z-shortcut", "bilderberg-hotel-slippers",
				"illuminati-nwo-booster-pack", "100-genuine-original-mona-lisa",
				"deja-vu-glitch", "capstone-polish"],
			"gold": 100, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: issue 29 (rarity metadata + Illuminati Fridge Magnet)", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1], ["pawn", 1, 2, 5], ["bishop", 1, 4, 5]],
			"artefacts": ["illuminati-fridge-magnet", "fema-summer-camp-flyer", # Rare + Common
				"putin-s-golden-toilet-brush", "cia-exploding-cigar"], # Uncommon + Legendary
			"gold": 100, "wave": 3, "stock": ["pawn"]}},
		{"name": "Artefacts: slice 30 (action log — Elvish Hard Hat)", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1], ["pawn", 1, 2, 5], ["bishop", 1, 4, 6]],
			"items": ["counter_intel", "blitz"],
			"artefacts": ["elvish-hard-hat"],
			"gold": 100, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: slice 35 (Clock-gain choke point — lifesteal, King refill, Black Knight)", "cfg": {
			# issue 69 repointed "lifesteal" (removed game-native key, the
			# only on_capture Clock-gain artefact) to 2012 Doomsday Party Hat
			# (on_gold_change, +5s per 10 Gold) — no surviving catalog
			# Artefact grants Clock on_capture, so this exercises the same
			# add_clock() choke point via a different hook instead. The name
			# itself is left as-is (not updated to mention the new key): a
			# longer name here pushes the "TEST" scroll list's "← Back"
			# button out of position in the fixed 480x800 menu window and
			# breaks test_menu_clicks.gd — found empirically bisecting a
			# menu-clicks regression, see PR notes.
			"board": [["queen", 0, 2, 1], ["king", 1, 2, 4], ["pawn", 1, 3, 5], ["rook", 1, 4, 6]],
			"artefacts": ["2012-doomsday-party-hat", "black-knight-morse-code"],
			"gold": 100, "score": 0, "clock_s": 90.0, "wave": 99, "kings_defeated": 1,
			"stock": ["pawn"]}}, # a recurring King refill on top of lifesteal/Black
			# Knight's own Clock hooks, and a 3rd-Turn cadence within easy reach
		{"name": "Artefacts: slice 42 (peak-rank stamp — Dark Market Light Bulb)", "cfg": {
			"board": [["sergeant", 0, 2, 1], # already Ranked
				["pawn", 0, 3, 1, {"peak_ranked": true}], # Demoted: below its own peak
				["pawn", 0, 4, 1], # never Ranked — the control case
				["pawn", 1, 2, 5], ["pawn", 1, 3, 5], ["rook", 1, 4, 6]],
			"items": ["demote", "promote"], # demote the sergeant, then promote the
				# demoted pawn back — the sandbox for "clears on re-promotion"
			"artefacts": ["dark-market-light-bulb"],
			"gold": 100, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: activation, confirm-gated (issue 52)", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1], ["pawn", 1, 2, 5], ["rook", 1, 4, 6]],
			"artefacts": ["oak-island-wishing-well", "fifa-complimentary-yacht",
				"moscovium-glow-stick", "roanoke-hex-kit", "zapruder-s-director-s-cut"],
			"gold": 500, "score": 0, "wave": 10, "stock": ["pawn"]}}, # generous
			# Gold/wave so the bot's per-frame activation roll (autoplay.gd) has
			# a real shot at Oak Island/FIFA/Moscovium landing within the sweep
		{"name": "Artefacts: activation, targeted — Bovine Tractor Beam (issue 52)", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 1, 4, 6]],
			"artefacts": ["bovine-tractor-beam"], "wave": 3, "stock": ["pawn"]}},
		{"name": "Extraction (rescue pieces to Stock)", "cfg": {
			"board": [["dragon-king", 0, 2, 2], ["knight", 0, 3, 3], ["pawn", 0, 1, 2],
				["rook", 1, 4, 8], ["bishop", 1, 2, 7]],
			"items": ["extraction"], "wave": 7, "stock": ["pawn"]}},
		{"name": "Drone Strike (3x3 wipe, King immune)", "cfg": {
			"board": [["queen", 0, 1, 1], ["pawn", 0, 4, 6], ["pawn", 1, 3, 5],
				["bishop", 1, 2, 4], ["king", 1, 3, 4], ["rook", 1, 6, 9]],
			"items": ["drone_strike"], "wave": 5, "stock": ["pawn"]}},
		{"name": "Counter-Intel (suppress live tariffs)", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1], ["pawn", 1, 2, 5], ["bishop", 1, 4, 5]],
			"items": ["counter_intel"], "tariffs": ["move_cost", "inflation"],
			"gold": 100, "wave": 11, "stock": ["pawn"]}},
		# --- tariffs ---
		{"name": "Tariffs: all action costs", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1], ["pawn", 1, 2, 5], ["bishop", 1, 4, 5]],
			"tariffs": ["move_cost", "capture_cost", "deploy_cost", "pass_cost",
				"long_range_cost", "ability_cost", "fuse_cost"],
			"gold": 500, "items": ["blitz"], "captured": ["pawn", "pawn"], "stock": ["pawn"], "score": 1000}},
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
		# --- issue 81: hand-built combo boards ---
		# Named for the QUESTION each answers, not for the Artefact it holds.
		# These are the boards a generator cannot produce, because the point is
		# an interaction rather than a trigger: every one settles something this
		# backlog has actually argued about, so it can be re-settled in seconds
		# instead of by reading dispatch code.
		{"name": "Combo: does an Item grant refuse cleanly at the cap of 3?", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]],
			"items": ["blitz", "shield", "promote"], "wave": 9, "gold": 400, "score": 1000}},
		{"name": "Combo: does the Shop refuse to sell a 6th Artefact?", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"artefacts": ["jet-fuel-vial", "denver-bunker-timeshare", "tape-eraser-magnet",
				"deep-state-yearbook", "mao-s-loyalty-badge"],
			"wave": 9, "gold": 900, "score": 1000, "stock": ["pawn"]}},
		{"name": "Combo: does a Piece Buff grant float \"Buffs full\" at the cap of 2?", "cfg": {
			# Bible grants Shield on EVERY capture by these three ids, so the
			# cap is reached within a couple of moves rather than engineered
			"board": [["bishop", 0, 2, 2], ["archbishop", 0, 5, 2],
				["pawn", 1, 3, 3], ["pawn", 1, 4, 3], ["pawn", 1, 2, 4], ["pawn", 1, 5, 4]],
			"artefacts": ["bible-gag-reel-scroll"], "score": 1000, "gold": 200}},
		{"name": "Combo: Bible fires for all three chain ids and no other piece", "cfg": {
			"board": [["bishop", 0, 1, 2], ["dragon-horse", 0, 3, 2], ["archbishop", 0, 5, 2],
				["rook", 0, 7, 2],
				["pawn", 1, 2, 3], ["pawn", 1, 4, 3], ["pawn", 1, 6, 3], ["pawn", 1, 7, 3]],
			"artefacts": ["bible-gag-reel-scroll"], "score": 1000, "gold": 200}},
		{"name": "Combo: is the Deep State Yearbook buy/sell loop really a net loss?", "cfg": {
			# 4 x 5 held = 20 Gold back on a 50-Gold Common at a 50% sell rate:
			# -5 per full cycle, at EVERY collection size, because the cap of 5
			# ends the scaling that made it look infinite
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"artefacts": ["deep-state-yearbook", "jet-fuel-vial", "tape-eraser-magnet",
				"denver-bunker-timeshare", "mao-s-loyalty-badge"],
			"wave": 9, "gold": 600, "score": 1000, "stock": ["pawn"]}},
		{"name": "Combo: can Mao's Loyalty Badge ever net positive Gold?", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"artefacts": ["mao-s-loyalty-badge"],
			"wave": 9, "gold": 400, "score": 1000, "stock": ["pawn"]}},
		{"name": "Combo: does selling an Item switch Denver Bunker's +30% off?", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]],
			"artefacts": ["denver-bunker-timeshare"],
			"items": ["blitz", "shield", "promote"], "wave": 9, "gold": 300, "score": 1000}},
		{"name": "Combo: Tape Eraser Magnet — selling is not using, so it must not fire", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]],
			"artefacts": ["tape-eraser-magnet"], "items": ["blitz"],
			"wave": 9, "gold": 300, "score": 1000}},
		{"name": "Combo: Captured Stock merges and converts, but cannot deploy", "cfg": {
			"board": ZONE_PAWNS + [["queen", 0, 3, 2]],
			"captured": ["rook", "rook", "knight", "pawn"], "stock": ["pawn"],
			"wave": 9, "gold": 400, "score": 1000}},
		{"name": "Combo: Jet Fuel Vial is spent across a Shop close/reopen, not reset", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]],
			"artefacts": ["jet-fuel-vial"], "wave": 9, "gold": 400, "score": 1000,
			"stock": ["pawn"]}},
		{"name": "Combo: the Pallet's count survives a Shop close at an odd purchase", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]],
			"artefacts": ["pandemic-toilet-paper-pallet"], "wave": 9, "gold": 600,
			"score": 1000, "stock": ["pawn"]}},
		{"name": "Combo: two Snowden copies stack their Box rerolls", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"artefacts": ["snowden-s-rubik-s-cube", "snowden-s-rubik-s-cube"],
			"wave": 9, "gold": 600, "score": 1000}},
		{"name": "Combo: Ecdysis copies a KEY, so it must not consume an Artefact slot", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"artefacts": ["ecdysis-sheddings", "jet-fuel-vial", "deep-state-yearbook",
				"tape-eraser-magnet"],
			"wave": 9, "gold": 600, "score": 1000, "stock": ["pawn"]}},
		{"name": "Combo: Hellfire Club at low resources — the softlock shape", "cfg": {
			"board": [["pawn", 0, 3, 1], ["rook", 1, 3, 8]],
			"artefacts": ["hellfire-club-discord-invite"], "gold": 0, "score": 200}},
		# Army Power / Artefact overlaps: one board per Army, each on the
		# resource its Power touches, so a doubled-up effect is visible rather
		# than inferred from two separate readings
		{"name": "Combo Army: Crown — free merges against a Stock full of pairs", "cfg": {
			"army": "Crown", "board": ZONE_PAWNS + [["queen", 0, 3, 2]],
			"stock": ["rook", "rook", "knight", "knight", "bishop", "bishop"],
			"wave": 9, "gold": 400, "score": 1000}},
		{"name": "Combo Army: Wild Hunt — first-capture refund with multiple targets", "cfg": {
			"army": "Wild Hunt",
			"board": [["queen", 0, 3, 2], ["rook", 0, 5, 2],
				["pawn", 1, 3, 4], ["pawn", 1, 5, 4], ["pawn", 1, 2, 3]],
			"items": ["blitz", "blitz"], "wave": 5, "gold": 300, "score": 1000}},
		{"name": "Combo Army: Old Guard — its Power against a scoring board", "cfg": {
			"army": "Old Guard",
			"board": [["queen", 0, 2, 2], ["knight", 0, 4, 2],
				["pawn", 1, 2, 5], ["bishop", 1, 3, 4]],
			"wave": 5, "gold": 300, "score": 1000, "stock": ["pawn"]}},
		{"name": "Combo Army: Syndicate — its Power against a Shop full of Gold", "cfg": {
			"army": "Syndicate", "board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"wave": 9, "gold": 800, "score": 1000, "stock": ["pawn"]}},
		{"name": "Combo Army: Cult — its Power against a Buff-granting board", "cfg": {
			"army": "Cult",
			"board": [["bishop", 0, 2, 2], ["archbishop", 0, 5, 2],
				["pawn", 1, 3, 3], ["pawn", 1, 4, 3]],
			"artefacts": ["bible-gag-reel-scroll"], "wave": 5, "gold": 300, "score": 1000}},
		{"name": "Combo Army: Horde — its Power against a wide spawn", "cfg": {
			"army": "Horde", "board": [["queen", 0, 3, 2], ["rook", 0, 5, 2]],
			"wave": 3, "gold": 300, "score": 1000, "stock": ["pawn", "pawn", "pawn"]}},
		{"name": "Combo: the Army Ability costs an Action, Artefact activation does not", "cfg": {
			"army": "Crown", "board": ZONE_PAWNS + [["queen", 0, 3, 2]],
			"stock": ["rook", "rook"], "artefacts": ["jet-fuel-vial"],
			"wave": 9, "gold": 400, "score": 1000}},
		{"name": "Combo: all three caps full at once (Items 3, Buffs 2, Artefacts 5)", "cfg": {
			"board": [["bishop", 0, 2, 2], ["archbishop", 0, 5, 2],
				["pawn", 1, 3, 3], ["pawn", 1, 4, 3]],
			"items": ["blitz", "shield", "promote"],
			"artefacts": ["bible-gag-reel-scroll", "jet-fuel-vial", "deep-state-yearbook",
				"tape-eraser-magnet", "denver-bunker-timeshare"],
			"wave": 9, "gold": 900, "score": 2000, "stock": ["pawn"]}},
		# --- loss conditions ---
		{"name": "Loss: clock-out (10s)", "cfg": {
			"board": ZONE_PAWNS, "clock_s": 10.0}},
		{"name": "Loss: starvation (pass twice)", "cfg": {
			"board": [["pawn", 0, 2, 0], ["rook", 1, 2, 9]]}},
		{"name": "Loss: back-row breach", "cfg": {
			"board": [["queen", 0, 3, 3],
				["rook", 1, 0, 0], ["rook", 1, 1, 0], ["rook", 1, 2, 0],
				["rook", 1, 3, 0], ["rook", 1, 4, 0], ["pawn", 1, 5, 1]]}},
		# --- enemy AI (2026-09-06: one-ply material safety, rules.gd ai_action) ---
		# PASS and watch: the rook must NOT take the pawn on (0,5) — the pawn on
		# (1,4) defends it — and takes the free knight on (7,10) instead.
		{"name": "Enemy AI: declines a poisoned capture, takes the free piece", "cfg": {
			"board": [["pawn", 0, 0, 5], ["pawn", 0, 1, 4], ["knight", 0, 7, 10],
				["rook", 1, 0, 10]], "stock": ["pawn"]}},
		# PASS and watch: the pawn on (3,7) can only step onto (3,6), which the
		# player pawn covers, so the enemy holds it and advances the knight.
		{"name": "Enemy AI: holds a pawn rather than feed it, advances the knight", "cfg": {
			"board": [["pawn", 0, 2, 5], ["pawn", 1, 3, 7], ["knight", 1, 6, 10]],
			"stock": ["pawn"]}},
	]
