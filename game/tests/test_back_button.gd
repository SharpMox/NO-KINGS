extends SceneTree
## NO-61: Android delivers NOTIFICATION_WM_GO_BACK_REQUEST TWICE per hardware
## Back press, and every handler in this project ran twice because of it.
##
## THIS SUITE EXISTS BECAUSE NOTHING COULD CATCH THAT. The defect shipped, was
## found only on a phone, was retracted once as a false positive, and cost two
## device sessions — all for a bug that is reproducible headlessly in one line.
## `Window::_propagate_window_notification` is what the engine calls, and
## `get_tree().root.propagate_notification(...)` is the same walk, so a test can
## deliver the notification exactly as Android does.
##
## THE DOUBLE IS DRIVEN THROUGH THE ROOT ON PURPOSE. Calling
## `menu._notification(...)` directly would skip the propagation walk and test
## less than the engine does — and the walk is the part that reaches every node.
##
## ALL THREE SCENES, because the double presented DIFFERENTLY in each and a test
## covering one leaves the other two free to regress:
##   menu  — first call closed the panel, second quit the app
##   game  — first call opened the pause menu, second closed it: Back did nothing
##   intro — looked fine only because _advance() already guarded itself
##
## Godot 4.7, the version in use, carries the upstream regression
## (godotengine/godot#117653). When a Godot without it is adopted, this suite
## should still pass — the guard is a defence, and a defence that becomes
## unnecessary is harmless. See scripts/back_guard.gd.
##
## VERIFIED TO HAVE BITE, and the way it fails is worth knowing: with the guard
## disabled this suite does not report a FAIL, it STOPS DEAD after "precondition:
## a panel is open" — because the second delivery reaches get_tree().quit() and
## kills the test process. That IS the defect, reproduced headlessly. A silent
## early exit rather than a red line is an odd failure signature, so anyone
## seeing this suite end early should suspect the guard rather than the harness.

const Account := preload("res://scripts/account.gd")
const Settings := preload("res://scripts/settings.gd")
const GameScript := preload("res://scripts/game.gd")
const BackGuard := preload("res://scripts/back_guard.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("ok: ", label)
	else:
		fails += 1
		print("FAIL: ", label)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text and node.is_visible_in_tree():
		return node
	for c in node.get_children():
		var hit := _find_button(c, text)
		if hit:
			return hit
	return null


## One hardware Back press AS ANDROID DELIVERS IT: the notification twice, close
## together. The 1 ms gap is what was measured on the device.
func _press_back_twice() -> void:
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame


## A single delivery, for the cases where one press SHOULD act.
func _press_back_once() -> void:
	BackGuard._reset()
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame


func _init() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: back-button suite still running after 120s")
		quit(1))
	DirAccess.remove_absolute(Settings.SETTINGS_PATH)
	Account._reset_cache()
	Account.start_guest()

	# ---- THE MENU: a panel must close, and the app must survive --------------
	BackGuard._reset()
	var menu: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	check(_find_button(menu, "TEST") != null, "precondition: the main menu is up")

	menu.test_scroll.visible = true
	menu.main_box.visible = false
	await process_frame
	check(menu.test_scroll.visible, "precondition: a panel is open")

	await _press_back_twice()
	# THE DEFECT: the second delivery found nothing open and called
	# get_tree().quit(). Asserted on what a player sees — the panel closed and
	# the menu came back — rather than on the guard having been consulted.
	check(not menu.test_scroll.visible, "one Back closes the open panel")
	check(menu.main_box.visible, "...and the main menu is showing again")
	check(is_instance_valid(menu), "...and the app is still alive")

	# The documented behaviour must SURVIVE the guard: from the bare main menu
	# there is nowhere up, so Back quits. A guard that swallowed this would be a
	# regression in the opposite direction, which is why it is pinned.
	check(_find_button(menu, "TEST") != null,
		"the menu still offers its panels after a Back")

	# A SECOND, SEPARATE press still works — the window must not latch.
	menu.test_scroll.visible = true
	menu.main_box.visible = false
	await process_frame
	await _press_back_once()
	check(not menu.test_scroll.visible,
		"a LATER press still acts — the guard is a window, not a one-shot")

	menu.queue_free()
	await process_frame

	# ---- THE INTRO: one press must not blow through the CONTINUE gate --------
	# The intro is the scene where the double looked HARMLESS, because
	# _advance() is already guarded by _advanced and so running it twice is
	# indistinguishable from once. The real exposure is the other direction:
	# from the non-looping state, the first delivery calls _begin_loop() and the
	# second would then find _looping true and call _advance() — one press
	# skipping the intro AND the CONTINUE gate behind it, in a scene whose whole
	# point is that entering the game is a deliberate press.
	BackGuard._reset()
	var intro: Node = load("res://scenes/Intro.tscn").instantiate()
	root.add_child(intro)
	await process_frame
	await process_frame
	check(not intro._looping and not intro._advanced,
		"precondition: the intro is playing, not yet looping")

	await _press_back_twice()
	check(intro._looping, "one Back hands the intro over to its loop")
	check(not intro._advanced,
		"...and does NOT also advance past the CONTINUE gate — the doubled call did")

	# Deliberately NOT driving a further press here: _advance() calls
	# change_scene_to_file, which in this harness replaces the running scene and
	# tears down the cases below it. "A later press still acts" is pinned on the
	# menu above, where it costs nothing.
	intro.queue_free()
	await process_frame

	# ---- IN A RUN: the pause menu must OPEN and stay open -------------------
	# This is the row the double turned into "Back does nothing": game.gd calls
	# hud.toggle_menu(not game_menu_open) twice, so it opened and closed again.
	BackGuard._reset()
	GameScript.next_config = {
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 200, "seed": 1}
	GameScript.is_scenario = true
	var game: Node = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(not game.game_menu_open, "precondition: the pause menu is closed")

	await _press_back_twice()
	check(game.game_menu_open,
		"one Back OPENS the pause menu and it stays open — the doubled call closed it again")

	await _press_back_once()
	check(not game.game_menu_open, "a second press closes it, as it should")

	game.queue_free()
	await process_frame

	Account._reset_cache()
	print("---")
	print("ALL BACK CHECKS OK" if fails == 0 else "BACK FAILURES: %d" % fails)
	quit(1 if fails > 0 else 0)
