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
	# Artefact activation (issue 52) costs 0 Actions, so it's tried up front,
	# independent of actions_left below — a bot that never presses these new
	# chips would prove nothing about the feature.
	if g.state == g.State.PLAYER_TURN and g.rng.randf() < 0.25:
		try_activate_artefact(g)
	# One random legal action per frame (everything costs one), pass when spent.
	if g.actions_left > 0:
		# The Army Ability (67) costs 1 Action, unlike Artefact activation
		# above — tried here, inside the actions_left gate, alongside items/
		# merges/moves rather than up front. A bot that never presses it
		# would prove nothing about the feature; try_activate_army_ability
		# returns false (no-op, falls through) when unavailable so an
		# unlucky roll never wastes a frame.
		if g.rng.randf() < 0.15 and try_activate_army_ability(g):
			return
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
	if it.target == "multi": # pick one random piece and confirm
		g._use_item(index)
		g.item_selected.append(targets[g.rng.randi() % targets.size()])
		return g._item_confirm_multi()
	if it.target == "pair":
		a = targets[g.rng.randi() % targets.size()]
		targets = g._item_stage_targets(it, a)
		if targets.is_empty():
			g.items.remove_at(index)
			return
	g.items.remove_at(index)
	g._item_apply(it, a, targets[g.rng.randi() % targets.size()])


## Artefact activation (issue 52): one random HELD activatable key, activated
## if available. The 5 confirm-gated ones resolve instantly under autoplay
## (g._activate_artefact's own autoplay bypass); Bovine Tractor Beam has no
## confirm to bypass — its targeting is plain board-click state, so the bot
## drives both stages itself, the same way use_item above drives a "pair" Item.
static func try_activate_artefact(g) -> void:
	var keys: Array = g._activatable_held_keys()
	if keys.is_empty():
		return
	var key: String = keys[g.rng.randi() % keys.size()]
	if key != "bovine-tractor-beam":
		if g._artefact_activation_available(key):
			g._activate_artefact(key)
		return
	if not g._artefact_activation_available(key):
		return
	g._begin_artefact_targeting(key)
	if g.artefact_targets.is_empty(): # shouldn't happen (availability already
		return                        # checked both stages), never leave it stuck
	var a: Vector2i = g.artefact_targets[g.rng.randi() % g.artefact_targets.size()]
	g._artefact_target_click(a)
	if g.artefact_targets.is_empty():
		return
	var b: Vector2i = g.artefact_targets[g.rng.randi() % g.artefact_targets.size()]
	g._artefact_target_click(b)


## The Army Ability (67/68): The Muster's Call the Banners is one targeted
## case (a Stock pick, not a board tile) — resolved via `rng` the same way
## _open_box_pick/every other autoplay modal is, so the bot never stalls on
## the confirm modal or leaves targeting stuck. Hostile Takeover (Syndicate)/
## Ritual (Cult) are the other targeted case, a board pick — driven the same
## two-call way try_activate_artefact drives Bovine Tractor Beam above. Wild
## Hunt/Old Guard/Horde are untargeted — g._activate_army_ability's own
## autoplay bypass (mirroring _activate_artefact's) resolves those
## immediately. Returns whether it actually activated.
static func try_activate_army_ability(g) -> bool:
	if not g._army_ability_available():
		return false
	if g.next_army == "Crown":
		g._begin_army_targeting()
		if g.stock.is_empty(): # availability already checked this; never leave
			g._army_targeting_reset() # targeting stuck with nothing to pick
			return false
		g._army_target_stock(g.stock[g.rng.randi() % g.stock.size()], false)
		return true
	if g.next_army == "Syndicate" or g.next_army == "Cult":
		g._begin_army_board_targeting()
		if g.army_board_targets.is_empty(): # availability already checked
			g._army_board_targeting_reset() # this; never leave it stuck
			return false
		var t: Vector2i = g.army_board_targets[g.rng.randi() % g.army_board_targets.size()]
		g._army_board_target_click(t)
		return true
	g._activate_army_ability()
	return true


## Execute one available pair merge (promotion or fusion). Returns true if merged.
static func try_merge(g) -> bool:
	var units := []
	for e in g.stock:
		units.append({"id": (e if e is String else e.id), "cap": false, "entry": e})
	for id in g.captured:
		units.append({"id": id, "cap": true, "entry": id})
	for i in units.size():
		for j in range(i + 1, units.size()):
			if MergeLogic.pair_ok(g, units[i].id, units[j].id):
				# issue 98: do_merge now REFUSES when the Gold is short, and
				# this function used to report success on "found a legal pair"
				# rather than on "the merge happened". With a pair in hand and
				# no Gold that made step() return every frame having done
				# nothing — a live-lock that burned the whole step budget at
				# wave 2. Check the payment before claiming the turn's action.
				if not MergeLogic.can_afford_merge(g):
					return false # fall through to moves/captures instead
				MergeLogic.do_merge(g, units[i], units[j])
				return true
	return false


## Bot version: the panel is free now — grab the 4 cheapest offers.
static func reinforce(g) -> void:
	var ids: Array = g._reinforce_ids()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(g.defs[a].value) < int(g.defs[b].value))
	for i in 4:
		g.stock.append(ids[i % ids.size()])
