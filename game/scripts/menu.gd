extends Control
## Main menu: Play / TEST (scenario launcher) / Quit. `--autoplay` and
## `--scenario N` skip the menu; `--screenshot <dir>` captures menu.png first.

const GameScript := preload("res://scripts/game.gd")
const Scenarios := preload("res://data/scenarios.gd")
const PixelFilter := preload("res://scripts/pixel_filter.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Guide := preload("res://scripts/guide.gd")
const Settings := preload("res://scripts/settings.gd")
const CloudSave := preload("res://scripts/cloud_save.gd")
const Armies := preload("res://scripts/armies.gd")

static var window_sized := false # once per launch, not on every return to menu

var main_box: VBoxContainer
var test_scroll: ScrollContainer
var army_center: ScrollContainer
var rank_center: CenterContainer
var seed_field: LineEdit # issue 75
var scores_center: CenterContainer
var history_scroll: ScrollContainer
var about_center: CenterContainer
var guide_scroll: ScrollContainer
var settings_panel: CenterContainer


func _ready() -> void:
	# issue 74: the pixel filter, on the MENU rather than the board — the board's
	# tokens are already painted pixel art and gain nothing from being quantised
	# again, while the menus are flat vector UI and are where the retro look
	# actually reads (user call 2026-08-31). --pixel <n> overrides the factor so
	# a screenshot can compare; --pixel 0 turns it off entirely.
	var pf := PixelFilter.new()
	add_child(pf)
	var override := pf.factor_from_args(OS.get_cmdline_user_args())
	pf.set_factor(override if OS.get_cmdline_user_args().has("--pixel")
		else PixelFilter.MENU_FACTOR)
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
	# issue 77: vertical only — a long scenario name must wrap or clip, never
	# push the list sideways
	test_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
	head.add_theme_font_size_override("font_size", 22)
	test_box.add_child(head)
	# issue 77: 53 scenarios in one flat column is unscannable. Sections are
	# DERIVED from the names rather than stored, so scenarios.gd is untouched
	# and anything added later groups itself by how it is named.
	#
	# The cut is at the first ":" OR "(", whichever comes first. Splitting on
	# ":" alone breaks on names whose colon sits inside parentheses
	# ("Recurring King (wave 100: ...)" -> a section literally called
	# "Recurring King (wave 100"). Cutting at "(" too fixes those and folds
	# "Piece Buffs (Buff Box: ...)" in with the other Piece Buffs entries.
	#
	# Sections with a single member collapse into "Other" — without that the
	# 53 split into 20 sections, 12 of them singletons, which is no more
	# scannable than the flat list it replaced.
	var groups := {}
	for s in Scenarios.all():
		var cuts: Array[int] = []
		for ch in [":", "("]:
			var at: int = s.name.find(ch)
			if at > 0:
				cuts.append(at)
		cuts.sort()
		var sec: String = s.name.substr(0, cuts[0]).strip_edges() if not cuts.is_empty() else "General"
		if not groups.has(sec):
			groups[sec] = []
		groups[sec].append(s)
	var singles := []
	for sec in groups:
		if groups[sec].size() == 1:
			singles.append(sec)
	for sec in singles:
		if not groups.has("Other"):
			groups["Other"] = []
		groups["Other"].append(groups[sec][0])
		groups.erase(sec)
	var ordered := groups.keys()
	ordered.sort_custom(func(a: String, b: String) -> bool:
		# biggest first, "Other" always last however big it gets
		if a == "Other":
			return false
		if b == "Other":
			return true
		return groups[a].size() > groups[b].size())
	for sec in ordered:
		var sec_head := Label.new()
		sec_head.text = "%s  (%d)" % [sec.to_upper(), groups[sec].size()]
		sec_head.add_theme_font_size_override("font_size", 11)
		sec_head.modulate = Color(1, 1, 1, 0.55) # same dimmed-header idiom the
			# inventory drawer's Activate section uses
		test_box.add_child(sec_head)
		for s in groups[sec]:
			_button(test_box, s.name, 15, func() -> void:
				GameScript.next_config = s.cfg
				GameScript.is_scenario = true # scenarios never autosave
				get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	_button(test_box, "← Back", 20, func() -> void:
		test_scroll.visible = false
		main_box.visible = true)

	# army select: Play goes here; each army is a button + composition line.
	# ScrollContainer, not CenterContainer (issue 68): 6 Armies' worth of
	# buttons + roster + Power/Ability lines overflow the fixed 480x800
	# portrait window — the same scrollable-list shape test_scroll/
	# history_scroll/guide_scroll already use below, so every entry (and the
	# trailing Back button) stays reachable regardless of Army count.
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
	# issue 68 tightened this from 12: six Armies' worth of entries have to
	# fit 480x800 without scrolling. The ScrollContainer above stays as the
	# safety net for a seventh.
	army_box.add_theme_constant_override("separation", 5)
	army_center.add_child(army_box)
	var pick := Label.new()
	pick.text = "Choose your Army" # issue 67: replaces the Army pick
	pick.add_theme_font_size_override("font_size", 22)
	army_box.add_child(pick)
	for army_name in Tuning.ARMIES: # the id stays Tuning.ARMIES' key
		# (load-bearing in the save's `army` field) — only the button's
		# display text differs, via Armies.display_name
		_button(army_box, Armies.display_name(army_name), 18, func() -> void:
			GameScript.next_army = army_name
			army_center.visible = false
			rank_center.visible = true)
		var roster := Label.new()
		roster.text = _army_summary(Tuning.ARMIES[army_name])
		roster.add_theme_font_size_override("font_size", 11)
		roster.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		roster.modulate = Color(1, 1, 1, 0.7)
		army_box.add_child(roster)
		var kit: Dictionary = Armies.entry(army_name)
		var powers := Label.new()
		powers.text = "%s · %s" % [kit.power_name, kit.ability_name]
		powers.add_theme_font_size_override("font_size", 10)
		powers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		powers.modulate = Color(0.85, 0.8, 0.55) # gold tint, matches the
			# in-game Army Ability chip's own tint (hud.gd)
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
	# issue 75: the seed field. Sits on the LAST screen before a run starts, so
	# it is the final thing set and cannot be lost by backing out of a later
	# step. Empty = a fresh random seed, exactly as before.
	var seed_row := VBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 2)
	var seed_label := Label.new()
	seed_label.text = "SEED — leave blank for random"
	seed_label.add_theme_font_size_override("font_size", 11)
	seed_label.modulate = Color(1, 1, 1, 0.55)
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_row.add_child(seed_label)
	seed_field = LineEdit.new()
	seed_field.placeholder_text = "any word or number"
	seed_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_field.custom_minimum_size = Vector2(240, 0)
	# must NOT take focus on show — the windowed click probes drive real input,
	# and a focused text field would swallow their keystrokes
	seed_field.focus_mode = Control.FOCUS_CLICK
	seed_row.add_child(seed_field)
	rank_box.add_child(seed_row)
	for tier_name in Tuning.TIERS:
		_button(rank_box, tier_name, 26, func() -> void:
			GameScript.next_tier = tier_name
			GameScript.next_seed = seed_field.text.strip_edges() # "" = random
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
