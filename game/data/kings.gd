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
