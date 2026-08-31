extends Control
## Cinematic intro (issue 71): plays once at the very start of every real
## launch, skippable by any click, then hands off to the Main Menu.
##
## Probe safety: test_menu_clicks.gd/test_game_clicks.gd (and every other
## tests/test_*.gd) run via `godot -s tests/test_X.gd`, which replaces
## Godot's main loop with the script's own SceneTree and never loads
## `run/main_scene` — they instantiate Menu.tscn directly instead. So this
## scene is structurally unreachable from the probes; no bypass flag needed
## for them. The one real launch mode that *does* go through main_scene
## without wanting the intro is the CLI bypasses (--autoplay/--scenario/
## --screenshot, the same three menu.gd already special-cases) — skip
## straight to the Menu for those.

const MENU_SCENE := "res://scenes/Menu.tscn"
const VIDEO := preload("res://assets/video/larry_intro.ogv")
const NATIVE_SIZE := Vector2(128, 228)
const UPSCALE := 3.0 # nearest-neighbour, suits the pixel-art source — smooth-
	# scaling 128px art to fill the 480-wide window would look soft

var _advanced := false


## Pulled out of _ready so tests/test_intro.gd can exercise it without a
## real CLI invocation.
static func should_bypass(args: PackedStringArray) -> bool:
	return args.has("--autoplay") or args.has("--scenario") or args.has("--screenshot")


func _ready() -> void:
	if should_bypass(OS.get_cmdline_user_args()):
		_advance()
		return

	mouse_filter = Control.MOUSE_FILTER_STOP # catches a click anywhere on screen

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var player := VideoStreamPlayer.new()
	player.stream = VIDEO
	player.expand = true
	player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.size = NATIVE_SIZE * UPSCALE
	player.position = (get_viewport_rect().size - player.size) / 2.0 # letterboxed, centered
	player.finished.connect(_advance)
	add_child(player)
	player.play()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance()


func _advance() -> void:
	if _advanced: # a click racing the `finished` signal must not double-fire
		return
	_advanced = true
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)
