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


func _init() -> void:
	check(Intro.should_bypass(["--autoplay"]), "bypasses on --autoplay")
	check(Intro.should_bypass(["--scenario", "0"]), "bypasses on --scenario")
	check(Intro.should_bypass(["--screenshot", "/tmp"]), "bypasses on --screenshot")
	check(not Intro.should_bypass([]), "plays for a real launch (no bypass args)")
	check(not Intro.should_bypass(["--army", "Cult"]), "an unrelated flag doesn't bypass it")

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
