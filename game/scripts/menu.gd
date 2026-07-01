extends Control
## Minimal main menu: Play + Quit. `--autoplay` (headless verification bot)
## skips the menu entirely.

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--autoplay"):
		get_tree().change_scene_to_file.call_deferred("res://scenes/Game.tscn")
		return
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 24)
	add_child(box)

	var title := Label.new()
	title.text = "NO KINGS"
	title.add_theme_font_size_override("font_size", 48)
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
