extends SceneTree
## UI click probe: boots the real menu and injects synthetic mouse clicks at
## button centers, asserting the UI responds. Catches invisible-overlay /
## mouse-filter bugs that logic tests and screenshots cannot. Needs a window —
## Godot 4.6 headless drops GUI picking (verified). Run:
##   godot --path game -s tests/test_menu_clicks.gd

const GameScript := preload("res://scripts/game.gd")
const Settings := preload("res://scripts/settings.gd")

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
	var menu: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame

	# TEST opens the scenario list (this click is what PR #20 shipped broken:
	# the hidden submenu's ScrollContainer swallowed every mouse event)
	check(await _click_button(menu, "TEST"), "TEST button visible")
	await process_frame
	check(_find_button(menu, "← Back") != null, "TEST opens the scenario list")

	# Back returns to the main menu
	check(await _click_button(menu, "← Back"), "Back button clickable")
	await process_frame
	check(_find_button(menu, "Play") != null, "Back restores the main menu")
	check(_find_button(menu, "← Back") == null, "scenario list hidden again")

	# a scenario button loads its config into the game boot slot
	await _click_button(menu, "TEST")
	await process_frame
	GameScript.next_config = {}
	check(await _click_button(menu, "King wave (checkmate to win)"), "scenario button clickable")
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
	check(_find_button(menu, "Crown") != null, "Play opens the army select")
	check(await _click_button(menu, "← Back"), "army Back clickable")
	await process_frame
	check(_find_button(menu, "Play") != null, "army Back restores the main menu")
	await _click_button(menu, "Play")
	await process_frame
	GameScript.next_army = ""
	check(await _click_button(menu, "Wild Hunt"), "army button clickable")
	await process_frame
	check(GameScript.next_army == "Wild Hunt", "army click stages its stock")

	# rank select: shown after the army, locked for the run (07-difficulty-ranks)
	check(_find_button(menu, "Citizen") != null, "army click opens the rank select")
	check(await _click_button(menu, "← Back"), "rank Back clickable")
	await process_frame
	check(_find_button(menu, "Wild Hunt") != null, "rank Back restores the army select")
	await _click_button(menu, "Wild Hunt")
	await process_frame
	GameScript.next_rank = ""
	check(await _click_button(menu, "Officer"), "rank button clickable")
	await process_frame
	check(GameScript.next_rank == "Officer", "rank click stages the run's difficulty")

	# Scores opens the local high-score list (fresh menu again: the rank
	# click above changed the scene). The rank click's change_scene_to_file
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
