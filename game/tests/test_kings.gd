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
const Economy := preload("res://scripts/economy.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")

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

	# --- issue 91: the Power/Ability engine ---------------------------------
	# Trump is the only King whose kit is ruled; the other 15 no-op by design.
	check(Kings.kit_of("donald_trump").has("power_name"), "Trump has a kit")
	check(Kings.kit_of("genghis_khan").is_empty(),
		"a King with no kit yet returns {} (Hat tier is unbuilt)")

	# the Power comes on with the WAVE, and is live through segment 1 — before
	# the King is on the board at all (ruling 6)
	var t: Node2D = _boot({"board": [], "wave": 49})
	await process_frame
	await process_frame
	t.king_order = ["donald_trump", "nero", "xerxes_i", "qin_shi_huang"]
	t._queue_wave(50)
	check(t.king_power_tariff != "", "the King's Power is in force during segment 1")
	check(Kings.active_id(t) == "donald_trump",
		"and the active King is resolved from the HELD King, not the board")
	var live := false
	for a in t.tariffs_active:
		if a.get("key", "") == t.king_power_tariff:
			live = true
	check(live, "the Power's Tariff is actually active, not just recorded")

	# ...and it does NOT outlive its wave. A Power that leaked into wave 51
	# would be a permanent difficulty increase nobody chose.
	t._queue_wave(51)
	check(t.king_power_tariff == "", "the Power is cleared when the wave ends")
	var leaked := false
	for a in t.tariffs_active:
		if a.get("key", "") == "inflation":
			leaked = true
	check(not leaked, "and its Tariff is removed, not left running")

	# the Ability needs the King ON THE BOARD: during segment 1 the Power is
	# live but the King has not arrived, and an Ability from a King the player
	# cannot see or attack would be unanswerable
	t._queue_wave(50)
	check(not Kings.fire_ability(t), "no Ability during segment 1 — the King is not there yet")
	check(not t.king_ability_used_this_wave, "and nothing is spent by the attempt")

	t.turns_since_wave = 99
	WaveLogic.release_king_if_due(t)
	WaveLogic.spawn_pending(t)
	t.board[Vector2i(3, 2)] = {"id": "queen", "owner": Rules.PLAYER}
	t.board[Vector2i(4, 2)] = {"id": "pawn", "owner": Rules.PLAYER}
	var before: int = t._player_pieces().size()
	check(Kings.fire_ability(t), "segment 2: the Ability fires")
	check(t.king_ability_used_this_wave, "and marks itself used")
	check(t._player_pieces().size() == before - 1,
		"JD Vance destroyed a player piece (%d -> %d)" % [before, t._player_pieces().size()])
	check(not Kings.fire_ability(t), "ONCE per Wave — a second attempt does nothing")

	# a King with no kit must not consume an Action for an Ability it lacks
	t.king_ability_used_this_wave = false
	for pos in t.board:
		if t.board[pos].get("id", "") == "king":
			t.board[pos].king_id = "genghis_khan"
	check(not Kings.fire_ability(t), "a kitless King fires nothing")
	check(not t.king_ability_used_this_wave, "and is charged no Action for it")
	t.queue_free()
	await process_frame

	# --- issue 92: the LAUREL tier, four Powers and four Abilities -----------
	for spec in [
		{"id": "nebuchadnezzar_ii", "power": "exile", "ability": "crumble"},
		{"id": "xerxes_i", "power": "host", "ability": "whip"},
		{"id": "qin_shi_huang", "power": "wall", "ability": "terracotta"},
		{"id": "nero", "power": "burns", "ability": "fire"},
	]:
		var kit: Dictionary = Kings.kit_of(spec.id)
		check(kit.get("power_key", "") == spec.power and kit.get("ability_key", "") == spec.ability,
			"%s has its Power and Ability" % Kings.name_of(spec.id))
		check(kit.power_desc != "" and kit.ability_desc != "",
			"%s's kit is described for the player" % Kings.name_of(spec.id))

	# Xerxes' Power composes with the TIER's enemy-action count rather than
	# replacing it — the same property issue 59 required of Filibuster
	var x: Node2D = _boot({"board": [], "wave": 1})
	await process_frame
	var base_actions: int = Economy.enemy_actions(x)
	x.king_power_id = "xerxes_i"
	check(Economy.enemy_actions(x) == base_actions + 1,
		"The Countless Host: +1 enemy Action on top of the tier's own (%d -> %d)"
			% [base_actions, Economy.enemy_actions(x)])
	x.king_power_id = ""
	check(Economy.enemy_actions(x) == base_actions, "and it stops when the Power ends")

	# Nero halves Gold gains, and must respect gain_immune exactly as Inflation
	# does — or Panama Papers Shredder silently stops working against Kings
	# while still working against Tariffs
	x.king_power_id = "nero"
	var ctx_gold: Dictionary = ArtefactHooks.run(x, "on_gold_gain", {"amount": 100.0, "base": 100.0})
	check(int(ctx_gold.amount) == 50, "Rome Burns: Gold gains halved (%d)" % int(ctx_gold.amount))
	var ctx_imm: Dictionary = ArtefactHooks.run(x, "on_gold_gain",
		{"amount": 100.0, "base": 100.0, "gain_immune": true})
	check(int(ctx_imm.amount) == 100, "...and gain_immune is respected, as Inflation does")

	# Qin Shi Huang doubles deploy cost — doubled, NOT blocked: blocking deploys
	# outright can strand a player into the resource-starvation game over
	x.king_power_id = "qin_shi_huang"
	var ctx_cost: Dictionary = ArtefactHooks.run(x, "on_place_cost", {"cost": 30.0, "base": 30.0})
	check(int(ctx_cost.cost) == 60, "The Great Wall: deploys cost double (%d)" % int(ctx_cost.cost))

	# Nebuchadnezzar deports captures
	x.king_power_id = "nebuchadnezzar_ii"
	check(Kings.deports_captures(x), "The Babylonian Exile deports captures")
	x.king_power_id = "nero"
	check(not Kings.deports_captures(x), "and no other King does")

	# --- the four Abilities ---
	x.king_power_id = ""
	x.board.clear()
	x.board[Vector2i(3, 10)] = {"id": "king", "owner": Rules.ENEMY, "king_id": "nebuchadnezzar_ii"}
	x.board[Vector2i(3, 3)] = {"id": "archbishop", "owner": Rules.PLAYER}
	x.board[Vector2i(4, 3)] = {"id": "pawn", "owner": Rules.PLAYER}
	x.king_ability_used_this_wave = false
	check(Kings.fire_ability(x), "The Dream of the Statue fires")
	check(x.board[Vector2i(3, 3)].id != "archbishop",
		"...and the best piece crumbled to its base (%s)" % x.board[Vector2i(3, 3)].id)
	check(x._player_pieces().size() == 2,
		"crumble DEMOTES rather than destroys — it takes the investment, not the piece")

	x.board[Vector2i(3, 10)].king_id = "xerxes_i"
	x.king_ability_used_this_wave = false
	var before_whip: int = x._player_pieces().size()
	check(Kings.fire_ability(x), "Whip the Hellespont fires")
	check(x._player_pieces().size() == before_whip,
		"...and costs POSITION, not material — nobody can be starved out by it")

	x.board[Vector2i(3, 10)].king_id = "qin_shi_huang"
	x.king_ability_used_this_wave = false
	x.pending_spawn.clear()
	check(Kings.fire_ability(x), "The Terracotta Army fires")
	check(x.pending_spawn.size() == 3, "...and marches in 3 (%d)" % x.pending_spawn.size())
	var no_king := true
	for e in x.pending_spawn:
		if e.get("id", "") == "king":
			no_king = false
	check(no_king, "...never duplicating the King itself")

	x.board[Vector2i(3, 10)].king_id = "nero"
	x.king_ability_used_this_wave = false
	x.items = [{"key": "blitz"}, {"key": "shield"}]
	x.artefacts = [{"key": "jet-fuel-vial"}]
	check(Kings.fire_ability(x), "The Fire of Rome fires")
	check(x.items.is_empty(), "...and every held Item burns")
	check(x.artefacts.size() == 1,
		"...but Artefacts do NOT — they are the run's identity, a different order of loss")
	x.queue_free()
	await process_frame
	g.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL KING CHECKS OK")
	quit(1 if fails > 0 else 0)
