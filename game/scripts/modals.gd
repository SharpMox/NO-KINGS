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
const Economy := preload("res://scripts/economy.gd")
const Kings := preload("res://data/kings.gd")
const Box := preload("res://scripts/box.gd")
const ItemLogic := preload("res://scripts/item_logic.gd")
const PieceDiagram := preload("res://scripts/piece_diagram.gd") # NO-139
const PieceMass := preload("res://scripts/piece_mass.gd") # NO-157
const BuffLogic := preload("res://scripts/buff_logic.gd") # NO-185
const UiAnim := preload("res://scripts/ui_anim.gd") # NO-243 S2: the shared UI animations
const SceneFade := preload("res://scripts/scene_fade.gd") # NO-243 S4

signal restart_pressed # game.gd owns what Restart MEANS; this is just the press
signal merge_confirmed
signal merge_cancelled
signal box_chosen(opt: Dictionary)
signal box_skipped
signal box_reroll_pressed
signal win_continue_pressed
signal win_end_pressed
signal feedback_pressed # NO-254: "Give Feedback" pressed on an end-of-run
	# screen — game.gd owns the actual open (open_feedback())
signal shop_buy_pressed(index: int)
signal shop_tile_preview_requested(index: int) # NO-167 (Max review 2026-09-20):
	# a Shop tile tap opens the tile's own preview now — same "long press =
	# the thing's own menu" shape NO-144 gave held Stock/Item/Artefact
	# entries, mirrored for an unowned Shop slot (game.gd owns preview_open,
	# hence the round trip rather than modals.gd calling show_preview
	# directly — this file only reads `g`, never writes it).
signal shop_closed
signal shop_restock_pressed # issue 52: Jet Fuel Vial's Restock button
signal box_sell_pressed(entry: Dictionary) # NO-38: sell a held Item from inside an Item Box
signal sell_pressed(kind: String, entry: Variant) # NO-144: from the preview
	# modal's Sell button — "piece" (Stock only, never Captured), "item",
	# "artefact". game.gd routes every one of these through the shared
	# confirm seam (_confirm_sell, NO-223, 2026-09-22 ruling) rather than
	# selling straight off this signal.
signal use_pressed(kind: String, entry: Variant) # NO-223: the preview modal's
	# own Use button — only ever "item" today (an Artefact's Activate stays a
	# plain tap on its cell, not duplicated into this menu; a Captured Stock
	# entry has Convert instead, below). game.gd resolves the live g.items
	# index from `entry` and calls the same _use_item a tap does.
signal convert_pressed(entry: Variant) # NO-223 (2026-09-22 ruling): Captured
	# -> Stock conversion, moved off the ⇄ badge (which is now information
	# only, hud.gd's _build_stack_button) and into this preview modal's own
	# menu, alongside Sell/Use — same "long-press = the thing's own menu"
	# idiom NO-144 already established.
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
var _shop_seen_stock: Variant = null # NO-243: the g.shop_stock array the Shop last
	# showed — Shop.roll assigns a new one, so a different array is a restock
var _shop_seen_sold: Array = [] # NO-243: each slot's `sold` as last shown — a
	# flip while the Shop stays open is a purchase
var _shop_tiles: Array = [] # NO-243: this build's tiles, in g.shop_stock order
var shop_lane_b_bar: ProgressBar # issue 64: Lane B restock progress —
	# exposed so probes can read/assert its value
var shop_lower: VBoxContainer # V4 (Max review 2026-09-21): the master grid —
	# PIECES+BOXES row, then ARTEFACTS, then ITEMS, all sharing one column
	# grid (see the V4 note below `_shop_zone`) — exposed, same reasoning as
	# shop_lane_b_bar above, so a probe can measure whether the content block
	# is actually centred in the panel. null while the Shop is empty (NO-240).
var shop_empty_label: Label # NO-240: "Restocks at wave N", shown instead of
	# shop_lower while g.shop_stock is empty (before the first restock)
## Shop geometry history (NO-119/132/142/144/166/167): PIECES, ARTEFACTS,
## ITEMS and BOXES were stacked full-width, one below another, all at
## Tuning.OFFBOARD_GRID_COLS (5) — precisely so no zone read thinner than
## PIECES (5 x 72 + 4 x 4 = 376, fits the drawer's ~412px content width;
## draw_w 432 minus the 10px MarginContainer margins each side).
##
## NO-188 (Max review): partial reverse — the PIECES/ARTEFACTS/ITEMS/BOXES
## labels are gone, and BOXES moves into its own single-OFFBOARD_ICON-wide
## column on the right, computed in show_shop() as `left_cols`/`_shop_zone`.
## Losing that width pays for itself in wrap: left content is
## 412 - SHOP_BOXES_COL_SEP(8) - OFFBOARD_ICON(72) = 332px, and
## Tuning.grid_cols(332, 4) = floor(336/76) = 4 columns (was 5) for
## PIECES/ARTEFACTS/ITEMS. Shop.ROWS (base, before any Tier 3+ delta):
## PIECES 10/4 = 3 rows (224px, was 2 rows/148px) · ARTEFACTS 4/4 = 1 row
## (72px, unchanged) · ITEMS 4/4 = 1 row (72px, unchanged) · BOXES 5 rows in
## its own column (5 x 72 + 4 x 4 = 376px). Left column total (3 zones + 2 x
## 8px gaps) = 224+8+72+8+72 = 384px, comfortably above BOXES' 376px, so the
## HBox's height is set by the left column.
##
## Compared to the OLD stacked total (each zone's grid + a ~16px label + 4px
## label gap, PIECES separated from `lower` by root's own 8px): PIECES
## (16+4+148=168) + 8 + 3 x (16+4+72=92) = 468px. The NEW 384px is SMALLER
## despite PIECES wrapping to a 3rd row — losing 4 labels (~80px) more than
## pays for the one extra PIECES row (~76px). No Godot run from this seat to
## confirm the ~16px label-height estimate was ever exact; it no longer
## matters, since labels are gone.
##
## NO-201 (Max review): `left_w`/`left_cols` above pick the WIDEST grid that
## fits the 332px budget, but fixed OFFBOARD_ICON tiles can't be stretched to
## consume it exactly — grid_cols floors, so left_cols=4 leaves a real 332 -
## grid_row_w(4, SHOP_SUBZONE_SEP) = 32px remainder. `left` used to be
## SIZE_EXPAND_FILL, so that remainder sat INSIDE the left column (the grid
## centred within it), reading as a gap before BOXES rather than at either
## edge. Stretching PIECES/ARTEFACTS/ITEMS to close it would resize every
## icon off Tuning.OFFBOARD_ICON, which every other grid in the app (Stock,
## Inventory, Box pick) shares — out of scope here. So `left` now sizes to
## its own minimum (grid_row_w(left_cols, SEP), no stretch) and `shop_lower`
## (the whole PIECES/ARTEFACTS/ITEMS + BOXES row) is SIZE_SHRINK_CENTER
## instead of filling root's width: the 32px remainder moves out to the
## panel's two edges, split evenly, rather than sitting as one asymmetric gap
## next to BOXES.
##
## V4 (Max review 2026-09-21): "everything aligned to a big grid but split
## into sections" — his mockup put PIECES 3 cols x 4 rows top-left, BOXES a
## single column top-right, then ARTEFACTS and ITEMS each a full-width row
## below. Rather than compute left_cols from the leftover width (NO-201
## above), this locks PIECES to 3 columns and ARTEFACTS/ITEMS to
## Tuning.OFFBOARD_GRID_COLS (5, the house grid NO-132 already standardises
## on) so every section's column edges land on the same 5-column grid:
## PIECES occupies columns 1-3, BOXES column 5, and SHOP_BOXES_COL_SEP (the
## gap between PIECES and BOXES) is sized to exactly the width of the
## unused column 4 plus its two flanking separators — the arithmetic that
## makes it work out: 3 PIECES cols + 1 gap-as-column-4 + 1 BOXES col = 5,
## the same total width ARTEFACTS/ITEMS reserve directly
## (grid_row_w(5, SEP) = 376px either way). `shop_lower` stacks the
## PIECES+BOXES row above ARTEFACTS above ITEMS in a VBox and is centred as
## ONE block (still SIZE_SHRINK_CENTER, NO-201's reasoning unchanged) so the
## shared alignment survives the centring. Supersedes left_cols/grid_cols()
## here — Tuning.grid_cols is still what OFFBOARD_GRID_COLS documents itself
## against, just not called from this file any more.
const SHOP_SUBZONE_SEP := 4.0
var king_ability_panel: PanelContainer # tariff detail overlay
var buff_panel: PanelContainer # generic choice-pick modal (issue 41); named
	# for its first caller, the Buff Box sub-pick — never renamed, since it's
	# just the panel field, not a Buff-specific behaviour
## NO-133: the Box pick rebuilt as a select-then-confirm icon grid — a tap
## selects a tile and fills the dock below with its description; it takes a
## second tap on the dock's Pick button to actually commit. (The Shop's own
## tiles used to share this select-then-confirm shape too; NO-167 replaced it
## there with a tap opening the tile's own preview instead — see
## shop_tile_preview_requested above. The Box pick keeps its own dock: NO-168
## already gave it a reason of its own — bigger icons instead of a name/dock,
## not a Shop-tile mirror. NO-186 put a small name label back under each
## tile — not the same thing as NO-168's old per-tile dock: the description
## text is still gated behind a tap, on the shared dock below the grid; only
## the option's bare name is always visible now.)
var box_expanded_index := -1 # which offered tile is selected, -1 = none
var _box_options: Array = [] # the options show_box was last called with, so
	# _box_tile/_box_detail can read by index without re-threading the array
	# through every closure the way _shop_tile reads g.shop_stock directly
var _box_cells: Array = [] # NO-243: this render's option cells, in order
var _box_rerolling := false # NO-243: set by the Reroll button, read once by show_box
var _box_dock: PanelContainer # refilled on a tile tap — NO-168 dropped its
	# fixed size/background — see _fill_box_dock's own header (the Shop's own
	# former dock, once the analogy here, is gone entirely as of NO-167)


## NO-186/NO-187 (Max review): one shared shape for a modal's commit/cancel
## pair — Box's Pick/Skip and Merge's Merge/Cancel. The commit button sits
## centred; cancel/skip sits MODAL_CANCEL_GAP below it, never sharing a row,
## so the two can't be mis-tapped into each other. Previously two different
## shapes (Merge's single HBoxContainer row, Box's Pick inline beside its
## detail text) — implemented once here rather than twice differently.
const MODAL_CANCEL_GAP := 32.0

func _centered(btn: Button) -> CenterContainer:
	var c := CenterContainer.new()
	c.add_child(btn)
	return c


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
	# NO-243 S3: the dim is _desat's shader now (it greys the run behind as
	# it dims it), so the panel itself draws nothing
	overlay.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var desat_mat := ShaderMaterial.new()
	desat_mat.shader = Shader.new()
	desat_mat.shader.code = DESAT_SHADER
	_desat.material = desat_mat
	_desat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_desat)
	g.hud.add_child(overlay)


## NO-169: 170% the size of the two below it — visually a pyramid, "two
## below converging into one above".
const MERGE_RESULT_SCALE := 1.7

## NO-140: `a_id`/`b_id` are shown as art now too, not just `result` — "the
## trade visible rather than described". Confirming plays a short animation
## (the two sources fading while the result grows to full size) before the
## panel actually closes; gated on g.animations_on and skipped under
## g.autoplay, same seam _slide_shop uses. MergeLogic.do_merge already never
## calls this at all under autoplay (it commits straight through), so that
## path is doubly safe — this gate is only the belt to that braces.
##
## NO-169: rebuilt as a pyramid — result on top at MERGE_RESULT_SCALE, the
## two sources underneath — replacing the old left-to-right "A + B → C" art
## row and its matching text line (removed entirely, no replacement: the
## icons and labels below already say the same thing). Labels are discreet
## on the sources (named underneath their own icon, dimmed) and big/bold
## above the result, so the result reads as the point of the screen.
##
## NO-187 (Max review): the result used to start as a dim 0.55-alpha preview,
## which read as washed-out/de-emphasized for what is literally the reward
## of the merge — it's fully opaque now, at rest and through the whole
## confirm animation. Only the SCALE still previews small (_play_merge_
## animation grows it to full on confirm, unchanged); the dimming that used
## to fade in alongside it is gone, so that tween is gone too.
## `a_piece`/`b_piece` (NO-185): the two sources' buffs-bearing Dictionaries
## (merge_logic.gd's own `_piece_state`), {} when a source carries none.
## `result_buffs` (NO-191): BuffLogic.inherited(a_piece, b_piece, cap) — the
## union the result will actually carry, deduped and cap-truncated. Each
## source column below only lists the buffs of ITS OWN that survive into
## that set, so a buff the cap drops (or that loses a dedupe tie) is never
## claimed to carry forward.
func show_merge_confirm(a_id: String, b_id: String, result: String,
		a_piece: Dictionary = {}, b_piece: Dictionary = {}, result_buffs: Array = []) -> void:
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

	var result_name := Label.new()
	result_name.text = g.defs[result].name
	result_name.theme_type_variation = &"Title"
	# Godot has no bold font asset in this project (audited: no other Label
	# here sets add_theme_font_override) — "bold" is approximated the same
	# way the rest of this file contrasts emphasis, size + full opacity
	# against the sources' smaller, dimmed labels below.
	result_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_name)

	var result_tex := _merge_piece_tex(result, Tuning.OFFBOARD_ICON * MERGE_RESULT_SCALE)
	if result_tex:
		# NO-187: fully opaque at rest — only the SCALE still starts small and
		# grows to full on confirm (_play_merge_animation); modulate.a no
		# longer dips (was 0.55, read as washed-out for the merge's reward).
		# SHRINK_CENTER so it stays centred at its own size if sources_row
		# below ends up wider.
		result_tex.pivot_offset = result_tex.custom_minimum_size / 2
		result_tex.scale = Vector2(0.7, 0.7)
		result_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(result_tex)

	var sources_row := HBoxContainer.new()
	sources_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sources_row.add_theme_constant_override("separation", 10)
	var a_tex := _merge_piece_tex(a_id, Tuning.OFFBOARD_ICON)
	var b_tex := _merge_piece_tex(b_id, Tuning.OFFBOARD_ICON)
	var kept_keys := {} # NO-191: which buff keys survive into result_buffs
	for b in result_buffs:
		kept_keys[b.key] = true
	sources_row.add_child(_merge_source_col(a_id, a_tex, a_piece, kept_keys))
	sources_row.add_child(_merge_glyph_label("+"))
	sources_row.add_child(_merge_source_col(b_id, b_tex, b_piece, kept_keys))
	box.add_child(sources_row)

	# NO-187 (Max review): the shared commit/cancel shape (MODAL_CANCEL_GAP) —
	# Merge centred, Cancel pushed clearly below it instead of sharing a row,
	# so the two can't be mis-tapped into each other.
	var yes := Button.new()
	yes.text = "Merge"
	var no := Button.new()
	no.text = "Cancel"
	yes.pressed.connect(func() -> void:
		yes.disabled = true # a second tap mid-animation must not re-fire the commit
		no.disabled = true
		merge_confirmed.emit()
		if g.autoplay or not g.animations_on:
			merge_panel.visible = false
		else:
			_play_merge_animation(a_tex, b_tex, result_tex))
	no.pressed.connect(func() -> void:
		UiAnim.fade_out(g, merge_panel) # NO-243: input-dead now, faded, hidden
		merge_cancelled.emit())
	box.add_child(_centered(yes))
	var cancel_gap := Control.new()
	cancel_gap.custom_minimum_size = Vector2(0, MODAL_CANCEL_GAP)
	box.add_child(cancel_gap)
	box.add_child(_centered(no))
	g.hud.add_child(merge_panel)
	merge_panel.move_to_front() # above the drawers and bottom bar
	UiAnim.modal_in(g, merge_panel, center) # NO-243 (row 42)


## An icon at `size` (Tuning.OFFBOARD_ICON for the sources, NO-169's
## MERGE_RESULT_SCALE multiple of it for the result) for `id`, or null when it
## has no art — guarded the same way every other modals.gd icon is
## (`g.textures.has`).
func _merge_piece_tex(id: String, size: float) -> TextureRect:
	if not g.textures.has(id):
		return null
	var tex := TextureRect.new()
	tex.texture = g.piece_tex(id)
	tex.custom_minimum_size = Vector2(size, size)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tex


func _merge_glyph_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## NO-169: a source's icon with its own name discreetly UNDERNEATH — the
## pyramid's base. `tex` may be null (no art for `id`), same as every other
## icon here; the name label still shows either way.
##
## NO-191: `piece`'s catalogued buffs that survive into the result (per
## `kept_keys`, show_merge_confirm's result_buffs by key) on a third line —
## green, since these carry forward now, not amber/lost. A buff the cap or a
## dedupe tie drops is simply not listed, so the line never over-claims.
func _merge_source_col(id: String, tex: TextureRect, piece: Dictionary = {},
		kept_keys: Dictionary = {}) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	if tex:
		col.add_child(tex)
	var name := Label.new()
	name.text = g.defs[id].name
	name.theme_type_variation = &"Meta"
	name.modulate = Color(1, 1, 1, 0.65) # discreet — the result's own name above carries the emphasis
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name)
	var buff_names: PackedStringArray = []
	for b in BuffLogic.of(piece):
		if kept_keys.has(b.key):
			buff_names.append(BuffLogic.name_of(b.key))
	if not buff_names.is_empty():
		var buffs_label := Label.new()
		buffs_label.text = "carries forward: %s" % ", ".join(buff_names)
		buffs_label.theme_type_variation = &"Meta"
		buffs_label.modulate = Color(0.45, 0.85, 1.0, 0.9) # merge cyan (game.gd COL_MERGE): inherited by the result; NO-256 ruling 4, off green
		buffs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		buffs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		buffs_label.custom_minimum_size = Vector2(110, 0)
		col.add_child(buffs_label)
	return col


## NO-140: sources fade out, the result scales up to full — reads as
## "the two becoming the result" without moving anything out of its own
## container layout (a position tween would fight the container's own sort;
## NO-169's pyramid arrangement — sources below fading, result above growing
## — reads this motion even more literally than the old side-by-side row
## did). Any of the three may be null (no art for that id); tween_property
## calls are just skipped for it. Ends by hiding merge_panel, the same state
## change the no-animation branch above makes immediately.
##
## NO-187: result_tex no longer tweens modulate:a — it starts and stays fully
## opaque (show_merge_confirm), so there's no dimness left to animate out of.
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
	UiAnim.input_dead(merge_panel)
	var tw := merge_panel.create_tween()
	tw.set_parallel(true)
	if a_tex:
		tw.tween_property(a_tex, "modulate:a", 0.0, Tuning.MERGE_ANIM_S)
	if b_tex:
		tw.tween_property(b_tex, "modulate:a", 0.0, Tuning.MERGE_ANIM_S)
	if result_tex:
		tw.tween_property(result_tex, "scale", Vector2.ONE, Tuning.MERGE_ANIM_S) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
func _overlay_label(text: String, variation := &"") -> Label: # NO-256: a theme role, not a px size
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(g.get_viewport_rect().size.x - 48, 0)
	return l


## The end screens' frame (Casualties): everything but the buttons scrolls —
## a long run's Casualties mass does not fit — and the buttons sit in their
## own column pinned at the bottom (#577's dismiss-at-bottom), always on
## screen. Returns [content, buttons]; content is vertically centred while it
## fits, as the old CenterContainer did.
func _end_screen_frame() -> Array:
	_clear_overlay()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	overlay.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)
	var scroll := ScrollContainer.new()
	scroll.name = "EndScroll" # the tests' handle
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 24 # a drag on the mass scrolls; menu.gd's value
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	# EXPAND + SHRINK_CENTER: the labels' own width (_overlay_width), centred
	# in the scroll; EXPAND_FILL down, so ALIGNMENT_CENTER centres it while
	# it is shorter than the screen
	box.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.custom_minimum_size.x = _overlay_width() # the width the buttons had
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(buttons)
	return [box, buttons]


## `--scroll-bottom` (tools/capture.md): the end screen scrolled to its end,
## the newest Casualties above the buttons.
func scroll_end_screen_to_bottom() -> void:
	var scroll: ScrollContainer = overlay.find_child("EndScroll", true, false)
	if scroll != null:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _overlay_width() -> float:
	return g.get_viewport_rect().size.x - 48


## Below the stats: "Casualties" and one mass of every piece that died this
## run (game.gd `casualties`) in the order they died — first top-left, newest
## at the bottom by the buttons (Max, 2026-09-25) — each in the art of the
## side it died on. null (nothing added) with no casualties.
func _add_casualties(box: VBoxContainer, buttons: VBoxContainer) -> Control:
	if g.casualties.is_empty():
		return null
	var section := VBoxContainer.new()
	section.name = "Casualties"
	section.add_theme_constant_override("separation", 8)
	section.add_child(_overlay_label("Casualties", &"Heading"))
	var mass := PieceMass.build(g.casualties.map(func(c: Dictionary) -> String: return c.id),
		_overlay_width() - 2.0 * PieceMass.edge_pad(true), # rows + margin = the panel's inner width
		g.casualties.map(func(c: Dictionary) -> int: return c.side), CASUALTIES_PER_ROW)
	section.add_child(mass)
	box.add_child(section)
	_add_casualty_banner(mass, box, buttons)
	return section


## The Casualties' purple banner backdrop: a medieval-pennant shape (a
## rectangle ending in a single downward point) drawn BEHIND the whole
## `mass` — near-black enemy Pawns/Rooks were unreadable against the dark
## end-screen background (Max, 2026-09-26 review of #604's first cut).
##
## Lives OUTSIDE `mass`/`box`'s scrolled subtree, as a `top_level` Control
## tracking `mass`'s own `global_position`: a ScrollContainer clips its OWN
## descendants unconditionally, so the only way to let the point overflow
## PAST the scroll's clip rect and bleed in behind the pinned buttons
## (Max's 2nd review, after Aux's scroll-bottom capture showed a flat
## clipped edge instead of a point) is a node that isn't one of those
## descendants in the first place. That's why this lives in modals.gd, not
## piece_mass.gd: only this file owns the scroll/buttons split the banner
## now has to straddle.
##
## `top_level = true` opts a CanvasItem out of its PARENT Container's
## layout/resort pass entirely (Godot's own documented escape hatch for a
## freely-positioned overlay inside an otherwise rigid Container stack) —
## `col`'s VBoxContainer never touches its position/size — while sibling
## DRAW ORDER (and therefore z-order) still follows plain tree order, so
## inserting it as `col`'s first child, then `col`'s child order after that
## is `[layer, scroll, backing, buttons]`, keeps it behind everything.
##
## A second flat ColorRect (`backing`), also top_level, sits directly behind
## `buttons` so the button labels still read against the purple bleeding
## through — Max: "give the pinned button column a backing... so the text
## contrasts against the purple". Both are `MOUSE_FILTER_IGNORE` — "the
## banner never takes input" — and `buttons` itself, drawn after both, on
## top, keeps working exactly as before.
func _add_casualty_banner(mass: Control, box: VBoxContainer, buttons: VBoxContainer) -> void:
	var col_node: Node = buttons.get_parent() # _end_screen_frame()'s `col` —
		# the shared parent of `scroll` (== box.get_parent()) and `buttons`.
	if col_node == null:
		return # defensive: never observed in practice
	# Lift the crowd and the buttons clear of `_desat`'s z (build()'s own
	# ColorRect, `overlay`'s first child, carrying the #590 reveal's grey/dim
	# shader — both sit at the engine default z otherwise) so the banner has
	# a gap to occupy: see CASUALTY_ABOVE_DIM_Z_INDEX's own header.
	mass.z_index = CASUALTY_ABOVE_DIM_Z_INDEX
	buttons.z_index = CASUALTY_ABOVE_DIM_Z_INDEX
	var mass_w: float = mass.custom_minimum_size.x
	var mass_h: float = mass.custom_minimum_size.y
	var mx := CASUALTY_BANNER_MARGIN_X
	var banner_w := mass_w + mx * 2.0
	var depth := banner_w * CASUALTY_BANNER_POINT_DEPTH_RATIO
	var layer := Control.new()
	layer.name = "CasualtyBanner" # the tests' handle
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.top_level = true
	layer.z_as_relative = false # an absolute paint-order z, not accumulated
		# through whatever `col_node` happens to sit under
	layer.z_index = CASUALTY_BANNER_Z_INDEX # see that constant's own header —
		# `top_level` alone controls neither this nor `_desat`'s ordering; z_index does
	layer.size = Vector2(banner_w, mass_h + depth)
	col_node.add_child(layer)
	col_node.move_child(layer, 0) # tree position no longer controls paint
		# order for a top_level node (see CASUALTY_BANNER_Z_INDEX's header) —
		# kept anyway so a reader scanning `col_node`'s children still finds
		# this built first, matching the visual stacking intent
	var points := PackedVector2Array([
		Vector2(0.0, 0.0),                       # top-left (layer's own local origin)
		Vector2(banner_w, 0.0),                   # top-right
		Vector2(banner_w, mass_h),                 # right, above the point
		Vector2(banner_w * 0.5, mass_h + depth),   # the single downward point, centred
		Vector2(0.0, mass_h),                      # left, above the point
	])
	var body := Polygon2D.new()
	body.polygon = points
	body.color = CASUALTY_BANNER_COLOR
	layer.add_child(body)
	var border_points := points.duplicate()
	border_points.append(points[0]) # close the loop — Line2D has no `closed`;
		# built as its own local array, then assigned once — mutating a
		# PackedVector2Array through a property accessor (`node.points.append`)
		# can silently write to a temporary copy instead of the node's own.
	var border := Line2D.new()
	border.points = border_points
	border.width = CASUALTY_BANNER_BORDER_WIDTH
	border.default_color = CASUALTY_BANNER_BORDER_COLOR
	layer.add_child(border)
	var rod := ColorRect.new()
	rod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rod.color = CASUALTY_BANNER_BORDER_COLOR
	var rod_x := CASUALTY_BANNER_ROD_OVERHANG
	rod.position = Vector2(-rod_x, -CASUALTY_BANNER_ROD_HEIGHT * 0.5)
	rod.size = Vector2(banner_w + rod_x * 2.0, CASUALTY_BANNER_ROD_HEIGHT)
	layer.add_child(rod)

	# `layer`'s local (0,0) is `mass`'s own top-left minus the left margin
	# (`mass` sits `mx` in from the banner's own left edge); kept in sync
	# with `mass`'s GLOBAL position — not set once — because scrolling
	# moves `mass` (ScrollContainer offsets `box`'s whole subtree) without
	# resizing anything, so no Container resort or `resized` signal fires
	# for that on its own; the scrollbar's own `value_changed` is the
	# correct, direct hook for it instead.
	var sync := func() -> void:
		if is_instance_valid(mass) and is_instance_valid(layer):
			layer.global_position = mass.global_position - Vector2(mx, 0.0)
	_settle_repeatedly(sync, CASUALTY_BANNER_SETTLE_TICKS) # initial placement — the layout
		# this whole tree sits in can cascade across MORE than one deferred-
		# call flush (e.g. a vertical scrollbar appearing once content grows
		# past the viewport narrows `box`'s available width, which then
		# RE-CENTRES `mass` — a resort that runs its OWN deferred pass after
		# the one that first laid out this frame's new nodes). A single
		# call_deferred() caught that mid-cascade: Aux's scroll-bottom
		# capture of #604's 3rd cut still showed the banner ~20px off from
		# the real mass, matching a scrollbar's own width exactly.
	var scroll: ScrollContainer = box.get_parent()
	scroll.get_v_scroll_bar().value_changed.connect(
		func(_v: float) -> void: _settle_repeatedly(sync, CASUALTY_BANNER_SETTLE_TICKS)) # a
		# scroll (drag, or `scroll_end_screen_to_bottom()`) fires this signal
		# BEFORE `mass`'s own transform reflects the new offset — the same
		# too-early gap the initial placement above hits, so it gets the
		# same repeated-settle treatment rather than a single sync.call().
	scroll.resized.connect(sync) # a window/orientation resize can also move
		# everything without touching scroll_vertical — cheap insurance

	var backing := ColorRect.new()
	backing.name = "CasualtyButtonBacking" # the tests' handle
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.color = CASUALTY_BUTTON_BACKING_COLOR
	backing.top_level = true
	backing.z_as_relative = false
	backing.z_index = CASUALTY_BUTTON_BACKING_Z_INDEX # behind the buttons'
		# own text (CASUALTY_ABOVE_DIM_Z_INDEX), ahead of the banner
		# (CASUALTY_BANNER_Z_INDEX) — see that constant's own header
	col_node.add_child(backing)
	col_node.move_child(backing, 2) # tree position is cosmetic here too —
		# see the banner's own z_index comment above
	var sync_backing := func() -> void:
		if is_instance_valid(buttons) and is_instance_valid(backing):
			backing.global_position = buttons.global_position
			backing.size = buttons.size
	_settle_repeatedly(sync_backing, CASUALTY_BANNER_SETTLE_TICKS) # same cascade risk as
		# `sync` above — `buttons` itself gains more children (the actual
		# Restart/Continue/etc. rows) AFTER this function returns, each an
		# additional resort pass this must outlast.
	buttons.resized.connect(sync_backing) # buttons' own rect settles once
		# built (it doesn't scroll), so unlike the banner this needs no
		# scrollbar hook — just the same settle-then-resize coverage


## Re-invokes `cb` via call_deferred() `ticks` times in a row, each queued
## only once the previous one has actually run — see its own call sites
## above for why one deferred pass isn't always enough to observe a
## settled Container layout.
func _settle_repeatedly(cb: Callable, ticks: int) -> void:
	cb.call()
	if ticks > 1:
		call_deferred("_settle_repeatedly", cb, ticks - 1)


## The end screen's reveal (#590), with the Casualties section held back until
## the Score has counted up, then faded in. `rest` is everything else after
## the title, buttons included — they animate alpha only, so they take clicks
## from the first frame. Snaps with the reveal (animations off, autoplay).
func _reveal_end_screen(title: Label, box: VBoxContainer, buttons: VBoxContainer, section: Control,
		stats: Label, stats_at: Callable, delay: float, burst: bool) -> void:
	var rest: Array = box.get_children().slice(1).filter(func(c: Node) -> bool: return c != section)
	rest.append_array(buttons.get_children())
	_reveal(title, rest, stats, stats_at, delay, burst)
	if section == null or reveal == null:
		return
	section.modulate.a = 0.0
	reveal.tween_property(section, "modulate:a", 1.0, CASUALTIES_FADE_S)


const CASUALTIES_FADE_S := 0.4
## Pieces per Casualties row (Max, 2026-09-25: "rows of 6-8", side by side
## with light overlap; the mass grows taller and scrolls instead). At
## PieceMass.SPACED_PITCH that is a ~325px row, centred, in the ~432px panel; a
## narrower panel gets fewer per row, never a tighter pitch. Tune here.
const CASUALTIES_PER_ROW := 8

## Max, 2026-09-26: a purple medieval-banner backdrop behind the WHOLE
## Casualties mass — see _add_casualty_banner()'s own header for the shape
## and why it lives here rather than in piece_mass.gd.
const CASUALTY_BANNER_COLOR := Color(0.34, 0.2, 0.46, 1.0) # muted, deep royal
	# purple: darker/more saturated than the board's own purple tile
	# (game.gd's BOARD_THEMES["sage"].dark = "8763A8" = Color(0.53, 0.39, 0.66)).
	# Max, 2026-09-26 (5th review): fully opaque, not semi-transparent — it
	# reads as a BACKGROUND because it paints behind the pieces (z_index,
	# below), not because it's see-through.
const CASUALTY_BANNER_BORDER_COLOR := Color(0.58, 0.42, 0.75, 1.0) # a lighter,
	# also-opaque tint of the same hue — the border and the rod bar share
	# this one colour, kept to a single family rather than a second hue.
const CASUALTY_BANNER_BORDER_WIDTH := 2.0 # px
const CASUALTY_BANNER_MARGIN_X := PieceMass.ICON * 0.3 # px each side beyond
	# the mass's own width — "spans the mass's width plus a margin".
const CASUALTY_BANNER_POINT_DEPTH_RATIO := 1.0 / 3.0 # Max: "the point's
	# height roughly 1/3 of the banner's width" — off the banner's OWN width
	# (mass width + 2*margin), not a fixed px, so a narrow Casualties mass
	# never gets a comically deep point and a wide one never gets a
	# barely-there notch.
const CASUALTY_BANNER_ROD_HEIGHT := 4.0 # px, straddling the banner's own top edge
const CASUALTY_BANNER_ROD_OVERHANG := PieceMass.ICON * 0.15 # px the rod
	# extends past the banner's own sides — a flagpole crossbar reads as a
	# rod BECAUSE it's wider than the flag hanging from it.
const CASUALTY_BUTTON_BACKING_COLOR := Color(0, 0, 0, 0.55) # Max: "give the
	# pinned button column a backing... so the text contrasts against the
	# purple" bleeding through from the banner below.
const CASUALTY_BANNER_SETTLE_TICKS := 8 # deferred-call passes _add_casualty_
	# banner()'s position syncs re-queue themselves for — see that function's
	# own comment on the sync callables for why one pass isn't always enough.

## Max, 2026-09-26 (4th review): Aux's capture showed the banner drawing ON
## TOP of the crowd and the buttons — `top_level` only detaches a CanvasItem's
## TRANSFORM from its parent, it says nothing about paint order, and this
## engine draws top_level items in their own pass, after the normal nested
## tree, whatever their sibling index. hud.gd's `stock_panel.z_index = -1`
## is the precedent this reuses: z_index pins a CanvasItem's PAINT order
## independent of both tree position and top_level.
##
## (5th review): a negative z_index fixed that but broke a DIFFERENT layer —
## `build()`'s `_desat` (a ColorRect, `overlay`'s own first child, carrying
## the #590 reveal's screen-texture grey/dim shader — see this file's own
## `_set_desat`/`REVEAL_DESAT_S`) sits at the engine default z (0) too, and a
## negative z put the banner BEHIND that opaque dim layer as well, reading as
## near-black with no visible point. The banner needs to sit ABOVE `_desat`
## (0) but BELOW the crowd and the buttons — impossible while all three of
## `_desat`/mass/buttons share the SAME z (0), so `_add_casualty_banner()`
## also lifts `mass` and `buttons` to CASUALTY_ABOVE_DIM_Z_INDEX, opening a
## gap the banner and its button-backing sit inside. Final order, back to
## front: `_desat` (0) < banner (CASUALTY_BANNER_Z_INDEX) < button backing
## (CASUALTY_BUTTON_BACKING_Z_INDEX) < mass and buttons
## (CASUALTY_ABOVE_DIM_Z_INDEX) — the last two are `z_as_relative` (the
## default), so this is the ONLY z touched on them; everything else about
## how they draw (and each other's relative order) is untouched, so "the
## crowd must look exactly like v4 (full colour) over the purple" holds.
const CASUALTY_BANNER_Z_INDEX := 1
const CASUALTY_BUTTON_BACKING_Z_INDEX := 2
const CASUALTY_ABOVE_DIM_Z_INDEX := 3 # lifts `mass` and `buttons` clear of
	# `_desat`'s z (0) so the banner/backing above have somewhere to sit


func show_overlay(won: bool, reason: String, rank := 0) -> void:
	_end_of_run_on_top()
	var frame := _end_screen_frame()
	var box: VBoxContainer = frame[0]
	var buttons: VBoxContainer = frame[1]
	var title := _overlay_label("VICTORY" if won else "GAME OVER", &"Hero")
	box.add_child(title)
	box.add_child(_overlay_label(reason))
	var stats := " · Deepest wave %d\nKings %d · King Abilities seen %d\nPieces lost %d · Enemies slain %d" \
		% [g.wave, g.kings_defeated, g.king_abilities_seen.size(), g.lost_player, g.lost_enemy]
	if not g.king_ids_defeated.is_empty():
		var names: Array = g.king_ids_defeated.map(func(id: String) -> String: return Kings.name_of(id))
		stats += "\nDefeated: %s" % ", ".join(names)
	if rank > 0:
		stats += "\n" + ("Local rank #%d" % rank if rank <= 10 else "Off the local top 10")
	var stats_label := _overlay_label("Score %d" % g.score + stats)
	box.add_child(stats_label)
	# issue 75: show the seed so a good run can be replayed or shared. The BUILD
	# is shown beside it deliberately — a seed only reproduces within the build
	# it was rolled in, because any content change that shifts how many rolls
	# happen moves every downstream result (slices 47 and 48 each did exactly
	# that to a pinned-seed test). Without the version, a seed that stops
	# working after a patch looks like a bug rather than the expected behaviour.
	if g.next_seed != "":
		box.add_child(_overlay_label("seed  %s   ·   build %s"
			% [g.next_seed, ProjectSettings.get_setting("application/config/version", "dev")], &"Meta"))
	var section := _add_casualties(box, buttons)
	var restart := Button.new()
	restart.text = "Restart"
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	buttons.add_child(restart)
	var menu := Button.new()
	menu.text = "Main Menu"
	menu.pressed.connect(func() -> void:
		SceneFade.go(get_tree(), "res://scenes/Menu.tscn"))
	buttons.add_child(menu)
	# NO-254: below Restart/Main Menu, a normal (non-primary) button.
	var feedback := Button.new()
	feedback.text = "Give Feedback"
	feedback.pressed.connect(func() -> void: feedback_pressed.emit())
	buttons.add_child(feedback)
	overlay.visible = true
	var stats_at := func(s: int) -> String: return "Score %d" % s + stats
	_reveal_end_screen(title, box, buttons, section, stats_label, stats_at, KING_FALL_S if won else 0.0, won)


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
	# NO-100: the overlay is a translucent dim, so the kill feed under it
	# and the banner layer (the world, below the HUD) showed through it —
	# the capture that ends a full clear also restocks the Shop, and its
	# "SHOP RESTOCKED" banner read behind VICTORY. Hidden, not cleared:
	# _on_win_continue shows both again for the endless run.
	if g.hud != null:
		g.hud.feed.visible = false
	g._banner_layer.visible = false


func show_win_screen() -> void:
	_end_of_run_on_top()
	var frame := _end_screen_frame()
	var box: VBoxContainer = frame[0]
	var buttons: VBoxContainer = frame[1]
	var title := _overlay_label("VICTORY", &"Hero")
	box.add_child(title)
	# The King who just fell, else (the --show-screen capture, which opens this
	# without a fall) the King still on the board — never a bare "King" when
	# the run knows his name.
	var fallen: String = Kings.name_of(g.king_ids_defeated.back()) \
			if not g.king_ids_defeated.is_empty() else g._king_name()
	box.add_child(_overlay_label("The wave-%d King, %s, has fallen" % [g.wave, fallen]))
	var preview := 1 # GDD "ranking preview": where the score would land now
	for e in g.load_scores():
		if int(e.score) >= g.score:
			preview += 1
	var stats := " · rank #%d if ended now\nWave %d · King Abilities seen %d\nPieces lost %d · Enemies slain %d" \
		% [preview, g.wave, g.king_abilities_seen.size(), g.lost_player, g.lost_enemy]
	var stats_label := _overlay_label("Score %d" % g.score + stats)
	box.add_child(stats_label)
	var section := _add_casualties(box, buttons)
	# the question belongs to the buttons it asks about, so it stays with them
	buttons.add_child(_overlay_label("Continue into endless waves?"))
	var cont := Button.new()
	cont.text = "Continue"
	cont.pressed.connect(func() -> void: win_continue_pressed.emit())
	buttons.add_child(cont)
	var end := Button.new()
	end.text = "End Run"
	end.pressed.connect(func() -> void: win_end_pressed.emit())
	buttons.add_child(end)
	# NO-254: below Continue/End Run, a normal (non-primary) button — the win
	# screen shares this end-of-run overlay with show_overlay above.
	var feedback := Button.new()
	feedback.text = "Give Feedback"
	feedback.pressed.connect(func() -> void: feedback_pressed.emit())
	buttons.add_child(feedback)
	overlay.visible = true
	# after the King's shatter (S1), with a gold burst off the title
	var stats_at := func(s: int) -> String: return "Score %d" % s + stats
	_reveal_end_screen(title, box, buttons, section, stats_label, stats_at, KING_FALL_S, true)


# --- NO-243 S3 (audit rows 53/54): the end screens' staged reveal ------------
# The run behind the overlay greys and dims over REVEAL_DESAT_S (a screen-
# texture shader, so it is whatever was on screen, board and HUD alike), then
# the title drops in, then the rest fades up while the Score counts up to its
# total. Only alpha, scale and label text animate, never position or a mouse
# filter: the buttons take clicks from the first frame, wherever the reveal is.
const REVEAL_DESAT_S := 0.6
const REVEAL_TITLE_S := 0.35
const REVEAL_REST_S := 0.6
const KING_FALL_S := 0.4 ## a win waits out S1's King shatter (game.gd DIE_TIME) first
const BURST_S := 0.6
const BURST_COLOR := Color(1.0, 0.8, 0.3) ## S1's COL_GOLD_FX, the King-fall gold
const DESAT_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float amount = 1.0; // 0 = the run as it stands, 1 = greyed under the dim
uniform vec4 dim : source_color = vec4(0.08, 0.08, 0.1, 0.93); // the old panel dim
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec3 grey = vec3(dot(c, vec3(0.299, 0.587, 0.114)));
	COLOR = vec4(mix(c, mix(grey, dim.rgb, dim.a), amount), 1.0);
}
"""
var _desat := ColorRect.new() ## overlay's first child, kept across screens
var reveal: Tween ## the running reveal; null when the last one snapped


func _clear_overlay() -> void:
	for c in overlay.get_children():
		if c != _desat:
			c.queue_free()


func _set_desat(v: float) -> void:
	(_desat.material as ShaderMaterial).set_shader_parameter("amount", v)


## `rest` fades in after `title`; `stats` counts up through `stats_at`
## (score -> its text). Instant with animations off or in autoplay.
func _reveal(title: Label, rest: Array, stats: Label, stats_at: Callable, delay: float, burst: bool) -> void:
	if reveal:
		reveal.kill()
	reveal = null
	_set_desat(1.0)
	if g.autoplay or not g.animations_on:
		return
	_set_desat(0.0)
	title.modulate.a = 0.0
	for c in rest:
		(c as Control).modulate.a = 0.0
	stats.text = stats_at.call(0)
	reveal = create_tween()
	reveal.tween_interval(delay)
	reveal.tween_method(_set_desat, 0.0, 1.0, REVEAL_DESAT_S)
	reveal.tween_callback(func() -> void: title.pivot_offset = title.size / 2.0)
	reveal.tween_property(title, "modulate:a", 1.0, REVEAL_TITLE_S)
	reveal.parallel().tween_property(title, "scale", Vector2.ONE, REVEAL_TITLE_S) \
		.from(Vector2(1.8, 1.8)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in rest.size():
		if i > 0:
			reveal.parallel()
		reveal.tween_property(rest[i], "modulate:a", 1.0, REVEAL_REST_S)
	var count := func(v: float) -> void:
		stats.text = stats_at.call(roundi(v))
	reveal.parallel().tween_method(count, 0.0, float(g.score), REVEAL_REST_S) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if burst:
		_gold_burst(title, delay + REVEAL_DESAT_S)


## Row 54: gold chips fly out of the title as it lands. Input-dead, freed
## with the screen.
func _gold_burst(title: Control, delay: float) -> void:
	var b := Control.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("t", 0.0)
	overlay.add_child(b)
	var paint := func() -> void:
		var t: float = b.get_meta("t")
		if t <= 0.0 or t >= 1.0:
			return
		var c := title.get_global_rect().get_center() - b.global_position
		var sz := 9.0 * (1.0 - t)
		for i in 18:
			var at := c + Vector2.from_angle(TAU * i / 18.0) * lerpf(24.0, 200.0, ease(t, 0.3))
			b.draw_rect(Rect2(at - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), Color(BURST_COLOR, 1.0 - t))
	b.draw.connect(paint)
	var step := func(t: float) -> void:
		b.set_meta("t", t)
		b.queue_redraw()
	var tw := b.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(step, 0.0, 1.0, BURST_S)


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
## read — null for a board tile, the one thing never sellable from here.
## The Sell button is built only when `entry` is given, and disabled (never
## omitted) when Shop.can_sell says no for a dynamic reason (not the
## player's turn, the starvation softlock) — same convention as the Shop's
## own Buy button.
##
## NO-223 (2026-09-22 ruling): `cap` — true for a Captured Stock stack.
## Convert and Sell are not the same thing: a Captured entry gets a Convert
## button instead of Sell (never both), reflecting what's actually permitted
## rather than a disabled Sell nobody can use (the 2026-09-19 ruling still
## stands — Captured sells only after converting to Stock). `entry` used to
## be nulled for a Captured stack specifically so this Sell-button block
## never fired for one; it no longer is (game.gd's _show_preview passes it
## through unconditionally now), because Convert needs it too. An Item also
## gets a Use button beside Sell — the same action a plain tap already fires
## (`_use_item`), just reachable from this menu too; an Artefact does not
## (its Activate stays a plain tap on the cell, never duplicated in here).
##
## NO-167 (Max review, second pass, 2026-09-20): `shop_index` mirrors `entry`
## in the opposite direction — a Shop tile is unowned, so there is no `entry`
## to sell, but the same modal now shows it too (name/rarity/description/
## price, matching a held item/artefact's layout) with a Buy button in Sell's
## place. `kind` is "box" here as well as "piece"/"item"/"artefact" — a Shop-
## only kind that never had a preview before this, added to the "item"/
## "artefact" branch below (no diagram, same as those two). Mutually
## exclusive with `entry` in practice (a caller passes one or the other,
## never both — see _show_shop_preview vs. _show_preview/_show_kind_preview
## in game.gd), so the two blocks below don't need to guard against both
## firing at once.
## `piece` (NO-185): the buffs-bearing Dictionary for a "piece" kind — board[at]
## or a Stock/Captured entry (game.gd's own `entry`, ADR-0002-shaped); {} for
## a Shop slot (never owned, so never buffed) and ignored for "item"/
## "artefact"/"box".
func show_preview(kind: String, id: String, king_id := "", entry: Variant = null,
		shop_index := -1, piece: Dictionary = {}, cap := false) -> void:
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
		if shop_index >= 0:
			box.add_child(_priced_title(g.defs[id].name, g.shop_stock[shop_index], false))
		else:
			var title := Label.new()
			title.text = g.defs[id].name
			title.theme_type_variation = &"Title"
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(title)

		var dia := Control.new()
		var cells := 9 # covers the longest leap (Ying Long's 4)
		var cell := 30
		dia.custom_minimum_size = Vector2(cells, cells) * cell
		# NO-171 (root cause, not an offset nudge): PieceDiagram.draw paints the
		# chequer from dia's own (0,0), assuming its rect IS the cells*cell box.
		# Without SHRINK_CENTER, a plain Control defaults to filling the VBox's
		# full width — and the legend line below (or the King Ability desc
		# labels, sized to near the full viewport width) was routinely wider
		# than 270px, stretching `dia` to match and pinning the painted board
		# to its new left edge instead of centring it. The "item"/"artefact"
		# branch's own icon TextureRect below already carries this same flag;
		# `dia` was simply the one node in this function that never got it.
		dia.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var dia_tex: Texture2D = g.piece_tex(id) if g.textures.has(id) else null
		dia.draw.connect(func() -> void: PieceDiagram.draw(dia, g.defs, id, cells, cell, dia_tex))
		box.add_child(dia)

		_add_preview_legend() # NO-171: hidden by default behind a top-left button

		# NO-185: reuses BuffLogic.describe() — the exact text NO-152's targeting
		# tip already shows — dropping its first line (the piece name) since the
		# title above already carries it.
		var buff_lines: PackedStringArray = BuffLogic.describe(id, piece, g.defs).split("\n")
		if buff_lines.size() > 1:
			var buffs_label := Label.new()
			buffs_label.text = "\n".join(buff_lines.slice(1))
			buffs_label.theme_type_variation = &"Meta"
			buffs_label.modulate = Color(1, 1, 1, 0.85)
			buffs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			buffs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			buffs_label.custom_minimum_size = Vector2(minf(260, g.get_viewport_rect().size.x - 96), 0)
			box.add_child(buffs_label)

		# Stunned is a debuff riding the same buffs list as a Piece Buff, but
		# is NOT catalogued (buff_logic.gd's module header) so it's absent
		# from buff_lines above — BuffLogic.describe() skips it on purpose.
		# Its own line here, in the board badge's red (g.STUN_BADGE_COL).
		if BuffLogic.has(piece, "stunned"):
			var stun_label := Label.new()
			stun_label.text = "Stunned"
			stun_label.theme_type_variation = &"Meta"
			stun_label.modulate = g.STUN_BADGE_COL
			stun_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(stun_label)

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
				tr.custom_minimum_size = Vector2(96, 96) # NO-171: 2x the old 48
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				if chain[i] != id:
					tr.modulate = Color(1, 1, 1, 0.45) # current stage stands out
				row.add_child(tr)
			box.add_child(row)

		var kit: Dictionary = Kings.kit_of(king_id)
		if kit.has("power_key"): # a bespoke Power (banner pass 2026-09-22):
			# not in the King Ability catalog, so it is listed from the kit
			var phead := Label.new()
			phead.text = "King Power — all wave"
			phead.theme_type_variation = &"Heading"
			phead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(phead)
			_add_power_row(box, str(kit.power_name), str(kit.power_desc))
		if kit.has("power_catalog_key") or kit.has("power_catalog_escalation"):
			var head := Label.new()
			head.text = "%s — King Abilities in force" % str(kit.get("power_name", ""))
			head.theme_type_variation = &"Heading"
			head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(head)
			_add_king_ability_rows(box)
	else: # "item" / "artefact" / "box" (NO-167: box is new — a Shop-only
		# kind, never previously owned or previewed) — icon, name,
		# description; no movement diagram. shop_index >= 0 reads off the
		# live unowned Shop slot (Shop's own display_name/description/
		# rarity_of/price, icon via this file's own _shop_icon — already
		# handles all four kinds, including box's placeholder); otherwise
		# off `entry`, an owned g.items/g.artefacts element, same as before.
		var slot: Dictionary = g.shop_stock[shop_index] if shop_index >= 0 else {}
		if shop_index >= 0:
			box.add_child(_priced_title(Shop.display_name(g, slot), slot, true))
		else:
			var title := Label.new()
			title.text = str(entry.name)
			title.theme_type_variation = &"Title"
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(title)

		# artefact_tex() never returns null (art or the shared placeholder);
		# an Item can, so it falls back to the same "✦" glyph its drawer cell
		# and the Shop's own _shop_icon already use (which also covers box,
		# with no painted art of its own yet either).
		var icon: Variant = _shop_icon(slot) if shop_index >= 0 else \
			(g.item_icons.get(id) if kind == "item" else g.artefact_tex(id))
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
			glyph.text = str(icon) if shop_index >= 0 else "✦" # a Shop slot's
				# own glyph fallback already varies by kind (_shop_icon); an
				# owned entry always fell back to the same ✦ regardless
			glyph.add_theme_font_size_override("font_size", 40)
			glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(glyph)

		# NO-167: rarity, previously only shown on the Shop's own tile/detail
		# — now shown here for both a Shop preview and a held artefact's
		# (entry.rarity is stamped at acquisition, shop.gd's buy()); an Item
		# has no rarity either way, so this stays empty and skipped for one.
		var rarity := Shop.rarity_of(slot) if shop_index >= 0 else str(entry.get("rarity", ""))
		if rarity != "":
			var rlabel := Label.new()
			rlabel.text = rarity
			rlabel.theme_type_variation = &"Meta"
			rlabel.add_theme_color_override("font_color", Tuning.ARTEFACT_RARITY_COLOR[rarity])
			rlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(rlabel)

		var desc_text := Shop.description(slot) if shop_index >= 0 else str(entry.get("description", ""))
		if desc_text != "":
			var desc := Label.new()
			desc.text = desc_text
			desc.modulate = Color(1, 1, 1, 0.8)
			desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.custom_minimum_size = Vector2(g.get_viewport_rect().size.x - 96, 0)
			box.add_child(desc)

		# All-Seeing Eye Contact Lens (49): "Boxes reveal their contents
		# before you buy or choose them" — X-ray gated on holding the
		# Artefact, not on the roll (issue 47 already rolls every Box
		# unconditionally at stock time, so there is nothing left to gate
		# but the display). Ported from the old _shop_detail (NO-167).
		if shop_index >= 0 and slot.kind == "box" \
				and g._artefact_count("all-seeing-eye-contact-lens") > 0:
			var reveal := Label.new()
			reveal.text = "Contains: %s" % Box.contents_names(slot.contents)
			reveal.theme_type_variation = &"Meta"
			reveal.modulate = Color(1, 1, 1, 0.65)
			reveal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			reveal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(reveal)

	if shop_index >= 0:
		var slot: Dictionary = g.shop_stock[shop_index]
		var buy := Button.new()
		buy.text = "SOLD" if slot.sold else ("Watch ad" if slot.get("ad", false) else "Buy")
		buy.disabled = not Shop.can_buy(g, slot)
		buy.pressed.connect(func() -> void:
			preview_panel.visible = false
			preview_closed.emit() # same reset Close does — buying must not
				# leave preview_open stuck true (it deadens board input)
			shop_buy_pressed.emit(shop_index))
		box.add_child(buy)

	if entry != null:
		if kind == "piece" and cap:
			# NO-223 (2026-09-22 ruling): a Captured entry gets Convert here
			# instead of Sell — the ⇄ badge that used to do this is display
			# only now (hud.gd's _build_stack_button).
			var convert := Button.new()
			var convert_cost: int = Shop.convert_price(g, entry)
			convert.text = "Convert -$%d" % convert_cost # NO-256 ruling 2: a cost, red, no parentheses
			Tuning.money(convert, -convert_cost)
			convert.disabled = not Shop.can_convert(g, entry)
			convert.pressed.connect(func() -> void:
				preview_panel.visible = false
				preview_closed.emit()
				convert_pressed.emit(entry))
			box.add_child(convert)
		else:
			if kind == "item":
				# NO-223: the same action a plain tap on the cell already
				# fires (_use_item) — offered here too, alongside Sell. Never
				# shown for "artefact" (Activate stays a plain tap, not
				# duplicated into this menu) or "piece" (no Use concept).
				var use := Button.new()
				use.text = "Use"
				use.pressed.connect(func() -> void:
					preview_panel.visible = false
					preview_closed.emit()
					use_pressed.emit(kind, entry))
				box.add_child(use)
			var sell := Button.new()
			var payout: int = Shop.sell_payout(g, kind, entry)
			sell.text = "Sell +$%d" % payout # NO-256 ruling 2: a gain, green
			Tuning.money(sell, payout)
			sell.disabled = not Shop.can_sell(g, kind, entry)
			sell.pressed.connect(func() -> void:
				preview_panel.visible = false
				preview_closed.emit() # same reset Close does — sale must not
					# leave preview_open stuck true (it deadens board input)
				sell_pressed.emit(kind, entry))
			box.add_child(sell)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void:
		preview_panel.visible = false
		preview_closed.emit())
	# Max ruling 2026-09-24 (isolated dismiss): same shared commit/cancel
	# shape as show_choice_pick/show_merge_confirm — Buy/Convert/Use/Sell (if
	# any were built above) stay grouped together; Close sits alone below
	# MODAL_CANCEL_GAP.
	var close_gap := Control.new()
	close_gap.custom_minimum_size = Vector2(0, MODAL_CANCEL_GAP)
	box.add_child(close_gap)
	box.add_child(_centered(close))
	# NO-243 (row 49): grows out of the point that was tapped or long-pressed
	# (the pointer is still there), rather than snapping in at the centre.
	UiAnim.modal_in(g, preview_panel, center, g.get_viewport().get_mouse_position(),
		PREVIEW_FROM)


const PREVIEW_FROM := 0.2 # NO-243: the preview's first scale, at the tapped point


## NO-171: the move legend, hidden by default behind a small button at the
## panel's top-left, opening a small floating panel above it. preview_panel
## is a PanelContainer, which stretches EVERY direct child to its own full
## content rect (Godot's documented behaviour, same reason `center` alone
## fills it today) — so the button and legend panel are free-positioned
## children of an `overlay` Control (a plain Control, not a Container) that
## is ITSELF the one direct child added here, rather than being added to
## preview_panel directly, where PanelContainer would override their
## position every layout pass. `overlay` is added after `center`, so it
## draws on top, and carries MOUSE_FILTER_IGNORE so an empty part of it
## (everywhere except the button/legend) doesn't steal taps meant for the
## diagram or the Sell/Close buttons underneath — same idiom as _slide_shop's
## own IGNORE comment (a parent's IGNORE doesn't disable a child's own STOP).
## Being a sibling of `center` rather than a child of `box` is also what
## makes "the diagram stays anchored as it toggles" true: an in-flow legend,
## even above a correctly-centred diagram, would still push the diagram down
## the screen by its own height every time it opened.
##
## Fixed top-left position, not measured against the diagram's own rect —
## this screen has no Godot run available to size against a real layout, so
## the numbers here (12px margin, a 220px-wide legend panel) are a
## reasonable guess; verify there's no overlap with the title in the tallest
## case (Sell + a chain + King Abilities) on real hardware.
func _add_preview_legend() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(overlay)

	var panel := PanelContainer.new()
	panel.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.07, 0.95)
	panel.add_theme_stylebox_override("panel", bg)
	panel.position = Vector2(12, 48)
	panel.custom_minimum_size = Vector2(220, 0)
	var legend := Label.new()
	legend.text = PieceDiagram.LEGEND
	legend.theme_type_variation = &"Meta"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(legend)
	overlay.add_child(panel)

	var btn := Button.new()
	btn.text = "?"
	btn.tooltip_text = "Move legend"
	btn.position = Vector2(12, 12)
	btn.pressed.connect(func() -> void: panel.visible = not panel.visible)
	overlay.add_child(btn) # after `panel`: draws on top if they ever overlap


## The Shop drawer: docked at the right edge, covering ~90% of the screen
## (a sliver of board stays visible on the left, reading as a drawer rather
## than the old full-screen modal). No entrance animation — this codebase has
## no Control-tween precedent, a tween buys nothing acceptance criteria test
## for, and it made click probes racy against the panel's in-flight position;
## simplest is the instant show every other panel here already uses.
## Never scrolls — every slot in g.shop_stock renders as an icon tile with a
## price badge, grouped into four fixed zones, all full-width and stacked
## top to bottom (PIECES, ARTEFACTS, ITEMS, BOXES — NO-142). NO-167 (Max
## review, second pass): tapping a tile no longer expands a dock in place —
## it opens the tile's own preview (show_preview, shop_index >= 0), the same
## modal a long-pressed Stock/Item/Artefact entry gets, with a Buy button
## where Sell would be; buying there emits shop_buy_pressed and game.gd
## reopens the Shop for fresh SOLD/affordability state. Close sits at the
## bottom of the Shop itself, permanently — nothing else lives in that zone
## any more, so there is no expanded/collapsed state for it to depend on.
func show_shop() -> void:
	var was_open := shop_panel != null and shop_panel.visible
	# NO-243: what changed since the Shop was last shown — read before the
	# old panel goes, since a bought tile flies from where it was drawn.
	var restocked: bool = _shop_seen_stock != null and not is_same(_shop_seen_stock, g.shop_stock)
	var bought := {} # index -> the old tile's screen rect
	if was_open and not restocked:
		for t in _shop_tiles:
			if t == null or not is_instance_valid(t):
				continue
			var i: int = (t as Button).get_meta("shop_index")
			if i < _shop_seen_sold.size() and g.shop_stock[i].sold and not _shop_seen_sold[i]:
				bought[i] = (t as Button).get_global_rect()
	_shop_seen_stock = g.shop_stock
	_shop_seen_sold = g.shop_stock.map(func(sl: Dictionary) -> bool: return sl.sold)
	_shop_tiles = []
	if _shop_tween: # NO-118: kill before the panel it targets is freed below
		_shop_tween.kill()
		_shop_tween = null
	if shop_panel:
		shop_panel.queue_free()

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

	# NO-167: Close moved to the bottom, permanently (see the plain Close
	# Button after `lower` below — the old detail dock it replaced is gone
	# entirely) — the header now carries only the title, the optional
	# Restock button, and Gold pinned to the far right.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "SHOP"
	title.theme_type_variation = &"Title"
	header.add_child(title)
	if g._held("jet-fuel-vial"): # issue 52: only while held (user ruling — a
		# Shop control, not part of the in-run Activate section)
		var restock := Button.new()
		restock.text = "Restock ($20)"
		restock.theme_type_variation = &"Meta"
		restock.disabled = not g._jet_fuel_restock_available()
		restock.pressed.connect(func() -> void: shop_restock_pressed.emit())
		header.add_child(restock)
	var gold_label := Label.new()
	# issue 64: buying is free of the Action cost. NO-143: dropped the "no
	# Action cost" suffix — noise, since the absence of a cost doesn't need
	# saying on every entry. NO-144: Sell/Convert moved off this label
	# entirely — Sell is now the previewed thing's own menu (modals.gd
	# show_preview), Convert the entry's own badge (hud.gd). NO-167: moved to
	# the header's far right, in HUD's own Gold green (hud.gd:453) rather
	# than a dimmed sub-label — NO-151 is the wider ticket for a $ symbol on
	# every player-facing currency, not touched here.
	gold_label.text = "$%d" % g.gold
	gold_label.theme_type_variation = &"Meta"
	gold_label.add_theme_color_override("font_color", Tuning.COL_GOLD)
	gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(gold_label)
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
	# (the project Theme's font, NO-256, since the bar isn't in the tree yet to
	# ask its own theme) plus 4px breathing room (2 top, 2 bottom), not a
	# guessed round number.
	var restock_font_size := 16 # NO-256: the ramp's small-meta size
	var restock_line_h := Tuning.ui_font().get_height(restock_font_size)
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
	# NO-167: Lane A (every Tuning.SHOP_RESTOCK_WAVES Waves, guaranteed) had no
	# on-screen readout at all — this gauge only ever showed Lane B's Score
	# progress. Shop.waves_until_lane_a(g) reads forward from g.wave, the same
	# n % SHOP_RESTOCK_WAVES == 0 test wave_logic.gd actually fires the
	# restock on, so this can't drift from it or from a resumed save. Same
	# outline treatment as lane_b_label (must read over both the groove and
	# the amber fill) and the same MOUSE_FILTER_IGNORE (must not steal a tap
	# meant for the panel underneath), anchored to the right end instead of
	# full-rect so the two labels don't overlap.
	var lane_a_label := Label.new()
	lane_a_label.text = "%dw" % Shop.waves_until_lane_a(g)
	lane_a_label.tooltip_text = "Waves until the Shop's guaranteed restock (Lane A)"
	lane_a_label.add_theme_font_size_override("font_size", restock_font_size)
	lane_a_label.add_theme_color_override("font_color", Color.WHITE)
	lane_a_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lane_a_label.add_theme_constant_override("outline_size", 3)
	lane_a_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lane_a_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Explicit pixel offsets off the CENTER_RIGHT anchor point, same idiom as
	# _shop_tile's own price badge (PRESET_BOTTOM_RIGHT + offset_left/top)
	# rather than relying on the Label's natural (unmeasured) minimum size.
	lane_a_label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	lane_a_label.offset_left = -30
	lane_a_label.offset_right = -6
	lane_a_label.offset_top = -restock_line_h / 2.0
	lane_a_label.offset_bottom = restock_line_h / 2.0
	lane_a_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_lane_b_bar.add_child(lane_a_label)
	root.add_child(shop_lane_b_bar)

	# NO-240 (Max, 2026-09-24): the Shop opens from Wave 1 but holds nothing
	# until its first restock (Tuning.SHOP_UNLOCK_WAVE). An empty grid of
	# section headers would read as "sold out"; one line says when it fills.
	shop_empty_label = null
	shop_lower = null
	if g.shop_stock.is_empty():
		shop_empty_label = Label.new()
		shop_empty_label.text = "Restocks at wave %d" % Tuning.SHOP_UNLOCK_WAVE
		shop_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		shop_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		shop_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shop_empty_label)
	else:
		_shop_tiles.resize(g.shop_stock.size()) # NO-243: indexed by shop_index
		var by_kind := {"piece": [], "artefact": [], "item": [], "box": []}
		for i in g.shop_stock.size():
			by_kind[g.shop_stock[i].kind].append(i)

		# V4 (Max review 2026-09-21): one master grid — PIECES (3 cols) and BOXES
		# (1 col) share a top row, ARTEFACTS and ITEMS each get their own
		# full-width row below at Tuning.OFFBOARD_GRID_COLS (5) — see the V4 note
		# above SHOP_SUBZONE_SEP for the column-alignment arithmetic.
		var piece_cols := 3
		var master_cols: int = Tuning.OFFBOARD_GRID_COLS

		shop_lower = VBoxContainer.new()
		shop_lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# NO-201: shrink to the block's own minimum and centre it in root's width,
		# rather than stretching to fill — unchanged by V4, now centring the
		# whole 3-row block instead of just the PIECES+BOXES row.
		shop_lower.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		shop_lower.add_theme_constant_override("separation", 8)

		# NO-210: PIECES and BOXES sit in an HBox whose cross-axis default is to
		# fill+centre each child — SHRINK_BEGIN on both pins them to the row's
		# top instead, unchanged by V4.
		# NO-241: 6 Boxes (5 Gold + the Ad Box) no longer fit one column beside
		# PIECES' 4 rows, so BOXES takes master columns 4-5 (2 cols x 3 rows,
		# shorter than PIECES) — the unused column 4 SHOP_BOXES_COL_SEP used to
		# stand in for. The 5-column alignment is unchanged: 3 + 2 = 5.
		var top_row := HBoxContainer.new()
		top_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top_row.add_theme_constant_override("separation", SHOP_SUBZONE_SEP)
		var piece_zone := _shop_zone(by_kind.piece, piece_cols)
		piece_zone.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top_row.add_child(piece_zone)
		var box_zone := _shop_zone(by_kind.box, 2)
		box_zone.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top_row.add_child(box_zone)
		shop_lower.add_child(top_row)
		shop_lower.add_child(_shop_zone(by_kind.artefact, master_cols))
		shop_lower.add_child(_shop_zone(by_kind.item, master_cols))
		root.add_child(shop_lower)

	# NO-167 (Max review 2026-09-20, second pass): the detail dock is gone
	# entirely — its one real job, Buy, moved to the tile's own preview
	# (shop_tile_preview_requested below; _shop_tile's press handler), so
	# the zone that used to hold it "either the hint or the detail" had
	# nothing left to justify existing. Close is simply the last thing in
	# the Shop now — always present, since it's the only thing here.
	# Max ruling 2026-09-24 (isolated dismiss): Close is the Shop's only
	# dismiss — sits alone below MODAL_CANCEL_GAP, same shape as every other
	# modal's Cancel/Close.
	var close_gap := Control.new()
	close_gap.custom_minimum_size = Vector2(0, MODAL_CANCEL_GAP)
	root.add_child(close_gap)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_shop) # NO-118: same path an outside click uses (game.gd)
	root.add_child(_centered(close))

	g.hud.add_child(shop_panel)
	shop_panel.move_to_front()
	# NO-243 (row 45): a restock flips every tile over in sequence, the
	# stagger shrunk to keep the whole sweep inside SHOP_FLIP_S.
	if restocked and not _shop_tiles.is_empty():
		UiAnim.deal_in(g, _shop_tiles, Vector2(0.05, 1.0),
			minf(UiAnim.DEAL_STAGGER, SHOP_FLIP_S / maxf(_shop_tiles.size() - 1, 1)))
	# NO-243 (row 44): the bought thing flies to the drawer it joined, and
	# its fresh tile's SOLD stamp slams in.
	for i in bought:
		var slot: Dictionary = g.shop_stock[i]
		if slot.kind != "box": # a Box opens its own pick instead
			UiAnim.fly_to(g, _shop_icon(slot), bought[i],
				g.hud.drawer_buttons["stock" if slot.kind == "piece" else "inventory"])
		_stamp_in(_shop_tiles[i].get_node("SoldStamp"))
	if not was_open: # NO-118: a rebuild while already open (Buy, Restock, ...)
		# reuses the fresh panel at rest with no re-animation — it never left
		# the screen.
		_slide_shop(true)


## NO-243: a restock's flip sweep ends by this + DEAL_S (0.4 s total).
const SHOP_FLIP_S := 0.25
## NO-243: the SOLD stamp's slam — from this scale down to rest.
const STAMP_FROM := 1.8


func _stamp_in(stamp: Control) -> void:
	if not UiAnim.on(g):
		return
	var rest := stamp.modulate.a
	stamp.scale = Vector2(STAMP_FROM, STAMP_FROM)
	stamp.modulate.a = 0.0
	var tw := stamp.create_tween().set_parallel()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.2)
	tw.tween_property(stamp, "modulate:a", rest, 0.12)


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
		# instead of rebuilding it (the kind of refill-not-rebuild the Box
		# pick's own _box_dock/_fill_box_dock does for its tile taps), this
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


## NO-188 (Max review): the one zone helper for PIECES/ARTEFACTS/ITEMS/BOXES
## now that none of them carry a label — position (top row vs. the two
## full-width rows below, V4) is what marks a zone, the same way the
## header/gold/Close already go unlabelled. Replaces the old
## _piece_grid/_shop_sub_zone split (which existed only to hang a label on
## three of the four). `cols` reserves the full row's width up front
## (Tuning.grid_row_w) so a short row aligns instead of centring itself
## (NO-132), and expands to fill its share of whatever vertical space its
## parent gives it (NO-142's "never read sparser") — PIECES/BOXES split
## `top_row`, ARTEFACTS/ITEMS each get their own row of `shop_lower`
## (show_shop, V4).
func _shop_zone(indices: Array, cols: int) -> CenterContainer:
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", SHOP_SUBZONE_SEP)
	grid.add_theme_constant_override("v_separation", SHOP_SUBZONE_SEP)
	grid.custom_minimum_size.x = Tuning.grid_row_w(cols, SHOP_SUBZONE_SEP) # NO-132
	for i in indices:
		var tile := _shop_tile(i)
		_shop_tiles[i] = tile
		grid.add_child(tile)
	center.add_child(grid)
	return center


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


## NO-256 (d): a Shop preview's "Name — $N" title, the price in its money
## colour (green; red when the player can't pay; "Watch ad" stays white). One
## RichTextLabel, so `wrap` can still break a long name across lines.
func _priced_title(name_text: String, slot: Dictionary, wrap: bool) -> RichTextLabel:
	var price := Shop.price_text(g, slot)
	if not slot.get("ad", false):
		price = "[color=#%s]%s[/color]" % [Tuning.money_color(0, Shop.affordable(g, slot)).to_html(false), price]
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.scroll_active = false
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	t.add_theme_font_override("normal_font", TITLE_FONT)
	t.add_theme_font_size_override("normal_font_size", 32) # the Title variation's size
	t.text = "[center]%s — %s[/center]" % [name_text.replace("[", "[lb]"), price]
	return t


const TITLE_FONT := preload("res://assets/fonts/PixelOperator-Bold.ttf")


## NO-256: height of the price strip under a Shop tile's art (a 16 px line + 2).
const PRICE_STRIP := 18.0


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
			init_badge.theme_type_variation = &"Meta"
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
		# NO-243 (row 44): stamped SOLD across the art (show_shop slams it in
		# on the purchase itself). A child of the Button, not a container, so
		# its scale and rotation are its own.
		var stamp := Label.new()
		stamp.name = "SoldStamp"
		stamp.text = "SOLD"
		stamp.theme_type_variation = &"Heading"
		stamp.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		stamp.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.02))
		stamp.add_theme_constant_override("outline_size", 4)
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stamp.position = Vector2.ZERO
		stamp.size = Vector2(Tuning.OFFBOARD_ICON, Tuning.OFFBOARD_ICON - PRICE_STRIP)
		stamp.pivot_offset = stamp.size / 2.0
		stamp.rotation = -0.35
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(stamp)
	var price := Label.new()
	price.text = Shop.price_text(g, slot) # NO-241: "Watch ad" on the Ad Box
	price.theme_type_variation = &"Meta"
	if not slot.get("ad", false): # "Watch ad" stays white; a price is green, red if short
		Tuning.money(price, 0, Shop.affordable(g, slot))
	price.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	price.add_theme_constant_override("outline_size", 3)
	# NO-256: the price gets its own strip BELOW the art, inside the tile: the
	# tile's content area gives up PRICE_STRIP px at the bottom (so the
	# expand_icon art shrinks above it), and the price sits centred on one
	# line in that strip — never over the art, never past the tile's edge.
	# "Watch ad" is ~51 px at 16 px, inside the 72 px tile.
	for style in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBox = btn.get_theme_stylebox(style).duplicate()
		sb.content_margin_bottom = PRICE_STRIP
		btn.add_theme_stylebox_override(style, sb)
	price.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	price.offset_top = -PRICE_STRIP
	price.offset_bottom = 0
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.clip_text = true
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(price)
	# NO-167 (Max review, second pass): a tap opens the tile's own preview
	# instead of expanding an in-place dock — see show_preview's shop_index
	# and _show_shop_preview (game.gd), which owns preview_open.
	btn.pressed.connect(func() -> void: shop_tile_preview_requested.emit(index))
	return btn


## NO-141 (Max, 2026-09-19): an announcement, not a shop — the pieces are
## already in Stock by the time this shows (game.gd grants them the instant
## pending_reinforce is consumed, before calling this); `ids` is that same
## list, for display only. No Buy button, nothing left to choose or pay for.
## NO-170: dropped the "Wave N cleared — added to Stock, free of charge"
## subtitle — the title plus the mass of pieces below it already say this is
## an announcement, not a choice.
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
	title.theme_type_variation = &"Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var mass := PieceMass.build(ids) # NO-157
	box.add_child(mass)
	var dismiss := Button.new()
	dismiss.text = "Dismiss"
	dismiss.pressed.connect(func() -> void:
		_fly_mass_to_stock(mass) # NO-243 S4 row 50
		reinforce_panel.visible = false
		reinforce_done_pressed.emit())
	box.add_child(dismiss)
	g.hud.add_child(reinforce_panel)
	reinforce_panel.move_to_front()
	UiAnim.modal_in(g, reinforce_panel, center)
	_drop_in(mass) # NO-243 S4 row 50


## NO-243 S4 row 50: the reinforcements drop into the mass one by one. The
## mass places its TextureRects by hand (it is not a Container), so each can
## fall from above its own resting spot. The whole drop stays under
## REINFORCE_DROP_TOTAL however many pieces arrived.
const REINFORCE_DROP_S := 0.2
const REINFORCE_DROP_TOTAL := 0.4
const REINFORCE_DROP_PX := 36.0
func _drop_in(mass: Control) -> void:
	if not UiAnim.on(g):
		return
	var pieces: Array = mass.get_children().filter(func(c: Node) -> bool: return c is TextureRect)
	var gap := minf(0.05, REINFORCE_DROP_TOTAL / maxf(pieces.size(), 1.0))
	for i in pieces.size():
		var p: TextureRect = pieces[i]
		var rest := p.position.y
		p.position.y = rest - REINFORCE_DROP_PX
		p.modulate.a = 0.0
		var tw := p.create_tween().set_parallel()
		tw.tween_property(p, "position:y", rest, REINFORCE_DROP_S).set_delay(i * gap) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 1.0, REINFORCE_DROP_S * 0.5).set_delay(i * gap)


## NO-243 S4 row 50: Dismiss sends the pieces on to the Stock button (up to
## six ghosts: they are already in Stock, this only shows where they went).
func _fly_mass_to_stock(mass: Control) -> void:
	var pieces: Array = mass.get_children().filter(func(c: Node) -> bool: return c is TextureRect)
	for i in mini(pieces.size(), 6):
		var p: TextureRect = pieces[i]
		UiAnim.fly_to(g, p.texture, p.get_global_rect(), g.hud.drawer_buttons["stock"])


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
	title.theme_type_variation = &"Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_add_king_ability_rows(box)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void:
		king_ability_panel.visible = false
		# NO-100: restore what opening the panel hid, below (same pattern as
		# _end_of_run_on_top/_offer_ad_retry).
		if g.hud != null:
			g.hud.feed.visible = true
		g._banner_layer.visible = true)
	box.add_child(close)
	g.hud.add_child(king_ability_panel)
	king_ability_panel.move_to_front()
	UiAnim.modal_in(g, king_ability_panel, center) # NO-243 S4 row 51 (S2 had not)
	# NO-100: the panel is a translucent dim, so the kill feed and the banner
	# layer (the world, below the HUD) showed through it — same issue
	# _end_of_run_on_top/_offer_ad_retry already fixed for the end-of-run and
	# ad-retry panels. Hidden, not cleared: the Close handler above restores
	# both.
	if g.hud != null:
		g.hud.feed.visible = false
	g._banner_layer.visible = false


## One name + description pair per active King Ability, or a "none yet" line.
## Shared by the ⚠ overlay and a King's info panel (NO-83), so the two can
## never list different things.
##
## NO-172: no longer names the tariff's level ("(mild)") — `t.tier` (Mild/
## Moderate/Severe, king_abilities.gd) still exists in the catalog and still
## drives on_charge's mild_blocked case-match (artefact_hooks.gd), just no
## longer echoed here; the effect text (`t.description`) is untouched.
##
## Banner pass 2026-09-22: a bespoke King Power (Kings.bespoke_power — one
## with a `power_key`, dispatched in kings.gd rather than drawn from the
## catalog) is listed FIRST, from its kit. It is in force for the whole wave
## and was previously visible only in its 1.1s wave-start banner.
func _add_king_ability_rows(box: VBoxContainer) -> void:
	var power: Dictionary = Kings.bespoke_power(g)
	if not power.is_empty():
		_add_power_row(box, str(power.power_name), str(power.power_desc))
	if g.king_abilities_active.is_empty() and power.is_empty():
		var none := Label.new()
		none.text = "none yet — they land every 10th wave"
		none.modulate = Color(1, 1, 1, 0.6)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(none)
	for t in g.king_abilities_active:
		_add_power_row(box, str(t.name), Economy.ability_desc(g, str(t.key)))


func _add_power_row(box: VBoxContainer, name_text: String, desc_text: String) -> void:
	var name := Label.new()
	name.text = name_text
	name.theme_type_variation = &"Heading"
	name.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
	box.add_child(name)
	var desc := Label.new()
	desc.text = desc_text
	desc.modulate = Color(1, 1, 1, 0.75)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(g.get_viewport_rect().size.x - 96, 0)
	box.add_child(desc)


# --- box pick ---

## NO-168: the Box grid's own icon size — a DELIBERATE exception to
## Tuning.OFFBOARD_ICON (the "every off-board grid" standard: Shop, Inventory
## Drawer, Stock Drawer), not an accident: the box name and per-tile detail
## dock are both gone (below), so the icon — plus NO-186's own name label
## underneath it — is what carries the choice, hence bigger. 100px + 3 gaps
## (BOX_SEP) at 4 columns fits comfortably inside the 480px screen width with
## no MarginContainer here (unlike the Shop drawer): 4*100+3*8=424, leaving
## 28px total for the CenterContainer to split as margin — BOX_COLS is a
## CEILING on that same budget now, not the column count itself (_box_cols).
##
## NO-186 (Max review): "two rows, minimum two items per row" — a Small Box's
## 3 options used to sit on a single row (ceil(3/4)=1). _box_cols now picks
## ceil(count/2) columns (capped at BOX_COLS), so every size reads as exactly
## two rows: Small (3) -> 2 cols, 2+1 · Big (5) -> 3 cols, 3+2 · Huge (7) ->
## 4 cols, 4+3 (the split NO-168 already gave it). The name label under each
## tile (BOX_NAME_FONT_SIZE, ~1.3x-font line height by this file's other
## estimates) adds ~15px to every row: 100 (icon) + 2 (cell separation) + ~13
## (label) = ~115px. Two rows + BOX_SEP between them: 2*115+8 = ~238px for
## every size now (was up to 208px for Big/Huge, 100px for Small alone) — no
## Godot run from this seat to measure the real label height, but box_panel
## is a full-screen modal with no fixed budget the way the Shop drawer has,
## so there's ample room regardless.
const BOX_ICON := 100.0
const BOX_COLS := 4 # ceiling — see _box_cols
const BOX_SEP := 8.0
const BOX_NAME_FONT_SIZE := 16 # NO-256: was 10 (~7 px on screen); the ramp's small-meta size # "very small" — matches this file's smallest
	# existing label, the Shop tile's own price badge (_shop_tile)

## NO-186: columns that read `count` options as exactly two rows —
## ceil(count/2), capped at BOX_COLS so a wider box (more than 8 options,
## none exist today) never overflows the row-width budget BOX_COLS's own
## header works out.
func _box_cols(count: int) -> int:
	return clampi(ceili(count / 2.0), 1, BOX_COLS)


func _box_clear() -> void:
	for c in box_panel.get_children():
		box_panel.remove_child(c) # gone NOW, not at frame end: a re-render mid-frame
			# (NO-38's sell row) must not leave a freed button clickable
		c.queue_free()


## NO-168: no title any more — the box name ("Small Item Box") is gone from
## this screen; "PICK N" moved to its own label just above Skip (show_box).
func _box_vbox() -> VBoxContainer:
	_box_clear()
	box_panel.visible = true
	var center := CenterContainer.new()
	box_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
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
	head.theme_type_variation = &"Title" # Bold 32: the popup's title, never smaller than its buttons
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# NO-256: wrap at the column width. At Bold 20/24 an unwrapped header or
	# "name\ndescription" option ran past 480, the full-rect panel grew to fit
	# it, and the whole column (Cancel included) slid off the right edge.
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size = Vector2(420, 0)
	box.add_child(head)
	var dealt: Array = []
	for o in offers:
		var btn := Button.new()
		dealt.append(btn)
		btn.text = str(o.label)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(420, 0)
		if o.has("money"): # NO-256 (d): a Gold offer ("+$100") reads green
			Tuning.money(btn, o.money)
		var value = o.value
		btn.pressed.connect(func() -> void: choice_chosen.emit(value))
		box.add_child(btn)
	var cancel := Button.new()
	cancel.text = cancel_text
	cancel.pressed.connect(func() -> void: choice_pick_cancelled.emit())
	# Max ruling 2026-09-24 (isolated dismiss): the shared commit/cancel shape
	# (MODAL_CANCEL_GAP) — every offer stays grouped above, the dismiss sits
	# alone below a clear gap, never sharing a row with an action.
	var cancel_gap := Control.new()
	cancel_gap.custom_minimum_size = Vector2(0, MODAL_CANCEL_GAP)
	box.add_child(cancel_gap)
	box.add_child(_centered(cancel))
	g.hud.add_child(buff_panel)
	buff_panel.move_to_front()
	UiAnim.modal_in(g, buff_panel, center) # NO-243 (row 48): the Box's deal-in
	UiAnim.deal_in(g, dealt)


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


## One option = an icon tile with a small name label underneath (NO-186;
## additional to _box_detail's own description, which still only shows once
## selected — see BOX_ICON's own header). Tapping the ICON SELECTS it —
## box_expanded_index drives _fill_box_dock() below, same select-then-confirm
## shape NO-121/124 gave Items and NO-119 gave every other grid. meta.box_index
## lives on the icon Button (not the wrapping cell), same idiom meta.shop_index
## plays for _shop_tile and what the click probes search for.
func _box_tile(index: int) -> Control:
	var opt: Dictionary = _box_options[index]
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(BOX_ICON, BOX_ICON) # NO-168: bigger than
		# the OFFBOARD_ICON standard — see BOX_ICON's own header
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
		_fill_box_dock()
		_box_lift())
	cell.add_child(btn)

	var name := Label.new()
	name.text = opt.name
	name.add_theme_font_size_override("font_size", BOX_NAME_FONT_SIZE)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	name.custom_minimum_size = Vector2(BOX_ICON, 0)
	cell.add_child(name)
	return cell


## NO-168: a bigger-icon grid for the Box's own options — kept separate from
## the Shop's own zone helper (_shop_zone), since BOX_ICON/BOX_SEP are this
## screen's own deliberate exception, not a site-wide standard. NO-186:
## `cols` comes from _box_cols(count), not a fixed constant, so the first row
## is always exactly full — no NO-132-style custom_minimum_size forcing
## needed (that trick is for a row narrower than a shared standard it must
## still align under; this grid has no such sibling to match).
## NO-220 (Max): a GridContainer left-aligns a partial last row (Small's 3
## options read as [2, 1] flush left) — he wants each row centred on its own,
## so a row of 1 under a row of 2 reads as a triangle. A GridContainer can't
## centre a partial row by itself, so this builds a VBoxContainer of
## per-row HBoxContainers instead, each with ALIGNMENT_CENTER — the OPPOSITE
## of hud.gd's stock/captured grids (NO-208/NO-209), which right-align their
## short row on purpose (fills bottom-right). Different surfaces, different
## intents — do not unify them. Every row's HBox is default-FILL, so the
## VBoxContainer stretches each one to the widest row's width (same
## mechanism _fill_rows_bottom_right relies on), which is what gives a
## shorter row room to centre in.
func _box_grid(count: int) -> CenterContainer:
	var center := CenterContainer.new()
	var cols := _box_cols(count)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", BOX_SEP)
	var i := 0
	while i < count:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", BOX_SEP)
		var hi := mini(i + cols, count)
		for j in range(i, hi):
			var cell := _box_tile(j)
			_box_cells.append(cell)
			row.add_child(cell)
		rows.add_child(row)
		i = hi
	center.add_child(rows)
	return center


## The selected tile's own detail (or nothing) — refilled on every tap.
## NO-168: no placeholder hint any more ("Tap an entry for details" and its
## own fixed-height dock panel are gone — the
## "tap for detail" zone the ticket named); this sits empty, taking no space,
## until a tile is actually selected, then shows _box_detail's icon/name/
## description row, plus a centred Pick button underneath it (NO-186's
## shared commit/cancel shape — see MODAL_CANCEL_GAP). _box_dock is a
## PanelContainer (stacks all direct children at the same rect), so the two
## pieces are wrapped in one VBoxContainer rather than added separately.
func _fill_box_dock() -> void:
	for c in _box_dock.get_children():
		c.free()
	if box_expanded_index >= 0 and box_expanded_index < _box_options.size():
		var opt: Dictionary = _box_options[box_expanded_index]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		col.add_child(_box_detail(opt))
		col.add_child(_centered(_box_pick_btn(opt)))
		_box_dock.add_child(col)


## The selected option's own icon + name/kind header + effect text — the
## dock content _fill_box_dock shows below the grid once a tile is picked.
## NO-186: Pick is no longer inline in this row — see _box_pick_btn and the
## shared commit/cancel shape (MODAL_CANCEL_GAP).
func _box_detail(opt: Dictionary) -> Control:
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
	name.theme_type_variation = &"Heading"
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if opt.kind == "artefact": # issue 20: rarity legibility
		var rarity: String = str(opt.payload.get("rarity", ""))
		if rarity != "":
			name.add_theme_color_override("font_color", Tuning.ARTEFACT_RARITY_COLOR[rarity])
	info.add_child(name)
	var desc := Label.new()
	desc.text = opt.description
	desc.modulate = Color(1, 1, 1, 0.8)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	row.add_child(info)
	return row


## The Pick confirm — the second tap of the select-then-confirm pair, built
## separately from _box_detail so it can sit centred underneath it (NO-186's
## shared commit/cancel shape). meta.box_pick exists for the click probes,
## same role meta.shop_index plays for _shop_tile.
func _box_pick_btn(opt: Dictionary) -> Button:
	var pick := Button.new()
	pick.text = "Pick"
	pick.set_meta("box_pick", true)
	pick.disabled = opt.kind == "artefact" and Shop.is_unique_held(g, opt.payload.key) # NO-244:
		# an offer rolled before the first probe was taken
	pick.pressed.connect(func() -> void:
		_box_fly(opt) # NO-243 (row 47): before box_chosen re-renders or closes the Box
		box_chosen.emit(opt))
	return pick


## NO-243 (row 47): the selected tile lifts, the others settle back. After a
## frame: the dock refill just above re-sorts the modal, and a sort resets a
## container child's scale (ui_anim.gd's header).
const BOX_LIFT := 1.08

func _box_lift() -> void:
	if not UiAnim.on(g):
		return
	await get_tree().process_frame
	for c in _box_cells:
		if not is_instance_valid(c) or not (c as Control).is_inside_tree():
			continue
		var btn: Button = (c as Control).get_child(0)
		btn.pivot_offset = btn.size / 2.0
		var up: bool = btn.get_meta("box_index") == box_expanded_index
		btn.create_tween().tween_property(btn, "scale",
			Vector2.ONE * (BOX_LIFT if up else 1.0), 0.1)


## NO-243 (row 47): the picked option's icon flies from its tile to the drawer
## it joins — Stock for a piece, Inventory for an Item or Artefact.
func _box_fly(opt: Dictionary) -> void:
	var i := _box_options.find(opt)
	if i < 0 or i >= _box_cells.size() or not is_instance_valid(_box_cells[i]):
		return
	var tile: Control = (_box_cells[i] as Control).get_child(0)
	UiAnim.fly_to(g, _box_icon(opt), tile.get_global_rect(),
		g.hud.drawer_buttons["stock" if opt.kind == "piece" else "inventory"])


## NO-243 (row 46): the Box's lid — a cover over the grid that lifts off and
## fades while the tiles deal in underneath. Drawn on the HUD layer (the grid
## is inside containers, which would place a child themselves), input-dead.
const BOX_LID_S := 0.25

func _box_lid(grid) -> void: # untyped: freed during the wait (ui_anim.gd modal_in)
	await get_tree().process_frame # the grid's first sort
	if not is_instance_valid(grid) or not grid.is_inside_tree():
		return
	var lid := Panel.new()
	lid.set_meta(&"box_lid", true)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.22, 0.12)
	sb.border_color = Color(0.85, 0.7, 0.35)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	lid.add_theme_stylebox_override("panel", sb)
	lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r: Rect2 = grid.get_global_rect()
	lid.position = r.position
	lid.size = r.size
	g.hud.add_child(lid)
	var tw := lid.create_tween().set_parallel()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(lid, "position:y", r.position.y - r.size.y * 0.6, BOX_LID_S)
	tw.tween_property(lid, "modulate:a", 0.0, BOX_LID_S)
	tw.chain().tween_callback(lid.queue_free)


func show_box(options: Array) -> void:
	# Above everything, like every other panel. Without this a Box could open
	# behind the Shop — reachable on any restock wave that also queues a Bounty
	# box — while box_open gates every input path in the game. The player saw
	# the Shop, could not act, and the clock kept draining, because Box Pick is
	# deliberately excluded from the tier pause list.
	box_panel.move_to_front()
	var fresh := not box_panel.visible # NO-243: a first open, not a re-render
	var rerolled := _box_rerolling
	_box_rerolling = false
	_box_cells = []
	_box_options = options
	box_expanded_index = -1 # NO-133: a fresh render — reroll/sell also call
		# back in here with a new/changed offer, so nothing carries over
	var picks: int = 1 + g.box_picks_left # Nostradamus Mad Libs stacks on
		# top of a Box's own native picks (Huge = 2 — issue 47); read off
		# g.box_picks_left, itself seeded from Box.SIZES[size].picks
		# (game.gd's _open_box_pick) — never a literal here.
	var box := _box_vbox()
	# NO-151: pin the modal's width instead of letting it fall out of whichever
	# child happens to be widest. Shortening Skip's label ("+20 gold" -> "+$20")
	# narrowed the panel and the Pick confirm then intermittently failed to
	# appear on the final pick — 9 failures in 19 runs, 0 in 10 once pinned.
	# 420 is this file's existing row width (the Sell rows below, _shop_tile).
	box.custom_minimum_size.x = 420
	# NO-168: bigger icons (BOX_ICON, a deliberate exception — see its own
	# header) than the Shop/Stock OFFBOARD_ICON standard's grid, now that its
	# name and per-tile dock chrome are gone. NO-186: always exactly two
	# rows (_box_cols) — see BOX_ICON's own header for the per-size split.
	var grid := _box_grid(options.size())
	box.add_child(grid)
	_box_dock = PanelContainer.new() # NO-168: no fixed size/background any
		# more — see _fill_box_dock's own header
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
			var payout: int = Shop.sell_payout(g, "item", it)
			sell.text = "Sell %s +$%d" % [it.name, payout] # NO-256: a gain, green
			Tuning.money(sell, payout)
			sell.custom_minimum_size = Vector2(420, 0)
			sell.pressed.connect(func() -> void: box_sell_pressed.emit(it))
			box.add_child(sell)
	if g.box_rerolls_left > 0: # Bible Gag Reel Scroll / Snowden's Rubik's
		# Cube (issue 46) — only while the per-Box budget is above zero
		var reroll := Button.new()
		reroll.text = "Reroll (%d left)" % g.box_rerolls_left
		reroll.pressed.connect(func() -> void:
			_box_rerolling = true # NO-243: show_box spins the new offer in
			box_reroll_pressed.emit())
		box.add_child(reroll)
	# NO-168: "PICK N" replaces the box-name title (gone from _box_vbox above)
	# as this screen's one piece of header text — sat right above Skip, `picks`
	# is the same value the old combined title used, off g.box_picks_left,
	# never a literal.
	var pick_label := Label.new()
	pick_label.text = "PICK %d" % picks
	pick_label.theme_type_variation = &"Title"
	pick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(pick_label)
	# NO-186 (Max review): Skip pushed MODAL_CANCEL_GAP below PICK N — the
	# shared commit/cancel shape (Pick sits centred in _box_dock above, once
	# a tile is selected).
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, MODAL_CANCEL_GAP)
	box.add_child(gap)
	var skip := Button.new()
	# The Box's price, in Gold. The old label said "+20 score" while earn() paid
	# ~20 Gold AND 200 Score — wrong currency and wrong by 10x at once.
	var skip_gold: int = Tuning.box_skip_gold(g.box_size)
	skip.text = "Skip +$%d" % skip_gold # NO-256: a gain, green
	Tuning.money(skip, skip_gold)
	skip.pressed.connect(func() -> void: box_skipped.emit())
	box.add_child(_centered(skip))
	# NO-243: a first open pops the modal in, lifts the lid and deals the
	# tiles in under it (row 46); a reroll spins the new tiles over (row 47).
	# A re-render after a pick or a sale stays instant.
	if fresh:
		UiAnim.modal_in(g, box_panel, box.get_parent() as Control)
		if UiAnim.on(g):
			_box_lid(grid)
		UiAnim.deal_in(g, _box_cells, Vector2(0.6, 0.6), BOX_DEAL_STAGGER, BOX_DEAL_DELAY)
	elif rerolled:
		UiAnim.deal_in(g, _box_cells, Vector2(0.05, 1.0), BOX_DEAL_STAGGER)


## NO-243: 7 tiles (a Huge Box) end by 0.06 + 6 x 0.03 + 0.15 = 0.39 s.
const BOX_DEAL_STAGGER := 0.03
const BOX_DEAL_DELAY := 0.06
