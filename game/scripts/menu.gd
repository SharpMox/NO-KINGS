extends Control
## Minimal main menu: Play + Quit. `--autoplay` (headless verification bot)
## skips the menu; `--screenshot <dir>` saves menu.png then hands off to the
## game scene for game.png (agent visual verification, windowed run).

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--autoplay"):
		get_tree().change_scene_to_file.call_deferred("res://scenes/Game.tscn")
		return
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	var title := Label.new()
	title.text = "NO KINGS"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var play := Button.new()
	play.text = "Play"
	play.add_theme_font_size_override("font_size", 32)
	play.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	box.add_child(play)

	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)

	if args.has("--screenshot"):
		var dir: String = args[args.find("--screenshot") + 1]
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("menu.png"))
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
