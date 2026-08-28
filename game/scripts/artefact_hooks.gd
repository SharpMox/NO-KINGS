## Artefact trigger engine — drives the live game node `g`. Dispatches artefact
## effects at named hook points instead of the ad hoc `for t in artefacts: if
## t.key == "move"` that used to be scattered through game.gd/economy.gd/
## wave_logic.gd. Fine for the 7 core effects (data/items.gd:ARTEFACT_EFFECTS_
## CORE); unworkable for the 180-entry catalog (data/artefacts.json) slices
## 16-20 wire in one at a time. This is that slice 13 (hook architecture)
## arriving against a real consumer — see .scratch/gdd-gaps/issues/13 and 15.
##
## HOOKS lists every trigger point the GDD effect texts imply. REGISTRY maps
## an artefact key to the hooks it listens on; ADD_HANDLER (the match in
## _dispatch) is where its logic lives. Adding artefact #8 means one REGISTRY
## line + one match case — never touching a call site again.
##
## STACKING: the same artefact can be held more than once — each copy is its
## own entry in g.artefacts (save_config.gd, shop.gd). run() dispatches once
## per held copy, so percentage/flat modifiers from repeats are ADDITIVE: two
## Greeds add +10 and +10, not +10 compounded multiplicatively. This is how
## the 7 core effects already behaved (each copy ran its own loop iteration
## pre-migration) and is simplest to reason about at 180 artefacts. A
## multiplicative artefact would be a deliberate, called-out exception inside
## its own handler. Covered by test_items.gd ("two Greeds stack additively").
##
## ORDERING: run() sorts the held artefacts by key before dispatching, so a
## value built from several artefacts touching the same number never depends
## on acquisition order. Handlers must be commutative for a fixed multiset of
## keys — true of all 7 today (every one just adds to a counter). Covered by
## test_items.gd ("Greed+Score" order doesn't change the total).
##
## issue 16 (Gold/Score batch) added:
## - on_score_change / on_gold_change (Economy.earn/economy.gd), ctx =
##   {base, amount, reason}. `base` is the untouched pre-artefact amount for
##   this one gain; every percentage handler does `ctx.amount += ctx.base *
##   pct` — reading from the immutable base (never the running `amount`) is
##   what keeps two held copies additive instead of compounding. `reason` is
##   "" for most gains; a few call sites tag one (e.g. "early_clear") so a
##   handler can scope itself to that specific gain without seeing every
##   other earn() in the game.
## - on_capture ctx grew `attacker_id`/`attacker_buffed` (board[from].id /
##   whether it carries a Piece Buff, read while the piece is still on the
##   board — "" / false from the two direct-call test sites, which every
##   attacker-dependent handler treats as "doesn't apply") and
##   `wave_capture_index`/`turn_capture_index` (captures already made this
##   wave/turn, 0-based, tracked centrally in Economy.capture_score so no
##   handler has to).
## - on_wave_clear (WaveLogic.queue, only n > 1) ctx = {clean, turns,
##   captures, gold_spent, gold_base} — all snapshotted before queue() resets
##   the underlying counters for the new wave, and `gold_base` in particular
##   keeps "N% of current Gold" handlers additive across held copies for the
##   same reason `ctx.base` does above. on_wave_spawn fires right after, for
##   the wave that's starting.
## - on_game_over (game.gd:_game_over, before the run is scored/saved) — new
##   hook, added to HOOKS below; Rapture Insurance Policy is its first user.

const Rules := preload("res://scripts/rules.gd")

const HOOKS := [
	"on_capture", "on_piece_lost", "on_deploy",
	"on_wave_clear", "on_wave_spawn", "on_milestone",
	"on_turn_start", "on_turn_end", "on_shop_restock", "on_purchase",
	"on_gold_change", "on_score_change", "on_box_open", "on_game_over",
]

## Artefact key -> hooks it fires on. The source of truth for "does this
## artefact do anything at this hook" — _dispatch is just the handler body.
const REGISTRY := {
	"greed": ["on_capture"],
	"score": ["on_capture"],
	"bounty": ["on_capture"],
	"lifesteal": ["on_capture"],
	"first_capture_extra": ["on_capture"],
	"move": ["on_turn_start"],
	"timer": ["on_milestone"],
	# --- issue 16: Gold/Score batch (31 artefacts, no needs-note) ---
	"tinfoil-hat": ["on_score_change", "on_gold_change"],
	"daylight-savings-jar": ["on_score_change", "on_gold_change"],
	"the-red-phone": ["on_score_change", "on_gold_change"],
	"bermuda-triangulation": ["on_score_change", "on_gold_change"],
	"naruto-run-manual": ["on_score_change"],
	"moon-landing-slate": ["on_score_change"],
	"el-dorado-body-glitter": ["on_score_change"],
	"tungsten-filled-gold-bar": ["on_gold_change"],
	"popemobile-piggy-bank": ["on_gold_change"],
	"suspiciously-large-femur": ["on_capture"],
	"sphinx-s-booger": ["on_capture"],
	"phantom-punch-glove": ["on_capture"],
	"azimuthal-pancake-map": ["on_capture"],
	"men-in-black-prescription-sunglasses": ["on_capture"],
	"holy-dna-kit": ["on_capture"],
	"cia-press-pass": ["on_capture"],
	"library-of-alexandria-matchbox": ["on_capture"],
	"voynich-dictionary": ["on_capture"],
	"nero-s-marshmallow-stick": ["on_capture"],
	"zurich-gnome-figurine": ["on_wave_clear"],
	"social-credit-report-card": ["on_wave_clear"],
	"qanon-profile-picture": ["on_wave_clear"],
	"bielefeld-library-card": ["on_wave_clear"],
	"trilateral-meeting-stickers": ["on_wave_clear"],
	"money-printer-service-manual": ["on_wave_clear"],
	"alien-autopsy-bloopers": ["on_wave_clear"],
	"golden-buddha-bobblehead": ["on_wave_clear"],
	"nigerian-prince-wire-transfer": ["on_wave_spawn"],
	"john-titor-s-crypto-wallet": ["on_milestone"],
	"putin-s-golden-toilet-brush": ["on_purchase"],
	"rapture-insurance-policy": ["on_game_over"],
}


## Run every held artefact's handler for `hook`, key-sorted, mutating and
## returning `ctx`. Handlers write to `ctx` for values the caller reads back
## (e.g. a score total) and touch `g` directly for side effects (clock,
## actions) — exactly what the pre-migration call sites did inline.
static func run(g, hook: String, ctx: Dictionary = {}) -> Dictionary:
	var held: Array = g.artefacts.duplicate()
	held.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.key < b.key)
	for t in held:
		if REGISTRY.get(t.key, []).has(hook):
			_dispatch(g, t.key, hook, ctx)
	return ctx


## Player-owned board pieces of the given id — the "2+/3+ of your same-type
## pieces" synergy check (Men in Black, Holy DNA Kit).
static func _count_player_id(g, id: String) -> int:
	var n := 0
	for pos in g.board:
		if g.board[pos].owner == Rules.PLAYER and g.board[pos].id == id:
			n += 1
	return n


static func _dispatch(g, key: String, hook: String, ctx: Dictionary) -> void:
	match [key, hook]:
		["greed", "on_capture"]:
			if ctx.victim_id == "pawn":
				ctx.pts += 10
		["score", "on_capture"]:
			ctx.pts += 10
		["bounty", "on_capture"]:
			if ctx.base >= 50:
				ctx.pts += 30
		["lifesteal", "on_capture"]:
			g.clock_ms += 2000
		["first_capture_extra", "on_capture"]:
			if g.turn_action_count == 0:
				g.actions_left += 1
				g.actions_max += 1
		["move", "on_turn_start"]:
			g.actions_left += 1
		["timer", "on_milestone"]:
			ctx.refill += 5000

		# --- issue 16: percentage Score/Gold gain modifiers ---
		["tinfoil-hat", "on_score_change"]:
			ctx.amount += ctx.base * 0.15
		["tinfoil-hat", "on_gold_change"]:
			ctx.amount -= ctx.base * 0.05
		["daylight-savings-jar", "on_score_change"]:
			if g.clock_ms > 90000.0:
				ctx.amount += ctx.base * 0.20
			elif g.clock_ms < 30000.0:
				ctx.amount -= ctx.base * 0.20 # a smaller gain, never negative (issue 16 ruling)
		["daylight-savings-jar", "on_gold_change"]:
			if g.clock_ms > 90000.0:
				ctx.amount += ctx.base * 0.10
			elif g.clock_ms < 30000.0:
				ctx.amount -= ctx.base * 0.10
		["the-red-phone", "on_score_change"]:
			if g.clock_ms < 30000.0:
				ctx.amount += ctx.base * 1.00
		["the-red-phone", "on_gold_change"]:
			if g.clock_ms < 30000.0:
				ctx.amount += ctx.base * 0.50
		["bermuda-triangulation", "on_score_change"]:
			if g.clock_ms < 60000.0:
				ctx.amount += ctx.base * 0.50
		["bermuda-triangulation", "on_gold_change"]:
			if g.clock_ms < 60000.0:
				ctx.amount += ctx.base * 0.25
		["naruto-run-manual", "on_score_change"]:
			# "x2 Score" on the early-clear bonus (early-clear tracking already
			# exists — game.gd _on_pass) = +1x more, additive per held copy
			if ctx.reason == "early_clear" and g.turns_since_wave <= 3:
				ctx.amount += ctx.base
		["moon-landing-slate", "on_score_change"]:
			if ctx.reason == "early_clear" and g.turns_since_wave <= 2:
				ctx.amount += ctx.base * 9.0 # "x10 Score" = +9x more
		["el-dorado-body-glitter", "on_score_change"]:
			g.gold += roundi(ctx.amount * 0.05) # reads the (possibly
				# already-modified) score ctx, pays a slice straight to Gold

		# --- issue 16: Gold gain also pays Score (mirror of the above) ---
		["tungsten-filled-gold-bar", "on_gold_change"]:
			g.score += roundi(ctx.amount) * 2
		["popemobile-piggy-bank", "on_gold_change"]:
			g.score += roundi(ctx.amount) * 10

		# --- issue 16: on_capture triggers ---
		["suspiciously-large-femur", "on_capture"]:
			var is_max := true
			for pos in g.board:
				if g.board[pos].owner == Rules.ENEMY and int(g.defs[g.board[pos].id].value) > ctx.base:
					is_max = false
					break
			if is_max:
				ctx.pts += 150
				g.gold += 3
		["sphinx-s-booger", "on_capture"]:
			if ctx.attacker_id != "" and int(g.defs[ctx.attacker_id].value) < ctx.base:
				ctx.pts += 100
				g.gold += 10
		["phantom-punch-glove", "on_capture"]:
			if ctx.attacker_id != "":
				var av: int = g.defs[ctx.attacker_id].value
				if av < ctx.base: # lower-value piece takes a higher-value one: double
					ctx.pts += ctx.base
				elif av > ctx.base: # higher-value piece takes a lower-value one: half
					ctx.pts -= roundi(ctx.base * 0.5)
		["azimuthal-pancake-map", "on_capture"]:
			if ctx.attacker_id.begins_with("inv-"):
				ctx.pts += ctx.base # double
		["men-in-black-prescription-sunglasses", "on_capture"]:
			if ctx.attacker_id != "" and _count_player_id(g, ctx.attacker_id) >= 2:
				ctx.pts += roundi(ctx.base * 0.25)
		["holy-dna-kit", "on_capture"]:
			if ctx.attacker_id != "" and _count_player_id(g, ctx.attacker_id) >= 3:
				ctx.pts += ctx.base # double Score and (via the shared pts->gold
					# pipeline in Economy.earn) proportionally double Gold too
		["cia-press-pass", "on_capture"]:
			if ctx.attacker_buffed:
				ctx.pts += ctx.base # double Score
				g.gold += roundi(ctx.base * 0.5) # +50% Gold
		["library-of-alexandria-matchbox", "on_capture"]:
			var n: int = g.stock.size()
			ctx.pts += 10 * n
			g.gold += n
		["voynich-dictionary", "on_capture"]:
			if ctx.wave_capture_index == 0: # first Capture this Wave
				ctx.pts += ctx.base # double Score and Gold
		["nero-s-marshmallow-stick", "on_capture"]:
			# "+25% more than the previous capture" — a linear +25%-per-copy
			# step off the untouched base, so it stacks additively like every
			# other percentage handler here instead of compounding
			ctx.pts += roundi(ctx.base * 0.25 * ctx.turn_capture_index)

		# --- issue 16: on_wave_clear triggers ---
		["zurich-gnome-figurine", "on_wave_clear"]:
			g.gold += roundi(ctx.gold_spent * 0.10)
		["social-credit-report-card", "on_wave_clear"]:
			if ctx.clean:
				g.score += 100
			else: # issue 16 ruling: the -10 Score penalty debits Gold instead
				g.gold = maxi(g.gold - 10, 0)
		["qanon-profile-picture", "on_wave_clear"]:
			if ctx.clean:
				g.score += 200
				g.gold += 20
		["bielefeld-library-card", "on_wave_clear"]:
			if ctx.captures == 0:
				g.score += 500
		["trilateral-meeting-stickers", "on_wave_clear"]:
			g.gold += 5 * g.artefacts.size()
		["money-printer-service-manual", "on_wave_clear"]:
			g.gold += roundi(ctx.gold_base * 0.10)
		["alien-autopsy-bloopers", "on_wave_clear"]:
			g.gold += 2 * g.captured.size()
		["golden-buddha-bobblehead", "on_wave_clear"]:
			g.gold += roundi(ctx.gold_base * 0.05)

		# --- issue 16: on_wave_spawn / on_milestone / on_purchase / on_game_over ---
		["nigerian-prince-wire-transfer", "on_wave_spawn"]:
			g.score += 100
			g.gold += 10
			g.clock_ms = maxf(g.clock_ms - 3000.0, 0.0)
		["john-titor-s-crypto-wallet", "on_milestone"]:
			g.gold += int(g.clock_ms / 1000.0 / 5.0)
		["putin-s-golden-toilet-brush", "on_purchase"]:
			g.score += 5 * ctx.price
		["rapture-insurance-policy", "on_game_over"]:
			g.score += g.gold * 20
			g.gold = 0
