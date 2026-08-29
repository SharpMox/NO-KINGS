extends Node2D
## The whole run: SETUP placement -> PLAYER_TURN <-> ENEMY_TURN -> GAME_OVER.
## This node owns run state, the turn state machine, input, and board
## painting. Everything else is split out (all UI still built in code):
## rules.gd (move legality) · wave_logic/economy/merge_logic/save_config/
## item_logic/box (domain logic, statics over this node) · hud.gd + modals.gd
## (child UI layers — signals up, calls down) · autoplay.gd (headless bot).

const Rules := preload("res://scripts/rules.gd")
const Box := preload("res://scripts/box.gd")
const ItemLogic := preload("res://scripts/item_logic.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const Economy := preload("res://scripts/economy.gd")
const MergeLogic := preload("res://scripts/merge_logic.gd")
const SaveConfig := preload("res://scripts/save_config.gd")
const CloudSave := preload("res://scripts/cloud_save.gd")
const Shop := preload("res://scripts/shop.gd")
const AutoplayBot := preload("res://scripts/autoplay.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Waves := preload("res://data/waves.gd")
const Items := preload("res://data/items.gd")
const Tariffs := preload("res://data/tariffs.gd")
const Scenarios := preload("res://data/scenarios.gd")
const Settings := preload("res://scripts/settings.gd")
const Kings := preload("res://data/kings.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")

enum State { SETUP, PLAYER_TURN, ENEMY_TURN, GAME_OVER }

## Boot config for the next Game scene (menu sets it; Restart replays it).
## Shape documented in data/scenarios.gd — the save file uses the same format.
static var next_config := {}
## TEST-menu / CLI scenario runs never autosave over the real run.
static var is_scenario := false
## Starting stock for a fresh run (menu's army select sets it; saves carry
## their stock in next_config instead, so this only matters when empty).
static var next_army: String = Tuning.DEFAULT_ARMY
## Difficulty tier (07-difficulty-ranks): menu's tier picker sets it, locked
## for the run — a save/Continue restores it via SaveConfig instead of
## re-reading this, same split as next_army above.
static var next_tier: String = Tuning.DEFAULT_TIER

const SAVE_PATH := "user://save.json"
const SCORES_PATH := "user://scores.json"
const HISTORY_PATH := "user://history.json"


## Local high scores, best first: [{score, wave, kings}], top 10 kept.
static func load_scores() -> Array:
	if not FileAccess.file_exists(SCORES_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCORES_PATH))
	return parsed if parsed is Array else []


## Games History: every real run's summary, newest first — distinct from the
## top-10 Highscores above. See Economy.record_history for what's stored.
static func load_history() -> Array:
	if not FileAccess.file_exists(HISTORY_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(HISTORY_PATH))
	return parsed if parsed is Array else []

const COL_LIGHT := Color("f0d9b5")
const COL_DARK := Color("b58863")
const COL_PLAYER := Color("1a3a6b")
const COL_ENEMY := Color("8b1a1a")
# side shift for monochrome tokens only — the painted art carries its own colour
const COL_SIDE_PLAYER := Color(0.72, 0.85, 1.25)
const COL_SIDE_ENEMY := Color(1.25, 0.72, 0.72)
const COL_PLACE := Color(0.2, 0.5, 0.9, 0.6) # placement / setup-relocation blue
# Palette rule (2026-07-07): everything player-side is a shade of blue —
# selection, moves, placement, merge partners; everything enemy-side is red —
# enemy pieces, threats, capture targets, recon.
const COL_MOVE := Color(0.3, 0.55, 0.95, 0.8)
const COL_CAPTURE := Color(0.85, 0.15, 0.15)
const COL_SELECT := Color(0.35, 0.62, 1.0, 0.4)
const COL_MERGE := Color(0.45, 0.85, 1.0) # cyan-blue: merge partners
const COL_ARROW := Color(0.95, 0.65, 0.15, 0.9) # Arrow Planning: deliberately
	# outside the blue/red side palette — decorative, not player or enemy state
const ANIM_TIME := 0.12 # seconds per move slide / capture pop

# board layout, computed from the viewport in _ready so any BOARD_W/H fits
var tile := 72
var board_px := Vector2(24, 120)

var defs: Dictionary
var fusions: Dictionary # unordered pair "a+b" -> result id
var textures := {} # id -> {Rules.PLAYER: Texture2D, Rules.ENEMY: Texture2D}
var mono_art := {} # ids whose token is one shared image, so it needs the side tint
var board := {} # Vector2i -> {id, owner}
var state := State.SETUP
var wave := 0            # last spawned wave number
var turns_since_wave := 0
var turn_number := 0 # run-long counter (issue 35), incremented once at the
	# single _begin_player_turn site — unlike turns_since_wave (reset every
	# Wave, in _enemy_turn), this never resets; Black Knight Morse Code's
	# "every 3rd Turn" reads it. Round-tripped through save_config.gd.
var kings_defeated := 0  # 1 = endless unlocked; end screens show it
var king_ids_defeated: Array = []  # roster (Kings.name_of), same order as falls
var win_open := false    # wave-50 win screen showing (Continue / End Run)
var lost_player := 0     # pieces lost, both sides — end-screen summary (GDD)
var lost_enemy := 0
var wave_start_lost_player := 0 # lost_player snapshot at wave start (artefact
	# hook 16: "clean wave" = lost_player unchanged since this snapshot)
var wave_capture_count := 0 # captures this wave, reset in WaveLogic.queue()
var turn_capture_count := 0 # captures this player turn, reset in _begin_player_turn
var gold_spent_shop_this_wave := 0 # reset in WaveLogic.queue() (artefact hook 16)
var silk_road_active := false # Silk Road Coupon's -50% Shop prices, reset in
	# WaveLogic.queue() every wave (artefact hook 18)
var nibiru_wave_streak := 0 # Nibiru Hide-and-Seek Trophy: grows +1 per Wave
	# clear, reset to 0 on_piece_lost (artefact_hooks.gd, artefact hook 19)
var hoffa_used_this_wave := false # Hoffa's Cement Shoes: once per Wave, reset
	# on_wave_clear (artefact_hooks.gd, artefact hook 24)
var salvation_charged := true # Salvation Gift Card: ready to veto the next
	# Tariff applied; consumed on use, restored on_wave_clear at wave%5==0
	# (artefact hook 22)
var last_capture_ctx: Dictionary = {} # this move's on_capture ctx (Economy.
	# capture_score) — read back by _move_player after its own board mutation
	# for USS Eldridge / Royal Fiat's post-move reposition (artefact hook 24)
var club27_streak := 0 # 27 Club Punch Card (issue 26): grows +1 per clean
	# Wave clear, reset to 0 on_piece_lost — same shape as nibiru_wave_streak
var wave_lost_ids: Array = [] # ids of player pieces lost this Wave, in order
	# (Jon Burrows' Fake ID / Walt's Cryonic Capsule, issue 26); reset in
	# WaveLogic.queue(), appended in _lose_player_piece — distinct from the
	# run-wide lost_player counter above
var arks_bunkbed_used := false # Ark's Bunkbed: this 5-Wave Milestone window's
	# free duplicate already granted; reset on_wave_clear when this HELD COPY's
	# own per-artefact "5-Wave Milestone" cadence hits (ArtefactHooks.
	# _milestone5_hit, ruled 2026-08-28 — see artefact_hooks.gd)
var lottery_purchase_count := 0 # Pre-Scratched Lottery Ticket: Shop
	# purchases made while held (issue 26) — read by Shop.price()
var doomsday_snooze_used_this_wave := false # Doomsday Clock Snooze Button:
	# this Wave's one +25s already spent, reset in WaveLogic.queue() (26)
var dihydrogen_free_wave := -1 # Dihydrogen Monoxide Battery: wave its one free
	# Tactical Item use already fired this Wave, -1 = not yet (artefact hook 19)
var wardenclyffe_free_wave := -1 # same idea, Wardenclyffe AAA Batteries' any-tier version
var mar_a_lago_free_wave := -1 # Mar-a-Lago Toilet Papers: g.wave the free Shop
	# slot was last (re)picked, -1 = not yet — guards against a 2nd held copy's
	# own milestone dispatch, in the same on_wave_clear event, clearing the 1st
	# copy's freshly-tagged slot before it's counted (artefact hook 43)
var item_use_tactical_count := 0 # 33rd Degree Fidelity Card's per-tier use counters
var item_use_strategic_count := 0
var mrna_apply_count := 0 # mRNA Firmware Update: Piece Buffs applied to your
	# pieces so far — every 3rd also Ranks Up (artefact hook 23)
var youth_fountain_wave := -1 # Youth Fountain Martini: wave its one free
	# buff-consume re-apply already fired this Wave, -1 = not yet (hook 23)
var artefact_echo_depth := 0 # ArtefactHooks re-entrancy guard (artefact hook 21):
	# >0 while the meta/echo pass itself is running, so a handler that somehow
	# re-entered ArtefactHooks.run() could never trigger a second echo pass
var mona_lisa_turn_done := false # 100% Genuine Original Mona Lisa: this Turn's
	# (player or enemy) first Artefact trigger already echoed; reset in
	# ArtefactHooks.run() at on_turn_start/on_enemy_turn_start
var dejavu_score_turn_done := false # Déjà Vu Glitch: this Turn's first Score
	# gain already doubled; reset in ArtefactHooks.run() at on_turn_start
var dejavu_gold_turn_done := false # same idea, first Gold gain each Turn
var pending_spawn: Array = [] # piece ids waiting for open top-row tiles
var fx_at := Vector2.ZERO # where the next score popup lands; ZERO = HUD label
var score := 0:
	set(value): # every gain/loss anywhere pops floating feedback (round 4);
		# popups anchor to the piece/effect that caused them (game-feel pass)
		if value != score and is_node_ready() and not autoplay and animations_on:
			var d := value - score
			anims.append({"kind": "text", "t": 0.0, "dur": 1.2,
				"text": ("+%d" if d > 0 else "%d") % d,
				"at_px": fx_at if fx_at != Vector2.ZERO
					else Vector2(hud.score_label.get_global_rect().end) + Vector2(6, 0),
				"color": Color(0.3, 0.85, 0.35) if d > 0 else Color(0.95, 0.3, 0.25)})
			queue_redraw()
		score = value
var gold := 0 # per-run spend currency; score stays the up-only metric
var shop_stock: Array = [] # 22 rolled slots {kind, key, sold} (scripts/shop.gd)
var shop_restocks := 0 # score thresholds banked so far (Shop.threshold)
var clock_ms := float(Tuning.CLOCK_START_MS)
var stock: Array = []
var captured: Array = []
var actions_left := 0 # unified: move, place, merge, item — 1 action each
var actions_max := 0  # granted this turn (base + artefact/item bonuses)
var early_clear_awarded := false # once per wave (resets when the next queues)
var pending_reinforce := false # shop due at the next player-turn start
var selected := Vector2i(-1, -1) # selected board piece
var legal_dests: Array[Vector2i] = []
var legal_paths: Array[Dictionary] = [] # shape-annotated dests (dots/arrows/links)
var moved_this_turn: Array[Vector2i] = [] # pieces (by tile) that already moved
var drag_from := Vector2i(-1, -1) # board drag in progress; ghost follows the mouse
var drag_moved := false # the pointer left the origin tile (tap vs aborted drag)
var drag_reselect := false # the pressed piece was already selected (re-click)
# Arrow Planning (Notion): purely decorative — never read by rules/AI. A
# scratchpad, not run state: cleared at turn end, never saved (2026-08-27).
var arrow_mode := false # while on, board drags draw arrows instead of selecting
var arrows: Array[Dictionary] = [] # {from: Vector2i, to: Vector2i}
var arrow_from := Vector2i(-1, -1) # arrow drag in progress
var pool_click_key := "" # double-tap detection on pool stacks (piece preview)
var pool_click_ms := 0
var pool_drag_id := "" # stock piece mid-drag from the strip (game-feel pass)
var armed_entry: Variant = "" # the exact Stock entry behind placing_id /
	# pool_drag_id: a bare id String or {id + state} Dictionary (ADR-0002).
	# Only read while one of those is armed, so no reset bookkeeping.
var preview_open := false
var placing_id := ""  # stock piece id being placed, "" = none
var placing_cap := false # the armed stack is captured stock (merge-only origin)
var pool_drag_cap := false # the mid-drag stack is captured stock
var drawer_autoclosed := "" # drawer the current drag closed; reopens on cancel
var merge_highlights := {} # ids that complete a merge with the current selection
var anims: Array = [] # {kind: "move"|"pop", t, ...} rendered by _draw
var items: Array = [] # held Items (single-use actives), max HUD row
var item_icons := {} # item key -> Texture2D; missing keys fall back to ✦ text
var artefacts: Array = [] # run-long passive effects
var box_open := false # box-pick modal showing; blocks all other input
var buff_pick_open := false # generic "choose 1 of N, then continue" modal
	# showing (issue 41) — same input block regardless of which caller opened
	# it; the Buff Box sub-pick was the first caller, never a special case.
var _choice_on_chosen: Callable # continuation for the open choice pick
var _choice_on_cancelled: Callable # ditto, run on cancel (may be invalid)
var pass_after_box := false # auto-pass deferred until the pick resolves
var item_active := -1 # items[] index being targeted, -1 = none
var item_stage_a := Vector2i(-1, -1) # first pick of a "pair" item
var item_targets: Array[Vector2i] = [] # valid target tiles for the active item
var item_selected: Array[Vector2i] = [] # toggled picks of a "multi" item
var pending_buff := "" # Buff Box: the buff chosen, waiting for its target
var _extract_sel: Array[Vector2i] = [] # multi selection frozen at confirm
var _buff_pick := "" # pending_buff frozen at confirm (_item_reset runs first)
var skip_enemy_turns := 0 # Surprise Attack
var turn_action_count := 0 # moves+placements taken this turn (artefact hook)
var action_log: Array[Dictionary] = [] # ordered {kind} entries this Turn (issue 30);
	# kind is one of "move"/"capture"/"place"/"merge"/"item". Cleared in
	# _begin_player_turn; appended only by _log_action, the choke point every
	# action site's turn_action_count += 1 already funnelled through.
var tariffs_active: Array = [] # action + persistent tariffs, run-long
var tariffs_suppressed := false # Counter-Intel: off for the rest of the wave
var tariffs_seen: Array = [] # every activation, for the end screens
var sanctioned_id := "" # Sanctions: piece type barred from placement
var rng := RandomNumberGenerator.new()

var autoplay := false
var autoplay_exit := false # quit-on-game-over: CLI --autoplay runs only, so the
                           # in-process scenario sweep (test_scenarios) survives
var autoplay_turns := 0
var autoplay_cap := 2000 # --steps N overrides, for short scenario sweeps
var screenshot_dir := "" # debug: save PNGs for agent visual verification

# HUD nodes
var hud := preload("res://scripts/hud.gd").new()
# HUD state forwarded read-only for the click probes and saves
# (the widgets themselves live in scripts/hud.gd)
var drawer_open: String:
	get: return hud.drawer_open
var pool_box: HBoxContainer:
	get: return hud.pool_box
var pass_button: Button:
	get: return hud.pass_button
var game_menu: PanelContainer:
	get: return hud.game_menu
var drawer_buttons: Dictionary:
	get: return hud.drawer_buttons
var stock_armed: Control:
	get: return hud.stock_armed
var modals := preload("res://scripts/modals.gd").new()
# modal panels forwarded read-only for the click probes (scripts/modals.gd)
var box_panel: PanelContainer:
	get: return modals.box_panel
var overlay: PanelContainer:
	get: return modals.overlay
var preview_panel: PanelContainer:
	get: return modals.preview_panel
var reinforce_panel: PanelContainer:
	get: return modals.reinforce_panel
var tariff_panel: PanelContainer:
	get: return modals.tariff_panel
var pending_merge: Array = [] # the two sources awaiting confirmation
var game_menu_open := false
var animations_on := true # Settings toggle (06); false short-circuits the
	# `anims` queue via the same seam autoplay already uses — see _add_*
var backgrounded := false # OS focus lost (app switch/call/notification, 06):
	# same pause state as the in-game menu — see _process and _enemy_turn


func _ready() -> void:
	# CLI bypasses (--autoplay/--scenario) and the click probes boot Game.tscn
	# straight, skipping the Menu's own apply() — so this scene applies too.
	var settings_data := Settings.load_settings()
	Settings.apply(settings_data)
	animations_on = settings_data.get("animations_on", true)
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
	if args.has("--tier"): # balance fleets: run the bot at a specific difficulty tier
		next_tier = args[args.find("--tier") + 1]
	_layout_board()
	defs = Rules.load_pieces()
	fusions = Rules.load_fusions()
	for id in defs:
		# Painted art is side-specific: <id>-light.png is the player token,
		# <id>-dark.png the enemy one, so no side tint is applied to them.
		# A lone <id>.svg is the old generated vector set — one monochrome
		# token for both sides, still tinted blue/red at draw time (king,
		# until its art arrives).
		var light := "res://assets/pieces/%s-light.png" % id
		var dark := "res://assets/pieces/%s-dark.png" % id
		if ResourceLoader.exists(light) and ResourceLoader.exists(dark):
			textures[id] = {Rules.PLAYER: load(light), Rules.ENEMY: load(dark)}
			continue
		var mono := "res://assets/pieces/%s.svg" % id
		if ResourceLoader.exists(mono):
			var t: Texture2D = load(mono)
			textures[id] = {Rules.PLAYER: t, Rules.ENEMY: t}
			mono_art[id] = true
	for it in Items.ITEMS: # item glyphs (picked 2026-07-17, .scratch/item-icons)
		var path := "res://assets/items/%s.svg" % it.key
		if ResourceLoader.exists(path):
			item_icons[it.key] = load(path)
	# GDD Game Flow — Run: one seed per run, captured so a save resumes the same
	# stream. SaveConfig.apply below overrides both when restoring a save, and a
	# scenario may pin "seed" to replay a bug exactly.
	rng.randomize()
	add_child(hud)
	hud.build(self)
	_connect_hud()
	add_child(modals)
	modals.build(self)
	_connect_modals()
	if args.has("--scenario"): # headless/CLI scenario boot, by index
		next_config = Scenarios.all()[int(args[args.find("--scenario") + 1])].cfg
		is_scenario = true
	if next_config.is_empty():
		# Tier 4+ halves each piece type, rounding up (07-difficulty-ranks)
		stock = Tuning.starting_stock(next_army, next_tier)
		_set_drawer("stock") # SETUP starts in the placement flow
	else:
		SaveConfig.apply(self, next_config)
	if args.has("--artefacts"): # balance sweep (issue 20): force a starting
		for key in args[args.find("--artefacts") + 1].split(","): # loadout, comma-separated keys, on top of whatever the boot path above granted
			for t in Items.ARTEFACT_EFFECTS:
				if t.key == key:
					var inst: Dictionary = t.duplicate() # per-copy acquisition
						# wave stamp (artefact_hooks.gd's "5-Wave Milestone") and
						# rarity stamp (issue 29 — Illuminati Fridge Magnet)
					inst.acquired_wave = wave
					inst.rarity = ArtefactHooks.rarity_of(key)
					artefacts.append(inst)
	if shop_stock.is_empty(): # fresh run, or a save from before the shop
		Shop.roll(self)
	if args.has("--scenario-check"): # boots, runs one frame, exits — CI probe
		await get_tree().process_frame
		await get_tree().process_frame
		print("SCENARIO OK")
		get_tree().quit()
	_refresh()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	var top := 26.0 # below the condensed top bar
	var bottom: float = vp.y - 46.0 # the button bar
	tile = int(minf((vp.x - 8.0) / Tuning.BOARD_W, (bottom - top) / Tuning.BOARD_H))
	# centered in the span so the top and bottom gaps match (2026-07-08)
	board_px = Vector2(roundf((vp.x - tile * Tuning.BOARD_W) / 2.0),
		roundf(top + (bottom - top - tile * Tuning.BOARD_H) / 2.0))
	queue_redraw()




func _pool() -> Array:
	return stock + captured




func _clock_text() -> String:
	return "⏱ %02d:%02d.%01d" % [int(clock_ms / 60000), int(clock_ms / 1000) % 60, int(clock_ms / 100) % 10]












func _clear_selection() -> void:
	selected = Vector2i(-1, -1)
	legal_dests.clear()
	legal_paths.clear()
	queue_redraw()


func _on_stack_pressed(entry: Variant, cap: bool, count: int) -> void:
	var id: String = entry if entry is String else entry.id
	if pool_drag_id != "":
		# mid-drag: hiding the drawer (drag-out close) force-releases the held
		# button, which fires a spurious tap inside the visibility cascade and
		# corrupts the strip rebuild (found 2026-07-08). Real taps clear the
		# drag in _input before this signal arrives.
		return
	if state == State.GAME_OVER or state == State.ENEMY_TURN or box_open or buff_pick_open \
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
	var same_stack: bool = placing_id != "" and armed_entry == entry and placing_cap == cap
	if not same_stack and merge_highlights.has(id):
		var unit := {"id": id, "cap": cap, "entry": entry}
		if placing_id != "":
			return MergeLogic.do_merge(self,
				{"id": placing_id, "cap": placing_cap, "entry": armed_entry}, unit)
		if selected.x >= 0:
			return MergeLogic.do_merge(self, selected, unit)
	# select / deselect the stack: arms placement + merging (captured stock
	# deploys too since 2026-07-07 — GDD Captured Stock rule, turn only)
	if same_stack:
		placing_id = ""
		placing_cap = false
	else:
		if cap and (state != State.PLAYER_TURN or actions_left <= 0):
			return # captured only merges, and a merge needs a turn action
		if not cap and Economy.sanctioned(self, id):
			return
		if not cap and not (state == State.SETUP or actions_left > 0):
			return
		placing_id = id
		placing_cap = cap
		armed_entry = entry
	_clear_selection()
	_refresh()








## Arrow Planning: a button toggle, guarded like the other HUD actions that
## must not fire mid-modal or mid-item-target (item targeting owns board taps).
func _on_arrow_toggle() -> void:
	if state == State.GAME_OVER or state == State.ENEMY_TURN or box_open or buff_pick_open \
			or preview_open or game_menu_open or win_open or item_active >= 0:
		return
	arrow_mode = not arrow_mode
	arrow_from = Vector2i(-1, -1)
	if arrow_mode: # entering the mode drops any selection/armed placement —
		placing_id = ""    # the board stops selecting pieces while it's on
		placing_cap = false
		_clear_selection()
	_refresh()


func _on_arrow_clear() -> void:
	arrows.clear()
	queue_redraw()


func _on_pass() -> void:
	if box_open or buff_pick_open or game_menu_open or win_open:
		return
	arrows.clear() # scratchpad: never survives past the turn it was drawn in
	queue_redraw()
	if state == State.SETUP:
		if hud.drawer_open != "": # setup done: full board for the run
			_set_drawer("")
		WaveLogic.spawn(self, 1)
		_begin_player_turn()
	elif state == State.PLAYER_TURN:
		fx_at = Vector2(hud.pass_button.get_global_rect().get_center())
		Economy.charge(self, "pass_cost")
		for pos in board: # same boundary rule, player side
			if board[pos].owner == Rules.PLAYER:
				BuffLogic.tick_side(board[pos])
		if not early_clear_awarded and _board_cleared():
			# wave beaten with turns to spare: score + clock scale with the lead
			early_clear_awarded = true
			var early := maxi(_cadence() - turns_since_wave, 0)
			if early > 0:
				Economy.earn(self, early * Tuning.EARLY_CLEAR_SCORE_PER_TURN, "early_clear")
				Economy.add_clock(self, early * Tuning.EARLY_CLEAR_CLOCK_MS_PER_TURN, "early_clear")
				_add_turn_fx("CLEARED EARLY  +%d ★ · +%ds" % [
					early * Tuning.EARLY_CLEAR_SCORE_PER_TURN,
					early * Tuning.EARLY_CLEAR_CLOCK_MS_PER_TURN / 1000],
					Color(0.95, 0.8, 0.25))
		Economy.add_clock(self, Tuning.TURN_END_CLOCK_BONUS_MS, "turn_end") # finishing a turn buys time
		ArtefactHooks.run(self, "on_turn_end") # Shrinkflation Cereal Box (18)
		_enemy_turn()


func _process(delta: float) -> void:
	if (selected.x >= 0 or placing_id != "") and not autoplay:
		queue_redraw() # the selection outline pulses every frame
		hud.stock_armed.queue_redraw()
	if autoplay and state == State.SETUP:
		# place the whole starting stock on random zone tiles, then begin
		var open := _setup_open_tiles()
		if stock.is_empty() or open.is_empty():
			_on_pass()
		else:
			_place(stock[rng.randi() % stock.size()], open[rng.randi() % open.size()])
		return
	if state == State.PLAYER_TURN:
		# Tier 1 (baseline) pauses the Clock for menu/win-screen/Shop/the Stock
		# and Inventory drawers/the piece preview; Tier 2+ keeps it running
		# through all of those, so browsing costs real time (07-difficulty-ranks).
		# Box Pick and the Buff Box sub-pick are deliberately absent from this
		# list at every tier — GDD Box Pick: "decisive picks rewarded,
		# indecision punished". OS-backgrounded pause (slice 06) always wins;
		# it is not a difficulty lever.
		var tier_pauses := not Tuning.clock_never_pauses(next_tier) \
				and (game_menu_open or win_open or shop_open() or drawer_open != "" or preview_open)
		if not tier_pauses and not backgrounded:
			# issue 35: deliberately NOT routed through Economy.add_clock/
			# on_clock_change — this is a continuous per-frame DRAIN, not a
			# discrete gain, and hooking it would fire on_clock_change every
			# single frame. Direct mutation stays, on purpose; don't "finish
			# the job" by wiring this one up too.
			clock_ms -= delta * 1000.0
		# Doomsday Clock Snooze Button (issue 26): the THRESHOLD CROSS is
		# watched here every frame (no discrete hook fires on one), but the
		# actual grant below is a one-time-per-wave GAIN, guarded by
		# doomsday_snooze_used_this_wave — routed through Economy.add_clock
		# (issue 35) same as any other gain, unlike the drain right above.
		if clock_ms < 30000.0 and clock_ms > 0.0 and not doomsday_snooze_used_this_wave \
				and _held("doomsday-clock-snooze-button"):
			Economy.add_clock(self, 25000.0, "doomsday_snooze")
			doomsday_snooze_used_this_wave = true
		if clock_ms <= 0:
			clock_ms = 0
			return _game_over(false, "Clock out")
		hud.clock_label.text = _clock_text()
		if autoplay:
			AutoplayBot.step(self)
	if not anims.is_empty():
		for a in anims:
			a.t += delta / a.get("dur", ANIM_TIME)
		anims = anims.filter(func(a: Dictionary) -> bool: return a.t < 1.0)
		queue_redraw()


# --- turn flow ---

## Turn/wave transition feedback: board-outline glow + a sliding banner
## (game-feel pass 2026-07-06). Stacked banners offset so they never overlap.
func _add_turn_fx(text: String, color: Color) -> void:
	if autoplay or not animations_on:
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
	turn_number += 1 # issue 35: the single increment site — save_config.gd's
		# apply() overrides the result AFTER this call (same pattern as
		# skip_enemy_turns there), since a resumed save must not double-count
		# the Turn it was saved on
	_clear_selection() # a setup selection must not survive START
	state = State.PLAYER_TURN
	actions_left = Tuning.actions_per_turn(next_tier) # Tier 5: -1 (07-difficulty-ranks)
	ArtefactHooks.run(self, "on_turn_start")
	actions_max = actions_left
	moved_this_turn.clear()
	for pos in board: # Blitz's free move is scoped "this Turn" — never carries over
		board[pos].erase("blitz_free_move")
	turn_action_count = 0
	action_log = []
	turn_capture_count = 0
	for pos in board: # timed buffs (Slow/Aura/Smog) age one player turn
		BuffLogic.tick(board[pos])
	# board cleared early -> skip the cadence wait, next wave arrives now
	if wave < Waves.WAVES.size() and pending_spawn.is_empty() and not _any_enemy():
		WaveLogic.queue(self, wave + 1)
	WaveLogic.spawn_pending(self)
	if _player_pieces().is_empty() and stock.is_empty() and not Rules.has_merge(_pool(), defs, fusions):
		return _game_over(false, "Resource starvation")
	if not autoplay and not is_scenario: # autosave at every turn start
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify(SaveConfig.to_config(self)))
		CloudSave.sync_file("run", SAVE_PATH) # mirror to the platform backend (12)
	_refresh()
	if pending_reinforce: # saved BEFORE consuming: a resumed run reopens it
		if autoplay:
			pending_reinforce = false
			AutoplayBot.reinforce(self)
		else:
			modals.show_reinforce()


func _enemy_turn() -> void:
	state = State.ENEMY_TURN
	_add_turn_fx("ENEMY TURN", Color(1.0, 0.42, 0.35))
	if hud.drawer_open != "": # full board while the enemy plays
		_set_drawer("")
	_clear_selection()
	placing_id = ""
	placing_cap = false
	pool_drag_id = ""
	pool_drag_cap = false
	_item_reset()
	_refresh()
	turns_since_wave += 1
	if wave < Waves.WAVES.size() and not _king_alive() and turns_since_wave >= _cadence():
		WaveLogic.queue(self, wave + 1)
	if skip_enemy_turns > 0: # Surprise Attack: the enemy sits this one out
		skip_enemy_turns -= 1
	else:
		if not autoplay and animations_on:
			await get_tree().create_timer(Tuning.ENEMY_TURN_PAUSE).timeout
		await _wait_while_backgrounded() # 06: no enemy turn resolves while backgrounded
		await _run_enemy_actions()
	if state != State.GAME_OVER:
		if not autoplay and animations_on:
			await get_tree().create_timer(Tuning.ENEMY_TURN_PAUSE).timeout
		await _wait_while_backgrounded()
		_begin_player_turn()


## OS backgrounding (06): app switch/call/notification must freeze the run
## exactly like the in-game menu — no enemy action may resolve mid-background.
## Polls rather than engine-pausing the tree, so it hangs off the same
## flag-based seam as game_menu_open/win_open/shop_open() instead of a second
## pause mechanism.
func _wait_while_backgrounded() -> void:
	while backgrounded:
		await get_tree().process_frame


func _run_enemy_actions() -> void:
	var actions := Economy.enemy_actions(self)
	for i in actions:
		await _wait_while_backgrounded()
		var act := Rules.ai_action(board, defs)
		if act.is_empty():
			return
		if not autoplay and animations_on:
			await get_tree().create_timer(0.35).timeout
		await _wait_while_backgrounded()
		if board.has(act.to) and BuffLogic.repels_capture(board[act.to]):
			# Shield works against the AI too: the attempt is spent, nothing
			# moves. Reflect kills the attacker and takes its tile.
			if BuffLogic.reflects_capture(board[act.to]):
				_consume_buff(act.to, "reflect")
				_add_float(act.from, "Reflected!", COL_CAPTURE)
				lost_enemy += 1
				_add_pop(act.from)
				board[act.from] = board[act.to]
				board.erase(act.to)
			else:
				_consume_buff(act.to, "shield")
				_add_float(act.to, "Blocked", COL_MERGE)
			queue_redraw()
			continue
		if board.has(act.to) and (BuffLogic.has(board[act.to], "bomb")
				or BuffLogic.has(board[act.from], "bomb")):
			# Consumed before either piece is erased, purely so Cleopatra's
			# Hairpin / Guidestone Blood Ritual see the trigger — both
			# pieces are gone either way.
			if BuffLogic.has(board[act.to], "bomb"):
				_consume_buff(act.to, "bomb")
			if BuffLogic.has(board[act.from], "bomb"):
				_consume_buff(act.from, "bomb")
			board.erase(act.to)
			board[act.to] = board[act.from]
			board.erase(act.from)
			_detonate(act.to)
			queue_redraw()
			continue
		if board.has(act.to) and BuffLogic.has(board[act.to], "trap"):
			# Trap takes the attacker with it — neither piece survives
			_consume_buff(act.to, "trap") # same reasoning as bomb above
			_add_float(act.from, "Trapped!", COL_CAPTURE)
			_lose_player_piece(act.to, "trap")
			lost_enemy += 1
			_add_pop(act.to)
			_add_pop(act.from)
			board.erase(act.to)
			board.erase(act.from)
			queue_redraw()
			continue
		if board.has(act.to):
			if BuffLogic.has(board[act.to], "stun"):
				# 2 ticks: the buff ages at the start of each PLAYER turn, so
				# 2 keeps the attacker out for exactly one enemy turn
				BuffLogic.add(board[act.from], "stunned", Tuning.STUN_MISSES + 1)
				_add_float(act.from, "Stunned!", COL_MERGE)
			_note_capture(act.from) # no on_capture here (the enemy doesn't
				# score) — still the attacker's OWN ledger, read later by
				# Chupacabra Chew Toy off the victim (issue 25). Fires even
				# when Hoffa's Cement Shoes sinks the attacker right after —
				# the capture already happened, same as Bomb/Trap in
				# _move_player killing the attacker AFTER its capture scored.
			if _lose_player_piece(act.to, "captured", act.from).destroy_attacker:
				# Hoffa's Cement Shoes (artefact hook 24): once per Wave, the
				# capturer sinks with its victim — Trap's own mutual-
				# destruction shape above, artefact-gated instead of
				# BuffLogic-gated
				_add_float(act.from, "Sunk!", COL_CAPTURE)
				lost_enemy += 1
				_add_pop(act.to)
				_add_pop(act.from)
				board.erase(act.to)
				board.erase(act.from)
				queue_redraw()
				continue
			_add_pop(act.to)
		_add_slide(act.from, act.to)
		board[act.to] = board[act.from]
		board.erase(act.from)
		queue_redraw()
		if _back_row_breached():
			return _game_over(false, "Back-row breach")
	for pos in board: # Stun ages on the stunned side's own turn boundary
		if board[pos].owner == Rules.ENEMY:
			BuffLogic.tick_side(board[pos])


func _add_slide(from: Vector2i, to: Vector2i) -> void:
	if autoplay or not animations_on:
		return
	anims.append({"kind": "move", "to": to, "from_px": _tile_px(from), "to_px": _tile_px(to), "t": 0.0})


## Floating label at a tile — the same anim the score popups use, for effects
## that have no score to show (a buff landing, a capture repelled).
func _add_float(at: Vector2i, text: String, color: Color) -> void:
	if autoplay or not animations_on:
		return
	anims.append({"kind": "text", "t": 0.0, "dur": 1.2, "text": text,
		"at_px": _tile_px(at) + Vector2(tile, tile) / 2, "color": color})


func _add_pop(at: Vector2i) -> void:
	if autoplay or not animations_on:
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


## Royal Fiat (Undamaged)'s forced-retreat landing tile (artefact hook 24):
## the first empty back-row (y=0) square scanning x=0..BOARD_W-1 — no GDD
## guidance on ties, ruled 2026-08-28. Vector2i(-1,-1) when the row is full,
## which the caller treats as "no forced move" rather than displacing anyone.
func _first_empty_backrow_tile() -> Vector2i:
	for x in Tuning.BOARD_W:
		var t := Vector2i(x, 0)
		if not board.has(t):
			return t
	return Vector2i(-1, -1)


func _cadence() -> int:
	var next_wave_i: int = mini(wave, Waves.WAVES.size() - 1)
	return Tuning.CADENCE_BASE + Waves.WAVES[next_wave_i].size()


func _king_alive() -> bool:
	return Rules.find_king(board, Rules.ENEMY).x >= 0


## Display name of the King currently on the board, or "King" if there is
## none / it wasn't spawned with an identity (hand-written test scenarios).
func _king_name() -> String:
	var k := Rules.find_king(board, Rules.ENEMY)
	if k.x < 0:
		return "King"
	return Kings.name_of(board[k].get("king_id", ""))








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


## Structural "is this Artefact held" read, for the handful of standing rules
## (issue 26: Nazca Boarding Pass, Nuclear Football Menu) that aren't a
## triggered effect and so have no hook to dispatch on — same direct
## g.artefacts read shop.gd already uses for chocolate-key-cake etc.
func _held(key: String) -> bool:
	for t in artefacts:
		if t.key == key:
			return true
	return false


## Nazca Boarding Pass (issue 26): Deploy legality opens to every empty tile
## instead of Rules.placement_tiles' zone/touching-ally set. A standing rule,
## not a hook — see _held above.
func _deploy_tiles() -> Array[Vector2i]:
	if _held("nazca-boarding-pass"):
		var out: Array[Vector2i] = []
		for x in Tuning.BOARD_W:
			for y in Tuning.BOARD_H:
				if not board.has(Vector2i(x, y)):
					out.append(Vector2i(x, y))
		return out
	return Rules.placement_tiles(board)


func _game_over(won: bool, reason: String) -> void:
	state = State.GAME_OVER
	ArtefactHooks.run(self, "on_game_over") # before record_score: e.g. Rapture
		# Insurance Policy converts Gold to Score, and the converted total is
		# what gets ranked (issue 16)
	if not is_scenario and FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH) # the run ended; nothing to resume
	var rank := 0 # scenario/bot runs stay off the local leaderboard
	if not is_scenario and not autoplay:
		rank = Economy.record_score(self)
		_record_history(won) # Games History: every real run, win or loss
	modals.show_overlay(won, reason, rank)
	_refresh()
	if autoplay_exit:
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






func _on_win_continue() -> void:
	win_open = false
	overlay.visible = false
	Economy.add_clock(self, Tuning.CONTINUE_CLOCK_REFILL_MS, "continue") # one-time endless bonus
	if actions_left == 0 and state == State.PLAYER_TURN:
		return _on_pass() # the checkmate spent the last action — resume the flow
	_refresh()


# --- input ---

## Press-drag from a stock stack: the piece follows the cursor and drops onto
## a valid placement tile. Tapping (release back on the button) still selects.
func _on_stack_drag_start(entry: Variant, cap: bool) -> void:
	var id: String = entry if entry is String else entry.id
	if box_open or buff_pick_open or win_open or game_menu_open or preview_open:
		return
	if not cap and Economy.sanctioned(self, id):
		return
	if cap and (state != State.PLAYER_TURN or actions_left <= 0):
		return # captured drags only merge, and a merge needs a turn action
	if state != State.SETUP and (state != State.PLAYER_TURN or actions_left <= 0):
		return
	_clear_selection()
	pool_drag_id = id
	pool_drag_cap = cap
	armed_entry = entry
	drawer_autoclosed = ""
	# highlight drop targets WITHOUT rebuilding the strip — a rebuild would
	# free the pressed button and its release-tap (pressed) would never fire,
	# breaking tap-to-place (found 2026-07-07)
	merge_highlights = MergeLogic.partner_ids(self)
	for c in hud.pool_box.get_children():
		if c is Button and c.has_meta("id") and merge_highlights.has(c.get_meta("id")):
			c.modulate = Color(0.8, 1.1, 1.4)
	queue_redraw()


## Buttons capture the click, so the drag's release lands here, not in
## _unhandled_input.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT and pool_drag_id != "":
		# the cursor left the window mid-drag: cancel and restore the drawer
		pool_drag_id = ""
		pool_drag_cap = false
		if drawer_autoclosed != "":
			_set_drawer.call_deferred(drawer_autoclosed)
			drawer_autoclosed = ""
		queue_redraw()
	# 06: app switch, phone call or notification — same pause state as the
	# in-game menu (clock stopped, no enemy turns), via `backgrounded`.
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		backgrounded = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		backgrounded = false


func _input(event: InputEvent) -> void:
	if pool_drag_id == "":
		return
	if event is InputEventMouseMotion:
		if hud.drawer_open != "" and not \
				(hud.drawers[hud.drawer_open] as Control).get_global_rect().has_point(event.position):
			drawer_autoclosed = hud.drawer_open # reopen if this drag cancels
			_set_drawer("") # dragged out toward the board: give it back
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		var t := _tile_at(event.position)
		var id := pool_drag_id
		var cap := pool_drag_cap
		var entry: Variant = armed_entry
		pool_drag_id = ""
		pool_drag_cap = false
		# a release inside the open drawer must never hit the board tiles
		# hidden beneath it — that reads as a misinput (2026-07-08). Dragging
		# out closes the drawer, so real board drops arrive uncovered.
		var covered: bool = hud.drawer_open != "" and (hud.drawers[hud.drawer_open] as Control) \
				.get_global_rect().has_point(event.position)
		# drop on a friendly partner piece: merge into its tile
		if not covered and state == State.PLAYER_TURN and t.x >= 0 and board.has(t) \
				and board[t].owner == Rules.PLAYER and merge_highlights.has(board[t].id):
			get_viewport().set_input_as_handled()
			drawer_autoclosed = ""
			return MergeLogic.do_merge(self, {"id": id, "cap": cap, "entry": entry}, t)
		# drop on a DIFFERENT partner stack in the strip: pool merge. Dropping
		# back on the same stack is a plain tap (arms placement) — same-stack
		# promotion goes through the ▲ badge instead (2026-07-07)
		var target := hud.stack_button_at(event.position)
		if state == State.PLAYER_TURN and target != null \
				and merge_highlights.has(target.get_meta("id")) \
				and not (target.get_meta("id") == id and target.get_meta("cap") == cap):
			get_viewport().set_input_as_handled()
			return MergeLogic.do_merge(self, {"id": id, "cap": cap, "entry": entry},
				{"id": target.get_meta("id"), "cap": target.get_meta("cap"),
					"entry": target.get_meta("entry")})
		var placeable: bool = not covered and t.x >= 0 and not board.has(t) \
			and (t.y < Tuning.PLAYER_ZONE_ROWS if state == State.SETUP
				else _deploy_tiles().has(t))
		if placeable and (state == State.SETUP
				or (state == State.PLAYER_TURN and actions_left > 0)):
			drawer_autoclosed = ""
			_place(entry, t, cap)
		else: # dropped elsewhere (incl. back on the button = plain tap)
			if drawer_autoclosed != "": # the drag closed it, nothing happened:
				_set_drawer.call_deferred(drawer_autoclosed) # give it back
				drawer_autoclosed = ""
			# deferred: an immediate rebuild frees the button before its
			# release-tap (pressed) fires, killing tap-to-place (2026-07-07)
			_refresh.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if preview_open or game_menu_open:
		return # the panels' own buttons handle dismissal
	if state == State.GAME_OVER or state == State.ENEMY_TURN or box_open or buff_pick_open or win_open:
		drag_from = Vector2i(-1, -1)
		arrow_from = Vector2i(-1, -1)
		return
	if arrow_mode and item_active < 0: # item targeting still owns board taps
		return _arrow_input(event)
	if event is InputEventMouseMotion:
		if drag_from.x >= 0:
			if _tile_at(event.position) != drag_from:
				drag_moved = true # a real drag, not a tap in place
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at := _tile_at(event.position)
		if event.pressed:
			# any press outside an open drawer closes it to reveal the board
			if hud.drawer_open != "" and not (hud.drawers[hud.drawer_open] as Control) \
					.get_global_rect().has_point(event.position):
				_set_drawer("")
			if at.x < 0: # dead UI space: a no-interaction press drops selection
				if selected.x >= 0 or placing_id != "":
					placing_id = ""
					placing_cap = false
					_clear_selection()
					_refresh()
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
					MergeLogic.do_merge(self, from, t) # dragged onto a partner: merge onto its tile
				elif state == State.SETUP and t.x < 0 and (
						(hud.pool_box.is_visible_in_tree() and (hud.pool_box.get_parent() as Control)
							.get_global_rect().has_point(event.position))
						or (hud.drawer_buttons["stock"] as Control)
							.get_global_rect().has_point(event.position)):
					_setup_to_stock(from) # dropped on the drawer or Stock button
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


## Arrow Planning: drag draws a decorative arrow; redrawing the same one
## removes it (clear-one). Purely visual — never reaches rules/AI/legality.
func _arrow_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if arrow_from.x >= 0:
			queue_redraw() # ghost line follows the pointer
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at := _tile_at(event.position)
		if event.pressed:
			arrow_from = at
		elif arrow_from.x >= 0:
			var from := arrow_from
			arrow_from = Vector2i(-1, -1)
			if at.x >= 0 and at != from:
				var idx := _arrow_index(from, at)
				if idx >= 0:
					arrows.remove_at(idx) # redrawing an existing arrow clears it
				else:
					arrows.append({"from": from, "to": at})
			queue_redraw()


func _arrow_index(from: Vector2i, to: Vector2i) -> int:
	for i in arrows.size():
		if arrows[i].from == from and arrows[i].to == to:
			return i
	return -1


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
			return MergeLogic.do_merge(self,
				{"id": placing_id, "cap": placing_cap, "entry": armed_entry}, tile)
		# captured stock deploys like stock (GDD Captured Stock, wired 2026-07-07)
		var ok := tile.y < Tuning.PLAYER_ZONE_ROWS if state == State.SETUP else _deploy_tiles().has(tile)
		if ok and not board.has(tile):
			_place(armed_entry, tile, placing_cap)
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
		MergeLogic.do_merge(self, selected, tile) # second pick completes the merge on its tile
	elif board.has(tile) and board[tile].owner == Rules.PLAYER and actions_left > 0 \
			and not moved_this_turn.has(tile) \
			and not BuffLogic.has(board[tile], "stunned"):
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


## `entry` is a Stock entry: a bare id String or {id + state} (ADR-0002).
func _place(entry: Variant, tile: Vector2i, cap := false) -> void:
	var id: String = entry if entry is String else entry.id
	fx_at = _tile_px(tile) + Vector2(self.tile, self.tile) / 2
	(captured if cap else stock).erase(entry)
	board[tile] = {"id": id, "owner": Rules.PLAYER}
	if entry is Dictionary: # restore the piece state it left the board with
		board[tile].merge(entry)
	placing_id = ""
	placing_cap = false
	if state == State.PLAYER_TURN:
		# MK-Ultra Sugar Cube (18); skip_action: Hitler's Argentinian Passport (26)
		var deploy_ctx := ArtefactHooks.run(self, "on_deploy", {"pos": tile, "skip_action": false})
		if not deploy_ctx.skip_action:
			actions_left -= 1
		_log_action("place")
		Economy.charge(self, "deploy_cost")
		Economy.spend_gold(self, Economy.deploy_cost(self))
		if actions_left == 0 or _board_cleared(): # last action spent placing
			return _on_pass()
	elif state == State.SETUP and not stock.is_empty() and hud.drawer_open != "stock":
		_set_drawer("stock") # keep the placement flow going
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
	var captured_king_id := ""
	var return_to_start := false # USS Eldridge Invisibility Paint (artefact hook 24)
	var move_to_backrow := false # Royal Fiat (Undamaged), same mechanism
	# Blitz rework (Notion 2026-08-28): the target's next move/capture this
	# Turn costs no action — a one-shot flag on the piece Dictionary itself
	# (ADR-0002: opaque piece state rides the Dictionary object, not a board
	# position, since `from` is about to move or disappear). Captured once,
	# up front, so every actions_left -= 1 below can consume it.
	var moving_piece: Dictionary = board[from]
	var blitz_free: bool = moving_piece.get("blitz_free_move", false)
	var did_capture := board.has(to) # action-log kind (issue 30): "move" vs "capture"
	fx_at = _tile_px(to) + Vector2(tile, tile) / 2 # popups at the action tile
	if board.has(to) and BuffLogic.repels_capture(board[to]):
		# GDD Pieces & Movement: a repelled attacker returns to its starting
		# tile and nothing is captured. The attempt still costs the action.
		# Reflect goes further — the defender takes the attacker's tile.
		if BuffLogic.reflects_capture(board[to]):
			_consume_buff(to, "reflect")
			_add_float(from, "Reflected!", COL_CAPTURE)
			_lose_player_piece(from, "reflect")
			_add_pop(from)
			board[from] = board[to] # the defender counter-attacks into the tile
			board.erase(to)
		else:
			_consume_buff(to, "shield")
			_add_float(to, "Blocked", COL_MERGE)
		Economy.charge(self, "move_cost")
		if blitz_free:
			moving_piece.erase("blitz_free_move")
		else:
			actions_left -= 1
		_log_action("capture") # blocked attack — still an attempt against a piece
		moved_this_turn.append(from)
		_clear_selection()
		if actions_left == 0 and state == State.PLAYER_TURN:
			return _on_pass()
		return _refresh()
	if board.has(to): # capture
		var victim: Dictionary = board[to]
		var attacker_buffed := not BuffLogic.of(board[from]).is_empty()
		var capture_pts := Economy.capture_score(self, victim.id, board[from].id, attacker_buffed, from, to) \
			* BuffLogic.capture_multiplier(board, from)
		# Curtain Rods Bag (issue 31): "first Capture each Wave" is only
		# knowable here, right after capture_score() sets last_capture_ctx —
		# wave_capture_index is 0-based, read before Economy.earn runs, so its
		# on_score_change/on_gold_change handlers below can scope to this one
		# call by reason alone (see artefact_hooks.gd's header).
		var earn_reason := "wave_first_capture" if last_capture_ctx.get("wave_capture_index", -1) == 0 else ""
		Economy.earn(self, capture_pts, earn_reason)
		# snapshotted now, before Multicapture (below) can fire a second
		# capture_score call that overwrites g.last_capture_ctx with its own
		# ctx (artefact hook 24 — see artefact_hooks.gd header)
		return_to_start = last_capture_ctx.get("return_to_start", false)
		move_to_backrow = last_capture_ctx.get("move_to_backrow", false)
		var grant_buffs: Array = last_capture_ctx.get("grant_buffs", [])
		if BuffLogic.has(board[from], "critical"):
			_consume_buff(from, "critical")
			_add_float(to, "Critical!", COL_MERGE)
		# Range is spent by the capture, not by repositioning
		if BuffLogic.has(board[from], "range"):
			_consume_buff(from, "range")
		# Grant-on-capture (Obedience-Flavored Tap Water, Holy Lint) lands here,
		# AFTER critical/range are consumed above — ruled 2026-08-28: a granted
		# buff is a reward banked for the NEXT capture, not this one. Landing it
		# any earlier let a newly-granted critical double THIS capture (its
		# score multiplier reads board[from] synchronously, right after the
		# on_capture dispatch above) or a newly-granted range get consumed here
		# for zero effect.
		for tier in grant_buffs:
			ArtefactHooks._grant_buff(self, from, tier)
		if BuffLogic.has(victim, "stun"): # cuts both ways
			BuffLogic.add(board[from], "stunned", Tuning.STUN_MISSES + 1)
			_add_float(from, "Stunned!", COL_MERGE)
		if BuffLogic.has(board[from], "multicapture"):
			# one extra enemy beside the piece just taken (ruled 2026-08-28)
			var also := BuffLogic.multicapture_target(board, to, Rules.PLAYER, defs)
			_consume_buff(from, "multicapture")
			if also.x >= 0:
				_add_float(also, "Multicapture!", COL_MERGE)
				Economy.earn(self, Economy.capture_score(self, board[also].id,
					board[from].id, attacker_buffed, from, also))
				captured.append(board[also].id)
				lost_enemy += 1
				_add_pop(also)
				board.erase(also)
		Economy.charge(self, "capture_cost")
		lost_enemy += 1
		if victim.id != "king" and (BuffLogic.has(victim, "bomb")
				or BuffLogic.has(board[from], "bomb")):
			# Precedence ruled 2026-08-28: Reflect > Bomb > Trap. Reflect
			# resolved above (the capture never lands); the blast takes the
			# attacker anyway, so Trap has nothing left to do.
			# Consumed before either piece is erased, purely so Cleopatra's
			# Hairpin / Guidestone Blood Ritual see the trigger.
			if BuffLogic.has(victim, "bomb"):
				_consume_buff(to, "bomb")
			if BuffLogic.has(board[from], "bomb"):
				_consume_buff(from, "bomb")
			captured.append(victim.id) # the capture itself still resolved
			board.erase(to)
			board[to] = board[from] # the attacker lands, then the blast
			board.erase(from)
			_detonate(to)
			if blitz_free:
				moving_piece.erase("blitz_free_move")
			else:
				actions_left -= 1
			_log_action("capture")
			if state == State.PLAYER_TURN and (actions_left == 0 or _board_cleared()):
				return _on_pass()
			return _refresh()
		if BuffLogic.has(victim, "trap"): # the attacker goes with it
			_consume_buff(to, "trap") # same reasoning as bomb above
			_add_float(from, "Trapped!", COL_CAPTURE)
			_lose_player_piece(from, "trap")
			_add_pop(from)
			board.erase(from)
			board.erase(to)
			captured.append(victim.id)
			if blitz_free:
				moving_piece.erase("blitz_free_move")
			else:
				actions_left -= 1
			_log_action("capture")
			if actions_left == 0 and state == State.PLAYER_TURN:
				return _on_pass()
			return _refresh()
		if victim.id == "king": # boss piece — never enters Captured Stock
			king_captured = true
			captured_king_id = victim.get("king_id", "")
		else:
			captured.append(victim.id)
			boxed = victim.get("buff", false)
		_add_pop(to)
	Economy.charge(self, "move_cost")
	if _is_long_range(board[from].id):
		var d := to - from
		Economy.charge(self, "long_range_cost", Tuning.TARIFF_LR_PER_SQUARE * maxi(absi(d.x), absi(d.y)))
	_add_slide(from, to)
	board[to] = board[from]
	board.erase(from)
	var final_pos := to
	if return_to_start: # USS Eldridge Invisibility Paint — undo the slide
		board[from] = board[to]
		board.erase(to)
		_add_slide(to, from)
		final_pos = from
	elif move_to_backrow and to.y != 0: # Royal Fiat (Undamaged) — forced retreat
		var dest := _first_empty_backrow_tile()
		if dest.x >= 0:
			board[dest] = board[to]
			board.erase(to)
			_add_slide(to, dest)
			final_pos = dest
	if blitz_free:
		moving_piece.erase("blitz_free_move")
	else:
		actions_left -= 1
	_log_action("capture" if did_capture else "move")
	moved_this_turn.append(final_pos)
	_clear_selection() # incl. legal_paths — stale shape overlay bug 2026-07-07
	if king_captured or (_king_alive() and Rules.is_checkmate(board, Rules.ENEMY, defs)):
		if _king_down(captured_king_id):
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


func _king_down(defeated_id := "") -> bool:
	kings_defeated += 1
	fx_at = Vector2(hud.wave_label.get_global_rect().get_center())
	Economy.earn(self, Tuning.WIN_SCORE_BONUS)
	var k := Rules.find_king(board, Rules.ENEMY)
	if k.x >= 0: # checkmated, not captured — the boss still leaves the board
		if defeated_id == "":
			defeated_id = board[k].get("king_id", "")
		board.erase(k)
	if defeated_id != "":
		king_ids_defeated.append(defeated_id)
	if wave >= Waves.WAVES.size():
		_game_over(true, "FULL CLEAR — every King has fallen")
		return true
	if kings_defeated == 1:
		if autoplay: # nobody to press Continue; end the run as a win
			_game_over(true, "Wave-%d King checkmated" % wave)
			return true
		_show_win_screen()
		return true
	Economy.add_clock(self, Tuning.KING_CLOCK_REFILL_MS, "king_refill") # recurring King
	_refresh()
	return false


# --- piece preview (long-press a piece anywhere) ---



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
		dia.draw_texture_rect(piece_tex(id),
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


func _reinforce_ids() -> Array:
	var seen := {}
	var out := []
	for id in Tuning.ARMIES.get(next_army, Tuning.ARMIES[Tuning.DEFAULT_ARMY]):
		if not seen.has(id):
			seen[id] = true
			out.append(id)
	return out







func _use_item(index: int) -> void:
	if state != State.PLAYER_TURN or box_open:
		return
	if item_active == index: # tap again to cancel targeting
		_item_reset()
		_refresh()
		return
	if hud.drawer_open != "": # using an item hands the board back (targeting)
		_set_drawer("")
	var it: Dictionary = items[index]
	if it.target == "":
		_consume_item(index, it)
		_item_apply(it, Vector2i(-1, -1), Vector2i(-1, -1))
		return
	if it.key == "buff_box" and pending_buff == "": # pick the buff, then the target
		item_active = index
		return _open_buff_pick()
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
	item_selected = []
	pending_buff = ""


## Generic "choose 1 of N, then continue" modal seam (issue 41). `offers` are
## Dictionaries with `label` (button text) and `value` (handed back verbatim
## to `on_chosen`) — the modal and this seam don't know what a caller does
## with the pick. `on_cancelled` is called with no args on Cancel/close; pass
## an invalid Callable if backing out needs no cleanup.
func _open_choice_pick(header: String, offers: Array, cancel_text: String,
		on_chosen: Callable, on_cancelled: Callable) -> void:
	buff_pick_open = true
	_choice_on_chosen = on_chosen
	_choice_on_cancelled = on_cancelled
	modals.show_choice_pick(header, offers, cancel_text)


func _choice_picked(value) -> void:
	buff_pick_open = false
	modals.hide_choice_pick()
	var cb := _choice_on_chosen
	_choice_on_chosen = Callable()
	_choice_on_cancelled = Callable()
	cb.call(value)


func _choice_pick_cancelled() -> void:
	buff_pick_open = false
	modals.hide_choice_pick()
	var cb := _choice_on_cancelled
	_choice_on_chosen = Callable()
	_choice_on_cancelled = Callable()
	if cb.is_valid():
		cb.call()


## Buff Box stage 0: 3 random Piece Buffs, pick one, then target a piece.
## The clock keeps ticking through both (GDD Box Pick). Numbers Station
## Sudoku (+1 choice) / Bohemian Grove Friendship Bracelet (+2) are a plain
## UI change here (issue 23), not a REGISTRY hook — additive per held copy,
## same convention artefact_hooks.gd documents for its own stacking. Riding
## the generic choice-pick seam (issue 41): the Buff Box was never special,
## just first.
func _open_buff_pick() -> void:
	var offer_size := 3 + _artefact_count("numbers-station-sudoku") \
		+ 2 * _artefact_count("bohemian-grove-friendship-bracelet")
	var pool: Array = Items.PIECE_BUFFS.duplicate()
	var offer := []
	for i in mini(offer_size, pool.size()):
		offer.append(pool.pop_at(rng.randi() % pool.size()))
	if autoplay: # bot: take one so the flow is exercised, never stall
		return _buff_chosen(offer[rng.randi() % offer.size()].key)
	var choices := []
	for b in offer:
		choices.append({"label": "%s — %s\n%s" % [b.name, b.tier, b.description],
			"value": b.key})
	_open_choice_pick("✦ Buff Box — pick a Piece Buff:", choices,
		"Cancel (keeps the item)", _buff_chosen, _buff_pick_cancelled)


## Catalogued life of a timed buff, in player turns (0 = dormant).
func _buff_turns(key: String) -> int:
	for b in Items.PIECE_BUFFS:
		if b.key == key:
			return int(b.get("turns", 0))
	return 0


func _buff_chosen(key: String) -> void:
	pending_buff = key
	gold = maxi(gold - 5 * _artefact_count("numbers-station-sudoku"), 0) # "each pick costs 5 Gold"
	var it: Dictionary = items[item_active]
	item_stage_a = Vector2i(-1, -1)
	item_targets = _item_stage_targets(it, Vector2i(-1, -1))
	_clear_selection()
	placing_id = ""
	placing_cap = false
	_refresh()


## Backing out of the buff pick leaves the item unspent, like cancelling any
## other targeting.
func _buff_pick_cancelled() -> void:
	_item_reset()
	_refresh()


## Yalta Cocktail Napkin (issue 44): "On 5-Wave Milestone: choose one — +100
## Gold / +1 Item / +15s Clock". Called from artefact_hooks.gd's on_wave_clear
## dispatch, one call per held copy that hits its own _milestone5_hit beat.
## Autoplay resolves immediately with `rng` instead of opening the modal —
## same pattern as _open_buff_pick / _open_box_pick — so the bot never
## deadlocks on a panel nobody is there to click.
func _open_yalta_pick() -> void:
	var offers := [
		{"label": "+100 Gold", "value": "gold"},
		{"label": "+1 Item", "value": "item"},
		{"label": "+15s Clock", "value": "clock"},
	]
	if autoplay:
		return _yalta_chosen(offers[rng.randi() % offers.size()].value)
	_open_choice_pick("✦ Yalta Cocktail Napkin — 5-Wave Milestone, pick one:",
		offers, "Forfeit (no refund)", _yalta_chosen, _yalta_pick_cancelled)


func _yalta_chosen(value: String) -> void:
	match value:
		"gold":
			Economy.earn(self, 100, "yalta-cocktail-napkin")
		"item":
			items.append(Items.ITEMS[rng.randi() % Items.ITEMS.size()])
		"clock":
			Economy.add_clock(self, 15000.0, "yalta-cocktail-napkin")
	_refresh()


## A 5-Wave Milestone reward is not a spend — nothing to refund on Cancel,
## just forfeit it and close (issue 44).
func _yalta_pick_cancelled() -> void:
	pass


## Targeting shim — the item targeting rules live in scripts/item_logic.gd.
## `a` = first pick for "pair" items, or (-1,-1).
func _item_stage_targets(it: Dictionary, a: Vector2i) -> Array[Vector2i]:
	return ItemLogic.stage_targets(board, defs, it.key, a, moved_this_turn)


func _item_click(tile: Vector2i) -> void:
	var it: Dictionary = items[item_active]
	if it.target == "area": # any tap re-anchors the preview; the anchor confirms
		if tile != item_stage_a:
			item_stage_a = tile
			item_targets = _item_stage_targets(it, tile)
			_refresh()
			return
	elif not item_targets.has(tile):
		return
	if it.target == "multi": # taps toggle; hud's Extract button confirms
		if item_selected.has(tile):
			item_selected.erase(tile)
		else:
			item_selected.append(tile)
		_refresh()
		return
	if it.target == "pair" and item_stage_a.x < 0:
		item_stage_a = tile
		item_targets = _item_stage_targets(it, tile)
		_refresh()
		return
	_consume_item(item_active, it)
	var a := item_stage_a
	_buff_pick = pending_buff # _item_reset clears it; the effect still needs it
	_item_reset()
	_item_apply(it, a, tile)


## Confirm a "multi" item on the current selection (>= 1 picks required).
func _item_confirm_multi() -> void:
	if item_active < 0 or item_selected.is_empty():
		return
	var it: Dictionary = items[item_active]
	_consume_item(item_active, it)
	_extract_sel = item_selected.duplicate()
	_buff_pick = pending_buff
	_item_reset()
	_item_apply(it, Vector2i(-1, -1), Vector2i(-1, -1))


func _item_apply(it: Dictionary, a: Vector2i, b: Vector2i) -> void:
	fx_at = _tile_px(b) + Vector2(tile, tile) / 2 if b.x >= 0 \
		else Vector2(hud.item_box.get_global_rect().get_center())
	Economy.charge(self, "ability_cost") # on use — a cancelled targeting costs nothing
	# Nuclear Football Menu (issue 26): Items are free of their Action cost
	# while the Clock is under 60s. Single call site, so no hook needed.
	if not (clock_ms < 60000.0 and _held("nuclear-football-menu")):
		actions_left -= it.get("action_cost", 1) # data-driven (Blitz: 0)
	_log_action("item")
	match it.key:
		"blitz": # Notion 2026-08-28 rework: costs 0 actions itself; the target's
			# NEXT move/capture this Turn is free (_move_player checks the flag).
			# If it already moved, also lift the one-move-per-piece lock so it
			# can genuinely move again — that move is the free one.
			moved_this_turn.erase(b)
			board[b].blitz_free_move = true
		"asset_recovery":
			stock.append(board[b].id) # copy a board piece into stock
		"surprise_attack":
			skip_enemy_turns += 1
		"counter_intel":
			tariffs_suppressed = true
		"extraction": # selection -> Stock at current id; board-only fields
			# stripped, any remaining piece state rides along (ADR-0002)
			for pos in _extract_sel:
				if board.has(pos) and board[pos].owner == Rules.PLAYER:
					var e: Dictionary = board[pos].duplicate()
					e.erase("owner")
					stock.append(e.id if e.size() == 1 else e)
					board.erase(pos)
		"drone_strike": # 3x3 around b; the King is unaffected (Destruction)
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var hit := b + Vector2i(dx, dy)
					if board.has(hit) and board[hit].id != "king":
						_destroy(hit, true)
		"radar_jamming": # strips the box-carrier flag AND any piece buffs
			board[b].erase("buff")
			# Antikythera Warranty Card: "Piece Buffs cannot be removed by
			# Tariffs or enemy effects" — the box-carrier flag isn't a Piece
			# Buff (buff_logic.gd header), so only BuffLogic.clear is gated.
			if not ArtefactHooks.run(self, "on_buff_removal", {"pos": b, "blocked": false}).blocked:
				BuffLogic.clear(board[b])
		"buff_box":
			_apply_buff(board[b], _buff_pick, _buff_turns(_buff_pick), b)
			_add_float(b, BuffLogic.name_of(_buff_pick), COL_MERGE)
			_buff_pick = ""
		"demote":
			# Atlantis Snow Globe / Antikythera Warranty Card: "your pieces
			# cannot be Demoted".
			if not ArtefactHooks.run(self, "on_demote", {"pos": b, "blocked": false}).blocked:
				var old_id: String = board[b].id
				board[b].id = ItemLogic.chain_base(defs, board[b].id)
				ArtefactHooks.run(self, "on_piece_demoted", {"pos": b, "old_id": old_id, "id": board[b].id})
		"promote":
			var old_id: String = board[b].id
			board[b].id = defs[board[b].id].next
			ArtefactHooks.run(self, "on_rank_up",
				{"pos": b, "old_id": old_id, "id": board[b].id, "stock_index": -1})
		"invert":
			board[b].id = "inv-" + board[b].id
		"air_strike", "sniper":
			_destroy(b, true)
		"tactical_reposition", "rapid_deployment":
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


## Bomb blast: everything within 1 square of `at`, the bomb piece included.
## Destruction, not capture (CONTEXT.md) — no score, no Captured Stock, and
## destroyed allies do not return to Stock. The King is unaffected, as with
## Drone Strike.
func _detonate(at: Vector2i) -> void:
	_add_float(at, "Boom!", COL_CAPTURE)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var pos := at + Vector2i(dx, dy)
			if board.has(pos) and board[pos].id != "king":
				_destroy(pos)


## Item destruction: piece leaves the board — no score, no captured stock.
## Fireproof Pajamas (artefact hook 24) vetoes this via _lose_player_piece's
## returned ctx.cancel — the single choke point every Item/Tariff kill
## (Drone Strike, Air Strike, Sniper, bomb detonation via _detonate, the
## jd_vance Tariff) already funnels through. `by_item` (issue 31) is true only
## from the three literal Item call sites (Drone Strike, Air Strike, Sniper)
## — $2.3 Trillion Receipt's "Enemies destroyed by Items award their Score
## and Gold value" is a DELIBERATE exception to "Destruction pays nothing"
## above, scoped exactly to the GDD text: Bomb's _detonate and the jd_vance
## Tariff are not Items, so they stay unpaid, same as ever.
func _destroy(pos: Vector2i, by_item: bool = false) -> void:
	if board[pos].owner == Rules.PLAYER:
		if _lose_player_piece(pos, "destroyed").cancel:
			return
	else:
		lost_enemy += 1
		if by_item:
			ArtefactHooks.run(self, "on_destroy", {"id": board[pos].id, "value": defs[board[pos].id].value})
	_add_pop(pos)
	board.erase(pos)


## Single choke point for a player piece leaving the board (artefact hook 19)
## — was 5 scattered `lost_player += 1` sites (enemy capture, both Reflect
## directions, both Trap directions, and _destroy above). Each now calls here
## instead, BEFORE the board entry is erased/overwritten, so on_piece_lost
## handlers can still read it (e.g. whether it carried a Piece Buff).
## `attacker_pos` is the enemy piece that did the capturing, when there is one
## (Vector2i(-1,-1) otherwise) — Tutankhamun's Death Thong debuffs it.
## Returns the dispatched ctx (artefact hook 24, was void — the other 4 call
## sites already ignored the return value): `cancel` is Fireproof Pajamas'
## veto (_destroy only), `destroy_attacker` is Hoffa's Cement Shoes' mutual-
## destruction request (the enemy-move loop only). `lost_player` and
## `wave_lost_ids` (issue 26: Jon Burrows' Fake ID / Walt's Cryonic Capsule,
## read on_wave_clear) only count when the loss isn't cancelled.
func _lose_player_piece(pos: Vector2i, reason: String, attacker_pos := Vector2i(-1, -1)) -> Dictionary:
	var ctx := ArtefactHooks.run(self, "on_piece_lost",
		{"pos": pos, "id": board[pos].id, "reason": reason, "attacker_pos": attacker_pos,
			"cancel": false, "destroy_attacker": false})
	if not ctx.cancel:
		lost_player += 1
		wave_lost_ids.append(board[pos].id)
	return ctx


## Single choke point for a piece's OWN capture ledger (issue 25, split from
## 19 — 3 artefacts read per-piece capture memory, not the run-wide
## wave/turn_capture_count Economy already tracks). `captures` is lifetime and
## rides through Stock round-trips like Piece Buffs already do (ADR-0002: the
## Stock entry is opaque, nothing strips a field it doesn't know about);
## `wave_captures` is reset every Wave in WaveLogic.queue. Both absent = 0.
## Called from Economy.capture_score (the player's own capture, `g._note_
## capture`) and _run_enemy_actions' capture branch above (the enemy's own
## capture, which never goes through capture_score since the enemy doesn't
## score) — the two "a piece's OWN capture resolves" sites issue 25 names.
func _note_capture(pos: Vector2i) -> void:
	board[pos].captures = board[pos].get("captures", 0) + 1
	board[pos].wave_captures = board[pos].get("wave_captures", 0) + 1


## Single choke point for the per-turn action log (issue 30) — the 7 sites
## that already did `turn_action_count += 1` (move, capture, blocked-capture,
## bomb, trap, place, item; merge_logic.gd's commit_merge calls this on `g`)
## now call this instead. Fires `on_action` BEFORE the log/counter update so
## a handler reading `ctx.first` (this being Action #1) can still act on the
## Turn's very first Action — same ordering first_capture_extra/Stargate
## Divination Crystal already rely on for `turn_action_count == 0` (see
## artefact_hooks.gd header). A handler granting an action here (Elvish Hard
## Hat) lands before every call site's own actions_left==0 auto-pass check,
## so it can never resurrect a turn that would otherwise already have ended —
## same shape as Stargate, covered by test_items.gd.
func _log_action(kind: String) -> void:
	ArtefactHooks.run(self, "on_action", {"kind": kind, "first": action_log.is_empty()})
	action_log.append({"kind": kind})
	turn_action_count += 1


## Single choke point for an Item leaving `items` (artefact hook 19) — was 3
## scattered `items.remove_at` sites. Fires BEFORE removal so a handler can
## veto it via ctx.cancel (Dihydrogen Monoxide Battery, Wardenclyffe AAA
## Batteries: "the Item is not consumed") — the call site only removes when
## the hook leaves ctx.cancel false. `it` is the item dict already looked up
## by the caller (items[index], before it moves).
func _consume_item(index: int, it: Dictionary) -> void:
	var ctx := ArtefactHooks.run(self, "on_item_consume",
		{"key": it.key, "tier": it.get("tier", ""), "last": items.size() == 1, "cancel": false})
	if not ctx.cancel:
		items.remove_at(index)


## Single choke point for granting a Piece Buff (artefact hook 23) — was
## BuffLogic.add called straight from game.gd's buff_box apply and half a
## dozen artefact grants in artefact_hooks.gd. Fires on_buff_apply AFTER the
## buff lands (Pied Piper's Rat Census, mRNA Firmware Update). `pos` is
## Vector2i(-1,-1) for a grant onto a piece not on the board (Stock — Holy
## Grail Coaster's stock-index branch); those handlers just no-op on pos.x<0.
## `fire_hook` is false for Pied Piper's own copy so a copy can never itself
## trigger another copy (would ping-pong between two adjacent allies).
## Debuffs riding the same buffs list (`stunned`) are NOT Piece Buffs and
## call BuffLogic.add directly — they must never reach this choke point.
func _apply_buff(piece: Dictionary, key: String, turns: int,
		pos := Vector2i(-1, -1), fire_hook := true) -> void:
	BuffLogic.add(piece, key, turns)
	if fire_hook:
		ArtefactHooks.run(self, "on_buff_apply", {"piece": piece, "key": key, "turns": turns, "pos": pos})


## Single choke point for a Piece Buff resolving off the board (artefact hook
## 23) — was 5 scattered BuffLogic.consume call sites (Reflect/Shield x2,
## Critical, Range, Multicapture) plus 2 new ones added alongside this hook
## (Bomb, Trap — previously the carrying piece was just erased with no
## explicit consume, so Cleopatra's Hairpin/Guidestone Blood Ritual never saw
## those triggers). Fires on_buff_consume AFTER removal — no artefact needs
## to veto a buff resolving, so unlike on_item_consume there is no ctx.cancel.
func _consume_buff(pos: Vector2i, key: String) -> void:
	BuffLogic.consume(board[pos], key)
	ArtefactHooks.run(self, "on_buff_consume", {"pos": pos, "key": key})


## Held copies of one artefact key — Numbers Station Sudoku / Bohemian Grove
## Friendship Bracelet's Buff Box choice-count is a plain UI change
## (_open_buff_pick), not a REGISTRY hook (issue 23), so it just counts here.
func _artefact_count(key: String) -> int:
	return artefacts.filter(func(a: Dictionary) -> bool: return a.key == key).size()


# --- box pick (GDD Game Flow — Box Pick; clock keeps ticking, input modal) ---

func _open_box_pick(only_kind := "") -> void:
	box_open = true
	Economy.charge(self, "box_cost")
	var options := _box_options(only_kind)
	if autoplay: # bot: random pick (or skip) — exercises every branch
		if rng.randf() < 0.1:
			Economy.earn(self, Tuning.BOX_SKIP_CONSOLATION)
			return _box_close()
		return _box_choose(options[rng.randi() % options.size()])
	modals.show_box(options)




func _box_options(only_kind := "") -> Array:
	var allowed_tiers: Array = []
	if only_kind == "item": # Majestic 12 Secret Handshake Diagram (18): Item
		for t in artefacts: # Boxes only, not the mixed capture-driven Box Pick
			if t.key == "majestic-12-secret-handshake-diagram":
				allowed_tiers = ["Strategic", "Decisive"]
				break
	return Box.roll_options(rng, only_kind, allowed_tiers)






func _box_choose(opt: Dictionary) -> void:
	fx_at = get_viewport_rect().size / 2.0
	match opt.kind:
		"item":
			items.append(opt.payload)
		"artefact":
			var entry: Dictionary = opt.payload.duplicate() # never mutate the
				# shared catalog Dictionary rolled by Box.roll_options — stamp a
				# per-copy acquisition wave (artefact_hooks.gd's "5-Wave
				# Milestone" cadence) and rarity (issue 29 — Illuminati Fridge
				# Magnet's "every rarity" check)
			entry.acquired_wave = wave
			entry.rarity = ArtefactHooks.rarity_of(entry.key)
			artefacts.append(entry)
		"score":
			Economy.earn(self, opt.value)
	_box_close()


func _box_close() -> void:
	box_open = false
	box_panel.visible = false
	if pass_after_box:
		pass_after_box = false
		_on_pass()
	else:
		_refresh()


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
	var recon: bool = selected.x >= 0 and board.has(selected) \
			and board[selected].owner == Rules.ENEMY
	if selected.x >= 0: # enemy recon selections tint red, own selections blue
		draw_rect(Rect2(_tile_px(selected), Vector2(tile, tile)),
			Color(COL_CAPTURE, 0.3) if recon else COL_SELECT)
	if not merge_highlights.is_empty(): # cyan ring: merges with the selection
		for pos in board:
			if board[pos].owner == Rules.PLAYER and pos != selected \
					and merge_highlights.has(board[pos].id):
				draw_arc(_tile_px(pos) + Vector2(tile, tile) / 2, tile * 0.46, 0, TAU, 24,
					COL_MERGE, 3.0)
	if item_active >= 0: # item targeting: cyan rings, stage-A pick in yellow
		for t in item_targets:
			draw_arc(_tile_px(t) + Vector2(tile, tile) / 2, tile * 0.38, 0, TAU, 24, Color(0.25, 0.8, 0.85), 3.0)
		if item_stage_a.x >= 0:
			draw_rect(Rect2(_tile_px(item_stage_a), Vector2(tile, tile)), COL_SELECT)
		for s in item_selected: # multi picks fill like the stage-A tile
			draw_rect(Rect2(_tile_px(s), Vector2(tile, tile)), COL_SELECT)
	# recon (enemy) paths draw red; the player's draw blue (palette rule)
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
		var tiles := _setup_open_tiles() if state == State.SETUP else _deploy_tiles()
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
		var tint := Color.WHITE # side colour lives in the art; _draw_piece tints mono tokens
		if pos == drag_from:
			tint.a = 0.35 # ghost follows the cursor instead
		elif state == State.PLAYER_TURN and moved_this_turn.has(pos):
			tint = Color(0.75, 0.75, 0.75) # spent this turn
		# the selected piece draws bigger, with a pulsing outline (below)
		_draw_piece(font, p, px, tint, -6.0 if pos == selected else -2.0)
		if p.get("buff", false): # box carrier: gold badge
			draw_circle(px + Vector2(tile - 9, 9), 6, Color(0.95, 0.78, 0.15))
	if selected.x >= 0 and board.has(selected): # animated pulse on the selection
		var t := Time.get_ticks_msec() / 1000.0
		var pulse := 0.5 + 0.5 * sin(t * 5.0)
		var pc := Color(COL_CAPTURE, 0.45 + 0.4 * pulse) if recon \
				else Color(0.4, 0.7, 1.0, 0.45 + 0.4 * pulse)
		draw_arc(_tile_px(selected) + half, tile * (0.46 + 0.035 * pulse), 0, TAU, 40,
			pc, 3.0 + 1.5 * pulse)
	for a in anims:
		if a.kind == "move" and board.has(a.to):
			var mp: Dictionary = board[a.to]
			_draw_piece(font, mp, a.from_px.lerp(a.to_px, ease(a.t, 0.4)), Color.WHITE)
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
		draw_texture_rect(piece_tex(board[drag_from].id, board[drag_from].owner),
			Rect2(get_global_mouse_position() - Vector2(tile, tile) * 0.5, Vector2(tile, tile)), false, Color(1, 1, 1, 0.85))
	if pool_drag_id != "" and textures.has(pool_drag_id): # stock drag ghost
		draw_texture_rect(piece_tex(pool_drag_id),
			Rect2(get_global_mouse_position() - Vector2(tile, tile) * 0.5, Vector2(tile, tile)), false, Color(1, 1, 1, 0.85))
	# Arrow Planning: drawn last so the decorative overlay always sits on top;
	# arrows persist independent of arrow_mode (toggling off just stops adding
	# more) and are cleared at turn end (scratchpad, never saved)
	for a in arrows:
		_draw_move_arrow(_tile_px(a.from) + half, _tile_px(a.to) + half, COL_ARROW)
	if arrow_from.x >= 0:
		var arrow_cur := _tile_at(get_global_mouse_position())
		if arrow_cur.x >= 0 and arrow_cur != arrow_from:
			_draw_move_arrow(_tile_px(arrow_from) + half, _tile_px(arrow_cur) + half, COL_ARROW)


## Token art for a piece; the player token unless a side is named.
func piece_tex(id: String, owner := Rules.PLAYER) -> Texture2D:
	return textures[id][owner]


## `inset` is negative on purpose: the painted tokens read better slightly
## overflowing their square than padded inside it (user call 2026-08-27).
func _draw_piece(font: Font, p: Dictionary, px: Vector2, tint: Color, inset := -2.0) -> void:
	if textures.has(p.id):
		# `tint` carries state only (spent grey, ghost alpha); a monochrome
		# token still needs the blue/red side shift multiplied in
		var col := tint
		if mono_art.has(p.id):
			col *= COL_SIDE_PLAYER if p.owner == Rules.PLAYER else COL_SIDE_ENEMY
		draw_texture_rect(piece_tex(p.id, p.owner),
			Rect2(px + Vector2(inset, inset), Vector2(tile - inset * 2, tile - inset * 2)), false, col)
	else: # ponytail: glyph fallback so a missing PNG never breaks the board
		var col := COL_PLAYER if p.owner == Rules.PLAYER else COL_ENEMY
		var glyph: String = defs[p.id].glyph
		var size := 40 if glyph.length() <= 1 else 22
		draw_string(font, px + Vector2(0, tile * 0.68), glyph, HORIZONTAL_ALIGNMENT_CENTER, tile, size, col)


func _tile_px(pos: Vector2i) -> Vector2:
	return board_px + Vector2(pos.x * tile, (Tuning.BOARD_H - 1 - pos.y) * tile)


# --- module shims (test-facing seams; logic lives in scripts/*.gd) ---

func _queue_wave(n: int) -> void:
	WaveLogic.queue(self, n)


func _to_config() -> Dictionary:
	return SaveConfig.to_config(self)


func _record_score() -> int:
	return Economy.record_score(self)


func _record_history(won: bool) -> void:
	Economy.record_history(self, won)


# --- HUD wiring (widgets live in scripts/hud.gd; signals up, calls down) ---

func _connect_hud() -> void:
	hud.pass_pressed.connect(_on_pass)
	hud.tariff_pressed.connect(_show_tariffs)
	hud.stack_pressed.connect(_on_stack_pressed)
	hud.stack_drag_started.connect(_on_stack_drag_start)
	hud.multi_confirm_pressed.connect(_item_confirm_multi)
	hud.item_pressed.connect(_use_item)
	hud.promote_pressed.connect(func(id: String, cap: bool) -> void:
		MergeLogic.do_merge(self, {"id": id, "cap": cap}, {"id": id, "cap": cap}))
	hud.return_to_stock_pressed.connect(func() -> void:
		if selected.x >= 0 and board.has(selected):
			_setup_to_stock(selected))
	hud.shop_pressed.connect(_open_shop)
	hud.drawer_changed.connect(_after_drawer_change)
	hud.arrow_toggle_pressed.connect(_on_arrow_toggle)
	hud.arrow_clear_pressed.connect(_on_arrow_clear)
	hud.menu_toggled.connect(func(open: bool) -> void:
		game_menu_open = open
		if open:
			placing_id = ""
			placing_cap = false
			_clear_selection())
	hud.settings_changed.connect(func(data: Dictionary) -> void:
		animations_on = data.get("animations_on", true)) # live — no restart needed


## Open one drawer (closing the others) or toggle it shut; "" closes all.
func _set_drawer(which: String) -> void:
	hud.set_drawer(which)
	_after_drawer_change()


func _after_drawer_change() -> void:
	if hud.drawer_open != "": # opening a drawer drops any selection (2026-07-08);
		placing_id = ""       # closing keeps it (outside-tap flow places next tap)
		placing_cap = false
		_clear_selection()
	_layout_board()
	_refresh()




func _refresh() -> void:
	merge_highlights = MergeLogic.partner_ids(self) # hud strips read it
	hud.refresh()
	queue_redraw()


# --- modal wiring (widgets live in scripts/modals.gd; signals up, calls down) ---

func _connect_modals() -> void:
	modals.choice_chosen.connect(_choice_picked)
	modals.choice_pick_cancelled.connect(_choice_pick_cancelled)
	modals.merge_confirmed.connect(func() -> void:
		var p := pending_merge
		pending_merge = []
		MergeLogic.commit_merge(self, p[0], p[1]))
	modals.merge_cancelled.connect(func() -> void:
		pending_merge = []
		_refresh())
	modals.box_chosen.connect(_box_choose)
	modals.box_skipped.connect(_on_box_skipped)
	modals.win_continue_pressed.connect(_on_win_continue)
	modals.win_end_pressed.connect(func() -> void:
		win_open = false
		_game_over(true, "Wave-%d King checkmated" % wave))
	modals.shop_buy_pressed.connect(func(index: int) -> void:
		if not Shop.buy(self, index):
			return
		if shop_stock[index].kind == "box": # the roll modal IS the grant
			if modals.shop_panel:
				modals.shop_panel.visible = false
			return _open_box_pick(shop_stock[index].key) # typed: rolls its kind
		modals.show_shop() # rebuild: fresh SOLD + affordability state
		_refresh())
	modals.shop_closed.connect(func() -> void: _refresh())
	modals.reinforce_buy_pressed.connect(func(id: String) -> void:
		stock.append(id) # reinforce is free (money-and-shop/02)
		modals.show_reinforce())
	modals.reinforce_done_pressed.connect(func() -> void:
		pending_reinforce = false
		_refresh())
	modals.preview_closed.connect(func() -> void: preview_open = false)


## Shop entry: player's turn only, never over another modal.
## Always openable, in any state — the GDD makes the Shop the one surface the
## player can reach at will. Buying is still turn-gated (Shop.can_buy), so
## outside your turn it is a readable catalog with dead Buy buttons.
func _open_shop() -> void:
	if box_open or buff_pick_open or preview_open or win_open: # one modal at a time
		return
	modals.show_shop()


## The Shop panel is up. Read from the panel itself rather than a mirrored
## flag: show_shop()/close both move it, and a second source of truth drifts.
func shop_open() -> bool:
	return modals.shop_panel != null and modals.shop_panel.visible


func _show_win_screen() -> void:
	win_open = true
	modals.show_win_screen()


func _show_preview(id: String) -> void:
	preview_open = true
	modals.show_preview(id)


## Opening the tariff overlay deselects, like menus and drawers.
func _show_tariffs() -> void:
	placing_id = ""
	placing_cap = false
	_clear_selection()
	modals.show_tariffs()


func _on_box_skipped() -> void:
	fx_at = get_viewport_rect().size / 2.0
	Economy.earn(self, Tuning.BOX_SKIP_CONSOLATION)
	_box_close()
