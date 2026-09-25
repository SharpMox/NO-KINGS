extends SceneTree
## NO-243 S2: the modal and Shop animations (scripts/ui_anim.gd). Every modal
## ends in the layout it has with animations off (same positions, scale 1,
## full alpha); animations off stays instant (nothing hidden, nothing
## created); every fly-to-target ghost frees itself after landing. Whether a
## click lands mid-animation needs GUI picking, so that half lives in the
## windowed tests/test_game_clicks.gd ("NO-243 S2").
## Run headless:  godot --headless --path game -s tests/test_ui_anim.gd

const GameScript := preload("res://scripts/game.gd")
const Scenarios := preload("res://data/scenarios.gd")
const Shop := preload("res://scripts/shop.gd")
const Box := preload("res://scripts/box.gd")
const UiAnim := preload("res://scripts/ui_anim.gd")
const Modals := preload("res://scripts/modals.gd")

const SCENARIO := "Capture: selling sandbox"
const QUEEN := Vector2i(3, 2) # the sandbox's player queen
const SETTLE_S := 0.7 # past every S2 animation (the longest ends by 0.4 s)

var fails := 0


func check(cond: bool, label: String, detail := "") -> void:
	if not cond:
		push_error("FAIL: " + label + (" -- " + detail if detail != "" else ""))
		fails += 1
	else:
		print("ok: " + label)


func _boot() -> Node2D:
	GameScript.reset_boot_defaults()
	var cfg: Dictionary = Scenarios.all()[Scenarios.find(SCENARIO)].cfg.duplicate()
	cfg.seed = 1
	GameScript.next_config = cfg
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	return game


func _settle() -> void:
	await create_timer(SETTLE_S).timeout


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ghosts(game: Node2D) -> Array:
	return game.hud.get_children().filter(func(c: Node) -> bool:
		return c.has_meta(UiAnim.GHOST) and not c.is_queued_for_deletion())


## A modal at rest: full alpha, its content at scale 1.
func _at_rest(panel: Control) -> bool:
	return is_equal_approx(panel.modulate.a, 1.0) \
		and (panel.get_child(0) as Control).scale.is_equal_approx(Vector2.ONE)


func _rects(nodes: Array) -> Array:
	return nodes.map(func(n: Control) -> Rect2: return n.get_global_rect())


func _rects_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if (a[i] as Rect2).position.distance_to((b[i] as Rect2).position) > 0.5 \
				or (a[i] as Rect2).size.distance_to((b[i] as Rect2).size) > 0.5:
			return false
	return true


func _cells_at_rest(nodes: Array) -> bool:
	for n in nodes:
		if not (n as Control).scale.is_equal_approx(Vector2.ONE) or not is_equal_approx((n as Control).modulate.a, 1.0):
			return false
	return true


func _init() -> void:
	await process_frame
	var game := await _boot()
	var m = game.modals
	var hud = game.hud
	var slot: Dictionary = Box.random_slot(game) # one Box, opened both ways

	# --- animations OFF: instant, nothing created ----------------------------
	game.animations_on = false
	hud.toggle_menu(true)
	check(_at_rest(hud.game_menu), "off: the pause menu opens at rest at once")
	hud.toggle_menu(false)
	game._show_preview(game.board[QUEEN].id, "", null, game.board[QUEEN])
	check(_at_rest(m.preview_panel), "off: the preview opens at rest at once")
	m.preview_panel.visible = false
	game.preview_open = false
	game._open_box_pick(slot)
	await _frames(2)
	var off_cells: Array = m._box_cells.duplicate()
	check(_at_rest(m.box_panel) and _cells_at_rest(off_cells), "off: the Box opens at rest, every tile dealt")
	check(not hud.get_children().any(func(c: Node) -> bool: return c.has_meta(&"box_lid")),
		"off: the Box has no lid")
	var off_rects := _rects(off_cells)
	game._box_close()
	m.show_choice_pick("Pick one", [{"label": "A", "value": 1}, {"label": "B", "value": 2}], "Cancel")
	check(_at_rest(m.buff_panel), "off: the choice pick opens at rest at once")
	m.hide_choice_pick()
	m.show_merge_confirm("pawn", "pawn", "pawn")
	check(_at_rest(m.merge_panel), "off: the merge confirm opens at rest at once")
	_button(m.merge_panel, "Cancel").pressed.emit()
	check(not m.merge_panel.visible, "off: Cancel closes the merge confirm at once")
	Shop.roll(game)
	game._open_shop()
	await _frames(2)
	var piece_i := _first_piece(game)
	game._shop_buy(piece_i)
	check(_ghosts(game).is_empty(), "off: a Shop buy flies nothing")
	m.close_shop()
	await _frames(2)

	# --- animations ON: each modal settles in its animations-off layout -------
	game.animations_on = true
	hud.toggle_menu(true)
	check(hud.game_menu.modulate.a < 0.01, "on: the pause menu starts faded out (it animates)")
	await _settle()
	check(_at_rest(hud.game_menu), "on: the pause menu ends at rest (alpha 1, scale 1)")
	hud.toggle_menu(false)

	game._show_preview(game.board[QUEEN].id, "", null, game.board[QUEEN])
	check(m.preview_panel.modulate.a < 0.01, "on: the preview starts faded out")
	await _settle()
	check(_at_rest(m.preview_panel), "on: the preview ends at rest")
	m.preview_panel.visible = false
	game.preview_open = false

	game._open_box_pick(slot)
	check(m.box_panel.modulate.a < 0.01, "on: the Box starts faded out")
	await _frames(2)
	check(hud.get_children().any(func(c: Node) -> bool: return c.has_meta(&"box_lid")),
		"on: the Box's lid is up")
	await _settle()
	var on_cells: Array = m._box_cells.duplicate()
	check(_at_rest(m.box_panel) and _cells_at_rest(on_cells), "on: the Box ends at rest, every tile dealt in")
	check(_rects_equal(_rects(on_cells), off_rects), "on: the Box's tiles land where they sit with animations off",
		"on=%s off=%s" % [_rects(on_cells), off_rects])
	check(not hud.get_children().any(func(c: Node) -> bool: return c.has_meta(&"box_lid")),
		"on: the Box's lid is gone")
	var tile: Button = (on_cells[0] as Control).get_child(0)
	tile.pressed.emit()
	await _settle()
	check(tile.scale.is_equal_approx(Vector2.ONE * Modals.BOX_LIFT), "on: the selected Box tile lifts",
		"scale=%s" % tile.scale)
	var pick: Button = null
	for b in m.box_panel.find_children("*", "Button", true, false):
		if b.has_meta("box_pick"):
			pick = b
	pick.pressed.emit()
	var box_ghosts := _ghosts(game)
	check(box_ghosts.size() == 1, "on: the picked option flies to its drawer tab")
	await _settle()
	check(box_ghosts.all(func(gh) -> bool: return not is_instance_valid(gh)),
		"on: the Box pick's ghost is freed after landing")
	if game.box_open:
		game._box_close()

	m.show_choice_pick("Pick one", [{"label": "A", "value": 1}, {"label": "B", "value": 2}], "Cancel")
	var offers: Array = m.buff_panel.find_children("*", "Button", true, false).filter(
		func(b: Button) -> bool: return b.text == "A" or b.text == "B")
	await _settle()
	check(_at_rest(m.buff_panel) and _cells_at_rest(offers), "on: the choice pick ends at rest, both offers dealt in")
	m.hide_choice_pick()

	m.show_merge_confirm("pawn", "pawn", "pawn")
	await _settle()
	check(_at_rest(m.merge_panel), "on: the merge confirm ends at rest")
	_button(m.merge_panel, "Cancel").pressed.emit()
	check(m.merge_panel.visible and m.merge_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and _button(m.merge_panel, "Merge").mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"on: a cancelled merge fades out input-dead (it can eat no click)")
	await _settle()
	check(not m.merge_panel.visible, "on: the cancelled merge ends hidden")

	# --- the Shop: buy fly + SOLD stamp, restock flip --------------------------
	Shop.roll(game)
	game._open_shop()
	await _settle()
	piece_i = _first_piece(game)
	var stock_n: int = game.stock.size()
	game._shop_buy(piece_i)
	var shop_ghosts := _ghosts(game)
	check(game.stock.size() == stock_n + 1 and shop_ghosts.size() == 1,
		"on: a Shop buy lands the piece and flies its icon to the Stock tab")
	var stamp: Control = m._shop_tiles[piece_i].get_node("SoldStamp")
	check(stamp.scale.x > 1.0, "on: the SOLD stamp slams in from large")
	await _settle()
	check(shop_ghosts.all(func(gh) -> bool: return not is_instance_valid(gh)),
		"on: the Shop buy's ghost is freed after landing")
	check(stamp.scale.is_equal_approx(Vector2.ONE), "on: the SOLD stamp ends at scale 1")
	var off_tiles := _rects(m._shop_tiles)
	Shop.roll(game)
	m.show_shop()
	check((m._shop_tiles[0] as Control).modulate.a < 0.01, "on: a restock hides the tiles to flip them in")
	await _settle()
	var flipped: bool = true
	for t in m._shop_tiles:
		flipped = flipped and (t as Control).scale.is_equal_approx(Vector2.ONE) \
			and is_equal_approx((t as Control).modulate.a, 1.0)
	check(flipped, "on: every restocked tile ends at rest")
	check(_rects_equal(_rects(m._shop_tiles), off_tiles), "on: the restocked tiles land in the Shop's grid")
	m.close_shop()
	await _frames(2)

	game.queue_free()
	await process_frame
	print("---")
	if fails == 0:
		print("ALL UI ANIM CHECKS OK")
	quit(1 if fails > 0 else 0)


func _button(root_node: Node, text: String) -> Button:
	for b in root_node.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


## The first unsold piece slot of the Shop's current roll.
func _first_piece(game: Node2D) -> int:
	for i in game.shop_stock.size():
		if game.shop_stock[i].kind == "piece" and not game.shop_stock[i].sold:
			return i
	return -1
