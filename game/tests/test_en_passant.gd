extends SceneTree
## NO-232: en passant, live-node lifecycle tests — the turn-scoped record
## (game.gd), the empty-square capture (teleport-the-victim trick shared by
## _move_player/_run_enemy_actions), and the save round-trip. The pure
## geometry/eligibility/AI-selection tests live in test_rules.gd (mirroring
## NO-224's own split between pure Rules coverage and any live-node need).
## Run headless:  godot --headless --path game -s tests/test_en_passant.gd

const GameScript := preload("res://scripts/game.gd")
const Rules := preload("res://scripts/rules.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


## Fixtures are deterministic by default (slice 36: a flaky suite makes every
## green claim unfalsifiable).
const DEFAULT_SEED := 1
## Cap on any single wait-for-turn. Generous — a real turn resolves in well
## under a second even on the slow Intel box — so hitting it means the turn
## is never coming, not that the machine is loaded.
const TURN_WAIT_CAP_MS := 10000


func _boot(cfg: Dictionary, seed_it: bool = true) -> Node2D:
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	if seed_it and not cfg.has("seed"):
		cfg = cfg.duplicate()
		cfg.seed = DEFAULT_SEED
	GameScript.next_config = cfg
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


## BOUNDED. An unbounded version of this hung the whole suite on its first run
## (exit 143, killed by run_all.sh's outer timeout) and reported nothing about
## where it stalled. A turn that never arrives is a real failure — a side with
## no legal action, or a game-over state — so cap it and say so, rather than
## spinning until something external kills the process.
func _wait_for_player_turn(g: Node2D, label: String = "") -> void:
	var t0 := Time.get_ticks_msec()
	while g.state != GameScript.State.PLAYER_TURN \
			and Time.get_ticks_msec() - t0 < TURN_WAIT_CAP_MS:
		await create_timer(0.1).timeout
	check(g.state == GameScript.State.PLAYER_TURN,
		"player turn arrives%s" % ("" if label == "" else " (" + label + ")") \
			+ " — state=%d after %dms" % [g.state, Time.get_ticks_msec() - t0])


func _init() -> void:
	# Watchdog. This suite hung on its first run and only run_all.sh's outer
	# timeout stopped it (exit 143), which reports nothing about where. Every
	# other live-node probe in this directory carries one for exactly that
	# reason; this file was added to run_all.sh without it. Kept under
	# run_all.sh's own TIMEOUT so the runner's log survives the quit.
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: test_en_passant still running after 120s — force quit")
		quit(1))
	# --- the offer is available throughout the opponent's whole next turn,
	# and the captured pawn leaves the board and lands wherever an ordinary
	# capture sends it (Captured Stock + Score) — same path, not a second one ---
	var a: Node2D = _boot({"board": [["pawn", 0, 2, 2], ["pawn", 1, 3, 4]], "gold": 100})
	await process_frame
	await process_frame
	a._on_pass() # player turn 1: nothing done, so the enemy's ONLY move is judged on its own
	await _wait_for_player_turn(a)
	check(not a.board.has(Vector2i(3, 4)) and a.board.has(Vector2i(3, 2)) \
			and a.board[Vector2i(3, 2)].owner == Rules.ENEMY,
		"sanity: the enemy pawn double-stepped, exactly as NO-224's own sandbox relies on")
	check(a.enemy_double_steps.size() == 1 and a.enemy_double_steps[0].pawn == Vector2i(3, 2) \
			and a.enemy_double_steps[0].skip == Vector2i(3, 3) and a.enemy_double_steps[0].id == "pawn",
		"the double-step is recorded and offered for the player's whole turn")
	var score0: int = a.score
	var captured0: int = a.captured.size()
	a._move_player(Vector2i(2, 2), Vector2i(3, 3)) # capture en passant onto the skip square
	check(not a.board.has(Vector2i(3, 2)), "the captured pawn actually left the board")
	check(a.board.has(Vector2i(3, 3)) and a.board[Vector2i(3, 3)].owner == Rules.PLAYER,
		"the attacker lands on the empty skip square")
	check(a.captured.size() == captured0 + 1 and a.captured.back() == "pawn",
		"the captured pawn lands in Captured Stock — the ordinary capture path, not a divergent one")
	check(a.score > score0, "the capture pays out, same as an ordinary capture")
	a.queue_free()
	await process_frame

	# --- expiry: once the offering side's window (the opponent's next turn)
	# ends, the SAME destination is no longer offered ---
	var b: Node2D = _boot({"board": [["pawn", 0, 2, 2], ["pawn", 1, 3, 4]], "gold": 100})
	await process_frame
	await process_frame
	b._on_pass() # enemy double-steps
	await _wait_for_player_turn(b)
	check(b.enemy_double_steps.size() == 1, "available at the start of the player's turn")
	check(Rules.moves_for(b.board, Vector2i(2, 2), b.defs, "", b.enemy_double_steps).has(Vector2i(3, 3)),
		"...and offered as a legal capture")
	b._on_pass() # the player lets the window close without using it
	await _wait_for_player_turn(b)
	check(b.enemy_double_steps.is_empty(),
		"the record is gone: the enemy's only pawn already moved, so it has nothing new to offer")
	check(not Rules.moves_for(b.board, Vector2i(2, 2), b.defs, "", b.enemy_double_steps).has(Vector2i(3, 3)),
		"expired: the destination is no longer offered once that turn has ended")
	b.queue_free()
	await process_frame

	# --- invalidated when the double-stepped pawn moves again within its own
	# turn (actions_per_turn baseline is 2 — NO-232's own concern #5) ---
	var c: Node2D = _boot({"board": [["pawn", 0, 2, 2], ["pawn", 1, 1, 4]], "gold": 100})
	await process_frame
	await process_frame
	c._move_player(Vector2i(2, 2), Vector2i(2, 4)) # double-step, action 1 of 2
	check(c.player_double_steps.size() == 1 and c.player_double_steps[0].pawn == Vector2i(2, 4),
		"the double-step is recorded the instant it commits")
	c._move_player(Vector2i(2, 4), Vector2i(2, 5)) # the SAME pawn moves again, action 2 of 2
	check(Rules.en_passant_victim(c.board, Vector2i(1, 4), Vector2i(2, 3), c.player_double_steps, c.defs) \
			== Vector2i(-1, -1),
		"invalidated: the pawn is no longer standing where the double-step left it")
	await _wait_for_player_turn(c)
	c.queue_free()
	await process_frame

	# --- the enemy AI performing one (rules.gd generates it for both sides;
	# this exercises it through the real turn machinery, not just ai_action
	# in isolation — see test_rules.gd for that) ---
	# The spare player pawn at (7,0) is load-bearing: without it the enemy's en
	# passant takes the player's ONLY piece, the game ends, and the wait below
	# is for a PLAYER_TURN that can never arrive. That is what hung this suite
	# on its first run — en passant SUCCEEDING, not failing. (7,0) is far from
	# the enemy's single pawn at (1,4) and unreachable by it, so it cannot
	# out-compete the capture the AI is meant to choose here.
	var d: Node2D = _boot({"board": [["pawn", 0, 2, 2], ["pawn", 0, 7, 0], ["pawn", 1, 1, 4]],
		"gold": 100})
	await process_frame
	await process_frame
	d._move_player(Vector2i(2, 2), Vector2i(2, 4)) # double-step, action 1 of 2 — leaves it offered
	d._on_pass() # end the turn without spending the 2nd action
	await _wait_for_player_turn(d)
	check(not d.board.has(Vector2i(2, 4)), "the enemy AI actually captured the double-stepped pawn")
	check(d.board.has(Vector2i(2, 3)) and d.board[Vector2i(2, 3)].owner == Rules.ENEMY,
		"...and landed on the skip square, exactly like the player's own capture above")
	d.queue_free()
	await process_frame

	# --- save round-trip: additive field, JSON-safe Vector2i encoding ---
	var e: Node2D = _boot({"board": [["pawn", 0, 2, 2], ["pawn", 1, 3, 4]], "gold": 100})
	await process_frame
	await process_frame
	e._on_pass()
	await _wait_for_player_turn(e)
	check(e.enemy_double_steps.size() == 1, "sanity: an offer exists before saving")
	var saved: Dictionary = e._to_config()
	e.queue_free()
	await process_frame
	# round-trip through JSON, exactly as the real save file does (test_save.gd's own idiom)
	var resumed: Node2D = _boot(JSON.parse_string(JSON.stringify(saved)))
	await process_frame
	check(resumed.enemy_double_steps.size() == 1 and resumed.enemy_double_steps[0].pawn == Vector2i(3, 2) \
			and resumed.enemy_double_steps[0].skip == Vector2i(3, 3) and resumed.enemy_double_steps[0].id == "pawn",
		"a resumed save round-trips the en passant offer (additive field, no migration)")
	check(Rules.moves_for(resumed.board, Vector2i(2, 2), resumed.defs, "", resumed.enemy_double_steps).has(Vector2i(3, 3)),
		"...and the resumed game actually honours it as a legal capture")
	resumed.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL TESTS PASSED")
	quit(1 if fails > 0 else 0)
