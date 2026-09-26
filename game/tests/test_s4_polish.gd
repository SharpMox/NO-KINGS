extends SceneTree
## NO-243 S4 polish (audit rows 1, 12, 17, 18, 21-23, 27, 29, 36, 38, 40, 41,
## 50-52, 57). For each: the state after it is the state the old snap left,
## animations off and autoplay stay instant (nothing queued, no tween), and
## input keeps working while it plays. The Main Menu pushes and the prompt
## fade (rows 63-65) are in test_scene_fade.gd, beside the scene fade.
## Run headless:  godot --headless --path game -s tests/test_s4_polish.gd

const GameScript := preload("res://scripts/game.gd")
const Rules := preload("res://scripts/rules.gd")
const Kings := preload("res://data/kings.gd")
const UiAnim := preload("res://scripts/ui_anim.gd")

## The kinds S4 adds to the board's anim queue.
const S4_KINDS := ["land", "spent", "flip", "hint", "zone", "ripple", "dome"]

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


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _running(hud, key: String) -> bool:
	var tw: Tween = hud._hud_tweens.get(key)
	return tw != null and tw.is_valid() and tw.is_running()


func _ghosts(g) -> int:
	return g.hud.get_children().filter(func(c: Node) -> bool:
		return c.has_meta(UiAnim.GHOST) and not c.is_queued_for_deletion()).size()


func _init() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: test_s4_polish still running after 120s")
		quit(1))
	await process_frame
	for mode in ["on", "off", "autoplay"]:
		var g := _boot({"board": [["rook", 0, 3, 3], ["sergeant", 0, 1, 1], ["pawn", 0, 5, 1],
			["king", 1, 4, 10], ["bishop", 1, 7, 6]], # the bishop keeps the board uncleared
			"stock": ["pawn", "knight"], "wave": 4, "gold": 300})
		await process_frame
		g.animations_on = mode != "off"
		g.autoplay = mode == "autoplay"
		# the bot must not play the waits below away: autoplay here only
		# means "the flag every gate reads", so the Game's _process is off
		g.set_process(mode != "autoplay")
		g.actions_left = 5
		var on: bool = mode == "on"
		var n := func(k: int) -> int: return k if on else 0
		var tag := "s4 %s: " % mode
		var hud = g.hud

		# rows 1/29: a move lands with a squash, then the piece greys out
		g.anims.clear()
		g._move_player(Vector2i(3, 3), Vector2i(3, 6))
		check(g.board.has(Vector2i(3, 6)) and g.board[Vector2i(3, 6)].id == "rook"
			and not g.board.has(Vector2i(3, 3)) and g.moved_this_turn.has(Vector2i(3, 6)),
			tag + "1: the move lands on the board at once, marked spent")
		check(_kind(g, "land").size() == n.call(1) and _kind(g, "spent").size() == n.call(1),
			tag + "1/29: queues %d landing squash and %d grey-out" % [n.call(1), n.call(1)])
		# input during it: a tap still selects
		g._on_tile_clicked(Vector2i(5, 1))
		check(g.selected == Vector2i(5, 1), tag + "a tap mid-landing still selects")
		# row 21: that selection's hints fade in
		check(_kind(g, "hint").size() == n.call(1) and (g._fade_of("hint") < 1.0) == on,
			tag + "21: a new selection queues %d hint fade-in" % n.call(1))
		g._clear_selection()

		# row 12: Invert flips the token
		g.anims.clear()
		g._item_apply({"key": "invert", "tier": "Tactical"}, Vector2i(-1, -1), Vector2i(1, 1))
		check(g.board[Vector2i(1, 1)].id == "inv-sergeant", tag + "12: Invert swaps the id at once")
		check(_kind(g, "flip").size() == n.call(1)
			and (not on or _kind(g, "flip")[0].before.id == "sergeant"),
			tag + "12: queues %d flip, from the piece as it was" % n.call(1))

		# row 18: Iron Dome refuses the King's fall with a shimmer on his tile
		g.anims.clear()
		g.king_power_id = "benjamin_netanyahu"
		check(not g._king_down() and g.board.has(Vector2i(4, 10)),
			tag + "18: Iron Dome holds, the King stays")
		check(_kind(g, "dome").size() == n.call(1)
			and (not on or _kind(g, "dome")[0].at == Vector2i(4, 10)),
			tag + "18: queues %d dome shimmer, on the King" % n.call(1))
		g.king_power_id = ""

		# row 22: arming a Stock piece ripples the deploy targets in
		g.anims.clear()
		g.placing_id = "pawn"
		check(_kind(g, "ripple").size() == n.call(1), tag + "22: arming queues %d ripple" % n.call(1))
		check(not g._deploy_highlight_tiles().is_empty(), tag + "22: the deploy targets are there at once")
		check(GameScript._ripple_k(0.0, 0, Vector2i(0, 1)) == 0.0
			and GameScript._ripple_k(1.0, 1, Vector2i(0, 1)) == 1.0
			and GameScript._ripple_k(0.5, 0, Vector2i(0, 1)) > GameScript._ripple_k(0.5, 1, Vector2i(0, 1)),
			tag + "22: the bottom row ripples in first, and every row ends fully in")
		g.placing_id = ""

		# row 23: an armed Item's zone fades in
		g.anims.clear()
		g.item_active = 0
		check(_kind(g, "zone").size() == n.call(1), tag + "23: arming an Item queues %d zone fade" % n.call(1))
		g.item_active = -1

		# row 27: the King-wave banner is the heavy one
		g.anims.clear()
		g._add_turn_fx("KING WAVE: Test", Color.GOLD, "", true)
		var banners := _kind(g, "banner")
		check(banners.size() == n.call(1) and (not on or (banners[0].get("heavy", false)
			and banners[0].dur == GameScript.HEAVY_BANNER_TIME and _kind(g, "shake").size() == 1)),
			tag + "27: a King wave queues %d heavy banner (longer, with a shake)" % n.call(1))

		# every board anim plays out and leaves nothing behind
		if on:
			await _wait(0.8)
			var left: Array = g.anims.filter(func(a: Dictionary) -> bool: return a.kind in S4_KINDS)
			check(left.is_empty(), tag + "the S4 board anims all finish (left %s)"
				% str(left.map(func(a: Dictionary) -> String: return a.kind)))
			check(g._fade_of("hint") == 1.0 and g._fade_of("zone") == 1.0 and g._fade_of("ripple") == 1.0,
				tag + "...and every overlay rests fully drawn")

		# row 36: PASS / START cross-fade
		g.state = GameScript.State.SETUP
		hud.refresh()
		g.state = GameScript.State.PLAYER_TURN
		hud.refresh()
		check(_running(hud, "pass_face") == on and (hud.pass_button.modulate.a < 1.0) == on,
			tag + "36: START -> PASS %s" % ("cross-fades" if on else "snaps"))
		check(hud.pass_label.text == "PASS" or hud.pass_label.text == "MUST ACT",
			tag + "36: the new face is set at once")
		# row 17: a King Power biting flashes the ⚠ toggle
		g.king_power_bitten = false
		Kings.bite(g, "test")
		check(_running(hud, "warn") == on, tag + "17: a bite %s the ⚠ toggle" % ("pulses" if on else "leaves"))
		# row 38: the band rises out of the deck on open; the close is instant
		hud.collapse_army_band()
		hud.army_band_reopen.pressed.emit()
		check(hud.army_band.visible and hud.army_band_open, tag + "38: the band opens at once")
		check((hud.army_band.position.y > hud._band_rest_y) == on,
			tag + "38: ...%s" % ("from below, sliding up" if on else "at rest"))
		# row 40: the tooltip fades in
		hud.show_tip("s4", "tip", Rect2(Vector2(40, 300), Vector2(120, 40)))
		check(hud.tip_panel.visible and (hud.tip_panel.modulate.a < 1.0) == on,
			tag + "40: the tip is up at once, %s" % ("fading in" if on else "opaque"))
		# row 41: the Shop's first stock glows its button
		var rings_before: int = hud.shop_button.get_children().filter(func(c: Node) -> bool: return c is Panel).size()
		hud.glow_shop()
		var rings: int = hud.shop_button.get_children().filter(func(c: Node) -> bool: return c is Panel).size()
		check(rings - rings_before == n.call(1), tag + "41: the Shop unlock adds %d glow ring" % n.call(1))
		# row 57: a Stock stack lifts on press; the drag still starts
		if hud.drawer_open != "stock":
			g._set_drawer("stock")
		await process_frame
		await process_frame
		var stacks: Array = g.pool_box.filter(func(b: Node) -> bool:
			return b is Button and b.has_meta("id") and not b.is_queued_for_deletion())
		check(not stacks.is_empty(), tag + "57: the Stock drawer has a stack")
		if not stacks.is_empty():
			var stack: Button = stacks[0]
			stack.button_down.emit()
			check(g.pool_drag_id != "", tag + "57: the press still starts the drag")
			await _wait(0.15)
			check((stack.scale.x > 1.05) == on, tag + "57: the stack is %s" % ("lifted" if on else "at rest"))
			stack.button_up.emit()
			check(stack.scale == Vector2.ONE, tag + "57: release settles it at once")
			g.pool_drag_id = ""
		g._set_drawer("")
		# row 52: a sale floats its coin to Gold
		var ghosts_before := _ghosts(g)
		var gold_before: int = g.gold
		g._sell_confirmed("piece", g.stock[0], func() -> void: pass)
		check(g.gold > gold_before, tag + "52: the sale pays at once")
		check((_ghosts(g) - ghosts_before >= 1) == on,
			tag + "52: %s" % ("the coin floats to Gold" if on else "no coin floats"))
		# row 50: reinforcements drop in; Dismiss flies them to Stock
		g.modals.show_reinforce(["pawn", "knight"])
		var mass: Array = g.modals.reinforce_panel.find_children("*", "TextureRect", true, false)
		check(mass.size() == 2, tag + "50: two pieces in the mass")
		check(mass.size() > 0 and (mass[0].modulate.a < 1.0) == on,
			tag + "50: ...%s" % ("dropping in" if on else "already in place"))
		# row 51: the King Abilities list scales in, and Close works mid-way
		g.modals.show_king_abilities()
		var kpanel: Control = g.modals.king_ability_panel
		check(kpanel.visible and (kpanel.modulate.a < 1.0) == on,
			tag + "51: King Abilities %s" % ("fades and scales in" if on else "opens at rest"))
		if on:
			await _wait(0.6)
			check(hud.pass_button.modulate.a == 1.0 and not _running(hud, "pass_face"),
				tag + "36: the cross-fade ends opaque")
			check(hud.army_band_reopen.self_modulate == Color.WHITE and not _running(hud, "warn"),
				tag + "17: the pulse ends at rest")
			check(is_equal_approx(hud.army_band.position.y, hud._band_rest_y),
				tag + "38: the band ends at rest (%.1f vs %.1f)" % [hud.army_band.position.y, hud._band_rest_y])
			check(hud.tip_panel.modulate.a == 1.0, tag + "40: the tip ends opaque")
			check(mass.all(func(p: TextureRect) -> bool: return p.modulate.a == 1.0),
				tag + "50: every piece has landed")
			check(kpanel.modulate.a == 1.0, tag + "51: the list ends opaque")
			check(hud.shop_button.get_children().filter(func(c: Node) -> bool:
				return c is Panel and not c.is_queued_for_deletion()).size() == rings_before,
				tag + "41: the glow ring is gone")
		for b in g.modals.king_ability_panel.find_children("*", "Button", true, false):
			if (b as Button).text == "Close":
				(b as Button).pressed.emit()
		check(not kpanel.visible, tag + "51: Close closes it")
		ghosts_before = _ghosts(g)
		for b in g.modals.reinforce_panel.find_children("*", "Button", true, false):
			if (b as Button).text == "Dismiss":
				(b as Button).pressed.emit()
		check(not g.modals.reinforce_panel.visible, tag + "50: Dismiss closes it at once")
		check((_ghosts(g) - ghosts_before > 0) == on,
			tag + "50: Dismiss %s" % ("flies the pieces to Stock" if on else "flies nothing"))
		hud.hide_tip()
		check(not hud.tip_panel.visible and hud.tip_panel.modulate.a == 1.0, tag + "40: hide is instant")
		hud.collapse_army_band()
		check(not hud.army_band.visible and hud.army_band.position.y == hud._band_rest_y,
			tag + "38: the close is instant, at rest")
		g.queue_free()
		await process_frame
		await process_frame

	print("---")
	if fails == 0:
		print("ALL GREEN")
		quit(0)
	else:
		print("FAILED: %d" % fails)
		quit(1)
