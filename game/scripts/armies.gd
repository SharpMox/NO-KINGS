## Army catalog + Power lookups (issue 67) — pure logic module over the
## live game node `g`, same split as merge_logic.gd/item_logic.gd. A Army
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

## `power_fires` / `ability_fires` (issue 94) — the producer half of the hook
## graph, in `ArtefactHooks.HOOKS`' vocabulary. See items.gd's header for the
## relation; the same fields live on Items and Piece Buffs.
##
## EIGHT OF THE TWELVE ARE EMPTY, and that is the finding, not an omission.
## Most Army effects MODIFY a value at a call site rather than causing a hook
## to fire, so under issue 94's directed rule (`fires(X) ∩ listens(Y)`) they are
## not producers and generate no boards:
##
##   Close Ranks / Blood in the Air / Loose the Hounds — gate `actions_left` at
##     its own decrement site. No hook exists for spending an Action.
##   Insider Rates — applied at shop.gd:189, AFTER the on_price dispatch at
##     shop.gd:164. Every on_price listener sees the undiscounted price, so the
##     Power reaches none of them.
##   Communion — widens BuffLogic.cap(). Read, never dispatched.
##   Endless Ranks — zeroes a pawn's deploy cost at _place, past on_place_cost.
##   Call the Banners / Conscription — append to Stock, which fires nothing.
##
## The four that DO produce: Hold the Line calls Economy.earn_gold (on_gold_gain
## then on_gold_change), Shield Wall and Ritual both reach _apply_buff
## (on_buff_apply), and Hostile Takeover spends Gold (on_gold_zero, when the
## purchase lands the player exactly on 0).

const CATALOG := {
	"Crown": {
		"display_name": "The Muster",
		"starting_gold": Tuning.ARMY_BASELINE_GOLD,
		"starting_items": ["promote"],
		"power_name": "Close Ranks",
		"power_desc": "Merges cost no Action.",
		"power_fires": [],
		"ability_name": "Call the Banners",
		"ability_desc": "Duplicate a target piece from your Stock into your Stock.",
		"ability_fires": [],
		"ability_targeted": true,
	},
	"Wild Hunt": {
		"display_name": "Wild Hunt",
		"starting_gold": Tuning.ARMY_BASELINE_GOLD / 2,
		"starting_items": ["blitz", "blitz"],
		"power_name": "Blood in the Air",
		"power_desc": "Your first capture each Turn refunds its Action.",
		"power_fires": [],
		"ability_name": "Loose the Hounds",
		"ability_desc": "This Turn, your pieces' moves cost no Actions. Captures still pay.",
		"ability_fires": [],
		"ability_targeted": false,
	},
	"Old Guard": {
		"display_name": "Old Guard",
		"starting_gold": Tuning.ARMY_BASELINE_GOLD / 2,
		"starting_items": ["extraction"],
		"power_name": "Hold the Line",
		"power_desc": "When you lose a piece, refund its full value in Gold.",
		"power_fires": ["on_gold_gain", "on_gold_change"],
		"ability_name": "Shield Wall",
		"ability_desc": "Every piece on your back two rows gains Shield.",
		"ability_fires": ["on_buff_apply"],
		"ability_targeted": false,
	},
	"Syndicate": {
		"display_name": "The Syndicate",
		"starting_gold": Tuning.ARMY_BASELINE_GOLD * 3,
		"starting_items": [],
		"power_name": "Insider Rates",
		"power_desc": "Shop buy prices -25%, sell payouts +25%.",
		"power_fires": [],
		"ability_name": "Hostile Takeover",
		"ability_desc": "Pay 200% of a target enemy piece's value: it leaves the board and joins your Stock.",
		"ability_fires": ["on_gold_zero"],
		"ability_targeted": true,
	},
	"Cult": {
		"display_name": "The Cult",
		"starting_gold": Tuning.ARMY_BASELINE_GOLD,
		"starting_items": ["buff_box"],
		"starting_artefact_count": 2, # issue 68: 2 random Artefacts at run start
		"power_name": "Communion",
		"power_desc": "Your Piece Buff cap is 3.",
		"power_fires": [],
		"ability_name": "Ritual",
		"ability_desc": "Grant a target piece a random Buff.",
		"ability_fires": ["on_buff_apply"],
		"ability_targeted": true,
	},
	"Horde": {
		"display_name": "The Horde",
		"starting_gold": Tuning.ARMY_BASELINE_GOLD,
		"starting_items": [],
		"power_name": "Endless Ranks",
		"power_desc": "Pawn deploys cost no Gold.",
		"power_fires": [],
		"ability_name": "Conscription",
		"ability_desc": "Add 2 pawns to your Stock.",
		"ability_fires": [],
		"ability_targeted": false,
	},
}


## `id`'s catalog entry, falling back to the default army for an
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


## Insider Rates (The Syndicate, issue 68): read by shop.gd's price()/
## sell_payout(). Deliberately NOT read by shop.gd's sell_price() — the
## Captured -> Stock conversion cost (game.gd._convert_captured) and a plain
## sell payout share that one function, and conversion must stay at the flat
## Tuning.SELL_RATE: "it is not a Shop purchase, and discounting it would
## reopen the convert/sell arbitrage that equal rates deliberately closed"
## (issue 68's own ruling; see SELL_RATE's own header for the arbitrage).
static func insider_rates(g) -> bool:
	return g.next_army == "Syndicate"


## Communion (The Cult, issue 68): +1 Piece Buff cap, additive with Abduction
## Probe — read by game.gd's _apply_buff alongside its existing
## _artefact_count("abduction-probe") term so the two SUM (base 2 + probe +
## Communion), never dedupe: "Communion + Abduction Probe = cap 4" (issue 68).
static func communion(g) -> bool:
	return g.next_army == "Cult"


## Endless Ranks (The Horde, issue 68): pawn deploys cost no Gold — read by
## game.gd's _place(), scoped there to `id == "pawn"` (majors still pay full
## price, though Horde's own kit fields none).
static func endless_ranks(g) -> bool:
	return g.next_army == "Horde"
