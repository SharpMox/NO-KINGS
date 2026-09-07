extends SceneTree
## Settings persistence: user://settings.json round-trips, defaults hold for
## an untouched or partial file, and unknown/legacy keys survive a save
## (07's difficulty picker adds a row here without this module changing).
## Also pins the one project.godot setting whose section placement is load-bearing
## and whose effect only shows on an Android device (NO-30).
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
	# NO-30: quit_on_go_back was written as `application/config/quit_on_go_back`
	# INSIDE the [application] section, so Godot registered it as
	# `application/application/config/quit_on_go_back` and the real setting kept
	# its default of true -- the engine quit the app after our own GO_BACK
	# handlers ran, discarding the turn in progress. Nothing on desktop or in any
	# suite could see it: NOTIFICATION_WM_GO_BACK_REQUEST only fires on Android.
	# Assert the setting the engine actually reads, and that the mis-sectioned
	# twin is gone, so the wrong-section form cannot come back.
	check(ProjectSettings.get_setting("application/config/quit_on_go_back") == false,
		"quit_on_go_back is false at the key the engine reads")
	check(not ProjectSettings.has_setting("application/application/config/quit_on_go_back"),
		"the mis-sectioned application/application/... twin does not exist")
	# Do NOT add `check(quit_on_go_back == false)` here. Godot applies these to the
	# SceneTree only on the scene-main-loop path, so under `-s` the property keeps
	# its constructor default and reads true no matter what the setting says. Shown
	# 2026-09-07 with a control: auto_accept_quit=false in project.godot also reads
	# true off the SceneTree in this mode. The setting above is the strongest pin a
	# headless suite can hold; the flag itself is only observable on a device.

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
	# Autoloads join the root right AFTER this _init's first frame (a `-s`
	# script's root is empty until then), so wait one, then read the real one.
	await process_frame
	var crt: Node = root.get_node_or_null("CrtOverlay")
	check(crt != null, "the CRT overlay autoload is registered")
	check(Settings.load_settings().get("crt_on", false) == true, "CRT defaults to on")
	check(crt.enabled(), "the overlay boots on")
	Settings.apply({"crt_on": false})
	check(not crt.enabled(), "apply({crt_on: false}) hides the overlay")
	Settings.apply({"crt_on": true})
	check(crt.enabled(), "apply({crt_on: true}) shows it again")
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
