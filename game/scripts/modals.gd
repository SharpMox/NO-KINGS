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
const PieceDiagram := preload("res://scripts/piece_diagram.gd") # NO-139
const PieceMass := preload("res://scripts/piece_mass.gd") # NO-157

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
signal box_sell_pressed(entry: Dictionary) # NO-38: sell a held Item from inside an Item Box
signal sell_pressed(kind: String, entry: Variant) # NO-144: from the preview
	# modal's Sell button — "piece" (Stock only, never Captured), "item",
	# "artefact". Captured -> Stock conversion isn't here: it lives on the
	# entry itself (hud.gd's own ⇄ badge, convert_pressed).
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
## NO-119: PIECES is a wrapping grid, not a fixed-width row, now that its
## tiles are Tuning.OFFBOARD_ICON (72) rather than the old 46 — up to 10 of
## them (Shop.ROWS.piece, NO-166) would overflow a single-row HBoxContainer well
## before it overflowed this column's width. Arithmetic, not taste: 5 x 72 +
## 4 x 4 = 376 fits the drawer's ~412px content width (draw_w 432 minus the
## 10px margins each side); 6 would need 452. NO-132 folds this into the
## site-wide standard — Tuning.OFFBOARD_GRID_COLS is the same 5, so the band
## no longer carries its own agreeing constant.
##
## NO-132 gave the lower band's side-by-side ARTEFACTS/ITEMS and BOXES
## columns 3 and 2 columns respectively (412px split 1.15/0.85 by stretch
## ratio, less `lower`'s own 8px separation: ~232px and ~172px — grid_cols
## floors at 76*cols-4, so 3 needs 224 and 2 needs 148). Neither reached the
## 5-column standard, and NO-144 didn't move these numbers (Buy and the old
## Sell mode shared this exact geometry) — closing the gap needed ~448px of
## column budget against `lower`'s 404, 44px short, and no re-split of the
## same 404px helped both sides — 3/3 for one side always cost the other
## its 2.
##
## NO-142: stacked instead — ARTEFACTS, ITEMS and BOXES each now get the
## FULL 412px `lower` width, one below another, so all three hit
## Tuning.OFFBOARD_GRID_COLS (5 x 72 + 4 x 4 = 376 <= 412; 6 needs 452),
## matching PIECES above them and the site-wide standard. What pays for the
## extra band is the vertical room NO-144 freed: PIECES used to become
## STOCK in Sell mode — the player's whole live Stock, unbounded (a real
## save once held 22, 5 rows at 5 columns, 376px). PIECES is Buy-only now,
## capped at Shop.ROWS.piece (10 as of NO-166, fewer at Tier 3+): still
## always <=2 rows (ceil(10/5)=2, same as the old ceil(8/5)=2), ~152px — no
## height change from NO-166's 8->10.
## `lower` is root's only EXPAND_FILL child, so every byte PIECES no longer
## needs at its old worst case, `lower` keeps — up to ~224px more,
## guaranteed rather than best-case.
##
## The stacked layout's own worst case, from Shop.ROWS (base, before any
## Tier 3+ reduction — the max, never more): ARTEFACTS ceil(4/5)=1 row,
## ITEMS ceil(4/5)=1 row, BOXES ceil(5/5)=1 row (72px) — NO-166 dropped
## BOXES 6->5, which drops it from 2 rows to 1 (was ceil(6/5)=2, 72*2+4=148px).
## Content height per zone = its grid + a zone label + the label-to-grid 4px
## separation (_shop_sub_zone's own `wrap`); the label's own height isn't
## measured here (no Godot run from this seat — see the label-height note
## on _shop_zone_label), estimated ~16px from this file's other measured
## font metrics (hud.gd's SCORE_FONT: 17px font, 24px tall). That puts all
## three zones at ~92px each (was ARTEFACTS/ITEMS ~92px, BOXES ~168px pre
## NO-166), plus 2 gaps at `lower`'s own 8px separation between the 3
## stacked zones: ~292px total (was ~368px) — NO-166 frees a further ~76px
## on top of the ~224px NO-144 already freed, comfortably inside it either
## way. If a real measurement ever puts a zone label taller than assumed
## here, recheck against the ~224px margin before assuming it still fits.
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


## NO-140: `a_id`/`b_id` are shown as art now too, not just `result` — "the
## trade visible rather than described". Confirming plays a short animation
## (the two sources fading while the result grows to full size) before the
## panel actually closes; gated on g.animations_on and skipped under
## g.autoplay, same seam _slide_shop uses. MergeLogic.do_merge already never
## calls this at all under autoplay (it commits straight through), so that
## path is doubly safe — this gate is only the belt to that braces.
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

	var art_row := HBoxContainer.new()
	art_row.alignment = BoxContainer.ALIGNMENT_CENTER
	art_row.add_theme_constant_override("separation", 10)
	var a_tex := _merge_piece_tex(a_id)
	var b_tex := _merge_piece_tex(b_id)
	var result_tex := _merge_piece_tex(result)
	if a_tex:
		art_row.add_child(a_tex)
	art_row.add_child(_merge_glyph_label("+"))
	if b_tex:
		art_row.add_child(b_tex)
	art_row.add_child(_merge_glyph_label("→"))
	if result_tex:
		# starts as a dim preview; confirming grows/brightens it to full while
		# a_tex/b_tex fade — see _play_merge_animation.
		result_tex.pivot_offset = result_tex.custom_minimum_size / 2
		result_tex.scale = Vector2(0.7, 0.7)
		result_tex.modulate.a = 0.55
		art_row.add_child(result_tex)
	box.add_child(art_row)

	var what := Label.new()
	what.text = "%s + %s → %s" % [g.defs[a_id].name, g.defs[b_id].name, g.defs[result].name]
	what.add_theme_font_size_override("font_size", 16)
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(what)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var yes := Button.new()
	yes.text = "Merge"
	yes.add_theme_font_size_override("font_size", 22)
	var no := Button.new()
	no.text = "Cancel"
	no.add_theme_font_size_override("font_size", 22)
	yes.pressed.connect(func() -> void:
		yes.disabled = true # a second tap mid-animation must not re-fire the commit
		no.disabled = true
		merge_confirmed.emit()
		if g.autoplay or not g.animations_on:
			merge_panel.visible = false
		else:
			_play_merge_animation(a_tex, b_tex, result_tex))
	row.add_child(yes)
	no.pressed.connect(func() -> void:
		merge_panel.visible = false
		merge_cancelled.emit())
	row.add_child(no)
	box.add_child(row)
	g.hud.add_child(merge_panel)
	merge_panel.move_to_front() # above the drawers and bottom bar


## One off-board-standard-sized icon (Tuning.OFFBOARD_ICON, same as the Shop/
## Drawer grids) for `id`, or null when it has no art — guarded the same way
## every other modals.gd icon is (`g.textures.has`).
func _merge_piece_tex(id: String) -> TextureRect:
	if not g.textures.has(id):
		return null
	var tex := TextureRect.new()
	tex.texture = g.piece_tex(id)
	tex.custom_minimum_size = Vector2(Tuning.OFFBOARD_ICON, Tuning.OFFBOARD_ICON)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tex


func _merge_glyph_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## NO-140: sources fade out, the result scales/brightens to full — reads as
## "the two becoming the result" without moving anything out of art_row's own
## HBoxContainer layout (a position tween would fight the container's own
## sort). Any of the three may be null (no art for that id); tween_property
## calls are just skipped for it. Ends by hiding merge_panel, the same state
## change the no-animation branch above makes immediately.
##
## Hardware fix (coordinator diagnosis, eleven downstream menu-click
## failures): merge_panel stays `visible` for the whole MERGE_ANIM_S outro,
## and a visible Control with the default MOUSE_FILTER_STOP still absorbs
## every click in its rect via Godot's own GUI picking before
## _unhandled_input ever runs — CLAUDE.md's documented trap, and the exact
## one NO-118 already hit on the Shop's close-slide. Hiding the panel only
## in the tween's callback left it a full-screen invisible input blocker for
## 350ms after the player had already confirmed. IGNORE goes on the instant
## the animation starts, not when it ends; the tween itself is now purely
## visual. Same idiom as _slide_shop above (IGNORE the instant a close
## starts, recursed into descendants since Godot doesn't cascade a parent's
## filter to its children) rather than hud.gd's _set_drawer_clickable's
## save/restore: no restore is needed here for the same reason _slide_shop
## needs none — show_merge_confirm frees this exact panel and builds a
## fresh one, default filters, on every subsequent open.
func _play_merge_animation(a_tex: TextureRect, b_tex: TextureRect, result_tex: TextureRect) -> void:
	merge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in merge_panel.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := merge_panel.create_tween()
	tw.set_parallel(true)
	if a_tex:
		tw.tween_property(a_tex, "modulate:a", 0.0, Tuning.MERGE_ANIM_S)
	if b_tex:
		tw.tween_property(b_tex, "modulate:a", 0.0, Tuning.MERGE_ANIM_S)
	if result_tex:
		tw.tween_property(result_tex, "scale", Vector2.ONE, Tuning.MERGE_ANIM_S) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(result_tex, "modulate:a", 1.0, Tuning.MERGE_ANIM_S)
	tw.chain().tween_callback(func() -> void: merge_panel.visible = false)


## Tier-1 pause parity (user ruling 2026-09-04: the gap was an oversight, not
## a lever). Reading the tariff list, a merge confirm or the reinforcement pick
## pauses the clock at Tier 1 exactly like the menu, Shop, drawers and preview
## already do. The reinforcement pick was the third instance of the same
## oversight — a full-rect panel whose only state is `visible`, so nothing
## mirrored it into a `*_open` flag the way preview_open/box_open do. Box Pick
## stays deliberately excluded — GDD: "decisive picks rewarded, indecision
## punished" — that one IS a difficulty lever.
##
## NO-140: `merge_panel.visible` deliberately still reads true for the whole
## MERGE_ANIM_S outro, even though the panel stopped ACCEPTING input the
## instant Merge was pressed (_play_merge_animation). Visible is the right
## predicate here regardless: the outro is a modal moment on screen whose
## length the player didn't choose, so the Clock stays paused through it,
## same as it would for a tween-free instant close — the two are decoupled
## on purpose, not entangled. Don't read this as "input-blocked", it never
## meant that; it means "there is still a modal up".
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
## diagram, the same rows the ⚠ overlay shows. Piece-only; ignored for
## `kind` != "piece".
##
## NO-144: "long-press = the thing's own menu" — Sell now lives here, not in
## a Shop mode of its own. `kind` is "piece" (board tile, or a Stock/Captured
## stack — the diagram/chain/King-Ability sections below are piece-only),
## "item" or "artefact" (icon + name + description, no diagram). `entry` is
## the live g.stock/g.items/g.artefacts element Shop.can_sell/sell_payout
## read — null for anything not sellable from here (a board tile, a Captured
## Stock entry: Convert and Sell are not the same thing, and Convert stays on
## the entry itself, hud.gd's own ⇄ badge). The Sell button is built only
## when `entry` is given, and disabled (never omitted) when Shop.can_sell
## says no for a dynamic reason (not the player's turn, the starvation
## softlock) — same convention as the Shop's own Buy/Convert buttons.
func show_preview(kind: String, id: String, king_id := "", entry: Variant = null) -> void:
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

	if kind == "piece":
		var title := Label.new()
		title.text = g.defs[id].name
		title.add_theme_font_size_override("font_size", 30)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)

		var dia := Control.new()
		var cells := 9 # covers the longest leap (Ying Long's 4)
		var cell := 30
		dia.custom_minimum_size = Vector2(cells, cells) * cell
		var dia_tex: Texture2D = g.piece_tex(id) if g.textures.has(id) else null
		dia.draw.connect(func() -> void: PieceDiagram.draw(dia, g.defs, id, cells, cell, dia_tex))
		box.add_child(dia)

		var legend := Label.new()
		legend.text = "● move + capture      ○ move only      ✕ capture only      ➜ slide      ⇢ rider"
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
	else: # "item" / "artefact" — icon, name, description; no movement diagram
		var title := Label.new()
		title.text = str(entry.name)
		title.add_theme_font_size_override("font_size", 26)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(title)

		# artefact_tex() never returns null (art or the shared placeholder);
		# an Item can, so it falls back to the same "✦" glyph its drawer cell
		# and the Shop's own _shop_icon already use.
		var icon: Variant = g.item_icons.get(id) if kind == "item" else g.artefact_tex(id)
		if icon is Texture2D:
			var tex := TextureRect.new()
			tex.texture = icon
			tex.custom_minimum_size = Vector2(72, 72)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			box.add_child(tex)
		else:
			var glyph := Label.new()
			glyph.text = "✦"
			glyph.add_theme_font_size_override("font_size", 40)
			glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(glyph)

		var desc_text := str(entry.get("description", ""))
		if desc_text != "":
			var desc := Label.new()
			desc.text = desc_text
			desc.add_theme_font_size_override("font_size", 15)
			desc.modulate = Color(1, 1, 1, 0.8)
			desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.custom_minimum_size = Vector2(g.get_viewport_rect().size.x - 96, 0)
			box.add_child(desc)

	if entry != null:
		var sell := Button.new()
		sell.text = "Sell (+$%d)" % Shop.sell_payout(g, kind, entry)
		sell.disabled = not Shop.can_sell(g, kind, entry)
		sell.add_theme_font_size_override("font_size", 18)
		sell.pressed.connect(func() -> void:
			preview_panel.visible = false
			preview_closed.emit() # same reset Close does — sale must not
				# leave preview_open stuck true (it deadens board input)
			sell_pressed.emit(kind, entry))
		box.add_child(sell)

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
## price badge, grouped into four fixed zones, all full-width and stacked
## top to bottom (PIECES, ARTEFACTS, ITEMS, BOXES — NO-142) so the grid
## geometry holds regardless of which tile is expanded (shop-drawer-ui/08).
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
	# NO-145: `margin` fills shop_panel's whole rect (MarginContainer, default
	# MOUSE_FILTER_STOP) but only INSETS `root` by 10px — that 10px ring
	# around root (and any of root's own unclaimed space) is what gui_input
	# reports here, the Shop's own "chrome or edge, not a scrollable cell"
	# a reverse-close swipe may start on. Reconnected every show_shop() call
	# since margin is rebuilt fresh each time (no save/restore needed, same
	# reasoning as _slide_shop's own descendant-filter comment above).
	margin.gui_input.connect(_on_shop_chrome_input)
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
	# issue 64: buying is free of the Action cost. NO-143: dropped the "no
	# Action cost" suffix — noise, since the absence of a cost doesn't need
	# saying on every entry. NO-144: Sell/Convert moved off this label
	# entirely — Sell is now the previewed thing's own menu (modals.gd
	# show_preview), Convert the entry's own badge (hud.gd).
	sub.text = "$%d" % g.gold
	sub.add_theme_font_size_override("font_size", 12)
	sub.modulate = Color(1, 1, 1, 0.75)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(sub)
	if g._held("jet-fuel-vial"): # issue 52: only while held (user ruling — a
		# Shop control, not part of the in-run Activate section)
		var restock := Button.new()
		restock.text = "Restock ($20)"
		restock.add_theme_font_size_override("font_size", 13)
		restock.disabled = not g._jet_fuel_restock_available()
		restock.pressed.connect(func() -> void: shop_restock_pressed.emit())
		header.add_child(restock)
	var close := Button.new()
	close.text = "Close"
	close.add_theme_font_size_override("font_size", 14)
	close.pressed.connect(close_shop) # NO-118: same path an outside click uses (game.gd)
	header.add_child(close)
	root.add_child(header)

	# issue 64: Lane B restock progress — Score banked toward the next
	# Score-driven restock (Lane A, every 5 Waves, needs no bar: it's a
	# guaranteed beat, not something to watch fill).
	shop_lane_b_bar = ProgressBar.new()
	shop_lane_b_bar.min_value = 0
	shop_lane_b_bar.max_value = Tuning.SHOP_LANE_B_SCORE
	shop_lane_b_bar.value = g.shop_lane_b_progress
	shop_lane_b_bar.show_percentage = false
	# NO-143 (Max, 2026-09-20): the label moves INSIDE the bar, so the bar has
	# to be tall enough to hold it — sized off the label's own font metrics
	# (ThemeDB.fallback_font, since the bar isn't in the tree yet to ask its
	# own theme) plus 4px breathing room (2 top, 2 bottom), not a guessed
	# round number.
	var restock_font_size := 12
	var restock_line_h := ThemeDB.fallback_font.get_height(restock_font_size)
	shop_lane_b_bar.custom_minimum_size = Vector2(0, restock_line_h + 4)
	# NO-143: reads as a gauge — a sunken groove behind a rounded fill in
	# Score's own colour (hud.gd:357) — rather than the bare default bar.
	# Presentation only: value/min/max are unchanged from issue 64.
	var gauge_bg := StyleBoxFlat.new()
	gauge_bg.bg_color = Color(0.05, 0.05, 0.07, 0.9)
	gauge_bg.border_color = Color(0.4, 0.4, 0.48)
	gauge_bg.set_border_width_all(1)
	gauge_bg.set_corner_radius_all(5)
	var gauge_fill := StyleBoxFlat.new()
	gauge_fill.bg_color = Color(0.95, 0.8, 0.25) # Score amber (hud.gd:357)
	gauge_fill.set_corner_radius_all(5)
	shop_lane_b_bar.add_theme_stylebox_override("background", gauge_bg)
	shop_lane_b_bar.add_theme_stylebox_override("fill", gauge_fill)
	# NO-143: the label lives INSIDE the bar now (was a separate row above
	# it) — "Restock: %d /%d" is Max's own spacing, space before the slash,
	# none after, reproduced literally, not tidied. FULL_RECT + centred both
	# ways so it sits in the middle of the gauge regardless of fill width.
	# White-on-black outline reads against both the dark groove and the
	# amber fill as the fill crosses under it — a flat colour can't do both.
	# MOUSE_FILTER_IGNORE: CLAUDE.md's "a visible Control absorbs clicks
	# before _unhandled_input runs" — this Label sits inside a Shop panel
	# with its own swipe/click handling, so it must not be able to eat a
	# press meant for the panel underneath.
	var lane_b_label := Label.new()
	lane_b_label.text = "Restock: %d /%d" % [g.shop_lane_b_progress, Tuning.SHOP_LANE_B_SCORE]
	lane_b_label.add_theme_font_size_override("font_size", restock_font_size)
	lane_b_label.add_theme_color_override("font_color", Color.WHITE)
	lane_b_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lane_b_label.add_theme_constant_override("outline_size", 3)
	lane_b_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lane_b_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lane_b_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	lane_b_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_lane_b_bar.add_child(lane_b_label)
	root.add_child(shop_lane_b_bar)

	var pieces_band := VBoxContainer.new()
	pieces_band.add_theme_constant_override("separation", 4)
	# NO-142: ARTEFACTS, ITEMS and BOXES stacked full-width, not split into
	# side-by-side columns — the drawer's 412px content width only fits 2
	# columns of columns (3 and 2, see the SHOP_SUBZONE_SEP comment above);
	# stacked, each one gets the whole width and reaches the site-wide 5.
	var lower := VBoxContainer.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.add_theme_constant_override("separation", 8)

	var by_kind := {"piece": [], "artefact": [], "item": [], "box": []}
	for i in g.shop_stock.size():
		by_kind[g.shop_stock[i].kind].append(i)
	pieces_band.add_child(_shop_zone_label("PIECES"))
	pieces_band.add_child(_piece_grid(_shop_tile, by_kind.piece))
	lower.add_child(_shop_sub_zone("ARTEFACTS", by_kind.artefact, Tuning.OFFBOARD_GRID_COLS))
	lower.add_child(_shop_sub_zone("ITEMS", by_kind.item, Tuning.OFFBOARD_GRID_COLS))
	lower.add_child(_shop_sub_zone("BOXES", by_kind.box, Tuning.OFFBOARD_GRID_COLS))
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
	if not was_open: # NO-118: a rebuild while already open (Buy, Restock, ...)
		# reuses the fresh panel at rest with no re-animation — it never left
		# the screen.
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


## NO-145: reverse-of-the-opening-swipe close — the Shop opens on a leftward
## swipe starting on an empty board tile (game.gd's _swipe_open_may_begin;
## hardware round 2 dropped the edge-proximity requirement — see tuning.gd),
## so it closes on a rightward swipe, started anywhere on its own chrome
## (margin.gui_input above — never on a scrollable cell, which claims its
## own rect first via the same MOUSE_FILTER_STOP mechanism).
var _shop_swipe_from := Vector2.ZERO
var _shop_swipe_down := false

func _on_shop_chrome_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_shop_swipe_from = event.position
		_shop_swipe_down = true
		return
	if not _shop_swipe_down:
		return
	_shop_swipe_down = false
	if Tuning.classify_swipe(event.position - _shop_swipe_from) == "right":
		close_shop()


## The dock's content for the current expanded tile (or the hint). Called
## from show_shop and from every tile tap; the tiles themselves are untouched
## by a tap, so nothing else needs rebuilding. free(), not queue_free(): the
## tap comes from a TILE, never from a dock child, so nothing here is mid-signal,
## and an immediately-freed dock can't be found by a same-frame probe.
func _fill_shop_dock() -> void:
	for c in _shop_dock.get_children():
		c.free()
	if shop_expanded_index >= 0 and shop_expanded_index < g.shop_stock.size():
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


## font_size 12; its rendered height isn't measured anywhere in this file
## (NO-142's vertical-fit estimate above assumes ~16px, by analogy with
## hud.gd's own measured font metrics — never taken on a running Godot from
## this seat).
func _shop_zone_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.modulate = Color(1, 1, 1, 0.6)
	return l


## NO-119: the Shop's PIECES band and the Box pick's own top band share this
## centered, wrapping grid — Tuning.OFFBOARD_GRID_COLS wide, built from
## whatever `tile_of` returns (_shop_tile or _box_tile) for each of `indices`
## (an Array of slot/option indices, or a plain count). Kept separate from
## _shop_sub_zone below: that one expands to fill a fixed-height column, this
## one sits in a top band sized to its own content.
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


## A labeled, centered grid of tiles that expands to fill its share of
## `lower`'s height — one zone of the full-width stack (money-and-shop/04
## kept the logic; shop-drawer-ui/08 and NO-142 are only the geometry, side
## by side then stacked).
##
## NO-132: `cols` reserves the full row's width up front (Tuning.grid_row_w),
## the same way _piece_grid does, so a short row aligns instead of centring
## itself. NO-142: every caller now passes Tuning.OFFBOARD_GRID_COLS, now
## that ARTEFACTS/ITEMS/BOXES all get the full drawer width — `cols` stays a
## parameter rather than hardcoding the constant in here, same as
## _piece_grid takes `tile_of` as a parameter rather than assuming its caller.
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


## NO-141 (Max, 2026-09-19): an announcement, not a shop — the pieces are
## already in Stock by the time this shows (game.gd grants them the instant
## pending_reinforce is consumed, before calling this); `ids` is that same
## list, for display only. No Buy button, nothing left to choose or pay for.
func show_reinforce(ids: Array) -> void:
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
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new()
	title.text = "REINFORCEMENTS ARRIVED"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Wave %d cleared — added to Stock, free of charge" % (g.wave - 1)
	sub.add_theme_font_size_override("font_size", 15)
	sub.modulate = Color(1, 1, 1, 0.8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(PieceMass.build(ids)) # NO-157
	var dismiss := Button.new()
	dismiss.text = "Dismiss"
	dismiss.add_theme_font_size_override("font_size", 22)
	dismiss.pressed.connect(func() -> void:
		reinforce_panel.visible = false
		reinforce_done_pressed.emit())
	box.add_child(dismiss)
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
