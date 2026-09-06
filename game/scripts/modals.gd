## Modals and overlays — box pick, merge confirm, piece preview, tariff list,
## reinforcement shop, win/end screens. Built in code as a CanvasLayer child
## of the Game node (split out of game.gd); the panels themselves parent into
## the HUD layer so stacking (and the click probes) behave exactly as before.
## Signals up, calls down: buttons emit intents handled by game.gd; builders
## only read game state via `g`.

extends Node

const Tuning := preload("res://scripts/tuning.gd")
const Shop := preload("res://scripts/shop.gd")
const Kings := preload("res://data/kings.gd")
const Box := preload("res://scripts/box.gd")

signal restart_pressed # game.gd owns what Restart MEANS; this is just the press
signal merge_confirmed
signal merge_cancelled
signal box_chosen(opt: Dictionary)
signal box_skipped
signal box_reroll_pressed
signal win_continue_pressed
signal win_end_pressed
signal shop_buy_pressed(index: int)
signal shop_closed
signal shop_restock_pressed # issue 52: Jet Fuel Vial's Restock button
signal shop_sell_pressed(kind: String, entry: Variant) # issue 60
signal shop_convert_pressed(entry: Variant) # issue 60: Captured -> Stock
signal reinforce_buy_pressed(id: String)
signal reinforce_done_pressed
signal preview_closed
signal choice_chosen(value)
signal choice_pick_cancelled

var g # the Game node — read-only from here; mutations go up via signals

var box_panel := PanelContainer.new() # box-pick modal
var preview_panel := PanelContainer.new() # long-press piece preview
var overlay := PanelContainer.new() # end/win screens
var merge_panel: PanelContainer # merge confirmation (shows the result piece)
var reinforce_panel: PanelContainer # the reinforcement shop overlay
var shop_panel: Panel # the Shop drawer (shop-drawer-ui/08)
var _shop_dock: PanelContainer # the detail dock — refilled on a tile tap, so a
	# tap no longer frees and rebuilds the whole ~80-node drawer (review pass 2)
var shop_lane_b_bar: ProgressBar # issue 64: Lane B restock progress —
	# exposed so probes can read/assert its value, same idiom as shop_expanded_index
var shop_expanded_index := -1 # tapped tile, if any; exposed so probes can assert on it
var shop_sell_mode := false # issue 60: Sell/Buy toggle on the Shop drawer —
	# exposed so probes can assert on it, same as shop_expanded_index above
var sell_expanded_kind := "" # "" (none), "piece", "captured", "item", "artefact"
var sell_expanded_index := -1 # index into the matching g.stock/g.captured/
	# g.items/g.artefacts array — a SEPARATE counter from shop_expanded_index
	# since Sell mode indexes held entries, not g.shop_stock slots
const SHOP_TILE := 46.0 # matches the pool-strip icon size (hud.gd) for visual rhythm
var tariff_panel: PanelContainer # tariff detail overlay
var buff_panel: PanelContainer # generic choice-pick modal (issue 41); named
	# for its first caller, the Buff Box sub-pick — never renamed, since it's
	# just the panel field, not a Buff-specific behaviour


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


## Tier-1 pause parity (user ruling 2026-09-04: the gap was an oversight, not
## a lever). Reading the tariff list or a merge confirm pauses the clock at
## Tier 1 exactly like the menu, Shop, drawers and preview already do. Box
## Pick stays deliberately excluded — GDD: "decisive picks rewarded,
## indecision punished" — that one IS a difficulty lever.
func pause_modal_open() -> bool:
	return (is_instance_valid(tariff_panel) and tariff_panel.visible) \
		or (is_instance_valid(merge_panel) and merge_panel.visible)


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
	_end_of_run_on_top()
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
	var stats := "Score %d · Deepest wave %d\nKings %d · King Abilities seen %d\nPieces lost %d · Enemies slain %d" \
		% [g.score, g.wave, g.kings_defeated, g.tariffs_seen.size(), g.lost_player, g.lost_enemy]
	if not g.king_ids_defeated.is_empty():
		var names: Array = g.king_ids_defeated.map(func(id: String) -> String: return Kings.name_of(id))
		stats += "\nDefeated: %s" % ", ".join(names)
	if rank > 0:
		stats += "\n" + ("Local rank #%d" % rank if rank <= 10 else "Off the local top 10")
	box.add_child(_overlay_label(stats, 19))
	# issue 75: show the seed so a good run can be replayed or shared. The BUILD
	# is shown beside it deliberately — a seed only reproduces within the build
	# it was rolled in, because any content change that shifts how many rolls
	# happen moves every downstream result (slices 47 and 48 each did exactly
	# that to a pinned-seed test). Without the version, a seed that stops
	# working after a patch looks like a bug rather than the expected behaviour.
	if g.next_seed != "":
		box.add_child(_overlay_label("seed  %s   ·   build %s"
			% [g.next_seed, ProjectSettings.get_setting("application/config/version", "dev")], 12))
	var restart := Button.new()
	restart.text = "Restart"
	restart.add_theme_font_size_override("font_size", 26)
	restart.pressed.connect(func() -> void: restart_pressed.emit())
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
## The run has ended, so nothing may sit above the screen that says so.
##
## `overlay` was the ONLY panel added to the HUD that never raised itself, while
## the pause menu, Shop, merge, reinforce, tariff and buff panels all call
## move_to_front() when they open. The HUD is a CanvasLayer, so last child wins:
## anything opened after the overlay was built drew on top of it.
##
## That was reachable at Tier 2+, where the clock does not stop for the pause
## menu or the Shop. Open either, let the clock run out, and GAME OVER rendered
## BEHIND an opaque panel — the player got a "Paused" screen with a Resume
## button on a run that was already over, and Resume is meaningless there.
##
## Raising the overlay and closing the pause menu makes the end of a run the
## last word, which is the one thing it has to be.
func _end_of_run_on_top() -> void:
	overlay.move_to_front()
	if g.hud != null and g.hud.game_menu != null:
		g.hud.game_menu.visible = false
		# The FLAG as well as the panel. game_menu_open gates input handling and
		# the clock-pause test in eight places; hiding the panel while leaving it
		# true would leave the run believing it is still paused by a menu the
		# player can no longer see.
		g.game_menu_open = false


func show_win_screen() -> void:
	_end_of_run_on_top()
	for c in overlay.get_children():
		c.queue_free()
	var center := CenterContainer.new()
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	box.add_child(_overlay_label("VICTORY", 32))
	var fallen: String = Kings.name_of(g.king_ids_defeated.back()) if not g.king_ids_defeated.is_empty() else "King"
	box.add_child(_overlay_label("The wave-%d King, %s, has fallen" % [g.wave, fallen], 18))
	var preview := 1 # GDD "ranking preview": where the score would land now
	for e in g.load_scores():
		if int(e.score) >= g.score:
			preview += 1
	box.add_child(_overlay_label(
		"Score %d · rank #%d if ended now\nWave %d · King Abilities seen %d\nPieces lost %d · Enemies slain %d" \
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
	# Raised for the same reason every other panel is. preview_panel and
	# box_panel were the only two added to the HUD that never did, so any panel
	# built later outranked them permanently — and `preview_open` deadens
	# _unhandled_input while the panel it refers to is hidden behind the Shop.
	preview_panel.move_to_front()
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


## The Shop drawer: docked at the right edge, covering ~90% of the screen
## (a sliver of board stays visible on the left, reading as a drawer rather
## than the old full-screen modal). No entrance animation — this codebase has
## no Control-tween precedent, a tween buys nothing acceptance criteria test
## for, and it made click probes racy against the panel's in-flight position;
## simplest is the instant show every other panel here already uses.
## Never scrolls — every slot in g.shop_stock renders as an icon tile with a
## price badge, grouped into four fixed zones (PIECES full-width top band;
## ARTEFACTS/ITEMS stacked lower-left; BOXES lower-right, full height) so the
## grid geometry holds regardless of which tile is expanded (shop-drawer-ui/08).
## Tapping a tile expands the fixed-height detail dock at the bottom with its
## name, effect text and Buy; buy rows emit an index and game.gd reopens for
## fresh SOLD/affordability state.
func show_shop() -> void:
	var was_open := shop_panel != null and shop_panel.visible
	if shop_panel:
		shop_panel.queue_free()
	if not was_open:
		shop_expanded_index = -1 # fresh open always starts collapsed
		shop_sell_mode = false # fresh open always starts in Buy mode
		sell_expanded_kind = ""
		sell_expanded_index = -1

	var vp: Vector2 = g.get_viewport_rect().size
	var draw_w := roundi(vp.x * 0.9) # "~90% of the screen up to full"
	shop_panel = Panel.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.97)
	shop_panel.add_theme_stylebox_override("panel", bg)
	shop_panel.position = Vector2(vp.x - draw_w, 0)
	shop_panel.size = Vector2(draw_w, vp.y)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	shop_panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "SHOP"
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)
	var sub := Label.new()
	# issue 64: buying/selling/converting are all free of the Action cost now
	sub.text = ("$%d — sell for 50%%, or convert Captured to Stock" % g.gold) \
		if shop_sell_mode else ("$%d — no Action cost" % g.gold)
	sub.add_theme_font_size_override("font_size", 12)
	sub.modulate = Color(1, 1, 1, 0.75)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(sub)
	if g._held("jet-fuel-vial") and not shop_sell_mode: # issue 52: only while
		# held (user ruling — a Shop control, not part of the in-run Activate
		# section) and only in Buy mode — Restock rerolls g.shop_stock, which
		# Sell mode doesn't even render
		var restock := Button.new()
		restock.text = "Restock ($20)"
		restock.add_theme_font_size_override("font_size", 13)
		restock.disabled = not g._jet_fuel_restock_available()
		restock.pressed.connect(func() -> void: shop_restock_pressed.emit())
		header.add_child(restock)
	var mode_btn := Button.new() # issue 60: Sell/Buy toggle — a distinct mode
		# rather than a parallel list, so Sell can never be confused with Buy
		# on the deliberately no-scroll drawer (issue 60's own UI note)
	mode_btn.text = "Buy" if shop_sell_mode else "Sell"
	mode_btn.add_theme_font_size_override("font_size", 14)
	mode_btn.pressed.connect(func() -> void:
		shop_sell_mode = not shop_sell_mode
		sell_expanded_kind = ""
		sell_expanded_index = -1
		show_shop())
	header.add_child(mode_btn)
	var close := Button.new()
	close.text = "Close"
	close.add_theme_font_size_override("font_size", 14)
	close.pressed.connect(func() -> void:
		shop_panel.visible = false
		shop_closed.emit())
	header.add_child(close)
	root.add_child(header)

	# issue 64: Lane B restock progress — Score banked toward the next
	# Score-driven restock (Lane A, every 5 Waves, needs no bar: it's a
	# guaranteed beat, not something to watch fill). Shown in both Buy and
	# Sell mode since it reflects Shop state, not the active mode.
	var lane_b_row := HBoxContainer.new()
	lane_b_row.add_theme_constant_override("separation", 6)
	var lane_b_label := Label.new()
	lane_b_label.text = "Next restock: %d / %d Score" \
		% [g.shop_lane_b_progress, Tuning.SHOP_LANE_B_SCORE]
	lane_b_label.add_theme_font_size_override("font_size", 11)
	lane_b_label.modulate = Color(1, 1, 1, 0.7)
	lane_b_row.add_child(lane_b_label)
	root.add_child(lane_b_row)
	shop_lane_b_bar = ProgressBar.new()
	shop_lane_b_bar.min_value = 0
	shop_lane_b_bar.max_value = Tuning.SHOP_LANE_B_SCORE
	shop_lane_b_bar.value = g.shop_lane_b_progress
	shop_lane_b_bar.show_percentage = false
	shop_lane_b_bar.custom_minimum_size = Vector2(0, 10)
	root.add_child(shop_lane_b_bar)

	var pieces_band := VBoxContainer.new()
	pieces_band.add_theme_constant_override("separation", 4)
	var lower := HBoxContainer.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.add_theme_constant_override("separation", 8)
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 1.15
	lower.add_child(left_col)
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 0.85
	lower.add_child(right_col)

	if shop_sell_mode:
		# same 4-zone geometry as Buy (issue 60): STOCK replaces the PIECES
		# band, ARTEFACTS/ITEMS stay put (now held entries, not shop slots),
		# CAPTURED replaces BOXES (nothing in a Box is ever sellable)
		pieces_band.add_child(_shop_zone_label("STOCK"))
		var pieces_row := HBoxContainer.new()
		pieces_row.alignment = BoxContainer.ALIGNMENT_CENTER
		pieces_row.add_theme_constant_override("separation", 4)
		for i in g.stock.size():
			pieces_row.add_child(_sell_tile("piece", i))
		pieces_band.add_child(pieces_row)
		left_col.add_child(_sell_sub_zone("ARTEFACTS", "artefact", g.artefacts.size()))
		left_col.add_child(_sell_sub_zone("ITEMS", "item", g.items.size()))
		right_col.add_child(_sell_sub_zone("CAPTURED", "captured", g.captured.size()))
	else:
		var by_kind := {"piece": [], "artefact": [], "item": [], "box": []}
		for i in g.shop_stock.size():
			by_kind[g.shop_stock[i].kind].append(i)
		pieces_band.add_child(_shop_zone_label("PIECES"))
		var pieces_row := HBoxContainer.new()
		pieces_row.alignment = BoxContainer.ALIGNMENT_CENTER
		pieces_row.add_theme_constant_override("separation", 4)
		for i in by_kind.piece:
			pieces_row.add_child(_shop_tile(i))
		pieces_band.add_child(pieces_row)
		left_col.add_child(_shop_sub_zone("ARTEFACTS", by_kind.artefact))
		left_col.add_child(_shop_sub_zone("ITEMS", by_kind.item))
		right_col.add_child(_shop_sub_zone("BOXES", by_kind.box))
	root.add_child(pieces_band)
	root.add_child(lower)

	_shop_dock = PanelContainer.new()
	_shop_dock.custom_minimum_size = Vector2(0, 92)
	var dock_bg := StyleBoxFlat.new()
	dock_bg.bg_color = Color(0.14, 0.14, 0.17, 1.0)
	_shop_dock.add_theme_stylebox_override("panel", dock_bg)
	_fill_shop_dock()
	root.add_child(_shop_dock)

	g.hud.add_child(shop_panel)
	shop_panel.move_to_front()


## The dock's content for the current expanded tile (or the hint). Called
## from show_shop and from every tile tap; the tiles themselves are untouched
## by a tap, so nothing else needs rebuilding. free(), not queue_free(): the
## tap comes from a TILE, never from a dock child, so nothing here is mid-signal,
## and an immediately-freed dock can't be found by a same-frame probe.
func _fill_shop_dock() -> void:
	for c in _shop_dock.get_children():
		c.free()
	if shop_sell_mode and sell_expanded_index >= 0 \
			and sell_expanded_index < _sell_entries(sell_expanded_kind).size():
		_shop_dock.add_child(_sell_detail(sell_expanded_kind, sell_expanded_index))
	elif not shop_sell_mode and shop_expanded_index >= 0 and shop_expanded_index < g.shop_stock.size():
		_shop_dock.add_child(_shop_detail(shop_expanded_index))
	else:
		var hint := Label.new()
		hint.text = "Tap a tile for details"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hint.modulate = Color(1, 1, 1, 0.5)
		hint.add_theme_font_size_override("font_size", 13)
		_shop_dock.add_child(hint)


func _shop_zone_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.modulate = Color(1, 1, 1, 0.6)
	return l


## A labeled, centered grid of tiles that expands to fill its share of the
## lower block's height — this is what gives ARTEFACTS/ITEMS their upper/lower
## halves and BOXES the full height of the lower-right (money-and-shop/04
## kept the logic; shop-drawer-ui/08 is only the geometry).
func _shop_sub_zone(title_text: String, indices: Array) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 4)
	wrap.add_child(_shop_zone_label(title_text))
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for i in indices:
		grid.add_child(_shop_tile(i))
	center.add_child(grid)
	wrap.add_child(center)
	return wrap


## Icon or price-badge glyph for a slot — a Texture2D when painted art exists,
## otherwise a fallback character (mirrors hud.gd's pool-strip glyph fallback
## and show_box's per-kind glyphs, so the vocabulary matches across the app).
func _shop_icon(slot: Dictionary) -> Variant:
	match slot.kind:
		"piece":
			return g.piece_tex(slot.key) if g.textures.has(slot.key) else g.defs[slot.key].glyph
		"item":
			return g.item_icons[slot.key] if g.item_icons.has(slot.key) else "✦"
		"artefact":
			return "◈"
		_: # box — glyph by the box's theme (issue 47: piece/artefact/item)
			return {"piece": "♟", "artefact": "◈", "item": "⚔"}.get(slot.key, "📦")


## One icon tile with a price badge; sold tiles grey out but keep their slot
## meta.shop_index (index into g.shop_stock) exists for the click probes.
func _shop_tile(index: int) -> Button:
	var slot: Dictionary = g.shop_stock[index]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(SHOP_TILE, SHOP_TILE)
	btn.clip_text = true # multi-char glyph fallbacks ("vRg") must never grow the tile
	btn.set_meta("shop_index", index)
	var icon: Variant = _shop_icon(slot)
	if icon is Texture2D:
		btn.icon = icon
		btn.expand_icon = true
	else:
		btn.text = str(icon)
		btn.add_theme_font_size_override("font_size", 16)
	btn.tooltip_text = Shop.display_name(g, slot)
	var rarity := Shop.rarity_of(slot) # issue 20: rarity legibility — tints the tile
	if rarity != "":
		btn.self_modulate = Tuning.ARTEFACT_RARITY_COLOR[rarity]
	if slot.sold:
		btn.modulate = Color(1, 1, 1, 0.4) # greys out, stays in place — never removed
	var price := Label.new()
	price.text = "$%d" % Shop.price(g, slot)
	price.add_theme_font_size_override("font_size", 10)
	price.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	price.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	price.add_theme_constant_override("outline_size", 3)
	price.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	price.offset_left = -28
	price.offset_top = -14
	btn.add_child(price)
	btn.pressed.connect(func() -> void:
		shop_expanded_index = -1 if shop_expanded_index == index else index
		_fill_shop_dock())
	return btn


## The expanded tile: icon, name, effect text (when the catalog has one) and
## Buy/SOLD, docked at a fixed height so expanding never reflows the grids.
func _shop_detail(index: int) -> Control:
	var slot: Dictionary = g.shop_stock[index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon: Variant = _shop_icon(slot)
	if icon is Texture2D:
		var tex := TextureRect.new()
		tex.texture = icon
		tex.custom_minimum_size = Vector2(56, 56)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tex)
	else:
		var glyph := Label.new()
		glyph.text = str(icon)
		glyph.add_theme_font_size_override("font_size", 34)
		glyph.custom_minimum_size = Vector2(56, 56)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(glyph)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	var name := Label.new()
	name.text = "%s — $%d" % [Shop.display_name(g, slot), Shop.price(g, slot)]
	name.add_theme_font_size_override("font_size", 16)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(name)
	var rarity := Shop.rarity_of(slot) # issue 20: rarity legibility
	if rarity != "":
		var rlabel := Label.new()
		rlabel.text = rarity
		rlabel.add_theme_font_size_override("font_size", 12)
		rlabel.add_theme_color_override("font_color", Tuning.ARTEFACT_RARITY_COLOR[rarity])
		info.add_child(rlabel)
	var desc_text := Shop.description(slot)
	if desc_text != "":
		var desc := Label.new()
		desc.text = desc_text
		desc.add_theme_font_size_override("font_size", 12)
		desc.modulate = Color(1, 1, 1, 0.8)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc)
	# All-Seeing Eye Contact Lens (49): "Boxes reveal their contents before
	# you buy or choose them" — X-ray gated on holding the Artefact, not on
	# the roll (issue 47 already rolls every Box unconditionally at stock
	# time, so there is nothing left to gate but the display).
	if slot.kind == "box" and g._artefact_count("all-seeing-eye-contact-lens") > 0:
		var reveal := Label.new()
		reveal.text = "Contains: %s" % Box.contents_names(slot.contents)
		reveal.add_theme_font_size_override("font_size", 10)
		reveal.modulate = Color(1, 1, 1, 0.65)
		reveal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(reveal)
	row.add_child(info)

	var buy := Button.new()
	buy.text = "SOLD" if slot.sold else "Buy"
	buy.disabled = not Shop.can_buy(g, slot)
	buy.add_theme_font_size_override("font_size", 15)
	buy.pressed.connect(func() -> void: shop_buy_pressed.emit(index))
	row.add_child(buy)
	return row


# --- Sell / Convert mode (issue 60) — same tile/sub-zone/detail-dock shapes
# as Buy above, reading held entries (g.stock/g.captured/g.items/g.artefacts)
# instead of g.shop_stock slots. `kind`: "piece" (Stock), "captured"
# (Captured Stock), "item", "artefact".

func _sell_entries(kind: String) -> Array:
	return Shop.held_entries(g, kind)


func _sell_id(kind: String, entry: Variant) -> String:
	if kind == "item" or kind == "artefact":
		return str(entry.key)
	return entry if entry is String else entry.id


## Icon or price-badge glyph — mirrors _shop_icon's per-kind vocabulary.
func _sell_icon(kind: String, id: String) -> Variant:
	match kind:
		"piece", "captured":
			return g.piece_tex(id) if g.textures.has(id) else g.defs[id].glyph
		"item":
			return g.item_icons[id] if g.item_icons.has(id) else "✦"
		_: # "artefact"
			return "◈"


func _sell_name(kind: String, entry: Variant, id: String) -> String:
	if kind == "item" or kind == "artefact":
		return str(entry.name)
	return str(g.defs[id].name)


## One icon tile with a sell-price badge; meta.sell_kind/sell_index (into the
## matching held-entry array) exist for the click probes, same role
## meta.shop_index plays for _shop_tile.
func _sell_tile(kind: String, index: int) -> Button:
	var entry: Variant = _sell_entries(kind)[index]
	var id := _sell_id(kind, entry)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(SHOP_TILE, SHOP_TILE)
	btn.clip_text = true
	btn.set_meta("sell_kind", kind)
	btn.set_meta("sell_index", index)
	var icon: Variant = _sell_icon(kind, id)
	if icon is Texture2D:
		btn.icon = icon
		btn.expand_icon = true
	else:
		btn.text = str(icon)
		btn.add_theme_font_size_override("font_size", 16)
	btn.tooltip_text = _sell_name(kind, entry, id)
	if kind == "artefact":
		var rarity := str(entry.get("rarity", "")) # issue 20: rarity legibility
		if rarity != "":
			btn.self_modulate = Tuning.ARTEFACT_RARITY_COLOR[rarity]
	if kind == "captured": # a visual tell distinct from ordinary Stock
		btn.modulate = Color(1.0, 0.85, 0.6)
	var price := Label.new()
	price.text = "+$%d" % Shop.sell_payout(g, kind, entry)
	price.add_theme_font_size_override("font_size", 10)
	price.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	price.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	price.add_theme_constant_override("outline_size", 3)
	price.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	price.offset_left = -32
	price.offset_top = -14
	btn.add_child(price)
	btn.pressed.connect(func() -> void:
		if sell_expanded_kind == kind and sell_expanded_index == index:
			sell_expanded_kind = ""
			sell_expanded_index = -1
		else:
			sell_expanded_kind = kind
			sell_expanded_index = index
		_fill_shop_dock())
	return btn


## Labeled, centered grid of sell tiles for one kind — same geometry as
## _shop_sub_zone (a held-entry index range instead of a slot index list).
func _sell_sub_zone(title_text: String, kind: String, count: int) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 4)
	wrap.add_child(_shop_zone_label(title_text))
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for i in count:
		grid.add_child(_sell_tile(kind, i))
	center.add_child(grid)
	wrap.add_child(center)
	return wrap


## The expanded tile: icon, name, sell price, and Sell — plus, for a
## Captured Stock entry only, a second Convert button (the only way a
## captured piece becomes deployable again — see game.gd._convert_captured).
func _sell_detail(kind: String, index: int) -> Control:
	var entry: Variant = _sell_entries(kind)[index]
	var id := _sell_id(kind, entry)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon: Variant = _sell_icon(kind, id)
	if icon is Texture2D:
		var tex := TextureRect.new()
		tex.texture = icon
		tex.custom_minimum_size = Vector2(56, 56)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tex)
	else:
		var glyph := Label.new()
		glyph.text = str(icon)
		glyph.add_theme_font_size_override("font_size", 34)
		glyph.custom_minimum_size = Vector2(56, 56)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(glyph)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	var name := Label.new()
	name.text = "%s — sell +$%d" % [_sell_name(kind, entry, id), Shop.sell_payout(g, kind, entry)]
	name.add_theme_font_size_override("font_size", 16)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(name)
	if kind == "captured":
		var tag := Label.new()
		tag.text = "Captured — convert to Stock, or sell"
		tag.add_theme_font_size_override("font_size", 12)
		tag.modulate = Color(1.0, 0.85, 0.6)
		info.add_child(tag)
	elif kind == "artefact":
		var rarity := str(entry.get("rarity", ""))
		if rarity != "":
			var rlabel := Label.new()
			rlabel.text = rarity
			rlabel.add_theme_font_size_override("font_size", 12)
			rlabel.add_theme_color_override("font_color", Tuning.ARTEFACT_RARITY_COLOR[rarity])
			info.add_child(rlabel)
	if kind == "item" or kind == "artefact":
		var desc_text := str(entry.get("description", ""))
		if desc_text != "":
			var desc := Label.new()
			desc.text = desc_text
			desc.add_theme_font_size_override("font_size", 12)
			desc.modulate = Color(1, 1, 1, 0.8)
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.add_child(desc)
	row.add_child(info)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	if kind == "captured":
		var convert := Button.new()
		convert.text = "Convert ($%d)" % Shop.convert_price(g, entry) # issue 97
		convert.disabled = not Shop.can_convert(g, entry)
		convert.add_theme_font_size_override("font_size", 13)
		convert.pressed.connect(func() -> void:
			sell_expanded_kind = ""
			sell_expanded_index = -1
			shop_convert_pressed.emit(entry))
		buttons.add_child(convert)
	var sell := Button.new()
	sell.text = "Sell (+$%d)" % Shop.sell_payout(g, kind, entry)
	sell.disabled = not Shop.can_sell(g, kind, entry)
	sell.add_theme_font_size_override("font_size", 13)
	sell.pressed.connect(func() -> void:
		sell_expanded_kind = ""
		sell_expanded_index = -1
		shop_sell_pressed.emit(kind, entry))
	buttons.add_child(sell)
	row.add_child(buttons)
	return row


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
	title.text = "Active King Abilities"
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


## Generic "choose 1 of N, then continue" modal (issue 41). `offers` are
## Dictionaries with `label` (button text) and `value` (emitted via
## `choice_chosen` when picked) — this modal doesn't know what a caller does
## with the pick, only how to show options and report back. First caller was
## the Buff Box sub-pick (pick 1 of 3 Piece Buffs, then the board takes over
## for targeting); cancelling leaves the triggering effect unspent, so there
## is no consolation here — same for every caller after it.
func show_choice_pick(header: String, offers: Array, cancel_text: String) -> void:
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
	head.text = header
	head.add_theme_font_size_override("font_size", 22)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	for o in offers:
		var btn := Button.new()
		btn.text = str(o.label)
		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size = Vector2(420, 0)
		var value = o.value
		btn.pressed.connect(func() -> void: choice_chosen.emit(value))
		box.add_child(btn)
	var cancel := Button.new()
	cancel.text = cancel_text
	cancel.pressed.connect(func() -> void: choice_pick_cancelled.emit())
	box.add_child(cancel)
	g.hud.add_child(buff_panel)
	buff_panel.move_to_front()


func hide_choice_pick() -> void:
	if buff_panel:
		buff_panel.queue_free()
		buff_panel = null


func show_box(options: Array) -> void:
	# Above everything, like every other panel. Without this a Box could open
	# behind the Shop — reachable on any restock wave that also queues a Bounty
	# box — while box_open gates every input path in the game. The player saw
	# the Shop, could not act, and the clock kept draining, because Box Pick is
	# deliberately excluded from the tier pause list.
	box_panel.move_to_front()
	var picks: int = 1 + g.box_picks_left # Nostradamus Mad Libs stacks on
		# top of a Box's own native picks (Huge = 2 — issue 47)
	var title := "📦 %s %s Box — pick %d:" % [
		str(g.box_size).capitalize(), str(g.box_only_kind).capitalize(), picks]
	var box := _box_vbox(title)
	for opt in options:
		var b := Button.new()
		var header := ""
		match opt.kind:
			"piece":
				header = "♟ %s — Piece · joins Stock" % opt.name
			"item":
				header = "⚔ %s — Item · %s · single use" % [opt.name, opt.tier]
			"artefact":
				var rarity: String = str(opt.payload.get("rarity", ""))
				header = "◈ %s — Artefact%s · passive, rest of the run" \
					% [opt.name, (" · %s" % rarity) if rarity != "" else ""]
		b.text = header + "\n" + opt.description
		if opt.kind == "item" and g.item_icons.has(opt.payload.key):
			b.icon = g.item_icons[opt.payload.key]
			b.add_theme_constant_override("icon_max_width", 30)
		if opt.kind == "artefact": # issue 20: rarity legibility
			var rarity: String = str(opt.payload.get("rarity", ""))
			if rarity != "":
				b.add_theme_color_override("font_color", Tuning.ARTEFACT_RARITY_COLOR[rarity])
		b.add_theme_font_size_override("font_size", 16)
		b.custom_minimum_size = Vector2(420, 0)
		b.pressed.connect(func() -> void: box_chosen.emit(opt))
		box.add_child(b)
	if g.box_rerolls_left > 0: # Bible Gag Reel Scroll / Snowden's Rubik's
		# Cube (issue 46) — only while the per-Box budget is above zero
		var reroll := Button.new()
		reroll.text = "Reroll (%d left)" % g.box_rerolls_left
		reroll.pressed.connect(func() -> void: box_reroll_pressed.emit())
		box.add_child(reroll)
	var skip := Button.new()
	skip.text = "Skip (+%d score)" % Tuning.BOX_SKIP_CONSOLATION
	skip.pressed.connect(func() -> void: box_skipped.emit())
	box.add_child(skip)
