## The 16-King cast (Notion GDD "Kings" page, fetched 2026-08-27), four per
## costume tier. Identity + selection only — no per-King mechanics are
## specced anywhere, so none are invented here (issue 09).
##
## SELECTION — ONE COSTUME TIER PER RUN (user ruling, 2026-08-31, issue 89).
##
## A run picks ONE tier at the start and meets all four of its Kings, in
## shuffled order:
##
##   wave 50 -> king 1 · 100 -> king 2 · 150 -> king 3 · 200 -> king 4
##
## This REPLACES the previous rule, which walked TIER_ORDER by depth
## (Laurel@50, Hat@100, Uniform@150, Suit unreachable). Under that rule three
## quarters of the cast could never appear in one run and Suit never appeared
## at all; under this one a run meets a coherent set of four.
##
## The tier and the order are rolled ONCE at run start and SAVED, not derived
## at each King wave. Deriving them would re-roll on load and hand a resumed
## run a different King than the one it was about to fight — the same class of
## bug as issue 55's silently-restarting Lane-B progress.
##
## Wave 50 remains the win condition and its end screen is unchanged; waves
## 51-200 are Endless, so Kings 2-4 are post-win content.

const Waves := preload("res://data/waves.gd")
const Rules := preload("res://scripts/rules.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")

## Economy is loaded lazily, NOT preloaded: artefact_hooks.gd preloads this
## file (issue 92 dispatches King Powers through its run()), and economy.gd
## preloads artefact_hooks.gd — so a preload here would close the cycle
## artefact_hooks -> kings -> economy -> artefact_hooks and fail to compile.
static func _economy() -> GDScript:
	return load("res://scripts/economy.gd")

const LAUREL := "laurel"
const HAT := "hat"
const UNIFORM := "uniform"
const SUIT := "suit"

const TIER_ORDER := [LAUREL, HAT, UNIFORM, SUIT]

const ROSTER := {
	LAUREL: [
		{"id": "nebuchadnezzar_ii", "name": "Nebuchadnezzar II"},
		{"id": "xerxes_i", "name": "Xerxes I"},
		{"id": "qin_shi_huang", "name": "Qin Shi Huang"},
		{"id": "nero", "name": "Nero"},
	],
	HAT: [
		{"id": "genghis_khan", "name": "Genghis Khan"},
		{"id": "tamerlane", "name": "Tamerlane"},
		{"id": "ivan_the_terrible", "name": "Ivan the Terrible"},
		{"id": "napoleon", "name": "Emperor Napoléon"},
	],
	UNIFORM: [
		{"id": "mao_zedong", "name": "Mao Zedong"},
		{"id": "joseph_stalin", "name": "Joseph Stalin"},
		{"id": "adolf_hitler", "name": "Adolf Hitler"},
		{"id": "hideki_tojo", "name": "Hideki Tojo"},
	],
	SUIT: [
		{"id": "donald_trump", "name": "Donald Trump"},
		{"id": "benjamin_netanyahu", "name": "Benjamin Netanyahu"},
		{"id": "vladimir_putin", "name": "Vladimir Putin"},
		{"id": "kim_jong_un", "name": "Kim Jong Un"},
	],
}


## Roll a run's King line-up: which costume tier, and the order its four Kings
## arrive in. Called once at run start from the run's own RNG, so it is seed
## deterministic; the result is saved rather than recomputed.
##
## Tier is random today. The user left the door open to picking it alongside
## the difficulty choice ("we can add that selection with the difficulty
## choice"), which is why this returns the tier rather than assuming it.
static func roll_run(rng: RandomNumberGenerator) -> Dictionary:
	var tier: String = TIER_ORDER[rng.randi() % TIER_ORDER.size()]
	var ids: Array = []
	for k in ROSTER[tier]:
		ids.append(k.id)
	# Fisher-Yates from the run RNG — Array.shuffle() draws from the GLOBAL
	# RNG, which would make the line-up unreproducible from a seed and break
	# the guarantee issue 75 shipped.
	for i in range(ids.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp: Variant = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	return {"tier": tier, "order": ids}


## The King id for the `ordinal`-th King wave of a run, or "" past the end of
## the line-up (wave 201 is Larry, who is parked — issue 89).
static func for_ordinal(order: Array, ordinal: int) -> String:
	if ordinal < 0 or ordinal >= order.size():
		return ""
	return str(order[ordinal])


## Ordinal of the King wave at wave `n` (0 for the first King wave, 1 for the
## second, ...) — counts "king" rosters up to and including wave n.
static func _ordinal(n: int) -> int:
	var count := -1
	for i in n:
		if Waves.WAVES[i].has("king"):
			count += 1
	return count


## The King for wave `n` (must be a King wave), from the run's rolled line-up.
## Falls back to rolling a line-up when a run has none — hand-written test
## scenarios and pre-89 saves both reach here without one, and a King wave with
## no King would be a softlock rather than a missing cosmetic.
static func select(rng: RandomNumberGenerator, n: int, order: Array = []) -> Dictionary:
	var line_up: Array = order if not order.is_empty() else roll_run(rng).order
	var id := for_ordinal(line_up, _ordinal(n))
	if id == "":
		id = str(line_up[line_up.size() - 1]) # past the line-up: reuse the last
	return {"id": id, "name": name_of(id)}


## Display name for a King id, or "King" if unset/unrecognized (bare "king"
## board entries with no king_id — e.g. hand-written test scenarios).
static func name_of(id: String) -> String:
	for tier in ROSTER:
		for k in ROSTER[tier]:
			if k.id == id:
				return k.name
	return "King"


## KING KITS (issue 91) — one Power and one Ability each, mirroring the Army
## structure exactly (user ruling, 2026-09-01: "32, a power and an ability for
## each king"). That symmetry is the point: the engine seams already exist, and
## a player reads a King the same way they read their own Army.
##
##   POWER   — static, live for the WHOLE King wave (both segments, ruling 6).
##   ABILITY — once per Wave, costs the King one of its Actions (ruling 4).
##             An Action spent on an Ability is an Action not spent attacking,
##             which is the visible tradeoff the player plays around.
##
## ONLY DONALD TRUMP'S KIT IS FILLED IN. It is the one that was ruled — Tariff
## is his Power (slice 66) and Diplomatic Visit – JD Vance his Ability (design
## session). The other 15 are deliberately absent and the engine no-ops on
## them, so this slice ships a working engine without inventing 30 effects that
## are the user's to design.
const KITS := {
	# ---- LAUREL (issue 92) --------------------------------------------------
	"nebuchadnezzar_ii": {
		"power_name": "The Babylonian Exile",
		"power_desc": "Pieces you capture this wave are deported — they never reach your Captured Stock.",
		"power_key": "exile",
		"ability_name": "The Dream of the Statue",
		"ability_desc": "Your highest-value piece on the board crumbles to its base form.",
		"ability_key": "crumble",
	},
	"xerxes_i": {
		"power_name": "The Countless Host",
		"power_desc": "The enemy takes one extra Action every turn this wave.",
		"power_key": "host",
		"ability_name": "Whip the Hellespont",
		"ability_desc": "Drives every piece you have on the board back one row.",
		"ability_key": "whip",
	},
	"qin_shi_huang": {
		"power_name": "The Great Wall",
		"power_desc": "Deploying from your Stock costs double this wave.",
		"power_key": "wall",
		"ability_name": "The Terracotta Army",
		"ability_desc": "Three more of the wave's own pieces march in at once.",
		"ability_key": "terracotta",
	},
	"nero": {
		"power_name": "Rome Burns",
		"power_desc": "Your Gold gains are halved this wave.",
		"power_key": "burns",
		"ability_name": "The Fire of Rome",
		"ability_desc": "Every Item you are holding burns.",
		"ability_key": "fire",
	},

	# ---- HAT (issue 93) -----------------------------------------------------
	"genghis_khan": {
		"power_name": "No Fixed Cities",
		"power_desc": "You cannot merge this wave — nothing may be consolidated.",
		"power_key": "nomerge",
		"ability_name": "The Silent Steppe",
		"ability_desc": "Strips every Piece Buff from your board.",
		"ability_key": "strip",
	},
	"tamerlane": {
		"power_name": "Scorched Earth",
		"power_desc": "Your Score gains are halved this wave.",
		"power_key": "scorched",
		"ability_name": "The Pyramid of Skulls",
		"ability_desc": "Your two least valuable pieces on the board are destroyed.",
		"ability_key": "pyramid",
	},
	"ivan_the_terrible": {
		"power_name": "The Oprichnina",
		"power_desc": "Your Items cannot be used this wave.",
		"power_key": "noitems",
		"ability_name": "Kill the Tsarevich",
		"ability_desc": "One of your pieces turns and fights for the King.",
		"ability_key": "turncoat",
	},
	"napoleon": {
		"power_name": "La Grande Armée",
		"power_desc": "Enemy reinforcements arrive carrying an extra Piece Buff.",
		"power_key": "grande",
		"ability_name": "Artillery Barrage",
		"ability_desc": "Every piece you have in one column is destroyed.",
		"ability_key": "barrage",
	},

	# ---- UNIFORM (issue 93) -------------------------------------------------
	"mao_zedong": {
		"power_name": "Backyard Furnaces",
		"power_desc": "Pieces you deploy this wave arrive demoted to their base form.",
		"power_key": "furnaces",
		"ability_name": "The Long March",
		"ability_desc": "Every enemy piece advances one row toward you.",
		"ability_key": "longmarch",
	},
	"joseph_stalin": {
		"power_name": "The Purge",
		"power_desc": "Your pieces cannot gain Piece Buffs this wave.",
		"power_key": "purge",
		"ability_name": "Order No. 227",
		"ability_desc": "Not one step back — your pieces on your own back row are destroyed.",
		"ability_key": "order227",
	},
	"adolf_hitler": {
		"power_name": "Total War",
		"power_desc": "Every piece you lose this wave also costs you Gold.",
		"power_key": "totalwar",
		"ability_name": "Total Mobilisation",
		"ability_desc": "The enemy takes an extra Action for the rest of this wave.",
		"ability_key": "mobilise",
	},
	"hideki_tojo": {
		"power_name": "Kamikaze",
		"power_desc": "Each capture you make also destroys the capturing piece's neighbour.",
		"power_key": "kamikaze",
		"ability_name": "Total Attrition",
		"ability_desc": "Halves the Clock you have left.",
		"ability_key": "attrition",
	},

	# ---- SUIT (ruled in slice 66 + the design session) ----------------------
	"donald_trump": {
		"power_name": "Tariff",
		"power_desc": "Tariffs are in force for the whole of this King's wave.",
		"power_tariff": "inflation",
		"ability_name": "Diplomatic Visit – JD Vance",
		"ability_desc": "Destroys your highest-value piece on the board.",
		"ability_tariff": "jd_vance",
	},
	"benjamin_netanyahu": {
		"power_name": "Iron Dome",
		"power_desc": "The King cannot be captured while any other enemy piece stands.",
		"power_key": "dome",
		"ability_name": "Targeted Strike",
		"ability_desc": "Destroys whichever of your pieces stands closest to the King.",
		"ability_key": "strike",
	},
	"vladimir_putin": {
		"power_name": "Annexation",
		"power_desc": "Your pieces that end your turn in the enemy half are annexed.",
		"power_key": "annex",
		"ability_name": "Disinformation",
		"ability_desc": "Your pieces on the board are shuffled between their own squares.",
		"ability_key": "disinfo",
	},
	"kim_jong_un": {
		"power_name": "Juche",
		"power_desc": "The Shop is closed this wave.",
		"power_key": "juche",
		"ability_name": "The Parade",
		"ability_desc": "Destroys every piece you have in a three-by-three block.",
		"ability_key": "parade",
	},
}


## A King's kit, or {} for the 15 that have none yet.
static func kit_of(id: String) -> Dictionary:
	return KITS.get(id, {})


## The King whose Power is live, or "" when none is. Covers BOTH segments of a
## King wave (ruling 6): during segment 1 the King is still held in
## `pending_king` and is not on the board, but its Power is already in force —
## which is what gives those 15 turns that King's identity rather than making
## them generic filler.
static func active_id(g) -> String:
	if not g.pending_king.is_empty():
		return str(g.pending_king.get("king_id", ""))
	for pos in g.board:
		var piece: Dictionary = g.board[pos]
		if piece.get("id", "") == "king" and piece.has("king_id"):
			return str(piece.king_id)
	return ""


## Bring a King's Power into force for its wave, and clear the previous one.
## Called from WaveLogic.queue for EVERY wave: a non-King wave passes "" and
## the effect is the clearing half, so a Power cannot outlive its wave — the
## ruling is "only during that King's wave", and a Power that leaked into wave
## 51 would be a permanent difficulty increase nobody chose.
static func apply_power(g, king_id: String) -> void:
	g.king_power_id = ""
	if g.king_power_tariff != "":
		for i in range(g.tariffs_active.size() - 1, -1, -1):
			if g.tariffs_active[i].get("key", "") == g.king_power_tariff:
				g.tariffs_active.remove_at(i)
		g.king_power_tariff = ""
	if king_id == "":
		return
	var kit := kit_of(king_id)
	if kit.is_empty():
		return # a King with no kit yet — the engine no-ops
	var key: String = str(kit.get("power_tariff", ""))
	if key != "":
		_economy().activate_tariff_by_key(g, key)
		g.king_power_tariff = key
	g.king_power_id = king_id
	g._add_turn_fx("%s: %s" % [name_of(king_id), kit.power_name], Color(1.0, 0.55, 0.4))


## Spend the King's once-per-Wave Ability. Returns true when it fired, so the
## caller can charge it an Action.
##
## Requires the King to actually be ON THE BOARD: during segment 1 the Power is
## live but the King has not arrived, and an Ability from a King the player
## cannot yet see or attack would be unanswerable.
static func fire_ability(g) -> bool:
	if g.king_ability_used_this_wave:
		return false
	var id := ""
	for pos in g.board:
		var piece: Dictionary = g.board[pos]
		if piece.get("id", "") == "king" and piece.has("king_id"):
			id = str(piece.king_id)
	if id == "":
		return false
	var kit := kit_of(id)
	var bespoke: String = str(kit.get("ability_key", ""))
	var tariff: String = str(kit.get("ability_tariff", ""))
	if bespoke == "" and tariff == "":
		return false # no kit yet: no Ability, and no Action charged for one
	g.king_ability_used_this_wave = true
	g._add_turn_fx("%s: %s" % [name_of(id), kit.ability_name], Color(1.0, 0.35, 0.3))
	if bespoke != "":
		_bespoke_ability(g, bespoke)
	else:
		_economy().activate_tariff_by_key(g, tariff)
	return true


## THE POWER HOOK (issue 92) — bespoke King Powers, dispatched through the same
## ctx contract Artefacts and Tariffs use (`artefact_hooks.gd`'s header): return
## values through `ctx`, compute off the immutable base, never write g.score or
## g.gold mid-dispatch.
##
## Called from ArtefactHooks.run for EVERY hook, so a Power participates in the
## same ordering as everything else rather than being applied before or after
## the rest and drifting.
static func power_hook(g, hook: String, ctx: Dictionary) -> void:
	if g.king_power_id == "":
		return
	# Total Mobilisation (Hitler's Ability) applies to EVERY enemy turn left in
	# the wave, so it lives here rather than at the Ability. OUTSIDE the match:
	# a `match` takes the first matching branch, so as a case it would have
	# shadowed whichever Power also answers this hook.
	if hook == "on_enemy_turn_start" and g.king_extra_actions > 0:
		ctx.actions += g.king_extra_actions
	var kit := kit_of(g.king_power_id)
	match [str(kit.get("power_key", "")), hook]:
		["host", "on_enemy_turn_start"]:
			# Xerxes: the vast host presses. Same shape as Filibuster, so it
			# composes with the tier's own enemy-action count rather than
			# replacing it (issue 59).
			ctx.actions += 1
		["wall", "on_place_cost"]:
			# Qin Shi Huang: the wall is sealed. Doubled rather than blocked —
			# blocking deploys outright can strand a player into the resource
			# starvation game-over, which is a softlock dressed as difficulty.
			ctx.cost *= 2
		["scorched", "on_score_change"]:
			# Tamerlane: nothing grows behind him. Halved rather than zeroed —
			# Shop restocks are Score-gated, and zeroing Score for a whole wave
			# would quietly close the Shop too, which is Kim Jong Un's Power.
			ctx.amount *= 0.5
		["totalwar", "on_piece_lost"]:
			# Hitler: every loss is also a material cost. Routed through
			# ctx.gold_bonus, never g.gold — the header's rule, so Economy
			# applies it exactly once.
			ctx.gold_bonus = ctx.get("gold_bonus", 0) - 10
		["nomerge", "on_merge_check"]:
			# Genghis Khan: nothing is consolidated. Same lever as Regulation,
			# but total rather than pawn-only.
			ctx.blocked = true
		["burns", "on_gold_gain"]:
			# Nero: extravagance drains the treasury. Respects gain_immune the
			# same way Inflation does (Panama Papers Shredder / Amber Room
			# Bubble Wrap), or those Artefacts would silently stop working
			# against Kings while still working against Tariffs.
			if not ctx.get("gain_immune", false):
				ctx.amount *= 0.5


## Branch-style Powers: read at the site rather than dispatched, because each
## one answers "is this action allowed / different" rather than "what is this
## value". Forcing them through ctx would mean a suppression flag per effect.
static func power_is(g, key: String) -> bool:
	return str(kit_of(g.king_power_id).get("power_key", "")) == key


## True while the active King's Power deports captures (Nebuchadnezzar II).
## Read at the Captured Stock append sites rather than dispatched, because
## "this capture produces no Captured entry" is a branch, not a modified value.
static func deports_captures(g) -> bool:
	return str(kit_of(g.king_power_id).get("power_key", "")) == "exile"


## The bespoke Abilities. Instantaneous, so they run directly rather than
## through a hook. Returns false when the King has no bespoke Ability, so the
## caller can fall through to the Tariff-backed ones.
static func _bespoke_ability(g, key: String) -> bool:
	match key:
		"crumble":
			# Nebuchadnezzar II: the statue of gold and silver crumbles. Demote
			# the best piece rather than destroy it — this King takes your
			# INVESTMENT, which is a different loss from JD Vance's.
			var best := Vector2i(-1, -1)
			for pos in g._player_pieces():
				var d: Dictionary = g.defs[g.board[pos].id]
				if best.x < 0 or d.value > g.defs[g.board[best].id].value:
					best = pos
			if best.x < 0:
				return true
			var base := _base_of(g, g.board[best].id)
			if base != g.board[best].id:
				g.board[best].id = base
			return true
		"whip":
			# Xerxes I: three hundred lashes for the water. Drives the player's
			# board back one row, toward their own side — position lost, not
			# material, so it cannot starve anyone out.
			var moved: Array = g._player_pieces()
			moved.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
			for pos in moved:
				var to := Vector2i(pos.x, pos.y - 1)
				if to.y >= 0 and not g.board.has(to):
					g.board[to] = g.board[pos]
					g.board.erase(pos)
			return true
		"terracotta":
			# Qin Shi Huang: the buried army marches. Drawn from the wave's own
			# roster so it escalates with the wave instead of being a flat add.
			var pool: Array = []
			for pos in g.board:
				if g.board[pos].owner == Rules.ENEMY and g.board[pos].get("id", "") != "king":
					pool.append(g.board[pos].id)
			if pool.is_empty():
				pool = ["pawn"]
			for _i in 3:
				g.pending_spawn.append({"id": pool[g.rng.randi() % pool.size()]})
			return true
		"strip":
			# Genghis Khan: the steppe leaves nothing standing.
			for pos in g._player_pieces():
				BuffLogic.clear(g.board[pos])
			return true
		"pyramid":
			# Tamerlane: the weakest are taken first — the mirror of JD Vance,
			# which takes the best. Two, so it is felt without being a wipe.
			var mine: Array = g._player_pieces()
			mine.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return g.defs[g.board[a].id].value < g.defs[g.board[b].id].value)
			for i in mini(2, mine.size()):
				g._destroy(mine[i])
			return true
		"turncoat":
			# Ivan: he killed his own son. Ownership, not destruction — the
			# piece keeps fighting, just not for you.
			var own: Array = g._player_pieces()
			if not own.is_empty():
				g.board[own[g.rng.randi() % own.size()]].owner = Rules.ENEMY
			return true
		"barrage":
			# Napoleon: artillery ranges a column, not a piece.
			var by_col := {}
			for pos in g._player_pieces():
				by_col[pos.x] = by_col.get(pos.x, 0) + 1
			if by_col.is_empty():
				return true
			var worst := -1
			for x in by_col:
				if worst < 0 or by_col[x] > by_col[worst]:
					worst = x
			for pos in g._player_pieces():
				if pos.x == worst:
					g._destroy(pos)
			return true
		"longmarch":
			# Mao: the march closes the distance. Enemies advance toward the
			# player's side (increasing y is the enemy's home, so decreasing).
			var foes: Array = []
			for pos in g.board:
				if g.board[pos].owner == Rules.ENEMY and g.board[pos].get("id", "") != "king":
					foes.append(pos)
			foes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
			for pos in foes:
				var to := Vector2i(pos.x, pos.y - 1)
				if to.y >= 0 and not g.board.has(to):
					g.board[to] = g.board[pos]
					g.board.erase(pos)
			return true
		"order227":
			# Stalin: not one step back. Punishes the safest squares on the
			# board, which is the opposite of every other Ability here.
			for pos in g._player_pieces():
				if pos.y == 0:
					g._destroy(pos)
			return true
		"mobilise":
			# Hitler: the extra Action persists for the REST of the wave, so it
			# compounds with the turns still to come rather than being a
			# one-off. Reset with every other per-wave flag.
			g.king_extra_actions += 1
			return true
		"attrition":
			# Tojo: the war of attrition takes time, not pieces.
			g.clock_ms *= 0.5
			return true
		"strike":
			# Netanyahu: precision. Takes whatever is closest to the King,
			# which punishes the approach rather than the best piece.
			var king_pos := Rules.find_king(g.board, Rules.ENEMY)
			if king_pos.x < 0:
				return true
			var closest := Vector2i(-1, -1)
			var best_d := 1 << 30
			for pos in g._player_pieces():
				var d: int = absi(pos.x - king_pos.x) + absi(pos.y - king_pos.y)
				if d < best_d:
					best_d = d
					closest = pos
			if closest.x >= 0:
				g._destroy(closest)
			return true
		"disinfo":
			# Putin: nothing is where you left it. Costs no material at all —
			# it destroys your PLAN, which no other Ability here does.
			var squares: Array = g._player_pieces()
			var pieces: Array = []
			for pos in squares:
				pieces.append(g.board[pos])
			for i in range(pieces.size() - 1, 0, -1):
				var j: int = g.rng.randi() % (i + 1)
				var tmp: Variant = pieces[i]
				pieces[i] = pieces[j]
				pieces[j] = tmp
			for i in squares.size():
				g.board[squares[i]] = pieces[i]
			return true
		"parade":
			# Kim Jong Un: the demonstration flattens a block, not a line.
			var anchor := Vector2i(-1, -1)
			var most := -1
			for pos in g._player_pieces():
				var n := 0
				for other in g._player_pieces():
					if absi(other.x - pos.x) <= 1 and absi(other.y - pos.y) <= 1:
						n += 1
				if n > most:
					most = n
					anchor = pos
			if anchor.x < 0:
				return true
			for pos in g._player_pieces():
				if absi(pos.x - anchor.x) <= 1 and absi(pos.y - anchor.y) <= 1:
					g._destroy(pos)
			return true
		"fire":
			# Nero: everything burns. Items only — Artefacts are the run's
			# identity and taking those would be a different order of loss.
			g.items.clear()
			return true
	return false


## The base of a piece's promotion chain (what `crumble` demotes to).
static func _base_of(g, id: String) -> String:
	var parent := {}
	for k in g.defs:
		var nxt: Variant = g.defs[k].get("next")
		if nxt is String and g.defs.has(nxt):
			parent[nxt] = k
	var cur := id
	var guard := 0
	while parent.has(cur) and guard < 16:
		cur = parent[cur]
		guard += 1
	return cur
