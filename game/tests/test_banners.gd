extends SceneTree
## Banner visibility pass (2026-09-22, Max: "banners for everything that is
## missing visibility for now, we will refine later"). Pins the two things the
## pass must not get wrong, asserting on `anims` contents rather than a flag:
##   - COALESCING: N fires of one cause in one frame is ONE banner with ×N
##     (a per-piece loop or a per-copy dispatch never holds the screen).
##   - The ENEMY TURN banner names a skipped / doubled turn instead of
##     announcing it as a normal one (it used to fire before the skip check).
## Plus the Gold-loss popup, the bespoke King Power's persistent ⚠ state and
## the once-per-wave first-bite gate.
## Run headless:  godot --headless --path game -s tests/test_banners.gd

const GameScript := preload("res://scripts/game.gd")
const Economy := preload("res://scripts/economy.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const Kings := preload("res://data/kings.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Shop := preload("res://scripts/shop.gd")
const SaveConfig := preload("res://scripts/save_config.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


const DEFAULT_SEED := 1


func _boot(cfg: Dictionary) -> Node2D:
	GameScript.reset_boot_defaults()
	if not cfg.has("seed"):
		cfg = cfg.duplicate()
		cfg.seed = DEFAULT_SEED
	GameScript.next_config = cfg
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _banners(g) -> Array:
	return g.anims.filter(func(a: Dictionary) -> bool: return a.kind == "banner")


func _has_banner(g, text: String) -> bool:
	return _banners(g).any(func(a: Dictionary) -> bool: return a.text == text)


func _restock_banners(g) -> Array:
	return _banners(g).filter(func(a: Dictionary) -> bool: return a.cause == "shop_restock")


func _init() -> void:
	var red := Color(1, 0, 0)

	# --- coalescing ---------------------------------------------------------
	var g := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	g.anims.clear()
	for i in 3:
		g._add_turn_fx("Annexed", red)
	check(_banners(g).size() == 1, "3 same-cause fires in one frame: ONE banner (%d)" % _banners(g).size())
	check(_has_banner(g, "Annexed ×3"), "...reading 'Annexed ×3'")
	check(g.anims.filter(func(a: Dictionary) -> bool: return a.kind == "outline").size() == 1,
		"...and one outline glow, not three")

	g._add_turn_fx("The Purge", red)
	check(_banners(g).size() == 2, "a different cause is its own banner")
	check(_banners(g)[1].slot == 1, "...stacked in the next slot")

	g.anims.clear()
	g._add_turn_fx("Total War −$10", red, "totalwar")
	g._add_turn_fx("Total War −$10", red, "totalwar")
	check(_banners(g).size() == 1 and _has_banner(g, "Total War −$10 ×2"),
		"an explicit cause coalesces under its first text")

	g.anims.clear()
	g._add_turn_fx("Annexed", red)
	g.anims[-1].t = 0.5 # a banner from an earlier frame (process advanced it)
	g._add_turn_fx("Annexed", red)
	check(_banners(g).size() == 2 and _has_banner(g, "Annexed"),
		"the same cause on a LATER frame is a fresh banner, never appended to an old one")

	# --- ENEMY TURN text ----------------------------------------------------
	check(g._enemy_turn_text({"actions": 1, "notes": []}) == "ENEMY TURN", "1 action: plain ENEMY TURN")
	check(g._enemy_turn_text({"actions": 2, "notes": []}) == "ENEMY TURN ×2", "2 actions: ×2")
	check(g._enemy_turn_text({"actions": 0, "notes": ["Y2K Patch Floppy Disk"]})
			== "ENEMY TURN — skipped (Y2K Patch Floppy Disk)", "0 actions: skipped, naming the cause")
	check(g._enemy_turn_text({"actions": 2, "notes": ["The Countless Host +1"]})
			== "ENEMY TURN ×2 (The Countless Host +1)", "a Power's extra action is named")

	g.anims.clear()
	g.skip_enemy_turns = 1
	g.state = g.State.PLAYER_TURN
	g._enemy_turn() # fire-and-forget: the banner lands before its first await
	check(_has_banner(g, "ENEMY TURN — skipped (Surprise Attack)"),
		"Surprise Attack: the skipped turn is announced as skipped")
	check(not _has_banner(g, "ENEMY TURN"), "...and NOT as a normal turn")
	await create_timer(1.5).timeout # let the coroutine finish before freeing
	g.queue_free()
	await process_frame

	var y2k := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["y2k-patch-floppy-disk"]})
	await process_frame
	WaveLogic.queue(y2k, y2k.wave + 1) # on_wave_spawn arms Y2K
	y2k.anims.clear()
	y2k.state = y2k.State.PLAYER_TURN
	y2k._enemy_turn()
	check(_has_banner(y2k, "ENEMY TURN — skipped (Y2K Patch Floppy Disk)"),
		"Y2K Patch: the zeroed turn is announced as skipped, naming the artefact")
	await create_timer(1.5).timeout
	y2k.queue_free()
	await process_frame

	# --- Gold loss popup ----------------------------------------------------
	var gl := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	gl.anims.clear()
	gl.gold = 50
	check(gl.anims.is_empty(), "a Gold GAIN pops nothing here (the HUD row pulses it)")
	gl.gold = 30
	check(gl.anims.any(func(a: Dictionary) -> bool: return a.kind == "text" and a.text == "-20"),
		"a Gold LOSS pops '-20'")

	# --- tariff charge banner uses the catalog name -------------------------
	check(Economy.ability_name("move_cost") == "Tariff on Move", "ability_name: catalog name for a key")
	gl.anims.clear()
	gl.gold = 100
	Economy.activate_king_ability_by_key(gl, "move_cost")
	gl.anims.clear()
	Economy.charge(gl, "move_cost", 7)
	check(_has_banner(gl, "Tariff on Move −$7"), "a tariff charge is bannered with its catalog name and amount")

	# --- bespoke King Power: wave-start desc, persistent ⚠, first bite ------
	gl.anims.clear()
	Kings.apply_power(gl, "xerxes_i")
	var kit: Dictionary = Kings.kit_of("xerxes_i")
	check(_has_banner(gl, str(kit.power_desc)), "wave start banners the Power's description, not just its name")
	check(Kings.bespoke_power(gl).get("power_key", "") == "host", "bespoke_power reads the live kit")
	gl._refresh()
	check(gl.hud.king_ability_button.visible and gl.hud.king_ability_button.text == "⚠2",
		"the ⚠ button counts the bespoke Power beside the Tariff in force (%s)" % gl.hud.king_ability_button.text)
	var ctx := Economy.enemy_turn_ctx(gl)
	check(ctx.actions == Tuning.enemy_actions_per_turn(gl.next_tier) + 1
			and ctx.notes == ["The Countless Host +1"],
		"Xerxes names himself in the enemy-turn ctx")
	gl.anims.clear()
	Kings.bite(gl, "first")
	Kings.bite(gl, "second")
	check(_banners(gl).size() == 1 and _has_banner(gl, "The Countless Host: first"),
		"first bite banners once per wave")
	Kings.apply_power(gl, "xerxes_i")
	gl.anims.clear()
	Kings.bite(gl, "again")
	check(_has_banner(gl, "The Countless Host: again"), "a new wave re-arms the first bite")
	Kings.apply_power(gl, "")
	gl._refresh()
	check(gl.hud.king_ability_button.text == "⚠1", "Power gone: the ⚠ button is back to the Tariff alone")
	gl.king_abilities_active.clear()
	gl._refresh()
	check(not gl.hud.king_ability_button.visible, "no Power, no Tariff: the ⚠ button hides again")
	gl.queue_free()
	await process_frame

	# --- NO-238: Shop restock banner ----------------------------------------
	var sh := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 9})
	await process_frame
	sh.anims.clear()
	WaveLogic.queue(sh, 10) # Lane A
	check(_restock_banners(sh).size() == 1 and _has_banner(sh, "SHOP RESTOCKED"),
		"Lane A restock: exactly one SHOP RESTOCKED banner (%d)" % _restock_banners(sh).size())
	sh.anims.clear()
	Shop.add_score_progress(sh, Tuning.SHOP_LANE_B_SCORE * 2) # crosses twice, rolls once
	check(_restock_banners(sh).size() == 1 and _has_banner(sh, "SHOP RESTOCKED"),
		"Lane B restock: exactly one SHOP RESTOCKED banner (%d)" % _restock_banners(sh).size())
	sh.anims.clear()
	Shop.roll(sh) # run setup / the player's own Jet Fuel restock
	check(_restock_banners(sh).is_empty(), "a bare Shop.roll (setup, Jet Fuel) is not bannered")
	var saved: Dictionary = SaveConfig.to_config(sh)
	sh.queue_free()
	await process_frame

	var rs := _boot(saved) # save restore
	await process_frame
	check(_restock_banners(rs).is_empty(), "a save restore banners no restock")
	rs.queue_free()
	await process_frame

	var op := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 4})
	await process_frame
	op.anims.clear()
	Shop.add_score_progress(op, Tuning.SHOP_LANE_B_SCORE) # before the unlock
	check(_restock_banners(op).is_empty(), "no restock banner while the Shop is still locked")
	WaveLogic.queue(op, Tuning.SHOP_UNLOCK_WAVE)
	check(_restock_banners(op).size() == 1 and _has_banner(op, "SHOP OPEN"),
		"the unlock Wave's restock reads SHOP OPEN")
	op.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL BANNER CHECKS OK")
	quit(1 if fails > 0 else 0)
