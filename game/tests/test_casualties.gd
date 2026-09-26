extends SceneTree
## Casualties: every piece that dies in a run, both sides, recorded in order
## (game.gd `casualties`), saved with the run, rolled back with the NO-241
## retry checkpoint, and drawn on the end screens as one PieceMass inside a
## ScrollContainer, the buttons pinned below it.
## Run headless:  godot --headless --path game -s tests/test_casualties.gd

const GameScript := preload("res://scripts/game.gd")
const PieceMass := preload("res://scripts/piece_mass.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const Rules := preload("res://scripts/rules.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Ads := preload("res://scripts/ads.gd")
const Modals := preload("res://scripts/modals.gd")

var fails := 0
const VIEWPORT_CENTER_TOL := 6.0 # px — see its own call site: a real vertical
	# scrollbar (251 casualties overflow the viewport) narrows the centred
	# area by its own reserved width, ~4.8px off centre, measured on CI


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _boot(cfg: Dictionary) -> Node2D:
	GameScript.reset_boot_defaults()
	cfg = cfg.duplicate(true)
	cfg.seed = 1
	GameScript.next_config = cfg
	GameScript.is_scenario = true # never touch the real save
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _free(g: Node) -> void:
	g.queue_free()
	await process_frame


## "id:side id:side ..." — one string, so a failing check prints what it saw.
func _list(g) -> String:
	return " ".join(PackedStringArray(g.casualties.map(func(c: Dictionary) -> String: return "%s:%d" % [c.id, c.side])))


func _section(g) -> Control:
	for n in g.modals.overlay.find_children("Casualties", "VBoxContainer", true, false):
		if not n.is_queued_for_deletion():
			return n
	return null


func _icons(section: Control) -> Array:
	return section.find_children("*", "TextureRect", true, false)


func _settle() -> void:
	for i in 10: # containers sort deferred — bumped from 3 (Max's 2026-09-26
		# banner review): a resort can cascade across more than one deferred-
		# call flush (a scrollbar appearing narrows `box`, which re-centres
		# `mass`, one pass after the first layout), so this needs to
		# comfortably outlast that
		await process_frame


## 251 casualties, interleaved, both sides — the long run the scroll is for
## (well past one screen of rows, whatever the theme's button height).
func _many() -> Array:
	var out := []
	for i in 180:
		out.append({"id": ["pawn", "knight", "rook", "queen"][i % 4], "side": Rules.ENEMY})
		if i < 70:
			out.append({"id": ["pawn", "bishop", "amazon"][i % 3], "side": Rules.PLAYER})
	out.append({"id": "king", "side": Rules.ENEMY})
	return out


func _init() -> void:
	await process_frame # Engine.get_main_loop() is still null inside _init
	# The phone's 480px design width, whatever window the host gives a headless
	# run ("expand" widened CI's to 800px, run 36186578428): the geometry
	# checks below are about the real panel.
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: test_casualties still running after 120s")
		quit(1))
	var E := Rules.ENEMY
	var P := Rules.PLAYER

	# --- every loss/kill path records ------------------------------------------
	var cap := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	cap.actions_left = 5
	cap._move_player(Vector2i(2, 2), Vector2i(2, 5))
	check(_list(cap) == "rook:%d" % E, "a player capture records the enemy (%s)" % _list(cap))
	await _free(cap)

	var mc := _boot({"board": [["queen", 0, 2, 2, {"buffs": [{"key": "multicapture"}]}], ["pawn", 1, 3, 2],
		["rook", 1, 4, 2], ["knight", 1, 4, 3], ["rook", 1, 7, 10]], "wave": 3, "artefacts": ["exhibit-399"]})
	await process_frame
	mc.actions_left = 5
	mc._move_player(Vector2i(2, 2), Vector2i(3, 2))
	check(mc.casualties.size() == 3 and mc.casualties.all(func(c: Dictionary) -> bool: return c.side == E),
		"Multicapture + Exhibit 399: the capture, its extra victim and the destroyed neighbour (%s)" % _list(mc))
	await _free(mc)

	var tr := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	tr.actions_left = 5
	BuffLogic.add(tr.board[Vector2i(2, 5)], "trap")
	tr._move_player(Vector2i(2, 2), Vector2i(2, 5))
	check(_list(tr) == "rook:%d queen:%d" % [E, P], "Trap: the victim and the attacker (%s)" % _list(tr))
	await _free(tr)

	var rf := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	rf.actions_left = 5
	BuffLogic.add(rf.board[Vector2i(2, 5)], "reflect")
	rf._move_player(Vector2i(2, 2), Vector2i(2, 5))
	check(_list(rf) == "queen:%d" % P, "Reflect: the reflected attacker is lost (%s)" % _list(rf))
	await _free(rf)

	var bm := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5], ["pawn", 0, 1, 4],
		["king", 1, 1, 5], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	bm.actions_left = 5
	BuffLogic.add(bm.board[Vector2i(2, 5)], "bomb")
	bm._move_player(Vector2i(2, 2), Vector2i(2, 5))
	var bm_l := _list(bm)
	check(bm_l.begins_with("rook:%d" % E) and bm_l.contains("queen:%d" % P) and bm_l.contains("pawn:%d" % P)
			and not bm_l.contains("king"),
		"Bomb: the victim, then the attacker and the ally in the blast; the King is spared (%s)" % bm_l)
	await _free(bm)

	var ds := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 4, 4], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	ds._destroy(Vector2i(7, 10), true) # an Item's kill
	ds._destroy(Vector2i(4, 4)) # a Tariff/King-Power destruction of an ally
	check(_list(ds) == "rook:%d pawn:%d" % [E, P], "destruction records both sides (%s)" % _list(ds))
	await _free(ds)

	var fp := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 4, 4], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["fireproof-pajamas"]})
	await process_frame
	fp._destroy(Vector2i(4, 4))
	check(fp.board.has(Vector2i(4, 4)) and fp.casualties.is_empty(),
		"a destruction Fireproof Pajamas vetoes is no casualty")
	await _free(fp)

	var ec := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 2, 5]], "wave": 4})
	await process_frame
	await ec._run_enemy_actions()
	check(_list(ec) == "pawn:%d" % P, "an enemy capture records the ally (%s)" % _list(ec))
	await _free(ec)

	var eb := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 2, 5]], "wave": 4})
	await process_frame
	BuffLogic.add(eb.board[Vector2i(2, 2)], "bomb")
	await eb._run_enemy_actions()
	check(_list(eb) == "pawn:%d rook:%d" % [P, E],
		"an enemy capturing a Bomb: the ally victim and the blasted attacker (%s)" % _list(eb))
	await _free(eb)

	var et := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 2, 5]], "wave": 4})
	await process_frame
	BuffLogic.add(et.board[Vector2i(2, 2)], "trap")
	await et._run_enemy_actions()
	check(_list(et) == "pawn:%d rook:%d" % [P, E], "an enemy capturing a Trap: both (%s)" % _list(et))
	await _free(et)

	var hf := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 2, 5]], "wave": 4,
		"artefacts": ["hoffa-s-cement-shoes"]})
	await process_frame
	await hf._run_enemy_actions()
	check(_list(hf) == "pawn:%d rook:%d" % [P, E], "Hoffa's Cement Shoes: victim and sunk attacker (%s)" % _list(hf))
	await _free(hf)

	var er := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 2, 5]], "wave": 4})
	await process_frame
	BuffLogic.add(er.board[Vector2i(2, 2)], "reflect")
	await er._run_enemy_actions()
	check(_list(er) == "rook:%d" % E, "an enemy reflected: the attacker dies (%s)" % _list(er))
	await _free(er)

	var row := []
	for x in Tuning.BOARD_W:
		row.append(["pawn", 0, x, Tuning.SPAWN_ROW])
	row.append(["rook", 1, 7, 5]) # an enemy left, so the boot does not clear the wave
	var sp := _boot({"board": row, "wave": 4})
	await process_frame
	sp.casualties = [] # only the crush below
	sp.pending_spawn = [{"id": "rook"}]
	WaveLogic.spawn_pending(sp)
	check(_list(sp) == "pawn:%d" % P, "a spawn crushing an ally records it (%s)" % _list(sp))
	await _free(sp)

	var kc := _boot({"board": [["queen", 0, 2, 2], ["king", 1, 2, 3], ["rook", 1, 7, 10]],
		"wave": 100, "kings_defeated": 1, "clock_s": 100.0})
	await process_frame
	kc._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(_list(kc) == "king:%d" % E, "a captured King is a casualty (%s)" % _list(kc))
	check(kc.lost_enemy == 1, "a captured King counts as an Enemy slain (%d)" % kc.lost_enemy)
	await _free(kc)

	var km := _boot({"board": [["queen", 0, 2, 2], ["king", 1, 5, 9], ["rook", 1, 7, 10]],
		"wave": 100, "kings_defeated": 1, "clock_s": 100.0})
	await process_frame
	km._king_down()
	check(_list(km) == "king:%d" % E, "a checkmated King leaving the board is a casualty (%s)" % _list(km))
	check(km.lost_enemy == 1, "a checkmated King ALSO counts as an Enemy slain (%d)" % km.lost_enemy)
	await _free(km)

	# --- a piece that dies twice is two casualties: an enemy Rook captured,
	# converted into Stock, deployed and then lost shows once as an enemy
	# and once as an ally, in that order
	var tw := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 1000})
	await process_frame
	tw.actions_left = 5
	tw._move_player(Vector2i(2, 2), Vector2i(2, 5))
	check(tw.captured.has("rook") and tw._convert_captured("rook") and tw.stock.has("rook"),
		"(setup) the captured Rook converts into Stock")
	tw._place("rook", Vector2i(4, 1))
	check(tw.board.has(Vector2i(4, 1)) and tw.board[Vector2i(4, 1)].id == "rook", "(setup) ...and deploys")
	tw._destroy(Vector2i(4, 1))
	check(_list(tw) == "rook:%d rook:%d" % [E, P],
		"a Rook slain, converted, deployed and lost is two casualties, enemy then ally (%s)" % _list(tw))
	await _free(tw)

	# --- save/load and the retry checkpoint -----------------------------------
	var sv := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 4, 4], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	sv._destroy(Vector2i(7, 10), true)
	sv._destroy(Vector2i(4, 4))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(sv._to_config()))
	await _free(sv)
	var ld := _boot(saved)
	await process_frame
	check(_list(ld) == "rook:%d pawn:%d" % [E, P] and ld.casualties[0].side is int,
		"casualties survive a JSON save/load, sides as ints (%s)" % _list(ld))
	await _free(ld)
	var old := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	check(old.casualties.is_empty(), "a save without the field loads with no casualties")
	await _free(old)

	var rt := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 4, 4], ["rook", 1, 7, 10], ["rook", 1, 6, 10]], "wave": 5})
	await process_frame
	rt.ad_retry_enabled = true # scenario boots turn it off; this test drives it
	current_scene = rt # reload_current_scene needs one, as the real game has
	rt._destroy(Vector2i(7, 10), true) # before the checkpoint: kept
	rt._take_wave_snapshot()
	rt._destroy(Vector2i(6, 10), true) # after it: rolled back
	rt._destroy(Vector2i(4, 4))
	check(rt.casualties.size() == 3, "(setup) three casualties before the loss")
	rt._game_over(false, "Clock out")
	rt._choice_picked(true) # Accept
	var close: Button = Ads.close_button()
	if close != null:
		close.pressed.emit()
	var r: Node = null
	for i in 60: # bounded: a reload that never lands fails here, not as a hang
		await process_frame
		if current_scene != null and current_scene != rt and is_instance_valid(current_scene):
			r = current_scene
			break
	check(r != null, "(setup) the retry reloads the game")
	if r != null:
		await process_frame
		check(_list(r) == "rook:%d" % E,
			"the retry rolls casualties back to the checkpoint (%s)" % _list(r))
		await _free(r)

	# --- the end screens ----------------------------------------------------
	var base := {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 5}
	var z := _boot(base)
	await process_frame
	z._game_over(false, "Clock out")
	await _settle()
	var z_text := ""
	for l in z.modals.overlay.find_children("*", "Label", true, false):
		z_text += (l as Label).text + "\n"
	check(z.modals.overlay.visible and _section(z) == null and not z_text.contains("Casualties"),
		"no casualties: no Casualties section, no empty label")
	await _free(z)

	for win in [false, true]:
		var g := _boot(base)
		await process_frame
		g.animations_on = false
		g.casualties = _many()
		if win:
			g._show_win_screen()
		else:
			g._game_over(false, "Clock out")
		await _settle()
		var screen := "win screen" if win else "game over"
		var section := _section(g)
		check(section != null, "%s: a Casualties section" % screen)
		if section == null:
			await _free(g)
			continue
		var titles := section.find_children("*", "Label", true, false)
		var title_label: Label = titles[0] if not titles.is_empty() else null
		check(title_label != null and title_label.text == "Casualties"
				and title_label.theme_type_variation == &"Heading",
			"%s: headed \"Casualties\" in the Heading style" % screen)
		var icons := _icons(section)
		var enemies: int = g.casualties.filter(func(c: Dictionary) -> bool: return c.side == E).size()
		var shown_enemies := icons.filter(func(t: TextureRect) -> bool: return t.get_meta("side") == E).size()
		check(icons.size() == g.casualties.size() and shown_enemies == enemies,
			"%s: one piece per casualty (%d of %d, %d enemies of %d)" % [screen, icons.size(),
				g.casualties.size(), shown_enemies, enemies])
		# Max, 2026-09-26 (7th review): the banner reverses the earlier
		# `top_level`-overflow design (piece_mass.gd's first cut clipped the
		# point invisibly; the 2nd-6th cuts let it escape the scroll and bleed
		# behind the buttons) — it now draws straight onto `section`'s own
		# canvas (`_add_casualty_banner()`'s `draw` signal), so there is no
		# separate banner NODE to find; these checks are all geometric,
		# against `section`, `mass` and the point's own depth spacer instead.
		var mass_ctrl: Control = section.get_child(1)
		var end_scroll: ScrollContainer = g.modals.overlay.find_child("EndScroll", true, false)
		var box_ctrl: Node = section.get_parent() # `box` itself — read straight
			# off `section`'s own parent so it stays correct however `box` is
			# wrapped above (Max, 10th review, added `box_pad`'s own margins)
		var bar_node: Control = g.modals.overlay.find_child("EndScreenBar", true, false)
		var strip_node: Control = bar_node.get_child(0) \
			if bar_node != null and bar_node.get_child_count() > 0 else null
		var buttons_ctrl: Control = strip_node.get_child(0) \
			if strip_node != null and strip_node.get_child_count() > 0 else null
		check(end_scroll != null and end_scroll.is_ancestor_of(section),
			"%s: the banner (drawn on `section` itself) is a descendant of the scrolled content" % screen)
		check(not section.top_level,
			"%s: no banner node is top_level — it scrolls with the pieces like any other content" % screen)
		var point_spacer: Control = section.find_child("CasualtyBannerPoint", false, false)
		check(point_spacer != null
				and section.get_child(section.get_child_count() - 1) == point_spacer
				and box_ctrl != null and box_ctrl.get_child(box_ctrl.get_child_count() - 1) == section,
			"%s: the point's own depth is the last thing in the scrolled content — nothing sits below it"
				% screen)
		# Max, 2026-09-26 (10th review, page-spec ruling): the scroll viewport
		# now spans the WHOLE screen — content scrolls off the top edge — and
		# the button block floats over it on its own opaque bar instead of
		# constraining the scroll's own height.
		var screen_size := g.get_viewport_rect().size
		check(end_scroll != null and absf(end_scroll.get_global_rect().position.y) <= 0.5
				and absf(end_scroll.get_global_rect().end.y - screen_size.y) <= 0.5,
			"%s: the scroll viewport spans the full screen, top (0) to bottom (%.1f) (got [%.1f, %.1f])"
				% [screen, screen_size.y,
					end_scroll.get_global_rect().position.y if end_scroll != null else -1.0,
					end_scroll.get_global_rect().end.y if end_scroll != null else -1.0])
		var strip_style: StyleBox = strip_node.get_theme_stylebox("panel") if strip_node != null else null
		check(strip_style is StyleBoxFlat and (strip_style as StyleBoxFlat).bg_color.a >= 0.999,
			"%s: the button bar is opaque" % screen)
		var overlay_kids: Array = g.modals.overlay.get_children()
		check(bar_node != null and end_scroll != null
				and overlay_kids.find(bar_node) > overlay_kids.find(end_scroll),
			"%s: the bar draws above the scroll (later tree position)" % screen)
		if point_spacer != null and title_label != null:
			var banner_w: float = mass_ctrl.custom_minimum_size.x + 2.0 * Modals.CASUALTY_BANNER_MARGIN_X
			var depth: float = banner_w * Modals.CASUALTY_BANNER_POINT_DEPTH_RATIO
			check(is_equal_approx(point_spacer.custom_minimum_size.y, depth),
				"%s: the bottom room is exactly the point's own depth (%.1f vs %.1f)"
					% [screen, point_spacer.custom_minimum_size.y, depth])
			var apex_y: float = mass_ctrl.position.y + mass_ctrl.size.y + depth
			check(section.size.y >= apex_y - 0.01,
				"%s: the section's own content height includes the point (%.1f >= %.1f)"
					% [screen, section.size.y, apex_y])
			var section_rect := section.get_global_rect()
			var title_rect := title_label.get_global_rect()
			check(title_rect.position.y >= section_rect.position.y - 0.5
					and title_rect.position.y <= section_rect.position.y + Modals.CASUALTY_TITLE_TOP_PAD + 4.0,
				"%s: the title sits near the banner's own top edge (%.1f vs section top %.1f)"
					% [screen, title_rect.position.y, section_rect.position.y])
			check(is_equal_approx(title_rect.get_center().x, section_rect.get_center().x),
				"%s: the title is centred horizontally on the banner (%.1f vs %.1f)"
					% [screen, title_rect.get_center().x, section_rect.get_center().x])
			check(title_label.get_theme_color("font_color") == Tuning.COL_LOSS,
				"%s: the title is loss-red (Tuning.COL_LOSS)" % screen)
			var gap: float = mass_ctrl.get_global_rect().position.y - title_rect.end.y
			check(gap >= 12.0 - 0.01,
				"%s: at least 12px between the title's bottom and the mass's top (%.1f px)" % [screen, gap])
			# Max, 8th review (of the PREVIOUS `top_level` capture, a1c799c):
			# the crowd's own art was sliced by a hard edge near the banner's
			# top, and by another right above the buttons. Both read as
			# `clip_contents` cutting into the rotated first/last row's own
			# overhang (piece_mass.gd's `edge_pad()` already reserves exactly
			# that much room INSIDE `mass` — these prove nothing ABOVE `mass`
			# throws that room away).
			var no_clip := true
			var clip_offender := ""
			var walker: Node = mass_ctrl
			while walker != null and walker != end_scroll:
				if walker is Control and (walker as Control).clip_contents:
					no_clip = false
					clip_offender = str(walker.name)
				walker = walker.get_parent()
			check(no_clip,
				"%s: nothing between the pieces and the ScrollContainer clips (offender: %s)"
					% [screen, clip_offender])
			check(mass_ctrl.size.y >= mass_ctrl.custom_minimum_size.y - 0.01,
				"%s: the mass keeps its own full height — the rotated first/last row's overhang room is never squeezed (%.1f vs %.1f)"
					% [screen, mass_ctrl.size.y, mass_ctrl.custom_minimum_size.y])
			# Max, 9th review (Aux's capture at e296e12): the banner's left
			# edge sat flush with the screen while the mass was centred — the
			# banner painted with `mass`'s pre-sort (still 0) local x, because
			# `mass`'s SHRINK_CENTER re-centring is a position-only Container
			# sort that never fired `section`'s own `resized`. Fixed by also
			# redrawing on `mass.resized`/`mass.item_rect_changed`; these
			# check the actually-settled result, both against the mass's own
			# centre and against the viewport's.
			var mass_rect := mass_ctrl.get_global_rect()
			var mass_center_x: float = mass_rect.get_center().x
			var bx_global: float = mass_rect.position.x - Modals.CASUALTY_BANNER_MARGIN_X
			var banner_center_x: float = bx_global + banner_w * 0.5
			var viewport_center_x: float = g.get_viewport_rect().size.x * 0.5
			check(absf(banner_center_x - mass_center_x) <= 1.0,
				"%s: the banner's horizontal centre matches the mass's own (%.1f vs %.1f)"
					% [screen, banner_center_x, mass_center_x])
			# VIEWPORT_CENTER_TOL, not 1px: this run's 251 casualties overflow
			# the viewport, so the ScrollContainer shows a real vertical
			# scrollbar that reserves its own width — `box`'s SHRINK_CENTER
			# then centres content in the SCROLLBAR-NARROWED area, a few
			# pixels left of the screen's true centre (measured 4.8px off on
			# CI run 36253532485). That is the scrollbar physically being
			# there, not a bug in the banner's own centring (already proven
			# exact against the mass, above).
			check(absf(banner_center_x - viewport_center_x) <= VIEWPORT_CENTER_TOL,
				"%s: the banner's horizontal centre is close to the viewport's own (%.1f vs %.1f)"
					% [screen, banner_center_x, viewport_center_x])
			var banner_left: float = bx_global
			var banner_right: float = bx_global + banner_w
			var all_inside := true
			var outside_id := ""
			for t in icons:
				var piece_rect: Rect2 = (t as Control).get_global_rect()
				if piece_rect.position.x < banner_left - 0.5 or piece_rect.end.x > banner_right + 0.5:
					all_inside = false
					outside_id = str((t as Control).get_meta("id"))
			check(all_inside,
				"%s: every piece's rect lies horizontally inside the banner (offender: %s, [%.1f, %.1f])"
					% [screen, outside_id, banner_left, banner_right])
			# --scroll-bottom (tools/capture.md): the exact state Aux's capture
			# judges. Nothing new needs to sync here (unlike the dropped
			# `top_level` design) — `section` is an ordinary scrolled
			# descendant, so it moves with the ScrollContainer for free.
			g.modals.scroll_end_screen_to_bottom()
			await _settle()
			var apex_global_y: float = section.get_global_rect().position.y + apex_y
			var scroll_rect := end_scroll.get_global_rect()
			check(apex_global_y >= scroll_rect.position.y - 0.5 and apex_global_y <= scroll_rect.end.y + 0.5,
				"%s: scrolled to the bottom, the point sits inside the scroll's own (clipped) rect (%.1f in [%.1f, %.1f])"
					% [screen, apex_global_y, scroll_rect.position.y, scroll_rect.end.y])
			check(strip_node == null
					or apex_global_y <= strip_node.get_global_rect().position.y - Modals.END_SCREEN_BAR_GAP + 0.5,
				"%s: at max scroll, the point sits at least %dpx above the bar's own top (%.1f vs bar top %.1f)"
					% [screen, Modals.END_SCREEN_BAR_GAP, apex_global_y,
						strip_node.get_global_rect().position.y if strip_node != null else -1.0])
		var tint_ok := true
		var unscaled := true
		var odd := ""
		var in_order := true
		var reading := true
		var row_counts := {}
		var prev_row := -1
		var prev_x := -INF
		for k in icons.size():
			var t: TextureRect = icons[k]
			in_order = in_order and t.get_meta("id") == g.casualties[k].id and t.get_meta("side") == g.casualties[k].side
			var row_i := roundi((t.position.y - PieceMass.edge_pad(true) - PieceMass.JITTER_Y) / PieceMass.SPACED_ROW_PITCH)
			reading = reading and (row_i == prev_row + 1 or (row_i == prev_row and t.position.x > prev_x))
			prev_row = row_i
			prev_x = t.position.x
			row_counts[row_i] = row_counts.get(row_i, 0) + 1
		# geometry (Aux's capture of 8fd8389: a column a third of the screen
		# wide): pitch >= 0.75 ICON across, >= 0.65 ICON down, full rows of 8,
		# centred
		var rows_x := {}
		var rows_y := {}
		for k in icons.size():
			var ti: TextureRect = icons[k]
			var rr := roundi((ti.position.y - PieceMass.edge_pad(true) - PieceMass.JITTER_Y) / PieceMass.SPACED_ROW_PITCH)
			rows_x[rr] = rows_x.get(rr, []) + [ti.position.x]
			rows_y[rr] = rows_y.get(rr, []) + [ti.position.y]
		var min_dx := INF
		var widest_row := 0.0
		for rr in rows_x:
			var xs: Array = rows_x[rr]
			for q in range(1, xs.size()):
				min_dx = minf(min_dx, xs[q] - xs[q - 1])
			if xs.size() == Modals.CASUALTIES_PER_ROW:
				widest_row = maxf(widest_row, xs[-1] + PieceMass.ICON - xs[0])
		var min_dy := INF
		var mean_y := func(ys: Array) -> float:
			return ys.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / ys.size()
		for rr in rows_y:
			if rows_y.has(rr + 1):
				min_dy = minf(min_dy, mean_y.call(rows_y[rr + 1]) - mean_y.call(rows_y[rr]))
		var inner_w: float = g.get_viewport_rect().size.x - 48
		print("%s: measured pitch %.1f px across, %.1f px down; full row %.1f px of %.1f inner (%.0f%%)"
			% [screen, min_dx, min_dy, widest_row, inner_w, 100.0 * widest_row / inner_w])
		check(min_dx >= PieceMass.ICON * 0.75 - 0.01, "%s: horizontal pitch >= 0.75 ICON (%.1f px)" % [screen, min_dx])
		check(min_dy >= PieceMass.ICON * 0.65 - 2.0 * PieceMass.JITTER_Y,
			"%s: vertical pitch >= 0.65 ICON, less the wobble (%.1f px)" % [screen, min_dy])
		# 8 at the full pitch (no row squeezed to fit), centred in the panel
		var full_row: float = (Modals.CASUALTIES_PER_ROW - 1) * PieceMass.SPACED_PITCH + PieceMass.ICON
		check(widest_row >= full_row - 0.01 and widest_row <= inner_w,
			"%s: a full row is %d pieces at full pitch inside the inner width (%.1f of %.1f)"
			% [screen, Modals.CASUALTIES_PER_ROW, widest_row, inner_w])
		var m_rect: Rect2 = (section.get_child(1) as Control).get_global_rect()
		var s_mid: float = section.get_global_rect().get_center().x # the panel's column
		check(absf(m_rect.get_center().x - s_mid) <= 1.0,
			"%s: the mass is centred in the panel (%.1f vs %.1f)" % [screen, m_rect.get_center().x, s_mid])
		var rows_ok := true
		for rk in row_counts:
			rows_ok = rows_ok and row_counts[rk] >= PieceMass.MIN_ROW_PIECES and row_counts[rk] <= Modals.CASUALTIES_PER_ROW
		check(in_order, "%s: the pieces are the casualties in the order they died" % screen)
		check(reading and icons[0].position.y < icons[-1].position.y,
			"%s: reading order — first death top-left, left to right, newest at the bottom" % screen)
		check(rows_ok, "%s: every row holds %d-%d pieces (%s)" % [screen, PieceMass.MIN_ROW_PIECES,
			Modals.CASUALTIES_PER_ROW, row_counts.values()])
		for t in icons:
			var id: String = t.get_meta("id")
			var side: int = t.get_meta("side")
			tint_ok = tint_ok and t.texture == g.piece_tex(id, side)
			if GameScript.is_mono_piece(id):
				tint_ok = tint_ok and t.modulate == (GameScript.COL_SIDE_ENEMY if side == E else GameScript.COL_SIDE_PLAYER)
			# approx: a Control keeps offsets, not a size, so a 52px icon at a
			# fractional x reads back as e.g. 52.00001 (CI run 36183894676)
			if t.scale != Vector2.ONE or not t.size.is_equal_approx(Vector2(PieceMass.ICON, PieceMass.ICON)):
				unscaled = false
				odd = "%s scale %s size %s" % [id, t.scale, t.size]
		check(tint_ok, "%s: each piece in its own side's art, like the board" % screen)
		check(unscaled, "%s: no piece is scaled (%s)" % [screen, odd])
		var mass: Control = section.get_child(1)
		var inner: float = g.get_viewport_rect().size.x - 48
		check(mass.custom_minimum_size.x <= inner + 0.01 and mass.get_global_rect().end.x <= g.get_viewport_rect().end.x,
			"%s: the mass fits the panel's inner width (%.1f <= %.1f)" % [screen, mass.custom_minimum_size.x, inner])
		var scroll: ScrollContainer = g.modals.overlay.find_child("EndScroll", true, false)
		check(scroll != null and scroll.is_ancestor_of(section)
				and scroll.get_v_scroll_bar().max_value > scroll.size.y,
			"%s: the stats and the mass scroll (%s > %s)" % [screen,
				scroll.get_v_scroll_bar().max_value if scroll else -1.0, scroll.size.y if scroll else -1.0])
		var vp: Rect2 = g.get_viewport_rect()
		var labels: Array = ["Continue", "End Run", "Give Feedback"] if win else ["Restart", "Main Menu", "Give Feedback"]
		for text in labels:
			var btn: Button = null
			for b in g.modals.overlay.find_children("*", "Button", true, false):
				if (b as Button).text == text and not b.is_queued_for_deletion():
					btn = b
			check(btn != null and not scroll.is_ancestor_of(btn) and vp.encloses(btn.get_global_rect()),
				"%s: %s sits outside the scroll, fully on screen with 100+ casualties" % [screen, text])
		if scroll != null:
			g.modals.scroll_end_screen_to_bottom() # --scroll-bottom's own call
			await _settle()
			check(scroll.scroll_vertical > 0, "%s: the scroll reaches further down the mass" % screen)
		await _free(g)

	# --- #590's staged reveal: the section fades in after the count-up, the
	# buttons are live throughout, and it is instant with animations off
	var fa := _boot(base)
	await process_frame
	fa.animations_on = true
	fa.score = 1234 # a count-up to watch
	fa.casualties = _many()
	fa._game_over(false, "Clock out")
	await process_frame
	var fs := _section(fa)
	check(fs != null and fs.modulate.a == 0.0 and fa.modals.reveal != null,
		"animations on: the section starts hidden inside the reveal")
	var restart: Button = null
	for b in fa.modals.overlay.find_children("*", "Button", true, false):
		if (b as Button).text == "Restart" and not b.is_queued_for_deletion():
			restart = b
	check(restart != null and restart.mouse_filter == Control.MOUSE_FILTER_STOP
			and restart.is_visible_in_tree() and not fs.is_ancestor_of(restart),
		"...and the buttons are live while it waits")
	# Frame by frame, not on a timer: a headless frame's delta is whatever the
	# host took, so a wall-clock sample lands anywhere in the tween. The rule
	# is ordering: the section shows nothing until the Score reads its total.
	var stats: Label = null
	for l in fa.modals.overlay.find_children("*", "Label", true, false):
		if (l as Label).text.begins_with("Score ") and not l.is_queued_for_deletion():
			stats = l
	var early := ""
	var t0 := Time.get_ticks_msec()
	while fs.modulate.a < 1.0 and Time.get_ticks_msec() - t0 < 5000:
		if fs.modulate.a > 0.0 and stats != null and not stats.text.begins_with("Score 1234"):
			early = stats.text.get_slice("\n", 0)
		await process_frame
	check(stats != null and early == "",
		"...still hidden while the Score counts up (visible at \"%s\")" % early)
	check(fs.modulate.a == 1.0, "...then fades fully in")
	await _free(fa)

	print("---")
	if fails == 0:
		print("ALL CASUALTIES CHECKS OK")
	quit(1 if fails > 0 else 0)
