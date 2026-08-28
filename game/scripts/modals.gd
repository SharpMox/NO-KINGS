## Modals and overlays — box pick, merge confirm, piece preview, tariff list,
## reinforcement shop, win/end screens. Built in code as a CanvasLayer child
## of the Game node (split out of game.gd); the panels themselves parent into
## the HUD layer so stacking (and the click probes) behave exactly as before.
## Signals up, calls down: buttons emit intents handled by game.gd; builders
## only read game state via `g`.

extends Node

const Tuning := preload("res://scripts/tuning.gd")
const Shop := preload("res://scripts/shop.gd")

signal merge_confirmed
signal merge_cancelled
signal box_chosen(opt: Dictionary)
signal box_skipped
signal win_continue_pressed
signal win_end_pressed
signal shop_buy_pressed(index: int)
signal shop_closed
signal reinforce_buy_pressed(id: String)
signal reinforce_done_pressed
signal preview_closed
signal buff_chosen(key: String)
signal buff_pick_cancelled

var g # the Game node — read-only from here; mutations go up via signals

var box_panel := PanelContainer.new() # box-pick modal
var preview_panel := PanelContainer.new() # long-press piece preview
var overlay := PanelContainer.new() # end/win screens
var merge_panel: PanelContainer # merge confirmation (shows the result piece)
var reinforce_panel: PanelContainer # the reinforcement shop overlay
var shop_panel: PanelContainer # the Shop overlay (money-and-shop/04)
var shop_scroll: ScrollContainer # exposed so probes can scroll rows into view
var tariff_panel: PanelContainer # tariff detail overlay
var buff_panel: PanelContainer # Buff Box sub-pick (3 Piece Buffs)


func build(game) -> void:
	g = game
	box_panel.visible = false
	box_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var box_bg := StyleBoxFlat.new()
	box_bg.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	box_panel.add_theme_stylebox_override("panel", box_bg)
	g.hud.add_child(box_panel)

	preview_panel.visible = false
	preview_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pv_bg := StyleBoxFlat.new()
	pv_bg.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	preview_panel.add_theme_stylebox_override("panel", pv_bg)
	g.hud.add_child(preview_panel)

	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := StyleBoxFlat.new()
	dim.bg_color = Color(0.08, 0.08, 0.1, 0.93)
	overlay.add_theme_stylebox_override("panel", dim)
	g.hud.add_child(overlay)


func show_merge_confirm(a_id: String, b_id: String, result: String) -> void:
	if merge_panel:
		merge_panel.queue_free()
	merge_panel = PanelContainer.new()
	merge_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	merge_panel.add_theme_stylebox_override("panel", bg)
	var center := CenterContainer.new()
	merge_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	if g.textures.has(result):
		var tex := TextureRect.new()
		tex.texture = g.piece_tex(result)
		tex.custom_minimum_size = Vector2(96, 96)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(tex)
	var what := Label.new()
	what.text = "%s + %s → %s" % [g.defs[a_id].name, g.defs[b_id].name, g.defs[result].name]
	what.add_theme_font_size_override("font_size", 20)
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(what)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var yes := Button.new()
	yes.text = "Merge"
	yes.add_theme_font_size_override("font_size", 22)
	yes.pressed.connect(func() -> void:
		merge_panel.visible = false
		merge_confirmed.emit())
	row.add_child(yes)
	var no := Button.new()
	no.text = "Cancel"
	no.add_theme_font_size_override("font_size", 22)
	no.pressed.connect(func() -> void:
		merge_panel.visible = false
		merge_cancelled.emit())
	row.add_child(no)
	box.add_child(row)
	g.hud.add_child(merge_panel)
	merge_panel.move_to_front() # above the drawers and bottom bar


## Width-capped, wrapping, centered label — end/win screens must never
## overflow the 480px design width (fixed 2026-07-07).
func _overlay_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(g.get_viewport_rect().size.x - 48, 0)
	return l


func show_overlay(won: bool, reason: String, rank := 0) -> void:
	for c in overlay.get_children():
		c.queue_free()
	var center := CenterContainer.new()
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	box.add_child(_overlay_label("VICTORY" if won else "GAME OVER", 32))
	box.add_child(_overlay_label(reason, 18))
	var stats := "Score %d · Deepest wave %d\nKings %d · Tariffs seen %d\nPieces lost %d · Enemies slain %d" \
		% [g.score, g.wave, g.kings_defeated, g.tariffs_seen.size(), g.lost_player, g.lost_enemy]
	if rank > 0:
		stats += "\n" + ("Local rank #%d" % rank if rank <= 10 else "Off the local top 10")
	box.add_child(_overlay_label(stats, 19))
	var restart := Button.new()
	restart.text = "Restart"
	restart.add_theme_font_size_override("font_size", 26)
	restart.pressed.connect(func() -> void: get_tree().reload_current_scene())
	box.add_child(restart)
	var menu := Button.new()
	menu.text = "Main Menu"
	menu.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	box.add_child(menu)
	overlay.visible = true


## Wave-50 win screen: the run pauses on top of the board; Continue enters
## endless mode, End Run locks the score in (GDD Game Over & Winner Screens,
## trimmed 2026-07-03: no leaderboard rank / pieces-lost summary yet).
func show_win_screen() -> void:
	for c in overlay.get_children():
		c.queue_free()
	var center := CenterContainer.new()
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	box.add_child(_overlay_label("VICTORY", 32))
	box.add_child(_overlay_label("The wave-%d King has fallen" % g.wave, 18))
	var preview := 1 # GDD "ranking preview": where the score would land now
	for e in g.load_scores():
		if int(e.score) >= g.score:
			preview += 1
	box.add_child(_overlay_label(
		"Score %d · rank #%d if ended now\nWave %d · Tariffs seen %d\nPieces lost %d · Enemies slain %d" \
		% [g.score, preview, g.wave, g.tariffs_seen.size(), g.lost_player, g.lost_enemy], 19))
	box.add_child(_overlay_label("Continue into endless waves?", 20))
	var cont := Button.new()
	cont.text = "Continue"
	cont.add_theme_font_size_override("font_size", 26)
	cont.pressed.connect(func() -> void: win_continue_pressed.emit())
	box.add_child(cont)
	var end := Button.new()
	end.text = "End Run"
	end.pressed.connect(func() -> void: win_end_pressed.emit())
	box.add_child(end)
	overlay.visible = true


func show_preview(id: String) -> void:
	for c in preview_panel.get_children():
		c.queue_free()
	preview_panel.visible = true
	var center := CenterContainer.new()
	preview_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = g.defs[id].name
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var dia := Control.new()
	var cells := 9 # covers the longest leap (Ying Long's 4)
	var cell := 30
	dia.custom_minimum_size = Vector2(cells, cells) * cell
	dia.draw.connect(g._draw_preview_diagram.bind(dia, id, cells, cell))
	box.add_child(dia)

	var legend := Label.new()
	legend.text = "● move + capture      ○ move only      ✕ capture only"
	legend.add_theme_font_size_override("font_size", 13)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(legend)

	var chain: Array = g._chain_of(id)
	if chain.size() > 1:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		for i in chain.size():
			if i > 0:
				var arrow := Label.new()
				arrow.text = "→"
				arrow.add_theme_font_size_override("font_size", 22)
				row.add_child(arrow)
			var tr := TextureRect.new()
			tr.texture = g.piece_tex(chain[i]) if g.textures.has(chain[i]) else null
			tr.custom_minimum_size = Vector2(48, 48)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			if chain[i] != id:
				tr.modulate = Color(1, 1, 1, 0.45) # current stage stands out
			row.add_child(tr)
		box.add_child(row)

	var close := Button.new()
	close.text = "Close"
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(func() -> void:
		preview_panel.visible = false
		preview_closed.emit())
	box.add_child(close)


## The Shop overlay: the 19 rolled slots as a scrollable list — lootboxes,
## artefacts, items, then base pieces (the user-specified row order). Buy rows
## emit an index; game.gd buys and reopens for fresh SOLD/affordability state.
func show_shop() -> void:
	if shop_panel:
		shop_panel.queue_free()
	shop_panel = PanelContainer.new()
	shop_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.94)
	shop_panel.add_theme_stylebox_override("panel", bg)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	shop_panel.add_child(box)
	var title := Label.new()
	title.text = "SHOP"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "$%d held — a purchase costs its price + 1 action" % g.gold
	sub.add_theme_font_size_override("font_size", 14)
	sub.modulate = Color(1, 1, 1, 0.8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	shop_scroll = ScrollContainer.new()
	shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(shop_scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	shop_scroll.add_child(rows)
	for i in g.shop_stock.size():
		var slot: Dictionary = g.shop_stock[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var slot_tex: Texture2D = g.piece_tex(slot.key) if slot.kind == "piece" \
				and g.textures.has(slot.key) \
			else g.item_icons.get(slot.key) if slot.kind == "item" else null
		if slot_tex != null:
			var tex := TextureRect.new()
			tex.texture = slot_tex
			tex.custom_minimum_size = Vector2(30, 30)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tex)
		var what := Label.new()
		what.text = "%s — $%d" % [Shop.display_name(g, slot), Shop.price(g, slot)]
		what.add_theme_font_size_override("font_size", 16)
		what.custom_minimum_size = Vector2(230, 0)
		if slot.kind == "item" or slot.kind == "artefact":
			what.tooltip_text = Shop.description(slot)
			what.mouse_filter = Control.MOUSE_FILTER_STOP # so the tooltip shows
		row.add_child(what)
		var buy := Button.new()
		buy.text = "SOLD" if slot.sold else "Buy"
		buy.disabled = not Shop.can_buy(g, slot)
		buy.add_theme_font_size_override("font_size", 16)
		buy.pressed.connect(func() -> void: shop_buy_pressed.emit(i))
		row.add_child(buy)
		if slot.sold:
			row.modulate = Color(1, 1, 1, 0.4)
		rows.add_child(row)
	var close := Button.new()
	close.text = "Close"
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(func() -> void:
		shop_panel.visible = false
		shop_closed.emit())
	box.add_child(close)
	g.hud.add_child(shop_panel)
	shop_panel.move_to_front()


func show_reinforce() -> void:
	if reinforce_panel:
		reinforce_panel.queue_free()
	reinforce_panel = PanelContainer.new()
	reinforce_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.94)
	reinforce_panel.add_theme_stylebox_override("panel", bg)
	var center := CenterContainer.new()
	reinforce_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = "REINFORCEMENTS"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Wave %d cleared — restock your army's reserve, free of charge" % (g.wave - 1)
	sub.add_theme_font_size_override("font_size", 15)
	sub.modulate = Color(1, 1, 1, 0.8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	for id in g._reinforce_ids():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		if g.textures.has(id):
			var tex := TextureRect.new()
			tex.texture = g.piece_tex(id)
			tex.custom_minimum_size = Vector2(34, 34)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(tex)
		var what := Label.new()
		what.text = str(g.defs[id].name)
		what.add_theme_font_size_override("font_size", 17)
		what.custom_minimum_size = Vector2(190, 0)
		row.add_child(what)
		var buy := Button.new()
		buy.text = "Buy"
		buy.add_theme_font_size_override("font_size", 17)
		buy.pressed.connect(func() -> void: reinforce_buy_pressed.emit(id))
		row.add_child(buy)
		box.add_child(row)
	var done := Button.new()
	done.text = "Done"
	done.add_theme_font_size_override("font_size", 22)
	done.pressed.connect(func() -> void:
		reinforce_panel.visible = false
		reinforce_done_pressed.emit())
	box.add_child(done)
	g.hud.add_child(reinforce_panel)
	reinforce_panel.move_to_front()


## Overlay listing every active tariff (name, tier, effect) — opened from the
## top-bar warning button; purely informational, Close dismisses.
func show_tariffs() -> void:
	if tariff_panel:
		tariff_panel.queue_free()
	tariff_panel = PanelContainer.new()
	tariff_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.94)
	tariff_panel.add_theme_stylebox_override("panel", bg)
	var center := CenterContainer.new()
	tariff_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = "Active tariffs"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	if g.tariffs_active.is_empty():
		var none := Label.new()
		none.text = "none yet — they land every 10th wave"
		none.modulate = Color(1, 1, 1, 0.6)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(none)
	for t in g.tariffs_active:
		var name := Label.new()
		name.text = "%s  (%s)" % [t.name, t.tier]
		name.add_theme_font_size_override("font_size", 17)
		name.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
		box.add_child(name)
		var desc := Label.new()
		desc.text = t.description
		desc.add_theme_font_size_override("font_size", 13)
		desc.modulate = Color(1, 1, 1, 0.75)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(g.get_viewport_rect().size.x - 96, 0)
		box.add_child(desc)
	var close := Button.new()
	close.text = "Close"
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(func() -> void: tariff_panel.visible = false)
	box.add_child(close)
	g.hud.add_child(tariff_panel)
	tariff_panel.move_to_front()


# --- box pick ---

func _box_clear() -> void:
	for c in box_panel.get_children():
		c.queue_free()


func _box_vbox(title_text: String) -> VBoxContainer:
	_box_clear()
	box_panel.visible = true
	var center := CenterContainer.new()
	box_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	return box


## Buff Box stage 0 — pick 1 of 3 Piece Buffs, then the board takes over for
## targeting. Cancel leaves the item unspent, so there is no consolation here.
func show_buff_pick(offer: Array) -> void:
	if buff_panel:
		buff_panel.queue_free()
	buff_panel = PanelContainer.new()
	buff_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	buff_panel.add_theme_stylebox_override("panel", bg)
	var center := CenterContainer.new()
	buff_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var head := Label.new()
	head.text = "\u2726 Buff Box \u2014 pick a Piece Buff:"
	head.add_theme_font_size_override("font_size", 22)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	for b in offer:
		var btn := Button.new()
		btn.text = "%s \u2014 %s\n%s" % [b.name, b.tier, b.description]
		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size = Vector2(420, 0)
		var key: String = b.key
		btn.pressed.connect(func() -> void: buff_chosen.emit(key))
		box.add_child(btn)
	var cancel := Button.new()
	cancel.text = "Cancel (keeps the item)"
	cancel.pressed.connect(func() -> void: buff_pick_cancelled.emit())
	box.add_child(cancel)
	g.hud.add_child(buff_panel)
	buff_panel.move_to_front()


func hide_buff_pick() -> void:
	if buff_panel:
		buff_panel.queue_free()
		buff_panel = null


func show_box(options: Array) -> void:
	var box := _box_vbox("📦 The enemy dropped a box! Pick one:")
	for opt in options:
		var b := Button.new()
		var header := ""
		match opt.kind:
			"item":
				header = "⚔ %s — Item · %s · single use" % [opt.name, opt.tier]
			"artefact":
				header = "◈ %s — Artefact · passive, rest of the run" % opt.name
			"score":
				header = "★ %s" % opt.name
		b.text = header + "\n" + opt.description
		if opt.kind == "item" and g.item_icons.has(opt.payload.key):
			b.icon = g.item_icons[opt.payload.key]
			b.add_theme_constant_override("icon_max_width", 30)
		b.add_theme_font_size_override("font_size", 16)
		b.custom_minimum_size = Vector2(420, 0)
		b.pressed.connect(func() -> void: box_chosen.emit(opt))
		box.add_child(b)
	var skip := Button.new()
	skip.text = "Skip (+%d score)" % Tuning.BOX_SKIP_CONSOLATION
	skip.pressed.connect(func() -> void: box_skipped.emit())
	box.add_child(skip)
