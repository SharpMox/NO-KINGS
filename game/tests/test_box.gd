extends SceneTree
## Randomized lootbox (goal rework 2026-07-06): one step, 3 random options
## across Item/Trinket/Score, each self-describing; choosing applies by kind.
## Run headless:  godot --headless --path game -s tests/test_box.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _init() -> void:
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3}
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame

	# offer shape: 3 options, self-describing, no duplicates
	var opts: Array = game._box_options()
	check(opts.size() == 3, "an offer holds 3 options")
	var shaped := true
	var names := {}
	for o in opts:
		shaped = shaped and o.kind in ["item", "trinket", "score"] \
			and o.name != "" and o.description != ""
		names[o.name] = true
	check(shaped, "every option carries kind, name and description")
	check(names.size() == 3, "options within an offer never repeat")

	# randomization: over many rolls every kind shows up
	var kinds_seen := {}
	for i in 100:
		for o in game._box_options():
			kinds_seen[o.kind] = true
	check(kinds_seen.size() == 3, "rolls cover items, trinkets and score")

	# choosing applies by kind
	var item_opt := {}
	var trinket_opt := {}
	var score_opt := {}
	while item_opt.is_empty() or trinket_opt.is_empty() or score_opt.is_empty():
		for o in game._box_options():
			match o.kind:
				"item": item_opt = o
				"trinket": trinket_opt = o
				"score": score_opt = o
	game._box_choose(item_opt)
	check(game.items.size() == 1, "picking an Item adds it to the held items")
	game._box_choose(trinket_opt)
	check(game.trinkets.size() == 1, "picking a Trinket adds a run-long passive")
	var before: int = game.score
	game._box_choose(score_opt)
	check(game.score == before + int(score_opt.value), "picking Score banks it now")
	check(not game.box_open, "choosing closes the box")

	game.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL BOX CHECKS OK")
	quit(1 if fails > 0 else 0)
