extends SceneTree
## Save/resume round-trip: boot a rich run, serialize it, boot a second game
## from the JSON-round-tripped save, and assert the state is identical.
## Run headless:  godot --headless --path game -s tests/test_save.gd

const GameScript := preload("res://scripts/game.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _boot(cfg: Dictionary) -> Node2D:
	GameScript.next_config = cfg
	GameScript.is_scenario = true # keep the probe from touching the real save
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _init() -> void:
	var rich := {
		"board": [["queen", 0, 2, 1], ["pawn", 0, 3, 1, "buff"], ["rook", 1, 4, 10]],
		"stock": ["pawn", "ferz"], "captured": ["knight", "knight", "bishop"],
		"items": ["blitz", "sniper"], "trinkets": ["greed", "greed", "move"],
		"tariffs": ["inflation", "inflation", "austerity"],
		"oneoffs": [], "wave": 23, "turns_since_wave": 4, "kings_defeated": 1,
		"lost_player": 5, "lost_enemy": 9,
		"pending": [{"id": "bishop"}, {"id": "pawn", "buff": true}],
		"score": 470, "money": 35, "clock_s": 812.5,
		"shop_stock": [{"kind": "piece", "key": "pawn", "sold": true},
			{"kind": "box", "key": "box", "sold": false}],
		"skip_enemy_turns": 1, "tariffs_off": true,
	}
	var a := _boot(rich)
	await process_frame
	var saved: Dictionary = a._to_config()
	a.queue_free()
	await process_frame

	# through JSON, like the real save file
	var restored: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var b := _boot(restored)
	await process_frame

	var again: Dictionary = b._to_config()
	check(absf(again.clock_s - saved.clock_s) < 0.5, "clock survives (minus live ticking)")
	again.erase("clock_s") # the clock ticks between frames; compared above
	saved.erase("clock_s")
	check(JSON.stringify(again) == JSON.stringify(saved), "save -> load -> save is identical")
	for k in saved:
		if JSON.stringify(saved[k]) != JSON.stringify(again.get(k)):
			print("DIFF %s: %s -> %s" % [k, JSON.stringify(saved[k]), JSON.stringify(again.get(k))])
	check(b.score == 470, "score restored")
	check(b.money == 35, "money restored")
	check(b.shop_stock.size() == 2 and b.shop_stock[0].sold and not b.shop_stock[1].sold,
		"shop slots and SOLD flags restored")
	check(b.wave == 23 and b.turns_since_wave == 4, "wave clock restored")
	check(b.kings_defeated == 1, "kings defeated restored")
	check(b.lost_player == 5 and b.lost_enemy == 9, "loss counters restored")
	check(b.trinkets.size() == 3, "trinket stacks restored")
	check(b.tariffs_active.size() == 3, "tariff stacks restored")
	check(b.pending_spawn.is_empty(), "pending wave spawned on resume")
	check(b.board.size() >= 5, "pending pieces landed on the board")
	check(b.skip_enemy_turns == 1, "item counters restored")
	check(b.tariffs_suppressed, "counter-intel suppression restored")
	var buffed := 0
	for pos in b.board:
		if b.board[pos].get("buff", false):
			buffed += 1
	check(buffed == 2, "box carriers survive the round trip")

	print("---")
	if fails == 0:
		print("ALL SAVE CHECKS OK")
	quit(1 if fails > 0 else 0)
