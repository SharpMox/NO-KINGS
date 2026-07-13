## Economy: score charges/gains, capture scoring, high-score persistence, and
## the tariff system — drives the live game node `g` (split out of game.gd;
## tariff data lives in data/tariffs.gd).

const Rules := preload("res://scripts/rules.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Tariffs := preload("res://data/tariffs.gd")


## Money cost charged when a tariffed action happens.
static func charge(g, key: String, amount: int = Tuning.TARIFF_ACTION_COST) -> void:
	if tariff_on(g, key):
		g.money = maxi(g.money - amount, 0)


## Award a gain: score counts the raw amount (up-only performance metric),
## money takes the Inflation-taxed amount. Every gain site goes through here.
static func earn(g, amount: int) -> void:
	g.score += amount
	g.money += gain(g, amount)


## Money gains pass through Inflation (-10% per stack, rounded down).
static func gain(g, amount: int) -> int:
	if g.counter_intel_turns > 0:
		return amount
	var out := float(amount)
	for t in g.tariffs_active:
		if t.key == "inflation":
			out *= 0.9
	# round, don't truncate: int() zeroed out pawn captures (1 * 0.9 -> 0)
	return roundi(out)


static func capture_score(g, victim_id: String) -> int:
	var base: int = g.defs[victim_id].value
	var pts := base
	for t in g.trinkets: # run-long passives (stack per copy)
		match t.key:
			"greed":
				if victim_id == "pawn":
					pts += 10
			"score":
				pts += 10
			"bounty":
				if base >= 50:
					pts += 30
			"lifesteal":
				g.clock_ms += 2000
			"first_capture_extra":
				if g.turn_action_count == 0:
					g.actions_left += 1
					g.actions_max += 1
	return pts


## Persist the finished run to the local high scores; returns its all-time
## rank (1-based; ties rank behind older entries).
static func record_score(g) -> int:
	var scores: Array = g.load_scores()
	var rank := 1
	for e in scores:
		if int(e.score) >= g.score:
			rank += 1
	scores.append({"score": g.score, "wave": g.wave, "kings": g.kings_defeated})
	scores.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return int(x.score) > int(y.score))
	var f := FileAccess.open(g.SCORES_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(scores.slice(0, 10)))
	return rank


# --- tariffs (penalties every 10th wave; see data/tariffs.gd) ---

static func activate_tariff(g, tier: String) -> void:
	var pool := Tariffs.TARIFFS.filter(func(t: Dictionary) -> bool:
		if t.tier != tier:
			return false
		# Mild may repeat; Moderate/Severe are run-unique (GDD Wave Catalog)
		return tier == "Mild" or not g.tariffs_seen.has(t.name))
	if pool.is_empty():
		return
	apply_tariff(g, pool[g.rng.randi() % pool.size()])


static func activate_tariff_by_key(g, key: String) -> void:
	for t in Tariffs.TARIFFS:
		if t.key == key:
			return apply_tariff(g, t)


static func apply_tariff(g, t: Dictionary) -> void:
	g.tariffs_seen.append(t.name)
	g._add_turn_fx(t.name.to_upper(), Color(1.0, 0.45, 0.35)) # tariff banner
	if t.kind == "oneoff":
		match t.key:
			"forced_audit":
				g.captured.clear()
			"asset_seizure":
				g.stock.clear()
			"asset_freeze":
				g.money /= 2
			"hostile_takeover":
				var mine: Array[Vector2i] = g._player_pieces()
				if not mine.is_empty():
					g.board[mine[g.rng.randi() % mine.size()]].owner = Rules.ENEMY
			"jd_vance":
				var best := Vector2i(-1, -1)
				for pos in g._player_pieces():
					if best.x < 0 or g.defs[g.board[pos].id].value > g.defs[g.board[best].id].value:
						best = pos
				if best.x >= 0:
					g._destroy(best)
		return
	g.tariffs_active.append(t)
	if t.key == "sanctions": # fix the barred type at trigger time
		var types := {}
		for id in g.stock + g.captured:
			types[id] = true
		if not types.is_empty():
			g.sanctioned_id = types.keys()[g.rng.randi() % types.size()]


static func tariff_on(g, key: String) -> bool:
	if g.counter_intel_turns > 0:
		return false
	for t in g.tariffs_active:
		if t.key == key:
			return true
	return false
