extends SceneTree
## Artefacts, part 3: Piece Buff lifecycle hooks (issue 23), the per-piece
## capture ledger (issue 25, its tariff-interception subsection moved to
## test_items_tariffs.gd), and the economy/Shop/Box batch (issue 26).
## Split out of test_items.gd (issue 37).
## Run headless:  godot --headless --path game -s tests/test_items_artefacts_3.gd

const GameScript := preload("res://scripts/game.gd")
const Economy := preload("res://scripts/economy.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const Rules := preload("res://scripts/rules.gd")
const Shop := preload("res://scripts/shop.gd")
const Items := preload("res://data/items.gd")
const Waves := preload("res://data/waves.gd")
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


func _item(key: String, target: String) -> Dictionary:
	return {"key": key, "name": key, "tier": "T", "target": target, "description": ""}


func _init() -> void:
	# --- issue 23: on_buff_consume (Amityville Ouija Board, Cleopatra's Hairpin)
	# — game.gd's new _consume_buff choke point
	var amc := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["amityville-ouija-board", "cleopatra-s-hairpin"]})
	await process_frame
	BuffLogic.add(amc.board[Vector2i(2, 2)], "shield") # Tactical
	await amc._run_enemy_actions() # the rook attacks, Shield repels and is consumed
	check(amc.gold == 10,
		"Amityville Ouija Board: +10 Gold on any-tier Piece Buff consume; Cleopatra's Hairpin skips a Tactical buff")
	BuffLogic.add(amc.board[Vector2i(2, 2)], "reflect") # Decisive
	await amc._run_enemy_actions() # the same rook attacks again, into Reflect
	check(amc.gold == 10 + 10 + 100,
		"Cleopatra's Hairpin: +100 Gold on top of Amityville's own +10, for a Decisive Buff (Reflect)")
	amc.queue_free()
	await process_frame

	# --- issue 23: on_buff_consume / on_piece_demoted, owner-agnostic
	# (Guidestone Blood Ritual) ---
	var gbr := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5]],
		"wave": 3, "gold": 0, "artefacts": ["guidestone-blood-ritual"]})
	await process_frame
	gbr.actions_left = 5
	BuffLogic.add(gbr.board[Vector2i(2, 5)], "shield") # the ENEMY rook carries it
	gbr._move_player(Vector2i(2, 2), Vector2i(2, 5)) # the player attacks into it
	check(gbr.gold == 25,
		"Guidestone Blood Ritual: +25 Gold on ANY piece's Buff consume, ally or enemy")
	gbr.queue_free()
	await process_frame

	var gbr2 := _boot({"board": [["sergeant", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["guidestone-blood-ritual"]})
	await process_frame
	gbr2.actions_left = 5
	gbr2.items.append(_item("demote", "tile"))
	gbr2._use_item(0)
	gbr2._item_click(Vector2i(2, 2))
	check(gbr2.board[Vector2i(2, 2)].id == "pawn" and gbr2.gold == 25,
		"Guidestone Blood Ritual: +25 Gold whenever a piece (ally or enemy) is Demoted")
	gbr2.queue_free()
	await process_frame

	# --- issue 23: on_buff_consume, first-per-Wave re-apply (Youth Fountain Martini) ---
	var yfm := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5]],
		"wave": 3, "artefacts": ["youth-fountain-martini"]})
	await process_frame
	BuffLogic.add(yfm.board[Vector2i(2, 2)], "shield")
	await yfm._run_enemy_actions() # Shield blocks the attack and is consumed
	check(BuffLogic.has(yfm.board[Vector2i(2, 2)], "shield"),
		"Youth Fountain Martini: the first Buff consumed each Wave is re-applied to the same piece")
	await yfm._run_enemy_actions() # the same rook, repelled again, attacks again
	check(not BuffLogic.has(yfm.board[Vector2i(2, 2)], "shield"),
		"Youth Fountain Martini: only the first consume each Wave gets the refresh")
	yfm.queue_free()
	await process_frame

	# --- issue 23: on_buff_apply (Pied Piper's Rat Census, mRNA Firmware Update)
	# — game.gd's new _apply_buff choke point ---
	var ppr := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 3, 3], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["pied-piper-s-rat-census"]})
	await process_frame
	ppr.actions_left = 5
	ppr.items.append(_item("buff_box", "tile"))
	ppr._use_item(0)
	ppr._buff_chosen("shield")
	ppr._item_click(Vector2i(2, 2)) # buff the queen — the pawn at (3,3) is adjacent
	check(BuffLogic.has(ppr.board[Vector2i(2, 2)], "shield")
			and BuffLogic.has(ppr.board[Vector2i(3, 3)], "shield"),
		"Pied Piper's Rat Census: applying a Piece Buff copies it to one adjacent ally")
	ppr.queue_free()
	await process_frame

	var mrna := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["mrna-firmware-update"]})
	await process_frame
	mrna.actions_left = 5
	for i in 3:
		mrna.items.append(_item("buff_box", "tile"))
		mrna._use_item(0)
		mrna._buff_chosen("shield")
		mrna._item_click(Vector2i(2, 2))
	check(mrna.board[Vector2i(2, 2)].id == "sergeant",
		"mRNA Firmware Update: every 3rd Piece Buff you apply also Ranks Up the piece")
	mrna.queue_free()
	await process_frame

	# --- issue 23: on_piece_lost buff transfer (KGB Photo Eraser) ---
	var kgb := _boot({"board": [["queen", 0, 2, 2, {"buffs": [{"key": "critical"}]}],
			["pawn", 0, 3, 3], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["kgb-photo-eraser"]})
	await process_frame
	kgb._destroy(Vector2i(2, 2)) # the queen carries a Buff and is lost
	check(BuffLogic.has(kgb.board[Vector2i(3, 3)], "critical"),
		"KGB Photo Eraser: a lost piece's Buff transfers to the nearest ally")
	kgb.queue_free()
	await process_frame

	# --- issue 23: demotion / buff-removal immunity (Antikythera Warranty
	# Card, Atlantis Snow Globe) — game.gd "demote"/"radar_jamming" ---
	var ant := _boot({"board": [["sergeant", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["antikythera-warranty-card"]})
	await process_frame
	ant.actions_left = 5
	ant.items.append(_item("demote", "tile"))
	ant._use_item(0)
	ant._item_click(Vector2i(2, 2))
	check(ant.board[Vector2i(2, 2)].id == "sergeant",
		"Antikythera Warranty Card: your pieces cannot be Demoted")
	BuffLogic.add(ant.board[Vector2i(2, 2)], "shield")
	ant.items.append(_item("radar_jamming", "tile"))
	ant._use_item(0)
	ant._item_click(Vector2i(2, 2))
	check(BuffLogic.has(ant.board[Vector2i(2, 2)], "shield"),
		"Antikythera Warranty Card: your Piece Buffs cannot be removed by Radar Jamming")
	ant.queue_free()
	await process_frame

	var atl := _boot({"board": [["sergeant", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["atlantis-snow-globe"]})
	await process_frame
	atl.actions_left = 5
	atl.items.append(_item("demote", "tile"))
	atl._use_item(0)
	atl._item_click(Vector2i(2, 2))
	check(atl.board[Vector2i(2, 2)].id == "sergeant",
		"Atlantis Snow Globe: your pieces cannot be Demoted")
	atl.queue_free()
	await process_frame

	# --- issue 23: payout + strip (45.5 Carat Curse) — no new hook needed ---
	var carat := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "score": 0, "artefacts": ["45-5-carat-curse"]})
	await process_frame
	BuffLogic.add(carat.board[Vector2i(2, 2)], "shield")
	Economy.earn(carat, 100)
	check(carat.gold == 145 and carat.score == 145,
		"45.5 Carat Curse: +45% Gold and Score gain")
	WaveLogic.queue(carat, carat.wave + 1) # Wave 3 clears — every 3rd Wave strips Buffs
	check(BuffLogic.of(carat.board[Vector2i(2, 2)]).is_empty(),
		"45.5 Carat Curse: every 3rd Wave clear strips all allied Piece Buffs")
	carat.queue_free()
	await process_frame

	# --- issue 23: Buff Box choice-count (Numbers Station Sudoku, Bohemian
	# Grove Friendship Bracelet) — a UI change in _open_buff_pick/_buff_chosen,
	# not a REGISTRY hook (issue 18's own held-back note) ---
	var nss := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 20, "artefacts": ["numbers-station-sudoku"]})
	await process_frame
	nss.actions_left = 5
	nss.items.append(_item("buff_box", "tile"))
	nss._use_item(0)
	var nss_box: Node = nss.modals.buff_panel.get_child(0).get_child(0)
	check(nss_box.get_child_count() - 2 == 4, # minus the head label and cancel button
		"Numbers Station Sudoku: the Buff Box offers 4 choices instead of 3")
	nss._buff_chosen("shield")
	check(nss.gold == 20 - 5, "Numbers Station Sudoku: each pick costs 5 Gold")
	nss.queue_free()
	await process_frame

	var bgf := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["bohemian-grove-friendship-bracelet"]})
	await process_frame
	bgf.actions_left = 5
	bgf.items.append(_item("buff_box", "tile"))
	bgf._use_item(0)
	var bgf_box: Node = bgf.modals.buff_panel.get_child(0).get_child(0)
	check(bgf_box.get_child_count() - 2 == 5,
		"Bohemian Grove Friendship Bracelet: the Buff Box offers 5 choices instead of 3")
	bgf.queue_free()
	await process_frame

	# --- issue 25: per-piece capture ledger (split from 19) — game.gd
	# _note_capture, fired from both the player's _move_player capture branch
	# and the enemy's _run_enemy_actions capture branch, plus the three
	# artefacts that read it.
	var ledger_p := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	ledger_p._move_player(Vector2i(2, 2), Vector2i(2, 5))
	check(ledger_p.board[Vector2i(2, 5)].get("captures", 0) == 1
		and ledger_p.board[Vector2i(2, 5)].get("wave_captures", 0) == 1,
		"issue 25: the player's OWN capturing piece gets its ledger bumped (_move_player)")
	ledger_p.queue_free()
	await process_frame

	var ledger_e := _boot({"board": [["pawn", 0, 2, 6], ["rook", 1, 2, 8], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	await ledger_e._run_enemy_actions()
	check(ledger_e.board.has(Vector2i(2, 6)) and ledger_e.board[Vector2i(2, 6)].owner == 1
		and ledger_e.board[Vector2i(2, 6)].get("captures", 0) == 1,
		"issue 25: the enemy's OWN capturing piece gets its ledger bumped too (_run_enemy_actions, no on_capture/scoring)")
	ledger_e.queue_free()
	await process_frame

	# Chupacabra Chew Toy: +2 Gold on Capture, +10 more if the captured piece
	# had captured one of yours (a lifetime captures > 0 on the victim)
	var chup_fresh := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 3], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["chupacabra-chew-toy"]})
	await process_frame
	var chup_base: int = chup_fresh.defs.pawn.value # captures also earn base Gold via Economy.earn
	chup_fresh._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(chup_fresh.gold == chup_base + 2, "Chupacabra Chew Toy: +2 Gold on a Capture of a piece with no capture history")
	chup_fresh.queue_free()
	await process_frame

	var chup_marked := _boot({"board": [["queen", 0, 2, 2],
			["pawn", 1, 2, 3, {"captures": 1}], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["chupacabra-chew-toy"]})
	await process_frame
	var chup_marked_base: int = chup_marked.defs.pawn.value
	chup_marked._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(chup_marked.gold == chup_marked_base + 12,
		"Chupacabra Chew Toy: +10 more Gold when the captured piece had captured one of yours")
	chup_marked.queue_free()
	await process_frame

	# Alien Rocket Toy: on a piece's 3rd (lifetime) Capture, it Ranks Up
	var rocket := _boot({"board": [["pawn", 0, 2, 2, {"captures": 2}], ["pawn", 1, 3, 3], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["alien-rocket-toy"]})
	await process_frame
	rocket._move_player(Vector2i(2, 2), Vector2i(3, 3)) # diagonal: pawns only capture on the diagonal
	check(rocket.board[Vector2i(3, 3)].id == "sergeant" and rocket.board[Vector2i(3, 3)].get("captures", 0) == 3,
		"Alien Rocket Toy: the 3rd Capture Ranks the piece Up (pawn -> sergeant)")
	rocket.queue_free()
	await process_frame

	# Zodiac Crossword Puzzle: On Wave clear, the ally with the most Captures
	# THAT WAVE (not lifetime) gets +1 Piece Buff — resets every Wave
	var zodiac := _boot({"board": [
			["queen", 0, 2, 1, {"wave_captures": 3}], ["pawn", 0, 3, 1, {"wave_captures": 1}],
			["rook", 1, 7, 10]],
		"wave": 4, "artefacts": ["zodiac-crossword-puzzle"]})
	await process_frame
	WaveLogic.queue(zodiac, zodiac.wave + 1)
	check(BuffLogic.of(zodiac.board[Vector2i(2, 1)]).size() == 1,
		"Zodiac Crossword Puzzle: the ally with the most Captures that Wave gets +1 Piece Buff")
	check(BuffLogic.of(zodiac.board[Vector2i(3, 1)]).is_empty(),
		"Zodiac Crossword Puzzle: the ally with fewer Captures that Wave gets nothing")
	check(not zodiac.board[Vector2i(2, 1)].has("wave_captures")
		and not zodiac.board[Vector2i(3, 1)].has("wave_captures"),
		"Zodiac Crossword Puzzle: the Wave-scoped ledger resets for every piece at the next Wave, win or lose")
	zodiac.queue_free()
	await process_frame

	# --- issue 26: spawn roster modifiers (HAARP Volume Knob, Wuhan Vial
	# Label, Pigeon Charging Cable) — on_wave_roster, Trade War's own
	# prerequisite (issue 13), not a new one
	var haarp := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "score": 0, "gold": 0, "artefacts": ["haarp-volume-knob"]})
	await process_frame
	var haarp_base: int = Waves.WAVES[1].size() # wave 2's designed roster
	haarp._queue_wave(2) # clears wave 1 and queues wave 2's roster
	check(haarp.score == 200 and haarp.gold == 15,
		"HAARP Volume Knob: +200 Score and +15 Gold on Wave clear")
	check(haarp.pending_spawn.size() == haarp_base + 1,
		"HAARP Volume Knob: Wave roster spawns +1 extra piece")
	haarp.queue_free()
	await process_frame

	var wuhan := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "gold": 0, "artefacts": ["wuhan-vial-label"]})
	await process_frame
	var wuhan_base: int = Waves.WAVES[1].size()
	wuhan._queue_wave(2)
	check(wuhan.pending_spawn.size() == wuhan_base + 1,
		"Wuhan Vial Label: Wave roster spawns +1 extra piece")
	Economy.capture_score(wuhan, "rook") # base 50
	check(wuhan.gold == roundi(50 * 0.25),
		"Wuhan Vial Label: Captures give +25% more Gold, off the capture's own base")
	wuhan.queue_free()
	await process_frame

	var pigeon := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "artefacts": ["pigeon-charging-cable"]})
	await process_frame
	var pigeon_base: int = Waves.WAVES[1].size()
	pigeon._queue_wave(2)
	check(pigeon.pending_spawn.size() == pigeon_base - 1,
		"Pigeon Charging Cable: Wave roster spawns 1 fewer piece")
	pigeon.queue_free()
	await process_frame

	# --- issue 26: Shop purchase counter + forced-free override
	# (Pre-Scratched Lottery Ticket) ---
	var lottery := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 9, "gold": 99999, "artefacts": ["pre-scratched-lottery-ticket"]})
	await process_frame
	lottery.actions_left = 20
	for i in 4:
		for j in lottery.shop_stock.size():
			if not lottery.shop_stock[j].sold:
				Shop.buy(lottery, j)
				break
	check(lottery.lottery_purchase_count == 4,
		"Pre-Scratched Lottery Ticket: purchase counter increments per Shop purchase")
	var free_idx := -1
	for j in lottery.shop_stock.size():
		if not lottery.shop_stock[j].sold:
			free_idx = j
			break
	check(free_idx >= 0 and Shop.price(lottery, lottery.shop_stock[free_idx]) == 0,
		"Pre-Scratched Lottery Ticket: every 5th Shop purchase is free")
	var gold_before_free: int = lottery.gold
	Shop.buy(lottery, free_idx)
	check(lottery.gold == gold_before_free, "...: the free purchase costs no Gold")
	lottery.queue_free()
	await process_frame

	# --- issue 26: free-deploy (Hitler's Argentinian Passport) ---
	var hitler := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["hitler-s-argentinian-passport"], "stock": ["pawn"], "gold": 100})
	await process_frame
	hitler.state = hitler.State.PLAYER_TURN
	hitler.actions_left = 2
	hitler._place("pawn", Vector2i(4, 2))
	check(hitler.actions_left == 2,
		"Hitler's Argentinian Passport: Deploying doesn't spend an Action")
	hitler.queue_free()
	await process_frame

	# --- issue 26: free deploy placement (Nazca Boarding Pass) — no hook, a
	# standing rule read directly off g.artefacts (game.gd's _deploy_tiles) ---
	var nazca := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["nazca-boarding-pass"]})
	await process_frame
	check(not Rules.placement_tiles(nazca.board).has(Vector2i(0, 8)),
		"(control) Vector2i(0,8) is not normally a legal placement tile")
	check(nazca._deploy_tiles().has(Vector2i(0, 8)),
		"Nazca Boarding Pass: Deploy legality opens to any empty square")
	nazca.queue_free()
	await process_frame

	# --- issue 26: cost exemption (Nuclear Football Menu) — a single call
	# site (_item_apply), also no hook ---
	var nfm := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["nuclear-football-menu"], "clock_s": 30.0})
	await process_frame
	nfm.state = nfm.State.PLAYER_TURN
	nfm.actions_left = 2
	nfm.items.append(_item("counter_intel", ""))
	nfm._use_item(0)
	check(nfm.actions_left == 2,
		"Nuclear Football Menu: Items don't spend an Action while the Clock is under 60s")
	nfm.queue_free()
	await process_frame

	var nfm_control := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["nuclear-football-menu"]})
	await process_frame
	nfm_control.state = nfm_control.State.PLAYER_TURN
	nfm_control.actions_left = 2
	nfm_control.items.append(_item("counter_intel", ""))
	nfm_control._use_item(0)
	check(nfm_control.actions_left == 1,
		"(control) Nuclear Football Menu: Items spend an Action at full Clock")
	nfm_control.queue_free()
	await process_frame

	# --- issue 26: "5-Wave Milestone" grants (Ark's Bunkbed, Trojan Horse
	# Assembly Manual) — on_wave_clear + _milestone5_hit, PER-ARTEFACT
	# (ruled 2026-08-28), silk-road-coupon's cadence, not the GLOBAL 10-wave
	# on_milestone hook. acquired_wave forced to 1 to isolate the handler's
	# own cadence math from the acquisition-stamping coverage below.
	var arkb := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 99999, "artefacts": ["ark-s-bunkbed"]})
	await process_frame
	arkb.artefacts[0].acquired_wave = 1
	arkb.actions_left = 20
	var arkb_idx1 := -1
	for j in arkb.shop_stock.size():
		if arkb.shop_stock[j].kind == "piece":
			arkb_idx1 = j
			break
	var arkb_id1: String = arkb.shop_stock[arkb_idx1].key
	Shop.buy(arkb, arkb_idx1)
	check(arkb.stock.count(arkb_id1) == 2,
		"Ark's Bunkbed: buying a Piece also queues a free duplicate")
	var arkb_idx2 := -1
	for j in arkb.shop_stock.size():
		if arkb.shop_stock[j].kind == "piece" and not arkb.shop_stock[j].sold:
			arkb_idx2 = j
			break
	var arkb_id2: String = arkb.shop_stock[arkb_idx2].key
	Shop.buy(arkb, arkb_idx2)
	check(arkb.stock.count(arkb_id2) == 1,
		"Ark's Bunkbed: no duplicate on a 2nd Piece buy before the next Milestone")
	WaveLogic.queue(arkb, 6) # clears wave 5 -> 5-Wave Milestone: recharges it
	var arkb_idx3 := -1
	for j in arkb.shop_stock.size():
		if arkb.shop_stock[j].kind == "piece" and not arkb.shop_stock[j].sold:
			arkb_idx3 = j
			break
	if arkb_idx3 >= 0:
		var arkb_id3: String = arkb.shop_stock[arkb_idx3].key
		Shop.buy(arkb, arkb_idx3)
		check(arkb.stock.count(arkb_id3) == 2,
			"Ark's Bunkbed: the free duplicate is available again after the Milestone")
	arkb.queue_free()
	await process_frame

	var trojan := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "artefacts": ["trojan-horse-assembly-manual"]})
	await process_frame
	trojan.artefacts[0].acquired_wave = 1
	check(not trojan.box_open, "(control) no Box open before the Wave-5 clear")
	WaveLogic.queue(trojan, 6) # clears wave 5 -> 5-Wave Milestone
	check(trojan.box_open,
		"Trojan Horse Assembly Manual: a free Box opens on a 5-Wave Milestone")
	trojan.queue_free()
	await process_frame

	# --- issue 26: per-Wave first/last-lost tracking (Jon Burrows' Fake ID,
	# Walt's Cryonic Capsule) ---
	var loss := _boot({"board": [["pawn", 0, 2, 2], ["knight", 0, 3, 2], ["bishop", 0, 4, 2],
			["rook", 1, 7, 10]],
		"wave": 4, "artefacts": ["jon-burrows-fake-id", "walt-s-cryonic-capsule"]})
	await process_frame
	loss._lose_player_piece(Vector2i(2, 2), "captured") # first lost: pawn
	loss._lose_player_piece(Vector2i(3, 2), "captured") # middle: knight
	loss._lose_player_piece(Vector2i(4, 2), "captured") # last lost: bishop
	WaveLogic.queue(loss, loss.wave + 1)
	check(loss.stock.has("pawn"),
		"Jon Burrows' Fake ID: the first piece lost this Wave returns to Stock")
	check(loss.stock.has("bishop"),
		"Walt's Cryonic Capsule: the last piece lost this Wave returns to Stock")
	check(not loss.stock.has("knight"),
		"(sanity) the middle loss isn't returned by either artefact")
	loss.queue_free()
	await process_frame

	# --- issue 26: Score-gain streak (27 Club Punch Card); -50 Gold on loss,
	# same issue-16 ruling as Social Credit Report Card ---
	var club27 := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 3, 2], ["rook", 1, 7, 10]],
		"wave": 1, "score": 0, "artefacts": ["27-club-punch-card"]})
	await process_frame
	WaveLogic.queue(club27, 2) # clean Wave-1 clear: streak -> 1
	club27.score = 0
	Economy.earn(club27, 100)
	check(club27.score == 105,
		"27 Club Punch Card: +5% Score gain per consecutive clean Wave (streak 1)")
	WaveLogic.queue(club27, 3) # clean Wave-2 clear: streak -> 2
	club27.score = 0
	Economy.earn(club27, 100)
	check(club27.score == 110,
		"27 Club Punch Card: the streak compounds (streak 2 = +10%)")
	club27.gold = 100
	club27._lose_player_piece(Vector2i(3, 2), "captured")
	check(club27.club27_streak == 0 and club27.gold == 50,
		"27 Club Punch Card: losing a piece resets the streak and debits 50 Gold")
	club27.queue_free()
	await process_frame

	# --- issue 26: Gold reaching exactly 0 (Zero-Point Energy Drink) ---
	var zpe := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 9, "gold": 20, "artefacts": ["zero-point-energy-drink"],
		"tariffs": ["move_cost"]})
	await process_frame
	zpe.actions_left = 3
	var zpe_actions_before: int = zpe.actions_left
	Economy.charge(zpe, "move_cost", 20) # spend exactly down to 0
	check(zpe.gold == 0, "(control) Gold lands exactly on 0")
	check(zpe.actions_left == zpe_actions_before + 2,
		"Zero-Point Energy Drink: +2 Actions when Gold reaches exactly 0")
	zpe.queue_free()
	await process_frame

	# --- issue 26: Gold floor -100 on Shop purchases (Agartha Welcome Mat) ---
	var agartha := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 9, "gold": 0, "artefacts": ["agartha-welcome-mat"]})
	await process_frame
	agartha.actions_left = 5
	var agartha_idx := -1
	for j in agartha.shop_stock.size():
		if agartha.shop_stock[j].kind == "item" and Shop.price(agartha, agartha.shop_stock[j]) <= 100:
			agartha_idx = j
			break
	check(agartha_idx >= 0 and Shop.can_buy(agartha, agartha.shop_stock[agartha_idx]),
		"Agartha Welcome Mat: a purchase is allowed even at 0 Gold (credit line)")
	Shop.buy(agartha, agartha_idx)
	check(agartha.gold < 0 and agartha.gold >= -100,
		"Agartha Welcome Mat: the purchase takes Gold negative, floored at -100")
	agartha.queue_free()
	await process_frame

	var agartha_control := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 9, "gold": 0})
	await process_frame
	agartha_control.actions_left = 5
	var control_idx := -1
	for j in agartha_control.shop_stock.size():
		if agartha_control.shop_stock[j].kind == "item":
			control_idx = j
			break
	check(control_idx >= 0 and not Shop.can_buy(agartha_control, agartha_control.shop_stock[control_idx]),
		"(control) without Agartha Welcome Mat, 0 Gold blocks the same purchase")
	agartha_control.queue_free()
	await process_frame


	print("---")
	if fails == 0:
		print("ALL ARTEFACTS 3 CHECKS OK")
	quit(1 if fails > 0 else 0)
