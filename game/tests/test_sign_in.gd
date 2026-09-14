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
# NO-76: the shape of a Game Center player id, as the iPhone showed it.
const HEX_64 := "a26b4668036156e12dcca5ee5856704f3f55f827cee5720427156111d3f55f82"

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

	# ---- NO-76: the prompt never shows a raw player id ------------------------
	# The iPhone's owner was bound before NO-54 recorded names, so the prompt
	# printed the 64-hex Game Center id, cut to the width, with the sentence's
	# "." wrapped onto a line of its own. An id is nothing a player recognises;
	# a nameless account gets a generic label instead. Asserted on the text the
	# player reads, on the prompt AND on the note left after declining.
	_fresh_install()
	Account.sign_in(Account.GOOGLE, HEX_64, [])
	menu = await _menu()
	menu._on_sign_in_finished(true)
	await process_frame
	check(_prompt_showing(menu), "precondition: a nameless owner is asked to switch")
	var hex := RegEx.create_from_string("(?i)[0-9a-f]{64}")
	var prompt: String = menu.switch_prompt_label.text
	check(hex.search(prompt) == null, "the prompt shows no 64-hex player id")
	check("this device's account" in prompt,
		"...a nameless owner is called this device's account")
	check("Memory Player" in prompt, "...and the live account keeps its display name")
	menu._on_switch_declined()
	await process_frame
	check(hex.search(menu.login_note.text) == null, "declining shows no id either")
	check("this device's account" in menu.login_note.text,
		"...and names the owner the same way")
	menu.queue_free()
	await process_frame

	# A recorded name is still shown — and a long one WRAPS rather than overflows.
	_fresh_install()
	var long_name := "Maximilian Alexander von Hohenzollern IV" # 40 chars
	Account.sign_in(Account.GOOGLE, HEX_64, [], long_name)
	menu = await _menu()
	menu._on_sign_in_finished(true)
	await process_frame
	await process_frame
	var label: Label = menu.switch_prompt_label
	var vp_w: float = root.get_visible_rect().size.x
	check(long_name in label.text, "a recorded display name is what the prompt shows")
	check(label.size.x <= vp_w,
		"...and the label fits the screen (%.0f <= %.0f)" % [label.size.x, vp_w])
	menu.queue_free()
	await process_frame
	# Wider still — a legal 64-character CJK name, wider than the screen at any
	# viewport: _who caps it at the text width, so the sentence around it always
	# overruns that width and must WRAP rather than push the menu sideways.
	_fresh_install()
	Account.sign_in(Account.GOOGLE, HEX_64, [], "山".repeat(64))
	menu = await _menu()
	menu._on_sign_in_finished(true)
	await process_frame
	await process_frame
	label = menu.switch_prompt_label
	check(label.get_line_count() > label.text.count("\n") + 1,
		"a name as wide as the screen wraps onto a further line (%d lines)"
			% label.get_line_count())
	check(label.size.x <= vp_w,
		"...and the label still fits the screen (%.0f <= %.0f)" % [label.size.x, vp_w])
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
