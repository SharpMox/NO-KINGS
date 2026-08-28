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
##
## issue 17 (Action/Time/Piece batch) added 8 no-prerequisite artefacts, all
## on hooks issue 16 had already wired (on_capture, on_turn_start,
## on_wave_clear) — no new call sites. Piece grants into Stock follow
## ADR-0002 (docs/adr/0002-stock-holds-opaque-piece-state.md): Terracotta
## Draft Card's grant is a bare id String because a fresh pool piece carries
## no board state (the Dictionary form is for a piece pulled off the board
## with state attached, e.g. Extraction in game.gd). Stargate Divination
## Crystal is the one action-granting handler that runs mid-turn (on_capture,
## not on_turn_start) — it fires from Economy.capture_score *before*
## _move_player's own actions_left -= 1 / auto-pass check, the same ordering
## that lets the Blitz item (game.gd _item_apply) refund its own action
## without ever resurrecting an already-ended turn. Covered by test_items.gd
## ("Stargate Divination Crystal refunds the capture's action before the
## auto-pass check").
##
## issue 18 (Shop/Item/Buff batch) added:
## - on_deploy fires from game.gd:_place, ctx = {pos} (the tile the piece just
##   landed on — MK-Ultra Sugar Cube reads g.board[ctx.pos]).
## - on_turn_end fires from game.gd:_on_pass's PLAYER_TURN branch, no ctx —
##   the turn-end mirror of the on_turn_start call already there.
## - on_capture ctx grew `attacker_pos` (the Vector2i the attacker piece was
##   still standing on when capture_score ran — Vector2i(-1,-1) from the two
##   direct-call test sites), so a handler can grant something to the actual
##   attacking piece instead of just reading its id.
## - on_price is the Shop's "base + modifiers" seam (shop-drawer-ui/08
##   deferred it "until an Artefact needs it" — several now do). Shop.price()
##   runs it after computing the row's base price; ctx = {base, amount, kind,
##   tier}. `tier` is an Item's tier ("Tactical"/"Strategic"/"Decisive") and
##   "" for every other kind. Same immutable-base/additive-amount contract as
##   on_score_change/on_gold_change, so two discounts stack additively.

const Rules := preload("res://scripts/rules.gd")
const Items := preload("res://data/items.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")
const Tuning := preload("res://scripts/tuning.gd")

const HOOKS := [
	"on_capture", "on_piece_lost", "on_deploy",
	"on_wave_clear", "on_wave_spawn", "on_milestone",
	"on_turn_start", "on_turn_end", "on_shop_restock", "on_purchase",
	"on_gold_change", "on_score_change", "on_box_open", "on_game_over", "on_price",
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
	# --- issue 17: Action/Time/Piece batch (8 artefacts, no needs-note) ---
	"cia-exploding-cigar": ["on_turn_start"],
	"i-am-not-a-robot-checkbox": ["on_turn_start"],
	"seed-vault-secret-hatch": ["on_turn_start"],
	"super-soldier-multivitamins": ["on_turn_start"],
	"stargate-divination-crystal": ["on_capture"],
	"5g-microchips": ["on_turn_start"],
	"terracotta-draft-card": ["on_wave_clear"],
	"charlemagne-s-birth-certificate": ["on_wave_clear"],
	# --- issue 18: Shop/Item/Buff batch (20 artefacts, no needs-note) ---
	"denazification-visa": ["on_price"],
	"hollow-moon-cross-section": ["on_price"],
	"shrinkflation-cereal-box": ["on_turn_end", "on_price"],
	"skull-and-bones-coffin": ["on_score_change", "on_price"],
	"silk-road-coupon": ["on_wave_clear", "on_price"],
	"crop-circle-plank": ["on_wave_clear"],
	"mk-ultra-sugar-cube": ["on_deploy"],
	"obedience-flavored-tap-water": ["on_capture"],
	"holy-lint": ["on_capture"],
	"scientology-e-meter": ["on_wave_clear"],
	"xenu-ot-iii-season-pass": ["on_wave_clear"],
	"sugar-free-chemtrail-can": ["on_wave_clear"],
	"sleeper-agent-pillow": ["on_purchase"],
	"frame-25": ["on_wave_clear"],
	"manna-vending-machine": ["on_wave_clear"],
	"mao-s-loyalty-badge": ["on_purchase"],
	# chocolate-key-cake, alleged-weather-balloon, sub-antarctic-visa and
	# majestic-12-secret-handshake-diagram fire nowhere — Shop.roll/price and
	# game.gd's _box_options read g.artefacts directly, the same way Shop.buy
	# already reads slot.kind without a hook (shop-drawer-ui/08's deferred pass).
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


## Player-owned board positions — the random-ally-target pool for Buff-tag
## artefacts (Crop Circle Plank, Scientology E-Meter, Xenu OT III Season
## Pass, Sugar Free Chemtrail Can).
static func _player_positions(g) -> Array:
	var out := []
	for pos in g.board:
		if g.board[pos].owner == Rules.PLAYER:
			out.append(pos)
	return out


## A uniformly random Piece Buff key, optionally restricted to one tier
## ("Tactical Piece Buff" in several issue-18 effect texts).
static func _random_buff_key(rng: RandomNumberGenerator, tier := "") -> String:
	var pool: Array = Items.PIECE_BUFFS if tier == "" \
		else Items.PIECE_BUFFS.filter(func(b: Dictionary) -> bool: return b.tier == tier)
	return pool[rng.randi() % pool.size()].key


## Catalogued life of a timed buff, in player turns (0 = dormant) — mirrors
## game.gd's private _buff_turns, kept alongside its own PIECE_BUFFS lookup
## instead of reaching across files for a one-line match.
static func _buff_turns(key: String) -> int:
	for b in Items.PIECE_BUFFS:
		if b.key == key:
			return int(b.get("turns", 0))
	return 0


## Grant one random Piece Buff to a live Dictionary — a board piece
## (BuffLogic.add takes any Dictionary with a `buffs` field) or a freshly
## built {"id": ...} piece not yet placed (Sleeper Agent Pillow).
static func _grant_buff_to(piece: Dictionary, rng: RandomNumberGenerator, tier := "") -> void:
	var key := _random_buff_key(rng, tier)
	BuffLogic.add(piece, key, _buff_turns(key))


static func _grant_buff(g, pos: Vector2i, tier := "") -> void:
	_grant_buff_to(g.board[pos], g.rng, tier)


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

		# --- issue 17: Action/Time/Piece batch ---
		["cia-exploding-cigar", "on_turn_start"]:
			g.actions_left += 1
		["i-am-not-a-robot-checkbox", "on_turn_start"]:
			if g._player_pieces().size() >= 8:
				g.actions_left += 1
		["seed-vault-secret-hatch", "on_turn_start"]:
			if g.items.size() >= 3:
				g.actions_left += 1
		["super-soldier-multivitamins", "on_turn_start"]:
			var buffed := 0
			for pos in g._player_pieces():
				if not BuffLogic.of(g.board[pos]).is_empty():
					buffed += 1
			if buffed >= 3:
				g.actions_left += 1
		["stargate-divination-crystal", "on_capture"]:
			# Fires from Economy.capture_score, BEFORE the capture's own
			# actions_left -= 1 / auto-pass check runs (game.gd _move_player)
			# — same ordering that lets Blitz refund its own action without
			# ever resurrecting an already-ended turn. actions_max moves too,
			# mirroring first_capture_extra (its on_capture sibling above),
			# since turn start already happened and won't re-sync it for us.
			if g.turn_action_count == 0:
				g.actions_left += 1
				g.actions_max += 1
		["5g-microchips", "on_turn_start"]:
			var allies: int = g._player_pieces().size()
			var enemies: int = g.board.size() - allies
			g.clock_ms += (allies - enemies) * 1000
		["terracotta-draft-card", "on_wave_clear"]:
			var mix: Array = Tuning.ARMIES.get(g.next_army, Tuning.ARMIES[Tuning.DEFAULT_ARMY])
			g.stock.append(mix[g.rng.randi() % mix.size()]) # bare id: a fresh
				# piece carries no board state, so ADR-0002's plain-String form
				# applies (a Dictionary would only be needed for a piece pulled
				# off the board with state attached, e.g. Extraction)
		["charlemagne-s-birth-certificate", "on_wave_clear"]:
			g.clock_ms += 10000

		# --- issue 18: Shop price modifiers (Shop.price's on_price seam) ---
		["denazification-visa", "on_price"]:
			if ctx.kind == "item" and ctx.tier == "Tactical":
				ctx.amount -= ctx.base * 0.50
		["hollow-moon-cross-section", "on_price"]:
			if ctx.kind == "artefact":
				ctx.amount -= ctx.base * 0.25
		["shrinkflation-cereal-box", "on_price"]:
			ctx.amount += ctx.base * 0.50
		["shrinkflation-cereal-box", "on_turn_end"]:
			g.gold += 10
			g.score += 10
			g.clock_ms += 1000.0
		["skull-and-bones-coffin", "on_price"]:
			ctx.amount += ctx.base * 0.05
		["skull-and-bones-coffin", "on_score_change"]:
			if g.gold >= 200:
				ctx.amount += ctx.base * 0.20
		["silk-road-coupon", "on_price"]:
			if g.silk_road_active:
				ctx.amount -= ctx.base * 0.50
		["silk-road-coupon", "on_wave_clear"]:
			# "5-Wave Milestone" (12 effect texts) is a different cadence than
			# on_milestone's own 10-wave clock-refill trigger, so this checks
			# the just-cleared wave directly rather than piggybacking that hook.
			if g.wave % 5 == 0:
				g.silk_road_active = true # reset false at the top of every WaveLogic.queue()

		# --- issue 18: Buff-tag triggers, all through BuffLogic.add ---
		["crop-circle-plank", "on_wave_clear"]:
			if g.wave % 5 == 0: # "5-Wave Milestone" — see silk-road-coupon's on_wave_clear case above
				var pool := _player_positions(g)
				for i in mini(2, pool.size()):
					var idx: int = g.rng.randi() % pool.size()
					_grant_buff(g, pool[idx])
					pool.remove_at(idx)
				g.gold = maxi(g.gold - 10, 0)
		["mk-ultra-sugar-cube", "on_deploy"]:
			_grant_buff(g, ctx.pos, "Tactical")
		["obedience-flavored-tap-water", "on_capture"]:
			if ctx.wave_capture_index == 0 and ctx.attacker_pos.x >= 0:
				_grant_buff(g, ctx.attacker_pos, "Tactical")
		["holy-lint", "on_capture"]:
			if ctx.attacker_pos.x >= 0:
				_grant_buff(g, ctx.attacker_pos)
		["scientology-e-meter", "on_wave_clear"]:
			# "the piece" — Wave clear has no single trigger piece, so this
			# reads it as a random ally (same reading as Xenu OT III below).
			g.gold = maxi(g.gold - 5, 0)
			var se_pool := _player_positions(g)
			if not se_pool.is_empty():
				_grant_buff(g, se_pool[g.rng.randi() % se_pool.size()])
		["xenu-ot-iii-season-pass", "on_wave_clear"]:
			g.gold = maxi(g.gold - 15, 0)
			var xe_pool := _player_positions(g)
			for i in 3: # 3 independent random-ally picks; may repeat a piece
				if xe_pool.is_empty():
					break
				_grant_buff(g, xe_pool[g.rng.randi() % xe_pool.size()])
		["sugar-free-chemtrail-can", "on_wave_clear"]:
			if g.wave % 5 == 0:
				for pos in _player_positions(g):
					_grant_buff(g, pos)
		["sleeper-agent-pillow", "on_purchase"]:
			# the piece landed as a plain id string at the end of g.stock
			# (Shop.buy, just before this hook runs) — replace it with a
			# Dictionary carrying the buff; _place's `entry is Dictionary`
			# branch already merges any extra fields onto the board piece.
			if ctx.kind == "piece" and not g.stock.is_empty():
				var piece := {"id": ctx.key}
				_grant_buff_to(piece, g.rng, "Tactical")
				g.stock[g.stock.size() - 1] = piece

		# --- issue 18: Item-tag triggers ---
		["frame-25", "on_wave_clear"]:
			var tac_pool: Array = Items.ITEMS.filter(func(it: Dictionary) -> bool:
				return it.tier == "Tactical")
			g.items.append(tac_pool[g.rng.randi() % tac_pool.size()])
			g.gold = maxi(g.gold - 10, 0)
		["manna-vending-machine", "on_wave_clear"]:
			if g.wave % 5 == 0:
				for i in 2:
					g.items.append(Items.ITEMS[g.rng.randi() % Items.ITEMS.size()])
		["mao-s-loyalty-badge", "on_purchase"]:
			if ctx.kind == "item":
				var tier := ""
				for it in Items.ITEMS:
					if it.key == ctx.key:
						tier = it.tier
						break
				if tier == "Tactical":
					var pool: Array = Items.ITEMS.filter(func(it: Dictionary) -> bool:
						return it.tier == "Tactical")
					g.items.append(pool[g.rng.randi() % pool.size()])
