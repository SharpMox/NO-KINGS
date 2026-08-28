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

const HOOKS := [
	"on_capture", "on_piece_lost", "on_deploy",
	"on_wave_clear", "on_wave_spawn", "on_milestone",
	"on_turn_start", "on_turn_end", "on_shop_restock", "on_purchase",
	"on_gold_change", "on_score_change", "on_box_open",
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
