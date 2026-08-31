## issue 79: one hand-playable sandbox per Artefact, GENERATED.
##
## The purpose is verification, not play (issue 73, user ruling 2026-08-31):
## a board you can load to watch a specific Artefact actually fire is how a
## disputed interaction gets settled in seconds instead of by reading dispatch
## code.
##
## The usual reason generated boards are worthless is that the effect never
## triggers. That is avoidable here because `ArtefactHooks.REGISTRY` already
## maps every key to the hooks it listens on — so the board that makes it fire
## is DERIVED rather than guessed. Boards are therefore authored per trigger
## FAMILY (nine of them), not per Artefact: template + the Artefact held + a
## pinned seed.
##
## Artefacts with no REGISTRY entry are passive reads — nothing to trigger.
## They are labelled "Passive" in their own name rather than given a board
## where nothing visibly happens, because a scenario that silently does nothing
## is worse than one labelled as needing manual setup.
##
## Names are "Artefact <Family>: <Name>" ON PURPOSE. menu.gd derives its
## sections from the text before the first ":" or "(", so naming them this way
## groups all 180 into nine scannable sections with no menu-side special case.

const Items := preload("res://data/items.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")

## Ordered: the FIRST family whose hook list intersects an Artefact's REGISTRY
## entry wins. Order is by how specific the trigger is, not alphabetical —
## `on_score_change` is listed low because a great many Artefacts carry it
## incidentally alongside a more interesting trigger.
const FAMILIES := [
	["Capture", ["on_capture", "on_destroy"]],
	["Losses", ["on_piece_lost", "on_charge", "on_tariff_charge", "on_demote",
		"on_piece_demoted"]],
	["Shop", ["on_purchase", "on_price", "on_shop_restock"]],
	["Items", ["on_item_consume"]],
	["Buffs", ["on_buff_apply", "on_buff_consume", "on_buff_removal"]],
	["Boxes", ["on_box_open"]],
	["Wave clear", ["on_wave_clear", "on_wave_spawn", "on_wave_roster",
		"on_clock_refill"]],
	["Turn", ["on_turn_start", "on_turn_end", "on_enemy_turn_start", "on_deploy",
		"on_merge_check", "on_place_cost", "on_sanction_check", "on_rank_up",
		"on_tariff_apply", "on_game_over"]],
	["Economy", ["on_score_change", "on_gold_change", "on_gold_gain", "on_gold_zero"]],
]

## One board per family. Each is deep-copied per Artefact, so a handler that
## mutates its config cannot leak into the next scenario.
const BOARDS := {
	"Capture": {
		"board": [["queen", 0, 2, 2], ["knight", 0, 4, 2],
			["pawn", 1, 2, 5], ["bishop", 1, 3, 4]],
		"stock": ["pawn"], "gold": 200, "score": 500},
	"Losses": { # an enemy rook poised to take an undefended player pawn
		"board": [["pawn", 0, 3, 3], ["queen", 0, 2, 1], ["rook", 1, 3, 7]],
		"stock": ["pawn"], "gold": 200, "score": 300},
	"Shop": { # wave 9 so the Shop is reachable, with Gold to spend in it
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
		"wave": 9, "gold": 400, "stock": ["pawn"], "score": 500},
	"Items": {
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]],
		"items": ["blitz"], "gold": 200, "score": 300},
	"Buffs": { # buffs arrive on capture, so the capture board plus a Buff Box budget
		"board": [["queen", 0, 2, 2], ["knight", 0, 4, 2], ["pawn", 1, 2, 5]],
		"stock": ["pawn"], "gold": 400, "score": 1000},
	"Boxes": {
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
		"wave": 9, "gold": 400, "score": 1000},
	"Wave clear": { # one capture away from clearing the wave
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]],
		"wave": 2, "stock": ["pawn"], "gold": 200, "score": 100},
	"Turn": {
		"board": [["pawn", 0, 1, 0], ["pawn", 0, 4, 0], ["queen", 0, 3, 1]],
		"stock": ["pawn"], "gold": 200, "score": 200},
	"Economy": { # anything that scores — the capture board serves (issue 73)
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5], ["bishop", 1, 3, 4]],
		"stock": ["pawn"], "gold": 200, "score": 500},
	# no trigger to stage: give it a board where its condition is visibly true
	# (Gold in hand, Score on the board, Stock and Captured both populated)
	"Passive": {
		"board": [["queen", 0, 2, 2], ["rook", 0, 4, 1], ["pawn", 1, 2, 5]],
		"stock": ["pawn", "rook"], "captured": ["pawn", "knight"],
		"items": ["blitz"], "gold": 400, "score": 1000},
}


## The family an Artefact's REGISTRY entry puts it in, or "Passive" if it has none.
static func family_of(key: String) -> String:
	var hooks: Array = ArtefactHooks.REGISTRY.get(key, [])
	if hooks.is_empty():
		return "Passive"
	for f in FAMILIES:
		for h in f[1]:
			if hooks.has(h):
				return f[0]
	return "Passive"


static func all() -> Array:
	var out: Array = []
	for e in Items.ARTEFACT_EFFECTS:
		var fam := family_of(e.key)
		var cfg: Dictionary = BOARDS[fam].duplicate(true)
		cfg["artefacts"] = [e.key]
		# pinned per key, so the same sandbox lays out identically every time
		# and a future diff of this file reads as a real change
		cfg["seed"] = abs(hash(e.key))
		out.append({"name": "Artefact %s: %s" % [fam, e.name], "cfg": cfg})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.name < b.name)
	return out
