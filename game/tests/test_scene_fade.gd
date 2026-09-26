extends SceneTree
## NO-243 S4 (audit rows 61/62): scene changes fade through black via
## scripts/scene_fade.gd. Proves: a test harness run is instant (no layer,
## the scene swaps as before); a forced fade still reaches the Menu and the
## Game and then removes itself; a second change during a fade is dropped;
## the black layer takes no input. (A real click during the fade-in is in
## the windowed test_menu_clicks.gd — headless drops GUI picking.)
## Run headless:  godot --headless --path game -s tests/test_scene_fade.gd

const SceneFade := preload("res://scripts/scene_fade.gd")
const GameScript := preload("res://scripts/game.gd")
const Account := preload("res://scripts/account.gd")

const MENU := "res://scenes/Menu.tscn"
const GAME := "res://scenes/Game.tscn"

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _layer() -> Node:
	return root.get_node_or_null(SceneFade.NODE_NAME)


func _on(path: String) -> bool:
	return current_scene != null and current_scene.scene_file_path == path


## Frames until `path` is the current scene, capped (never a bare while-await).
func _wait_scene(path: String, cap := 120) -> int:
	var n := 0
	while not _on(path) and n < cap:
		await process_frame
		n += 1
	return n


func _wait_gone(cap := 120) -> int:
	var n := 0
	while _layer() != null and n < cap:
		await process_frame
		n += 1
	return n


func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: test_scene_fade still running after 60s")
		quit(1))
	Account._reset_cache()
	Account.start_guest() # the Menu comes up on its main screen, not the login
	GameScript.reset_boot_defaults()
	GameScript.next_seed = "1" # the Game boots below: seed pinned
	GameScript.next_config = {"seed": 1, "board": [["queen", 0, 2, 2]], "wave": 1}
	GameScript.is_scenario = true # never autosaves

	# --- a test harness is instant: no layer, the swap is the engine's own ---
	check(not SceneFade.animate(), "under -s, animate() is false (tests never wait on a fade)")
	SceneFade.go(self, MENU)
	check(_layer() == null, "instant: no fade layer is created")
	await process_frame
	await process_frame
	check(_on(MENU), "instant: the Menu is reached as before")

	# --- forced: through black, and the change still lands ---
	SceneFade.force = true
	SceneFade.go(self, GAME)
	var layer := _layer()
	check(layer != null and layer is CanvasLayer, "forced: a fade layer goes up on the root")
	var blacks: Array[Node] = []
	if layer != null:
		blacks = layer.find_children("*", "Control", true, false)
	var dead := blacks.size() > 0
	for c in blacks:
		dead = dead and (c as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE
	check(dead, "the black layer takes no input (every Control IGNORE)")
	check(_on(MENU), "the old scene stays up for the fade-out")
	SceneFade.go(self, MENU) # a double tap during the fade
	await process_frame
	var mid_alpha: float = (blacks[0] as Control).modulate.a if blacks.size() > 0 else -1.0
	check(mid_alpha > 0.0, "the screen darkens (alpha %.2f)" % mid_alpha)
	var frames := await _wait_scene(GAME)
	check(_on(GAME), "forced: the Game is reached (%d frames)" % frames)
	check(_layer() != null, "...under the black, which then fades back in")
	var gone := await _wait_gone()
	check(_layer() == null, "the layer frees itself after the fade-in (%d frames)" % gone)
	for i in 3:
		await process_frame
	check(_on(GAME), "the double tap was dropped: still on the Game")

	# --- and back to the Menu ---
	SceneFade.go(self, MENU)
	frames = await _wait_scene(MENU)
	check(_on(MENU), "forced: Game -> Menu is reached (%d frames)" % frames)
	await _wait_gone()
	check(_layer() == null, "...and the layer is gone again")
	SceneFade.force = false

	print("---")
	if fails == 0:
		print("ALL GREEN")
		quit(0)
	else:
		print("FAILED: %d" % fails)
		quit(1)
