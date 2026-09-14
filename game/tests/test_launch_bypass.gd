extends SceneTree
## NO-77: a `--scenario N` / `--autoplay` launch is honoured ONCE. The args last
## for the whole process, and menu.gd used to re-forward to Game.tscn on every
## Menu load — so pause -> Main Menu bounced straight back into a fresh copy of
## the scenario, and Play would have booted the scenario again too.
##
## Needs the real flag on the command line, so run_all.sh passes it:
##   godot --headless --path game -s tests/test_launch_bypass.gd -- --scenario 0

const Account := preload("res://scripts/account.gd")
const Settings := preload("res://scripts/settings.gd")
const GameScript := preload("res://scripts/game.gd")
const SyncQueue := preload("res://scripts/sync_queue.gd")

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
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: launch-bypass suite still running after 120s")
		quit(1))
	check(OS.get_cmdline_user_args().has("--scenario"),
		"precondition: launched with `-- --scenario 0` (else every check below is vacuous)")
	DirAccess.remove_absolute(Settings.SETTINGS_PATH)
	SyncQueue.clear() # NO-88: worktrees share user://, a stale queue drains here
	Account._reset_cache()
	Account.start_guest()
	GameScript.next_seed = "1" # pinned, like every other suite

	# ---- first Menu load: the launch bypass fires ---------------------------
	var menu: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/Game.tscn",
		"the first Menu load honours --scenario and boots the Game")
	var game: Node = current_scene
	check(game != null and game.state == GameScript.State.PLAYER_TURN,
		"...into the scenario's playable turn, not a fresh SETUP")
	menu.queue_free()
	await process_frame

	# ---- second Menu load, same process (pause -> Main Menu) ---------------
	var again: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(again)
	await process_frame
	await process_frame
	await process_frame
	check(current_scene == game,
		"returning to the Menu does NOT boot the scenario again")
	check(_find_button(again, "Play") != null,
		"...and the main menu is actually showing (Play is up)")
	again.queue_free()
	await process_frame

	# ---- Play from that menu: a fresh run, not the scenario ----------------
	GameScript.next_config = {} # what the new-run screen sets before change_scene
	GameScript.is_scenario = false
	var fresh: Node = load("res://scenes/Game.tscn").instantiate()
	root.add_child(fresh)
	await process_frame
	await process_frame
	check(fresh.state == GameScript.State.SETUP,
		"a later Play boots a fresh run (SETUP), not the CLI scenario")
	check(not GameScript.is_scenario,
		"...and it is a real run, not flagged as a scenario")
	fresh.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL GREEN")
	else:
		print("FAILED: %d" % fails)
	quit(1 if fails > 0 else 0)
