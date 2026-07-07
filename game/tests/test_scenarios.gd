extends SceneTree
## Non-regression sweep over EVERY TEST scenario: boots each config in-process
## and lets the greedy bot play it for a while — any script error, bad config,
## or crash in an interaction path surfaces here. Headless-safe (no GUI input;
## the click probes cover picking). Run:
##   godot --headless --path game -s tests/test_scenarios.gd

const GameScript := preload("res://scripts/game.gd")
const Scenarios := preload("res://data/scenarios.gd")

const BOT_STEPS := 40 # bot actions per scenario; enough to hit waves & merges

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _init() -> void:
	var all := Scenarios.all()
	for i in all.size():
		var s: Dictionary = all[i]
		GameScript.next_config = s.cfg
		GameScript.is_scenario = true
		var game: Node2D = load("res://scenes/Game.tscn").instantiate()
		root.add_child(game)
		await process_frame
		await process_frame
		check(game.state == GameScript.State.PLAYER_TURN,
			"[%d] %s — boots into a playable turn" % [i, s.name])
		# bot-play the scenario in-process (autoplay_exit stays false, so a
		# game over shows the end screen instead of quitting the sweep)
		game.autoplay = true
		var steps := 0
		while steps < BOT_STEPS and game.state != GameScript.State.GAME_OVER:
			await process_frame
			steps += 1
		check(true, "[%d] %s — bot survived %d frames%s" % [i, s.name, steps,
			" (game over)" if game.state == GameScript.State.GAME_OVER else ""])
		game.queue_free()
		await process_frame

	print("---")
	if fails == 0:
		print("ALL %d SCENARIOS OK" % all.size())
	quit(1 if fails > 0 else 0)
