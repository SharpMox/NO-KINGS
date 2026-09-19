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


## NO-118: hud.gd's _slide_drawer takes Tuning.PANEL_SLIDE_S of real time to
## carry a drawer from drawer_hidden[key] to drawer_rest[key]. A drag/tap
## aimed at a control inside the drawer, sent before that settles, reads a
## rect that is still mid-slide. Poll process_frame, bounded, until the
## drawer's own Control sits at its cached rest position; the bound means a
## broken tween fails loudly here instead of every downstream check silently
## missing.
func _await_drawer_settled(game: Node, key: String) -> void:
	var panel: Control = game.hud.drawers[key]
	var rest: Vector2 = game.hud.drawer_rest[key]
	var polls := 0
	while panel.position != rest and polls < 60:
		await process_frame
		polls += 1
	check(panel.position == rest, "the %s drawer's slide settled before use" % key)


## NO-145: a point inside `container`'s own rect but OUTSIDE `content`'s —
## the slack a Container leaves around a child sized smaller than itself,
## i.e. the "chrome or edge, not a scrollable cell" a reverse-close swipe
## must land on. Self-computed from the live rects rather than a guessed
## pixel offset, so it tracks the real layout instead of assuming this
## file's own math; the check() below turns a wrong layout assumption into
## a clear, named failure instead of a silently-wrong swipe target.
func _chrome_point(container: Control, content: Control) -> Vector2:
	var cr := container.get_global_rect()
	var pr := content.get_global_rect()
	check(cr.size.x > pr.size.x or cr.size.y > pr.size.y,
		"NO-145: %s leaves slack around its content for chrome" % container.name)
	return Vector2(cr.position.x + cr.size.x - 2.0, pr.position.y + pr.size.y - 2.0)


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
		# "Device info" is a fixed row beside Back, not a scenario — same
		# exclusion as test_menu_clicks.gd's accordion-collapse check.
		if c is Button and c.visible and not c.text.begins_with("▾") and c.text != "← Back" \
				and c.text != "Device info":
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
		# "Device info" is a fixed row beside Back, not a scenario — same
		# exclusion as test_menu_clicks.gd's accordion-collapse check.
		if c is Button and c.visible and not c.text.begins_with("▾") and c.text != "← Back" \
				and c.text != "Device info":
			var r: Rect2 = c.get_global_rect()
			if r.position.y > scroll.global_position.y + 40 and r.end.y < scroll.global_position.y + scroll.size.y - 40:
				row = c
				break
	check(row != null, "a scenario row is on screen to tap")
	row.pressed.connect(_on_row_pressed)
	var tap_at := row.get_global_rect().get_center()
	_mouse(true, tap_at)
	await process_frame
	# NO-71: same race as the item tap further down, which carries the full
	# explanation — a real desktop-cursor motion landing in this frame cancels
	# the Button's press. Re-assert the finger's position, back to back with the
	# release.
	var tap_back := InputEventMouseMotion.new()
	tap_back.position = tap_at
	tap_back.global_position = tap_at
	tap_back.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(tap_back)
	_mouse(false, tap_at)
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
		#
		# NO-85: the Artefacts grid packs far denser than the old wrapping
		# strip (INV_ARTEFACTS_COLS columns instead of one long flow), so the
		# original 16 keys no longer overflow the drawer at all (measured:
		# -56px of range, i.e. it FITS). Doubled to 32 so this stays a genuine
		# scroll-range assertion regardless of exact column tuning.
		"artefacts": ["27-club-punch-card", "tinfoil-hat",
			"area-51-parking-permit", "fort-knox-iou",
			"fema-summer-camp-flyer", "zurich-gnome-figurine",
			"nero-s-marshmallow-stick", "pre-scratched-lottery-ticket",
			"tungsten-filled-gold-bar", "crop-circle-plank",
			"mar-a-lago-toilet-papers", "suspiciously-large-femur",
			"daylight-savings-jar", "phantom-punch-glove",
			"naruto-run-manual", "social-credit-report-card",
			"mk-ultra-sugar-cube", "frog-pride-flag",
			"hoffa-s-cement-shoes", "witness-protection-mustache",
			"5g-microchips", "frame-25",
			"satoshi-s-private-key", "capstone-polish",
			"golden-buddha-bobblehead", "charlemagne-s-birth-certificate",
			"nigerian-prince-wire-transfer", "curtain-rods-bag-rifle-shaped",
			"obedience-flavored-tap-water", "cia-heart-attack-gun",
			"dihydrogen-monoxide-battery", "walt-s-cryonic-capsule"],
		"wave": 3, "gold": 200, "seed": 1}
	GameScript.is_scenario = true
	var game: Node = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game._set_drawer("inventory")
	await process_frame
	await process_frame
	await _await_drawer_settled(game, "inventory") # NO-118

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
	var art_row: Control = game.hud.artefacts_grid.get_child(0)
	var inv_before: int = inv_sc.scroll_vertical
	await _drag(art_row.get_global_rect().get_center(), Vector2(0, -30), 6)
	check(inv_sc.scroll_vertical != inv_before,
		"a drag STARTING ON an artefact row scrolls the inventory drawer (%d -> %d)"
			% [inv_before, inv_sc.scroll_vertical])
	# that drag must NOT also have popped a description — a scroll is not a tap.
	check(not game.hud.tip_panel.visible,
		"...and the drag does NOT pop a description")

	# NO-65 fix, structural: nothing in this drawer paints outside it any more.
	check(inv_sc.clip_contents, "the Inventory Drawer's ScrollContainer clips its contents")

	# --- NO-85 story 53: a plain TAP on a passive Artefact cell does nothing —
	# no description (that moved to long-press, tested in test_long_press.gd),
	# no state change. Long-press-vs-tap on Items, passive and ✹ Artefacts is
	# probed there with the cross-contamination-safe long-press helper; this
	# file's job is the drag/scroll gesture, not the hold timing.
	# The drag above scrolled child(0) out of the drawer's visible area —
	# scroll back to top first, or the tap lands outside the drawer instead.
	inv_sc.scroll_vertical = 0
	await process_frame
	var art_cell: Control = game.hud.artefacts_grid.get_child(0)
	var art_tap_at: Vector2 = art_cell.get_global_rect().get_center()
	game.hud.hide_tip()
	_mouse(true, art_tap_at)
	await process_frame
	_mouse(false, art_tap_at)
	await process_frame
	check(not game.hud.tip_panel.visible,
		"a plain tap on a passive Artefact cell shows no description (NO-85: tap no longer describes)")
	check(game.hud.drawer_open == "inventory",
		"...and does not close or otherwise disturb the drawer")

	# ...and the Items grid shares the drawer and its cells still take a tap —
	# they are Buttons set to PASS (NO-45), same as the Artefacts grid, and a
	# Button flipped to PASS that stopped firing would be a silent regression.
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
	await _await_drawer_settled(game, "inventory") # NO-118
	inv_sc = null
	for c in (game.hud.drawers["inventory"] as Control).get_children():
		if c is ScrollContainer:
			inv_sc = c
	var item_btn: Button = null
	for c in game.hud.items_grid.get_children():
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
		# NO-71: put the pointer back on the button before releasing. A Button
		# emits `pressed` on release only if the last pointer motion it saw while
		# held was inside it, and this probe's window also receives the REAL
		# desktop cursor's motion. One of those landing in the frame between press
		# and release cancelled the press: 1 in ~7 runs, every failure with real
		# motion in the gap and none without; injecting an off-button motion there
		# failed 20/20. A finger stays where it landed and a phone has no second
		# pointer, so re-asserting the position is the tap, not a longer wait. The
		# motion and release are pushed back to back, with nothing between for the
		# OS to interleave.
		var back := InputEventMouseMotion.new()
		back.position = p
		back.global_position = p
		back.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(back)
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
	await _await_drawer_settled(game, "stock") # NO-118
	var stack_btn: Button = null
	for c in game.hud.pool_buttons():
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
	# NO-84 story 36: Captured Stock and Stock are two separate
	# ScrollContainers now, not one strip -- that IS what makes dragging
	# one side never scroll the other, so the structural check is the
	# behavioural guarantee.
	# NO-135: stock_grid's direct parent is now a right-alignment wrapper
	# (not the ScrollContainer itself), so walk to the nearest ScrollContainer
	# ancestor instead of asserting a direct parent.
	var stock_sc: Node = game.hud.stock_grid.get_parent()
	while stock_sc != null and not (stock_sc is ScrollContainer):
		stock_sc = stock_sc.get_parent()
	var cap_sc: Node = game.hud.captured_grid.get_parent()
	while cap_sc != null and not (cap_sc is ScrollContainer):
		cap_sc = cap_sc.get_parent()
	check(stock_sc is ScrollContainer
			and cap_sc is ScrollContainer
			and stock_sc != cap_sc,
		"Stock and Captured Stock scroll in separate containers, independently")
	game.queue_free()
	await process_frame

	# ---- NO-145: swipe-to-open/close, and that it never steals an existing
	# drag. Board background / deck chrome opens; a drawer/Shop's own chrome
	# (never a scrollable cell) closes by reversing the OPENING GESTURE.
	GameScript.next_config = {
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 200, "seed": 1}
	GameScript.is_scenario = true
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	# Swipe DOWN on empty board background opens Stock (Max: "swipe down
	# opens Stock"). (4, 4) is empty in this config.
	check(game.hud.drawer_open == "", "NO-145: nothing open before the swipe")
	var board_bg: Vector2 = game._tile_px(Vector2i(4, 4)) + Vector2(game.tile, game.tile) / 2
	await _drag(board_bg, Vector2(0, 15), 6) # 90px down, well past SWIPE_MIN_DIST (40)
	check(game.hud.drawer_open == "stock", "NO-145: swipe down on empty board opens Stock")
	await _await_drawer_settled(game, "stock")

	# Reverse swipe (UP), started on the Stock drawer's OWN CHROME — the
	# slack a VBoxContainer leaves around a child sized smaller than itself
	# (cap_scroll, by STOCK_DRAWER_PAD) — never on a cell, which claims its
	# own rect first (NO-45's PASS rows). Self-computed from the live rects,
	# not a guessed pixel offset.
	var cap_scroll: ScrollContainer = game.hud.captured_grid.get_parent() as ScrollContainer
	check(cap_scroll != null, "NO-145: found the Captured Stock ScrollContainer")
	var cap_col: Control = cap_scroll.get_parent() as Control
	var stock_chrome := _chrome_point(cap_col, cap_scroll)
	await _drag(stock_chrome, Vector2(0, -15), 6) # 90px up
	check(game.hud.drawer_open == "", "NO-145: reverse swipe on Stock's own chrome closes it")

	# Swipe UP on deck chrome opens Inventory (Max: "swipe up opens
	# Inventory") — the gap BETWEEN the drawers row and the thumb row, never
	# one of their buttons.
	var inv_btn_rect: Rect2 = (game.hud.drawer_buttons["inventory"] as Control).get_global_rect()
	var ability_rect: Rect2 = game.hud.army_ability_button.get_global_rect()
	var deck_chrome := Vector2(inv_btn_rect.position.x + 4,
		(inv_btn_rect.position.y + inv_btn_rect.size.y + ability_rect.position.y) / 2.0)
	await _drag(deck_chrome, Vector2(0, -15), 6)
	check(game.hud.drawer_open == "inventory", "NO-145: swipe up on deck chrome opens Inventory")
	await _await_drawer_settled(game, "inventory")

	# Reverse swipe (DOWN) on the Inventory drawer's own chrome closes it —
	# reverses the GESTURE (up), not the panel's own left-to-right slide;
	# see build()'s own note on why those two differ for Inventory.
	var inv_panel: Control = game.hud.drawers["inventory"]
	var inv_sc2: ScrollContainer = null
	for c in inv_panel.get_children():
		if c is ScrollContainer:
			inv_sc2 = c
	check(inv_sc2 != null, "NO-145: found the Inventory drawer's ScrollContainer")
	var inv_chrome := _chrome_point(inv_panel, inv_sc2)
	await _drag(inv_chrome, Vector2(0, 15), 6)
	check(game.hud.drawer_open == "", "NO-145: reverse swipe on Inventory's own chrome closes it")

	# Leftward swipe starting near the RIGHT EDGE opens the Shop (it slides
	# in from the right) — column 7 (the board's last column) is both
	# "board background" (empty here) and within SWIPE_EDGE_ZONE of the
	# right edge, since the board spans the full 480px viewport width.
	var edge_pt: Vector2 = game._tile_px(Vector2i(7, 4)) + Vector2(game.tile, game.tile) / 2
	await _drag(edge_pt, Vector2(-15, 0), 6)
	check(game.shop_open(), "NO-145: leftward swipe near the right edge opens the Shop")
	var shop_polls := 0
	while game.modals.shop_panel.position != game.modals.shop_rest and shop_polls < 60:
		await process_frame
		shop_polls += 1

	# Reverse swipe (RIGHT), started on the Shop's own chrome (the 10px
	# margin ring around its content), closes it.
	var shop_margin: Control = game.modals.shop_panel.get_child(0) as Control
	var shop_root: Control = shop_margin.get_child(0) as Control
	var shop_chrome := _chrome_point(shop_margin, shop_root)
	await _drag(shop_chrome, Vector2(15, 0), 6)
	check(not game.shop_open(), "NO-145: reverse swipe on the Shop's own chrome closes it")

	# ---- regression: a swipe-SHAPED drag starting ON A CELL must never
	# open/close anything — that press belongs to drag-scroll (NO-45's PASS
	# rows) or a Stock deploy-drag, never the swipe recogniser.
	game.queue_free()
	await process_frame
	GameScript.next_config = {
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"artefacts": ["27-club-punch-card", "tinfoil-hat", "area-51-parking-permit",
			"fort-knox-iou", "fema-summer-camp-flyer", "zurich-gnome-figurine"],
		"wave": 3, "gold": 200, "seed": 1}
	GameScript.is_scenario = true
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game._set_drawer("inventory")
	await process_frame
	await process_frame
	await _await_drawer_settled(game, "inventory")
	var art_row2: Control = game.hud.artefacts_grid.get_child(0)
	await _drag(art_row2.get_global_rect().get_center(), Vector2(0, -15), 6) # swipe-shaped, starts on a cell
	check(game.hud.drawer_open == "inventory",
		"NO-145: a swipe-shaped drag starting on an Artefact cell never closes the drawer")
	game._set_drawer("stock")
	await process_frame
	await process_frame
	await _await_drawer_settled(game, "stock")
	var stack_btn2: Button = null
	for c in game.hud.pool_buttons():
		if c is Button and c.has_meta("id"):
			stack_btn2 = c
			break
	check(stack_btn2 != null, "NO-145: the stock drawer has a stack button to test")
	if stack_btn2 != null:
		var drag_started2 := [false]
		game.hud.stack_drag_started.connect(func(_e: Variant, _c: bool) -> void:
			drag_started2[0] = true)
		await _drag(stack_btn2.get_global_rect().get_center(), Vector2(0, -15), 6) # swipe-shaped, starts on a cell
		check(drag_started2[0],
			"NO-145: a swipe-shaped drag on a Stock stack still arms a deploy — the swipe recogniser left it alone")
	game.queue_free()
	await process_frame

	if fails == 0:
		print("ALL GREEN (touch-scroll probe)")
	quit(0 if fails == 0 else 1)
