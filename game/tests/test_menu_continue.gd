extends SceneTree
## NO-88: Continue must appear when a cloud restore lands AFTER the menu is built.
##
## On a fresh install the menu has to exist before the player can sign in, so
## the run snapshot always lands post-menu — and it was written to disk with
## nothing re-checking the button. Seen on an iPhone (build e8160ab): the save
## was on disk, Continue only showed after a relaunch.
##
## Driven through the bridge's own `snapshot_loaded` signal — the path both
## platforms share (menu.gd connects to whichever bridge autoload exists) — and
## asserted on the VISIBLE control, never on a flag.

const GameScript := preload("res://scripts/game.gd")
const Account := preload("res://scripts/account.gd")
const CloudSave := preload("res://scripts/cloud_save.gd")
const SyncQueue := preload("res://scripts/sync_queue.gd")
const Memory := preload("res://scripts/cloud/cloud_backend_memory.gd")
const SaveConfig := preload("res://scripts/save_config.gd")

const RUN := {"save_version": SaveConfig.SAVE_VERSION, "wave": 2, "score": 500,
	"gold": 50, "seed": 1, "board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]]}

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


func _menu() -> Node:
	var m: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m


func _init() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: menu-continue suite still running after 120s")
		quit(1))
	Account._reset_cache()
	Account.start_guest()
	# The queue is on disk and shared across suites: an earlier suite that ended a
	# real run against the desktop Noop backend leaves a "run" TOMBSTONE queued,
	# and the menu drains it into the backend at boot — before the sync — which
	# replaces the cloud run below with null. Verified: that alone fails the
	# first case under run_all while it passes standalone.
	SyncQueue.clear()
	var prev_backend = CloudSave.backend
	CloudSave.backend = Memory
	# ---- restore lands BEFORE the menu builds (the boot sync) ---------------
	DirAccess.remove_absolute(GameScript.SAVE_PATH)
	Memory.reset()
	Memory.push("run", {"ts": 1, "data": RUN})
	var early: Node = await _menu()
	check(_find_button(early, "Play") != null, "precondition: the main menu is up")
	check(_find_button(early, "Continue") != null,
		"a restore already in the cloud at boot shows Continue")
	# autoloads are not in the tree yet at _init; look the bridge up once they are
	var bridge: Node = root.get_node("PlayGamesBridge")
	early.queue_free()
	await process_frame

	# ---- restore lands AFTER the menu is built (sign-in on a fresh device) --
	DirAccess.remove_absolute(GameScript.SAVE_PATH)
	Memory.reset()
	var late: Node = await _menu()
	check(_find_button(late, "Continue") == null,
		"precondition: no save anywhere, so no Continue")
	Memory.push("run", {"ts": 1, "data": RUN})
	bridge.snapshot_loaded.emit("run")
	await process_frame
	check(FileAccess.file_exists(GameScript.SAVE_PATH),
		"precondition: the snapshot was mirrored to disk")
	var btn := _find_button(late, "Continue")
	check(btn != null, "THE DEFECT: Continue appears once the restore lands, no relaunch")
	if btn != null:
		GameScript.next_config = {}
		btn.pressed.emit()
		check(int(GameScript.next_config.get("wave", 0)) == 2,
			"...and pressing it stages the RESTORED run, not a stale read")
	late.queue_free()
	await process_frame
	# the press above scheduled a scene change; drop whatever it booted
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame

	DirAccess.remove_absolute(GameScript.SAVE_PATH)
	GameScript.next_config = {}
	Memory.reset()
	SyncQueue.clear()
	CloudSave.backend = prev_backend
	Account._reset_cache()
	print("---")
	print("ALL MENU CONTINUE CHECKS OK" if fails == 0 else "MENU CONTINUE FAILURES: %d" % fails)
	quit(1 if fails > 0 else 0)
