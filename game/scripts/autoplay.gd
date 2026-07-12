## Autoplay bot (headless verification) — drives one random legal action per
## frame through the live game node `g` (split out of game.gd verbatim; the
## bot deliberately pokes game internals, it is test glue, not game logic).

const Rules := preload("res://scripts/rules.gd")
const MergeLogic := preload("res://scripts/merge_logic.gd")


static func step(g) -> void:
	g.autoplay_turns += 1
	if g.autoplay_turns > g.autoplay_cap:
		# not a failure: the bot surviving this long just means no crash surfaced
		if g.autoplay_exit:
			print("AUTOPLAY CAP: alive after %d steps (wave %d, score %d)" % [g.autoplay_cap, g.wave, g.score])
			g.get_tree().quit(0)
		return
	# One random legal action per frame (everything costs one), pass when spent.
	if g.actions_left > 0:
		if not g.items.is_empty() and g.rng.randf() < 0.3: # exercise item paths
			use_item(g)
			return
		if g.turn_action_count == 0 and not g.stock.is_empty(): # ≤1 placement/turn,
			var tiles := Rules.placement_tiles(g.board)        # like the old economy
			if not tiles.is_empty():
				g._place(g.stock[g.rng.randi() % g.stock.size()], tiles[g.rng.randi() % tiles.size()])
				return
		if try_merge(g):
			return
		var moves := Rules.legal_moves(g.board, Rules.PLAYER, g.defs)
		moves = moves.filter(func(m: Dictionary) -> bool: return not g.moved_this_turn.has(m.from))
		if not moves.is_empty():
			# greedy: prefer captures so runs go deep enough to exercise waves/merges
			var caps := moves.filter(func(m: Dictionary) -> bool: return g.board.has(m.to))
			var pick: Array[Dictionary] = caps if not caps.is_empty() else moves
			var m: Dictionary = pick[g.rng.randi() % pick.size()]
			g._move_player(m.from, m.to)
			return
	g._on_pass()


static func use_item(g) -> void:
	var index: int = g.rng.randi() % g.items.size()
	var it: Dictionary = g.items[index]
	if it.target == "":
		g._use_item(index)
		return
	var a := Vector2i(-1, -1)
	var targets: Array[Vector2i] = g._item_stage_targets(it, a)
	if targets.is_empty():
		g.items.remove_at(index) # discard unusable (e.g. sniper with no valid mark)
		return
	if it.target == "pair":
		a = targets[g.rng.randi() % targets.size()]
		targets = g._item_stage_targets(it, a)
		if targets.is_empty():
			g.items.remove_at(index)
			return
	g.items.remove_at(index)
	g._item_apply(it, a, targets[g.rng.randi() % targets.size()])


## Execute one available pair merge (promotion or fusion). Returns true if merged.
static func try_merge(g) -> bool:
	var units := []
	for id in g.stock:
		units.append({"id": id, "cap": false})
	for id in g.captured:
		units.append({"id": id, "cap": true})
	for i in units.size():
		for j in range(i + 1, units.size()):
			if MergeLogic.pair_ok(g, units[i].id, units[j].id):
				MergeLogic.do_merge(g, units[i], units[j])
				return true
	return false


## Bot version: cheapest pieces first, keeping a 100-score reserve, max 4.
static func reinforce(g) -> void:
	var ids: Array = g._reinforce_ids()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(g.defs[a].value) < int(g.defs[b].value))
	for i in 4:
		var bought := false
		for id in ids:
			var cost: int = int(g.defs[id].value)
			if g.score - cost >= 100:
				g.score -= cost
				g.stock.append(id)
				bought = true
				break
		if not bought:
			return
