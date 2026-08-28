## Run-state serialization: the config Dictionary a save restores from and a
## scenario boots from — over the live game node `g` (split out of game.gd;
## the shape is documented in data/scenarios.gd).

const Tuning := preload("res://scripts/tuning.gd")
const Waves := preload("res://data/waves.gd")
const Items := preload("res://data/items.gd")
const Economy := preload("res://scripts/economy.gd")


## Start the game from a config Dictionary instead of the normal SETUP flow.
## Every field of run state is settable — the same mechanism a saved game
## will restore from.
static func apply(g, cfg: Dictionary) -> void:
	g.stock = cfg.get("stock", []).duplicate()
	g.captured = cfg.get("captured", []).duplicate()
	g.score = int(cfg.get("score", 0)) # int(): JSON numbers arrive as floats
	g.gold = int(cfg.get("gold", 0))
	g.shop_stock = cfg.get("shop_stock", []).duplicate(true)
	g.shop_restocks = int(cfg.get("shop_restocks", 0)) # no reroll-scumming
	# GDD Game Flow — Run: restore the run's RNG so a resumed save rolls what an
	# uninterrupted run would have. Seed first — assigning it resets the state.
	# Both travel as strings: they are int64 and JSON numbers are doubles.
	if cfg.has("seed"):
		g.rng.seed = int(cfg.seed)
	if cfg.has("rng_state"): # mid-stream, not back at the top of it
		g.rng.state = int(cfg.rng_state)
	g.clock_ms = cfg.get("clock_s", Tuning.CLOCK_START_MS / 1000.0) * 1000.0
	# default: all designed waves done, so nothing spawns into the sandbox
	g.wave = int(cfg.get("wave", Waves.WAVES.size()))
	g.turns_since_wave = int(cfg.get("turns_since_wave", 0))
	g.early_clear_awarded = bool(cfg.get("early_clear_awarded", false))
	g.pending_reinforce = bool(cfg.get("pending_reinforce", false))
	g.kings_defeated = int(cfg.get("kings_defeated", 0))
	g.king_ids_defeated = cfg.get("king_ids_defeated", []).duplicate()
	g.next_army = str(cfg.get("army", g.next_army)) # milestone drip draws from it
	g.next_rank = str(cfg.get("rank", g.next_rank)) # locked at run start, Continue keeps it
	g.lost_player = int(cfg.get("lost_player", 0))
	g.lost_enemy = int(cfg.get("lost_enemy", 0))
	g.pending_spawn = cfg.get("pending", []).duplicate(true)
	for p in cfg.get("board", []):
		var piece := {"id": p[0], "owner": int(p[1])}
		# slot 4 is the piece's non-positional state. Legacy saves and the
		# scenario table write the bare string "buff" (box carrier); anything
		# richer — piece buffs — travels as a Dictionary merged in whole.
		if p.size() > 4:
			if typeof(p[4]) == TYPE_STRING:
				piece.buff = true
			elif typeof(p[4]) == TYPE_DICTIONARY:
				piece.merge(p[4], true)
		g.board[Vector2i(int(p[2]), int(p[3]))] = piece
	for key in cfg.get("items", []):
		for it in Items.ITEMS:
			if it.key == key:
				g.items.append(it)
	for key in cfg.get("artefacts", []):
		for t in Items.ARTEFACT_EFFECTS:
			if t.key == key:
				g.artefacts.append(t)
	for key in cfg.get("tariffs", []) + cfg.get("oneoffs", []):
		Economy.activate_tariff_by_key(g, key)
	if cfg.has("sanctioned_id"): # a save must restore the exact barred type
		g.sanctioned_id = cfg.sanctioned_id
	if cfg.has("tariffs_seen"): # activation above re-logged; restore the truth
		g.tariffs_seen = cfg.tariffs_seen.duplicate()
	g.tariffs_suppressed = cfg.get("tariffs_off", false)
	g._begin_player_turn()
	# item-effect counters restore AFTER the turn reset (a save is always taken
	# at a turn start, so move/place/merge budgets are simply fresh)
	g.skip_enemy_turns = int(cfg.get("skip_enemy_turns", 0))


## The inverse of apply(): the live run as a JSON-safe config Dictionary.
static func to_config(g) -> Dictionary:
	var b := []
	for pos in g.board:
		var row := [g.board[pos].id, g.board[pos].owner, pos.x, pos.y]
		var extra: Dictionary = g.board[pos].duplicate(true)
		extra.erase("id")
		extra.erase("owner")
		if not extra.is_empty(): # box-carrier flag and/or piece buffs
			row.append(extra)
		b.append(row)
	var keys_of := func(arr: Array) -> Array:
		var out := []
		for e in arr:
			out.append(e.key)
		return out
	return {
		"board": b, "stock": g.stock.duplicate(), "captured": g.captured.duplicate(),
		"items": keys_of.call(g.items), "artefacts": keys_of.call(g.artefacts),
		"tariffs": keys_of.call(g.tariffs_active), "tariffs_seen": g.tariffs_seen.duplicate(),
		"wave": g.wave, "turns_since_wave": g.turns_since_wave,
		"early_clear_awarded": g.early_clear_awarded,
		"pending_reinforce": g.pending_reinforce,
		"kings_defeated": g.kings_defeated, "king_ids_defeated": g.king_ids_defeated.duplicate(),
		"army": g.next_army, "rank": g.next_rank,
		"lost_player": g.lost_player, "lost_enemy": g.lost_enemy,
		"pending": g.pending_spawn.duplicate(true),
		"score": g.score, "gold": g.gold, "clock_s": g.clock_ms / 1000.0,
		"shop_stock": g.shop_stock.duplicate(true),
		"shop_restocks": g.shop_restocks,
		"sanctioned_id": g.sanctioned_id,
		"skip_enemy_turns": g.skip_enemy_turns,
		"tariffs_off": g.tariffs_suppressed,
		"seed": str(g.rng.seed), "rng_state": str(g.rng.state),
	}
