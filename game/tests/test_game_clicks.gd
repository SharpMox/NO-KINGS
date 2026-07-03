extends SceneTree
## In-game HUD click probe: boots the Game scene from a config and injects
## synthetic clicks — PASS ends the turn, Merge toggles, pool buttons select,
## board tiles respond, the box-pick modal blocks and resolves. Companion to
## test_menu_clicks.gd. Needs a window (headless drops GUI picking). Run:
##   godot --path game -s tests/test_game_clicks.gd

const GameScript := preload("res://scripts/game.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _click_button_in(node: Node, text: String) -> bool:
	if node is Button and node.text == text and node.is_visible_in_tree():
		_click(node.get_global_rect().get_center())
		return true
	for c in node.get_children():
		if await _click_button_in(c, text):
			return true
	return false


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		root.push_input(ev)


func _init() -> void:
	GameScript.next_config = {
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]],
		"captured": ["pawn", "pawn"],
	}
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	check(game.state == game.State.PLAYER_TURN, "config boots into player turn")

	# board click selects the queen and shows its moves
	_click(game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.selected == Vector2i(2, 2), "board click selects a piece")
	check(not game.legal_dests.is_empty(), "selection shows legal moves")

	# Merge toggles on, pool buttons select, confirm appears for the pair
	_click(game.merge_button.get_global_rect().get_center())
	await process_frame
	check(game.merge_mode, "Merge button toggles merge mode")
	check(game.pool_box.get_child_count() == 1, "2 captured pawns show as one stack")
	for i in 2: # two taps on the stack pick two units; strip rebuilds each time
		var live: Array = game.pool_box.get_children().filter(
			func(b: Node) -> bool: return not b.is_queued_for_deletion())
		_click(live[0].get_global_rect().get_center())
		await process_frame
		await process_frame
	check(game.merge_sel.size() == 2, "pool clicks select merge sources")
	check(game.confirm_button.visible, "valid pair shows Confirm")
	_click(game.confirm_button.get_global_rect().get_center())
	await process_frame
	check(game.stock == ["sergeant"] and game.captured.is_empty(),
		"Confirm promotes the pawn pair into a Ranger in stock")
	check(not game.merge_mode, "merge mode auto-deactivates after a merge")
	_click(game.merge_button.get_global_rect().get_center()) # merge mode off
	await process_frame

	# PASS hands the turn over and comes back
	_click(game.pass_button.get_global_rect().get_center())
	await create_timer(1.0).timeout # enemy turn runs (animated path)
	check(game.state == game.State.PLAYER_TURN, "PASS cycles through the enemy turn")

	# double-tap on the queen opens the piece preview; Close dismisses it
	var at: Vector2 = game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2
	_click(at)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.double_click = true
	press.position = at
	press.global_position = at
	root.push_input(press)
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	release.double_click = false
	root.push_input(release)
	await process_frame
	check(game.preview_open, "double-tap opens the piece preview")
	check(await _click_button_in(game.preview_panel, "Close"), "Close button clickable")
	await process_frame
	check(not game.preview_open, "Close dismisses the preview")

	# in-game menu: opens, pauses the clock, Resume returns
	check(await _click_button_in(game.hud, "☰"), "menu button clickable")
	await process_frame
	check(game.game_menu_open, "menu opens")
	var frozen: float = game.clock_ms
	await create_timer(0.4).timeout
	check(game.clock_ms == frozen, "clock pauses while the menu is open")
	check(await _click_button_in(game.game_menu, "Resume"), "Resume clickable")
	await process_frame
	check(not game.game_menu_open, "Resume closes the menu")

	# wave-50 King capture opens the win screen; Continue resumes the run
	game.queue_free()
	await process_frame
	GameScript.next_config = {"wave": 50,
		"board": [["queen", 0, 2, 2], ["king", 1, 2, 3], ["rook", 1, 7, 12]]}
	GameScript.is_scenario = true # keep the probe off the real save file
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_click(game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	_click(game._tile_px(Vector2i(2, 3)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.win_open, "capturing the wave-50 King opens the win screen")
	_click(game._tile_px(Vector2i(7, 12)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.selected != Vector2i(7, 12), "win screen blocks board clicks")
	check(await _click_button_in(game.overlay, "Continue"), "Continue clickable")
	await process_frame
	check(not game.win_open and game.state == game.State.PLAYER_TURN,
		"Continue resumes the run into endless")

	print("---")
	if fails == 0:
		print("ALL GAME CLICKS OK")
	quit(1 if fails > 0 else 0)
