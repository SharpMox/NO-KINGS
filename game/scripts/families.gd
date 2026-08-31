## Family catalog + Power lookups (issue 67) — pure logic module over the
## live game node `g`, same split as merge_logic.gd/item_logic.gd. A Family
## REPLACES the Army pick at run start: it determines Starting Stock (still
## Tuning.ARMIES, keyed by the same id), Starting Gold, Starting Items, plus
## a static Power (always on) and a once-per-Wave Ability (1 Action — a
## deliberate contrast with Artefact activation/the Shop, both 0).
##
## Ids stay Tuning.ARMIES' existing keys ("Crown"/"Wild Hunt"/"Old Guard") —
## load-bearing in the save's `army` key (bounty/Apocrypha precedent: a
## load-bearing key stays even when the display name changes). Display names
## differ for one seed: "The Levy" was vetoed (Levy is a common Jewish
## surname; the display name is "The Muster" — issue 67).
##
## Ability activation itself (confirm/targeting, autoplay bypass) lives in
## game.gd, mirroring _activate_artefact's own shape (issue 52) — this file
## only holds the data and the three Power checks that need to be read from
## more than one call site (merge_logic.gd, economy.gd, game.gd).

const Tuning := preload("res://scripts/tuning.gd")

const CATALOG := {
	"Crown": {
		"display_name": "The Muster",
		"starting_gold": Tuning.FAMILY_BASELINE_GOLD,
		"starting_items": ["promote"],
		"power_name": "Close Ranks",
		"power_desc": "Merges cost no Action.",
		"ability_name": "Call the Banners",
		"ability_desc": "Duplicate a target piece from your Stock into your Stock.",
		"ability_targeted": true,
	},
	"Wild Hunt": {
		"display_name": "Wild Hunt",
		"starting_gold": Tuning.FAMILY_BASELINE_GOLD / 2,
		"starting_items": ["blitz", "blitz"],
		"power_name": "Blood in the Air",
		"power_desc": "Your first capture each Turn refunds its Action.",
		"ability_name": "Loose the Hounds",
		"ability_desc": "This Turn, your pieces' moves cost no Actions. Captures still pay.",
		"ability_targeted": false,
	},
	"Old Guard": {
		"display_name": "Old Guard",
		"starting_gold": Tuning.FAMILY_BASELINE_GOLD / 2,
		"starting_items": ["extraction"],
		"power_name": "Hold the Line",
		"power_desc": "When you lose a piece, refund its full value in Gold.",
		"ability_name": "Shield Wall",
		"ability_desc": "Every piece on your back two rows gains Shield.",
		"ability_targeted": false,
	},
}


## `id`'s catalog entry, falling back to the default family for an
## unrecognized/old-save id — same "unknown value falls back to baseline"
## shape Tuning.tier_index already uses for an old save's Tier string.
static func entry(id: String) -> Dictionary:
	return CATALOG.get(id, CATALOG[Tuning.DEFAULT_ARMY])


static func display_name(id: String) -> String:
	return str(entry(id).display_name)


## Close Ranks (The Muster): merges cost no Action — read by merge_logic.gd's
## three actions_left gates/decrement.
static func merge_free(g) -> bool:
	return g.next_army == "Crown"


## Blood in the Air (Wild Hunt): the run's first-capture-refunds-its-Action
## Power, near-identical to the core `first_capture_extra` Artefact — held
## together they stack ADDITIVELY (two refunds), the standing "big
## interactions stay" rule (issue 67). Implemented as its own independent
## check at the same call site `first_capture_extra` dispatches from
## (economy.gd's capture_score), rather than folded into that Artefact's own
## REGISTRY handler, so the two never share state and genuinely compose.
static func blood_in_the_air(g) -> bool:
	return g.next_army == "Wild Hunt"


## Hold the Line (Old Guard): read by game.gd's _lose_player_piece, AFTER
## ArtefactHooks.run(g, "on_piece_lost", ctx) returns — a structural
## post-dispatch check, same shape as that function's own lost_player/bounty-
## buff handling, never a direct g.gold write from inside a REGISTRY handler
## (the ctx contract, artefact_hooks.gd header). Selling never reaches this:
## _sell() erases straight from g.stock/g.captured and calls
## Economy.earn_gold directly, without ever calling _lose_player_piece — the
## hook placement gives the "no 150% money printer" safety catch for free.
static func hold_the_line(g) -> bool:
	return g.next_army == "Old Guard"
