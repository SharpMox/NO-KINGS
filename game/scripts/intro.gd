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
## Two clips, not one (2026-09-09). The intro plays once and hands over to a
## short loop that runs under a CONTINUE button, so the player enters the menu
## — and the sign-in behind it — by choosing to, rather than by being dropped
## there when a video happens to end.
const VIDEO := preload("res://assets/video/nokings_intro.ogv")
const LOOP_VIDEO := preload("res://assets/video/nokings_intro_endloop.ogv")
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

## Comfortably longer than the 11.5s clip, short enough that a player staring at
## a stream that never decoded gets somewhere rather than force-quitting.
##
## It now advances to the LOOP state rather than to the menu. That keeps the
## original safety property — a broken decode never leaves a black screen — while
## respecting the new rule that the menu is only ever reached through CONTINUE.
## The loop state is safe to land in even if IT fails to decode too, because the
## button is drawn by us rather than by the video.
const INTRO_MAX_SECONDS := 20.0

var _advanced := false
var _looping := false
var _player: VideoStreamPlayer


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

	_player = VideoStreamPlayer.new()
	_player.stream = VIDEO
	_player.expand = true
	_player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := get_viewport_rect().size
	_player.size = NATIVE_SIZE * _scale_for(vp)
	_player.position = (vp - _player.size) / 2.0 # centered on whichever axis is left over
	# hands over to the loop, NOT to the menu
	_player.finished.connect(_begin_loop)
	add_child(_player)
	_player.play()

	# Deadman timer. `finished` is the only automatic way out of this scene, and
	# it never fires if the stream fails to decode — which is exactly the kind of
	# thing that varies across Android hardware we cannot test on. The failure
	# mode without this is a black screen on the FIRST thing a new player sees,
	# indistinguishable from a hung app, on a launch path where the only other
	# exit is knowing to tap. Cheap insurance against an uninstall.
	#
	# _begin_loop is idempotent, so a normal playthrough just finds it already run.
	get_tree().create_timer(INTRO_MAX_SECONDS).timeout.connect(_begin_loop)


## A tap during the intro SKIPS to the loop rather than to the menu. The point
## of the loop is that entering the game is a deliberate press, so a stray tap
## on the splash must not carry the player past the one thing asking them to
## choose. Once the CONTINUE button is up it owns the press; taps elsewhere do
## nothing, which is what makes the button the only door.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _looping:
		_begin_loop()


## Android's hardware Back skips the intro, exactly as a tap does.
##
## Needed because quit_on_go_back is now off (project.godot): before that,
## Back here quit the app, which was at least a response. Without a handler it
## would do NOTHING on the very first screen of the game — which reads as a
## frozen app to anyone whose reflex is to press Back.
## Android's hardware Back: during the intro it skips to the loop, exactly as a
## tap does. On the loop it advances, because Back that does nothing at all reads
## as a frozen app — the reason this handler exists at all.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _looping:
			_advance()
		else:
			_begin_loop()


func _advance() -> void:
	if _advanced: # a click racing the `finished` signal must not double-fire
		return
	_advanced = true
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)


## Swap to the short loop and raise the CONTINUE call to action. Idempotent: the
## deadman timer, the `finished` signal and a tap can all arrive, and only the
## first does anything.
func _begin_loop() -> void:
	if _looping or _advanced:
		return
	_looping = true
	if _player != null:
		_player.stream = LOOP_VIDEO
		_player.loop = true
		_player.play()
	_add_continue()


## Drawn by us rather than composited into the clip, so it survives a stream
## that never decodes — the same reasoning as the deadman timer above.
func _add_continue() -> void:
	var vp := get_viewport_rect().size
	var btn := Button.new()
	btn.text = "CONTINUE"
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.96, 0.93, 0.85))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.12, 0.92)
	sb.border_color = Color(0.85, 0.72, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
	btn.pressed.connect(_advance)
	add_child(btn)
	# measured, then placed: the button sizes itself from its own text and
	# padding, and reading that AFTER adding it is what keeps it centred at any
	# font scale rather than at the one it was written against.
	var want: Vector2 = btn.get_combined_minimum_size()
	btn.size = want
	btn.position = Vector2((vp.x - want.x) / 2.0, vp.y - want.y - vp.y * 0.12)
