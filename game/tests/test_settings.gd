extends SceneTree
## Settings persistence: user://settings.json round-trips, defaults hold for
## an untouched or partial file, and unknown/legacy keys survive a save
## (07's difficulty picker adds a row here without this module changing).
## Also pins the one project.godot setting whose section placement is load-bearing
## and whose effect only shows on an Android device (NO-30).
## Run headless:
##   godot --headless --path game -s tests/test_settings.gd

const Settings := preload("res://scripts/settings.gd")
const Account := preload("res://scripts/account.gd")

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

	# NO-31: the logout confirm asked "Log out of Apple?" on iOS. capitalize() on
	# the provider KEY spells the key, and PR #301 ruled the provider is always
	# shown as "Game Center" -- Apple names Sign in with Apple, a different
	# service a player then goes looking for. Account.label() is the one place
	# that knows, and menu.gd reads the same helper.
	var acct_paths := ["user://t_no31_save.json"]
	for prov_case in [[Account.APPLE, "Game Center", "Apple"],
			[Account.GOOGLE, "Google", ""]]:
		Account.logout(acct_paths)
		Account._reset_cache()
		Account.sign_in(prov_case[0], "id-" + str(prov_case[0]), acct_paths)
		var layer := Control.new()
		root.add_child(layer)
		Settings.build(layer, func() -> void: pass, Callable(),
			func() -> void: pass)
		var warn_text := _find_logout_warn(layer)
		check(prov_case[1] in warn_text,
			"the logout confirm names %s for provider %s (%s)"
				% [prov_case[1], prov_case[0], warn_text.split("\n")[0]])
		if prov_case[2] != "":
			check(not (prov_case[2] in warn_text),
				"and never says \"%s\" -- that is a different Apple service" % prov_case[2])
		layer.queue_free()
		await process_frame
	Account.logout(acct_paths)
	DirAccess.remove_absolute(acct_paths[0])

	DirAccess.remove_absolute(Settings.SETTINGS_PATH)

	print("---")
	if fails == 0:
		print("ALL SETTINGS CHECKS OK")
	quit(1 if fails > 0 else 0)


## The logout confirm's warning Label, found by content rather than by index:
## the panel's child order is not this test's business and moves with the
## settings rows.
func _find_logout_warn(node: Node) -> String:
	if node is Label and "Log out of" in (node as Label).text:
		return (node as Label).text
	for c in node.get_children():
		var found := _find_logout_warn(c)
		if found != "":
			return found
	return ""
