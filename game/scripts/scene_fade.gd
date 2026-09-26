## NO-243 S4 (audit rows 61/62): every scene change goes through `go`, which
## fades through black — FADE_S out on the old scene, the swap, FADE_S in on
## the new one. One helper, no autoload: the black layer is parented to the
## tree ROOT, so it outlives the scene it was started from (the same trick
## intro.gd's driver uses), and frees itself when the fade-in ends.
##
## Never blocks input: the black rect is MOUSE_FILTER_IGNORE, so a tap during
## the fade-in reaches the new scene. A second `go` while one is running is
## dropped — a double tap on Play must not queue a second change.
##
## Instant (a plain change_scene_to_file, nothing created) when `animate()` is
## false: Settings' animations_on off, a headless run, a test harness
## (`-s tests/...`), autoplay and every capture/driver flag — so no suite, no
## `--screenshot`/`--show-screen` capture and no driver ever waits on a fade.
## `--write-movie` is an engine flag, not a user one, so a movie capture keeps
## the fade. Tests opt back in with `force`.

const Settings := preload("res://scripts/settings.gd")

const FADE_S := 0.15 # each way: 0.3 s through black
const LAYER := 127 # above every scene's own layers, below CrtOverlay's 128
const NODE_NAME := "SceneFade"
## The flags that must stay instant (intro.gd's should_bypass, plus the
## capture and driver flags — tools/capture.md).
const SKIP_ARGS := ["--autoplay", "--scenario", "--scenario-name", "--screenshot",
	"--show-screen", "--ui-demo", "--drive"]

static var force := false # tests: animate even under `-s`


static func animate() -> bool:
	if force:
		return true
	if DisplayServer.get_name() == "headless":
		return false
	# a test harness: `-s tests/...` swaps in a SceneTree script as the main
	# loop, which a real launch never has
	var engine_args := OS.get_cmdline_args()
	if engine_args.has("-s") or engine_args.has("--script") \
			or Engine.get_main_loop().get_script() != null:
		return false
	for a in OS.get_cmdline_user_args():
		if a in SKIP_ARGS:
			return false
	return bool(Settings.load_settings().get("animations_on", true))


## Changes to the scene at `path` through black. Safe from a button's
## `pressed` (the old scene stays up for the fade-out and is swapped by the
## engine as usual).
static func go(tree: SceneTree, path: String) -> void:
	if tree.root.has_node(NODE_NAME):
		return # a fade is already running; it owns the change
	if not animate():
		tree.change_scene_to_file(path)
		return
	var layer := CanvasLayer.new()
	layer.name = NODE_NAME
	layer.layer = LAYER
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.modulate.a = 0.0
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(black)
	tree.root.add_child(layer)
	var tw := layer.create_tween()
	tw.tween_property(black, "modulate:a", 1.0, FADE_S)
	tw.tween_callback(func() -> void: tree.change_scene_to_file(path))
	tw.tween_property(black, "modulate:a", 0.0, FADE_S)
	tw.tween_callback(func() -> void:
		layer.name = NODE_NAME + "Done" # free for the next go() at once
		layer.queue_free())
