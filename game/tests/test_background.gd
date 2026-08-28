extends SceneTree
## OS-level backgrounding auto-pause (06): app switch / call / notification
## must freeze the run exactly like the in-game menu — clock stopped, no
## enemy turn resolves — and resume exactly where it left off. Nothing
## handled NOTIFICATION_APPLICATION_FOCUS_OUT / NOTIFICATION_WM_WINDOW_FOCUS_OUT
## before this slice. Run headless:
##   godot --headless --path game -s tests/test_background.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")

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
	GameScript.is_scenario = true # never touch the real save
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _init() -> void:
	# --- clock stops while backgrounded, resumes exactly where it left off ---
	var a := _boot({"board": [["queen", 0, 2, 2], ["king", 1, 2, 3]], "clock_s": 100.0})
	await process_frame
	check(a.state == GameScript.State.PLAYER_TURN, "boot starts on the player's turn")
	await create_timer(0.2).timeout # let a real tick happen so the clock is live
	var frozen: float = a.clock_ms
	check(frozen < 100_000.0, "clock ticks down normally before backgrounding")

	a.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(a.backgrounded, "FOCUS_OUT sets backgrounded")
	await create_timer(0.3).timeout
	check(a.clock_ms == frozen, "clock frozen while backgrounded")

	a.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not a.backgrounded, "FOCUS_IN clears backgrounded")
	await create_timer(0.2).timeout
	check(a.clock_ms < frozen, "clock resumes ticking after returning to the foreground")
	a.queue_free()
	await process_frame

	# --- no enemy turn resolves while backgrounded; it resumes after ---
	var b := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 7]]})
	await process_frame
	b.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	b._enemy_turn() # fire-and-forget: the coroutine must stall, not resolve
	var before := JSON.stringify(b._to_config())
	await create_timer(Tuning.ENEMY_TURN_PAUSE + 0.6).timeout # past every pacing timer
	check(b.state == GameScript.State.ENEMY_TURN, "enemy turn still open while backgrounded")
	check(JSON.stringify(b._to_config()) == before, "no enemy action resolves while backgrounded")

	b.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await create_timer(Tuning.ENEMY_TURN_PAUSE * 2 + 0.7).timeout # enough for the turn to finish
	check(b.state == GameScript.State.PLAYER_TURN, "enemy turn resumes and completes after returning")
	b.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL BACKGROUND CHECKS OK")
	quit(1 if fails > 0 else 0)
