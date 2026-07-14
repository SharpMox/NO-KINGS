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
	g.money = int(cfg.get("money", 0))
	g.shop_stock = cfg.get("shop_stock", []).duplicate(true)
	g.clock_ms = cfg.get("clock_s", Tuning.CLOCK_START_MS / 1000.0) * 1000.0
	# default: all designed waves done, so nothing spawns into the sandbox
	g.wave = int(cfg.get("wave", Waves.WAVES.size()))
	g.turns_since_wave = int(cfg.get("turns_since_wave", 0))
	g.early_clear_awarded = bool(cfg.get("early_clear_awarded", false))
	g.pending_reinforce = bool(cfg.get("pending_reinforce", false))
	g.kings_defeated = int(cfg.get("kings_defeated", 0))
	g.next_army = str(cfg.get("army", g.next_army)) # milestone drip draws from it
	g.lost_player = int(cfg.get("lost_player", 0))
	g.lost_enemy = int(cfg.get("lost_enemy", 0))
	g.pending_spawn = cfg.get("pending", []).duplicate(true)
	for p in cfg.get("board", []):
		var piece := {"id": p[0], "owner": int(p[1])}
		if p.size() > 4 and p[4] == "buff":
			piece.buff = true
		g.board[Vector2i(int(p[2]), int(p[3]))] = piece
	for key in cfg.get("items", []):
		for it in Items.ITEMS:
			if it.key == key:
				g.items.append(it)
	for key in cfg.get("trinkets", []):
		for t in Items.TRINKET_EFFECTS:
			if t.key == key:
				g.trinkets.append(t)
	for key in cfg.get("tariffs", []) + cfg.get("oneoffs", []):
		Economy.activate_tariff_by_key(g, key)
	if cfg.has("sanctioned_id"): # a save must restore the exact barred type
		g.sanctioned_id = cfg.sanctioned_id
	if cfg.has("tariffs_seen"): # activation above re-logged; restore the truth
		g.tariffs_seen = cfg.tariffs_seen.duplicate()
	g._begin_player_turn()
	# item-effect counters restore AFTER the turn reset (a save is always taken
	# at a turn start, so move/place/merge budgets are simply fresh)
	g.skip_enemy_turns = int(cfg.get("skip_enemy_turns", 0))


## The inverse of apply(): the live run as a JSON-safe config Dictionary.
static func to_config(g) -> Dictionary:
	var b := []
	for pos in g.board:
		var row := [g.board[pos].id, g.board[pos].owner, pos.x, pos.y]
		if g.board[pos].get("buff", false):
			row.append("buff")
		b.append(row)
	var keys_of := func(arr: Array) -> Array:
		var out := []
		for e in arr:
			out.append(e.key)
		return out
	return {
		"board": b, "stock": g.stock.duplicate(), "captured": g.captured.duplicate(),
		"items": keys_of.call(g.items), "trinkets": keys_of.call(g.trinkets),
		"tariffs": keys_of.call(g.tariffs_active), "tariffs_seen": g.tariffs_seen.duplicate(),
		"wave": g.wave, "turns_since_wave": g.turns_since_wave,
		"early_clear_awarded": g.early_clear_awarded,
		"pending_reinforce": g.pending_reinforce,
		"kings_defeated": g.kings_defeated, "army": g.next_army,
		"lost_player": g.lost_player, "lost_enemy": g.lost_enemy,
		"pending": g.pending_spawn.duplicate(true),
		"score": g.score, "money": g.money, "clock_s": g.clock_ms / 1000.0,
		"shop_stock": g.shop_stock.duplicate(true),
		"sanctioned_id": g.sanctioned_id,
		"skip_enemy_turns": g.skip_enemy_turns,
	}
