## Settings: persisted user prefs (user://settings.json, alongside save.json
## and scores.json) plus the shared panel both the Main Menu and the
## in-game menu embed. This is the shell 06 (animations toggle) and 07
## (difficulty picker) hang their own rows off — 05-menus-and-settings only
## ships the one real, wired toggle that exists today: Sound.

const SETTINGS_PATH := "user://settings.json"
const DEFAULTS := {"sound_on": true, "animations_on": true}


static func load_settings() -> Dictionary:
	var data := DEFAULTS.duplicate()
	if FileAccess.file_exists(SETTINGS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if parsed is Dictionary:
			data.merge(parsed, true) # unknown/future keys still overwrite defaults
	return data


static func save_settings(data: Dictionary) -> void:
	# Null-checked like every other write: this one fires on each toggle, so a
	# failed open would crash the Settings panel out from under the player. The
	# setting still applies to the running session; it just will not persist.
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		push_error("settings: could not write %s (error %d)"
			% [SETTINGS_PATH, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(data))


## Mutes/unmutes the Master bus from a loaded settings Dictionary. Call once
## at every boot (Menu and Game scenes) so a relaunch respects the choice.
## Also applies the hard-edged text rendering (74) — not a user pref, it rides
## here because this is already the "runs once at every boot, idempotent" hook.
static func apply(data: Dictionary) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not data.get("sound_on", true))
	_crisp_text()


## issue 74: turn OFF font antialiasing project-wide, so text renders as hard
## pixels instead of soft grey edges and sits with the pixel-art tokens.
##
## This is what survived the pixel-filter spike. A full-screen pixelate shader
## and a SubViewport downscale were both tried and both rejected by the user:
## downscaling a vector font and upscaling it back reads as damage, not as
## retro, and the smaller the render the worse the glyphs break (see
## `.scratch/gdd-gaps/issues/74-assets/`). Antialiasing was the whole of the
## blur; removing it is the entire effect, at native resolution, with no
## shader, no viewport and no coordinate-space shift for the click probes.
##
## BOTH font slots have to be hardened, and this is the whole trap:
## `ThemeDB.fallback_font` is only consulted when nothing else supplies a font,
## and the DEFAULT THEME supplies one. Hardening the fallback alone therefore
## sets a property nothing reads — the first version of this shipped exactly
## that, changed no pixels, and every assertion about it still passed because
## they read back the property that had just been written.
##
## `test_settings.gd` now asks a live Label and Button what they RESOLVE
## (`get_theme_font("font")`) instead, which is the only form of this assertion
## that can fail when the effect is absent.
static func _crisp_text() -> void:
	var theme := ThemeDB.get_default_theme()
	theme.default_font = _hardened(theme.default_font)
	ThemeDB.fallback_font = _hardened(ThemeDB.fallback_font)


## A copy of `f` with antialiasing off — or `f` untouched when it is not a
## FontFile or is already hard, so repeated boots do not re-duplicate.
static func _hardened(f: Font) -> Font:
	if not (f is FontFile) or f.antialiasing == TextServer.FONT_ANTIALIASING_NONE:
		return f
	var hard: FontFile = f.duplicate()
	hard.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	hard.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	hard.hinting = TextServer.HINTING_NONE
	return hard


## Shared, full-rect, initially-hidden Settings panel built as a child of
## `layer`; returns it so the caller toggles `.visible`. `on_back` runs when
## the panel's own Back button is pressed (hides the panel itself). `on_change`
## (optional) fires with the full settings Dictionary after every toggle, so a
## caller with a live session (the in-game menu) can apply it without a
## restart — the Main Menu has no running game to update, so it's unused there.
static func build(layer: Node, on_back: Callable, on_change := Callable()) -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.visible = false
	layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var head := Label.new()
	head.text = "Settings"
	head.add_theme_font_size_override("font_size", 28)
	box.add_child(head)

	var data := load_settings()
	var sound := Button.new()
	sound.add_theme_font_size_override("font_size", 22)
	var relabel := func() -> void:
		sound.text = "Sound: On" if data.sound_on else "Sound: Off"
	relabel.call()
	sound.pressed.connect(func() -> void:
		data.sound_on = not data.sound_on
		save_settings(data)
		apply(data)
		relabel.call()
		if on_change.is_valid():
			on_change.call(data))
	box.add_child(sound)

	# Reduce/Disable Animations (06): instant transitions, for motion
	# sensitivity and low-end devices. Muted uniformly — slides, pops
	# (including box-pick capture pops), floating text, banners, outlines;
	# see game.gd's `animations_on` gate on the `anims` queue.
	var anim := Button.new()
	anim.add_theme_font_size_override("font_size", 22)
	var relabel_anim := func() -> void:
		anim.text = "Animations: On" if data.animations_on else "Animations: Reduced"
	relabel_anim.call()
	anim.pressed.connect(func() -> void:
		data.animations_on = not data.animations_on
		save_settings(data)
		relabel_anim.call()
		if on_change.is_valid():
			on_change.call(data))
	box.add_child(anim)

	var back := Button.new()
	back.text = "← Back"
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func() -> void:
		center.visible = false
		on_back.call())
	box.add_child(back)
	return center
