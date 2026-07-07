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


## Poll until the enemy turn hands control back (animations + ENEMY_TURN_PAUSE
## make its duration a tunable, not a constant) — up to 4s.
func _await_player_turn(game: Node2D) -> void:
	for i in 40:
		if game.state == game.State.PLAYER_TURN:
			return
		await create_timer(0.1).timeout


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

	# re-clicking the selected piece deselects it
	var qpx: Vector2 = game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2
	_click(qpx)
	await process_frame
	check(game.selected == Vector2i(-1, -1), "re-click deselects the piece")

	# dragging away and releasing back home takes no action and deselects
	var q_press := InputEventMouseButton.new()
	q_press.button_index = MOUSE_BUTTON_LEFT
	q_press.pressed = true
	q_press.position = qpx
	q_press.global_position = qpx
	root.push_input(q_press)
	await process_frame
	var q_motion := InputEventMouseMotion.new()
	q_motion.position = game._tile_px(Vector2i(4, 6)) + Vector2(game.tile, game.tile) / 2
	q_motion.global_position = q_motion.position
	root.push_input(q_motion)
	await process_frame
	var q_release := InputEventMouseButton.new()
	q_release.button_index = MOUSE_BUTTON_LEFT
	q_release.pressed = false
	q_release.position = qpx
	q_release.global_position = qpx
	root.push_input(q_release)
	await process_frame
	check(game.selected == Vector2i(-1, -1) and game.board.has(Vector2i(2, 2)),
		"aborted drag (released at home) deselects, no action taken")

	# enemy recon: clicking a foe shows its moves/threats but can't move it
	# (deselect the queen first — the foe is one of her capture targets)
	_click(game._tile_px(Vector2i(4, 9)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	_click(game._tile_px(Vector2i(2, 4)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.selected == Vector2i(2, 4) and not game.legal_dests.is_empty(),
		"clicking an enemy shows where it can move")
	var recon_dest: Vector2i = game.legal_dests[0]
	_click(game._tile_px(recon_dest) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(Vector2i(2, 4)) and not game.board.has(recon_dest),
		"an enemy recon selection can never be moved")

	# Buttonless merging: dragging the captured pawn stack onto itself promotes
	# the pair (same-stack pairs merge by drag; tap-again means deselect)
	check(await _click_button_in(game.hud, "Stock 2"), "Stock button opens the drawer")
	await process_frame
	check(game.drawer_open == "stock" and game.pool_box.is_visible_in_tree(),
		"stock drawer is open and shows the pool strip")
	check(game.pool_box.get_child_count() == 1, "2 captured pawns show as one stack")
	var stack: Button = game.pool_box.get_child(0)
	_click(stack.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(game.placing_id == "pawn" and game.placing_cap,
		"tapping the stack arms it (no merge on tap — 2026-07-07)")
	var badges: Array = []
	for b in game.pool_box.get_children():
		if b.is_queued_for_deletion():
			continue
		for c in b.get_children():
			if c is Button and c.text == "▲":
				badges.append(c)
	check(not badges.is_empty(), "an armed promotable stack shows the ▲ button")
	_click((badges[0] as Button).get_global_rect().get_center())
	await process_frame
	check(game.pending_merge.size() == 2, "the ▲ badge asks for merge confirmation")
	check(game.captured.size() == 2, "nothing merges before confirmation")
	check(await _click_button_in(game.hud, "Merge"), "confirm button clickable")
	await process_frame
	check(game.stock == ["sergeant"] and game.captured.is_empty(),
		"confirming promotes the pawn pair into stock")

	# PASS hands the turn over, banks the +5s turn bonus, and comes back
	var clock_before: float = game.clock_ms
	_click(game.pass_button.get_global_rect().get_center())
	await _await_player_turn(game) # enemy turn runs (animated + paced path)
	check(game.state == game.State.PLAYER_TURN, "PASS cycles through the enemy turn")
	check(game.clock_ms >= clock_before + 4000, # 5s bonus minus a little ticking
		"finishing the turn grants the clock bonus")

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

	# capturing a box carrier opens the randomized one-step box; an option
	# button applies its reward and closes the panel
	game.queue_free()
	await process_frame
	GameScript.next_config = {"wave": 3,
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 3, "buff"], ["rook", 1, 7, 12]]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_click(game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	_click(game._tile_px(Vector2i(2, 3)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.box_open, "capturing a box carrier opens the box")
	var opt_btn := _first_option_button(game.box_panel)
	check(opt_btn != null and "\n" in opt_btn.text,
		"box options describe themselves (two-line label)")
	var loot_before: int = game.items.size() + game.trinkets.size()
	var score_before: int = game.score
	_click(opt_btn.get_global_rect().get_center())
	await process_frame
	check(not game.box_open, "picking an option closes the box")
	check(game.items.size() + game.trinkets.size() > loot_before
		or game.score > score_before, "the picked reward is applied")

	# SETUP: the pass button reads START, and a stock piece can be dragged
	# from the pool strip onto a zone tile (game-feel pass 2026-07-06)
	game.queue_free()
	await process_frame
	GameScript.next_config = {} # fresh run -> SETUP placement phase
	GameScript.next_army = "Crown"
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.state == game.State.SETUP, "empty config boots into SETUP")
	check(game.pass_button.text == "START", "setup shows START instead of PASS")
	var stack_btn: Button = game.pool_box.get_child(0)
	var stock_before: int = game.stock.size()
	var d_press := InputEventMouseButton.new()
	d_press.button_index = MOUSE_BUTTON_LEFT
	d_press.pressed = true
	d_press.position = stack_btn.get_global_rect().get_center()
	d_press.global_position = d_press.position
	root.push_input(d_press)
	await process_frame
	var zone_px: Vector2 = game._tile_px(Vector2i(4, 0)) + Vector2(game.tile, game.tile) / 2
	var d_motion := InputEventMouseMotion.new()
	d_motion.position = zone_px
	d_motion.global_position = zone_px
	root.push_input(d_motion)
	await process_frame
	var d_release := InputEventMouseButton.new()
	d_release.button_index = MOUSE_BUTTON_LEFT
	d_release.pressed = false
	d_release.position = zone_px
	d_release.global_position = zone_px
	root.push_input(d_release)
	await process_frame
	check(game.board.has(Vector2i(4, 0)) and game.stock.size() == stock_before - 1,
		"drag from the stock strip places the piece on the zone tile")

	# setup free repositioning: tap the placed piece, tap another zone tile
	# (the drawer overlays the zone now — an outside tap closes it first)
	_click(game._tile_px(Vector2i(4, 8)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.drawer_open == "", "an outside tap closes the drawer")
	_click(game._tile_px(Vector2i(4, 0)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	_click(game._tile_px(Vector2i(2, 1)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(Vector2i(2, 1)) and not game.board.has(Vector2i(4, 0)),
		"setup: tap-tap relocates a placed piece freely")

	# selecting a placed piece offers an empty stock slot to put it back
	_click(game._tile_px(Vector2i(2, 1)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	var slots: Array = game.pool_box.get_children().filter(func(b: Node) -> bool:
		return b is Button and b.text == "+" and not b.is_queued_for_deletion())
	check(not slots.is_empty(), "setup: selecting a placed piece shows the put-back slot")

	# and dragging a placed piece onto the stock strip takes it back
	var piece_px: Vector2 = game._tile_px(Vector2i(2, 1)) + Vector2(game.tile, game.tile) / 2
	var strip_px: Vector2 = (game.drawer_buttons["stock"] as Control).get_global_rect().get_center()
	var b_press := InputEventMouseButton.new()
	b_press.button_index = MOUSE_BUTTON_LEFT
	b_press.pressed = true
	b_press.position = piece_px
	b_press.global_position = piece_px
	root.push_input(b_press)
	await process_frame
	var b_motion := InputEventMouseMotion.new()
	b_motion.position = strip_px
	b_motion.global_position = strip_px
	root.push_input(b_motion)
	await process_frame
	var b_release := InputEventMouseButton.new()
	b_release.button_index = MOUSE_BUTTON_LEFT
	b_release.pressed = false
	b_release.position = strip_px
	b_release.global_position = strip_px
	root.push_input(b_release)
	await process_frame
	check(not game.board.has(Vector2i(2, 1)) and game.stock.size() == stock_before,
		"setup: drop on the Stock button returns the piece to stock")

	# tap-to-place regression (2026-07-07): strip rebuilds on press/release used
	# to free the button before its arming tap fired
	check(await _click_button_in(game.hud, "Stock %d" % stock_before),
		"Stock button reopens the drawer")
	await process_frame
	var live_stack: Button = game.pool_box.get_children().filter(func(b: Node) -> bool:
		return b is Button and b.has_meta("id") and not b.is_queued_for_deletion())[0]
	_click(live_stack.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(game.placing_id != "", "setup: tapping a stack arms placement")
	check(not game.drawer_buttons["stock"].icon == null,
		"the armed piece shows on the Stock button")
	_click(game._tile_px(Vector2i(6, 8)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.placing_id != "" and game.drawer_open == "",
		"outside tap closes the drawer but keeps the armed piece")
	_click(game._tile_px(Vector2i(6, 1)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(Vector2i(6, 1)), "setup: tapping a zone tile places the piece")

	# clearing the last enemy auto-passes the turn; first, a captured piece
	# deploys like stock (GDD Captured Stock, wired 2026-07-07)
	game.queue_free()
	await process_frame
	GameScript.next_config = {"wave": 3, "captured": ["rook"],
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_button_in(game.hud, "Stock 1"), "Stock drawer opens")
	await process_frame
	var cap_stack: Button = game.pool_box.get_children().filter(func(b: Node) -> bool:
		return b is Button and b.has_meta("id") and not b.is_queued_for_deletion())[0]
	_click(cap_stack.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(game.placing_id == "rook" and game.placing_cap, "captured stack arms placement")
	_click(game._tile_px(Vector2i(5, 6)) + Vector2(game.tile, game.tile) / 2) # close drawer
	await process_frame
	_click(game._tile_px(Vector2i(5, 0)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(Vector2i(5, 0)) and game.captured.is_empty(),
		"captured piece deploys onto the zone")
	_click(game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	_click(game._tile_px(Vector2i(2, 4)) + Vector2(game.tile, game.tile) / 2)
	await _await_player_turn(game) # auto-pass runs the enemy turn (animated)
	check(game.state == game.State.PLAYER_TURN and game.wave == 4,
		"capturing the last enemy auto-passes into the next wave")

	# stale-overlay regression (2026-07-07): a move must clear the movement
	# shapes with the selection, or arrows keep drawing from _tile_px(-1,-1)
	game.queue_free()
	await process_frame
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 12]],
		"tariffs": ["move_cost"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_click(game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(not game.legal_paths.is_empty(), "selection builds the shape overlay")
	_click(game._tile_px(Vector2i(4, 4)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(Vector2i(4, 4)) and game.legal_paths.is_empty(),
		"moving clears the movement-shape overlay")

	# tariff button in the top row opens the detail overlay
	check(await _click_button_in(game.hud, "⚠1"), "tariff button clickable")
	await process_frame
	check(game.tariff_panel != null and game.tariff_panel.visible, "tariff overlay opens")
	check(await _click_button_in(game.tariff_panel, "Close"), "tariff Close clickable")
	await process_frame
	check(not game.tariff_panel.visible, "tariff overlay closes")

	print("---")
	if fails == 0:
		print("ALL GAME CLICKS OK")
	quit(1 if fails > 0 else 0)


## First reward button in the box panel (options precede the Skip button).
func _first_option_button(node: Node) -> Button:
	if node is Button and not node.text.begins_with("Skip"):
		return node
	for c in node.get_children():
		var hit := _first_option_button(c)
		if hit:
			return hit
	return null
