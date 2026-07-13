extends SceneTree
## Money: every gain raises score by the raw amount (up-only metric) and
## money by the Inflation-taxed amount — Inflation never touches score.
## Run headless:  godot --headless --path game -s tests/test_money.gd

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
	# the enemy rook keeps the boot from queueing the next wave (board-cleared rule)
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3}
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame

	check(game.money == 0, "a run starts broke")
	Economy.earn(game, 50)
	check(game.score == 50 and game.money == 50, "earn raises score and money 1:1")

	Economy.activate_tariff_by_key(game, "inflation")
	Economy.earn(game, 100)
	check(game.score == 150, "Inflation never touches score")
	check(game.money == 140, "Inflation taxes money (-10% per stack)")

	game.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL MONEY CHECKS OK")
	quit(1 if fails > 0 else 0)
