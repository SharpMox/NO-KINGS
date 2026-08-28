extends SceneTree
## Piece Buffs (slice 03/04): Buff Box pick + targeting, Shield, Critical,
## Slow, Smog, Aura, Reflect, Range, Trap, Taunt, Stun, Multicapture, Bomb,
## and their precedence rules (Reflect > Bomb > Trap). Split out of
## test_items.gd (issue 37).
## Run headless:  godot --headless --path game -s tests/test_items_buffs.gd

const GameScript := preload("res://scripts/game.gd")
const Rules := preload("res://scripts/rules.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")
const MergeLogic := preload("res://scripts/merge_logic.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


## Fixtures are deterministic by default (slice 36: a flaky suite makes every
## green claim unfalsifiable). Pass a "seed" in cfg, or seed_it=false, to opt
## out — only for a test that genuinely wants variance.
const DEFAULT_SEED := 1


func _boot(cfg: Dictionary, seed_it: bool = true) -> Node2D:
	if seed_it and not cfg.has("seed"):
		cfg = cfg.duplicate()
		cfg.seed = DEFAULT_SEED
	GameScript.next_config = cfg
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _item(key: String, target: String) -> Dictionary:
	return {"key": key, "name": key, "tier": "T", "target": target, "description": ""}


func _init() -> void:
	# --- Piece Buffs (slice 03): Buff Box picks a buff, then targets a piece;
	# Shield repels one capture from either side; Critical doubles one capture
	var bb := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 3],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	bb.actions_left = 5
	bb.items.append(_item("buff_box", "tile"))
	bb._use_item(0)
	check(bb.buff_pick_open or bb.pending_buff != "", "Buff Box opens the buff sub-pick")
	bb._buff_pick_cancelled()
	check(bb.items.size() == 1 and bb.pending_buff == "",
		"cancelling the sub-pick leaves the item unspent")
	bb._use_item(0)
	bb._buff_chosen("shield")
	check(bb.item_targets.has(Vector2i(2, 2)) and bb.item_targets.has(Vector2i(3, 3)),
		"buff targeting offers both allies and enemies")
	bb._item_click(Vector2i(2, 2)) # shield the queen
	check(BuffLogic.has(bb.board[Vector2i(2, 2)], "shield"), "the buff lands on the target")
	check(bb.items.is_empty(), "the Buff Box is spent")

	# the AI attacking a shielded piece is repelled; the shield is consumed.
	# The rook must share a file with the queen or it simply never attacks —
	# and then both assertions below would pass for the wrong reason.
	bb.board.erase(Vector2i(3, 3))
	bb.board[Vector2i(2, 5)] = {"id": "rook", "owner": 1}
	check(Rules.moves_for(bb.board, Vector2i(2, 5), bb.defs).has(Vector2i(2, 2)),
		"the enemy rook really can reach the shielded queen")
	await bb._run_enemy_actions()
	check(bb.board.has(Vector2i(2, 2)) and bb.board[Vector2i(2, 2)].id == "queen",
		"Shield repels the enemy capture — the piece survives")
	check(not BuffLogic.has(bb.board[Vector2i(2, 2)], "shield"),
		"Shield is consumed by the attempt it blocks")
	bb.queue_free()
	await process_frame

	# player side: shield blocks one capture, then the next one lands
	var sh := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	sh.actions_left = 5
	BuffLogic.add(sh.board[Vector2i(2, 5)], "shield")
	sh._move_player(Vector2i(2, 2), Vector2i(2, 5))
	check(sh.board.has(Vector2i(2, 2)) and sh.board[Vector2i(2, 5)].id == "rook",
		"a repelled attacker stays on its starting tile and captures nothing")
	check(not BuffLogic.has(sh.board[Vector2i(2, 5)], "shield"), "the shield is spent")
	sh.moved_this_turn.clear()
	sh._move_player(Vector2i(2, 2), Vector2i(2, 5))
	check(sh.board[Vector2i(2, 5)].id == "queen", "the next attempt captures normally")
	sh.queue_free()
	await process_frame

	# Critical doubles exactly one capture, then is gone
	var cr := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5],
		["rook", 1, 2, 8], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	cr.actions_left = 5
	BuffLogic.add(cr.board[Vector2i(2, 2)], "critical")
	var before: int = cr.score
	cr._move_player(Vector2i(2, 2), Vector2i(2, 5))
	var doubled: int = cr.score - before
	check(not BuffLogic.has(cr.board[Vector2i(2, 5)], "critical"), "Critical is consumed")
	cr.moved_this_turn.clear()
	before = cr.score
	cr._move_player(Vector2i(2, 5), Vector2i(2, 8))
	check(doubled == 2 * (cr.score - before),
		"Critical doubles one capture's score, the next is normal")
	cr.queue_free()
	await process_frame

	# Radar Jamming strips piece buffs, as its description promises
	var rj := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	rj.actions_left = 5
	BuffLogic.add(rj.board[Vector2i(2, 2)], "shield")
	rj.items.append(_item("radar_jamming", "tile"))
	rj._use_item(0)
	rj._item_click(Vector2i(2, 2))
	check(BuffLogic.of(rj.board[Vector2i(2, 2)]).is_empty(),
		"Radar Jamming strips piece buffs")
	rj.queue_free()
	await process_frame

	# --- slice 04, timed model: "reduced movement range" = moves and captures
	# like a Pawn (user ruling 2026-08-28), and timed buffs age one player turn
	# an enemy sits on the diagonal: capture-mode destinations only list squares
	# that actually hold an enemy (Rules._add_dest)
	var sl := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 3],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	var full: int = Rules.moves_for(sl.board, Vector2i(2, 2), sl.defs).size()
	BuffLogic.add(sl.board[Vector2i(2, 2)], "slow", 1)
	var slowed: Array = Rules.moves_for(sl.board, Vector2i(2, 2), sl.defs)
	check(slowed.size() < full, "Slow cuts the queen down from her full move set")
	check(slowed.has(Vector2i(2, 3)) and not slowed.has(Vector2i(2, 5)),
		"a slowed piece steps one square forward, like a Pawn")
	check(Rules.moves_for(sl.board, Vector2i(2, 2), sl.defs, "capture").has(Vector2i(3, 3)),
		"a slowed piece captures one square diagonally forward, like a Pawn")
	sl._begin_player_turn()
	check(Rules.moves_for(sl.board, Vector2i(2, 2), sl.defs).size() == full,
		"Slow expires after one player turn and the queen is whole again")
	sl.queue_free()
	await process_frame

	# Smog projects the same Pawn downgrade onto ADJACENT ENEMIES only
	var sm := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 3, 3],
		["rook", 1, 7, 7], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	var far_moves: int = Rules.moves_for(sm.board, Vector2i(7, 7), sm.defs).size()
	BuffLogic.add(sm.board[Vector2i(2, 2)], "smog", 2)
	check(Rules.moves_for(sm.board, Vector2i(3, 3), sm.defs).size() < far_moves,
		"Smog downgrades the adjacent enemy")
	check(Rules.moves_for(sm.board, Vector2i(7, 7), sm.defs).size() == far_moves,
		"a distant enemy is untouched")
	check(Rules.moves_for(sm.board, Vector2i(2, 2), sm.defs).size() > 4,
		"Smog does not debuff its own carrier")
	sm._begin_player_turn()
	check(Rules.moves_for(sm.board, Vector2i(3, 3), sm.defs).size() < far_moves,
		"Smog still runs on its second player turn")
	sm._begin_player_turn()
	check(not BuffLogic.has(sm.board[Vector2i(2, 2)], "smog"),
		"Smog expires after two player turns")
	check(Rules.moves_for(sm.board, Vector2i(3, 3), sm.defs).size() > 4,
		"the formerly smogged enemy moves freely again")
	sm.queue_free()
	await process_frame

	# Aura doubles captures for ADJACENT ALLIES, not for its own carrier
	var au := _boot({"board": [["queen", 0, 2, 2], ["knight", 0, 3, 3],
		["rook", 1, 3, 5], ["rook", 1, 2, 5], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	au.actions_left = 9
	check(BuffLogic.capture_multiplier(au.board, Vector2i(3, 3)) == 1, "no aura, no bonus")
	BuffLogic.add(au.board[Vector2i(2, 2)], "aura", 2)
	check(BuffLogic.capture_multiplier(au.board, Vector2i(3, 3)) == 2,
		"an ally beside the Aura carrier scores double")
	check(BuffLogic.capture_multiplier(au.board, Vector2i(2, 2)) == 1,
		"the Aura carrier itself gets no bonus")
	au.queue_free()
	await process_frame

	# Reflect: the attempt is stopped AND the attacker dies on its own tile
	var rf := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	rf.actions_left = 5
	BuffLogic.add(rf.board[Vector2i(2, 5)], "reflect")
	rf._move_player(Vector2i(2, 2), Vector2i(2, 5))
	check(not rf.board.has(Vector2i(2, 5)), "the reflecting piece vacates its tile")
	check(rf.board.has(Vector2i(2, 2)) and rf.board[Vector2i(2, 2)].id == "rook"
			and rf.board[Vector2i(2, 2)].owner == 1,
		"Reflect kills the attacker and takes its tile")
	check(not BuffLogic.has(rf.board[Vector2i(2, 2)], "reflect"), "Reflect is consumed")
	rf.queue_free()
	await process_frame

	# --- Range (ruled 2026-08-28): every enemy this piece can already capture
	# also exposes the enemies standing beside it, capture-only
	var rg := _boot({"board": [["rook", 0, 2, 2], ["rook", 1, 2, 5],
		["pawn", 1, 3, 5], ["pawn", 1, 5, 9], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	rg.actions_left = 5
	var plain: Array = Rules.moves_for(rg.board, Vector2i(2, 2), rg.defs)
	check(plain.has(Vector2i(2, 5)) and not plain.has(Vector2i(3, 5)),
		"without Range the rook takes its blocker but nothing beside it")
	BuffLogic.add(rg.board[Vector2i(2, 2)], "range")
	var reach: Array = Rules.moves_for(rg.board, Vector2i(2, 2), rg.defs)
	check(reach.has(Vector2i(3, 5)), "Range reaches the enemy beside a capturable enemy")
	check(not reach.has(Vector2i(5, 9)), "a distant enemy stays out of reach")
	check(not reach.has(Vector2i(3, 4)),
		"Range is capture-only — it does not open empty squares")
	rg._move_player(Vector2i(2, 2), Vector2i(3, 5)) # take past the blocker
	check(rg.board.has(Vector2i(3, 5)) and rg.board[Vector2i(3, 5)].owner == 0,
		"the piece captures through the halo")
	check(not BuffLogic.has(rg.board[Vector2i(3, 5)], "range"),
		"Range is consumed by the capture")
	rg.queue_free()
	await process_frame

	# --- Trap: the attacker dies with its victim, on either side
	var tr := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	tr.actions_left = 5
	BuffLogic.add(tr.board[Vector2i(2, 5)], "trap")
	tr._move_player(Vector2i(2, 2), Vector2i(2, 5))
	check(not tr.board.has(Vector2i(2, 2)) and not tr.board.has(Vector2i(2, 5)),
		"Trap kills both the victim and the attacker")
	check(tr.captured.has("rook"), "the trapped victim still enters Captured Stock")
	tr.queue_free()
	await process_frame

	# --- Taunt forces the AI's capture choice away from the juicier target
	var tt := _boot({"board": [["queen", 0, 2, 4], ["pawn", 0, 2, 6],
		["rook", 1, 2, 8], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	BuffLogic.add(tt.board[Vector2i(2, 6)], "taunt") # the cheap pawn taunts
	var act: Dictionary = Rules.ai_action(tt.board, tt.defs)
	check(act.get("to") == Vector2i(2, 6),
		"Taunt overrides the highest-value-target heuristic")
	tt.queue_free()
	await process_frame

	# --- Stun: the enemy that takes a stunning piece sits out one enemy turn
	var st := _boot({"board": [["pawn", 0, 2, 6], ["rook", 1, 2, 8],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	BuffLogic.add(st.board[Vector2i(2, 6)], "stun")
	await st._run_enemy_actions()
	check(st.board.has(Vector2i(2, 6)) and st.board[Vector2i(2, 6)].owner == 1,
		"the enemy captures the stunning piece")
	check(BuffLogic.has(st.board[Vector2i(2, 6)], "stunned"), "the attacker is stunned")
	# Stun costs the attacker 2 of its OWN turns (user call 2026-08-28), which
	# is a different cadence from the player-turn-timed buffs
	# Assert on behaviour, not on the buff: the tick happens at the end of the
	# side's own turn, so checking presence after the call sees it already aged.
	var frozen: Vector2i = Vector2i(2, 6)
	await st._run_enemy_actions()
	check(st.board.has(frozen), "stun turn 1: the piece did not move")
	await st._run_enemy_actions()
	check(st.board.has(frozen), "stun turn 2: still frozen")
	await st._run_enemy_actions()
	check(not st.board.has(frozen),
		"it moves again on the third turn — exactly 2 enemy turns lost")
	st.queue_free()
	await process_frame

	# ...and the same cuts the player's way: taking a stunning enemy stuns YOUR
	# piece, for 2 player turns, and it cannot be picked up meanwhile
	var sp := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	sp.actions_left = 9
	BuffLogic.add(sp.board[Vector2i(2, 5)], "stun")
	sp._move_player(Vector2i(2, 2), Vector2i(2, 5))
	check(BuffLogic.has(sp.board[Vector2i(2, 5)], "stunned"),
		"capturing a stunning enemy stuns your own attacker")
	sp._on_tile_clicked(Vector2i(2, 5))
	check(sp.selected == Vector2i(-1, -1), "a stunned piece cannot be picked up")
	sp.queue_free()
	await process_frame

	# --- Multicapture (ruled 2026-08-28): also takes one enemy beside the
	# piece just captured — the most valuable neighbour
	var mc := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5],
		["rook", 1, 3, 5], ["pawn", 1, 3, 6], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	mc.actions_left = 5
	BuffLogic.add(mc.board[Vector2i(2, 2)], "multicapture")
	mc._move_player(Vector2i(2, 2), Vector2i(2, 5))
	check(not mc.board.has(Vector2i(3, 5)),
		"Multicapture also takes the rook beside the captured pawn")
	check(mc.board.has(Vector2i(3, 6)), "only ONE extra piece is taken")
	check(mc.captured.has("rook") and mc.captured.has("pawn"),
		"both captures reach Captured Stock")
	check(not BuffLogic.has(mc.board[Vector2i(2, 5)], "multicapture"),
		"Multicapture is consumed")
	mc.queue_free()
	await process_frame

	# --- Bomb: on either side of a capture, everything within 1 square dies.
	# Destruction, not capture — no score, nothing to Captured Stock, and the
	# King is unaffected. Precedence ruled 2026-08-28: Reflect > Bomb > Trap.
	var bm := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5],
		["pawn", 1, 3, 5], ["pawn", 0, 1, 4], ["king", 1, 1, 5],
		["pawn", 1, 6, 9], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	bm.actions_left = 5
	BuffLogic.add(bm.board[Vector2i(2, 5)], "bomb")
	var score_before: int = bm.score
	var caught: int = bm.captured.size()
	bm._move_player(Vector2i(2, 2), Vector2i(2, 5))
	check(not bm.board.has(Vector2i(2, 5)), "the bomb piece is gone")
	check(not bm.board.has(Vector2i(2, 2)), "the attacker is caught in the blast")
	check(not bm.board.has(Vector2i(3, 5)) and not bm.board.has(Vector2i(1, 4)),
		"the blast takes enemies AND allies within 1 square")
	check(bm.board.has(Vector2i(1, 5)), "the King is unaffected by the blast")
	check(bm.board.has(Vector2i(6, 9)), "pieces outside the blast survive")
	check(bm.captured.size() == caught + 1,
		"only the captured piece reaches Captured Stock — the blast is destruction")
	check(bm.score > score_before, "the capture itself still scores")
	bm.queue_free()
	await process_frame

	# Reflect outranks Bomb: the capture never lands, so nothing detonates
	var rb := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5],
		["pawn", 1, 3, 5], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	rb.actions_left = 5
	BuffLogic.add(rb.board[Vector2i(2, 5)], "bomb")
	BuffLogic.add(rb.board[Vector2i(2, 5)], "reflect")
	rb._move_player(Vector2i(2, 2), Vector2i(2, 5))
	check(rb.board.has(Vector2i(3, 5)),
		"Reflect outranks Bomb — the capture never lands, nothing detonates")
	rb.queue_free()
	await process_frame

	# Bomb outranks Trap: the blast resolves, Trap adds nothing
	var bt := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5],
		["pawn", 1, 3, 5], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	bt.actions_left = 5
	BuffLogic.add(bt.board[Vector2i(2, 5)], "bomb")
	BuffLogic.add(bt.board[Vector2i(2, 5)], "trap")
	bt._move_player(Vector2i(2, 2), Vector2i(2, 5))
	check(not bt.board.has(Vector2i(3, 5)),
		"Bomb outranks Trap — the area blast still resolves")
	bt.queue_free()
	await process_frame

	# --- issue 42: peak-rank stamp ("Demoted" ruled option (b) — currently
	# below the piece's own historical PEAK rank, clearing on re-promotion,
	# not "was ever demoted"). `peak_ranked` rides the piece Dictionary next
	# to `buffs` (ADR-0002); ArtefactHooks._demoted() is the read side. Dark
	# Market Light Bulb (the only consumer today) has its own coverage in
	# test_items_artefacts_2.gd, alongside the rest of the "Ranked" cluster.
	var pr := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 0, 3, 2], ["rook", 1, 7, 10]],
		"wave": 4, "items": ["demote", "promote"]})
	await process_frame
	pr.actions_left = 10 # merge, demote, promote in one sequence
	MergeLogic.commit_merge(pr, Vector2i(2, 2), Vector2i(3, 2)) # Rank Up: pawn+pawn -> sergeant
	var pr_ranked: Dictionary = pr.board[Vector2i(3, 2)]
	check(pr_ranked.id == "sergeant" and pr_ranked.get("peak_ranked", false),
		"peak-rank stamp: a Rank Up sets peak_ranked")
	check(not ArtefactHooks._demoted(pr.defs, pr_ranked), "a freshly Ranked piece is not Demoted")

	pr._use_item(0) # "demote"
	pr._item_click(Vector2i(3, 2)) # sergeant -> pawn (chain_base)
	var pr_demoted: Dictionary = pr.board[Vector2i(3, 2)]
	check(pr_demoted.id == "pawn" and pr_demoted.get("peak_ranked", false),
		"Demote drops the id to base but the peak-rank stamp survives")
	check(ArtefactHooks._demoted(pr.defs, pr_demoted), "below its own peak rank: Demoted")

	pr._use_item(0) # "promote" — "demote" was consumed above, shifting it to index 0
	pr._item_click(Vector2i(3, 2)) # pawn -> sergeant again: re-Ranked
	var pr_reranked: Dictionary = pr.board[Vector2i(3, 2)]
	check(not ArtefactHooks._demoted(pr.defs, pr_reranked),
		"re-promoting past the old peak clears Demoted (ruled option b, not \"was ever demoted\")")
	pr.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL BUFF CHECKS OK")
	quit(1 if fails > 0 else 0)
