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
## Shape documented in data/scenarios.gd — the save file uses the same format.
static var next_config := {}
## TEST-menu / CLI scenario runs never autosave over the real run.
static var is_scenario := false
## Starting stock for a fresh run (menu's army select sets it; saves carry
## their stock in next_config instead, so this only matters when empty).
static var next_army: String = Tuning.DEFAULT_ARMY

const SAVE_PATH := "user://save.json"
const SCORES_PATH := "user://scores.json"


## Local high scores, best first: [{score, wave, kings}], top 10 kept.
static func load_scores() -> Array:
	if not FileAccess.file_exists(SCORES_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCORES_PATH))
	return parsed if parsed is Array else []

const COL_LIGHT := Color("f0d9b5")
const COL_DARK := Color("b58863")
const COL_PLAYER := Color("1a3a6b")
const COL_ENEMY := Color("8b1a1a")
const COL_PLACE := Color(0.2, 0.5, 0.9, 0.6) # placement / setup-relocation blue
const BOARD_TOP := 44.0 # below the condensed top bar + tariff strip
const DRAWER_H := 68.0  # stock / items / trinkets drawer height
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
var kings_defeated := 0  # 1 = endless unlocked; end screens show it
var win_open := false    # wave-50 win screen showing (Continue / End Run)
var lost_player := 0     # pieces lost, both sides — end-screen summary (GDD)
var lost_enemy := 0
var pending_spawn: Array = [] # piece ids waiting for open top-row tiles
var fx_at := Vector2.ZERO # where the next score popup lands; ZERO = HUD label
var score := 0:
	set(value): # every gain/loss anywhere pops floating feedback (round 4);
		# popups anchor to the piece/effect that caused them (game-feel pass)
		if value != score and is_node_ready() and not autoplay:
			var d := value - score
			anims.append({"kind": "text", "t": 0.0, "dur": 1.2,
				"text": ("+%d" if d > 0 else "%d") % d,
				"at_px": fx_at if fx_at != Vector2.ZERO
					else Vector2(score_label.get_global_rect().end) + Vector2(6, 0),
				"color": Color(0.3, 0.85, 0.35) if d > 0 else Color(0.95, 0.3, 0.25)})
			queue_redraw()
		score = value
var clock_ms := float(Tuning.CLOCK_START_MS)
var stock: Array = []
var captured: Array = []
var actions_left := 0 # unified: move, place, merge, item — 1 action each
var actions_max := 0  # granted this turn (base + trinket/item bonuses)
var early_clear_awarded := false # once per wave (resets when the next queues)
var pass_count := Label.new() # blue N/M action counter on the PASS button
var pass_label := Label.new() # the "PASS" word next to the counter
var selected := Vector2i(-1, -1) # selected board piece
var legal_dests: Array[Vector2i] = []
var legal_paths: Array[Dictionary] = [] # shape-annotated dests (dots/arrows/links)
var moved_this_turn: Array[Vector2i] = [] # pieces (by tile) that already moved
var drag_from := Vector2i(-1, -1) # board drag in progress; ghost follows the mouse
var drag_moved := false # the pointer left the origin tile (tap vs aborted drag)
var drag_reselect := false # the pressed piece was already selected (re-click)
var pool_click_key := "" # double-tap detection on pool stacks (piece preview)
var pool_click_ms := 0
var pool_drag_id := "" # stock piece mid-drag from the strip (game-feel pass)
var preview_open := false
var placing_id := ""  # stock piece id being placed, "" = none
var placing_cap := false # the armed stack is captured stock (merge-only origin)
var pool_drag_cap := false # the mid-drag stack is captured stock
var merge_highlights := {} # ids that complete a merge with the current selection
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
var autoplay_exit := false # quit-on-game-over: CLI --autoplay runs only, so the
                           # in-process scenario sweep (test_scenarios) survives
var autoplay_turns := 0
var autoplay_cap := 2000 # --steps N overrides, for short scenario sweeps
var screenshot_dir := "" # debug: save PNGs for agent visual verification

# HUD nodes
var hud := CanvasLayer.new()
var clock_label := Label.new()
var score_label := Label.new()
var foes_label := Label.new() # enemies on board (+ incoming spillover)
var drawer_open := "" # "", "stock", "items", "trinkets"
var merge_panel: PanelContainer # merge confirmation (shows the result piece)
var pending_merge: Array = [] # the two sources awaiting confirmation
var drawers := {} # name -> PanelContainer
var drawer_buttons := {} # name -> Button (count text updates)
var trinket_box := HBoxContainer.new()
var wave_label := Label.new()
var turn_label := Label.new()
var pass_button := Button.new()
var tariff_label := Label.new()
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
	autoplay_exit = autoplay
	if args.has("--screenshot"):
		screenshot_dir = args[args.find("--screenshot") + 1]
		if not autoplay: # with --autoplay, the end screen is captured instead
			_screenshot_and_quit(screenshot_dir)
	if args.has("--clock"): # debug: short clock to reach the end screen fast
		clock_ms = float(args[args.find("--clock") + 1]) * 1000.0
	if args.has("--steps"): # debug: shorter autoplay cap for scenario sweeps
		autoplay_cap = int(args[args.find("--steps") + 1])
	if args.has("--army"): # balance fleets: run the bot with a specific army
		next_army = args[args.find("--army") + 1]
	_layout_board()
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
		is_scenario = true
	if next_config.is_empty():
		stock = Tuning.ARMIES[next_army].duplicate()
		_set_drawer("stock") # SETUP starts in the placement flow
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
	score = int(cfg.get("score", 0)) # int(): JSON numbers arrive as floats
	clock_ms = cfg.get("clock_s", Tuning.CLOCK_START_MS / 1000.0) * 1000.0
	# default: all designed waves done, so nothing spawns into the sandbox
	wave = int(cfg.get("wave", Waves.WAVES.size()))
	turns_since_wave = int(cfg.get("turns_since_wave", 0))
	early_clear_awarded = bool(cfg.get("early_clear_awarded", false))
	kings_defeated = int(cfg.get("kings_defeated", 0))
	next_army = str(cfg.get("army", next_army)) # milestone drip draws from it
	lost_player = int(cfg.get("lost_player", 0))
	lost_enemy = int(cfg.get("lost_enemy", 0))
	pending_spawn = cfg.get("pending", []).duplicate(true)
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
	if cfg.has("tariffs_seen"): # activation above re-logged; restore the truth
		tariffs_seen = cfg.tariffs_seen.duplicate()
	_begin_player_turn()
	# item-effect counters restore AFTER the turn reset (a save is always taken
	# at a turn start, so move/place/merge budgets are simply fresh)
	free_placements = int(cfg.get("free_placements", 0))
	ceasefire_turns = int(cfg.get("ceasefire_turns", 0))
	skip_enemy_turns = int(cfg.get("skip_enemy_turns", 0))
	counter_intel_turns = int(cfg.get("counter_intel_turns", 0))
	recent_place_costs.clear()
	for c in cfg.get("recent_place_costs", []):
		recent_place_costs.append(int(c)) # JSON numbers arrive as floats


## The inverse of _apply_config: the live run as a JSON-safe config Dictionary.
func _to_config() -> Dictionary:
	var b := []
	for pos in board:
		var row := [board[pos].id, board[pos].owner, pos.x, pos.y]
		if board[pos].get("buff", false):
			row.append("buff")
		b.append(row)
	var keys_of := func(arr: Array) -> Array:
		var out := []
		for e in arr:
			out.append(e.key)
		return out
	return {
		"board": b, "stock": stock.duplicate(), "captured": captured.duplicate(),
		"items": keys_of.call(items), "trinkets": keys_of.call(trinkets),
		"tariffs": keys_of.call(tariffs_active), "tariffs_seen": tariffs_seen.duplicate(),
		"wave": wave, "turns_since_wave": turns_since_wave,
		"early_clear_awarded": early_clear_awarded,
		"kings_defeated": kings_defeated, "army": next_army,
		"lost_player": lost_player, "lost_enemy": lost_enemy,
		"pending": pending_spawn.duplicate(true),
		"score": score, "clock_s": clock_ms / 1000.0,
		"sanctioned_id": sanctioned_id,
		"free_placements": free_placements, "ceasefire_turns": ceasefire_turns,
		"skip_enemy_turns": skip_enemy_turns, "counter_intel_turns": counter_intel_turns,
		"recent_place_costs": recent_place_costs.duplicate(),
	}


## Board fills everything between the top bar and the bottom UI; an open
## drawer pushes it up so no tile is ever hidden.
func _layout_board() -> void:
	var vp := get_viewport_rect().size
	var limit: float = vp.y - 70.0 - (DRAWER_H if drawer_open != "" else 0.0)
	tile = int(minf((vp.x - 8.0) / Tuning.BOARD_W, (limit - BOARD_TOP) / Tuning.BOARD_H))
	board_px = Vector2(roundf((vp.x - tile * Tuning.BOARD_W) / 2.0), BOARD_TOP)
	queue_redraw()


## Open one drawer (closing the others) or toggle it shut; "" closes all.
func _set_drawer(which: String) -> void:
	drawer_open = "" if drawer_open == which else which
	for name in drawers:
		drawers[name].visible = drawer_open == name
	_layout_board()
	_refresh()


func _build_hud() -> void:
	add_child(hud)
	var vp := get_viewport_rect().size
	# condensed top bar: clock · score · wave · foes, menu at the right corner
	clock_label.add_theme_font_size_override("font_size", 17)
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.25))
	for l: Label in [wave_label, foes_label]:
		l.add_theme_font_size_override("font_size", 15)
		l.modulate = Color(1, 1, 1, 0.85)
	var top := HBoxContainer.new()
	top.position = Vector2(10, 4)
	top.custom_minimum_size = Vector2(vp.x - 56, 0)
	top.add_theme_constant_override("separation", 14)
	for l in [clock_label, score_label, wave_label, foes_label]:
		top.add_child(l)
	hud.add_child(top)
	tariff_label.position = Vector2(10, 28)
	tariff_label.add_theme_font_size_override("font_size", 13)
	tariff_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	tariff_label.custom_minimum_size = Vector2(vp.x - 20, 0)
	tariff_label.size = Vector2(vp.x - 20, 16)
	tariff_label.clip_text = true
	hud.add_child(tariff_label)

	var menu_btn := Button.new()
	menu_btn.text = "☰"
	menu_btn.add_theme_font_size_override("font_size", 18)
	menu_btn.position = Vector2(vp.x - 36, 2)
	menu_btn.pressed.connect(func() -> void:
		_clear_selection()
		game_menu_open = true
		game_menu.move_to_front() # above every other HUD control
		game_menu.visible = true)
	hud.add_child(menu_btn)

	# bottom: action count above a 4-button row (Stock / Items / Trinkets / PASS)
	turn_label.position = Vector2(0, vp.y - 70)
	turn_label.custom_minimum_size = Vector2(vp.x, 0)
	turn_label.add_theme_font_size_override("font_size", 14)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(turn_label)
	var bar := HBoxContainer.new()
	bar.position = Vector2(4, vp.y - 46)
	bar.custom_minimum_size = Vector2(vp.x - 8, 42)
	bar.add_theme_constant_override("separation", 4)
	for name in ["stock", "items", "trinkets"]:
		var b := Button.new()
		b.text = name.capitalize()
		b.add_theme_font_size_override("font_size", 17)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_drawer.bind(name))
		drawer_buttons[name] = b
		bar.add_child(b)
	pass_button.text = "PASS"
	pass_button.add_theme_font_size_override("font_size", 17)
	# self_modulate: the red tint must not bleed into the blue counter child
	pass_button.self_modulate = Color(1, 0.5, 0.5)
	pass_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_button.pressed.connect(_on_pass)
	# "2/2 PASS", both vertically centered — the button's own text is only
	# used for START (setup); in-turn the label pair takes over
	var pass_box := HBoxContainer.new()
	pass_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	pass_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pass_box.add_theme_constant_override("separation", 7)
	pass_box.mouse_filter = Control.MOUSE_FILTER_IGNORE # clicks hit the button
	pass_count.add_theme_font_size_override("font_size", 15)
	pass_count.add_theme_color_override("font_color", Color(0.45, 0.7, 1.0))
	pass_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pass_box.add_child(pass_count)
	pass_label.text = "PASS"
	pass_label.add_theme_font_size_override("font_size", 17)
	pass_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pass_box.add_child(pass_label)
	pass_button.add_child(pass_box)
	bar.add_child(pass_button)
	hud.add_child(bar)

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

	# drawers above the button row: Stock opens from the bottom-left, Items
	# from the bottom (center), Trinkets from the bottom-right; one at a time,
	# the board shrinks to stay fully visible while one is open
	trinket_box.add_theme_constant_override("separation", 16)
	var drawer_specs := [
		["stock", pool_box, 0.0, vp.x],
		["items", item_box, (vp.x - 340.0) / 2.0, 340.0],
		["trinkets", trinket_box, vp.x - 340.0, 340.0],
	]
	for spec in drawer_specs:
		var panel := PanelContainer.new()
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.1, 0.13, 0.97)
		panel.add_theme_stylebox_override("panel", bg)
		panel.position = Vector2(spec[2], vp.y - 70.0 - DRAWER_H)
		panel.custom_minimum_size = Vector2(spec[3], DRAWER_H)
		panel.visible = false
		var sc := ScrollContainer.new()
		sc.custom_minimum_size = Vector2(spec[3] - 8, DRAWER_H - 8)
		if spec[0] == "stock": # the ▲ promote badge overhangs the drawer top
			sc.clip_contents = false
		sc.add_child(spec[1])
		panel.add_child(sc)
		drawers[spec[0]] = panel
		hud.add_child(panel)

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


func _stacks() -> Array:
	# pool grouped for display/selection: stock stacks first, then captured
	var out := []
	for cap in [false, true]:
		var counts := {}
		for id in (captured if cap else stock):
			counts[id] = counts.get(id, 0) + 1
		for id in counts:
			out.append({"id": id, "cap": cap, "count": counts[id]})
	return out


func _clock_text() -> String:
	return "⏱ %02d:%02d.%01d" % [int(clock_ms / 60000), int(clock_ms / 1000) % 60, int(clock_ms / 100) % 10]


func _refresh() -> void:
	clock_label.text = _clock_text()
	score_label.text = "★%d" % score
	var next_in := _cadence() - turns_since_wave
	var wave_txt := "King!" if _king_alive() \
		else ("in %d" % maxi(next_in, 0)) if wave < Waves.WAVES.size() else "done"
	wave_label.text = "wave %d/%d · %s" % [wave, Waves.WAVES.size(), wave_txt]
	var incoming := pending_spawn.size()
	foes_label.text = "%d foes" % _enemy_count() + (" +%d" % incoming if incoming > 0 else "")
	match state:
		State.SETUP: # the pass button doubles as the explicit start trigger
			turn_label.text = "Place your army (%d left), then START" % stock.size()
			pass_button.text = "START"
			pass_button.self_modulate = Color(0.55, 1.0, 0.55)
			pass_count.text = ""
			pass_label.text = ""
		State.PLAYER_TURN:
			pass_button.text = ""
			pass_button.self_modulate = Color(1, 0.5, 0.5)
			pass_count.text = "%d/%d" % [actions_left, actions_max]
			pass_label.text = "PASS"
			turn_label.text = ""
		State.ENEMY_TURN:
			turn_label.text = "enemy turn…"
			pass_count.text = ""
			pass_label.text = "PASS"
		State.GAME_OVER:
			turn_label.text = ""
			pass_count.text = ""
	drawer_buttons["stock"].text = "Stock %d" % _pool().size()
	drawer_buttons["items"].text = "Items %d" % items.size()
	drawer_buttons["trinkets"].text = "Trinkets %d" % trinkets.size()
	merge_highlights = _merge_partner_ids()
	var names := []
	for t in tariffs_active:
		names.append(t.name.trim_prefix("Tariff on "))
	tariff_label.text = "" if names.is_empty() else "⚠ " + ", ".join(names) \
			+ (" (suppressed)" if counter_intel_turns > 0 else "")
	_rebuild_pool_strip()
	_rebuild_item_strip()
	_rebuild_trinket_strip()
	queue_redraw()


func _enemy_count() -> int:
	var n := 0
	for pos in board:
		if board[pos].owner == Rules.ENEMY:
			n += 1
	return n


func _rebuild_trinket_strip() -> void:
	for c in trinket_box.get_children():
		c.queue_free()
	if trinkets.is_empty():
		var none := Label.new()
		none.text = "no trinkets yet"
		none.modulate = Color(1, 1, 1, 0.6)
		trinket_box.add_child(none)
		return
	var counts := {}
	for t in trinkets: # stack copies: one entry per kind
		counts[t.key] = counts.get(t.key, 0) + 1
	var seen := {}
	for t in trinkets:
		if seen.has(t.key):
			continue
		seen[t.key] = true
		var l := Label.new()
		l.text = "◈%s%s" % [t.name, " ×%d" % counts[t.key] if counts[t.key] > 1 else ""]
		l.tooltip_text = t.description
		l.mouse_filter = Control.MOUSE_FILTER_STOP # so the tooltip shows
		trinket_box.add_child(l)


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
	for st in _stacks():
		var btn := Button.new()
		var id: String = st.id
		if textures.has(id): # piece icon instead of glyph text (round 3)
			btn.icon = textures[id]
			btn.expand_icon = true
			btn.custom_minimum_size = Vector2(46, 46)
		else:
			btn.text = defs[id].glyph
			btn.add_theme_font_size_override("font_size", 22)
		var show_promote: bool = placing_id == id and placing_cap == st.cap \
				and st.count >= 2 and _pair_ok(id, id) \
				and state == State.PLAYER_TURN and actions_left > 0
		if st.count > 1:
			# corner badge keeps the icon full-size (no inline text); it yields
			# the top-right corner to the ▲ promote button when that shows
			var badge := Label.new()
			badge.text = str(st.count)
			badge.add_theme_font_size_override("font_size", 11)
			badge.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
			badge.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
			badge.add_theme_constant_override("outline_size", 4)
			if show_promote:
				badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
				badge.offset_left = 3
				badge.offset_right = 16
				badge.offset_bottom = 12
			else:
				badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
				badge.offset_left = -16
				badge.offset_bottom = 12
			btn.add_child(badge)
		if show_promote:
			# round ▲ badge floating over the stack's top-right corner: it
			# overhangs the drawer's top edge and pokes out a little to the
			# right of the icon (the stock scroll doesn't clip)
			var promote := Button.new()
			promote.text = "▲"
			promote.add_theme_font_size_override("font_size", 11)
			promote.add_theme_color_override("font_color", Color(0.12, 0.1, 0.04))
			var round := StyleBoxFlat.new()
			round.bg_color = Color(0.95, 0.8, 0.25) # merge gold
			round.set_corner_radius_all(9)
			for style in ["normal", "hover", "pressed"]:
				promote.add_theme_stylebox_override(style, round)
			promote.tooltip_text = "Promote: merge two into one"
			promote.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			promote.offset_left = -14
			promote.offset_right = 4
			promote.offset_top = -9
			promote.offset_bottom = 9
			promote.pressed.connect(func() -> void:
				_do_merge({"id": id, "cap": st.cap}, {"id": id, "cap": st.cap}))
			btn.add_child(promote)
		btn.tooltip_text = defs[id].name + (" (captured)" if st.cap else "")
		if placing_id == id and placing_cap == st.cap:
			btn.modulate = Color(0.6, 1.2, 0.6) # armed: placement / merge origin
		elif merge_highlights.has(id):
			btn.modulate = Color(1.2, 1.05, 0.55) # completes a merge — tap or drop
		elif not st.cap and id == sanctioned_id and _tariff_on("sanctions"):
			btn.modulate = Color(1.0, 0.45, 0.45) # Sanctions: unplaceable
		elif st.cap:
			btn.modulate = Color(1.0, 0.8, 0.8) # captured stock: warm tint
		btn.set_meta("id", id) # drop-target lookup for drag merges
		btn.set_meta("cap", st.cap)
		btn.pressed.connect(_on_stack_pressed.bind(id, st.cap, st.count))
		btn.button_down.connect(_on_stack_drag_start.bind(id, st.cap))
		pool_box.add_child(btn)
	if state == State.SETUP and selected.x >= 0:
		# empty slot: tap it (or drop the dragged piece on the strip) to take
		# the selected board piece back into stock
		var slot := Button.new()
		slot.text = "+"
		slot.custom_minimum_size = Vector2(46, 46)
		slot.add_theme_font_size_override("font_size", 22)
		slot.modulate = Color(0.55, 0.75, 1.0, 0.85) # placement blue, dimmed
		slot.tooltip_text = "Put the piece back into stock"
		slot.pressed.connect(func() -> void:
			if selected.x >= 0 and board.has(selected):
				_setup_to_stock(selected))
		pool_box.add_child(slot)


## The piece the current selection would merge FROM: an armed pool stack
## (placing_id, stock or captured), a mid-drag stack, or the selected board
## piece. "" when nothing is selected.
func _merge_origin_id() -> String:
	if pool_drag_id != "":
		return pool_drag_id
	if placing_id != "":
		return placing_id
	if selected.x >= 0 and board.has(selected) and board[selected].owner == Rules.PLAYER:
		return board[selected].id
	return ""


## Valid pair under the current tariffs (Regulation blocks pawn merges).
func _pair_ok(a: String, b: String) -> bool:
	if _tariff_on("regulation") and (a == "pawn" or b == "pawn"):
		return false
	return Rules.merge_result([a, b], defs, fusions) != ""


## Ids that complete a merge with the current selection — drives the gold
## highlights on pool stacks and board pieces. Empty outside the player turn,
## with no selection, or with no action left to pay for the merge.
func _merge_partner_ids() -> Dictionary:
	var out := {}
	var origin := _merge_origin_id()
	if origin == "" or state != State.PLAYER_TURN or actions_left <= 0:
		return out
	var all: Array = _pool()
	for pos in _player_pieces():
		all.append(board[pos].id)
	var counts := {}
	for id in all:
		counts[id] = counts.get(id, 0) + 1
	for id in all:
		if id == origin and counts[id] < 2:
			continue # a self-pair needs a second copy
		if _pair_ok(origin, id):
			out[id] = true
	return out


## The pool-strip stack button under a screen point (drag drop target).
func _stack_button_at(screen: Vector2) -> Button:
	if not pool_box.is_visible_in_tree(): # stock drawer closed: no targets
		return null
	for c in pool_box.get_children():
		if c is Button and not c.is_queued_for_deletion() and c.has_meta("id") \
				and (c as Button).get_global_rect().has_point(screen):
			return c
	return null


## Any new interaction (menu, stock tap/drag, pass, item) drops the board
## selection so stale highlights never survive into the next action.
func _clear_selection() -> void:
	selected = Vector2i(-1, -1)
	legal_dests.clear()
	legal_paths.clear()
	queue_redraw()


func _on_stack_pressed(id: String, cap: bool, count: int) -> void:
	if state == State.GAME_OVER or state == State.ENEMY_TURN or box_open \
			or preview_open or game_menu_open or win_open:
		return
	# double-tap on the same stack: piece info
	var key := id + ("!" if cap else "")
	var now := Time.get_ticks_msec()
	if key == pool_click_key and now - pool_click_ms < 400:
		pool_click_key = ""
		return _show_preview(id)
	pool_click_key = key
	pool_click_ms = now
	# tapping a partner of the current selection completes the merge; a
	# same-stack pair goes through drag instead (tap-again means deselect)
	var same_stack := placing_id == id and placing_cap == cap
	if not same_stack and merge_highlights.has(id):
		var unit := {"id": id, "cap": cap}
		if placing_id != "":
			return _do_merge({"id": placing_id, "cap": placing_cap}, unit)
		if selected.x >= 0:
			return _do_merge(selected, unit)
	# select / deselect the stack: arms placement + merging (captured stock
	# deploys too since 2026-07-07 — GDD Captured Stock rule, turn only)
	if same_stack:
		placing_id = ""
		placing_cap = false
	else:
		if cap and (state != State.PLAYER_TURN or actions_left <= 0):
			return # captured only merges, and a merge needs a turn action
		if not cap and id == sanctioned_id and _tariff_on("sanctions"):
			return
		if not cap and not (state == State.SETUP or actions_left > 0):
			return
		placing_id = id
		placing_cap = cap
	_clear_selection()
	_refresh()


## Merge entry point: validates the pair, then asks for confirmation showing
## the result piece (the bot skips straight to the commit). Cancel keeps the
## origin selected so another partner can be picked.
func _do_merge(a: Variant, b: Variant) -> void:
	if state != State.PLAYER_TURN or actions_left <= 0:
		return
	var ids := []
	for ref in [a, b]:
		ids.append(board[ref].id if ref is Vector2i else ref.id)
	if not _pair_ok(ids[0], ids[1]):
		return
	if autoplay:
		return _commit_merge(a, b)
	pending_merge = [a, b]
	_show_merge_confirm(ids[0], ids[1], Rules.merge_result(ids, defs, fusions))


func _show_merge_confirm(a_id: String, b_id: String, result: String) -> void:
	if merge_panel:
		merge_panel.queue_free()
	merge_panel = PanelContainer.new()
	merge_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	merge_panel.add_theme_stylebox_override("panel", bg)
	var center := CenterContainer.new()
	merge_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	if textures.has(result):
		var tex := TextureRect.new()
		tex.texture = textures[result]
		tex.custom_minimum_size = Vector2(96, 96)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(tex)
	var what := Label.new()
	what.text = "%s + %s → %s" % [defs[a_id].name, defs[b_id].name, defs[result].name]
	what.add_theme_font_size_override("font_size", 20)
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(what)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var yes := Button.new()
	yes.text = "Merge"
	yes.add_theme_font_size_override("font_size", 22)
	yes.pressed.connect(func() -> void:
		var p := pending_merge
		pending_merge = []
		merge_panel.visible = false
		_commit_merge(p[0], p[1]))
	row.add_child(yes)
	var no := Button.new()
	no.text = "Cancel"
	no.add_theme_font_size_override("font_size", 22)
	no.pressed.connect(func() -> void:
		pending_merge = []
		merge_panel.visible = false
		_refresh())
	row.add_child(no)
	box.add_child(row)
	hud.add_child(merge_panel)
	merge_panel.move_to_front() # above the drawers and bottom bar


## The result lands on the LATER board tile (grilled 2026-07-02: drop/tap
## target wins); pool-only merges go to Stock.
func _commit_merge(a: Variant, b: Variant) -> void:
	if state != State.PLAYER_TURN or actions_left <= 0:
		return
	var ids := []
	for ref in [a, b]:
		ids.append(board[ref].id if ref is Vector2i else ref.id)
	if not _pair_ok(ids[0], ids[1]):
		return
	var result := Rules.merge_result(ids, defs, fusions)
	actions_left -= 1
	turn_action_count += 1
	var result_tile := Vector2i(-1, -1)
	for ref in [a, b]:
		if ref is Vector2i:
			result_tile = ref # later selections win
			board.erase(ref)
		else: # a unit from a stack: remove one copy by value
			(captured if ref.cap else stock).erase(ref.id)
	if result_tile.x >= 0:
		board[result_tile] = {"id": result, "owner": Rules.PLAYER}
		fx_at = _tile_px(result_tile) + Vector2(tile, tile) / 2
	else:
		stock.append(result)
		fx_at = Vector2((pool_box.get_parent() as Control).get_global_rect().get_center())
	_charge("fuse_cost")
	placing_id = ""
	placing_cap = false
	_clear_selection()
	if actions_left == 0 or _board_cleared(): # last action spent on the merge
		return _on_pass()
	_refresh()


func _on_pass() -> void:
	if box_open or game_menu_open or win_open:
		return
	if state == State.SETUP:
		if drawer_open != "": # setup done: full board for the run
			_set_drawer("")
		_spawn_wave(1)
		_begin_player_turn()
	elif state == State.PLAYER_TURN:
		fx_at = Vector2(pass_button.get_global_rect().get_center())
		_charge("pass_cost")
		if not early_clear_awarded and _board_cleared():
			# wave beaten with turns to spare: score + clock scale with the lead
			early_clear_awarded = true
			var early := maxi(_cadence() - turns_since_wave, 0)
			if early > 0:
				score += early * Tuning.EARLY_CLEAR_SCORE_PER_TURN
				clock_ms += early * Tuning.EARLY_CLEAR_CLOCK_MS_PER_TURN
				_add_turn_fx("CLEARED EARLY  +%d ★ · +%ds" % [
					early * Tuning.EARLY_CLEAR_SCORE_PER_TURN,
					early * Tuning.EARLY_CLEAR_CLOCK_MS_PER_TURN / 1000],
					Color(0.95, 0.8, 0.25))
		clock_ms += Tuning.TURN_END_CLOCK_BONUS_MS # finishing a turn buys time
		_enemy_turn()


func _process(delta: float) -> void:
	if autoplay and state == State.SETUP:
		# place the whole starting stock on random zone tiles, then begin
		var open := _setup_open_tiles()
		if stock.is_empty() or open.is_empty():
			_on_pass()
		else:
			_place(stock[rng.randi() % stock.size()], open[rng.randi() % open.size()])
		return
	if state == State.PLAYER_TURN:
		if ceasefire_turns <= 0 and not game_menu_open and not win_open: # paused
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


# --- turn flow ---

## Turn/wave transition feedback: board-outline glow + a sliding banner
## (game-feel pass 2026-07-06). Stacked banners offset so they never overlap.
func _add_turn_fx(text: String, color: Color) -> void:
	if autoplay:
		return
	var slot := 0
	for a in anims:
		if a.kind == "banner":
			slot += 1
	anims.append({"kind": "outline", "t": 0.0, "dur": 0.6, "color": color})
	anims.append({"kind": "banner", "t": 0.0, "dur": 1.1, "text": text,
		"color": color, "slot": slot})
	queue_redraw()


func _begin_player_turn() -> void:
	if state == State.ENEMY_TURN: # skip on the SETUP->first-turn transition
		_add_turn_fx("YOUR TURN", Color(0.45, 0.7, 1.0))
	_clear_selection() # a setup selection must not survive START
	state = State.PLAYER_TURN
	actions_left = Tuning.ACTIONS_PER_TURN
	for t in trinkets:
		if t.key == "move":
			actions_left += 1
	actions_max = actions_left
	moved_this_turn.clear()
	turn_action_count = 0
	counter_intel_turns = maxi(counter_intel_turns - 1, 0)
	# board cleared early -> skip the cadence wait, next wave arrives now
	if wave < Waves.WAVES.size() and pending_spawn.is_empty() and not _any_enemy():
		_queue_wave(wave + 1)
	_spawn_pending()
	if _player_pieces().is_empty() and stock.is_empty() and not Rules.has_merge(_pool(), defs, fusions):
		return _game_over(false, "Resource starvation")
	if not autoplay and not is_scenario: # autosave at every turn start
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify(_to_config()))
	_refresh()


func _enemy_turn() -> void:
	state = State.ENEMY_TURN
	_add_turn_fx("ENEMY TURN", Color(1.0, 0.42, 0.35))
	if drawer_open != "": # full board while the enemy plays
		_set_drawer("")
	_clear_selection()
	placing_id = ""
	placing_cap = false
	pool_drag_id = ""
	pool_drag_cap = false
	_item_reset()
	_refresh()
	turns_since_wave += 1
	ceasefire_turns = maxi(ceasefire_turns - 1, 0)
	if wave < Waves.WAVES.size() and not _king_alive() and turns_since_wave >= _cadence():
		_queue_wave(wave + 1)
	if skip_enemy_turns > 0: # Surprise Attack: the enemy sits this one out
		skip_enemy_turns -= 1
	else:
		if not autoplay:
			await get_tree().create_timer(Tuning.ENEMY_TURN_PAUSE).timeout
		await _run_enemy_actions()
	if state != State.GAME_OVER:
		if not autoplay:
			await get_tree().create_timer(Tuning.ENEMY_TURN_PAUSE).timeout
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
			lost_player += 1
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
	early_clear_awarded = false # the new wave can earn its own clear bonus
	var buff_id: String = Waves.BUFFS.get(n, "")
	var roster: Array = Waves.WAVES[n - 1].duplicate()
	_add_turn_fx("KING WAVE!" if roster.has("king") else "WAVE %d" % n,
		Color(1.0, 0.8, 0.3))
	if _tariff_on("trade_war"): # +1 piece per wave, drawn from the wave's own mix
		var extras: Array = roster.filter(func(id: String) -> bool: return id != "king")
		if not extras.is_empty(): # never duplicate the King (review 2026-07-03)
			roster.append(extras[rng.randi() % extras.size()])
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
		fx_at = Vector2(wave_label.get_global_rect().get_center())
		score += _gain(Tuning.MILESTONE_SCORE_BONUS)
		# reinforcement drip from the army's own mix (balance 2026-07-06:
		# starvation was 100% of bot deaths — nothing replenished Stock)
		var mix: Array = Tuning.ARMIES.get(next_army, Tuning.ARMIES[Tuning.DEFAULT_ARMY])
		for i in Tuning.MILESTONE_STOCK_DRIP:
			stock.append(mix[rng.randi() % mix.size()])


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
		if board.has(spot): # arrival captures a friendly blockading the row
			lost_player += 1
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
	if not is_scenario and FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH) # the run ended; nothing to resume
	var rank := 0 # scenario/bot runs stay off the local leaderboard
	if not is_scenario and not autoplay:
		rank = _record_score()
	_show_overlay(won, reason, rank)
	_refresh()
	if autoplay_exit:
		print("AUTOPLAY RESULT: %s — %s (wave %d, score %d, %d turns)" % ["WIN" if won else "LOSS", reason, wave, score, autoplay_turns])
		if screenshot_dir != "":
			_end_shot() # fire-and-forget: capture the end screen, then quit
		else:
			get_tree().quit(0)


## Persist the finished run to the local high scores; returns its all-time
## rank (1-based; ties rank behind older entries).
func _record_score() -> int:
	var scores := load_scores()
	var rank := 1
	for e in scores:
		if int(e.score) >= score:
			rank += 1
	scores.append({"score": score, "wave": wave, "kings": kings_defeated})
	scores.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return int(x.score) > int(y.score))
	var f := FileAccess.open(SCORES_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(scores.slice(0, 10)))
	return rank


func _end_shot() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_dir.path_join("gameover.png"))
	get_tree().quit()


## Width-capped, wrapping, centered label — end/win screens must never
## overflow the 480px design width (fixed 2026-07-07).
func _overlay_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(get_viewport_rect().size.x - 48, 0)
	return l


func _show_overlay(won: bool, reason: String, rank := 0) -> void:
	for c in overlay.get_children():
		c.queue_free()
	var center := CenterContainer.new()
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	box.add_child(_overlay_label("VICTORY" if won else "GAME OVER", 32))
	box.add_child(_overlay_label(reason, 18))
	var stats := "Score %d · Deepest wave %d\nKings %d · Tariffs seen %d\nPieces lost %d · Enemies slain %d" \
		% [score, wave, kings_defeated, tariffs_seen.size(), lost_player, lost_enemy]
	if rank > 0:
		stats += "\n" + ("Local rank #%d" % rank if rank <= 10 else "Off the local top 10")
	box.add_child(_overlay_label(stats, 19))
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


## Wave-50 win screen: the run pauses on top of the board; Continue enters
## endless mode, End Run locks the score in (GDD Game Over & Winner Screens,
## trimmed 2026-07-03: no leaderboard rank / pieces-lost summary yet).
func _show_win_screen() -> void:
	win_open = true
	for c in overlay.get_children():
		c.queue_free()
	var center := CenterContainer.new()
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	box.add_child(_overlay_label("VICTORY", 32))
	box.add_child(_overlay_label("The wave-%d King has fallen" % wave, 18))
	var preview := 1 # GDD "ranking preview": where the score would land now
	for e in load_scores():
		if int(e.score) >= score:
			preview += 1
	box.add_child(_overlay_label(
		"Score %d · rank #%d if ended now\nWave %d · Tariffs seen %d\nPieces lost %d · Enemies slain %d" \
		% [score, preview, wave, tariffs_seen.size(), lost_player, lost_enemy], 19))
	box.add_child(_overlay_label("Continue into endless waves?", 20))
	var cont := Button.new()
	cont.text = "Continue"
	cont.add_theme_font_size_override("font_size", 26)
	cont.pressed.connect(_on_win_continue)
	box.add_child(cont)
	var end := Button.new()
	end.text = "End Run"
	end.pressed.connect(func() -> void:
		win_open = false
		_game_over(true, "Wave-%d King checkmated" % wave))
	box.add_child(end)
	overlay.visible = true


func _on_win_continue() -> void:
	win_open = false
	overlay.visible = false
	clock_ms += Tuning.CONTINUE_CLOCK_REFILL_MS # one-time endless bonus
	if actions_left == 0 and state == State.PLAYER_TURN:
		return _on_pass() # the checkmate spent the last action — resume the flow
	_refresh()


# --- input ---

## Press-drag from a stock stack: the piece follows the cursor and drops onto
## a valid placement tile. Tapping (release back on the button) still selects.
func _on_stack_drag_start(id: String, cap: bool) -> void:
	if box_open or win_open or game_menu_open or preview_open:
		return
	if not cap and id == sanctioned_id and _tariff_on("sanctions"):
		return
	if cap and (state != State.PLAYER_TURN or actions_left <= 0):
		return # captured drags only merge, and a merge needs a turn action
	if state != State.SETUP and (state != State.PLAYER_TURN or actions_left <= 0):
		return
	_clear_selection()
	pool_drag_id = id
	pool_drag_cap = cap
	# highlight drop targets WITHOUT rebuilding the strip — a rebuild would
	# free the pressed button and its release-tap (pressed) would never fire,
	# breaking tap-to-place (found 2026-07-07)
	merge_highlights = _merge_partner_ids()
	for c in pool_box.get_children():
		if c is Button and c.has_meta("id") and merge_highlights.has(c.get_meta("id")):
			c.modulate = Color(1.2, 1.05, 0.55)
	queue_redraw()


## Buttons capture the click, so the drag's release lands here, not in
## _unhandled_input.
func _input(event: InputEvent) -> void:
	if pool_drag_id == "":
		return
	if event is InputEventMouseMotion:
		if state == State.PLAYER_TURN and drawer_open != "" and not \
				(drawers[drawer_open] as Control).get_global_rect().has_point(event.position):
			_set_drawer("") # dragged out toward the board: give it back
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		var t := _tile_at(event.position)
		var id := pool_drag_id
		var cap := pool_drag_cap
		pool_drag_id = ""
		pool_drag_cap = false
		# drop on a friendly partner piece: merge into its tile
		if state == State.PLAYER_TURN and t.x >= 0 and board.has(t) \
				and board[t].owner == Rules.PLAYER and merge_highlights.has(board[t].id):
			get_viewport().set_input_as_handled()
			return _do_merge({"id": id, "cap": cap}, t)
		# drop on a DIFFERENT partner stack in the strip: pool merge. Dropping
		# back on the same stack is a plain tap (arms placement) — same-stack
		# promotion goes through the ▲ badge instead (2026-07-07)
		var target := _stack_button_at(event.position)
		if state == State.PLAYER_TURN and target != null \
				and merge_highlights.has(target.get_meta("id")) \
				and not (target.get_meta("id") == id and target.get_meta("cap") == cap):
			get_viewport().set_input_as_handled()
			return _do_merge({"id": id, "cap": cap},
				{"id": target.get_meta("id"), "cap": target.get_meta("cap")})
		var placeable: bool = t.x >= 0 and not board.has(t) \
			and (t.y < Tuning.PLAYER_ZONE_ROWS if state == State.SETUP
				else Rules.placement_tiles(board).has(t))
		if placeable and (state == State.SETUP
				or (state == State.PLAYER_TURN and actions_left > 0)):
			_place(id, t, cap)
		else: # dropped elsewhere (incl. back on the button = plain tap)
			# deferred: an immediate rebuild frees the button before its
			# release-tap (pressed) fires, killing tap-to-place (2026-07-07)
			_refresh.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if preview_open or game_menu_open:
		return # the panels' own buttons handle dismissal
	if state == State.GAME_OVER or state == State.ENEMY_TURN or box_open or win_open:
		drag_from = Vector2i(-1, -1)
		return
	if event is InputEventMouseMotion:
		if drag_from.x >= 0:
			if _tile_at(event.position) != drag_from:
				drag_moved = true # a real drag, not a tap in place
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at := _tile_at(event.position)
		if event.pressed:
			# a board press outside the drawer gives the board back (the tile
			# was computed against the pushed-up layout, so it stays valid)
			if drawer_open != "" and state != State.SETUP and at.x >= 0:
				_set_drawer("")
			if event.double_click and at.x >= 0 and board.has(at):
				drag_from = Vector2i(-1, -1)
				return _show_preview(board[at].id) # double-tap: piece info
			var was_selected := at.x >= 0 and at == selected
			if at.x >= 0:
				_on_tile_clicked(at)
			# a selection of an OWN piece also starts a potential drag (enemy
			# recon selections are read-only — never draggable)
			if selected == at and at.x >= 0 and board.has(at) \
					and board[at].owner == Rules.PLAYER:
				drag_from = at
				drag_moved = false
				drag_reselect = was_selected # in-place release = re-click
		else:
			if drag_from.x >= 0: # release ends a drag
				var t := _tile_at(event.position)
				var from := drag_from
				drag_from = Vector2i(-1, -1)
				if t != from and legal_dests.has(t):
					if state == State.SETUP:
						_setup_relocate(from, t)
					else:
						_move_player(from, t)
				elif state == State.PLAYER_TURN and t.x >= 0 and t != from \
						and board.has(t) and board[t].owner == Rules.PLAYER \
						and board.has(from) and merge_highlights.has(board[t].id):
					_do_merge(from, t) # dragged onto a partner: merge onto its tile
				elif state == State.SETUP and t.x < 0 and pool_box.is_visible_in_tree() \
						and (pool_box.get_parent() as Control) \
						.get_global_rect().has_point(event.position):
					_setup_to_stock(from) # dropped on the stock drawer: take it back
				elif t == from and (drag_moved or drag_reselect):
					# dragged away and dropped back home (no action taken), or a
					# completed re-click on an already-selected piece: deselect
					_clear_selection()
					_refresh()
				else: # release in place = fresh select; elsewhere = cancel ghost
					queue_redraw()


## Hop-chains (bent rides, leap-riders): a dot per reachable tile, linked by
## a dotted line tracing the path from the piece outward.
func _draw_linked_dots(origin: Vector2, line: Array, col: Color) -> void:
	var prev := origin
	for t in line:
		var c: Vector2 = _tile_px(t) + Vector2(tile, tile) / 2
		draw_dashed_line(prev, c, Color(col, 0.65), 2.5, 5.0)
		if not board.has(t):
			draw_circle(c, 8, col)
		prev = c


## Slide indicator: shaft from the piece toward the ride's end, arrowhead at
## the last reachable tile (a capture there keeps its ring on top).
func _draw_move_arrow(from_px: Vector2, to_px: Vector2, col: Color) -> void:
	var dir := (to_px - from_px).normalized()
	draw_line(from_px + dir * (tile * 0.35), to_px - dir * 10.0, col, 3.0)
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([to_px,
		to_px - dir * 14.0 + side * 8.0, to_px - dir * 14.0 - side * 8.0]), col)


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
	if placing_id != "":
		# tapping a partner piece on the board merges the armed stack unit
		# into it (result on that tile)
		if board.has(tile) and board[tile].owner == Rules.PLAYER \
				and merge_highlights.has(board[tile].id):
			return _do_merge({"id": placing_id, "cap": placing_cap}, tile)
		# captured stock deploys like stock (GDD Captured Stock, wired 2026-07-07)
		var ok := tile.y < Tuning.PLAYER_ZONE_ROWS if state == State.SETUP else Rules.placement_tiles(board).has(tile)
		if ok and not board.has(tile):
			_place(placing_id, tile, placing_cap)
		return
	if state == State.SETUP: # free repositioning before the game starts
		if selected.x >= 0 and legal_dests.has(tile):
			_setup_relocate(selected, tile)
		elif board.has(tile) and board[tile].owner == Rules.PLAYER:
			selected = tile
			legal_dests = _setup_open_tiles()
			_refresh()
		else:
			_clear_selection()
			_refresh()
		return
	if state != State.PLAYER_TURN:
		return
	if selected.x >= 0 and legal_dests.has(tile) and board.has(selected) \
			and board[selected].owner == Rules.PLAYER: # enemy previews never move
		_move_player(selected, tile)
	elif selected.x >= 0 and tile != selected and board.has(tile) \
			and board[tile].owner == Rules.PLAYER and merge_highlights.has(board[tile].id):
		_do_merge(selected, tile) # second pick completes the merge on its tile
	elif board.has(tile) and board[tile].owner == Rules.PLAYER and actions_left > 0 \
			and not moved_this_turn.has(tile):
		selected = tile
		legal_dests = Rules.moves_for(board, tile, defs)
		legal_paths = Rules.move_paths(board, tile, defs)
		_refresh()
	elif board.has(tile) and board[tile].owner == Rules.ENEMY:
		if tile == selected: # re-click on a recon selection: dismiss it
			_clear_selection()
			_refresh()
			return
		# read-only recon: show where the enemy can move and what it threatens
		selected = tile
		legal_dests = Rules.moves_for(board, tile, defs)
		legal_paths = Rules.move_paths(board, tile, defs)
		_refresh()
	else:
		_clear_selection()
		_refresh()


func _place(id: String, tile: Vector2i, cap := false) -> void:
	fx_at = _tile_px(tile) + Vector2(self.tile, self.tile) / 2
	(captured if cap else stock).erase(id)
	board[tile] = {"id": id, "owner": Rules.PLAYER}
	placing_id = ""
	placing_cap = false
	if state == State.PLAYER_TURN:
		actions_left -= 1
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
		if actions_left == 0 or _board_cleared(): # last action spent placing
			return _on_pass()
	_refresh()


## SETUP-only: pieces slide anywhere open in the zone and can return to stock.
func _setup_relocate(from: Vector2i, to: Vector2i) -> void:
	board[to] = board[from]
	board.erase(from)
	_clear_selection()
	_refresh()


func _setup_to_stock(from: Vector2i) -> void:
	stock.append(board[from].id)
	board.erase(from)
	_clear_selection()
	_refresh()


func _move_player(from: Vector2i, to: Vector2i) -> void:
	var boxed := false
	var king_captured := false
	fx_at = _tile_px(to) + Vector2(tile, tile) / 2 # popups at the action tile
	if board.has(to): # capture
		var victim: Dictionary = board[to]
		score += _gain(_capture_score(victim.id))
		_charge("capture_cost")
		lost_enemy += 1
		if victim.id == "king": # boss piece — never enters Captured Stock
			king_captured = true
		else:
			captured.append(victim.id)
			boxed = victim.get("buff", false)
		_add_pop(to)
	_charge("move_cost")
	if _is_long_range(board[from].id):
		var d := to - from
		_charge("long_range_cost", Tuning.TARIFF_LR_PER_SQUARE * maxi(absi(d.x), absi(d.y)))
	_add_slide(from, to)
	board[to] = board[from]
	board.erase(from)
	actions_left -= 1
	turn_action_count += 1
	moved_this_turn.append(to)
	_clear_selection() # incl. legal_paths — stale shape overlay bug 2026-07-07
	if king_captured or (_king_alive() and Rules.is_checkmate(board, Rules.ENEMY, defs)):
		if _king_down():
			return
	# last action auto-passes (playtest 2026-07-02); so does clearing the board's
	# last enemy — no point sitting on an empty board (game-feel 2026-07-06)
	if (actions_left == 0 or _board_cleared()) and state == State.PLAYER_TURN:
		if boxed: # resolve the box first; the pick UI defers the auto-pass
			pass_after_box = true
		else:
			return _on_pass()
	if boxed:
		return _open_box_pick()
	_refresh()


## No enemy left, nothing incoming, and more waves to come — the turn is over.
func _board_cleared() -> bool:
	return not _any_enemy() and pending_spawn.is_empty() and wave < Waves.WAVES.size()


## Long-range = any non-leap move (ride or bent ride) — the Tariff on
## Long-Range covers every rider, not just bishop/rook (review 2026-07-03).
func _is_long_range(id: String) -> bool:
	for m in defs[id].moves:
		if m.type != "leap":
			return true
	return false


func _capture_score(victim_id: String) -> int:
	var base: int = defs[victim_id].value
	var pts := base
	for t in trinkets: # run-long passives (stack per copy)
		match t.key:
			"greed":
				if victim_id == "pawn":
					pts += 10
			"score":
				pts += 10
			"bounty":
				if base >= 50:
					pts += 30
			"lifesteal":
				clock_ms += 2000
			"first_capture_extra":
				if turn_action_count == 0:
					actions_left += 1
					actions_max += 1
	return pts


## A King fell (captured or checkmated). First King → win screen (Continue /
## End Run), recurring King (wave 100) → bonus + refill and the run continues,
## last designed King (wave 150) → full clear. Returns true when the caller
## must stop the turn flow (screen showing or game over).
func _king_down() -> bool:
	kings_defeated += 1
	fx_at = Vector2(wave_label.get_global_rect().get_center())
	score += Tuning.WIN_SCORE_BONUS
	var k := Rules.find_king(board, Rules.ENEMY)
	if k.x >= 0: # checkmated, not captured — the boss still leaves the board
		board.erase(k)
	if wave >= Waves.WAVES.size():
		_game_over(true, "FULL CLEAR — every King has fallen")
		return true
	if kings_defeated == 1:
		if autoplay: # nobody to press Continue; end the run as a win
			_game_over(true, "Wave-%d King checkmated" % wave)
			return true
		_show_win_screen()
		return true
	clock_ms += Tuning.KING_CLOCK_REFILL_MS # recurring King
	_refresh()
	return false


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
		if m.type == "bent": # pivot step, then a ride outward from the pivot
			var steps := [[int(m.pivot[0]), int(m.pivot[1])]]
			var bx: int = int(m.pivot[0]) + int(m.dir[0])
			var by: int = int(m.pivot[1]) + int(m.dir[1])
			while absi(bx) <= c and absi(by) <= c:
				steps.append([bx, by])
				bx += int(m.dir[0])
				by += int(m.dir[1])
			for st in steps:
				_diagram_mark(dia, c, cell, int(st[0]), int(st[1]), m.mode)
			continue
		for dir in m.dirs:
			var reach: int = int(m.get("range", 0)) if m.type == "ride" else 1
			if reach == 0:
				reach = cells # unbounded ride: to the diagram edge
			for s in range(1, reach + 1):
				if absi(int(dir[0]) * s) > c or absi(int(dir[1]) * s) > c:
					break
				_diagram_mark(dia, c, cell, int(dir[0]) * s, int(dir[1]) * s, m.mode)


func _diagram_mark(dia: Control, c: int, cell: int, dx: int, dy: int, mode: String) -> void:
	var pc := Vector2(c + dx, c - dy) * cell + Vector2(cell, cell) / 2 # +y is up
	match mode:
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
	if drawer_open != "": # using an item hands the board back (targeting)
		_set_drawer("")
	var it: Dictionary = items[index]
	if it.target == "":
		items.remove_at(index)
		_item_apply(it, Vector2i(-1, -1), Vector2i(-1, -1))
		return
	item_active = index
	item_stage_a = Vector2i(-1, -1)
	item_targets = _item_stage_targets(it, Vector2i(-1, -1))
	_clear_selection()
	placing_id = ""
	placing_cap = false
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
	fx_at = _tile_px(b) + Vector2(tile, tile) / 2 if b.x >= 0 \
		else Vector2(item_box.get_global_rect().get_center())
	_charge("ability_cost") # on use — a cancelled targeting costs nothing
	actions_left -= 1 # every item use is one of the turn's actions
	turn_action_count += 1
	match it.key:
		"blitz":
			actions_left += 2 # costs 1 to use -> net +1, the item's old value
			actions_max += 2
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
		if _king_down():
			return
	if state == State.PLAYER_TURN and (actions_left == 0 or _board_cleared()):
		return _on_pass() # last action, or the item cleared the last enemy
	_refresh()


## Item destruction: piece leaves the board — no score, no captured stock.
func _destroy(pos: Vector2i) -> void:
	if board[pos].owner == Rules.PLAYER:
		lost_player += 1
	else:
		lost_enemy += 1
	_add_pop(pos)
	board.erase(pos)


# --- box pick (GDD Game Flow — Box Pick; clock keeps ticking, input modal) ---

func _open_box_pick() -> void:
	box_open = true
	_charge("box_cost")
	var options := _box_options()
	if autoplay: # bot: random pick (or skip) — exercises every branch
		if rng.randf() < 0.1:
			score += _gain(Tuning.BOX_SKIP_CONSOLATION)
			return _box_close()
		return _box_choose(options[rng.randi() % options.size()])
	_box_show(options)


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


## One randomized offer (goal rework 2026-07-06, diverges from the GDD's
## two-step pick): 3 options rolled independently — Item 40% / Trinket 30% /
## Score 30% — never repeating within the offer. Each is self-describing:
## {kind, name, description, tier?, value?, payload?}.
func _box_options() -> Array:
	var out := []
	var taken := {}
	for i in 3:
		var r := rng.randf()
		var kind := "item" if r < 0.4 else ("trinket" if r < 0.7 else "score")
		var opt := {}
		match kind:
			"item":
				var pool := Items.ITEMS.filter(func(e: Dictionary) -> bool:
					return not taken.has(e.name))
				var e: Dictionary = pool[rng.randi() % pool.size()]
				opt = {"kind": "item", "name": e.name, "tier": e.tier,
					"description": e.description, "payload": e}
			"trinket":
				var pool := Items.TRINKET_EFFECTS.filter(func(e: Dictionary) -> bool:
					return not taken.has(e.name))
				var e: Dictionary = pool[rng.randi() % pool.size()]
				opt = {"kind": "trinket", "name": e.name,
					"description": e.description, "payload": e}
			"score":
				var pool := Tuning.SCORE_BOX_CHUNKS.filter(func(v: int) -> bool:
					return not taken.has("+%d score" % v))
				var v: int = pool[rng.randi() % pool.size()]
				opt = {"kind": "score", "name": "+%d score" % v, "value": v,
					"description": "Banked immediately."}
		taken[opt.name] = true
		out.append(opt)
	return out


func _box_show(options: Array) -> void:
	var box := _box_vbox("📦 The enemy dropped a box! Pick one:")
	for opt in options:
		var b := Button.new()
		var header := ""
		match opt.kind:
			"item":
				header = "⚔ %s — Item · %s · single use" % [opt.name, opt.tier]
			"trinket":
				header = "◈ %s — Trinket · passive, rest of the run" % opt.name
			"score":
				header = "★ %s" % opt.name
		b.text = header + "\n" + opt.description
		b.add_theme_font_size_override("font_size", 16)
		b.custom_minimum_size = Vector2(420, 0)
		b.pressed.connect(_box_choose.bind(opt))
		box.add_child(b)
	_box_add_skip(box)


func _box_add_skip(box: VBoxContainer) -> void:
	var skip := Button.new()
	skip.text = "Skip (+%d score)" % Tuning.BOX_SKIP_CONSOLATION
	skip.pressed.connect(func() -> void:
		fx_at = get_viewport_rect().size / 2.0
		score += _gain(Tuning.BOX_SKIP_CONSOLATION)
		_box_close())
	box.add_child(skip)


func _box_choose(opt: Dictionary) -> void:
	fx_at = get_viewport_rect().size / 2.0
	match opt.kind:
		"item":
			items.append(opt.payload)
		"trinket":
			trinkets.append(opt.payload)
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
		if autoplay_exit:
			print("AUTOPLAY CAP: alive after %d steps (wave %d, score %d)" % [autoplay_cap, wave, score])
			get_tree().quit(0)
		return
	# One random legal action per frame (everything costs one), pass when spent.
	if actions_left > 0:
		if not items.is_empty() and rng.randf() < 0.3: # exercise item paths
			_autoplay_use_item()
			return
		if turn_action_count == 0 and not stock.is_empty(): # ≤1 placement/turn,
			var tiles := Rules.placement_tiles(board)      # like the old economy
			if not tiles.is_empty():
				_place(stock[rng.randi() % stock.size()], tiles[rng.randi() % tiles.size()])
				return
		if _autoplay_merge():
			return
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
	var units := []
	for id in stock:
		units.append({"id": id, "cap": false})
	for id in captured:
		units.append({"id": id, "cap": true})
	for i in units.size():
		for j in range(i + 1, units.size()):
			if _pair_ok(units[i].id, units[j].id):
				_do_merge(units[i], units[j])
				return true
	return false


## Debug: place the army, spawn wave 1, save a PNG of the board, quit.
## Used by the agent for visual verification (windowed run required).
func _screenshot_and_quit(dir: String) -> void:
	await get_tree().process_frame # let _ready finish first
	var open := _setup_open_tiles()
	while not stock.is_empty() and not open.is_empty():
		_place(stock[rng.randi() % stock.size()], open.pop_at(rng.randi() % open.size()))
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
	# whose-turn outline around the board (game-feel pass 2026-07-06)
	var oc := Color(0.5, 0.5, 0.5)
	if state == State.PLAYER_TURN:
		oc = Color(0.45, 0.7, 1.0)
	elif state == State.ENEMY_TURN:
		oc = Color(1.0, 0.42, 0.35)
	var bsize := Vector2(Tuning.BOARD_W, Tuning.BOARD_H) * tile
	draw_rect(Rect2(board_px - Vector2(4, 4), bsize + Vector2(8, 8)), oc, false, 3.0)
	if selected.x >= 0:
		draw_rect(Rect2(_tile_px(selected), Vector2(tile, tile)), COL_SELECT)
	if not merge_highlights.is_empty(): # gold ring: merges with the selection
		for pos in board:
			if board[pos].owner == Rules.PLAYER and pos != selected \
					and merge_highlights.has(board[pos].id):
				draw_arc(_tile_px(pos) + Vector2(tile, tile) / 2, tile * 0.46, 0, TAU, 24,
					Color(0.95, 0.8, 0.2), 3.0)
	if item_active >= 0: # item targeting: cyan rings, stage-A pick in yellow
		for t in item_targets:
			draw_arc(_tile_px(t) + Vector2(tile, tile) / 2, tile * 0.38, 0, TAU, 24, Color(0.25, 0.8, 0.85), 3.0)
		if item_stage_a.x >= 0:
			draw_rect(Rect2(_tile_px(item_stage_a), Vector2(tile, tile)), COL_SELECT)
	# enemy recon selection: its reachable tiles draw in enemy red instead of
	# the player's move green (threatened pieces keep the capture ring)
	var recon: bool = selected.x >= 0 and board.has(selected) \
			and board[selected].owner == Rules.ENEMY
	var half := Vector2(tile, tile) / 2
	for d in legal_dests:
		if board.has(d): # capturable target: red tile tint + ring around the piece
			draw_rect(Rect2(_tile_px(d), Vector2(tile, tile)), Color(COL_CAPTURE, 0.3))
			draw_arc(_tile_px(d) + half, tile * 0.44, 0, TAU, 32, COL_CAPTURE, 3.0)
	if state == State.SETUP or legal_paths.is_empty():
		for d in legal_dests: # setup relocation / placement targets: plain dots
			if not board.has(d):
				draw_circle(_tile_px(d) + half, 8, COL_PLACE)
	else:
		# movement by shape: leaps = dots, rides = arrows, bent rides = dots
		# linked by a line (game-feel 2026-07-07)
		var col := Color(COL_ENEMY, 0.85) if recon else Color(COL_MOVE, 0.9)
		for p in legal_paths:
			match p.kind:
				"leap":
					if not board.has(p.to):
						draw_circle(_tile_px(p.to) + half, 10, col)
				"ride":
					if p.get("hop", false): # leap-rider: linked dots, not a slide
						_draw_linked_dots(_tile_px(selected) + half, p.line, col)
					else:
						_draw_move_arrow(_tile_px(selected) + half,
							_tile_px(p.line[-1]) + half, col)
				"bent":
					_draw_linked_dots(_tile_px(selected) + half, p.line, col)
	if placing_id != "" or pool_drag_id != "":
		var tiles := _setup_open_tiles() if state == State.SETUP else Rules.placement_tiles(board)
		for t in tiles:
			draw_circle(_tile_px(t) + Vector2(tile, tile) / 2, 8, COL_PLACE)
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
		elif a.kind == "outline": # turn-switch glow expanding off the border
			var grow: float = 4.0 + 12.0 * a.t
			draw_rect(Rect2(board_px - Vector2(grow, grow),
				Vector2(Tuning.BOARD_W, Tuning.BOARD_H) * tile + Vector2(grow, grow) * 2),
				Color(a.color, 1.0 - a.t), false, 5.0)
		elif a.kind == "banner": # turn/wave strip: slides in, holds, fades out
			var bw: float = Tuning.BOARD_W * tile
			var by: float = board_px.y + tile * 3.0 + a.get("slot", 0) * 52.0
			var alpha: float = minf(1.0, 4.0 * (1.0 - a.t))
			var slide: float = ease(minf(a.t * 4.0, 1.0), 0.3)
			var bx: float = board_px.x - (1.0 - slide) * bw
			draw_rect(Rect2(Vector2(bx, by), Vector2(bw, 44)),
				Color(0.06, 0.06, 0.09, 0.78 * alpha))
			draw_string(font, Vector2(bx, by + 31), a.text,
				HORIZONTAL_ALIGNMENT_CENTER, bw, 26, Color(a.color, alpha))
	if drag_from.x >= 0 and board.has(drag_from) and textures.has(board[drag_from].id):
		draw_texture_rect(textures[board[drag_from].id],
			Rect2(get_global_mouse_position() - Vector2(tile, tile) * 0.5, Vector2(tile, tile)), false, Color(1, 1, 1, 0.85))
	if pool_drag_id != "" and textures.has(pool_drag_id): # stock drag ghost
		draw_texture_rect(textures[pool_drag_id],
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
