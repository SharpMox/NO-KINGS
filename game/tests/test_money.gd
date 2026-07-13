extends SceneTree
## Money: every gain raises score by the raw amount (up-only metric) and
## money by the Inflation-taxed amount — Inflation never touches score.
## Run headless:  godot --headless --path game -s tests/test_money.gd

const GameScript := preload("res://scripts/game.gd")
const Economy := preload("res://scripts/economy.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Items := preload("res://data/items.gd")

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

	# --- every former score cost hits money instead (issue 02) ---
	var s: int = game.score
	var m: int = game.money
	game.stock.append("pawn")
	game.actions_left = 2
	game._place("pawn", Vector2i(0, 0))
	check(game.score == s, "placement never touches score")
	check(game.money == m - Tuning.PLACEMENT_COST, "placement debits money")

	Economy.activate_tariff_by_key(game, "move_cost")
	s = game.score
	m = game.money
	Economy.charge(game, "move_cost")
	check(game.score == s, "tariff charges never touch score")
	check(game.money == m - Tuning.TARIFF_ACTION_COST, "tariff charges debit money")

	s = game.score
	m = game.money
	for it in Items.ITEMS:
		if it.key == "resupply_drop":
			game.items.append(it)
	game._use_item(game.items.size() - 1)
	check(game.score == s, "Resupply Drop never touches score")
	check(game.money == m + Tuning.PLACEMENT_COST, "Resupply Drop refunds money")

	m = game.money
	Economy.activate_tariff_by_key(game, "asset_freeze")
	check(game.score == s, "Asset Freeze never touches score")
	check(game.money == m / 2, "Asset Freeze halves money")

	s = game.score
	m = game.money
	var stock_n: int = game.stock.size()
	game.modals.reinforce_buy_pressed.emit("pawn")
	check(game.stock.size() == stock_n + 1, "reinforce buy adds the piece")
	check(game.score == s and game.money == m, "reinforce buys are free")

	game.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL MONEY CHECKS OK")
	quit(1 if fails > 0 else 0)
