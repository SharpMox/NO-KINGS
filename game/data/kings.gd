## The 16-King cast (Notion GDD "Kings" page, fetched 2026-08-27), four per
## costume tier. Identity + selection only — no per-King mechanics are
## specced anywhere, so none are invented here (issue 09).
##
## Selection rule (recorded here, this slice): King waves (50/100/150,
## data/waves.gd) escalate tier-ordered by depth — the Nth King wave draws
## from TIER_ORDER[N], clamped to the last tier once waves run out. Today
## that's Laurel@50, Hat@100, Uniform@150; Suit is reserved for a King wave
## deeper than 150, which the wave catalog doesn't generate yet (waves.gd:
## "the catalog's procedural extension past 150 is not implemented"). The
## specific King is sampled uniformly within the tier from the run's own RNG,
## so it stays seed/save deterministic.

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


## Ordinal of the King wave at wave `n` (0 for the first King wave, 1 for the
## second, ...) — counts "king" rosters up to and including wave n.
static func _ordinal(n: int) -> int:
	var count := -1
	for i in n:
		if Waves.WAVES[i].has("king"):
			count += 1
	return count


## Pick the King for wave `n` (must be a King wave) using the run's RNG.
static func select(rng: RandomNumberGenerator, n: int) -> Dictionary:
	var tier: String = TIER_ORDER[mini(_ordinal(n), TIER_ORDER.size() - 1)]
	var pool: Array = ROSTER[tier]
	return pool[rng.randi() % pool.size()]


## Display name for a King id, or "King" if unset/unrecognized (bare "king"
## board entries with no king_id — e.g. hand-written test scenarios).
static func name_of(id: String) -> String:
	for tier in ROSTER:
		for k in ROSTER[tier]:
			if k.id == id:
				return k.name
	return "King"
