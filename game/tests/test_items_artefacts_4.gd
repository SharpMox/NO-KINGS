extends SceneTree
## Artefacts, part 4: the echo/meta-trigger layer (issue 21), the Blitz
## rework and its Tier-5 interaction, the per-artefact 5-Wave Milestone fix,
## runtime rarity metadata + Illuminati Fridge Magnet (issue 29),
## capture-context effects (issue 31), and the issue 28 audit (unwired
## artefacts, REGISTRY-coverage guard, echo x milestone coverage).
## Split out of test_items.gd (issue 37).
## Run headless:  godot --headless --path game -s tests/test_items_artefacts_4.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Economy := preload("res://scripts/economy.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const Shop := preload("res://scripts/shop.gd")
const Items := preload("res://data/items.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")

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

	# --- issue 28: audit the 3 unwired 5-Wave-Milestone artefacts + a general
	# REGISTRY-coverage guard + echo x milestone coverage ---

	# Roanoke Hex Kit has no REGISTRY wiring (its Outcome says deliberately
	# unimplemented) — must stay `implemented: false` so
	# Items._build_artefact_effects() never offers a dead artefact to the
	# player. It is the last of the originally-unwired trio: issue 43 wired
	# Mar-a-Lago Toilet Papers (on_wave_clear + on_price) and issue 44 wired
	# Yalta Cocktail Napkin (the choice-modal seam's first real consumer) —
	# both are covered in test_items_artefacts_3.gd.
	for unwired_key in ["roanoke-hex-kit"]:
		var unwired_found := false
		for cat in Items.ARTEFACT_CATALOG:
			if cat.key == unwired_key:
				unwired_found = true
				check(not cat.get("implemented", false),
					"%s stays implemented: false (no REGISTRY wiring exists to fire it)" % cat.name)
		check(unwired_found, "%s is in the catalog" % unwired_key)

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

	print("---")
	if fails == 0:
		print("ALL ARTEFACTS 4 CHECKS OK")
	quit(1 if fails > 0 else 0)
