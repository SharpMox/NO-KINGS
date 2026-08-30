extends SceneTree
## Wave Catalog data sanity — the 150 designed waves transcribed from the GDD
## (Draft v1), plus the tariff schedule that rides on them.
## Run headless:  godot --headless --path game -s tests/test_waves.gd

const Waves := preload("res://data/waves.gd")
const Tariffs := preload("res://data/tariffs.gd")
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
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _init() -> void:
	check(Waves.WAVES.size() == 150, "150 designed waves")

	# Kings at 50/100/150 only, with the catalog escorts
	for n in range(1, Waves.WAVES.size() + 1):
		var has_king: bool = Waves.WAVES[n - 1].has("king")
		if n % 50 == 0:
			check(has_king, "wave %d is a King wave" % n)
		elif has_king:
			check(false, "unexpected king in wave %d" % n)
	check(Waves.WAVES[49].size() == 5, "wave 50: King + 4 escorts")
	check(Waves.WAVES[99].size() == 5, "wave 100: King + 4 escorts")
	check(Waves.WAVES[149].size() == 6, "wave 150: King + 5 escorts")

	# Density curve (GDD totals): 5 through wave 69, 6 from wave 70
	var curve_ok := true
	for n in range(51, 70):
		curve_ok = curve_ok and Waves.WAVES[n - 1].size() == 5
	for n in range(70, 150):
		if n % 50 == 0:
			continue
		curve_ok = curve_ok and Waves.WAVES[n - 1].size() == 6
	check(curve_ok, "density curve: 5 (waves 51-69), 6 (waves 70-149)")

	# Tariff schedule: every 10th wave through 150, catalog tiers
	var tiers := {
		10: "Mild", 20: "Mild", 30: "Mild", 40: "Moderate", 50: "Severe",
		60: "Mild", 70: "Mild", 80: "Moderate", 90: "Moderate", 100: "Severe",
		110: "Mild", 120: "Moderate", 130: "Moderate", 140: "Severe", 150: "Severe",
	}
	check(Tariffs.SCHEDULE.size() == 15, "15 tariff waves")
	for n in tiers:
		check(Tariffs.SCHEDULE.get(n) == tiers[n], "wave %d tariff is %s" % [n, tiers[n]])

	# --- early-clear bonus: emptying the board before the next wave pays out
	# score + clock scaled by the turns to spare, once per wave (2026-07-07) ---
	var g: Node2D = _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]], "wave": 2})
	await process_frame
	await process_frame
	var clock0: float = g.clock_ms
	g._move_player(Vector2i(2, 2), Vector2i(2, 4)) # capture the last enemy
	var early: int = g._cadence() # cleared with the whole cadence to spare
	check(g.early_clear_awarded, "clearing before the wave flags the bonus")
	check(g.score == (10 + early * Tuning.EARLY_CLEAR_SCORE_PER_TURN) * 10, # issue 57: x10
			# — the capture and the early-clear bonus are separate Economy.earn
			# calls, each independently x10'd by SCORE_MULTIPLIER
		"early clear pays +%d score on top of the capture" \
		% (early * Tuning.EARLY_CLEAR_SCORE_PER_TURN * 10))
	check(g.clock_ms >= clock0 + early * Tuning.EARLY_CLEAR_CLOCK_MS_PER_TURN \
		+ Tuning.TURN_END_CLOCK_BONUS_MS - 500,
		"early clear refills the clock per spare turn")
	while g.state != GameScript.State.PLAYER_TURN: # let the enemy turn finish
		await create_timer(0.1).timeout
	var score_after: int = g.score
	g._on_pass()
	check(g.score == score_after, "the bonus pays only once per wave")
	g.queue_free()
	await process_frame

	# --- reinforcement shop: queues after waves 10/20/30/40, bot buys in ---
	var r: Node2D = _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 10, "score": 300})
	await process_frame
	await process_frame
	r._queue_wave(11)
	check(r.pending_reinforce, "clearing wave 10 pends the reinforcement shop")
	r.autoplay = true # bot path: the panel is free, grab the cheapest offers
	var stock0: int = r.stock.size()
	var score0: int = r.score
	r._begin_player_turn()
	check(not r.pending_reinforce, "the bot consumes the pending shop")
	check(r.stock.size() == stock0 + 4 and r.score == score0,
		"the bot restocked for free (stock +%d)" % (r.stock.size() - stock0))
	r._queue_wave(12)
	check(not r.pending_reinforce, "non-milestone waves pend no shop")
	r.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL WAVE CHECKS OK")
	quit(1 if fails > 0 else 0)
