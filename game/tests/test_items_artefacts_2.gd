extends SceneTree
## Artefacts, part 2: grant-on-capture (Obedience-Flavored Tap Water etc.),
## issue 19's remaining hooks (on_piece_lost, on_item_consume, on_rank_up,
## chain-lookup, board-half reads, enemy auto-debuff, cheap follow-ups,
## capture conversion — its tariff hooks moved to test_items_tariffs.gd),
## and combat & positioning (issue 24). Split out of test_items.gd (issue 37).
## Run headless:  godot --headless --path game -s tests/test_items_artefacts_2.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Economy := preload("res://scripts/economy.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const MergeLogic := preload("res://scripts/merge_logic.gd")
const Rules := preload("res://scripts/rules.gd")
const Shop := preload("res://scripts/shop.gd")
const Items := preload("res://data/items.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


## Fixtures are deterministic by default (slice 36: a flaky suite makes every
## green claim unfalsifiable). Pass a "seed" in cfg, or seed_it=false, to opt
## out — only for a test that genuinely wants variance.
const DEFAULT_SEED := 1


func _boot(cfg: Dictionary, seed_it: bool = true) -> Node2D:
	if seed_it and not cfg.has("seed"):
		cfg = cfg.duplicate()
		cfg.seed = DEFAULT_SEED
	GameScript.next_config = cfg
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _init() -> void:
	# --- fix (ruled 2026-08-28): grant-on-capture (Obedience-Flavored Tap
	# Water, Holy Lint) must land AFTER critical/range are consumed by the
	# SAME capture that granted them — a reward banked for the NEXT capture,
	# not this one. Before the fix, a granted Critical doubled the capture
	# that granted it (capture_multiplier read the just-mutated board[from]
	# synchronously) and a granted Range was immediately spent for zero
	# effect (the comment above, on Holy Lint, is the flake this caused).
	# Seeds are found live, mirroring _random_buff_key's own pool + roll, so
	# this doesn't hardcode an RNG index that could silently drift.
	var tac_pool: Array = Items.PIECE_BUFFS.filter(func(b: Dictionary) -> bool:
		return not b.get("self_harming", false) and b.tier == "Tactical")
	var crit_idx := -1
	var range_idx := -1
	for i in tac_pool.size():
		if tac_pool[i].key == "critical":
			crit_idx = i
		elif tac_pool[i].key == "range":
			range_idx = i
	var find_rng := RandomNumberGenerator.new()
	var crit_seed := -1
	var range_seed := -1
	for s in 5000:
		if crit_seed < 0:
			find_rng.seed = s
			if find_rng.randi() % tac_pool.size() == crit_idx:
				crit_seed = s
		if range_seed < 0:
			find_rng.seed = s
			if find_rng.randi() % tac_pool.size() == range_idx:
				range_seed = s
		if crit_seed >= 0 and range_seed >= 0:
			break
	check(crit_seed >= 0 and range_seed >= 0, "(setup) found seeds landing a granted Critical and a granted Range")

	var gc := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 1, 2, 3], ["pawn", 1, 5, 5], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["obedience-flavored-tap-water"]})
	await process_frame
	var gc_pawn_val: int = gc.defs.pawn.value
	gc.actions_left = 3
	gc.rng.seed = crit_seed # the very next rng draw is _random_buff_key's, inside this capture
	gc._move_player(Vector2i(2, 2), Vector2i(2, 3)) # first Capture this wave: Tap Water grants Critical
	check(gc.score == gc_pawn_val,
		"a Critical granted by THIS capture doesn't double THIS capture's own score")
	check(BuffLogic.has(gc.board[Vector2i(2, 3)], "critical"),
		"the granted Critical survives on the attacker after the capture that granted it")
	gc.score = 0
	gc._move_player(Vector2i(2, 3), Vector2i(5, 5)) # a second, unrelated capture
	check(gc.score == gc_pawn_val * 2,
		"the banked Critical doubles the NEXT capture — it really works as a reward")
	gc.queue_free()
	await process_frame

	var gr := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 1, 2, 3], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["obedience-flavored-tap-water"]})
	await process_frame
	gr.actions_left = 3
	gr.rng.seed = range_seed
	gr._move_player(Vector2i(2, 2), Vector2i(2, 3)) # first Capture this wave: Tap Water grants Range
	check(BuffLogic.has(gr.board[Vector2i(2, 3)], "range"),
		"the granted Range survives on the attacker after the capture that granted it, not spent for zero effect")
	gr.queue_free()
	await process_frame

	# Frame 25: On Wave clear, +1 Tactical Item, -10 Gold
	var frame := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["frame-25"], "gold": 50})
	await process_frame
	var items_n0: int = frame.items.size()
	WaveLogic.queue(frame, frame.wave + 1)
	check(frame.items.size() == items_n0 + 1, "Frame 25: +1 Item at Wave clear")
	check(frame.items.back().tier == "Tactical", "Frame 25: the granted Item is Tactical-tier")
	check(frame.gold == 40, "Frame 25: -10 Gold at Wave clear")
	frame.queue_free()
	await process_frame

	# Sleeper Agent Pillow: a bought Piece arrives with a random Tactical Buff
	# — the piece isn't on the board yet, so this rides stock as a Dictionary
	var sleeper := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["sleeper-agent-pillow"], "gold": 9999})
	await process_frame
	sleeper.state = sleeper.State.PLAYER_TURN
	sleeper.actions_left = 5
	var piece_i := -1
	for i in sleeper.shop_stock.size():
		if sleeper.shop_stock[i].kind == "piece":
			piece_i = i
			break
	Shop.buy(sleeper, piece_i)
	var bought: Variant = sleeper.stock.back()
	check(bought is Dictionary and BuffLogic.of(bought).size() == 1,
		"Sleeper Agent Pillow: the bought Piece lands in Stock carrying a Buff")
	sleeper.actions_left = 5
	sleeper._place(bought, Vector2i(4, 2))
	check(BuffLogic.of(sleeper.board[Vector2i(4, 2)]).size() == 1,
		"Sleeper Agent Pillow: the Buff survives deployment onto the board")
	sleeper.queue_free()
	await process_frame

	# Shrinkflation Cereal Box: +10 Gold/+10 Score/+1s Clock at every Turn end
	# (new on_turn_end hook, game.gd:_on_pass)
	var shrink := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["shrinkflation-cereal-box"], "gold": 50, "score": 0})
	await process_frame
	shrink.state = shrink.State.PLAYER_TURN
	shrink.actions_left = 0 # any non-SETUP pass through _on_pass reaches on_turn_end
	var clock0: float = shrink.clock_ms
	shrink._on_pass()
	check(shrink.gold == 60 and shrink.score == 10, "Shrinkflation Cereal Box: +10 Gold/+10 Score at Turn end")
	check(shrink.clock_ms > clock0, "Shrinkflation Cereal Box: +1s Clock at Turn end")
	shrink.queue_free()
	await process_frame

	# Skull and Bones Coffin: +20% Score gain while holding 200+ Gold, gated
	# off (not just discounted) below that
	var skull := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["skull-and-bones-coffin"], "gold": 199})
	await process_frame
	Economy.earn(skull, 100)
	check(skull.score == 100, "Skull and Bones Coffin: no bonus under 200 Gold")
	skull.gold = 200
	Economy.earn(skull, 100)
	check(skull.score == 220, "Skull and Bones Coffin: +20% Score gain at 200+ Gold")
	skull.queue_free()
	await process_frame

	# Majestic 12 Secret Handshake Diagram: Item Boxes only offer
	# Strategic/Decisive Items — the mixed Box Pick is unaffected
	var majestic := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["majestic-12-secret-handshake-diagram"]})
	await process_frame
	var tactical_keys: Array = Items.ITEMS.filter(func(it: Dictionary) -> bool:
		return it.tier == "Tactical").map(func(it: Dictionary) -> String: return it.key)
	var saw_only_high_tier := true
	for i in 20:
		for opt in majestic._box_options("item"):
			if tactical_keys.has(opt.payload.key):
				saw_only_high_tier = false
	check(saw_only_high_tier, "Majestic 12: typed Item Boxes never roll a Tactical Item")
	check(majestic._box_options().size() == 3, "Majestic 12: the mixed Box Pick still rolls freely")
	majestic.queue_free()
	await process_frame

	# --- issue 19: on_piece_lost (Satoshi's Private Key, Nibiru Hide-and-Seek
	# Trophy) — game.gd's new choke point, called from _destroy here
	var sat := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 0, 3, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 50, "artefacts": ["satoshi-s-private-key", "nibiru-hide-and-seek-trophy"]})
	await process_frame
	WaveLogic.queue(sat, sat.wave + 1) # Wave clear 1: Satoshi +2/ally (2 allies), Nibiru +10 (streak 1)
	check(sat.gold == 50 + 4 + 10, "Satoshi's Private Key + Nibiru Hide-and-Seek Trophy: first Wave-clear payout")
	WaveLogic.queue(sat, sat.wave + 1) # Wave clear 2, no loss yet: Nibiru grows to +20 (streak 2)
	check(sat.gold == 50 + 4 + 10 + 4 + 20, "Nibiru Hide-and-Seek Trophy: the payout grows +10 per Wave")
	sat._destroy(Vector2i(2, 2)) # lose a piece: Satoshi -2 Gold, Nibiru streak resets
	check(sat.nibiru_wave_streak == 0, "Nibiru Hide-and-Seek Trophy: losing a piece resets the streak")
	var gold_after_loss: int = sat.gold
	check(gold_after_loss == 50 + 4 + 10 + 4 + 20 - 2, "Satoshi's Private Key: -2 Gold on losing a piece")
	WaveLogic.queue(sat, sat.wave + 1) # Wave clear 3: Nibiru restarts at +10 (streak 1), 1 ally left
	check(sat.gold == gold_after_loss + 2 + 10, "Nibiru Hide-and-Seek Trophy: collapses to 0 and restarts after a loss")
	sat.queue_free()
	await process_frame

	# --- issue 19: on_piece_lost (Lusitania "Hardtack" Crate, D.B. Cooper's
	# Parachute, Templar Severance Gold, Backmasked Vinyl, Tutankhamun's Death
	# Thong) — the Buff-carry / Ranked / attacker-debuff branches
	var lus := _boot({"board": [["queen", 0, 2, 2, {"buffs": [{"key": "critical"}]}],
			["pawn", 1, 7, 10]],
		"wave": 4, "gold": 0, "score": 0,
		"artefacts": ["lusitania-hardtack-crate", "d-b-cooper-s-parachute"]})
	await process_frame
	lus._destroy(Vector2i(2, 2)) # the queen carries a Buff and is unranked
	check(lus.score == 150, "Lusitania \"Hardtack\" Crate: +150 Score for a Buff-carrying piece lost")
	check(lus.gold == 150 + roundi(lus.defs["queen"].value * 0.75),
		"Lusitania (+150 Gold) and D.B. Cooper's Parachute (+75% of value) both pay on the same loss")
	lus.queue_free()
	await process_frame

	var rank := _boot({"board": [["sergeant", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0,
		"artefacts": ["templar-severance-gold-one-pile", "backmasked-vinyl"]})
	await process_frame
	rank._destroy(Vector2i(2, 2)) # a Ranked piece (sergeant, promoted from pawn)
	check(rank.gold == 150, "Templar Severance Gold (One Pile): +150 Gold for a Ranked piece lost")
	check(rank.stock == ["pawn"], "Backmasked Vinyl: a copy of the base-chain piece (pawn) joins Stock")
	rank.queue_free()
	await process_frame

	var unranked := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0,
		"artefacts": ["templar-severance-gold-one-pile", "backmasked-vinyl"]})
	await process_frame
	unranked._destroy(Vector2i(2, 2)) # a base pawn: not Ranked — neither artefact pays
	check(unranked.gold == 0 and unranked.stock.is_empty(),
		"Templar Severance Gold / Backmasked Vinyl: no payout for a non-Ranked piece")
	unranked.queue_free()
	await process_frame

	var tutan := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 2, 5]],
		"wave": 4, "artefacts": ["tutankhamun-s-death-thong"]})
	await process_frame
	await tutan._run_enemy_actions() # the enemy rook captures the player's pawn
	check(BuffLogic.has(tutan.board[Vector2i(2, 2)], "slow"),
		"Tutankhamun's Death Thong: the capturing enemy piece gets Slow")
	tutan.queue_free()
	await process_frame

	# --- issue 19: on_item_consume — each artefact boots alone (any single-item
	# use also satisfies Tape Eraser Magnet's "last held" gate, so it gets its
	# own isolated boot rather than entangling its math with the others)
	var arms := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0, "artefacts": ["arms-fair-goodie-bag"]})
	await process_frame
	arms.items.append({"key": "x1", "name": "x1", "tier": "Strategic", "target": "", "description": ""})
	arms.actions_left = 5
	arms._use_item(0)
	check(arms.gold == 25, "Arms Fair Goodie Bag: +25 Gold on a Strategic Item use")
	arms.queue_free()
	await process_frame

	var doom := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "score": 0, "artefacts": ["doomsday-autoclicker"]})
	await process_frame
	doom.items.append({"key": "x2", "name": "x2", "tier": "Decisive", "target": "", "description": ""})
	doom.actions_left = 5
	var clock_doom: float = doom.clock_ms
	doom._use_item(0)
	check(doom.score == 200 and doom.clock_ms > clock_doom,
		"Doomsday Autoclicker: +200 Score and +10s Clock on a Decisive Item use")
	doom.queue_free()
	await process_frame

	var tape := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0, "score": 0, "artefacts": ["tape-eraser-magnet"]})
	await process_frame
	tape.items.append({"key": "x3", "name": "x3", "tier": "Tactical", "target": "", "description": ""})
	tape.actions_left = 5
	tape._use_item(0) # the ONLY held Item — Tape Eraser Magnet's "last held" gate
	check(tape.score == 100 and tape.gold == 50,
		"Tape Eraser Magnet: +100 Score and +50 Gold on using your last held Item")
	tape.queue_free()
	await process_frame

	var lobbyist := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "artefacts": ["defense-lobbyist-business-card"]})
	await process_frame
	lobbyist.items.append({"key": "x4", "name": "x4", "tier": "Strategic", "target": "", "description": ""})
	lobbyist.actions_left = 5
	lobbyist._use_item(0) # non-Tactical use: the grant lands, then x4 itself is removed
	check(lobbyist.items.size() == 1 and lobbyist.items[0].tier == "Tactical",
		"Defense Lobbyist Business Card: a non-Tactical use grants a Tactical Item")
	lobbyist.items.clear()
	lobbyist.items.append({"key": "x5", "name": "x5", "tier": "Tactical", "target": "", "description": ""})
	lobbyist.actions_left = 5
	lobbyist._use_item(0) # a Tactical use grants nothing
	check(lobbyist.items.is_empty(), "Defense Lobbyist Business Card: no grant on a Tactical use")
	lobbyist.queue_free()
	await process_frame

	var cancel := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "artefacts": ["dihydrogen-monoxide-battery", "wardenclyffe-aaa-batteries"]})
	await process_frame
	cancel.items.append({"key": "y1", "name": "y1", "tier": "Tactical", "target": "", "description": ""})
	cancel.actions_left = 5
	cancel._use_item(0)
	check(cancel.items.size() == 1, "Dihydrogen Monoxide Battery: the first Tactical use this Wave is not consumed")
	cancel.actions_left = 5
	cancel._use_item(0) # second use this Wave: both artefacts already spent their free use
	check(cancel.items.is_empty(), "the second use this Wave IS consumed")
	cancel.queue_free()
	await process_frame

	var fidelity := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "artefacts": ["33rd-degree-fidelity-card"]})
	await process_frame
	for i in 3:
		fidelity.items.append({"key": "z", "name": "z", "tier": "Tactical", "target": "", "description": ""})
		fidelity.actions_left = 5
		fidelity._use_item(0)
	check(fidelity.items.size() == 1 and fidelity.items[0].tier == "Strategic",
		"33rd Degree Fidelity Card: the 3rd Tactical use grants a Strategic Item")
	fidelity.queue_free()
	await process_frame

	# --- issue 19: on_rank_up (Witness Protection Mustache, Holy Grail
	# Coaster, Bigfoot Toenail Clipping) — merge_logic.gd's commit_merge, a
	# same-id merge (Rank Up), both board- and Stock-landing cases
	var rankup := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 0, 3, 2], ["rook", 1, 7, 10]],
		"wave": 4, "stock": ["pawn", "pawn"],
		"artefacts": ["witness-protection-mustache", "holy-grail-coaster", "bigfoot-toenail-clipping"]})
	await process_frame
	var clock_rankup: float = rankup.clock_ms
	MergeLogic.commit_merge(rankup, Vector2i(2, 2), Vector2i(3, 2)) # board merge: lands on Vector2i(3, 2)
	check(rankup.clock_ms > clock_rankup, "Witness Protection Mustache: +20s Clock on Rank Up")
	check(BuffLogic.of(rankup.board[Vector2i(3, 2)]).size() == 1,
		"Holy Grail Coaster: +1 Piece Buff to the Ranked piece (board landing)")
	check(rankup.stock.has("pawn"), "Bigfoot Toenail Clipping: a copy of the base-chain piece joins Stock")
	MergeLogic.commit_merge(rankup, # pool-only merge (both refs from Stock): lands in Stock, not the board
		{"id": "pawn", "cap": false, "entry": "pawn"}, {"id": "pawn", "cap": false, "entry": "pawn"})
	var converted: Variant = null # Bigfoot Toenail Clipping's own Stock grant (a bare
		# String) can land anywhere in the Array — find the Dictionary instead
	for stock_entry in rankup.stock:
		if stock_entry is Dictionary:
			converted = stock_entry
	check(converted != null and BuffLogic.of(converted).size() == 1,
		"Holy Grail Coaster: the Stock-landing case converts the bare id into a Buff-carrying Dictionary")
	rankup.queue_free()
	await process_frame

	# --- issue 19: chain-lookup off existing hooks (CIA Heart Attack Gun,
	# Montauk Eggo Waffle) — ItemLogic.chain_base, no new hook
	var cia := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0, "artefacts": ["cia-heart-attack-gun"]})
	await process_frame
	var pawn_val: int = cia.defs["pawn"].value
	Economy.capture_score(cia, "pawn", "knight", true, Vector2i(2, 2)) # Buffed attacker, first Capture this Turn
	check(cia.gold == pawn_val, "CIA Heart Attack Gun: +100% Gold on the first Capture with a Buffed attacker")
	cia.gold = 0
	cia.turn_capture_count = 0
	Economy.capture_score(cia, "pawn", "pawn", false, Vector2i(2, 2)) # unranked, unbuffed attacker: no bonus
	check(cia.gold == 0, "CIA Heart Attack Gun: no bonus for an unranked, unbuffed attacker")
	cia.gold = 0
	cia.turn_capture_count = 0
	Economy.capture_score(cia, "pawn", "sergeant", false, Vector2i(2, 2)) # a Ranked, unbuffed attacker still qualifies
	check(cia.gold == pawn_val, "CIA Heart Attack Gun: +100% Gold for a Ranked (not just Buffed) attacker")
	cia.queue_free()
	await process_frame

	var montauk := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "stock": ["pawn"], "artefacts": ["montauk-eggo-waffle"]})
	await process_frame
	montauk.artefacts[0].acquired_wave = 1 # per-artefact cadence (2026-08-28):
		# isolate the handler's own math from acquisition-stamping coverage below
	WaveLogic.queue(montauk, 6) # Wave 5 just cleared -> this copy's own "5-Wave Milestone" fires this on_wave_clear
	check(montauk.stock == ["sergeant"],
		"Montauk Eggo Waffle: the only Stock piece Ranks Up on the 5-Wave Milestone")
	montauk.queue_free()
	await process_frame

	# --- issue 19: board-half reads (Dyatlov Geiger Counter, FEMA Summer Camp
	# Flyer) — Tuning.BOARD_H, no new hook
	var dya := _boot({"board": [["pawn", 0, 2, 7], ["pawn", 0, 3, 8], ["pawn", 0, 4, 9],
			["rook", 1, 7, 10]],
		"wave": 4, "score": 0, "artefacts": ["dyatlov-geiger-counter"]})
	await process_frame
	Economy.earn(dya, 100)
	check(dya.score == 200, "Dyatlov Geiger Counter: +100% Score with 3+ allies on the enemy half")
	dya.queue_free()
	await process_frame

	var fema := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2], ["rook", 1, 4, 3]],
		"wave": 4, "gold": 0, "artefacts": ["fema-summer-camp-flyer"]})
	await process_frame
	fema.state = fema.State.PLAYER_TURN
	fema.actions_left = 0
	fema._on_pass()
	check(fema.gold == 4, "FEMA Summer Camp Flyer: +2 Gold per enemy piece on your half at Turn end")
	fema.queue_free()
	await process_frame

	# --- issue 19: enemy auto-debuff (Diplomatic Migraine Ray) — BuffLogic is
	# owner-agnostic already, no new hook
	var dip := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 1, 3, 8], ["queen", 1, 4, 9]],
		"wave": 4, "artefacts": ["diplomatic-migraine-ray"]})
	await process_frame
	WaveLogic.queue(dip, dip.wave + 1) # on_wave_spawn: the strongest enemy piece gets Slow
	check(BuffLogic.has(dip.board[Vector2i(4, 9)], "slow"),
		"Diplomatic Migraine Ray: the strongest enemy piece gets Slow on Wave spawn")
	dip.queue_free()
	await process_frame

	# --- issue 19: cheap follow-ups (Casino Invisible Clock, 2012 Doomsday
	# Party Hat, Fort Knox IOU) — hooks that landed after their own slice
	var cheap := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 9999, "score": 0,
		"artefacts": ["casino-invisible-clock", "2012-doomsday-party-hat", "fort-knox-iou"]})
	await process_frame
	var clock_cheap1: float = cheap.clock_ms
	for i in cheap.shop_stock.size():
		if cheap.shop_stock[i].kind == "item":
			Shop.buy(cheap, i)
			break
	check(cheap.clock_ms > clock_cheap1, "Casino Invisible Clock: +25s Clock on a Shop purchase")
	var clock_cheap2: float = cheap.clock_ms
	Economy.earn(cheap, 20) # a Gold gain, not a purchase — 2012 Doomsday Party Hat's own hook
	check(cheap.clock_ms > clock_cheap2, "2012 Doomsday Party Hat: +5s Clock per 10 Gold gained")
	cheap.gold = 5
	var s0: int = cheap.score
	Economy.earn(cheap, 100)
	check(cheap.score == s0 + 150, "Fort Knox IOU: +50% Score gain while holding under 10 Gold")
	cheap.queue_free()
	await process_frame

	# --- issue 19: capture conversion, the cheap wave-clear half (Stockholm
	# Syndrome Pamphlet)
	var stock19 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "captured": ["pawn"], "artefacts": ["stockholm-syndrome-pamphlet"]})
	await process_frame
	WaveLogic.queue(stock19, stock19.wave + 1)
	check(stock19.captured.is_empty() and stock19.stock.has("pawn"),
		"Stockholm Syndrome Pamphlet: a Captured Stock piece moves to Stock on Wave clear")
	stock19.queue_free()
	await process_frame

	# --- issue 24: combat & positioning (USS Eldridge Invisibility Paint,
	# Royal Fiat (Undamaged)) — the shared post-move ctx flag mechanism
	var eldridge := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2]],
		"wave": 3, "artefacts": ["uss-eldridge-invisibility-paint"]})
	await process_frame
	eldridge.actions_left = 5
	eldridge._move_player(Vector2i(2, 2), Vector2i(3, 2))
	check(eldridge.board.has(Vector2i(2, 2)) and not eldridge.board.has(Vector2i(3, 2)),
		"USS Eldridge Invisibility Paint: the capturing piece returns to its starting position")
	eldridge.queue_free()
	await process_frame

	var eldridge2 := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2], ["pawn", 1, 4, 2]],
		"wave": 3, "artefacts": ["uss-eldridge-invisibility-paint"]})
	await process_frame
	eldridge2.actions_left = 5
	eldridge2._move_player(Vector2i(2, 2), Vector2i(3, 2)) # 1st Capture this Turn: returns
	eldridge2._move_player(Vector2i(2, 2), Vector2i(4, 2)) # 2nd Capture this Turn: stays put
	check(eldridge2.board.has(Vector2i(4, 2)) and not eldridge2.board.has(Vector2i(2, 2)),
		"USS Eldridge Invisibility Paint: only your first Capture each Turn returns")
	eldridge2.queue_free()
	await process_frame

	var fiat := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2]],
		"wave": 3, "artefacts": ["royal-fiat-undamaged"]})
	await process_frame
	fiat.actions_left = 5
	fiat._move_player(Vector2i(2, 2), Vector2i(3, 2))
	check(fiat.board.has(Vector2i(0, 0)) and not fiat.board.has(Vector2i(3, 2)),
		"Royal Fiat (Undamaged): the first capturing piece each Turn retreats to the back row")
	fiat.queue_free()
	await process_frame

	var backrow: Array = []
	for x in 8:
		backrow.append(["pawn", 0, x, 0])
	var fiat_full := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2]] + backrow,
		"wave": 3, "artefacts": ["royal-fiat-undamaged"]})
	await process_frame
	fiat_full.actions_left = 5
	fiat_full._move_player(Vector2i(2, 2), Vector2i(3, 2))
	check(fiat_full.board.has(Vector2i(3, 2)),
		"Royal Fiat (Undamaged): a full back row is a no-op, the piece stays put")
	fiat_full.queue_free()
	await process_frame

	# both held: return_to_start wins the tie (ruled in artefact_hooks.gd)
	var both := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2]],
		"wave": 3, "artefacts": ["uss-eldridge-invisibility-paint", "royal-fiat-undamaged"]})
	await process_frame
	both.actions_left = 5
	both._move_player(Vector2i(2, 2), Vector2i(3, 2))
	check(both.board.has(Vector2i(2, 2)),
		"USS Eldridge Invisibility Paint takes precedence over Royal Fiat when both fire together")
	both.queue_free()
	await process_frame

	# Fireproof Pajamas — blocks Item/Tariff destruction (_destroy's choke
	# point), leaves ordinary Capture untouched
	var fire := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 4, 4]],
		"wave": 3, "artefacts": ["fireproof-pajamas"]})
	await process_frame
	fire._destroy(Vector2i(4, 4))
	check(fire.board.has(Vector2i(4, 4)) and fire.lost_player == 0,
		"Fireproof Pajamas: an Item/Tariff destroy is blocked and doesn't count as a loss")
	fire.queue_free()
	await process_frame

	var fire2 := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 2, 5]],
		"wave": 4, "artefacts": ["fireproof-pajamas"]})
	await process_frame
	await fire2._run_enemy_actions() # the enemy rook captures the player's pawn
	check(fire2.board.has(Vector2i(2, 2)) and fire2.board[Vector2i(2, 2)].owner == Rules.ENEMY,
		"Fireproof Pajamas: does not block an ordinary Capture, only Item/Tariff destruction")
	fire2.queue_free()
	await process_frame

	# Hoffa's Cement Shoes — once per Wave, the capturer sinks with its victim
	var hoffa := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 2, 5]],
		"wave": 4, "artefacts": ["hoffa-s-cement-shoes"]})
	await process_frame
	await hoffa._run_enemy_actions()
	check(not hoffa.board.has(Vector2i(2, 2)) and hoffa.lost_enemy == 1,
		"Hoffa's Cement Shoes: the capturing enemy piece is removed along with its victim")
	hoffa.queue_free()
	await process_frame

	var hoffa2 := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 0, 4, 2],
			["rook", 1, 2, 5], ["rook", 1, 4, 5]],
		"wave": 4, "artefacts": ["hoffa-s-cement-shoes"]})
	await process_frame
	await hoffa2._run_enemy_actions() # 1st Capture this Wave: mutual destruction
	await hoffa2._run_enemy_actions() # 2nd Capture this Wave: already used, capturer survives
	var enemies_left := 0
	for pos in hoffa2.board:
		if hoffa2.board[pos].owner == Rules.ENEMY:
			enemies_left += 1
	check(hoffa2.board.is_empty() == false and enemies_left == 1 and hoffa2.lost_enemy == 1
			and hoffa2.lost_player == 2,
		"Hoffa's Cement Shoes: once per Wave — the second Capture's attacker survives")
	hoffa2.queue_free()
	await process_frame


	print("---")
	if fails == 0:
		print("ALL ARTEFACTS 2 CHECKS OK")
	quit(1 if fails > 0 else 0)
