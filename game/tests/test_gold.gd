extends SceneTree
## Gold: every gain raises score by the raw amount (up-only metric) and
## gold by the Inflation-taxed amount — Inflation never touches score.
## Run headless:  godot --headless --path game -s tests/test_gold.gd

const GameScript := preload("res://scripts/game.gd")
const Economy := preload("res://scripts/economy.gd")
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
	# the enemy rook keeps the boot from queueing the next wave (board-cleared rule)
	var game: Node2D = _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame

	check(game.gold == 0, "a run starts broke")
	Economy.earn(game, 50)
	check(game.score == 50 and game.gold == 50, "earn raises score and gold 1:1")

	Economy.activate_tariff_by_key(game, "inflation")
	Economy.earn(game, 100)
	check(game.score == 150, "Inflation never touches score")
	check(game.gold == 140, "Inflation taxes gold (-10% per stack)")

	# --- every former score cost hits gold instead (issue 02) ---
	var s: int = game.score
	var m: int = game.gold
	game.stock.append("pawn")
	game.actions_left = 2
	game._place("pawn", Vector2i(0, 0))
	check(game.score == s, "placement never touches score")
	check(game.gold == m - Tuning.PLACEMENT_COST, "placement debits gold")

	Economy.activate_tariff_by_key(game, "move_cost")
	s = game.score
	m = game.gold
	Economy.charge(game, "move_cost")
	check(game.score == s, "tariff charges never touch score")
	check(game.gold == m - Tuning.TARIFF_ACTION_COST, "tariff charges debit gold")

	m = game.gold
	Economy.activate_tariff_by_key(game, "asset_freeze")
	check(game.score == s, "Asset Freeze never touches score")
	check(game.gold == m / 2, "Asset Freeze halves gold")

	s = game.score
	m = game.gold
	var stock_n: int = game.stock.size()
	game.modals.reinforce_buy_pressed.emit("pawn")
	check(game.stock.size() == stock_n + 1, "reinforce buy adds the piece")
	check(game.score == s and game.gold == m, "reinforce buys are free")

	game.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL GOLD CHECKS OK")
	quit(1 if fails > 0 else 0)
