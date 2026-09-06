extends SceneTree
## Settings persistence: user://settings.json round-trips, defaults hold for
## an untouched or partial file, and unknown/legacy keys survive a save
## (07's difficulty picker adds a row here without this module changing).
## Run headless:
##   godot --headless --path game -s tests/test_settings.gd

const Settings := preload("res://scripts/settings.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _init() -> void:
	DirAccess.remove_absolute(Settings.SETTINGS_PATH) # clean slate

	check(Settings.load_settings().sound_on == true,
		"no file on disk falls back to the default (sound on)")
	check(Settings.load_settings().animations_on == true,
		"no file on disk falls back to the default (animations on)")

	Settings.save_settings({"sound_on": false})
	check(Settings.load_settings().sound_on == false,
		"a saved value survives a fresh load_settings() call — the relaunch case")

	Settings.save_settings({"sound_on": true, "animations_on": false})
	var reloaded := Settings.load_settings()
	check(reloaded.sound_on == true and reloaded.animations_on == false,
		"animations_on round-trips independently of sound_on")

	# a future key added by 07 (difficulty) must not get clobbered by this module
	Settings.save_settings({"sound_on": true, "animations_on": true, "difficulty": "hard"})
	var reloaded2 := Settings.load_settings()
	check(reloaded2.difficulty == "hard",
		"keys this module doesn't own still round-trip")

	# CRT overlay (2026-09-06): the toggle drives the autoload, on by default.
	# `-s` scripts register no autoloads, so the overlay is mounted by hand
	# under its autoload name — which is exactly what Settings._crt looks up.
	var crt: Node = load("res://scripts/crt_overlay.gd").new()
	crt.name = "CrtOverlay"
	root.add_child(crt)
	await process_frame # Engine.get_main_loop() is unset while this _init runs
	check(Settings.load_settings().get("crt_on", false) == true, "CRT defaults to on")
	check(crt.enabled(), "the overlay boots on")
	Settings.apply({"crt_on": false})
	check(not crt.enabled(), "apply({crt_on: false}) hides the overlay")
	Settings.apply({"crt_on": true})
	check(crt.enabled(), "apply({crt_on: true}) shows it again")
	crt.queue_free()
	Settings.apply({"sound_on": false})
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
		"apply() mutes the Master bus when sound is off")
	Settings.apply({"sound_on": true})
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
		"apply() unmutes the Master bus when sound is on")

	# issue 74's hard-edged text was removed 2026-09-06 (user: "remove the
	# pixelated filter"): apply() must leave the fonts a live control resolves
	# antialiased. Same assert-what-resolves shape as before, inverted.
	Settings.apply({"sound_on": true})
	var probe_label := Label.new()
	root.add_child(probe_label)
	var label_font := probe_label.get_theme_font("font")
	check(label_font is FontFile and label_font.antialiasing
			!= TextServer.FONT_ANTIALIASING_NONE,
		"a Label RESOLVES an antialiased font (no pixelated text)")
	var probe_button := Button.new()
	root.add_child(probe_button)
	var button_font := probe_button.get_theme_font("font")
	check(button_font is FontFile and button_font.antialiasing
			!= TextServer.FONT_ANTIALIASING_NONE,
		"a Button RESOLVES an antialiased font (no pixelated text)")
	probe_label.queue_free()
	probe_button.queue_free()

	DirAccess.remove_absolute(Settings.SETTINGS_PATH)

	print("---")
	if fails == 0:
		print("ALL SETTINGS CHECKS OK")
	quit(1 if fails > 0 else 0)
