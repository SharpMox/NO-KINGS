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
## The clip is as WIDE as the device allows: the largest scale that still fits
## both axes, so nothing is cropped. On a 9:20 phone that is width-bound and
## the video spans the full screen width; on a squarer 3:5 window it becomes
## height-bound instead and stops short of the edges, which is the correct
## answer there — overflowing would crop the frame.
##
## This replaces a fixed x3, chosen back when the canvas was always 480x800.
## That constant left ~48px of black either side on a phone. The old note
## warned that scaling past x3 "would look soft"; the player keeps
## TEXTURE_FILTER_NEAREST, so the trade is not softness but uneven pixel
## blocks at non-integer scales. Ruled acceptable: filling the screen matters
## more here than perfectly square pixels (user, 2026-09-05).
static func _scale_for(vp: Vector2) -> float:
	return minf(vp.x / NATIVE_SIZE.x, vp.y / NATIVE_SIZE.y)

## Comfortably longer than the clip, short enough that a player staring at a
## stream that never decoded gets to the menu rather than force-quitting.
const INTRO_MAX_SECONDS := 20.0

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
	var vp := get_viewport_rect().size
	player.size = NATIVE_SIZE * _scale_for(vp)
	player.position = (vp - player.size) / 2.0 # centered on whichever axis is left over
	player.finished.connect(_advance)
	add_child(player)
	player.play()

	# Deadman timer. `finished` is the only automatic way out of this scene, and
	# it never fires if the stream fails to decode — which is exactly the kind of
	# thing that varies across Android hardware we cannot test on. The failure
	# mode without this is a black screen on the FIRST thing a new player sees,
	# indistinguishable from a hung app, on a launch path where the only other
	# exit is knowing to tap. Cheap insurance against an uninstall.
	#
	# _advance is idempotent, so a normal playthrough just finds it already gone.
	get_tree().create_timer(INTRO_MAX_SECONDS).timeout.connect(_advance)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance()


## Android's hardware Back skips the intro, exactly as a tap does.
##
## Needed because quit_on_go_back is now off (project.godot): before that,
## Back here quit the app, which was at least a response. Without a handler it
## would do NOTHING on the very first screen of the game — which reads as a
## frozen app to anyone whose reflex is to press Back.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_advance()


func _advance() -> void:
	if _advanced: # a click racing the `finished` signal must not double-fire
		return
	_advanced = true
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)
