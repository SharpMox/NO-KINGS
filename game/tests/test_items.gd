extends SceneTree
## Item behavior + review-regression coverage (2026-07-03 code review):
## merge-selection survives item removal, ability tariff charges on USE (not
## on targeting), Long-Range tariff covers every riding piece.
## Run headless:  godot --headless --path game -s tests/test_items.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Economy := preload("res://scripts/economy.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const MergeLogic := preload("res://scripts/merge_logic.gd")
const Rules := preload("res://scripts/rules.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _boot(cfg: Dictionary) -> Node2D:
	GameScript.next_config = cfg
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _item(key: String, target: String) -> Dictionary:
	return {"key": key, "name": key, "tier": "T", "target": target, "description": ""}


func _init() -> void:
	# --- review bug 1 (reworked for buttonless merging): removing a selected
	# piece with an item must drop the selection, not leave a stale board ref
	var a := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 0, 3, 2], ["rook", 1, 7, 10]],
		"wave": 3})
	await process_frame
	a._on_tile_clicked(Vector2i(2, 2)) # select the board pawn (partner glows)
	check(a.merge_highlights.has("pawn"), "selection highlights its merge partner")
	a.items.append(_item("asset_recovery", "tile"))
	a._use_item(0)
	a._item_click(Vector2i(2, 2)) # duplicate the selected pawn into stock
	check(a.selected == Vector2i(-1, -1), "item use clears the selection")
	a._refresh() # would error on a stale board ref
	check(a.stock.has("pawn") and a.board.has(Vector2i(2, 2)),
		"asset recovery copies the board piece into stock")
	# tap-merge: select the remaining board pawn, tap the stock pawn's partner…
	# the pool side is covered in the click probe; here merge the pool pair back
	check(a.merge_highlights.is_empty(), "no selection, no merge highlights")
	a.queue_free()
	await process_frame

	# --- review bug 4: ability tariff charges when the item is USED, once —
	# cancelling a targeted item costs nothing
	var b := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "score": 500, "tariffs": ["ability_cost"]})
	await process_frame
	b.gold = 500 # tariffs charge gold now (money-and-shop/02)
	b.items.append(_item("demote", "tile"))
	b._use_item(0) # start targeting
	b._use_item(0) # tap again: cancel
	check(b.gold == 500, "cancelled item charges no ability tariff")
	b._use_item(0)
	b._item_click(Vector2i(2, 2)) # complete the use
	check(b.gold == 500 - Tuning.TARIFF_ACTION_COST,
		"completed item charges the ability tariff once")
	b.queue_free()
	await process_frame

	# --- review bug 3: Long-Range tariff covers every rider, not just
	# bishop/rook; leapers stay exempt
	var c := _boot({"board": [["queen", 0, 2, 2], ["knight", 0, 5, 2], ["rook", 1, 7, 10]],
		"wave": 3, "score": 500, "tariffs": ["long_range_cost"]})
	await process_frame
	c.gold = 500
	c._move_player(Vector2i(2, 2), Vector2i(2, 5)) # queen rides 3 squares
	check(c.gold == 500 - 3 * Tuning.TARIFF_LR_PER_SQUARE,
		"riding 3 squares charges 3x the long-range tariff")
	var gold_after: int = c.gold
	c._move_player(Vector2i(5, 2), Vector2i(6, 4)) # knight leap
	check(c.gold == gold_after, "leaps stay exempt from the long-range tariff")
	c.queue_free()
	await process_frame

	# --- promote: advances a piece with a next tier, no-op target otherwise
	var d := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	d.items.append(_item("promote", "tile"))
	d._use_item(0)
	d._item_click(Vector2i(2, 2))
	check(d.board[Vector2i(2, 2)].id == "sergeant", "promote advances a pawn to its next tier")
	d.queue_free()
	await process_frame

	# --- invert: swaps a piece for its inv- counterpart when one is defined
	var e := _boot({"board": [["sergeant", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	e.items.append(_item("invert", "tile"))
	e._use_item(0)
	e._item_click(Vector2i(2, 2))
	check(e.board[Vector2i(2, 2)].id == "inv-sergeant", "invert swaps a piece for its inv- counterpart")
	e.queue_free()
	await process_frame

	# --- rapid deployment: ally piece -> a Deploy tile only (zone rows or
	# tiles touching an ally — Rules.placement_tiles; Notion KEEP desc)
	var f := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	f.items.append(_item("rapid_deployment", "pair"))
	f._use_item(0)
	f._item_click(Vector2i(2, 2)) # stage A: pick the queen
	check(not f.item_targets.has(Vector2i(6, 9)),
		"a far empty tile is not a deploy tile")
	check(f.item_targets.has(Vector2i(0, 0)), "zone tiles are deploy tiles")
	check(f.item_targets.has(Vector2i(3, 3)),
		"tiles touching an ally are deploy tiles")
	f._item_click(Vector2i(0, 0))
	check(f.board.has(Vector2i(0, 0)) and not f.board.has(Vector2i(2, 2)),
		"rapid deployment moves the piece")
	f.queue_free()
	await process_frame

	# --- radar jamming: strips the buff from a buffed piece; only buffed
	# pieces are valid targets
	var h := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 5, "buff"],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	h.items.append(_item("radar_jamming", "tile"))
	h._use_item(0)
	check(h.item_targets.size() == 1 and h.item_targets.has(Vector2i(3, 5)),
		"radar jamming targets only buffed pieces")
	h._item_click(Vector2i(3, 5))
	check(not h.board[Vector2i(3, 5)].get("buff", false),
		"radar jamming strips the buff")
	h.queue_free()
	await process_frame

	# --- counter-intel: suppresses action tariffs for the rest of the wave
	var ci := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "tariffs": ["move_cost"]})
	await process_frame
	ci.gold = 500
	ci.items.append(_item("counter_intel", ""))
	ci._use_item(0)
	ci._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(ci.gold == 500, "counter-intel suppresses the move tariff")
	ci.queue_free()
	await process_frame

	# --- counter-intel: persistent tariffs pause too; the next wave's spawn
	# ends the suppression (CONTEXT.md: Tariff suppression)
	var cj := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "tariffs": ["move_cost", "inflation"]})
	await process_frame
	cj.gold = 500
	cj.items.append(_item("counter_intel", ""))
	cj._use_item(0)
	Economy.earn(cj, 10)
	check(cj.gold == 510, "suppressed inflation taxes no gains")
	cj._refresh()
	check(cj.hud.tariff_button.text.ends_with("·off"), "HUD marks tariffs suppressed")
	WaveLogic.spawn(cj, 4)
	Economy.earn(cj, 10)
	check(cj.gold == 519, "next wave spawn ends the suppression (inflation resumes)")
	cj._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(cj.gold == 519 - Tuning.TARIFF_ACTION_COST,
		"next wave spawn ends the suppression (move tariff resumes)")
	cj.queue_free()
	await process_frame

	# --- drone strike: 3x3 destruction around the confirmed anchor; the King
	# survives; destruction is not capture (CONTEXT.md: Destruction)
	var ds := _boot({"board": [["queen", 0, 0, 1], ["pawn", 1, 3, 5], ["bishop", 1, 2, 4],
		["pawn", 0, 4, 6], ["king", 1, 3, 4], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["greed", "score"], "score": 100})
	await process_frame
	ds.gold = 100
	ds.items.append(_item("drone_strike", "area"))
	ds._use_item(0)
	ds._item_click(Vector2i(3, 5)) # anchor: preview only, not spent yet
	check(not ds.items.is_empty(), "area anchor tap previews without spending")
	ds._item_click(Vector2i(3, 5)) # confirm
	check(not ds.board.has(Vector2i(3, 5)) and not ds.board.has(Vector2i(2, 4))
		and not ds.board.has(Vector2i(4, 6)), "drone strike clears the 3x3 (ally included)")
	check(ds.board.has(Vector2i(3, 4)), "the King survives a drone strike")
	check(ds.board.has(Vector2i(7, 10)), "pieces outside the 3x3 survive")
	check(ds.score == 100 and ds.gold == 100, "destruction pays no score, gold, or artefact procs")
	ds.queue_free()
	await process_frame

	# --- drone strike: corner anchors hang off the board; re-anchor + cancel
	var de := _boot({"board": [["queen", 0, 5, 5], ["pawn", 1, 0, 0], ["pawn", 1, 1, 1],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	de.items.append(_item("drone_strike", "area"))
	de._use_item(0)
	de._item_click(Vector2i(0, 0))
	check(de.item_targets.size() == 4, "corner preview covers only the on-board 2x2")
	de._item_click(Vector2i(5, 5)) # far tap re-anchors instead of confirming
	check(de.items.size() == 1 and de.item_targets.has(Vector2i(4, 4)),
		"far tap re-anchors the preview")
	de._use_item(0) # tap the armed item: cancel, unspent
	check(de.items.size() == 1 and de.item_active == -1, "area cancel leaves the item unspent")
	de._use_item(0)
	de._item_click(Vector2i(0, 0))
	de._item_click(Vector2i(0, 0)) # confirm at the corner
	check(not de.board.has(Vector2i(0, 0)) and not de.board.has(Vector2i(1, 1)),
		"corner strike destroys the on-board part")
	de.queue_free()
	await process_frame

	# --- extraction: multi-select own pieces back to Stock at current identity
	var ex := _boot({"board": [["dragon-king", 0, 2, 2], ["pawn", 0, 3, 3],
		["queen", 0, 5, 5], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	ex.items.append(_item("extraction", "multi"))
	ex._use_item(0)
	check(ex.item_targets.size() == 3 and not ex.item_targets.has(Vector2i(7, 10)),
		"extraction targets only own pieces")
	ex._item_confirm_multi()
	check(ex.items.size() == 1, "zero-selection confirm is a no-op")
	ex._item_click(Vector2i(2, 2))
	ex._item_click(Vector2i(3, 3))
	ex._item_click(Vector2i(3, 3)) # toggle the pawn back off
	check(ex.item_selected == [Vector2i(2, 2)], "taps toggle the selection")
	ex._use_item(0) # tap the armed item: cancel, unspent, board untouched
	check(ex.items.size() == 1 and ex.item_selected.is_empty()
		and ex.board.has(Vector2i(2, 2)), "cancel leaves the item unspent")
	ex._use_item(0)
	ex._item_click(Vector2i(2, 2))
	ex._item_click(Vector2i(3, 3))
	ex._item_confirm_multi()
	check(ex.items.is_empty() and ex.stock.has("dragon-king") and ex.stock.has("pawn")
		and not ex.board.has(Vector2i(2, 2)) and not ex.board.has(Vector2i(3, 3)),
		"confirm returns the selection to Stock at current identity")
	check(ex.board.has(Vector2i(5, 5)), "unselected pieces stay on the board")
	ex.queue_free()
	await process_frame

	# --- extraction: piece state rides along opaquely; stateful copies stack
	# apart; placement restores; merging discards (ADR-0002)
	var ez := _boot({"board": [["knight", 0, 2, 2, "buff"], ["knight", 0, 4, 2],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	ez.actions_left = 5
	ez.actions_max = 5
	ez.items.append(_item("extraction", "multi"))
	ez._use_item(0)
	ez._item_click(Vector2i(2, 2))
	ez._item_click(Vector2i(4, 2))
	ez._item_confirm_multi()
	var stateful := {"id": "knight", "buff": true}
	check(ez.stock.has(stateful) and ez.stock.has("knight"),
		"state rides into Stock; the plain copy stays a bare id")
	check(ez.hud._stacks().size() == 2, "a stateful copy stacks apart from plain ones")
	ez._place(stateful, Vector2i(3, 6))
	check(ez.board[Vector2i(3, 6)].get("buff", false), "placement restores the state")
	check(not ez.stock.has(stateful) and ez.stock.has("knight"),
		"placement consumed the stateful entry, not the plain one")
	ez.queue_free()
	await process_frame

	# --- merge: a stateful entry is a normal merge input — consumed exactly,
	# state discarded, result is the plain next piece
	var em := _boot({"board": [["rook", 1, 7, 10]], "wave": 3, "stock": ["pawn"]})
	await process_frame
	em.stock.append({"id": "pawn", "buff": true})
	em.actions_left = 3
	MergeLogic.commit_merge(em,
		{"id": "pawn", "cap": false, "entry": {"id": "pawn", "buff": true}},
		{"id": "pawn", "cap": false, "entry": "pawn"})
	check(em.stock == ["sergeant"], "merging a stateful entry consumes it and discards the state")
	em.queue_free()
	await process_frame

	# --- Demote returns a piece to the base of its own chain, not always Pawn
	# (Notion resync 2026-08-27); a piece with no chain above it isn't targetable
	var dm := _boot({"board": [["archbishop", 0, 2, 2], ["squirrel", 0, 4, 2],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	dm.actions_left = 3
	dm.items.append(_item("demote", "tile"))
	dm._use_item(0)
	check(dm.item_targets.has(Vector2i(2, 2)) and not dm.item_targets.has(Vector2i(4, 2)),
		"Demote offers a promoted piece but not a chainless one")
	dm._item_click(Vector2i(2, 2))
	check(dm.board[Vector2i(2, 2)].id == "bishop",
		"Demote sends the Archbishop back to Bishop, its chain base")
	dm.queue_free()
	await process_frame

	# --- Piece Buffs (slice 03): Buff Box picks a buff, then targets a piece;
	# Shield repels one capture from either side; Critical doubles one capture
	const BuffLogic := preload("res://scripts/buff_logic.gd")
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

	# --- artefact trigger engine (slice 15): stacking is additive per copy,
	# and the result never depends on acquisition order
	var stack := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["greed", "greed"]})
	await process_frame
	var pawn_base: int = stack.defs.pawn.value
	check(Economy.capture_score(stack, "pawn") == pawn_base + 20,
		"two Greeds stack additively (+10 each), not multiplicatively")
	stack.queue_free()
	await process_frame

	var order_a := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["greed", "score", "bounty"]})
	await process_frame
	var order_b := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["bounty", "score", "greed"]})
	await process_frame
	check(Economy.capture_score(order_a, "pawn") == Economy.capture_score(order_b, "pawn"),
		"capture score is independent of artefact acquisition order")
	order_a.queue_free()
	order_b.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL ITEM CHECKS OK")
	quit(1 if fails > 0 else 0)
