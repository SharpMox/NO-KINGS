extends SceneTree
## Artefacts, part 3: Piece Buff lifecycle hooks (issue 23), the per-piece
## capture ledger (issue 25, its tariff-interception subsection moved to
## test_items_tariffs.gd), the economy/Shop/Box batch (issue 26), and the
## Box Pick flow Artefacts — extra pick + reroll (issue 46).
## Split out of test_items.gd (issue 37).
## Run headless:  godot --headless --path game -s tests/test_items_artefacts_3.gd

const GameScript := preload("res://scripts/game.gd")
const Economy := preload("res://scripts/economy.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const Rules := preload("res://scripts/rules.gd")
const Shop := preload("res://scripts/shop.gd")
const Box := preload("res://scripts/box.gd")
const Items := preload("res://data/items.gd")
const Waves := preload("res://data/waves.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")
const Tuning := preload("res://scripts/tuning.gd")

var fails := 0


## A freshly-rolled Box slot, as Shop.roll would stock it (issue 47) — the
## mechanics tests below (Nostradamus, reroll, box_cost) don't care which
## theme, so they all use "item" for a stable, easy-to-read offer.
func _box_slot(g, theme: String, size: String) -> Dictionary:
	return {"kind": "box", "key": theme, "size": size,
		"contents": Box.roll_options(g, theme, size), "sold": false}


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

	var mrna := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 0, 3, 3], ["pawn", 0, 4, 4],
			["rook", 1, 7, 10]], "wave": 3, "artefacts": ["mrna-firmware-update"]})
	await process_frame
	mrna.actions_left = 5
	# 3 DIFFERENT pieces, one apply each (issue 53: a Piece Buff cap now
	# exists — the same piece taking 3 applies of "shield" would hit it and
	# refuse the 3rd, which is exactly what this loop used to rely on).
	# mrna_apply_count is a run-wide counter either way, so every 3rd apply
	# still Ranks Up whichever piece THAT one landed on.
	for t in [Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 4)]:
		mrna.items.append(_item("buff_box", "tile"))
		mrna._use_item(0)
		mrna._buff_chosen("shield")
		mrna._item_click(t)
	check(mrna.board[Vector2i(4, 4)].id == "sergeant",
		"mRNA Firmware Update: every 3rd Piece Buff you apply also Ranks Up that piece")
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

	# --- issue 61 (was issue 45): Pandemic Toilet Paper Pallet — every 2nd
	# purchase in the same Wave costs 50% less (moved off "Shop visit": the
	# panel can be closed/reopened at will, so that was never a real
	# boundary). Uses a synthetic slot (same style as test_shop.gd's
	# Denazification Visa coverage) so the price math is checked against a
	# known base, independent of the randomized stock.
	var pallet := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 9, "gold": 500, "artefacts": ["pandemic-toilet-paper-pallet"]})
	await process_frame
	var pallet_slot := {"kind": "piece", "key": "queen", "sold": false}
	var pallet_base: int = pallet.defs.queen.value
	check(Shop.price(pallet, pallet_slot) == pallet_base,
		"Pandemic Toilet Paper Pallet: the 1st purchase (counter 0) pays full price")
	check(Shop.price(pallet, pallet_slot) == pallet_base,
		"Pandemic Toilet Paper Pallet: price() is a pure read — calling it again doesn't drift the price")
	ArtefactHooks.run(pallet, "on_purchase", {"kind": "piece", "key": "queen", "price": pallet_base})
	check(pallet.pallet_purchase_count == 1,
		"Pandemic Toilet Paper Pallet: on_purchase counts this Wave's purchases")
	check(Shop.price(pallet, pallet_slot) == roundi(pallet_base * 0.5),
		"Pandemic Toilet Paper Pallet: the 2nd purchase (counter 1) is 50% off")
	# --- issue 61's failing case: closing and reopening the Shop must NOT
	# reset the counter anymore (that was the exploit path for Jet Fuel
	# Vial, and the fragile silent-discard for this card). Closed here at an
	# ODD count (1, discount pending) so a stray reset — which would drop it
	# to 0, an EVEN count with no discount pending — would actually show up
	# in the price, not just in the raw counter. ---
	pallet.actions_left = 5
	pallet._open_shop()
	check(pallet.pallet_purchase_count == 1,
		"Pandemic Toilet Paper Pallet: issue 61 — closing and reopening the Shop no longer resets the counter (a small buff: progress toward the discount now persists within the Wave)")
	check(Shop.price(pallet, pallet_slot) == roundi(pallet_base * 0.5),
		"Pandemic Toilet Paper Pallet: the discount pending before the close is still pending after reopening — a reset would have shown full price here instead")
	ArtefactHooks.run(pallet, "on_purchase", {"kind": "piece", "key": "queen", "price": pallet_base})
	check(Shop.price(pallet, pallet_slot) == pallet_base,
		"Pandemic Toilet Paper Pallet: the 3rd purchase (counter 2, post-reopen) is back to full price — every 2nd, not sticky")
	WaveLogic.queue(pallet, pallet.wave + 1)
	check(pallet.pallet_purchase_count == 0,
		"Pandemic Toilet Paper Pallet: only a Wave boundary resets the counter now")
	pallet.queue_free()
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

	# --- issue 44: Yalta Cocktail Napkin, the choice-modal seam's (issue 41)
	# first real consumer — "On 5-Wave Milestone: choose one — +100 Gold /
	# +1 Item / +15s Clock", same per-artefact _milestone5_hit cadence as
	# silk-road-coupon/ark's-bunkbed/trojan-horse-assembly-manual above ---
	var yalta_gold := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 0, "artefacts": ["yalta-cocktail-napkin"], "clock_s": 100.0})
	await process_frame
	yalta_gold.artefacts[0].acquired_wave = 1
	check(not yalta_gold.buff_pick_open, "(control) no choice pick open before the Wave-5 clear")
	WaveLogic.queue(yalta_gold, 6) # clears wave 5 -> 5-Wave Milestone
	check(yalta_gold.buff_pick_open and yalta_gold.modals.buff_panel != null,
		"Yalta Cocktail Napkin: a 5-Wave Milestone opens the choice-modal seam")
	var yalta_clock_before_wait: float = yalta_gold.clock_ms
	await create_timer(0.2).timeout
	check(yalta_gold.clock_ms < yalta_clock_before_wait,
		"Yalta Cocktail Napkin: the Clock keeps ticking while its Milestone pick is open")
	var yalta_gold_before: int = yalta_gold.gold
	yalta_gold.modals.choice_chosen.emit("gold")
	check(not yalta_gold.buff_pick_open and yalta_gold.gold == yalta_gold_before + 100,
		"Yalta Cocktail Napkin: the 'gold' branch pays +100 Gold through Economy.earn")
	yalta_gold.queue_free()
	await process_frame

	var yalta_item := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "artefacts": ["yalta-cocktail-napkin"]})
	await process_frame
	yalta_item.artefacts[0].acquired_wave = 1
	WaveLogic.queue(yalta_item, 6)
	check(yalta_item.buff_pick_open and yalta_item.items.is_empty(),
		"(setup) the Milestone pick is open, no Items held yet")
	yalta_item.modals.choice_chosen.emit("item")
	check(yalta_item.items.size() == 1 and not yalta_item.buff_pick_open,
		"Yalta Cocktail Napkin: the 'item' branch appends a random entry from Items.ITEMS — the same pool a Box's item roll draws from")
	yalta_item.queue_free()
	await process_frame

	var yalta_clock := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "artefacts": ["yalta-cocktail-napkin"], "clock_s": 100.0})
	await process_frame
	yalta_clock.artefacts[0].acquired_wave = 1
	WaveLogic.queue(yalta_clock, 6)
	var yalta_clock_before_pick: float = yalta_clock.clock_ms
	yalta_clock.modals.choice_chosen.emit("clock")
	check(yalta_clock.clock_ms >= yalta_clock_before_pick + 14500.0 and not yalta_clock.buff_pick_open,
		"Yalta Cocktail Napkin: the 'clock' branch grants +15s through Economy.add_clock")
	yalta_clock.queue_free()
	await process_frame

	var yalta_cancel := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 0, "artefacts": ["yalta-cocktail-napkin"]})
	await process_frame
	yalta_cancel.artefacts[0].acquired_wave = 1
	WaveLogic.queue(yalta_cancel, 6)
	check(yalta_cancel.buff_pick_open, "(setup) the Milestone pick is open")
	yalta_cancel.modals.choice_pick_cancelled.emit()
	check(not yalta_cancel.buff_pick_open and yalta_cancel.gold == 0 and yalta_cancel.items.is_empty(),
		"Yalta Cocktail Napkin: cancelling forfeits the reward — a Milestone isn't a spend, nothing to refund")
	yalta_cancel.queue_free()
	await process_frame

	# per-artefact cadence: two held copies acquired on different Waves fire
	# independently — only the one due copy hits this clear
	var yalta_stagger := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "artefacts": ["yalta-cocktail-napkin", "yalta-cocktail-napkin"]})
	await process_frame
	yalta_stagger.artefacts[0].acquired_wave = 1 # due on this Wave-5 clear
	yalta_stagger.artefacts[1].acquired_wave = 2 # due on Wave 6's clear instead
	WaveLogic.queue(yalta_stagger, 6)
	check(yalta_stagger.buff_pick_open,
		"Yalta Cocktail Napkin: the copy acquired on Wave 1 hits its own Milestone on the Wave-5 clear")
	yalta_stagger.modals.choice_chosen.emit("gold")
	check(not yalta_stagger.buff_pick_open,
		"Yalta Cocktail Napkin: only the one due copy fired — resolving it leaves nothing else pending")
	yalta_stagger.queue_free()
	await process_frame

	# two copies acquired on the SAME Wave both hit the Milestone in the
	# same synchronous on_wave_clear dispatch pass; the second must not
	# clobber the first copy's still-open panel (mirrors trojan-horse-
	# assembly-manual's own `not g.box_open` guard above) — resolving the
	# first pays exactly one reward, not two
	var yalta_double := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 0, "artefacts": ["yalta-cocktail-napkin", "yalta-cocktail-napkin"]})
	await process_frame
	yalta_double.artefacts[0].acquired_wave = 1
	yalta_double.artefacts[1].acquired_wave = 1
	WaveLogic.queue(yalta_double, 6)
	check(yalta_double.buff_pick_open, "(setup) both copies are due; the first opens the modal")
	yalta_double.modals.choice_chosen.emit("gold")
	check(yalta_double.gold == 100 and not yalta_double.buff_pick_open,
		"Yalta Cocktail Napkin: two copies due on the same Wave still pay exactly one reward, not two")
	yalta_double.queue_free()
	await process_frame

	# autoplay resolves the choice itself with rng instead of opening the
	# modal, so the bot never deadlocks on the panel
	var yalta_bot := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 0, "artefacts": ["yalta-cocktail-napkin"]})
	await process_frame
	yalta_bot.artefacts[0].acquired_wave = 1
	yalta_bot.autoplay = true
	WaveLogic.queue(yalta_bot, 6)
	check(not yalta_bot.buff_pick_open,
		"Yalta Cocktail Napkin: autoplay resolves the Milestone pick itself — no modal, no hang")
	yalta_bot.queue_free()
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

	# --- issue 43: economy Artefacts batch (no needs-note) ---

	# Mar-a-Lago Toilet Papers: "On 5-Wave Milestone: a random Shop item
	# becomes free; all other Shop prices +10%". Same seed with/without the
	# artefact held rolls the identical Shop stock (holding it doesn't touch
	# any of Shop.roll's own RNG draws — only Chocolate Key Cake/Alleged
	# Weather Balloon/Sub-Antarctic Visa do that), so a control boot gives an
	# exact "+10%" baseline instead of recomputing Tuning's price table here.
	var mal_control := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 99999})
	await process_frame
	var mal := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 99999, "artefacts": ["mar-a-lago-toilet-papers"]})
	await process_frame
	mal.artefacts[0].acquired_wave = 1 # isolate the cadence math (ark's-bunkbed
		# precedent above) from the acquisition-stamping coverage elsewhere
	check(mal.shop_stock.size() == mal_control.shop_stock.size(),
		"(sanity) same seed rolls the same Shop stock size with/without the artefact held")
	WaveLogic.queue(mal, 6) # clears Wave 5 -> 5-Wave Milestone (per-artefact cadence)
	var mal_free_idx := -1
	for j in mal.shop_stock.size():
		if mal.shop_stock[j].get("free_slot", false):
			mal_free_idx = j
			break
	check(mal_free_idx >= 0, "Mar-a-Lago Toilet Papers: a Shop slot is marked free on the Milestone")
	var mal_price_a := Shop.price(mal, mal.shop_stock[mal_free_idx])
	var mal_price_b := Shop.price(mal, mal.shop_stock[mal_free_idx])
	check(mal_price_a == 0 and mal_price_b == mal_price_a,
		"Mar-a-Lago Toilet Papers: the free slot prices at 0, stable across repeated price() calls")
	var mal_others_plus_10pct := true
	for j in mal.shop_stock.size():
		if j == mal_free_idx:
			continue
		var base_price: int = Shop.price(mal_control, mal_control.shop_stock[j])
		var expected := maxi(roundi(float(base_price) * 1.10), 0)
		if Shop.price(mal, mal.shop_stock[j]) != expected:
			mal_others_plus_10pct = false
	check(mal_others_plus_10pct,
		"Mar-a-Lago Toilet Papers: every other Shop slot prices +10% over its base — the free slot excluded")
	mal.queue_free()
	mal_control.queue_free()
	await process_frame

	# Deep State Yearbook: "On buying an Artefact: each other Artefact you own
	# pays +5 Gold". Shop.buy() appends the bought copy to g.artefacts BEFORE
	# firing on_purchase, so "each OTHER Artefact" is size() - 1 at dispatch
	# time either way (see the handler's own comment).
	var ys := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 99999, "artefacts": ["deep-state-yearbook", "greed"]})
	await process_frame
	ys.actions_left = 5
	var ys_idx := -1
	for j in ys.shop_stock.size():
		if ys.shop_stock[j].kind == "artefact" and not ys.shop_stock[j].sold:
			ys_idx = j
			break
	check(ys_idx >= 0, "(sanity) the rolled Shop stock has a buyable Artefact slot")
	var ys_cost := Shop.price(ys, ys.shop_stock[ys_idx])
	var ys_gold_before: int = ys.gold
	Shop.buy(ys, ys_idx)
	check(ys.gold == ys_gold_before - ys_cost + 10,
		"Deep State Yearbook: buying an Artefact pays +5 Gold for each of the 2 other held Artefacts")
	ys.queue_free()
	await process_frame

	var yself := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 99999})
	await process_frame
	yself.actions_left = 5
	yself.shop_stock[0] = {"kind": "artefact", "key": "deep-state-yearbook", "sold": false}
	check(yself.artefacts.is_empty(), "(sanity) no Artefacts held before the purchase")
	var yself_cost := Shop.price(yself, yself.shop_stock[0])
	var yself_gold_before: int = yself.gold
	Shop.buy(yself, 0)
	check(yself.gold == yself_gold_before - yself_cost,
		"Deep State Yearbook: pays nothing when it is your only Artefact (buying its own first copy)")
	yself.queue_free()
	await process_frame

	# --- issue 46/47: Box Pick flow Artefacts — Nostradamus Mad Libs (+1 extra
	# pick, from the same offer), Bible Gag Reel Scroll + Snowden's Rubik's
	# Cube (functionally identical: 1 reroll each, stacking additively), and
	# Huge's own native 2-picks-per-Box (issue 47) stacking with Nostradamus
	# on top. Small Boxes (3 choices, 1 native pick) isolate the issue-46
	# mechanics from the issue-47 size dimension; a dedicated Huge case below
	# proves the "Huge + Nostradamus = 3 picks" spec example.

	# Nostradamus Mad Libs: 1 copy takes 2 of the 3 offered options, picking
	# the same box_offer[0] each round so the count is deterministic
	# regardless of which kind rolls into that slot.
	var mad1 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 500, "artefacts": ["nostradamus-mad-libs"]})
	await process_frame
	mad1._open_box_pick(_box_slot(mad1, "item", "small"))
	check(mad1.box_open and mad1.box_offer.size() == 3, "(setup) the Box opens with a 3-option offer")
	var mad1_picks := 0
	while mad1.box_open:
		mad1._box_choose(mad1.box_offer[0])
		mad1_picks += 1
	check(mad1_picks == 2, "Nostradamus Mad Libs: 1 copy banks 2 rewards (the base pick + 1 extra)")
	mad1.queue_free()
	await process_frame

	# 2 copies = 3 picks, i.e. the whole offer — stops when it's exhausted,
	# not capped below that for its own sake.
	var mad2 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 500, "artefacts": ["nostradamus-mad-libs", "nostradamus-mad-libs"]})
	await process_frame
	mad2._open_box_pick(_box_slot(mad2, "item", "small"))
	var mad2_picks := 0
	while mad2.box_open:
		mad2._box_choose(mad2.box_offer[0])
		mad2_picks += 1
	check(mad2_picks == 3, "Nostradamus Mad Libs: 2 held copies take the whole offer (3 picks), no further cap")
	mad2.queue_free()
	await process_frame

	# Bible Gag Reel Scroll + Snowden's Rubik's Cube: both hold "1 reroll",
	# stack additively (holding one of each, same as 2 copies of either), a
	# reroll replaces the offer wholesale, and — the trap this slice exists
	# for — box_cost is charged exactly once across a Box with rerolls,
	# never re-charged by _box_reroll.
	var rr := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 100, "tariffs": ["box_cost"],
		"artefacts": ["bible-gag-reel-scroll", "snowden-s-rubik-s-cube"]})
	await process_frame
	var rr_gold_before: int = rr.gold
	rr._open_box_pick(_box_slot(rr, "item", "small"))
	check(rr.gold == rr_gold_before - 10,
		"box_cost charges once on Box open (Mild tariff, 10 Gold — Tuning.TARIFF_ACTION_COST)")
	check(rr.box_rerolls_left == 2,
		"Bible Gag Reel Scroll + Snowden's Rubik's Cube: 1 reroll each, stacking to 2")
	var rr_offer_before: Array = rr.box_offer.duplicate(true)
	rr._box_reroll()
	check(rr.box_rerolls_left == 1, "a reroll spends one charge from the budget")
	check(rr.box_offer != rr_offer_before, "a reroll replaces the offer")
	check(rr.gold == rr_gold_before - 10,
		"a reroll does NOT re-charge box_cost (the trap this slice exists for)")
	rr._box_reroll()
	check(rr.box_rerolls_left == 0, "the second reroll spends the second stacked charge")
	check(rr.gold == rr_gold_before - 10,
		"...still exactly one box_cost charge across both rerolls")
	rr.queue_free()
	await process_frame

	# two copies of the SAME key stack the same way as one of each
	var two_snow := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 500, "artefacts": ["snowden-s-rubik-s-cube", "snowden-s-rubik-s-cube"]})
	await process_frame
	two_snow._open_box_pick(_box_slot(two_snow, "item", "small"))
	check(two_snow.box_rerolls_left == 2,
		"two copies of Snowden's Rubik's Cube alone also stack to 2 rerolls")
	two_snow.queue_free()
	await process_frame

	# the reroll budget is per-Box and does not leak into the next one
	var leak := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 500, "artefacts": ["snowden-s-rubik-s-cube"]})
	await process_frame
	leak._open_box_pick(_box_slot(leak, "item", "small"))
	leak._box_reroll()
	check(leak.box_rerolls_left == 0, "(setup) the budget is spent on this Box")
	leak._box_choose(leak.box_offer[0])
	check(not leak.box_open, "(setup) the Box resolved")
	leak._open_box_pick(_box_slot(leak, "item", "small"))
	check(leak.box_rerolls_left == 1, "the reroll budget resets fresh on the next Box — no leak from the last one")
	leak.queue_free()
	await process_frame

	# a reroll respects the theme pin for the life of the Box (issue 47:
	# every Box is typed, so this is every Box, not a special "typed" case)
	var typed := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 500, "artefacts": ["snowden-s-rubik-s-cube"]})
	await process_frame
	typed._open_box_pick(_box_slot(typed, "item", "small"))
	typed._box_reroll()
	var typed_all_items := true
	for o in typed.box_offer:
		if o.kind != "item":
			typed_all_items = false
	check(typed_all_items, "Reroll re-rolls within the same theme as the Box it belongs to")
	typed.queue_free()
	await process_frame

	# Huge grants 2 native picks (issue 47) — Nostradamus stacks ON TOP, so
	# Huge + 1 held copy = 3 total picks (the spec's own worked example)
	var huge := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 500, "artefacts": ["nostradamus-mad-libs"]})
	await process_frame
	huge._open_box_pick(_box_slot(huge, "item", "huge"))
	check(huge.box_picks_left == 2, "Huge (2 native) + 1 Nostradamus copy = 2 extra picks beyond the first")
	var huge_picks := 0
	while huge.box_open:
		huge._box_choose(huge.box_offer[0])
		huge_picks += 1
	check(huge_picks == 3, "Huge + Nostradamus Mad Libs = 3 picks total (spec example, issue 47)")
	huge.queue_free()
	await process_frame

	# autoplay: both new paths must stay inside _open_box_pick's autoplay
	# branch or the bot deadlocks on a modal nobody is there to click.
	# box_picks_left/box_rerolls_left aren't reset until the next Box opens,
	# so a value below the seeded starting point after resolution proves the
	# branch actually ran (not just "didn't hang").
	var extra_pick_branch_hit := false
	for s in range(1, 9):
		var mb := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
			"wave": 3, "gold": 500, "artefacts": ["nostradamus-mad-libs", "nostradamus-mad-libs"], "seed": s})
		await process_frame
		mb.autoplay = true
		mb._open_box_pick(_box_slot(mb, "item", "small"))
		check(not mb.box_open, "autoplay (seed %d) resolves the Box itself — no modal, no hang" % s)
		if mb.box_picks_left < 2:
			extra_pick_branch_hit = true
		mb.queue_free()
		await process_frame
	check(extra_pick_branch_hit,
		"Nostradamus Mad Libs: autoplay exercises the extra-pick recursion itself, not just under the modal")

	var reroll_branch_hit := false
	for s in range(1, 16):
		var rb := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
			"wave": 3, "gold": 500, "artefacts": ["snowden-s-rubik-s-cube"], "seed": s})
		await process_frame
		rb.autoplay = true
		rb._open_box_pick(_box_slot(rb, "item", "small"))
		check(not rb.box_open, "autoplay (seed %d) resolves the Box itself — no modal, no hang" % s)
		if rb.box_rerolls_left == 0:
			reroll_branch_hit = true
		rb.queue_free()
		await process_frame
	check(reroll_branch_hit,
		"Snowden's Rubik's Cube: autoplay exercises the reroll branch itself, not just under the modal")

	# autoplay + Huge (issue 47): the bot must resolve a Huge Box's 2 native
	# picks (no Nostradamus needed) without a modal too — the exact edge the
	# issue's "Autoplay must resolve every Box path" acceptance test calls out
	for s in range(1, 9):
		var hb := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
			"wave": 3, "gold": 500, "seed": s})
		await process_frame
		hb.autoplay = true
		hb._open_box_pick(_box_slot(hb, "item", "huge"))
		check(not hb.box_open, "autoplay (seed %d) resolves a Huge Box's 2 native picks — no modal, no hang" % s)
		hb.queue_free()
		await process_frame

	# --- issue 49: the four Box-dependent Artefacts (needs Box 47) ---

	# Loch Ness Stool Sample: a run-long cumulative "Score GAINED" tracker,
	# never the running (spendable) g.score — crossing each 1000 opens a
	# random Piece Box. `not g.box_open` mirrors Trojan Horse Assembly
	# Manual's own guard, so this drives Economy.earn directly rather than
	# through a real capture (isolates the threshold math from board setup).
	var loch := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["loch-ness-stool-sample"]})
	await process_frame
	check(not loch.box_open, "(setup) no Box open yet")
	Economy.earn(loch, 999)
	check(not loch.box_open and loch.score_gained_total == 999,
		"Loch Ness Stool Sample: 999 Score gained does not yet cross the 1000 threshold")
	Economy.earn(loch, 1)
	check(loch.box_open and loch.box_only_kind == "piece",
		"Loch Ness Stool Sample: crossing 1000 Score gained opens a random Piece Box")
	loch._box_close() # free the guard so the next earn() can trigger again
	# "gained, not current": spending Score (Templar Debit Card pays Shop
	# purchases 10 Score : 1 Gold via a direct g.score -=, bypassing
	# Economy.earn entirely) must not touch the tracker or re-trigger.
	loch.score -= 500 # simulate that spend directly, same as shop.gd:280
	check(loch.score_gained_total == 1000,
		"...and spending Score afterward leaves the GAINED tracker untouched")
	Economy.earn(loch, 999) # gained now 1999 — still short of the next 2000
	check(not loch.box_open, "...999 more gained (net of the spend) does not re-cross a threshold")
	Economy.earn(loch, 1) # gained now 2000
	check(loch.box_open, "...the SAME real threshold (2000) still fires once actually reached")
	loch.queue_free()
	await process_frame

	# Cicada Rejection Letter: valuation is the Shop base-price formula for
	# EACH content kind, summed over whatever is still in box_offer at the
	# moment of decline (the full offer here — nothing picked first), on top
	# of the existing flat BOX_SKIP_CONSOLATION. Computed independently of
	# Box.content_value (the function under test) from raw catalog data, so
	# this is a real correctness check, not a tautology.
	var cic_piece := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["cicada-rejection-letter"]})
	await process_frame
	cic_piece._open_box_pick(_box_slot(cic_piece, "piece", "small"))
	var expect_piece := 0
	for opt in cic_piece.box_offer:
		expect_piece += int(cic_piece.defs[opt.payload].value)
	cic_piece._on_box_skipped()
	check(cic_piece.gold == Tuning.BOX_SKIP_CONSOLATION + expect_piece,
		"Cicada Rejection Letter: declining a Piece Box pays g.defs[id].value per piece, on top of the flat consolation")
	cic_piece.queue_free()
	await process_frame

	var cic_item := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["cicada-rejection-letter"]})
	await process_frame
	cic_item._open_box_pick(_box_slot(cic_item, "item", "small"))
	var expect_item := 0
	for opt in cic_item.box_offer:
		expect_item += int(Tuning.SHOP_ITEM_PRICE[opt.payload.tier])
	cic_item._on_box_skipped()
	check(cic_item.gold == Tuning.BOX_SKIP_CONSOLATION + expect_item,
		"Cicada Rejection Letter: declining an Item Box pays Tuning.SHOP_ITEM_PRICE[tier] per item")
	cic_item.queue_free()
	await process_frame

	# Huge (7 choices) proves the payout scales with size — intended, not a
	# bug (issue 49) — and covers the artefact-kind valuation at the same time.
	var cic_artefact := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["cicada-rejection-letter"]})
	await process_frame
	cic_artefact._open_box_pick(_box_slot(cic_artefact, "artefact", "huge"))
	check(cic_artefact.box_offer.size() == 7, "(setup) Huge Box declines 7 contents")
	var expect_artefact := 0
	for opt in cic_artefact.box_offer:
		var rarity: String = str(opt.payload.get("rarity", ""))
		expect_artefact += int(Tuning.SHOP_ARTEFACT_PRICE.get(rarity, Tuning.SHOP_ARTEFACT_PRICE[""]))
	cic_artefact._on_box_skipped()
	check(cic_artefact.gold == Tuning.BOX_SKIP_CONSOLATION + expect_artefact,
		"Cicada Rejection Letter: declining a Huge Artefact Box pays Tuning.SHOP_ARTEFACT_PRICE[rarity] per artefact, scaled to all 7")
	cic_artefact.queue_free()
	await process_frame

	# Epstein's Black Book: NOT consumed by a Box's own native picks, spent
	# only the moment a pick exceeds that entitlement — then takes everything
	# that's left. Big (native 1 pick, 5 choices) matches the catalog's
	# original "all 5 contents" wording exactly.
	var bb1 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["epstein-s-black-book"]})
	await process_frame
	bb1._open_box_pick(_box_slot(bb1, "item", "big"))
	bb1._box_choose(bb1.box_offer[0]) # the Box's own normal 1 pick
	check(bb1._artefact_count("epstein-s-black-book") == 1,
		"Epstein's Black Book: NOT consumed by a Big Box's normal 1 pick")
	check(bb1.box_open, "...it offers one more free look instead of closing")
	bb1._on_box_skipped() # decline that look
	check(bb1._artefact_count("epstein-s-black-book") == 1 and not bb1.box_open,
		"...declining the free look leaves it untouched (\"it waits\") and closes the Box normally")
	bb1.queue_free()
	await process_frame

	var bb2 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["epstein-s-black-book"]})
	await process_frame
	bb2._open_box_pick(_box_slot(bb2, "item", "big"))
	bb2._box_choose(bb2.box_offer[0]) # pick 1 — native, not consumed
	check(bb2._artefact_count("epstein-s-black-book") == 1, "(setup) not consumed after the native pick")
	bb2._box_choose(bb2.box_offer[0]) # pick 2 — the FIRST excess pick
	check(bb2._artefact_count("epstein-s-black-book") == 0,
		"Epstein's Black Book: consumed exactly on the first pick beyond entitlement")
	var bb2_picks := 2
	while bb2.box_open:
		bb2._box_choose(bb2.box_offer[0])
		bb2_picks += 1
	check(bb2_picks == 5, "...and then takes every remaining content — all 5, Big's full offer")
	bb2.queue_free()
	await process_frame

	# Composition with Nostradamus Mad Libs (issue 46): entitlement is native
	# + Nostradamus TOGETHER, so Black Book only spends beyond BOTH — the
	# reading issue 49 asked to be documented and tested explicitly.
	var bb3 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["epstein-s-black-book", "nostradamus-mad-libs"]})
	await process_frame
	bb3._open_box_pick(_box_slot(bb3, "item", "big")) # native 1 + Nostradamus 1 = 2 entitled
	bb3._box_choose(bb3.box_offer[0]) # pick 1 — native
	bb3._box_choose(bb3.box_offer[0]) # pick 2 — the Nostradamus-granted pick, STILL entitled
	check(bb3._artefact_count("epstein-s-black-book") == 1,
		"Epstein's Black Book + Nostradamus Mad Libs: not consumed while still within THEIR combined entitlement")
	bb3._box_choose(bb3.box_offer[0]) # pick 3 — beyond native+Nostradamus together
	check(bb3._artefact_count("epstein-s-black-book") == 0,
		"...consumed only once picks exceed everything else already entitled to (native + Nostradamus)")
	bb3.queue_free()
	await process_frame

	# autoplay must resolve Black Book's bonus-round branch too, no modal.
	var bb_auto_hit := false
	for s in range(1, 9):
		var ab := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
			"wave": 3, "gold": 0, "artefacts": ["epstein-s-black-book"], "seed": s})
		await process_frame
		ab.autoplay = true
		ab._open_box_pick(_box_slot(ab, "item", "big"))
		check(not ab.box_open, "autoplay (seed %d) resolves Epstein's Black Book's bonus round — no modal, no hang" % s)
		if ab._artefact_count("epstein-s-black-book") == 0:
			bb_auto_hit = true
		ab.queue_free()
		await process_frame
	check(bb_auto_hit, "Epstein's Black Book: autoplay exercises the consume-on-excess-pick branch itself")

	# All-Seeing Eye Contact Lens: the reveal is read straight off the same
	# pre-rolled `contents` issue 47 already stores on the slot, so it must
	# equal exactly what opening the Box actually yields — the acceptance
	# test the issue calls out by name.
	var eye := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["all-seeing-eye-contact-lens"]})
	await process_frame
	var eye_slot := _box_slot(eye, "artefact", "huge")
	var revealed := Box.contents_names(eye_slot.contents)
	eye._open_box_pick(eye_slot)
	check(eye.box_offer.size() == 7, "(setup) Huge Box has 7 entries")
	check(Box.contents_names(eye.box_offer) == revealed,
		"All-Seeing Eye Contact Lens: revealed contents equal exactly what the Box yields on open")
	eye.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL ARTEFACTS 3 CHECKS OK")
	quit(1 if fails > 0 else 0)
