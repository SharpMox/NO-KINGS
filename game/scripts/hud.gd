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
const Account := preload("res://scripts/account.gd")
const Settings := preload("res://scripts/settings.gd")
const Armies := preload("res://scripts/armies.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd") # NO-120: tip content for Stock/Captured

const DRAWER_H := 68.0 # one strip row; the inventory drawer stacks two

## NO-45: how far a finger must travel inside a drawer before the drag becomes a
## SCROLL rather than a tap. 24px, the same value menu.gd:654 settled on for the
## TEST list in PR #379 — one number for one gesture, and that one is device-
## verified on a Nothing Phone 2a.
##
## THE ROWS IN BOTH DRAWERS ARE MOUSE_FILTER_PASS FOR THE SAME REASON, and the
## pair is what makes it work. Viewport::_gui_call_input marks a pointer press
## handled at a MOUSE_FILTER_STOP control and stops climbing, so with STOP rows
## the press never reached the ScrollContainer and its touch drag — which only
## starts in that press branch — never began. PASS still delivers the press to
## the row, so taps and tooltips keep working; the deadzone is what stops a tap
## being read as a scroll.
##
## WHAT THIS COSTS, accepted by user ruling 2026-09-11 ("take the trade"): on
## DESKTOP the hover tooltip a row had under STOP is given up. Phones never had
## tooltips, so nothing is lost where the defect actually lives. Restoring the
## descriptions on desktop by tap is a separate, filed piece of work — it is a
## small feature (Godot's tooltips are hover-only), not a side-effect of this.
const DRAWER_SCROLL_DEADZONE := 24

## NO-59: the description popup. Preferred wrap width, and the gutter it keeps
## from every screen edge. Both are only PREFERENCES — _show_tip clamps the
## panel into the viewport whatever they are, because an item at the right edge
## of a 480-wide screen is where a popup anchored to its row goes off screen.
const TIP_W := 240.0
const TIP_MARGIN := 8.0
## NO-72: how long an item or Activate chip must be held to show its description
## instead of firing. Android's own long-press timeout
## (ViewConfiguration.getLongPressTimeout), so it feels like every other long
## press on the device rather than a number picked here.
const LONG_PRESS_MS := 500
## ---- INVENTORY DRAWER TUNING (NO-85) ----------------------------------------
## Every spacing number for the Inventory Drawer lives in THIS block. Canvas
## px. It opens UPWARD from the button row (story 45), over the lower board,
## at a FIXED height whatever it holds (story 46) — not measured at runtime,
## so it never resizes as Items/Artefacts come and go. One scrolling column:
## an Items grid, then an Artefacts grid (story 47) — the separate Activate
## section is gone, and an activatable Artefact joins the Artefacts grid with
## a ✹ marker instead (issue 52's chip idiom, carried over verbatim).
##
## INV_DRAWER_H keeps the old flat value (was INV_H_ACTIVATE: +1 row for the
## Activate strip, +48 for issue 100's Army Power line) rather than
## re-deriving it, so nothing jumps on this PR alone.
const INV_DRAWER_H := DRAWER_H * 3 + 118.0
const INV_CELL_SEP := 6 ## gap between cells, both axes, both grids
## NO-132: both grids are full width (472px avail: the drawer's 480 minus the
## ScrollContainer's 8px inset) — Tuning.grid_cols(472, 6) fits 6, capped at
## the OFFBOARD_GRID_COLS standard, so both land on 5 (set where the grids
## are built, off the same `vp.x - 8.0` the ScrollContainer itself uses).
## ----------------------------------------------------------------------------

## ---- HEADER TUNING (NO-83) -------------------------------------------------
## Every spacing number in the Header lives in THIS block, so tuning it on the
## phone means editing one place. Canvas px on the 480-wide viewport. Nothing
## here is measured at runtime: game.gd's board solve reads HEADER_H, and the
## notch inset (g.safe_top) is ADDED above it, never taken out of it.
## NO-125: hit the ticket's 75px target. Font.get_height() measured on Aux
## (2026-09-19) showed the LEFT column's three stacked rows (Score, Gold,
## Clock) don't fit 75 at the old CLOCK_FONT (36 -> 50px tall) — Score+Gold
## alone are 48px, leaving only 23px for the Clock once HEADER_PAD_Y*2 is
## paid, and 36 needs 50. 75/50 only clear that budget if either the Clock
## shrinks or Score/Gold do; the ticket protects the Clock specifically, but
## Score/Gold shrinking to fit was left open, so that's the lever pulled
## here: CLOCK_FONT drops 36 -> 15 (get_height 22px). 16 (23px) lands
## exactly on the 23px boundary with zero slack against rounding; 15 leaves
## 1px, matching how tight this same column's fit already ran before this
## ticket (SCORE_FONT's comment: 109 of 110, never landed on the exact
## edge). 15 is legible — it's the same size the ⚑ Wave counter already
## ships at (COUNTER_FONT) — but it costs the Clock its old visual
## prominence as the biggest thing in the Header; it now reads at the same
## size as the smallest counters instead of 2x their height.
const HEADER_H := 75.0
const HEADER_PAD_X := 10.0 ## gutter at the left and right edges
const HEADER_PAD_Y := 2.0 ## NO-125: halved from 4 — the only slack left once HEADER_H is at its content floor
const HEADER_GAP := 6.0 ## between the counters column, the Stock button and the menu button
const CLOCK_FONT := 15 ## NO-125: shrunk from 36 to fit 75 (see the HEADER_H note above) — was the largest text in the Header, now matches COUNTER_FONT
const SCORE_FONT := 17 ## a 17px Label is 24px tall (measured, NO-125): 2 + 24 + 24 + 22 fits the 75, 1px to spare
const GOLD_FONT := 17
const COUNTER_FONT := 15 ## the ⚑ Wave and turn counters
const COUNTER_W := 150.0 ## width of the centre column; a King's name ellipsises past it
const SYMBOL_W := 16.0 ## NO-114: fixed column for ★/$ so their digits align
const MENU_FONT := 15
const MENU_W := 34.0 ## the ☰ button's footprint in the corner
const STOCK_ICON := 44 ## the piece icon on the Stock button
const STOCK_BADGE_FONT := 13
const STOCK_BADGE_OFFSET := Vector2(14.0, -30.0) ## the count badge, from the icon's centre
const HEADER_BG := Color(0.06, 0.06, 0.08, 0.92) ## painted from y = 0, so it runs up behind the notch
## ----------------------------------------------------------------------------

## NO-127: below this, the Clock shakes + pulses red continuously as an
## urgency cue. Literally "under two minutes" per the ticket.
const CLOCK_URGENT_MS := 120000.0
## NO-126: the Score reads as a 6-digit odometer; greyed padding, unit text.
const SCORE_DIGITS := 6
const SCORE_ZERO_COLOR := Color(0.45, 0.45, 0.45)

## ---- STOCK DRAWER TUNING (NO-84) --------------------------------------------
## Every spacing number for the Stock Drawer lives in THIS block. Canvas px.
## It opens DOWNWARD from the Header's bottom edge (g.hud_top), full width, at
## a FIXED height computed from a fraction of the board's own pixel height —
## not measured at runtime, so it never resizes as stacks come and go. It
## overlays the board (ADR-0004's board-as-slack-absorber solve is untouched:
## this drawer never feeds back into the layout, only paints over it).
const STOCK_DRAWER_FRAC := 2.0 / 3.0 ## drawer height, as a fraction of the board's pixel height
const STOCK_DRAWER_CAP_FRAC := 1.0 / 3.0 ## Captured Stock column's share of the drawer width
const STOCK_DRAWER_PAD := 6.0 ## inner margin around each column's scroll area
## NO-132: column counts aren't fixed here — cap_w/stock_w below are already
## runtime values (vp.x split by STOCK_DRAWER_CAP_FRAC), so their grids call
## Tuning.grid_cols() directly off the same width the ScrollContainer uses,
## rather than a second hand-picked constant that could drift from it.
## Captured (~154px avail) fits 2; Stock (~314px avail) fits 4.
const STOCK_DRAWER_CELL_SEP := 6 ## gap between cells, both axes, both grids
## ----------------------------------------------------------------------------
## The first King's wave (data/kings.gd: "wave 50 -> king 1"; data/waves.gd row
## 50). The ⚑ Wave counter's denominator until that King falls (NO-82).
const WIN_WAVE := 50

signal pass_pressed
signal king_ability_pressed
signal stack_pressed(entry: Variant, cap: bool, count: int) # entry: ADR-0002
signal stack_drag_started(entry: Variant, cap: bool)
signal multi_confirm_pressed # NO-124: the floating targeting-confirm button —
	# was "multi"'s own Extract, generalised to every targeted Item/Artefact's
	# final confirm (see multi_confirm_btn's own declaration below)
signal item_pressed(index: int)
signal artefact_activate_pressed(key: String) # issue 52: an Activate chip pressed
signal army_ability_pressed # issue 67: the Army Ability chip pressed
signal promote_pressed(id: String)
signal convert_pressed(entry: Variant) # the ⇄ badge on a Captured entry (2026-09-06)
signal return_to_stock_pressed
signal drawer_changed
signal shop_pressed
signal menu_toggled(open: bool)
signal settings_changed(data: Dictionary) # a toggle changed; game.gd applies it live
signal arrow_toggle_pressed
signal arrow_clear_pressed


## Open or close the in-game menu. Shared by the ☰ button, Resume, and Android's
## hardware Back (game.gd's NOTIFICATION_WM_GO_BACK_REQUEST) so the three cannot
## drift apart — the emit in particular, which is what keeps game.gd's
## game_menu_open flag in step with what is on screen.
func toggle_menu(open: bool) -> void:
	# Never over a finished run. The pause menu raises itself above everything,
	# including the result overlay, and its Resume button would then restore a
	# run that is already over — a genuine trap rather than a cosmetic one.
	# Opening was previously unreachable at GAME_OVER only by accident of child
	# order and the Shop happening to cover the button, which is not a property
	# any future panel is obliged to preserve.
	# `win_open` as well as GAME_OVER: at the wave-50 victory screen the state is
	# still PLAYER_TURN, so the GAME_OVER test alone let the pause menu open on
	# top of it. Raising the overlay closed the mouse route to this button but
	# not the Back-key one, so the fix that hid the button created the hole.
	# From there "Main Menu" leaves without ever running _game_over, and the win
	# is never scored or recorded.
	if open and g != null and (g.state == g.State.GAME_OVER or g.win_open):
		return
	if open:
		game_menu.move_to_front() # above every other HUD control
	game_menu.visible = open
	menu_toggled.emit(open)


var g # the Game node — read-only from here; mutations go up via signals

var clock_label := Label.new()
var score_label := Label.new() # NO-126: the coloured, significant digits only
var score_zeros_label := Label.new() # NO-126: greyed leading-zero padding
var score_pts_label := Label.new() # NO-126: greyed " Pts" unit
var score_row := HBoxContainer.new() # NO-127: pulsed as one unit on a gain
var gold_label := Label.new() # spendable currency (score is the metric)
var gold_row := HBoxContainer.new() # NO-127: pulsed as one unit on a gain
var wave_label := Label.new()
var turn_label := Label.new()
var pass_button := Button.new()
var shop_button := Button.new()
var pass_count := Label.new() # blue N/M action counter on the PASS button
var pass_label := Label.new() # the "PASS" word next to the counter
var king_ability_button := Button.new() # top-row tariff count; opens the overlay
var arrow_button := Button.new() # Arrow Planning: toggles decorative drawing mode
var arrow_clear_button := Button.new() # clears every drawn arrow
var drawer_open := "" # "", "stock", "inventory"
var drawers := {} # name -> PanelContainer
var drawer_buttons := {} # name -> Button (count text updates)
## NO-118: each drawer's rest position and its fully-off-screen origin, set
## once in build() (Stock's own geometry never moves after that; the
## Inventory drawer is FIXED height too — see INV_DRAWER_H above), plus the
## in-flight Tween per drawer so a second toggle before the first finishes
## can kill it instead of racing it.
var drawer_rest := {} # name -> Vector2
var drawer_hidden := {} # name -> Vector2, off-screen along this drawer's own slide axis
var _drawer_tweens := {} # name -> Tween
## NO-118: name -> {Control: int}, the descendant mouse_filter values
## overridden to IGNORE while the drawer is closed/closing, so they can be
## restored exactly (not reset to a blanket STOP) on the next open. See
## _set_drawer_clickable's own comment for why this has to recurse at all.
var _drawer_saved_filters := {}
## NO-127: key -> Tween, the in-flight "gain" pulse or minute-shake per
## counter (Score/Gold/Clock) — same kill-first idiom as _drawer_tweens, so a
## second trigger before the first finishes replaces it instead of racing it.
var _gain_tweens := {}
## NO-127: last value refresh()/update_clock() actually RENDERED, so a gain
## animation is driven by the value changing, never by refresh() itself
## running (refresh() runs on nearly every state change). Paired with an
## explicit "have we observed one yet" flag rather than a sentinel VALUE
## (e.g. -1) — a sentinel is indistinguishable from a legitimate reading
## once any counter's real value can coincide with it, and the Clock's own
## per-frame delta can be negative. The first observation always just
## establishes the baseline; only a later CHANGE against it animates.
var _score_shown := 0
var _score_seen := false
var _gold_shown := 0
var _gold_seen := false
var _clock_shown_ms := 0.0
var _clock_shown_min := 0
var _clock_seen := false
## NO-127: the continuous under-2-minutes shake+pulse. Two loop Tweens (one
## per animated property) rather than one, so killing/restarting never has to
## unpick a parallel/chain sequence.
var _urgent_tweens: Array = []
var _clock_urgent_on := false # whether the loop above is ACTUALLY playing —
	# tracks the Settings toggle and autoplay too, not just the ms threshold,
	# so flipping either mid-run starts/stops it correctly.
var stock_armed := Control.new() # draws the armed piece on the Stock button
var stock_badge := Label.new() # the Stock count, on the Header's Stock button (NO-83)
var menu_button := Button.new() # ☰, the Header's top-right corner
var menu_tap := Control.new() # NO-60: its tap area, bigger than the glyph
var multi_confirm_btn := Button.new() # NO-124: floating targeting-confirm —
	# "Extract N" for a "multi" Item's picks, "Confirm" for a staged
	# tile/pair/area Item target, an untargeted Item, or Bovine Tractor
	# Beam's staged target (see refresh()'s visibility/text below)
## NO-59: the description popup and its text. Built once in build(), owned by
## the HUD rather than by any row — hud.refresh() frees every strip child, so a
## panel parented to a row would not survive the next state change.
var tip_panel: PanelContainer
var tip_label: Label
## Which artefact row the popup is currently describing, so tapping the same row
## again closes it. Empty when nothing is shown.
var tip_key := ""
## NO-84: Captured Stock (left third) and Stock (right two thirds) are two
## independent grids now, not one strip — each inside its own ScrollContainer
## so dragging one side never scrolls the other (story 36).
var stock_grid := GridContainer.new()
var captured_grid := GridContainer.new()
var captured_hint := Label.new() # "no Captured Stock yet" — shown only when empty
## NO-85: Items, one scrolling grid (story 48) — replaces the item_box strip.
var items_grid := GridContainer.new()
## NO-85: Artefacts, one scrolling grid (story 49) — replaces artefact_box
## (passive rows) AND activate_box (issue 52's Activate chips, now merged in
## with a ✹ marker per story 50, instead of a separate section).
var artefacts_grid := GridContainer.new()
## issue 100: the Army POWER, written out in the drawer. It was previously
## readable in exactly two places — the tooltip of the Ability chip (deleted by
## NO-32; the deck button carries that tooltip now), and the army-select screen
## before the run — and this is a portrait TOUCH game, so once a run starts a
## hover tooltip is unreachable. Several Powers change what
## is LEGAL (Close Ranks makes merges free, Endless Ranks makes pawn deploys
## free), so a player who has forgotten theirs is misreading their own rules.
var army_power_label := Label.new()
## The Army Ability, promoted out of the Inventory drawer onto the deck so its
## readiness is visible without opening a menu (design C).
var army_ability_button := Button.new()
## NO-115: a short reminder of what the Ability DOES, under its name — there
## is no hover to read the tooltip on a touch screen mid-run.
var army_ability_hint := Label.new()
## Height of the control deck. Drawers open ABOVE it rather than covering it:
## the deck is the persistent surface in design C, and a drawer that buries PASS
## and the Ability takes the two most-pressed controls away exactly when the
## player is mid-decision.
var deck_h := 0.0
## The bottom row: Ability beside PASS. Held as a member because build() places
## it before the power label exists and the final order is set afterwards.
var act_row: HBoxContainer
## The drawers row: Inventory and Shop, equal halves (NO-83 retired the Deck's
## Stock button — Stock opens from the Header).
var nav_row: HBoxContainer
var game_menu := PanelContainer.new() # in-game menu (pauses the clock)


## Deck surface styling, one place. The colours are the design-C prototype's
## tokens (issue 106): pill, power badge, ability, PASS. Applying
## them through a helper is what stops the four surfaces drifting into four
## slightly different greys the way the old bar did.
static func _surface(bg: Color, border: Color, radius: int = 8, pad_x: int = 10,
		pad_y: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func _style_button(b: Button, bg: Color, border: Color, radius: int = 8,
		pad_x: int = 10, pad_y: int = 4) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, _surface(bg, border, radius, pad_x, pad_y))


## NO-119: the tooltip/long-press text for an Items or Artefacts grid cell —
## name on its own line, then the description. Shared so a cell's tap target
## (no name text any more) and the popup that names it can never say two
## different things, and so tests asserting "the popup shows THAT entry's
## text" build the expected string from the same place the product code does.
static func _grid_tip_desc(entry_name: String, description: String) -> String:
	return "%s\n%s" % [entry_name, description]


func build(game) -> void:
	g = game
	var vp: Vector2 = g.get_viewport_rect().size
	# ---- THE HEADER (NO-82/NO-83) -------------------------------------------
	# The band above the board: g.hud_top tall, of which the top g.safe_top is
	# the platform's notch inset. The background is painted from y = 0 so it runs
	# up behind the notch; every control starts at `y0`, below it.
	var y0: float = g.safe_top
	var header_bg := ColorRect.new()
	header_bg.color = HEADER_BG
	header_bg.position = Vector2.ZERO
	header_bg.size = Vector2(vp.x, g.hud_top)
	header_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header_bg)
	# LEFT: Score, then Gold, then Clock at the bottom (NO-125 restack; was
	# Clock/Score/Gold, NO-82 stories 4-5 — Max wants the timer last).
	clock_label.add_theme_font_size_override("font_size", CLOCK_FONT)
	# NO-125: the box follows the font's own metric instead of a hardcoded
	# constant, so the next CLOCK_FONT change resizes it automatically rather
	# than silently clipping the way the old HEADER_H / 2 fraction did.
	clock_label.custom_minimum_size = Vector2(0, clock_label.get_theme_default_font().get_height(CLOCK_FONT))
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", SCORE_FONT)
	score_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.25))
	# NO-126: the odometer look — greyed padding zeros before the coloured
	# digits, greyed unit after. Same font, just a different colour, so all
	# three sit on one baseline in one row.
	score_zeros_label.add_theme_font_size_override("font_size", SCORE_FONT)
	score_zeros_label.add_theme_color_override("font_color", SCORE_ZERO_COLOR)
	score_pts_label.text = " Pts"
	score_pts_label.add_theme_font_size_override("font_size", SCORE_FONT)
	score_pts_label.add_theme_color_override("font_color", SCORE_ZERO_COLOR)
	gold_label.add_theme_font_size_override("font_size", GOLD_FONT)
	gold_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.4))
	# NO-114: ★ and $ are different glyph widths, so the bare symbol+number
	# labels didn't line up their digits. A fixed-width symbol column fixes it
	# without a monospace font.
	var score_symbol := Label.new()
	score_symbol.text = "★"
	score_symbol.add_theme_font_size_override("font_size", SCORE_FONT)
	score_symbol.add_theme_color_override("font_color", Color(0.95, 0.8, 0.25))
	score_symbol.custom_minimum_size = Vector2(SYMBOL_W, 0)
	var gold_symbol := Label.new()
	gold_symbol.text = "$"
	gold_symbol.add_theme_font_size_override("font_size", GOLD_FONT)
	gold_symbol.add_theme_color_override("font_color", Color(0.35, 0.85, 0.4))
	gold_symbol.custom_minimum_size = Vector2(SYMBOL_W, 0)
	score_row.add_theme_constant_override("separation", 0)
	# NO-126: zeros immediately after the symbol column — same x as the Gold
	# row's value (NO-114's alignment), the odometer padding just rides ahead
	# of the coloured digits instead of replacing them.
	for l in [score_symbol, score_zeros_label, score_label, score_pts_label]:
		score_row.add_child(l)
	gold_row.add_theme_constant_override("separation", 0)
	for l in [gold_symbol, gold_label]:
		gold_row.add_child(l)
	var left := VBoxContainer.new()
	left.position = Vector2(HEADER_PAD_X, y0 + HEADER_PAD_Y)
	left.custom_minimum_size = Vector2(0, HEADER_H - HEADER_PAD_Y * 2.0)
	left.add_theme_constant_override("separation", 0)
	for l in [score_row, gold_row, clock_label]:
		left.add_child(l)
	add_child(left)
	# CENTRE, flush to the bottom: ⚑ Wave over turns. The column has a fixed
	# width so a long King name is cut with an ellipsis rather than pushing into
	# the Stock button (story 20).
	var mid := VBoxContainer.new()
	mid.position = Vector2((vp.x - COUNTER_W) / 2.0, y0)
	mid.custom_minimum_size = Vector2(COUNTER_W, HEADER_H - HEADER_PAD_Y)
	mid.alignment = BoxContainer.ALIGNMENT_END
	mid.add_theme_constant_override("separation", 0)
	for l: Label in [wave_label, turn_label]:
		l.add_theme_font_size_override("font_size", COUNTER_FONT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		mid.add_child(l)
	wave_label.modulate = Color(1, 1, 1, 0.85)
	add_child(mid)
	# RIGHT: the menu in the corner, the Stock button just left of it.
	king_ability_button.add_theme_font_size_override("font_size", 13)
	king_ability_button.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
	king_ability_button.pressed.connect(func() -> void: king_ability_pressed.emit())
	arrow_button.text = "Arrows"
	arrow_button.add_theme_font_size_override("font_size", 13)
	arrow_button.pressed.connect(func() -> void: arrow_toggle_pressed.emit())
	# NO-83: the ⚠ and Arrows buttons are NOT on screen. Their state, signals
	# and handlers stay (refresh still writes their text) so nothing behind
	# them is lost; they get a home again when the Deck is redesigned (NO-84+).

	menu_button.text = "☰"
	menu_button.add_theme_font_size_override("font_size", MENU_FONT)
	menu_button.position = Vector2(vp.x - HEADER_PAD_X - MENU_W, y0 + HEADER_PAD_Y)
	menu_button.custom_minimum_size = Vector2(MENU_W, 0)
	# flat compact styling (2026-07-08); the two off-screen buttons keep theirs
	for b: Button in [king_ability_button, arrow_button, menu_button]:
		var compact := StyleBoxFlat.new()
		compact.bg_color = Color(0.22, 0.22, 0.26)
		compact.set_corner_radius_all(4)
		compact.content_margin_left = 7
		compact.content_margin_right = 7
		compact.content_margin_top = 1
		compact.content_margin_bottom = 1
		for style in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(style, compact)
	menu_button.pressed.connect(func() -> void: toggle_menu(true))
	add_child(menu_button)
	# NO-60: the glyph stays put (content-sized, top-right corner) but its tap
	# area gets the same treatment as the Stock button below — the Header's
	# full height, out to the physical corner. Left edge matches the button's
	# own, so it still stops short of Stock by HEADER_GAP same as before; a
	# transparent overlay on top rather than enlarging menu_button itself,
	# which would have recentred the glyph in the bigger rect (visual change).
	menu_tap.position = Vector2(menu_button.position.x, y0)
	menu_tap.custom_minimum_size = Vector2(vp.x - menu_button.position.x, HEADER_H)
	menu_tap.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_tap.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			toggle_menu(true))
	add_child(menu_tap)
	# THE STOCK BUTTON (stories 7-12). Its tap area is the Header's full height
	# and runs from the counters column to the menu button — and no further:
	# the bottom edge IS g.hud_top, where the board starts, and the right edge
	# stops HEADER_GAP short of the menu, so neither can be hit by accident.
	var stock_btn := Button.new()
	var stock_x: float = (vp.x + COUNTER_W) / 2.0 + HEADER_GAP
	stock_btn.position = Vector2(stock_x, y0)
	stock_btn.custom_minimum_size = Vector2(menu_button.position.x - HEADER_GAP - stock_x, HEADER_H)
	if g.textures.has("pawn"):
		stock_btn.icon = g.piece_tex("pawn") # Stock is always yours: the player token
		stock_btn.expand_icon = true
		stock_btn.add_theme_constant_override("icon_max_width", STOCK_ICON)
	else:
		stock_btn.text = "♟"
	_style_button(stock_btn, Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 8, 4, 4)
	stock_btn.pressed.connect(func() -> void:
		set_drawer("stock")
		drawer_changed.emit())
	# the count badge, same idiom as a pool stack's: a corner label over the icon
	stock_badge.add_theme_font_size_override("font_size", STOCK_BADGE_FONT)
	stock_badge.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	stock_badge.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	stock_badge.add_theme_constant_override("outline_size", 4)
	stock_badge.set_anchors_preset(Control.PRESET_CENTER)
	stock_badge.offset_left = STOCK_BADGE_OFFSET.x
	stock_badge.offset_top = STOCK_BADGE_OFFSET.y
	stock_badge.offset_right = STOCK_BADGE_OFFSET.x + 24.0
	stock_badge.offset_bottom = STOCK_BADGE_OFFSET.y + 16.0
	stock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stock_btn.add_child(stock_badge)
	# the armed stack rides on the Stock button, styled like a selection
	stock_armed.set_anchors_preset(Control.PRESET_FULL_RECT)
	stock_armed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stock_armed.draw.connect(_draw_stock_armed)
	stock_btn.add_child(stock_armed)
	drawer_buttons["stock"] = stock_btn
	add_child(stock_btn)
	# ---- THE CONTROL DECK (design C, user pick 2026-09-05) ------------------
	# Everything under the board lives in one column that starts where the board
	# ends and runs to the bottom edge. That is what removes the dead band: the
	# board is flush to the top strip, so all the leftover height arrives here in
	# one piece, and the rows below expand into it rather than leaving a gap.
	var deck_top: float = g.board_px.y + g.tile * Tuning.BOARD_H + 6.0
	var deck := VBoxContainer.new()
	deck_h = vp.y - deck_top
	# NO-115: the deck runs flush to both screen edges and the bottom — it used
	# to sit 4px in on each side and stop 6px short of the bottom, leaving a
	# dead strip under the thumb row. act_row (its last child) claims that
	# freed 6px via EXPAND|SHRINK_END below, so its own height doesn't move.
	deck.position = Vector2(0, deck_top)
	deck.custom_minimum_size = Vector2(vp.x, deck_h)
	deck.add_theme_constant_override("separation", 6)
	add_child(deck)

	# NO-83: the stock strip and the status line are gone from the Deck. The
	# strip's job (which pieces you hold, without opening anything) moves to
	# the Header's Stock badge; wave and turn moved up with it. The Deck is now
	# the drawers row, the Power badge and the thumb row.
	nav_row = HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 5)
	nav_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deck.add_child(nav_row)

	var bar := nav_row
	var inv := Button.new()
	inv.text = "Inventory"
	inv.add_theme_font_size_override("font_size", 17)
	inv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv.pressed.connect(func() -> void:
		set_drawer("inventory")
		drawer_changed.emit())
	drawer_buttons["inventory"] = inv
	bar.add_child(inv)
	shop_button.text = "Shop"
	shop_button.add_theme_font_size_override("font_size", 17)
	shop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_button.pressed.connect(func() -> void: shop_pressed.emit())
	bar.add_child(shop_button)
	# NO-124: floating targeting-confirm, shown once there's something to
	# confirm — see refresh() for exactly when, per targeting shape
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
	# green, matching the prototype: PASS ends your turn, it is not a warning
	_style_button(pass_button, Color(0.125, 0.196, 0.122), Color(0.290, 0.490, 0.278), 8, 11, 6)
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
	pass_count.add_theme_color_override("font_color", Color(0.498, 0.878, 0.541))
	pass_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pass_box.add_child(pass_count)
	pass_label.text = "PASS"
	pass_label.add_theme_font_size_override("font_size", 17)
	pass_label.add_theme_color_override("font_color", Color(0.902, 0.965, 0.902))
	pass_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pass_box.add_child(pass_label)
	pass_button.add_child(pass_box)
	# the ABILITY sits beside PASS on the last row: the two most-pressed controls,
	# lowest on the screen, inside the thumb arc (design C)
	army_ability_button.add_theme_font_size_override("font_size", 16)
	_style_button(army_ability_button, Color(0.231, 0.208, 0.141),
		Color(0.427, 0.373, 0.180), 8, 11, 6)
	army_ability_button.add_theme_color_override("font_color", Color(0.953, 0.886, 0.675))
	army_ability_button.add_theme_color_override("font_disabled_color", Color(0.62, 0.62, 0.62))
	army_ability_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	army_ability_button.pressed.connect(func() -> void: army_ability_pressed.emit())
	# NO-115: the effect hint (set in refresh()), UNDER the button rather than
	# appended into its own text — Button's autowrap re-flowed the whole
	# string past the name+status line instead of honoring an inserted "\n",
	# growing the row. A Label with its own fixed budget is predictable.
	# NO-115 fix (coordinator review 2026-09-18): act_row sits flush to the
	# screen bottom, so ANY shortfall in this Label's reserved height shows up
	# as the hint's own descenders sliced by the viewport edge, not just
	# visual crowding. 16px was sized for one bare line and didn't leave room
	# for descenders (p/y/g, all present in the truncated hint text) at this
	# font size. Shrinking the font and widening the reserved height is the
	# "fit inside the existing 60px budget" fix — act_row's own height is
	# unchanged, so board_tile_for()'s output can't move.
	army_ability_hint.add_theme_font_size_override("font_size", 10)
	army_ability_hint.add_theme_color_override("font_color", Color(0.78, 0.71, 0.55))
	army_ability_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	army_ability_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	army_ability_hint.custom_minimum_size = Vector2(0, 22)
	var ability_col := VBoxContainer.new()
	ability_col.add_theme_constant_override("separation", 1)
	ability_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ability_col.add_child(army_ability_button)
	ability_col.add_child(army_ability_hint)
	act_row = HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 5)
	# NO-115: EXPAND claims the deck's now-unused trailing space (see deck's
	# own comment above); SHRINK_END keeps act_row pinned at its own 60px
	# minimum and docks it at the bottom of that space, flush to the screen.
	act_row.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	act_row.custom_minimum_size = Vector2(0, 60)
	act_row.add_child(ability_col)
	act_row.add_child(pass_button)
	deck.add_child(act_row)

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
	resume.pressed.connect(func() -> void: toggle_menu(false))
	gm_box.add_child(resume)

	# Guide and Settings are shared with the Main Menu (scripts/guide.gd,
	# scripts/settings.gd) so both entry points show identical content
	var guide_scroll := Guide.build(game_menu, func() -> void: gm_box.visible = true)
	# Logging out mid-run LEAVES the run: its save was just parked under the
	# account that owns it, and staying in a live game whose save now belongs to
	# nobody would write a fresh unowned one on the next autosave. Back to the
	# menu, which comes up on the login screen.
	var settings_panel := Settings.build(game_menu, func() -> void: gm_box.visible = true,
		func(data: Dictionary) -> void: settings_changed.emit(data),
		func() -> void:
			# load() rather than preload(): menu.gd is a heavy scene script and a
			# compile-time edge here is the exact class of trap play_games_bridge
			# documents. Nothing needs it before this button is pressed.
			var MenuScript: GDScript = load("res://scripts/menu.gd")
			Account.logout(MenuScript._SAVE_PATHS())
			game.get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
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
	# it stays visible and clickable over them. Inventory scrolls as ONE column
	# (story 47): the Items grid, then the Artefacts grid — no separate
	# Activate section any more (NO-85).
	items_grid.columns = Tuning.grid_cols(vp.x - 8.0, INV_CELL_SEP) # NO-132
	items_grid.add_theme_constant_override("h_separation", INV_CELL_SEP)
	items_grid.add_theme_constant_override("v_separation", INV_CELL_SEP)
	artefacts_grid.columns = Tuning.grid_cols(vp.x - 8.0, INV_CELL_SEP) # NO-132
	artefacts_grid.add_theme_constant_override("h_separation", INV_CELL_SEP)
	artefacts_grid.add_theme_constant_override("v_separation", INV_CELL_SEP)
	army_power_label.add_theme_font_size_override("font_size", 13)
	army_power_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	army_power_label.custom_minimum_size = Vector2(vp.x - 24.0, 0)
	var inv_box := VBoxContainer.new()
	inv_box.add_theme_constant_override("separation", 8)
	# issue 100 put this at the top of the Inventory drawer. Design C brings it
	# onto the main view instead: a passive badge you can read without opening
	# anything, which was half the point of the redesign.
	# the Power is passive, so it is a BADGE: readable, and visibly not a button
	var power_badge := PanelContainer.new()
	power_badge.add_theme_stylebox_override("panel",
		_surface(Color(0.165, 0.20, 0.141), Color(0.275, 0.345, 0.235), 8, 10, 5))
	army_power_label.add_theme_color_override("font_color", Color(0.749, 0.878, 0.690))
	power_badge.add_child(army_power_label)
	deck.add_child(power_badge)
	# DECK ORDER (design C, cut down by NO-83): drawers under the board, the
	# passive power, and the thumb row last. The rows are built in whatever order
	# the rest of build() needs them, so the order that matters is asserted here
	# rather than implied by construction sequence.
	deck.move_child(nav_row, 0)
	deck.move_child(power_badge, 1)
	deck.move_child(act_row, 2)
	# (the power label used to sit here; design C moved it onto the deck)
	inv_box.add_child(items_grid)
	inv_box.add_child(artefacts_grid)
	var drawer_specs := [ # name, content, x, width, height
		["inventory", inv_box, 0.0, vp.x, INV_DRAWER_H],
	]
	for spec in drawer_specs:
		var panel := PanelContainer.new()
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.1, 0.13, 0.97)
		panel.add_theme_stylebox_override("panel", bg)
		panel.position = Vector2(spec[2], vp.y - deck_h - spec[4]) # above the deck
		panel.custom_minimum_size = Vector2(spec[3], spec[4])
		panel.visible = false
		var sc := ScrollContainer.new()
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER # NO-136
		sc.scroll_deadzone = DRAWER_SCROLL_DEADZONE # NO-45
		sc.custom_minimum_size = Vector2(spec[3] - 8, spec[4] - 8)
		# NO-65 fix: nothing in this drawer overhangs it any more (no promote
		# badge lives in Items/Artefacts — that was Stock's), so clip for real.
		sc.clip_contents = true
		sc.add_child(spec[1])
		panel.add_child(sc)
		drawers[spec[0]] = panel
		add_child(panel)
		drawer_rest[spec[0]] = panel.position
		# NO-118: Inventory slides in from the LEFT — off-screen is its own
		# width to the left of rest, not a move of where it rests.
		drawer_hidden[spec[0]] = panel.position - Vector2(spec[3], 0)
	# ---- THE STOCK DRAWER (NO-84) --------------------------------------------
	# Opens downward from the Header's bottom edge, next to the button that
	# opens it (story 31) — everything else in this file opens above the deck,
	# so this one is built separately rather than folded into drawer_specs.
	var stock_h: float = roundf(STOCK_DRAWER_FRAC * Tuning.BOARD_H * g.tile)
	var stock_panel := PanelContainer.new()
	var stock_bg := StyleBoxFlat.new()
	stock_bg.bg_color = Color(0.1, 0.1, 0.13, 0.97)
	stock_panel.add_theme_stylebox_override("panel", stock_bg)
	stock_panel.position = Vector2(0, g.hud_top)
	stock_panel.custom_minimum_size = Vector2(vp.x, stock_h)
	stock_panel.clip_contents = true # NO-84: never paints over the board below it
	stock_panel.visible = false
	var stock_row := HBoxContainer.new()
	stock_row.add_theme_constant_override("separation", 0)
	# LEFT: Captured Stock, a fixed fraction of the width — fixed so the split
	# never moves as pieces are captured or deployed (story 38).
	var cap_w: float = roundf(vp.x * STOCK_DRAWER_CAP_FRAC)
	var cap_col := VBoxContainer.new()
	cap_col.custom_minimum_size = Vector2(cap_w, stock_h)
	captured_hint.text = "Captured pieces land here"
	captured_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	captured_hint.custom_minimum_size = Vector2(cap_w - STOCK_DRAWER_PAD * 2.0, 0)
	captured_hint.modulate = Color(1, 1, 1, 0.6)
	captured_hint.add_theme_font_size_override("font_size", 11)
	captured_hint.visible = false
	cap_col.add_child(captured_hint)
	var cap_scroll := ScrollContainer.new()
	cap_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER # NO-136
	cap_scroll.scroll_deadzone = DRAWER_SCROLL_DEADZONE
	cap_scroll.custom_minimum_size = Vector2(cap_w - STOCK_DRAWER_PAD, stock_h - STOCK_DRAWER_PAD)
	captured_grid.columns = Tuning.grid_cols(cap_w - STOCK_DRAWER_PAD, STOCK_DRAWER_CELL_SEP) # NO-132
	captured_grid.add_theme_constant_override("h_separation", STOCK_DRAWER_CELL_SEP)
	captured_grid.add_theme_constant_override("v_separation", STOCK_DRAWER_CELL_SEP)
	cap_scroll.add_child(captured_grid)
	cap_col.add_child(cap_scroll)
	stock_row.add_child(cap_col)
	# RIGHT: Stock, the remaining two thirds.
	var stock_w: float = vp.x - cap_w
	var stock_col := VBoxContainer.new()
	stock_col.custom_minimum_size = Vector2(stock_w, stock_h)
	var stock_scroll := ScrollContainer.new()
	stock_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER # NO-136
	stock_scroll.scroll_deadzone = DRAWER_SCROLL_DEADZONE
	stock_scroll.custom_minimum_size = Vector2(stock_w - STOCK_DRAWER_PAD, stock_h - STOCK_DRAWER_PAD)
	stock_grid.columns = Tuning.grid_cols(stock_w - STOCK_DRAWER_PAD, STOCK_DRAWER_CELL_SEP) # NO-132
	stock_grid.add_theme_constant_override("h_separation", STOCK_DRAWER_CELL_SEP)
	stock_grid.add_theme_constant_override("v_separation", STOCK_DRAWER_CELL_SEP)
	stock_scroll.add_child(stock_grid)
	stock_col.add_child(stock_scroll)
	stock_row.add_child(stock_col)
	stock_panel.add_child(stock_row)
	drawers["stock"] = stock_panel
	add_child(stock_panel)
	drawer_rest["stock"] = stock_panel.position
	# NO-118: Stock slides in from the TOP — off-screen is its own height
	# above rest, tucked behind the Header.
	drawer_hidden["stock"] = stock_panel.position - Vector2(0, stock_h)
	# NO-59: the description popup. ONE instance, owned by the HUD rather than by
	# a row, because hud.refresh() frees and rebuilds every strip child — a panel
	# parented to a row would be destroyed by the next refresh, which happens on
	# essentially every state change.
	#
	# MOUSE_FILTER_IGNORE on both: it must not eat the press that dismisses it,
	# and it must never sit between a finger and a control underneath.
	tip_panel = PanelContainer.new()
	tip_panel.add_theme_stylebox_override("panel",
		_surface(Color(0.08, 0.08, 0.11, 0.97), Color(0.45, 0.45, 0.55), 8, 10, 8))
	tip_panel.visible = false
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_label = Label.new()
	tip_label.add_theme_font_size_override("font_size", 13)
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A fixed wrap width rather than a free one: without it a long description is
	# laid out as a single line whose minimum width is the whole string, and the
	# clamp below would then have nothing it could fit on screen. Same failure
	# NO-55 was, arriving through a different control.
	tip_label.custom_minimum_size = Vector2(minf(TIP_W, vp.x - TIP_MARGIN * 2), 0)
	tip_panel.add_child(tip_label)
	add_child(tip_panel)
	# NO move_to_front here any more. It existed because the drawer opened OVER
	# the button bar and the bar had to be raised above it; design C opens the
	# drawers above the deck instead, so there is nothing to out-rank. Worse, the
	# raise made the bar the LAST child of the deck, silently dropping the
	# drawers row to the bottom of the screen and undoing the row order set in
	# build() - which is exactly how it presented: the tree said one order and
	# the screen showed another.


## NO-118: a panel's own mouse_filter alone is not enough — Godot does not
## cascade a parent's MOUSE_FILTER_IGNORE to its children, so a descendant
## (a drawer's ScrollContainer, in particular) goes on absorbing clicks in
## its own rect even while the panel itself is set to ignore them. Found via
## a real failure: the Stock drawer's HIDDEN position sits directly above
## its rest position by its own height, which for the Stock drawer means
## hidden's bottom edge lands exactly on the Header's bottom edge — so while
## "closed" (hidden, mid-slide-out, or freshly killed mid-tween), the panel's
## rect still geometrically covers the whole Header, INCLUDING the Header's
## own Stock button, and a click meant for that button was landing on the
## drawer's ScrollContainer instead.
##
## `clickable=false` walks every descendant Control once, remembers its
## current filter (NO-45's rows are deliberately MOUSE_FILTER_PASS, not
## STOP, for the drag-scroll behaviour documented at DRAWER_SCROLL_DEADZONE
## above — this must restore that exact value, never a blanket STOP) and
## sets it to IGNORE. `clickable=true` restores every remembered value. Saves
## only once per close (a second close call while already closed would
## otherwise capture and "restore" IGNORE, permanently losing the original).
func _set_drawer_clickable(key: String, clickable: bool) -> void:
	var panel: Control = drawers[key]
	if clickable:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var saved: Dictionary = _drawer_saved_filters.get(key, {})
		for c in saved:
			if is_instance_valid(c):
				c.mouse_filter = saved[c]
		_drawer_saved_filters.erase(key)
	else:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not _drawer_saved_filters.has(key):
			var saved := {}
			for c in panel.find_children("*", "Control", true, false):
				saved[c] = (c as Control).mouse_filter
				(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			_drawer_saved_filters[key] = saved


## NO-118: slides `panel` along its own axis between drawer_rest[key] and
## drawer_hidden[key], swift in-out. `opening` sets the direction; the caller
## has already flipped `visible` true before calling this for an open (a
## tween never renders on a hidden Control) and this hides it again, only
## once the close tween finishes, for a close.
##
## Skips the tween entirely in autoplay/headless-with-animations-off — same
## seam `animations_on`/`autoplay` already gate every other HUD animation on
## (game.gd:1046 etc.), so a scenario sweep never stalls 0.18s per toggle.
##
## Kills whatever tween is already running on this drawer first: a second
## toggle before the first tween finishes must replace it, not race it.
##
## NO-118 fix: `visible` stays true for the whole close slide (see above), and
## a visible Control with the default MOUSE_FILTER_STOP still absorbs a click
## anywhere in its rect via Godot's own GUI picking, BEFORE that click can
## ever reach _unhandled_input — regardless of drawer_open having already
## flipped to "". A press landing on the still-sliding panel (e.g. a board
## tile the drawer used to cover) was silently eaten instead of reaching the
## board, for up to PANEL_SLIDE_S after the "close". _set_drawer_clickable
## below turns that off the instant a close starts and back on the instant an
## open starts, so an open drawer still blocks the board underneath it
## exactly as before.
func _slide_drawer(key: String, opening: bool) -> void:
	if _drawer_tweens.get(key):
		(_drawer_tweens[key] as Tween).kill()
		_drawer_tweens.erase(key)
	var panel: Control = drawers[key]
	var rest: Vector2 = drawer_rest[key]
	var hidden: Vector2 = drawer_hidden[key]
	_set_drawer_clickable(key, opening)
	if g.autoplay or not g.animations_on:
		panel.position = rest
		if not opening:
			panel.visible = false
		return
	if opening:
		panel.position = hidden
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(panel, "position", rest if opening else hidden, Tuning.PANEL_SLIDE_S)
	if not opening:
		tw.finished.connect(func() -> void: panel.visible = false)
	_drawer_tweens[key] = tw


## NO-127: squish-grow-settle when a counter GAINS (Score, Gold, or the
## Clock via a time grant). Swift — three short legs, ~0.2s total. Same gate
## as every other HUD animation (`_slide_drawer` above is the precedent), so
## a headless sweep never even creates a Tween to wait on.
func _pulse_gain(node: Control, key: String) -> void:
	if g.autoplay or not g.animations_on:
		return
	if _gain_tweens.get(key):
		(_gain_tweens[key] as Tween).kill()
	node.pivot_offset = node.size / 2.0
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(0.82, 1.22), 0.06)
	tw.tween_property(node, "scale", Vector2(1.1, 0.94), 0.07)
	tw.tween_property(node, "scale", Vector2.ONE, 0.08)
	_gain_tweens[key] = tw


## NO-127: minute-rollover cue on the Clock — grows then shakes back level.
## One-shot; shares `_gain_tweens`'s "clock" slot with `_pulse_gain` (kill-
## first idiom) since both animate the same Label. Suppressed once the
## continuous under-2-minutes loop owns `rotation` (see `_apply_clock_urgent`)
## — two Tweens racing the same property is what "fights" would mean, not an
## extra emphasis.
func _shake_clock_minute() -> void:
	if g.autoplay or not g.animations_on:
		return
	if _gain_tweens.get("clock"):
		(_gain_tweens["clock"] as Tween).kill()
	clock_label.pivot_offset = clock_label.size / 2.0
	var tw := create_tween()
	tw.tween_property(clock_label, "scale", Vector2(1.35, 1.35), 0.07)
	for deg in [6, -6, 3, 0]:
		tw.tween_property(clock_label, "rotation", deg_to_rad(deg), 0.045)
	tw.tween_property(clock_label, "scale", Vector2.ONE, 0.1)
	_gain_tweens["clock"] = tw


## NO-127: the continuous "under two minutes" urgency cue — shake + pulse
## red, looping, while `ms` stays below CLOCK_URGENT_MS. Driven off `want`
## CHANGING (the ms threshold crossing, or the Settings toggle / autoplay
## flipping), never off being called every frame — update_clock() calls this
## every frame, but the early-return below makes every no-op call free.
func _apply_clock_urgent(ms: float) -> void:
	var want: bool = ms < CLOCK_URGENT_MS and not g.autoplay and g.animations_on
	if want == _clock_urgent_on:
		return
	_clock_urgent_on = want
	for tw in _urgent_tweens:
		if tw:
			(tw as Tween).kill()
	_urgent_tweens.clear()
	clock_label.rotation = 0.0
	clock_label.modulate = Color.WHITE
	if not want:
		return
	clock_label.pivot_offset = clock_label.size / 2.0
	var rot_tw := create_tween().set_loops()
	rot_tw.tween_property(clock_label, "rotation", deg_to_rad(4), 0.1)
	rot_tw.tween_property(clock_label, "rotation", deg_to_rad(-4), 0.1)
	var col_tw := create_tween().set_loops()
	col_tw.tween_property(clock_label, "modulate", Color(1.0, 0.25, 0.2), 0.3)
	col_tw.tween_property(clock_label, "modulate", Color.WHITE, 0.3)
	_urgent_tweens = [rot_tw, col_tw]


## NO-127: the single seam every Clock text update goes through — game.gd's
## per-frame drain AND refresh()'s on-state-change set both call this instead
## of writing `clock_label.text` directly, so the three Clock animations
## trigger off the ms VALUE changing, never off how often either caller runs.
func update_clock(ms: float) -> void:
	clock_label.text = g._clock_text()
	var whole_min: int = int(ms / 60000.0)
	# NO-127: settle urgency FIRST. The 2-minute mark IS a minute boundary, so
	# the instant the urgency loop claims `rotation` is the same instant
	# whole_min changes — checking _clock_urgent_on before this call would
	# see last frame's stale answer and fire the one-shot shake into the loop
	# that starts this same frame, fighting over the same property.
	_apply_clock_urgent(ms)
	if _clock_seen: # not the first observation — there's a baseline to compare against
		if ms > _clock_shown_ms + 1.0: # a real GAIN, not per-frame float drift
			_pulse_gain(clock_label, "clock")
		elif whole_min != _clock_shown_min and not _clock_urgent_on:
			_shake_clock_minute()
	_clock_shown_ms = ms
	_clock_shown_min = whole_min
	_clock_seen = true


## Open one drawer (closing the others) or toggle it shut; "" closes all.
## Visibility only — selection/board consequences live in game.gd's handler.
func set_drawer(which: String) -> void:
	var prev := drawer_open
	drawer_open = "" if drawer_open == which else which
	for name in drawers:
		if drawer_open == name and prev != name: # newly opening
			(drawers[name] as Control).visible = true
			_slide_drawer(name, true)
		elif drawer_open != name and prev == name: # newly closing
			_slide_drawer(name, false)
	hide_tip() # NO-59: a description outlives neither its drawer nor its row


## NO-59: the tap-to-describe popup.
##
## WHY IT EXISTS. NO-45 set the drawer rows to MOUSE_FILTER_PASS so the lists
## drag-scroll on touch, which gave up the hover tooltip STOP was there for. But
## the bigger half is that a hover tooltip NEVER worked on a phone, so these
## descriptions have not been readable during a run on the platform this game
## ships to. hud.gd already argues this for a different control: the CAPTURED
## header exists because "this is a portrait TOUCH game: the tooltip does not
## exist on a phone".
##
## `anchor` is the row's global rect; the panel is placed BESIDE it (user ruling
## 2026-09-11: a small popup beside the item, not a line inside the drawer) and
## then clamped into the viewport.
func show_tip(key: String, text: String, anchor: Rect2) -> void:
	if key == tip_key: # tapping the same row again closes it
		hide_tip()
		return
	tip_key = key
	tip_label.text = text
	tip_panel.visible = true
	# The panel's size is not known until the container has sorted its children,
	# and a position computed from a stale size is the whole bug this clamp
	# exists to avoid. reset_size() forces it to its minimum NOW rather than
	# next frame, so the arithmetic below runs on the real box.
	tip_panel.reset_size()
	var vp: Vector2 = g.get_viewport_rect().size
	var box: Vector2 = tip_panel.size
	# BESIDE THE ROW MEANS UNDER IT, not to its right, and that is a measurement
	# rather than a preference: an artefact row is ~245px wide in a 480px
	# viewport and the panel is 260, so there is never room to its right, and
	# flipping it to the left landed it exactly on top of the row it describes —
	# covering the thing the player just tapped. Directly under the row, aligned
	# to its left edge, is adjacent and never hides it. Above instead when the
	# row is near the bottom.
	var y := anchor.end.y + 2.0
	if y + box.y > vp.y - TIP_MARGIN:
		y = anchor.position.y - 2.0 - box.y
	# THE CLAMP IS THE POINT. A popup anchored to a row near an edge of a
	# 480-wide portrait screen is exactly the failure NO-55 was — a control
	# placed without reference to the viewport. maxf before minf so a panel
	# TALLER OR WIDER than the screen still lands at the margin rather than at a
	# negative offset, which is the case a bare clamp() gets wrong.
	tip_panel.position = Vector2(
		maxf(TIP_MARGIN, minf(anchor.position.x, vp.x - box.x - TIP_MARGIN)),
		maxf(TIP_MARGIN, minf(y, vp.y - box.y - TIP_MARGIN)))


func hide_tip() -> void:
	tip_key = ""
	if tip_panel != null:
		tip_panel.visible = false


## NO-72: a LONG PRESS on an Item or Artefact cell shows its description and
## does not fire the control. A tap on a cell already does something (an item
## arms, a ✹ artefact activates), so unlike NO-59's original tap-to-describe
## (retired by NO-85 — see hide_tip's callers) the reveal gesture has to be a
## hold, and it must work on a DISABLED cell too (story 55: greyed-out still
## explains).
##
## Cancelled by moving past DRAWER_SCROLL_DEADZONE, the number the scroller
## uses to call a drag a scroll, so a scroll can never also be a long press.
## GLOBAL positions, because gui_input's own `position` is relative to the
## control and travels WITH it during a scroll — a finger moving 180px up
## while its cell moves 180px up would read as a local delta of zero, making
## every drag look like it never moved. Each press gets its own token, so a
## timer left over from a quick earlier press cannot fire into this one — and
## show_tip toggles on a repeated key, so a double fire would open and then
## shut.
##
## When it fires, `lp_fired` makes the Button's own `pressed` handler swallow
## the release that ends the hold. The next PRESS clears it, so a hold
## released off the button cannot leak into a later tap.
func _long_press_input(btn: Button, key: String, desc: String, e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if not e.pressed:
			btn.remove_meta("lp_token")
			return
		btn.remove_meta("lp_fired")
		var token := Time.get_ticks_usec()
		btn.set_meta("lp_token", token)
		btn.set_meta("lp_from", e.global_position)
		get_tree().create_timer(LONG_PRESS_MS / 1000.0).timeout.connect(func() -> void:
			if is_instance_valid(btn) and btn.get_meta("lp_token", 0) == token:
				btn.remove_meta("lp_token")
				btn.set_meta("lp_fired", true)
				show_tip(key, desc, btn.get_global_rect()))
	elif e is InputEventMouseMotion and btn.has_meta("lp_token") \
			and e.global_position.distance_to(btn.get_meta("lp_from")) > DRAWER_SCROLL_DEADZONE:
		btn.remove_meta("lp_token")


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
	update_clock(g.clock_ms) # NO-127: routes through the shared seam (see its header)
	# NO-126: odometer — grey zero padding up to SCORE_DIGITS, then the score's
	# own digits, coloured. Growing past SCORE_DIGITS is never cut: `digits`
	# is just str(g.score), whatever length that is, and the padding floors at 0.
	var digits := str(g.score)
	score_zeros_label.text = "0".repeat(maxi(0, SCORE_DIGITS - digits.length()))
	score_label.text = digits
	gold_label.text = "%d" % g.gold
	# NO-127: gain pulses, driven off the value CHANGING (refresh() itself
	# runs on nearly every state change, which is not the same thing — see
	# _pulse_gain's header). The first observation establishes the baseline
	# and never pulses.
	if _score_seen and g.score > _score_shown:
		_pulse_gain(score_row, "score")
	_score_shown = g.score
	_score_seen = true
	if _gold_seen and g.gold > _gold_shown:
		_pulse_gain(gold_row, "gold")
	_gold_shown = g.gold
	_gold_seen = true
	# ⚑ WAVE COUNTER (NO-82): out of 50 until the first King falls, then out of
	# the whole table — Wave 50 reads 50/50, Wave 51 reads 51/201.
	# NO-114: blank during a King wave — the King's own name in turn_label is
	# enough, and showing both crowded the centre column.
	var king_wave: bool = g._king_alive() or not g.pending_king.is_empty()
	wave_label.text = "" if king_wave else "⚑ %d/%d" % [g.wave,
		WIN_WAVE if g.kings_defeated == 0 else Waves.WAVES.size()]
	# TURN COUNTER: turns played this Wave out of the upcoming Wave's cadence.
	# The King's name instead while he is alive OR pending (no Wave arrives
	# until he is checkmated); blank after the last Wave, when no Wave is coming.
	# NO-114: dropped the ⧖ glyph — no painted icon fits it, and the name/count
	# reads fine unprefixed.
	if king_wave:
		turn_label.text = g._king_name()
	elif g.wave >= Waves.WAVES.size():
		turn_label.text = ""
	else:
		turn_label.text = "%d/%d" % [g.turns_since_wave, g._cadence()]
	if g.state == g.State.SETUP: # the pass button doubles as the explicit start trigger
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
	elif g.state == g.State.ENEMY_TURN:
		pass_button.disabled = false
		pass_button.tooltip_text = ""
		pass_count.text = ""
		pass_label.text = "PASS"
	elif g.state == g.State.GAME_OVER:
		pass_button.disabled = false
		pass_button.tooltip_text = ""
		pass_count.text = ""
	stock_badge.text = str(g._pool().size())
	stock_armed.queue_redraw() # armed piece rides the button (selection style)
	drawer_buttons["inventory"].text = "Inventory %d" % (g.items.size() + g.artefacts.size())
	king_ability_button.text = "⚠%d" % g.king_abilities_active.size() \
		+ ("·off" if g.king_abilities_suppressed else "")
	# armed-placement tint (2026-07-07 palette) marks the toggle as active
	arrow_button.self_modulate = Color(0.55, 0.95, 1.5) if g.arrow_mode else Color(1, 1, 1)
	arrow_clear_button.visible = g.arrow_mode
	# NO-124: generalised from "multi"'s own Extract button to every targeted
	# Item/Artefact's final confirm — visible whenever there's a complete,
	# spendable target staged (or, for an untargeted Item, as soon as it's
	# armed — there's nothing to stage). Bovine Tractor Beam and Item
	# targeting are mutually exclusive (game.gd), so at most one of these two
	# conditions is ever true at once.
	var item_confirm := false
	var item_confirm_text := "Confirm"
	if g.item_active >= 0:
		var it: Dictionary = g.items[g.item_active]
		if it.target == "multi":
			item_confirm = not g.item_selected.is_empty()
			item_confirm_text = "Extract %d" % g.item_selected.size()
		elif it.target == "":
			item_confirm = true
		else:
			item_confirm = g.item_pending_tile.x >= 0
	var artefact_confirm: bool = g.artefact_targeting_key != "" and g.artefact_pending_tile.x >= 0
	multi_confirm_btn.visible = item_confirm or artefact_confirm
	multi_confirm_btn.text = item_confirm_text
	_rebuild_stock_drawer()
	_rebuild_items_grid()
	# issue 100: the Power is always on, so it is stated, not offered. The
	# Ability's 1-Action cost rides along here too — that cost is the
	# deliberate contrast with Artefact activation and the Shop (both 0), and
	# it was also tooltip-only until now.
	var kit: Dictionary = Armies.entry(g.next_army)
	# the Power stays a statement; it is passive and there is nothing to press
	army_power_label.text = "%s — %s: %s" % [
		Armies.display_name(g.next_army), kit.power_name, kit.power_desc]
	# THE ABILITY WEARS ITS OWN STATE (design C). Availability had to be visible
	# without opening a menu, and the three states a player can be in are
	# genuinely different problems: already used this wave, no Action to spend,
	# or ready. Saying which one it is beats greying the button out and leaving
	# them to guess.
	army_ability_button.text = "★ %s" % kit.ability_name
	# NO-32: the drawer chip was the only place the Ability's DESCRIPTION lived
	# (its tooltip). The chip is gone, so the deck button inherits that tooltip
	# verbatim — the button's own text carries the name and the cost, the tooltip
	# carries what the Ability actually does.
	army_ability_button.tooltip_text = "%s (1 Action)\n%s" % [
		kit.power_name + " — always on. " + kit.ability_name, kit.ability_desc]
	if g.army_ability_used_this_wave:
		army_ability_button.text += "  ·  next wave"
		army_ability_button.disabled = true
		army_ability_button.self_modulate = Color(0.62, 0.62, 0.62)
	elif g.actions_left < 1:
		army_ability_button.text += "  ·  no Action"
		army_ability_button.disabled = true
		army_ability_button.self_modulate = Color(1.0, 0.66, 0.62)
	else:
		army_ability_button.text += "  ·  1 Action"
		army_ability_button.disabled = false
		army_ability_button.self_modulate = Color(1.3, 1.16, 0.72)
	# NO-115: a reminder of what pressing this DOES, since the tooltip above
	# is unreachable on a touch screen mid-run.
	army_ability_hint.text = Armies.ability_hint(g.next_army)
	_rebuild_artefacts_grid()
	# NO-85: the drawer's height is a flat choice (INV_DRAWER_H), not a
	# consequence of what it holds — it must not resize as Items/Artefacts
	# come and go (story 46).
	var inv_panel: PanelContainer = drawers["inventory"]
	var inv_h := INV_DRAWER_H
	if inv_panel.custom_minimum_size.y != inv_h:
		# NO-118: build() always sets custom_minimum_size.y to this same
		# INV_DRAWER_H, so this branch is unreachable — the position write
		# below can never stale drawer_rest["inventory"].
		var inv_w: float = inv_panel.custom_minimum_size.x
		inv_panel.custom_minimum_size = Vector2(inv_w, inv_h)
		inv_panel.position = Vector2(inv_panel.position.x,
			g.get_viewport_rect().size.y - deck_h - inv_h)


## issue 97: can the player currently pay for this entry's action? Drives the
## price colour only — the real refusals stay where they are (Economy/Shop).
func _pool_affordable(cap: bool, entry: Variant) -> bool:
	return g.gold >= (Shop.convert_price(g, entry) if cap else Economy.deploy_cost(g))


## NO-84: every stack button across both grids, Stock first then Captured —
## the flat order _rebuild_stock_drawer used to hold as one strip. Used
## wherever code needs to sweep "every stack on screen" rather than one side.
func pool_buttons() -> Array:
	return stock_grid.get_children() + captured_grid.get_children()


## The pool-strip stack button under a screen point (drag drop target).
func stack_button_at(screen: Vector2) -> Button:
	if not (drawers["stock"] as Control).is_visible_in_tree(): # closed: no targets
		return null
	for c in pool_buttons():
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
	# over the Header button's icon (NO-83): the armed piece replaces the
	# generic token, with the same pulsing ring a selected board piece wears
	var c := stock_armed.size / 2.0
	var half := STOCK_ICON / 2.0
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	stock_armed.draw_texture_rect(g.piece_tex(g.placing_id),
		Rect2(c - Vector2(half, half), Vector2(STOCK_ICON, STOCK_ICON)), false)
	stock_armed.draw_arc(c, half + 2.0 + 2.0 * pulse, 0, TAU, 24,
		Color(0.4, 0.7, 1.0, 0.45 + 0.4 * pulse), 2.0 + pulse)


func _stacks() -> Array:
	# pool grouped for display/selection: Stock stacks first, then Captured.
	# Stock grouping is by WHOLE entry (ADR-0002), so a piece carrying state
	# stacks apart from plain copies of the same id.
	#
	# CAPTURED NEVER STACKS (user ruling 2026-09-10): one row per captured
	# piece, MOST RECENT CAPTURE FIRST. g.captured is append-ordered, so newest
	# first is simply its reverse. A stack made sense while a captured pair
	# could merge; with convert and sell the only exits, every action is on ONE
	# piece, so a row is one piece and the count badge has nothing to count.
	var out := []
	var counts := {}
	for e in g.stock:
		counts[e] = counts.get(e, 0) + 1
	for e in counts:
		out.append({"entry": e, "id": (e if e is String else e.id),
			"cap": false, "count": counts[e]})
	for i in range(g.captured.size() - 1, -1, -1):
		var e: Variant = g.captured[i]
		out.append({"entry": e, "id": (e if e is String else e.id),
			"cap": true, "count": 1})
	return out


## NO-85: Items then Artefacts, in ONE scrolling column — the Artefacts grid
## holds BOTH passive and activatable entries now (story 47/50), replacing the
## old artefact_box (passive rows, tap-to-describe) + activate_box (issue 52's
## Activate chips) split. Tap uses (arms/activates), long-press describes,
## for every entry including greyed ones (stories 51-55) — one mechanism,
## reusing NO-72's _long_press_input for both kinds, instead of passive rows
## having their own tap-to-describe path (NO-59's _tip_input — retired here,
## it had no other caller).
## "no artefacts yet" still gates on the whole g.artefacts list, not just the
## passive subset: holding only an activatable Artefact is not "nothing".
func _rebuild_artefacts_grid() -> void:
	for c in artefacts_grid.get_children():
		c.queue_free()
	if g.artefacts.is_empty():
		var none := Label.new()
		none.text = "no artefacts yet"
		none.modulate = Color(1, 1, 1, 0.6)
		artefacts_grid.add_child(none)
		# NO-121: scoped to this grid's OWN "artefact:" keys, same as the
		# non-empty branch below — an unscoped hide_tip() here was wiping a
		# Board/Item-target tip (NO-120/NO-121) on every refresh whenever the
		# player held zero artefacts, since _refresh() runs right after
		# show_tip() for those.
		if tip_key.begins_with("artefact:"):
			hide_tip()
		return
	var counts := {}
	for t in g.artefacts: # stack copies: one entry per kind
		counts[t.key] = counts.get(t.key, 0) + 1
	var seen := {}
	for t in g.artefacts:
		if seen.has(t.key):
			continue
		seen[t.key] = true
		artefacts_grid.add_child(_build_artefact_cell(t.key, counts[t.key]))
	# the cell the popup was anchored to may have just been freed. Keep it up
	# only while the artefact it describes is still held — otherwise a
	# consumed artefact leaves a description of something no longer held.
	# Scoped to "artefact:" keys (NO-120): an open Board or Stock tip is not
	# in `seen` either, but it is not this grid's to close.
	if tip_key.begins_with("artefact:") and not seen.has(tip_key.trim_prefix("artefact:")):
		hide_tip()


## One Artefacts-grid cell — passive or activatable (story 50: activatable
## joins the same grid with a ✹ marker rather than a separate section).
## Always a Button (NO-17: a disabled Button still carries its icon, once
## icon_disabled_color is set — the earlier bare-TextureRect route lost that
## and rendered art at zero alpha) so long-press works identically on both:
## gui_input still arrives on a DISABLED Button, which is most of the time for
## an unavailable activatable one, and "why can't I use this?" is exactly when
## the description is wanted (story 55).
func _build_artefact_cell(key: String, count: int) -> Button:
	var entry: Dictionary = g._artefact_entry(key)
	var activatable: bool = g.ACTIVATABLE_ARTEFACT_KEYS.has(key)
	var btn := Button.new()
	btn.icon = g.artefact_tex(key)
	btn.expand_icon = true
	btn.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.55))
	# NO-119: no name text on the cell any more — ✹ (activatable) and the
	# stack count are live state, same reasoning the Shop's price badge stays
	# on an otherwise nameless tile (CLAUDE.md). The name moves into
	# tooltip_text / the long-press description below, since that's now the
	# only place it's shown.
	#
	# A child Label, not Button.text: Button lays icon+text out together when
	# both are set, and that layout isn't queryable, so a second badge (the
	# initials one below) anchored to the BUTTON's rect lands beside the icon,
	# not on it (found 2026-09-18, coordinator review). Text-only-if-needed +
	# expand_icon with no competing Button.text is what makes the icon fill
	# the whole button — the same guarantee the Shop's icon-only tiles already
	# have (modals.gd _shop_tile) — so corner badges anchored to the button's
	# rect are anchored to the icon's rect too, same idiom as the stack count
	# / ADR-0002 mark in _build_stack_button below.
	var marker_text := "%s%s" % ["✹" if activatable else "", " ×%d" % count if count > 1 else ""]
	if marker_text != "":
		var marker := Label.new()
		marker.text = marker_text
		marker.add_theme_font_size_override("font_size", 12)
		marker.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
		marker.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
		marker.add_theme_constant_override("outline_size", 4)
		marker.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		marker.offset_left = -40
		marker.offset_top = -16
		btn.add_child(marker)
	if not g.artefact_icons.has(key): # NO-119: unpainted — badge initials over
		# the shared placeholder so two unpainted artefacts read apart at a
		# glance. Centred on the art, not the corner (NO-119, Max's call
		# 2026-09-19): expand_icon fills the Button with the icon, so a
		# full-rect Label with centred text alignment lands on the art
		# without depending on the Label's own (frame-late) minimum size.
		var init_badge := Label.new()
		init_badge.text = g.initials_of(entry.name)
		init_badge.add_theme_font_size_override("font_size", 13)
		init_badge.add_theme_color_override("font_color", Color(1, 1, 1))
		init_badge.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
		init_badge.add_theme_constant_override("outline_size", 4)
		init_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE # must not eat the tap
		init_badge.set_anchors_preset(Control.PRESET_FULL_RECT)
		init_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		init_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.add_child(init_badge)
	var desc := _grid_tip_desc(entry.name, entry.description)
	btn.tooltip_text = desc
	if activatable:
		var targeting: bool = g.artefact_targeting_key == key
		btn.disabled = not (g._artefact_activation_available(key) or targeting)
		if targeting: # mid-targeting (Bovine): tint like an active Item, tap
			# again to cancel — same shape _use_item already uses
			btn.modulate = Color(0.5, 1.3, 1.3)
	else: # story 53: a tap does nothing — a passive Artefact has nothing to press
		btn.disabled = true
	# NO-99: pressed only ever reaches artefact_activate_pressed while
	# activatable is true, because a passive cell is disabled above and a
	# disabled Button never fires `pressed` — connecting it unconditionally
	# here (rather than only inside the activatable branch) changes nothing.
	# NO-120: prefixed so _rebuild_artefacts_grid's own-tip cleanup below can
	# tell an Artefact tip apart from a Board or Stock one (show_tip is now a
	# shared popup, not this grid's alone) — bare `key` would make every
	# non-Artefact tip look like an artefact no longer held and get closed.
	_wire_grid_button(btn, true, "artefact:" + key, desc, func() -> void:
		artefact_activate_pressed.emit(key))
	btn.set_meta("key", key) # lookup for probes/tests
	return btn


## NO-99: the icon sizing, lp_fired tap-vs-long-press guard, gui_input
## wiring and drag-scroll passthrough every drawer grid button (Artefacts,
## Items) shares. `has_icon` is false only for an Items cell with no art,
## which stays glyph-sized rather than reserving icon layout space it isn't
## using.
##
## NO-119: no cell carries name text beside its icon any more, so there's
## nothing left to reserve width for — every cell with an icon is a flat
## Tuning.OFFBOARD_ICON square, expand_icon filling it rather than collapsing
## to 0 in the packed grid (the same square shape _build_stack_button and
## modals.gd's Shop tiles already use).
func _wire_grid_button(btn: Button, has_icon: bool, lp_key: String, lp_desc: String, on_tap: Callable) -> void:
	if has_icon:
		btn.expand_icon = true
		btn.custom_minimum_size = Vector2(Tuning.OFFBOARD_ICON, Tuning.OFFBOARD_ICON)
	btn.pressed.connect(func() -> void:
		if btn.has_meta("lp_fired"): # NO-72: this release ended a long press
			btn.remove_meta("lp_fired")
			return
		on_tap.call())
	btn.gui_input.connect(func(e: InputEvent) -> void:
		_long_press_input(btn, lp_key, lp_desc, e))
	btn.mouse_filter = Control.MOUSE_FILTER_PASS # NO-45: drag-scroll the drawer


func _rebuild_items_grid() -> void:
	for c in items_grid.get_children():
		c.queue_free()
	for i in g.items.size():
		var btn := Button.new()
		var has_icon: bool = g.item_icons.has(g.items[i].key)
		# NO-119: no name text on the cell — the glyph fallback stands alone,
		# same as the Shop's own icon fallback (_shop_icon/_shop_tile).
		if has_icon:
			btn.icon = g.item_icons[g.items[i].key]
		else:
			btn.text = "✦"
		var desc := _grid_tip_desc(g.items[i].name, g.items[i].description)
		btn.tooltip_text = "%s (%s)\n%s" % [g.items[i].name, g.items[i].tier, g.items[i].description]
		if g.item_active == i:
			btn.modulate = Color(0.5, 1.3, 1.3)
		_wire_grid_button(btn, has_icon, "item:%d" % i, desc, func() -> void:
			item_pressed.emit(i))
		btn.set_meta("key", g.items[i].key) # NO-119: no name text left to find
			# this cell by (probes/tests) — same convention _build_artefact_cell
			# already uses
		items_grid.add_child(btn)


## NO-84: Stock and Captured Stock are two independent grids (stories 31-44),
## Captured on the left, Stock on the right — replaces the single strip issue
## 96 gave a labelled divider inside. The two pools still obey different
## rules (Captured can convert but never deploy or merge, issue 60/2026-09-10)
## but that is now which GRID an entry is in, not a tint plus a tooltip a
## phone can't show anyway.
func _rebuild_stock_drawer() -> void:
	for c in stock_grid.get_children():
		c.queue_free()
	for c in captured_grid.get_children():
		c.queue_free()
	var cap_count := 0
	for st in _stacks():
		var btn := _build_stack_button(st)
		if st.cap:
			cap_count += 1
			captured_grid.add_child(btn)
		else:
			stock_grid.add_child(btn)
	# story 37: the hint only while the column would otherwise be blank — an
	# empty GridContainer has no size of its own to hang a message on.
	captured_hint.visible = cap_count == 0
	if g.state == g.State.SETUP and g.selected.x >= 0:
		# empty slot: tap it (or drop the dragged piece on the strip) to take
		# the selected board piece back into stock — lives with Stock, the
		# side it returns pieces to.
		var slot := Button.new()
		slot.text = "+"
		# NO-119: every stack button beside it in this same container is
		# Tuning.OFFBOARD_ICON — keep this one square with them.
		slot.custom_minimum_size = Vector2(Tuning.OFFBOARD_ICON, Tuning.OFFBOARD_ICON)
		slot.add_theme_font_size_override("font_size", 22)
		slot.modulate = Color(0.55, 0.75, 1.0, 0.85) # placement blue, dimmed
		slot.tooltip_text = "Put the piece back into stock"
		slot.pressed.connect(func() -> void: return_to_stock_pressed.emit())
		slot.mouse_filter = Control.MOUSE_FILTER_PASS # NO-45: drag-scroll the drawer
		stock_grid.add_child(slot)


## One stack button (Stock or Captured entry) — everything from the icon down
## to its drag/tap wiring. Split out of _rebuild_stock_drawer so that
## function only decides which grid an entry lands in.
func _build_stack_button(st: Dictionary) -> Button:
	var btn := Button.new()
	var id: String = st.id
	var cap: bool = st.cap
	if g.textures.has(id): # piece icon instead of glyph text (round 3)
		btn.icon = g.piece_tex(id) # Stock is always yours: the player token
		btn.expand_icon = true
		# NO-119: every off-board icon (Shop, Inventory, Stock, Captured) is
		# now a flat Tuning.OFFBOARD_ICON square, no longer tied to the board
		# tile (that relationship — "so a piece reads the same wherever it
		# is" — is what NO-119 explicitly overrides for icons outside the
		# board).
		btn.custom_minimum_size = Vector2(Tuning.OFFBOARD_ICON, Tuning.OFFBOARD_ICON)
	else:
		btn.text = g.defs[id].glyph
		btn.add_theme_font_size_override("font_size", 22)
	# `not cap` is load-bearing, not decoration: placing_id is only ever a
	# STOCK id now (game.gd), so without it a captured row holding the same
	# piece id as the armed Stock stack would light up armed too.
	var armed: bool = not cap and g.placing_id == id and g.armed_entry == st.entry
	var show_promote: bool = armed \
			and st.count >= 2 and MergeLogic.pair_ok(g, id, id) \
			and g.state == g.State.PLAYER_TURN and g.actions_left > 0
	# 2026-09-06: Captured -> Stock conversion on the entry itself. It lived
	# only in the Shop's Sell mode — four taps deep, and unreachable before
	# SHOP_UNLOCK_WAVE since issue 101 locks the panel — so early captures
	# could not be converted at all.
	#
	# 2026-09-10: ALWAYS SHOWN, on every captured entry. It used to appear
	# only on an armed stack and only when ▲ promote did not claim the
	# corner first — so holding two of a piece hid Convert behind the merge
	# it lost the corner to, which is exactly the "tap to convert tries to
	# merge instead" the user reported. Merge is gone from Captured Stock
	# and arming it does nothing, so the badge has no reason to hide.
	var show_convert: bool = cap
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
		promote.pressed.connect(func() -> void: promote_pressed.emit(id))
		btn.add_child(promote)
	if show_convert:
		var convert := Button.new()
		convert.text = "⇄$%d" % Shop.convert_price(g, st.entry)
		convert.add_theme_font_size_override("font_size", 11)
		convert.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
		convert.disabled = not Shop.can_convert(g, st.entry)
		var pill := StyleBoxFlat.new()
		pill.bg_color = Color(0.3, 0.6, 1.0) # player blue, same as ▲
		pill.set_corner_radius_all(9)
		for style in ["normal", "hover", "pressed", "disabled"]:
			convert.add_theme_stylebox_override(style, pill)
		convert.tooltip_text = "Convert to Stock (deployable)"
		convert.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		convert.offset_left = -26
		convert.offset_right = 4
		convert.offset_top = -9
		convert.offset_bottom = 9
		var entry: Variant = st.entry
		convert.pressed.connect(func() -> void: convert_pressed.emit(entry))
		btn.add_child(convert)
	btn.tooltip_text = g.defs[id].name + (" (captured)" if cap else "")
	if armed:
		btn.modulate = Color(0.55, 0.95, 1.5) # armed: placement / merge origin
	elif not cap and g.merge_highlights.has(id):
		btn.modulate = Color(0.8, 1.1, 1.4) # completes a merge — tap or drop
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
	# NO-120: long-press shows the piece's name + any Piece Buffs it carries
	# (state Stock never interprets itself, ADR-0002 — st.entry is the state
	# Dictionary when there is one). "cap:"/"stock:" so the same id held in
	# both grids at once gets two distinct tip keys, never one toggling shut
	# the other's popup.
	var lp_desc: String = BuffLogic.describe(id, st.entry if st.entry is Dictionary else {}, g.defs)
	var lp_key := ("cap:" if cap else "stock:") + id
	btn.pressed.connect(func() -> void:
		if btn.has_meta("lp_fired"): # NO-72's swallow, same as every other long-press cell
			btn.remove_meta("lp_fired")
			return
		stack_pressed.emit(st.entry, cap, st.count))
	btn.gui_input.connect(func(e: InputEvent) -> void:
		_long_press_input(btn, lp_key, lp_desc, e))
	btn.button_down.connect(func() -> void: stack_drag_started.emit(st.entry, cap))
	# NO-45: PASS here too, and this is the one strip where it is a JUDGEMENT
	# rather than a straight win. These buttons are drag SOURCES — button_down
	# arms a deploy — so a press now also reaches the ScrollContainer and can
	# start a scroll. The conflict is small in practice and the deadzone
	# bounds it: this strip is horizontal, a deploy drag goes UP to the board,
	# and a mostly-vertical drag moves a horizontal scroll barely at all.
	# Against that, a full Stock (22 stacks was a real save) cannot currently
	# be drag-scrolled at all — the one complaint Max has already made about
	# this drawer. Flagged rather than assumed: if deploying from a long Stock
	# ever feels like it drifts, this line is the suspect.
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	return btn
