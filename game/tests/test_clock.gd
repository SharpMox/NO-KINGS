extends SceneTree
## Clock: Economy.add_clock is the single choke point for every Clock GAIN
## site (issue 35), mirroring earn()/gain() for Score/Gold — on_clock_change
## is its hook. Also covers the run-long Turn counter (g.turn_number,
## round-tripped through save_config.gd) and Black Knight Morse Code, the
## artefact both seams exist for.
## Run headless:  godot --headless --path game -s tests/test_clock.gd

const GameScript := preload("res://scripts/game.gd")
const Economy := preload("res://scripts/economy.gd")
const SaveConfig := preload("res://scripts/save_config.gd")

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
	# --- Economy.add_clock: the choke point itself, no artefacts held ---
	var g := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "clock_s": 100.0})
	await process_frame
	Economy.add_clock(g, 5000.0, "test")
	check(g.clock_ms == 105000.0, "add_clock adds the exact amount")
	Economy.add_clock(g, -999999.0, "test")
	check(g.clock_ms == 0.0, "add_clock floors a large loss at 0, same as the old direct maxf() sites")
	g.queue_free()
	await process_frame

	# --- run-long Turn counter: ticks once per _begin_player_turn, unlike
	# turns_since_wave (resets every Wave, in _enemy_turn) ---
	var t := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	check(t.turn_number == 1, "turn_number starts at 1 after the first player turn begins")
	t._on_pass()
	while t.state != GameScript.State.PLAYER_TURN:
		await create_timer(0.1).timeout
	check(t.turn_number == 2, "turn_number ticks again on the next player turn")
	t.queue_free()
	await process_frame

	# --- turn_number round-trips through save/load, without double-counting
	# the Turn the save was taken on (_begin_player_turn's own += 1 runs
	# again inside apply(), then save_config.gd overrides it back) ---
	var s := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	s.turn_number = 7
	var cfg := SaveConfig.to_config(s)
	check(cfg.turn_number == 7, "to_config saves the current turn_number")
	SaveConfig.apply(s, cfg)
	check(s.turn_number == 7, "apply restores it exactly, not 8 — a resumed save must not double-count its own Turn")
	s.queue_free()
	await process_frame

	# --- Black Knight Morse Code: every 3rd Turn, Score AND Clock GAINS that
	# Turn are doubled — a Clock LOSS is not ---
	var bk := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "score": 0, "clock_s": 100.0, "artefacts": ["black-knight-morse-code"]})
	await process_frame
	bk.turn_number = 2 # not the cadence
	Economy.earn(bk, 10)
	check(bk.score == 100, "Black Knight: no Score doubling off the 3rd Turn") # issue 57: x10
	var clock_before: float = bk.clock_ms
	Economy.add_clock(bk, 1000.0, "test")
	check(bk.clock_ms == clock_before + 1000.0, "Black Knight: no Clock doubling off the 3rd Turn")

	bk.turn_number = 3 # the cadence
	Economy.earn(bk, 10)
	check(bk.score == 300, "Black Knight: Score gain doubled on the 3rd Turn (10 + 20)") # issue 57: x10
	clock_before = bk.clock_ms
	Economy.add_clock(bk, 1000.0, "test")
	check(bk.clock_ms == clock_before + 2000.0, "Black Knight: Clock gain doubled on the 3rd Turn")
	clock_before = bk.clock_ms
	Economy.add_clock(bk, -500.0, "test") # a same-Turn Clock LOSS
	check(bk.clock_ms == clock_before - 500.0, "Black Knight: a Clock LOSS is never doubled, even on the 3rd Turn")
	bk.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL CLOCK CHECKS OK")
	quit(1 if fails > 0 else 0)
