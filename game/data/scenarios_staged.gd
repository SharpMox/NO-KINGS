## issue 95: the STAGED combo boards — hand-built, one per question.
##
## Issue 94 generates 34 boards from the hook graph, and they do what they were
## specced to do: prove two effects can reach each other. They do NOT stage the
## interaction — all 34 share one template and only the payload changes. These
## do the opposite: each board is built FOR its interaction, and is named for
## the QUESTION it settles rather than for the effect it holds (81's rule).
##
## Picked from 94's own graph (`scenarios_combos.pairs()`), not invented, but
## picked for DISPUTABILITY: every board below answers something a reasonable
## player would get wrong, and several build the control into the same board so
## the answer is a contrast rather than a memory of what usually happens.
##
## Hand-written, so they live apart from the generators. They are in their own
## file rather than in scenarios.gd's `_hand_written()` (where 81 put its 22)
## only because that list is already long; the distinction that matters —
## authored, not derived — is unchanged.
##
## EVERY BOARD CARRIES GOLD. Issue 98 priced merging, and issue 97 priced
## Captured -> Stock conversion; a staged board with no budget would fail to
## demonstrate anything the moment it needed either.

const Tuning := preload("res://scripts/tuning.gd")

## Player back rows are y 0-1, enemies come from the top. Staging puts the two
## sides within a move of each other so the interaction resolves in a couple of
## moves, not twenty (81's acceptance bar).
const GOLD := 400


static func all() -> Array:
	return [
	# --- what a capture ACTUALLY pays -------------------------------------
	{"name": "Combo: does a Shield-blocked attack still pay your capture Artefacts?", "cfg": {
		# The shielded pawn and the bare one are the same piece at the same
		# distance, so the Score difference between taking them IS the answer.
		"board": [["queen", 0, 3, 4],
			["pawn", 1, 3, 5, {"buffs": [{"key": "shield"}]}],
			["pawn", 1, 2, 5]],
		"artefacts": ["suspiciously-large-femur", "library-of-alexandria-matchbox"],
		"gold": GOLD, "score": 500}},
	{"name": "Combo: Reflect kills your attacker — does that pay capture or loss Artefacts?", "cfg": {
		# Holds one of each, so a single attack answers both halves at once.
		"board": [["queen", 0, 3, 4],
			["rook", 1, 3, 5, {"buffs": [{"key": "reflect"}]}]],
		"artefacts": ["suspiciously-large-femur", "27-club-punch-card", "backmasked-vinyl"],
		"gold": GOLD, "score": 500}},
	{"name": "Combo: does Multicapture's extra victim pay your capture Artefacts twice?", "cfg": {
		# Two enemies side by side: the extra victim is the whole question.
		"board": [["queen", 0, 3, 4, {"buffs": [{"key": "multicapture"}]}],
			["pawn", 1, 3, 5], ["pawn", 1, 4, 5]],
		"artefacts": ["suspiciously-large-femur", "library-of-alexandria-matchbox",
			"phantom-punch-glove"],
		"gold": GOLD, "score": 500}},
	{"name": "Combo: Destruction is not a capture — so what does Air Strike actually pay?", "cfg": {
		# One on-destroy Artefact and two on-capture ones. CONTEXT.md: a
		# destroyed piece awards no Score, no Gold and fires no per-capture
		# effect — but on_destroy is a real hook with a real listener.
		"board": [["queen", 0, 3, 4], ["rook", 1, 3, 6], ["pawn", 1, 2, 5]],
		"items": ["air_strike"],
		"artefacts": ["2-3-trillion-receipt", "suspiciously-large-femur",
			"library-of-alexandria-matchbox"],
		"gold": GOLD, "score": 500}},

	# --- losing pieces on purpose -----------------------------------------
	{"name": "Combo: your own Bomb takes your own pieces — do the on-loss Artefacts pay?", "cfg": {
		# The bomb carrier is a pawn with allies inside the blast, so the board
		# loses several pieces at once and the payout is unmistakable.
		"board": [["pawn", 0, 3, 4, {"buffs": [{"key": "bomb"}]}],
			["pawn", 0, 2, 4], ["pawn", 0, 4, 4], ["queen", 0, 3, 1],
			["rook", 1, 3, 5]],
		"artefacts": ["27-club-punch-card", "backmasked-vinyl", "d-b-cooper-s-parachute",
			"hoffa-s-cement-shoes"],
		"gold": GOLD, "score": 500}},
	{"name": "Combo: does Fireproof Pajamas veto the loss your own Bomb caused?", "cfg": {
		"board": [["pawn", 0, 3, 4, {"buffs": [{"key": "bomb"}]}],
			["pawn", 0, 2, 4], ["queen", 0, 3, 1], ["rook", 1, 3, 5]],
		"artefacts": ["fireproof-pajamas", "27-club-punch-card"],
		"gold": GOLD, "score": 500}},

	# --- Items pointed at the enemy ---------------------------------------
	{"name": "Combo: does Demoting an ENEMY fire your on-demote Artefacts?", "cfg": {
		# Demote's own text is "ally OR enemy", and hostile use is the half
		# nobody tries. The enemy is an end-tier piece so the drop is visible.
		"board": [["queen", 0, 3, 4], ["dragon-king", 1, 3, 6], ["pawn", 1, 2, 5]],
		"items": ["demote"],
		"artefacts": ["guidestone-blood-ritual"],
		"gold": GOLD, "score": 500}},
	{"name": "Combo: can Radar Jamming strip a Buff while Antikythera Warranty Card is held?", "cfg": {
		# The Card's whole text is that Buffs cannot be removed. Whether that
		# covers YOUR OWN Radar Jamming is the question.
		"board": [["queen", 0, 3, 4, {"buffs": [{"key": "shield"}, {"key": "critical"}]}],
			["pawn", 1, 3, 6]],
		"items": ["radar_jamming"],
		"artefacts": ["antikythera-warranty-card"],
		"gold": GOLD, "score": 500}},
	{"name": "Combo: which Items survive use with both 'not consumed' Artefacts held?", "cfg": {
		"board": [["queen", 0, 3, 4], ["pawn", 1, 3, 5], ["pawn", 1, 4, 5]],
		"items": ["air_strike", "blitz", "promote"],
		"artefacts": ["dihydrogen-monoxide-battery", "wardenclyffe-aaa-batteries",
			"tape-eraser-magnet"],
		"gold": GOLD, "score": 500}},

	# --- Army Powers feeding Artefacts ------------------------------------
	{"name": "Combo: does Hold the Line's refund feed your Gold-percentage Artefacts?", "cfg": {
		# Old Guard refunds a lost piece's value through Economy.earn_gold, so
		# the refund is a Gold GAIN — and Gold gains are what these listen to.
		"army": "Old Guard",
		"board": [["queen", 0, 3, 4], ["rook", 0, 2, 4], ["rook", 1, 3, 5], ["rook", 1, 2, 5]],
		"artefacts": ["tungsten-filled-gold-bar", "popemobile-piggy-bank",
			"denver-bunker-timeshare"],
		"gold": GOLD, "score": 500}},
	{"name": "Combo: does Hostile Takeover's spend trip Zero-Point Energy Drink at 0 Gold?", "cfg": {
		# Gold is set to exactly twice the target pawn's value, which is what
		# Hostile Takeover charges — so the purchase lands on precisely 0.
		"army": "Syndicate",
		"board": [["queen", 0, 3, 4], ["pawn", 1, 3, 6]],
		"artefacts": ["zero-point-energy-drink"],
		"gold": 20, "score": 500}},
	{"name": "Combo: does the Cult's Ritual fire your on-Buff Artefacts?", "cfg": {
		"army": "Cult",
		"board": [["queen", 0, 3, 4], ["rook", 0, 2, 4], ["pawn", 1, 3, 6]],
		"artefacts": ["mrna-firmware-update", "pied-piper-s-rat-census"],
		"gold": GOLD, "score": 500}},

	# --- the Shop as a trigger surface ------------------------------------
	{"name": "Combo: does a Mar-a-Lago restock re-price through your on-price Artefacts?", "cfg": {
		# Wave 5+: issue 101 keeps the Shop shut before then, and this board is
		# only about what happens inside it.
		"board": [["queen", 0, 3, 4], ["pawn", 1, 3, 8]],
		"artefacts": ["mar-a-lago-toilet-papers", "denazification-visa",
			"pandemic-toilet-paper-pallet", "shrinkflation-cereal-box"],
		"wave": 9, "gold": 1200, "score": 500}},
	{"name": "Combo: do Deep State Yearbook and the purchase Artefacts pay on the same buy?", "cfg": {
		"board": [["queen", 0, 3, 4], ["pawn", 1, 3, 8]],
		"artefacts": ["deep-state-yearbook", "putin-s-golden-toilet-brush",
			"seti-s-red-marker"],
		"wave": 9, "gold": 1200, "score": 500}},
	]
