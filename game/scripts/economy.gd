## Economy: score charges/gains, capture scoring, high-score persistence, and
## the tariff system — drives the live game node `g` (split out of game.gd;
## tariff data lives in data/tariffs.gd).

const Rules := preload("res://scripts/rules.gd")
const Shop := preload("res://scripts/shop.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Tariffs := preload("res://data/tariffs.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")
const CloudSave := preload("res://scripts/cloud_save.gd")


## Gold cost charged when a tariffed action happens.
static func charge(g, key: String, amount: int = Tuning.TARIFF_ACTION_COST) -> void:
	if tariff_on(g, key):
		g.gold = maxi(g.gold - amount, 0)


## Award a gain: score counts the raw amount (up-only performance metric),
## gold takes the Inflation-taxed amount. Every gain site goes through here.
## `reason` tags the source for hook handlers that must not fire on every
## gain (e.g. an early-clear-only multiplier) — most callers leave it "".
## Score/Gold percentage artefacts hook in here (issue 16), ADDITIVE off an
## immutable ctx.base so multiple copies/artefacts never compound (matches
## the on_capture stacking rule in artefact_hooks.gd).
static func earn(g, amount: int, reason: String = "") -> void:
	var score_ctx := ArtefactHooks.run(g, "on_score_change",
		{"base": float(amount), "amount": float(amount), "reason": reason})
	g.score += roundi(score_ctx.amount)
	var gold_amount := gain(g, amount)
	var gold_ctx := ArtefactHooks.run(g, "on_gold_change",
		{"base": float(gold_amount), "amount": float(gold_amount), "reason": reason})
	g.gold += roundi(gold_ctx.amount)
	Shop.maybe_restock(g) # the shelf refreshes on score, not on waves


## Gold gains pass through Inflation (-10% per stack, rounded down).
static func gain(g, amount: int) -> int:
	if g.tariffs_suppressed: # Counter-Intel pauses persistent tariffs too
		return amount
	var out := float(amount)
	for t in g.tariffs_active:
		if t.key == "inflation":
			out *= 0.9
	# round, don't truncate: int() zeroed out pawn captures (1 * 0.9 -> 0)
	return roundi(out)


## `attacker_id`/`attacker_buffed` describe the capturing piece (board[from],
## still intact when the two call sites in game.gd call this) — "" / false
## when no attacker applies (e.g. direct test calls), which every
## attacker-dependent handler treats as "no match" (issue 16). `attacker_pos`
## (issue 18) is that same board position, Vector2i(-1,-1) when it doesn't
## apply, so a handler can grant something to the attacking piece itself
## (Obedience-Flavored Tap Water, Holy Lint) instead of just reading its id.
static func capture_score(g, victim_id: String, attacker_id: String = "",
		attacker_buffed: bool = false, attacker_pos: Vector2i = Vector2i(-1, -1)) -> int:
	var base: int = g.defs[victim_id].value
	var ctx := ArtefactHooks.run(g, "on_capture", {
		"victim_id": victim_id, "base": base, "pts": base,
		"attacker_id": attacker_id, "attacker_buffed": attacker_buffed,
		"attacker_pos": attacker_pos,
		"wave_capture_index": g.wave_capture_count, # captures already made
		"turn_capture_index": g.turn_capture_count, # this wave/turn, 0-based
	})
	g.wave_capture_count += 1
	g.turn_capture_count += 1
	return ctx.pts


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
	CloudSave.sync_file("scores", g.SCORES_PATH) # mirror to the platform backend (12)
	return rank


const HISTORY_CAP := 50 # newest-first log; capped so the file can't grow forever


## Games History: every real run's end-screen summary (05-menus-and-settings)
## — distinct from the ranked top-10 Highscores above.
static func record_history(g, won: bool) -> void:
	var history: Array = g.load_history()
	history.push_front({
		"score": g.score, "wave": g.wave, "kings": g.kings_defeated,
		"tariffs": g.tariffs_seen.size(), "lost": g.lost_player, "won": won,
	})
	var f := FileAccess.open(g.HISTORY_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(history.slice(0, HISTORY_CAP)))
	CloudSave.sync_file("history", g.HISTORY_PATH) # mirror to the platform backend (12)


# --- tariffs (penalties every 10th wave; see data/tariffs.gd) ---

static func activate_tariff(g, tier: String) -> void:
	# rank lever (b): Officer/Autocrat draw one tier harsher, capped at Severe
	# (07-difficulty-ranks) — a binary bump, like the Shop clock-pause lever
	if g.next_rank != Tuning.RANKS[0]:
		var i: int = Tariffs.TIER_ORDER.find(tier)
		tier = Tariffs.TIER_ORDER[mini(i + 1, Tariffs.TIER_ORDER.size() - 1)]
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
				g.gold /= 2
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
		for e in g.stock + g.captured:
			types[e if e is String else e.id] = true
		if not types.is_empty():
			g.sanctioned_id = types.keys()[g.rng.randi() % types.size()]


static func tariff_on(g, key: String) -> bool:
	if g.tariffs_suppressed: # Counter-Intel (CONTEXT.md: Tariff suppression)
		return false
	for t in g.tariffs_active:
		if t.key == key:
			return true
	return false
