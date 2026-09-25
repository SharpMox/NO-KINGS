extends SceneTree
## NO-243 S1 board animations. Every event leaves the same board state with
## animations on, off and under autoplay; only "on" queues its anims; the
## enemy-move stagger keeps turn order and swallows input; animations off and
## autoplay run the enemy's moves without waiting a frame.
## Run headless:  godot --headless --path game -s tests/test_board_anims.gd

const GameScript := preload("res://scripts/game.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const MergeLogic := preload("res://scripts/merge_logic.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")
const Rules := preload("res://scripts/rules.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Scenarios := preload("res://data/scenarios.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _boot(cfg: Dictionary) -> Node2D:
	GameScript.reset_boot_defaults()
	cfg = cfg.duplicate()
	cfg.seed = 1
	GameScript.next_config = cfg
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _kind(g, kind: String) -> Array:
	return g.anims.filter(func(a: Dictionary) -> bool: return a.kind == kind)


func _enemy_tiles(g) -> Array:
	var out := []
	for pos in g.board:
		if g.board[pos].owner == Rules.ENEMY:
			out.append(pos)
	out.sort()
	return out


func _init() -> void:
	await process_frame
	for mode in ["on", "off", "autoplay"]:
		var g := _boot({"board": [["queen", 0, 2, 1], ["pawn", 0, 5, 3], ["pawn", 0, 6, 3],
			["bishop", 1, 7, 6]], # the bishop keeps the board uncleared, so nothing auto-passes
			"wave": 4, "gold": 300})
		await process_frame
		g.animations_on = mode != "off"
		g.autoplay = mode == "autoplay"
		g.actions_left = 5
		var on: bool = mode == "on"
		var n := func(k: int) -> int: return k if on else 0
		var tag := "anims %s: " % mode

		# 10: Rank Up
		g.anims.clear()
		MergeLogic.commit_merge(g, Vector2i(5, 3), Vector2i(6, 3))
		check(g.board.has(Vector2i(6, 3)) and not g.board.has(Vector2i(5, 3))
			and g.board[Vector2i(6, 3)].id != "pawn", tag + "a Rank Up promotes on the board at once")
		check(_kind(g, "rankup").size() == n.call(1), tag + "...and queues %d rankup" % n.call(1))
		if on:
			check(_kind(g, "rankup")[0].t < 0.0, "...which waits for the merge anim")

		# 13: spawn drop-in + red tile flash, staggered
		g.anims.clear()
		g.pending_spawn.append({"id": "pawn"})
		g.pending_spawn.append({"id": "knight"})
		WaveLogic.spawn_pending(g)
		check(_enemy_tiles(g).size() == 3, tag + "2 spawns are on the board at once")
		var flashes := _kind(g, "flash")
		check(flashes.size() == n.call(2), tag + "...with %d tile flashes" % n.call(2))
		if on:
			check(flashes[1].t < flashes[0].t, "...the second flash staggered after the first")

		# 15: King arrival
		g.anims.clear()
		g.pending_spawn.append({"id": "king"})
		WaveLogic.spawn_pending(g)
		var king := Rules.find_king(g.board, Rules.ENEMY)
		check(king.y == Tuning.SPAWN_ROW, tag + "the King lands on the spawn row at once")
		check(_kind(g, "shake").size() == n.call(1), tag + "...with %d shake" % n.call(1))
		var gold_pops := _kind(g, "pop").filter(func(a: Dictionary) -> bool: return a.has("color"))
		check(gold_pops.size() == n.call(1), tag + "...and %d gold crown ring" % n.call(1))

		# 16: King checkmated (the recurring-King path: no win screen)
		g.anims.clear()
		g.kings_defeated = 1
		g._king_down()
		check(Rules.find_king(g.board, Rules.ENEMY).x < 0 and not g.win_open,
			tag + "a fallen King leaves the board at once")
		var dies := _kind(g, "die")
		check(dies.size() == n.call(1) and (not on or dies[0].get("gold", false)),
			tag + "...shattering gold (%d)" % dies.size())
		check(_kind(g, "shake").size() == n.call(1), tag + "...with %d shake" % n.call(1))

		# 14: a spawn crushes a friendly piece
		g.anims.clear()
		for x in Tuning.BOARD_W:
			g.board[Vector2i(x, Tuning.SPAWN_ROW)] = {"id": "pawn", "owner": Rules.PLAYER}
		g.pending_spawn.append({"id": "rook"})
		WaveLogic.spawn_pending(g)
		var crushed := _kind(g, "die")
		var rooks: Array = g.board.values().filter(func(p: Dictionary) -> bool: return p.id == "rook")
		check(rooks.size() == 1 and rooks[0].owner == Rules.ENEMY, tag + "the spawn replaces the friendly at once")
		check(crushed.size() == n.call(1) and (not on or crushed[0].piece.owner == Rules.PLAYER),
			tag + "...which dies under it (%d)" % crushed.size())
		for x in Tuning.BOARD_W:
			g.board.erase(Vector2i(x, Tuning.SPAWN_ROW))

		# 4: an explosion
		g.anims.clear()
		g.board[Vector2i(4, 6)] = {"id": "pawn", "owner": Rules.ENEMY}
		g._detonate(Vector2i(4, 6))
		check(not g.board.has(Vector2i(4, 6)), tag + "a detonation destroys at once")
		check(_kind(g, "die").size() == n.call(1) and _kind(g, "shake").size() == n.call(1),
			tag + "...with %d burst and shake" % n.call(1))

		# 19: a buff badge pops in, then fades when consumed
		var q := Vector2i(2, 1)
		g.anims.clear()
		g._apply_buff(g.board[q], "shield", 0, q)
		check(BuffLogic.has(g.board[q], "shield"), tag + "a Buff applies at once")
		var badges := _kind(g, "badge")
		check(badges.size() == n.call(1) and (not on or not badges[0].gone), tag + "...popping %d badge" % n.call(1))
		g.anims.clear()
		g._consume_buff(q, "shield")
		check(not BuffLogic.has(g.board[q], "shield"), tag + "a consumed Buff goes at once")
		badges = _kind(g, "badge")
		check(badges.size() == n.call(1) and (not on or badges[0].gone), tag + "...fading %d badge" % n.call(1))

		if on: # every anim ends, and the shake leaves the board where it was
			g.state = g.State.ENEMY_TURN # no clock, no bot
			g.anims.append({"kind": "shake", "t": 0.5, "dur": GameScript.SHAKE_TIME})
			check(g._shake_offset() != Vector2.ZERO, "a live shake offsets the board")
			g._process(5.0)
			check(g.anims.is_empty() and g.position == Vector2.ZERO, "...and it settles back to ZERO")
		g.autoplay = false # the bot must not step on the node's last frame
		g.queue_free()
		await process_frame

	# --- 2: enemy moves one by one -------------------------------------------
	var e := _boot({"board": [["queen", 0, 0, 0], ["pawn", 1, 1, 9], ["pawn", 1, 5, 9]], "wave": 4})
	await process_frame
	e.animations_on = true
	e.state = e.State.ENEMY_TURN
	var before := _enemy_tiles(e)
	e._run_enemy_actions(2) # fire-and-forget: it waits a beat per move
	check(_enemy_tiles(e) == before, "anims on: no enemy moves before its beat")
	check(_kind(e, "flash").size() == 1, "...while the mover's tile flashes")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = e._tile_px(Vector2i(0, 0)) + Vector2(e.tile, e.tile) / 2
	e._unhandled_input(click)
	check(e.selected.x < 0, "a tap during the enemy's moves selects nothing")
	var t0 := Time.get_ticks_msec()
	var seen := [before]
	var times := []
	while times.size() < 2 and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
		var now := _enemy_tiles(e)
		if now != seen[-1]:
			seen.append(now)
			times.append(Time.get_ticks_msec())
			check(_kind(e, "move").size() == 1, "move %d slides alone" % times.size())
	check(times.size() == 2, "both enemy moves land (%d)" % times.size())
	if times.size() == 2:
		check(times[1] - times[0] >= int(GameScript.ENEMY_MOVE_GAP * 1000 * 0.9),
			"...a beat apart (%d ms)" % (times[1] - times[0]))
	e.anims.clear()
	e._enemy_turn()
	t0 = Time.get_ticks_msec()
	while e.state != e.State.PLAYER_TURN and Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	check(e.state == e.State.PLAYER_TURN, "an animated enemy turn hands back to the player (state=%d)" % e.state)
	e.queue_free()
	await process_frame

	for mode in ["off", "autoplay"]:
		var f := _boot({"board": [["queen", 0, 0, 0], ["pawn", 1, 1, 9], ["pawn", 1, 5, 9]], "wave": 4})
		await process_frame
		f.animations_on = mode != "off"
		f.autoplay = mode == "autoplay"
		f.state = f.State.ENEMY_TURN
		var b := _enemy_tiles(f)
		var frame := Engine.get_process_frames()
		await f._run_enemy_actions(2)
		check(Engine.get_process_frames() == frame and _enemy_tiles(f) != b and f.anims.is_empty(),
			"anims %s: the enemy's moves resolve without waiting a frame, queueing nothing" % mode)
		f.autoplay = false
		f.queue_free()
		await process_frame

	# --- the --show-screen anim:<name> captures (tools/capture.md) ---------------

	var sc: Dictionary = Scenarios.all()[Scenarios.find("Movement & drag")].cfg
	for anim in ["spawn", "crush", "king-arrive", "king-fall", "rankup", "enemy-moves", "explode", "badge"]:
		var c := _boot(sc)
		await process_frame
		var enemies := _enemy_tiles(c).size()
		await c._debug_show_screen("anim:" + anim, PackedStringArray())
		var ok := true
		match anim:
			"spawn": ok = _enemy_tiles(c).size() == enemies + 3
			"crush", "king-arrive": ok = _enemy_tiles(c).size() == enemies + 1
			"king-fall": ok = Rules.find_king(c.board, Rules.ENEMY).x < 0 and not c.win_open
			"rankup": ok = c.board.has(Vector2i(6, 3)) and not c.board.has(Vector2i(5, 3))
			"enemy-moves": ok = c.state == c.State.PLAYER_TURN and _enemy_tiles(c).size() == 3
			"explode": ok = _enemy_tiles(c).is_empty()
			"badge": ok = not BuffLogic.has(c.board[Vector2i(2, 1)], "shield")
		check(ok and c.position == Vector2.ZERO, "capture anim:%s plays out to its end state" % anim)
		c.queue_free()
		await process_frame

	print("---")
	if fails == 0:
		print("ALL BOARD ANIM CHECKS OK")
	else:
		print("%d FAILED" % fails)
	quit(1 if fails > 0 else 0)
