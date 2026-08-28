extends SceneTree
## Settings persistence: user://settings.json round-trips, defaults hold for
## an untouched or partial file, and unknown/legacy keys survive a save
## (06's animations toggle and 07's difficulty picker add rows here without
## this module changing). Run headless:
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

	Settings.save_settings({"sound_on": false})
	check(Settings.load_settings().sound_on == false,
		"a saved value survives a fresh load_settings() call — the relaunch case")

	# a future key added by 06/07 must not get clobbered by this module
	Settings.save_settings({"sound_on": true, "animations_on": false})
	var reloaded := Settings.load_settings()
	check(reloaded.sound_on == true and reloaded.animations_on == false,
		"keys this module doesn't own still round-trip")

	Settings.apply({"sound_on": false})
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
		"apply() mutes the Master bus when sound is off")
	Settings.apply({"sound_on": true})
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
		"apply() unmutes the Master bus when sound is on")

	DirAccess.remove_absolute(Settings.SETTINGS_PATH)

	print("---")
	if fails == 0:
		print("ALL SETTINGS CHECKS OK")
	quit(1 if fails > 0 else 0)
