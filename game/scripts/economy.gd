## NOTE (issue 66, 2026-08-30): the design-facing name for this mechanic is
## now "King Ability" — "Tariff" survives only as Donald Trump's King Power
## (data/kings.gd). Code identifiers below (tariff_on, apply_king_ability,
## resolve_king_ability, etc.) are deliberately left as "tariff"; the rename lands
## with the coming Kings + Tariffs rework, which restructures this code
## rather than just renaming it.
##
## Economy: score charges/gains, capture scoring, high-score persistence, and
## the tariff system — drives the live game node `g` (split out of game.gd;
## tariff data lives in data/tariffs.gd).

const Rules := preload("res://scripts/rules.gd")
const Shop := preload("res://scripts/shop.gd")
const Tuning := preload("res://scripts/tuning.gd")
const KingAbilities := preload("res://data/king_abilities.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")
const CloudSave := preload("res://scripts/cloud_save.gd")
const Leaderboard := preload("res://scripts/leaderboard.gd") # set-union sync
const Armies := preload("res://scripts/armies.gd")

## Issue 57: the Shop's restock thresholds (Shop.threshold, since replaced
## entirely by the issue-64 two-lane restock) were unreachable —
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
## on_item_consume/on_king_ability_charge/on_piece_lost/on_destroy effects in
## artefact_hooks.gd), are x10'd individually at their own literal instead.
const SCORE_MULTIPLIER := 10


## Gold cost charged when a tariffed action happens. Dispatches on_charge
## (issue 13) with ctx.key set to the specific tariff being charged; the
## matching held tariff (if any, and only Counter-Intel's suppression is
## checked centrally by ArtefactHooks.run) sets ctx.charged. When it does,
## on_king_ability_charge (issue 19) fires right after — "whenever a Tariff charges
## you" — a single choke point since every call site already funnels through
## here. `base`/`amount` (issue 22) let Ark Grounding Cable scale the amount
## before it's deducted — same immutable-base/additive-amount contract as
## on_score_change, off ctx.base, never the running ctx.amount.
## NO-105: a Tariff bills a percentage of a reference value, rounded DOWN with
## a floor of 1 so a cheap asset is still taxed something. Every tariff call
## site goes through here so the rounding rule lives in one place.
static func tariff_cut(base: int, pct: float) -> int:
	return maxi(1, int(floor(float(base) * pct)))


## Does this Tariff actually fire right now? king_abilities_active holds the
## tariff DICTIONARIES, not their keys, so a `"key" in` membership test is
## silently always false — that shipped once (NO-105) and killed the
## Long-Range tariff outright. Suppression is part of the answer: while
## Counter-Intel holds, no tariff charges at all.
static func tariff_fires(g, key: String) -> bool:
	if g.king_abilities_suppressed:
		return false
	for t in g.king_abilities_active:
		if t.key == key:
			return true
	return false


static func charge(g, key: String, amount: int = Tuning.KING_ABILITY_ACTION_COST) -> void:
	var ctx := ArtefactHooks.run(g, "on_charge",
		{"key": key, "charged": false, "base": float(amount), "amount": float(amount)})
	if ctx.charged:
		var charged_amount := roundi(ctx.amount) # issue 22: Ark Grounding Cable scales this
		spend_gold(g, charged_amount) # issue 26: floor + on_gold_zero (Zero-Point Energy Drink)
		g.tariff_charges[key] = g.tariff_charges.get(key, 0) + charged_amount # NO-109: per-tariff attribution
		g._add_turn_fx("%s −$%d" % [ability_name(key), charged_amount], g.BANNER_LOSS, key)
		ArtefactHooks.run(g, "on_king_ability_charge", {"key": key, "amount": charged_amount})


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
## NO-239: `label` is what the kill feed says the gain was for ("captured
## Knight"); "" falls back to the artefact named by `reason`. `icon` is the
## piece token the line shows (the victim, the piece sold), or null.
static func earn(g, amount: int, reason: String = "", label: String = "",
		icon: Texture2D = null) -> void:
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
	var score_bonus_amount := roundi(gold_ctx.score_bonus) * SCORE_MULTIPLIER
	g.score += score_amount + score_bonus_amount # ONE write: the score setter
		# pops per assignment, and two writes showed two "+N" for one event
		# (Tungsten-Filled Gold Bar / Popemobile Piggy Bank)
	g.gold += gold_gain + roundi(score_ctx.gold_bonus)
	_feed(g, reason, label, score_amount + score_bonus_amount, gold_gain + roundi(score_ctx.gold_bonus), icon)
	Shop.add_score_progress(g, score_amount + score_bonus_amount) # issue 64
		# Lane B: banks toward the next Score-driven restock (Lane A, every 5
		# Waves, is independent of this and lives in wave_logic.gd instead)


## Gold gains pass through Inflation (-10% per stack, rounded down). Each
## held Inflation copy dispatches on_gold_gain once (issue 13), multiplying
## ctx.amount — the deliberate multiplicative-stacking exception documented
## in artefact_hooks.gd. round(), don't truncate: int() zeroed out pawn
## captures (1 * 0.9 -> 0).
static func gain(g, amount: int) -> int:
	var ctx := ArtefactHooks.run(g, "on_gold_gain", {"amount": float(amount)})
	return roundi(ctx.amount)


## Gold-only gain (issue 60): selling and Captured -> Stock conversion pay/
## charge Gold with no Score involved — the same asymmetry Buy already has
## (Shop.buy debits Gold only, never grants Score). Mirrors earn()'s Gold
## half exactly (Inflation via gain(), on_gold_change for Denver Bunker
## Timeshare et al., the Moscovium triple, and score_bonus for a Gold->Score
## converter like Popemobile Piggy Bank) without the Score/SCORE_MULTIPLIER
## half, so a sale doesn't also score. Called from game.gd's _sell(), AFTER
## the sold entry is already removed — Denver Bunker Timeshare's "+30% Gold
## while Items are full" must see the POST-sale Item count, so selling the
## Item that fills the last slot correctly does NOT get its own bonus.
static func earn_gold(g, amount: int, reason: String = "", label: String = "",
		icon: Texture2D = null) -> void:
	var gold_amount := gain(g, amount)
	var gold_ctx := ArtefactHooks.run(g, "on_gold_change",
		{"base": float(gold_amount), "amount": float(gold_amount), "reason": reason, "score_bonus": 0.0})
	var gold_gain := roundi(gold_ctx.amount)
	if g.moscovium_active: # Moscovium Glow Stick (52): "Score and Gold gains
		# are tripled" — same deliberate multiplicative exception earn() applies
		gold_gain *= 3
	g.gold += gold_gain
	var score_bonus_amount := roundi(gold_ctx.score_bonus) * SCORE_MULTIPLIER
	g.score += score_bonus_amount
	_feed(g, reason, label, score_bonus_amount, gold_gain, icon)
	Shop.add_score_progress(g, score_bonus_amount) # issue 64 Lane B: harmless
		# no-op unless a converter artefact's score_bonus just crossed it


## NO-239: every earn()/earn_gold() lands one kill-feed line per label per
## frame (hud.feed_gain coalesces), so this is the feed's one choke point for
## gains with a game reason. Artefacts' own direct writes post from
## artefact_hooks.gd (_dispatch) instead.
static func _feed(g, reason: String, label: String, score: int, gold: int,
		icon: Texture2D = null) -> void:
	if label == "":
		label = ArtefactHooks.artefact_name(reason) if reason != "" else "Score"
	g.hud.feed_gain(label, label, score, gold, "", icon)


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
		"exhibit_destroys": 0, # NO-81: Exhibit 399's OUTPUT count, +1 per held
			# copy on the Turn's first Capture; _move_player reads it back off
			# g.last_capture_ctx and destroys that many adjacent enemies
	})
	if Armies.blood_in_the_air(g) and g.turn_action_count == 0: # Wild Hunt
		# (67): "your first capture each Turn refunds its Action" — the exact
		# same condition/effect as the core `first_capture_extra` Artefact's
		# own on_capture handler (artefact_hooks.gd _dispatch), deliberately
		# NOT folded into that handler: held together the two must stack
		# ADDITIVELY (two refunds), so this is its own independent check at
		# the same call site, not a second REGISTRY entry reading the same
		# ctx. g.turn_action_count is still 0 here — this call always runs
		# BEFORE the caller's own _log_action increments it (game.gd
		# _move_player), same ordering first_capture_extra relies on.
		g.actions_left += 1
		g.actions_max += 1
		g._add_turn_fx("Wild Hunt: Action refunded", g.BANNER_GAIN)
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
	# Null-checked: a failed open here would crash at game over, taking the whole
	# result screen with it. Closed before the mirror, which reads the file back
	# through a separate handle. Same shape as the autosave in game.gd.
	var f := FileAccess.open(g.SCORES_PATH, FileAccess.WRITE)
	if f == null:
		push_error("scores: could not write %s (error %d)"
			% [g.SCORES_PATH, FileAccess.get_open_error()])
		return rank
	f.store_string(JSON.stringify(scores.slice(0, 10)))
	f = null # close before the mirror reads the file back through its own handle
	CloudSave.sync_file("scores", g.SCORES_PATH,
		Leaderboard.merger_for("scores")) # union, never pick-a-side
	return rank


## Re-exported from Tuning so Economy.HISTORY_CAP keeps working for its existing
## readers; Tuning is the single definition (NO-37).
const HISTORY_CAP := Tuning.HISTORY_CAP


## Games History: every real run's end-screen summary (05-menus-and-settings)
## — distinct from the ranked top-10 Highscores above.
static func record_history(g, won: bool) -> void:
	var history: Array = g.load_history()
	history.push_front({
		"score": g.score, "wave": g.wave, "kings": g.kings_defeated,
		"king_abilities": g.king_abilities_seen.size(), "lost": g.lost_player, "won": won,
	})
	var f := FileAccess.open(g.HISTORY_PATH, FileAccess.WRITE)
	if f == null:
		push_error("history: could not write %s (error %d)"
			% [g.HISTORY_PATH, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(history.slice(0, HISTORY_CAP)))
	f = null # close before the mirror reads it back
	CloudSave.sync_file("history", g.HISTORY_PATH,
		Leaderboard.merger_for("history")) # union


# --- King Abilities (data/king_abilities.gd; reached through Kings only) ---

static func activate_king_ability_by_key(g, key: String) -> void:
	for t in KingAbilities.ABILITIES:
		if t.key == key:
			return apply_king_ability(g, t)


## Catalog display name for a King Ability key — the one name every banner
## uses (the charge banner above, kings.gd's escalation banner), never the
## raw key.
static func ability_name(key: String) -> String:
	for t in KingAbilities.ABILITIES:
		if t.key == key:
			return str(t.name)
	return key.replace("_", " ")


## Single choke point for every Tariff taking effect (oneoff or persistent) —
## "whenever a new Tariff is applied" (artefact hook 19) fires here, once,
## regardless of which of the two activate_* callers led here. `cancel`
## (issue 22) is Salvation Gift Card's veto — mirrors on_item_consume's
## ctx.cancel (issue 19): the tariff never takes effect, but same-hook reward
## handlers (e.g. Merchants of Death Sample Case) still fire regardless of
## key-sort order, the same precedent as on_piece_lost's Fireproof Pajamas
## (artefact hook 24) rather than reordering the dispatch to favor one
## handler over another.
static func apply_king_ability(g, t: Dictionary) -> void:
	g.king_abilities_seen.append(t.name)
	g._add_turn_fx(t.name.to_upper(), Color(1.0, 0.45, 0.35)) # tariff banner
	var ctx := ArtefactHooks.run(g, "on_king_ability_apply",
		{"key": t.key, "tier": t.get("tier", ""), "cancel": false})
	if ctx.cancel:
		return
	resolve_king_ability(g, t)


## The Tariff's actual effect — split out of apply_king_ability (issue 54).
static func resolve_king_ability(g, t: Dictionary) -> void:
	if t.kind == "oneoff": # JD Vance is the only one-off left (NO-95)
		if t.key == "jd_vance":
			var best := Vector2i(-1, -1)
			for pos in g._player_pieces():
				if best.x < 0 or g.defs[g.board[pos].id].value > g.defs[g.board[best].id].value:
					best = pos
			if best.x >= 0:
				g._destroy(best)
		return
	g.king_abilities_active.append(t)


# --- issue 13: narrow query wrappers for the keys that gate/modify behaviour
# rather than charge gold — each just unpacks the ctx an ArtefactHooks.run()
# call filled in, mirroring earn()/gain()/capture_score() above for artefacts.

## False when a King Power (Genghis Khan) blocks this merge pair.
static func merge_ok(g, a: String, b: String) -> bool:
	return not ArtefactHooks.run(g, "on_merge_check", {"a": a, "b": b, "blocked": false}).blocked


## Placement gold cost, doubled by Qin Shi Huang's Power.
static func deploy_cost(g) -> int:
	return ArtefactHooks.run(g, "on_place_cost", {"cost": Tuning.PLACEMENT_COST}).cost


## Enemy actions this turn — 2 at Tier 5, 1 at Tiers 1-4 (issue 59), plus King Powers.
static func enemy_actions(g) -> int:
	return enemy_turn_ctx(g).actions


## The whole on_enemy_turn_start ctx: `actions` plus `notes`, the names of
## whatever changed the count (Y2K Patch, Xerxes, Total Mobilisation) for the
## ENEMY TURN banner (game.gd _enemy_turn_text). Dispatch ONCE per turn —
## Y2K Patch disarms itself in here.
static func enemy_turn_ctx(g) -> Dictionary:
	return ArtefactHooks.run(g, "on_enemy_turn_start",
		{"actions": Tuning.enemy_actions_per_turn(g.next_tier), "notes": []})
