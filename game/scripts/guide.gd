## Shared "Guide" panel — one builder so the Main Menu and the in-game menu
## (05-menus-and-settings) show the exact same rules text instead of two
## copies drifting apart.

const GuideText := preload("res://data/guide_text.gd")


## Builds a full-rect, initially-hidden, scrollable Guide panel as a child of
## `layer` and returns it so the caller toggles `.visible`. `on_back` runs
## when the panel's own Back button is pressed (hides the panel itself).
static func build(layer: Node, on_back: Callable) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 30
	scroll.offset_top = 30
	scroll.offset_right = -30
	scroll.offset_bottom = -30
	scroll.visible = false
	layer.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	var head := Label.new()
	head.text = "Guide"
	head.add_theme_font_size_override("font_size", 28)
	box.add_child(head)
	var body := Label.new()
	body.text = GuideText.TEXT
	body.add_theme_font_size_override("font_size", 15)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(body)
	var back := Button.new()
	back.text = "← Back"
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func() -> void:
		scroll.visible = false
		on_back.call())
	box.add_child(back)
	return scroll
