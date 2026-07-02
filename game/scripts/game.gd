extends Node2D
## The whole run: SETUP placement -> PLAYER_TURN <-> ENEMY_TURN -> GAME_OVER.
## All UI is built in code; rules.gd holds every game-logic decision.

const Rules := preload("res://scripts/rules.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Waves := preload("res://data/waves.gd")

enum State { SETUP, PLAYER_TURN, ENEMY_TURN, GAME_OVER }

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
var textures := {} # id -> Texture2D; missing ids fall back to glyph text
var board := {} # Vector2i -> {id, owner}
var state := State.SETUP
var wave := 0            # last spawned wave number
var turns_since_wave := 0
var pending_spawn: Array = [] # piece ids waiting for open top-row tiles
var score := 0
var clock_ms := float(Tuning.CLOCK_START_MS)
var stock: Array = []
var captured: Array = []
var moves_left := 0
var placements_left := 0
var selected := Vector2i(-1, -1) # selected board piece
var legal_dests: Array[Vector2i] = []
var moved_this_turn: Array[Vector2i] = [] # pieces (by tile) that already moved
var drag_from := Vector2i(-1, -1) # board drag in progress; ghost follows the mouse
var placing_index := -1  # stock index being placed, -1 = none
var merge_mode := false
var merge_sel: Array = [] # int = combined-pool index, Vector2i = board tile
var anims: Array = [] # {kind: "move"|"pop", t, ...} rendered by _draw
var rng := RandomNumberGenerator.new()

var autoplay := false
var autoplay_turns := 0
var screenshot_dir := "" # debug: save PNGs for agent visual verification

# HUD nodes
var hud := CanvasLayer.new()
var clock_label := Label.new()
var score_label := Label.new()
var wave_label := Label.new()
var turn_label := Label.new()
var pass_button := Button.new()
var merge_button := Button.new()
var confirm_button := Button.new()
var pool_box := HBoxContainer.new()
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
	var vp := get_viewport_rect().size
	tile = int(minf((vp.x - 48.0) / Tuning.BOARD_W, (vp.y - 224.0) / Tuning.BOARD_H))
	board_px = Vector2(roundf((vp.x - tile * Tuning.BOARD_W) / 2.0), 100)
	defs = Rules.load_pieces()
	for id in defs:
		var path := "res://assets/pieces/%s.png" % id
		if ResourceLoader.exists(path):
			textures[id] = load(path)
	stock = Tuning.STARTING_STOCK.duplicate()
	rng.randomize()
	_build_hud()
	_refresh()


func _build_hud() -> void:
	add_child(hud)
	for l: Label in [clock_label, score_label, wave_label, turn_label]:
		l.add_theme_font_size_override("font_size", 20)
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

	pass_button.text = "PASS"
	pass_button.add_theme_font_size_override("font_size", 24)
	pass_button.modulate = Color(1, 0.5, 0.5)
	pass_button.position = Vector2(380, 36)
	pass_button.pressed.connect(_on_pass)
	hud.add_child(pass_button)

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
	score_label.text = "★ %d" % score
	wave_label.text = "wave %d/%d" % [wave, Waves.WAVES.size()]
	match state:
		State.SETUP:
			turn_label.text = "Place army (%d left) → PASS" % stock.size()
		State.PLAYER_TURN:
			var next_in := _cadence() - turns_since_wave
			var wave_txt := "King wave!" if _king_alive() else ("wave in %d" % maxi(next_in, 0)) if wave < Waves.WAVES.size() else "no more waves"
			turn_label.text = "moves %d · place %d · %s" % [moves_left, placements_left, wave_txt]
		State.ENEMY_TURN:
			turn_label.text = "enemy turn…"
		State.GAME_OVER:
			turn_label.text = ""
	_rebuild_pool_strip()
	confirm_button.visible = merge_mode and Rules.merge_result(_merge_ids(), defs) != ""
	queue_redraw()


func _rebuild_pool_strip() -> void:
	for c in pool_box.get_children():
		c.queue_free()
	var pool := _pool()
	for i in pool.size():
		var btn := Button.new()
		var from_captured: bool = i >= stock.size()
		btn.text = ("[%s]" if from_captured else "%s") % defs[pool[i]].glyph
		btn.tooltip_text = defs[pool[i]].name + (" (captured)" if from_captured else "")
		btn.add_theme_font_size_override("font_size", 22)
		if merge_mode and merge_sel.has(i):
			btn.modulate = Color(1.2, 1.1, 0.4)
		elif placing_index == i:
			btn.modulate = Color(0.6, 1.2, 0.6)
		btn.pressed.connect(_on_pool_pressed.bind(i))
		pool_box.add_child(btn)


func _merge_ids() -> Array:
	var pool := _pool()
	var ids := []
	for ref in merge_sel:
		ids.append(board[ref].id if ref is Vector2i else pool[ref])
	return ids


func _on_pool_pressed(index: int) -> void:
	if state == State.GAME_OVER or state == State.ENEMY_TURN:
		return
	if merge_mode:
		if merge_sel.has(index):
			merge_sel.erase(index)
		elif merge_sel.size() < 3:
			merge_sel.append(index)
	else:
		# placement: only stock pieces are placeable (captured merge in first)
		if index >= stock.size():
			return
		var can_place: bool = state == State.SETUP or placements_left > 0
		placing_index = index if placing_index != index and can_place else -1
		selected = Vector2i(-1, -1)
	_refresh()


func _on_confirm_merge() -> void:
	var result := Rules.merge_result(_merge_ids(), defs)
	if result == "":
		return
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
	_refresh()


func _on_pass() -> void:
	if state == State.SETUP:
		_spawn_wave(1)
		_begin_player_turn()
	elif state == State.PLAYER_TURN:
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
		clock_ms -= delta * 1000.0
		if clock_ms <= 0:
			clock_ms = 0
			return _game_over(false, "Clock out")
		clock_label.text = _clock_text()
		if autoplay:
			_autoplay_step()
	if not anims.is_empty():
		for a in anims:
			a.t += delta / ANIM_TIME
		anims = anims.filter(func(a: Dictionary) -> bool: return a.t < 1.0)
		queue_redraw()


# --- turn flow ---

func _begin_player_turn() -> void:
	state = State.PLAYER_TURN
	moves_left = Tuning.MOVES_PER_TURN
	placements_left = Tuning.PLACEMENTS_PER_TURN
	moved_this_turn.clear()
	# board cleared early -> skip the cadence wait, next wave arrives now
	if wave < Waves.WAVES.size() and pending_spawn.is_empty() and not _any_enemy():
		_queue_wave(wave + 1)
	_spawn_pending()
	if _player_pieces().is_empty() and stock.is_empty() and not Rules.has_merge(_pool()):
		return _game_over(false, "Resource starvation")
	_refresh()


func _enemy_turn() -> void:
	state = State.ENEMY_TURN
	selected = Vector2i(-1, -1)
	placing_index = -1
	merge_sel.clear()
	merge_button.button_pressed = false # also resets merge_mode via its toggle
	_refresh()
	turns_since_wave += 1
	if wave < Waves.WAVES.size() and not _king_alive() and turns_since_wave >= _cadence():
		_queue_wave(wave + 1)
	await _run_enemy_actions()
	if state != State.GAME_OVER:
		_begin_player_turn()


func _run_enemy_actions() -> void:
	for i in Tuning.ENEMY_ACTIONS_PER_TURN:
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
	pending_spawn.append_array(Waves.WAVES[n - 1])
	if n % Tuning.MILESTONE_WAVES == 0:
		clock_ms += Tuning.CLOCK_REFILL_MS
		score += Tuning.MILESTONE_SCORE_BONUS


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
		var tile: Vector2i = open[rng.randi() % open.size()]
		board[tile] = {"id": pending_spawn.pop_front(), "owner": Rules.ENEMY}


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
	detail.text = "%s\nScore %d · Deepest wave %d" % [reason, score, wave]
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
	if state == State.GAME_OVER or state == State.ENEMY_TURN:
		drag_from = Vector2i(-1, -1)
		return
	if event is InputEventMouseMotion and drag_from.x >= 0:
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var tile := _tile_at(event.position)
		if event.pressed:
			if tile.x >= 0:
				_on_tile_clicked(tile)
			# a fresh selection of an own piece also starts a potential drag
			if selected == tile and tile.x >= 0:
				drag_from = tile
		elif drag_from.x >= 0: # release ends a drag
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
	if merge_mode: # board clicks select merge sources, nothing else
		if board.has(tile) and board[tile].owner == Rules.PLAYER:
			if merge_sel.has(tile):
				merge_sel.erase(tile)
			elif merge_sel.size() < 3:
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
		score = maxi(score - Tuning.PLACEMENT_SCORE_COST, 0)
	_refresh()


func _move_player(from: Vector2i, to: Vector2i) -> void:
	if board.has(to): # capture
		var victim: Dictionary = board[to]
		score += defs[victim.id].value
		if victim.id == "king":
			return _win()
		captured.append(victim.id)
		_add_pop(to)
	_add_slide(from, to)
	board[to] = board[from]
	board.erase(from)
	moves_left -= 1
	moved_this_turn.append(to)
	selected = Vector2i(-1, -1)
	legal_dests.clear()
	if _king_alive() and Rules.is_checkmate(board, Rules.ENEMY, defs):
		return _win()
	if moves_left == 0 and state == State.PLAYER_TURN:
		return _on_pass() # last move auto-passes (playtest 2026-07-02)
	_refresh()


func _win() -> void:
	score += Tuning.WIN_SCORE_BONUS
	_game_over(true, "Wave-%d King checkmated" % wave)


# --- autoplay bot (headless verification) ---

func _autoplay_step() -> void:
	autoplay_turns += 1
	if autoplay_turns > 2000:
		# not a failure: the bot surviving this long just means no crash surfaced
		print("AUTOPLAY CAP: alive after 2000 steps (wave %d, score %d)" % [wave, score])
		get_tree().quit(0)
		return
	# One random legal action per frame, then pass when spent.
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


## Execute one available merge (3-same preferred, else 2-same). Returns true if merged.
func _autoplay_merge() -> bool:
	var pool := _pool()
	var counts := {}
	for i in pool.size():
		counts[pool[i]] = counts.get(pool[i], []) + [i]
	for want in [3, 2]:
		for id in counts:
			if counts[id].size() < want:
				continue
			# a 2-same merge yields 1 of the same piece — only worth it when it
			# converts a captured (unplaceable) piece into stock
			if want == 2 and counts[id].slice(0, want).all(func(i: int) -> bool: return i < stock.size()):
				continue
			merge_sel.assign(counts[id].slice(0, want))
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
	for a in anims:
		if a.kind == "move" and board.has(a.to):
			var mp: Dictionary = board[a.to]
			var mtint := Color(0.72, 0.85, 1.25) if mp.owner == Rules.PLAYER else Color(1.25, 0.72, 0.72)
			_draw_piece(font, mp, a.from_px.lerp(a.to_px, ease(a.t, 0.4)), mtint)
		elif a.kind == "pop":
			draw_arc(a.at_px, tile * (0.2 + 0.3 * a.t), 0, TAU, 24, Color(COL_CAPTURE, 1.0 - a.t), 4.0)
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
