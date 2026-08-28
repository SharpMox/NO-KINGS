## Wave queueing and spawning — drives the live game node `g`
## (split out of game.gd; wave data lives in data/waves.gd).

const Rules := preload("res://scripts/rules.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Waves := preload("res://data/waves.gd")
const Tariffs := preload("res://data/tariffs.gd")
const Kings := preload("res://data/kings.gd")
const Economy := preload("res://scripts/economy.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")


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
	g.gold_spent_shop_this_wave = 0
	g.wave_start_lost_player = g.lost_player
	g.tariffs_suppressed = false # Counter-Intel ends when the next wave arrives
	g.early_clear_awarded = false # the new wave can earn its own clear bonus
	if Tuning.REINFORCE_WAVES.has(n - 1): # that wave is done: shop at turn start
		g.pending_reinforce = true
	var buff_id: String = Waves.BUFFS.get(n, "")
	var roster: Array = Waves.WAVES[n - 1].duplicate()
	# King identity picked here, once, so the wave banner can name it (issue 09
	# selection rule: tier-ordered by King-wave depth, sampled within the tier)
	var king: Dictionary = Kings.select(g.rng, n) if roster.has("king") else {}
	g._add_turn_fx(("KING WAVE: %s" % king.name) if not king.is_empty() else "WAVE %d" % n,
		Color(1.0, 0.8, 0.3))
	if Economy.tariff_on(g, "trade_war"): # +1 piece per wave, drawn from the wave's own mix
		var extras: Array = roster.filter(func(id: String) -> bool: return id != "king")
		if not extras.is_empty(): # never duplicate the King (review 2026-07-03)
			roster.append(extras[g.rng.randi() % extras.size()])
	for id in roster:
		var entry := {"id": id}
		if id == "king":
			entry.king_id = king.id
		if id == buff_id: # first spawned piece of the flagged type carries the box
			entry.buff = true
			buff_id = ""
		g.pending_spawn.append(entry)
	if n == 2:
		Economy.activate_tariff_by_key(g, "inflation") # T0, GDD: fires after wave 1
	elif Tariffs.SCHEDULE.has(n):
		Economy.activate_tariff(g, Tariffs.SCHEDULE[n])
	if n % Tuning.MILESTONE_WAVES == 0:
		var ctx := ArtefactHooks.run(g, "on_milestone", {"refill": Tuning.CLOCK_REFILL_MS})
		var refill: float = ctx.refill
		if Economy.tariff_on(g, "recession"):
			refill *= 0.5
		g.clock_ms += refill
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


static func spawn_pending(g) -> void:
	while not g.pending_spawn.is_empty():
		# spawns land on any top-row tile not held by an enemy; a friendly piece
		# there is captured by the arrival (so the spawn row can't be blockaded)
		var open: Array[Vector2i] = []
		for x in Tuning.BOARD_W:
			var pos := Vector2i(x, Tuning.SPAWN_ROW)
			if not g.board.has(pos) or g.board[pos].owner == Rules.PLAYER:
				open.append(pos)
		if open.is_empty():
			return # row full of enemies — spill to next player turn
		var spot: Vector2i = open[g.rng.randi() % open.size()]
		var entry: Dictionary = g.pending_spawn.pop_front()
		if g.board.has(spot): # arrival captures a friendly blockading the row
			g.lost_player += 1
		g.board[spot] = {"id": entry.id, "owner": Rules.ENEMY}
		if entry.get("buff", false):
			g.board[spot].buff = true
		if entry.has("king_id"):
			g.board[spot].king_id = entry.king_id
