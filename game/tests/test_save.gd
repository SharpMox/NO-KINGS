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
		"stock": ["pawn", {"id": "ferz", "buff": true}],
		"captured": ["knight", "knight", "bishop"],
		"items": ["blitz", "sniper"], "artefacts": ["greed", "greed", "move"],
		"tariffs": ["inflation", "inflation", "austerity"],
		"oneoffs": [], "wave": 23, "turns_since_wave": 4, "kings_defeated": 1,
		"lost_player": 5, "lost_enemy": 9,
		"pending": [{"id": "bishop"}, {"id": "pawn", "buff": true}],
		"score": 470, "gold": 35, "clock_s": 812.5, "shop_restocks": 2,
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
	check(b.gold == 35, "gold restored")
	check(b.shop_stock.size() == 2 and b.shop_stock[0].sold and not b.shop_stock[1].sold,
		"shop slots and SOLD flags restored")
	check(b.shop_restocks == 2, "the restock marker survives (no reroll-scumming)")
	check(b.wave == 23 and b.turns_since_wave == 4, "wave clock restored")
	check(b.kings_defeated == 1, "kings defeated restored")
	check(b.lost_player == 5 and b.lost_enemy == 9, "loss counters restored")
	check(b.artefacts.size() == 3, "artefact stacks restored")
	check(b.tariffs_active.size() == 3, "tariff stacks restored")
	check(b.pending_spawn.is_empty(), "pending wave spawned on resume")
	check(b.board.size() >= 5, "pending pieces landed on the board")
	check(b.skip_enemy_turns == 1, "item counters restored")
	check(b.tariffs_suppressed, "counter-intel suppression restored")
	check(b.stock.has({"id": "ferz", "buff": true}) and b.stock.has("pawn"),
		"mixed String/Dictionary stock survives the JSON round-trip (ADR-0002)")
	var buffed := 0
	for pos in b.board:
		if b.board[pos].get("buff", false):
			buffed += 1
	check(buffed == 2, "box carriers survive the round trip")

	# --- issue 25: a piece's capture ledger (lifetime `captures` + Wave-scoped
	# `wave_captures`) survives the JSON round-trip on both board and Stock —
	# ADR-0002's opaque pass-through, same mechanism Piece Buffs already ride.
	# A separate, single round-trip (not folded into the "identical" check
	# above): JSON.parse_string returns floats for JSON numbers, and neither
	# Dictionary `==`/`has()` nor JSON.stringify string-compare treat 2 and
	# 2.0 as equal the way a bare `==` on the field does — this checks the
	# value actually read back, not a byte-identical re-serialization.
	var ledger := _boot({"board": [["knight", 0, 5, 1, {"captures": 2, "wave_captures": 1}],
			["rook", 1, 7, 10]], # a live enemy, so boot doesn't read as "board
			# cleared early" and advance straight into next Wave's own reset
		"stock": ["pawn", {"id": "rook", "captures": 3}], "wave": 3})
	await process_frame
	var ledger_saved: Dictionary = ledger._to_config()
	ledger.queue_free()
	await process_frame
	var ledger_restored := _boot(JSON.parse_string(JSON.stringify(ledger_saved)))
	await process_frame
	check(ledger_restored.board[Vector2i(5, 1)].get("captures", 0) == 2
		and ledger_restored.board[Vector2i(5, 1)].get("wave_captures", 0) == 1,
		"issue 25: a board piece's capture ledger (lifetime + Wave-scoped) survives the JSON round-trip")
	var restored_rook: Variant = null
	for e in ledger_restored.stock:
		if e is Dictionary and e.get("id") == "rook":
			restored_rook = e
	check(restored_rook != null and restored_rook.get("captures", 0) == 3,
		"issue 25: a piece's lifetime capture ledger rides along into Stock (ADR-0002), same as a Piece Buff")
	ledger_restored.queue_free()
	await process_frame

	# --- GDD Game Flow — Run: the seed rides along, so resuming a save rolls
	# exactly what an uninterrupted run would have rolled from that point.
	var live := _boot({"board": [["rook", 1, 4, 10]], "wave": 3})
	await process_frame
	live.rng.seed = 424242
	for i in 5: # burn some stream so the save is captured mid-sequence
		live.rng.randi()
	var mid: Dictionary = live._to_config()
	var expected := []
	for i in 8:
		expected.append(live.rng.randi())
	live.queue_free()
	await process_frame

	# round-trip through JSON, exactly as the real save file does
	var resumed := _boot(JSON.parse_string(JSON.stringify(mid)))
	await process_frame
	var got := []
	for i in 8:
		got.append(resumed.rng.randi())
	check(int(mid.seed) == 424242, "the seed is captured in the save")
	check(got == expected, "a resumed save continues the same RNG stream")
	resumed.queue_free()
	await process_frame

	# a fresh run without a seed still varies
	var fresh := _boot({"board": [["rook", 1, 4, 10]], "wave": 3})
	await process_frame
	check(fresh.rng.seed != 0, "an unpinned run still gets a random seed")
	fresh.queue_free()
	await process_frame

	# --- issue 38: schema versioning. A save written before `save_version`
	# existed must still load — proven against a hand-built v0 fixture, not a
	# live save, so the check keeps working once no v0 saves exist anywhere.
	const SaveConfig := preload("res://scripts/save_config.gd")
	var v0 := {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3,
		"score": 120, "gold": 45}
	check(not v0.has("save_version"), "the v0 fixture genuinely predates the field")
	var walked: Dictionary = SaveConfig.migrate(v0.duplicate(true))
	check(int(walked.save_version) == SaveConfig.SAVE_VERSION,
		"migrate() walks an unversioned save up to the current version")
	var old_save := _boot(v0.duplicate(true))
	await process_frame
	check(old_save.score == 120 and old_save.gold == 45,
		"a pre-versioning save still loads with its state intact")
	old_save.queue_free()
	await process_frame

	var stamped: Dictionary = _boot({"board": [["rook", 1, 7, 10]], "wave": 3})._to_config()
	await process_frame
	check(int(stamped.get("save_version", -1)) == SaveConfig.SAVE_VERSION,
		"every save written now carries the current version")

	print("---")
	if fails == 0:
		print("ALL SAVE CHECKS OK")
	quit(1 if fails > 0 else 0)
