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
const Connectivity := preload("res://scripts/connectivity.gd")
const GlobalBoard := preload("res://scripts/global_board.gd")
const PlayBridge := preload("res://scripts/cloud/play_games_bridge.gd")


## NO-64: a platform board that exists, so the Scores door is built on desktop.
class FakeBoard:
	static func board_available() -> bool:
		return true

	static func board_show(_board: String) -> bool:
		return true

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


## NO-179: the carousel's own cards — one PanelContainer per Army, direct
## children of army_row (the two end spacers are bare Controls, not
## PanelContainers, so no further filter is needed).
func _army_cards(node: Node) -> Array[PanelContainer]:
	var out: Array[PanelContainer] = []
	if node is PanelContainer:
		out.append(node)
	for c in node.get_children():
		out.append_array(_army_cards(c))
	return out


## The carousel's own ScrollContainer (army_scroll in menu.gd), not exposed
## as a member — found the same way _army_cards finds its PanelContainers.
func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for c in node.get_children():
		var found := _find_scroll(c)
		if found != null:
			return found
	return null


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
	return await _click_control(btn)


## NO-190: the tier buttons carry no text any more, so they can't be found
## by _find_button — the caller looks them up via menu._tier_buttons instead
## and clicks the Control directly. Same scroll-into-view + click logic
## _click_button uses, factored out so neither path can drift from the other.
func _click_control(ctrl: Control) -> bool:
	if ctrl == null or not ctrl.is_visible_in_tree():
		return false
	var p: Node = ctrl.get_parent()
	while p: # bring buttons inside scroll lists into the viewport first
		if p is ScrollContainer:
			p.ensure_control_visible(ctrl)
			await process_frame
			break
		p = p.get_parent()
	_click(ctrl.get_global_rect().get_center())
	return true


## NO-194: this file has no shared _boot() helper — every fixture below sets
## GameScript.next_config directly, so each boot calls reset_boot_defaults()
## right before it, rather than inheriting a reset from one funnel. Not an
## oversight; see game.gd's reset_boot_defaults() doc comment.
func _init() -> void:
	# Watchdog: a SCRIPT ERROR mid-run kills this coroutine and quit() below
	# never fires, leaving the window open until a human closes it (user
	# report 2026-07-12). Force-quit instead; normal runs finish long before.
	# NO-192: raised from 120s. Must stay below run_all.sh's TIMEOUT (600s) or
	# the runner kills the process first and the tail of this probe's log is lost.
	create_timer(240.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: probe still running after 240s — force quit")
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

	# NO-147 (Max, 2026-09-19): Quit is REMOVED on every platform — "people
	# can just close the app." Android's hardware Back already quits from the
	# bare main menu (NO-61), so the button only duplicated a platform
	# affordance every player already has.
	check(_find_button(menu, "Quit") == null, "NO-147: Quit is gone, on every platform")

	# TEST opens the scenario list (this click is what PR #20 shipped broken:
	# the hidden submenu's ScrollContainer swallowed every mouse event).
	# NO-147: TEST now nests inside Settings, reached in two taps.
	check(await _click_button(menu, "Settings"), "Settings button clickable")
	await process_frame
	check(await _click_button(menu, "TEST"), "NO-147: TEST reached from Settings")
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
		# "Device info" is a fixed row beside Back, not a scenario section —
		# same exclusion as "← Back".
		if sec_child is Button and sec_child.visible and sec_child.text != "← Back" \
				and sec_child.text != "Device info" \
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
				and sec_child.text != "Device info" \
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

	# Back returns to the Settings panel TEST was opened from — NO-147: TEST
	# nests under Settings now, same "Back lands one level up" shape the tier
	# picker already carried for returning to the army picker.
	check(await _click_button(menu, "← Back"), "Back button clickable")
	await process_frame
	check(_find_button(menu, "Sound: On") != null, "Back restores the Settings panel")
	check(not menu.test_scroll.visible, "scenario list hidden again")

	# a scenario button loads its config into the game boot slot. Settings is
	# still the visible panel from the Back above, so TEST is reachable again.
	await _click_button(menu, "TEST")
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
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
	# NO-179 (Max: "just make a normal carousel with out changing any
	# dimensions of the other cards"): every card renders at the SAME size,
	# full scale, always — no per-card scaling. A neighbour simply extends
	# past the scroller's own viewport edge. Geometry, not a flag: assert
	# equal sizes/scale, then scroll to a middle Army and assert both
	# neighbours are genuinely PARTIALLY on screen (part inside the
	# viewport, part cropped by it), while the resting card is fully clear.
	await process_frame # menu.gd's _show_armies awaits one frame for the
		# deferred container sort before reading real geometry; give it one.
	var cards := _army_cards(menu.army_center)
	check(cards.size() > 2, "the carousel built more than two cards")
	if cards.size() > 2:
		for c in cards:
			check(c.size.is_equal_approx(cards[0].size), "every card is the same size")
			check(c.scale.is_equal_approx(Vector2.ONE), "no card is scaled")
		var scroll := _find_scroll(menu.army_center)
		# Same scroll target the page dots use (menu.gd: dot.pressed) — land
		# on Army 1 so it has a real neighbour on both sides.
		var card_w: float = cards[0].size.x
		scroll.scroll_horizontal = int(card_w + MenuScript.ARMY_CARD_MARGIN)
		await process_frame
		var viewport: Rect2 = scroll.get_global_rect()
		var prev_overlap: Rect2 = viewport.intersection(cards[0].get_global_rect())
		var next_overlap: Rect2 = viewport.intersection(cards[2].get_global_rect())
		check(prev_overlap.size.x > 0.0 and prev_overlap.size.x < cards[0].size.x,
			"the previous Army's card peeks in on the left, partially cropped")
		check(next_overlap.size.x > 0.0 and next_overlap.size.x < cards[2].size.x,
			"the next Army's card peeks in on the right, partially cropped")
		var resting_overlap: Rect2 = viewport.intersection(cards[1].get_global_rect())
		check(is_equal_approx(resting_overlap.size.x, cards[1].size.x),
			"the resting card is fully visible, uncropped")
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
	# NO-190: the "Tier N" text is gone from the row buttons (Max), so
	# _find_button can no longer locate them — the walk reads menu._tier_buttons
	# directly instead (same convention test_menu_clicks already uses for
	# _selected_tier), which is a stronger check than a text lookup: it proves
	# the picker built exactly 5 tier rows, not just that some button somewhere
	# says "Tier 5".
	check(menu._tier_buttons.size() == 5, "army click opens the tier select, with all 5 tiers")
	check(menu._tier_buttons[0].is_visible_in_tree(), "tier row is a real, visible tap target")
	# NO-212: the tap button is now a full-panel overlay (a direct sibling of
	# the description Label inside tier_panel, not a wrapper two levels up —
	# see menu.gd), so the button's own parent IS the panel.
	# fix/tier-bg-and-tip-centring: _update_tier_outline built a StyleBoxFlat
	# and never set bg_color, so every tier row rendered Godot's default flat
	# light grey. Assert the actual bg_color, not merely that a stylebox
	# exists (a read-back of a value just written would pass even if the fix
	# were reverted to a different, still-wrong colour).
	var tier_panel := menu._tier_buttons[0].get_parent() as PanelContainer
	var tier_sb := tier_panel.get_theme_stylebox("panel") as StyleBoxFlat
	check(tier_sb != null and tier_sb.bg_color == menu.NESTED_PANEL_TINT,
		"tier panel background is the dark nested-panel tint, not Godot's default flat grey")
	# NO-212: each row's description text must start level with its own
	# icon (Max: "aligned to its red icon piece") — assert the LIVE rects
	# after an idle frame, not a size-flag read-back (CLAUDE.md: "Assert the
	# observable consequence, never the flag that was just written" — a
	# previous attempt set SIZE_SHRINK_BEGIN on the icon alone and shipped
	# with the text still displaced, which a flag check would have missed).
	await process_frame
	for i in menu._tier_buttons.size():
		var panel := menu._tier_buttons[i].get_parent() as PanelContainer
		var row := panel.get_parent() as HBoxContainer
		var icon: Control = row.get_child(0).get_child(0) # icon wrap -> TextureRect
		var desc: Label = null
		for c in panel.get_children():
			if c is Label:
				desc = c
				break
		var icon_top := icon.get_global_rect().position.y
		var desc_top := desc.get_global_rect().position.y
		# tolerance covers the panel's own 8px top content margin (the
		# icon sits outside the panel and has none) — not slack for drift.
		check(absf(icon_top - desc_top) <= 10.0,
			"tier %d description top aligns with its icon (icon %.1f, text %.1f)" % [i, icon_top, desc_top])
	check(await _click_button(menu, "← Back"), "tier Back clickable")
	await process_frame
	check(_find_button(menu, "Wild Hunt") != null, "tier Back restores the army select")
	await _click_button(menu, "Wild Hunt")
	await process_frame
	GameScript.next_tier = ""
	# NO-190: Confirm replaces the old select-then-confirm second tap. A tier
	# tap now only ever selects — so tapping Tier 3 (index 2) twice must NOT
	# stage a run any more; only Confirm does. That is a stronger walk than
	# the old one, not weaker: it proves both that a tap never launches by
	# itself AND that Confirm launches using whatever tier is selected.
	check(await _click_control(menu._tier_buttons[2]), "tier button clickable")
	await process_frame
	check(menu._selected_tier == 2, "tap selects Tier 3 (0-based index)")
	check(GameScript.next_tier == "", "selecting a tier does not stage a run yet")
	check(await _click_control(menu._tier_buttons[2]), "re-tapping the selected tier is clickable")
	await process_frame
	check(GameScript.next_tier == "", "re-tapping a tier still does not stage a run — Confirm does")
	check(await _click_button(menu, "Confirm"), "Confirm button clickable")
	await process_frame
	check(GameScript.next_tier == "Tier 3", "Confirm stages the run with the selected tier")

	# Scores opens the local high-score list (fresh menu again: the Confirm
	# click above changed the scene). Its change_scene_to_file
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
	# NO-147: Games History folds into Scores, so its fixture is written up
	# front too — the walk below goes Scores -> Games History -> back to
	# Scores -> back to the main menu.
	var hf := FileAccess.open(GameScript.HISTORY_PATH, FileAccess.WRITE)
	hf.store_string(JSON.stringify(
		[{"score": 77, "wave": 4, "kings": 0, "king_abilities": 1, "lost": 2, "won": false}]))
	hf = null
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
	check(await _click_button(menu, "Games History"), "NO-147: Games History reached from Scores")
	await process_frame
	check(_find_label(menu, "77") != null, "history list shows the stored run")
	check(await _click_button(menu, "← Back"), "history Back clickable")
	await process_frame
	check(_find_label(menu, "512") != null,
		"NO-147: history's Back restores Scores, not the main menu directly")
	check(await _click_button(menu, "← Back"), "scores Back clickable")
	await process_frame
	check(_find_button(menu, "Play") != null, "scores Back restores the main menu")
	DirAccess.remove_absolute(GameScript.SCORES_PATH)
	DirAccess.remove_absolute(GameScript.HISTORY_PATH)

	# Guide: NO-189 turned this into a hub of 7 entries (Rules + six catalog
	# pages) — one navigation level deeper than before, matching the tier
	# picker and TEST list's own "Back lands one level up" shape. The walk
	# now goes one level further in and back out, rather than landing
	# straight on the rules text the old flat panel showed immediately.
	check(await _click_button(menu, "Guide"), "Guide button clickable")
	await process_frame
	check(_find_button(menu, "Rules") != null, "Guide hub offers Rules")
	check(_find_button(menu, "Pieces") != null, "Guide hub offers Pieces")
	check(_find_button(menu, "Indicators") != null, "Guide hub offers Indicators")
	check(await _click_button(menu, "Rules"), "Rules button clickable")
	await process_frame
	check(_find_label(menu, "Objective") != null, "Rules page shows its rules text")
	check(await _click_button(menu, "← Back"), "Rules Back clickable")
	await process_frame
	check(_find_button(menu, "Rules") != null, "Rules Back restores the Guide hub, not the main menu")
	check(await _click_button(menu, "← Back"), "Guide hub Back clickable")
	await process_frame
	check(_find_button(menu, "Play") != null, "Guide hub Back restores the main menu")

	# About: credits/version. NO-147: folds into Settings.
	check(await _click_button(menu, "Settings"), "Settings button clickable (About)")
	await process_frame
	check(await _click_button(menu, "About"), "NO-147: About reached from Settings")
	await process_frame
	check(_find_label(menu, "NO KINGS") != null, "About panel shows its heading")
	check(await _click_button(menu, "← Back"), "About Back clickable")
	await process_frame
	check(_find_button(menu, "Sound: On") != null,
		"NO-147: About's Back restores Settings, not the main menu directly")
	check(await _click_button(menu, "← Back"), "Settings Back clickable (About)")
	await process_frame
	check(_find_button(menu, "Play") != null, "Settings Back restores the main menu")

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
	# NO-76: the owner has no recorded name, so it is called "this device's
	# account" — not its id, not even a prefix of it. The iPhone showed the
	# full 64-hex id; no player recognises that as theirs.
	check(prompt_text != null and "this device's account" in prompt_text.text
			and "Memory Player" in prompt_text.text,
		"and the prompt NAMES BOTH accounts — \"an account changed\" is not answerable")
	check(prompt_text != null and not (OWNER_64.substr(0, 20) in prompt_text.text)
			and not ("memory-account" in prompt_text.text),
		"neither account is shown as an id — a name where one exists, a generic label where none does")

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
	check(sw._who(sw.switch_prompt_label, "", "another account") == "another account",
		"an account with no recorded name falls back to the caller's label, never to a blank")

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

	# ---- NO-88: a cloud restore landing AFTER the menu is built ------------
	# The fresh-install case: the menu exists before the player can sign in, so
	# the run snapshot always arrives on an already-built menu. Continue must
	# not only appear (tests/test_menu_continue.gd pins that headlessly) but take
	# a real CLICK — a late-added control is exactly the kind that can land
	# under something else. Driven through the bridge's own signal.
	Account._reset_cache()
	Account.start_guest()
	DirAccess.remove_absolute(GameScript.SAVE_PATH)
	CloudSave.backend = MemoryBackend
	MemoryBackend.reset()
	var late: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(late)
	await process_frame
	await process_frame
	check(_find_button(late, "Continue") == null, "precondition: no save, no Continue")
	MemoryBackend.push("run", {"ts": 1, "data": {
		"save_version": 2, "wave": 2, "gold": 50, "seed": 1,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]]}})
	root.get_node("PlayGamesBridge").snapshot_loaded.emit("run")
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {}
	check(await _click_button(late, "Continue"),
		"NO-88: Continue that appeared after the restore landed is clickable")
	await process_frame
	check(int(GameScript.next_config.get("wave", 0)) == 2,
		"...and the click stages the restored run")
	late.queue_free()
	if current_scene and current_scene != late:
		current_scene.queue_free() # the Game that click booted (deferred change_scene)
		current_scene = null
	await process_frame
	DirAccess.remove_absolute(GameScript.SAVE_PATH)
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {}
	MemoryBackend.reset()
	CloudSave.backend = prev_backend
	Account.logout([])
	Account._reset_cache()

	# ---- NO-64: offline DISABLES network controls, with a reason -------------
	# Detection asks the phone and cannot run here; its CONSEQUENCE can. The
	# state is faked at the seam (Connectivity.override), and the rest is the
	# real menu driven by real clicks.
	#
	# Desktop builds no "Sign in to sync" — PlayBridge.supported() is false with
	# no plugin — so give the bridge a stand-in handle for the duration. Nothing
	# here reaches a call on it: the button is disabled, which is the point.
	Account.start_guest()
	var prev_snapshots = PlayBridge._snapshots
	PlayBridge._snapshots = Node.new()
	GlobalBoard.backend_override = FakeBoard
	Connectivity.override = false
	var off: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(off)
	await process_frame
	await process_frame
	var sync := _find_button(off, "Sign in to sync")
	check(sync != null and sync.disabled,
		"offline: Sign in to sync is still SHOWN, but disabled — not hidden")
	check(_find_label(off, MenuScript.OFFLINE_REASON) != null, "...with the reason on screen")
	await _click_button(off, "Sign in to sync")
	await process_frame
	check(_find_button(off, "Play") != null and not off.login_center.visible,
		"...and pressing it does nothing")

	# The login screen, reached the way a lapsed session would see it.
	off.main_box.visible = false
	off.login_center.visible = true
	await process_frame
	for prov_text in ["Sign in with Google", "Sign in with Game Center"]:
		var pb := _find_button(off, prov_text)
		check(pb != null and pb.disabled, "offline: %s is disabled" % prov_text)
	check(_find_label(off, MenuScript.OFFLINE_REASON) != null, "...with the reason on screen")
	await _click_button(off, "Sign in with Google")
	await process_frame
	check(off.login_note.text == MenuScript.LOGIN_TAGLINE,
		"...and a press starts no sign-in (the note still reads the tagline)")
	# The lock release every verdict path calls must not re-enable them offline.
	off._set_providers_disabled(false)
	check(_find_button(off, "Sign in with Google").disabled,
		"releasing the in-flight sign-in lock does not re-enable a provider offline")
	var way_out := _find_button(off, "Continue offline")
	check(way_out != null and not way_out.disabled, "the way out stays LIVE offline")
	check(await _click_button(off, "Continue offline"), "Continue offline clickable")
	await process_frame
	check(_find_button(off, "Play") != null, "...and it still leaves the login screen")

	# The Scores screen's door to the global board.
	check(await _click_button(off, "Scores"), "Scores opens offline")
	await process_frame
	var door := _find_button(off, "Global ranking")
	check(door != null and door.disabled,
		"offline: Global ranking is shown but disabled (a board exists, the network does not)")
	check(_find_label(off, MenuScript.OFFLINE_REASON) != null, "...with the reason on screen")

	# THE ONE THAT MATTERS MOST: connectivity returns mid-session and the control
	# comes back ON ITS OWN, through the poll — no reopen, no restart. A greyed
	# button that never ungreys is worse than the old behaviour.
	Connectivity.override = true
	await create_timer(1.5).timeout
	check(not door.disabled, "back online: the door re-enables by itself, via the poll")
	check(_find_label(off, MenuScript.OFFLINE_REASON) == null, "...and the reason goes away")
	check(await _click_button(off, "← Back"), "scores Back clickable")
	await process_frame
	check(not _find_button(off, "Sign in to sync").disabled,
		"...and Sign in to sync is live again too")

	# Regaining focus re-asks at once (pulling down Control Center or the shade to
	# toggle airplane mode takes focus from the app), without waiting for a tick.
	Connectivity.override = false
	off.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(_find_button(off, "Sign in to sync").disabled,
		"regaining focus re-checks immediately")

	off.queue_free()
	await process_frame
	Connectivity.override = null
	GlobalBoard.backend_override = null
	PlayBridge._snapshots.free()
	PlayBridge._snapshots = prev_snapshots
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
