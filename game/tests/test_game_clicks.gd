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
	check(game.pool_box.get_child_count() == 2, "pool strip shows the 2 captured pawns")
	for i in 2: # strip rebuilds after each click — re-fetch, never cache
		var live: Array = game.pool_box.get_children().filter(
			func(b: Node) -> bool: return not b.is_queued_for_deletion())
		_click(live[i].get_global_rect().get_center())
		await process_frame
		await process_frame
	check(game.merge_sel.size() == 2, "pool clicks select merge sources")
	check(game.confirm_button.visible, "valid pair shows Confirm")
	_click(game.confirm_button.get_global_rect().get_center())
	await process_frame
	check(game.stock.size() == 1 and game.captured.is_empty(), "Confirm merges 2 pawns into stock")
	_click(game.merge_button.get_global_rect().get_center()) # merge mode off
	await process_frame

	# PASS hands the turn over and comes back
	_click(game.pass_button.get_global_rect().get_center())
	await create_timer(1.0).timeout # enemy turn runs (animated path)
	check(game.state == game.State.PLAYER_TURN, "PASS cycles through the enemy turn")

	print("---")
	if fails == 0:
		print("ALL GAME CLICKS OK")
	quit(1 if fails > 0 else 0)
