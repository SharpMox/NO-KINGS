extends SceneTree
## NO-86: a sign-in verdict on an install with NO owner is a first bind, never
## an account switch. Found on an iPhone 2026-09-13: a fresh install showed the
## "Switch account" prompt, and neither of its buttons could bind anything.
##
## Headless, at the one seam both bridges share — menu._on_sign_in_finished
## (Play Games and Game Center emit the same signal; menu.gd connects whichever
## exists and catches up on its cached verdict). The memory backend reports a
## FIXED account_id ("memory-account"), so which owner is bound BEFORE the
## verdict decides which case each block drives, with no device involved.
##
## Asserted on what the player sees — the bound owner and whether the prompt
## is on screen once the main menu is up — never on the handler's flags.

const Account := preload("res://scripts/account.gd")
const CloudSave := preload("res://scripts/cloud_save.gd")
const MemoryBackend := preload("res://scripts/cloud/cloud_backend_memory.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("ok: ", label)
	else:
		fails += 1
		print("FAIL: ", label)


## The prompt as the player would see it: its Switch button visible IN THE TREE,
## so a prompt raised inside a hidden main_box counts only once main_box shows —
## which is exactly how the iPhone surfaced it.
func _prompt_showing(node: Node) -> bool:
	if node is Button and node.text == "Switch account":
		return node.is_visible_in_tree()
	for c in node.get_children():
		if _prompt_showing(c):
			return true
	return false


func _fresh_install() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Account.ACCOUNT_PATH))
	Account._reset_cache()


func _menu() -> Node:
	var m: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	return m


func _init() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: sign-in suite still running after 120s")
		quit(1))
	var prev_backend = CloudSave.backend
	CloudSave.backend = MemoryBackend

	# ---- (a) no owner: the boot verdict must not ask, and the press binds -----
	_fresh_install()
	var menu: Node = await _menu()
	check(menu.login_center.visible, "precondition: a fresh install shows the login screen")
	menu._on_sign_in_finished(true) # the silent boot check — nobody pressed anything
	await process_frame
	check(Account.owner() == "", "a silent verdict does not bind a first run on its own")
	check(menu.login_center.visible, "...and leaves the login screen up for the player")
	# The press. _on_provider_pressed runs the verdict path directly for a session
	# the plugin already authenticated (menu.gd), which is the path the iPhone took.
	menu._sign_in_gen += 1
	menu._on_sign_in_finished(true)
	await process_frame
	check(Account.owner() == "memory-account", "the player's press binds the account")
	check(menu.main_box.visible and not menu.login_center.visible,
		"...and the main menu is up")
	check(not _prompt_showing(menu),
		"with NO switch prompt — an empty owner is a first bind, not a switch")
	menu.queue_free()
	await process_frame

	# An interactive first bind with no silent verdict before it: the same answer.
	_fresh_install()
	menu = await _menu()
	menu._sign_in_gen += 1
	menu._on_sign_in_finished(true)
	await process_frame
	check(Account.owner() == "memory-account", "an interactive first bind binds")
	check(not _prompt_showing(menu), "...without a switch prompt")
	menu.queue_free()
	await process_frame

	# ---- (b) owner A, verdict as B: the switch prompt, as today ---------------
	_fresh_install()
	Account.sign_in(Account.GOOGLE, "google-alice", [])
	menu = await _menu()
	menu._on_sign_in_finished(true)
	await process_frame
	check(_prompt_showing(menu), "a different signed-in owner IS asked to switch")
	check(Account.owner() == "google-alice", "...and nothing rebinds until they answer")
	menu.queue_free()
	await process_frame

	# ---- (c) owner A, verdict as A: nothing to ask ----------------------------
	_fresh_install()
	Account.sign_in(Account.GOOGLE, "memory-account", [])
	menu = await _menu()
	menu._on_sign_in_finished(true)
	await process_frame
	check(not _prompt_showing(menu), "the owner signing in again is not asked to switch")
	check(Account.owner() == "memory-account", "...and stays bound")
	menu.queue_free()
	await process_frame

	# A guest is the other owner switch_to refuses (account.gd): a silent verdict
	# must neither convert them nor ask them to "switch" to a button that cannot.
	_fresh_install()
	var guest_id := Account.start_guest()
	menu = await _menu()
	menu._on_sign_in_finished(true)
	await process_frame
	check(not _prompt_showing(menu), "a guest is not asked to switch on a silent verdict")
	check(Account.owner() == guest_id, "...and stays a guest")
	menu.queue_free()
	await process_frame

	CloudSave.backend = prev_backend
	_fresh_install()
	print("---")
	print("ALL GREEN" if fails == 0 else "FAILED: %d" % fails)
	quit(1 if fails > 0 else 0)
