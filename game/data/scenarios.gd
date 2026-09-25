## Test scenarios: each is a plain config Dictionary the game can boot from
## (game.gd/_apply_config). The config shape doubles as the future save format.
##
## Config keys (all optional):
##   board: Array of [piece_id, owner(0/1), x, y]
##   stock / captured: Array of piece ids
##   items / artefacts: Array of catalog keys
##   tariffs: Array of tariff keys (action/persistent, added active)
##   oneoffs: Array of one-off tariff keys, applied after setup
##   wave: int (default = all waves done, so no spawns disturb the sandbox)
##   clock_s: float seconds (default = normal budget)
##   score: int

const Tuning := preload("res://scripts/tuning.gd")

const ZONE_PAWNS := [["pawn", 0, 1, 0], ["pawn", 0, 4, 0]]

## issue 79: the 180 generated per-Artefact sandboxes are appended by all(),
## not listed here — see scenarios_artefacts.gd for why they are derived from
## ArtefactHooks.REGISTRY rather than hand-written.
const Generated := preload("res://data/scenarios_artefacts.gd")

## issue 80: likewise one per piece, derived from data/pieces.json.
const GeneratedPieces := preload("res://data/scenarios_pieces.gd")

## issue 82: likewise one per King, derived from Kings.ROSTER.
const GeneratedKings := preload("res://data/scenarios_kings.gd")

## issue 94: the Combo boards, derived from the fires/listens hook graph.
const GeneratedCombos := preload("res://data/scenarios_combos.gd")

## issue 95: the STAGED combo boards — hand-built, one per question, picked
## from 94's graph for disputability rather than derived from it.
const StagedCombos := preload("res://data/scenarios_staged.gd")


static func _chain(title: String, base: String, mid: String) -> Dictionary:
	# issue 98: merging now costs Gold, so a chain sandbox needs a budget or it
	# demonstrates nothing — the board exists to walk a promotion chain by hand.
	return {"name": "Promote: %s" % title, "cfg": {
		"board": ZONE_PAWNS, "stock": [base, base, mid, mid], "score": 500,
		"gold": 300}}


static func all() -> Array:
	return _hand_written() + Generated.all() + GeneratedPieces.all() \
		+ GeneratedKings.all() + GeneratedCombos.all() + GeneratedCombos.anti_all() \
		+ StagedCombos.all()


## Index of the scenario called `scenario_name` in all(), or -1. The CLI's
## `--scenario-name` resolves through here, because `--scenario N` shifts
## whenever a scenario is inserted above N (tools/capture.md).
static func find(scenario_name: String) -> int:
	var list := all()
	for i in list.size():
		if list[i].name == scenario_name:
			return i
	return -1


static func _hand_written() -> Array:
	return [
		# --- core interactions ---
		{"name": "Movement & drag", "cfg": {
			"board": [["queen", 0, 2, 1], ["knight", 0, 3, 1], ["arrow-pawn", 0, 1, 0], ["kirin", 0, 4, 0]]}},
		{"name": "Captures & highlights", "cfg": {
			"board": [["queen", 0, 2, 2], ["knight", 0, 4, 2], ["pawn", 1, 2, 5], ["bishop", 1, 3, 4], ["rook", 1, 5, 3]]}},
		# NO-224: the Pawn's initial two-square move. Four pawns side by side —
		# unmoved (double-step available), already moved (single only), an
		# unmoved one BLOCKED by a piece on the intervening square (mW2cF
		# precedent: it slides, doesn't jump) — plus an unmoved enemy pawn
		# with nothing else on the board, so the greedy AI's own best-advance
		# pick exercises the double-step on its turn.
		{"name": "Pawn double-step (NO-224)", "cfg": {
			"board": [
				["pawn", 0, 1, 1],
				["pawn", 0, 3, 1, {"moved": true}],
				["pawn", 0, 5, 1], ["pawn", 0, 5, 2],
				["pawn", 1, 6, 10],
			]}},
		# NO-232: en passant, turn-scoped (Max's ruling — softened from
		# chess's "next move" to "next TURN"). The lone enemy pawn's single
		# step (3,10)->(3,9) walks straight into the player pawn's ordinary
		# diagonal capture — _move_value prices that at -10 and _pick drops
		# it outright — so the double-step (3,10)->(3,8), which lands out of
		# that range, is the AI's only surviving candidate and its own first
		# turn exercises it, same as NO-224's own sandbox relies on the
		# greedy AI for. From there the player pawn's ordinary diagonal
		# capture already reaches the skip square (3,9): select (2,8),
		# then tap (3,9) to capture en passant.
		{"name": "En passant (NO-232)", "cfg": {
			"board": [["pawn", 0, 2, 8], ["pawn", 1, 3, 10]]}},
		# NO-233: same AI double-step setup as the sandbox above — capture
		# en passant the same way (select (2,8), tap (3,9)) — plus a knight
		# and a bishop beside the victim's REAL square (3,8), NOT the empty
		# landing square (3,9). Multicapture and Exhibit 399 both search
		# "beside the piece just captured" from that real square, so one
		# extra piece goes to each.
		{"name": "En passant + Multicapture + Exhibit 399 (NO-233)", "cfg": {
			"board": [["pawn", 0, 2, 8, {"buffs": [{"key": "multicapture"}]}],
				["pawn", 1, 3, 10], ["knight", 1, 3, 7], ["bishop", 1, 2, 7]],
			"artefacts": ["exhibit-399"]}},
		{"name": "Waves & cadence", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1]], "wave": 1, "stock": ["pawn", "pawn"]}},
		{"name": "Spawn overflow: full top row (friendly capture + spillover)", "cfg": {
			"board": [["queen", 0, 2, 1],
				["pawn", 0, 0, 11], ["pawn", 0, 1, 11], ["pawn", 0, 2, 11], ["pawn", 0, 3, 11],
				["pawn", 0, 4, 11], ["pawn", 0, 5, 11], ["pawn", 0, 6, 11], ["pawn", 0, 7, 11]],
			"wave": 1, "score": 500}},
		{"name": "Captured stock: convert & sell", "cfg": {
			"board": ZONE_PAWNS, "captured": ["rook", "rook", "knight", "pawn"],
			"stock": ["pawn"], "score": 500, "wave": 5}},
		# NO-84: both Stock Drawer grids full at once — Captured Stock never
		# stacks (one row per piece), so fourteen distinct captured pieces
		# force that column to scroll; the large Stock does the same for the
		# right column, mixing duplicates (real stacks) with distinct ids.
		{"name": "Stock Drawer: full Captured Stock and a large Stock", "cfg": {
			"board": ZONE_PAWNS, "score": 500, "wave": 5, "gold": 1000,
			"captured": ["rook", "knight", "bishop", "queen", "ferz", "wazir",
				"champion", "archbishop", "chancellor", "gnu", "buffalo",
				"kirin", "alibaba", "squirrel"],
			"stock": ["pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn",
				"rook", "rook", "rook", "knight", "knight", "bishop", "queen",
				"ferz", "wazir", "champion", "gnu", "buffalo"]}},
		# NO-85: the Inventory Drawer's one scrolling column (Items grid, then
		# Artefacts grid) with enough of each to force a scroll — several
		# Items, several passive Artefacts and two ✹ Artefacts mixed into the
		# same grid (story 50).
		{"name": "Inventory Drawer: several Items, passive and ✹ Artefacts", "cfg": {
			"board": ZONE_PAWNS, "score": 500, "wave": 5, "gold": 1000,
			"items": ["blitz", "sniper", "air_strike", "demote", "promote",
				"invert", "tactical_reposition", "decoy_swap"],
			"artefacts": ["27-club-punch-card", "tinfoil-hat",
				"area-51-parking-permit", "fort-knox-iou",
				"fema-summer-camp-flyer", "zurich-gnome-figurine",
				"nero-s-marshmallow-stick", "pre-scratched-lottery-ticket",
				"oak-island-wishing-well", "fifa-complimentary-yacht"]}},
		{"name": "Early clear: bonus for beating the cadence", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]],
			"wave": 2, "stock": ["pawn"], "score": 100}},
		{"name": "Shop: browse & buy (gold, SOLD, reroll at 10s)", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"wave": 9, "gold": 400, "stock": ["pawn"]}},
		{"name": "Reinforcements: post-wave-10 shop", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"wave": 11, "score": 300, "stock": ["pawn"], "pending_reinforce": true}},
		{"name": "Economy: Blitz + First-Capture bonus actions", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4], ["pawn", 1, 4, 4], ["rook", 1, 5, 6]],
			"items": ["blitz"], "artefacts": ["stargate-divination-crystal"], "score": 200, "wave": 3}},
		# win-screen tests: King one queen-move away, capture it to trigger the
		# screen — wave 50 = Continue/End Run, wave >= 201 = FULL CLEAR game over.
		#
		# The full-clear entry below was named "@ wave 200" and set `wave: 200`
		# against a table that stopped at 150. That satisfied
		# `wave >= WAVES.size()`, so it exercised the FULL CLEAR branch at a wave
		# real play could never arrive at — passing, but for the wrong reason.
		# The comment above tracked the truncation ("wave >= 150") and the
		# scenario NAME did not, which is how the two drifted apart unnoticed.
		# The lesson generalises: a name that drifts from what a test actually
		# exercises hides a test that has stopped testing anything. It names
		# Larry's wave now, and that wave exists.
		# NO-100: the King carries a real identity. Without one the win screen
		# (captured with --show-screen win, so no fall is recorded) read "The
		# wave-50 King, King, has fallen" — a real wave-50 King always has one
		# (WaveLogic.queue stamps king_id on every spawned King).
		{"name": "Win screen: wave 50 (capture King)", "cfg": {
			"board": [["queen", 0, 3, 8], ["king", 1, 3, 10, {"king_id": "nero"}]],
			"wave": 50, "score": 1000}},
		{"name": "Win screen: named King (identity, issue 09)", "cfg": {
			"board": [["queen", 0, 3, 8], ["king", 1, 3, 10, {"king_id": "nero"}]],
			"wave": 50, "score": 1000}},
		{"name": "Win screen: full clear @ wave 201 (capture Larry)", "cfg": {
			"board": [["queen", 0, 3, 8], ["king", 1, 3, 10]],
			"wave": 201, "score": 5000}},
		{"name": "Larry: wave 201, the 17th boss and the full clear", "cfg": {
			"board": [["queen", 0, 3, 8], ["king", 1, 3, 10, {"king_id": "larry"}],
				["godzilla", 1, 2, 10], ["amazon", 1, 4, 10]],
			"wave": 201, "kings_defeated": 4, "score": 9000}},
		{"name": "King wave 200 (the 4th King — order[3], reachable at last)", "cfg": {
			"board": [["queen", 0, 2, 2], ["rook", 0, 0, 1],
				["king", 1, 3, 10], ["godzilla", 1, 2, 10], ["raven", 1, 4, 10]],
			"wave": 200, "kings_defeated": 3, "score": 5000}},
		{"name": "Recurring King (wave 150: run continues, no longer a full clear)", "cfg": {
			"board": [["queen", 0, 3, 8], ["king", 1, 3, 10], ["rook", 1, 2, 10]],
			"wave": 150, "kings_defeated": 2, "score": 4000}},
		{"name": "Recurring King (wave 100: bonus + refill, run continues)", "cfg": {
			"board": [["queen", 0, 3, 8], ["king", 1, 3, 10], ["rook", 1, 2, 10]],
			"wave": 100, "kings_defeated": 1, "score": 3000}},
		{"name": "King wave (checkmate to win)", "cfg": {
			"board": [["queen", 0, 2, 2], ["rook", 0, 0, 1], ["rook", 0, 5, 1],
				["king", 1, 3, 10], ["rook", 1, 2, 10], ["bishop", 1, 4, 10]],
			"wave": 50, "score": 1000}},
		# --- NO-83: the Header ---
		# Donald Trump with THREE Tariffs already in force (his Power escalates
		# every KING_TARIFF_STACK_TURNS turns; turns_since_wave 20 is what
		# stack_power_if_due would have reached by itself). ⧖ reads his name;
		# double-tap the King to read the three in his info panel.
		{"name": "Header: King Wave — Donald Trump, Tariffs in force", "cfg": {
			"board": [["queen", 0, 2, 2], ["rook", 0, 0, 1], ["rook", 0, 5, 1],
				["king", 1, 3, 10, {"king_id": "donald_trump"}], ["rook", 1, 2, 10], ["bishop", 1, 4, 10]],
			"wave": 50, "score": 1000, "gold": 300, "turns_since_wave": 20,
			"king_power_id": "donald_trump",
			"king_abilities": ["move_cost", "inflation", "capture_cost"],
			"king_power_abilities": ["move_cost", "inflation", "capture_cost"]}},
		# Wave 51 after the win: ⚑ reads 51/201, ⧖ counts toward Wave 52.
		{"name": "Header: Wave 51 after the win", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"wave": 51, "kings_defeated": 1, "score": 2000, "stock": ["pawn"]}},
		# NO-80: Donald Trump enters at the START of his wave. Boots one END
		# TURN short of wave 50 (cadence 6 + 5 pieces) with him first in the
		# line-up, so the next turn queues his wave and he lands at once — the
		# entry path itself, not a board pre-seeded with him.
		{"name": "King wave: Donald Trump from turn 0 (NO-80)", "cfg": {
			"board": [["queen", 0, 2, 2], ["rook", 0, 0, 1], ["rook", 0, 5, 1]],
			"wave": 49, "turns_since_wave": 10,
			"king_order": ["donald_trump", "benjamin_netanyahu", "vladimir_putin", "kim_jong_un"],
			"score": 1000}},
		# --- merging ---
		# NO-100 review (2026-09-24): merges happen on the board only, so each
		# Stock piece here has a board partner; Captured never merges.
		{"name": "Merge: a Stock pawn onto a board pawn", "cfg": {
			"board": ZONE_PAWNS, "stock": ["pawn", "pawn"],
			"captured": ["pawn", "pawn", "rook", "rook"], "gold": 300}},
		{"name": "Merge: fusions (bishop+rook, knight+rook, ...)", "cfg": {
			"board": ZONE_PAWNS + [["rook", 0, 2, 1], ["wazir", 0, 5, 1]],
			"captured": ["rook", "rook", "bishop", "knight", "kirin"],
			"stock": ["alibaba", "bishop", "knight"], "gold": 300}},
		{"name": "Merge: on the board", "cfg": {
			"board": ZONE_PAWNS + [["ferz", 0, 2, 1], ["ferz", 0, 3, 1], ["bishop", 0, 4, 1], ["rook", 0, 5, 1]], "gold": 300}},
		_chain("Pawn chain", "pawn", "sergeant"),
		_chain("Seer chain", "ferz", "elephant-modern"),
		_chain("Mage chain", "wazir", "war-machine"),
		_chain("Bishop chain", "bishop", "dragon-horse"),
		_chain("Rook chain", "rook", "dragon-king"),
		_chain("Knight chain", "knight", "gnu"),
		_chain("Long Ma chain", "kirin", "kirin-plus"),
		_chain("Duchess chain", "alibaba", "bodyguard"),
		# --- reward economy ---
		{"name": "Boxes (Shop, issue 47: 9 typed Boxes)", "cfg": {
			"board": [["queen", 0, 3, 3], ["knight", 0, 1, 3]], "wave": 3, "gold": 2000}},
		# NO-45 needs a drag that STARTS ON an artefact row, and until now no
		# scenario held more than ONE artefact — the generated per-artefact ones
		# hold exactly one each — so the drawer never had enough rows to scroll
		# and the question could not be answered on any device. EIGHT rows was
		# not enough: measured, they overflow the drawer by 2px, leaving 2px of
		# scrollable range and an assertion that could barely fail. Sixteen
		# leaves real room, and the probe asserts the margin rather than a bare
		# inequality so this cannot go vacuous unnoticed.
		# All PASSIVE keys — predates NO-85, which merged activatable Artefacts
		# into this same grid; kept passive-only since nothing needs it mixed.
		{"name": "Artefacts: sixteen held, so the drawer list actually scrolls", "cfg": {
			"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
			"artefacts": ["27-club-punch-card", "tinfoil-hat",
				"area-51-parking-permit", "fort-knox-iou",
				"fema-summer-camp-flyer", "zurich-gnome-figurine",
				"nero-s-marshmallow-stick", "pre-scratched-lottery-ticket",
				"tungsten-filled-gold-bar", "crop-circle-plank",
				"mar-a-lago-toilet-papers", "suspiciously-large-femur",
				"daylight-savings-jar", "phantom-punch-glove",
				"naruto-run-manual", "social-credit-report-card"],
			"wave": 3, "gold": 200}},
		{"name": "Items: full inventory", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 0, 3, 1], ["pawn", 0, 1, 1],
				["pawn", 1, 2, 6], ["bishop", 1, 4, 6], ["rook", 1, 1, 8], ["knight", 1, 3, 8]],
			"items": ["blitz", "sniper", "air_strike", "demote", "promote", "invert",
				"surprise_attack", "tactical_reposition", "rapid_deployment",
				"decoy_swap", "asset_recovery", "radar_jamming", "counter_intel",
				"drone_strike", "extraction"],
			"stock": ["pawn", "pawn"], "score": 500, "wave": 1}},
		# NO-23: capture the rook to clear the wave. Under 10 Gold, Fort Knox
		# IOU opens a Small Item Box; the inventory is already at the base cap
		# (2), so NO-38's sell row is what makes the pick land — sell one,
		# then pick one. Before NO-23 this grant was silently dropped.
		{"name": "NO-23: Fort Knox IOU opens a Small Item Box at a full inventory", "cfg": {
			"board": [["queen", 0, 2, 2], ["rook", 1, 2, 6]],
			"items": ["blitz", "sniper"], "gold": 5,
			"artefacts": ["fort-knox-iou"], "wave": 3}},
		{"name": "Piece Buffs (Buff Box: pick, target, Shield/Critical)", "cfg": {
			"board": [["queen", 0, 2, 1, {"buffs": [{"key": "critical"}]}],
				["pawn", 0, 3, 1], ["rook", 1, 2, 6, {"buffs": [{"key": "shield"}]}],
				["bishop", 1, 4, 6], ["knight", 1, 3, 8]],
			"items": ["buff_box", "buff_box", "radar_jamming"],
			"stock": ["pawn"], "score": 500, "wave": 1}},
		{"name": "Piece Buffs: timed (Slow/Aura/Smog) + Reflect", "cfg": {
			"board": [["queen", 0, 2, 1, {"buffs": [{"key": "aura", "turns": 2}]}],
				["knight", 0, 3, 1], ["bishop", 0, 1, 1, {"buffs": [{"key": "slow", "turns": 1}]}],
				["rook", 1, 2, 5, {"buffs": [{"key": "reflect"}]}],
				["rook", 1, 4, 6, {"buffs": [{"key": "smog", "turns": 2}]}],
				["knight", 1, 3, 8]],
			"items": ["buff_box"], "stock": ["pawn"], "score": 500, "wave": 1}},
		{"name": "Piece Buffs: Range / Trap / Taunt / Stun", "cfg": {
			"board": [["rook", 0, 2, 1, {"buffs": [{"key": "range"}]}],
				["pawn", 0, 3, 1, {"buffs": [{"key": "taunt"}]}],
				["pawn", 0, 1, 1, {"buffs": [{"key": "stun"}]}],
				["queen", 0, 4, 1, {"buffs": [{"key": "trap"}]}],
				["knight", 0, 5, 1, {"buffs": [{"key": "multicapture"}]}],
				["pawn", 0, 6, 1, {"buffs": [{"key": "bomb"}]}],
				["rook", 1, 2, 5], ["pawn", 1, 3, 5], ["knight", 1, 3, 8]],
			"items": ["buff_box"], "stock": ["pawn"], "score": 500, "wave": 1}},
		# NO-122: bomb blast + drone strike zone previews. Queen at (3,3)
		# carries bomb and can legally capture the pawn at (4,4), so
		# selecting it exercises both preview triggers (piece selected,
		# capture destination); "drone_strike" gives the other preview
		# a live anchor to arm.
		{"name": "NO-122: bomb blast + drone strike zone preview", "cfg": {
			"board": [["queen", 0, 3, 3, {"buffs": [{"key": "bomb"}]}], ["pawn", 1, 4, 4]],
			"items": ["drone_strike"], "score": 500, "wave": 1}},
		# --- NO-81: Exhibit 399 — the queen's first Capture destroys a random
		# adjacent enemy (not the King). Capture (3,5) from (3,3).
		{"name": "Exhibit 399: several adjacent enemies", "cfg": {
			"board": [["queen", 0, 3, 3], ["pawn", 1, 3, 5], ["knight", 1, 2, 6], ["bishop", 1, 4, 6],
				["pawn", 1, 4, 5], ["rook", 1, 7, 10]],
			"artefacts": ["exhibit-399"], "score": 500, "wave": 3}},
		{"name": "Exhibit 399 + Multicapture", "cfg": {
			"board": [["queen", 0, 3, 3, {"buffs": [{"key": "multicapture"}]}], ["pawn", 1, 3, 5],
				["rook", 1, 4, 5], ["knight", 1, 2, 6], ["pawn", 1, 4, 6], ["rook", 1, 7, 10]],
			"artefacts": ["exhibit-399"], "score": 500, "wave": 3}},
		{"name": "Exhibit 399: King adjacent", "cfg": {
			"board": [["queen", 0, 3, 6], ["pawn", 1, 3, 9], ["king", 1, 3, 10],
				["rook", 1, 0, 10], ["bishop", 1, 7, 10]],
			"artefacts": ["exhibit-399"], "score": 500, "wave": 50}},
		{"name": "Artefacts: mixed simple triggers", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 1, 2, 4], ["pawn", 1, 3, 4], ["rook", 1, 4, 5]],
			"artefacts": ["stargate-divination-crystal", "library-of-alexandria-matchbox",
				"cia-exploding-cigar", "2012-doomsday-party-hat", "voynich-dictionary",
				"suspiciously-large-femur", "nero-s-marshmallow-stick"],
			"wave": 9, "stock": ["pawn"]}},
		{"name": "Artefacts: Gold/Score batch (issue 16)", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 1, 2, 4], ["pawn", 1, 3, 4], ["rook", 1, 4, 5]],
			"artefacts": ["tinfoil-hat", "tungsten-filled-gold-bar", "zurich-gnome-figurine",
				"nero-s-marshmallow-stick", "suspiciously-large-femur",
				"social-credit-report-card", "john-titor-s-crypto-wallet"],
			"gold": 100, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: slice 17 (Action/Time/Piece)", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1], ["bishop", 0, 1, 1], ["knight", 0, 4, 1],
				["pawn", 0, 0, 1], ["pawn", 0, 5, 1], ["pawn", 0, 6, 1], ["pawn", 0, 7, 1],
				["pawn", 1, 2, 5], ["rook", 1, 4, 6]],
			"items": ["blitz", "sniper", "demote"],
			"artefacts": ["cia-exploding-cigar", "i-am-not-a-robot-checkbox", "seed-vault-secret-hatch",
				"super-soldier-multivitamins", "stargate-divination-crystal", "5g-microchips",
				"terracotta-draft-card", "charlemagne-s-birth-certificate"],
			"wave": 3, "score": 200, "stock": ["pawn"]}},
		{"name": "Artefacts: Shop/Item/Buff batch (issue 18)", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 1, 2, 4], ["pawn", 1, 3, 4], ["rook", 1, 4, 5]],
			"artefacts": ["denazification-visa", "hollow-moon-cross-section", "chocolate-key-cake",
				"sub-antarctic-visa", "crop-circle-plank", "mk-ultra-sugar-cube",
				"frame-25", "sleeper-agent-pillow"],
			"gold": 200, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: slice 19 (Special + prereqs)", "cfg": {
			"board": [["pawn", 0, 2, 1], ["pawn", 0, 3, 1], ["queen", 0, 4, 1],
				["pawn", 1, 2, 5], ["pawn", 1, 3, 5], ["rook", 1, 4, 6]],
			"items": ["air_strike", "drone_strike", "buff_box"],
			"artefacts": ["satoshi-s-private-key", "flight-19-blackbox",
				"arms-fair-goodie-bag", "dihydrogen-monoxide-battery",
				"witness-protection-mustache", "cia-heart-attack-gun",
				"dyatlov-geiger-counter", "merchants-of-death-sample-case",
				"tunguska-toothpicks"],
			"king_abilities": ["move_cost"], "gold": 100, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: issue 25 (per-piece capture ledger)", "cfg": {
			"board": [["queen", 0, 2, 1, {"captures": 2, "wave_captures": 1}],
				["pawn", 0, 3, 1], ["pawn", 1, 2, 5], ["pawn", 1, 3, 5, {"captures": 1}],
				["rook", 1, 4, 6]],
			"artefacts": ["chupacabra-chew-toy", "zodiac-crossword-puzzle", "alien-rocket-toy"],
			"gold": 50, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: slice 22 (tariff interception)", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1], ["pawn", 1, 2, 5], ["bishop", 1, 4, 5]],
			"artefacts": ["panama-papers-shredder", "amber-room-bubble-wrap",
				"ark-grounding-cable", "salvation-gift-card"],
			"king_abilities": ["move_cost", "inflation", "deploy_cost"],
			"gold": 200, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: economy & Box batch (issue 26)", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 1, 2, 4], ["pawn", 1, 3, 4], ["rook", 1, 4, 5]],
			"artefacts": ["haarp-volume-knob", "wuhan-vial-label", "pigeon-charging-cable",
				"pre-scratched-lottery-ticket", "hitler-s-argentinian-passport",
				"nazca-boarding-pass", "nuclear-football-menu", "ark-s-bunkbed",
				"trojan-horse-assembly-manual", "jon-burrows-fake-id",
				"walt-s-cryonic-capsule", "27-club-punch-card",
				"doomsday-clock-snooze-button", "zero-point-energy-drink",
				"agartha-welcome-mat"],
			"items": ["counter_intel"],
			"gold": 200, "wave": 4, "stock": ["pawn"], "clock_s": 40.0}},
		{"name": "Artefacts: issue 31 (capture-context effects)", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 1, 2, 4], ["pawn", 1, 3, 4],
				["pawn", 1, 4, 4], ["rook", 1, 5, 6]],
			"artefacts": ["curtain-rods-bag-rifle-shaped", "templar-debit-card",
				"2-3-trillion-receipt"],
			"items": ["drone_strike"], # destroy a pawn for the Receipt; capture the
				# other two for Curtain Rods Bag's first-Capture-each-Wave bonus
			"score": 200, "gold": 20, "wave": 4, "stock": ["pawn"]}}, # low Gold, enough
			# Score to test Templar Debit Card paying a Shop cost's shortfall
		{"name": "Artefacts: slice 21 (echo and meta-triggers)", "cfg": {
			"board": [["pawn", 0, 2, 1], ["pawn", 0, 3, 1], ["queen", 0, 4, 1],
				["pawn", 1, 2, 5], ["pawn", 1, 3, 5], ["rook", 1, 4, 6]],
			"artefacts": ["voynich-dictionary", "zurich-gnome-figurine", "d-b-cooper-s-parachute",
				"polybius-cartridge", "max-headroom-mask", "red-diary-s-missing-pages",
				"cern-ctrl-z-shortcut", "bilderberg-hotel-slippers",
				"illuminati-nwo-booster-pack", "100-genuine-original-mona-lisa",
				"deja-vu-glitch", "capstone-polish"],
			"gold": 100, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: issue 29 (rarity metadata + Illuminati Fridge Magnet)", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1], ["pawn", 1, 2, 5], ["bishop", 1, 4, 5]],
			"artefacts": ["illuminati-fridge-magnet", "fema-summer-camp-flyer", # Rare + Common
				"putin-s-golden-toilet-brush", "cia-exploding-cigar"], # Uncommon + Legendary
			"gold": 100, "wave": 3, "stock": ["pawn"]}},
		{"name": "Artefacts: slice 30 (action log — Elvish Hard Hat)", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1], ["pawn", 1, 2, 5], ["bishop", 1, 4, 6]],
			"items": ["counter_intel", "blitz"],
			"artefacts": ["elvish-hard-hat"],
			"gold": 100, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: slice 35 (Clock-gain choke point — lifesteal, King refill, Black Knight)", "cfg": {
			# issue 69 repointed "lifesteal" (removed game-native key, the
			# only on_capture Clock-gain artefact) to 2012 Doomsday Party Hat
			# (on_gold_change, +5s per 10 Gold) — no surviving catalog
			# Artefact grants Clock on_capture, so this exercises the same
			# add_clock() choke point via a different hook instead. The name
			# itself is left as-is (not updated to mention the new key): a
			# longer name here pushes the "TEST" scroll list's "← Back"
			# button out of position in the fixed 480x800 menu window and
			# breaks test_menu_clicks.gd — found empirically bisecting a
			# menu-clicks regression, see PR notes.
			"board": [["queen", 0, 2, 1], ["king", 1, 2, 4], ["pawn", 1, 3, 5], ["rook", 1, 4, 6]],
			"artefacts": ["2012-doomsday-party-hat", "black-knight-morse-code"],
			"gold": 100, "score": 0, "clock_s": 90.0, "wave": 99, "kings_defeated": 1,
			"stock": ["pawn"]}}, # a recurring King refill on top of lifesteal/Black
			# Knight's own Clock hooks, and a 3rd-Turn cadence within easy reach
		{"name": "Artefacts: slice 42 (peak-rank stamp — Dark Market Light Bulb)", "cfg": {
			"board": [["sergeant", 0, 2, 1], # already Ranked
				["pawn", 0, 3, 1, {"peak_ranked": true}], # Demoted: below its own peak
				["pawn", 0, 4, 1], # never Ranked — the control case
				["pawn", 1, 2, 5], ["pawn", 1, 3, 5], ["rook", 1, 4, 6]],
			"items": ["demote", "promote"], # demote the sergeant, then promote the
				# demoted pawn back — the sandbox for "clears on re-promotion"
			"artefacts": ["dark-market-light-bulb"],
			"gold": 100, "wave": 4, "stock": ["pawn"]}},
		{"name": "Artefacts: activation, confirm-gated (issue 52)", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1], ["pawn", 1, 2, 5], ["rook", 1, 4, 6]],
			"artefacts": ["oak-island-wishing-well", "fifa-complimentary-yacht",
				"moscovium-glow-stick", "roanoke-hex-kit", "zapruder-s-director-s-cut"],
			"gold": 500, "score": 0, "wave": 10, "stock": ["pawn"]}}, # generous
			# Gold/wave so the bot's per-frame activation roll (autoplay.gd) has
			# a real shot at Oak Island/FIFA/Moscovium landing within the sweep
		{"name": "Artefacts: activation, targeted — Bovine Tractor Beam (issue 52)", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 1, 4, 6]],
			"artefacts": ["bovine-tractor-beam"], "wave": 3, "stock": ["pawn"]}},
		{"name": "Extraction (rescue pieces to Stock)", "cfg": {
			"board": [["dragon-king", 0, 2, 2], ["knight", 0, 3, 3], ["pawn", 0, 1, 2],
				["rook", 1, 4, 8], ["bishop", 1, 2, 7]],
			"items": ["extraction"], "wave": 7, "stock": ["pawn"]}},
		{"name": "Drone Strike (3x3 wipe, King immune)", "cfg": {
			"board": [["queen", 0, 1, 1], ["pawn", 0, 4, 6], ["pawn", 1, 3, 5],
				["bishop", 1, 2, 4], ["king", 1, 3, 4], ["rook", 1, 6, 9]],
			"items": ["drone_strike"], "wave": 5, "stock": ["pawn"]}},
		{"name": "Counter-Intel (suppress live tariffs)", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1], ["pawn", 1, 2, 5], ["bishop", 1, 4, 5]],
			"items": ["counter_intel"], "king_abilities": ["move_cost", "inflation"],
			"gold": 100, "wave": 11, "stock": ["pawn"]}},
		# --- tariffs ---
		{"name": "Tariffs: all action costs", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 0, 3, 1], ["pawn", 1, 2, 5], ["bishop", 1, 4, 5]],
			"king_abilities": ["move_cost", "capture_cost", "deploy_cost", "pass_cost",
				"long_range_cost", "ability_cost", "fuse_cost"],
			"gold": 500, "items": ["blitz"], "captured": ["pawn", "pawn"], "stock": ["pawn"], "score": 1000}},
		{"name": "Tariffs: all persistent", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 1, 3, 6]],
			"king_abilities": ["inflation"],
			"stock": ["pawn", "pawn", "rook"], "captured": ["pawn", "pawn"], "wave": 8, "score": 1000}},
		{"name": "One-off: JD Vance", "cfg": {
			"board": ZONE_PAWNS + [["queen", 0, 3, 1]], "oneoffs": ["jd_vance"]}},
		# --- full piece set ---
		{"name": "Showcase: riders & voids", "cfg": {
			"board": [["gryphon", 0, 0, 1], ["manticore", 0, 2, 1], ["godzilla", 0, 4, 1],
				["banshee", 0, 6, 1], ["raven", 0, 1, 0], ["amazonrider", 0, 3, 0],
				["berolina", 0, 5, 0], ["inv-sergeant", 0, 7, 0], ["inv-arrow-pawn", 0, 7, 1],
				["inv-kirin-plus", 0, 6, 0], ["inv-kirin-plus-plus", 0, 0, 0],
				["pawn", 1, 3, 10], ["rook", 1, 5, 10]],
			"captured": ["ferz", "rook", "wazir", "bishop"], "score": 500}},
		# --- issue 81: hand-built combo boards ---
		# Named for the QUESTION each answers, not for the Artefact it holds.
		# These are the boards a generator cannot produce, because the point is
		# an interaction rather than a trigger: every one settles something this
		# backlog has actually argued about, so it can be re-settled in seconds
		# instead of by reading dispatch code.
		{"name": "Combo: does an Item grant refuse cleanly at the cap of 2?", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]],
			"items": ["blitz", "shield"], "wave": 9, "gold": 400, "score": 1000}},
		{"name": "Combo: does the Shop refuse to sell a 6th Artefact?", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"artefacts": ["jet-fuel-vial", "denver-bunker-timeshare", "tape-eraser-magnet",
				"deep-state-yearbook", "mao-s-loyalty-badge"],
			"wave": 9, "gold": 900, "score": 1000, "stock": ["pawn"]}},
		{"name": "Combo: does a Piece Buff grant float \"Buffs full\" at the cap of 2?", "cfg": {
			# Bible grants Shield on EVERY capture by these three ids, so the
			# cap is reached within a couple of moves rather than engineered
			"board": [["bishop", 0, 2, 2], ["archbishop", 0, 5, 2],
				["pawn", 1, 3, 3], ["pawn", 1, 4, 3], ["pawn", 1, 2, 4], ["pawn", 1, 5, 4]],
			"artefacts": ["bible-gag-reel-scroll"], "score": 1000, "gold": 200}},
		{"name": "Combo: Bible fires for all three chain ids and no other piece", "cfg": {
			"board": [["bishop", 0, 1, 2], ["dragon-horse", 0, 3, 2], ["archbishop", 0, 5, 2],
				["rook", 0, 7, 2],
				["pawn", 1, 2, 3], ["pawn", 1, 4, 3], ["pawn", 1, 6, 3], ["pawn", 1, 7, 3]],
			"artefacts": ["bible-gag-reel-scroll"], "score": 1000, "gold": 200}},
		{"name": "Combo: is the Deep State Yearbook buy/sell loop really a net loss?", "cfg": {
			# 4 x 5 held = 20 Gold back on a 50-Gold Common at a 50% sell rate:
			# -5 per full cycle, at EVERY collection size, because the cap of 5
			# ends the scaling that made it look infinite
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"artefacts": ["deep-state-yearbook", "jet-fuel-vial", "tape-eraser-magnet",
				"denver-bunker-timeshare", "mao-s-loyalty-badge"],
			"wave": 9, "gold": 600, "score": 1000, "stock": ["pawn"]}},
		{"name": "Combo: can Mao's Loyalty Badge ever net positive Gold?", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"artefacts": ["mao-s-loyalty-badge"],
			"wave": 9, "gold": 400, "score": 1000, "stock": ["pawn"]}},
		{"name": "Combo: does selling an Item switch Denver Bunker's +30% off?", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]],
			"artefacts": ["denver-bunker-timeshare"],
			"items": ["blitz", "shield"], "wave": 9, "gold": 300, "score": 1000}},
		{"name": "Combo: NO-38 — sell from inside an Item Box at a full inventory", "cfg": {
			"board": [["queen", 0, 3, 3], ["knight", 0, 1, 3]],
			"items": ["blitz", "sniper"], "wave": 3, "gold": 2000}},
		{"name": "Combo: Tape Eraser Magnet — selling is not using, so it must not fire", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]],
			"artefacts": ["tape-eraser-magnet"], "items": ["blitz"],
			"wave": 9, "gold": 300, "score": 1000}},
		{"name": "Combo: Captured Stock converts, but cannot deploy or merge", "cfg": {
			"board": ZONE_PAWNS + [["queen", 0, 3, 2]],
			"captured": ["rook", "rook", "knight", "pawn"], "stock": ["pawn"],
			"wave": 9, "gold": 400, "score": 1000}},
		{"name": "Combo: Jet Fuel Vial is spent across a Shop close/reopen, not reset", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]],
			"artefacts": ["jet-fuel-vial"], "wave": 9, "gold": 400, "score": 1000,
			"stock": ["pawn"]}},
		{"name": "Combo: the Pallet's count survives a Shop close at an odd purchase", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]],
			"artefacts": ["pandemic-toilet-paper-pallet"], "wave": 9, "gold": 600,
			"score": 1000, "stock": ["pawn"]}},
		{"name": "Combo: two Snowden copies stack their Box rerolls", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"artefacts": ["snowden-s-rubik-s-cube", "snowden-s-rubik-s-cube"],
			"wave": 9, "gold": 600, "score": 1000}},
		{"name": "Combo: Ecdysis copies a KEY, so it must not consume an Artefact slot", "cfg": {
			"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"artefacts": ["ecdysis-sheddings", "jet-fuel-vial", "deep-state-yearbook",
				"tape-eraser-magnet"],
			"wave": 9, "gold": 600, "score": 1000, "stock": ["pawn"]}},
		{"name": "Combo: Hellfire Club at low resources — the softlock shape", "cfg": {
			"board": [["pawn", 0, 3, 1], ["rook", 1, 3, 8]],
			"artefacts": ["hellfire-club-discord-invite"], "gold": 0, "score": 200}},
		# Army Power / Artefact overlaps: one board per Army, each on the
		# resource its Power touches, so a doubled-up effect is visible rather
		# than inferred from two separate readings
		{"name": "Combo Army: Crown — free merges, Stock pieces onto board partners", "cfg": {
			# NO-100: one enemy on the board. With none, the first turn start
			# saw a cleared board and queued wave 10 — a Shop restock Wave,
			# which opens the Shop over the Stock drawer this capture is for.
			# Close Ranks waives the merge's Action; every Stock piece has a
			# board partner, since merges happen on the board only.
			"army": "Crown", "board": ZONE_PAWNS + [["queen", 0, 3, 2], ["pawn", 1, 6, 10],
				["rook", 0, 2, 1], ["knight", 0, 5, 1], ["bishop", 0, 6, 1]],
			"stock": ["rook", "rook", "knight", "knight", "bishop", "bishop"],
			"wave": 9, "gold": 400, "score": 1000}},
		{"name": "Combo Army: Wild Hunt — first-capture refund with multiple targets", "cfg": {
			"army": "Wild Hunt",
			"board": [["queen", 0, 3, 2], ["rook", 0, 5, 2],
				["pawn", 1, 3, 4], ["pawn", 1, 5, 4], ["pawn", 1, 2, 3]],
			"items": ["blitz", "blitz"], "wave": 5, "gold": 300, "score": 1000}},
		{"name": "Combo Army: Old Guard — its Power against a scoring board", "cfg": {
			"army": "Old Guard",
			"board": [["queen", 0, 2, 2], ["knight", 0, 4, 2],
				["pawn", 1, 2, 5], ["bishop", 1, 3, 4]],
			"wave": 5, "gold": 300, "score": 1000, "stock": ["pawn"]}},
		{"name": "Combo Army: Syndicate — its Power against a Shop full of Gold", "cfg": {
			"army": "Syndicate", "board": [["queen", 0, 2, 2], ["pawn", 1, 2, 6]],
			"wave": 9, "gold": 800, "score": 1000, "stock": ["pawn"]}},
		{"name": "Combo Army: Cult — its Power against a Buff-granting board", "cfg": {
			"army": "Cult",
			"board": [["bishop", 0, 2, 2], ["archbishop", 0, 5, 2],
				["pawn", 1, 3, 3], ["pawn", 1, 4, 3]],
			"artefacts": ["bible-gag-reel-scroll"], "wave": 5, "gold": 300, "score": 1000}},
		{"name": "Combo Army: Horde — its Power against a wide spawn", "cfg": {
			"army": "Horde", "board": [["queen", 0, 3, 2], ["rook", 0, 5, 2]],
			"wave": 3, "gold": 300, "score": 1000, "stock": ["pawn", "pawn", "pawn"]}},
		{"name": "Combo: the Army Ability costs an Action, Artefact activation does not", "cfg": {
			# NO-100: one enemy on the board. With none, the first turn start
			# saw a cleared board and queued wave 10 — a Shop restock Wave,
			# which opens the Shop over the Stock drawer this capture is for.
			"army": "Crown", "board": ZONE_PAWNS + [["queen", 0, 3, 2], ["pawn", 1, 6, 10]],
			"stock": ["rook", "rook"], "artefacts": ["jet-fuel-vial"],
			"wave": 9, "gold": 400, "score": 1000}},
		{"name": "Combo: all three caps full at once (Items 2, Buffs 2, Artefacts 5)", "cfg": {
			"board": [["bishop", 0, 2, 2], ["archbishop", 0, 5, 2],
				["pawn", 1, 3, 3], ["pawn", 1, 4, 3]],
			"items": ["blitz", "shield"],
			"artefacts": ["bible-gag-reel-scroll", "jet-fuel-vial", "deep-state-yearbook",
				"tape-eraser-magnet", "denver-bunker-timeshare"],
			"wave": 9, "gold": 900, "score": 2000, "stock": ["pawn"]}},
		# --- loss conditions ---
		{"name": "Loss: clock-out (10s)", "cfg": {
			"board": ZONE_PAWNS, "clock_s": 10.0}},
		{"name": "Loss: starvation (pass twice)", "cfg": {
			"board": [["pawn", 0, 2, 0], ["rook", 1, 2, 9]]}},
		{"name": "Loss: back-row breach", "cfg": {
			"board": [["queen", 0, 3, 3],
				["rook", 1, 0, 0], ["rook", 1, 1, 0], ["rook", 1, 2, 0],
				["rook", 1, 3, 0], ["rook", 1, 4, 0], ["pawn", 1, 5, 1]]}},
		# --- enemy AI (2026-09-06: one-ply material safety, rules.gd ai_action) ---
		# PASS and watch: the rook must NOT take the pawn on (0,5) — the pawn on
		# (1,4) defends it — and takes the free knight on (7,10) instead.
		{"name": "Enemy AI: declines a poisoned capture, takes the free piece", "cfg": {
			"board": [["pawn", 0, 0, 5], ["pawn", 0, 1, 4], ["knight", 0, 7, 10],
				["rook", 1, 0, 10]], "stock": ["pawn"]}},
		# PASS and watch: the pawn on (3,7) can only step onto (3,6), which the
		# player pawn covers, so the enemy holds it and advances the knight.
		{"name": "Enemy AI: holds a pawn rather than feed it, advances the knight", "cfg": {
			"board": [["pawn", 0, 2, 5], ["pawn", 1, 3, 7], ["knight", 1, 6, 10]],
			"stock": ["pawn"]}},
		# --- debug: turn/wave banner (NO-234) ---
		# Frozen: paired with `--show-screen banner`, which pins the banner
		# mid-animation (fully wiped in, fully opaque) so --screenshot can
		# capture NO-219's fullscreen italic/bold banner — see game.gd's
		# _debug_state_screenshot, "banner" branch. Board content only needs
		# to look like a real board; the banner itself is hardcoded there.
		{"name": "Banner: frozen (NO-234)", "cfg": {
			"board": [["queen", 0, 2, 1], ["rook", 1, 4, 9]]}},
		# Looping: for the in-app TEST menu, not the CLI. PASS repeatedly to
		# fire ENEMY TURN / YOUR TURN back to back and watch the wipe/stripes
		# animate. Default wave (all waves done) keeps spawns from interrupting
		# it; the one player piece keeps _player_pieces() non-empty so Pass
		# never trips the starvation loss condition.
		{"name": "Banner: looping (NO-234)", "cfg": {
			"board": [["queen", 0, 2, 1], ["pawn", 1, 4, 9]]}},
		# --- debug: capture paths (tools/capture.md) ---
		# Something of every sellable kind, a full Item inventory (exactly the
		# base cap, so an Item Box shows its Sell row) and Gold for a Convert. Backs
		# `--show-screen pick` and every `--ui-demo` flow (scripts/ui_demo.gd
		# boots it BY NAME — rename both together).
		{"name": "Capture: selling sandbox", "cfg": {
			"board": [["queen", 0, 3, 2], ["pawn", 0, 1, 0], ["rook", 1, 4, 9]],
			"stock": ["rook", "knight", "pawn", "pawn"], "captured": ["bishop"],
			"items": ["blitz", "sniper", "promote"].slice(0, Tuning.ITEM_CAP_BASE),
			"artefacts": ["jet-fuel-vial", "deep-state-yearbook"],
			"gold": 500, "score": 1000}},
		# NO-250: the three new Artefact mechanics, one sandbox each (tools/
		# capture.md has the capture commands). Magic bullet: tap the Rook —
		# the Knight behind your own Pawn is offered, dots through the Pawn,
		# ringed red. Pincer: at Turn start the enemy Pawn between your two
		# Knights is Stunned. Oligarch: tap the enemy Pawn — its recon preview
		# has no capture on your Queen (the control scenario shows it does).
		{"name": "NO-250: Magic bullet", "cfg": {
			"board": [["rook", 0, 0, 1], ["pawn", 0, 0, 2], ["knight", 1, 0, 6],
				["rook", 1, 7, 10]],
			"artefacts": ["curtain-rods-bag-rifle-shaped"]}},
		{"name": "NO-250: Pincer", "cfg": {
			"board": [["knight", 0, 3, 3], ["knight", 0, 5, 3], ["pawn", 1, 4, 4],
				["rook", 1, 7, 10]],
			"artefacts": ["men-in-black-prescription-sunglasses"]}},
		{"name": "NO-250: Oligarch", "cfg": {
			"board": [["queen", 0, 3, 3], ["pawn", 0, 0, 1], ["pawn", 1, 2, 4],
				["rook", 1, 7, 10]],
			"artefacts": ["putin-s-golden-toilet-brush"]}},
		{"name": "NO-250: Oligarch (control, no Artefact)", "cfg": {
			"board": [["queen", 0, 3, 3], ["pawn", 0, 0, 1], ["pawn", 1, 2, 4],
				["rook", 1, 7, 10]]}},
	]
