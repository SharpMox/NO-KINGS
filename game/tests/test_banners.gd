extends SceneTree
## Banner visibility pass (2026-09-22, Max: "banners for everything that is
## missing visibility for now, we will refine later"). Pins the two things the
## pass must not get wrong, asserting on `anims` contents rather than a flag:
##   - COALESCING: N fires of one cause in one frame is ONE banner with ×N
##     (a per-piece loop or a per-copy dispatch never holds the screen).
##   - The ENEMY TURN banner names a skipped / doubled turn instead of
##     announcing it as a normal one (it used to fire before the skip check).
## Plus the Gold-loss popup, the bespoke King Power's persistent ⚠ state and
## the once-per-wave first-bite gate. NO-239/NO-243: the kill feed (one line
## per capture, same-frame coalescing, 4 visible, expiry) and the Score roll-up.
## NO-243: a capture, a spawn and a merge queue their board anims
## (die / arrive / merge) only with animations on.
## Run headless:  godot --headless --path game -s tests/test_banners.gd

const GameScript := preload("res://scripts/game.gd")
const Economy := preload("res://scripts/economy.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const Kings := preload("res://data/kings.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Shop := preload("res://scripts/shop.gd")
const SaveConfig := preload("res://scripts/save_config.gd")
const MergeLogic := preload("res://scripts/merge_logic.gd")
const Rules := preload("res://scripts/rules.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")

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


func _kind(g, kind: String) -> Array:
	return g.anims.filter(func(a: Dictionary) -> bool: return a.kind == kind)


func _restock_banners(g) -> Array:
	return _banners(g).filter(func(a: Dictionary) -> bool: return a.cause == "shop_restock")


## The feed's live lines, top first (a pushed-out pill is removed at once; an
## expired one is queue_free'd, so skip those).
func _feed_texts(g) -> Array:
	var out := []
	for pill in g.hud.feed.get_children():
		if not pill.is_queued_for_deletion():
			out.append((pill.get_child(0).get_child(-1) as Label).text)
	return out


## The icon on the feed's top line, or null for a text-only line.
func _feed_icon(g) -> Texture2D:
	var tr = g.hud.feed.get_child(0).get_child(0).get_child(0)
	return tr.texture if tr is TextureRect else null


func _clear_feed(g) -> void:
	g.hud._feed_pending.clear()
	for pill in g.hud.feed.get_children():
		g.hud.feed.remove_child(pill)
		pill.queue_free()


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

	# #552: a Juche Wave closes the Shop, so its Lane-A restock rolls unbannered
	# — the Power is applied after the roll, and the banner must read the NEW
	# Wave's Power, not the previous one's.
	var ju := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 49})
	await process_frame
	ju.king_order = ["kim_jong_un"] # Wave 50 is the first King Wave (ordinal 0)
	var restocks_before: int = ju.shop_restocks
	ju.anims.clear()
	WaveLogic.queue(ju, 50) # Lane A, on Kim Jong Un's Wave
	check(Kings.power_is(ju, "juche"), "Wave 50 carries Juche")
	check(ju.shop_restocks == restocks_before + 1, "...the Lane-A restock still rolls")
	check(_restock_banners(ju).is_empty(), "...but a Juche Wave banners no restock (%d)" % _restock_banners(ju).size())
	ju.anims.clear()
	Shop.add_score_progress(ju, Tuning.SHOP_LANE_B_SCORE) # Lane B, same Wave
	check(_restock_banners(ju).is_empty(), "...nor a Lane-B restock during it")
	ju.king_order = ["kim_jong_un", "napoleon"]
	for w in range(51, 100): # to the next King Wave, a Lane-A beat after Juche
		WaveLogic.queue(ju, w)
	ju.anims.clear()
	WaveLogic.queue(ju, 100)
	check(not Kings.power_is(ju, "juche") and _has_banner(ju, "SHOP RESTOCKED"),
		"the next Wave's restock banners again once Juche has ended")
	ju.queue_free()
	await process_frame

	# --- NO-239: the kill feed ----------------------------------------------
	var kf := _boot({"board": [["queen", 0, 2, 2], ["knight", 1, 2, 3], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	await process_frame # boot-time posts flushed
	_clear_feed(kf)
	kf.anims.clear()
	kf._move_player(Vector2i(2, 2), Vector2i(2, 3))
	kf.hud._flush_feed()
	var lines := _feed_texts(kf)
	check(lines.size() == 1 and lines[0].begins_with("+") and lines[0].ends_with("captured Knight"),
		"a capture posts ONE feed line naming the victim (%s)" % [lines])
	check(_feed_icon(kf) != null and _feed_icon(kf) == kf.piece_tex("knight", Rules.ENEMY),
		"...showing the victim's (enemy) piece token")
	check(not kf.anims.any(func(a: Dictionary) -> bool: return a.kind == "text" and a.text.begins_with("+")),
		"...and no '+N' Score popup any more (the feed replaced it)")

	_clear_feed(kf)
	Economy.earn(kf, 10, "", "test gain")
	Economy.earn(kf, 10, "", "test gain")
	kf.hud._flush_feed()
	lines = _feed_texts(kf)
	check(lines == ["+%d · +$20 · test gain" % (20 * Economy.SCORE_MULTIPLIER)],
		"two same-reason gains in one frame coalesce into one line (%s)" % [lines])

	# Max, round 2: an Artefact trigger is text only, no icon and no ✦
	_clear_feed(kf)
	ArtefactHooks.feed(kf, "27-club-punch-card", 0, 0, "Piece Buff granted")
	kf.hud._flush_feed()
	check(_feed_texts(kf) == ["27 Club Punch Card: Piece Buff granted"] and _feed_icon(kf) == null,
		"an Artefact trigger posts text only (%s)" % [_feed_texts(kf)])

	_clear_feed(kf)
	for i in 6:
		kf.hud.post("e%d" % i)
	lines = _feed_texts(kf)
	check(lines == ["e5", "e4", "e3", "e2"], ">4 entries: only 4 kept, newest on top (%s)" % [lines])

	# #558: a line wider than the screen is cut with "…", amounts kept whole
	_clear_feed(kf)
	var long_reason := "captured an extraordinarily long-named piece ".repeat(8)
	kf.hud.post("+999 · +$99 · " + long_reason)
	await process_frame # let the pill's container lay it out
	await process_frame
	var pill: Control = kf.hud.feed.get_child(0)
	var fit: String = _feed_texts(kf)[0]
	check(pill.size.x <= kf.hud.feed_max_w(),
		"a long feed line fits the screen: pill %.0f <= %.0f" % [pill.size.x, kf.hud.feed_max_w()])
	check(fit.begins_with("+999 · +$99 · ") and fit.ends_with("…") and fit.length() < long_reason.length(),
		"...its reason truncated with '…', the amounts intact (%s)" % fit)
	_clear_feed(kf) # the same with a piece icon eating into the width
	kf.hud.post("+999 · +$99 · " + long_reason, kf.piece_tex("knight", Rules.ENEMY))
	await process_frame
	await process_frame
	pill = kf.hud.feed.get_child(0)
	check(pill.size.x <= kf.hud.feed_max_w() and _feed_texts(kf)[0].ends_with("…"),
		"...and still fits with a piece icon: pill %.0f <= %.0f" % [pill.size.x, kf.hud.feed_max_w()])
	check(kf.hud.FEED_FONT_SIZE % 16 == 0, "the feed font stays on Pixel Operator's 16 px grid")
	_clear_feed(kf)
	kf.hud.post("+5 · short")
	check(_feed_texts(kf) == ["+5 · short"], "a line that fits is left alone")

	await create_timer(kf.hud.FEED_LIFE_S + kf.hud.FEED_FADE_S + 0.3).timeout
	await process_frame
	check(_feed_texts(kf).is_empty(), "entries expire after ~%.1f s" % kf.hud.FEED_LIFE_S)

	# --- NO-243: the Score counter rolls up to the exact value -------------
	var before: int = kf.score
	kf.score += 1234
	kf._refresh()
	if kf.animations_on:
		check(kf.hud.score_label.text != str(kf.score), "the counter does not snap while animations are on")
	await create_timer(kf.hud.COUNT_UP_S + 0.2).timeout
	check(kf.score == before + 1234 and kf.hud.score_label.text == str(kf.score),
		"the Score counter lands on the exact final value (%s)" % kf.hud.score_label.text)

	kf.autoplay = true
	_clear_feed(kf)
	kf.hud.post("bot")
	check(_feed_texts(kf).is_empty(), "autoplay posts nothing to the feed")
	kf.autoplay = false
	kf.queue_free()
	await process_frame

	# --- NO-243: board anims queue with animations on, never with them off,
	# and the board state never waits on them --------------------------------
	for on in [true, false]:
		var bd := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 3], ["pawn", 0, 4, 2],
			["pawn", 0, 5, 2], ["pawn", 0, 6, 2], ["rook", 1, 7, 8]],
			"wave": 4, "stock": ["pawn"], "gold": 300})
		await process_frame
		bd.animations_on = on
		bd.actions_left = 5
		var tag := "anims %s: " % ("on" if on else "off")

		bd.anims.clear()
		bd._move_player(Vector2i(2, 2), Vector2i(2, 3))
		check(bd.board[Vector2i(2, 3)].id == "queen", tag + "a capture updates the board at once")
		var dies := _kind(bd, "die")
		check(dies.size() == (1 if on else 0), tag + "a capture queues %d die anim(s) (%d)"
			% [1 if on else 0, dies.size()])
		if on:
			check(dies[0].piece.id == "pawn", "...snapshotting the victim, not the attacker")

		bd.anims.clear()
		bd.pending_spawn.append({"id": "pawn"})
		bd.pending_spawn.append({"id": "knight"})
		WaveLogic.spawn_pending(bd)
		var arrives := _kind(bd, "arrive")
		check(arrives.size() == (2 if on else 0), tag + "2 spawns queue %d arrive anims (%d)"
			% [2 if on else 0, arrives.size()])
		if on:
			check(arrives[1].t < arrives[0].t, "...the second staggered after the first")
			check(bd.board.has(arrives[0].to) and bd.board.has(arrives[1].to),
				"...with both enemies already on the board")

		bd.anims.clear()
		bd.state = bd.State.PLAYER_TURN
		MergeLogic.commit_merge(bd, Vector2i(4, 2), Vector2i(5, 2))
		check(bd.board.has(Vector2i(5, 2)) and not bd.board.has(Vector2i(4, 2)),
			tag + "a merge updates the board at once")
		var merges := _kind(bd, "merge")
		check(merges.size() == (1 if on else 0), tag + "a board merge queues %d merge anim(s) (%d)"
			% [1 if on else 0, merges.size()])
		if on:
			check(merges[0].sources.size() == 2, "...sliding both board inputs")
			bd.anims.clear()
			MergeLogic.commit_merge(bd, {"id": "pawn", "cap": false, "entry": "pawn"}, Vector2i(6, 2))
			merges = _kind(bd, "merge")
			check(merges.size() == 1 and merges[0].sources.size() == 1,
				"a Stock + board merge slides only the board input")
		bd.queue_free()
		await process_frame

	print("---")
	if fails == 0:
		print("ALL BANNER CHECKS OK")
	quit(1 if fails > 0 else 0)
