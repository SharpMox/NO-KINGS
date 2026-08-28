extends SceneTree
## The 16-King cast (issue 09): roster shape, the tier-by-depth selection
## rule, and that a spawned King carries its identity onto the board.
## Run headless:  godot --headless --path game -s tests/test_kings.gd

const Kings := preload("res://data/kings.gd")
const Rules := preload("res://scripts/rules.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const GameScript := preload("res://scripts/game.gd")

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

	# --- selection rule: tier-ordered by King-wave depth ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var picks := {
		50: Kings.LAUREL, 100: Kings.HAT, 150: Kings.UNIFORM,
	}
	for n in picks:
		var king: Dictionary = Kings.select(rng, n)
		var tier: String = picks[n]
		check(Kings.ROSTER[tier].any(func(k: Dictionary) -> bool: return k.id == king.id),
			"wave %d King is drawn from the %s tier" % [n, tier])

	check(Kings.name_of("nero") == "Nero", "name_of resolves a known id")
	check(Kings.name_of("") == "King", "name_of falls back on an unset id")
	check(Kings.name_of("nonexistent") == "King", "name_of falls back on an unknown id")

	# --- a queued King wave attaches an identity that lands on the board ---
	var g: Node2D = _boot({"board": [], "wave": 49})
	await process_frame
	await process_frame
	g._queue_wave(50)
	WaveLogic.spawn_pending(g)
	var k := Rules.find_king(g.board, Rules.ENEMY)
	check(k.x >= 0, "wave 50 spawns a King onto the board")
	if k.x >= 0:
		var kid: String = g.board[k].get("king_id", "")
		check(Kings.ROSTER[Kings.LAUREL].any(func(e: Dictionary) -> bool: return e.id == kid),
			"the spawned wave-50 King is Laurel-tier, and its id rides on the board piece")
		check(g._king_name() == Kings.name_of(kid), "_king_name() reads the board piece's identity")
	g.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL KING CHECKS OK")
	quit(1 if fails > 0 else 0)
