extends SceneTree
## Artefacts, part 4: the echo/meta-trigger layer (issue 21), the Blitz
## rework and its Tier-5 interaction, the per-artefact 5-Wave Milestone fix,
## runtime rarity metadata + Illuminati Fridge Magnet (issue 29),
## capture-context effects (issue 31), the issue 28 audit (unwired
## artefacts, REGISTRY-coverage guard, echo x milestone coverage), and
## Artefact activation (issue 52) — the last 7 catalog entries and the new
## on-demand affordance (Activate section, confirm/cancel, Bovine's
## targeting, autoplay) — plus issue 56's redesign of Zapruder's Director's
## Cut (Item/Deploy/Merge resource-return, complementing the move/capture
## replay) and SETI's Red Marker (on-purchase Tariff removal + Box open),
## which closed the catalog at 180/180.
## Split out of test_items.gd (issue 37).
## Run headless:  godot --headless --path game -s tests/test_items_artefacts_4.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Economy := preload("res://scripts/economy.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const Shop := preload("res://scripts/shop.gd")
const Items := preload("res://data/items.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")
const MergeLogic := preload("res://scripts/merge_logic.gd")
const Rules := preload("res://scripts/rules.gd")
const AutoplayBot := preload("res://scripts/autoplay.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


## Fixtures are deterministic by default (slice 36: a flaky suite makes every
## green claim unfalsifiable). Pass a "seed" in cfg, or seed_it=false, to opt
## out — only for a test that genuinely wants variance.
const DEFAULT_SEED := 1


func _boot(cfg: Dictionary, seed_it: bool = true) -> Node2D:
	if seed_it and not cfg.has("seed"):
		cfg = cfg.duplicate()
		cfg.seed = DEFAULT_SEED
	GameScript.next_config = cfg
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _init() -> void:
	# --- issue 21: echo and meta-triggers (ArtefactHooks._run_meta_triggers) ---

	# Polybius Cartridge: a Capture Artefact (Greed) triggers one extra time
	var poly := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["greed", "polybius-cartridge"]})
	await process_frame
	var poly_base: int = poly.defs.pawn.value
	check(Economy.capture_score(poly, "pawn") == poly_base + 20,
		"Polybius Cartridge: a Capture Artefact (Greed) triggers an extra time (+10 twice)")
	poly.queue_free()
	await process_frame

	# Max Headroom Mask: a Wave Artefact triggers an extra time — both on Wave
	# clear (Zurich Gnome Figurine, +10% Gold spent) and Wave spawn (Nigerian
	# Prince Wire Transfer), the same queue() call fires both hooks
	var headroom := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 100, "score": 0,
		"artefacts": ["zurich-gnome-figurine", "nigerian-prince-wire-transfer", "max-headroom-mask"]})
	await process_frame
	headroom.gold_spent_shop_this_wave = 40
	WaveLogic.queue(headroom, headroom.wave + 1)
	check(headroom.score == 200 and headroom.gold == 128,
		"Max Headroom Mask: doubles a Wave Artefact's trigger on both Wave clear " +
		"(Zurich: +4 twice = 108) and Wave spawn (Nigerian Prince: +10/+100 twice, 108+20=128 Gold, 200 Score)")
	headroom.queue_free()
	await process_frame

	# Red Diary's Missing Pages: an on_piece_lost Artefact (D.B. Cooper's
	# Parachute) triggers one extra time
	var diary := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 2, 5]],
		"wave": 4, "gold": 0, "artefacts": ["d-b-cooper-s-parachute", "red-diary-s-missing-pages"]})
	await process_frame
	var diary_val: int = diary.defs.pawn.value
	await diary._run_enemy_actions()
	check(diary.gold == 2 * roundi(diary_val * 0.75),
		"Red Diary's Missing Pages: an on_piece_lost Artefact triggers an extra time")
	diary.queue_free()
	await process_frame

	# CERN Ctrl+Z Shortcut: a key held 2+ times (two Greeds) gets ONE flat
	# extra trigger, not one per duplicate; a singly-held key gets none
	var cern := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["greed", "greed", "cern-ctrl-z-shortcut"]})
	await process_frame
	var cern_base: int = cern.defs.pawn.value
	check(Economy.capture_score(cern, "pawn") == cern_base + 30,
		"CERN Ctrl+Z Shortcut: two held Greeds (a duplicate) get one flat extra trigger (+10x3, not +10x4)")
	cern.queue_free()
	await process_frame

	var cern_single := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["score", "cern-ctrl-z-shortcut"]})
	await process_frame
	var cern_single_base: int = cern_single.defs.pawn.value
	check(Economy.capture_score(cern_single, "pawn") == cern_single_base + 10,
		"CERN Ctrl+Z Shortcut: a singly-held Artefact (Score) gets no extra trigger")
	cern_single.queue_free()
	await process_frame

	# Bilderberg Hotel Slippers: +15 Gold only when 2+ Artefacts actually
	# fired this call — "fired", not "held" (Score alone never triggers it)
	var bilder := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["greed", "score", "bilderberg-hotel-slippers"]})
	await process_frame
	var bilder_base: int = bilder.defs.pawn.value
	var bilder_pts := Economy.capture_score(bilder, "pawn")
	check(bilder_pts == bilder_base + 20 and bilder.gold == 15,
		"Bilderberg Hotel Slippers: +15 Gold when 2+ of your Artefacts (Greed+Score) trigger on the same event")
	bilder.queue_free()
	await process_frame

	var bilder_one := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["score", "bilderberg-hotel-slippers"]})
	await process_frame
	Economy.capture_score(bilder_one, "queen") # only Score fires (Greed isn't held)
	check(bilder_one.gold == 0, "Bilderberg Hotel Slippers: no bonus when only one Artefact triggers")
	bilder_one.queue_free()
	await process_frame

	# Illuminati: NWO Booster Pack: +2 Gold/+20 Score per Capture Artefact
	# trigger this call, scaling with how many actually fired
	var nwo := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "score": 0, "artefacts": ["greed", "illuminati-nwo-booster-pack"]})
	await process_frame
	var nwo_base: int = nwo.defs.pawn.value
	var nwo_pts := Economy.capture_score(nwo, "pawn")
	check(nwo_pts == nwo_base + 10 and nwo.gold == 2 and nwo.score == 20,
		"Illuminati: NWO Booster Pack: +2 Gold/+20 Score when one Capture Artefact triggers (Greed)")
	nwo.queue_free()
	await process_frame

	var nwo2 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "score": 0, "artefacts": ["greed", "score", "illuminati-nwo-booster-pack"]})
	await process_frame
	Economy.capture_score(nwo2, "pawn") # Greed + Score both fire on_capture: 2 triggers
	check(nwo2.gold == 4 and nwo2.score == 40,
		"Illuminati: NWO Booster Pack: scales with the number of Capture Artefact triggers (2 -> double)")
	nwo2.queue_free()
	await process_frame

	# 100% Genuine Original Mona Lisa: only the Turn's FIRST Artefact trigger
	# (any hook) is echoed, including a fresh echo when the enemy Turn begins
	var mona := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["greed", "100-genuine-original-mona-lisa"]})
	await process_frame
	var mona_base: int = mona.defs.pawn.value
	check(Economy.capture_score(mona, "pawn") == mona_base + 20,
		"100% Genuine Original Mona Lisa: the first Artefact trigger of the Turn (Greed) is echoed")
	check(Economy.capture_score(mona, "pawn") == mona_base + 10,
		"100% Genuine Original Mona Lisa: only the FIRST trigger of the Turn echoes, not every later one")
	mona.queue_free()
	await process_frame

	var mona_enemy := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 2, 5]],
		"wave": 4, "gold": 0,
		"artefacts": ["greed", "d-b-cooper-s-parachute", "100-genuine-original-mona-lisa"]})
	await process_frame
	var mona_enemy_val: int = mona_enemy.defs.pawn.value
	Economy.capture_score(mona_enemy, "pawn") # consumes this player Turn's echo via Greed
	await mona_enemy._run_enemy_actions() # on_enemy_turn_start resets the flag for a fresh echo
	check(mona_enemy.gold == 2 * roundi(mona_enemy_val * 0.75),
		"100% Genuine Original Mona Lisa: on_enemy_turn_start resets the echo — the enemy Turn " +
		"gets its own first-trigger echo even after the player Turn already used one")
	mona_enemy.queue_free()
	await process_frame

	# Déjà Vu Glitch: only the Turn's first Score/Gold gain is doubled (per
	# copy: N copies -> (1+N)x), later gains the same Turn are untouched
	var dejavu := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "score": 0, "artefacts": ["deja-vu-glitch", "deja-vu-glitch"]})
	await process_frame
	Economy.earn(dejavu, 100)
	check(dejavu.score == 300 and dejavu.gold == 300,
		"Déjà Vu Glitch: two held copies triple (not double) the Turn's first Score/Gold gain")
	Economy.earn(dejavu, 50)
	check(dejavu.score == 350 and dejavu.gold == 350,
		"Déjà Vu Glitch: only the Turn's FIRST Score/Gold gain doubles — later gains are untouched")
	dejavu.queue_free()
	await process_frame

	# Capstone Polish: +150 Score / +5s Clock on acquiring an Artefact
	var capstone := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 9999, "score": 0, "artefacts": ["capstone-polish"]})
	await process_frame
	var capstone_clock0: float = capstone.clock_ms
	for i in capstone.shop_stock.size():
		if capstone.shop_stock[i].kind == "artefact":
			Shop.buy(capstone, i)
			break
	check(capstone.score == 150 and capstone.clock_ms == capstone_clock0 + 5000,
		"Capstone Polish: +150 Score and +5s Clock on acquiring an Artefact")
	capstone.queue_free()
	await process_frame

	# --- the risky one: two echo artefacts (Polybius + CERN, both hooked to
	# on_capture) plus a percentage Artefact (Tinfoil Hat) on the resulting
	# gain — must be a single deterministic bounded number, not an infinite
	# loop, and identical regardless of REGISTRY-array insertion order.
	# Held: Greed x2 (the Capture Artefact being echoed, also CERN's
	# duplicate) + Polybius (+1 extra trigger PER fired Greed = +2) + CERN
	# (+1 flat extra trigger for the duplicated key = +1) -> 5 total Greed
	# dispatches (2 main + 2 Polybius + 1 CERN), pts = base + 50. Then
	# Tinfoil Hat's +15%/-5% applies once, off that same immutable base.
	var order_1 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "score": 0,
		"artefacts": ["greed", "greed", "polybius-cartridge", "cern-ctrl-z-shortcut", "tinfoil-hat"]})
	await process_frame
	var order_2 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "score": 0,
		"artefacts": ["tinfoil-hat", "greed", "cern-ctrl-z-shortcut", "greed", "polybius-cartridge"]})
	await process_frame
	var risky_base: int = order_1.defs.pawn.value
	var pts_1 := Economy.capture_score(order_1, "pawn")
	var pts_2 := Economy.capture_score(order_2, "pawn")
	check(pts_1 == risky_base + 50 and pts_2 == risky_base + 50,
		"two echo Artefacts stacked on the same Capture Artefact stay bounded at a fixed, computed " +
		"total (2 main + 2 Polybius + 1 CERN = 5 Greed dispatches), not a hang and not runaway growth")
	check(pts_1 == pts_2, "the same held keys in a different acquisition order give the same result")
	Economy.earn(order_1, pts_1)
	Economy.earn(order_2, pts_2)
	check(order_1.score == roundi(pts_1 * 1.15) and order_1.gold == roundi(pts_1 * 0.95),
		"Tinfoil Hat's percentage still applies once, off the echoed capture's own immutable base")
	check(order_1.score == order_2.score and order_1.gold == order_2.gold,
		"the full capture+earn pipeline stays order-independent with two echo Artefacts stacked")
	order_1.queue_free()
	order_2.queue_free()
	await process_frame

	# --- Blitz rework (Notion 2026-08-28): costs 0 actions itself (data-driven
	# via items.gd's action_cost, defaulting to 1 for every other item),
	# targets ANY own piece (King excluded, like every other targeted item —
	# the already-moved-only restriction is gone), and marks the target's
	# NEXT move/capture this Turn free. If the target already moved, Blitz
	# also lifts the one-move-per-piece lock so that free move can actually
	# happen. A real power increase (three Blitzes = three free moves), not a
	# wash: the old "costs 1, refunds 1" behavior is gone. ---

	# targeting: an un-moved own piece is now offered too; the King never is
	var bfree := _boot({"board": [["queen", 0, 2, 2], ["king", 0, 0, 0], ["rook", 1, 7, 10]],
		"wave": 3, "items": ["blitz"]})
	await process_frame
	check(bfree.actions_left == 2, "2 actions/turn at the default tier")
	bfree._use_item(0)
	check(bfree.item_targets.has(Vector2i(2, 2)) and not bfree.item_targets.has(Vector2i(0, 0)),
		"Blitz offers the un-moved queen but excludes the King")
	bfree._item_click(Vector2i(2, 2))
	check(bfree.items.is_empty() and bfree.actions_left == 2, "Blitz costs 0 actions to use")
	check(bfree.board[Vector2i(2, 2)].get("blitz_free_move", false),
		"Blitz marks the target's next move/capture as free")
	bfree._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(bfree.actions_left == 2, "the marked piece's move costs no action")
	check(not bfree.board[Vector2i(2, 3)].get("blitz_free_move", false),
		"the free-move flag is consumed by that one move")
	bfree.queue_free()
	await process_frame

	# an already-moved target: Blitz also lifts the one-move-per-piece lock,
	# and THAT second move is the free one
	var bt2 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "items": ["blitz"]})
	await process_frame
	bt2._move_player(Vector2i(2, 2), Vector2i(2, 3)) # spends the queen's move
	check(bt2.moved_this_turn.has(Vector2i(2, 3)) and bt2.actions_left == 1,
		"queen is spent for the turn, 1 action left")
	bt2._use_item(0)
	check(bt2.item_targets.has(Vector2i(2, 3)), "Blitz can target an already-moved piece too")
	bt2._item_click(Vector2i(2, 3))
	check(not bt2.moved_this_turn.has(Vector2i(2, 3)) and bt2.actions_left == 1,
		"Blitz lifts the one-move-per-piece lock, still costing nothing itself")
	bt2._move_player(Vector2i(2, 3), Vector2i(2, 4))
	check(bt2.actions_left == 1, "the second move is free — genuinely moved again for 0 actions")
	bt2.queue_free()
	await process_frame

	# the flag is scoped "this Turn" — it must not survive into the next one
	var bt3 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "items": ["blitz"]})
	await process_frame
	bt3._use_item(0)
	bt3._item_click(Vector2i(2, 2))
	check(bt3.board[Vector2i(2, 2)].get("blitz_free_move", false), "flag set this turn")
	bt3._begin_player_turn() # simulate the next player turn starting
	check(not bt3.board[Vector2i(2, 2)].get("blitz_free_move", false),
		"the free-move flag does not survive into a new turn")
	bt3.queue_free()
	await process_frame

	# --- 07-difficulty-ranks: Tier 5's -1 action/turn. The OLD Blitz refunded
	# its own action, so at 1 action/turn the first move alone spent the
	# turn's only action and auto-passed before Blitz's target filter (a
	# piece that already moved) was ever reachable — Blitz was functionally
	# dead at Tier 5. The rework fixes this by construction: Blitz itself is
	# free and its target's move is free too, so it must genuinely work here.
	GameScript.next_tier = "Tier 5"
	var bz := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "items": ["blitz"]})
	await process_frame
	check(bz.actions_left == 1, "Tier 5 grants exactly 1 action at turn start")
	bz._use_item(0) # Blitz on the un-moved queen
	bz._item_click(Vector2i(2, 2))
	check(bz.actions_left == 1 and bz.state == bz.State.PLAYER_TURN,
		"Blitz itself costs no action, even at Tier 5 — no auto-pass either")
	bz._move_player(Vector2i(2, 2), Vector2i(2, 3)) # the marked free move
	check(bz.actions_left == 1 and bz.state == bz.State.PLAYER_TURN,
		"the free move spends no action — the turn's only action is still there, no auto-pass")
	bz.queue_free()
	await process_frame
	GameScript.next_tier = Tuning.DEFAULT_TIER

	# --- fix (ruled 2026-08-28): the "5-Wave Milestone" is PER-ARTEFACT, not
	# the GLOBAL beat every held copy used to check (g.wave % 5 == 0). Each
	# held copy counts its own 5 waves from its own acquisition wave (stamped
	# on g.artefacts entries — ArtefactHooks._milestone5_hit) ---

	# core fix: two copies of the same artefact, acquired on different waves,
	# fire on DIFFERENT wave-clears — not in lockstep. Manna Vending Machine
	# (+2 Items per firing) makes each copy's own firing directly countable.
	var m5 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "artefacts": ["manna-vending-machine"]}) # copy A: acquired wave 1
	await process_frame
	for t in Items.ARTEFACT_EFFECTS: # copy B: acquired wave 3 (held from the
		if t.key == "manna-vending-machine": # start, same as two Shop buys on
			var copy_b: Dictionary = t.duplicate() # different waves would produce)
			copy_b.acquired_wave = 3
			m5.artefacts.append(copy_b)
			break
	check(m5.artefacts.size() == 2, "two held copies, acquired on different waves")
	m5.artefacts.append({"key": "area-51-parking-permit"}) # issue 53: this
		# test's countable side effect (Manna Vending Machine's Item grants)
		# would otherwise itself get clipped by the new base Item cap (3)
		# before all 4 across both copies land — raise it (+3, to 6) so it
		# stays a clean read of the per-artefact milestone timing, not a
		# second assertion about the cap (that's test_items.gd's job)
	for n in range(2, 6): # clear waves 1..4: neither copy is due yet
		WaveLogic.queue(m5, n)
	check(m5.items.size() == 0, "neither copy fires before its own beat 5 (waves 1-4 cleared)")
	WaveLogic.queue(m5, 6) # clears wave 5: copy A's beat 5 (1+4) — copy B's is wave 7 (3+4)
	check(m5.items.size() == 2, "only copy A (acquired wave 1) fires clearing wave 5")
	WaveLogic.queue(m5, 7) # clears wave 6: neither copy's beat
	check(m5.items.size() == 2, "no double-fire clearing wave 6")
	WaveLogic.queue(m5, 8) # clears wave 7: copy B's beat 5 (3+4)
	check(m5.items.size() == 4, "copy B (acquired wave 3) fires on its OWN beat, clearing wave 7 — not lockstepped with copy A")
	m5.queue_free()
	await process_frame

	# acquisition-wave stamping: every acquisition path stamps g.wave, and
	# never mutates the shared Items.ARTEFACT_EFFECTS catalog entry
	var catalog_entry: Dictionary
	for t in Items.ARTEFACT_EFFECTS:
		if t.key == "manna-vending-machine":
			catalog_entry = t
			break
	check(not catalog_entry.has("acquired_wave"),
		"the shared catalog entry itself is never stamped (each acquisition duplicates it)")

	# Shop buy
	var buyer := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 7, "gold": 99999})
	await process_frame
	buyer.actions_left = 5
	buyer.shop_stock.append({"kind": "artefact", "key": "manna-vending-machine", "sold": false})
	Shop.buy(buyer, buyer.shop_stock.size() - 1)
	check(buyer.artefacts.size() == 1 and buyer.artefacts[0].acquired_wave == 7,
		"Shop buy stamps acquired_wave to the current wave")
	check(buyer.artefacts[0].rarity == "Common", # issue 29
		"Shop buy stamps rarity from the catalog (Manna Vending Machine: Common)")
	buyer.queue_free()
	await process_frame

	# Box pick
	var boxer := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 9})
	await process_frame
	boxer._box_choose({"kind": "artefact", "name": "x", "description": "x", "payload": catalog_entry})
	check(boxer.artefacts.size() == 1 and boxer.artefacts[0].acquired_wave == 9,
		"Box pick stamps acquired_wave to the current wave")
	check(boxer.artefacts[0].rarity == "Common", # issue 29
		"Box pick stamps rarity from the catalog (Manna Vending Machine: Common)")
	boxer.queue_free()
	await process_frame

	# save/load round-trip: each held copy's own acquired_wave AND rarity survive
	var saver := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "artefacts": ["manna-vending-machine"]})
	await process_frame
	for t in Items.ARTEFACT_EFFECTS:
		if t.key == "manna-vending-machine":
			var b2: Dictionary = t.duplicate()
			b2.acquired_wave = 3
			saver.artefacts.append(b2)
			break
	var m5_cfg: Dictionary = saver._to_config()
	saver.queue_free()
	await process_frame
	var m5_restored := _boot(JSON.parse_string(JSON.stringify(m5_cfg)))
	await process_frame
	var restored_waves: Array = []
	for t in m5_restored.artefacts:
		restored_waves.append(int(t.acquired_wave))
		check(t.rarity == "Common", "save -> load preserves rarity (issue 29)") # issue 29
	restored_waves.sort()
	check(restored_waves == [1, 3],
		"save -> load preserves each held copy's own acquired_wave (%s)" % [restored_waves])
	m5_restored.queue_free()
	await process_frame

	# --- issue 29: runtime rarity metadata — an old save's artefact entries
	# predate the `rarity` field ({key, acquired_wave} only, no `rarity` key)
	# — apply() must not crash and must degrade to a fresh catalog lookup
	# (ArtefactHooks.rarity_of), not treat the copy as unrated
	var old_save := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "artefacts": [{"key": "manna-vending-machine", "acquired_wave": 2}]})
	await process_frame
	check(old_save.artefacts.size() == 1 and old_save.artefacts[0].rarity == "Common",
		"an old save entry with no `rarity` key degrades to the catalog lookup, not a crash")
	old_save.queue_free()
	await process_frame

	# --- issue 29: Illuminati Fridge Magnet — "+50% Gold gain" while holding
	# an Artefact of every rarity (Common/Uncommon/Rare/Legendary). Rare is
	# the Fridge Magnet itself; the other three are picked for hooks that
	# never touch on_gold_change/on_score_change, so Economy.earn's result
	# isolates the Fridge Magnet's own bonus.
	var partial := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3,
		"artefacts": ["illuminati-fridge-magnet", "fema-summer-camp-flyer", # Rare + Common
			"putin-s-golden-toilet-brush"]}) # + Uncommon — no Legendary yet
	await process_frame
	check(not ArtefactHooks.holds_every_rarity(partial),
		"three of four rarities held (Legendary missing): holds_every_rarity is false")
	Economy.earn(partial, 100)
	check(partial.gold == 100, "Illuminati Fridge Magnet withholds its bonus until every rarity is held")
	partial.queue_free()
	await process_frame

	var all_rarities := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3,
		"artefacts": ["illuminati-fridge-magnet", "fema-summer-camp-flyer",
			"putin-s-golden-toilet-brush", "cia-exploding-cigar"]}) # Rare/Common/Uncommon/Legendary
	await process_frame
	check(ArtefactHooks.holds_every_rarity(all_rarities),
		"all four rarities held: holds_every_rarity is true")
	Economy.earn(all_rarities, 100)
	check(all_rarities.gold == 150, "Illuminati Fridge Magnet: +50% Gold gain once every rarity is held")
	all_rarities.queue_free()
	await process_frame

	# --- issue 31: capture-context effects ---

	# Curtain Rods Bag: first Capture each Wave doubles Score and pays no
	# Gold; later Captures the same Wave are unaffected (pawn value 10)
	var crb := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 3], ["pawn", 1, 2, 4],
		["rook", 1, 7, 10]], "wave": 3, "score": 0, "gold": 0,
		"artefacts": ["curtain-rods-bag-rifle-shaped"]})
	await process_frame
	crb.actions_left = 5
	crb._move_player(Vector2i(2, 2), Vector2i(2, 3)) # first Capture this Wave
	check(crb.score == 20 and crb.gold == 0,
		"Curtain Rods Bag: first Capture each Wave doubles Score (10 -> 20) and pays no Gold")
	crb._move_player(Vector2i(2, 3), Vector2i(2, 4)) # second Capture this Wave
	check(crb.score == 30 and crb.gold == 10,
		"Curtain Rods Bag: the second Capture the same Wave pays normally")
	crb.queue_free()
	await process_frame

	# Templar Debit Card: pay Shop costs with Score, 10 Score per 1 Gold, for
	# whatever Gold can't cover
	var tdc := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "score": 100, "gold": 5, "artefacts": ["templar-debit-card"]})
	await process_frame
	tdc.shop_stock.append({"kind": "piece", "key": "pawn", "sold": false}) # 10 Gold
	check(Shop.can_buy(tdc, tdc.shop_stock[-1]),
		"Templar Debit Card: Score covers what 5 Gold can't of a 10-Gold pawn")
	Shop.buy(tdc, tdc.shop_stock.size() - 1)
	check(tdc.gold == 0 and tdc.score == 50,
		"Templar Debit Card: the Gold-uncovered remainder (5) debits as Score at 10:1 (-50)")
	tdc.queue_free()
	await process_frame

	var tdc_no := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "score": 100, "gold": 5})
	await process_frame
	tdc_no.shop_stock.append({"kind": "piece", "key": "pawn", "sold": false})
	check(not Shop.can_buy(tdc_no, tdc_no.shop_stock[-1]),
		"without the card, Score alone can't cover a Gold shortfall")
	tdc_no.queue_free()
	await process_frame

	# $2.3 Trillion Receipt: enemies destroyed by Items award their Score and
	# Gold value; non-Item destruction (Bomb/Tariff) still pays nothing
	var receipt := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 4, 4], ["pawn", 1, 5, 5],
		["rook", 1, 7, 10]], "wave": 3, "score": 0, "gold": 0,
		"artefacts": ["2-3-trillion-receipt"]})
	await process_frame
	receipt._destroy(Vector2i(4, 4), true) # Item-caused (Drone Strike/Air Strike/Sniper)
	check(receipt.score == 10 and receipt.gold == 10,
		"$2.3 Trillion Receipt: an enemy destroyed by an Item awards its Score and Gold value")
	receipt._destroy(Vector2i(5, 5)) # not Item-caused (Bomb's _detonate / jd_vance Tariff path)
	check(receipt.score == 10 and receipt.gold == 10,
		"$2.3 Trillion Receipt: non-Item destruction still pays nothing (Destruction default)")
	receipt.queue_free()
	await process_frame

	var no_receipt := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 4, 4], ["rook", 1, 7, 10]],
		"wave": 3, "score": 0, "gold": 0})
	await process_frame
	no_receipt._destroy(Vector2i(4, 4), true)
	check(no_receipt.score == 0 and no_receipt.gold == 0,
		"without the artefact, an Item-destroyed enemy still pays nothing")
	no_receipt.queue_free()
	await process_frame

	# --- issue 28: audit (originally) the 3 unwired 5-Wave-Milestone
	# artefacts + a general REGISTRY-coverage guard + echo x milestone
	# coverage. Roanoke Hex Kit was the last of that unwired trio — issue 43
	# wired Mar-a-Lago Toilet Papers (on_wave_clear + on_price) and issue 44
	# wired Yalta Cocktail Napkin (the choice-modal seam's first real
	# consumer), both covered in test_items_artefacts_3.gd. Issue 52 wired
	# Roanoke Hex Kit too, on a DIFFERENT seam than REGISTRY (player-triggered
	# activation, game.gd's _roanoke_activate) — it is no longer unwired, so
	# this block no longer asserts it stays implemented: false; it is instead
	# one of the 7 documented REGISTRY exceptions below (activation keys are
	# never dispatched by ArtefactHooks.run() at all).

	# General guard: every artefact flagged implemented: true must have a
	# REGISTRY entry, OR be one of these documented standing-rule exceptions
	# — artefacts read directly off g.artefacts / a held-count instead of
	# dispatched through ArtefactHooks.run(). Adding a name here must be a
	# deliberate act, never a silent workaround for a genuinely missed
	# REGISTRY line (that's exactly the class of bug this test exists to
	# catch — see the audit above).
	var no_registry_exceptions := {
		# Shop.roll/price + box.gd's roll_options read g.artefacts directly
		# (shop-drawer-ui/08's deferred pass; artefact_hooks.gd's issue 18
		# no-hook-list comment, next to the REGISTRY const)
		"chocolate-key-cake": true, "alleged-weather-balloon": true,
		"sub-antarctic-visa": true, "majestic-12-secret-handshake-diagram": true,
		# standing shop.gd/game.gd rules, each its own credit-line/direct read
		# (artefact_hooks.gd's issue 18/26/31 no-hook-list comments)
		"agartha-welcome-mat": true, "templar-debit-card": true,
		"nazca-boarding-pass": true, "nuclear-football-menu": true,
		"doomsday-clock-snooze-button": true,
		# game.gd's _artefact_count(key) reads (Buff Box offer size/cost,
		# game.gd:1544-1568) — same standing-rule pattern, in game.gd instead
		"numbers-station-sudoku": true, "bohemian-grove-friendship-bracelet": true,
		# issue 46: the Box Pick flow batch — same _artefact_count(key) standing
		# rule as the Buff Box pair above, read directly in _open_box_pick /
		# _box_choose (game.gd) instead of dispatched through ArtefactHooks.run()
		"nostradamus-mad-libs": true, "bible-gag-reel-scroll": true,
		"snowden-s-rubik-s-cube": true,
		# issue 21's echo/meta-trigger layer: pure observers that only ever
		# dispatch through ArtefactHooks._run_meta_triggers, never the normal
		# REGISTRY loop (artefact_hooks.gd's own "no REGISTRY entry" comment)
		"polybius-cartridge": true, "max-headroom-mask": true,
		"red-diary-s-missing-pages": true, "cern-ctrl-z-shortcut": true,
		"bilderberg-hotel-slippers": true, "illuminati-nwo-booster-pack": true,
		"100-genuine-original-mona-lisa": true, "deja-vu-glitch": true,
		# issue 43: New World Order Gerrymandering — a run()-tail post-pass
		# (artefact_hooks.gd's own REGISTRY comment, next to the const),
		# neither an echo/meta-trigger observer nor a standing g.artefacts
		# read: it multiplies what the normal dispatch + echo layer both
		# already added to a Gold gain, which only exists once both have run.
		"new-world-order-gerrymandering": true,
		# issue 51: the two zone-rule Artefacts. Passive board rules read
		# straight off held Artefacts at the point the rule is evaluated —
		# Cheyenne Mountain Doorbell in _run_enemy_actions' repel branch,
		# Winchester Salt Lined Doors via game.gd._enemy_denied_tiles() fed
		# into Rules.legal_moves/ai_action/is_checkmate — same standing-rule
		# shape as Nazca Boarding Pass, never an on_* dispatch.
		"cheyenne-mountain-doorbell": true, "winchester-salt-lined-doors": true,
		# issue 49: the Box-dependent batch. Epstein's Black Book and Cicada
		# Rejection Letter are the SAME issue-46 _artefact_count(key) standing
		# rule as Nostradamus/Bible Gag Reel Scroll/Snowden's Rubik's Cube
		# above — read directly in game.gd's _box_choose/_decline_box_pick,
		# not dispatched through ArtefactHooks.run(). All-Seeing Eye Contact
		# Lens is a pure display gate (modals.gd's _shop_detail, game.gd's
		# _open_bounty_pick), same standing-rule shape, no on_* hook to fire
		# on at all — it never changes what a Box yields, only whether the
		# UI shows it beforehand (issue 47 already rolls unconditionally).
		"epstein-s-black-book": true, "cicada-rejection-letter": true,
		"all-seeing-eye-contact-lens": true,
		# issue 53: the two new base-game caps. Area 51 Parking Permit /
		# Abduction Probe are read straight off g.artefacts by
		# item_logic.gd's cap() / buff_logic.gd's cap() at the moment
		# capacity is checked — same standing-rule shape as Chocolate Key
		# Cake/Alleged Weather Balloon above, never an on_* dispatch.
		"area-51-parking-permit": true, "abduction-probe": true,
		# 'Definitely Not Russia' Patch: the masking verdict is decided
		# structurally in game.gd's _lose_player_piece BEFORE on_piece_lost
		# dispatches (artefact_hooks.gd's REGISTRY comment, next to the
		# const), so every listener on that hook sees it regardless of
		# key-sort order — it never dispatches through the normal loop itself.
		"definitely-not-russia-patch": true,
		# issue 55: Troll Farm Employee of the Month / Ecdysis Sheddings —
		# same "pure _run_meta_triggers observer" shape as the issue-21 batch
		# above, see artefact_hooks.gd's own header.
		"troll-farm-employee-of-the-month": true, "ecdysis-sheddings": true,
		# issue 52: Artefact activation. Player-triggered ("on use"/"you may
		# pay"), not a passive listener on any hook — game.gd's own
		# _activate_artefact/_artefact_confirmed dispatch table (plus
		# _jet_fuel_restock_confirmed for the Shop-only 7th) is the whole
		# mechanism, deliberately separate from ArtefactHooks' REGISTRY/run()
		# engine (built for "every HELD copy fires automatically on a hook" —
		# see artefact_hooks.gd's header for why that shape doesn't fit an
		# on-demand, player-picks-when ability). Moscovium Glow Stick
		# especially: it must keep working after consuming itself and leaving
		# g.artefacts, when there is no held copy left for run() to dispatch.
		"oak-island-wishing-well": true, "fifa-complimentary-yacht": true,
		"moscovium-glow-stick": true, "roanoke-hex-kit": true,
		"zapruder-s-director-s-cut": true, "bovine-tractor-beam": true,
		"jet-fuel-vial": true,
	}
	var unregistered := []
	for cat in Items.ARTEFACT_CATALOG:
		if cat.get("implemented", false) and not ArtefactHooks.REGISTRY.has(cat.key) \
				and not no_registry_exceptions.has(cat.key):
			unregistered.append(cat.key)
	check(unregistered.is_empty(),
		"every implemented: true artefact has a REGISTRY entry or a documented exception (missing: %s)" % [unregistered])

	# Echo + a 5-Wave Milestone artefact together (issue 28): John Titor's
	# Crypto Wallet acquired wave 2 (its own beat-1 milestone is wave 6, see
	# the earlier John Titor coverage above) held with Max Headroom Mask,
	# which echoes any Wave artefact that fired on_wave_clear. Before the
	# fix, the echo dispatch fell back to acquired_wave=1, so
	# _milestone5_hit(6, 1) == false and the echo silently paid nothing;
	# fixed, it carries this copy's real acquired_wave=2 and
	# _milestone5_hit(6, 2) == true, so the echo pays out too.
	var echo_milestone := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 2, "gold": 0, "artefacts": ["john-titor-s-crypto-wallet", "max-headroom-mask"]})
	await process_frame
	echo_milestone.clock_ms = 25000.0 # +5 Gold per firing (int(25.0 / 5.0))
	for n in range(3, 7): # clear waves 2..5: not this copy's beat yet
		WaveLogic.queue(echo_milestone, n)
	check(echo_milestone.gold == 0,
		"John Titor's Crypto Wallet + Max Headroom Mask: no payout before the copy's own beat (wave 6)")
	WaveLogic.queue(echo_milestone, 7) # clears wave 6: this copy's own beat 1 (2+4)
	check(echo_milestone.gold == 10,
		"John Titor's Crypto Wallet + Max Headroom Mask: the normal dispatch (+5) AND Max " +
		"Headroom's echo (+5, using THIS copy's own acquired_wave, not the wave-1 default) both " +
		"pay out on the copy's own beat (10, not 5)")
	echo_milestone.queue_free()
	await process_frame

	# --- issue 51: the two zone-rule Artefacts ---

	# Cheyenne Mountain Doorbell: a player piece on the back row (y=0) cannot
	# be captured. Control run first (no artefact) proves the scenario is
	# real — the rook otherwise freely takes the back-row piece — so the
	# held-artefact run below is proof of the block, not a move that was
	# never going to happen anyway.
	var cheyenne_ctrl := _boot({"board": [["rook", 0, 2, 0], ["rook", 1, 2, 3]], "wave": 3})
	await process_frame
	await cheyenne_ctrl._run_enemy_actions()
	check(cheyenne_ctrl.board.get(Vector2i(2, 0), {}).get("owner", -1) == 1,
		"control: without Cheyenne, an enemy rook freely captures a player piece on the back row")
	cheyenne_ctrl.queue_free()
	await process_frame

	var cheyenne := _boot({"board": [["rook", 0, 2, 0], ["rook", 1, 2, 3]], "wave": 3,
		"artefacts": ["cheyenne-mountain-doorbell"]})
	await process_frame
	await cheyenne._run_enemy_actions()
	check(cheyenne.board.get(Vector2i(2, 0), {}).get("owner", -1) == 0,
		"Cheyenne Mountain Doorbell: a player piece on the back row survives the capture attempt")
	check(cheyenne.board.get(Vector2i(2, 3), {}).get("id", "") == "rook"
			and cheyenne.board[Vector2i(2, 3)].owner == 1,
		"Cheyenne Mountain Doorbell: the attacker is repelled and stays on its own tile")
	cheyenne.queue_free()
	await process_frame

	# Winchester Salt Lined Doors: enemy pieces cannot move onto the back row.
	# 7 enemy pawns already fill columns 0-6 of row 0 (stuck: no forward or
	# capture squares) and an enemy rook at (7,1) is one step from filling
	# the last column — with 8 enemies at y<=2 the AI's back-row "commit"
	# threshold (BACKROW_COMMIT_COUNT) is met, so without Winchester the
	# advance heuristic doesn't hold it back either. Control run first, same
	# reasoning as Cheyenne above: prove the breach is really reachable here
	# before proving Winchester stops it. A player pawn parked out of both
	# the rook's lines and any column/row it rides is just so _boot doesn't
	# hit "Resource starvation" (no player pieces, no stock) before the
	# enemy turn we're testing even runs.
	var winchester_board := [["pawn", 1, 0, 0], ["pawn", 1, 1, 0], ["pawn", 1, 2, 0],
		["pawn", 1, 3, 0], ["pawn", 1, 4, 0], ["pawn", 1, 5, 0], ["pawn", 1, 6, 0], ["rook", 1, 7, 1],
		["pawn", 0, 0, 5]]
	var winch_ctrl := _boot({"board": winchester_board, "wave": 3})
	await process_frame
	await winch_ctrl._run_enemy_actions()
	check(winch_ctrl.board.get(Vector2i(7, 0), {}).get("owner", -1) == 1
			and winch_ctrl._back_row_breached() and winch_ctrl.state == GameScript.State.GAME_OVER,
		"control: without Winchester, the massed swarm completes the back-row breach")
	winch_ctrl.queue_free()
	await process_frame

	var winch := _boot({"board": winchester_board, "wave": 3,
		"artefacts": ["winchester-salt-lined-doors"]})
	await process_frame
	await winch._run_enemy_actions() # driven through ai_action, not just legal_moves
	check(not winch.board.has(Vector2i(7, 0)),
		"Winchester Salt Lined Doors: the AI (via ai_action) never lands the rook on the last back-row tile")
	check(not winch._back_row_breached() and winch.state != GameScript.State.GAME_OVER,
		"Winchester Salt Lined Doors: the back-row breach loss is unreachable while held — the card " +
		"working as written, not a bug (issue 33 addendum)")
	winch.queue_free()
	await process_frame

	# --- issue 53: two new base-game caps + four resolved ambiguities.
	# Spare Organ Receipt / 'Definitely Not Russia' Patch / Alien Pet Rocks —
	# the two caps (Item, Piece Buff) are covered in test_items.gd /
	# test_items_buffs.gd, next to their own base-game mechanics. ---

	# Spare Organ Receipt: "On Fuse: refund 50% of both consumed pieces'
	# value combined as Gold" (user ruling) — merge_logic.gd's commit_merge
	# fires a new on_fuse hook, the only new call site this slice adds, for
	# every merge (Rank Up here; a Fusion of two different pieces goes
	# through the exact same call site).
	var sor := _boot({"board": [["rook", 1, 7, 10]], "wave": 3,
		"artefacts": ["spare-organ-receipt"], "stock": ["pawn", "pawn"], "gold": 0})
	await process_frame
	sor.actions_left = 3
	MergeLogic.commit_merge(sor,
		{"id": "pawn", "cap": false, "entry": "pawn"},
		{"id": "pawn", "cap": false, "entry": "pawn"})
	check(sor.stock == ["sergeant"], "(setup) the merge itself still resolves to a Sergeant")
	check(sor.gold == 10,
		"Spare Organ Receipt: 50% of both consumed Pawns' value (10+10) combined = 10 Gold")
	sor.queue_free()
	await process_frame

	# 'Definitely Not Russia' Patch: the first piece lost each Wave is still
	# ACTUALLY lost (not Fireproof Pajamas' ctx.cancel, which saves it) but
	# masked from every effect reading on_piece_lost — Nibiru Hide-and-Seek
	# Trophy's streak collapse, lost_player, wave_lost_ids. Only the FIRST
	# loss each Wave is masked; a second one counts normally.
	var dnr := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 4, 4], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["definitely-not-russia-patch", "nibiru-hide-and-seek-trophy"]})
	await process_frame
	dnr.nibiru_wave_streak = 5 # a streak already banked from prior Waves
	var dnr_lost_before: int = dnr.lost_player
	dnr._destroy(Vector2i(2, 2)) # the masked first loss this Wave
	check(not dnr.board.has(Vector2i(2, 2)),
		"'Definitely Not Russia' Patch: the piece is still actually gone")
	check(dnr.nibiru_wave_streak == 5,
		"'Definitely Not Russia' Patch: masks the loss from Nibiru's streak collapse — it does not reset")
	check(dnr.lost_player == dnr_lost_before,
		"'Definitely Not Russia' Patch: the masked loss doesn't count toward lost_player either")
	dnr._destroy(Vector2i(4, 4)) # a second loss the SAME Wave: not masked
	check(not dnr.board.has(Vector2i(4, 4)), "a second lost piece is also actually gone")
	check(dnr.nibiru_wave_streak == 0,
		"only the FIRST loss each Wave is masked — the second resets Nibiru's streak normally")
	check(dnr.lost_player == dnr_lost_before + 1, "the second loss counts normally")
	dnr.queue_free()
	await process_frame

	# Alien Pet Rocks: "+2 Gold per allied piece that did not move this Wave"
	# — only a move/capture you spent an Action on counts as moving (user
	# ruling). A Deploy (game.gd _place) and an effect-driven shove (Tactical
	# Reposition/Decoy Swap/Rapid Deployment, all resolved in _item_apply,
	# never through _move_player) both still count as "did not move" and pay.
	var apr := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 4, 4], ["bishop", 0, 6, 6],
			["rook", 1, 7, 10]], "wave": 3, "stock": ["knight"],
			"artefacts": ["alien-pet-rocks"], "items": ["tactical_reposition"], "gold": 0})
	await process_frame
	apr.actions_left = 5
	apr._move_player(Vector2i(2, 2), Vector2i(2, 3)) # the queen: a real, Action-spent move
	apr._place("knight", Vector2i(0, 0)) # Deployed this Wave — still "did not move"
	apr._use_item(0)
	apr._item_click(Vector2i(4, 4)) # stage A: the pawn
	apr._item_click(Vector2i(4, 5)) # stage B: shoved 1 square — no Action of ITS own
	WaveLogic.queue(apr, apr.wave + 1) # clears wave 3
	check(apr.gold == 6, "Alien Pet Rocks: +2 Gold each for the deployed knight, the " +
		"shoved pawn, and the untouched bishop (6) — the queen that actually moved doesn't pay")
	apr.queue_free()
	await process_frame

	# --- issue 54: dodge (UAP Breath Mint / Inflatable Vietcong Torpedo, both
	# auto-resolving — user ruling: no targeting step, no Gold prompt) + two
	# action-economy rules (Hellfire Club Discord Invite, Pegasus Free Trial).
	# Both dodges extend BuffLogic.repels_capture's existing guard in
	# _run_enemy_actions rather than a second interception point. ---

	var uap_ctrl := _boot({"board": [["rook", 0, 4, 5], ["rook", 1, 4, 0]], "wave": 3})
	await process_frame
	await uap_ctrl._run_enemy_actions()
	check(uap_ctrl.board.get(Vector2i(4, 5), {}).get("owner", -1) == 1,
		"control: without UAP Breath Mint, the enemy rook freely captures the player piece")
	uap_ctrl.queue_free()
	await process_frame

	var uap := _boot({"board": [["rook", 0, 4, 5], ["rook", 1, 4, 0]], "wave": 3,
		"artefacts": ["uap-breath-mint"]})
	await process_frame
	await uap._run_enemy_actions()
	check(not uap.board.has(Vector2i(4, 5)) and uap.board.get(Vector2i(3, 6), {}).get("owner", -1) == 0,
		"UAP Breath Mint: dodges to the empty tile farthest from the attacker (3,6) instead of being captured")
	check(uap.board.get(Vector2i(4, 0), {}).get("owner", -1) == 1,
		"UAP Breath Mint: the attacker is repelled and stays on its own tile")
	check(uap.uap_used_this_wave, "UAP Breath Mint: spent for the Wave")
	uap.queue_free()
	await process_frame

	# once per Wave: a second attempt the same Wave is captured normally
	var uap_once := _boot({"board": [["rook", 0, 4, 5], ["rook", 1, 4, 0]], "wave": 3,
		"artefacts": ["uap-breath-mint"]})
	await process_frame
	uap_once.uap_used_this_wave = true
	await uap_once._run_enemy_actions()
	check(uap_once.board.get(Vector2i(4, 5), {}).get("owner", -1) == 1,
		"UAP Breath Mint: already spent this Wave — a second attempt is captured normally")
	WaveLogic.queue(uap_once, uap_once.wave + 1) # clears wave 3 -> on_wave_clear resets it
	check(not uap_once.uap_used_this_wave, "UAP Breath Mint: re-arms on the Wave boundary")
	uap_once.queue_free()
	await process_frame

	# no tile free: the dodge does nothing and the capture proceeds (user
	# ruling) — a corner traps the defender behind exactly 3 in-bounds
	# neighbours, all boxed; the attacking Knight leaps straight in, so the
	# 3 blockers can't obstruct its path the way they would a slider's.
	var uap_boxed := _boot({"board": [["pawn", 0, 0, 0], ["knight", 1, 2, 1],
			["pawn", 1, 0, 1], ["pawn", 1, 1, 0], ["pawn", 1, 1, 1]],
		"wave": 3, "artefacts": ["uap-breath-mint"]})
	await process_frame
	check(uap_boxed._uap_dodge_target(Vector2i(0, 0), Vector2i(2, 1)) == Vector2i(-1, -1),
		"UAP Breath Mint: every in-bounds neighbour occupied -> no dodge target")
	await uap_boxed._run_enemy_actions()
	check(uap_boxed.board.get(Vector2i(0, 0), {}).get("owner", -1) == 1,
		"UAP Breath Mint: no tile free — the dodge does nothing and the capture proceeds")
	check(not uap_boxed.uap_used_this_wave, "UAP Breath Mint: not spent when the dodge couldn't fire")
	uap_boxed.queue_free()
	await process_frame

	var torp_ctrl := _boot({"board": [["rook", 0, 4, 5], ["rook", 1, 4, 0]], "wave": 3, "gold": 500})
	await process_frame
	await torp_ctrl._run_enemy_actions()
	check(torp_ctrl.board.get(Vector2i(4, 5), {}).get("owner", -1) == 1,
		"control: without Inflatable Vietcong Torpedo, the enemy rook freely captures the player piece")
	torp_ctrl.queue_free()
	await process_frame

	var torp := _boot({"board": [["rook", 0, 4, 5], ["rook", 1, 4, 0]], "wave": 3, "gold": 500,
		"artefacts": ["inflatable-vietcong-torpedo"]})
	await process_frame
	await torp._run_enemy_actions()
	check(torp.board.get(Vector2i(4, 5), {}).get("owner", -1) == 0,
		"Inflatable Vietcong Torpedo: pays 15 Gold and the piece survives in place")
	check(torp.gold == 485, "Inflatable Vietcong Torpedo: 15 Gold is actually deducted")
	check(torp.board.get(Vector2i(4, 0), {}).get("owner", -1) == 1,
		"Inflatable Vietcong Torpedo: the attacker is repelled and stays on its own tile")
	check(torp.torpedo_used_this_wave, "Inflatable Vietcong Torpedo: spent for the Wave")
	torp.queue_free()
	await process_frame

	# under 15 Gold: doesn't fire, the capture proceeds, nothing is spent
	var torp_poor := _boot({"board": [["rook", 0, 4, 5], ["rook", 1, 4, 0]], "wave": 3, "gold": 14,
		"artefacts": ["inflatable-vietcong-torpedo"]})
	await process_frame
	await torp_poor._run_enemy_actions()
	check(torp_poor.board.get(Vector2i(4, 5), {}).get("owner", -1) == 1,
		"Inflatable Vietcong Torpedo: under 15 Gold — doesn't fire, the capture proceeds")
	check(torp_poor.gold == 14, "Inflatable Vietcong Torpedo: no Gold spent when it can't afford to fire")
	torp_poor.queue_free()
	await process_frame

	# once per Wave + re-arms at the Wave boundary
	var torp_once := _boot({"board": [["rook", 0, 4, 5], ["rook", 1, 4, 0]], "wave": 3, "gold": 500,
		"artefacts": ["inflatable-vietcong-torpedo"]})
	await process_frame
	torp_once.torpedo_used_this_wave = true
	await torp_once._run_enemy_actions()
	check(torp_once.board.get(Vector2i(4, 5), {}).get("owner", -1) == 1 and torp_once.gold == 500,
		"Inflatable Vietcong Torpedo: already spent this Wave — a second attempt is captured normally")
	WaveLogic.queue(torp_once, torp_once.wave + 1)
	check(not torp_once.torpedo_used_this_wave, "Inflatable Vietcong Torpedo: re-arms on the Wave boundary")
	torp_once.queue_free()
	await process_frame

	# combo: the free dodge is tried before the Gold-cost one — Torpedo's
	# Gold stays untouched when UAP alone already saved the piece
	var combo := _boot({"board": [["rook", 0, 4, 5], ["rook", 1, 4, 0]], "wave": 3, "gold": 500,
		"artefacts": ["uap-breath-mint", "inflatable-vietcong-torpedo"]})
	await process_frame
	await combo._run_enemy_actions()
	check(combo.uap_used_this_wave and not combo.torpedo_used_this_wave and combo.gold == 500,
		"UAP Breath Mint + Inflatable Vietcong Torpedo: the free dodge fires first, Torpedo's Gold untouched")
	combo.queue_free()
	await process_frame

	# --- Hellfire Club Discord Invite: +2 Actions/Turn, but you cannot Pass
	# while Actions remain — gated on a real legal Action existing, or the
	# rule would be able to soft-lock a Turn ---
	var hell_free := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	check(not hell_free._pass_blocked(), "control: without Hellfire, Pass is never blocked")
	hell_free.queue_free()
	await process_frame

	var hell := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3,
		"artefacts": ["hellfire-club-discord-invite"]})
	await process_frame
	check(hell.actions_left == Tuning.actions_per_turn(hell.next_tier) + 2,
		"Hellfire Club Discord Invite: +2 Actions per Turn")
	check(hell._pass_blocked(),
		"Hellfire Club Discord Invite: Pass is blocked while Actions remain and a legal move exists")
	hell._refresh()
	check(hell.hud.pass_button.disabled and hell.hud.pass_label.text == "MUST ACT" \
			and hell.hud.pass_button.tooltip_text != "",
		"Hellfire Club Discord Invite: the Pass button shows it's disabled and why, not a silent failed click")
	var hell_state_before: int = hell.state
	hell._on_pass()
	check(hell.state == hell_state_before, "Hellfire Club Discord Invite: a blocked Pass is a genuine no-op")
	hell.queue_free()
	await process_frame

	# spend every Action: the block lifts once actions_left hits 0
	var hell_spent := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3,
		"artefacts": ["hellfire-club-discord-invite"]})
	await process_frame
	hell_spent.actions_left = 0
	check(not hell_spent._pass_blocked(), "Hellfire Club Discord Invite: no block once every Action is spent")
	hell_spent.queue_free()
	await process_frame

	# no legal Action anywhere: even with Actions left and Hellfire held,
	# Pass must still end the Turn — a fully boxed-in pawn, empty Stock, no
	# Items (the softlock the issue explicitly called out)
	var hell_stuck := _boot({"board": [["pawn", 0, 2, 5], ["pawn", 1, 2, 6]], "wave": 3,
		"artefacts": ["hellfire-club-discord-invite"]})
	await process_frame
	check(hell_stuck.actions_left > 0 and not hell_stuck._has_legal_action(),
		"(setup) Actions remain, but the pawn has no legal move, Stock is empty, no Items held")
	check(not hell_stuck._pass_blocked(),
		"Hellfire Club Discord Invite: no legal Action anywhere — the block lifts so the Turn can still end")
	hell_stuck._on_pass()
	var hell_polls := 0
	while hell_stuck.state != GameScript.State.PLAYER_TURN and hell_polls < 50:
		await create_timer(0.05).timeout
		hell_polls += 1
	check(hell_stuck.turn_number == 2,
		"Hellfire Club Discord Invite: Pass actually ends the Turn when nothing else can be done")
	hell_stuck.queue_free()
	await process_frame

	# a piece that already moved this Turn doesn't count as a legal Action
	# either — Rules.legal_moves knows nothing about the once-per-piece-per-
	# Turn click-select gate (game.gd's own tile-click handler), so without
	# this filter Hellfire could block Pass on a Turn where nothing is
	# actually still selectable
	var hell_moved := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3,
		"artefacts": ["hellfire-club-discord-invite"]})
	await process_frame
	hell_moved.moved_this_turn.append(Vector2i(2, 2))
	check(not hell_moved._has_legal_action(),
		"Hellfire Club Discord Invite: a piece that already moved this Turn doesn't count as a legal Action")
	check(not hell_moved._pass_blocked(),
		"Hellfire Club Discord Invite: Pass stays allowed once the only piece has already moved")
	hell_moved.queue_free()
	await process_frame

	# --- Pegasus Free Trial (REWORKED by the user, 2026-08-29): "the first
	# move or capture each Turn by a piece at the end of its Rank chain costs
	# no Action" — reuses Blitz's own blitz_free_move flag, per piece, and
	# never touches moved_this_turn (which Blitz depends on) ---
	var peg_ctrl := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	check(not peg_ctrl.board[Vector2i(2, 2)].get("blitz_free_move", false),
		"control: without Pegasus Free Trial, an end-of-chain piece gets no free move")
	peg_ctrl.queue_free()
	await process_frame

	var peg := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 4, 4], ["rook", 1, 7, 10]], "wave": 3,
		"artefacts": ["pegasus-free-trial"]})
	await process_frame
	check(peg.board[Vector2i(2, 2)].get("blitz_free_move", false),
		"Pegasus Free Trial: an end-of-chain piece (Queen, no `next`) is granted a free move at Turn start")
	check(not peg.board[Vector2i(4, 4)].get("blitz_free_move", false),
		"Pegasus Free Trial: a piece mid-chain (Pawn, promotes into Sergeant) gets no free move")
	var peg_actions_before: int = peg.actions_left
	peg._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(peg.actions_left == peg_actions_before, "Pegasus Free Trial: the first move costs no Action")
	check(peg.moved_this_turn.has(Vector2i(2, 3)),
		"Pegasus Free Trial: moved_this_turn still tracks the move normally — untouched by the free-move flag")
	check(not peg.board[Vector2i(2, 3)].get("blitz_free_move", false),
		"Pegasus Free Trial: the free-move flag is consumed by that one move")
	peg._move_player(Vector2i(2, 3), Vector2i(2, 4))
	check(peg.actions_left == peg_actions_before - 1, "Pegasus Free Trial: the second move costs a normal Action")
	peg.queue_free()
	await process_frame

	# per piece: a second end-of-chain piece gets its OWN free move, not one
	# shared across the whole Turn — same reading as the original "move
	# twice each Turn" text, which was per piece too
	var peg2 := _boot({"board": [["queen", 0, 2, 2], ["queen", 0, 4, 4], ["rook", 1, 7, 10]], "wave": 3,
		"artefacts": ["pegasus-free-trial"]})
	await process_frame
	var peg2_actions_before: int = peg2.actions_left
	peg2._move_player(Vector2i(2, 2), Vector2i(2, 3)) # 1st Queen's own free move
	peg2._move_player(Vector2i(4, 4), Vector2i(4, 5)) # 2nd Queen's own free move
	check(peg2.actions_left == peg2_actions_before,
		"Pegasus Free Trial: per piece — a second end-of-chain piece gets its own free move, not one shared")
	peg2.queue_free()
	await process_frame

	# --- issue 55: meta-dispatch and capture conversion (the last 3) ---

	# Zeta Reticuli Souvenir Map: every 3rd Capture of the RUN (not the Wave
	# or Turn) goes to Stock instead of Captured Stock, state intact — the
	# 3rd victim below carries a manually-stamped `captures` field (the
	# per-piece ledger, issue 25) to prove Stock keeps it, not just the id
	# (ADR-0002). A bystander rook far away keeps the board from clearing
	# (and auto-passing) after the 3rd capture.
	var zeta := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2], ["pawn", 1, 4, 2],
			["pawn", 1, 5, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["zeta-reticuli-souvenir-map"]})
	await process_frame
	zeta.actions_left = 10
	zeta.board[Vector2i(5, 2)]["captures"] = 3 # arbitrary piece state to carry over
	zeta._move_player(Vector2i(2, 2), Vector2i(3, 2)) # 1st Capture
	check(zeta.captured.count("pawn") == 1 and zeta.stock.is_empty(),
		"Zeta Reticuli Souvenir Map: the 1st Capture is unaffected")
	zeta._move_player(Vector2i(3, 2), Vector2i(4, 2)) # 2nd Capture
	check(zeta.captured.count("pawn") == 2 and zeta.stock.is_empty(),
		"Zeta Reticuli Souvenir Map: the 2nd Capture is unaffected")
	zeta._move_player(Vector2i(4, 2), Vector2i(5, 2)) # 3rd Capture — diverted
	check(zeta.captured.count("pawn") == 2 and zeta.stock.size() == 1,
		"Zeta Reticuli Souvenir Map: the 3rd Capture lands in Stock instead of Captured Stock")
	check(zeta.stock[0] is Dictionary and zeta.stock[0].id == "pawn"
			and zeta.stock[0].get("captures", -1) == 3 and not zeta.stock[0].has("owner"),
		"Zeta Reticuli Souvenir Map: the Stock entry keeps the piece's state intact (captures " +
		"ledger = 3), owner stripped — same shape as Extraction (ADR-0002)")
	zeta.queue_free()
	await process_frame

	# Troll Farm Employee of the Month: a held on_wave_clear Artefact pays
	# TWICE across one Wave boundary — once at the normal Wave clear, once
	# more from the Wave-start echo. Trilateral Meeting Stickers (+5 Gold per
	# held Artefact, no ctx read) makes the math ctx-independent.
	var troll_a := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "gold": 0,
		"artefacts": ["trilateral-meeting-stickers", "troll-farm-employee-of-the-month"]})
	await process_frame
	WaveLogic.queue(troll_a, 2)
	check(troll_a.gold == 20,
		"Troll Farm Employee of the Month: a Wave Artefact (Trilateral Meeting Stickers) pays " +
		"twice across one Wave boundary — Wave clear (5x2=10) + the Wave-start echo (10) = 20")
	troll_a.queue_free()
	await process_frame

	# Troll Farm re-triggering a 5-Wave Milestone Artefact (John Titor's
	# Crypto Wallet, acquired Wave 2 -> beats at Wave 6, 11, …) uses THAT
	# copy's own acquired_wave, not a wave-1 default (issue 28's exact bug) —
	# the Wave-start echo re-checks the milestone against the already-bumped
	# NEW wave, so it can hit (Wave 6) even on a boundary whose normal
	# Wave-clear dispatch (for Wave 5, not this copy's beat) didn't pay.
	var troll_b := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 2, "gold": 0,
		"artefacts": ["john-titor-s-crypto-wallet", "troll-farm-employee-of-the-month"]})
	await process_frame
	troll_b.clock_ms = 25000.0 # +5 Gold per firing (int(25.0 / 5.0))
	for n in range(3, 6): # clear Waves 2, 3, 4: none is this copy's own beat
		WaveLogic.queue(troll_b, n)
	check(troll_b.gold == 0,
		"Troll Farm + John Titor's Crypto Wallet: no payout before Wave 6 (this copy's own beat)")
	WaveLogic.queue(troll_b, 6) # Wave 5 clears (not a beat); Wave 6 STARTS as one
	check(troll_b.gold == 5,
		"Troll Farm Employee of the Month: the Wave-start echo of a 5-Wave Milestone Artefact " +
		"uses THIS copy's own acquired_wave (2) — it pays on Wave 6 (its beat) even though the " +
		"ordinary Wave 5 Wave-clear dispatch just before it did not")
	troll_b.queue_free()
	await process_frame

	# Ecdysis Sheddings: inert before any purchase, then mirrors the last
	# OTHER Artefact bought as a genuine second copy (Greed: +10 per Capture).
	var ecdy := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 9999, "artefacts": ["ecdysis-sheddings"]})
	await process_frame
	check(ecdy.ecdysis_copy_key == "", "Ecdysis Sheddings: inert (no copy key) before anything is bought")
	var ecdy_base: int = ecdy.defs.pawn.value
	check(Economy.capture_score(ecdy, "pawn") == ecdy_base,
		"Ecdysis Sheddings: copies nothing before any purchase — a plain Capture is unaffected")
	ecdy.actions_left = 5
	ecdy.shop_stock.append({"kind": "artefact", "key": "greed", "sold": false})
	Shop.buy(ecdy, ecdy.shop_stock.size() - 1)
	check(ecdy.ecdysis_copy_key == "greed", "Ecdysis Sheddings: records the last Artefact bought (Greed)")
	check(Economy.capture_score(ecdy, "pawn") == ecdy_base + 20,
		"Ecdysis Sheddings: mirrors the bought Greed as a second copy (+10 real, +10 mirrored = +20)")
	# Buying a SECOND Ecdysis must not overwrite the copy key with its own —
	# "other" excludes it — or two copies would chase each other.
	ecdy.actions_left = 5
	ecdy.shop_stock.append({"kind": "artefact", "key": "ecdysis-sheddings", "sold": false})
	Shop.buy(ecdy, ecdy.shop_stock.size() - 1)
	check(ecdy.ecdysis_copy_key == "greed",
		"Ecdysis Sheddings: buying ANOTHER Ecdysis does not overwrite the copied key")
	check(Economy.capture_score(ecdy, "pawn") == ecdy_base + 30,
		"Ecdysis Sheddings: two held copies each independently mirror Greed (+10 real + 10 + 10 " +
		"= +30) — bounded, no chase")
	check(ecdy.artefact_echo_depth == 0,
		"Ecdysis Sheddings: the echo-depth guard is back at 0 after dispatch (no leak)")
	ecdy.queue_free()
	await process_frame

	# A Box-granted Artefact never fires on_purchase, so it can't set the
	# copy key — "Box grants ... do not set it" (issue 55).
	var ecdy_box := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["ecdysis-sheddings"]})
	await process_frame
	var score_catalog: Dictionary
	for t in Items.ARTEFACT_EFFECTS:
		if t.key == "score":
			score_catalog = t
			break
	ecdy_box._box_choose({"kind": "artefact", "name": "x", "description": "x", "payload": score_catalog})
	check(ecdy_box.ecdysis_copy_key == "",
		"Ecdysis Sheddings: a Box-granted Artefact does not set the copied key")
	ecdy_box.queue_free()
	await process_frame

	# The risky combo named in the issue: Ecdysis copying a bought Wave
	# Artefact while Troll Farm is also held. Bounded, deterministic dispatch
	# count across one Wave boundary proves neither the two-Ecdysis nor the
	# Ecdysis+Troll-Farm shape can recurse: normal Wave-clear (1) + Ecdysis's
	# mirror of it (1, hook == on_wave_clear) + Troll Farm's Wave-start echo
	# of the real copy (1, hook == on_wave_spawn, never re-mirrored by
	# Ecdysis since Trilateral doesn't listen on_wave_spawn) = 3 dispatches,
	# not an infinite chain.
	var ecdy_troll := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "gold": 9999,
		"artefacts": ["troll-farm-employee-of-the-month", "ecdysis-sheddings"]})
	await process_frame
	ecdy_troll.actions_left = 5
	ecdy_troll.shop_stock.append({"kind": "artefact", "key": "trilateral-meeting-stickers", "sold": false})
	Shop.buy(ecdy_troll, ecdy_troll.shop_stock.size() - 1)
	check(ecdy_troll.ecdysis_copy_key == "trilateral-meeting-stickers",
		"setup: buying Trilateral Meeting Stickers records it as Ecdysis's copy target")
	ecdy_troll.gold = 0 # isolate the Wave-boundary payout from the purchase's own spend
	WaveLogic.queue(ecdy_troll, 2)
	check(ecdy_troll.gold == 45,
		"Ecdysis Sheddings + Troll Farm Employee of the Month + a bought Wave Artefact: exactly " +
		"3 bounded dispatches across one Wave boundary (5 Gold x 3 held Artefacts x 3 dispatches " +
		"= 45), not an infinite chain")
	check(ecdy_troll.artefact_echo_depth == 0,
		"Ecdysis + Troll Farm combo: the echo-depth guard is back at 0 after dispatch (no leak)")
	ecdy_troll.queue_free()
	await process_frame

	# --- issue 52: Artefact activation ---

	# Oak Island Wishing Well: confirm-gated, untargeted, once per Turn
	var oak := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "gold": 100, "score": 0, "artefacts": ["oak-island-wishing-well"]})
	await process_frame
	check(oak._artefact_activation_available("oak-island-wishing-well"),
		"Oak Island Wishing Well: available (held, affordable, not used this Turn)")
	oak._artefact_confirmed("oak-island-wishing-well")
	check(oak.gold == 475 and oak.score == 400,
		"Oak Island Wishing Well: confirmed activation pays 25 Gold for +400 Score (earn() " +
		"also grants the matching Gold, same as every other reward routed through it: 100 - 25 + 400 = 475)")
	check(not oak._artefact_activation_available("oak-island-wishing-well"),
		"Oak Island Wishing Well: unavailable again — once per Turn already spent")
	oak._begin_player_turn() # next Turn: the once-per-Turn charge recharges
	check(oak._artefact_activation_available("oak-island-wishing-well"),
		"Oak Island Wishing Well: available again next Turn")
	oak.queue_free()
	await process_frame

	# FIFA Complimentary Yacht: no per-Turn limit, the deliberate exception
	var fifa := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "gold": 150, "artefacts": ["fifa-complimentary-yacht"]})
	await process_frame
	var fifa_actions_before: int = fifa.actions_left
	fifa._artefact_confirmed("fifa-complimentary-yacht")
	check(fifa.gold == 100 and fifa.actions_left == fifa_actions_before + 1 \
			and fifa.actions_max == fifa_actions_before + 1,
		"FIFA Complimentary Yacht: 50 Gold for +1 Action — actions_left AND actions_max both grow")
	fifa._artefact_confirmed("fifa-complimentary-yacht") # again, same Turn
	check(fifa.gold == 50 and fifa.actions_left == fifa_actions_before + 2,
		"FIFA Complimentary Yacht: any number of times per Turn — a 2nd activation the same Turn still works")
	fifa._artefact_confirmed("fifa-complimentary-yacht") # a 3rd time: gold hits 0
	check(fifa.gold == 0 and fifa.actions_left == fifa_actions_before + 3,
		"FIFA Complimentary Yacht: a 3rd activation the same Turn still works — no limit at all")
	check(not fifa._artefact_activation_available("fifa-complimentary-yacht"),
		"FIFA Complimentary Yacht: unavailable once Gold drops below 50")
	fifa.queue_free()
	await process_frame

	# Moscovium Glow Stick: the first consumable Artefact + the deliberate
	# multiplicative-stacking exception (artefact_hooks.gd header)
	var glow := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "gold": 0, "score": 0, "artefacts": ["moscovium-glow-stick"]})
	await process_frame
	glow._artefact_confirmed("moscovium-glow-stick")
	check(glow._artefact_count("moscovium-glow-stick") == 0 and glow.moscovium_active,
		"Moscovium Glow Stick: activation consumes the Artefact and flags the triple-gain window")
	Economy.earn(glow, 100)
	check(glow.score == 300 and glow.gold == 300,
		"Moscovium Glow Stick: Score and Gold gains are tripled while active (100 -> 300 each)")
	glow._begin_player_turn() # next Turn: "until end of Turn" expires
	check(not glow.moscovium_active, "Moscovium Glow Stick: the window ends at the next Turn")
	Economy.earn(glow, 100)
	check(glow.score == 400 and glow.gold == 400,
		"Moscovium Glow Stick: back to normal (not tripled) once the window has ended")
	glow.queue_free()
	await process_frame

	var glow2 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "artefacts": ["moscovium-glow-stick", "moscovium-glow-stick"]})
	await process_frame
	glow2._artefact_confirmed("moscovium-glow-stick")
	check(glow2._artefact_count("moscovium-glow-stick") == 1,
		"Moscovium Glow Stick: activating one held copy leaves a held duplicate untouched")
	glow2.queue_free()
	await process_frame

	# Moscovium + Ecdysis Sheddings (issue 55): copying a consumed Artefact's
	# key must be a safe no-op — Moscovium has no REGISTRY entry, so
	# REGISTRY.get("moscovium-glow-stick", []) is empty and _run_meta_triggers
	# never dispatches it, no matter how many hooks fire afterward.
	var ecdy_glow := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "gold": 9999, "score": 0, "artefacts": ["ecdysis-sheddings"]})
	await process_frame
	ecdy_glow.actions_left = 5
	ecdy_glow.shop_stock.append({"kind": "artefact", "key": "moscovium-glow-stick", "sold": false})
	Shop.buy(ecdy_glow, ecdy_glow.shop_stock.size() - 1)
	check(ecdy_glow.ecdysis_copy_key == "moscovium-glow-stick",
		"setup: buying Moscovium Glow Stick records it as Ecdysis's copy target")
	ecdy_glow._artefact_confirmed("moscovium-glow-stick") # consume the ONLY copy
	check(ecdy_glow._artefact_count("moscovium-glow-stick") == 0,
		"setup: Moscovium Glow Stick is now consumed — gone from g.artefacts entirely")
	check(ecdy_glow.ecdysis_copy_key == "moscovium-glow-stick",
		"Moscovium + Ecdysis Sheddings: the copied key is never cleared by the copy being consumed")
	Economy.capture_score(ecdy_glow, "pawn") # on_capture: exercises the full
		# held+tariff dispatch loop AND _run_meta_triggers' Ecdysis branch
	check(ecdy_glow.artefact_echo_depth == 0 and ecdy_glow._artefact_count("moscovium-glow-stick") == 0,
		"Moscovium + Ecdysis Sheddings: a hook firing afterward does not crash or double-consume " +
		"(Ecdysis's mirror of an un-registered key is an inert no-op)")
	ecdy_glow.queue_free()
	await process_frame

	# Roanoke Hex Kit: "vanishes, paying nothing" (_destroy-shaped) + the
	# per-copy "every 2nd 5-Wave Milestone" recharge
	var roan := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10], ["pawn", 1, 2, 9]],
		"wave": 10, "gold": 0, "score": 0, "artefacts": ["roanoke-hex-kit"]})
	await process_frame
	roan.artefacts[0].acquired_wave = 1 # this copy's 2nd 5-Wave Milestone
		# (every 2nd, per held copy) lands at wave 1 + 10*1 - 1 = 10
	check(roan._artefact_activation_available("roanoke-hex-kit"),
		"Roanoke Hex Kit: available once its copy's 2nd 5-Wave Milestone (wave 10) is reached")
	roan._artefact_confirmed("roanoke-hex-kit")
	check(not roan.board.has(Vector2i(7, 10)) and roan.board.has(Vector2i(2, 9)),
		"Roanoke Hex Kit: the strongest enemy (Rook) vanishes; the weaker Pawn is untouched")
	check(roan.score == 0 and roan.gold == 0, "Roanoke Hex Kit: vanishes paying no Score or Gold")
	check(not roan._artefact_activation_available("roanoke-hex-kit"),
		"Roanoke Hex Kit: unavailable again until its NEXT even milestone (wave 20)")
	roan.wave = 19
	check(not roan._artefact_activation_available("roanoke-hex-kit"),
		"Roanoke Hex Kit: still unavailable one Wave before its next even milestone")
	roan.wave = 20
	check(roan._artefact_activation_available("roanoke-hex-kit"),
		"Roanoke Hex Kit: available again exactly at its next even milestone (wave 20)")
	roan.queue_free()
	await process_frame

	# Zapruder's Director's Cut: repeats the SAME piece's SAME displacement
	# from its new position — game.gd's own scoping of "previous Action"
	var zap := _boot({"board": [["rook", 0, 2, 2], ["pawn", 1, 7, 10]],
		"wave": 1, "artefacts": ["zapruder-s-director-s-cut"]})
	await process_frame
	zap.actions_left = 5
	zap._move_player(Vector2i(2, 2), Vector2i(2, 5)) # plain move, no capture
	check(zap.board.has(Vector2i(2, 5)), "setup: the Rook moved to (2,5)")
	var zap_actions_before: int = zap.actions_left
	check(zap._artefact_activation_available("zapruder-s-director-s-cut"),
		"Zapruder's Director's Cut: available — the last Action was a plain, still-legal move")
	zap._artefact_confirmed("zapruder-s-director-s-cut")
	check(zap.board.has(Vector2i(2, 8)) and not zap.board.has(Vector2i(2, 5)),
		"Zapruder's Director's Cut: repeats the SAME displacement from the piece's new position (2,5 -> 2,8)")
	check(zap.actions_left == zap_actions_before,
		"Zapruder's Director's Cut: the repeat spends no Action")
	check(not zap._artefact_activation_available("zapruder-s-director-s-cut"),
		"Zapruder's Director's Cut: unavailable again — once per Wave already spent")
	zap.queue_free()
	await process_frame

	# Zapruder's Director's Cut (issue 56 redesign): complements the
	# move/capture replay above — for the 3 kinds a replay can't express, it
	# gives back the resource instead. Deploy: the deployed piece un-deploys,
	# back to Stock.
	var zap_place := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 7, 10]],
		"wave": 1, "stock": ["rook"], "artefacts": ["zapruder-s-director-s-cut"]})
	await process_frame
	zap_place.actions_left = 5
	zap_place._place("rook", Vector2i(3, 0))
	check(zap_place._artefact_activation_available("zapruder-s-director-s-cut"),
		"Zapruder's Director's Cut: available after a Deploy too — it returns the piece instead of repeating")
	zap_place._artefact_confirmed("zapruder-s-director-s-cut")
	check(not zap_place.board.has(Vector2i(3, 0)) and zap_place.stock == ["rook"],
		"Zapruder's Director's Cut: the just-Deployed piece is un-deployed, back in Stock")
	check(not zap_place._artefact_activation_available("zapruder-s-director-s-cut"),
		"Zapruder's Director's Cut: unavailable again — once per Wave already spent")
	zap_place.queue_free()
	await process_frame

	# Item use: the Item itself comes back.
	var zap_item := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 7, 10]],
		"wave": 1, "artefacts": ["zapruder-s-director-s-cut"]})
	await process_frame
	zap_item.actions_left = 5
	zap_item.items.append({"key": "counter_intel", "name": "Counter-Intel", "tier": "Strategic",
		"target": "", "description": ""})
	zap_item._use_item(0) # target "" resolves instantly, no tile click needed
	check(zap_item.items.is_empty(), "setup: Counter-Intel consumed")
	check(zap_item._artefact_activation_available("zapruder-s-director-s-cut"),
		"Zapruder's Director's Cut: available after an Item use")
	zap_item._artefact_confirmed("zapruder-s-director-s-cut")
	check(zap_item.items.size() == 1 and zap_item.items[0].key == "counter_intel",
		"Zapruder's Director's Cut: the used Item is back in the inventory")
	zap_item.queue_free()
	await process_frame

	# Item return refused at a full inventory (issue 53's cap of 3) — the
	# once-per-Wave charge is still spent, same "spent either way" precedent
	# as every other full-inventory grant (e.g. _box_choose's ItemLogic.grant).
	var zap_full := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 7, 10]],
		"wave": 1, "artefacts": ["zapruder-s-director-s-cut"]})
	await process_frame
	zap_full.actions_left = 5
	zap_full.items.append({"key": "counter_intel", "name": "Counter-Intel", "tier": "Strategic",
		"target": "", "description": ""})
	zap_full._use_item(0) # the Item Zapruder will try (and fail) to return
	for i in 3: # refill to the cap with something else, as if drawn meanwhile
		zap_full.items.append({"key": "blitz", "name": "Blitz", "tier": "Tactical",
			"target": "tile", "action_cost": 0, "description": ""})
	check(zap_full.items.size() == 3, "setup: inventory refilled to the cap (3) after the Item was used")
	check(zap_full._artefact_activation_available("zapruder-s-director-s-cut"),
		"Zapruder's Director's Cut: still available — availability doesn't check the cap")
	zap_full._artefact_confirmed("zapruder-s-director-s-cut")
	check(zap_full.items.size() == 3 and zap_full.items.all(func(it: Dictionary) -> bool: return it.key == "blitz"),
		"Zapruder's Director's Cut: the return is refused at a full inventory")
	check(not zap_full._artefact_activation_available("zapruder-s-director-s-cut"),
		"Zapruder's Director's Cut: the once-per-Wave charge is spent either way")
	zap_full.queue_free()
	await process_frame

	# Merge: BOTH consumed pieces return to Stock, state intact (ADR-0002) —
	# on top of the merge result the player already kept (user ruling: the
	# duplication is accepted, bounded by once-per-Wave on a Legendary).
	var zap_merge := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 7, 10]],
		"wave": 1, "stock": ["pawn"], "artefacts": ["zapruder-s-director-s-cut"]})
	await process_frame
	zap_merge.stock.append({"id": "pawn", "buff": true})
	zap_merge.actions_left = 5
	MergeLogic.commit_merge(zap_merge,
		{"id": "pawn", "cap": false, "entry": {"id": "pawn", "buff": true}},
		{"id": "pawn", "cap": false, "entry": "pawn"})
	check(zap_merge.stock == ["sergeant"], "setup: the merge consumed both pawns, leaving only the result")
	check(zap_merge._artefact_activation_available("zapruder-s-director-s-cut"),
		"Zapruder's Director's Cut: available after a Merge")
	zap_merge._artefact_confirmed("zapruder-s-director-s-cut")
	check(zap_merge.stock.size() == 3 and zap_merge.stock.has("sergeant") \
			and zap_merge.stock.has("pawn") and zap_merge.stock.has({"id": "pawn", "buff": true}),
		"Zapruder's Director's Cut: both consumed pieces return to Stock (one with its state intact), " +
		"alongside the merge result the player already kept")
	zap_merge.queue_free()
	await process_frame

	# Bovine Tractor Beam: the one TARGETED activation — no confirm, cancels
	# from targeting instead (user ruling)
	var bov_notarget := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "artefacts": ["bovine-tractor-beam"]}) # an enemy in the initial
		# config, else _begin_player_turn's "board cleared -> next Wave" branch
		# (not _any_enemy()) auto-spawns one, defeating "no target" on purpose
	await process_frame
	bov_notarget.board.erase(Vector2i(7, 10)) # now genuinely no enemy left
	check(not bov_notarget._artefact_activation_available("bovine-tractor-beam"),
		"Bovine Tractor Beam: unavailable with no enemy piece to target")
	bov_notarget.queue_free()
	await process_frame

	var bov := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "artefacts": ["bovine-tractor-beam"]})
	await process_frame
	bov._activate_artefact("bovine-tractor-beam")
	check(bov.artefact_targeting_key == "bovine-tractor-beam", "setup: targeting is staged")
	bov._artefact_target_click(Vector2i(7, 10)) # stage A: the enemy Rook
	check(bov.artefact_target_stage_a == Vector2i(7, 10), "setup: stage A picked (the enemy Rook)")
	var dest: Vector2i = bov.artefact_targets[0] # an empty tile on the player's side
	bov._artefact_target_click(dest)
	check(not bov.board.has(Vector2i(7, 10)) and bov.board.get(dest, {}).get("id", "") == "rook" \
			and bov.board[dest].owner == Rules.ENEMY,
		"Bovine Tractor Beam: the enemy piece relocates to the picked tile on the player's side, ownership unchanged")
	check(bov.artefact_targeting_key == "" and bov.bovine_used_this_wave,
		"Bovine Tractor Beam: targeting resets and the once-per-Wave charge is spent only on commit")
	check(not bov._artefact_activation_available("bovine-tractor-beam"),
		"Bovine Tractor Beam: unavailable again — once per Wave already spent")
	bov.queue_free()
	await process_frame

	# Jet Fuel Vial: the Shop-only 7th (not part of the in-run Activate set)
	var jet := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 9, "gold": 100, "artefacts": ["jet-fuel-vial"]})
	await process_frame
	check(not GameScript.ACTIVATABLE_ARTEFACT_KEYS.has("jet-fuel-vial"),
		"Jet Fuel Vial: NOT part of the in-run Activate set (user ruling: it's a Shop control)")
	check(jet._jet_fuel_restock_available(),
		"Jet Fuel Vial: available (held, Shop-visit charge unused, affordable)")
	jet._jet_fuel_restock_confirmed()
	check(jet.gold == 80 and jet.jet_fuel_used_this_visit,
		"Jet Fuel Vial: confirmed restock pays 20 Gold and spends the once-per-Shop-visit charge")
	check(not jet._jet_fuel_restock_available(),
		"Jet Fuel Vial: unavailable again — already used this Shop visit")
	jet._open_shop() # a fresh Shop visit
	check(jet._jet_fuel_restock_available(), "Jet Fuel Vial: available again on a fresh Shop visit")
	jet.queue_free()
	await process_frame

	# Cancel costs nothing — both shapes (acceptance: assert explicitly)
	var cancel := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "gold": 100, "score": 0, "artefacts": ["oak-island-wishing-well"]})
	await process_frame
	cancel._activate_artefact("oak-island-wishing-well") # opens the confirm modal
	check(cancel.buff_pick_open, "setup: the confirm modal is open")
	cancel._choice_pick_cancelled() # "Cancel"
	check(cancel.gold == 100 and cancel.score == 0 and not cancel.oak_island_used_this_turn \
			and cancel._artefact_count("oak-island-wishing-well") == 1,
		"Confirm path: cancelling costs nothing — no Gold, no charge, Artefact untouched")
	check(cancel._artefact_activation_available("oak-island-wishing-well"),
		"Confirm path: still available after a cancel")
	cancel.queue_free()
	await process_frame

	var jet_cancel := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 9, "gold": 100, "artefacts": ["jet-fuel-vial"]})
	await process_frame
	jet_cancel._jet_fuel_restock_pressed() # opens the confirm modal
	jet_cancel._choice_pick_cancelled()
	check(jet_cancel.gold == 100 and not jet_cancel.jet_fuel_used_this_visit,
		"Confirm path (Shop): cancelling the restock confirm costs nothing")
	jet_cancel.queue_free()
	await process_frame

	var bcancel := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "artefacts": ["bovine-tractor-beam"]})
	await process_frame
	bcancel._activate_artefact("bovine-tractor-beam")
	bcancel._artefact_target_click(Vector2i(7, 10)) # stage A picked
	bcancel._activate_artefact("bovine-tractor-beam") # tap the chip again: cancel
	check(bcancel.artefact_targeting_key == "" and bcancel.board.has(Vector2i(7, 10)) \
			and not bcancel.bovine_used_this_wave and bcancel._artefact_count("bovine-tractor-beam") == 1,
		"Targeting path: cancelling MID-STAGE costs nothing — no move, no charge, Artefact untouched")
	check(bcancel._artefact_activation_available("bovine-tractor-beam"),
		"Targeting path: still available after a cancel")
	bcancel.queue_free()
	await process_frame

	# The Activate section: absent entirely when empty (acceptance: "the
	# drawer is unchanged from today"), present once something is held
	var no_activ := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 1})
	await process_frame
	no_activ._refresh()
	check(no_activ.hud.activate_box.get_child_count() == 0 \
			and no_activ.hud.drawers["inventory"].custom_minimum_size.y == no_activ.hud.INV_H_BASE,
		"Activate section: absent, drawer at today's height, with no activatable Artefact held")
	no_activ.queue_free()
	await process_frame

	var held_activ := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 1,
		"artefacts": ["fifa-complimentary-yacht"]})
	await process_frame
	held_activ._refresh()
	await process_frame # queue_free() on the rebuilt chip is deferred — let it
		# resolve before counting, else a stale one lingers alongside the fresh one
	check(held_activ.hud.activate_box.get_child_count() == 1,
		"Activate section: exactly one chip once one activatable Artefact is held")
	check(held_activ.hud.drawers["inventory"].custom_minimum_size.y == held_activ.hud.INV_H_ACTIVATE,
		"Activate section: the drawer grows one row to fit it")
	held_activ.queue_free()
	await process_frame

	# Activation costs 0 Actions — assert directly (acceptance)
	var free_action := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "gold": 100, "artefacts": ["oak-island-wishing-well"]})
	await process_frame
	var actions_before_activation: int = free_action.actions_left
	free_action._artefact_confirmed("oak-island-wishing-well")
	check(free_action.actions_left == actions_before_activation,
		"Artefact activation costs 0 Actions (Oak Island Wishing Well, representative of all 6)")
	free_action.queue_free()
	await process_frame

	# Autoplay exercises activation without hanging, and sometimes actually
	# activates — driven directly (headless, no window needed) with a pinned
	# seed so the outcome is reproducible, not a flake.
	var bot := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 7, 10]],
		"wave": 1, "gold": 500, "artefacts": ["fifa-complimentary-yacht", "moscovium-glow-stick"],
		"seed": 7})
	bot.autoplay = true
	await process_frame
	var activated := false
	for i in 200:
		AutoplayBot.step(bot)
		if bot.gold != 500 or bot._artefact_count("moscovium-glow-stick") == 0:
			activated = true
			break
	check(activated, "Autoplay: sometimes actually activates a held Artefact (not a silent never-press bot)")
	bot.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL ARTEFACTS 4 CHECKS OK")
	quit(1 if fails > 0 else 0)
