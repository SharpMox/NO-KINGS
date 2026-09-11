extends SceneTree
## UI click probe: boots the real menu and injects synthetic mouse clicks at
## button centers, asserting the UI responds. Catches invisible-overlay /
## mouse-filter bugs that logic tests and screenshots cannot. Needs a window —
## Godot 4.6 headless drops GUI picking (verified). Run:
##   godot --path game -s tests/test_menu_clicks.gd

const GameScript := preload("res://scripts/game.gd")
const MenuScript := preload("res://scripts/menu.gd")
const Settings := preload("res://scripts/settings.gd")
const Account := preload("res://scripts/account.gd")
const MemoryBackend := preload("res://scripts/cloud/cloud_backend_memory.gd")
const CloudSave := preload("res://scripts/cloud_save.gd")

## NO-55: the owner id this probe binds is a REAL 64-character Game Center id,
## not a short label, because the defect is about WIDTH. The earlier
## "probe-owner-a" was 13 characters and fitted comfortably in a 480px viewport,
## so a layout assertion written against it would have passed with the bug still
## in place — verified by disabling the fix and watching it stay green. The
## measured device failure was 792-797px of content in that viewport.
const OWNER_64 := "A26B4668036156E12DCCA5EE5856704F3F55F827CEE5720427156111D3F55F82"

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

	# NO-56: Quit is offered on every platform that can honour it and on no
	# platform that cannot. Written as the invariant rather than as "Quit
	# exists", because the rule is the gate: iOS cannot self-terminate, so a
	# Quit button there is a dead control. The suite only ever runs off-iOS, so
	# what this actually guards is the other half — that gating it did not
	# delete it from desktop and Android, which is what NO-56 explicitly rules
	# against. The iOS half is unobservable from here and is not claimed.
	check((_find_button(menu, "Quit") != null) == (not MenuScript._IS_IOS()),
		"Quit is offered exactly on the platforms that can quit")

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

	# ---- NO-58: the search box -----------------------------------------------
	# The complaint: the hand-written scenarios — the ones that exist FOR hand
	# testing — are named distinctively, so each is usually a section of one, so
	# all of them fold into "Other" at the very bottom behind fifty sections.
	# Measured: 385 scenarios, 50 sections, 16 singletons, and all 16 are
	# hand-written. A search is what makes them reachable.
	check(menu.test_filter != null, "the TEST list has a search box")
	# The trap this guards: a text field that focuses itself on show swallows
	# every keystroke this probe sends, which is why the seed field carries the
	# same focus_mode line. SAY WHAT IT IS WORTH: removing focus_mode =
	# FOCUS_CLICK does NOT make this fail — a LineEdit does not grab focus just
	# by being added to the tree — so this is insurance against a future
	# grab_focus(), not evidence that the current line is doing anything. The
	# line stays because FOCUS_ALL also puts the field in the Tab order.
	check(not menu.test_filter.has_focus(),
		"...and it does NOT take focus on show — a focused field eats the probe's input")

	# Pick a target the way a person would be stuck: a row in a COLLAPSED
	# section, found by its full name rather than by opening anything. Chosen
	# from the data rather than hardcoded, so renaming a scenario cannot rot it.
	var buried: Button = null
	for sec_dict in menu._test_sections:
		if sec_dict.head.text.begins_with("▾"):
			continue # this one is open; the point is to reach a closed one
		for r: Button in sec_dict.rows:
			if not r.visible:
				buried = r
				break
		if buried != null:
			break
	check(buried != null, "found a scenario inside a collapsed section")
	var buried_name: String = str(buried.get_meta("scenario_name"))
	menu.test_filter.text = buried_name
	menu._apply_test_filter()
	await process_frame
	check(buried.visible,
		"typing its name reveals a scenario WITHOUT opening its section (%s)" % buried_name)
	# ...and the rest of the list is gone, which is what makes it findable.
	var still_up := 0
	for sec_dict in menu._test_sections:
		for r: Button in sec_dict.rows:
			if r.visible:
				still_up += 1
	check(still_up < 20, "and the other 380-odd are filtered out (%d left)" % still_up)
	check("of" in menu.test_head.text,
		"the heading counts the matches rather than the catalog (%s)" % menu.test_head.text)

	# MATCH THE FULL NAME, NOT THE ROW LABEL. _test_row_text strips the section
	# prefix, so "Artefacts: Tinfoil Hat" renders as "Tinfoil Hat" — searching
	# the label would never find anything by its section. Only assert this where
	# a stripped row actually exists.
	var stripped: Button = null
	for sec_dict in menu._test_sections:
		for r: Button in sec_dict.rows:
			var full: String = str(r.get_meta("scenario_name"))
			if full != r.text and full.length() > r.text.length():
				stripped = r
				break
		if stripped != null:
			break
	if stripped != null:
		var prefix: String = str(stripped.get_meta("scenario_name")) \
			.substr(0, str(stripped.get_meta("scenario_name")).length() - stripped.text.length())
		prefix = prefix.strip_edges().trim_suffix(":").strip_edges()
		menu.test_filter.text = prefix
		menu._apply_test_filter()
		await process_frame
		check(stripped.visible,
			"searching the SECTION half of a name finds it, though the row does not show it (%s)"
				% prefix)

	# Clearing restores exactly the previous behaviour — the search is an
	# addition, not a replacement.
	menu.test_filter.text = ""
	menu._apply_test_filter()
	await process_frame
	check(not buried.visible, "clearing the box collapses the list again")
	check(_find_button(menu, deepest) != null,
		"...and the section that was open before the search is still open")

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
	# ...AND the Game that the scene change actually created. This probe rebuilt
	# the menu but left the game sitting in the tree as a sibling, where its HUD
	# draws over the menu. It went unnoticed while the HUD's only bottom control
	# was a 42px bar down at y754; design C's deck reaches y524 on this viewport,
	# so it began swallowing clicks aimed at the menu's own Back button at y540.
	# The two never coexist in the real app — change_scene frees one.
	for stray in root.get_children():
		if stray.name == "Game":
			stray.queue_free()
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
		[{"score": 77, "wave": 4, "kings": 0, "king_abilities": 1, "lost": 2, "won": false}]))
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

	# ---- NO-31: an account switch ASKS before it rebinds ---------------------
	# NO-11 called Account.switch_to straight from the verdict handler, on every
	# verdict including the silent boot check, so a device whose account changed
	# re-homed the install with nothing on screen saying so. Drive a mismatched
	# verdict and pin that the rebind waits for an answer.
	#
	# The memory backend reports a FIXED account_id ("memory-account"), so signing
	# in as anything else and then handing the menu a successful verdict IS the
	# mismatch, with no device involved (the pattern PR #338 established).
	out.queue_free()
	await process_frame
	var prev_backend = CloudSave.backend
	CloudSave.backend = MemoryBackend
	Account._reset_cache()
	Account.sign_in(Account.GOOGLE, OWNER_64, [])
	var sw: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(sw)
	await process_frame
	await process_frame
	sw._on_sign_in_finished(true)
	await process_frame
	check(Account.owner() == OWNER_64,
		"a mismatched verdict does NOT rebind on its own — switch_to waits for consent")
	check(_find_button(sw, "Switch account") != null
			and _find_button(sw, "Not now") != null,
		"it asks instead, offering both answers")
	var prompt_text := _find_label(sw, "Switch to the new account?")
	# A PREFIX of the owner id, not the whole thing: it has no recorded name, so
	# it falls back to its id — and NO-54 then shortens that id to what fits.
	check(prompt_text != null and OWNER_64.substr(0, 20) in prompt_text.text
			and "Memory Player" in prompt_text.text,
		"and the prompt NAMES BOTH accounts — \"an account changed\" is not answerable")
	# NO-54: and it names them by DISPLAY NAME, not by id. Both halves of the
	# rule are in that one assertion: the live account shows the backend's name
	# ("Memory Player", not its id "memory-account"), and the owner — bound
	# above with no name recorded — falls back to its id. This line pins the
	# fallback explicitly, because the useful failure is showing a BLANK where a
	# nameless account should show its id.
	check(prompt_text != null and not ("memory-account" in prompt_text.text),
		"the live account is named, not identified — no raw id where a name exists")

	# NO-55: the layout consequence, which is what actually reached the player.
	# A Label with AUTOWRAP_OFF reports its full text width as its MINIMUM, a
	# VBox takes the max of its children and CenterContainer does not clamp — so
	# a long line pushed the whole menu sideways, measured at 792-797px in a 480
	# viewport, with "NO KINGS" clipped off the left edge.
	#
	# Asserted on the RENDERED RECTS of the menu's own controls rather than on
	# any property of the label: the property is the mechanism, the rects are
	# what a player sees. Checked while the prompt is UP — hidden children
	# contribute no minimum size, so a check with it closed proves nothing.
	var vp_w: float = root.get_visible_rect().size.x
	var widest := 0.0
	var leftmost := vp_w
	for ctrl in _controls(sw):
		var r := ctrl.get_global_rect()
		widest = maxf(widest, r.size.x)
		leftmost = minf(leftmost, r.position.x)
	# VERIFIED TO HAVE BITE: with _wrap_account_text disabled this reads 643,
	# and with the value-level truncation disabled too it reads 693.
	check(widest <= vp_w,
		"no menu control is wider than the screen with the prompt up (%.0f <= %.0f)"
			% [widest, vp_w])
	# The left edge is the symptom Max actually reported ("NO KINGS" clipped, the
	# N cut by the screen edge). Kept as a guard, but SAY WHAT IT IS: it did NOT
	# fail in either negative control above — with the fix removed this fixture's
	# overflow all went right, leftmost stayed 0 — so the width assertion is the
	# one carrying the weight here and this one is insurance, not evidence.
	check(leftmost >= 0.0,
		"and nothing is pushed off the left edge — the title is not clipped (x=%.0f)" % leftmost)
	# NO-54, the value half of the ruling ("shortened if long"). Asserted on the
	# function rather than through the UI because the memory backend's name is
	# fixed: what needs pinning is that a pathological name is cut, and cut on
	# MEASURED WIDTH — the string below is 300 CJK characters, which no
	# character-count cap tuned for Latin text would size correctly.
	var monster: String = "山".repeat(300)
	var fitted: String = sw._who(sw.switch_prompt_label, monster, "")
	check(fitted.length() < monster.length() and fitted.ends_with("…"),
		"a pathological display name is truncated, with an ellipsis (%d -> %d chars)"
			% [monster.length(), fitted.length()])
	var fitted_font: Font = sw.switch_prompt_label.get_theme_font("font")
	var fitted_w: float = fitted_font.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT,
		-1, sw.switch_prompt_label.get_theme_font_size("font_size")).x
	check(fitted_w <= vp_w,
		"...and what is left actually FITS the screen (%.0f <= %.0f)" % [fitted_w, vp_w])
	check(sw._who(sw.switch_prompt_label, "", "short-id") == "short-id",
		"an account with no recorded name falls back to its id, never to a blank")

	# Decline: pre-NO-11 behaviour for the session, but said out loud.
	check(await _click_button(sw, "Not now"), "Not now clickable")
	await process_frame
	check(Account.owner() == OWNER_64, "declining does not rebind")
	check(_find_button(sw, "Switch account") == null, "and the prompt closes")
	sw._on_sign_in_finished(true)
	await process_frame
	check(_find_button(sw, "Switch account") == null,
		"a later verdict in the SAME session does not re-ask — declining is not a nag loop")
	check(Account.owner() == OWNER_64, "and still does not rebind")

	# Accept, on a fresh menu — the prompt re-appears on the next boot.
	sw.queue_free()
	await process_frame
	var sw2: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(sw2)
	await process_frame
	await process_frame
	sw2._on_sign_in_finished(true)
	await process_frame
	check(_find_button(sw2, "Switch account") != null,
		"the prompt DOES come back on the next boot")
	check(await _click_button(sw2, "Switch account"), "Switch account clickable")
	await process_frame
	check(Account.owner() == "memory-account",
		"accepting rebinds, through the same Account.switch_to")
	sw2.queue_free()
	await process_frame
	CloudSave.backend = prev_backend
	Account.logout([])
	Account._reset_cache()

	print("---")
	if fails == 0:
		print("ALL MENU CLICKS OK")
	quit(1 if fails > 0 else 0)


## Every visible Control under `node`. Used by the NO-55 layout assertions,
## which are about what is on screen rather than about any one widget.
func _controls(node: Node, out: Array[Control] = []) -> Array[Control]:
	if node is Control and node.is_visible_in_tree():
		out.append(node)
	for c in node.get_children():
		_controls(c, out)
	return out


## First visible Label whose text contains `needle`.
func _find_label(node: Node, needle: String) -> Label:
	if node is Label and needle in node.text and node.is_visible_in_tree():
		return node
	for c in node.get_children():
		var hit := _find_label(c, needle)
		if hit:
			return hit
	return null
