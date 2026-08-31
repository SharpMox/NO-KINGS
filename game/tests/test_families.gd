extends SceneTree
## The Family framework (issue 67): catalog sanity, kit application on a
## fresh boot, the three Powers, the three Abilities, the once-per-Wave +
## 1-Action gating, and the safety-catch/stacking assertions the issue calls
## out by name. Run headless:  godot --headless --path game -s tests/test_families.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Families := preload("res://scripts/families.gd")
const MergeLogic := preload("res://scripts/merge_logic.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const Economy := preload("res://scripts/economy.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")
const Shop := preload("res://scripts/shop.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


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


## A genuinely FRESH boot (game.gd's `next_config.is_empty()` branch) — the
## only way to exercise the Family kit application itself (Gold/Items),
## which only runs there, not on a config/save restore.
func _boot_fresh(army: String) -> Node2D:
	GameScript.next_config = {}
	GameScript.next_army = army
	GameScript.next_tier = Tuning.DEFAULT_TIER
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _init() -> void:
	# --- catalog sanity ---
	check(Families.CATALOG.size() == 3, "three seed Families")
	for id in Tuning.ARMIES:
		check(Families.CATALOG.has(id), "%s: every Army id has a Family entry (load-bearing save key)" % id)
	check(Families.display_name("Crown") == "The Muster",
		"Crown's DISPLAY name is The Muster (\"The Levy\" vetoed) — the save id stays \"Crown\"")
	check(Families.display_name("Wild Hunt") == "Wild Hunt" and Families.display_name("Old Guard") == "Old Guard",
		"the other two seeds keep their id as their display name")

	# --- kit application on a fresh boot: Stock (pre-existing), Gold, Items ---
	var muster := _boot_fresh("Crown")
	await process_frame
	check(muster.gold == Tuning.FAMILY_BASELINE_GOLD, "The Muster: baseline Gold")
	check(muster.items.size() == 1 and muster.items[0].key == "promote", "The Muster: 1 Promote item")
	muster.queue_free()
	await process_frame

	var hunt := _boot_fresh("Wild Hunt")
	await process_frame
	check(hunt.gold == Tuning.FAMILY_BASELINE_GOLD / 2, "Wild Hunt: ~half Gold")
	check(hunt.items.size() == 2 and hunt.items[0].key == "blitz" and hunt.items[1].key == "blitz",
		"Wild Hunt: 2 Blitz items")
	hunt.queue_free()
	await process_frame

	var guard := _boot_fresh("Old Guard")
	await process_frame
	check(guard.gold == Tuning.FAMILY_BASELINE_GOLD / 2, "Old Guard: ~half Gold")
	check(guard.items.size() == 1 and guard.items[0].key == "extraction", "Old Guard: 1 Extraction item")
	guard.queue_free()
	await process_frame

	# --- Power: Close Ranks (The Muster) — merges cost no Action ---
	var muster_merge := _boot({"army": "Crown", "wave": 1, "stock": ["pawn", "pawn"],
		"board": [["rook", 1, 7, 10]]})
	await process_frame
	muster_merge.actions_left = 0 # already spent — a free merge must still work
	var actions_before: int = muster_merge.actions_left
	var pair := [{"id": "pawn", "cap": false, "entry": "pawn"}, {"id": "pawn", "cap": false, "entry": "pawn"}]
	MergeLogic.commit_merge(muster_merge, pair[0], pair[1])
	check(muster_merge.stock.size() == 1 and muster_merge.stock[0] == "sergeant",
		"Close Ranks: the merge landed (2 pawns -> 1 sergeant) despite 0 actions_left going in")
	check(muster_merge.actions_left == actions_before,
		"Close Ranks: merging spent no Action (actions_left unchanged: %d -> %d)"
		% [actions_before, muster_merge.actions_left])
	check(muster_merge.state == muster_merge.State.PLAYER_TURN,
		"Close Ranks: a free merge at 0 actions_left does not auto-pass the Turn")
	muster_merge.queue_free()
	await process_frame

	# A non-Muster Family still pays for merges (sanity: the Power is scoped, not global)
	var crown_merge := _boot({"army": "Old Guard", "wave": 1, "stock": ["pawn", "pawn"], "gold": 0,
		"board": [["rook", 1, 7, 10]]})
	await process_frame
	var before_actions: int = crown_merge.actions_left
	MergeLogic.commit_merge(crown_merge,
		{"id": "pawn", "cap": false, "entry": "pawn"}, {"id": "pawn", "cap": false, "entry": "pawn"})
	check(crown_merge.actions_left == before_actions - 1,
		"(sanity) Old Guard has no Close Ranks — merging still costs its Action")
	crown_merge.queue_free()
	await process_frame

	# --- Power: Blood in the Air (Wild Hunt) stacks ADDITIVELY with the core
	# first_capture_extra Artefact — two refunds, not deduped (issue 67) ---
	var blood := _boot({"army": "Wild Hunt", "wave": 1,
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 3]],
		"artefacts": ["first_capture_extra"]})
	await process_frame
	var actions_max_before: int = blood.actions_max
	blood._move_player(Vector2i(2, 2), Vector2i(2, 3)) # the Turn's first action: a capture
	check(blood.actions_max == actions_max_before + 2,
		"Blood in the Air + first_capture_extra: BOTH refund the Turn's first capture " +
		"(actions_max %d -> %d, +2 not +1 — the standing 'big interactions stay' rule)"
		% [actions_max_before, blood.actions_max])
	blood.queue_free()
	await process_frame

	# --- Power: Hold the Line (Old Guard) — refund on LOSS, and the two
	# safety catches named in the issue, asserted directly ---
	var line := _boot({"army": "Old Guard", "gold": 0,
		"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 1})
	await process_frame
	var pawn_value: int = line.defs["pawn"].value
	line._lose_player_piece(Vector2i(2, 2), "captured")
	check(line.gold == pawn_value, "Hold the Line: losing a piece refunds its full value in Gold")
	line.queue_free()
	await process_frame

	# Safety catch 1: selling must NOT also trigger Hold the Line (50% sale +
	# 100% loss-refund would be a 150% money printer) — assert the exact amount.
	var sell := _boot({"army": "Old Guard", "gold": 0, "stock": ["pawn"], "wave": 1,
		"board": [["rook", 0, 1, 0], ["rook", 1, 7, 10]]}) # a board piece so selling
		# the only Stock pawn doesn't also trip the starvation softlock (Shop.
		# sell_softlocks) — unrelated to what this assertion is testing
	await process_frame
	var sell_price := Shop.sell_price(sell, "piece", "pawn")
	check(sell._sell("piece", "pawn"),
		"(setup) selling a Stock pawn succeeds")
	check(sell.gold == sell_price,
		"SAFETY CATCH: sell a piece as Old Guard, Gold rises by EXACTLY the sell price " +
		"(%d) — not sell_price + full value, i.e. Hold the Line never fires on a sale" % sell_price)
	sell.queue_free()
	await process_frame

	# Safety catch 2: 'Definitely Not Russia' Patch masks the first loss each
	# Wave from EVERY on_piece_lost effect (issue 53) — Hold the Line included.
	var dnr := _boot({"army": "Old Guard", "gold": 0,
		"board": [["pawn", 0, 2, 2], ["knight", 0, 3, 2], ["rook", 1, 7, 10]],
		"wave": 1, "artefacts": ["definitely-not-russia-patch"]})
	await process_frame
	var knight_val: int = dnr.defs["knight"].value
	dnr._lose_player_piece(Vector2i(2, 2), "captured") # first loss this Wave: masked
	check(dnr.gold == 0,
		"SAFETY CATCH: 'Definitely Not Russia' Patch masks the first loss this Wave — " +
		"Hold the Line pays NO refund on it (issue 53's mask covers on_piece_lost entirely)")
	dnr._lose_player_piece(Vector2i(3, 2), "captured") # second loss: normal
	check(dnr.gold == knight_val,
		"(sanity) the SECOND loss this Wave is unmasked — Hold the Line refunds it normally")
	dnr.queue_free()
	await process_frame

	# --- Ability: gating (1 Action, once per Wave, re-arms on Wave clear) ---
	var gate := _boot({"army": "Old Guard", "wave": 1,
		"board": [["pawn", 0, 2, 2], ["pawn", 0, 2, 1], ["rook", 1, 7, 10]]})
	await process_frame
	gate.actions_left = 0
	check(not gate._family_ability_available(), "Ability gate: unavailable at 0 actions_left")
	gate.actions_left = 2 # a spare action left over, so the spend below lands
		# at 1, not 0 — 0 would auto-pass the Turn (_family_ability_confirmed's
		# own "last action" convenience), which would reset actions_left again
		# via the next Turn's _begin_player_turn before this test can inspect it
	check(gate._family_ability_available(), "Ability gate: available at >=1 actions_left")
	gate._family_ability_confirmed()
	check(gate.family_ability_used_this_wave and gate.actions_left == 1,
		"Ability activation spends exactly 1 Action (2 -> 1) and marks the Wave flag")
	check(not gate._family_ability_available(),
		"Ability gate: unavailable again once used this Wave (even with actions_left topped up)")
	gate.actions_left = 2
	check(not gate._family_ability_available(), "(still) once-per-Wave, not once-per-Turn")
	WaveLogic.queue(gate, gate.wave + 1)
	check(not gate.family_ability_used_this_wave, "Ability re-arms on Wave clear")
	gate.queue_free()
	await process_frame

	# --- Ability: Shield Wall (Old Guard) — back two rows, cap refusal ---
	var wall := _boot({"army": "Old Guard", "wave": 1,
		"board": [["pawn", 0, 1, 0], ["pawn", 0, 1, 1], ["pawn", 0, 1, 5], ["rook", 1, 7, 10]]})
	await process_frame
	wall.actions_left = 2 # a spare left over — see the "gate" test's own
		# comment on why 0 (auto-pass) would corrupt this test
	wall._family_ability_confirmed()
	check(BuffLogic.has(wall.board[Vector2i(1, 0)], "shield")
			and BuffLogic.has(wall.board[Vector2i(1, 1)], "shield"),
		"Shield Wall: every piece on the back two rows (y=0,1) gains Shield")
	check(not BuffLogic.has(wall.board[Vector2i(1, 5)], "shield"),
		"Shield Wall: a piece outside the back two rows is untouched")
	wall.queue_free()
	await process_frame

	var full_cap := _boot({"army": "Old Guard", "wave": 1,
		"board": [["pawn", 0, 1, 0], ["rook", 1, 7, 10]]})
	await process_frame
	full_cap._apply_buff(full_cap.board[Vector2i(1, 0)], "critical", 0, Vector2i(1, 0))
	full_cap._apply_buff(full_cap.board[Vector2i(1, 0)], "range", 0, Vector2i(1, 0))
	check(BuffLogic.catalogued_count(full_cap.board[Vector2i(1, 0)]) == 2, "(setup) piece is at the base Buff cap")
	full_cap.actions_left = 2 # a spare left over — see the "gate" test's comment
	full_cap._family_ability_confirmed()
	check(not BuffLogic.has(full_cap.board[Vector2i(1, 0)], "shield")
			and BuffLogic.catalogued_count(full_cap.board[Vector2i(1, 0)]) == 2,
		"Shield Wall: a piece already at Buff capacity correctly REFUSES the grant (no crash, no overflow)")
	full_cap.queue_free()
	await process_frame

	# --- Ability: Loose the Hounds (Wild Hunt) — moves free, captures still pay ---
	var hounds := _boot({"army": "Wild Hunt", "wave": 1,
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4], ["rook", 0, 7, 0]]})
	await process_frame
	hounds.actions_left = 3 # one spare left over after the capture below, so
		# the Turn never hits 0 actions_left (which would auto-pass into the
		# enemy turn — see the "gate"/"wall" tests' own comment on why that
		# risks reading a RESET actions_left instead of the spent value)
	hounds._family_ability_confirmed() # spends 1: actions_left -> 2
	check(hounds.actions_left == 2, "(setup) activating Loose the Hounds itself spends 1 Action")
	hounds._move_player(Vector2i(2, 2), Vector2i(2, 3)) # a plain MOVE, no capture
	check(hounds.actions_left == 2,
		"Loose the Hounds: a move this Turn costs no Action (actions_left unchanged)")
	hounds._move_player(Vector2i(2, 3), Vector2i(2, 4)) # a CAPTURE
	check(hounds.actions_left == 1,
		"Loose the Hounds: a capture this Turn still pays its Action")
	hounds.queue_free()
	await process_frame

	# --- Ability: Call the Banners (The Muster) — targeted, duplicates a
	# Stock entry VERBATIM (ADR-0002; Asset Recovery/Extraction precedent) ---
	var banners := _boot({"army": "Crown", "wave": 1,
		"stock": ["pawn", {"id": "ferz", "buffs": [{"key": "shield"}]}],
		"board": [["rook", 1, 7, 10]]})
	await process_frame
	banners.actions_left = 2 # a spare left over, same reasoning as the "gate" test
	check(banners._family_ability_available(), "(setup) Call the Banners is available")
	banners._begin_family_targeting()
	check(banners.family_targeting, "Call the Banners begins targeting (no confirm modal)")
	var target: Variant = banners.stock[1] # the stateful ferz entry
	banners._family_target_stock(target, false)
	check(not banners.family_targeting, "targeting resolves after the Stock tap")
	var ferz_copies: Array = banners.stock.filter(func(e) -> bool: return e is Dictionary and e.id == "ferz")
	check(ferz_copies.size() == 2, "Call the Banners: the target Stock entry now appears twice")
	ferz_copies[0].buffs.append({"key": "critical"}) # mutate one copy...
	check(ferz_copies[1].buffs.size() == 1,
		"Call the Banners: the duplicate is an INDEPENDENT copy (.duplicate(true)), " +
		"not the same Dictionary reference twice — mutating one doesn't mutate the other")
	check(banners.actions_left == 1 and banners.family_ability_used_this_wave,
		"Call the Banners spends its 1 Action (2 -> 1) and the once-per-Wave flag")
	banners.queue_free()
	await process_frame

	# tap-again-to-cancel (targeted back-out, slice 52's rule)
	var cancel := _boot({"army": "Crown", "wave": 1,
		"stock": ["pawn"], "board": [["rook", 1, 7, 10]]})
	await process_frame
	cancel.actions_left = 1
	cancel._begin_family_targeting()
	cancel._begin_family_targeting() # tap the (virtual) chip again
	check(not cancel.family_targeting and cancel.stock.size() == 1 and cancel.actions_left == 1
			and not cancel.family_ability_used_this_wave,
		"Call the Banners: cancelling FROM TARGETING costs nothing — no duplicate, no charge")
	cancel.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL FAMILY CHECKS OK")
	quit(1 if fails > 0 else 0)
