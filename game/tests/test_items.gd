extends SceneTree
## Item behavior + review-regression coverage (2026-07-03 code review):
## merge-selection survives item removal, ability tariff charges on USE (not
## on targeting), Long-Range tariff covers every riding piece.
## Run headless:  godot --headless --path game -s tests/test_items.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")

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

	print("---")
	if fails == 0:
		print("ALL ITEM CHECKS OK")
	quit(1 if fails > 0 else 0)
