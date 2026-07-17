extends SceneTree
## Item behavior + review-regression coverage (2026-07-03 code review):
## merge-selection survives item removal, ability tariff charges on USE (not
## on targeting), Long-Range tariff covers every riding piece.
## Run headless:  godot --headless --path game -s tests/test_items.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Economy := preload("res://scripts/economy.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const MergeLogic := preload("res://scripts/merge_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _boot(cfg: Dictionary) -> Node2D:
	GameScript.next_config = cfg
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _item(key: String, target: String) -> Dictionary:
	return {"key": key, "name": key, "tier": "T", "target": target, "description": ""}


func _init() -> void:
	# --- review bug 1 (reworked for buttonless merging): removing a selected
	# piece with an item must drop the selection, not leave a stale board ref
	var a := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 0, 3, 2], ["rook", 1, 7, 10]],
		"wave": 3})
	await process_frame
	a._on_tile_clicked(Vector2i(2, 2)) # select the board pawn (partner glows)
	check(a.merge_highlights.has("pawn"), "selection highlights its merge partner")
	a.items.append(_item("asset_recovery", "tile"))
	a._use_item(0)
	a._item_click(Vector2i(2, 2)) # duplicate the selected pawn into stock
	check(a.selected == Vector2i(-1, -1), "item use clears the selection")
	a._refresh() # would error on a stale board ref
	check(a.stock.has("pawn") and a.board.has(Vector2i(2, 2)),
		"asset recovery copies the board piece into stock")
	# tap-merge: select the remaining board pawn, tap the stock pawn's partner…
	# the pool side is covered in the click probe; here merge the pool pair back
	check(a.merge_highlights.is_empty(), "no selection, no merge highlights")
	a.queue_free()
	await process_frame

	# --- review bug 4: ability tariff charges when the item is USED, once —
	# cancelling a targeted item costs nothing
	var b := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "score": 500, "tariffs": ["ability_cost"]})
	await process_frame
	b.money = 500 # tariffs charge money now (money-and-shop/02)
	b.items.append(_item("demote", "tile"))
	b._use_item(0) # start targeting
	b._use_item(0) # tap again: cancel
	check(b.money == 500, "cancelled item charges no ability tariff")
	b._use_item(0)
	b._item_click(Vector2i(2, 2)) # complete the use
	check(b.money == 500 - Tuning.TARIFF_ACTION_COST,
		"completed item charges the ability tariff once")
	b.queue_free()
	await process_frame

	# --- review bug 3: Long-Range tariff covers every rider, not just
	# bishop/rook; leapers stay exempt
	var c := _boot({"board": [["queen", 0, 2, 2], ["knight", 0, 5, 2], ["rook", 1, 7, 10]],
		"wave": 3, "score": 500, "tariffs": ["long_range_cost"]})
	await process_frame
	c.money = 500
	c._move_player(Vector2i(2, 2), Vector2i(2, 5)) # queen rides 3 squares
	check(c.money == 500 - 3 * Tuning.TARIFF_LR_PER_SQUARE,
		"riding 3 squares charges 3x the long-range tariff")
	var money_after: int = c.money
	c._move_player(Vector2i(5, 2), Vector2i(6, 4)) # knight leap
	check(c.money == money_after, "leaps stay exempt from the long-range tariff")
	c.queue_free()
	await process_frame

	# --- promote: advances a piece with a next tier, no-op target otherwise
	var d := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	d.items.append(_item("promote", "tile"))
	d._use_item(0)
	d._item_click(Vector2i(2, 2))
	check(d.board[Vector2i(2, 2)].id == "sergeant", "promote advances a pawn to its next tier")
	d.queue_free()
	await process_frame

	# --- invert: swaps a piece for its inv- counterpart when one is defined
	var e := _boot({"board": [["sergeant", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	e.items.append(_item("invert", "tile"))
	e._use_item(0)
	e._item_click(Vector2i(2, 2))
	check(e.board[Vector2i(2, 2)].id == "inv-sergeant", "invert swaps a piece for its inv- counterpart")
	e.queue_free()
	await process_frame

	# --- rapid deployment: ally piece -> a Deploy tile only (zone rows or
	# tiles touching an ally — Rules.placement_tiles; Notion KEEP desc)
	var f := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	f.items.append(_item("rapid_deployment", "pair"))
	f._use_item(0)
	f._item_click(Vector2i(2, 2)) # stage A: pick the queen
	check(not f.item_targets.has(Vector2i(6, 9)),
		"a far empty tile is not a deploy tile")
	check(f.item_targets.has(Vector2i(0, 0)), "zone tiles are deploy tiles")
	check(f.item_targets.has(Vector2i(3, 3)),
		"tiles touching an ally are deploy tiles")
	f._item_click(Vector2i(0, 0))
	check(f.board.has(Vector2i(0, 0)) and not f.board.has(Vector2i(2, 2)),
		"rapid deployment moves the piece")
	f.queue_free()
	await process_frame

	# --- radar jamming: strips the buff from a buffed piece; only buffed
	# pieces are valid targets
	var h := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 5, "buff"],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	h.items.append(_item("radar_jamming", "tile"))
	h._use_item(0)
	check(h.item_targets.size() == 1 and h.item_targets.has(Vector2i(3, 5)),
		"radar jamming targets only buffed pieces")
	h._item_click(Vector2i(3, 5))
	check(not h.board[Vector2i(3, 5)].get("buff", false),
		"radar jamming strips the buff")
	h.queue_free()
	await process_frame

	# --- counter-intel: suppresses action tariffs for the rest of the wave
	var ci := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "tariffs": ["move_cost"]})
	await process_frame
	ci.money = 500
	ci.items.append(_item("counter_intel", ""))
	ci._use_item(0)
	ci._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(ci.money == 500, "counter-intel suppresses the move tariff")
	ci.queue_free()
	await process_frame

	# --- counter-intel: persistent tariffs pause too; the next wave's spawn
	# ends the suppression (CONTEXT.md: Tariff suppression)
	var cj := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "tariffs": ["move_cost", "inflation"]})
	await process_frame
	cj.money = 500
	cj.items.append(_item("counter_intel", ""))
	cj._use_item(0)
	Economy.earn(cj, 10)
	check(cj.money == 510, "suppressed inflation taxes no gains")
	cj._refresh()
	check(cj.hud.tariff_button.text.ends_with("·off"), "HUD marks tariffs suppressed")
	WaveLogic.spawn(cj, 4)
	Economy.earn(cj, 10)
	check(cj.money == 519, "next wave spawn ends the suppression (inflation resumes)")
	cj._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(cj.money == 519 - Tuning.TARIFF_ACTION_COST,
		"next wave spawn ends the suppression (move tariff resumes)")
	cj.queue_free()
	await process_frame

	# --- drone strike: 3x3 destruction around the confirmed anchor; the King
	# survives; destruction is not capture (CONTEXT.md: Destruction)
	var ds := _boot({"board": [["queen", 0, 0, 1], ["pawn", 1, 3, 5], ["bishop", 1, 2, 4],
		["pawn", 0, 4, 6], ["king", 1, 3, 4], ["rook", 1, 7, 10]],
		"wave": 3, "trinkets": ["greed", "score"], "score": 100})
	await process_frame
	ds.money = 100
	ds.items.append(_item("drone_strike", "area"))
	ds._use_item(0)
	ds._item_click(Vector2i(3, 5)) # anchor: preview only, not spent yet
	check(not ds.items.is_empty(), "area anchor tap previews without spending")
	ds._item_click(Vector2i(3, 5)) # confirm
	check(not ds.board.has(Vector2i(3, 5)) and not ds.board.has(Vector2i(2, 4))
		and not ds.board.has(Vector2i(4, 6)), "drone strike clears the 3x3 (ally included)")
	check(ds.board.has(Vector2i(3, 4)), "the King survives a drone strike")
	check(ds.board.has(Vector2i(7, 10)), "pieces outside the 3x3 survive")
	check(ds.score == 100 and ds.money == 100, "destruction pays no score, money, or trinket procs")
	ds.queue_free()
	await process_frame

	# --- drone strike: corner anchors hang off the board; re-anchor + cancel
	var de := _boot({"board": [["queen", 0, 5, 5], ["pawn", 1, 0, 0], ["pawn", 1, 1, 1],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	de.items.append(_item("drone_strike", "area"))
	de._use_item(0)
	de._item_click(Vector2i(0, 0))
	check(de.item_targets.size() == 4, "corner preview covers only the on-board 2x2")
	de._item_click(Vector2i(5, 5)) # far tap re-anchors instead of confirming
	check(de.items.size() == 1 and de.item_targets.has(Vector2i(4, 4)),
		"far tap re-anchors the preview")
	de._use_item(0) # tap the armed item: cancel, unspent
	check(de.items.size() == 1 and de.item_active == -1, "area cancel leaves the item unspent")
	de._use_item(0)
	de._item_click(Vector2i(0, 0))
	de._item_click(Vector2i(0, 0)) # confirm at the corner
	check(not de.board.has(Vector2i(0, 0)) and not de.board.has(Vector2i(1, 1)),
		"corner strike destroys the on-board part")
	de.queue_free()
	await process_frame

	# --- extraction: multi-select own pieces back to Stock at current identity
	var ex := _boot({"board": [["dragon-king", 0, 2, 2], ["pawn", 0, 3, 3],
		["queen", 0, 5, 5], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	ex.items.append(_item("extraction", "multi"))
	ex._use_item(0)
	check(ex.item_targets.size() == 3 and not ex.item_targets.has(Vector2i(7, 10)),
		"extraction targets only own pieces")
	ex._item_confirm_multi()
	check(ex.items.size() == 1, "zero-selection confirm is a no-op")
	ex._item_click(Vector2i(2, 2))
	ex._item_click(Vector2i(3, 3))
	ex._item_click(Vector2i(3, 3)) # toggle the pawn back off
	check(ex.item_selected == [Vector2i(2, 2)], "taps toggle the selection")
	ex._use_item(0) # tap the armed item: cancel, unspent, board untouched
	check(ex.items.size() == 1 and ex.item_selected.is_empty()
		and ex.board.has(Vector2i(2, 2)), "cancel leaves the item unspent")
	ex._use_item(0)
	ex._item_click(Vector2i(2, 2))
	ex._item_click(Vector2i(3, 3))
	ex._item_confirm_multi()
	check(ex.items.is_empty() and ex.stock.has("dragon-king") and ex.stock.has("pawn")
		and not ex.board.has(Vector2i(2, 2)) and not ex.board.has(Vector2i(3, 3)),
		"confirm returns the selection to Stock at current identity")
	check(ex.board.has(Vector2i(5, 5)), "unselected pieces stay on the board")
	ex.queue_free()
	await process_frame

	# --- extraction: piece state rides along opaquely; stateful copies stack
	# apart; placement restores; merging discards (ADR-0002)
	var ez := _boot({"board": [["knight", 0, 2, 2, "buff"], ["knight", 0, 4, 2],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	ez.actions_left = 5
	ez.actions_max = 5
	ez.items.append(_item("extraction", "multi"))
	ez._use_item(0)
	ez._item_click(Vector2i(2, 2))
	ez._item_click(Vector2i(4, 2))
	ez._item_confirm_multi()
	var stateful := {"id": "knight", "buff": true}
	check(ez.stock.has(stateful) and ez.stock.has("knight"),
		"state rides into Stock; the plain copy stays a bare id")
	check(ez.hud._stacks().size() == 2, "a stateful copy stacks apart from plain ones")
	ez._place(stateful, Vector2i(3, 6))
	check(ez.board[Vector2i(3, 6)].get("buff", false), "placement restores the state")
	check(not ez.stock.has(stateful) and ez.stock.has("knight"),
		"placement consumed the stateful entry, not the plain one")
	ez.queue_free()
	await process_frame

	# --- merge: a stateful entry is a normal merge input — consumed exactly,
	# state discarded, result is the plain next piece
	var em := _boot({"board": [["rook", 1, 7, 10]], "wave": 3, "stock": ["pawn"]})
	await process_frame
	em.stock.append({"id": "pawn", "buff": true})
	em.actions_left = 3
	MergeLogic.commit_merge(em,
		{"id": "pawn", "cap": false, "entry": {"id": "pawn", "buff": true}},
		{"id": "pawn", "cap": false, "entry": "pawn"})
	check(em.stock == ["sergeant"], "merging a stateful entry consumes it and discards the state")
	em.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL ITEM CHECKS OK")
	quit(1 if fails > 0 else 0)
