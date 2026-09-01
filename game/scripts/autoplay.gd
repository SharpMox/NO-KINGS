## Autoplay bot (headless verification) — drives one random legal action per
## frame through the live game node `g` (split out of game.gd verbatim; the
## bot deliberately pokes game internals, it is test glue, not game logic).

const Rules := preload("res://scripts/rules.gd")
const MergeLogic := preload("res://scripts/merge_logic.gd")
const Shop := preload("res://scripts/shop.gd") # issue 103


static func step(g) -> void:
	g.autoplay_turns += 1
	if g.autoplay_turns > g.autoplay_cap:
		# not a failure: the bot surviving this long just means no crash surfaced
		if g.autoplay_exit:
			print("AUTOPLAY CAP: alive after %d steps (wave %d, score %d)" % [g.autoplay_cap, g.wave, g.score])
			# issue 103: a capped run MUST still emit its row. It is the run
			# that lived longest, so dropping it biases the batch against the
			# bot's best play — which is the opposite of what this harness is
			# for. Filed as its own result (CAP), never as a LOSS.
			print(g._telemetry_csv("CAP", "Outlived the step cap"))
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
		# issue 103: economy before board actions. Both are cheap no-ops when
		# they do not apply, and neither costs an Action (Shop purchases are
		# free by issue 64; conversion is Gold-only), so this cannot starve the
		# turn budget the way an extra board move would.
		if try_shop(g):
			return
		if try_convert(g):
			return
		if not g.items.is_empty() and g.rng.randf() < 0.3 and use_item(g):
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


## issue 103. Two bugs lived here, and both corrupted every balance run:
##
## 1. The tile/pair paths did `g.items.remove_at(index)` and called _item_apply
##    directly, BYPASSING _consume_item — the choke point that fires
##    on_item_consume and honours the "the Item is not consumed" veto. So the 7
##    Artefacts listening on that hook were inert in every measured run, and
##    Dihydrogen Monoxide Battery / Wardenclyffe AAA Batteries could never fire
##    at all. The UI path is _consume_item then _item_apply; this now matches it.
## 2. An Item with no legal target was DISCARDED. It left the inventory without
##    ever being used, which is why item_use read 0 while the bot "used items".
##    Now an untargetable Item is simply skipped and kept for a later turn.
##
## Returns whether an Item was actually used, so the caller does not burn its
## turn slot on a no-op.
static func use_item(g) -> bool:
	# Rotate the starting index off the SEEDED stream (g.rng) rather than
	# Array.shuffle(), which draws from the global RNG — a pinned seed has to
	# reproduce a run exactly (issue 75), and the playtest harness depends on it.
	var start: int = g.rng.randi() % g.items.size()
	for k in g.items.size():
		var index: int = (start + k) % g.items.size()
		var it: Dictionary = g.items[index]
		if it.target == "":
			g._use_item(index) # _use_item consumes instant Items itself
			return true
		var a := Vector2i(-1, -1)
		var targets: Array[Vector2i] = g._item_stage_targets(it, a)
		if targets.is_empty():
			continue # keep it: unusable THIS turn is not unusable forever
		if it.key == "buff_box":
			# Buff Box is the one Item whose effect needs state the direct
			# _item_apply path below never sets: _item_click assigns
			# `_buff_pick = pending_buff`, and pending_buff is only filled by
			# the buff-pick step inside _use_item. Applying it directly grants
			# a buff with an EMPTY key — a meaningless entry occupying one of
			# the two cap slots. So this one goes through the real UI path,
			# which autoplay can drive because _open_buff_pick has its own
			# bot bypass (game.gd: "take one so the flow is exercised").
			g._use_item(index)
			if g.item_active < 0 or g.item_targets.is_empty():
				continue
			g._item_click(g.item_targets[g.rng.randi() % g.item_targets.size()])
			return true
		if it.target == "multi": # pick one random piece and confirm
			g._use_item(index)
			g.item_selected.append(targets[g.rng.randi() % targets.size()])
			g._item_confirm_multi() # consumes via _consume_item itself
			return true
		if it.target == "pair":
			a = targets[g.rng.randi() % targets.size()]
			targets = g._item_stage_targets(it, a)
			if targets.is_empty():
				continue
		g._consume_item(index, it) # the hook + veto path the UI uses
		g._item_apply(it, a, targets[g.rng.randi() % targets.size()])
		return true
	return false


## issue 103: SHOP. The bot bought NOTHING, ever — the measured cause of death
## was "Resource starvation" in runs that ended holding five figures of unspent
## Gold, while the Shop sells pieces. That made every tier-difficulty number
## this project has quoted a measurement of the bot's floor.
##
## Buys through Shop.buy — the same function the panel calls — rather than
## driving the modal. Autoplay deliberately avoids modals (see
## try_activate_artefact's own bypass), and Shop purchases cost no Action
## (issue 64), so nothing about the turn budget changes.
##
## BOXES ARE SKIPPED: Shop.buy grants nothing for a box (the roll modal IS the
## grant, shop.gd), so buying one the bot never opens would burn Gold for
## nothing.
const LOW_STOCK := 3 # below this, deployable material is the binding constraint


static func try_shop(g) -> bool:
	# Pieces first while Stock is thin — that is the resource the bot actually
	# runs out of. Otherwise take the cheapest thing it can hold, so a full
	# wallet keeps converting into board presence.
	var passes: Array = [["item", "artefact", "piece"]]
	if g.stock.size() < LOW_STOCK:
		passes.push_front(["piece"])
	for kinds in passes:
		var pick := -1
		for i in g.shop_stock.size():
			var slot: Dictionary = g.shop_stock[i]
			if not kinds.has(slot.kind) or not Shop.can_buy(g, slot):
				continue
			if pick < 0 or Shop.price(g, slot) < Shop.price(g, g.shop_stock[pick]):
				pick = i
		if pick >= 0:
			return Shop.buy(g, pick)
	return false


## issue 103: Captured Stock -> Stock. Captured pieces can merge but never
## deploy (issue 60), so a bot with an empty Stock and a full Captured Stock is
## out of deployable material while holding the cure. Costs Gold, which is
## exactly the point — it is the other half of the same starvation.
static func try_convert(g) -> bool:
	if not g.stock.is_empty() or g.captured.is_empty():
		return false
	for e in g.captured.duplicate():
		if g._convert_captured(e):
			return true
	return false


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
