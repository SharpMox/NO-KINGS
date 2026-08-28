extends SceneTree
## Randomized lootbox (goal rework 2026-07-06): one step, 3 random options
## across Item/Artefact/Score, each self-describing; choosing applies by kind.
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
		shaped = shaped and o.kind in ["item", "artefact", "score"] \
			and o.name != "" and o.description != ""
		names[o.name] = true
	check(shaped, "every option carries kind, name and description")
	check(names.size() == 3, "options within an offer never repeat")

	# randomization: over many rolls every kind shows up
	var kinds_seen := {}
	for i in 100:
		for o in game._box_options():
			kinds_seen[o.kind] = true
	check(kinds_seen.size() == 3, "rolls cover items, artefacts and score")

	# choosing applies by kind
	var item_opt := {}
	var artefact_opt := {}
	var score_opt := {}
	while item_opt.is_empty() or artefact_opt.is_empty() or score_opt.is_empty():
		for o in game._box_options():
			match o.kind:
				"item": item_opt = o
				"artefact": artefact_opt = o
				"score": score_opt = o
	game._box_choose(item_opt)
	check(game.items.size() == 1, "picking an Item adds it to the held items")
	# score banked BEFORE the artefact pick (issue 20 widened which artefacts
	# roll_options can offer): several catalog artefacts hook on_score_change
	# and would legitimately change the banked amount, so this check must not
	# be racing whichever one artefact_opt happens to be this run.
	var before: int = game.score
	game._box_choose(score_opt)
	check(game.score == before + int(score_opt.value), "picking Score banks it now")
	game._box_choose(artefact_opt)
	check(game.artefacts.size() == 1, "picking a Artefact adds a run-long passive")
	check(not game.box_open, "choosing closes the box")

	# --- issue 20: rarity weighting + depth gating ---
	check(Tuning.artefact_rarity_weight("Common", 0) == 100.0
			and Tuning.artefact_rarity_weight("Legendary", 0) == 10.0,
		"at Score 0 Common outweighs Legendary 10:1")
	check(Tuning.artefact_rarity_weight("Common", Tuning.ARTEFACT_RARITY_DEPTH_CAP_SCORE) == 20.0
			and Tuning.artefact_rarity_weight("Legendary", Tuning.ARTEFACT_RARITY_DEPTH_CAP_SCORE) == 35.0,
		"deep into a run Common tapers below Legendary")
	check(Tuning.artefact_rarity_weight("", 0) == Tuning.artefact_rarity_weight("", 999999),
		"the 7 core (unrated) artefacts aren't depth-gated")

	var pool := [{"rarity": "Common"}, {"rarity": "Legendary"}]
	var wrng := RandomNumberGenerator.new()
	wrng.seed = 1
	var common_n := 0
	var legend_n := 0
	for i in 2000:
		if Tuning.weighted_artefact_pick(pool, 0, wrng) == 0:
			common_n += 1
		else:
			legend_n += 1
	check(common_n > legend_n * 5,
		"at Score 0 the weighted pick strongly favors Common (%d vs %d)" % [common_n, legend_n])
	var common_deep := 0
	var legend_deep := 0
	for i in 2000:
		if Tuning.weighted_artefact_pick(pool, Tuning.ARTEFACT_RARITY_DEPTH_CAP_SCORE, wrng) == 0:
			common_deep += 1
		else:
			legend_deep += 1
	check(legend_deep > common_deep,
		"deep into a run the weighted pick favors Legendary over Common (%d vs %d)" % [legend_deep, common_deep])

	# integration: _box_options depth-gates by game.score, not just the Tuning curve
	game.score = 0
	var low := {}
	for i in 400:
		for o in game._box_options():
			if o.kind == "artefact":
				var r: String = str(o.payload.get("rarity", ""))
				if r != "":
					low[r] = low.get(r, 0) + 1
	game.score = 50000 # far past the depth cap
	var high := {}
	for i in 400:
		for o in game._box_options():
			if o.kind == "artefact":
				var r: String = str(o.payload.get("rarity", ""))
				if r != "":
					high[r] = high.get(r, 0) + 1
	var low_total := 0
	for v in low.values():
		low_total += v
	var high_total := 0
	for v in high.values():
		high_total += v
	var low_common_share := float(low.get("Common", 0)) / float(maxi(1, low_total))
	var high_common_share := float(high.get("Common", 0)) / float(maxi(1, high_total))
	check(low_common_share > high_common_share,
		"Common's share of _box_options artefact rolls drops as Score rises (%.2f -> %.2f)"
			% [low_common_share, high_common_share])

	game.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL BOX CHECKS OK")
	quit(1 if fails > 0 else 0)
