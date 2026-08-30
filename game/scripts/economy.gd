## Economy: score charges/gains, capture scoring, high-score persistence, and
## the tariff system — drives the live game node `g` (split out of game.gd;
## tariff data lives in data/tariffs.gd).

const Rules := preload("res://scripts/rules.gd")
const Shop := preload("res://scripts/shop.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Tariffs := preload("res://data/tariffs.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")
const CloudSave := preload("res://scripts/cloud_save.gd")

## Issue 57: the Shop's restock thresholds (Shop.threshold) were unreachable —
## median Crown run ends near Score 300, first threshold is 1000 — so Score
## income rises 10x instead of the thresholds dropping. Applied HERE, in
## earn() below, the single choke point every ordinary Score gain already
## routes through (piece captures, wave-clear/early-clear/milestone/win
## bonuses, flat Artefact Score grants that call Economy.earn) — not by
## multiplying `defs[id].value`, which is ALSO the Gold/Shop-price number
## (shop.gd price()/on_capture threshold comparisons/_sample_pieces
## weighting all read it unscaled) and would 10x every price. Gold from the
## same gain stays untouched: gain() below derives Gold from the raw
## `amount`, never the x10'd Score. Handlers that write g.score directly,
## bypassing earn() (a handful of on_wave_clear/on_purchase/on_game_over/
## on_item_consume/on_tariff_charge/on_piece_lost/on_destroy effects in
## artefact_hooks.gd), are x10'd individually at their own literal instead.
const SCORE_MULTIPLIER := 10


## Gold cost charged when a tariffed action happens. Dispatches on_charge
## (issue 13) with ctx.key set to the specific tariff being charged; the
## matching held tariff (if any, and only Counter-Intel's suppression is
## checked centrally by ArtefactHooks.run) sets ctx.charged. When it does,
## on_tariff_charge (issue 19) fires right after — "whenever a Tariff charges
## you" — a single choke point since every call site already funnels through
## here. `base`/`amount` (issue 22) let Ark Grounding Cable scale the amount
## before it's deducted — same immutable-base/additive-amount contract as
## on_score_change, off ctx.base, never the running ctx.amount.
static func charge(g, key: String, amount: int = Tuning.TARIFF_ACTION_COST) -> void:
	var ctx := ArtefactHooks.run(g, "on_charge",
		{"key": key, "charged": false, "base": float(amount), "amount": float(amount)})
	if ctx.charged:
		var charged_amount := roundi(ctx.amount) # issue 22: Ark Grounding Cable scales this
		spend_gold(g, charged_amount) # issue 26: floor + on_gold_zero (Zero-Point Energy Drink)
		ArtefactHooks.run(g, "on_tariff_charge", {"key": key, "amount": charged_amount})


## Debit gold, floored at `floor_at` (0 for every call site here; Shop.buy
## passes a negative floor for Agartha Welcome Mat's credit line — it can't
## call this directly, shop.gd would cycle back through this file's own
## `const Shop` preload, so it inlines the same 3 lines instead — see there).
## Zero-Point Energy Drink (issue 26) watches every debit for landing exactly
## on 0 (and not already there before this spend) — +2 Actions that Turn.
static func spend_gold(g, amount: int, floor_at: int = 0) -> void:
	var before: int = g.gold
	g.gold = maxi(g.gold - amount, floor_at)
	if before > 0 and g.gold == 0:
		ArtefactHooks.run(g, "on_gold_zero", {})


## Award a gain: score counts the raw amount (up-only performance metric),
## gold takes the Inflation-taxed amount. Every gain site goes through here.
## `reason` tags the source for hook handlers that must not fire on every
## gain (e.g. an early-clear-only multiplier) — most callers leave it "".
## Score/Gold percentage artefacts hook in here (issue 16), ADDITIVE off an
## immutable ctx.base so multiple copies/artefacts never compound (matches
## the on_capture stacking rule in artefact_hooks.gd). `gold_bonus`/
## `score_bonus` (issue 20) are the cross-resource side-payment channels for
## converter handlers (El Dorado Body Glitter, Tungsten-Filled Gold Bar,
## Popemobile Piggy Bank) — pre-seeded 0.0, applied exactly once here, never
## written by a handler directly (see artefact_hooks.gd's CONTRACT comment).
## Issue 57: the on_score_change dispatch itself stays off the UNSCALED
## `amount` — every percentage handler (and El Dorado's ctx.gold_bonus,
## computed off this same immutable base) is unaffected by SCORE_MULTIPLIER,
## so a Score-based Gold conversion doesn't also inflate 10x. Only the
## dispatch's OUTPUT (`score_amount`, and the symmetric Gold->Score
## `gold_ctx.score_bonus`) is scaled, right before it lands on g.score —
## mathematically identical to scaling every percentage handler's own
## literal, since `(base + base*pct) * k == (base*k) + (base*k)*pct`.
static func earn(g, amount: int, reason: String = "") -> void:
	var score_ctx := ArtefactHooks.run(g, "on_score_change",
		{"base": float(amount), "amount": float(amount), "reason": reason, "gold_bonus": 0.0})
	var score_amount := roundi(score_ctx.amount) * SCORE_MULTIPLIER
	var gold_amount := gain(g, amount)
	var gold_ctx := ArtefactHooks.run(g, "on_gold_change",
		{"base": float(gold_amount), "amount": float(gold_amount), "reason": reason, "score_bonus": 0.0})
	var gold_gain := roundi(gold_ctx.amount)
	if g.moscovium_active: # Moscovium Glow Stick (issue 52): "Score and Gold
		# gains are tripled" — a deliberate multiplicative exception
		# (artefact_hooks.gd header), applied here directly rather than
		# through the REGISTRY/run() per-held-copy dispatch: the effect must
		# keep working AFTER the artefact consumes itself and leaves
		# g.artefacts, when there is no held copy left to dispatch from.
		# Scoped to this call's own base gain (score_amount / the post-
		# Inflation gold_gain), not the cross-resource gold_bonus/score_bonus
		# converter payments below, which are a different artefact's own
		# conversion, layered on top.
		score_amount *= 3
		gold_gain *= 3
	g.score += score_amount
	g.gold += gold_gain + roundi(score_ctx.gold_bonus)
	g.score += roundi(gold_ctx.score_bonus) * SCORE_MULTIPLIER
	Shop.maybe_restock(g) # the shelf refreshes on score, not on waves


## Gold gains pass through Inflation (-10% per stack, rounded down). Each
## held Inflation copy dispatches on_gold_gain once (issue 13), multiplying
## ctx.amount — the deliberate multiplicative-stacking exception documented
## in artefact_hooks.gd. round(), don't truncate: int() zeroed out pawn
## captures (1 * 0.9 -> 0).
static func gain(g, amount: int) -> int:
	var ctx := ArtefactHooks.run(g, "on_gold_gain", {"amount": float(amount)})
	return roundi(ctx.amount)


## Clock choke point (issue 35), mirroring earn()/gain(): every direct
## `clock_ms +=` gain site — milestone/King refills, the Continue bonus, the
## early-clear and turn-end bonuses, and every artefact/item/tariff that
## grants time — now routes through here instead, so on_clock_change (Black
## Knight Morse Code's first listener) has one place to hook. Same
## immutable-base/additive-amount ctx contract as on_score_change/
## on_gold_change (artefact_hooks.gd header CONTRACT). `ms` can be negative —
## a Clock *loss* (e.g. Nigerian Prince Wire Transfer) routes through the
## same call, so on_clock_change sees the whole picture; a handler that only
## wants to react to gains (Black Knight) guards `ctx.base > 0` itself,
## same as Score/Gold handlers gate on their own `reason`/conditions.
## The one deliberate exception is game.gd's `_process` per-frame drain —
## a continuous tick, not a discrete gain, so hooking it would fire every
## frame; see the comment at that call site.
static func add_clock(g, ms: float, reason: String = "") -> void:
	var ctx := ArtefactHooks.run(g, "on_clock_change",
		{"base": ms, "amount": ms, "reason": reason})
	g.clock_ms = maxf(g.clock_ms + ctx.amount, 0.0)


## `attacker_id`/`attacker_buffed` describe the capturing piece (board[from],
## still intact when the two call sites in game.gd call this) — "" / false
## when no attacker applies (e.g. direct test calls), which every
## attacker-dependent handler treats as "no match" (issue 16). `attacker_pos`
## (issue 18) is that same board position, Vector2i(-1,-1) when it doesn't
## apply, so a handler can grant something to the attacking piece itself
## (Obedience-Flavored Tap Water, Holy Lint) instead of just reading its id.
## `return_to_start`/`move_to_backrow` (issue 24) are output flags for
## handlers that want to reposition the capturing piece — the ctx itself is
## stashed on `g.last_capture_ctx` (a Dictionary reference survives the call
## boundary this int return value can't) so `_move_player` can read them back
## AFTER its own board mutation runs; see artefact_hooks.gd's header.
## `victim_pos` (issue 25) is board[to]/board[also] — still intact here too —
## read into `victim_captures` BEFORE the caller erases it, for Chupacabra
## Chew Toy's "the captured piece had captured one of yours" (a piece can
## only capture a player piece, so any lifetime captures > 0 qualifies).
## attacker_pos also bumps the attacker's own ledger here (g._note_capture)
## before the hook runs, so an on_capture handler in the same dispatch (Alien
## Rocket Toy) already sees this capture counted.
## `run_capture_index` (issue 55) is the run-long sibling of wave/turn_capture_
## index above (g.run_capture_count, never resets). `to_stock` is the same
## output-flag shape as return_to_start/move_to_backrow — Zeta Reticuli
## Souvenir Map sets it on the run's every 3rd capture; game.gd's capture
## sites divert the victim into Stock (state intact, ADR-0002) instead of
## Captured Stock when it's set.
static func capture_score(g, victim_id: String, attacker_id: String = "",
		attacker_buffed: bool = false, attacker_pos: Vector2i = Vector2i(-1, -1),
		victim_pos: Vector2i = Vector2i(-1, -1)) -> int:
	var base: int = g.defs[victim_id].value
	if attacker_pos.x >= 0 and g.board.has(attacker_pos):
		g._note_capture(attacker_pos)
	var victim_captures: int = g.board[victim_pos].get("captures", 0) \
		if victim_pos.x >= 0 and g.board.has(victim_pos) else 0
	var ctx := ArtefactHooks.run(g, "on_capture", {
		"victim_id": victim_id, "base": base, "pts": base,
		"attacker_id": attacker_id, "attacker_buffed": attacker_buffed,
		"attacker_pos": attacker_pos, "victim_captures": victim_captures,
		"wave_capture_index": g.wave_capture_count, # captures already made
		"turn_capture_index": g.turn_capture_count, # this wave/turn, 0-based
		"run_capture_index": g.run_capture_count, # issue 55: same idiom, but
			# run-long — Zeta Reticuli Souvenir Map's "every 3rd Capture"
			# needs a count that never resets on a wave/turn boundary, unlike
			# the two siblings above
		"return_to_start": false, "move_to_backrow": false,
		"to_stock": false, # issue 55: Zeta Reticuli Souvenir Map's OUTPUT
			# flag — set true on the run's every 3rd capture; read back off
			# g.last_capture_ctx at game.gd's capture sites, same shape as
			# return_to_start/move_to_backrow above
		"no_score": false, # issue 42: Dark Market Light Bulb's "Demoted pieces
			# give no Score" — an OUTPUT flag, not a direct ctx.pts write, so it
			# doesn't depend on whether a same-hook `+=` handler dispatches
			# before or after it (run()'s key-sort); applied exactly once,
			# below, after every on_capture handler has finished — same
			# pattern as gold_bonus/score_bonus above.
		"grant_buffs": [], # tiers ("" = any) an on_capture handler wants to hand
			# the attacker (Obedience-Flavored Tap Water, Holy Lint) — an OUTPUT
			# list, not applied here: _move_player reads it back off
			# g.last_capture_ctx (same shape as return_to_start/move_to_backrow
			# above) and lands the grant AFTER its own critical/range
			# consumption, so the new buff is banked for the NEXT capture
			# instead of being doubled/spent by this one (ruled 2026-08-28 —
			# see game.gd's _move_player).
	})
	g.wave_capture_count += 1
	g.turn_capture_count += 1
	g.run_capture_count += 1
	if ctx.no_score:
		ctx.pts = 0
	g.last_capture_ctx = ctx
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
	# Tariffs behave identically at every difficulty tier (07-difficulty-ranks
	# rework — the severity-shift lever was rejected as illegible).
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


## Single choke point for every Tariff taking effect (oneoff or persistent) —
## "whenever a new Tariff is applied" (artefact hook 19) fires here, once,
## regardless of which of the two activate_* callers led here. `cancel`
## (issue 22) is Salvation Gift Card's veto — mirrors on_item_consume's
## ctx.cancel (issue 19): the tariff never takes effect, but same-hook reward
## handlers (e.g. Merchants of Death Sample Case) still fire regardless of
## key-sort order, the same precedent as on_piece_lost's Fireproof Pajamas
## (artefact hook 24) rather than reordering the dispatch to favor one
## handler over another. `choice` (issue 22/54) is Exhibit 399's — the actual
## effect (resolve_tariff below) is deferred to game.gd's choice-pick
## callback instead of running here; Salvation's automatic cancel still wins
## outright if both are somehow held (ctx.cancel is checked first).
static func apply_tariff(g, t: Dictionary) -> void:
	g.tariffs_seen.append(t.name)
	g._add_turn_fx(t.name.to_upper(), Color(1.0, 0.45, 0.35)) # tariff banner
	var ctx := ArtefactHooks.run(g, "on_tariff_apply",
		{"key": t.key, "tier": t.get("tier", ""), "cancel": false, "choice": false})
	if ctx.cancel:
		return
	if ctx.choice:
		return g._open_exhibit_choice(t)
	resolve_tariff(g, t)


## The Tariff's actual effect — split out of apply_tariff (issue 54) so
## Exhibit 399 can defer this half behind a player choice while the banner
## and the on_tariff_apply dispatch above still fire immediately, exactly as
## they always did (Merchants of Death Sample Case's own reward doesn't wait
## on the pick either).
static func resolve_tariff(g, t: Dictionary) -> void:
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


# --- issue 13: narrow query wrappers for the tariff keys that gate/modify
# behaviour rather than charge gold — each just unpacks the ctx an
# ArtefactHooks.run() call filled in, mirroring earn()/gain()/capture_score()
# above for artefacts. Replaces the ad hoc `if tariff_on(g, "...")` branches
# that used to sit inline at every call site (see artefact_hooks.gd header).

## True when `id` (an uncaptured piece type) is barred from placement by
## Sanctions.
static func sanctioned(g, id: String) -> bool:
	return ArtefactHooks.run(g, "on_sanction_check", {"id": id, "blocked": false}).blocked


## False when Regulation blocks this merge pair (a fielded Pawn on either side).
static func merge_ok(g, a: String, b: String) -> bool:
	return not ArtefactHooks.run(g, "on_merge_check", {"a": a, "b": b, "blocked": false}).blocked


## Placement gold cost, doubled by Austerity.
static func deploy_cost(g) -> int:
	return ArtefactHooks.run(g, "on_place_cost", {"cost": Tuning.PLACEMENT_COST}).cost


## Enemy actions this turn — 2 at Tier 5, 1 at Tiers 1-4 (issue 59), +1 under Filibuster.
static func enemy_actions(g) -> int:
	return ArtefactHooks.run(g, "on_enemy_turn_start",
		{"actions": Tuning.enemy_actions_per_turn(g.next_tier)}).actions
