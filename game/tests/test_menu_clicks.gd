extends SceneTree
## UI click probe: boots the real menu and injects synthetic mouse clicks at
## button centers, asserting the UI responds. Catches invisible-overlay /
## mouse-filter bugs that logic tests and screenshots cannot. Needs a window —
## Godot 4.6 headless drops GUI picking (verified). Run:
##   godot --path game -s tests/test_menu_clicks.gd

const GameScript := preload("res://scripts/game.gd")
const Settings := preload("res://scripts/settings.gd")
const Account := preload("res://scripts/account.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _find_button(node: Node, text: String) -> Button:
	# visible-first: "← Back" exists in both the TEST and army submenus
	if node is Button and node.text == text and node.is_visible_in_tree():
		return node
	for c in node.get_children():
		var hit := _find_button(c, text)
		if hit:
			return hit
	return null


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		root.push_input(ev)


func _click_button(menu: Node, text: String) -> bool:
	var btn := _find_button(menu, text)
	if btn == null or not btn.is_visible_in_tree():
		return false
	var p: Node = btn.get_parent()
	while p: # bring buttons inside scroll lists into the viewport first
		if p is ScrollContainer:
			p.ensure_control_visible(btn)
			await process_frame
			break
		p = p.get_parent()
	_click(btn.get_global_rect().get_center())
	return true


func _init() -> void:
	# Watchdog: a SCRIPT ERROR mid-run kills this coroutine and quit() below
	# never fires, leaving the window open until a human closes it (user
	# report 2026-07-12). Force-quit instead; normal runs finish long before.
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: probe still running after 120s — force quit")
		quit(1))
	DirAccess.remove_absolute(Settings.SETTINGS_PATH) # clean slate for the Sound toggle probe
	# issue 83: an account must exist before the main menu is reachable at all.
	# Every assertion below drives the MAIN menu, so establish one first — the
	# login screen itself is probed at the end, on a fresh menu.
	Account._reset_cache()
	Account.start_guest()
	var menu: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame

	# TEST opens the scenario list (this click is what PR #20 shipped broken:
	# the hidden submenu's ScrollContainer swallowed every mouse event)
	check(await _click_button(menu, "TEST"), "TEST button visible")
	await process_frame
	check(_find_button(menu, "← Back") != null, "TEST opens the scenario list")
	# issue 77: the list is sectioned, and the point of sectioning is that every
	# entry stays REACHABLE. The six-Army menu overflow was exactly this bug:
	# content existed but a real player could not get to it, and only a windowed
	# probe saw it.
	#
	# issue 79: sections now COLLAPSE and start collapsed, because the 180
	# generated Artefact sandboxes take this list to 240 entries. So
	# reachability is a two-step property — the header must open, and the entry
	# must then be clickable — and both steps are asserted here. A probe that
	# only looked for the button by text would pass against a list that never
	# expands, since _find_button is visible-first.
	var headers: Array[Button] = []
	for sec_child in menu.test_scroll.get_child(0).get_children():
		if sec_child is Button and sec_child.text.begins_with("▸"):
			headers.append(sec_child)
	check(headers.size() >= 5,
		"scenarios are grouped into collapsible sections (%d headers)" % headers.size())
	var showing := 0
	for sec_child in menu.test_scroll.get_child(0).get_children():
		if sec_child is Button and sec_child.visible and sec_child.text != "← Back" \
				and not sec_child.text.begins_with("▸"):
			showing += 1
	check(showing == 0, "every section starts collapsed (%d rows showing)" % showing)

	# open the LAST section and reach its LAST entry — the deepest thing here
	var last_head: Button = headers[headers.size() - 1]
	check(await _click_button(menu, last_head.text), "a section header is clickable")
	await process_frame
	check(last_head.text.begins_with("▾"), "the opened header reads as expanded")
	var deepest := ""
	for sec_child in menu.test_scroll.get_child(0).get_children():
		if sec_child is Button and sec_child.visible and sec_child.text != "← Back" \
				and not sec_child.text.begins_with("▸") \
				and not sec_child.text.begins_with("▾"):
			deepest = sec_child.text
	check(deepest != "", "opening a section reveals its scenario buttons")
	check(_find_button(menu, deepest) != null,
		"the LAST scenario of the LAST section is reachable, not clipped (%s)" % deepest)

	# Back returns to the main menu
	check(await _click_button(menu, "← Back"), "Back button clickable")
	await process_frame
	check(_find_button(menu, "Play") != null, "Back restores the main menu")
	check(_find_button(menu, "← Back") == null, "scenario list hidden again")

	# a scenario button loads its config into the game boot slot
	await _click_button(menu, "TEST")
	await process_frame
	GameScript.next_config = {}
	# `deepest` rather than a named scenario: it is inside the section opened
	# above, so this also proves the expanded state SURVIVES Back-and-reopen —
	# Back only hides the list, it does not rebuild it.
	check(await _click_button(menu, deepest), "scenario button clickable")
	await process_frame
	check(not GameScript.next_config.is_empty(), "scenario click stages its config")

	# Play opens the army select; picking an army stages a fresh run.
	# Fresh menu: the scenario click above tried to change the scene.
	menu.queue_free()
	await process_frame
	menu = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	check(await _click_button(menu, "Play"), "Play button clickable")
	await process_frame
	check(_find_button(menu, "The Muster") != null, "Play opens the army select") # issue
		# 67: "Crown" is still the save id (Tuning.ARMIES key) — the BUTTON now
		# shows the Army's display name, "The Muster" ("The Levy" was vetoed)
	check(await _click_button(menu, "← Back"), "army Back clickable")
	await process_frame
	check(_find_button(menu, "Play") != null, "army Back restores the main menu")
	await _click_button(menu, "Play")
	await process_frame
	GameScript.next_army = ""
	check(await _click_button(menu, "Wild Hunt"), "army button clickable")
	await process_frame
	check(GameScript.next_army == "Wild Hunt", "army click stages its stock")

	# tier select: shown after the army, locked for the run (07-difficulty-ranks)
	check(_find_button(menu, "Tier 1") != null, "army click opens the tier select")
	check(_find_button(menu, "Tier 5") != null, "tier select offers all 5 tiers")
	check(await _click_button(menu, "← Back"), "tier Back clickable")
	await process_frame
	check(_find_button(menu, "Wild Hunt") != null, "tier Back restores the army select")
	await _click_button(menu, "Wild Hunt")
	await process_frame
	GameScript.next_tier = ""
	check(await _click_button(menu, "Tier 3"), "tier button clickable")
	await process_frame
	check(GameScript.next_tier == "Tier 3", "tier click stages the run's difficulty")

	# Scores opens the local high-score list (fresh menu again: the tier
	# click above changed the scene). The tier click's change_scene_to_file
	# is deferred, so the Game it loaded is still root's current_scene here —
	# free it too, or its full-rect HUD keeps intercepting clicks that land
	# near the screen bottom (found via the Guide panel's Back, 05-menus).
	menu.queue_free()
	if current_scene and current_scene != menu:
		current_scene.queue_free()
		current_scene = null
	await process_frame
	var f := FileAccess.open(GameScript.SCORES_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify([{"score": 512, "wave": 7, "kings": 0}]))
	f = null
	menu = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	check(await _click_button(menu, "Scores"), "Scores button clickable")
	await process_frame
	# issue 85: the board says WHICH board it is. An unreachable cloud is the
	# normal case, so it must read as a state rather than look like an error.
	check(_find_label(menu, "Local scores") != null or _find_label(menu, "Cloud scores") != null,
		"the Scores screen states whether cloud scores are included")
	await process_frame
	check(_find_label(menu, "512") != null, "score list shows the stored run")
	check(await _click_button(menu, "← Back"), "scores Back clickable")
	await process_frame
	check(_find_button(menu, "Play") != null, "scores Back restores the main menu")
	DirAccess.remove_absolute(GameScript.SCORES_PATH)

	# Games History: per-run log, distinct from the top-10 Highscores above
	var hf := FileAccess.open(GameScript.HISTORY_PATH, FileAccess.WRITE)
	hf.store_string(JSON.stringify(
		[{"score": 77, "wave": 4, "kings": 0, "tariffs": 1, "lost": 2, "won": false}]))
	hf = null
	check(await _click_button(menu, "Games History"), "Games History button clickable")
	await process_frame
	check(_find_label(menu, "77") != null, "history list shows the stored run")
	check(await _click_button(menu, "← Back"), "history Back clickable")
	await process_frame
	check(_find_button(menu, "Play") != null, "history Back restores the main menu")
	DirAccess.remove_absolute(GameScript.HISTORY_PATH)

	# Guide: shared rules reference (identical copy lives in the in-game menu)
	check(await _click_button(menu, "Guide"), "Guide button clickable")
	await process_frame
	check(_find_label(menu, "Objective") != null, "Guide panel shows its rules text")
	check(await _click_button(menu, "← Back"), "Guide Back clickable")
	await process_frame
	check(_find_button(menu, "Play") != null, "Guide Back restores the main menu")

	# About: credits/version
	check(await _click_button(menu, "About"), "About button clickable")
	await process_frame
	check(_find_label(menu, "NO KINGS") != null, "About panel shows its heading")
	check(await _click_button(menu, "← Back"), "About Back clickable")
	await process_frame
	check(_find_button(menu, "Play") != null, "About Back restores the main menu")

	# Settings: the Sound toggle round-trips to user://settings.json (clean
	# slate came from the SETTINGS_PATH wipe at the top) — the shell 06
	# (animations) and 07 (difficulty) hang their own rows off
	check(await _click_button(menu, "Settings"), "Settings button clickable")
	await process_frame
	check(await _click_button(menu, "Sound: On"), "Sound toggle clickable")
	await process_frame
	check(not Settings.load_settings().sound_on, "Sound toggle persists to disk")
	check(await _click_button(menu, "Animations: On"), "Animations toggle clickable")
	await process_frame
	check(not Settings.load_settings().animations_on, "Animations toggle persists to disk")
	check(await _click_button(menu, "← Back"), "Settings Back clickable")
	await process_frame
	check(_find_button(menu, "Play") != null, "Settings Back restores the main menu")
	DirAccess.remove_absolute(Settings.SETTINGS_PATH)

	# --- issue 83: the login screen itself ---
	# Driven through, not bypassed. --skip-login exists for the CLI, but a
	# bypass that is the ONLY tested path is exactly how this repo once shipped
	# a fully dead main menu (CLAUDE.md, "UI first, bypasses second").
	menu.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Account.ACCOUNT_PATH))
	Account._reset_cache()
	check(Account.needs_login(), "a fresh install is back to needing login")
	var fresh: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(fresh)
	await process_frame
	await process_frame
	check(_find_button(fresh, "Play") == null,
		"the login screen is IN FRONT of the main menu, not beside it")
	check(_find_button(fresh, "Play as Guest") != null, "the login screen renders")
	check(_find_button(fresh, "Sign in with Google") != null, "Google sign-in offered")
	# GAME CENTER, not "Apple" — "Sign in with Apple" is a different Apple
	# service, and naming it that sent a live tester looking for a Game Center
	# app that has not existed since iOS 10. (issue 87)
	check(_find_button(fresh, "Sign in with Game Center") != null,
		"Game Center sign-in offered, under its real name")
	# desktop has no backend, so this must say so rather than appear to work
	check(await _click_button(fresh, "Sign in with Google"), "Google button clickable")
	await process_frame
	check(_find_label(fresh, "isn\'t available") != null,
		"an unavailable backend says so instead of silently doing nothing")
	check(Account.needs_login(), "and a failed sign-in creates NO account")
	check(await _click_button(fresh, "Play as Guest"), "Guest button clickable")
	await process_frame
	check(_find_button(fresh, "Play") != null, "Guest reaches the main menu")
	check(not Account.needs_login(), "Guest created a real account")

	# ---- LOG OUT: the two-step confirm, driven through the real panel --------
	# The guest above cannot see this row at all (Account.logout refuses a
	# guest), so sign in first — that is also the only state where the button is
	# meant to exist.
	fresh.queue_free()
	await process_frame
	Account.sign_in(Account.GOOGLE, "probe-logout-id", [])
	var out: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(out)
	await process_frame
	await process_frame
	check(await _click_button(out, "Settings"), "Settings opens")
	await process_frame
	check(_find_button(out, "Log out") != null, "a signed-in account is offered Log out")
	check(await _click_button(out, "Log out"), "Log out clickable")
	await process_frame
	# CONFIRMATION, not a hair trigger: the first press must ask, never act.
	check(_find_button(out, "Cancel") != null, "it asks before doing anything")
	check(not Account.needs_login(), "and nothing has happened yet")
	check(await _click_button(out, "Cancel"), "Cancel clickable")
	await process_frame
	check(not Account.needs_login(), "cancelling leaves the account signed in")
	check(_find_button(out, "Log out") != null, "and the row returns to its resting state")
	# Now go through with it.
	check(await _click_button(out, "Log out"), "Log out clickable again")
	await process_frame
	check(await _click_button(out, "Log out"), "confirming is a second, separate press")
	await process_frame
	check(Account.needs_login(), "confirmed logout ends the session")
	check(_find_button(out, "Play as Guest") != null,
		"and lands on the login screen, with its guest exit relabelled for a device with nothing to continue")

	print("---")
	if fails == 0:
		print("ALL MENU CLICKS OK")
	quit(1 if fails > 0 else 0)


## First visible Label whose text contains `needle`.
func _find_label(node: Node, needle: String) -> Label:
	if node is Label and needle in node.text and node.is_visible_in_tree():
		return node
	for c in node.get_children():
		var hit := _find_label(c, needle)
		if hit:
			return hit
	return null
