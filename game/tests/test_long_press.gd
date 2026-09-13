extends SceneTree
## NO-72: a LONG PRESS on an item or an Activate chip shows its description,
## and does not fire the control. Needs a window AND touch emulation — run it
## through run_all.sh, or by hand with the override test_touch_scroll.gd
## documents. Its own file rather than a section of test_touch_scroll.gd,
## because that suite's taps raced the real cursor until NO-71, and a check that
## HOLDS for half a second is far more exposed to the same thing.

const Settings := preload("res://scripts/settings.gd")
const Account := preload("res://scripts/account.gd")
const GameScript := preload("res://scripts/game.gd")

## Longer than Android's long-press timeout (ViewConfiguration, 500 ms), which
## is what the HUD's threshold is taken from. A literal rather than the HUD
## constant, so this cannot pass because the two drifted together.
const HOLD_S := 0.65

var fails := 0
var recording := false
var foreign_motion := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


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
	await create_timer(HOLD_S).timeout
	recording = false
	_release_at(at)
	await process_frame
	return foreign_motion == 0


func _boot_game() -> Node:
	GameScript.next_config = {
		"board": [["queen", 0, 2, 1], ["pawn", 0, 3, 1], ["pawn", 1, 2, 6]],
		"items": ["sniper", "blitz"],
		"artefacts": ["moscovium-glow-stick"],
		"stock": ["pawn"], "wave": 1, "gold": 200, "seed": 1}
	GameScript.is_scenario = true
	var game: Node = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game._set_drawer("inventory")
	await process_frame
	await process_frame
	return game


func _item_button(game: Node, key: String) -> Button:
	for i in game.items.size():
		if game.items[i].key == key:
			return game.hud.item_box.get_child(i)
	return null


func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: probe still running after 60s — force quit")
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

	# --- a long press on an ITEM shows its description and does not arm it ---
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
	check(game.hud.tip_panel.visible, "a long press on an item shows its description")
	check(game.hud.tip_label.text == game.items[0].description,
		"...and it is that item's description")
	check(game.item_active == -1, "...and does NOT arm the item")
	game.queue_free()
	await process_frame

	# --- a long press on an ACTIVATE CHIP shows its description, does not activate
	# Moscovium Glow Stick is free and always available while held, so a plain
	# press WOULD open the activation confirm — which is what must not happen.
	game = await _boot_game()
	var chip: Button = game.hud.activate_box.get_child(0) if game.hud.activate_box.get_child_count() > 0 else null
	check(chip != null and not chip.disabled, "the inventory drawer has a live Activate chip")
	clean = false
	for attempt in 3:
		game.hud.hide_tip()
		if await _long_press(chip.get_global_rect().get_center()):
			clean = true
			break
		print("   (attempt %d contaminated by real cursor motion — retrying)" % attempt)
	check(clean, "a long press on the chip completed without real cursor motion")
	check(game.hud.tip_panel.visible, "a long press on an Activate chip shows its description")
	check(game.hud.tip_label.text == game._artefact_entry("moscovium-glow-stick").description,
		"...and it is that artefact's description")
	check(not game.buff_pick_open, "...and does NOT open the activation confirm")
	var tr: Rect2 = game.hud.tip_panel.get_global_rect()
	var vp: Vector2 = root.get_visible_rect().size
	# visible first: a hidden panel sits at (0,0) and would pass the bounds check
	check(game.hud.tip_panel.visible and tr.position.x >= 0.0 and tr.position.y >= 0.0
			and tr.end.x <= vp.x and tr.end.y <= vp.y,
		"...and the popup is visible and fully on screen (%s in %s)" % [tr, vp])
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

	if fails == 0:
		print("ALL GREEN (long-press probe)")
	quit(0 if fails == 0 else 1)
