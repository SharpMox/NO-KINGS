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
const Rules := preload("res://scripts/rules.gd") # NO-164: Rules.ENEMY for a Captured entry's icon
const ItemLogic := preload("res://scripts/item_logic.gd") # NO-165: Held Item capacity
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd") # NO-165: Held Artefact capacity
const Kings := preload("res://data/kings.gd") # banner pass: bespoke Power in the ⚠ button
const PieceDiagram := preload("res://scripts/piece_diagram.gd") # NO-152: the targeting tip's diagram

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
## NO-152: a compact PieceDiagram above the text when show_tip is given a
## piece id — same 9-cell board modals.gd's own preview uses (covers Ying
## Long's 4-square leap), at roughly half its cell size (16 vs 30) so the
## whole popup stays a small anchored tile-side tip, not a modal-sized panel.
const TIP_DIA_CELLS := 9
const TIP_DIA_CELL := 16
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
## Row spacing (vertical) for both grids, and the column-count/column-fit
## base gap grid_cols() sizes off. The GAP BETWEEN CELLS (horizontal) is
## wider than this in practice — NO-207 stretches it per row so the columns
## span the full width with no leftover; see _inv_row_sep().
const INV_CELL_SEP := 6
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
## NO-175, 3rd pass — Max's revised mockup supersedes the 1st/2nd pass layout
## below (a long left column with Turn/Wave on top): LEFT is now just TWO
## rows, Score then Gold; CENTRE stacks a small Turn/Wave line directly above
## the Clock, both horizontally centred as their own blocks; RIGHT is
## unchanged, Stock and the ☰ button at the same size. "Slim the header to
## the right two buttons' height" makes HEADER_BTN (52, below) the sizing
## reference instead of the tallest column's content — HEADER_H is now
## DERIVED from it (52 + HEADER_PAD_Y*2 = 56), not an independent number to
## keep in sync. This genuinely shrinks the header (96 -> 56); board_tile_for
## grows in response (49 -> 52 no-notch, 44 -> 48 on an iPhone-11-class 56px
## notch — see build()'s own comment for the arithmetic). Squeezes the
## Clock's vertical room hard, since it now shares the centre band's height
## with the Turn/Wave line above it — CLOCK_FONT's ceiling (36, below) is
## very unlikely to be reached now; expect something closer to CLOCK_FONT_MIN.
const HEADER_PAD_X := 10.0 ## gutter at the LEFT edge (the counters column)
## NO-175 margin fix: the right column (Stock, ☰) reads its right-edge
## gutter from THIS constant, not HEADER_PAD_X, so it equals the top/bottom
## margin the buttons already get from being centred in HEADER_H (which is
## HEADER_BTN + HEADER_PAD_Y*2 by construction — see HEADER_H's own
## comment). Before this fix the right gutter was HEADER_PAD_X (10) against
## a 2px top/bottom, which is the "random margin" Max flagged. HEADER_PAD_X
## keeps a bigger value because the LEFT edge sits beside the Score/Gold
## counters' text, not a square button, and was never part of the complaint.
const HEADER_PAD_Y := 2.0
const HEADER_GAP := 6.0 ## between the counters column, the Stock button and the menu button
const STOCK_ICON := 44 ## the piece icon on the Stock button
const STOCK_PAD := 4.0 ## padding around the Stock icon, both axes
## NO-175: "pause menu and stock buttons are now the same size" — HEADER_BTN
## is Stock's old footprint (icon + padding, unchanged: shrinking the piece
## icon would hurt legibility), and the ☰ button grows to match it instead
## of the other way round.
const HEADER_BTN := STOCK_ICON + STOCK_PAD * 2.0
## NO-175, 3rd pass: "slim down the header to the height of the right 2
## buttons" — HEADER_BTN plus the same top/bottom breathing room every other
## row in this Header uses (HEADER_PAD_Y), not an independently-tuned number
## that could drift from what actually sizes the buttons.
const HEADER_H := HEADER_BTN + HEADER_PAD_Y * 2.0
const CLOCK_FONT := 36 ## NO-162: restored — NO-125 had shrunk this to 15 to fit the old HEADER_H.
## Ceiling only: build() measures the real font and shrinks toward this if
## 36 doesn't fit the restacked left column's width (fix for the clipped
## clock Max's screenshot pass caught) — see build()'s own comment. A real
## 480-wide portrait run should land well clear of this — it is a hard
## anti-infinite-loop floor (below which text stops being legible at all),
## not a design target; it deliberately is NOT picked near NO-125's old 15,
## so the search is free to find whatever the real font actually needs
## rather than being nudged back toward the value this ticket undid.
const CLOCK_FONT_MIN := 12
const SCORE_FONT := 17 ## a 17px Label is 24px tall (measured, NO-125). NO-175: Gold reads at this size too now.
const COUNTER_FONT := 15 ## the ⚑ Wave and turn counters
## NO-175, 3rd pass: the LEFT column now holds only Score/Gold (Turn/Wave
## moved to the CENTRE band, above the Clock — see build()). Kept at its
## established value, generous for two six-digit odometers; no longer bounds
## a King name, which is capped by the centre band's own width now instead.
const COUNTER_W := 150.0
## NO-175: was 15, sized for the old 34px button — coordinator feedback:
## "reads as a small mark floating in a large box" now that the button is
## HEADER_BTN(52). Scaled up toward the ratio Stock's icon fills its own
## button (44/52 ≈ 0.85; a text glyph doesn't need quite that much given the
## button's own left/right padding) — visual judgement call, re-check on capture.
const MENU_FONT := 28
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
const STACK_SLIDE_S := 0.18 ## NO-237: a kept stack sliding to its new cell
const STACK_POP_IN_S := 0.15 ## NO-237: a new stack scaling/fading in
const STACK_FADE_OUT_S := 0.12 ## NO-237: a gone stack fading out
## NO-164: a fixed visible divider between Captured Stock and Stock — was
## nothing (separation 0), relying only on incidental slack (NO-135) landing
## near the boundary, which isn't always there. Comes out of Stock's own
## width (cap_w is still the NO-84 fixed fraction), so the split point never
## moves as pieces are captured or deployed, same as before.
const STOCK_DRAWER_GUTTER := 6.0
## ----------------------------------------------------------------------------
## The first King's wave (data/kings.gd: "wave 50 -> king 1"; data/waves.gd row
## 50). The ⚑ Wave counter's denominator until that King falls (NO-82).
const WIN_WAVE := 50

signal pass_pressed
signal king_ability_pressed
signal stack_pressed(entry: Variant, cap: bool, count: int) # entry: ADR-0002
signal stack_drag_started(entry: Variant, cap: bool)
signal stack_preview_requested(id: String, cap: bool, entry: Variant) # NO-138:
	# a Stock/Captured cell's long press — game.gd owns _show_preview, hud.gd
	# only asks for it (see `g`'s own "read-only from here" rule above).
	# cap/entry (NO-144/NO-223): so game.gd's preview can offer Sell for a
	# Stock entry or Convert for a Captured one (never both) — the ⇄ badge
	# below is information only now, Convert itself lives in that preview.
signal multi_confirm_pressed # NO-124: the floating targeting-confirm button —
	# was "multi"'s own Extract, generalised to every targeted Item/Artefact's
	# final confirm (see multi_confirm_btn's own declaration below)
signal multi_cancel_pressed # NO-137: the Cancel button underneath it — same
	# entry-point shape as multi_confirm_pressed, but resets targeting instead
	# of committing it (see multi_cancel_btn's own declaration below)
signal item_pressed(index: int)
signal item_preview_requested(index: int) # NO-144: an Item cell's long
	# press — same "own menu" preview pieces get (stack_preview_requested
	# above), so Sell has somewhere to live for a held Item too
signal artefact_activate_pressed(key: String) # issue 52: an Activate chip pressed
signal artefact_preview_requested(key: String) # NO-144: same as
	# item_preview_requested above, for a held Artefact
signal army_ability_pressed # issue 67: the Army Ability chip pressed
signal promote_pressed(id: String)
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
var gold_zeros_label := Label.new() # NO-175: greyed leading-zero padding, same odometer as Score
var gold_label := Label.new() # spendable currency (score is the metric)
var gold_row := HBoxContainer.new() # NO-127: pulsed as one unit on a gain
var wave_label := Label.new()
var turn_label := Label.new()
var turn_wave_row := Control.new() # NO-175, 3rd pass: centred above the Clock; refresh() re-centres it as content changes
var pass_button := Button.new()
var shop_button := Button.new()
var pass_count := Label.new() # blue N/M action counter on the PASS button
var pass_label := Label.new() # the "PASS" word next to the counter
var king_ability_button := Button.new() # top-row tariff count; opens the overlay
var arrow_button := Button.new() # Arrow Planning: toggles decorative drawing mode
var arrow_clear_button := Button.new() # clears every drawn arrow
var drawer_open := "" # "", "stock", "inventory"
var drawers := {} # name -> Control (the "stock" entry is a PanelContainer; NO-134 made "inventory" a plain Control so its background can outsize its scroll content)
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
var multi_cancel_btn := Button.new() # NO-137: sits underneath multi_confirm_btn
var confirm_backdrop := ColorRect.new() # NO-137: dims the bottom UI (Shop/
	# Inventory/Ability/Pass) while Confirm/Cancel float over it, so those
	# buttons read as "not clickable right now" instead of merely being
	# covered — see build()'s own comment for the MOUSE_FILTER_STOP choice.
## NO-59: the description popup and its text. Built once in build(), owned by
## the HUD rather than by any row — hud.refresh() frees every strip child, so a
## panel parented to a row would not survive the next state change.
var tip_panel: PanelContainer
var tip_label: Label
## NO-152: the compact movement diagram, shown above tip_label when show_tip
## is given a piece id. Built once (like tip_panel/tip_label) and just
## toggled/redrawn per call, rather than rebuilt, so a repeat tip doesn't
## need a fresh `draw` connection.
var tip_diagram: Control
var tip_diagram_id := "" # "" hides tip_diagram; read by its own `draw` closure
var tip_diagram_tex: Texture2D = null
## Which artefact row the popup is currently describing, so tapping the same row
## again closes it. Empty when nothing is shown.
var tip_key := ""
## NO-84: Captured Stock (left third) and Stock (right two thirds) are two
## independent grids now, not one strip — each inside its own ScrollContainer
## so dragging one side never scrolls the other (story 36).
## V1 (Max, 2026-09-21 correction): a plain GridContainer fills top-left
## first, which can't express "item 0 bottom-right, filling right-to-left,
## piling new rows upward" — a VBoxContainer of per-row HBoxContainers can
## (see _rebuild_stock_drawer's own comment). Kept the `_grid` name: every
## other reference to these two treats them as "the pool container", not as
## anything GridContainer-specific.
var stock_grid := VBoxContainer.new()
var captured_grid := VBoxContainer.new()
## NO-237: the button showing each stack, keyed by _stack_keys — kept across
## _rebuild_stock_drawer so a stack can slide rather than be rebuilt.
var _stack_btns := {}
var _stack_anim_gen := 0 ## NO-237: only the latest rebuild's FLIP pass runs
## How many entries fit per row — was `stock_grid.columns`/`captured_grid.
## columns` before V1; a VBoxContainer has no such property, so the layout
## step below stores it here instead, for _rebuild_stock_drawer to read.
var stock_cols := 1
var cap_cols := 1
var captured_hint := Label.new() # "no Captured Stock yet" — shown only when empty
## NO-208: both drawers' own ScrollContainers, kept so _rebuild_stock_drawer
## can reset their scroll position — built as locals inside build() otherwise.
var stock_scroll := ScrollContainer.new()
var cap_scroll := ScrollContainer.new()
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
## NO-180: the Power's own effect line, split out of army_power_label (which
## used to carry name + effect on one row) so the band reads as three
## distinct rows — Title (army + Power name), Subtitle (what the Power
## does), Body (the Ability, below) — rather than one long run-on line.
var army_power_desc_label := Label.new()
## The Army Ability, promoted out of the Inventory drawer onto the deck so its
## readiness is visible without opening a menu (design C).
var army_ability_button := Button.new()
## NO-115: a short reminder of what the Ability DOES, under its name — there
## is no hover to read the tooltip on a touch screen mid-run. NO-128 moved it
## out of act_row and into army_band, below.
var army_ability_hint := Label.new()
## NO-128: the collapsible band — Army Power, the Ability hint, and (while one
## is active) the King Abilities button. Was the bare "power_badge" panel;
## renamed because it now holds three things, not one. NOT a deck row (see
## build()'s own comment where it's positioned): it overlays the board above
## the deck, like the Inventory drawer, so collapsing it actually gives board
## space back instead of a permanent reservation DECK_ROWS would have to pay
## for whether or not the band is ever open (coordinator review 2026-09-19).
var army_band := PanelContainer.new()
var army_band_open := true
## NO-163: the ONE control that opens/closes army_band, anchored in the
## button row — ALWAYS visible there, never moving. Before this it was two
## separate buttons in two separate places (a "▴ Hide" wedge inside
## army_band itself, at the top of the header area; this wedge, only shown
## once collapsed): the affordance for "control the band" jumped from the
## top of the screen to the button row depending on state, which is the
## exact "moves under the player's finger" failure this ticket named. Now
## it's one Button whose glyph flips (_update_band_toggle below) and whose
## position never does. NO-180 moved it from between Inventory/Shop to
## their LEFT — still the one fixed slot in nav_row, still never moving
## between open and closed.
## NO-180: re-added inside the band (top-right of band_header) alongside the
## nav-row wedge below — NO-163 had merged the in-band hide control into that
## wedge; Max wants a close affordance back inside the band too.
var army_band_close := Button.new()
var army_band_reopen := Button.new()
## NO-128: separation inside army_band's internal VBox. Its own constant (not
## reused from elsewhere) because it is a tighter internal stack, not a deck
## row gap.
const BAND_GAP := 1
## NO-128: army_band's own fixed height, same convention as INV_DRAWER_H
## (flat, never measured at runtime). ESTIMATED, revised for NO-180's 3-row
## body (was 78 for 2 rows) — padding 10 + title 22 (army_power_label's row,
## shared with army_band_close, taken as the taller of the two) + BAND_GAP 1
## + subtitle 18 (army_power_desc_label, a smaller single line) + BAND_GAP 1
## + body ~30 (army_ability_hint now wraps the FULL ability description
## instead of a 45-char truncation — budgeted for ~2 wrapped lines at its
## font size) + BAND_GAP 1 + king-ability ~22 (unchanged; hidden unless an
## ability is active). Unlike DECK_ROWS this no longer feeds the board-tile
## solve, so being off costs only a little dead space or a tight fit inside
## this one overlay, never a tile — UNVERIFIED (no Godot run): confirm the
## body never overlaps the deck below it on the longest ability_desc
## (Syndicate's Hostile Takeover).
const ARMY_BAND_H := 105.0
## NO-180: clearance between army_band's own bottom edge and deck_top (the
## button row it used to sit flush against, "glued to the bottom menu" per
## the ticket). Purely repositions the overlay upward — ARMY_BAND_H itself is
## unchanged by this, and neither value feeds DECK_ROWS/board_tile_for
## (ADR-0004: army_band is not a deck row; that must stay true).
const ARMY_BAND_MARGIN := 6.0
## NO-181: the ONE gap between any two deck buttons — horizontal within
## nav_row/act_row and vertical between the two rows alike. Before this,
## nav_row and act_row separations happened to both read 5 while the actual
## gap BETWEEN the rows was whatever leftover slack act_row's EXPAND|
## SHRINK_END absorbed instead (deck's own separation was 0) — the same "two
## constants that happen to agree" shape as NO-175's header gutter
## (HEADER_PAD_X vs HEADER_PAD_Y). Reused by game.gd's DECK_ROWS so the two
## accountings can't drift apart.
const DECK_GAP := 5.0
## NO-180: army_band_reopen's new square footprint, moved to the LEFT of the
## Inventory/Shop pair — nav_row's own natural row height (32, live-checked
## by test_game_clicks.gd against DECK_ROWS), reused so the button reads as
## sized-to-its-row rather than an odd size dropped into it.
const DECK_ICON_BTN := 32.0
## Height of the control deck. Drawers open ABOVE it rather than covering it:
## the deck is the persistent surface in design C, and a drawer that buries PASS
## and the Ability takes the two most-pressed controls away exactly when the
## player is mid-decision.
var deck_h := 0.0
## The bottom row: Ability beside PASS. Held as a member because build() places
## it before the power label exists and the final order is set afterwards.
var act_row: HBoxContainer
## The drawers row: Inventory and Shop, equal halves (NO-83 retired the Deck's
## Stock button — Stock opens from the Header). NO-128 added army_band_reopen
## beside them; NO-180 moved it to their LEFT, square, as an icon button.
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


## NO-165: a section heading inside the Inventory drawer (Items, Artefacts).
static func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	return l


## NO-207: the horizontal gap that makes `cols` Tuning.OFFBOARD_ICON cells
## span `avail_w` exactly, edge to edge, instead of the fixed INV_CELL_SEP
## leaving a shortfall (5-column standard, fixed icon size — see the call
## site's comment). `cols` is always >= 1 (grid_cols() clamps it there).
static func _inv_row_sep(avail_w: float, cols: int) -> float:
	if cols <= 1:
		return INV_CELL_SEP
	return (avail_w - cols * Tuning.OFFBOARD_ICON) / (cols - 1)


## NO-165: an unfilled slot, signifying room left against whatever actually
## bounds the holding (ItemLogic.cap / ArtefactHooks.cap) — same
## Tuning.OFFBOARD_ICON footprint as a real cell (NO-132: a row of
## placeholders is still a row for the 5-column grid standard). Decorative
## only: MOUSE_FILTER_IGNORE, not PASS — a plain Control with no gui_input at
## all can never become a click target or grow a long-press, which is a
## stronger guarantee than the real cells' deliberate PASS (NO-45) needs to
## make for their own drag-scroll passthrough.
static func _empty_slot() -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(Tuning.OFFBOARD_ICON, Tuning.OFFBOARD_ICON)
	slot.add_theme_stylebox_override("panel",
		_surface(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.14), 6))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return slot


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
	# ---- THE HEADER (NO-82/NO-83, rebuilt NO-175) ---------------------------
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

	# LEFT COLUMN (NO-175, 3rd pass — Max's revised mockup): Score, then
	# Gold, TWO rows only — Turn/Wave moved to the CENTRE band, above the
	# Clock (below). Tight, top-flush: both rows are plain HBoxContainers
	# with no leading symbol, stacked in the same VBox, so their zeros
	# labels start at the same x and the digits share a left edge for free
	# (NO-114's old SYMBOL_W trick only existed because the Score row used
	# to lead with a ★).
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
	score_row.add_theme_constant_override("separation", 0)
	for l in [score_zeros_label, score_label, score_pts_label]:
		score_row.add_child(l)

	# GOLD (NO-175): "$ and score should also have the same font size and
	# their numbers aligned" — Gold adopts SCORE_FONT and Score's odometer
	# shape (was a plain "%d", trailing "$" at its own GOLD_FONT). gold_row
	# is shaped exactly like score_row (no leading symbol, separation 0), so
	# it aligns with Score for free — see this block's own header comment.
	gold_zeros_label.add_theme_font_size_override("font_size", SCORE_FONT)
	gold_zeros_label.add_theme_color_override("font_color", SCORE_ZERO_COLOR)
	gold_label.add_theme_font_size_override("font_size", SCORE_FONT)
	gold_label.add_theme_color_override("font_color", Tuning.COL_GOLD)
	var gold_symbol := Label.new()
	gold_symbol.text = " $" # leading space is the gap, same idiom as score_pts_label's " Pts"
	gold_symbol.add_theme_font_size_override("font_size", SCORE_FONT)
	gold_symbol.add_theme_color_override("font_color", Tuning.COL_GOLD)
	gold_row.add_theme_constant_override("separation", 0)
	for l in [gold_zeros_label, gold_label, gold_symbol]:
		gold_row.add_child(l)

	var left := VBoxContainer.new()
	left.position = Vector2(HEADER_PAD_X, y0 + HEADER_PAD_Y)
	left.custom_minimum_size = Vector2(COUNTER_W, 0)
	left.add_theme_constant_override("separation", 0) # "tight" per the mockup
	left.add_child(score_row)
	left.add_child(gold_row)
	add_child(left)

	# CENTRE (NO-175, 3rd pass): a small Turn/Wave line directly above the
	# Clock, both horizontally centred as their own blocks in the same band
	# between the LEFT column and the Stock button. The band's width is
	# shared by both — the Clock's own fit loop AND Turn's hard ellipsis
	# cap (a long King name) — computed once, here.
	#
	# At 480x800: mid_left_edge=160, mid_right_edge=360, centre=240 — the
	# LEFT side is the binding constraint (80px vs 120px of clearance), so
	# the band is symmetric around centre at 2*(80-HEADER_GAP)=148px, not
	# the full 200px between the two edges.
	var mid_left_edge: float = HEADER_PAD_X + COUNTER_W
	var mid_right_edge: float = vp.x - HEADER_PAD_Y - HEADER_BTN * 2.0 - HEADER_GAP
	var centre_x: float = vp.x / 2.0
	var half_budget: float = minf(centre_x - mid_left_edge, mid_right_edge - centre_x) - HEADER_GAP
	var centre_w: float = half_budget * 2.0

	# Turn/Wave: same fully-explicit, hard-capped approach the last fix
	# established (see its own history below), just capped to centre_w
	# instead of COUNTER_W now that it lives in the centre band, not the
	# left column. turn_wave_row has no meaningful width of its own — it's
	# a grouping parent, positioned (and RE-positioned every refresh(),
	# since the visible pair must stay centred as its content changes) the
	# same way clock_label is: a direct HUD child, not Container-managed.
	#
	# 2nd-pass history, still the reason turn_label is built this way:
	# `text_overrun_behavior` alone does nothing — Godot only trims
	# rendered ink when the Control's own size is smaller than its
	# content, and `clip_text` is what makes that possible. Without it, a
	# long King name's un-ellipsised natural width dragged the whole row
	# (and, in the 2nd pass, `left`) out to 500+px (coordinator capture,
	# 2026-09-20).
	var counter_font := turn_label.get_theme_default_font()
	var counter_h: float = counter_font.get_height(COUNTER_FONT)
	turn_wave_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_wave_row.position = Vector2(centre_x, y0 + HEADER_PAD_Y) # x is a placeholder; refresh() centres it
	turn_label.add_theme_font_size_override("font_size", COUNTER_FONT)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.clip_text = true
	turn_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	turn_label.position = Vector2.ZERO
	turn_label.size = Vector2(centre_w, counter_h)
	turn_label.custom_minimum_size = Vector2(centre_w, counter_h)
	turn_wave_row.add_child(turn_label)
	wave_label.add_theme_font_size_override("font_size", COUNTER_FONT)
	wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_label.modulate = Color(1, 1, 1, 0.85)
	wave_label.position = Vector2.ZERO # x is recomputed every refresh() from Turn's real width
	wave_label.size = Vector2(centre_w, counter_h)
	turn_wave_row.add_child(wave_label)
	add_child(turn_wave_row)

	# The Clock, large, directly under the Turn/Wave line, both centred in
	# the same band. Kept fully explicit — no Container, alignment pinned,
	# clip_text on — for the same reason NO-162's fix comment gives: a
	# Container's own rect isn't where the text actually lands, and three
	# earlier passes on this exact Label shipped a passing assertion over a
	# visibly clipped clock because they trusted it. `_clock_text()`
	# (game.gd) is "%02d:%02d.%03d", ALWAYS 9 characters, so this sample is
	# the only case that exists.
	#
	# NO-162's "glyphs ~26% wider than get_string_size, ~10 units left of
	# position.x" measurements were captures taken mid minute-shake (scale
	# 1.35 around the centre pivot) — see NO-174. At rest the Label box is
	# exact, so this fits to the full centre band and centres plainly.
	#
	# NO-175, 3rd pass: the vertical budget changes AGAIN — the centre band
	# now also holds the Turn/Wave line above the Clock, and the whole
	# Header slimmed to HEADER_BTN's height (see HEADER_H's own comment),
	# so the fit loop now shrinks for HEIGHT as well as width — it never
	# needed to before, because the Clock used to have the Header's full
	# height to itself. Expect a much smaller applied size than the 36pt
	# ceiling.
	var clock_sample := "00:00.000"
	var tw_gap := 2.0 # minimal — "remove empty space" (Max)
	var clock_h_budget: float = (HEADER_H - HEADER_PAD_Y * 2.0) - counter_h - tw_gap
	var clock_target_w: float = centre_w
	var clock_font := clock_label.get_theme_default_font()
	var clock_size := CLOCK_FONT
	while clock_size > CLOCK_FONT_MIN \
			and (clock_font.get_string_size(clock_sample, HORIZONTAL_ALIGNMENT_LEFT, -1, clock_size).x > clock_target_w \
				or clock_font.get_height(clock_size) > clock_h_budget):
		clock_size -= 1
	var clock_w: float = clock_font.get_string_size(clock_sample, HORIZONTAL_ALIGNMENT_LEFT, -1, clock_size).x
	var clock_h: float = clock_font.get_height(clock_size)
	clock_label.add_theme_font_size_override("font_size", clock_size)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock_label.clip_text = true
	clock_label.position = Vector2(centre_x - clock_w / 2.0,
		y0 + HEADER_PAD_Y + counter_h + tw_gap)
	clock_label.size = Vector2(clock_w, clock_h)
	clock_label.custom_minimum_size = Vector2(clock_w, clock_h)
	add_child(clock_label)

	# RIGHT: Stock and the ☰ button, side by side, the SAME size AND the
	# SAME style (NO-175). Size was already matched last pass (HEADER_BTN);
	# the colour mismatch Max flagged was real — ☰ was styled through the
	# shared "compact" StyleBoxFlat loop below (a solid dark grey,
	# Color(0.22, 0.22, 0.26)), meant for the two OFF-SCREEN buttons in that
	# loop, while Stock uses `_style_button` with a translucent white tint
	# (Color(1, 1, 1, 0.08)) — two different styling calls, never unified.
	# ☰ now uses the SAME `_style_button` call as Stock, so the only
	# remaining differences are the glyph and Stock's count badge, exactly
	# what Max asked for. Both are vertically centred in the Header now
	# that nothing else shares their column (Wave/Turn moved into the
	# CENTRE band, above).
	king_ability_button.add_theme_font_size_override("font_size", 13)
	king_ability_button.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
	king_ability_button.pressed.connect(func() -> void: king_ability_pressed.emit())
	arrow_button.text = "Arrows"
	arrow_button.add_theme_font_size_override("font_size", 13)
	arrow_button.pressed.connect(func() -> void: arrow_toggle_pressed.emit())
	# NO-83: the ⚠ and Arrows buttons are NOT on screen. Their state, signals
	# and handlers stay (refresh still writes their text) so nothing behind
	# them is lost; they get a home again when the Deck is redesigned (NO-84+).
	# flat compact styling (2026-07-08) for the two off-screen buttons only —
	# ☰ moved OUT of this loop (NO-175, 3rd pass) so it can share Stock's
	# own style instead.
	for b: Button in [king_ability_button, arrow_button]:
		var compact := StyleBoxFlat.new()
		compact.bg_color = Color(0.22, 0.22, 0.26)
		compact.set_corner_radius_all(4)
		compact.content_margin_left = 7
		compact.content_margin_right = 7
		compact.content_margin_top = 1
		compact.content_margin_bottom = 1
		for style in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(style, compact)

	var header_btn_y: float = y0 + (HEADER_H - HEADER_BTN) / 2.0
	menu_button.text = "☰"
	menu_button.add_theme_font_size_override("font_size", MENU_FONT)
	# NO-175 margin fix: right gutter is HEADER_PAD_Y, matching the top/bottom
	# margin header_btn_y already gives the buttons (see HEADER_PAD_Y's own
	# comment) — not HEADER_PAD_X, which would reintroduce the mismatch.
	menu_button.position = Vector2(vp.x - HEADER_PAD_Y - HEADER_BTN, header_btn_y)
	menu_button.custom_minimum_size = Vector2(HEADER_BTN, HEADER_BTN) # NO-131/NO-175: square, matches Stock
	_style_button(menu_button, Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 8, STOCK_PAD, STOCK_PAD) # NO-175: same call as Stock (this block's header comment)
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
	# THE STOCK BUTTON (stories 7-12). NO-131: a regular button — its own
	# rect, sized to its icon and padding, not stretched to the Header's full
	# height and out to the counters column (NO-83's original enlarged tap
	# zone). See test_game_clicks.gd's NO-83 block for why that zone existed
	# (a tap on the top-right board tile, or on the menu button, must never
	# open Stock) and confirmation the smaller rect still holds it. NO-175:
	# that footprint is now HEADER_BTN, shared with the ☰ button above.
	var stock_btn := Button.new()
	if g.textures.has("pawn"):
		stock_btn.icon = g.piece_tex("pawn") # Stock is always yours: the player token
		stock_btn.expand_icon = true
		stock_btn.add_theme_constant_override("icon_max_width", STOCK_ICON)
	else:
		stock_btn.text = "♟"
	_style_button(stock_btn, Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 8, STOCK_PAD, STOCK_PAD)
	stock_btn.pressed.connect(func() -> void:
		set_drawer("stock")
		drawer_changed.emit())
	# expand_icon lets the icon SHRINK for min-size purposes (it's what makes
	# icon_max_width a cap rather than a fixed size), so get_combined_minimum_size()
	# can't be trusted the way intro.gd's text-only Skip button trusts it —
	# it collapsed this button to near-nothing. Pin the rect explicitly, to
	# the same HEADER_BTN footprint as the ☰ button, right-aligned before it
	# with the usual HEADER_GAP, both vertically centred in the Header.
	stock_btn.custom_minimum_size = Vector2(HEADER_BTN, HEADER_BTN)
	stock_btn.position = Vector2(menu_button.position.x - HEADER_GAP - HEADER_BTN, header_btn_y)
	add_child(stock_btn)
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
	# ---- THE CONTROL DECK (design C, user pick 2026-09-05) ------------------
	# Everything under the board lives in one column, bottom-anchored to the
	# screen edge, at its own FIXED height — DECK_ROWS (game.gd), the same
	# constant board_tile_for() already reserves when it solves the tile size.
	# NO-196: it used to be "whatever's left after the board" (vp.y - a
	# board-bottom-derived deck_top), which is not the same thing —
	# board_tile_for() floors tile to an int, and the resulting residual (0 to
	# just under BOARD_H px) landed as a SECOND, resolution-dependent gap
	# between nav_row and act_row (act_row's own SIZE_EXPAND|SIZE_SHRINK_END
	# absorbed it invisibly, on top of DECK_GAP). Sizing the deck to DECK_ROWS
	# instead leaves nothing inside it for act_row to claim, so that gap is
	# now always exactly DECK_GAP; any residual shows up ABOVE the deck, where
	# ADR-0004 already says leftover height belongs (the board is the slack
	# absorber, not the deck).
	var deck := VBoxContainer.new()
	deck_h = g.DECK_ROWS
	# deck_top is therefore "screen bottom minus the deck's own fixed height",
	# not board-derived any more — everything below that anchors "just above
	# the deck" (army_band, the Inventory drawer, confirm_backdrop) already
	# reads this same var, so they inherit the fix unchanged.
	# NO-197: this also clears the deck of the board's own outline. board_tile_for()
	# reserves DECK_MARGINS (12) between the board and DECK_ROWS, well past the
	# outline's outer ink (BOARD_OUTLINE_INSET + BOARD_OUTLINE_WIDTH/2 = 5.5,
	# game.gd) — bottom-anchoring the deck at a fixed height can only widen
	# that gap, never shrink it below the ink. (Proof: with tile floored,
	# deck_top - board_bottom = vp.y - DECK_ROWS - top - tile*BOARD_H >=
	# vp.y - DECK_ROWS - top - (vp.y-top-DECK_MARGINS-DECK_ROWS) = DECK_MARGINS,
	# for either branch of board_tile_for's min().)
	var deck_top: float = vp.y - deck_h
	deck.position = Vector2(0, deck_top)
	deck.custom_minimum_size = Vector2(vp.x, deck_h)
	# NO-163 closed this to 0 (was 6). NO-181 reopens it to DECK_GAP — the SAME
	# constant nav_row/act_row use for their own button gaps below, rather
	# than an independently-chosen number — so the gap between the two rows
	# reads as one deliberate value, not whatever slack was left over.
	# game.gd's DECK_ROWS grows by DECK_GAP to match (it derives directly off
	# this constant now).
	deck.add_theme_constant_override("separation", DECK_GAP)
	add_child(deck)
	# NO-145 (hardware round 2): deck used to also be hooked here as a
	# swipe-to-open surface (its own unclaimed area, MOUSE_FILTER_STOP).
	# Real hardware showed that gap is not reliable — NO-128 took DECK_ROWS
	# from 132 to 98 without shrinking nav_row/act_row, squeezing or
	# removing the gap a press was aimed at, so the press landed on a
	# child before deck.gui_input ever saw it. Coordinator ruling: all
	# three open gestures now start on an empty board tile only
	# (game.gd's _swipe_open_may_begin) — no dependence on deck geometry.

	# NO-83: the stock strip and the status line are gone from the Deck. The
	# strip's job (which pieces you hold, without opening anything) moves to
	# the Header's Stock badge; wave and turn moved up with it. The Deck is now
	# the drawers row, the Power badge and the thumb row.
	nav_row = HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", DECK_GAP)
	nav_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deck.add_child(nav_row)

	var bar := nav_row
	# NO-128/NO-163/NO-180: the wedge that opens AND closes army_band. NO-180
	# moves it to the LEFT of Inventory/Shop (was between them) and gives it a
	# square, icon-button footprint instead of a thin wedge, so it reads as
	# its own control rather than a divider — fixed-size either way (no
	# EXPAND_FILL), so Inventory and Shop still stay equal to EACH OTHER.
	# ALWAYS visible (was hidden while the band was open, when a second
	# button — band_collapse, inside army_band itself — did the closing
	# instead; see this var's own declaration for why that was wrong).
	army_band_reopen.custom_minimum_size = Vector2(DECK_ICON_BTN, DECK_ICON_BTN)
	army_band_reopen.add_theme_font_size_override("font_size", 15)
	# NO-225: square, and green. The footprint (DECK_ICON_BTN, 32x32) was
	# already square — the old radius 16 is exactly half of that, which
	# rendered a full circle, not a square with soft corners. Radius 8 below
	# matches menu_button/stock_btn (the row's other icon buttons, same
	# _style_button call). Surface is pass_count's bright green
	# (0.498, 0.878, 0.541, hud.gd:1012) scaled down in value (~x0.25) to a
	# dark surface so it reads as green without the white glyph washing out.
	# NO-225: the glyph's own font_color is set (and kept in sync per state)
	# by _update_band_toggle below, not here — a static override here would
	# be a second source of truth immediately clobbered by that call.
	_style_button(army_band_reopen, Color(0.125, 0.220, 0.136), Color(0, 0, 0, 0), 8, 4, 4)
	army_band_reopen.pressed.connect(func() -> void:
		if army_band_open:
			collapse_army_band()
		else:
			if drawer_open == "inventory": # NO-128: same screen rect as army_band
				set_drawer("inventory") # already "inventory" -> toggles it closed
				drawer_changed.emit()
			army_band_open = true
			army_band.visible = true
		_update_band_toggle())
	bar.add_child(army_band_reopen)
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
	# NO-137: a semi-transparent backdrop over the bottom UI (Shop/Inventory/
	# Ability/Pass) while an Item/Artefact's floating Confirm is up. Sized to
	# `deck`'s own rect exactly (deck_top/deck_h, both already computed above
	# for `deck` itself) — "the bottom buttons" the ticket names, nothing
	# more (army_band, above the board, is untouched).
	#
	# MOUSE_FILTER_STOP here is the point, not a trap to dodge: added as a
	# LATER sibling than `deck`, so Godot's front-to-back GUI picking gives
	# it first refusal over deck's buttons and it absorbs the press — they
	# read as "not clickable right now" because they genuinely aren't.
	# multi_confirm_btn/multi_cancel_btn are added AFTER this (later still),
	# so they stay clickable on top of it. Unlike _set_drawer_clickable's
	# IGNORE case (which must fall THROUGH to the board), this wants to
	# BLOCK, so no per-descendant filter save/restore is needed — deck's own
	# buttons keep whatever filter they already have; only what sits above
	# them (this backdrop) changes.
	confirm_backdrop.color = Color(0, 0, 0, 0.55)
	confirm_backdrop.position = Vector2(0, deck_top)
	confirm_backdrop.custom_minimum_size = Vector2(vp.x, deck_h)
	confirm_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_backdrop.visible = false
	add_child(confirm_backdrop)
	# NO-124: floating targeting-confirm, shown once there's something to
	# confirm — see refresh() for exactly when, per targeting shape
	multi_confirm_btn.add_theme_font_size_override("font_size", 17)
	multi_confirm_btn.position = Vector2(vp.x / 2 - 70, vp.y - 96)
	multi_confirm_btn.custom_minimum_size = Vector2(140, 40)
	multi_confirm_btn.visible = false
	multi_confirm_btn.pressed.connect(func() -> void: multi_confirm_pressed.emit())
	add_child(multi_confirm_btn)
	# NO-137: Cancel, underneath Confirm. NO-121's "tap the armed chip again"
	# path still works unchanged; this just gives it an affordance right next
	# to Confirm instead of requiring the Inventory drawer be reopened first.
	# Costs nothing: game.gd's handler only resets targeting state (the same
	# reset the chip-tap path already uses) — Economy.charge only ever runs
	# from _item_apply, on an actual commit.
	multi_cancel_btn.text = "Cancel"
	multi_cancel_btn.add_theme_font_size_override("font_size", 15)
	multi_cancel_btn.position = Vector2(vp.x / 2 - 70, vp.y - 48)
	multi_cancel_btn.custom_minimum_size = Vector2(140, 40)
	multi_cancel_btn.visible = false
	multi_cancel_btn.pressed.connect(func() -> void: multi_cancel_pressed.emit())
	add_child(multi_cancel_btn)
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
	# NO-115 (styling kept, parenting moved by NO-128): the effect hint used to
	# sit UNDER the button as a Label with its own fixed budget rather than
	# appended into the button's own text (Button's autowrap re-flowed the
	# whole string past the name+status line instead of honoring an inserted
	# "\n"). NO-128 moves the Label itself into army_band (built further down,
	# see band_col.add_child(army_ability_hint)) so its description reads next
	# to the Power it belongs with, rather than under the button. The button
	# now has ability_col — and so act_row's own 60px minimum — to itself; its
	# existing SIZE_EXPAND_FILL vertical flag (below) already claims whatever
	# that frees, no further change needed.
	army_ability_hint.add_theme_font_size_override("font_size", 10)
	army_ability_hint.add_theme_color_override("font_color", Color(0.78, 0.71, 0.55))
	army_ability_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	army_ability_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	army_ability_hint.custom_minimum_size = Vector2(0, 22)
	var ability_col := VBoxContainer.new()
	ability_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ability_col.add_child(army_ability_button)
	act_row = HBoxContainer.new()
	act_row.add_theme_constant_override("separation", DECK_GAP)
	# NO-196: used to carry SIZE_EXPAND|SIZE_SHRINK_END to soak up the deck's
	# leftover trailing space and still dock flush at the bottom. The deck no
	# longer HAS leftover space (its own height is fixed to DECK_ROWS, above),
	# so there's nothing left for EXPAND to claim — act_row is simply the
	# deck's last child now, flush to the deck's own bottom edge by construction.
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
	var guide_scroll := Guide.build(game_menu, func() -> void: gm_box.visible = true, g)
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
	# NO-207 (Max's 4th ask on this): NO-201's SIZE_SHRINK_CENTER pass centred
	# items_grid/artefacts_grid inside inv_box, but inv_box is a VBoxContainer
	# that shrinks to its widest child — which, once custom_minimum_size.x
	# was forced onto the grid (NO-182), IS the grid. There was never any
	# slack inside inv_box to split; the dead column sat OUTSIDE it, between
	# inv_box's right edge and `sc` (the ScrollContainer wrapping it), because
	# `sc` leaves horizontal scrolling at its Godot default (AUTO, never
	# turned off) and a ScrollContainer never stretches a child on an axis
	# where it might need to scroll it — so `sc` gave inv_box only its own
	# minimum width, not `sc`'s. SHRINK_CENTER changed nothing because its
	# parent was already exactly its own size.
	# Fix at the actual source instead: don't leave a shortfall to redistribute
	# at all. grid_cols() floors AND clamps to the 5-column standard
	# (OFFBOARD_GRID_COLS, tuning.gd), so 5 columns of fixed-size
	# Tuning.OFFBOARD_ICON cells are narrower than the available width — here,
	# 5*72 + 4*INV_CELL_SEP(6) = 384 against avail_w's 472, an 88px shortfall
	# (close to one whole cell, matching what Max sees). Resizing
	# OFFBOARD_ICON is out of scope (shared by Stock/Shop, NO-201's call);
	# instead widen just the GAP between cells so `cols` of them span
	# `avail_w` edge to edge — same standard column count, same icon size,
	# genuinely no leftover. Row spacing (v_separation) is untouched, so rows
	# don't grow taller. Both grids share one avail_w/columns/gap, so they
	# always agree.
	var inv_avail_w: float = vp.x - 8.0
	items_grid.columns = Tuning.grid_cols(inv_avail_w, INV_CELL_SEP) # NO-132
	var inv_h_sep: float = _inv_row_sep(inv_avail_w, items_grid.columns) # NO-207
	items_grid.add_theme_constant_override("h_separation", inv_h_sep)
	items_grid.add_theme_constant_override("v_separation", INV_CELL_SEP)
	# NO-182: without an explicit width, a GridContainer shrinks to whatever
	# it actually holds (fewer than `columns` entries in the only/last row
	# makes it narrower still), leaving empty space at the drawer's right edge
	# instead of the full 5-column standard NO-132 names. stock_grid already
	# forces this (NO-135); items_grid/artefacts_grid never did.
	items_grid.custom_minimum_size.x = inv_avail_w # NO-207: fills exactly, by construction
	artefacts_grid.columns = Tuning.grid_cols(inv_avail_w, INV_CELL_SEP) # NO-132
	artefacts_grid.add_theme_constant_override("h_separation",
			_inv_row_sep(inv_avail_w, artefacts_grid.columns)) # NO-207
	artefacts_grid.add_theme_constant_override("v_separation", INV_CELL_SEP)
	artefacts_grid.custom_minimum_size.x = inv_avail_w # NO-182, NO-207
	army_power_label.add_theme_font_size_override("font_size", 13)
	army_power_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var inv_box := VBoxContainer.new()
	inv_box.add_theme_constant_override("separation", 8)
	# issue 100 put this at the top of the Inventory drawer. Design C brings it
	# onto the main view instead: a passive badge you can read without opening
	# anything, which was half the point of the redesign. NO-128: it is now
	# army_band — the Power stays a passive badge, and the Ability hint and
	# (while one is active) the King Abilities button join it, collapsible.
	army_band.add_theme_stylebox_override("panel",
		_surface(Color(0.165, 0.20, 0.141), Color(0.275, 0.345, 0.235), 8, 10, 5))
	var band_col := VBoxContainer.new()
	band_col.add_theme_constant_override("separation", BAND_GAP)
	var band_header := HBoxContainer.new()
	# NO-180: Title row — army + Power name only now (the effect moved to its
	# own subtitle row below).
	army_power_label.add_theme_color_override("font_color", Color(0.749, 0.878, 0.690))
	army_power_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band_header.add_child(army_power_label)
	# NO-180: the close affordance, re-added inside the band (top-right of the
	# Title row — army_power_label's EXPAND_FILL above pushes it there for
	# free) alongside the nav-row wedge (army_band_reopen), which still
	# reopens it once collapsed. STOP is explicit: band_header is IGNORE
	# (NO-128, so a tap elsewhere in the band falls through to the board) and
	# Godot does not cascade that to children.
	army_band_close.text = "✕"
	army_band_close.tooltip_text = "Hide"
	army_band_close.add_theme_font_size_override("font_size", 12)
	army_band_close.custom_minimum_size = Vector2(20, 20)
	army_band_close.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(army_band_close, Color(0.22, 0.22, 0.26), Color(0, 0, 0, 0), 10, 2, 2)
	army_band_close.pressed.connect(func() -> void: collapse_army_band())
	band_header.add_child(army_band_close)
	band_col.add_child(band_header)
	# NO-180: Subtitle row — what the Power actually does (was folded into
	# army_power_label's single combined line).
	army_power_desc_label.add_theme_font_size_override("font_size", 11)
	army_power_desc_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.62))
	army_power_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	band_col.add_child(army_power_desc_label)
	band_col.add_child(army_ability_hint) # NO-128: moved out of act_row; NO-180: Body row, full text
	# NO-128: the King Abilities button, built (styled, wired to
	# king_ability_pressed) in the Header section above but never added to the
	# tree — NO-83 parked it there for "the Deck redesign" to give it a home.
	# refresh() toggles its visibility; it is shown only while an ability is
	# active, so it contributes nothing to army_band's height the rest of
	# the time.
	king_ability_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	king_ability_button.visible = false
	band_col.add_child(king_ability_button)
	army_band.add_child(band_col)
	# NO-128 (coordinator review 2026-09-19, second round): the board is not a
	# Control — it's drawn in game.gd's _draw and its taps arrive through
	# _unhandled_input, which Godot's GUI picking only reaches AFTER every
	# visible Control has had first refusal (CLAUDE.md's "A visible Control
	# absorbs clicks before _unhandled_input ever runs"). army_band overlays
	# the board's own tiles while open, and PanelContainer/VBoxContainer/
	# HBoxContainer all default to MOUSE_FILTER_STOP, so left as built above
	# it silently ate every tap on a covered tile — 3 SETUP click-probe
	# failures, caught only because the probes are windowed (headless drops
	# GUI picking entirely and would never have seen it).
	#
	# Fix: IGNORE on the panel and both plain layout containers, so a tap
	# anywhere in the band that isn't one of ITS OWN controls falls through
	# to the board underneath. Godot does NOT cascade IGNORE to children
	# (same CLAUDE.md bullet — _set_drawer_clickable exists for exactly this
	# asymmetry), so king_ability_button, left at its default STOP, keeps
	# working — a filter set high in this tree has no effect on a control
	# below it that never asked to inherit it. NO-163 moved the band's own
	# open/close control (band_collapse) out of army_band entirely, onto the
	# deck's nav_row (army_band_reopen). NO-180 put a close button back inside
	# the band (army_band_close, band_header) — its own mouse_filter is set to
	# STOP explicitly, above, for exactly this reason: nothing else inside
	# army_band claims input except that and king_ability_button.
	# army_power_label, army_power_desc_label and army_ability_hint need no
	# change: Label already defaults to IGNORE.
	army_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# NO-128 (coordinator review 2026-09-19, route 2 of 2 offered): army_band
	# is NOT a deck row. A deck row is a permanent reservation — DECK_ROWS is
	# sized once at boot and never revisited (ADR-0004), so a collapsible row
	# would force the board to pay for the band's OPEN state forever, whether
	# or not it's ever open. Instead army_band overlays the board above the
	# deck, exactly like the Inventory drawer below (NO-118/NO-134's worked
	# example): DECK_ROWS never sees it, so collapsing genuinely gives board
	# space back rather than costing it permanently. ARMY_BAND_H is a flat
	# estimate, same convention as INV_DRAWER_H — but non-critical now: it
	# only sizes this one overlay, not the board, so being off by a few px
	# costs a little dead space or a tight fit here, never a tile.
	# NO-180: ARMY_BAND_MARGIN lifts the band clear of deck_top instead of
	# sitting flush against it ("glued to the bottom menu") — still just
	# repositioning this one overlay, not a size or budget change.
	army_band.position = Vector2(0, deck_top - ARMY_BAND_H - ARMY_BAND_MARGIN)
	army_band.custom_minimum_size = Vector2(vp.x, ARMY_BAND_H)
	add_child(army_band)
	# Inventory's drawer panel occupies this SAME rect when open (both are
	# anchored to deck_top, extending upward) — see the mutual-exclusion in
	# set_drawer() and army_band_reopen's own handler above. Sibling order
	# doesn't matter for input (the two rects never overlap deck's own), but
	# placing it behind deck matches NO-134's defensive convention in case
	# ARMY_BAND_H is ever a few px taller than estimated.
	move_child(army_band, deck.get_index())
	# DECK ORDER (design C, cut down by NO-83; NO-128 dropped the band to two
	# rows): the drawers row under the board, the thumb row last.
	deck.move_child(nav_row, 0)
	deck.move_child(act_row, 1)
	# NO-165: name the two sections — the drawer used to run straight from
	# Items into Artefacts with nothing marking the seam.
	inv_box.add_child(_section_label("Items"))
	inv_box.add_child(items_grid)
	inv_box.add_child(_section_label("Artefacts"))
	inv_box.add_child(artefacts_grid)
	var drawer_specs := [ # name, content, x, width, height
		["inventory", inv_box, 0.0, vp.x, INV_DRAWER_H],
	]
	for spec in drawer_specs:
		# NO-134: `panel` is a plain Control now, not a PanelContainer — a
		# PanelContainer forces EVERY child to fill its full rect, which is
		# fine for one child (`sc`) but wrong once a second one (`bg`) needs a
		# taller rect than `sc`'s own fixed content height. `bg` paints the
		# full extended height (content height + the deck's own height, so
		# the background runs behind the bottom button row); `sc` keeps its
		# old fixed size and position, unaffected.
		var panel := Control.new()
		var full_h: float = spec[4] + deck_h
		panel.position = Vector2(spec[2], vp.y - deck_h - spec[4]) # above the deck — unchanged: NO-118 caches this as drawer_rest/drawer_hidden
		panel.custom_minimum_size = Vector2(spec[3], full_h)
		panel.visible = false
		var bg := Panel.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.1, 0.1, 0.13, 0.97)
		bg.add_theme_stylebox_override("panel", bg_style)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE # paint only; the deck (moved on top below) handles its own input
		panel.add_child(bg)
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
		# NO-134: behind the deck, so the deck's buttons paint on top of the
		# extended background and win Godot's GUI picking over it (front-to-
		# back, last sibling first) — the same z-order mechanism this file's
		# tip_panel/game_menu already rely on to stay on top of everything.
		move_child(panel, deck.get_index())
		drawer_rest[spec[0]] = panel.position
		# NO-145: `panel`'s own default MOUSE_FILTER_STOP (unset above — only
		# `bg` was set to IGNORE) already claims any press inside its rect
		# that `sc`/cells don't; gui_input reports exactly that leftover
		# "chrome", the surface a reverse-close swipe must start on.
		panel.gui_input.connect(_on_chrome_swipe_input.bind(spec[0]))
		# NO-226: Inventory slides in from the BOTTOM — off-screen is its own
		# full height below rest, so the panel's top sits exactly on the
		# viewport's bottom edge before sliding up to rest.
		drawer_hidden[spec[0]] = panel.position + Vector2(0, full_h)
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
	# NO-228: the Header's controls are added earlier as direct children of
	# `self` (lines ~581-890), so by plain tree order stock_panel — added
	# later — paints OVER them while sliding through the Header's y-range.
	# z_index (not move_child/move_to_front) pins it behind: it only changes
	# CanvasItem paint order, never sibling index, so it cannot reproduce the
	# NO-180 incident (a move_to_front there reordered the deck's children and
	# silently dropped the drawers row) and it cannot touch the tree-order-
	# dependent gui_input/MOUSE_FILTER_STOP chrome-swipe detection those
	# drawers rely on (NO-118/NO-145) — Godot's GUI input picking is unaffected
	# by z_index.
	stock_panel.z_index = -1
	var stock_row := HBoxContainer.new()
	stock_row.add_theme_constant_override("separation", 0)
	# LEFT: Captured Stock, a fixed fraction of the width — fixed so the split
	# never moves as pieces are captured or deployed (story 38).
	var cap_w: float = roundf(vp.x * STOCK_DRAWER_CAP_FRAC)
	# NO-227: lighter background behind the whole Captured Stock column, same
	# "panel inside a panel" idiom as menu.gd's NESTED_PANEL_TINT and the
	# gutter just below (a white overlay at low alpha, so it lightens
	# whatever the drawer's own bg_color is instead of a hardcoded opaque
	# colour that would drift out of sync with it). cap_col is a
	# VBoxContainer, which would force this into its vertical stack instead
	# of painting behind it, so the tint sits on a plain Control wrapper one
	# level up — the same bg/content split this file already uses for the
	# Inventory drawer panel above (`panel`/`bg`/`sc`). IGNORE + added first
	# so it never intercepts cap_scroll's drag-scroll (NO-45).
	var cap_wrap := Control.new()
	cap_wrap.custom_minimum_size = Vector2(cap_w, stock_h)
	var cap_bg := ColorRect.new()
	cap_bg.color = Color(1, 1, 1, 0.06)
	cap_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	cap_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_wrap.add_child(cap_bg)
	var cap_col := VBoxContainer.new()
	cap_col.custom_minimum_size = Vector2(cap_w, stock_h)
	captured_hint.text = "Captured pieces land here"
	captured_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	captured_hint.custom_minimum_size = Vector2(cap_w - STOCK_DRAWER_PAD * 2.0, 0)
	captured_hint.modulate = Color(1, 1, 1, 0.6)
	captured_hint.add_theme_font_size_override("font_size", 11)
	captured_hint.visible = false
	cap_col.add_child(captured_hint)
	cap_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER # NO-136
	cap_scroll.scroll_deadzone = DRAWER_SCROLL_DEADZONE
	var cap_view: Vector2 = Vector2(cap_w - STOCK_DRAWER_PAD, stock_h - STOCK_DRAWER_PAD)
	cap_scroll.custom_minimum_size = cap_view
	cap_cols = Tuning.grid_cols(cap_w - STOCK_DRAWER_PAD, STOCK_DRAWER_CELL_SEP) # NO-132
	# V1: STOCK_DRAWER_CELL_SEP's OTHER axis (between buttons within a row)
	# is set per-row, on each row's own HBoxContainer — _rebuild_stock_drawer.
	captured_grid.add_theme_constant_override("separation", STOCK_DRAWER_CELL_SEP)
	# NO-208: bottom-anchors the grid — ALIGNMENT_END collects any slack (the
	# section taller than the content) above the grid instead of below it, the
	# same slack-collection idea as stock_align's horizontal ALIGNMENT_END
	# below, one axis over. custom_minimum_size matches cap_scroll's own so
	# the anchor has the full viewport height to push against; a plain
	# ScrollContainer would otherwise size its child to the content alone
	# (NO-135) and there'd be no slack to collect.
	var cap_anchor := VBoxContainer.new()
	cap_anchor.alignment = BoxContainer.ALIGNMENT_END
	cap_anchor.custom_minimum_size = cap_view
	cap_anchor.add_child(captured_grid)
	cap_scroll.add_child(cap_anchor)
	cap_col.add_child(cap_scroll)
	cap_wrap.add_child(cap_col)
	stock_row.add_child(cap_wrap)
	# NO-164: the gutter — a fixed, always-visible divider, unlike the
	# incidental slack NO-135 already routes here. IGNORE: purely decorative,
	# never a target and never in the way of a drag reaching either scroller.
	var gutter := ColorRect.new()
	gutter.color = Color(1, 1, 1, 0.14)
	gutter.custom_minimum_size = Vector2(STOCK_DRAWER_GUTTER, stock_h)
	gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stock_row.add_child(gutter)
	# RIGHT: Stock, the remaining two thirds minus the gutter just added.
	var stock_w: float = vp.x - cap_w - STOCK_DRAWER_GUTTER
	var stock_col := VBoxContainer.new()
	stock_col.custom_minimum_size = Vector2(stock_w, stock_h)
	stock_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER # NO-136
	stock_scroll.scroll_deadzone = DRAWER_SCROLL_DEADZONE
	var stock_view: Vector2 = Vector2(stock_w - STOCK_DRAWER_PAD, stock_h - STOCK_DRAWER_PAD)
	stock_scroll.custom_minimum_size = stock_view
	stock_cols = Tuning.grid_cols(stock_w - STOCK_DRAWER_PAD, STOCK_DRAWER_CELL_SEP) # NO-132
	stock_grid.add_theme_constant_override("separation", STOCK_DRAWER_CELL_SEP)
	# NO-135: a ScrollContainer always places its content flush at its own
	# top-left, so grid_cols()'s floor-remainder (and a short last row) used
	# to strand its slack at the drawer's outer right edge. Captured Stock
	# stays flush left (default placement, against the screen edge — already
	# correct); force Stock's grid to its full row width (same guard as
	# modals.gd's _shop_zone) and right-align that box in a
	# wrapper spanning the scroll viewport, so both sections' slack collects
	# in one gap against the shared Captured/Stock boundary instead. Forcing
	# the VBox's own width still works post-V1: a VBoxContainer's default-FILL
	# children stretch to ITS width regardless of whether that width came
	# from content or this override, which is what lets a short row's own
	# ALIGNMENT_END (below) put its gap on the correct side.
	stock_grid.custom_minimum_size.x = Tuning.grid_row_w(stock_cols, STOCK_DRAWER_CELL_SEP) # NO-135
	var stock_align := HBoxContainer.new()
	stock_align.alignment = BoxContainer.ALIGNMENT_END
	stock_align.custom_minimum_size = Vector2(stock_w - STOCK_DRAWER_PAD, 0)
	stock_align.add_child(stock_grid)
	# NO-208: bottom-anchors the row vertically, same mechanism as cap_anchor
	# above — stock_align already right-aligns stock_grid horizontally, this
	# wraps it once more for the other axis rather than teaching an
	# HBoxContainer two alignments at once.
	var stock_anchor := VBoxContainer.new()
	stock_anchor.alignment = BoxContainer.ALIGNMENT_END
	stock_anchor.custom_minimum_size = stock_view
	stock_anchor.add_child(stock_align)
	stock_scroll.add_child(stock_anchor)
	stock_col.add_child(stock_scroll)
	stock_row.add_child(stock_col)
	# NO-145: stock_panel is a PanelContainer, which stretches its one child
	# (stock_row) to fill it exactly — no chrome at THAT level to hook, unlike
	# the plain-Control inventory panel above. cap_col/stock_col each hold
	# only ONE sized-smaller child of their own (cap_scroll/stock_scroll, by
	# STOCK_DRAWER_PAD), so the leftover slack a VBoxContainer leaves around
	# an unexpanded child is this drawer's own "chrome or edge, not a
	# scrollable cell" — same STOP-claims-its-own-rect mechanism as the
	# inventory panel's gui_input, one level deeper in this drawer's tree.
	cap_col.gui_input.connect(_on_chrome_swipe_input.bind("stock"))
	stock_col.gui_input.connect(_on_chrome_swipe_input.bind("stock"))
	stock_panel.add_child(stock_row)
	drawers["stock"] = stock_panel
	add_child(stock_panel)
	drawer_rest["stock"] = stock_panel.position
	# NO-118: Stock slides in from the TOP — off-screen is its own height
	# above rest, into the Header's y-range. NO-228's z_index (set above) is
	# what actually keeps it tucked BEHIND the Header while sliding through
	# that range — this offset alone only positioned it there.
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
	# NO-152: a VBox so the diagram (when shown) stacks above the text — both
	# still need their OWN MOUSE_FILTER_IGNORE, same reason as tip_panel's
	# (CLAUDE.md: Godot doesn't cascade a parent's IGNORE to its children).
	var tip_box := VBoxContainer.new()
	tip_box.add_theme_constant_override("separation", 6)
	tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_diagram = Control.new()
	tip_diagram.custom_minimum_size = Vector2(TIP_DIA_CELLS, TIP_DIA_CELLS) * TIP_DIA_CELL
	tip_diagram.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tip_diagram.visible = false
	tip_diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_diagram.draw.connect(func() -> void:
		if tip_diagram_id != "":
			PieceDiagram.draw(tip_diagram, g.defs, tip_diagram_id, TIP_DIA_CELLS, TIP_DIA_CELL, tip_diagram_tex))
	tip_box.add_child(tip_diagram)
	tip_label = Label.new()
	tip_label.add_theme_font_size_override("font_size", 13)
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A fixed wrap width rather than a free one: without it a long description is
	# laid out as a single line whose minimum width is the whole string, and the
	# clamp below would then have nothing it could fit on screen. Same failure
	# NO-55 was, arriving through a different control. The real value is set per
	# call in show_tip(), which knows whether a diagram is showing; this is just
	# the pre-first-call default.
	tip_label.custom_minimum_size = Vector2(minf(TIP_W, vp.x - TIP_MARGIN * 2), 0)
	tip_box.add_child(tip_label)
	tip_panel.add_child(tip_box)
	add_child(tip_panel)
	# NO move_to_front here any more. It existed because the drawer opened OVER
	# the button bar and the bar had to be raised above it; design C opens the
	# drawers above the deck instead, so there is nothing to out-rank. Worse, the
	# raise made the bar the LAST child of the deck, silently dropping the
	# drawers row to the bottom of the screen and undoing the row order set in
	# build() - which is exactly how it presented: the tree said one order and
	# the screen showed another.
	_update_band_toggle() # NO-163: the toggle's initial glyph (army_band_open starts true)


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


## NO-128: collapses army_band — the visibility half of what army_band_reopen
## and the mutual-exclusion guards below do. Public: game.gd's SETUP boot
## calls it too (see its own call site for why).
func collapse_army_band() -> void:
	army_band_open = false
	army_band.visible = false
	_update_band_toggle()


## NO-163: the single toggle button's glyph/tooltip, kept in one place so
## build()'s initial state, every press, and refresh()'s King-Abilities
## warning can never say three different things. OPEN never warns even with
## an active King ability — king_ability_button is visible INSIDE the band
## then, so the toggle itself only ever needs to offer "Hide". CLOSED
## borrows the warning glyph so an active ability stays visible while
## collapsed, same as before NO-163 merged the two buttons into this one.
## NO-180: the old ▴/▾ open/closed glyphs are gone — a round "i" info icon
## now stands for the button in both states (it moved to a square footprint
## specifically to read as an icon button, not a directional wedge). The
## warning glyph is kept: it is an alert, not an open/closed indicator, and
## dropping it would lose the one place an active-while-collapsed King
## Ability is visible without opening the band.
func _update_band_toggle() -> void:
	var warn: bool = g != null and not army_band_open \
		and (not g.king_abilities_active.is_empty() or not Kings.bespoke_power(g).is_empty())
	if army_band_open:
		army_band_reopen.text = "ⓘ"
		army_band_reopen.tooltip_text = "Hide"
	else:
		army_band_reopen.text = "⚠" if warn else "ⓘ"
		army_band_reopen.tooltip_text = "King Abilities in force — tap to show" \
			if warn else "Show Army Power"
	# NO-225 gave this button a permanent green font_color override, which the
	# ⚠ glyph (no override of its own) silently inherited — an alert that
	# looks identical to the resting state has lost its job. Set the colour
	# per state here instead, following the same `warn` (glyph is only ever
	# ⚠ when warn is true): the established green otherwise, Tuning.COL_GOLD
	# (this project's attention colour, also score/gold) when warning, for a
	# clear hue shift against the dark green surface.
	army_band_reopen.add_theme_color_override("font_color",
		Tuning.COL_GOLD if warn else Color(0.498, 0.878, 0.541))


## Open one drawer (closing the others) or toggle it shut; "" closes all.
## Visibility only — selection/board consequences live in game.gd's handler.
func set_drawer(which: String) -> void:
	var prev := drawer_open
	drawer_open = "" if drawer_open == which else which
	# NO-128: army_band overlays the exact same rect the Inventory drawer opens
	# into (both anchored to deck_top, extending upward) — Stock opens
	# downward from the Header instead, so it never reaches that rect and
	# needs no guard here. Only one of the two can be on screen at a time.
	if drawer_open == "inventory" and army_band_open:
		collapse_army_band()
	for name in drawers:
		if drawer_open == name and prev != name: # newly opening
			(drawers[name] as Control).visible = true
			_slide_drawer(name, true)
		elif drawer_open != name and prev == name: # newly closing
			_slide_drawer(name, false)
	hide_tip() # NO-59: a description outlives neither its drawer nor its row


## NO-145: swipe-to-CLOSE a drawer via its own chrome — press/release
## tracked here and hooked to each drawer panel's `gui_input` in build()
## rather than routed through game.gd's _unhandled_input: `panel` (and
## Stock's `cap_col`/`stock_col`) are Controls with the default
## MOUSE_FILTER_STOP, so a press over their own unclaimed area (never over
## a ScrollContainer or a cell — those claim their own rect first, same STOP
## mechanism) is exactly what `gui_input` reports and _unhandled_input never
## sees at all (CLAUDE.md: "a visible Control absorbs clicks before
## _unhandled_input ever runs").
##
## `source` is the drawer key ("stock"/"inventory", drawers[key].gui_input).
##
## Hardware round 2 (coordinator diagnosis): this used to ALSO handle the
## OPEN gesture via deck.gui_input ("__deck__"), aimed at the gap between
## nav_row and act_row. NO-128 shrank DECK_ROWS without shrinking those
## rows, squeezing that gap shut, and the press landed on a child before
## deck.gui_input ever saw it. Ruling: every open gesture now starts on an
## empty board tile instead (game.gd's _swipe_open_may_begin) — this
## function only ever closes a drawer that's already open.
var _chrome_swipe_from := Vector2.ZERO
var _chrome_swipe_source := ""

func _on_chrome_swipe_input(event: InputEvent, source: String) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_chrome_swipe_from = event.position
		_chrome_swipe_source = source
		return
	if _chrome_swipe_source != source:
		return
	_chrome_swipe_source = ""
	var dir := Tuning.classify_swipe(event.position - _chrome_swipe_from)
	# Reverse of the OPENING SWIPE (the gesture Max named), not of the
	# panel's own slide direction — Stock opens on a DOWN swipe and slides
	# down, so its reverse is up either way; Inventory opens on an UP swipe
	# but slides in from the LEFT (see build()'s own note), so its
	# reverse-close is DOWN, matching the gesture, not the motion.
	var want := "up" if source == "stock" else "down"
	if dir == want and drawer_open == source:
		set_drawer(source) # same key toggles it closed
		drawer_changed.emit()


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
##
## `diagram_id` (NO-152): a piece id shows PieceDiagram's compact movement
## diagram above the text; "" (every non-piece caller) hides it, same as
## before this slice.
func show_tip(key: String, text: String, anchor: Rect2, diagram_id := "") -> void:
	if key == tip_key: # tapping the same row again closes it
		hide_tip()
		return
	tip_key = key
	tip_label.text = text
	tip_diagram_id = diagram_id
	tip_diagram_tex = g.piece_tex(diagram_id) if diagram_id != "" and g.textures.has(diagram_id) else null
	tip_diagram.visible = diagram_id != ""
	tip_diagram.queue_redraw()
	tip_panel.visible = true
	var vp: Vector2 = g.get_viewport_rect().size
	# NO-152 follow-up (Max: "center name and infos with diagram, slim the
	# sides down to the diagram width"): with a diagram, the label wraps to
	# the diagram's own width instead of the wider TIP_W, so the panel reads
	# as one column instead of the diagram sitting inside a wider box. Every
	# other caller (diagram_id == "") keeps the old TIP_W wrap width.
	var wrap_w := tip_diagram.custom_minimum_size.x if diagram_id != "" else TIP_W
	tip_label.custom_minimum_size = Vector2(minf(wrap_w, vp.x - TIP_MARGIN * 2), 0)
	# The panel's size is not known until the container has sorted its children,
	# and a position computed from a stale size is the whole bug this clamp
	# exists to avoid. reset_size() forces it to its minimum NOW rather than
	# next frame, so the arithmetic below runs on the real box.
	tip_panel.reset_size()
	var box: Vector2 = tip_panel.size
	# NO-152/NO-124: the floating Confirm/Cancel strip is the actionable
	# control in a commit/cancel flow, the tip is only informational — ruling
	# "the Confirm/Cancel buttons win", they must stay fully visible whenever
	# they're on screen. So while either is up, the bottom bound tightens
	# from the viewport edge to the strip's own top edge (multi_confirm_btn
	# sits above multi_cancel_btn, so its position.y is that edge), which
	# both trips the "flip above" check below for a low anchor and keeps the
	# final clamp out of the strip.
	var bottom_limit := vp.y - TIP_MARGIN
	if multi_confirm_btn.visible or multi_cancel_btn.visible:
		bottom_limit = minf(bottom_limit, multi_confirm_btn.position.y - TIP_MARGIN)
	# BESIDE THE ROW MEANS UNDER IT, not to its right, and that is a measurement
	# rather than a preference: an artefact row is ~245px wide in a 480px
	# viewport and the panel is 260, so there is never room to its right, and
	# flipping it to the left landed it exactly on top of the row it describes —
	# covering the thing the player just tapped. Directly under the row, aligned
	# to its left edge, is adjacent and never hides it. Above instead when the
	# row is near the bottom.
	var y := anchor.end.y + 2.0
	if y + box.y > bottom_limit:
		y = anchor.position.y - 2.0 - box.y
	# THE CLAMP IS THE POINT. A popup anchored to a row near an edge of a
	# 480-wide portrait screen is exactly the failure NO-55 was — a control
	# placed without reference to the viewport. maxf before minf so a panel
	# TALLER OR WIDER than the screen still lands at the margin rather than at a
	# negative offset, which is the case a bare clamp() gets wrong.
	tip_panel.position = Vector2(
		maxf(TIP_MARGIN, minf(anchor.position.x, vp.x - box.x - TIP_MARGIN)),
		maxf(TIP_MARGIN, minf(y, bottom_limit - box.y)))


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
##
## NO-138: `on_fire`, when given, replaces the default show_tip with
## whatever the caller wants a long press to do instead — the preview modal,
## for a Stock/Captured cell (_build_stack_button below, `key`/`desc` unused,
## pass "" for both) and, since NO-144, an Items/Artefacts cell too
## (_wire_grid_button's own `on_long_press`, forwarded here as `on_fire`).
func _long_press_input(btn: Button, key: String, desc: String, e: InputEvent, on_fire := Callable()) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if not e.pressed:
			btn.remove_meta("lp_token")
			return
		btn.remove_meta("lp_fired")
		var token := Time.get_ticks_usec()
		btn.set_meta("lp_token", token)
		btn.set_meta("lp_from", e.global_position)
		# NO-156: bind btn's instance id, not btn itself — hud.refresh() frees
		# and rebuilds grid cells constantly, and this timer routinely outlives
		# its cell. Capturing the Node directly means Godot prints "Lambda
		# capture at index 0 was freed. Passed 'null' instead" the instant the
		# signal fires on a freed btn, BEFORE is_instance_valid ever runs — the
		# guard stopped the crash but not the noise. An int is copied by value,
		# so there is nothing left for Godot to null out.
		var btn_id := btn.get_instance_id()
		get_tree().create_timer(LONG_PRESS_MS / 1000.0).timeout.connect(func() -> void:
			var b := instance_from_id(btn_id) as Button
			if is_instance_valid(b) and b.get_meta("lp_token", 0) == token:
				b.remove_meta("lp_token")
				b.set_meta("lp_fired", true)
				if on_fire.is_valid():
					on_fire.call()
				else:
					show_tip(key, desc, b.get_global_rect()))
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
	# NO-175: Gold is the same odometer as Score now (was a plain "%d").
	var gold_digits := str(g.gold)
	gold_zeros_label.text = "0".repeat(maxi(0, SCORE_DIGITS - gold_digits.length()))
	gold_label.text = gold_digits
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
	# NO-175, 3rd pass: turn_wave_row now lives in the CENTRE band, above the
	# Clock (see build()'s comment), so the PAIR has to stay centred as a
	# block as its content changes — not just Wave placed after Turn inside
	# a fixed-position row. Turn's own box is pinned at local x=0 (build()),
	# clamped to centre_w for the King-name-ellipsis case; Wave's x follows
	# Turn's ACTUAL rendered text width (measured, same technique the Clock
	# uses); turn_wave_row's own x is then set so the visible pair (or Turn
	# alone, while Wave is blank) is centred on centre_x — the same
	# mid-band math build() uses for the Clock, recomputed here since it's
	# not cached anywhere.
	var vp: Vector2 = g.get_viewport_rect().size
	var mid_left_edge: float = HEADER_PAD_X + COUNTER_W
	var mid_right_edge: float = vp.x - HEADER_PAD_Y - HEADER_BTN * 2.0 - HEADER_GAP
	var centre_x: float = vp.x / 2.0
	var centre_w: float = (minf(centre_x - mid_left_edge, mid_right_edge - centre_x) - HEADER_GAP) * 2.0
	var counter_font := turn_label.get_theme_default_font()
	var turn_text_w: float = counter_font.get_string_size(
		turn_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, COUNTER_FONT).x
	var turn_visible_w: float = minf(turn_text_w, centre_w)
	wave_label.position.x = turn_visible_w + 6.0 # 6 = the row's own gap
	var wave_text_w: float = counter_font.get_string_size(
		wave_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, COUNTER_FONT).x
	var pair_w: float = turn_visible_w if wave_label.text.is_empty() else wave_label.position.x + wave_text_w
	turn_wave_row.position.x = centre_x - pair_w / 2.0
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
	# Banner pass 2026-09-22: a bespoke King Power (Kings.bespoke_power) counts
	# as one ability in force — it is live all wave and had no persistent
	# indicator before this.
	var abilities_in_force: int = g.king_abilities_active.size() \
		+ (0 if Kings.bespoke_power(g).is_empty() else 1)
	king_ability_button.text = "⚠%d" % abilities_in_force \
		+ ("·off" if g.king_abilities_suppressed else "")
	# NO-128: shown in army_band only while an ability is active — the button
	# lived off-screen (built, never parented) before this; now it's parented
	# but hidden the rest of the time.
	king_ability_button.visible = abilities_in_force > 0
	# NO-128 (coordinator review 2026-09-19): an active King ability must
	# never go invisible just because the band is collapsed — that's exactly
	# the thing a player must not lose track of. The CLOSED glyph carries its
	# own warning while one is active; tapping it still just reopens the band
	# (uniform behaviour) rather than skipping straight to the modal. NO-163:
	# both glyphs (open/closed) now live in _update_band_toggle, so a refresh
	# mid-open never overwrites the "▴ Hide" state with the closed one.
	_update_band_toggle()
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
	var armed_targeting: bool = item_confirm or artefact_confirm
	multi_confirm_btn.visible = armed_targeting
	multi_confirm_btn.text = item_confirm_text
	# NO-137: the backdrop and Cancel appear/disappear together with Confirm —
	# there is nothing for either to do before Confirm itself would show.
	multi_cancel_btn.visible = armed_targeting
	confirm_backdrop.visible = armed_targeting
	_rebuild_stock_drawer()
	_rebuild_items_grid()
	# issue 100: the Power is always on, so it is stated, not offered. The
	# Ability's 1-Action cost rides along here too — that cost is the
	# deliberate contrast with Artefact activation and the Shop (both 0), and
	# it was also tooltip-only until now.
	var kit: Dictionary = Armies.entry(g.next_army)
	# the Power stays a statement; it is passive and there is nothing to press.
	# NO-180: three rows now, not one combined line — Title (army + Power
	# name), Subtitle (what the Power does), Body (the Ability, below).
	army_power_label.text = "%s — %s" % [Armies.display_name(g.next_army), kit.power_name]
	army_power_desc_label.text = str(kit.power_desc)
	# THE ABILITY WEARS ITS OWN STATE (design C). Availability had to be visible
	# without opening a menu, and the three states a player can be in are
	# genuinely different problems: already used this wave, no Action to spend,
	# or ready. Saying which one it is beats greying the button out and leaving
	# them to guess.
	army_ability_button.text = "★ %s" % kit.ability_name
	# NO-32: the drawer chip was the only place the Ability's DESCRIPTION lived
	# (its tooltip). The chip is gone, so the deck button inherits that tooltip
	# verbatim — the tooltip is the one place the cost lives now (NO-163
	# dropped "1 Action" from the button's own text; ready needs no caveat).
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
		army_ability_button.disabled = false
		army_ability_button.self_modulate = Color(1.3, 1.16, 0.72)
	# NO-115: a reminder of what pressing this DOES, since the tooltip above
	# is unreachable on a touch screen mid-run. NO-180: Body row — the FULL
	# name + description, wrapped (autowrap_mode is already word-smart), not
	# Armies.ability_hint()'s 45-char truncation. The band was mostly empty
	# while the truncated hint left the rest of the description unreadable;
	# ARMY_BAND_H grew to budget the extra wrapped lines this can now take.
	army_ability_hint.text = "%s: %s" % [kit.ability_name, kit.ability_desc]
	_rebuild_artefacts_grid()
	# NO-85: the drawer's height is a flat choice (INV_DRAWER_H), not a
	# consequence of what it holds — it must not resize as Items/Artefacts
	# come and go (story 46). NO-134: the panel's own custom_minimum_size.y
	# also carries the deck-covering background (see build()'s drawer_specs
	# loop), so the flat constant compared here is INV_DRAWER_H + deck_h.
	var inv_panel: Control = drawers["inventory"]
	var inv_h := INV_DRAWER_H
	var full_h := inv_h + deck_h
	if inv_panel.custom_minimum_size.y != full_h:
		# NO-118: build() always sets custom_minimum_size.y to this same
		# value, so this branch is unreachable — the position write below can
		# never stale drawer_rest["inventory"].
		var inv_w: float = inv_panel.custom_minimum_size.x
		inv_panel.custom_minimum_size = Vector2(inv_w, full_h)
		inv_panel.position = Vector2(inv_panel.position.x,
			g.get_viewport_rect().size.y - deck_h - inv_h)


## issue 97: can the player currently pay for this entry's action? Drives the
## price colour only — the real refusals stay where they are (Economy/Shop).
func _pool_affordable(cap: bool, entry: Variant) -> bool:
	return g.gold >= (Shop.convert_price(g, entry) if cap else Economy.deploy_cost(g))


## NO-84: every stack button across both grids, Stock first then Captured —
## the flat order _rebuild_stock_drawer used to hold as one strip. Used
## wherever code needs to sweep "every stack on screen" rather than one side.
## V1: stock_grid/captured_grid are now a VBoxContainer of per-row
## HBoxContainers, not a flat GridContainer of buttons — one level to
## flatten through. Every row holds only Buttons (no placeholders, no
## further nesting), so this keeps "pool_buttons() is buttons-only"
## (test_game_clicks.gd's own comment on game.pool_box) true.
func pool_buttons() -> Array:
	var out := []
	for row in stock_grid.get_children():
		out.append_array(row.get_children())
	for row in captured_grid.get_children():
		out.append_array(row.get_children())
	return out


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
	# NO-182: Stock now reads MOST RECENTLY ACQUIRED FIRST too, matching
	# Captured below ("the bottom becomes the top") — scan g.stock in reverse
	# so a stack's first appearance (its Dictionary insertion order, which
	# GDScript preserves) is the newest copy, not the oldest.
	#
	# CAPTURED NEVER STACKS (user ruling 2026-09-10): one row per captured
	# piece, MOST RECENT CAPTURE FIRST. g.captured is append-ordered, so newest
	# first is simply its reverse. A stack made sense while a captured pair
	# could merge; with convert and sell the only exits, every action is on ONE
	# piece, so a row is one piece and the count badge has nothing to count.
	var out := []
	var counts := {}
	for i in range(g.stock.size() - 1, -1, -1):
		var e: Variant = g.stock[i]
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
## Activate chips) split. Tap uses (arms/activates), long-press opens the
## preview modal (NO-144: icon/name/description and, when sellable, Sell —
## previously the description-only show_tip popup), for every entry including
## greyed ones (stories 51-55) — one mechanism, reusing NO-72's
## _long_press_input for both kinds, instead of passive rows having their own
## tap-to-describe path (NO-59's _tip_input — retired here, it had no other
## caller).
func _rebuild_artefacts_grid() -> void:
	for c in artefacts_grid.get_children():
		c.queue_free()
	var counts := {}
	for t in g.artefacts: # stack copies: one entry per kind
		counts[t.key] = counts.get(t.key, 0) + 1
	var seen := {}
	# NO-202: most recently acquired kind first, matching _stacks()'s Stock
	# drawer — g.artefacts is append-ordered, so scan it in reverse rather
	# than reversing the built grid (which would also flip the empty-slot
	# padding below). Cells key off t.key, not an array index, so display
	# order never disagrees with which artefact a tap resolves to.
	for i in range(g.artefacts.size() - 1, -1, -1):
		var t: Variant = g.artefacts[i]
		if seen.has(t.key):
			continue
		seen[t.key] = true
		artefacts_grid.add_child(_build_artefact_cell(t.key, counts[t.key]))
	# NO-144: a held Artefact's long press opens the preview modal now, never
	# show_tip (_build_artefact_cell passes on_long_press) — so tip_key can
	# no longer carry an "artefact:" popup for this grid's own tip-cleanup to
	# scope to. The NO-120/121 hide_tip() guards this used to need are gone
	# with it.
	# NO-165: empty slots signify the CAP itself (ArtefactHooks.cap), not
	# "one more grid cell" — a stacked cell already holds several copies
	# (counts[key] above) behind its ×N badge, so the capacity actually spent
	# is g.artefacts.size() (one per COPY, per that cap's own doc comment),
	# never seen.size() (one per KIND). This also replaces the old "no
	# artefacts yet" text for the zero-held case: a row of empty slots says
	# the same thing and additionally states how many.
	for i in ArtefactHooks.cap(g) - g.artefacts.size():
		artefacts_grid.add_child(_empty_slot())


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
		# NO-209: was 12 with no alignment override — a Label's default
		# alignment is top-left, so the glyph sat at the LEFT edge of the
		# offset box below rather than centred in it, and the box's zero
		# bottom/right offsets left it flush with the button's own edge,
		# straddling the card's rounded corner. Centred + a 4px margin off
		# both edges puts it cleanly on the icon; 14 reads better at this size.
		marker.add_theme_font_size_override("font_size", 14)
		marker.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
		marker.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
		marker.add_theme_constant_override("outline_size", 4)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		marker.offset_left = -38
		marker.offset_top = -22
		marker.offset_right = -4
		marker.offset_bottom = -4
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
	# The "artefact:" + key prefix is a leftover of NO-120's own tip-cleanup
	# scoping in _rebuild_artefacts_grid, which NO-144 removed (an Artefact
	# long press opens the preview modal now, never show_tip, so tip_key can
	# no longer carry one) — kept here only as the lp_key _long_press_input
	# still takes, unused since on_long_press below always overrides it.
	_wire_grid_button(btn, true, "artefact:" + key, desc, func() -> void:
		artefact_activate_pressed.emit(key),
		func() -> void: artefact_preview_requested.emit(key)) # NO-144
	btn.set_meta("key", key) # lookup for probes/tests
	btn.add_child(_build_sell_badge("artefact", entry)) # NO-223
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
##
## NO-144: `on_long_press`, when given, replaces the default show_tip with
## the preview modal (same `on_fire` override _build_stack_button's long
## press already uses) — Items and Artefacts get their own Sell button there
## now, same as Stock.
func _wire_grid_button(btn: Button, has_icon: bool, lp_key: String, lp_desc: String,
		on_tap: Callable, on_long_press := Callable()) -> void:
	if has_icon:
		btn.expand_icon = true
		btn.custom_minimum_size = Vector2(Tuning.OFFBOARD_ICON, Tuning.OFFBOARD_ICON)
	btn.pressed.connect(func() -> void:
		if btn.has_meta("lp_fired"): # NO-72: this release ended a long press
			btn.remove_meta("lp_fired")
			return
		on_tap.call())
	btn.gui_input.connect(func(e: InputEvent) -> void:
		_long_press_input(btn, lp_key, lp_desc, e, on_long_press))
	btn.mouse_filter = Control.MOUSE_FILTER_PASS # NO-45: drag-scroll the drawer


## NO-223 (2026-09-22 ruling: "badges are too small... they should just be
## information, whatever they do should be accessed with a long press") —
## the Inventory drawer's own Sell badge, top-left corner pill on an
## Item/Artefact cell, priced and greyed exactly like the Stock/Captured
## grid's own ⇄ Convert badge (_build_stack_button above). INFORMATION ONLY:
## it takes no input of its own (MOUSE_FILTER_IGNORE) — Sell itself lives in
## the long-press preview's menu (modals.gd show_preview, wired through
## game.gd's _confirm_sell). A leaf Button has no descendants to cascade the
## filter to (contrast _set_drawer_clickable above, which restores a whole
## subtree's prior filters) — this one control is the whole story.
func _build_sell_badge(kind: String, entry: Variant) -> Button:
	var payout: int = Shop.sell_payout(g, kind, entry)
	var sell := Button.new()
	sell.text = "$%d" % payout
	sell.add_theme_font_size_override("font_size", 11)
	sell.add_theme_color_override("font_color", Color(1, 0.9, 0.85))
	sell.disabled = not Shop.can_sell(g, kind, entry)
	sell.mouse_filter = Control.MOUSE_FILTER_IGNORE # info only — long-press to sell
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.75, 0.25, 0.2) # sell = red-ish, distinct from Convert's blue
	pill.set_corner_radius_all(9)
	for style in ["normal", "hover", "pressed", "disabled"]:
		sell.add_theme_stylebox_override(style, pill)
	sell.tooltip_text = "Sell for $%d — long-press to sell" % payout
	sell.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sell.offset_left = 2
	sell.offset_right = 30
	sell.offset_top = 2
	sell.offset_bottom = 18
	return sell


func _rebuild_items_grid() -> void:
	for c in items_grid.get_children():
		c.queue_free()
	# NO-202: most recently acquired first, matching _stacks()'s Stock
	# drawer — g.items is append-ordered, so scan it in reverse. `i` stays
	# the real g.items index throughout (item_pressed.emit(i), the
	# g.item_active comparison, the "item:%d" lp_key), only the loop's
	# visitation order changes, so no click handler or save/load index is
	# affected.
	for i in range(g.items.size() - 1, -1, -1):
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
			item_pressed.emit(i),
			func() -> void: item_preview_requested.emit(i)) # NO-144
		btn.set_meta("key", g.items[i].key) # NO-119: no name text left to find
			# this cell by (probes/tests) — same convention _build_artefact_cell
			# already uses
		btn.add_child(_build_sell_badge("item", g.items[i])) # NO-223
		items_grid.add_child(btn)
	# NO-165: the remaining room, signified — ItemLogic.cap is the real bound
	# (base 3, +3 per held Area 51 Parking Permit), so this is never a
	# made-up number.
	for i in ItemLogic.cap(g) - g.items.size():
		items_grid.add_child(_empty_slot())


## NO-84: Stock and Captured Stock are two independent grids (stories 31-44),
## Captured on the left, Stock on the right — replaces the single strip issue
## 96 gave a labelled divider inside. The two pools still obey different
## rules (Captured can convert but never deploy or merge, issue 60/2026-09-10)
## but that is now which GRID an entry is in, not a tint plus a tooltip a
## phone can't show anyway.
##
## NO-237: stack buttons are KEPT across rebuilds (_stack_btns, one per
## stack) instead of freed and rebuilt, so a stack that only moved slides to
## its new cell, a new one pops in, and a gone one fades out (_animate_stacks).
func _rebuild_stock_drawer() -> void:
	var animate: bool = not g.autoplay and g.animations_on \
			and DisplayServer.get_name() != "headless" \
			and drawers.has("stock") and (drawers["stock"] as Control).is_visible_in_tree()
	var stacks := _stacks()
	var keys := _stack_keys(stacks)
	var live := {} # key -> Button, this rebuild's
	var old_pos := {} # kept Button -> position before this rebuild (_stack_origin-relative)
	var fresh: Array = []
	var cap_count := 0
	var stock_children: Array = []
	var cap_children: Array = []
	for i in stacks.size():
		var st: Dictionary = stacks[i]
		var btn: Button = _stack_btns.get(keys[i])
		if btn == null:
			btn = _build_stack_button(st)
			fresh.append(btn)
		else:
			if animate and btn.is_inside_tree():
				old_pos[btn] = btn.global_position - _stack_origin(btn)
			_build_stack_button(st, btn)
		live[keys[i]] = btn
		if st.cap:
			cap_count += 1
			cap_children.append(btn)
		else:
			stock_children.append(btn)
	for k in _stack_btns:
		if not live.has(k):
			_drop_stack_button(_stack_btns[k], animate)
	_stack_btns = live
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
		stock_children.append(slot)
	_fill_rows_bottom_right(stock_grid, stock_children, stock_cols)
	_fill_rows_bottom_right(captured_grid, cap_children, cap_cols)
	_scroll_stock_to_bottom() # NO-208
	if animate and not (old_pos.is_empty() and fresh.is_empty()):
		_animate_stacks(old_pos, fresh)


## NO-237: one identity per stack. A Stock stack is its whole entry (ADR-0002
## — _stacks() groups by it); a Captured row is one piece, and two captured
## copies of one entry are told apart by how many older copies precede them,
## so a fresh capture of a piece already held gets the NEW key (numbering from
## the oldest) and the rows already on screen keep theirs.
func _stack_keys(stacks: Array) -> Array:
	var keys := []
	keys.resize(stacks.size())
	var seen := {}
	for i in range(stacks.size() - 1, -1, -1): # captured rows are newest-first
		var st: Dictionary = stacks[i]
		var k: String = ("c|" if st.cap else "s|") + var_to_str(st.entry)
		if st.cap:
			var n: int = seen.get(k, 0)
			seen[k] = n + 1
			k += "|%d" % n
		keys[i] = k
	return keys


## NO-237: a stack that is gone. Detached from its row at once, so no
## pool_buttons()/stack_button_at lookup ever finds it again; when animating,
## it fades out where it stood (reparented onto this layer, input-dead) and
## then frees.
func _drop_stack_button(btn: Button, animate: bool) -> void:
	var shown: bool = animate and btn.is_inside_tree()
	var at: Vector2 = btn.global_position if shown else Vector2.ZERO
	if btn.get_parent():
		btn.get_parent().remove_child(btn)
	if not shown:
		btn.queue_free()
		return
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in btn.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(btn)
	btn.global_position = at
	var tw := create_tween()
	tw.tween_property(btn, "modulate:a", 0.0, STACK_FADE_OUT_S)
	tw.tween_callback(btn.queue_free)


## NO-237: where a stack's scroll area is. Positions for the slide are taken
## relative to it, not raw global ones: the drawer itself may be mid-slide
## (NO-118) between the rebuild and the frame, and that motion is not the
## stack's.
func _stack_origin(btn: Button) -> Vector2:
	return (cap_scroll if btn.get_meta("cap") else stock_scroll).global_position


## NO-237: FLIP. Runs just before the frame draws — after the deferred
## container sort has placed every row, before anything is shown — so a kept
## button is put back at its old spot and tweened to its new one, and a new
## one scales/fades in, with no frame of the final layout showing first.
## Only the latest rebuild's pass runs (`_stack_anim_gen`). Nothing here
## touches input: a sliding button is clickable wherever it is drawn.
## The tweens move `position` inside a container, so any re-sort mid-tween
## (the next rebuild) snaps it home — that rebuild then starts its own slide
## from wherever the button was.
func _animate_stacks(old_pos: Dictionary, fresh: Array) -> void:
	_stack_anim_gen += 1
	var gen := _stack_anim_gen
	await RenderingServer.frame_pre_draw
	if gen != _stack_anim_gen:
		return
	for btn in old_pos:
		if not is_instance_valid(btn) or not btn.is_inside_tree():
			continue
		if btn.has_meta("flip_tw"):
			(btn.get_meta("flip_tw") as Tween).kill()
			btn.remove_meta("flip_tw")
		var home: Vector2 = btn.position
		var from: Vector2 = old_pos[btn] + _stack_origin(btn)
		if from.distance_to(btn.global_position) < 0.5:
			continue
		btn.global_position = from
		var tw := create_tween().bind_node(btn)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "position", home, STACK_SLIDE_S)
		btn.set_meta("flip_tw", tw)
	for btn in fresh:
		if not is_instance_valid(btn) or not btn.is_inside_tree():
			continue
		# scale/self_modulate, not modulate: modulate carries the armed/merge
		# tint (and game.gd's drag-start merge highlight writes it directly).
		# 0.4, not 0: a zero scale is a singular transform to GUI picking.
		btn.pivot_offset = btn.size / 2.0
		btn.scale = Vector2(0.4, 0.4)
		btn.self_modulate.a = 0.0
		var tw := create_tween().bind_node(btn).set_parallel()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, STACK_POP_IN_S)
		tw.tween_property(btn, "self_modulate:a", 1.0, STACK_POP_IN_S)


## V1 (Max, 2026-09-21 correction): Max rejected an earlier padded-
## GridContainer version of this ("Padding with empty cells is definitely not
## what we want") in favour of a true reverse flow: "a reversed list where it
## start from the bottom with first items stacking right to left, and then
## the next items pile on the row above, and then scrolling that list up." A
## single GridContainer can't express that — it always fills from the
## top-left, so a short row lands bottom-right, the opposite corner from what
## he wants. `grid` (stock_grid/captured_grid) is instead a VBoxContainer of
## per-row HBoxContainers built fresh here.
##
## Indexing: `children[0]` is _stacks()'s newest entry. With `rows = ceil(n /
## cols)`, row_idx 0 (built LAST, so it ends up at the BOTTOM of the
## VBoxContainer) holds children[0 : cols]; row_idx 1 holds children[cols :
## 2*cols] and sits above it; and so on up to the last row_idx built FIRST
## (top). Any incomplete row is therefore always the last one filled —
## row_idx = rows-1, the TOPMOST — never row 0, so there is nothing to pad:
## the short row simply has fewer buttons, and each row's own
## ALIGNMENT_END right-aligns its buttons, leaving that row's gap on the
## LEFT for free (a VBoxContainer stretches every default-FILL child, i.e.
## every row, to its own width, which a full row already establishes).
## Within a row, the lowest index is added LAST so it lands rightmost
## (children[0] itself, in row 0, ends up in the true bottom-right cell).
##
## Worked example, 6 children / 4 cols (the case that reveals a padding bug,
## carried over from the earlier version since it's still the case worth
## checking): rows=2. row_idx 1 (top, built first) = children[4:6] = [4, 5],
## added in reverse (5 then 4) so row reads left-to-right as [5, 4], right-
## aligned in a 4-wide row -> 2 blank cells on its LEFT. row_idx 0 (bottom,
## built last) = children[0:4] = [0,1,2,3], added in reverse (3,2,1,0) so the
## row reads [3, 2, 1, 0] — 0 bottom-right, 1 to its left, matching Max's
## description exactly, with no spacer of any kind.
##
## NO-237: rows are REUSED, not rebuilt — extra rows come off the top, missing
## ones are added on top — and a child is only reparented when its row
## changes, so a kept button stays in the tree (and keeps any press in
## progress) whenever it can. Anything left in a row that `children` no
## longer lists (the last rebuild's "+" slot) is removed and freed; a gone
## stack's button was already detached by _drop_stack_button.
func _fill_rows_bottom_right(grid: VBoxContainer, children: Array, cols: int) -> void:
	cols = maxi(cols, 1)
	var rows := ceili(float(children.size()) / float(cols))
	while grid.get_child_count() > rows:
		var extra := grid.get_child(0)
		for c in extra.get_children(): # kept buttons are re-placed below
			extra.remove_child(c)
			if not children.has(c):
				c.queue_free()
		grid.remove_child(extra)
		extra.queue_free()
	while grid.get_child_count() < rows:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END # short row's gap lands on the left
		row.add_theme_constant_override("separation", STOCK_DRAWER_CELL_SEP)
		grid.add_child(row)
		grid.move_child(row, 0) # new rows go on top; row 0 stays the bottom child
	for row_idx in rows:
		var row: HBoxContainer = grid.get_child(rows - 1 - row_idx) # row 0 is the bottom child
		var lo := row_idx * cols
		var hi := mini(lo + cols, children.size())
		var at := 0
		for i in range(hi - 1, lo - 1, -1): # descending: lowest index added last = rightmost
			var c: Control = children[i]
			if c.get_parent() != row:
				if c.get_parent():
					c.get_parent().remove_child(c)
				row.add_child(c)
			row.move_child(c, at)
			at += 1
	for row in grid.get_children():
		for c in row.get_children():
			if not children.has(c):
				row.remove_child(c)
				c.queue_free()
		row.queue_sort() # re-lay kept buttons even if nothing in this row moved (NO-237 FLIP)


## NO-208: default scroll position is the bottom, matching cap_anchor/
## stock_anchor's bottom-anchoring above. Fire-and-forget (not awaited by the
## caller) — _rebuild_stock_drawer's own synchronous work (grid contents,
## captured_hint) is already done by the time this runs. Awaits a frame first:
## CLAUDE.md — a freshly rebuilt control's size isn't final until the next
## idle frame, so reading "the max scroll" (or here, setting scroll_vertical
## before the grid's new row count has been laid out) would land on the STALE
## range. ScrollContainer clamps scroll_vertical to whatever range is valid at
## the time it's set, so a large constant is as good as reading the true max.
func _scroll_stock_to_bottom() -> void:
	await get_tree().process_frame
	stock_scroll.scroll_vertical = 1 << 30
	cap_scroll.scroll_vertical = 1 << 30


## One stack button (Stock or Captured entry) — everything from the icon down
## to its drag/tap wiring. Split out of _rebuild_stock_drawer so that
## function only decides which grid an entry lands in.
##
## NO-237: pass `btn` to re-dress a button that already shows this stack —
## _rebuild_stock_drawer keeps one button per stack so it can slide instead
## of being rebuilt. What never changes for a stack (icon, id/cap, the input
## wiring) is set once, on creation; everything that can change (count,
## entry, tint, badges, prices) is redone on every call. The handlers read
## entry/count from meta, not from `st`, so a kept button never emits a stale
## count.
func _build_stack_button(st: Dictionary, btn: Button = null) -> Button:
	var id: String = st.id
	var cap: bool = st.cap
	if btn == null:
		btn = _new_stack_button(id, cap)
	else:
		for c in btn.get_children(): # last dressing's badges
			btn.remove_child(c)
			c.queue_free()
	btn.set_meta("entry", st.entry)
	btn.set_meta("count", st.count)
	# NO-164: see _new_stack_button — the King's mono svg carries no side colour.
	btn.modulate = g.COL_SIDE_ENEMY if cap and g.textures.has(id) and g.mono_art.has(id) \
			else Color.WHITE
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
		promote.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0)) # NO-151: NOT COL_GOLD — green on the blue pill is ~1.6:1
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
		# NO-223 (2026-09-22 ruling, extended from the new Sell badge to this
		# pre-existing one — "badges are too small... whatever they do should
		# be accessed with a long press"): INFORMATION ONLY now — the price,
		# greyed when not affordable, but no input of its own
		# (MOUSE_FILTER_IGNORE; no descendants to cascade it to, same as the
		# Sell badge). Convert itself moved into the long-press preview's own
		# menu (modals.gd show_preview, wired through modals.convert_pressed
		# in game.gd) — a BEHAVIOUR CHANGE to already-shipped UI, easy to
		# revert to a plain `convert.pressed.connect(...)` if this turns out
		# to be the wrong call.
		var convert := Button.new()
		convert.text = "⇄$%d" % Shop.convert_price(g, st.entry)
		convert.add_theme_font_size_override("font_size", 11)
		convert.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0)) # NO-151: NOT COL_GOLD — green on the blue pill is ~1.6:1
		convert.disabled = not Shop.can_convert(g, st.entry)
		convert.mouse_filter = Control.MOUSE_FILTER_IGNORE # info only — long-press to convert
		var pill := StyleBoxFlat.new()
		pill.bg_color = Color(0.3, 0.6, 1.0) # player blue, same as ▲
		pill.set_corner_radius_all(9)
		for style in ["normal", "hover", "pressed", "disabled"]:
			convert.add_theme_stylebox_override(style, pill)
		convert.tooltip_text = "Convert to Stock (deployable) — long-press to convert"
		convert.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		convert.offset_left = -26
		convert.offset_right = 4
		convert.offset_top = -9
		convert.offset_bottom = 9
		btn.add_child(convert)
	btn.tooltip_text = g.defs[id].name + (" (captured)" if cap else "")
	if armed:
		btn.modulate = Color(0.55, 0.95, 1.5) # armed: placement / merge origin
	elif not cap and g.merge_highlights.has(id):
		btn.modulate = Color(0.8, 1.1, 1.4) # completes a merge — tap or drop
	# NO-164: the old "captured stock: warm tint" wash is gone — the enemy
	# (dark) sprite set above IS the distinguishing signal now, so a captured
	# entry's modulate stays at whatever the icon block set (default WHITE,
	# or COL_SIDE_ENEMY for the King's untinted mono svg) unless armed/merge
	# already claimed it above.
	if st.entry is Dictionary: # carries state: mark the stack (ADR-0002)
		var mark := Label.new()
		mark.text = "◆"
		mark.add_theme_font_size_override("font_size", 11)
		mark.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		mark.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		mark.offset_left = -14
		mark.offset_top = -14
		btn.add_child(mark)
	return btn


## NO-237: the parts of a stack button that never change for its stack —
## created once, then kept across rebuilds (see _build_stack_button).
func _new_stack_button(id: String, cap: bool) -> Button:
	var btn := Button.new()
	if g.textures.has(id): # piece icon instead of glyph text (round 3)
		# NO-164: a Captured entry was taken FROM the enemy — its enemy (dark)
		# token says so without a label. A painted light/dark pair gets this
		# for free from piece_tex's own owner param; the King's shared
		# monochrome svg (mono_art) carries no side colour of its own — that
		# only happens at board-draw time (game.gd's _draw_piece), which this
		# Button icon bypasses entirely — so it's tinted the same
		# COL_SIDE_ENEMY the board itself uses.
		btn.icon = g.piece_tex(id, Rules.ENEMY if cap else Rules.PLAYER)
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
	btn.set_meta("id", id) # drop-target lookup for drag merges
	btn.set_meta("cap", cap)
	# NO-138: long-press opens the same preview modal a double-tap does
	# (game.gd's _show_preview, via stack_preview_requested — this cell has a
	# piece id, not a description to show, so on_fire bypasses show_tip
	# entirely: NO-120's tip popup is retired for pieces, board and Stock/
	# Captured alike).
	btn.pressed.connect(func() -> void:
		if btn.has_meta("lp_fired"): # NO-72's swallow, same as every other long-press cell
			btn.remove_meta("lp_fired")
			return
		stack_pressed.emit(btn.get_meta("entry"), cap, btn.get_meta("count")))
	btn.gui_input.connect(func(e: InputEvent) -> void:
		_long_press_input(btn, "", "", e, func() -> void:
			stack_preview_requested.emit(id, cap, btn.get_meta("entry"))))
	btn.button_down.connect(func() -> void: stack_drag_started.emit(btn.get_meta("entry"), cap))
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
