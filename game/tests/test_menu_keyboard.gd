extends SceneTree
## NO-69: the soft keyboard covers the TEST menu's search results (measured on
## the Android emulator: keyboard ~47% of the screen, hiding all but ~7 of 30
## rows). menu.gd's `keyboard_height_override` is the injection seam — it lets
## this headless suite simulate a real IME height without a real one, since
## DisplayServer.virtual_keyboard_get_height() always reports 0 off-device.
##
## Asserts GEOMETRY (the results ScrollContainer's own global rect), never a
## flag: see CLAUDE.md "Assert the observable consequence, never the flag that
## was just written."

const MenuScript := preload("res://scripts/menu.gd")

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


func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: menu-keyboard suite still running after 60s")
		quit(1))

	var m: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	var menu := m as MenuScript

	# NO-147: TEST now nests inside Settings — open it first.
	var settings_btn := _find_button(m, "Settings")
	check(settings_btn != null, "precondition: the Settings button exists")
	if settings_btn != null:
		settings_btn.pressed.emit()
	await process_frame

	var test_btn := _find_button(m, "TEST")
	check(test_btn != null, "precondition: the TEST button exists")
	if test_btn != null:
		test_btn.pressed.emit()
	await process_frame
	check(menu.test_scroll.visible, "precondition: the TEST results list is open")

	var viewport_h: float = m.get_viewport_rect().size.y
	var base_bottom: float = menu.test_scroll.get_global_rect().end.y
	check(base_bottom > viewport_h - 30.0,
		"baseline: results run to the bottom of the screen with no keyboard")

	# --- desktop must not change: DisplayServer reports 0 off-device --------
	check(menu.keyboard_height_override == -1, "default seam is 'ask the real DisplayServer'")
	menu._update_test_scroll_for_keyboard()
	check(menu.test_scroll.get_global_rect().end.y == base_bottom,
		"desktop (0-height keyboard) leaves the results list untouched")

	# --- simulate a keyboard covering ~47% of the screen, via real focus ----
	menu.keyboard_height_override = int(viewport_h * 0.47)
	menu.test_filter.grab_focus()
	await process_frame
	await process_frame
	var covered_bottom: float = menu.test_scroll.get_global_rect().end.y
	var kb_top: float = viewport_h - menu.keyboard_height_override
	check(covered_bottom <= kb_top,
		"THE DEFECT: focusing search shrinks the results list above the keyboard (bottom %.1f <= %.1f)"
			% [covered_bottom, kb_top])
	check(covered_bottom < base_bottom, "the list actually shrank from its no-keyboard baseline")

	# --- restore on focus loss ------------------------------------------------
	menu.test_filter.release_focus()
	await process_frame
	check(menu.keyboard_height_override == -1, "losing focus clears the injected height")
	check(menu.test_scroll.get_global_rect().end.y == base_bottom,
		"losing focus restores the results list to its original extent")

	m.queue_free()
	await process_frame
	print("---")
	print("ALL MENU KEYBOARD CHECKS OK" if fails == 0 else "MENU KEYBOARD FAILURES: %d" % fails)
	quit(1 if fails > 0 else 0)
