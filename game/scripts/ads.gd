## NO-241: the one ad seam. Every rewarded ad in the game goes through
## show_rewarded(); a real SDK replaces THIS FILE only, keeping the same two
## functions (show_rewarded, is_open).
##
## Placeholder: a full-screen "AD" overlay with a Close button. Closing it
## counts as watching the ad, so on_reward fires (Max, 2026-09-24).
## _on_cancel exists for the real SDK (ad failed to load / skipped early); the
## placeholder never calls it.
##
## The overlay is its own CanvasLayer above the HUD, full-rect with
## MOUSE_FILTER_STOP, so no tap reaches the board or a panel beneath it.
## game.gd also reads is_open() in its tier-gated Clock pause set.

const LAYER := 127 # above the HUD, below the CRT overlay (128)

static var _layer: CanvasLayer = null


static func is_open() -> bool:
	return is_instance_valid(_layer)


static func show_rewarded(on_reward: Callable, _on_cancel := Callable()) -> void:
	if is_open():
		return # one ad at a time
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)
	var label := Label.new()
	label.text = "AD"
	label.add_theme_font_size_override("font_size", 96)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void:
		_layer.queue_free()
		_layer = null
		on_reward.call())
	box.add_child(close)
	(Engine.get_main_loop() as SceneTree).root.add_child(_layer)


## The placeholder's Close button — tests press it through this.
static func close_button() -> Button:
	return _layer.find_children("*", "Button", true, false)[0] as Button if is_open() else null
