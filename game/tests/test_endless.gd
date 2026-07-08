extends SceneTree
## Endless-mode King branching: wave-50 win screen with Continue, wave-100
## recurring King (bonus + refill, run continues), wave-150 full clear.
## Run headless:  godot --headless --path game -s tests/test_endless.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Rules := preload("res://scripts/rules.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _boot(cfg: Dictionary) -> Node2D:
	GameScript.next_config = cfg
	GameScript.is_scenario = true # never touch the real save
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


## A player queen at (2,2) one step below the enemy king at (2,3), plus a far
## rook so the board isn't cleared by the kill.
func _king_cfg(wave: int, kings: int) -> Dictionary:
	return {"board": [["queen", 0, 2, 2], ["king", 1, 2, 3], ["rook", 1, 7, 10]],
		"wave": wave, "kings_defeated": kings, "clock_s": 100.0, "score": 0}


func _init() -> void:
	# --- wave-100 recurring King: bonus + clock refill, run continues ---
	var a := _boot(_king_cfg(100, 1))
	await process_frame
	a._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(a.state == GameScript.State.PLAYER_TURN, "recurring King: run continues")
	check(a.kings_defeated == 2, "recurring King: kings_defeated ticks")
	check(a.score >= Tuning.WIN_SCORE_BONUS, "recurring King: score bonus awarded")
	check(a.clock_ms >= 100_000 + Tuning.KING_CLOCK_REFILL_MS,
		"recurring King: clock refilled")
	check(Rules.find_king(a.board, Rules.ENEMY).x < 0, "recurring King: king off the board")
	check(a.lost_enemy == 1, "captured King counts as an enemy loss")
	a._destroy(Vector2i(2, 3)) # item-style destruction of the player's queen
	a._destroy(Vector2i(7, 10)) # and of the enemy rook
	check(a.lost_player == 1 and a.lost_enemy == 2,
		"destruction feeds the loss counters for both sides")
	a.queue_free()
	await process_frame

	# --- review bug 2: Trade War's +1 piece must never duplicate the King ---
	var tw := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 99,
		"tariffs": ["trade_war"]})
	await process_frame
	var double_king := false
	for i in 200:
		tw.pending_spawn.clear()
		tw._queue_wave(100)
		var kings := 0
		for e in tw.pending_spawn:
			if e.id == "king":
				kings += 1
		double_king = double_king or kings > 1
	check(not double_king, "Trade War never queues a second King (200 rolls)")
	tw.queue_free()
	await process_frame

	# --- wave-50 first King: win screen pauses the run; Continue = endless ---
	var b := _boot(_king_cfg(50, 0))
	await process_frame
	b._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(b.win_open, "first King: win screen shows")
	check(b.state == GameScript.State.PLAYER_TURN, "first King: run paused, not over")
	check(b.kings_defeated == 1, "first King: kings_defeated = 1")
	var clock_at_win: float = b.clock_ms
	check(_press(b, "Continue"), "win screen has a Continue button")
	check(not b.win_open, "Continue: screen closes")
	check(b.clock_ms >= clock_at_win + Tuning.CONTINUE_CLOCK_REFILL_MS,
		"Continue: one-time endless refill")
	check(b.state == GameScript.State.PLAYER_TURN, "Continue: play resumes")
	b.queue_free()
	await process_frame

	# --- wave-50 first King: End Run locks the score in ---
	var c := _boot(_king_cfg(50, 0))
	await process_frame
	c._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(_press(c, "End Run"), "win screen has an End Run button")
	check(c.state == GameScript.State.GAME_OVER, "End Run: run over")
	c.queue_free()
	await process_frame

	# --- wave-150 last King: full clear ends the run ---
	var d := _boot(_king_cfg(150, 2))
	await process_frame
	d._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(d.state == GameScript.State.GAME_OVER, "full clear: run over")
	check(d.kings_defeated == 3, "full clear: three Kings defeated")
	d.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL ENDLESS CHECKS OK")
	quit(1 if fails > 0 else 0)


## Find a Button by text under the game's overlay and press it.
func _press(game: Node2D, text: String) -> bool:
	var stack: Array = [game.overlay]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and n.text == text:
			n.pressed.emit()
			return true
		stack.append_array(n.get_children())
	return false
