## Settings: persisted user prefs (user://settings.json, alongside save.json
## and scores.json) plus the shared panel both the Main Menu and the
## in-game menu embed. This is the shell 06 (animations toggle) and 07
## (difficulty picker) hang their own rows off — 05-menus-and-settings only
## ships the one real, wired toggle that exists today: Sound.

const Account := preload("res://scripts/account.gd")
const SETTINGS_PATH := "user://settings.json"
const DEFAULTS := {"sound_on": true, "animations_on": true, "crt_on": true,
	"board_theme": "sage"} # Y1/NO-216 — id, not a colour; game.gd's BOARD_THEMES
	# owns the values themselves


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
## at every boot (Menu and Game scenes) so a relaunch respects the choice, and
## on every toggle. The hard-edged text of issue 74 (font antialiasing off,
## project-wide) used to ride here too; removed 2026-09-06 at the user's ask
## ("remove the pixelated filter") — text renders with Godot's default
## antialiasing again, and the CRT overlay is the only look-changer left.
static func apply(data: Dictionary) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not data.get("sound_on", true))
	_crt(data)


## The CRT overlay (scripts/crt_overlay.gd, an autoload) follows the toggle.
## Looked up by path, not preloaded: it is an autoload and this file is a
## preloaded dependency of half the game — the same trap play_games_bridge
## documents. Absent (a test that never registered autoloads) means no-op.
static func _crt(data: Dictionary) -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var overlay: Node = (loop as SceneTree).root.get_node_or_null("CrtOverlay")
	if overlay != null:
		overlay.set_enabled(bool(data.get("crt_on", true)))


## Shared, full-rect, initially-hidden Settings panel built as a child of
## `layer`; returns it so the caller toggles `.visible`. `on_back` runs when
## the panel's own Back button is pressed (hides the panel itself). `on_change`
## (optional) fires with the full settings Dictionary after every toggle, so a
## caller with a live session (the in-game menu) can apply it without a
## restart — the Main Menu has no running game to update, so it's unused there.


## `on_logout` is what makes the Log out row appear at all. Both entry points
## pass one because they have to do different things afterwards — the Main Menu
## shows the login screen, the in-game menu has a live run to leave first — but
## the ROW is built once, here, so the two copies cannot drift apart the way
## this repo has been bitten by duplicated controls before.

# Board-theme swatches (feat/board-theme-picker): each quadrant is this many
# px, so a 2x2 swatch is ~2x this plus the panel's own content margins --
# lands in the 64-80px range Max asked for. Outline colour is the same accent
# already used for a selection elsewhere: menu.gd's TIER_OUTLINE_COLOR /
# game.gd's COL_SELECT board highlight (0.35, 0.62-0.65, 1.0).
const SWATCH_QUADRANT := 32.0
const SWATCH_OUTLINE_COLOR := Color(0.35, 0.62, 1.0)

static func build(layer: Node, on_back: Callable, on_change := Callable(),
		on_logout := Callable()) -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.visible = false
	layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	# NO-256: every toggle fills this width, so "Animations: Reduced" in Bold 24
	# keeps clear air to its edges (Aux: at 22 it nearly touched them).
	box.custom_minimum_size.x = 340
	center.add_child(box)
	var head := Label.new()
	head.text = "Settings"
	head.theme_type_variation = &"Title"
	box.add_child(head)

	var data := load_settings()
	var sound := Button.new()
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

	# CRT TV look (2026-09-06): the whole-screen overlay, opt-out. apply() is
	# what flips the autoload, so the change is immediate on both menus.
	var crt := Button.new()
	var relabel_crt := func() -> void:
		crt.text = "CRT: On" if data.get("crt_on", true) else "CRT: Off"
	relabel_crt.call()
	crt.pressed.connect(func() -> void:
		data.crt_on = not data.get("crt_on", true)
		save_settings(data)
		apply(data)
		relabel_crt.call()
		if on_change.is_valid():
			on_change.call(data))
	box.add_child(crt)

	# Board colours (Y1/NO-216, side-by-side picker: feat/board-theme-picker,
	# Max ruling): a row of tappable 2x2 mini-board swatches, one per
	# BOARD_THEMES entry, each drawn in that theme's own light/dark/dark/light
	# colours with its label underneath — replaces the old cycling button so
	# both options are visible and chosen directly, and a future third theme
	# needs no code here. The theme ids/colours/labels live in game.gd's
	# BOARD_THEMES (load(), not preload() — game.gd preloads this script, so
	# a preload back would close a compile cycle; same seam piece_diagram.gd
	# uses for the same colours). A run's own board draw picks this up live
	# via hud.gd's settings_changed signal — this panel only stores the
	# choice and redraws the outline.
	var GameScript: GDScript = load("res://scripts/game.gd")
	var theme_ids: Array = GameScript.BOARD_THEMES.keys()
	# One PanelContainer per theme, in theme_ids order — its "panel" style is
	# the outline surface (same idiom as menu.gd's tier_panels /
	# _update_tier_outline): bordered in SWATCH_OUTLINE_COLOR when selected,
	# borderless otherwise, so exactly one swatch is ever outlined.
	var swatches: Array[PanelContainer] = []
	var update_swatches := func(selected_id: String) -> void:
		for i in swatches.size():
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)
			sb.content_margin_left = 4
			sb.content_margin_right = 4
			sb.content_margin_top = 4
			sb.content_margin_bottom = 4
			if theme_ids[i] == selected_id:
				sb.border_color = SWATCH_OUTLINE_COLOR
				sb.set_border_width_all(3)
			swatches[i].add_theme_stylebox_override("panel", sb)

	var swatch_row := HFlowContainer.new() # wraps automatically if a future theme won't fit one line
	swatch_row.alignment = FlowContainer.ALIGNMENT_CENTER
	swatch_row.add_theme_constant_override("h_separation", 16)
	swatch_row.add_theme_constant_override("v_separation", 16)
	box.add_child(swatch_row)
	for theme_id in theme_ids:
		var t: Dictionary = GameScript.BOARD_THEMES[theme_id]
		var swatch_col := VBoxContainer.new()
		swatch_col.add_theme_constant_override("separation", 4)
		swatch_row.add_child(swatch_col)

		var swatch_panel := PanelContainer.new()
		swatch_panel.name = "SwatchPanel_%s" % theme_id # addressed by name in test_settings.gd
		swatches.append(swatch_panel)
		swatch_col.add_child(swatch_panel)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 0)
		grid.add_theme_constant_override("v_separation", 0)
		swatch_panel.add_child(grid)
		for quad in [t.light, t.dark, t.dark, t.light]: # 2x2: light/dark top, dark/light bottom
			var cell := ColorRect.new()
			cell.color = quad
			cell.custom_minimum_size = Vector2(SWATCH_QUADRANT, SWATCH_QUADRANT)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE # the overlay button below takes the tap
			grid.add_child(cell)
		# Borderless overlay spanning the whole panel (PanelContainer fits
		# every child to the same rect) is the tap target — same convention
		# menu.gd's tier rows use for a full-panel hit area.
		var swatch_btn := Button.new()
		swatch_btn.name = "SwatchButton_%s" % theme_id # addressed by name in test_settings.gd
		swatch_btn.flat = true
		swatch_panel.add_child(swatch_btn)
		swatch_btn.pressed.connect(func() -> void:
			data.board_theme = theme_id
			save_settings(data)
			update_swatches.call(theme_id)
			if on_change.is_valid():
				on_change.call(data))

		var swatch_label := Label.new()
		swatch_label.text = t.label
		swatch_label.theme_type_variation = &"Meta"
		swatch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		swatch_col.add_child(swatch_label)
	update_swatches.call(data.get("board_theme", GameScript.DEFAULT_BOARD_THEME))

	# LOG OUT, with the confirm inline rather than as a modal. This panel is
	# embedded in two different scenes and a modal would have to be built and
	# positioned correctly in both; a two-step button cannot be wrong in one of
	# them. Hidden for a guest: Account.logout() refuses them anyway, because a
	# fresh guest id every time would orphan their parked saves for good.
	if on_logout.is_valid() and Account.signed_in():
		var logout_btn := Button.new()
		logout_btn.text = "Log out"
		box.add_child(logout_btn)

		var confirm_box := VBoxContainer.new()
		confirm_box.add_theme_constant_override("separation", 8)
		confirm_box.visible = false
		box.add_child(confirm_box)
		var warn := Label.new()
		warn.theme_type_variation = &"Meta"
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Says what actually happens, because the honest answer is reassuring:
		# nothing is deleted here and nothing is lost.
		# NO-31: this said "Log out of Apple?" on iOS, because capitalize() on the
		# provider key spells the KEY, not the service. PR #301 ruled the provider
		# is always shown as "Game Center" -- Account.label() is the one place that
		# knows, and menu.gd reads it too.
		warn.text = "Log out of %s?\nYour progress stays with this account and\ncomes back when you sign in again." \
			% Account.label(Account.provider())
		confirm_box.add_child(warn)
		var yes := Button.new()
		yes.text = "Log out"
		confirm_box.add_child(yes)
		var no := Button.new()
		no.text = "Cancel"
		confirm_box.add_child(no)

		logout_btn.pressed.connect(func() -> void:
			logout_btn.visible = false
			confirm_box.visible = true)
		no.pressed.connect(func() -> void:
			confirm_box.visible = false
			logout_btn.visible = true)
		yes.pressed.connect(func() -> void:
			# Back to the resting state FIRST: this panel is not rebuilt between
			# visits, so a confirm left open would greet the next visitor
			# mid-question — and after a logout the row hides itself anyway.
			confirm_box.visible = false
			logout_btn.visible = false
			center.visible = false
			on_logout.call())

	# Max ruling 2026-09-24 (isolated dismiss): Back leaves Settings
	# entirely, so it sits alone below a gap, after every toggle and Log out.
	var back_gap := Control.new()
	back_gap.custom_minimum_size = Vector2(0, 32) # matches modals.gd's MODAL_CANCEL_GAP
	box.add_child(back_gap)
	var back := Button.new()
	back.text = "← Back"
	back.pressed.connect(func() -> void:
		center.visible = false
		on_back.call())
	box.add_child(back)
	return center
