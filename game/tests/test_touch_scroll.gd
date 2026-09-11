extends SceneTree
## Touch-drag probe for every scrolling list a finger lands on: the TEST menu's
## scenario list (PR #379) and the in-game HUD drawers (NO-45). Needs a window
## AND touch emulation — run it through run_all.sh, or by hand with:
##   printf '[input_devices]\npointing/emulate_touch_from_mouse=true\n' > game/override.cfg
##   godot --path game -s tests/test_touch_scroll.gd; rm game/override.cfg
##
## Why the override: ScrollContainer::gui_input (Godot 4.7) returns before its
## drag branch unless DisplayServer.is_touchscreen_available(), which on a desktop
## is only true while emulate_touch_from_mouse is on, and Input exposes no setter
## for it. Without the override this probe cannot go red, so it refuses to run
## rather than pass vacuously.
##
## The bug (2026-09-10, Max on the Nothing Phone 2a): dragging the list did
## nothing at all, no snap-back, while a tap on the scrollbar groove paged. The
## rows are Buttons, whose default mouse_filter is STOP; Viewport::_gui_call_input
## marks a pointer press handled at a STOP control, so the press never reached
## the ScrollContainer and drag_touching never started. The assertion below is
## the observable consequence — the scroll offset moved — never a flag.

const Settings := preload("res://scripts/settings.gd")
const Account := preload("res://scripts/account.gd")
const Drive := preload("res://scripts/drive.gd")
const GameScript := preload("res://scripts/game.gd")

var fails := 0
# A member, not a local: a GDScript lambda captures locals BY VALUE, so a
# `fired = true` inside one never reaches the probe — the first cut of this
# file passed "a drag does not press the row" vacuously that way.
var fired := false


func _on_row_pressed() -> void:
	fired = true


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text and node.is_visible_in_tree():
		return node
	for c in node.get_children():
		var hit := _find_button(c, text)
		if hit:
			return hit
	return null


func _mouse(pressed: bool, at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	root.push_input(ev)


## A finger drag: press, several motion steps with the button held, release.
func _drag(from: Vector2, step: Vector2, steps: int) -> void:
	_mouse(true, from)
	await process_frame
	var at := from
	for i in steps:
		at += step
		var mm := InputEventMouseMotion.new()
		mm.position = at
		mm.global_position = at
		mm.relative = step
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(mm)
		await process_frame
	_mouse(false, at)
	await process_frame


## Drive one command batch and return the ack lines. Writes cmd.txt and pumps
## the driver's own poll rather than waiting on its Timer, so the probe stays
## deterministic — this repo's rule against fixed sleeps applies to probes too.
func _drive(d: Node, dir: String, seq: int, cmds: Array) -> PackedStringArray:
	var f := FileAccess.open(dir.path_join("cmd.txt"), FileAccess.WRITE)
	f.store_line("seq %d" % seq)
	for c in cmds:
		f.store_line(c)
	f = null
	await d._poll()
	return FileAccess.get_file_as_string(dir.path_join("ack.txt")).split("\n", false)


func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: probe still running after 60s — force quit")
		quit(1))
	if not DisplayServer.is_touchscreen_available():
		push_error("FAIL: touch emulation is off — this probe needs game/override.cfg (see header)")
		quit(1)
		return
	DirAccess.remove_absolute(Settings.SETTINGS_PATH)
	Account._reset_cache()
	Account.start_guest()
	var menu: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame

	var test_btn := _find_button(menu, "TEST")
	check(test_btn != null, "TEST button visible")
	_mouse(true, test_btn.get_global_rect().get_center())
	_mouse(false, test_btn.get_global_rect().get_center())
	await process_frame
	var scroll: ScrollContainer = menu.test_scroll
	check(scroll.visible, "TEST opens the scenario list")

	# Open the LAST section so the list overflows the viewport, then drag on a
	# visible scenario ROW — a real finger lands on rows, not on gaps.
	var headers: Array[Button] = []
	for c in scroll.get_child(0).get_children():
		if c is Button and c.text.begins_with("▸"):
			headers.append(c)
	var last_head: Button = headers[headers.size() - 1]
	_mouse(true, last_head.get_global_rect().get_center())
	_mouse(false, last_head.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(scroll.get_v_scroll_bar().max_value > scroll.size.y,
		"the open section overflows the list (%d > %d)" % [scroll.get_v_scroll_bar().max_value, scroll.size.y])
	var row: Button = null
	for c in scroll.get_child(0).get_children():
		if c is Button and c.visible and not c.text.begins_with("▾") and c.text != "← Back":
			var r: Rect2 = c.get_global_rect()
			if r.position.y > scroll.global_position.y + 40 and r.end.y < scroll.global_position.y + scroll.size.y - 40:
				row = c
				break
	check(row != null, "a scenario row is on screen to drag on")
	fired = false
	row.pressed.connect(_on_row_pressed)

	var before: float = scroll.scroll_vertical
	await _drag(row.get_global_rect().get_center(), Vector2(0, -30), 6)
	check(scroll.scroll_vertical > before,
		"dragging up on a row scrolls the list (offset %d -> %d)" % [before, scroll.scroll_vertical])
	check(not fired, "a drag does not press the row it started on")

	# A plain tap must still press the row (the deadzone keeps taps as taps).
	# The list is still decelerating after the drag; wait for it to stop, then
	# re-find a row that is on screen now.
	var last_off := -1.0
	for i in 120:
		if scroll.scroll_vertical == last_off:
			break
		last_off = scroll.scroll_vertical
		await process_frame
	fired = false
	row = null
	for c in scroll.get_child(0).get_children():
		if c is Button and c.visible and not c.text.begins_with("▾") and c.text != "← Back":
			var r: Rect2 = c.get_global_rect()
			if r.position.y > scroll.global_position.y + 40 and r.end.y < scroll.global_position.y + scroll.size.y - 40:
				row = c
				break
	check(row != null, "a scenario row is on screen to tap")
	row.pressed.connect(_on_row_pressed)
	_mouse(true, row.get_global_rect().get_center())
	await process_frame
	_mouse(false, row.get_global_rect().get_center())
	await process_frame
	check(fired, "a tap still presses the row")

	# --- the host-driven input harness (scripts/drive.gd) --------------------
	# TWO THINGS ONLY A WINDOW CAN ASSERT, which is why they are here and not in
	# tests/test_drive.gd: headless drops GUI picking (CLAUDE.md, re-verified on
	# 4.7), so a synthesised tap reports `ok` there while pressing nothing. The
	# headless test covers the protocol and the failure reasons; this covers that
	# the input actually LANDS.
	var dd := "user://t_drive_probe"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dd))
	var drv := Drive.new()
	drv.dir = dd
	root.add_child(drv)
	await process_frame

	# 1. a driven tap really presses a control
	var target := Button.new()
	target.text = "DRIVEN TAP TARGET"
	target.position = Vector2(30, 30)
	target.size = Vector2(220, 44)
	target.pressed.connect(_on_row_pressed)
	root.add_child(target)
	await process_frame
	await process_frame
	fired = false
	await _drive(drv, dd, 1, ["tap_text DRIVEN TAP TARGET"])
	check(fired, "a driven tap_text ACTUALLY PRESSES the control — observable, not the ack")
	target.queue_free()
	await process_frame
	drv.queue_free()
	await process_frame
	for f in ["cmd.txt", "ack.txt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dd.path_join(f)))

	# ---- NO-45: the HUD drawers, which is the same mechanism in the game ----
	# This block replaces tests/repro_no45.gd, which was deliberately red while
	# the bug was live and is deleted now that it is green — its own header said
	# a suite test expected to fail teaches the reader to ignore red. It lands
	# HERE rather than in a file of its own because this is the one suite
	# run_all.sh already wraps in the touch-emulation override, and the
	# precondition is the whole reason a separate file would exist.
	#
	# The fix is rows -> MOUSE_FILTER_PASS plus a deadzone on the container, so
	# there are two things to pin and the second is the one that bites: a drag
	# must SCROLL, and a tap must still PRESS. PASS delivers the press to the row
	# either way, so "the button still works" is not free — it is what the
	# deadzone buys.
	menu.queue_free()
	await process_frame
	GameScript.next_config = {
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		# NO ITEMS HERE, deliberately. Adding six put the inventory drawer's
		# scroll range down from 314px to 37px — the item strip changes the
		# drawer's height — and an assertion with 37px of room and a 24px
		# deadzone is one layout tweak away from being unable to fail. The tap
		# assertions below get their own scenario instead.
		"artefacts": ["27-club-punch-card", "tinfoil-hat",
			"area-51-parking-permit", "fort-knox-iou",
			"fema-summer-camp-flyer", "zurich-gnome-figurine",
			"nero-s-marshmallow-stick", "pre-scratched-lottery-ticket",
			"tungsten-filled-gold-bar", "crop-circle-plank",
			"mar-a-lago-toilet-papers", "suspiciously-large-femur",
			"daylight-savings-jar", "phantom-punch-glove",
			"naruto-run-manual", "social-credit-report-card"],
		"wave": 3, "gold": 200, "seed": 1}
	GameScript.is_scenario = true
	var game: Node = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game._set_drawer("inventory")
	await process_frame
	await process_frame

	var inv_sc: ScrollContainer = null # reused by the second scenario below
	for c in (game.hud.drawers["inventory"] as Control).get_children():
		if c is ScrollContainer:
			inv_sc = c
	check(inv_sc != null, "the inventory drawer has a ScrollContainer")
	check(inv_sc.get_v_scroll_bar().max_value - inv_sc.size.y > 100.0,
		"...with real scroll range (%dpx) — a drawer that cannot scroll proves nothing"
			% int(inv_sc.get_v_scroll_bar().max_value - inv_sc.size.y))
	# START THE DRAG ON AN ARTEFACT ROW. That is the whole point: those rows are
	# the ones that carried MOUSE_FILTER_STOP "so the tooltip shows", and a drag
	# that began on blank drawer space would have scrolled even with the bug —
	# which is exactly how a device test on 2026-09-10 reported "the drawer
	# scrolls fine" against a scenario holding no artefacts at all.
	var art_row: Control = game.hud.artefact_box.get_child(0)
	var inv_before: int = inv_sc.scroll_vertical
	await _drag(art_row.get_global_rect().get_center(), Vector2(0, -30), 6)
	check(inv_sc.scroll_vertical != inv_before,
		"a drag STARTING ON an artefact row scrolls the inventory drawer (%d -> %d)"
			% [inv_before, inv_sc.scroll_vertical])

	# ...and the strips that share the drawer still take a tap. item_box and
	# activate_box build their rows as Buttons, whose default filter was also
	# STOP, so they were changed too — and a Button set to PASS that stopped
	# firing would be a silent, much worse regression than the one being fixed.
	game.queue_free()
	await process_frame
	GameScript.next_config = {
		"board": [["queen", 0, 2, 1], ["pawn", 0, 3, 1], ["pawn", 1, 2, 6]],
		"items": ["blitz", "sniper", "air_strike", "demote", "promote", "invert"],
		"stock": ["pawn", "pawn", "knight"], "wave": 1, "gold": 200, "seed": 1}
	GameScript.is_scenario = true
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game._set_drawer("inventory")
	await process_frame
	await process_frame
	inv_sc = null
	for c in (game.hud.drawers["inventory"] as Control).get_children():
		if c is ScrollContainer:
			inv_sc = c
	var item_btn: Button = null
	for c in game.hud.item_box.get_children():
		if c is Button:
			item_btn = c
			break
	check(item_btn != null, "the inventory drawer has an item button to tap")
	if item_btn != null:
		var item_fired := [false]
		game.hud.item_pressed.connect(func(_i: int) -> void: item_fired[0] = true)
		inv_sc.ensure_control_visible(item_btn)
		await process_frame
		await process_frame
		var p := item_btn.get_global_rect().get_center()
		_mouse(true, p)
		await process_frame
		_mouse(false, p)
		await process_frame
		check(item_fired[0], "a TAP on an item row still presses it — PASS did not cost the press")

	# The Stock drawer is the fourth strip, and the one where PASS is a
	# judgement call: its buttons are drag SOURCES for deploying a piece. Pin
	# that arming a deploy still works, because that is what a careless PASS
	# would break and no artefact assertion would notice.
	game._set_drawer("stock")
	await process_frame
	await process_frame
	var stack_btn: Button = null
	for c in game.hud.pool_box.get_children():
		if c is Button and c.has_meta("id"):
			stack_btn = c
			break
	check(stack_btn != null, "the stock drawer has a stack button")
	if stack_btn != null:
		var drag_started := [false]
		game.hud.stack_drag_started.connect(func(_e: Variant, _c: bool) -> void:
			drag_started[0] = true)
		var sp := stack_btn.get_global_rect().get_center()
		_mouse(true, sp)
		await process_frame
		_mouse(false, sp)
		await process_frame
		check(drag_started[0],
			"pressing a Stock stack still arms a deploy — PASS did not cost the drag source")
	game.queue_free()
	await process_frame

	if fails == 0:
		print("ALL GREEN (touch-scroll probe)")
	quit(0 if fails == 0 else 1)
