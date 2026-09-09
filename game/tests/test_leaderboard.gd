extends SceneTree
## issue 85: the cloud leaderboard is a UNION, not a pick-one.

const Leaderboard := preload("res://scripts/leaderboard.gd")
const CloudSave := preload("res://scripts/cloud_save.gd")
const Memory := preload("res://scripts/cloud/cloud_backend_memory.gd")
const GlobalBoard := preload("res://scripts/global_board.gd")
const GameScript := preload("res://scripts/game.gd")
const Noop := preload("res://scripts/cloud/cloud_backend_noop.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("ok: ", label)
	else:
		fails += 1
		print("FAIL: ", label)


func _e(score: int, wave: int) -> Dictionary:
	return {"score": score, "wave": wave, "kings": 0}


func _boot(cfg: Dictionary) -> Node2D:
	if not cfg.has("seed"):
		cfg = cfg.duplicate()
		cfg.seed = 1
	GameScript.next_config = cfg
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _init() -> void:
	# --- NO-8: the GLOBAL board (was issue 104) -----------------------------
	# A different question from the personal board above: "how do I rank?"
	# rather than "am I improving?". Desktop has no platform behind it.
	check(not GlobalBoard.available(),
		"no global board on desktop — so no door to one on the Scores screen")

	# THE ONE THAT SILENTLY CORRUPTS A REAL LEADERBOARD IF IT REGRESSES.
	# tools/playtest.sh plays hundreds of bot runs. If the submit ever escapes
	# game.gd's `not is_scenario and not autoplay` guard, every one of them
	# posts to a public board — and it would look fine here, because desktop
	# submits nothing either way. So this counts ATTEMPTS, not sends.
	var sc := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	GlobalBoard.submits = 0
	sc._game_over(false, "test")
	check(GlobalBoard.submits == 0,
		"a scenario run submits NOTHING to the global board (attempts: %d)"
			% GlobalBoard.submits)
	sc.queue_free()
	await process_frame

	var bot := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	bot.is_scenario = false
	bot.autoplay = true # the harness's own shape: a real config, driven by the bot
	GlobalBoard.submits = 0
	bot._game_over(false, "test")
	check(GlobalBoard.submits == 0,
		"an autoplay run submits NOTHING either (attempts: %d)" % GlobalBoard.submits)
	bot.queue_free()
	await process_frame

	# ...and the guard is not simply always-false: a real run DOES reach the
	# submit. Without this, both checks above would pass on a deleted call.
	var real := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	real.is_scenario = false
	real.autoplay = false
	GlobalBoard.submits = 0
	real._game_over(false, "test")
	check(GlobalBoard.submits == 1,
		"a REAL run does reach the submit — the guard gates it, it is not dead code")
	real.queue_free()
	await process_frame

	Memory.reset()
	CloudSave.backend = Noop

	# --- offline: the local board is the whole board, and that is not an error
	check(not Leaderboard.cloud_available(), "no cloud on desktop")
	var local := [_e(500, 20), _e(300, 12)]
	var shown := Leaderboard.board(local)
	check(shown.size() == 2 and int(shown[0].score) == 500,
		"offline shows exactly the local board, best first")

	# --- the load-bearing property: a UNION, not a pick-one -------------------
	# CloudSave.resolve() picks one side wholesale. For a run state that is
	# right; for a board it silently deletes the other device's real scores.
	CloudSave.backend = Memory
	Memory.push(Leaderboard.KEY, {"ts": 1, "data": [_e(900, 40), _e(400, 15)]})
	shown = Leaderboard.board(local)
	check(shown.size() == 4, "both devices' runs survive the merge (%d)" % shown.size())
	check(int(shown[0].score) == 900, "the best run overall ranks first")
	var scores: Array = []
	for e in shown:
		scores.append(int(e.score))
	check(scores == [900, 500, 400, 300], "the union is ordered by score: %s" % str(scores))

	# --- the same board synced back must not duplicate itself ---------------
	Memory.push(Leaderboard.KEY, {"ts": 1, "data": local.duplicate(true)})
	shown = Leaderboard.board(local)
	check(shown.size() == 2, "an identical run on both sides is ONE entry, not two")

	# --- order-independent and capped ---------------------------------------
	var a := [_e(10, 1), _e(30, 3)]
	var b := [_e(20, 2)]
	check(Leaderboard.merge(a, b) == Leaderboard.merge(b, a),
		"merge is order-independent")
	check(Leaderboard.merge(a, a) == Leaderboard.merge(a, []),
		"merging a board with itself changes nothing")
	var many: Array = []
	for i in 15:
		many.append(_e(i * 10, i))
	check(Leaderboard.merge(many, []).size() == Leaderboard.CAP,
		"the board is capped at %d" % Leaderboard.CAP)

	# --- a malformed cloud payload must not take the board down -------------
	Memory.push(Leaderboard.KEY, {"ts": 1, "data": "not a board"})
	check(Leaderboard.board(local).size() == 2,
		"a malformed cloud payload falls back to local rather than erroring")

	Memory.reset()
	CloudSave.backend = Noop
	print("---")
	print("ALL LEADERBOARD CHECKS OK" if fails == 0 else "LEADERBOARD FAILURES: %d" % fails)
	quit(1 if fails > 0 else 0)
