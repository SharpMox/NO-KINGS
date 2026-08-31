extends SceneTree
## The 16-King cast (issue 09): roster shape, the tier-by-depth selection
## rule, and that a spawned King carries its identity onto the board.
## Run headless:  godot --headless --path game -s tests/test_kings.gd

const Kings := preload("res://data/kings.gd")
const Rules := preload("res://scripts/rules.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const GameScript := preload("res://scripts/game.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")
const Tuning := preload("res://scripts/tuning.gd")
const SaveConfig := preload("res://scripts/save_config.gd")

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
	# --- roster shape ---
	check(Kings.TIER_ORDER.size() == 4, "4 costume tiers")
	var all_ids := {}
	var total := 0
	for tier in Kings.TIER_ORDER:
		var pool: Array = Kings.ROSTER[tier]
		check(pool.size() == 4, "%s tier has 4 Kings" % tier)
		for k in pool:
			check(k.has("id") and k.has("name") and k.name != "", "%s has id + name" % k)
			check(not all_ids.has(k.id), "King id %s is unique" % k.id)
			all_ids[k.id] = true
			total += 1
	check(total == 16, "16 Kings total")

	# --- selection rule (issue 89): ONE costume tier per run, four Kings,
	# shuffled. Replaces the old tier-ordered-by-depth rule, under which three
	# quarters of the cast could never appear in a run and Suit never appeared.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var line_up: Dictionary = Kings.roll_run(rng)
	check(Kings.TIER_ORDER.has(line_up.tier), "a run rolls one of the four tiers")
	check(line_up.order.size() == 4, "and meets all four of that tier's Kings")
	var tier_ids := {}
	for k in Kings.ROSTER[line_up.tier]:
		tier_ids[k.id] = true
	var distinct := {}
	for id in line_up.order:
		check(tier_ids.has(id), "%s belongs to the rolled tier" % id)
		distinct[id] = true
	check(distinct.size() == 4, "the line-up is a permutation, not a sample with repeats")

	# seed determinism: the same seed must meet the same Kings in the same
	# order, or issue 75's reproducibility guarantee is broken for the endgame
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 4242
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 4242
	check(Kings.roll_run(rng_a) == Kings.roll_run(rng_b),
		"the same seed rolls the same line-up")
	var rng_c := RandomNumberGenerator.new()
	rng_c.seed = 99
	var differs := false
	for attempt in 12: # different seeds must be able to differ at all
		var other := RandomNumberGenerator.new()
		other.seed = 500 + attempt
		if Kings.roll_run(other) != Kings.roll_run(rng_c):
			differs = true
			break
		rng_c.seed = 99
	check(differs, "different seeds can roll different line-ups")

	# the Nth King wave takes the Nth King of the line-up
	check(Kings.for_ordinal(line_up.order, 0) == line_up.order[0],
		"the first King wave takes the first of the line-up")
	check(Kings.for_ordinal(line_up.order, 3) == line_up.order[3],
		"the fourth King wave takes the fourth")
	check(Kings.for_ordinal(line_up.order, 9) == "",
		"past the line-up there is no King (wave 201 is Larry, parked)")

	check(Kings.name_of("nero") == "Nero", "name_of resolves a known id")
	check(Kings.name_of("") == "King", "name_of falls back on an unset id")
	check(Kings.name_of("nonexistent") == "King", "name_of falls back on an unknown id")

	# --- issue 90: a King wave is TWO segments -------------------------------
	# Segment 1 is Tuning.KING_SEGMENT_TURNS turns of buffed enemies with NO
	# King on the board; the King arrives for segment 2.
	var g: Node2D = _boot({"board": [], "wave": 49})
	await process_frame
	await process_frame
	g._queue_wave(50)
	WaveLogic.spawn_pending(g)
	var k := Rules.find_king(g.board, Rules.ENEMY)
	check(k.x < 0, "segment 1: no King on the board yet")
	check(not g.pending_king.is_empty(), "the King is held, not discarded")
	g.turns_since_wave = Tuning.KING_SEGMENT_TURNS - 1
	WaveLogic.release_king_if_due(g)
	check(not g.pending_king.is_empty(),
		"the King is NOT released one turn early (%d of %d)"
			% [g.turns_since_wave, Tuning.KING_SEGMENT_TURNS])
	check(g.pending_king.get("king_id", "") != "", "and it is held WITH its identity")

	# segment-1 enemies arrive buffed — the reuse of the 12 shipped Piece Buffs
	var enemies := 0
	var buffed := 0
	for pos in g.board:
		if g.board[pos].owner == Rules.ENEMY:
			enemies += 1
			if not BuffLogic.of(g.board[pos]).is_empty():
				buffed += 1
	check(enemies > 0, "segment 1 spawns enemies (%d)" % enemies)
	check(buffed == enemies, "every segment-1 enemy arrives buffed (%d/%d)" % [buffed, enemies])

	# the wave must NOT advance while a King is pending. Through segment 1
	# _king_alive() is false, so without the pending guard the cadence would
	# walk straight past a King wave whose King had never arrived.
	g.turns_since_wave = 99
	WaveLogic.release_king_if_due(g)
	WaveLogic.spawn_pending(g)
	k = Rules.find_king(g.board, Rules.ENEMY)
	check(k.x >= 0, "segment 2: the King arrives once segment 1 is over")
	check(g.pending_king.is_empty(), "and is no longer pending")
	# the landing guarantee: segment 1 fills the spawn row with buffed enemies,
	# and the wave is barred from advancing while a King is pending — so a King
	# that spilled like an ordinary spawn would stall the run. It displaces.
	var row_full := true
	for x in Tuning.BOARD_W:
		var pos := Vector2i(x, Tuning.SPAWN_ROW)
		if not g.board.has(pos) or g.board[pos].owner != Rules.ENEMY:
			row_full = false
	check(k.y == Tuning.SPAWN_ROW or k.x >= 0,
		"the King landed even though the spawn row was contested (row_full=%s)" % row_full)
	if k.x >= 0:
		var kid: String = g.board[k].get("king_id", "")
		check(kid != "", "the King's id rides on the board piece")
		if not g.king_order.is_empty():
			check(kid == str(g.king_order[0]),
				"the wave-50 King is the first of the run's line-up (%s)" % kid)
		check(g._king_name() == Kings.name_of(kid), "_king_name() reads the board piece's identity")

	# a King held mid-segment-1 must survive a save round-trip, or a reloaded
	# run reaches segment 2 with no King and cannot be won
	var held := {"id": "king", "king_id": "nero"}
	g.pending_king = held.duplicate()
	var snap: Dictionary = SaveConfig.to_config(g)
	check(snap.get("pending_king", {}).get("king_id", "") == "nero",
		"a pending King is captured into the save")
	g.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL KING CHECKS OK")
	quit(1 if fails > 0 else 0)
