extends Node2D
## The whole run: SETUP placement -> PLAYER_TURN <-> ENEMY_TURN -> GAME_OVER.
## All UI is built in code; rules.gd holds every game-logic decision.

const Rules := preload("res://scripts/rules.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Waves := preload("res://data/waves.gd")
const Items := preload("res://data/items.gd")
const Tariffs := preload("res://data/tariffs.gd")
const Scenarios := preload("res://data/scenarios.gd")

enum State { SETUP, PLAYER_TURN, ENEMY_TURN, GAME_OVER }

## Boot config for the next Game scene (menu sets it; Restart replays it).
## Shape documented in data/scenarios.gd — this is the future save format.
static var next_config := {}

const COL_LIGHT := Color("f0d9b5")
const COL_DARK := Color("b58863")
const COL_PLAYER := Color("1a3a6b")
const COL_ENEMY := Color("8b1a1a")
const COL_MOVE := Color(0.2, 0.6, 0.3, 0.55)
const COL_CAPTURE := Color(0.85, 0.15, 0.15)
const COL_SELECT := Color(0.95, 0.85, 0.2, 0.6)
const ANIM_TIME := 0.12 # seconds per move slide / capture pop

# board layout, computed from the viewport in _ready so any BOARD_W/H fits
var tile := 72
var board_px := Vector2(24, 120)

var defs: Dictionary
var fusions: Dictionary # unordered pair "a+b" -> result id
var textures := {} # id -> Texture2D; missing ids fall back to glyph text
var board := {} # Vector2i -> {id, owner}
var state := State.SETUP
var wave := 0            # last spawned wave number
var turns_since_wave := 0
var pending_spawn: Array = [] # piece ids waiting for open top-row tiles
var score := 0:
	set(value): # every gain/loss anywhere pops floating feedback (round 4)
		if value != score and is_node_ready() and not autoplay:
			var d := value - score
			anims.append({"kind": "text", "t": 0.0, "dur": 1.2,
				"text": ("+%d" if d > 0 else "%d") % d,
				"at_px": score_label.get_global_rect().end + Vector2(6, 0),
				"color": Color(0.3, 0.85, 0.35) if d > 0 else Color(0.95, 0.3, 0.25)})
			queue_redraw()
		score = value
var merges_left := 0
var clock_ms := float(Tuning.CLOCK_START_MS)
var stock: Array = []
var captured: Array = []
var moves_left := 0
var placements_left := 0
var selected := Vector2i(-1, -1) # selected board piece
var legal_dests: Array[Vector2i] = []
var moved_this_turn: Array[Vector2i] = [] # pieces (by tile) that already moved
var drag_from := Vector2i(-1, -1) # board drag in progress; ghost follows the mouse
var press_tile := Vector2i(-1, -1) # candidate long-press (piece preview)
var press_ms := 0
var pool_press_id := "" # candidate long-press on a pool button
var pool_press_ms := 0
var preview_open := false
var placing_index := -1  # stock index being placed, -1 = none
var merge_mode := false
var merge_sel: Array = [] # int = combined-pool index, Vector2i = board tile
var merge_highlights := {} # ids that can merge right now (merge-mode UX)
var anims: Array = [] # {kind: "move"|"pop", t, ...} rendered by _draw
var items: Array = [] # held Items (single-use actives), max HUD row
var trinkets: Array = [] # run-long passive effects
var box_open := false # box-pick modal showing; blocks all other input
var pass_after_box := false # auto-pass deferred until the pick resolves
var item_active := -1 # items[] index being targeted, -1 = none
var item_stage_a := Vector2i(-1, -1) # first pick of a "pair" item
var item_targets: Array[Vector2i] = [] # valid target tiles for the active item
var free_placements := 0 # Field Orders
var ceasefire_turns := 0 # Cease Fire: clock paused while > 0
var skip_enemy_turns := 0 # Surprise Attack
var turn_action_count := 0 # moves+placements taken this turn (trinket hook)
var recent_place_costs: Array = [] # last 3 paid placement costs (Resupply Drop)
var tariffs_active: Array = [] # action + persistent tariffs, run-long
var tariffs_seen: Array = [] # every activation, for the end screens
var sanctioned_id := "" # Sanctions: piece type barred from placement
var counter_intel_turns := 0 # Counter-Intel: tariffs suppressed while > 0
var rng := RandomNumberGenerator.new()

var autoplay := false
var autoplay_turns := 0
var autoplay_cap := 2000 # --steps N overrides, for short scenario sweeps
var screenshot_dir := "" # debug: save PNGs for agent visual verification

# HUD nodes
var hud := CanvasLayer.new()
var clock_label := Label.new()
var score_label := Label.new()
var wave_label := Label.new()
var turn_label := Label.new()
var pass_button := Button.new()
var tariff_label := Label.new()
var merge_button := Button.new()
var confirm_button := Button.new()
var pool_box := HBoxContainer.new()
var item_box := HBoxContainer.new() # held-items strip
var box_panel := PanelContainer.new() # box-pick modal
var preview_panel := PanelContainer.new() # long-press piece preview
var game_menu := PanelContainer.new() # in-game menu (pauses the clock)
var game_menu_open := false
var overlay := PanelContainer.new()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	autoplay = args.has("--autoplay")
	if args.has("--screenshot"):
		screenshot_dir = args[args.find("--screenshot") + 1]
		if not autoplay: # with --autoplay, the end screen is captured instead
			_screenshot_and_quit(screenshot_dir)
	if args.has("--clock"): # debug: short clock to reach the end screen fast
		clock_ms = float(args[args.find("--clock") + 1]) * 1000.0
	if args.has("--steps"): # debug: shorter autoplay cap for scenario sweeps
		autoplay_cap = int(args[args.find("--steps") + 1])
	var vp := get_viewport_rect().size
	tile = int(minf((vp.x - 48.0) / Tuning.BOARD_W, (vp.y - 224.0) / Tuning.BOARD_H))
	board_px = Vector2(roundf((vp.x - tile * Tuning.BOARD_W) / 2.0), 100)
	defs = Rules.load_pieces()
	fusions = Rules.load_fusions()
	for id in defs:
		# png wins if present (drop painted art in anytime); svg is the
		# generated vector set (tools/generate-piece-art.py)
		for ext in ["png", "svg"]:
			var path := "res://assets/pieces/%s.%s" % [id, ext]
			if ResourceLoader.exists(path):
				textures[id] = load(path)
				break
	rng.randomize()
	_build_hud()
	if args.has("--scenario"): # headless/CLI scenario boot, by index
		next_config = Scenarios.all()[int(args[args.find("--scenario") + 1])].cfg
	merges_left = Tuning.MERGES_PER_TURN
	if next_config.is_empty():
		stock = Tuning.STARTING_STOCK.duplicate()
	else:
		_apply_config(next_config)
	if args.has("--scenario-check"): # boots, runs one frame, exits — CI probe
		await get_tree().process_frame
		await get_tree().process_frame
		print("SCENARIO OK")
		get_tree().quit()
	_refresh()


## Start the game from a config Dictionary instead of the normal SETUP flow.
## Every field of run state is settable — the same mechanism a saved game
## will restore from.
func _apply_config(cfg: Dictionary) -> void:
	stock = cfg.get("stock", []).duplicate()
	captured = cfg.get("captured", []).duplicate()
	score = cfg.get("score", 0)
	clock_ms = cfg.get("clock_s", Tuning.CLOCK_START_MS / 1000.0) * 1000.0
	# default: all designed waves done, so nothing spawns into the sandbox
	wave = cfg.get("wave", Waves.WAVES.size())
	turns_since_wave = cfg.get("turns_since_wave", 0)
	for p in cfg.get("board", []):
		var piece := {"id": p[0], "owner": int(p[1])}
		if p.size() > 4 and p[4] == "buff":
			piece.buff = true
		board[Vector2i(int(p[2]), int(p[3]))] = piece
	for key in cfg.get("items", []):
		for it in Items.ITEMS:
			if it.key == key:
				items.append(it)
	for key in cfg.get("trinkets", []):
		for t in Items.TRINKET_EFFECTS:
			if t.key == key:
				trinkets.append(t)
	for key in cfg.get("tariffs", []) + cfg.get("oneoffs", []):
		_activate_tariff_by_key(key)
	if cfg.has("sanctioned_id"): # a save must restore the exact barred type
		sanctioned_id = cfg.sanctioned_id
	# ponytail: not yet in the config shape — mid-turn state (moves/placements
	# left, moved_this_turn) and item counters (free_placements, ceasefire,
	# skip_enemy_turns, counter_intel_turns, recent_place_costs). Add when the
	# save system lands; scenario boots always start at a fresh turn.
	_begin_player_turn()


func _build_hud() -> void:
	add_child(hud)
	for l: Label in [clock_label, score_label, wave_label, turn_label]:
		l.add_theme_font_size_override("font_size", 20)
	turn_label.add_theme_font_size_override("font_size", 17) # 4 counters + wave fit
	score_label.add_theme_font_size_override("font_size", 24) # score front & center
	score_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.25))
	var top := HBoxContainer.new()
	top.position = Vector2(24, 12)
	top.custom_minimum_size = Vector2(432, 0)
	top.add_theme_constant_override("separation", 18)
	for l in [clock_label, score_label, wave_label]:
		top.add_child(l)
	hud.add_child(top)
	turn_label.position = Vector2(24, 44)
	turn_label.custom_minimum_size = Vector2(348, 0)
	turn_label.size = Vector2(348, 26)
	turn_label.clip_text = true # PASS button sits to the right
	hud.add_child(turn_label)
	tariff_label.position = Vector2(24, 72)
	tariff_label.add_theme_font_size_override("font_size", 13)
	tariff_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	tariff_label.custom_minimum_size = Vector2(432, 0)
	tariff_label.size = Vector2(432, 20)
	tariff_label.clip_text = true
	hud.add_child(tariff_label)

	pass_button.text = "PASS"
	pass_button.add_theme_font_size_override("font_size", 24)
	pass_button.modulate = Color(1, 0.5, 0.5)
	pass_button.position = Vector2(380, 36)
	pass_button.pressed.connect(_on_pass)
	hud.add_child(pass_button)

	var menu_btn := Button.new()
	menu_btn.text = "☰"
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.position = Vector2(444, 6)
	menu_btn.pressed.connect(func() -> void:
		game_menu_open = true
		game_menu.move_to_front() # above every other HUD control
		game_menu.visible = true)
	hud.add_child(menu_btn)

	game_menu.visible = false
	game_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gm_bg := StyleBoxFlat.new()
	gm_bg.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	game_menu.add_theme_stylebox_override("panel", gm_bg)
	var gm_center := CenterContainer.new()
	game_menu.add_child(gm_center)
	var gm_box := VBoxContainer.new()
	gm_box.add_theme_constant_override("separation", 20)
	gm_center.add_child(gm_box)
	var gm_title := Label.new()
	gm_title.text = "Paused" # menu open = clock frozen (GDD pause)
	gm_title.add_theme_font_size_override("font_size", 32)
	gm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gm_box.add_child(gm_title)
	var resume := Button.new()
	resume.text = "Resume"
	resume.add_theme_font_size_override("font_size", 26)
	resume.pressed.connect(func() -> void:
		game_menu_open = false
		game_menu.visible = false)
	gm_box.add_child(resume)
	var to_menu := Button.new()
	to_menu.text = "Main Menu"
	to_menu.add_theme_font_size_override("font_size", 20)
	to_menu.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	gm_box.add_child(to_menu)
	hud.add_child(game_menu)

	merge_button.text = "Merge"
	merge_button.toggle_mode = true
	merge_button.position = Vector2(24, 756)
	merge_button.toggled.connect(func(on: bool) -> void:
		merge_mode = on
		merge_sel.clear()
		placing_index = -1
		selected = Vector2i(-1, -1)
		legal_dests.clear()
		_refresh())
	hud.add_child(merge_button)

	confirm_button.text = "Confirm merge"
	confirm_button.position = Vector2(110, 756)
	confirm_button.visible = false
	confirm_button.pressed.connect(_on_confirm_merge)
	hud.add_child(confirm_button)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 700)
	scroll.custom_minimum_size = Vector2(432, 52)
	scroll.add_child(pool_box)
	hud.add_child(scroll)

	var item_scroll := ScrollContainer.new()
	item_scroll.position = Vector2(210, 748)
	item_scroll.custom_minimum_size = Vector2(246, 50)
	item_scroll.add_child(item_box)
	hud.add_child(item_scroll)

	box_panel.visible = false
	box_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var box_bg := StyleBoxFlat.new()
	box_bg.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	box_panel.add_theme_stylebox_override("panel", box_bg)
	hud.add_child(box_panel)

	preview_panel.visible = false
	preview_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pv_bg := StyleBoxFlat.new()
	pv_bg.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	preview_panel.add_theme_stylebox_override("panel", pv_bg)
	hud.add_child(preview_panel)

	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := StyleBoxFlat.new()
	dim.bg_color = Color(0.08, 0.08, 0.1, 0.93)
	overlay.add_theme_stylebox_override("panel", dim)
	hud.add_child(overlay)


## Combined pool the player can act on: stock first, then captured.
func _pool() -> Array:
	return stock + captured


func _pool_take(index: int) -> String:
	if index < stock.size():
		return stock.pop_at(index)
	return captured.pop_at(index - stock.size())


func _clock_text() -> String:
	return "⏱ %02d:%02d.%01d" % [int(clock_ms / 60000), int(clock_ms / 1000) % 60, int(clock_ms / 100) % 10]


func _refresh() -> void:
	clock_label.text = _clock_text()
	score_label.text = "Score %d" % score
	wave_label.text = "wave %d/%d" % [wave, Waves.WAVES.size()]
	match state:
		State.SETUP:
			turn_label.text = "Place army (%d left) → PASS" % stock.size()
		State.PLAYER_TURN:
			var next_in := _cadence() - turns_since_wave
			var wave_txt := "King wave!" if _king_alive() else ("wave in %d" % maxi(next_in, 0)) if wave < Waves.WAVES.size() else "no more waves"
			turn_label.text = "moves %d · place %d · merge %d · %s" % [moves_left, placements_left, merges_left, wave_txt]
		State.ENEMY_TURN:
			turn_label.text = "enemy turn…"
		State.GAME_OVER:
			turn_label.text = ""
	merge_highlights = _merge_highlight_ids() if merge_mode else {}
	var names := []
	for t in tariffs_active:
		names.append(t.name.trim_prefix("Tariff on "))
	tariff_label.text = "" if names.is_empty() else "⚠ " + ", ".join(names) \
			+ (" (suppressed)" if counter_intel_turns > 0 else "")
	_rebuild_pool_strip()
	_rebuild_item_strip()
	confirm_button.visible = merge_mode and merges_left > 0 \
			and Rules.merge_result(_merge_ids(), defs, fusions) != ""
	queue_redraw()


func _rebuild_item_strip() -> void:
	for c in item_box.get_children():
		c.queue_free()
	for i in items.size():
		var btn := Button.new()
		btn.text = "✦" + items[i].name
		btn.tooltip_text = "%s (%s)\n%s" % [items[i].name, items[i].tier, items[i].description]
		if item_active == i:
			btn.modulate = Color(0.5, 1.3, 1.3)
		btn.pressed.connect(_use_item.bind(i))
		item_box.add_child(btn)


func _rebuild_pool_strip() -> void:
	for c in pool_box.get_children():
		c.queue_free()
	var pool := _pool()
	for i in pool.size():
		var btn := Button.new()
		var from_captured: bool = i >= stock.size()
		var id: String = pool[i]
		if textures.has(id): # piece icon instead of glyph text (round 3)
			btn.icon = textures[id]
			btn.expand_icon = true
			btn.custom_minimum_size = Vector2(46, 46)
		else:
			btn.text = defs[id].glyph
			btn.add_theme_font_size_override("font_size", 22)
		btn.tooltip_text = defs[id].name + (" (captured)" if from_captured else "")
		if merge_mode and merge_sel.has(i):
			btn.modulate = Color(1.3, 1.15, 0.4)
		elif merge_mode: # mergeable pieces pop; the rest dim
			btn.modulate = Color(1.2, 1.05, 0.55) if merge_highlights.has(id) else Color(0.5, 0.5, 0.5)
		elif placing_index == i:
			btn.modulate = Color(0.6, 1.2, 0.6)
		elif not from_captured and id == sanctioned_id and _tariff_on("sanctions"):
			btn.modulate = Color(1.0, 0.45, 0.45) # Sanctions: unplaceable
		elif from_captured:
			btn.modulate = Color(1.0, 0.8, 0.8) # captured stock: warm tint
		btn.pressed.connect(_on_pool_pressed.bind(i))
		btn.button_down.connect(func() -> void:
			pool_press_id = id
			pool_press_ms = Time.get_ticks_msec())
		btn.button_up.connect(func() -> void: pool_press_id = "")
		pool_box.add_child(btn)


## Ids that can participate in a merge right now: with nothing selected, any id
## with a valid partner among the player's pieces (pool + board); with one
## selected, only ids completing a merge with it.
func _merge_highlight_ids() -> Dictionary:
	var all: Array = _pool()
	for pos in _player_pieces():
		all.append(board[pos].id)
	var out := {}
	if merge_sel.size() == 1:
		var sel: String = _merge_ids()[0]
		var counts := {}
		for id in all:
			counts[id] = counts.get(id, 0) + 1
		for id in all:
			if id == sel and counts[id] < 2:
				continue # a self-pair needs a second copy
			if Rules.merge_result([sel, id], defs, fusions) != "":
				out[id] = true
	elif merge_sel.is_empty():
		for i in all.size():
			for j in range(i + 1, all.size()):
				if Rules.merge_result([all[i], all[j]], defs, fusions) != "":
					out[all[i]] = true
					out[all[j]] = true
	return out


func _merge_ids() -> Array:
	var pool := _pool()
	var ids := []
	for ref in merge_sel:
		ids.append(board[ref].id if ref is Vector2i else pool[ref])
	return ids


func _on_pool_pressed(index: int) -> void:
	if state == State.GAME_OVER or state == State.ENEMY_TURN or box_open \
			or preview_open or game_menu_open:
		return
	if merge_mode:
		if merge_sel.has(index):
			merge_sel.erase(index)
		elif merge_sel.size() < 2:
			merge_sel.append(index)
	else:
		# placement: only stock pieces are placeable (captured merge in first)
		if index >= stock.size():
			return
		if stock[index] == sanctioned_id and _tariff_on("sanctions"):
			return
		var can_place: bool = state == State.SETUP or placements_left > 0
		placing_index = index if placing_index != index and can_place else -1
		selected = Vector2i(-1, -1)
	_refresh()


func _on_confirm_merge() -> void:
	if merges_left <= 0:
		return
	var result := Rules.merge_result(_merge_ids(), defs, fusions)
	if result == "":
		return
	if _tariff_on("regulation") and _merge_ids().has("pawn"):
		return # Regulation: pawns can't be merged
	merges_left -= 1
	_charge("fuse_cost")
	# if any source stood on the board, the result appears on the LAST-selected
	# board tile (grilled 2026-07-02); pool-only merges send it to Stock
	var result_tile := Vector2i(-1, -1)
	var pool_refs: Array[int] = []
	for ref in merge_sel:
		if ref is Vector2i:
			result_tile = ref # later selections win
			board.erase(ref)
		else:
			pool_refs.append(ref)
	pool_refs.sort()
	pool_refs.reverse() # remove high indices first so the rest stay valid
	for i in pool_refs:
		_pool_take(i)
	if result_tile.x >= 0:
		board[result_tile] = {"id": result, "owner": Rules.PLAYER}
	else:
		stock.append(result)
	merge_sel.clear()
	merge_button.button_pressed = false # merge done -> mode off (round 3)
	_refresh()


func _on_pass() -> void:
	if box_open or game_menu_open:
		return
	if state == State.SETUP:
		_spawn_wave(1)
		_begin_player_turn()
	elif state == State.PLAYER_TURN:
		_charge("pass_cost")
		_enemy_turn()


func _process(delta: float) -> void:
	if autoplay and state == State.SETUP:
		# place the whole starting stock on random zone tiles, then begin
		var open := _setup_open_tiles()
		if stock.is_empty() or open.is_empty():
			_on_pass()
		else:
			_place(rng.randi() % stock.size(), open[rng.randi() % open.size()])
		return
	if state == State.PLAYER_TURN:
		if ceasefire_turns <= 0 and not game_menu_open: # menu open = paused
			clock_ms -= delta * 1000.0
		if clock_ms <= 0:
			clock_ms = 0
			return _game_over(false, "Clock out")
		clock_label.text = _clock_text()
		if autoplay:
			_autoplay_step()
	if not anims.is_empty():
		for a in anims:
			a.t += delta / a.get("dur", ANIM_TIME)
		anims = anims.filter(func(a: Dictionary) -> bool: return a.t < 1.0)
		queue_redraw()
	if press_tile.x >= 0 and not preview_open \
			and Time.get_ticks_msec() - press_ms > 500: # long-press -> preview
		var id: String = board[press_tile].id if board.has(press_tile) else ""
		press_tile = Vector2i(-1, -1)
		drag_from = Vector2i(-1, -1)
		if id != "":
			_show_preview(id)
	if pool_press_id != "" and not preview_open \
			and Time.get_ticks_msec() - pool_press_ms > 500:
		var id := pool_press_id
		pool_press_id = ""
		_show_preview(id) # the release lands while preview_open and is swallowed


# --- turn flow ---

func _begin_player_turn() -> void:
	state = State.PLAYER_TURN
	moves_left = Tuning.MOVES_PER_TURN
	for t in trinkets:
		if t.key == "move":
			moves_left += 1
	placements_left = Tuning.PLACEMENTS_PER_TURN
	merges_left = Tuning.MERGES_PER_TURN
	moved_this_turn.clear()
	turn_action_count = 0
	counter_intel_turns = maxi(counter_intel_turns - 1, 0)
	# board cleared early -> skip the cadence wait, next wave arrives now
	if wave < Waves.WAVES.size() and pending_spawn.is_empty() and not _any_enemy():
		_queue_wave(wave + 1)
	_spawn_pending()
	if _player_pieces().is_empty() and stock.is_empty() and not Rules.has_merge(_pool(), defs, fusions):
		return _game_over(false, "Resource starvation")
	_refresh()


func _enemy_turn() -> void:
	state = State.ENEMY_TURN
	selected = Vector2i(-1, -1)
	placing_index = -1
	_item_reset()
	merge_sel.clear()
	merge_button.button_pressed = false # also resets merge_mode via its toggle
	_refresh()
	turns_since_wave += 1
	ceasefire_turns = maxi(ceasefire_turns - 1, 0)
	if wave < Waves.WAVES.size() and not _king_alive() and turns_since_wave >= _cadence():
		_queue_wave(wave + 1)
	if skip_enemy_turns > 0: # Surprise Attack: the enemy sits this one out
		skip_enemy_turns -= 1
	else:
		await _run_enemy_actions()
	if state != State.GAME_OVER:
		_begin_player_turn()


func _run_enemy_actions() -> void:
	var actions := Tuning.ENEMY_ACTIONS_PER_TURN
	if _tariff_on("filibuster"):
		actions += 1
	for i in actions:
		var act := Rules.ai_action(board, defs)
		if act.is_empty():
			return
		if not autoplay:
			await get_tree().create_timer(0.35).timeout
		if board.has(act.to):
			_add_pop(act.to)
		_add_slide(act.from, act.to)
		board[act.to] = board[act.from]
		board.erase(act.from)
		queue_redraw()
		if _back_row_breached():
			return _game_over(false, "Back-row breach")


func _add_slide(from: Vector2i, to: Vector2i) -> void:
	if autoplay:
		return
	anims.append({"kind": "move", "to": to, "from_px": _tile_px(from), "to_px": _tile_px(to), "t": 0.0})


func _add_pop(at: Vector2i) -> void:
	if autoplay:
		return
	anims.append({"kind": "pop", "at_px": _tile_px(at) + Vector2(tile, tile) / 2, "t": 0.0})


## Loss only when EVERY back-row tile holds an enemy (playtest rule 2026-07-02;
## a single enemy reaching row 0 no longer ends the run).
func _back_row_breached() -> bool:
	for x in Tuning.BOARD_W:
		var t := Vector2i(x, 0)
		if not board.has(t) or board[t].owner != Rules.ENEMY:
			return false
	return true


func _cadence() -> int:
	var next_wave_i: int = mini(wave, Waves.WAVES.size() - 1)
	return Tuning.CADENCE_BASE + Waves.WAVES[next_wave_i].size()


func _king_alive() -> bool:
	return Rules.find_king(board, Rules.ENEMY).x >= 0


func _queue_wave(n: int) -> void:
	wave = n
	turns_since_wave = 0
	var buff_id: String = Waves.BUFFS.get(n, "")
	var roster: Array = Waves.WAVES[n - 1].duplicate()
	if _tariff_on("trade_war"): # +1 piece per wave, drawn from the wave's own mix
		roster.append(roster[rng.randi() % roster.size()])
	for id in roster:
		var entry := {"id": id}
		if id == buff_id: # first spawned piece of the flagged type carries the box
			entry.buff = true
			buff_id = ""
		pending_spawn.append(entry)
	if n == 2:
		_activate_tariff_by_key("inflation") # T0, GDD: fires after wave 1
	elif Tariffs.SCHEDULE.has(n):
		_activate_tariff(Tariffs.SCHEDULE[n])
	if n % Tuning.MILESTONE_WAVES == 0:
		var refill: float = Tuning.CLOCK_REFILL_MS
		for t in trinkets:
			if t.key == "timer":
				refill += 5000
		if _tariff_on("recession"):
			refill *= 0.5
		clock_ms += refill
		score += _gain(Tuning.MILESTONE_SCORE_BONUS)


func _spawn_wave(n: int) -> void:
	_queue_wave(n)
	_spawn_pending()


func _spawn_pending() -> void:
	while not pending_spawn.is_empty():
		# spawns land on any top-row tile not held by an enemy; a friendly piece
		# there is captured by the arrival (so the spawn row can't be blockaded)
		var open: Array[Vector2i] = []
		for x in Tuning.BOARD_W:
			var pos := Vector2i(x, Tuning.SPAWN_ROW)
			if not board.has(pos) or board[pos].owner == Rules.PLAYER:
				open.append(pos)
		if open.is_empty():
			return # row full of enemies — spill to next player turn
		var spot: Vector2i = open[rng.randi() % open.size()]
		var entry: Dictionary = pending_spawn.pop_front()
		board[spot] = {"id": entry.id, "owner": Rules.ENEMY}
		if entry.get("buff", false):
			board[spot].buff = true


func _setup_open_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in Tuning.BOARD_W:
		for y in Tuning.PLAYER_ZONE_ROWS:
			if not board.has(Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out


func _any_enemy() -> bool:
	for pos in board:
		if board[pos].owner == Rules.ENEMY:
			return true
	return false


func _player_pieces() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pos in board:
		if board[pos].owner == Rules.PLAYER:
			out.append(pos)
	return out


func _game_over(won: bool, reason: String) -> void:
	state = State.GAME_OVER
	_show_overlay(won, reason)
	_refresh()
	if autoplay:
		print("AUTOPLAY RESULT: %s — %s (wave %d, score %d, %d turns)" % ["WIN" if won else "LOSS", reason, wave, score, autoplay_turns])
		if screenshot_dir != "":
			_end_shot() # fire-and-forget: capture the end screen, then quit
		else:
			get_tree().quit(0)


func _end_shot() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_dir.path_join("gameover.png"))
	get_tree().quit()


func _show_overlay(won: bool, reason: String) -> void:
	for c in overlay.get_children():
		c.queue_free()
	var center := CenterContainer.new()
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var title := Label.new()
	title.text = "VICTORY — the King has fallen" if won else "GAME OVER"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var detail := Label.new()
	detail.text = "%s\nScore %d · Deepest wave %d · Tariffs %d" % [reason, score, wave, tariffs_seen.size()]
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 22)
	box.add_child(detail)
	var restart := Button.new()
	restart.text = "Restart"
	restart.add_theme_font_size_override("font_size", 26)
	restart.pressed.connect(func() -> void: get_tree().reload_current_scene())
	box.add_child(restart)
	var menu := Button.new()
	menu.text = "Main Menu"
	menu.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	box.add_child(menu)
	overlay.visible = true


# --- input ---

func _unhandled_input(event: InputEvent) -> void:
	if preview_open or game_menu_open:
		return # the panels' own buttons handle dismissal
	if state == State.GAME_OVER or state == State.ENEMY_TURN or box_open:
		drag_from = Vector2i(-1, -1)
		press_tile = Vector2i(-1, -1)
		return
	if event is InputEventMouseMotion:
		if press_tile.x >= 0 and event.button_mask & MOUSE_BUTTON_MASK_LEFT \
				and event.position.distance_to(_tile_px(press_tile) + Vector2(tile, tile) / 2) > tile:
			press_tile = Vector2i(-1, -1) # dragged away while held: not a long-press
		if drag_from.x >= 0:
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at := _tile_at(event.position)
		if event.pressed:
			if at.x >= 0 and board.has(at): # any piece: candidate long-press preview
				press_tile = at
				press_ms = Time.get_ticks_msec()
			if at.x >= 0:
				_on_tile_clicked(at)
			# a fresh selection of an own piece also starts a potential drag
			if selected == at and at.x >= 0:
				drag_from = at
		else:
			press_tile = Vector2i(-1, -1)
			if drag_from.x >= 0: # release ends a drag
				var t := _tile_at(event.position)
				var from := drag_from
				drag_from = Vector2i(-1, -1)
				if t != from and legal_dests.has(t):
					_move_player(from, t)
				else: # release on origin = plain select; elsewhere = cancel ghost only
					queue_redraw()


func _tile_at(screen: Vector2) -> Vector2i:
	var local := screen - board_px
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var x := int(local.x / tile)
	var y := Tuning.BOARD_H - 1 - int(local.y / tile)
	return Vector2i(x, y) if Rules.in_bounds(Vector2i(x, y)) else Vector2i(-1, -1)


func _on_tile_clicked(tile: Vector2i) -> void:
	if item_active >= 0: # an item is targeting; board clicks feed it
		_item_click(tile)
		return
	if merge_mode: # board clicks select merge sources, nothing else
		if board.has(tile) and board[tile].owner == Rules.PLAYER:
			if merge_sel.has(tile):
				merge_sel.erase(tile)
			elif merge_sel.size() < 2:
				merge_sel.append(tile)
			_refresh()
		return
	if placing_index >= 0:
		var ok := tile.y < Tuning.PLAYER_ZONE_ROWS if state == State.SETUP else Rules.placement_tiles(board).has(tile)
		if ok and not board.has(tile):
			_place(placing_index, tile)
		return
	if state != State.PLAYER_TURN:
		return
	if selected.x >= 0 and legal_dests.has(tile):
		_move_player(selected, tile)
	elif board.has(tile) and board[tile].owner == Rules.PLAYER and moves_left > 0 \
			and not moved_this_turn.has(tile):
		selected = tile
		legal_dests = Rules.moves_for(board, tile, defs)
		_refresh()
	else:
		selected = Vector2i(-1, -1)
		legal_dests.clear()
		_refresh()


func _place(pool_index: int, tile: Vector2i) -> void:
	var id := _pool_take(pool_index)
	board[tile] = {"id": id, "owner": Rules.PLAYER}
	placing_index = -1
	if state == State.PLAYER_TURN:
		placements_left -= 1
		turn_action_count += 1
		var cost := Tuning.PLACEMENT_SCORE_COST
		if _tariff_on("austerity"):
			cost *= 2
		if free_placements > 0: # Field Orders
			free_placements -= 1
			cost = 0
		_charge("deploy_cost")
		score = maxi(score - cost, 0)
		recent_place_costs.append(cost)
		if recent_place_costs.size() > 3:
			recent_place_costs.pop_front()
	_refresh()


func _move_player(from: Vector2i, to: Vector2i) -> void:
	var boxed := false
	if board.has(to): # capture
		var victim: Dictionary = board[to]
		score += _gain(_capture_score(victim.id))
		_charge("capture_cost")
		if victim.id == "king":
			return _win()
		captured.append(victim.id)
		boxed = victim.get("buff", false)
		_add_pop(to)
	_charge("move_cost")
	if board[from].id in ["bishop", "rook"]:
		var d := to - from
		_charge("long_range_cost", Tuning.TARIFF_LR_PER_SQUARE * maxi(absi(d.x), absi(d.y)))
	_add_slide(from, to)
	board[to] = board[from]
	board.erase(from)
	moves_left -= 1
	turn_action_count += 1
	moved_this_turn.append(to)
	selected = Vector2i(-1, -1)
	legal_dests.clear()
	if _king_alive() and Rules.is_checkmate(board, Rules.ENEMY, defs):
		return _win()
	if moves_left == 0 and state == State.PLAYER_TURN:
		if boxed: # resolve the box first; the pick UI defers the auto-pass
			pass_after_box = true
		else:
			return _on_pass() # last move auto-passes (playtest 2026-07-02)
	if boxed:
		return _open_box_pick()
	_refresh()


func _capture_score(victim_id: String) -> int:
	var base: int = defs[victim_id].value
	var pts := base
	for t in trinkets: # run-long passives (stack per copy)
		match t.key:
			"greed":
				if victim_id == "pawn":
					pts += 1
			"score":
				pts += 1
			"bounty":
				if base >= 5:
					pts += 3
			"lifesteal":
				clock_ms += 2000
			"first_capture_extra":
				if turn_action_count == 0:
					moves_left += 1
	return pts


func _win() -> void:
	score += Tuning.WIN_SCORE_BONUS
	_game_over(true, "Wave-%d King checkmated" % wave)


# --- piece preview (long-press a piece anywhere) ---

func _show_preview(id: String) -> void:
	preview_open = true
	for c in preview_panel.get_children():
		c.queue_free()
	preview_panel.visible = true
	var center := CenterContainer.new()
	preview_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = defs[id].name
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var dia := Control.new()
	var cells := 9 # covers the longest leap (Celestial Kirin's 4)
	var cell := 30
	dia.custom_minimum_size = Vector2(cells, cells) * cell
	dia.draw.connect(_draw_preview_diagram.bind(dia, id, cells, cell))
	box.add_child(dia)

	var legend := Label.new()
	legend.text = "● move + capture      ○ move only      ✕ capture only"
	legend.add_theme_font_size_override("font_size", 13)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(legend)

	var chain := _chain_of(id)
	if chain.size() > 1:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		for i in chain.size():
			if i > 0:
				var arrow := Label.new()
				arrow.text = "→"
				arrow.add_theme_font_size_override("font_size", 22)
				row.add_child(arrow)
			var tr := TextureRect.new()
			tr.texture = textures.get(chain[i])
			tr.custom_minimum_size = Vector2(48, 48)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			if chain[i] != id:
				tr.modulate = Color(1, 1, 1, 0.45) # current stage stands out
			row.add_child(tr)
		box.add_child(row)

	var close := Button.new()
	close.text = "Close"
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(_close_preview)
	box.add_child(close)


func _close_preview() -> void:
	preview_open = false
	preview_panel.visible = false


## The promotion chain containing `id` (base -> ... -> end), or [id].
func _chain_of(id: String) -> Array:
	var prev := {}
	for pid in defs:
		if defs[pid].next != null:
			prev[defs[pid].next] = pid
	var base := id
	while prev.has(base):
		base = prev[base]
	var chain := [base]
	while defs[chain[-1]].next != null:
		chain.append(defs[chain[-1]].next)
	return chain


func _draw_preview_diagram(dia: Control, id: String, cells: int, cell: int) -> void:
	var c := cells / 2
	for x in cells:
		for y in cells:
			dia.draw_rect(Rect2(Vector2(x, y) * cell, Vector2(cell, cell)),
				COL_LIGHT if (x + y) % 2 == 0 else COL_DARK)
	if textures.has(id):
		dia.draw_texture_rect(textures[id],
			Rect2(Vector2(c, c) * cell + Vector2(2, 2), Vector2(cell - 4, cell - 4)), false)
	for m in defs[id].moves:
		for dir in m.dirs:
			var reach: int = int(m.get("range", 0)) if m.type == "ride" else 1
			if reach == 0:
				reach = cells # unbounded ride: to the diagram edge
			for s in range(1, reach + 1):
				var gx: int = c + int(dir[0]) * s
				var gy: int = c - int(dir[1]) * s # board +y is up; screen is down
				if gx < 0 or gx >= cells or gy < 0 or gy >= cells:
					break
				var pc := Vector2(gx, gy) * cell + Vector2(cell, cell) / 2
				match m.mode:
					"both":
						dia.draw_circle(pc, cell * 0.17, Color(0.22, 0.55, 0.28))
					"move":
						dia.draw_arc(pc, cell * 0.17, 0, TAU, 16, Color(0.22, 0.55, 0.28), 2.5)
					"capture":
						var d := cell * 0.13
						dia.draw_line(pc - Vector2(d, d), pc + Vector2(d, d), Color(0.8, 0.2, 0.2), 3.0)
						dia.draw_line(pc + Vector2(d, -d), pc - Vector2(d, -d), Color(0.8, 0.2, 0.2), 3.0)


# --- tariffs (penalties every 10th wave; see data/tariffs.gd) ---

func _activate_tariff(tier: String) -> void:
	var pool := Tariffs.TARIFFS.filter(func(t: Dictionary) -> bool:
		if t.tier != tier:
			return false
		# Mild may repeat; Moderate/Severe are run-unique (GDD Wave Catalog)
		return tier == "Mild" or not tariffs_seen.has(t.name))
	if pool.is_empty():
		return
	_apply_tariff(pool[rng.randi() % pool.size()])


func _activate_tariff_by_key(key: String) -> void:
	for t in Tariffs.TARIFFS:
		if t.key == key:
			return _apply_tariff(t)


func _apply_tariff(t: Dictionary) -> void:
	tariffs_seen.append(t.name)
	if t.kind == "oneoff":
		match t.key:
			"forced_audit":
				captured.clear()
			"asset_seizure":
				stock.clear()
			"asset_freeze":
				score /= 2
			"hostile_takeover":
				var mine := _player_pieces()
				if not mine.is_empty():
					board[mine[rng.randi() % mine.size()]].owner = Rules.ENEMY
			"jd_vance":
				var best := Vector2i(-1, -1)
				for pos in _player_pieces():
					if best.x < 0 or defs[board[pos].id].value > defs[board[best].id].value:
						best = pos
				if best.x >= 0:
					_destroy(best)
		return
	tariffs_active.append(t)
	if t.key == "sanctions": # fix the barred type at trigger time
		var types := {}
		for id in stock + captured:
			types[id] = true
		if not types.is_empty():
			sanctioned_id = types.keys()[rng.randi() % types.size()]


func _tariff_on(key: String) -> bool:
	if counter_intel_turns > 0:
		return false
	for t in tariffs_active:
		if t.key == key:
			return true
	return false


## Score cost charged when a tariffed action happens.
func _charge(key: String, amount: int = Tuning.TARIFF_ACTION_COST) -> void:
	if _tariff_on(key):
		score = maxi(score - amount, 0)


## Score gains pass through Inflation (-10% per stack, rounded down).
func _gain(amount: int) -> int:
	if counter_intel_turns > 0:
		return amount
	var out := float(amount)
	for t in tariffs_active:
		if t.key == "inflation":
			out *= 0.9
	# round, don't truncate: int() zeroed out pawn captures (1 * 0.9 -> 0)
	return roundi(out)


# --- items (single-use actives from the Items catalog) ---

func _use_item(index: int) -> void:
	if state != State.PLAYER_TURN or box_open:
		return
	if item_active == index: # tap again to cancel targeting
		_item_reset()
		_refresh()
		return
	var it: Dictionary = items[index]
	_charge("ability_cost")
	if it.target == "":
		items.remove_at(index)
		_item_apply(it, Vector2i(-1, -1), Vector2i(-1, -1))
		return
	item_active = index
	item_stage_a = Vector2i(-1, -1)
	item_targets = _item_stage_targets(it, Vector2i(-1, -1))
	selected = Vector2i(-1, -1)
	legal_dests.clear()
	placing_index = -1
	_refresh()


func _item_reset() -> void:
	item_active = -1
	item_stage_a = Vector2i(-1, -1)
	item_targets = []


## Valid tiles for the active item; `a` = first pick for "pair" items, or (-1,-1).
func _item_stage_targets(it: Dictionary, a: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in Tuning.BOARD_W:
		for y in Tuning.BOARD_H:
			var pos := Vector2i(x, y)
			if _item_tile_valid(it.key, a, pos):
				out.append(pos)
	return out


func _item_tile_valid(key: String, a: Vector2i, pos: Vector2i) -> bool:
	var occupied := board.has(pos)
	var enemy: bool = occupied and board[pos].owner == Rules.ENEMY
	var own: bool = occupied and board[pos].owner == Rules.PLAYER
	var king: bool = occupied and board[pos].id == "king"
	if a.x < 0: # stage A (or single-tile items)
		match key:
			"demote":
				return occupied and not king
			"air_strike":
				return enemy and not king
			"sniper":
				return enemy and not king and Rules.is_attacked(board, pos, Rules.PLAYER, defs)
			"extraction":
				return own
			"drone_strike", "bombing_run":
				return true
			"tactical_reposition", "decoy_swap", "forced_march":
				return occupied and not king
			"rapid_deployment":
				return own
	else: # stage B of a pair
		match key:
			"tactical_reposition":
				return not occupied and pos.distance_to(a) < 1.5 and pos != a
			"rapid_deployment":
				return not occupied
			"decoy_swap":
				return occupied and not king and pos != a
			"forced_march":
				var d := pos - a
				if pos == a or occupied:
					return false
				var steps := maxi(absi(d.x), absi(d.y))
				if steps > 3 or (d.x != 0 and d.y != 0 and absi(d.x) != absi(d.y)):
					return false
				var step := d.sign()
				for s in range(1, steps): # path must be clear
					if board.has(a + step * s):
						return false
				return true
	return false


func _item_click(tile: Vector2i) -> void:
	if not item_targets.has(tile):
		return
	var it: Dictionary = items[item_active]
	if it.target == "pair" and item_stage_a.x < 0:
		item_stage_a = tile
		item_targets = _item_stage_targets(it, tile)
		_refresh()
		return
	items.remove_at(item_active)
	var a := item_stage_a
	_item_reset()
	_item_apply(it, a, tile)


func _item_apply(it: Dictionary, a: Vector2i, b: Vector2i) -> void:
	match it.key:
		"blitz":
			moves_left += 1
		"asset_recovery":
			if not captured.is_empty():
				captured.append(captured[rng.randi() % captured.size()])
		"field_orders":
			free_placements += 2
		"cease_fire":
			ceasefire_turns += 2
		"surprise_attack":
			skip_enemy_turns += 1
		"suppressing_fire":
			turns_since_wave -= 3
		"cluster_bomb":
			var foes: Array[Vector2i] = []
			for pos in board:
				if board[pos].owner == Rules.ENEMY and board[pos].id != "king":
					foes.append(pos)
			foes.shuffle()
			for pos in foes.slice(0, 3):
				_destroy(pos)
		"conscription":
			var pawns: Array[Vector2i] = []
			for pos in board:
				if board[pos].owner == Rules.PLAYER and board[pos].id == "pawn":
					pawns.append(pos)
			pawns.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return p.y > q.y)
			for pos in pawns:
				var ahead := pos + Vector2i(0, 1)
				if Rules.in_bounds(ahead) and not board.has(ahead):
					_add_slide(pos, ahead)
					board[ahead] = board[pos]
					board.erase(pos)
		"resupply_drop":
			for c in recent_place_costs:
				score += c
			recent_place_costs.clear()
		"counter_intel":
			counter_intel_turns += 2
		"demote":
			board[b].id = "pawn"
		"air_strike", "sniper":
			_destroy(b)
		"extraction":
			stock.append(board[b].id)
			board.erase(b)
		"drone_strike":
			for dx in [0, 1]:
				for dy in [0, 1]:
					var pos := b + Vector2i(dx, dy)
					if board.has(pos) and board[pos].id != "king":
						_destroy(pos)
		"bombing_run":
			for x in Tuning.BOARD_W:
				var pos := Vector2i(x, b.y)
				if board.has(pos) and board[pos].id != "king":
					_destroy(pos)
		"tactical_reposition", "rapid_deployment", "forced_march":
			_add_slide(a, b)
			board[b] = board[a]
			board.erase(a)
		"decoy_swap":
			var tmp: Dictionary = board[a]
			board[a] = board[b]
			board[b] = tmp
	if _king_alive() and Rules.is_checkmate(board, Rules.ENEMY, defs):
		return _win()
	_refresh()


## Item destruction: piece leaves the board — no score, no captured stock.
func _destroy(pos: Vector2i) -> void:
	_add_pop(pos)
	board.erase(pos)


# --- box pick (GDD Game Flow — Box Pick; clock keeps ticking, input modal) ---

func _open_box_pick() -> void:
	box_open = true
	_charge("box_cost")
	if autoplay: # bot: random box, random content — exercises every branch
		var kinds := ["item", "trinket", "score"]
		_box_step2(kinds[rng.randi() % kinds.size()], true)
		return
	_box_step1()


func _box_clear() -> void:
	for c in box_panel.get_children():
		c.queue_free()


func _box_vbox(title_text: String) -> VBoxContainer:
	_box_clear()
	box_panel.visible = true
	var center := CenterContainer.new()
	box_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	return box


func _box_step1() -> void:
	var box := _box_vbox("📦 The enemy dropped a box!")
	for kind_label in [["item", "Item Box — a single-use ability"], ["trinket", "Trinket Box — a passive for the run"], ["score", "Score Box — points, now"]]:
		var b := Button.new()
		b.text = kind_label[1]
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_box_step2.bind(kind_label[0], false))
		box.add_child(b)
	_box_add_skip(box)


func _box_step2(kind: String, bot_pick: bool) -> void:
	var options := []
	match kind:
		"item":
			var pool := Items.ITEMS.duplicate()
			pool.shuffle()
			options = pool.slice(0, 5)
		"trinket":
			var pool := Items.TRINKET_EFFECTS.duplicate()
			pool.shuffle()
			options = pool.slice(0, 5)
		"score":
			var pool := Tuning.SCORE_BOX_CHUNKS.duplicate()
			pool.shuffle()
			for v in pool.slice(0, 5):
				options.append({"name": "+%d score" % v, "value": v})
	if bot_pick:
		return _box_choose(kind, options[rng.randi() % options.size()])
	var box := _box_vbox("Pick one:")
	for opt in options:
		var b := Button.new()
		b.text = opt.name
		b.tooltip_text = opt.get("description", "")
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_box_choose.bind(kind, opt))
		box.add_child(b)
	_box_add_skip(box)


func _box_add_skip(box: VBoxContainer) -> void:
	var skip := Button.new()
	skip.text = "Skip (+%d score)" % Tuning.BOX_SKIP_CONSOLATION
	skip.pressed.connect(func() -> void:
		score += _gain(Tuning.BOX_SKIP_CONSOLATION)
		_box_close())
	box.add_child(skip)


func _box_choose(kind: String, opt: Dictionary) -> void:
	match kind:
		"item":
			items.append(opt)
		"trinket":
			trinkets.append(opt)
		"score":
			score += _gain(opt.value)
	_box_close()


func _box_close() -> void:
	box_open = false
	box_panel.visible = false
	if pass_after_box:
		pass_after_box = false
		_on_pass()
	else:
		_refresh()


# --- autoplay bot (headless verification) ---

func _autoplay_step() -> void:
	autoplay_turns += 1
	if autoplay_turns > autoplay_cap:
		# not a failure: the bot surviving this long just means no crash surfaced
		print("AUTOPLAY CAP: alive after %d steps (wave %d, score %d)" % [autoplay_cap, wave, score])
		get_tree().quit(0)
		return
	# One random legal action per frame, then pass when spent.
	if not items.is_empty() and rng.randf() < 0.3: # exercise item paths
		_autoplay_use_item()
		return
	if placements_left > 0 and not stock.is_empty():
		var tiles := Rules.placement_tiles(board)
		if not tiles.is_empty():
			placing_index = rng.randi() % stock.size()
			_place(placing_index, tiles[rng.randi() % tiles.size()])
			return
	if _autoplay_merge():
		return
	if moves_left > 0:
		var moves := Rules.legal_moves(board, Rules.PLAYER, defs)
		moves = moves.filter(func(m: Dictionary) -> bool: return not moved_this_turn.has(m.from))
		if not moves.is_empty():
			# greedy: prefer captures so runs go deep enough to exercise waves/merges
			var caps := moves.filter(func(m: Dictionary) -> bool: return board.has(m.to))
			var pick: Array[Dictionary] = caps if not caps.is_empty() else moves
			var m: Dictionary = pick[rng.randi() % pick.size()]
			_move_player(m.from, m.to)
			return
	_on_pass()


func _autoplay_use_item() -> void:
	var index := rng.randi() % items.size()
	var it: Dictionary = items[index]
	if it.target == "":
		_use_item(index)
		return
	var a := Vector2i(-1, -1)
	var targets := _item_stage_targets(it, a)
	if targets.is_empty():
		items.remove_at(index) # discard unusable (e.g. sniper with no valid mark)
		return
	if it.target == "pair":
		a = targets[rng.randi() % targets.size()]
		targets = _item_stage_targets(it, a)
		if targets.is_empty():
			items.remove_at(index)
			return
	items.remove_at(index)
	_item_apply(it, a, targets[rng.randi() % targets.size()])


## Execute one available pair merge (promotion or fusion). Returns true if merged.
func _autoplay_merge() -> bool:
	var pool := _pool()
	for i in pool.size():
		for j in range(i + 1, pool.size()):
			if Rules.merge_result([pool[i], pool[j]], defs, fusions) != "":
				merge_sel.assign([i, j])
				_on_confirm_merge()
				return true
	return false


## Debug: place the army, spawn wave 1, save a PNG of the board, quit.
## Used by the agent for visual verification (windowed run required).
func _screenshot_and_quit(dir: String) -> void:
	await get_tree().process_frame # let _ready finish first
	var open := _setup_open_tiles()
	while not stock.is_empty() and not open.is_empty():
		_place(rng.randi() % stock.size(), open.pop_at(rng.randi() % open.size()))
	_on_pass()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("game.png"))
	get_tree().quit()


# --- rendering ---

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for x in Tuning.BOARD_W:
		for y in Tuning.BOARD_H:
			var pos := Vector2i(x, y)
			var rect := Rect2(_tile_px(pos), Vector2(tile, tile))
			draw_rect(rect, COL_LIGHT if (x + y) % 2 == 0 else COL_DARK)
			if y < Tuning.PLAYER_ZONE_ROWS and state == State.SETUP and not board.has(pos):
				draw_rect(rect, Color(0.2, 0.5, 0.9, 0.25))
	if selected.x >= 0:
		draw_rect(Rect2(_tile_px(selected), Vector2(tile, tile)), COL_SELECT)
	for ref in merge_sel: # board pieces picked as merge sources
		if ref is Vector2i:
			draw_rect(Rect2(_tile_px(ref), Vector2(tile, tile)), COL_SELECT)
	if merge_mode: # gold ring on board pieces that can merge right now
		for pos in board:
			if board[pos].owner == Rules.PLAYER and merge_highlights.has(board[pos].id) \
					and not merge_sel.has(pos):
				draw_arc(_tile_px(pos) + Vector2(tile, tile) / 2, tile * 0.46, 0, TAU, 24,
					Color(0.95, 0.8, 0.2), 3.0)
	if item_active >= 0: # item targeting: cyan rings, stage-A pick in yellow
		for t in item_targets:
			draw_arc(_tile_px(t) + Vector2(tile, tile) / 2, tile * 0.38, 0, TAU, 24, Color(0.25, 0.8, 0.85), 3.0)
		if item_stage_a.x >= 0:
			draw_rect(Rect2(_tile_px(item_stage_a), Vector2(tile, tile)), COL_SELECT)
	for d in legal_dests:
		if board.has(d): # capturable target: red tile tint + ring around the piece
			draw_rect(Rect2(_tile_px(d), Vector2(tile, tile)), Color(COL_CAPTURE, 0.3))
			draw_arc(_tile_px(d) + Vector2(tile, tile) / 2, tile * 0.44, 0, TAU, 32, COL_CAPTURE, 3.0)
		else:
			draw_circle(_tile_px(d) + Vector2(tile, tile) / 2, 10, COL_MOVE)
	if placing_index >= 0:
		var tiles := _setup_open_tiles() if state == State.SETUP else Rules.placement_tiles(board)
		for t in tiles:
			draw_circle(_tile_px(t) + Vector2(tile, tile) / 2, 8, Color(0.2, 0.5, 0.9, 0.6))
	var sliding := {} # tiles whose piece is mid-slide (drawn at the lerp instead)
	for a in anims:
		if a.kind == "move":
			sliding[a.to] = a
	for pos in board:
		if sliding.has(pos):
			continue
		var p: Dictionary = board[pos]
		var px := _tile_px(pos)
		var tint := Color(0.72, 0.85, 1.25) if p.owner == Rules.PLAYER else Color(1.25, 0.72, 0.72)
		if pos == drag_from:
			tint.a = 0.35 # ghost follows the cursor instead
		elif state == State.PLAYER_TURN and moved_this_turn.has(pos):
			tint = Color(0.75, 0.75, 0.75) # spent this turn
		_draw_piece(font, p, px, tint)
		if p.get("buff", false): # box carrier: gold badge
			draw_circle(px + Vector2(tile - 9, 9), 6, Color(0.95, 0.78, 0.15))
	for a in anims:
		if a.kind == "move" and board.has(a.to):
			var mp: Dictionary = board[a.to]
			var mtint := Color(0.72, 0.85, 1.25) if mp.owner == Rules.PLAYER else Color(1.25, 0.72, 0.72)
			_draw_piece(font, mp, a.from_px.lerp(a.to_px, ease(a.t, 0.4)), mtint)
		elif a.kind == "pop":
			draw_arc(a.at_px, tile * (0.2 + 0.3 * a.t), 0, TAU, 24, Color(COL_CAPTURE, 1.0 - a.t), 4.0)
		elif a.kind == "text": # score gains/losses float up and fade
			draw_string(font, a.at_px + Vector2(0, -20.0 * a.t), a.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(a.color, 1.0 - a.t))
	if drag_from.x >= 0 and board.has(drag_from) and textures.has(board[drag_from].id):
		draw_texture_rect(textures[board[drag_from].id],
			Rect2(get_global_mouse_position() - Vector2(tile, tile) * 0.5, Vector2(tile, tile)), false, Color(1, 1, 1, 0.85))


func _draw_piece(font: Font, p: Dictionary, px: Vector2, tint: Color) -> void:
	if textures.has(p.id):
		draw_texture_rect(textures[p.id], Rect2(px + Vector2(4, 4), Vector2(tile - 8, tile - 8)), false, tint)
	else: # ponytail: glyph fallback so a missing PNG never breaks the board
		var col := COL_PLAYER if p.owner == Rules.PLAYER else COL_ENEMY
		var glyph: String = defs[p.id].glyph
		var size := 40 if glyph.length() <= 1 else 22
		draw_string(font, px + Vector2(0, tile * 0.68), glyph, HORIZONTAL_ALIGNMENT_CENTER, tile, size, col)


func _tile_px(pos: Vector2i) -> Vector2:
	return board_px + Vector2(pos.x * tile, (Tuning.BOARD_H - 1 - pos.y) * tile)
