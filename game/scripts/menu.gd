extends Control
## Main menu: Play / TEST (scenario launcher) / Quit. `--autoplay` and
## `--scenario N` skip the menu; `--screenshot <dir>` captures menu.png first.

const GameScript := preload("res://scripts/game.gd")
const Scenarios := preload("res://data/scenarios.gd")

var main_box: VBoxContainer
var test_scroll: ScrollContainer


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--autoplay") or args.has("--scenario"):
		get_tree().change_scene_to_file.call_deferred("res://scenes/Game.tscn")
		return
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
	_button(main_box, "Play", 32, func() -> void:
		GameScript.next_config = {}
		GameScript.is_scenario = false
		get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	_button(main_box, "TEST", 24, _show_tests)
	_button(main_box, "Quit", 20, func() -> void: get_tree().quit())

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

	if args.has("--screenshot"):
		var dir: String = args[args.find("--screenshot") + 1]
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("menu.png"))
		get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _show_tests() -> void:
	main_box.visible = false
	test_scroll.visible = true


func _button(parent: Container, text: String, size: int, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(on_press)
	parent.add_child(b)
