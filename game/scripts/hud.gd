## In-game HUD — top bar, bottom button row, drawers + strips, pause menu.
## Built in code as a CanvasLayer child of the Game node (split out of
## game.gd). Signals up, calls down: user intents are emitted as signals and
## handled by game.gd; this layer only reads game state (via `g`) to render.

extends CanvasLayer

const Tuning := preload("res://scripts/tuning.gd")
const Waves := preload("res://data/waves.gd")
const Economy := preload("res://scripts/economy.gd")
const MergeLogic := preload("res://scripts/merge_logic.gd")

const DRAWER_H := 68.0 # one strip row; the inventory drawer stacks two

signal pass_pressed
signal tariff_pressed
signal stack_pressed(id: String, cap: bool, count: int)
signal stack_drag_started(id: String, cap: bool)
signal item_pressed(index: int)
signal promote_pressed(id: String, cap: bool)
signal return_to_stock_pressed
signal drawer_changed
signal shop_pressed
signal menu_toggled(open: bool)

var g # the Game node — read-only from here; mutations go up via signals

var clock_label := Label.new()
var score_label := Label.new()
var money_label := Label.new() # spendable currency (score is the metric)
var wave_label := Label.new()
var turn_label := Label.new()
var pass_button := Button.new()
var shop_button := Button.new()
var pass_count := Label.new() # blue N/M action counter on the PASS button
var pass_label := Label.new() # the "PASS" word next to the counter
var tariff_button := Button.new() # top-row tariff count; opens the overlay
var drawer_open := "" # "", "stock", "inventory"
var drawers := {} # name -> PanelContainer
var drawer_buttons := {} # name -> Button (count text updates)
var stock_armed := Control.new() # draws the armed piece on the Stock button
var pool_box := HBoxContainer.new()
var item_box := HBoxContainer.new() # held-items strip
var trinket_box := HBoxContainer.new()
var game_menu := PanelContainer.new() # in-game menu (pauses the clock)


func build(game) -> void:
	g = game
	var vp: Vector2 = g.get_viewport_rect().size
	# condensed top bar: clock · score · money · wave, menu at the right corner
	clock_label.add_theme_font_size_override("font_size", 17)
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.25))
	money_label.add_theme_font_size_override("font_size", 18)
	money_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.4))
	wave_label.add_theme_font_size_override("font_size", 15)
	wave_label.modulate = Color(1, 1, 1, 0.85)
	var top := HBoxContainer.new()
	top.position = Vector2(10, 4)
	top.custom_minimum_size = Vector2(vp.x - 56, 0)
	top.add_theme_constant_override("separation", 14)
	for l in [clock_label, score_label, money_label, wave_label]:
		top.add_child(l)
	add_child(top)
	tariff_button.add_theme_font_size_override("font_size", 13)
	tariff_button.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
	tariff_button.pressed.connect(func() -> void: tariff_pressed.emit())
	top.add_child(tariff_button)

	var menu_btn := Button.new()
	menu_btn.text = "☰"
	menu_btn.add_theme_font_size_override("font_size", 15)
	menu_btn.position = Vector2(vp.x - 34, 3)
	# both top-row buttons get flat compact styling so they fit inside the
	# top strip without overflowing onto the board (2026-07-08)
	for b: Button in [tariff_button, menu_btn]:
		var compact := StyleBoxFlat.new()
		compact.bg_color = Color(0.22, 0.22, 0.26)
		compact.set_corner_radius_all(4)
		compact.content_margin_left = 7
		compact.content_margin_right = 7
		compact.content_margin_top = 1
		compact.content_margin_bottom = 1
		for style in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(style, compact)
	menu_btn.pressed.connect(func() -> void:
		game_menu.move_to_front() # above every other HUD control
		game_menu.visible = true
		menu_toggled.emit(true))
	add_child(menu_btn)

	# bottom: action count above the button row (Stock / Inventory / Shop / PASS)
	turn_label.position = Vector2(0, vp.y - 70)
	turn_label.custom_minimum_size = Vector2(vp.x, 0)
	turn_label.add_theme_font_size_override("font_size", 14)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# it floats over the board's bottom edge now — outline for readability
	turn_label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.1))
	turn_label.add_theme_constant_override("outline_size", 6)
	add_child(turn_label)
	var bar := HBoxContainer.new()
	bar.position = Vector2(4, vp.y - 46)
	bar.custom_minimum_size = Vector2(vp.x - 8, 42)
	bar.add_theme_constant_override("separation", 4)
	for name in ["stock", "inventory"]:
		var b := Button.new()
		b.text = name.capitalize()
		b.add_theme_font_size_override("font_size", 17)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			set_drawer(name)
			drawer_changed.emit())
		drawer_buttons[name] = b
		bar.add_child(b)
	# the armed stack rides on the Stock button, styled like a selection
	stock_armed.set_anchors_preset(Control.PRESET_FULL_RECT)
	stock_armed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stock_armed.draw.connect(_draw_stock_armed)
	drawer_buttons["stock"].add_child(stock_armed)
	shop_button.text = "Shop"
	shop_button.add_theme_font_size_override("font_size", 17)
	shop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_button.pressed.connect(func() -> void: shop_pressed.emit())
	bar.add_child(shop_button)
	pass_button.text = "PASS"
	pass_button.add_theme_font_size_override("font_size", 17)
	# self_modulate: the red tint must not bleed into the blue counter child
	pass_button.self_modulate = Color(1, 0.5, 0.5)
	pass_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_button.pressed.connect(func() -> void: pass_pressed.emit())
	# "2/2 PASS", both vertically centered — the button's own text is only
	# used for START (setup); in-turn the label pair takes over
	var pass_box := HBoxContainer.new()
	pass_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	pass_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pass_box.add_theme_constant_override("separation", 7)
	pass_box.mouse_filter = Control.MOUSE_FILTER_IGNORE # clicks hit the button
	pass_count.add_theme_font_size_override("font_size", 15)
	pass_count.add_theme_color_override("font_color", Color(0.45, 0.7, 1.0))
	pass_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pass_box.add_child(pass_count)
	pass_label.text = "PASS"
	pass_label.add_theme_font_size_override("font_size", 17)
	pass_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pass_box.add_child(pass_label)
	pass_button.add_child(pass_box)
	bar.add_child(pass_button)
	add_child(bar)

	game_menu.visible = false
	game_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gm_bg := StyleBoxFlat.new()
	gm_bg.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	game_menu.add_theme_stylebox_override("panel", gm_bg)
	var gm_center := CenterContainer.new()
	game_menu.add_child(gm_center)
	var gm_box := VBoxContainer.new()
	gm_box.add_theme_constant_override("separation", 20)
	gm_center.add_child(gm_box)
	var gm_title := Label.new()
	gm_title.text = "Paused" # menu open = clock frozen (GDD pause)
	gm_title.add_theme_font_size_override("font_size", 32)
	gm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gm_box.add_child(gm_title)
	var resume := Button.new()
	resume.text = "Resume"
	resume.add_theme_font_size_override("font_size", 26)
	resume.pressed.connect(func() -> void:
		game_menu.visible = false
		menu_toggled.emit(false))
	gm_box.add_child(resume)
	var to_menu := Button.new()
	to_menu.text = "Main Menu"
	to_menu.add_theme_font_size_override("font_size", 20)
	to_menu.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	gm_box.add_child(to_menu)
	add_child(game_menu)

	# drawers above the button row, one at a time, overlaying the board, full
	# width and running to the screen bottom; the button bar re-fronts below so
	# it stays visible and clickable over them. Inventory stacks the held-items
	# strip over the trinket strip (money-and-shop/03).
	trinket_box.add_theme_constant_override("separation", 16)
	var inv_box := VBoxContainer.new()
	inv_box.add_theme_constant_override("separation", 8)
	inv_box.add_child(item_box)
	inv_box.add_child(trinket_box)
	var drawer_specs := [ # name, content, x, width, height
		["stock", pool_box, 0.0, vp.x, DRAWER_H + 70.0],
		["inventory", inv_box, 0.0, vp.x, DRAWER_H * 2 + 70.0],
	]
	for spec in drawer_specs:
		var panel := PanelContainer.new()
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.1, 0.13, 0.97)
		panel.add_theme_stylebox_override("panel", bg)
		panel.position = Vector2(spec[2], vp.y - spec[4]) # bottom-anchored
		panel.custom_minimum_size = Vector2(spec[3], spec[4])
		panel.visible = false
		var sc := ScrollContainer.new()
		sc.custom_minimum_size = Vector2(spec[3] - 8, spec[4] - 8)
		sc.clip_contents = false # the ▲ promote badge overhangs the drawer top
		sc.add_child(spec[1])
		panel.add_child(sc)
		drawers[spec[0]] = panel
		add_child(panel)
	bar.move_to_front() # the button bar stays visible over the stock drawer


## Open one drawer (closing the others) or toggle it shut; "" closes all.
## Visibility only — selection/board consequences live in game.gd's handler.
func set_drawer(which: String) -> void:
	drawer_open = "" if drawer_open == which else which
	for name in drawers:
		drawers[name].visible = drawer_open == name


func refresh() -> void:
	clock_label.text = g._clock_text()
	score_label.text = "★%d" % g.score
	money_label.text = "$%d" % g.money
	var next_in: int = g._cadence() - g.turns_since_wave
	var wave_txt := "King!" if g._king_alive() \
		else ("in %d" % maxi(next_in, 0)) if g.wave < Waves.WAVES.size() else "done"
	wave_label.text = "wave %d/%d · %s" % [g.wave, Waves.WAVES.size(), wave_txt]
	if g.state == g.State.SETUP: # the pass button doubles as the explicit start trigger
		turn_label.text = "Place your army (%d left), then START" % g.stock.size()
		pass_button.text = "START"
		pass_button.self_modulate = Color(0.55, 1.0, 0.55)
		pass_count.text = ""
		pass_label.text = ""
	elif g.state == g.State.PLAYER_TURN:
		pass_button.text = ""
		pass_button.self_modulate = Color(1, 0.5, 0.5)
		pass_count.text = "%d/%d" % [g.actions_left, g.actions_max]
		pass_label.text = "PASS"
		turn_label.text = ""
	elif g.state == g.State.ENEMY_TURN:
		turn_label.text = "enemy turn…"
		pass_count.text = ""
		pass_label.text = "PASS"
	elif g.state == g.State.GAME_OVER:
		turn_label.text = ""
		pass_count.text = ""
	drawer_buttons["stock"].text = "Stock %d" % g._pool().size()
	stock_armed.queue_redraw() # armed piece rides the button (selection style)
	drawer_buttons["inventory"].text = "Inventory %d" % (g.items.size() + g.trinkets.size())
	tariff_button.text = "⚠%d" % g.tariffs_active.size() \
			+ ("·off" if g.counter_intel_turns > 0 and not g.tariffs_active.is_empty() else "")
	_rebuild_pool_strip()
	_rebuild_item_strip()
	_rebuild_trinket_strip()


## The pool-strip stack button under a screen point (drag drop target).
func stack_button_at(screen: Vector2) -> Button:
	if not pool_box.is_visible_in_tree(): # stock drawer closed: no targets
		return null
	for c in pool_box.get_children():
		if c is Button and not c.is_queued_for_deletion() and c.has_meta("id") \
				and (c as Button).get_global_rect().has_point(screen):
			return c
	return null


## The armed stack piece rides on the Stock button styled like a selection:
## player-blue tint plus the same pulsing outline as a selected board piece.
func _draw_stock_armed() -> void:
	# only while the drawer is closed — open, the armed stack itself is visible
	if g.placing_id == "" or drawer_open == "stock" or not g.textures.has(g.placing_id):
		return
	var c := Vector2(19.0, stock_armed.size.y / 2.0)
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	stock_armed.draw_texture_rect(g.textures[g.placing_id],
		Rect2(c - Vector2(13, 13), Vector2(26, 26)), false, Color(0.72, 0.85, 1.25))
	stock_armed.draw_arc(c, 14.0 + 2.0 * pulse, 0, TAU, 24,
		Color(0.4, 0.7, 1.0, 0.45 + 0.4 * pulse), 2.0 + pulse)


func _stacks() -> Array:
	# pool grouped for display/selection: stock stacks first, then captured
	var out := []
	for cap in [false, true]:
		var counts := {}
		for id in (g.captured if cap else g.stock):
			counts[id] = counts.get(id, 0) + 1
		for id in counts:
			out.append({"id": id, "cap": cap, "count": counts[id]})
	return out


func _rebuild_trinket_strip() -> void:
	for c in trinket_box.get_children():
		c.queue_free()
	if g.trinkets.is_empty():
		var none := Label.new()
		none.text = "no trinkets yet"
		none.modulate = Color(1, 1, 1, 0.6)
		trinket_box.add_child(none)
		return
	var counts := {}
	for t in g.trinkets: # stack copies: one entry per kind
		counts[t.key] = counts.get(t.key, 0) + 1
	var seen := {}
	for t in g.trinkets:
		if seen.has(t.key):
			continue
		seen[t.key] = true
		var l := Label.new()
		l.text = "◈%s%s" % [t.name, " ×%d" % counts[t.key] if counts[t.key] > 1 else ""]
		l.tooltip_text = t.description
		l.mouse_filter = Control.MOUSE_FILTER_STOP # so the tooltip shows
		trinket_box.add_child(l)


func _rebuild_item_strip() -> void:
	for c in item_box.get_children():
		c.queue_free()
	for i in g.items.size():
		var btn := Button.new()
		btn.text = "✦" + g.items[i].name
		btn.tooltip_text = "%s (%s)\n%s" % [g.items[i].name, g.items[i].tier, g.items[i].description]
		if g.item_active == i:
			btn.modulate = Color(0.5, 1.3, 1.3)
		btn.pressed.connect(func() -> void: item_pressed.emit(i))
		item_box.add_child(btn)


func _rebuild_pool_strip() -> void:
	for c in pool_box.get_children():
		c.queue_free()
	for st in _stacks():
		var btn := Button.new()
		var id: String = st.id
		var cap: bool = st.cap
		if g.textures.has(id): # piece icon instead of glyph text (round 3)
			btn.icon = g.textures[id]
			btn.expand_icon = true
			btn.custom_minimum_size = Vector2(46, 46)
		else:
			btn.text = g.defs[id].glyph
			btn.add_theme_font_size_override("font_size", 22)
		var show_promote: bool = g.placing_id == id and g.placing_cap == cap \
				and st.count >= 2 and MergeLogic.pair_ok(g, id, id) \
				and g.state == g.State.PLAYER_TURN and g.actions_left > 0
		if st.count > 1:
			# corner badge keeps the icon full-size (no inline text); it yields
			# the top-right corner to the ▲ promote button when that shows
			var badge := Label.new()
			badge.text = str(st.count)
			badge.add_theme_font_size_override("font_size", 11)
			badge.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
			badge.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
			badge.add_theme_constant_override("outline_size", 4)
			if show_promote:
				badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
				badge.offset_left = 3
				badge.offset_right = 16
				badge.offset_bottom = 12
			else:
				badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
				badge.offset_left = -16
				badge.offset_bottom = 12
			btn.add_child(badge)
		if show_promote:
			# round ▲ badge floating over the stack's top-right corner: it
			# overhangs the drawer's top edge and pokes out a little to the
			# right of the icon (the stock scroll doesn't clip)
			var promote := Button.new()
			promote.text = "▲"
			promote.add_theme_font_size_override("font_size", 11)
			promote.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
			var round := StyleBoxFlat.new()
			round.bg_color = Color(0.3, 0.6, 1.0) # player blue
			round.set_corner_radius_all(9)
			for style in ["normal", "hover", "pressed"]:
				promote.add_theme_stylebox_override(style, round)
			promote.tooltip_text = "Promote: merge two into one"
			promote.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			promote.offset_left = -14
			promote.offset_right = 4
			promote.offset_top = -9
			promote.offset_bottom = 9
			promote.pressed.connect(func() -> void: promote_pressed.emit(id, cap))
			btn.add_child(promote)
		btn.tooltip_text = g.defs[id].name + (" (captured)" if cap else "")
		if g.placing_id == id and g.placing_cap == cap:
			btn.modulate = Color(0.55, 0.95, 1.5) # armed: placement / merge origin
		elif g.merge_highlights.has(id):
			btn.modulate = Color(0.8, 1.1, 1.4) # completes a merge — tap or drop
		elif not cap and id == g.sanctioned_id and Economy.tariff_on(g, "sanctions"):
			btn.modulate = Color(1.0, 0.45, 0.45) # Sanctions: unplaceable
		elif cap:
			btn.modulate = Color(1.0, 0.8, 0.8) # captured stock: warm tint
		btn.set_meta("id", id) # drop-target lookup for drag merges
		btn.set_meta("cap", cap)
		btn.pressed.connect(func() -> void: stack_pressed.emit(id, cap, st.count))
		btn.button_down.connect(func() -> void: stack_drag_started.emit(id, cap))
		pool_box.add_child(btn)
	if g.state == g.State.SETUP and g.selected.x >= 0:
		# empty slot: tap it (or drop the dragged piece on the strip) to take
		# the selected board piece back into stock
		var slot := Button.new()
		slot.text = "+"
		slot.custom_minimum_size = Vector2(46, 46)
		slot.add_theme_font_size_override("font_size", 22)
		slot.modulate = Color(0.55, 0.75, 1.0, 0.85) # placement blue, dimmed
		slot.tooltip_text = "Put the piece back into stock"
		slot.pressed.connect(func() -> void: return_to_stock_pressed.emit())
		pool_box.add_child(slot)
