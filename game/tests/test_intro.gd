extends SceneTree
## Headless coverage for the cinematic intro's skip logic (issue 71) — the
## two things that must never race or double-fire: the CLI-bypass predicate
## (--autoplay/--scenario/--screenshot) and the idempotent guard shared by
## the video's `finished` signal and a click landing on the very first frame.
##
## Real click routing isn't probed here: this repo's own click-probe headers
## document that headless Godot drops GUI picking, so a true click test
## needs a window — and the intro is deliberately unreachable from the two
## existing windowed probes (they instantiate Menu.tscn directly; see
## scripts/intro.gd's header), so a third windowed suite would only re-prove
## `_gui_input` fires, at real window-boot cost, for coverage the deferred
## guard check below already gives cheaper and faster. Run headless:
##   godot --headless --path game -s tests/test_intro.gd

const Intro := preload("res://scripts/intro.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


## The CONTINUE button, found by text rather than by index so a future sibling
## node cannot silently make this assert about the wrong control.
func _continue_button(root_node: Node) -> Button:
	for c in root_node.get_children():
		if c is Button and (c as Button).text == "CONTINUE":
			return c
	return null


func _count_continue(root_node: Node) -> int:
	var n := 0
	for c in root_node.get_children():
		if c is Button and (c as Button).text == "CONTINUE":
			n += 1
	return n


func _init() -> void:
	check(Intro.should_bypass(["--autoplay"]), "bypasses on --autoplay")
	check(Intro.should_bypass(["--scenario", "0"]), "bypasses on --scenario")
	check(Intro.should_bypass(["--screenshot", "/tmp"]), "bypasses on --screenshot")
	check(not Intro.should_bypass([]), "plays for a real launch (no bypass args)")
	check(not Intro.should_bypass(["--army", "Cult"]), "an unrelated flag doesn't bypass it")

	# --- the loop + CONTINUE gate (2026-09-09) ------------------------------
	# The intro no longer walks straight into the menu. It hands over to a short
	# looping clip under a CONTINUE button, so entering the game (and the sign-in
	# behind it) is a deliberate press. Three different things can end the intro
	# — the `finished` signal, the deadman timer and a tap — and all three must
	# land in the SAME loop state exactly once.
	var gate: Control = Intro.new()
	root.add_child(gate)
	await process_frame
	await process_frame
	check(not gate._looping, "the intro starts in its first clip, not the loop")
	check(_continue_button(gate) == null,
		"...and CONTINUE is not offered while the intro is still playing")
	gate._begin_loop()
	gate._begin_loop() # a tap racing the deadman racing `finished`
	await process_frame
	var btn := _continue_button(gate)
	check(gate._looping and btn != null,
		"ending the intro raises the loop with a CONTINUE button")
	check(_count_continue(gate) == 1,
		"...exactly one, however many things ended the intro (found %d)"
			% _count_continue(gate))
	# THE POINT OF THE GATE: reaching the loop must not reach the menu. If this
	# regresses, the sign-in screen appears on its own again and the button is
	# decoration.
	check(current_scene == null
		or current_scene.scene_file_path != "res://scenes/Menu.tscn",
		"reaching the loop does NOT enter the menu on its own")
	btn.pressed.emit()
	await process_frame
	await process_frame
	check(current_scene != null
		and current_scene.scene_file_path == "res://scenes/Menu.tscn",
		"pressing CONTINUE is what enters the menu")
	gate.queue_free()
	await process_frame

	var intro: Control = Intro.new()
	root.add_child(intro)
	await process_frame
	await process_frame
	intro._advance() # simulates the `finished` signal, or a click
	intro._advance() # racing it a second time (e.g. a click on the last frame) must no-op
	await process_frame
	await process_frame
	check(current_scene != null
		and current_scene.scene_file_path == "res://scenes/Menu.tscn",
		"advancing hands off to the Menu scene exactly once, even if triggered twice")

	print("---")
	if fails == 0:
		print("ALL GREEN")
		quit(0)
	else:
		print("FAILED: %d" % fails)
		quit(1)
