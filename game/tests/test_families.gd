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
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")

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
	check(Families.CATALOG.size() == 6, "six Families: issue 67's three seeds + issue 68's three more")
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

	# --- Power: Blood in the Air (Wild Hunt) stacks ADDITIVELY with an
	# Action-refund Artefact — two refunds, not deduped (issue 67). Repointed
	# (issue 69) at Stargate Divination Crystal after the original
	# first_capture_extra core Artefact was removed: same "first Capture of
	# the Turn refunds its Action" shape, so the invariant this test proves
	# — Families.blood_in_the_air's own independent check at the same
	# capture_score call site (economy.gd) stacks rather than dedupes with a
	# REGISTRY-dispatched Artefact doing the identical thing — survives
	# unchanged. ---
	var blood := _boot({"army": "Wild Hunt", "wave": 1,
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 3]],
		"artefacts": ["stargate-divination-crystal"]})
	await process_frame
	var actions_max_before: int = blood.actions_max
	blood._move_player(Vector2i(2, 2), Vector2i(2, 3)) # the Turn's first action: a capture
	check(blood.actions_max == actions_max_before + 2,
		"Blood in the Air + Stargate Divination Crystal: BOTH refund the Turn's first capture " +
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

	# ================= issue 68: three more Families =================

	# --- kit application on a fresh boot ---
	var syndicate := _boot_fresh("Syndicate")
	await process_frame
	check(syndicate.gold == Tuning.FAMILY_BASELINE_GOLD * 3, "The Syndicate: TRIPLE baseline Gold")
	check(syndicate.items.is_empty(), "The Syndicate: no starting Items")
	check(syndicate.stock == Tuning.ARMIES["Syndicate"], "The Syndicate: the thin 6-pawn + knight kit")
	syndicate.queue_free()
	await process_frame

	var cult := _boot_fresh("Cult")
	await process_frame
	check(cult.gold == Tuning.FAMILY_BASELINE_GOLD, "The Cult: baseline Gold")
	check(cult.items.size() == 1 and cult.items[0].key == "buff_box", "The Cult: 1 Buff Box item")
	check(cult.stock == Tuning.ARMIES["Cult"], "The Cult: \"standard stock\" (Crown's own classic-chess kit)")
	check(cult.artefacts.size() == 2, "The Cult: 2 random Artefacts granted at run start")
	cult.queue_free()
	await process_frame

	var horde := _boot_fresh("Horde")
	await process_frame
	check(horde.gold == Tuning.FAMILY_BASELINE_GOLD, "The Horde: baseline Gold")
	check(horde.items.is_empty(), "The Horde: no starting Items")
	check(horde.stock.size() == 14 and horde.stock.all(func(id: String) -> bool: return id == "pawn"),
		"The Horde: 14 pawns, no majors")
	horde.queue_free()
	await process_frame

	# --- Power: Insider Rates (The Syndicate) — Shop buy -25%, sell +25%,
	# Captured -> Stock conversion UNCHANGED (issue 68's explicit safety catch:
	# conversion is not a Shop purchase, and discounting it would reopen the
	# convert/sell arbitrage SELL_RATE's own header (tuning.gd) closed) ---
	var rates := _boot({"army": "Syndicate", "gold": 1000, "wave": 1,
		"captured": ["pawn"], "board": [["pawn", 0, 1, 0], ["rook", 1, 7, 10]]})
	await process_frame
	var syn_pawn_value: int = rates.defs["pawn"].value
	var piece_slot := {"kind": "piece", "key": "pawn", "sold": false}
	check(Shop.price(rates, piece_slot) == maxi(roundi(syn_pawn_value * 0.75), 0),
		"Insider Rates: Shop buy price is the pawn's value x0.75")
	check(Shop.sell_payout(rates, "piece", "pawn") == floori(syn_pawn_value * Tuning.SELL_RATE * 1.25),
		"Insider Rates: an actual sell payout is 50% x1.25 = 62.5% of value, floored")
	var flat_conversion := floori(syn_pawn_value * Tuning.SELL_RATE)
	check(Shop.sell_price(rates, "captured", "pawn") == flat_conversion,
		"REQUIRED ASSERTION: the Captured -> Stock conversion rate stays the flat 50% under " +
		"Insider Rates — it is not a Shop purchase, and discounting it would reopen the " +
		"convert/sell arbitrage that equal rates deliberately closed")
	var conv_gold_before: int = rates.gold
	check(rates._convert_captured("pawn"), "(setup) converting the captured pawn succeeds")
	check(rates.gold == conv_gold_before - flat_conversion,
		"the ACTUAL Gold spent converting matches the unmodified 50% rate, not the discounted 62.5%")
	rates.queue_free()
	await process_frame

	var no_rates := _boot({"army": "Crown", "wave": 1, "board": [["rook", 1, 7, 10]]})
	await process_frame
	check(Shop.price(no_rates, piece_slot) == syn_pawn_value
			and Shop.sell_payout(no_rates, "piece", "pawn") == floori(syn_pawn_value * Tuning.SELL_RATE),
		"(sanity) Insider Rates is scoped to the Syndicate — a non-Syndicate Family pays/receives base rates")
	no_rates.queue_free()
	await process_frame

	# --- Ability: Hostile Takeover (The Syndicate) — targeted at the BOARD
	# (Bovine Tractor Beam's flow, not Call the Banners' Stock-tap one) ---
	var strip := _boot({"army": "Syndicate", "gold": 1000, "wave": 1,
		"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 3, {"buffs": [{"key": "shield"}]}]]})
	await process_frame
	strip.actions_left = 2
	var pv: int = strip.defs["pawn"].value
	var gold_before: int = strip.gold
	var score_before: int = strip.score
	var wcc_before: int = strip.wave_capture_count
	var tcc_before: int = strip.turn_capture_count
	var rcc_before: int = strip.run_capture_count
	strip._begin_family_board_targeting()
	check(strip.family_board_targeting and strip.family_board_targets.has(Vector2i(3, 3))
			and strip.hud.drawer_open == "",
		"Hostile Takeover stages targeting on the BOARD (drawer hands back, same as Bovine) — " +
		"the buffed enemy pawn is a valid, affordable target")
	strip._family_board_target_click(Vector2i(3, 3))
	check(not strip.board.has(Vector2i(3, 3)), "Hostile Takeover: the piece leaves the board")
	check(strip.stock.has("pawn") and typeof(strip.stock[strip.stock.find("pawn")]) == TYPE_STRING,
		"Hostile Takeover: the piece joins Stock as a BARE id — state (its Shield buff) stripped, " +
		"you bought the soldier, not their buffs")
	check(strip.gold == gold_before - pv * 2,
		"Hostile Takeover: pays exactly 200%% of the target's value (%d)" % (pv * 2))
	check(strip.score == score_before and strip.wave_capture_count == wcc_before
			and strip.turn_capture_count == tcc_before and strip.run_capture_count == rcc_before,
		"REQUIRED ASSERTION: Hostile Takeover is a PURCHASE, not a capture — Score and every " +
		"capture ledger (wave/turn/run capture counts) are completely unchanged; no on_capture " +
		"dispatch, no Gold reward")
	check(strip.actions_left == 1 and strip.family_ability_used_this_wave,
		"Hostile Takeover spends its 1 Action and the once-per-Wave flag")
	strip.queue_free()
	await process_frame

	# King exclusion (Air Strike/Sniper precedent)
	var king_only := _boot({"army": "Syndicate", "gold": 1000, "wave": 1,
		"board": [["queen", 0, 2, 2], ["king", 1, 7, 10]]})
	await process_frame
	check(king_only._affordable_takeover_targets().is_empty(),
		"Hostile Takeover: the King is NEVER a valid target (Air Strike/Sniper precedent)")
	check(not king_only._family_ability_available(),
		"(sanity) with only the King on the enemy side, the Ability is correctly unavailable")
	king_only.queue_free()
	await process_frame

	# affordability exclusion
	var poor := _boot({"army": "Syndicate", "gold": 1, "wave": 1,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]]})
	await process_frame
	check(poor._affordable_takeover_targets().is_empty(),
		"Hostile Takeover: an enemy piece the player can't afford at 200% is excluded from targeting")
	poor.queue_free()
	await process_frame

	# tap-again-to-cancel (a cancelled activation costs nothing)
	var cancel_takeover := _boot({"army": "Syndicate", "gold": 1000, "wave": 1,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]]})
	await process_frame
	cancel_takeover.actions_left = 1
	var gold_before2: int = cancel_takeover.gold
	cancel_takeover._begin_family_board_targeting()
	cancel_takeover._begin_family_board_targeting() # tap the (virtual) chip again
	check(not cancel_takeover.family_board_targeting and cancel_takeover.board.has(Vector2i(7, 10))
			and cancel_takeover.gold == gold_before2 and cancel_takeover.actions_left == 1
			and not cancel_takeover.family_ability_used_this_wave,
		"REQUIRED ASSERTION: Hostile Takeover cancelled FROM TARGETING costs nothing — " +
		"no purchase, no Gold spent, no Action, no Wave charge")
	cancel_takeover.queue_free()
	await process_frame

	# --- Power: Communion (The Cult) — Piece Buff cap 3 (base 2 +1), and
	# additive stacking with Abduction Probe to cap 4 ---
	var comm_only := _boot({"army": "Cult", "wave": 1, "board": [["pawn", 0, 1, 0], ["rook", 1, 7, 10]]})
	await process_frame
	var comm_piece: Dictionary = comm_only.board[Vector2i(1, 0)]
	for i in 3:
		comm_only._apply_buff(comm_piece, "critical", 0, Vector2i(1, 0))
	check(BuffLogic.catalogued_count(comm_piece) == 3, "Communion alone: cap is 3 (base 2 + 1) — the 3rd grant lands")
	comm_only._apply_buff(comm_piece, "range", 0, Vector2i(1, 0))
	check(BuffLogic.catalogued_count(comm_piece) == 3,
		"a 4th grant at Communion's own cap (3, no Abduction Probe) correctly REFUSES")
	comm_only.queue_free()
	await process_frame

	var comm_probe := _boot({"army": "Cult", "wave": 1, "board": [["pawn", 0, 1, 0], ["rook", 1, 7, 10]],
		"artefacts": ["abduction-probe"]})
	await process_frame
	var stacked_piece: Dictionary = comm_probe.board[Vector2i(1, 0)]
	for i in 4:
		comm_probe._apply_buff(stacked_piece, "critical", 0, Vector2i(1, 0))
	check(BuffLogic.catalogued_count(stacked_piece) == 4,
		"REQUIRED ASSERTION: Communion (+1) and Abduction Probe (+1) stack ADDITIVELY off the " +
		"base cap of 2 -> 4, NOT deduped — the 4th grant lands")
	comm_probe._apply_buff(stacked_piece, "range", 0, Vector2i(1, 0)) # a 5th: must be refused
	check(BuffLogic.catalogued_count(stacked_piece) == 4,
		"a 5th grant at the stacked cap (4) correctly REFUSES, same cap-refusal shape as issue 53/67's own tests")
	comm_probe.queue_free()
	await process_frame

	# --- Ability: Ritual (The Cult) — targeted at the BOARD, safe pool only ---
	var safe_probe := RandomNumberGenerator.new()
	var saw_slow := false
	for i in 300:
		safe_probe.seed = i
		if ArtefactHooks._random_buff_key(safe_probe) == "slow":
			saw_slow = true
			break
	check(not saw_slow,
		"Ritual's underlying pick (ArtefactHooks._random_buff_key, the SAFE pool) never returns " +
		"the self_harming Slow buff, across 300 seeds")

	var ritual := _boot({"army": "Cult", "wave": 1, "board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]]})
	await process_frame
	ritual.actions_left = 2
	ritual._begin_family_board_targeting()
	check(ritual.family_board_targeting and ritual.family_board_targets == [Vector2i(2, 2)]
			and ritual.hud.drawer_open == "",
		"Ritual stages targeting on the BOARD — only the player's own piece is a valid target")
	ritual._family_board_target_click(Vector2i(2, 2))
	check(BuffLogic.catalogued_count(ritual.board[Vector2i(2, 2)]) == 1,
		"Ritual: the target gains exactly one random Buff")
	check(ritual.actions_left == 1 and ritual.family_ability_used_this_wave,
		"Ritual spends its 1 Action and the once-per-Wave flag")
	ritual.queue_free()
	await process_frame

	# tap-again-to-cancel
	var cancel_ritual := _boot({"army": "Cult", "wave": 1, "board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]]})
	await process_frame
	cancel_ritual.actions_left = 1
	cancel_ritual._begin_family_board_targeting()
	cancel_ritual._begin_family_board_targeting() # tap the (virtual) chip again
	check(not cancel_ritual.family_board_targeting
			and BuffLogic.catalogued_count(cancel_ritual.board[Vector2i(2, 2)]) == 0
			and cancel_ritual.actions_left == 1 and not cancel_ritual.family_ability_used_this_wave,
		"Ritual: cancelling FROM TARGETING costs nothing — no Buff granted, no Action, no Wave charge")
	cancel_ritual.queue_free()
	await process_frame

	# --- Power: Endless Ranks (The Horde) — pawn deploys cost no Gold ---
	var horde_deploy := _boot({"army": "Horde", "gold": 50, "wave": 1,
		"stock": ["pawn"], "board": [["rook", 1, 7, 10]]})
	await process_frame
	horde_deploy.actions_left = 2
	var gold_before3: int = horde_deploy.gold
	horde_deploy._place("pawn", Vector2i(2, 0))
	check(horde_deploy.gold == gold_before3, "Endless Ranks: deploying a pawn as Horde costs no Gold")
	horde_deploy.queue_free()
	await process_frame

	var horde_major := _boot({"army": "Horde", "gold": 50, "wave": 1,
		"stock": ["knight"], "board": [["rook", 1, 7, 10]]})
	await process_frame
	horde_major.actions_left = 2
	var major_cost := Economy.deploy_cost(horde_major)
	var gold_before4: int = horde_major.gold
	horde_major._place("knight", Vector2i(2, 0))
	check(horde_major.gold == gold_before4 - major_cost,
		"Endless Ranks is scoped to PAWNS only — a non-pawn deploy still pays even as Horde")
	horde_major.queue_free()
	await process_frame

	var crown_deploy := _boot({"army": "Crown", "gold": 50, "wave": 1,
		"stock": ["pawn"], "board": [["rook", 1, 7, 10]]})
	await process_frame
	crown_deploy.actions_left = 2
	var pawn_cost := Economy.deploy_cost(crown_deploy)
	var gold_before5: int = crown_deploy.gold
	crown_deploy._place("pawn", Vector2i(2, 0))
	check(crown_deploy.gold == gold_before5 - pawn_cost,
		"(sanity) Endless Ranks is scoped to the Horde — a non-Horde Family still pays for a pawn deploy")
	crown_deploy.queue_free()
	await process_frame

	# --- Ability: Conscription (The Horde) — untargeted, confirm modal ---
	var consc := _boot({"army": "Horde", "wave": 1, "board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]]})
	await process_frame
	consc.actions_left = 2
	consc._family_ability_confirmed()
	check(consc.stock.size() == 2 and consc.stock.count("pawn") == 2,
		"Conscription: adds exactly 2 pawns to Stock, as bare ids")
	check(consc.actions_left == 1 and consc.family_ability_used_this_wave,
		"Conscription spends its 1 Action and the once-per-Wave flag")
	consc.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL FAMILY CHECKS OK")
	quit(1 if fails > 0 else 0)
