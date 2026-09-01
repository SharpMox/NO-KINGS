## Wave queueing and spawning — drives the live game node `g`
## (split out of game.gd; wave data lives in data/waves.gd).

const Rules := preload("res://scripts/rules.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Waves := preload("res://data/waves.gd")
const Tariffs := preload("res://data/tariffs.gd")
const Kings := preload("res://data/kings.gd")
const Economy := preload("res://scripts/economy.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")
const Shop := preload("res://scripts/shop.gd")
const Items := preload("res://data/items.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")


static func queue(g, n: int) -> void:
	g.silk_road_active = false # cleared before dispatch, so this wave-clear's
		# own on_wave_clear handler (below) can re-enable it for the wave ahead
	if n > 1: # wave 1 has no prior wave to have "cleared" (issue 16)
		var clean: bool = g.lost_player == g.wave_start_lost_player
		ArtefactHooks.run(g, "on_wave_clear", {
			"clean": clean, "turns": g.turns_since_wave,
			"captures": g.wave_capture_count, "gold_spent": g.gold_spent_shop_this_wave,
			"gold_base": g.gold, # immutable snapshot: percentage payouts stay
		}) # additive across held copies, not compounding one on the next
	g.wave = n
	g.turns_since_wave = 0
	g.wave_capture_count = 0
	for pos in g.board: # Zodiac Crossword Puzzle's Wave-scoped per-piece ledger
		g.board[pos].erase("wave_captures") # (issue 25) — the lifetime one
			# (`captures`) is untouched, only this Wave-scoped copy resets
	for entry in g.stock: # a piece Extracted mid-Wave shouldn't carry a stale
		if entry is Dictionary: # count into a Wave it never played (edge case,
			entry.erase("wave_captures") # cheap enough to close outright)
	g.gold_spent_shop_this_wave = 0
	g.wave_start_lost_player = g.lost_player
	g.wave_lost_ids = [] # Jon Burrows' Fake ID / Walt's Cryonic Capsule (26)
	g.doomsday_snooze_used_this_wave = false # Doomsday Clock Snooze Button (26)
	g.zapruder_used_this_wave = false # Zapruder's Director's Cut (52)
	g.bovine_used_this_wave = false # Bovine Tractor Beam (52)
	g.jet_fuel_used_this_wave = false # Jet Fuel Vial (52; issue 61 — moved off
		# the "Shop visit" boundary onto the same no-REGISTRY activation
		# army as zapruder/bovine above, so it resets the same way here)
	g.army_ability_used_this_wave = false # the Army Ability (67), same idiom
	g.king_ability_used_this_wave = false # the King Ability (91), same idiom again
	g.king_extra_actions = 0 # Total Mobilisation (93) ends with its wave
	g.tariffs_suppressed = false # Counter-Intel ends when the next wave arrives
	g.early_clear_awarded = false # the new wave can earn its own clear bonus
	if Tuning.REINFORCE_WAVES.has(n - 1): # that wave is done: shop at turn start
		g.pending_reinforce = true
	if n % Tuning.SHOP_RESTOCK_WAVES == 0: # issue 64 Lane A: guaranteed
		Shop.lane_a_restock(g) # restock every 5 Waves, independent of Score
	var roster: Array = Waves.WAVES[n - 1].duplicate()
	# King identity picked here, once, so the wave banner can name it (issue 09
	# selection rule: tier-ordered by King-wave depth, sampled within the tier)
	var king: Dictionary = Kings.select(g.rng, n, g.king_order) if roster.has("king") else {}
	g._add_turn_fx(("KING WAVE: %s" % king.name) if not king.is_empty() else "WAVE %d" % n,
		Color(1.0, 0.8, 0.3))
	ArtefactHooks.run(g, "on_wave_roster", {"roster": roster}) # Trade War (issue 13)
	# issue 91: the King's Power comes on with its WAVE, not with the King —
	# ruling 6 makes it live for both segments, so the 15 turns before the King
	# lands already carry that King's identity.
	Kings.apply_power(g, king.get("id", "") if not king.is_empty() else "")
	for id in roster:
		var entry := {"id": id}
		if id == "king":
			# issue 90: the King does NOT arrive with its wave. Segment 1 is
			# Tuning.KING_SEGMENT_TURNS turns of buffed enemies; the King is
			# held here and released by game.gd's turn advance.
			entry.king_id = king.id
			g.pending_king = entry
			continue
		g.pending_spawn.append(entry)
	if Tuning.TARIFFS_SCHEDULED: # off for now — see Tuning.TARIFFS_SCHEDULED
		if n == 2:
			Economy.activate_tariff_by_key(g, "inflation") # T0, GDD: fires after wave 1
		elif Tariffs.SCHEDULE.has(n):
			Economy.activate_tariff(g, Tariffs.SCHEDULE[n])
	if n % Tuning.MILESTONE_WAVES == 0:
		var ctx := ArtefactHooks.run(g, "on_clock_refill", {"refill": Tuning.CLOCK_REFILL_MS})
		Economy.add_clock(g, ctx.refill, "milestone") # Recession (issue 13) halves
			# ctx.refill via the same on_clock_refill hook, BEFORE this call — issue
			# 35 routes the actual application through the Clock choke point
		g.fx_at = Vector2(g.hud.wave_label.get_global_rect().get_center())
		Economy.earn(g, Tuning.MILESTONE_SCORE_BONUS)
		# reinforcement drip from the army's own mix (balance 2026-07-06:
		# starvation was 100% of bot deaths — nothing replenished Stock)
		var mix: Array = Tuning.ARMIES.get(g.next_army, Tuning.ARMIES[Tuning.DEFAULT_ARMY])
		for i in Tuning.MILESTONE_STOCK_DRIP:
			g.stock.append(mix[g.rng.randi() % mix.size()])
	ArtefactHooks.run(g, "on_wave_spawn", {"wave": n})


static func spawn(g, n: int) -> void:
	queue(g, n)
	spawn_pending(g)


## True when wave `n` is a King wave. Reads the catalog rather than a flag, so
## it cannot drift from what actually spawns.
static func is_king_wave(n: int) -> bool:
	return n >= 1 and n <= Waves.WAVES.size() and Waves.WAVES[n - 1].has("king")


## issue 90: release the held King once segment 1 is over. Called from the turn
## advance; a no-op when no King is pending.
static func release_king_if_due(g) -> void:
	if g.pending_king.is_empty():
		return
	if g.turns_since_wave < Tuning.KING_SEGMENT_TURNS:
		return
	# push_front, not append: the King is the event of the wave and must not
	# queue behind ordinary spawns. Appending let a full spawn row stop the
	# queue BEFORE reaching the King — the landing guarantee below only
	# inspects the head of the queue, so a King sitting behind a spilled
	# spawn never got the chance to displace.
	g.pending_spawn.push_front(g.pending_king)
	g.pending_king = {}
	g._add_turn_fx("THE KING ARRIVES", Color(1.0, 0.45, 0.35))


static func spawn_pending(g) -> void:
	while not g.pending_spawn.is_empty():
		# spawns land on any top-row tile not held by an enemy; a friendly piece
		# there is captured by the arrival (so the spawn row can't be blockaded)
		var open: Array[Vector2i] = []
		for x in Tuning.BOARD_W:
			var pos := Vector2i(x, Tuning.SPAWN_ROW)
			if not g.board.has(pos) or g.board[pos].owner == Rules.PLAYER:
				open.append(pos)
		# issue 90: THE KING MUST ALWAYS LAND. Ordinary spawns spill to the next
		# player turn when the row is full of enemies, which is fine because the
		# wave advances anyway. A King cannot spill: the wave is barred from
		# advancing while it is pending, and segment 1 deliberately fills the row
		# with buffed enemies — so "wait for space" is a stall the player may not
		# be able to clear. It displaces one of its own instead.
		var next_is_king: bool = not g.pending_spawn.is_empty() \
			and g.pending_spawn[0].has("king_id")
		if open.is_empty():
			if not next_is_king:
				return # row full of enemies — spill to next player turn
			open = []
			for x in Tuning.BOARD_W:
				open.append(Vector2i(x, Tuning.SPAWN_ROW))
		var spot: Vector2i = open[g.rng.randi() % open.size()]
		var entry: Dictionary = g.pending_spawn.pop_front()
		if g.board.has(spot) and g.board[spot].owner == Rules.PLAYER:
			g.lost_player += 1 # arrival captures a friendly blockading the row
		# an enemy displaced by a King arrival is simply absorbed: it is not a
		# player capture, so it must not score, pay Gold or fire on_capture
		g.board[spot] = {"id": entry.id, "owner": Rules.ENEMY}
		if entry.has("king_id"):
			g.board[spot].king_id = entry.king_id
		elif is_king_wave(g.wave):
			# issue 90: segment-1 enemies arrive buffed. BuffLogic.add rather
			# than g._apply_buff — the latter is the PLAYER's grant choke point
			# and fires on_buff_apply, which would run the player's Artefacts
			# on an enemy spawn.
			# Napoleon: La Grande Armee — reinforcements arrive better equipped.
			var buffs: int = Tuning.KING_SEGMENT_BUFFS \
				+ (1 if Kings.power_is(g, "grande") else 0)
			for _i in buffs:
				var pool: Array = Items.PIECE_BUFFS
				var pick: Dictionary = pool[g.rng.randi() % pool.size()]
				BuffLogic.add(g.board[spot], pick.key)
