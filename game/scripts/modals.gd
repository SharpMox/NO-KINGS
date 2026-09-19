## Modals and overlays — box pick, merge confirm, piece preview, tariff list,
## reinforcement shop, win/end screens. Built in code as a CanvasLayer child
## of the Game node (split out of game.gd); the panels themselves parent into
## the HUD layer so stacking (and the click probes) behave exactly as before.
## Signals up, calls down: buttons emit intents handled by game.gd; builders
## only read game state via `g`.
##
## ONE deliberate exception (NO-37, documented rather than routed): the in-game
## menu's close path writes `g.game_menu_open = false` as well as hiding the
## panel. The flag gates input handling and the clock-pause test in eight
## places, so hiding the panel while leaving it true would leave the run
## believing it is paused by a menu the player can no longer see. Routing it as
## a signal game.gd handles would be the pure form; it is not worth a round trip
## for a flag whose only correct value at that instant is false. Do not treat
## this as licence for further writes -- everything else here still only reads.

extends Node

const Tuning := preload("res://scripts/tuning.gd")
const Shop := preload("res://scripts/shop.gd")
const Kings := preload("res://data/kings.gd")
const Box := preload("res://scripts/box.gd")
const ItemLogic := preload("res://scripts/item_logic.gd")

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
signal box_sell_pressed(entry: Dictionary) # NO-38: sell a held Item from inside an Item Box
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
var _shop_tween: Tween # NO-118: the in-flight slide, if any — killed before a
	# new one starts (a tween on a freed node throws, and show_shop() frees
	# shop_panel on every fresh open)
var shop_rest: Vector2 # NO-118: shop_panel's rest position, cached the same
	# way hud.gd caches drawer_rest — read-only for probes that need to know
	# when the open slide has actually settled rather than duplicating the
	# vp.x - draw_w formula themselves
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
## NO-119: PIECES/STOCK is a wrapping grid, not a fixed-width row, now that
## its tiles are Tuning.OFFBOARD_ICON (72) rather than the old 46 — Buy mode
## holds up to 8 (Shop.ROWS.piece), but Sell mode's row is the player's whole
## live Stock (unbounded), and either one would overflow a single-row
## HBoxContainer well before it overflowed this column's width. Arithmetic,
## not taste: 5 x 72 + 4 x 4 = 376 fits the drawer's ~412px content width
## (draw_w 432 minus the 10px margins each side); 6 would need 452. NO-132
## folds this into the site-wide standard — Tuning.OFFBOARD_GRID_COLS is the
## same 5, so the band no longer carries its own agreeing constant.
##
## NO-132: the lower band's ARTEFACTS/ITEMS (left_col) and BOXES/CAPTURED
## (right_col) split the same 412px on `lower`'s 1.15 / 0.85 stretch ratio,
## less its own 8px separation: left ~232px, right ~172px. At the same 4px
## separation, Tuning.grid_cols gives left_col 3 columns (76*3-4=224 <= 232)
## and right_col 2 (76*2-4=148 <= 172; 76*3-4=224 does not fit). Neither
## reaches the 5-column standard — the drawer is only 90% of the 480px
## screen, and this band is one of two side by side in it.
const SHOP_SUBZONE_LEFT_W := 232.0
const SHOP_SUBZONE_RIGHT_W := 172.0
const SHOP_SUBZONE_SEP := 4.0
var king_ability_panel: PanelContainer # tariff detail overlay
var buff_panel: PanelContainer # generic choice-pick modal (issue 41); named
	# for its first caller, the Buff Box sub-pick — never renamed, since it's
	# just the panel field, not a Buff-specific behaviour
## NO-133: the Box pick rebuilt as a select-then-confirm icon grid, same shape
## as the Shop's own tiles (shop_expanded_index / _shop_dock above) — a tap
## selects a tile and fills the dock below with its description; it takes a
## second tap on the dock's Pick button to actually commit.
var box_expanded_index := -1 # which offered tile is selected, -1 = none
var _box_options: Array = [] # the options show_box was last called with, so
	# _box_tile/_box_detail can read by index without re-threading the array
	# through every closure the way _shop_tile reads g.shop_stock directly
var _box_dock: PanelContainer # refilled on a tile tap — same idiom as _shop_dock


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
## a lever). Reading the tariff list, a merge confirm or the reinforcement pick
## pauses the clock at Tier 1 exactly like the menu, Shop, drawers and preview
## already do. The reinforcement pick was the third instance of the same
## oversight — a full-rect panel whose only state is `visible`, so nothing
## mirrored it into a `*_open` flag the way preview_open/box_open do. Box Pick
## stays deliberately excluded — GDD: "decisive picks rewarded, indecision
## punished" — that one IS a difficulty lever.
func pause_modal_open() -> bool:
	return (is_instance_valid(king_ability_panel) and king_ability_panel.visible) \
		or (is_instance_valid(merge_panel) and merge_panel.visible) \
		or (is_instance_valid(reinforce_panel) and reinforce_panel.visible)


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
		% [g.score, g.wave, g.kings_defeated, g.king_abilities_seen.size(), g.lost_player, g.lost_enemy]
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
		% [g.score, preview, g.wave, g.king_abilities_seen.size(), g.lost_player, g.lost_enemy], 19))
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


## `king_id` (NO-83): a King whose Power draws on the King Ability catalogue —
## only Donald Trump does (kings.gd) — lists the Abilities in force under his
## diagram, the same rows the ⚠ overlay shows.
func show_preview(id: String, king_id := "") -> void:
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

	var kit: Dictionary = Kings.kit_of(king_id)
	if kit.has("power_catalog_key") or kit.has("power_catalog_escalation"):
		var head := Label.new()
		head.text = "%s — King Abilities in force" % str(kit.get("power_name", ""))
		head.add_theme_font_size_override("font_size", 15)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(head)
		_add_king_ability_rows(box, 14, 12)

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
	if _shop_tween: # NO-118: kill before the panel it targets is freed below
		_shop_tween.kill()
		_shop_tween = null
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
	shop_rest = shop_panel.position

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
	close.pressed.connect(close_shop) # NO-118: same path an outside click uses (game.gd)
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
		pieces_band.add_child(_piece_grid(func(i: int) -> Button: return _sell_tile("piece", i),
			g.stock.size()))
		var left_cols := Tuning.grid_cols(SHOP_SUBZONE_LEFT_W, SHOP_SUBZONE_SEP) # NO-132
		var right_cols := Tuning.grid_cols(SHOP_SUBZONE_RIGHT_W, SHOP_SUBZONE_SEP) # NO-132
		left_col.add_child(_sell_sub_zone("ARTEFACTS", "artefact", g.artefacts.size(), left_cols))
		left_col.add_child(_sell_sub_zone("ITEMS", "item", g.items.size(), left_cols))
		right_col.add_child(_sell_sub_zone("CAPTURED", "captured", g.captured.size(), right_cols))
	else:
		var by_kind := {"piece": [], "artefact": [], "item": [], "box": []}
		for i in g.shop_stock.size():
			by_kind[g.shop_stock[i].kind].append(i)
		pieces_band.add_child(_shop_zone_label("PIECES"))
		pieces_band.add_child(_piece_grid(_shop_tile, by_kind.piece))
		var left_cols := Tuning.grid_cols(SHOP_SUBZONE_LEFT_W, SHOP_SUBZONE_SEP) # NO-132
		var right_cols := Tuning.grid_cols(SHOP_SUBZONE_RIGHT_W, SHOP_SUBZONE_SEP) # NO-132
		left_col.add_child(_shop_sub_zone("ARTEFACTS", by_kind.artefact, left_cols))
		left_col.add_child(_shop_sub_zone("ITEMS", by_kind.item, left_cols))
		right_col.add_child(_shop_sub_zone("BOXES", by_kind.box, right_cols))
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
	if not was_open: # NO-118: a rebuild while already open (mode toggle, Buy,
		# Restock, ...) reuses the fresh panel at rest with no re-animation —
		# it never left the screen.
		_slide_shop(true)


## NO-118: slides shop_panel between its rest position (vp.x - draw_w, 0) and
## fully off-screen to the right, swift in-out. `opening` sets the direction;
## on a close, shop_panel is only hidden once the tween finishes. Skips the
## tween in autoplay/headless-with-animations-off, same seam every other HUD
## animation is gated on (see hud.gd's _slide_drawer).
##
## NO-118 fix (found via hud.gd's own drawers): `visible` stays true for the
## whole close slide, and a visible Control with the default
## MOUSE_FILTER_STOP still absorbs any click in its rect via Godot's own GUI
## picking before game.gd's _unhandled_input ever sees it — a board tap
## landing where the Shop used to sit was silently eaten for up to
## PANEL_SLIDE_S after "closing". IGNORE the instant a close starts; restore
## STOP the instant an open starts, so an open Shop still blocks the board.
##
## Godot does not cascade a parent's IGNORE to its children, so shop_panel's
## own descendants (its ScrollContainers, tiles, ...) need the same treatment
## — unlike hud.gd's drawers, this needs no save/restore: show_shop() frees
## this exact panel and builds a fresh one (with fresh default filters) on
## every subsequent open, so there is nothing to restore it TO.
func _slide_shop(opening: bool) -> void:
	if _shop_tween:
		_shop_tween.kill()
		_shop_tween = null
	var rest: Vector2 = shop_panel.position # already Vector2(vp.x - draw_w, 0)
	var hidden := rest + Vector2(shop_panel.size.x, 0) # off the right edge
	var filter := Control.MOUSE_FILTER_STOP if opening else Control.MOUSE_FILTER_IGNORE
	shop_panel.mouse_filter = filter
	if not opening:
		# Descendants are set to IGNORE here but never explicitly restored on
		# open — that's only safe because show_shop() frees this exact
		# shop_panel and builds a fresh one (default filters) on every
		# subsequent open. If the Shop is ever changed to reuse a panel
		# instead of rebuilding it (the kind of change modals.gd's own
		# _shop_dock comment describes doing for the tile-tap case), this
		# needs the same save/restore hud.gd's _set_drawer_clickable does,
		# or every control in here stays permanently unclickable.
		for c in shop_panel.find_children("*", "Control", true, false):
			(c as Control).mouse_filter = filter
	if g.autoplay or not g.animations_on:
		if not opening:
			shop_panel.visible = false
		return
	if opening:
		shop_panel.position = hidden
	_shop_tween = shop_panel.create_tween()
	_shop_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_shop_tween.tween_property(shop_panel, "position", rest if opening else hidden, Tuning.PANEL_SLIDE_S)
	if not opening:
		_shop_tween.finished.connect(func() -> void: shop_panel.visible = false)


## NO-118: the one path that closes the Shop — the Close button and an
## outside click (game.gd's _unhandled_input) both call this, so
## shop_closed always fires and whatever listens to it (game.gd:4121:
## _refresh()) still runs, whichever of the two triggered the close.
func close_shop() -> void:
	_slide_shop(false)
	shop_closed.emit()


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


## NO-119: the PIECES/STOCK band's own centered, wrapping grid —
## Tuning.OFFBOARD_GRID_COLS wide, built from whatever `tile_of` returns (a
## _shop_tile or _sell_tile closure) for each of `indices` (an Array of
## shop-slot indices, or a plain count for Sell mode's `for i in
## g.stock.size()`). Kept separate from _shop_sub_zone below: that one
## expands to fill a fixed-height column, this one sits in a top band sized
## to its own content.
##
## NO-132: custom_minimum_size.x is forced to the FULL row's width (see
## Tuning.grid_row_w) before the CenterContainer sees it, so fewer than
## Tuning.OFFBOARD_GRID_COLS tiles still start at column 1 — a 3-piece row
## sits at columns 1-3, not centered across the whole band.
func _piece_grid(tile_of: Callable, indices) -> CenterContainer:
	var center := CenterContainer.new()
	var grid := GridContainer.new()
	grid.columns = Tuning.OFFBOARD_GRID_COLS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.custom_minimum_size.x = Tuning.grid_row_w(Tuning.OFFBOARD_GRID_COLS, 4.0) # NO-132
	for i in indices:
		grid.add_child(tile_of.call(i))
	center.add_child(grid)
	return center


## A labeled, centered grid of tiles that expands to fill its share of the
## lower block's height — this is what gives ARTEFACTS/ITEMS their upper/lower
## halves and BOXES the full height of the lower-right (money-and-shop/04
## kept the logic; shop-drawer-ui/08 is only the geometry).
##
## NO-132: `cols` is the caller's Tuning.grid_cols() result for its own share
## of the lower band (SHOP_SUBZONE_LEFT_W/RIGHT_W above) — left_col and
## right_col differ, so this can no longer hardcode one column count for
## both. custom_minimum_size.x reserves the full `cols`-wide row the same way
## _piece_grid does, so a short row aligns instead of centering itself.
func _shop_sub_zone(title_text: String, indices: Array, cols: int) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 4)
	wrap.add_child(_shop_zone_label(title_text))
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", SHOP_SUBZONE_SEP)
	grid.add_theme_constant_override("v_separation", SHOP_SUBZONE_SEP)
	grid.custom_minimum_size.x = Tuning.grid_row_w(cols, SHOP_SUBZONE_SEP) # NO-132
	for i in indices:
		grid.add_child(_shop_tile(i))
	center.add_child(grid)
	wrap.add_child(center)
	return wrap


## Icon for a slot. Artefacts and Boxes always resolve to a Texture2D now
## (NO-17: real art or the shared placeholder); pieces and items still fall back
## to a glyph character when unpainted, which mirrors hud.gd's pool-strip
## fallback so the vocabulary matches across the app.
func _shop_icon(slot: Dictionary) -> Variant:
	match slot.kind:
		"piece":
			return g.piece_tex(slot.key) if g.textures.has(slot.key) else g.defs[slot.key].glyph
		"item":
			return g.item_icons[slot.key] if g.item_icons.has(slot.key) else "✦"
		"artefact":
			# NO-17: painted art where it exists, the shared placeholder where it
			# does not. artefact_tex never returns null, so an artefact tile is
			# the same size whether or not its art has landed — which is the
			# whole point of the placeholder: the Shop must not reflow as art
			# arrives one file at a time.
			return g.artefact_tex(slot.key)
		_: # box — no painted art for any of the 9 yet
			return g.art_placeholder if g.art_placeholder != null \
				else {"piece": "♟", "artefact": "◈", "item": "⚔"}.get(slot.key, "▣")


## NO-119: true when `_shop_icon`'s Texture2D for this slot is the shared
## placeholder rather than painted art. Boxes always are — no painted Box
## art exists yet (Box.gd); an Artefact is only when its key has landed no
## art. Pieces/Items never reach here Texture2D-false: their fallback is a
## glyph String, not a shared placeholder image.
func _shop_icon_is_placeholder(slot: Dictionary) -> bool:
	match slot.kind:
		"artefact":
			return not g.artefact_icons.has(slot.key)
		_:
			return slot.kind != "piece" and slot.kind != "item" # box


## One icon tile with a price badge; sold tiles grey out but keep their slot
## meta.shop_index (index into g.shop_stock) exists for the click probes.
func _shop_tile(index: int) -> Button:
	var slot: Dictionary = g.shop_stock[index]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(Tuning.OFFBOARD_ICON, Tuning.OFFBOARD_ICON) # NO-119
	btn.clip_text = true # multi-char glyph fallbacks ("vRg") must never grow the tile
	btn.set_meta("shop_index", index)
	var icon: Variant = _shop_icon(slot)
	if icon is Texture2D:
		btn.icon = icon
		btn.expand_icon = true
		if _shop_icon_is_placeholder(slot): # NO-119: initials over the placeholder,
			# centred on the art rather than the corner (Max's call 2026-09-19) -
			# full-rect Label + centred alignment, same idiom as hud.gd's
			# _build_artefact_cell.
			var init_badge := Label.new()
			init_badge.text = g.initials_of(Shop.display_name(g, slot))
			init_badge.add_theme_font_size_override("font_size", 13)
			init_badge.add_theme_color_override("font_color", Color(1, 1, 1))
			init_badge.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
			init_badge.add_theme_constant_override("outline_size", 4)
			init_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE # must not eat the tap
			init_badge.set_anchors_preset(Control.PRESET_FULL_RECT)
			init_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			init_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			btn.add_child(init_badge)
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
	btn.custom_minimum_size = Vector2(Tuning.OFFBOARD_ICON, Tuning.OFFBOARD_ICON) # NO-119
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
## _shop_sub_zone (a held-entry index range instead of a slot index list),
## including its NO-132 `cols` parameter and row-width alignment fix.
func _sell_sub_zone(title_text: String, kind: String, count: int, cols: int) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 4)
	wrap.add_child(_shop_zone_label(title_text))
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", SHOP_SUBZONE_SEP)
	grid.add_theme_constant_override("v_separation", SHOP_SUBZONE_SEP)
	grid.custom_minimum_size.x = Tuning.grid_row_w(cols, SHOP_SUBZONE_SEP) # NO-132
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
## King Abilities warning button, in army_band while an ability is active
## (NO-128; built in the Header but parked off-screen by NO-83 before that).
## Purely informational, Close dismisses.
func show_king_abilities() -> void:
	if king_ability_panel:
		king_ability_panel.queue_free()
	king_ability_panel = PanelContainer.new()
	king_ability_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.94)
	king_ability_panel.add_theme_stylebox_override("panel", bg)
	var center := CenterContainer.new()
	king_ability_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = "Active King Abilities"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_add_king_ability_rows(box, 17, 13)
	var close := Button.new()
	close.text = "Close"
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(func() -> void: king_ability_panel.visible = false)
	box.add_child(close)
	g.hud.add_child(king_ability_panel)
	king_ability_panel.move_to_front()


## One name + description pair per active King Ability, or a "none yet" line.
## Shared by the ⚠ overlay and a King's info panel (NO-83), so the two can
## never list different things.
func _add_king_ability_rows(box: VBoxContainer, name_size: int, desc_size: int) -> void:
	if g.king_abilities_active.is_empty():
		var none := Label.new()
		none.text = "none yet — they land every 10th wave"
		none.modulate = Color(1, 1, 1, 0.6)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(none)
	for t in g.king_abilities_active:
		var name := Label.new()
		name.text = "%s  (%s)" % [t.name, t.tier]
		name.add_theme_font_size_override("font_size", name_size)
		name.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
		box.add_child(name)
		var desc := Label.new()
		desc.text = t.description
		desc.add_theme_font_size_override("font_size", desc_size)
		desc.modulate = Color(1, 1, 1, 0.75)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(g.get_viewport_rect().size.x - 96, 0)
		box.add_child(desc)


# --- box pick ---

func _box_clear() -> void:
	for c in box_panel.get_children():
		box_panel.remove_child(c) # gone NOW, not at frame end: a re-render mid-frame
			# (NO-38's sell row) must not leave a freed button clickable
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


## Icon for a Box option — mirrors _shop_icon's per-kind vocabulary, reading
## a Box option's shape (kind/name/description/payload/tier) instead of a
## shop_stock slot's.
func _box_icon(opt: Dictionary) -> Variant:
	match opt.kind:
		"piece":
			return g.piece_tex(opt.payload) if g.textures.has(opt.payload) else g.defs[opt.payload].glyph
		"item":
			return g.item_icons[opt.payload.key] if g.item_icons.has(opt.payload.key) else "✦"
		_: # "artefact"
			return g.artefact_tex(opt.payload.key)


## One icon tile per offered option (NO-133: was a full-width button carrying
## its own header + description text, which is what overflowed a phone
## screen once a Huge Box's 7 options stacked one per row). Tapping SELECTS
## it — box_expanded_index drives _fill_box_dock() below, same select-then-
## confirm shape NO-121/124 gave Items and NO-119 gave every other grid.
## meta.box_index exists for the click probes, same role meta.shop_index
## plays for _shop_tile.
func _box_tile(index: int) -> Button:
	var opt: Dictionary = _box_options[index]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(Tuning.OFFBOARD_ICON, Tuning.OFFBOARD_ICON) # NO-119
	btn.clip_text = true
	btn.set_meta("box_index", index)
	var icon: Variant = _box_icon(opt)
	if icon is Texture2D:
		btn.icon = icon
		btn.expand_icon = true
	else:
		btn.text = str(icon)
		btn.add_theme_font_size_override("font_size", 16)
	btn.tooltip_text = opt.name
	if opt.kind == "artefact": # issue 20: rarity legibility, same as _shop_tile
		var rarity := str(opt.payload.get("rarity", ""))
		if rarity != "":
			btn.self_modulate = Tuning.ARTEFACT_RARITY_COLOR[rarity]
	btn.pressed.connect(func() -> void:
		box_expanded_index = -1 if box_expanded_index == index else index
		_fill_box_dock())
	return btn


## The dock's content for the selected tile (or the hint) — refilled on every
## tap, same shape as _fill_shop_dock.
func _fill_box_dock() -> void:
	for c in _box_dock.get_children():
		c.free()
	if box_expanded_index >= 0 and box_expanded_index < _box_options.size():
		_box_dock.add_child(_box_detail(box_expanded_index))
	else:
		var hint := Label.new()
		hint.text = "Tap an entry for details"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hint.modulate = Color(1, 1, 1, 0.5)
		hint.add_theme_font_size_override("font_size", 13)
		_box_dock.add_child(hint)


## The expanded option: icon, name/kind header, effect text and a Pick
## confirm — the second tap of the select-then-confirm pair. meta.box_pick
## exists for the click probes, same role meta.shop_index plays for _shop_tile.
func _box_detail(index: int) -> Control:
	var opt: Dictionary = _box_options[index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon: Variant = _box_icon(opt)
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
	var name := Label.new()
	name.text = header
	name.add_theme_font_size_override("font_size", 14)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if opt.kind == "artefact": # issue 20: rarity legibility
		var rarity: String = str(opt.payload.get("rarity", ""))
		if rarity != "":
			name.add_theme_color_override("font_color", Tuning.ARTEFACT_RARITY_COLOR[rarity])
	info.add_child(name)
	var desc := Label.new()
	desc.text = opt.description
	desc.add_theme_font_size_override("font_size", 12)
	desc.modulate = Color(1, 1, 1, 0.8)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	row.add_child(info)

	var pick := Button.new()
	pick.text = "Pick"
	pick.set_meta("box_pick", true)
	pick.add_theme_font_size_override("font_size", 15)
	pick.pressed.connect(func() -> void: box_chosen.emit(opt))
	row.add_child(pick)
	return row


func show_box(options: Array) -> void:
	# Above everything, like every other panel. Without this a Box could open
	# behind the Shop — reachable on any restock wave that also queues a Bounty
	# box — while box_open gates every input path in the game. The player saw
	# the Shop, could not act, and the clock kept draining, because Box Pick is
	# deliberately excluded from the tier pause list.
	box_panel.move_to_front()
	_box_options = options
	box_expanded_index = -1 # NO-133: a fresh render — reroll/sell also call
		# back in here with a new/changed offer, so nothing carries over
	var picks: int = 1 + g.box_picks_left # Nostradamus Mad Libs stacks on
		# top of a Box's own native picks (Huge = 2 — issue 47)
	var title := "▣ %s %s Box — pick %d:" % [
		str(g.box_size).capitalize(), str(g.box_only_kind).capitalize(), picks]
	var box := _box_vbox(title)
	# NO-133: the icon grid (was one full-width button per option, each two
	# lines of header + description — that's what overflowed a phone screen
	# once a Huge Box's 7 options stacked). _piece_grid is the same NO-132
	# helper the Shop's own PIECES/STOCK band uses, so a Small Box's 3 tiles
	# still start at column 1 instead of centering as their own short block.
	box.add_child(_piece_grid(_box_tile, options.size()))
	_box_dock = PanelContainer.new()
	_box_dock.custom_minimum_size = Vector2(0, 92) # matches _shop_dock's own fixed height
	var dock_bg := StyleBoxFlat.new()
	dock_bg.bg_color = Color(0.14, 0.14, 0.17, 1.0)
	_box_dock.add_theme_stylebox_override("panel", dock_bg)
	_fill_box_dock()
	box.add_child(_box_dock)
	if g.box_only_kind == "item" and not ItemLogic.has_room(g):
		# NO-38 (user ruling 2026-09-08): a full inventory sells from INSIDE the
		# Box. The Shop cannot open under it (one modal at a time), and issue
		# 53's refusal would otherwise spend the pick for nothing. Selling goes
		# through game._sell like any sale, then the Box re-renders without this row.
		var full := Label.new()
		full.text = "Items full (%d/%d) — sell one to make room:" % [g.items.size(), ItemLogic.cap(g)]
		full.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(full)
		for it in g.items:
			var sell := Button.new()
			sell.text = "Sell %s (+%d gold)" % [it.name, Shop.sell_payout(g, "item", it)]
			sell.add_theme_font_size_override("font_size", 16)
			sell.custom_minimum_size = Vector2(420, 0)
			sell.pressed.connect(func() -> void: box_sell_pressed.emit(it))
			box.add_child(sell)
	if g.box_rerolls_left > 0: # Bible Gag Reel Scroll / Snowden's Rubik's
		# Cube (issue 46) — only while the per-Box budget is above zero
		var reroll := Button.new()
		reroll.text = "Reroll (%d left)" % g.box_rerolls_left
		reroll.pressed.connect(func() -> void: box_reroll_pressed.emit())
		box.add_child(reroll)
	var skip := Button.new()
	# The Box's price, in Gold. The old label said "+20 score" while earn() paid
	# ~20 Gold AND 200 Score — wrong currency and wrong by 10x at once.
	skip.text = "Skip (+%d gold)" % Tuning.box_skip_gold(g.box_size)
	skip.pressed.connect(func() -> void: box_skipped.emit())
	box.add_child(skip)
