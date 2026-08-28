extends SceneTree
## Games History: every real run's summary persists to user://history.json,
## newest first, distinct from the ranked top-10 Highscores (scores.json).
## Run headless:  godot --headless --path game -s tests/test_history.gd

const GameScript := preload("res://scripts/game.gd")
const Economy := preload("res://scripts/economy.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _init() -> void:
	DirAccess.remove_absolute(GameScript.HISTORY_PATH) # clean slate

	# the enemy rook keeps the boot from queueing the next wave (board-cleared rule)
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3}
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame

	game.score = 300
	game.wave = 5
	game.kings_defeated = 1
	game.tariffs_seen = ["Inflation"]
	game.lost_player = 2
	game._record_history(false)

	var history: Array = GameScript.load_history()
	check(history.size() == 1, "a run appends one entry")
	var e: Dictionary = history[0]
	check(int(e.score) == 300 and int(e.wave) == 5 and int(e.kings) == 1
		and int(e.tariffs) == 1 and int(e.lost) == 2 and e.won == false,
		"the entry carries the full run summary")

	game.score = 900
	game._record_history(true)
	history = GameScript.load_history()
	check(history.size() == 2, "a second run appends, it doesn't replace")
	check(int(history[0].score) == 900 and history[0].won == true,
		"newest run is first (distinct from Highscores' best-first order)")
	check(int(history[1].score) == 300, "the earlier run is still there, second")

	for i in Economy.HISTORY_CAP + 5: # push well past the cap
		game.score = i
		game._record_history(false)
	check(GameScript.load_history().size() == Economy.HISTORY_CAP,
		"the log caps at HISTORY_CAP so it can't grow forever")

	DirAccess.remove_absolute(GameScript.HISTORY_PATH)
	game.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL HISTORY CHECKS OK")
	quit(1 if fails > 0 else 0)
