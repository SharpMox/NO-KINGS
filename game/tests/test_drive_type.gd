extends SceneTree
## NO-68: the driver's `type` verb (scripts/drive.gd). It sends one
## InputEventKey per character (unicode set, pressed then released) through
## Input.parse_input_event — the same path the driver's taps already use — so a
## host can prove a field it just `tap_text`ed actually receives what a player
## types, rather than falling back to `adb shell input text`, which goes
## through the OS IME and proves nothing about Godot focus
## (docs/ios-device-automation.md, "Device test driver cannot type text").
##
## Two things pinned here, same family as tests/test_drive.gd:
##
## 1. IT REFUSES RATHER THAN TYPES NOWHERE. `gui_get_focus_owner()` is checked
##    before a single key is sent; null OR a non-LineEdit/TextEdit both fail,
##    with a reason, rather than silently discarding the batch.
## 2. PROVEN AGAINST A REAL FIELD, NOT A STUB: the TEST menu's search box
##    (NO-58), driven through the real cmd.txt/ack.txt protocol, asserting the
##    LineEdit's own text and the filtered list — not a flag that was just set.
##
## Focus itself is granted with grab_focus() rather than a driven `tap_text`:
## Godot headless drops GUI PICKING (CLAUDE.md, re-verified on 4.7), which is
## what a screen-position tap needs and a keyboard event routed to the current
## focus owner does not. That half — does a tap actually focus this field — is
## the windowed click probes' job (tests/test_menu_clicks.gd); this suite only
## has to prove what `type` does once focus already sits somewhere.
##
## Run headless: godot --headless --path game -s tests/test_drive_type.gd

const Drive := preload("res://scripts/drive.gd")
const MenuScript := preload("res://scripts/menu.gd")
const Account := preload("res://scripts/account.gd")
const SyncQueue := preload("res://scripts/sync_queue.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("ok: ", label)
	else:
		fails += 1
		print("FAIL: ", label)


func _dir() -> String:
	return "user://t_drive_type"


## Write a command batch and run one poll cycle, returning the ack lines.
## Mirrors tests/test_drive.gd's _send() — same protocol, same shape.
func _send(d: Drive, seq: int, cmds: Array) -> PackedStringArray:
	var f := FileAccess.open(_dir().path_join("cmd.txt"), FileAccess.WRITE)
	f.store_line("seq %d" % seq)
	for c in cmds:
		f.store_line(c)
	f = null
	await d._poll()
	var raw := FileAccess.get_file_as_string(_dir().path_join("ack.txt"))
	return raw.split("\n", false)


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
		push_error("WATCHDOG: drive-type suite still running after 60s")
		quit(1))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir()))
	var d := Drive.new()
	d.dir = _dir()
	root.add_child(d)
	await process_frame

	# --- 1. nothing focused at all -------------------------------------------
	var ack := await _send(d, 1, ["type hello"])
	check(ack.size() >= 2 and ack[1].begins_with("fail type"),
		"type with nothing focused fails rather than typing nowhere (%s)"
			% (ack[1] if ack.size() > 1 else "-"))
	check(ack.size() >= 2 and "focused" in ack[1],
		"...and says WHY (%s)" % (ack[1] if ack.size() > 1 else "-"))

	# --- 2. something focused, but not a LineEdit/TextEdit -------------------
	var btn := Button.new()
	btn.text = "NOT A TEXT FIELD"
	root.add_child(btn)
	await process_frame
	btn.grab_focus()
	await process_frame
	ack = await _send(d, 2, ["type hello"])
	check(ack.size() >= 2 and ack[1].begins_with("fail type"),
		"a focused Button still fails — the guard checks the TYPE, not just presence (%s)"
			% (ack[1] if ack.size() > 1 else "-"))
	btn.queue_free()
	await process_frame

	# --- 3. proven against the real TEST menu search box (NO-58) -------------
	# Account state is on disk and shared across suites in one run_all pass: an
	# earlier suite's signed-in/needs-login state carries into this process's
	# boot and can leave the menu on its login screen instead of main_box,
	# where the TEST button does not exist. Same fix test_menu_continue.gd
	# carries, for the same reason: it passed standalone and failed under
	# run_all until this was added.
	Account._reset_cache()
	Account.start_guest()
	SyncQueue.clear()
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
	check(menu.test_filter != null, "precondition: the TEST list has its search box")
	check(menu.test_filter.text == "", "precondition: the search box starts EMPTY")

	# An empty LineEdit's `.text` is "", so `tap_text`/`probe` had nothing to
	# find it by until _text_of() fell back to `placeholder_text` for that
	# case (drive.gd) — on a real screen this is the only way a host reaches
	# this field at all, since it holds no text before someone types into it.
	ack = await _send(d, 3, ["tap_text search scenarios"])
	check(ack.size() >= 2 and ack[1].begins_with("ok tap_text"),
		"tap_text finds the EMPTY search box by its placeholder text (%s)"
			% (ack[1] if ack.size() > 1 else "-"))

	# Godot headless drops GUI PICKING, so the tap above cannot actually move
	# focus (that half is the windowed probes' job, same note as
	# tests/test_drive.gd). grab_focus() stands in for "the tap landed" so
	# `type` below has something real to prove.
	menu.test_filter.grab_focus()
	await process_frame

	# a scenario name buried in a COLLAPSED section — same target NO-58's own
	# probe uses, chosen from the data rather than hardcoded so a rename cannot
	# rot this suite
	var buried: Button = null
	for sec_dict in menu._test_sections:
		if sec_dict.head.text.begins_with("▾"):
			continue # open already; the point is a name nothing shows yet
		for r: Button in sec_dict.rows:
			if not r.visible:
				buried = r
				break
		if buried != null:
			break
	check(buried != null, "precondition: found a scenario inside a collapsed section")
	if buried != null:
		var buried_name: String = str(buried.get_meta("scenario_name"))

		ack = await _send(d, 4, ["type " + buried_name])
		check(ack.size() >= 2 and ack[1].begins_with("ok type"),
			"typing into a focused LineEdit reports ok (%s)" % (ack[1] if ack.size() > 1 else "-"))
		check(menu.test_filter.text == buried_name,
			"the LineEdit's OWN text matches what was typed, character by character (got '%s')"
				% menu.test_filter.text)
		check(buried.visible,
			"...and the filter it drove shows the match (%s)" % buried_name)
		var still_up := 0
		for sec_dict in menu._test_sections:
			for r: Button in sec_dict.rows:
				if r.visible:
					still_up += 1
		check(still_up < 20,
			"...and hides everything that does not match (%d rows left)" % still_up)

	menu.test_filter.text = ""
	menu._apply_test_filter()
	m.queue_free()
	d.queue_free()
	await process_frame
	for f in ["cmd.txt", "ack.txt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_dir().path_join(f)))

	print("---")
	print("ALL DRIVE-TYPE CHECKS OK" if fails == 0 else "DRIVE-TYPE FAILURES: %d" % fails)
	quit(1 if fails > 0 else 0)
