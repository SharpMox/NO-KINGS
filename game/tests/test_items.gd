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
	var a := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 0, 3, 2], ["rook", 1, 7, 12]],
		"wave": 3})
	await process_frame
	a._on_tile_clicked(Vector2i(2, 2)) # select the board pawn (partner glows)
	check(a.merge_highlights.has("pawn"), "selection highlights its merge partner")
	a.items.append(_item("extraction", "tile"))
	a._use_item(0)
	a._item_click(Vector2i(2, 2)) # extract the selected pawn off the board
	check(a.selected == Vector2i(-1, -1), "item use clears the selection")
	a._refresh() # would error on a stale board ref
	check(a.stock.has("pawn"), "extraction still lands the piece in stock")
	# tap-merge: select the remaining board pawn, tap the stock pawn's partner…
	# the pool side is covered in the click probe; here merge the pool pair back
	check(a.merge_highlights.is_empty(), "no selection, no merge highlights")
	a.queue_free()
	await process_frame

	# --- review bug 4: ability tariff charges when the item is USED, once —
	# cancelling a targeted item costs nothing
	var b := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 12]],
		"wave": 3, "score": 500, "tariffs": ["ability_cost"]})
	await process_frame
	b.items.append(_item("extraction", "tile"))
	b._use_item(0) # start targeting
	b._use_item(0) # tap again: cancel
	check(b.score == 500, "cancelled item charges no ability tariff")
	b._use_item(0)
	b._item_click(Vector2i(2, 2)) # complete the use
	check(b.score == 500 - Tuning.TARIFF_ACTION_COST,
		"completed item charges the ability tariff once")
	b.queue_free()
	await process_frame

	# --- review bug 3: Long-Range tariff covers every rider, not just
	# bishop/rook; leapers stay exempt
	var c := _boot({"board": [["queen", 0, 2, 2], ["knight", 0, 5, 2], ["rook", 1, 7, 12]],
		"wave": 3, "score": 500, "tariffs": ["long_range_cost"]})
	await process_frame
	c._move_player(Vector2i(2, 2), Vector2i(2, 5)) # queen rides 3 squares
	check(c.score == 500 - 3 * Tuning.TARIFF_LR_PER_SQUARE,
		"riding 3 squares charges 3x the long-range tariff")
	var score_after: int = c.score
	c._move_player(Vector2i(5, 2), Vector2i(6, 4)) # knight leap
	check(c.score == score_after, "leaps stay exempt from the long-range tariff")
	c.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL ITEM CHECKS OK")
	quit(1 if fails > 0 else 0)
