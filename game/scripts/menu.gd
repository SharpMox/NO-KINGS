extends Control
## Main menu: Play / TEST (scenario launcher) / Quit. `--autoplay` and
## `--scenario N` skip the menu; `--screenshot <dir>` captures menu.png first.

const GameScript := preload("res://scripts/game.gd")
const Scenarios := preload("res://data/scenarios.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Guide := preload("res://scripts/guide.gd")
const Settings := preload("res://scripts/settings.gd")
const CloudSave := preload("res://scripts/cloud_save.gd")
const Families := preload("res://scripts/families.gd")

static var window_sized := false # once per launch, not on every return to menu

var main_box: VBoxContainer
var test_scroll: ScrollContainer
var army_center: ScrollContainer
var rank_center: CenterContainer
var scores_center: CenterContainer
var history_scroll: ScrollContainer
var about_center: CenterContainer
var guide_scroll: ScrollContainer
var settings_panel: CenterContainer


func _ready() -> void:
	# CLI bypasses/probes boot Game.tscn straight past this scene, so it also
	# applies at its own _ready() — belt and suspenders, both are idempotent.
	Settings.apply(Settings.load_settings())
	# real boots only — the click probes instantiate the menu by hand and inject
	# clicks at 480×800 coords, which a mid-probe resize would break
	if not window_sized and DisplayServer.get_name() != "headless" \
			and get_tree().current_scene == self:
		window_sized = true
		var usable := DisplayServer.screen_get_usable_rect()
		var h: int = usable.size.y - 40 # title-bar allowance
		get_window().size = Vector2i(int(h * 480.0 / 800.0), h) # keep portrait aspect
		get_window().move_to_center()
	var args := OS.get_cmdline_user_args()
	if args.has("--autoplay") or args.has("--scenario"):
		get_tree().change_scene_to_file.call_deferred("res://scenes/Game.tscn")
		return
	# pull the cloud mirror before deciding what's on disk (12): a no-op on
	# desktop today, but on iOS/Android (once the native plugin lands) this
	# is what makes a fresh install offer "Continue" from another device.
	CloudSave.sync_file("run", GameScript.SAVE_PATH)
	CloudSave.sync_file("scores", GameScript.SCORES_PATH)
	CloudSave.sync_file("history", GameScript.HISTORY_PATH)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 24)
	center.add_child(main_box)

	var title := Label.new()
	title.text = "NO KINGS"
	title.add_theme_font_size_override("font_size", 48)
	main_box.add_child(title)
	if FileAccess.file_exists(GameScript.SAVE_PATH):
		_button(main_box, "Continue", 32, func() -> void:
			GameScript.next_config = JSON.parse_string(
				FileAccess.get_file_as_string(GameScript.SAVE_PATH))
			GameScript.is_scenario = false
			get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	_button(main_box, "Play", 32, _show_armies)
	_button(main_box, "Scores", 24, _show_scores)
	_button(main_box, "Games History", 24, _show_history)
	_button(main_box, "Guide", 24, func() -> void:
		main_box.visible = false
		guide_scroll.visible = true)
	_button(main_box, "About", 24, _show_about)
	_button(main_box, "Settings", 24, func() -> void:
		main_box.visible = false
		settings_panel.visible = true)
	_button(main_box, "TEST", 24, _show_tests)
	_button(main_box, "Quit", 20, func() -> void: get_tree().quit())

	# Guide and Settings are shared with the in-game menu (scripts/guide.gd,
	# scripts/settings.gd) so the two entry points can't drift apart
	guide_scroll = Guide.build(self, func() -> void: main_box.visible = true)
	settings_panel = Settings.build(self, func() -> void: main_box.visible = true)

	# scenario submenu: scrollable list, hidden until TEST — hide the SCROLL
	# itself: a visible full-rect ScrollContainer eats every click beneath it
	test_scroll = ScrollContainer.new()
	test_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	test_scroll.offset_left = 60
	test_scroll.offset_top = 30
	test_scroll.offset_right = -60
	test_scroll.offset_bottom = -30
	test_scroll.visible = false
	add_child(test_scroll)
	var test_box := VBoxContainer.new()
	test_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_box.add_theme_constant_override("separation", 6)
	test_scroll.add_child(test_box)
	var head := Label.new()
	head.text = "Test scenarios"
	head.add_theme_font_size_override("font_size", 28)
	test_box.add_child(head)
	for s in Scenarios.all():
		_button(test_box, s.name, 17, func() -> void:
			GameScript.next_config = s.cfg
			GameScript.is_scenario = true # scenarios never autosave
			get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	_button(test_box, "← Back", 20, func() -> void:
		test_scroll.visible = false
		main_box.visible = true)

	# army select: Play goes here; each army is a button + composition line.
	# ScrollContainer, not CenterContainer (issue 68): 6 Families' worth of
	# buttons + roster + Power/Ability lines overflow the fixed 480x800
	# portrait window — the same scrollable-list shape test_scroll/
	# history_scroll/guide_scroll already use below, so every entry (and the
	# trailing Back button) stays reachable regardless of Family count.
	army_center = ScrollContainer.new()
	army_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	army_center.offset_left = 40
	army_center.offset_top = 30
	army_center.offset_right = -40
	army_center.offset_bottom = -30
	army_center.visible = false
	add_child(army_center)
	var army_box := VBoxContainer.new()
	army_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	army_box.add_theme_constant_override("separation", 12)
	army_center.add_child(army_box)
	var pick := Label.new()
	pick.text = "Choose your Family" # issue 67: replaces the Army pick
	pick.add_theme_font_size_override("font_size", 28)
	army_box.add_child(pick)
	for army_name in Tuning.ARMIES: # the id stays Tuning.ARMIES' key
		# (load-bearing in the save's `army` field) — only the button's
		# display text differs, via Families.display_name
		_button(army_box, Families.display_name(army_name), 26, func() -> void:
			GameScript.next_army = army_name
			army_center.visible = false
			rank_center.visible = true)
		var roster := Label.new()
		roster.text = _army_summary(Tuning.ARMIES[army_name])
		roster.add_theme_font_size_override("font_size", 13)
		roster.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		roster.modulate = Color(1, 1, 1, 0.7)
		army_box.add_child(roster)
		var kit: Dictionary = Families.entry(army_name)
		var powers := Label.new()
		powers.text = "%s · %s" % [kit.power_name, kit.ability_name]
		powers.add_theme_font_size_override("font_size", 12)
		powers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		powers.modulate = Color(0.85, 0.8, 0.55) # gold tint, matches the
			# in-game Family Ability chip's own tint (hud.gd)
		army_box.add_child(powers)
	_button(army_box, "← Back", 20, func() -> void:
		army_center.visible = false
		main_box.visible = true)

	# tier select: chosen after the army, locked for the run
	# (07-difficulty-ranks — Continue into endless keeps it)
	rank_center = CenterContainer.new()
	rank_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	rank_center.visible = false
	add_child(rank_center)
	var rank_box := VBoxContainer.new()
	rank_box.add_theme_constant_override("separation", 12)
	rank_center.add_child(rank_box)
	var rank_pick := Label.new()
	rank_pick.text = "Choose your difficulty"
	rank_pick.add_theme_font_size_override("font_size", 28)
	rank_box.add_child(rank_pick)
	for tier_name in Tuning.TIERS:
		_button(rank_box, tier_name, 26, func() -> void:
			GameScript.next_tier = tier_name
			GameScript.next_config = {}
			GameScript.is_scenario = false
			get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	_button(rank_box, "← Back", 20, func() -> void:
		rank_center.visible = false
		army_center.visible = true)

	if args.has("--screenshot"):
		var dir: String = args[args.find("--screenshot") + 1]
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("menu.png"))
		get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _show_tests() -> void:
	main_box.visible = false
	test_scroll.visible = true


func _show_armies() -> void:
	main_box.visible = false
	army_center.visible = true


func _show_scores() -> void:
	main_box.visible = false
	# rebuilt on every open so fresh runs show up without a restart
	if scores_center:
		scores_center.queue_free()
	scores_center = CenterContainer.new()
	scores_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scores_center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	scores_center.add_child(box)
	var head := Label.new()
	head.text = "High scores"
	head.add_theme_font_size_override("font_size", 28)
	box.add_child(head)
	var scores := GameScript.load_scores()
	if scores.is_empty():
		var none := Label.new()
		none.text = "No runs yet"
		box.add_child(none)
	for i in scores.size():
		var e: Dictionary = scores[i]
		var row := Label.new()
		row.text = "%2d.  %5d — wave %d · %d king%s" % [i + 1, int(e.score),
			int(e.wave), int(e.kings), "" if int(e.kings) == 1 else "s"]
		row.add_theme_font_size_override("font_size", 18)
		box.add_child(row)
	_button(box, "← Back", 20, func() -> void:
		scores_center.visible = false
		main_box.visible = true)


## Games History: every real run's summary, newest first — distinct from the
## ranked top-10 Highscores above (05-menus-and-settings).
func _show_history() -> void:
	main_box.visible = false
	if history_scroll:
		history_scroll.queue_free()
	history_scroll = ScrollContainer.new()
	history_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	history_scroll.offset_left = 40
	history_scroll.offset_top = 30
	history_scroll.offset_right = -40
	history_scroll.offset_bottom = -30
	add_child(history_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	history_scroll.add_child(box)
	var head := Label.new()
	head.text = "Games History"
	head.add_theme_font_size_override("font_size", 28)
	box.add_child(head)
	var runs := GameScript.load_history()
	if runs.is_empty():
		var none := Label.new()
		none.text = "No runs yet"
		box.add_child(none)
	for e in runs:
		var row := Label.new()
		row.text = "%s — %d · wave %d · %d king%s · %d king abilit%s · %d lost" % [
			"Win" if e.get("won", false) else "Loss", int(e.score), int(e.wave),
			int(e.kings), "" if int(e.kings) == 1 else "s",
			int(e.tariffs), "y" if int(e.tariffs) == 1 else "ies", int(e.get("lost", 0))]
		row.add_theme_font_size_override("font_size", 15)
		box.add_child(row)
	_button(box, "← Back", 20, func() -> void:
		history_scroll.visible = false
		main_box.visible = true)


func _show_about() -> void:
	main_box.visible = false
	if about_center:
		about_center.queue_free()
	about_center = CenterContainer.new()
	about_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(about_center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	about_center.add_child(box)
	var head := Label.new()
	head.text = "About"
	head.add_theme_font_size_override("font_size", 28)
	box.add_child(head)
	var body := Label.new()
	body.text = "NO KINGS\nA fairy-chess strategy game — MVP build.\nBuilt with Godot 4."
	body.add_theme_font_size_override("font_size", 15)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	_button(box, "← Back", 20, func() -> void:
		about_center.visible = false
		main_box.visible = true)


func _army_summary(army: Array) -> String:
	var counts := {} # insertion-ordered, so the summary follows the army list
	for id in army:
		counts[id] = counts.get(id, 0) + 1
	var parts := []
	for id in counts:
		parts.append(("%d× %s" % [counts[id], id]) if counts[id] > 1 else id)
	return " · ".join(parts)


func _button(parent: Container, text: String, size: int, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(on_press)
	parent.add_child(b)
