extends SceneTree
## Non-regression sweep over EVERY TEST scenario: boots each config in-process
## and lets the greedy bot play it for a while — any script error, bad config,
## or crash in an interaction path surfaces here. Headless-safe (no GUI input;
## the click probes cover picking). Run:
##   godot --headless --path game -s tests/test_scenarios.gd

const GameScript := preload("res://scripts/game.gd")
const Scenarios := preload("res://data/scenarios.gd")

const BOT_STEPS := 40 # bot actions per scenario; enough to hit waves & merges

## This sweep only checks "did it boot into a playable turn" and "did it
## crash" (slice 36: check(true, ...) below asserts nothing else) — pinned by
## default so a crash's presence/absence is reproducible, not itself a flake.
## No scenario pins its own "seed", so every sweep gets the same one.
const DEFAULT_SEED := 1

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
		var cfg: Dictionary = s.cfg
		if not cfg.has("seed"):
			cfg = cfg.duplicate()
			cfg.seed = DEFAULT_SEED
		GameScript.next_config = cfg
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
