extends SceneTree
## Local high scores: run results persist to user://scores.json (top 10,
## best first), and recording a run returns its all-time rank.
## Run headless:  godot --headless --path game -s tests/test_scores.gd

const GameScript := preload("res://scripts/game.gd")

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
	DirAccess.remove_absolute(GameScript.SCORES_PATH) # clean slate

	# the enemy rook keeps the boot from queueing the next wave (board-cleared rule)
	var game: Node2D = _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame

	game.score = 300
	check(game._record_score() == 1, "first run ranks #1")
	game.score = 500
	check(game._record_score() == 1, "higher score takes #1")
	game.score = 100
	check(game._record_score() == 3, "lower score ranks below")

	var scores: Array = GameScript.load_scores()
	check(scores.size() == 3, "three runs stored")
	check(int(scores[0].score) == 500 and int(scores[2].score) == 100,
		"stored best first")
	check(int(scores[0].wave) == 3, "entries carry the wave reached")

	for i in 12: # only the top 10 survive
		game.score = 1000 + i
		game._record_score()
	check(GameScript.load_scores().size() == 10, "list caps at 10")
	game.score = 1
	check(game._record_score() > 10, "a bottom score still gets a rank")

	DirAccess.remove_absolute(GameScript.SCORES_PATH)
	game.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL SCORE CHECKS OK")
	quit(1 if fails > 0 else 0)
