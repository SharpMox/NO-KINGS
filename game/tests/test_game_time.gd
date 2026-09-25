extends SceneTree
## Game time (Tuning.now_ms) is FRAMES under --fixed-fps, not wall clock.
## Two taps on one Stock stack N frames apart must give the same verdict
## (double tap or not) whether those frames took 1 ms or 60 ms each. The
## #581 flake was exactly this: a double-tap window measured by wall clock,
## taps that landed 410-451 ms apart on a loaded CI runner.
## Run headless, WITH the flag (run_all.sh does):
##   godot --headless --path game --fixed-fps 60 -s tests/test_game_time.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")

const FPS := 60
const SLOW_MS := 60 # a real-time stall per frame, far slower than 1/FPS
const INSIDE := 10  # frames: 167 ms of game time, well inside DOUBLE_TAP_MS
const OUTSIDE := 40 # frames: 667 ms of game time, well outside it

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _boot(cfg: Dictionary) -> Node2D:
	GameScript.reset_boot_defaults()
	cfg = cfg.duplicate()
	cfg.seed = 1
	GameScript.next_config = cfg
	GameScript.is_scenario = true # never touch the real save
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


## Waits `n` frames, stalling the real clock `stall_ms` before each one.
func _frames(n: int, stall_ms: int) -> void:
	for _i in n:
		OS.delay_msec(stall_ms)
		await process_frame


## Two taps on the Stock pawn `n` frames apart. Returns [opened_preview, real_ms].
func _tap_pair(n: int, stall_ms: int) -> Array:
	var g := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "stock": ["pawn"]})
	await process_frame
	g.state = g.State.PLAYER_TURN
	g.actions_left = 5
	g._on_stack_pressed("pawn", false)
	check(g.placing_id == "pawn" and not g.preview_open, "(setup) the first tap arms the stack")
	var t0 := Time.get_ticks_msec()
	await _frames(n, stall_ms)
	var real_ms := Time.get_ticks_msec() - t0
	g._on_stack_pressed("pawn", false)
	var opened: bool = g.preview_open
	g.queue_free()
	await process_frame
	return [opened, real_ms]


func _init() -> void:
	await process_frame # Engine.get_main_loop() is still null inside _init

	# the clock itself: N stalled frames advance game time by exactly N/FPS
	var before := Tuning.now_ms()
	await _frames(INSIDE, SLOW_MS)
	var step := Tuning.now_ms() - before
	var want := roundi(INSIDE * 1000.0 / FPS)
	check(absi(step - want) <= 1,
		"%d frames stalled %d ms each advance game time by %d ms, not the ~%d ms that really passed (needs --fixed-fps %d; got %d)" \
		% [INSIDE, SLOW_MS, want, INSIDE * SLOW_MS, FPS, step])

	var fast_in: Array = await _tap_pair(INSIDE, 0)
	var slow_in: Array = await _tap_pair(INSIDE, SLOW_MS)
	check(fast_in[0], "taps %d frames apart, fast frames: a double tap (preview opens)" % INSIDE)
	check(slow_in[1] > Tuning.DOUBLE_TAP_MS,
		"(setup) the slow pair really was %d ms apart by wall clock, past the %d ms window" \
		% [slow_in[1], Tuning.DOUBLE_TAP_MS])
	check(slow_in[0], "taps %d frames apart, %d ms of real time: STILL a double tap" \
		% [INSIDE, slow_in[1]])

	var fast_out: Array = await _tap_pair(OUTSIDE, 0)
	var slow_out: Array = await _tap_pair(OUTSIDE, SLOW_MS)
	check(not fast_out[0], "taps %d frames apart, fast frames (%d ms real): not a double tap" \
		% [OUTSIDE, fast_out[1]])
	check(not slow_out[0], "taps %d frames apart, slow frames: not a double tap either" % OUTSIDE)

	print("---")
	if fails == 0:
		print("ALL GAME TIME CHECKS OK")
	quit(1 if fails > 0 else 0)
