## In-game HUD — top bar, bottom button row, drawers + strips, pause menu.
## Built in code as a CanvasLayer child of the Game node (split out of
## game.gd). Signals up, calls down: user intents are emitted as signals and
## handled by game.gd; this layer only reads game state (via `g`) to render.

extends CanvasLayer

const Tuning := preload("res://scripts/tuning.gd")
const Waves := preload("res://data/waves.gd")
const Economy := preload("res://scripts/economy.gd")
const Shop := preload("res://scripts/shop.gd") # issue 96/97: convert price
const MergeLogic := preload("res://scripts/merge_logic.gd")
const Guide := preload("res://scripts/guide.gd")
const Settings := preload("res://scripts/settings.gd")
const Armies := preload("res://scripts/armies.gd")

const DRAWER_H := 68.0 # one strip row; the inventory drawer stacks two
const INV_H_BASE := DRAWER_H * 2 + 70.0 # pre-issue-52 height: items + artefacts
	# only — unreachable since issue 67, kept so nothing breaks reading it
const INV_H_ACTIVATE := DRAWER_H * 3 + 118.0 # +1 row while the Activate
	# strip is up, +48 more for issue 100's Army Power line (two wrapped rows
	# at 13px on a 480-wide portrait screen)
	# section has content (issue 52). Issue 67: the Army Ability chip is
	# now unconditionally in that section (every run holds a Army), so this
	# is the drawer's permanent height going forward, not a conditional one

signal pass_pressed
signal tariff_pressed
signal stack_pressed(entry: Variant, cap: bool, count: int) # entry: ADR-0002
signal stack_drag_started(entry: Variant, cap: bool)
signal multi_confirm_pressed # the floating Extract button
signal item_pressed(index: int)
signal artefact_activate_pressed(key: String) # issue 52: an Activate chip pressed
signal army_ability_pressed # issue 67: the Army Ability chip pressed
signal promote_pressed(id: String, cap: bool)
signal return_to_stock_pressed
signal drawer_changed
signal shop_pressed
signal menu_toggled(open: bool)
signal settings_changed(data: Dictionary) # a toggle changed; game.gd applies it live
signal arrow_toggle_pressed
signal arrow_clear_pressed

var g # the Game node — read-only from here; mutations go up via signals

var clock_label := Label.new()
var score_label := Label.new()
var gold_label := Label.new() # spendable currency (score is the metric)
var wave_label := Label.new()
var turn_label := Label.new()
var pass_button := Button.new()
var shop_button := Button.new()
var pass_count := Label.new() # blue N/M action counter on the PASS button
var pass_label := Label.new() # the "PASS" word next to the counter
var tariff_button := Button.new() # top-row tariff count; opens the overlay
var arrow_button := Button.new() # Arrow Planning: toggles decorative drawing mode
var arrow_clear_button := Button.new() # clears every drawn arrow
var drawer_open := "" # "", "stock", "inventory"
var drawers := {} # name -> PanelContainer
var drawer_buttons := {} # name -> Button (count text updates)
var stock_armed := Control.new() # draws the armed piece on the Stock button
var multi_confirm_btn := Button.new() # floating "Extract N" confirm
var pool_box := HBoxContainer.new()
var item_box := HBoxContainer.new() # held-items strip
var activate_box := HBoxContainer.new() # issue 52: pressable Activate chips
## issue 100: the Army POWER, written out in the drawer. It was previously
## readable in exactly two places — the tooltip of the Ability chip, and the
## army-select screen before the run — and this is a portrait TOUCH game, so
## once a run starts a hover tooltip is unreachable. Several Powers change what
## is LEGAL (Close Ranks makes merges free, Endless Ranks makes pawn deploys
## free), so a player who has forgotten theirs is misreading their own rules.
var army_power_label := Label.new()
	# for activatable Artefacts; issue 67 added the Army Ability chip here
	# too (always present, unlike the Artefact ones — every run holds one)
var artefact_box := HBoxContainer.new() # passive Artefacts only (issue 52
	# moved the 6 activatable keys out into activate_box above)
var game_menu := PanelContainer.new() # in-game menu (pauses the clock)


func build(game) -> void:
	g = game
	var vp: Vector2 = g.get_viewport_rect().size
	# condensed top bar: clock · score · gold · wave, menu at the right corner
	clock_label.add_theme_font_size_override("font_size", 17)
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.25))
	gold_label.add_theme_font_size_override("font_size", 18)
	gold_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.4))
	wave_label.add_theme_font_size_override("font_size", 15)
	wave_label.modulate = Color(1, 1, 1, 0.85)
	var top := HBoxContainer.new()
	top.position = Vector2(10, 4)
	top.custom_minimum_size = Vector2(vp.x - 56, 0)
	top.add_theme_constant_override("separation", 14)
	for l in [clock_label, score_label, gold_label, wave_label]:
		top.add_child(l)
	add_child(top)
	tariff_button.add_theme_font_size_override("font_size", 13)
	tariff_button.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
	tariff_button.pressed.connect(func() -> void: tariff_pressed.emit())
	top.add_child(tariff_button)
	arrow_button.text = "Arrows"
	arrow_button.add_theme_font_size_override("font_size", 13)
	arrow_button.pressed.connect(func() -> void: arrow_toggle_pressed.emit())
	top.add_child(arrow_button)

	var menu_btn := Button.new()
	menu_btn.text = "☰"
	menu_btn.add_theme_font_size_override("font_size", 15)
	menu_btn.position = Vector2(vp.x - 34, 3)
	# both top-row buttons get flat compact styling so they fit inside the
	# top strip without overflowing onto the board (2026-07-08)
	for b: Button in [tariff_button, arrow_button, menu_btn]:
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
	# floating confirm for "multi" items: shows once >= 1 piece is picked
	multi_confirm_btn.add_theme_font_size_override("font_size", 17)
	multi_confirm_btn.position = Vector2(vp.x / 2 - 70, vp.y - 96)
	multi_confirm_btn.custom_minimum_size = Vector2(140, 40)
	multi_confirm_btn.visible = false
	multi_confirm_btn.pressed.connect(func() -> void: multi_confirm_pressed.emit())
	add_child(multi_confirm_btn)
	# floating Clear-all for Arrow Planning: only worth showing while the mode
	# is on (top bar has no room to spare — money-and-shop already fills it)
	arrow_clear_button.text = "Clear"
	arrow_clear_button.add_theme_font_size_override("font_size", 17)
	arrow_clear_button.position = Vector2(vp.x / 2 - 70, vp.y - 96)
	arrow_clear_button.custom_minimum_size = Vector2(140, 40)
	arrow_clear_button.visible = false
	arrow_clear_button.pressed.connect(func() -> void: arrow_clear_pressed.emit())
	add_child(arrow_clear_button)
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

	# Guide and Settings are shared with the Main Menu (scripts/guide.gd,
	# scripts/settings.gd) so both entry points show identical content
	var guide_scroll := Guide.build(game_menu, func() -> void: gm_box.visible = true)
	var settings_panel := Settings.build(game_menu, func() -> void: gm_box.visible = true,
		func(data: Dictionary) -> void: settings_changed.emit(data))
	var guide_btn := Button.new()
	guide_btn.text = "Guide"
	guide_btn.add_theme_font_size_override("font_size", 20)
	guide_btn.pressed.connect(func() -> void:
		gm_box.visible = false
		guide_scroll.visible = true)
	gm_box.add_child(guide_btn)
	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.add_theme_font_size_override("font_size", 20)
	settings_btn.pressed.connect(func() -> void:
		gm_box.visible = false
		settings_panel.visible = true)
	gm_box.add_child(settings_btn)

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
	# strip over the artefact strip (money-and-shop/03), with the issue-52
	# Activate section between them, shown/sized only while it has content.
	artefact_box.add_theme_constant_override("separation", 16)
	activate_box.add_theme_constant_override("separation", 8)
	army_power_label.add_theme_font_size_override("font_size", 13)
	army_power_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	army_power_label.custom_minimum_size = Vector2(vp.x - 24.0, 0)
	var inv_box := VBoxContainer.new()
	inv_box.add_theme_constant_override("separation", 8)
	inv_box.add_child(army_power_label) # issue 100: above the strips — it is
		# the standing rule the rest of the drawer operates under
	inv_box.add_child(item_box)
	inv_box.add_child(activate_box)
	inv_box.add_child(artefact_box)
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
	# issue 101: the Shop button STAYS but is disabled before the unlock Wave
	# (user ruling) — a hidden button reads as "this game has no Shop", a
	# greyed one reads as "not yet". It carries the Wave, because a disabled
	# control with no reason is the failure the ruling was one step away from.
	var shop_locked: bool = g.wave < Tuning.SHOP_UNLOCK_WAVE
	shop_button.disabled = shop_locked
	shop_button.text = "Shop (W%d)" % Tuning.SHOP_UNLOCK_WAVE if shop_locked else "Shop"
	shop_button.tooltip_text = "Opens on Wave %d" % Tuning.SHOP_UNLOCK_WAVE \
		if shop_locked else ""
	clock_label.text = g._clock_text()
	score_label.text = "★%d" % g.score
	gold_label.text = "$%d" % g.gold
	var next_in: int = g._cadence() - g.turns_since_wave
	var wave_txt := ("King: %s" % g._king_name()) if g._king_alive() \
		else ("in %d" % maxi(next_in, 0)) if g.wave < Waves.WAVES.size() else "done"
	wave_label.text = "wave %d/%d · %s" % [g.wave, Waves.WAVES.size(), wave_txt]
	if g.state == g.State.SETUP: # the pass button doubles as the explicit start trigger
		turn_label.text = "Place your army (%d left), then START" % g.stock.size()
		pass_button.text = "START"
		pass_button.disabled = false
		pass_button.tooltip_text = ""
		pass_button.self_modulate = Color(0.55, 1.0, 0.55)
		pass_count.text = ""
		pass_label.text = ""
	elif g.state == g.State.PLAYER_TURN:
		pass_button.text = ""
		# Hellfire Club Discord Invite (issue 54): "you cannot Pass while
		# Actions remain" — greyed out AND relabeled, not a silent failed
		# click, so the block is visible before the player even taps it.
		var pass_blocked: bool = g._pass_blocked()
		pass_button.disabled = pass_blocked
		pass_button.tooltip_text = "Hellfire Club Discord Invite: use an Action before you can Pass" \
			if pass_blocked else ""
		pass_button.self_modulate = Color(0.5, 0.5, 0.5) if pass_blocked else Color(1, 0.5, 0.5)
		pass_count.text = "%d/%d" % [g.actions_left, g.actions_max]
		pass_label.text = "MUST ACT" if pass_blocked else "PASS"
		turn_label.text = ""
	elif g.state == g.State.ENEMY_TURN:
		turn_label.text = "enemy turn…"
		pass_button.disabled = false
		pass_button.tooltip_text = ""
		pass_count.text = ""
		pass_label.text = "PASS"
	elif g.state == g.State.GAME_OVER:
		pass_button.disabled = false
		pass_button.tooltip_text = ""
		turn_label.text = ""
		pass_count.text = ""
	drawer_buttons["stock"].text = "Stock %d" % g._pool().size()
	stock_armed.queue_redraw() # armed piece rides the button (selection style)
	drawer_buttons["inventory"].text = "Inventory %d" % (g.items.size() + g.artefacts.size())
	tariff_button.text = "⚠%d" % g.tariffs_active.size() \
		+ ("·off" if g.tariffs_suppressed else "")
	# armed-placement tint (2026-07-07 palette) marks the toggle as active
	arrow_button.self_modulate = Color(0.55, 0.95, 1.5) if g.arrow_mode else Color(1, 1, 1)
	arrow_clear_button.visible = g.arrow_mode
	multi_confirm_btn.visible = g.item_active >= 0 and not g.item_selected.is_empty() \
		and g.items[g.item_active].target == "multi"
	multi_confirm_btn.text = "Extract %d" % g.item_selected.size()
	_rebuild_pool_strip()
	_rebuild_item_strip()
	# issue 100: the Power is always on, so it is stated, not offered. The
	# Ability's 1-Action cost rides along here too — that cost is the
	# deliberate contrast with Artefact activation and the Shop (both 0), and
	# it was also tooltip-only until now.
	var kit: Dictionary = Armies.entry(g.next_army)
	army_power_label.text = "%s — %s: %s   ·   ★%s (1 Action): %s" % [
		Armies.display_name(g.next_army), kit.power_name, kit.power_desc,
		kit.ability_name, kit.ability_desc]
	_rebuild_activate_strip()
	_rebuild_artefact_strip()
	# issue 52 grew the drawer only when the Activate row had content; issue
	# 67 made that permanent — the Army Ability chip means it always does.
	var inv_panel: PanelContainer = drawers["inventory"]
	var inv_h := INV_H_ACTIVATE
	if inv_panel.custom_minimum_size.y != inv_h:
		var inv_w: float = inv_panel.custom_minimum_size.x
		inv_panel.custom_minimum_size = Vector2(inv_w, inv_h)
		inv_panel.position = Vector2(inv_panel.position.x, g.get_viewport_rect().size.y - inv_h)


## issue 97: can the player currently pay for this entry's action? Drives the
## price colour only — the real refusals stay where they are (Economy/Shop).
func _pool_affordable(cap: bool, entry: Variant) -> bool:
	return g.gold >= (Shop.convert_price(g, entry) if cap else Economy.deploy_cost(g))


## issue 96: the divider between Stock and Captured Stock. Carries the RULE
## that makes the pool different ("no deploy"), not just a name — the
## constraint is the reason the section exists, and a label that only said
## "Captured" would leave the player to discover the rule by being refused.
func _add_captured_header() -> void:
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(10, 0)
	pool_box.add_child(sep)
	var lbl := Label.new()
	lbl.text = "CAPTURED\nno deploy"
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pool_box.add_child(lbl)


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
	stock_armed.draw_texture_rect(g.piece_tex(g.placing_id),
		Rect2(c - Vector2(13, 13), Vector2(26, 26)), false)
	stock_armed.draw_arc(c, 14.0 + 2.0 * pulse, 0, TAU, 24,
		Color(0.4, 0.7, 1.0, 0.45 + 0.4 * pulse), 2.0 + pulse)


func _stacks() -> Array:
	# pool grouped for display/selection: stock stacks first, then captured.
	# Grouping is by WHOLE entry (ADR-0002), so a piece carrying state stacks
	# apart from plain copies of the same id.
	var out := []
	for cap in [false, true]:
		var counts := {}
		for e in (g.captured if cap else g.stock):
			counts[e] = counts.get(e, 0) + 1
		for e in counts:
			out.append({"entry": e, "id": (e if e is String else e.id),
				"cap": cap, "count": counts[e]})
	return out


## issue 52: activatable Artefacts (game.ACTIVATABLE_ARTEFACT_KEYS) get a
## pressable chip in activate_box instead — this row keeps EXACTLY today's
## quiet label treatment, for passive Artefacts only. "no artefacts yet"
## still gates on the whole g.artefacts list (unchanged), not just the
## passive subset: holding only an activatable Artefact is not "nothing".
func _rebuild_artefact_strip() -> void:
	for c in artefact_box.get_children():
		c.queue_free()
	if g.artefacts.is_empty():
		var none := Label.new()
		none.text = "no artefacts yet"
		none.modulate = Color(1, 1, 1, 0.6)
		artefact_box.add_child(none)
		return
	var counts := {}
	for t in g.artefacts: # stack copies: one entry per kind
		counts[t.key] = counts.get(t.key, 0) + 1
	var seen := {}
	for t in g.artefacts:
		if seen.has(t.key) or g.ACTIVATABLE_ARTEFACT_KEYS.has(t.key):
			continue
		seen[t.key] = true
		var l := Label.new()
		l.text = "◈%s%s" % [t.name, " ×%d" % counts[t.key] if counts[t.key] > 1 else ""]
		l.tooltip_text = t.description
		l.mouse_filter = Control.MOUSE_FILTER_STOP # so the tooltip shows
		artefact_box.add_child(l)


## issue 52: the Activate section — entry point 1 ("click the Artefact in
## the list") and 2 ("a dedicated section in the Items menu") are the SAME
## widget here, since this codebase's single Inventory drawer already holds
## both Items and Artefacts (there is no second menu to put a distinct copy
## in). Empty (no activatable Artefact held) leaves activate_box with zero
## children — refresh() reads that to keep the drawer at today's height.
func _rebuild_activate_strip() -> void:
	for c in activate_box.get_children():
		c.queue_free()
	for key in g._activatable_held_keys():
		var entry: Dictionary = g._artefact_entry(key)
		var count: int = g._artefact_count(key)
		var btn := Button.new()
		btn.text = "⚡%s%s" % [entry.name, " ×%d" % count if count > 1 else ""]
		var targeting: bool = g.artefact_targeting_key == key
		btn.disabled = not (g._artefact_activation_available(key) or targeting)
		btn.tooltip_text = entry.description
		if targeting: # mid-targeting (Bovine): tint like an active Item, tap
			# again to cancel — same shape _rebuild_item_strip already uses
			btn.modulate = Color(0.5, 1.3, 1.3)
		btn.pressed.connect(func() -> void: artefact_activate_pressed.emit(key))
		activate_box.add_child(btn)
	_add_army_ability_chip()


## issue 67: the Army Ability chip — same activate_box row as the Artefact
## chips above, but every run always holds exactly one (a Army replaces
## the Army pick), so this is unconditional, not gated on "is one held" the
## way the Artefact loop above is. "Visually distinct from Artefact chips"
## (acceptance): a ★ glyph instead of ⚡ and a warm gold tint at rest,
## instead of the Artefact chips' plain default button styling.
func _add_army_ability_chip() -> void:
	var kit: Dictionary = Armies.entry(g.next_army)
	var btn := Button.new()
	btn.text = "★%s" % kit.ability_name
	var targeting: bool = g.army_targeting or g.army_board_targeting # issue
		# 68: Hostile Takeover/Ritual's board-targeting flavor gets the same tint
	btn.disabled = not (g._army_ability_available() or targeting)
	btn.tooltip_text = "%s (1 Action)\n%s" % [kit.power_name + " — always on. " \
		+ kit.ability_name, kit.ability_desc]
	if targeting:
		btn.modulate = Color(0.5, 1.3, 1.3) # mid-targeting: same tint as an
			# Artefact/Item mid-target, tap again to cancel
	else:
		btn.modulate = Color(1.35, 1.2, 0.75) # at-rest: warm gold, distinct
			# from an Artefact chip's plain default tint
	btn.pressed.connect(func() -> void: army_ability_pressed.emit())
	activate_box.add_child(btn)


func _rebuild_item_strip() -> void:
	for c in item_box.get_children():
		c.queue_free()
	for i in g.items.size():
		var btn := Button.new()
		if g.item_icons.has(g.items[i].key):
			btn.icon = g.item_icons[g.items[i].key]
			# icon_max_width clamps AND reserves layout space; expand_icon
			# would let the icon collapse to 0 in a packed strip
			btn.add_theme_constant_override("icon_max_width", 30)
			btn.text = g.items[i].name
		else:
			btn.text = "✦" + g.items[i].name
		btn.tooltip_text = "%s (%s)\n%s" % [g.items[i].name, g.items[i].tier, g.items[i].description]
		if g.item_active == i:
			btn.modulate = Color(0.5, 1.3, 1.3)
		btn.pressed.connect(func() -> void: item_pressed.emit(i))
		item_box.add_child(btn)


func _rebuild_pool_strip() -> void:
	for c in pool_box.get_children():
		c.queue_free()
	var captured_marked := false
	for st in _stacks():
		# issue 96: Captured Stock becomes its own LABELLED section rather than
		# a tinted tail of the same run of buttons. The two pools obey different
		# rules — a Captured entry can merge, convert and sell but can NEVER be
		# deployed (issue 60) — and the only signals for that were a warm tint
		# and a tooltip suffix. This is a portrait TOUCH game: the tooltip does
		# not exist on a phone, so a player could not tell which of their pieces
		# were placeable. _stacks() returns stock first then captured, so the
		# first captured stack is the boundary.
		if st.cap and not captured_marked:
			captured_marked = true
			_add_captured_header()
		var btn := Button.new()
		var id: String = st.id
		var cap: bool = st.cap
		if g.textures.has(id): # piece icon instead of glyph text (round 3)
			btn.icon = g.piece_tex(id) # Stock is always yours: the player token
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
		# issue 97: the price of acting on this entry, on the entry itself —
		# deploy cost for a Stock piece, conversion cost for a Captured one.
		# BOTH the base and the effective number when they differ, because
		# showing only the effective one hides that a modifier exists and
		# showing only the base is a lie: a Horde pawn deploys FREE (Endless
		# Ranks) and a Qin Shi Huang deploy costs double (The Great Wall).
		# Read from the live calls, never re-derived here — re-implementing the
		# modifiers in the HUD would be a second copy of the rules, and it
		# would drift.
		var price := Label.new()
		if cap:
			price.text = "$%d" % Shop.convert_price(g, st.entry)
		else:
			var base: int = Tuning.PLACEMENT_COST
			var eff: int = Economy.deploy_cost(g)
			if id == "pawn" and Armies.endless_ranks(g):
				eff = 0 # Endless Ranks is scoped to pawns at _place, so the
					# generic deploy_cost() does not know about it
			price.text = "$%d" % eff if eff == base else "$%d>%d" % [base, eff]
		price.add_theme_font_size_override("font_size", 10)
		price.add_theme_color_override("font_color",
			Color(1, 0.95, 0.7) if _pool_affordable(cap, st.entry) else Color(1, 0.5, 0.5))
		price.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
		price.add_theme_constant_override("outline_size", 4)
		price.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		price.offset_top = -13
		btn.add_child(price)
		if show_promote:
			# round ▲ badge floating over the stack's top-right corner: it
			# overhangs the drawer's top edge and pokes out a little to the
			# right of the icon (the stock scroll doesn't clip)
			var promote := Button.new()
			# issue 97: the merge's price, on the control that starts it.
			# Free under Close Ranks? No — that Power waives the ACTION only
			# (merge_logic.can_afford_merge), so the Gold shows regardless.
			promote.text = "▲$%d" % Tuning.MERGE_COST
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
		if g.placing_id != "" and g.armed_entry == st.entry and g.placing_cap == cap:
			btn.modulate = Color(0.55, 0.95, 1.5) # armed: placement / merge origin
		elif g.merge_highlights.has(id):
			btn.modulate = Color(0.8, 1.1, 1.4) # completes a merge — tap or drop
		elif not cap and Economy.sanctioned(g, id):
			btn.modulate = Color(1.0, 0.45, 0.45) # Sanctions: unplaceable
		elif cap:
			btn.modulate = Color(1.0, 0.8, 0.8) # captured stock: warm tint
		if st.entry is Dictionary: # carries state: mark the stack (ADR-0002)
			var mark := Label.new()
			mark.text = "◆"
			mark.add_theme_font_size_override("font_size", 11)
			mark.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
			mark.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			mark.offset_left = -14
			mark.offset_top = -14
			btn.add_child(mark)
		btn.set_meta("id", id) # drop-target lookup for drag merges
		btn.set_meta("cap", cap)
		btn.set_meta("entry", st.entry)
		btn.pressed.connect(func() -> void: stack_pressed.emit(st.entry, cap, st.count))
		btn.button_down.connect(func() -> void: stack_drag_started.emit(st.entry, cap))
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
