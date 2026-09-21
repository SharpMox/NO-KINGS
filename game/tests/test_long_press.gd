extends SceneTree
## NO-72: a LONG PRESS on an item or an Activate chip shows its description,
## and does not fire the control. Needs a window AND touch emulation — run it
## through run_all.sh, or by hand with the override test_touch_scroll.gd
## documents. Its own file rather than a section of test_touch_scroll.gd,
## because that suite's taps raced the real cursor until NO-71, and a check that
## HOLDS for half a second is far more exposed to the same thing.
##
## NO-138: a long press on a PIECE (board, Stock, Captured) opens the preview
## modal instead — game.preview_open / game.preview_panel, not hud's tip
## popup. NO-144 finished the same swap for Items and Artefacts below, which
## NO-138 had missed (no piece to preview was never the reason they were
## left out — Max's own rule was "one rule: long press opens the modal with
## the preview, not the tip popup, and not only in some places"). Do not
## resurrect the old tip_panel/tip_label assertions this file used to carry
## for Items/Artefacts on the grounds that they used to pass.
##
## hud's show_tip/tip_panel/tip_label are NOT dead, though — grid-cell long
## press (this file's only concern) is the one thing NO-144 moved off them.
## They're still the live popup for a board tile's description while
## targeting an Item or Artefact (game.gd's _item_target_tip/
## _artefact_target_click), which this file does not cover.

const Settings := preload("res://scripts/settings.gd")
const Account := preload("res://scripts/account.gd")
const GameScript := preload("res://scripts/game.gd")

## Longer than Android's long-press timeout (ViewConfiguration, 500 ms), which
## is what the HUD's threshold is taken from. A literal rather than the HUD
## constant, so this cannot pass because the two drifted together.
const HOLD_S := 0.65

## NO-192: the settle wait is bounded by WALL TIME, not a frame count. A frame
## budget measures the host, and this assertion fails on Aux and passes on Main
## with no recorded reason — PANEL_SLIDE_S is 0.18s, so 60 frames already looked
## ample, which is exactly why the cause is still unknown. 3s is ~16x the slide:
## a failure at this cap is a broken tween, not a slow machine. The detail string
## on the check is the point of this change — the old assertion printed nothing,
## so every failure had to be re-theorised from scratch.
const SETTLE_CAP_MS := 3000
## A tween's final frame can land a hair off its target; half a pixel cannot
## change which control a click lands on, and exact Vector2 equality was the
## other candidate cause of the failures above.
const SETTLE_EPS_PX := 0.5

var fails := 0
var recording := false
var foreign_motion := 0
## [DEBUG-lp-flake] which part of a long press is in flight: "hold" or "release".
## Read only by _instrument's log line; it changes nothing the checks see.
var hold_phase := ""


## NO-113: `detail` is printed alongside a failing label — see
## test_game_clicks.gd's copy for the rationale. Optional, so every existing
## two-argument call site is unchanged.
func check(cond: bool, label: String, detail := "") -> bool:
	if not cond:
		push_error("FAIL: " + label + (" -- " + detail if detail != "" else ""))
		fails += 1
	else:
		print("ok: " + label)
	return cond


func _mouse(pressed: bool, at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	root.push_input(ev)


## Release where the finger landed, the motion back to back with the release so
## no real-cursor event can land between them (NO-71).
func _release_at(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(mm)
	_mouse(false, at)


## Press, hold past the threshold, release. Returns false if the REAL desktop
## cursor moved during the hold: this probe pushes no motion while holding, so
## any motion seen then is foreign, and it may legitimately have cancelled the
## long press. That attempt is not a result — the caller retries.
func _long_press(at: Vector2) -> bool:
	foreign_motion = 0
	recording = true
	_mouse(true, at)
	hold_phase = "hold" # [DEBUG-lp-flake]
	await create_timer(HOLD_S).timeout
	recording = false
	hold_phase = "release" # [DEBUG-lp-flake]
	_release_at(at)
	await process_frame
	hold_phase = "" # [DEBUG-lp-flake]
	return foreign_motion == 0


## NO-118: hud.gd's _slide_drawer takes Tuning.PANEL_SLIDE_S of real time to
## carry a drawer from drawer_hidden[key] to drawer_rest[key]. A long press
## aimed at a control inside the drawer, sent before that settles, reads a
## rect that is still mid-slide. Poll process_frame, bounded, until the
## drawer's own Control sits at its cached rest position; the bound means a
## broken tween fails loudly here instead of every downstream check silently
## missing.
func _await_drawer_settled(game: Node, key: String) -> void:
	var panel: Control = game.hud.drawers[key]
	var rest: Vector2 = game.hud.drawer_rest[key]
	var t0 := Time.get_ticks_msec()
	var polls := 0
	while panel.position.distance_to(rest) > SETTLE_EPS_PX \
			and Time.get_ticks_msec() - t0 < SETTLE_CAP_MS:
		await process_frame
		polls += 1
	check(panel.position.distance_to(rest) <= SETTLE_EPS_PX,
		"the %s drawer's slide settled before use" % key,
		"pos=%s rest=%s polls=%d elapsed=%dms" % [
			panel.position, rest, polls, Time.get_ticks_msec() - t0])


func _boot_game() -> Node:
	GameScript.next_config = {
		"board": [["queen", 0, 2, 1], ["pawn", 0, 3, 1], ["pawn", 1, 2, 6]],
		"items": ["sniper", "blitz"],
		# NO-85: one activatable (moscovium) and one passive (tinfoil-hat), so
		# the same boot covers tap-vs-long-press on both kinds of Artefacts
		# grid cell, alongside the Items grid above.
		"artefacts": ["moscovium-glow-stick", "tinfoil-hat"],
		"stock": ["pawn"], "wave": 1, "gold": 200, "seed": 1}
	GameScript.is_scenario = true
	var game: Node = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game._set_drawer("inventory")
	await process_frame
	await process_frame
	await _await_drawer_settled(game, "inventory") # NO-118
	_instrument(game) # [DEBUG-lp-flake]
	return game


## [DEBUG-lp-flake] LOG ONLY. The intermittent "Parent node is busy setting up
## children" failure (full run_all only, never reproduced in isolation) showed the
## item's pressed firing inside a long press and re-entering through
## _set_drawer(""). This records, for any pressed during a hold or its release,
## the hovered control, the button mask and the caller stack, so the next natural
## occurrence carries its own diagnosis. Connected after the HUD's handler, so it
## runs second and alters nothing. Remove with the flake's fix.
func _instrument(game: Node) -> void:
	for grid in [game.hud.items_grid, game.hud.artefacts_grid]:
		for c in grid.get_children():
			if c is Button:
				var btn: Button = c
				btn.pressed.connect(func() -> void:
					if hold_phase == "":
						return
					print("[DEBUG-lp-flake] pressed during %s on '%s': hovered=%s mask=%d focus=%s" % [
						hold_phase, btn.text, root.gui_get_hovered_control(),
						Input.get_mouse_button_mask(), root.gui_get_focus_owner()])
					for f in get_stack():
						print("[DEBUG-lp-flake]   at %s:%d %s" % [f.source, f.line, f.function]))


## NO-202: items_grid displays most-recently-acquired first (hud.gd's
## _rebuild_items_grid), so a cell's grid POSITION no longer matches its
## g.items ARRAY index — this used to return game.items[i]'s position-i
## cell, which after NO-202 is a different item's button whenever more than
## one item is held. Cells carry their key as meta (same convention
## _artefact_cell below already uses), so look up by that instead — order-
## independent, same as the product's own click handlers (item_pressed.emit
## closes over the real index, never the display position).
func _item_button(game: Node, key: String) -> Button:
	for c in game.hud.items_grid.get_children():
		if c is Button and c.get_meta("key", "") == key:
			return c
	return null


## NO-85: cells carry their key as meta (hud.gd's _build_artefact_cell), so
## lookup does not depend on grid order.
func _artefact_cell(game: Node, key: String) -> Button:
	for c in game.hud.artefacts_grid.get_children():
		if c is Button and c.get_meta("key", "") == key:
			return c
	return null


## NO-120: Stock/Captured cells carry id + cap as meta (hud.gd's
## _build_stack_button), so lookup does not depend on grid order either.
## Root cause of the "short tap on a Stock cell still arms it" flake
## (2026-09-18): called right after _set_drawer("stock"), which just
## triggered _rebuild_stock_drawer — the OLD button is still in
## get_children() (queue_free is deferred, not immediate) and sorts before
## the new one Godot just add_child()'d. Same trap test_game_clicks.gd's
## _pool_rows already documents ("a row held across one is a freed node")
## and already guards against the same way.
## V1: grid's direct children are now per-row HBoxContainers, not buttons —
## one level to recurse through. _rebuild_stock_drawer queue_free()s the OLD
## ROW (not its buttons individually), so the same stale-frame guard now
## checks the row, not the button inside it.
func _stock_button(game: Node, id: String, cap: bool) -> Button:
	var grid: Control = game.hud.captured_grid if cap else game.hud.stock_grid
	for row in grid.get_children():
		if row.is_queued_for_deletion():
			continue
		for c in row.get_children():
			if c is Button and c.get_meta("id", "") == id and c.get_meta("cap", false) == cap:
				return c
	return null


## True when some Label under `node` contains `text` — same helper
## test_game_clicks.gd uses to inspect the preview modal (NO-138).
func _has_label_text(node: Node, text: String) -> bool:
	if node is Label and text in (node as Label).text:
		return true
	for c in node.get_children():
		if _has_label_text(c, text):
			return true
	return false


func _init() -> void:
	# NO-192: raised from 60s. Must stay below run_all.sh's TIMEOUT (600s) or
	# the runner kills the process first and the tail of this probe's log is lost.
	create_timer(180.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: probe still running after 180s — force quit")
		quit(1))
	if not DisplayServer.is_touchscreen_available():
		push_error("FAIL: touch emulation is off — this probe needs game/override.cfg")
		quit(1)
		return
	DirAccess.remove_absolute(Settings.SETTINGS_PATH)
	Account._reset_cache()
	Account.start_guest()
	root.window_input.connect(func(e: InputEvent) -> void:
		if recording and e is InputEventMouseMotion:
			foreign_motion += 1)

	# --- NO-144: a long press on an ITEM opens its preview modal and does not
	# arm it. Was show_tip until NO-144 — NO-138's own rule ("one rule: long
	# press opens the modal with the preview, not the tip popup, and not only
	# in some places") had missed Items and Artefacts; NO-144 finished
	# applying it here. Do not restore the tip_panel/tip_label assertions
	# below on the grounds that they used to pass — they described a path
	# this cell no longer takes.
	var game: Node = await _boot_game()
	var sniper := _item_button(game, "sniper")
	check(sniper != null, "the inventory drawer has the Sniper item")
	var clean := false
	for attempt in 3:
		game.hud.hide_tip()
		if await _long_press(sniper.get_global_rect().get_center()):
			clean = true
			break
		print("   (attempt %d contaminated by real cursor motion — retrying)" % attempt)
	check(clean, "a long press completed without real cursor motion")
	check(game.preview_open, "a long press on an item opens its preview modal")
	check(_has_label_text(game.preview_panel, game.items[0].name),
		"a long press on an item shows its description")
	check(_has_label_text(game.preview_panel, game.items[0].description),
		"...and it is that item's description")
	var item_tr: Rect2 = game.preview_panel.get_global_rect()
	var item_vp: Vector2 = root.get_visible_rect().size
	# visible first: a hidden panel sits at (0,0) and would pass the bounds check
	check(game.preview_panel.visible and item_tr.position.x >= 0.0 and item_tr.position.y >= 0.0
			and item_tr.end.x <= item_vp.x and item_tr.end.y <= item_vp.y,
		"...and the item's popup is visible and fully on screen (%s in %s)" % [item_tr, item_vp])
	check(game.item_active == -1, "...and does NOT arm the item")
	game.queue_free()
	await process_frame

	# --- NO-144: a long press on a ✹ ARTEFACT CELL opens its preview modal,
	# does not activate. Moscovium Glow Stick is free and always available
	# while held, so a plain press WOULD open the activation confirm — which
	# is what must not happen. Was show_tip until NO-144, same as the Item
	# case above — see that block's comment; do not restore the tip_panel
	# assertions here either.
	game = await _boot_game()
	var chip: Button = _artefact_cell(game, "moscovium-glow-stick")
	check(chip != null and not chip.disabled, "the Artefacts grid has a live ✹ cell")
	clean = false
	for attempt in 3:
		game.hud.hide_tip()
		if await _long_press(chip.get_global_rect().get_center()):
			clean = true
			break
		print("   (attempt %d contaminated by real cursor motion — retrying)" % attempt)
	check(clean, "a long press on the cell completed without real cursor motion")
	check(game.preview_open, "a long press on a ✹ Artefact cell opens its preview modal")
	check(_has_label_text(game.preview_panel, game._artefact_entry("moscovium-glow-stick").name),
		"a long press on a ✹ Artefact cell shows its description")
	check(_has_label_text(game.preview_panel, game._artefact_entry("moscovium-glow-stick").description),
		"...and it is the ✹ artefact's description")
	check(not game.buff_pick_open, "...and does NOT open the activation confirm")
	var tr: Rect2 = game.preview_panel.get_global_rect()
	var vp: Vector2 = root.get_visible_rect().size
	# visible first: a hidden panel sits at (0,0) and would pass the bounds check
	check(game.preview_panel.visible and tr.position.x >= 0.0 and tr.position.y >= 0.0
			and tr.end.x <= vp.x and tr.end.y <= vp.y,
		"...and the ✹ artefact's popup is visible and fully on screen (%s in %s)" % [tr, vp])
	game.queue_free()
	await process_frame

	# --- NO-85 story 53/54/55: a PASSIVE Artefact cell — tap does nothing, long
	# press still describes it. This is the one cell that is disabled forever
	# (not just conditionally, like an unavailable ✹ one), so it is the sharpest
	# check that long-press still reaches a permanently-greyed cell.
	game = await _boot_game()
	var passive := _artefact_cell(game, "tinfoil-hat")
	check(passive != null and passive.disabled, "the Artefacts grid has a passive (always-disabled) cell")
	game.hud.hide_tip()
	var pat: Vector2 = passive.get_global_rect().get_center()
	_mouse(true, pat)
	await process_frame
	_release_at(pat)
	await process_frame
	check(not game.hud.tip_panel.visible, "a short tap on a passive Artefact cell shows no description")
	check(not game.buff_pick_open, "...and does nothing else either")
	clean = false
	for attempt in 3:
		game.hud.hide_tip()
		if await _long_press(pat):
			clean = true
			break
		print("   (attempt %d contaminated by real cursor motion — retrying)" % attempt)
	check(clean, "a long press on the passive cell completed without real cursor motion")
	# NO-144: preview modal, not show_tip — same swap as the Item and ✹
	# Artefact blocks above (see the Item block's comment); a disabled cell
	# still reaches _wire_grid_button's on_long_press unconditionally.
	check(game.preview_open, "a long press on a passive Artefact cell opens its preview modal")
	check(_has_label_text(game.preview_panel, game._artefact_entry("tinfoil-hat").name),
		"a long press on a passive Artefact cell shows its description")
	check(_has_label_text(game.preview_panel, game._artefact_entry("tinfoil-hat").description),
		"...and it is the passive artefact's description")
	game.queue_free()
	await process_frame

	# --- a SHORT tap still fires the item: suppression is the risky half -------
	game = await _boot_game()
	sniper = _item_button(game, "sniper")
	game.hud.hide_tip()
	var at: Vector2 = sniper.get_global_rect().get_center()
	_mouse(true, at)
	await process_frame
	_release_at(at)
	await process_frame
	check(game.item_active == 0, "a short tap on an item still arms it")
	check(not game.hud.tip_panel.visible, "...and shows no description")
	game.queue_free()
	await process_frame

	# --- a DRAG starting on an item shows nothing, however long it lasts --------
	# Foreign cursor motion here can only cancel the long press early, which this
	# expects anyway — so contamination can make a broken cancel look right, never
	# a working one look broken. No retry needed.
	game = await _boot_game()
	sniper = _item_button(game, "sniper")
	game.hud.hide_tip()
	at = sniper.get_global_rect().get_center()
	_mouse(true, at)
	await process_frame
	for i in 6: # 180px, well past DRAWER_SCROLL_DEADZONE
		at += Vector2(0, -30)
		var mm := InputEventMouseMotion.new()
		mm.position = at
		mm.global_position = at
		mm.relative = Vector2(0, -30)
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(mm)
		await process_frame
	await create_timer(HOLD_S).timeout # keep holding past the threshold
	_mouse(false, at)
	await process_frame
	check(not game.hud.tip_panel.visible, "a drag starting on an item shows no description, even held past the threshold")
	check(game.item_active == -1, "...and does not arm the item")
	game.queue_free()
	await process_frame

	# --- NO-138 (was NO-120's tip): a long press on a BOARD PIECE opens its
	# preview modal, and does not select it. The board is drawn in _draw, not
	# built from Controls, so this exercises _board_long_press_start (game.gd)
	# rather than hud.gd's _long_press_input — no Button, no gui_input to hold.
	game = await _boot_game()
	game._set_drawer("") # the queen tile used sits low enough to be covered
		# by the open Inventory drawer otherwise
	check(game.selected == Vector2i(-1, -1), "nothing selected before the press")
	var queen_at := Vector2i(2, 1) # the player Queen _boot_game()'s config places
	var qpos: Vector2 = game._tile_px(queen_at) + Vector2(game.tile, game.tile) / 2
	clean = false
	for attempt in 3:
		game.hud.hide_tip()
		if await _long_press(qpos):
			clean = true
			break
		print("   (attempt %d contaminated by real cursor motion — retrying)" % attempt)
	check(clean, "a long press on the board piece completed without real cursor motion")
	check(game.preview_open, "a long press on a board piece opens its preview modal")
	check(_has_label_text(game.preview_panel, game.defs["queen"].name),
		"...and it shows the board piece's name")
	check(game.selected == Vector2i(-1, -1), "...and does NOT select the piece")
	game.queue_free()
	await process_frame

	# --- a SHORT TAP on the same board piece still selects it, as before -------
	game = await _boot_game()
	game._set_drawer("")
	game.hud.hide_tip()
	qpos = game._tile_px(queen_at) + Vector2(game.tile, game.tile) / 2
	_mouse(true, qpos)
	await process_frame
	_release_at(qpos)
	await process_frame
	check(game.selected == queen_at, "a short tap on a board piece still selects it")
	check(not game.preview_open, "...and opens no preview (board piece)")
	game.queue_free()
	await process_frame

	# --- NO-120 hazard (found in review 2026-09-18): long-pressing an ENEMY
	# piece on a legal destination of the current selection must NOT capture
	# it. _on_tile_clicked used to run on press, before the hold could even
	# resolve — the tooltip appeared over a board that had already changed.
	# Assert what a capture would have changed (the enemy gone, gold, actions
	# spent), never `selected` alone — a restored `selected` reads green even
	# while the capture already happened (CLAUDE.md: assert the observable
	# consequence, never the flag that was just written).
	var enemy_at := Vector2i(2, 6) # the enemy Pawn _boot_game()'s config
		# places, directly up the Queen's own file — a legal capture
	game = await _boot_game()
	game._set_drawer("")
	qpos = game._tile_px(queen_at) + Vector2(game.tile, game.tile) / 2
	_mouse(true, qpos) # select the Queen first (a short tap — not timed)
	await process_frame
	_release_at(qpos)
	await process_frame
	check(game.selected == queen_at, "the Queen is selected before the hazard press")
	check(game.legal_dests.has(enemy_at), "the enemy Pawn is a legal capture from here")
	var gold_before: int = game.gold
	var actions_before: int = game.actions_left
	var epos: Vector2 = game._tile_px(enemy_at) + Vector2(game.tile, game.tile) / 2
	clean = false
	for attempt in 3:
		game.hud.hide_tip()
		if await _long_press(epos):
			clean = true
			break
		print("   (attempt %d contaminated by real cursor motion — retrying)" % attempt)
	check(clean, "a long press on the enemy completed without real cursor motion")
	check(game.preview_open, "a long press on the enemy opens its preview modal")
	check(_has_label_text(game.preview_panel, game.defs["pawn"].name), "...and it shows the enemy piece's name")
	check(game.board.has(enemy_at) and game.board[enemy_at].owner == GameScript.Rules.ENEMY,
		"...and the enemy Pawn is STILL on the board — not captured")
	check(game.gold == gold_before, "...and gold is unchanged")
	check(game.actions_left == actions_before, "...and no action was spent")
	game.queue_free()
	await process_frame

	# --- positive control: a SHORT TAP on that same enemy still captures it,
	# so the hazard test above cannot pass by the press simply missing --------
	game = await _boot_game()
	game._set_drawer("")
	qpos = game._tile_px(queen_at) + Vector2(game.tile, game.tile) / 2
	_mouse(true, qpos)
	await process_frame
	_release_at(qpos)
	await process_frame
	actions_before = game.actions_left
	epos = game._tile_px(enemy_at) + Vector2(game.tile, game.tile) / 2
	_mouse(true, epos)
	await process_frame
	_release_at(epos)
	await process_frame
	check(game.board.has(enemy_at) and game.board[enemy_at].owner == GameScript.Rules.PLAYER \
			and game.board[enemy_at].id == "queen",
		"(control) a short tap on the same enemy DOES capture — the Queen lands there")
	check(not game.board.has(queen_at), "(control) ...and the Queen's old tile is empty")
	check(game.actions_left == actions_before - 1, "(control) ...and an action was spent")
	game.queue_free()
	await process_frame

	# --- NO-138 (was NO-120's tip): a long press on a STOCK cell opens its
	# preview modal, through _long_press_input exactly like an Inventory cell
	# (on_fire replaces show_tip — see _build_stack_button), and does not
	# arm it for deploy ---
	game = await _boot_game()
	game._set_drawer("stock")
	await _await_drawer_settled(game, "stock") # NO-118
	var pawn_btn := _stock_button(game, "pawn", false)
	check(pawn_btn != null, "the Stock drawer has the pawn stack _boot_game() placed")
	clean = false
	for attempt in 3:
		game.hud.hide_tip()
		if await _long_press(pawn_btn.get_global_rect().get_center()):
			clean = true
			break
		print("   (attempt %d contaminated by real cursor motion — retrying)" % attempt)
	check(clean, "a long press on the Stock cell completed without real cursor motion")
	check(game.preview_open, "a long press on a Stock cell opens its preview modal")
	check(_has_label_text(game.preview_panel, game.defs["pawn"].name),
		"...and it shows the Stock piece's name")
	check(game.placing_id == "", "...and does NOT arm it for deploy")
	game.queue_free()
	await process_frame

	# --- a SHORT TAP on the same Stock cell still arms it, as before -----------
	game = await _boot_game()
	game._set_drawer("stock")
	# NO-120 flake, root-caused 2026-09-18, hit AGAIN once #464's drawer slide
	# landed on main (2026-09-19) — two INDEPENDENT waits, both needed, do not
	# delete either as "redundant":
	#   1. _await_drawer_settled (NO-118): the panel itself takes
	#      Tuning.PANEL_SLIDE_S of real time to slide from drawer_hidden to
	#      drawer_rest. Read a rect before that finishes and it's the panel's
	#      MID-SLIDE position, most of a drawer-height off from where it lands.
	#   2. The plain `await process_frame` below it: GridContainer defers its
	#      OWN layout sort to the next idle frame, independent of the panel's
	#      position — the panel arriving at rest does not imply the grid
	#      inside it has also sorted the freshly rebuilt row into its column.
	# A LONG press tolerates skipping both (the hold outlasts them, and the
	# tip is tracked by object, not by screen position); a SHORT tap's release
	# does not — it lands wherever the button's rect says it is RIGHT NOW,
	# stale or not.
	await _await_drawer_settled(game, "stock") # NO-118
	game.hud.hide_tip()
	pawn_btn = _stock_button(game, "pawn", false)
	await process_frame # grid sort, independent of the drawer-settle above
	var ppos: Vector2 = pawn_btn.get_global_rect().get_center()
	_mouse(true, ppos)
	await process_frame
	_release_at(ppos)
	await process_frame
	check(game.placing_id == "pawn", "a short tap on a Stock cell still arms it")
	check(not game.preview_open, "...and opens no preview (Stock cell)")
	game.queue_free()
	await process_frame

	# --- NO-138: a long press during ITEM TARGETING opens the preview modal —
	# before this, NO-121 left an occupied tile's hold showing nothing while
	# targeting was active, because every tap in that mode classifies as a
	# commit (_board_tap_is_readonly). Reuses enemy_at from the hazard test
	# above: the Queen can capture the enemy Pawn there, so Sniper
	# (target == "tile") accepts it as a target too.
	game = await _boot_game()
	game._set_drawer("")
	game._use_item(0) # arms Sniper — NO-124: select, target, confirm
	check(game.item_active == 0, "Sniper is armed before the hazard press")
	check(game.item_targets.has(enemy_at), "the enemy Pawn is a legal Sniper target")
	epos = game._tile_px(enemy_at) + Vector2(game.tile, game.tile) / 2
	clean = false
	for attempt in 3:
		game.hud.hide_tip()
		if await _long_press(epos):
			clean = true
			break
		print("   (attempt %d contaminated by real cursor motion — retrying)" % attempt)
	check(clean, "a long press on the enemy during targeting completed without real cursor motion")
	check(game.preview_open, "...and opens the preview modal")
	check(_has_label_text(game.preview_panel, game.defs["pawn"].name),
		"...and it shows the targeted enemy's name")
	check(game.item_active == 0, "...and Sniper is still armed, untouched")
	check(game.item_pending_tile == Vector2i(-1, -1),
		"...and does NOT stage the enemy as Sniper's target")
	check(game.board_lp_pending_tile == Vector2i(-1, -1),
		"...and leaves no deferred tap behind for the next press to trip over")
	check(game.board.has(enemy_at) and game.board[enemy_at].owner == GameScript.Rules.ENEMY,
		"...and the enemy Pawn is untouched")
	game.queue_free()
	await process_frame

	# --- positive control: a SHORT TAP on the same enemy still stages it as
	# Sniper's target, so the hazard test above cannot pass by the press
	# simply missing ---
	game = await _boot_game()
	game._set_drawer("")
	game._use_item(0)
	epos = game._tile_px(enemy_at) + Vector2(game.tile, game.tile) / 2
	_mouse(true, epos)
	await process_frame
	_release_at(epos)
	await process_frame
	check(game.item_pending_tile == enemy_at,
		"(control) a short tap on the enemy stages it as Sniper's target")
	check(not game.preview_open, "(control) ...and opens no preview")
	game.queue_free()
	await process_frame

	if fails == 0:
		print("ALL GREEN (long-press probe)")
	quit(0 if fails == 0 else 1)
