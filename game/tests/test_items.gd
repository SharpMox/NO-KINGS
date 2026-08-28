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
const Shop := preload("res://scripts/shop.gd")
const Items := preload("res://data/items.gd")

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

	# --- issue 16 (Gold/Score batch): percentage Score/Gold modifiers stack
	# additively — two Tinfoil Hats give +30%/-10%, not compounding (95%^2)
	var tinfoil := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["tinfoil-hat", "tinfoil-hat"]})
	await process_frame
	Economy.earn(tinfoil, 100)
	check(tinfoil.score == 130, "two Tinfoil Hats: +15% Score each stacks to +30%, not +30.25%")
	check(tinfoil.gold == 90, "two Tinfoil Hats: -5% Gold each stacks to -10%, not -9.75%")
	tinfoil.queue_free()
	await process_frame

	# Tungsten-Filled Gold Bar: Gold gains also add 2x their amount as Score
	var tungsten := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["tungsten-filled-gold-bar"]})
	await process_frame
	Economy.earn(tungsten, 100)
	check(tungsten.gold == 100, "Tungsten-Filled Gold Bar doesn't change the Gold gain itself")
	check(tungsten.score == 300, "Tungsten-Filled Gold Bar: +100 base, +200 (2x the Gold) Score")
	tungsten.queue_free()
	await process_frame

	# --- issue 20 regression: the slice 20 fleet sweep caught Tungsten-Filled
	# Gold Bar + Popemobile Piggy Bank as a degenerate pair (score ~11-13x an
	# organic baseline) because both wrote g.score straight from inside their
	# on_gold_change dispatch instead of through Economy.earn's ctx.score_bonus
	# channel — held together, held score should be the plain additive sum
	# of each one's own bonus (2x + 10x), not doubled or compounded
	var tungsten_pope := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["tungsten-filled-gold-bar", "popemobile-piggy-bank"]})
	await process_frame
	Economy.earn(tungsten_pope, 100)
	check(tungsten_pope.gold == 100, "Tungsten + Popemobile together don't change the Gold gain itself")
	check(tungsten_pope.score == 100 + 200 + 1000,
		"Tungsten (+200, 2x) and Popemobile (+1000, 10x) add on top of the +100 base — the correct sum, not doubled")
	tungsten_pope.queue_free()
	await process_frame

	# El Dorado Body Glitter: 5% of Score gains paid as Gold, off the
	# immutable ctx.base — must give the same payout whether or not another
	# on_score_change handler (Bermuda Triangulation, key-sorts before
	# "el-dorado-body-glitter" so it dispatches first) already inflated the
	# running ctx.amount. Pre-fix, El Dorado read ctx.amount and would have
	# paid 5% of the Bermuda-inflated 150 (= 8 Gold, for a buggy total of 133)
	# instead of 5% of the untouched 100 base.
	var el_dorado_order := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["el-dorado-body-glitter", "bermuda-triangulation"],
		"clock_s": 10})
	await process_frame
	Economy.earn(el_dorado_order, 100)
	check(el_dorado_order.score == 150, "Bermuda Triangulation: +50% Score under 60s Clock")
	check(el_dorado_order.gold == 130,
		"El Dorado's 5% Gold bonus is off the 100 base (+5), not the Bermuda-inflated 150 (+8) — " +
		"125 (100 base +25% Bermuda Gold) + 5 (El Dorado) = 130, order-independent")
	el_dorado_order.queue_free()
	await process_frame

	# Zurich Gnome Figurine: at Wave end, refund 10% of Gold spent in the Shop
	var zurich := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["zurich-gnome-figurine"], "gold": 100})
	await process_frame
	zurich.gold_spent_shop_this_wave = 40
	WaveLogic.queue(zurich, zurich.wave + 1)
	check(zurich.gold == 104, "Zurich Gnome Figurine refunds 10% of Gold spent in the Shop at Wave clear")
	zurich.queue_free()
	await process_frame

	# Social Credit Report Card + issue 16 ruling: the -10 Score penalty on
	# losing a piece debits Gold instead, so Score stays up-only
	var social := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["social-credit-report-card"], "gold": 100, "score": 500})
	await process_frame
	WaveLogic.queue(social, social.wave + 1) # clean: no pieces lost since wave start
	check(social.score == 600, "Social Credit Report Card: +100 Score on a clean Wave clear")
	check(social.gold == 100, "Social Credit Report Card: no Gold change on a clean clear")
	social.lost_player += 1 # a piece falls during the next wave
	WaveLogic.queue(social, social.wave + 1)
	check(social.score == 600, "Social Credit Report Card: Score stays up-only after losing a piece")
	check(social.gold == 90, "Social Credit Report Card: the -10 Score penalty debits Gold instead (issue 16 ruling)")
	social.queue_free()
	await process_frame

	# Nero's Marshmallow Stick: each Capture in a Turn gives +25% more Score
	# than the previous one (linear step off the untouched base value)
	var nero := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["nero-s-marshmallow-stick"]})
	await process_frame
	var nero_base: int = nero.defs.pawn.value
	var cap1 := Economy.capture_score(nero, "pawn")
	var cap2 := Economy.capture_score(nero, "pawn")
	var cap3 := Economy.capture_score(nero, "pawn")
	check(cap1 == nero_base, "Nero's Marshmallow Stick: the first Capture this Turn is unmodified")
	check(cap2 == nero_base + roundi(nero_base * 0.25), "Nero's Marshmallow Stick: the 2nd Capture gives +25% more")
	check(cap3 == nero_base + roundi(nero_base * 0.5), "Nero's Marshmallow Stick: the 3rd Capture gives +50% more")
	nero.queue_free()
	await process_frame

	# --- slice 17 (Action/Time/Piece, no-prerequisite subset) ---

	# CIA Exploding Cigar: flat +1 action every turn, like "move"
	var cig := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["cia-exploding-cigar"]})
	await process_frame
	check(cig.actions_left == Tuning.ACTIONS_PER_TURN + 1
			and cig.actions_max == Tuning.ACTIONS_PER_TURN + 1,
		"CIA Exploding Cigar grants +1 action every turn")
	cig.queue_free()
	await process_frame

	# 'I Am Not a Robot' Checkbox: +1 action at 8+ allied pieces on the Board
	var bot8 := _boot({"board": [
			["queen", 0, 0, 0], ["rook", 0, 1, 0], ["bishop", 0, 2, 0], ["knight", 0, 3, 0],
			["pawn", 0, 4, 0], ["pawn", 0, 5, 0], ["pawn", 0, 6, 0], ["pawn", 0, 7, 0],
			["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["i-am-not-a-robot-checkbox"]})
	await process_frame
	check(bot8.actions_left == Tuning.ACTIONS_PER_TURN + 1,
		"'I Am Not a Robot' Checkbox grants +1 action at 8+ allied pieces")
	bot8.queue_free()
	await process_frame

	var bot7 := _boot({"board": [
			["queen", 0, 0, 0], ["rook", 0, 1, 0], ["bishop", 0, 2, 0], ["knight", 0, 3, 0],
			["pawn", 0, 4, 0], ["pawn", 0, 5, 0], ["pawn", 0, 6, 0],
			["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["i-am-not-a-robot-checkbox"]})
	await process_frame
	check(bot7.actions_left == Tuning.ACTIONS_PER_TURN,
		"'I Am Not a Robot' Checkbox withholds the bonus below 8 allied pieces")
	bot7.queue_free()
	await process_frame

	# Seed Vault Secret Hatch: +1 action while holding 3+ unused Items
	var sv3 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "items": ["blitz", "sniper", "demote"],
		"artefacts": ["seed-vault-secret-hatch"]})
	await process_frame
	check(sv3.actions_left == Tuning.ACTIONS_PER_TURN + 1,
		"Seed Vault Secret Hatch grants +1 action at 3+ unused items")
	sv3.queue_free()
	await process_frame

	var sv2 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "items": ["blitz", "sniper"],
		"artefacts": ["seed-vault-secret-hatch"]})
	await process_frame
	check(sv2.actions_left == Tuning.ACTIONS_PER_TURN,
		"Seed Vault Secret Hatch withholds the bonus below 3 items")
	sv2.queue_free()
	await process_frame

	# Super Soldier Multivitamins: +1 action while 3+ allied pieces carry a
	# Piece Buff (board slot 4 as a Dictionary merges onto the piece — the
	# `buffs` array BuffLogic.of() reads, per buff_logic.gd's header)
	var ss3 := _boot({"board": [
			["queen", 0, 2, 2, {"buffs": [{"key": "shield"}]}],
			["rook", 0, 3, 2, {"buffs": [{"key": "critical"}]}],
			["bishop", 0, 4, 2, {"buffs": [{"key": "range"}]}],
			["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["super-soldier-multivitamins"]})
	await process_frame
	check(ss3.actions_left == Tuning.ACTIONS_PER_TURN + 1,
		"Super Soldier Multivitamins grants +1 action at 3+ buffed allies")
	ss3.queue_free()
	await process_frame

	var ss2 := _boot({"board": [
			["queen", 0, 2, 2, {"buffs": [{"key": "shield"}]}],
			["rook", 0, 3, 2, {"buffs": [{"key": "critical"}]}],
			["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["super-soldier-multivitamins"]})
	await process_frame
	check(ss2.actions_left == Tuning.ACTIONS_PER_TURN,
		"Super Soldier Multivitamins withholds the bonus below 3 buffed allies")
	ss2.queue_free()
	await process_frame

	# 5G Microchips: +1s Clock per allied piece, -1s per enemy piece, at Turn start
	var g5 := _boot({"board": [["queen", 0, 2, 2], ["rook", 0, 3, 2], ["bishop", 0, 4, 2],
			["rook", 1, 7, 10]],
		"wave": 3, "clock_s": 100.0, "artefacts": ["5g-microchips"]})
	await process_frame
	check(g5.clock_ms <= 100000 + 2000 and g5.clock_ms >= 100000 + 2000 - 1000,
		"5G Microchips nets +1s per ally minus 1s per enemy (3 allies, 1 enemy here)")
	g5.queue_free()
	await process_frame

	# Terracotta Draft Card + Charlemagne's Birth Certificate: On Wave clear.
	# An all-player, no-pending-spawn board clears on the very first
	# _begin_player_turn() the boot already runs, so no extra plumbing is
	# needed to reach the hook.
	var wc := _boot({"board": [["queen", 0, 2, 2]], "wave": 1, "clock_s": 100.0,
		"artefacts": ["terracotta-draft-card", "charlemagne-s-birth-certificate"]})
	await process_frame
	check(wc.stock.size() == 1 and wc.stock[0] is String,
		"Terracotta Draft Card grants a bare-id piece to Stock on Wave clear (ADR-0002: no board state to carry)")
	check(wc.clock_ms <= 100000 + 10000 and wc.clock_ms >= 100000 + 10000 - 1000,
		"Charlemagne's Birth Certificate grants +10s Clock on Wave clear")
	wc.queue_free()
	await process_frame

	# Stargate Divination Crystal — the auto-pass interaction the issue calls
	# out (Blitz hit the same shape): granting an action mid-resolution must
	# never resurrect a turn that already auto-passed. Baseline first: with no
	# artefact, spending the last action on a capture auto-passes.
	var base := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4], ["rook", 1, 7, 10]],
		"wave": 3})
	await process_frame
	base.actions_left = 1
	base.actions_max = 1
	base._move_player(Vector2i(2, 2), Vector2i(2, 4)) # captures the pawn: last action
	check(base.actions_left == 0 and base.state == base.State.ENEMY_TURN,
		"baseline: spending the last action on a capture auto-passes the turn")
	base.queue_free()
	await process_frame

	# With Stargate, the SAME capture is also the first action of the turn:
	# the hook refunds the action inside Economy.capture_score, before
	# _move_player's own actions_left -= 1 / auto-pass check runs — so the
	# check never sees 0 and the turn never ends.
	var sg := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["stargate-divination-crystal"]})
	await process_frame
	sg.actions_left = 1
	sg.actions_max = 1
	sg._move_player(Vector2i(2, 2), Vector2i(2, 4))
	check(sg.actions_left == 1 and sg.state == sg.State.PLAYER_TURN,
		"Stargate Divination Crystal refunds the capture's action before the auto-pass check — the turn stays open")
	sg.queue_free()
	await process_frame

	# --- issue 18 (Shop/Item/Buff batch): Buff-tag artefacts go through
	# BuffLogic.add, not a parallel path ---

	# Crop Circle Plank: "5-Wave Milestone" fires off the just-cleared wave
	# number directly (on_wave_clear), not the engine's own 10-wave
	# on_milestone cadence — see artefact_hooks.gd's silk-road-coupon note
	var crop := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 3, 2],
		["knight", 0, 4, 2], ["rook", 1, 7, 10]],
		"wave": 5, "artefacts": ["crop-circle-plank"], "gold": 50})
	await process_frame
	WaveLogic.queue(crop, crop.wave + 1) # clears wave 5: a real 5-Wave Milestone
	var buffed := 0
	for pos in crop.board:
		if crop.board[pos].owner == Rules.PLAYER and BuffLogic.of(crop.board[pos]).size() > 0:
			buffed += 1
	check(buffed == 2, "Crop Circle Plank: exactly 2 allied pieces get +1 Piece Buff")
	check(crop.gold == 40, "Crop Circle Plank: -10 Gold")
	crop.queue_free()
	await process_frame

	# it does NOT fire clearing wave 6 or 7 (not a multiple of 5)
	var crop_off := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 3, 2],
		["rook", 1, 7, 10]], "wave": 6, "artefacts": ["crop-circle-plank"], "gold": 50})
	await process_frame
	WaveLogic.queue(crop_off, crop_off.wave + 1)
	check(crop_off.gold == 50, "Crop Circle Plank: no-op on a wave clear that isn't a multiple of 5")
	crop_off.queue_free()
	await process_frame

	# MK-Ultra Sugar Cube: On Deploy, the deployed piece gets a Tactical buff
	var mkultra := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["mk-ultra-sugar-cube"], "stock": ["pawn"], "gold": 100})
	await process_frame
	mkultra.state = mkultra.State.PLAYER_TURN
	mkultra.actions_left = 2
	mkultra._place("pawn", Vector2i(4, 2))
	var deployed: Array = BuffLogic.of(mkultra.board[Vector2i(4, 2)])
	check(deployed.size() == 1, "MK-Ultra Sugar Cube: the deployed piece gets +1 Piece Buff")
	if deployed.size() == 1:
		var tac_keys: Array = Items.PIECE_BUFFS.filter(func(b: Dictionary) -> bool:
			return b.tier == "Tactical").map(func(b: Dictionary) -> String: return b.key)
		check(tac_keys.has(deployed[0].key), "MK-Ultra Sugar Cube: the Buff is Tactical-tier")
	mkultra.queue_free()
	await process_frame

	# Holy Lint: On Capture, the capturing piece gets +1 Piece Buff (no gate) —
	# exercises attacker_pos end to end through a real board capture
	var lint := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2]],
		"wave": 3, "artefacts": ["holy-lint"]})
	await process_frame
	lint.actions_left = 5
	lint._move_player(Vector2i(2, 2), Vector2i(3, 2))
	check(BuffLogic.of(lint.board[Vector2i(3, 2)]).size() == 1,
		"Holy Lint: the capturing piece gets +1 Piece Buff")
	lint.queue_free()
	await process_frame

	# Frame 25: On Wave clear, +1 Tactical Item, -10 Gold
	var frame := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["frame-25"], "gold": 50})
	await process_frame
	var items_n0: int = frame.items.size()
	WaveLogic.queue(frame, frame.wave + 1)
	check(frame.items.size() == items_n0 + 1, "Frame 25: +1 Item at Wave clear")
	check(frame.items.back().tier == "Tactical", "Frame 25: the granted Item is Tactical-tier")
	check(frame.gold == 40, "Frame 25: -10 Gold at Wave clear")
	frame.queue_free()
	await process_frame

	# Sleeper Agent Pillow: a bought Piece arrives with a random Tactical Buff
	# — the piece isn't on the board yet, so this rides stock as a Dictionary
	var sleeper := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["sleeper-agent-pillow"], "gold": 9999})
	await process_frame
	sleeper.state = sleeper.State.PLAYER_TURN
	sleeper.actions_left = 5
	var piece_i := -1
	for i in sleeper.shop_stock.size():
		if sleeper.shop_stock[i].kind == "piece":
			piece_i = i
			break
	Shop.buy(sleeper, piece_i)
	var bought: Variant = sleeper.stock.back()
	check(bought is Dictionary and BuffLogic.of(bought).size() == 1,
		"Sleeper Agent Pillow: the bought Piece lands in Stock carrying a Buff")
	sleeper.actions_left = 5
	sleeper._place(bought, Vector2i(4, 2))
	check(BuffLogic.of(sleeper.board[Vector2i(4, 2)]).size() == 1,
		"Sleeper Agent Pillow: the Buff survives deployment onto the board")
	sleeper.queue_free()
	await process_frame

	# Shrinkflation Cereal Box: +10 Gold/+10 Score/+1s Clock at every Turn end
	# (new on_turn_end hook, game.gd:_on_pass)
	var shrink := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["shrinkflation-cereal-box"], "gold": 50, "score": 0})
	await process_frame
	shrink.state = shrink.State.PLAYER_TURN
	shrink.actions_left = 0 # any non-SETUP pass through _on_pass reaches on_turn_end
	var clock0: float = shrink.clock_ms
	shrink._on_pass()
	check(shrink.gold == 60 and shrink.score == 10, "Shrinkflation Cereal Box: +10 Gold/+10 Score at Turn end")
	check(shrink.clock_ms > clock0, "Shrinkflation Cereal Box: +1s Clock at Turn end")
	shrink.queue_free()
	await process_frame

	# Skull and Bones Coffin: +20% Score gain while holding 200+ Gold, gated
	# off (not just discounted) below that
	var skull := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["skull-and-bones-coffin"], "gold": 199})
	await process_frame
	Economy.earn(skull, 100)
	check(skull.score == 100, "Skull and Bones Coffin: no bonus under 200 Gold")
	skull.gold = 200
	Economy.earn(skull, 100)
	check(skull.score == 220, "Skull and Bones Coffin: +20% Score gain at 200+ Gold")
	skull.queue_free()
	await process_frame

	# Majestic 12 Secret Handshake Diagram: Item Boxes only offer
	# Strategic/Decisive Items — the mixed Box Pick is unaffected
	var majestic := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["majestic-12-secret-handshake-diagram"]})
	await process_frame
	var tactical_keys: Array = Items.ITEMS.filter(func(it: Dictionary) -> bool:
		return it.tier == "Tactical").map(func(it: Dictionary) -> String: return it.key)
	var saw_only_high_tier := true
	for i in 20:
		for opt in majestic._box_options("item"):
			if tactical_keys.has(opt.payload.key):
				saw_only_high_tier = false
	check(saw_only_high_tier, "Majestic 12: typed Item Boxes never roll a Tactical Item")
	check(majestic._box_options().size() == 3, "Majestic 12: the mixed Box Pick still rolls freely")
	majestic.queue_free()
	await process_frame

	# --- issue 19: on_piece_lost (Satoshi's Private Key, Nibiru Hide-and-Seek
	# Trophy) — game.gd's new choke point, called from _destroy here
	var sat := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 0, 3, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 50, "artefacts": ["satoshi-s-private-key", "nibiru-hide-and-seek-trophy"]})
	await process_frame
	WaveLogic.queue(sat, sat.wave + 1) # Wave clear 1: Satoshi +2/ally (2 allies), Nibiru +10 (streak 1)
	check(sat.gold == 50 + 4 + 10, "Satoshi's Private Key + Nibiru Hide-and-Seek Trophy: first Wave-clear payout")
	WaveLogic.queue(sat, sat.wave + 1) # Wave clear 2, no loss yet: Nibiru grows to +20 (streak 2)
	check(sat.gold == 50 + 4 + 10 + 4 + 20, "Nibiru Hide-and-Seek Trophy: the payout grows +10 per Wave")
	sat._destroy(Vector2i(2, 2)) # lose a piece: Satoshi -2 Gold, Nibiru streak resets
	check(sat.nibiru_wave_streak == 0, "Nibiru Hide-and-Seek Trophy: losing a piece resets the streak")
	var gold_after_loss: int = sat.gold
	check(gold_after_loss == 50 + 4 + 10 + 4 + 20 - 2, "Satoshi's Private Key: -2 Gold on losing a piece")
	WaveLogic.queue(sat, sat.wave + 1) # Wave clear 3: Nibiru restarts at +10 (streak 1), 1 ally left
	check(sat.gold == gold_after_loss + 2 + 10, "Nibiru Hide-and-Seek Trophy: collapses to 0 and restarts after a loss")
	sat.queue_free()
	await process_frame

	# --- issue 19: on_piece_lost (Lusitania "Hardtack" Crate, D.B. Cooper's
	# Parachute, Templar Severance Gold, Backmasked Vinyl, Tutankhamun's Death
	# Thong) — the Buff-carry / Ranked / attacker-debuff branches
	var lus := _boot({"board": [["queen", 0, 2, 2, {"buffs": [{"key": "critical"}]}],
			["pawn", 1, 7, 10]],
		"wave": 4, "gold": 0, "score": 0,
		"artefacts": ["lusitania-hardtack-crate", "d-b-cooper-s-parachute"]})
	await process_frame
	lus._destroy(Vector2i(2, 2)) # the queen carries a Buff and is unranked
	check(lus.score == 150, "Lusitania \"Hardtack\" Crate: +150 Score for a Buff-carrying piece lost")
	check(lus.gold == 150 + roundi(lus.defs["queen"].value * 0.75),
		"Lusitania (+150 Gold) and D.B. Cooper's Parachute (+75% of value) both pay on the same loss")
	lus.queue_free()
	await process_frame

	var rank := _boot({"board": [["sergeant", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0,
		"artefacts": ["templar-severance-gold-one-pile", "backmasked-vinyl"]})
	await process_frame
	rank._destroy(Vector2i(2, 2)) # a Ranked piece (sergeant, promoted from pawn)
	check(rank.gold == 150, "Templar Severance Gold (One Pile): +150 Gold for a Ranked piece lost")
	check(rank.stock == ["pawn"], "Backmasked Vinyl: a copy of the base-chain piece (pawn) joins Stock")
	rank.queue_free()
	await process_frame

	var unranked := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0,
		"artefacts": ["templar-severance-gold-one-pile", "backmasked-vinyl"]})
	await process_frame
	unranked._destroy(Vector2i(2, 2)) # a base pawn: not Ranked — neither artefact pays
	check(unranked.gold == 0 and unranked.stock.is_empty(),
		"Templar Severance Gold / Backmasked Vinyl: no payout for a non-Ranked piece")
	unranked.queue_free()
	await process_frame

	var tutan := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 2, 5]],
		"wave": 4, "artefacts": ["tutankhamun-s-death-thong"]})
	await process_frame
	await tutan._run_enemy_actions() # the enemy rook captures the player's pawn
	check(BuffLogic.has(tutan.board[Vector2i(2, 2)], "slow"),
		"Tutankhamun's Death Thong: the capturing enemy piece gets Slow")
	tutan.queue_free()
	await process_frame

	# --- issue 19: on_item_consume — each artefact boots alone (any single-item
	# use also satisfies Tape Eraser Magnet's "last held" gate, so it gets its
	# own isolated boot rather than entangling its math with the others)
	var arms := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0, "artefacts": ["arms-fair-goodie-bag"]})
	await process_frame
	arms.items.append({"key": "x1", "name": "x1", "tier": "Strategic", "target": "", "description": ""})
	arms.actions_left = 5
	arms._use_item(0)
	check(arms.gold == 25, "Arms Fair Goodie Bag: +25 Gold on a Strategic Item use")
	arms.queue_free()
	await process_frame

	var doom := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "score": 0, "artefacts": ["doomsday-autoclicker"]})
	await process_frame
	doom.items.append({"key": "x2", "name": "x2", "tier": "Decisive", "target": "", "description": ""})
	doom.actions_left = 5
	var clock_doom: float = doom.clock_ms
	doom._use_item(0)
	check(doom.score == 200 and doom.clock_ms > clock_doom,
		"Doomsday Autoclicker: +200 Score and +10s Clock on a Decisive Item use")
	doom.queue_free()
	await process_frame

	var tape := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0, "score": 0, "artefacts": ["tape-eraser-magnet"]})
	await process_frame
	tape.items.append({"key": "x3", "name": "x3", "tier": "Tactical", "target": "", "description": ""})
	tape.actions_left = 5
	tape._use_item(0) # the ONLY held Item — Tape Eraser Magnet's "last held" gate
	check(tape.score == 100 and tape.gold == 50,
		"Tape Eraser Magnet: +100 Score and +50 Gold on using your last held Item")
	tape.queue_free()
	await process_frame

	var lobbyist := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "artefacts": ["defense-lobbyist-business-card"]})
	await process_frame
	lobbyist.items.append({"key": "x4", "name": "x4", "tier": "Strategic", "target": "", "description": ""})
	lobbyist.actions_left = 5
	lobbyist._use_item(0) # non-Tactical use: the grant lands, then x4 itself is removed
	check(lobbyist.items.size() == 1 and lobbyist.items[0].tier == "Tactical",
		"Defense Lobbyist Business Card: a non-Tactical use grants a Tactical Item")
	lobbyist.items.clear()
	lobbyist.items.append({"key": "x5", "name": "x5", "tier": "Tactical", "target": "", "description": ""})
	lobbyist.actions_left = 5
	lobbyist._use_item(0) # a Tactical use grants nothing
	check(lobbyist.items.is_empty(), "Defense Lobbyist Business Card: no grant on a Tactical use")
	lobbyist.queue_free()
	await process_frame

	var cancel := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "artefacts": ["dihydrogen-monoxide-battery", "wardenclyffe-aaa-batteries"]})
	await process_frame
	cancel.items.append({"key": "y1", "name": "y1", "tier": "Tactical", "target": "", "description": ""})
	cancel.actions_left = 5
	cancel._use_item(0)
	check(cancel.items.size() == 1, "Dihydrogen Monoxide Battery: the first Tactical use this Wave is not consumed")
	cancel.actions_left = 5
	cancel._use_item(0) # second use this Wave: both artefacts already spent their free use
	check(cancel.items.is_empty(), "the second use this Wave IS consumed")
	cancel.queue_free()
	await process_frame

	var fidelity := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "artefacts": ["33rd-degree-fidelity-card"]})
	await process_frame
	for i in 3:
		fidelity.items.append({"key": "z", "name": "z", "tier": "Tactical", "target": "", "description": ""})
		fidelity.actions_left = 5
		fidelity._use_item(0)
	check(fidelity.items.size() == 1 and fidelity.items[0].tier == "Strategic",
		"33rd Degree Fidelity Card: the 3rd Tactical use grants a Strategic Item")
	fidelity.queue_free()
	await process_frame

	# --- issue 19: on_rank_up (Witness Protection Mustache, Holy Grail
	# Coaster, Bigfoot Toenail Clipping) — merge_logic.gd's commit_merge, a
	# same-id merge (Rank Up), both board- and Stock-landing cases
	var rankup := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 0, 3, 2], ["rook", 1, 7, 10]],
		"wave": 4, "stock": ["pawn", "pawn"],
		"artefacts": ["witness-protection-mustache", "holy-grail-coaster", "bigfoot-toenail-clipping"]})
	await process_frame
	var clock_rankup: float = rankup.clock_ms
	MergeLogic.commit_merge(rankup, Vector2i(2, 2), Vector2i(3, 2)) # board merge: lands on Vector2i(3, 2)
	check(rankup.clock_ms > clock_rankup, "Witness Protection Mustache: +20s Clock on Rank Up")
	check(BuffLogic.of(rankup.board[Vector2i(3, 2)]).size() == 1,
		"Holy Grail Coaster: +1 Piece Buff to the Ranked piece (board landing)")
	check(rankup.stock.has("pawn"), "Bigfoot Toenail Clipping: a copy of the base-chain piece joins Stock")
	MergeLogic.commit_merge(rankup, # pool-only merge (both refs from Stock): lands in Stock, not the board
		{"id": "pawn", "cap": false, "entry": "pawn"}, {"id": "pawn", "cap": false, "entry": "pawn"})
	var converted: Variant = null # Bigfoot Toenail Clipping's own Stock grant (a bare
		# String) can land anywhere in the Array — find the Dictionary instead
	for stock_entry in rankup.stock:
		if stock_entry is Dictionary:
			converted = stock_entry
	check(converted != null and BuffLogic.of(converted).size() == 1,
		"Holy Grail Coaster: the Stock-landing case converts the bare id into a Buff-carrying Dictionary")
	rankup.queue_free()
	await process_frame

	# --- issue 19: chain-lookup off existing hooks (CIA Heart Attack Gun,
	# Montauk Eggo Waffle) — ItemLogic.chain_base, no new hook
	var cia := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0, "artefacts": ["cia-heart-attack-gun"]})
	await process_frame
	var pawn_val: int = cia.defs["pawn"].value
	Economy.capture_score(cia, "pawn", "knight", true, Vector2i(2, 2)) # Buffed attacker, first Capture this Turn
	check(cia.gold == pawn_val, "CIA Heart Attack Gun: +100% Gold on the first Capture with a Buffed attacker")
	cia.gold = 0
	cia.turn_capture_count = 0
	Economy.capture_score(cia, "pawn", "pawn", false, Vector2i(2, 2)) # unranked, unbuffed attacker: no bonus
	check(cia.gold == 0, "CIA Heart Attack Gun: no bonus for an unranked, unbuffed attacker")
	cia.gold = 0
	cia.turn_capture_count = 0
	Economy.capture_score(cia, "pawn", "sergeant", false, Vector2i(2, 2)) # a Ranked, unbuffed attacker still qualifies
	check(cia.gold == pawn_val, "CIA Heart Attack Gun: +100% Gold for a Ranked (not just Buffed) attacker")
	cia.queue_free()
	await process_frame

	var montauk := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "stock": ["pawn"], "artefacts": ["montauk-eggo-waffle"]})
	await process_frame
	WaveLogic.queue(montauk, 6) # Wave 5 just cleared -> "5-Wave Milestone" fires this on_wave_clear
	check(montauk.stock == ["sergeant"],
		"Montauk Eggo Waffle: the only Stock piece Ranks Up on the 5-Wave Milestone")
	montauk.queue_free()
	await process_frame

	# --- issue 19: board-half reads (Dyatlov Geiger Counter, FEMA Summer Camp
	# Flyer) — Tuning.BOARD_H, no new hook
	var dya := _boot({"board": [["pawn", 0, 2, 7], ["pawn", 0, 3, 8], ["pawn", 0, 4, 9],
			["rook", 1, 7, 10]],
		"wave": 4, "score": 0, "artefacts": ["dyatlov-geiger-counter"]})
	await process_frame
	Economy.earn(dya, 100)
	check(dya.score == 200, "Dyatlov Geiger Counter: +100% Score with 3+ allies on the enemy half")
	dya.queue_free()
	await process_frame

	var fema := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2], ["rook", 1, 4, 3]],
		"wave": 4, "gold": 0, "artefacts": ["fema-summer-camp-flyer"]})
	await process_frame
	fema.state = fema.State.PLAYER_TURN
	fema.actions_left = 0
	fema._on_pass()
	check(fema.gold == 4, "FEMA Summer Camp Flyer: +2 Gold per enemy piece on your half at Turn end")
	fema.queue_free()
	await process_frame

	# --- issue 19: enemy auto-debuff (Diplomatic Migraine Ray) — BuffLogic is
	# owner-agnostic already, no new hook
	var dip := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 1, 3, 8], ["queen", 1, 4, 9]],
		"wave": 4, "artefacts": ["diplomatic-migraine-ray"]})
	await process_frame
	WaveLogic.queue(dip, dip.wave + 1) # on_wave_spawn: the strongest enemy piece gets Slow
	check(BuffLogic.has(dip.board[Vector2i(4, 9)], "slow"),
		"Diplomatic Migraine Ray: the strongest enemy piece gets Slow on Wave spawn")
	dip.queue_free()
	await process_frame

	# --- issue 19: cheap follow-ups (Casino Invisible Clock, 2012 Doomsday
	# Party Hat, Fort Knox IOU) — hooks that landed after their own slice
	var cheap := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 9999, "score": 0,
		"artefacts": ["casino-invisible-clock", "2012-doomsday-party-hat", "fort-knox-iou"]})
	await process_frame
	var clock_cheap1: float = cheap.clock_ms
	for i in cheap.shop_stock.size():
		if cheap.shop_stock[i].kind == "item":
			Shop.buy(cheap, i)
			break
	check(cheap.clock_ms > clock_cheap1, "Casino Invisible Clock: +25s Clock on a Shop purchase")
	var clock_cheap2: float = cheap.clock_ms
	Economy.earn(cheap, 20) # a Gold gain, not a purchase — 2012 Doomsday Party Hat's own hook
	check(cheap.clock_ms > clock_cheap2, "2012 Doomsday Party Hat: +5s Clock per 10 Gold gained")
	cheap.gold = 5
	var s0: int = cheap.score
	Economy.earn(cheap, 100)
	check(cheap.score == s0 + 150, "Fort Knox IOU: +50% Score gain while holding under 10 Gold")
	cheap.queue_free()
	await process_frame

	# --- issue 19: on_tariff_apply / on_tariff_charge (Merchants of Death
	# Sample Case, Tunguska Toothpicks) — economy.gd's existing choke points
	var tar := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0, "score": 0,
		"artefacts": ["merchants-of-death-sample-case", "tunguska-toothpicks"]})
	await process_frame
	Economy.activate_tariff_by_key(tar, "move_cost")
	check(tar.gold == 100, "Merchants of Death Sample Case: +100 Gold whenever a new Tariff is applied")
	tar.gold = 500
	var clock_tar: float = tar.clock_ms
	Economy.charge(tar, "move_cost")
	check(tar.score == 150 and tar.clock_ms > clock_tar,
		"Tunguska Toothpicks: +150 Score and +5s Clock whenever a Tariff charges you")
	tar.queue_free()
	await process_frame

	# --- issue 19: capture conversion, the cheap wave-clear half (Stockholm
	# Syndrome Pamphlet)
	var stock19 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "captured": ["pawn"], "artefacts": ["stockholm-syndrome-pamphlet"]})
	await process_frame
	WaveLogic.queue(stock19, stock19.wave + 1)
	check(stock19.captured.is_empty() and stock19.stock.has("pawn"),
		"Stockholm Syndrome Pamphlet: a Captured Stock piece moves to Stock on Wave clear")
	stock19.queue_free()
	await process_frame

	# --- issue 24: combat & positioning (USS Eldridge Invisibility Paint,
	# Royal Fiat (Undamaged)) — the shared post-move ctx flag mechanism
	var eldridge := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2]],
		"wave": 3, "artefacts": ["uss-eldridge-invisibility-paint"]})
	await process_frame
	eldridge.actions_left = 5
	eldridge._move_player(Vector2i(2, 2), Vector2i(3, 2))
	check(eldridge.board.has(Vector2i(2, 2)) and not eldridge.board.has(Vector2i(3, 2)),
		"USS Eldridge Invisibility Paint: the capturing piece returns to its starting position")
	eldridge.queue_free()
	await process_frame

	var eldridge2 := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2], ["pawn", 1, 4, 2]],
		"wave": 3, "artefacts": ["uss-eldridge-invisibility-paint"]})
	await process_frame
	eldridge2.actions_left = 5
	eldridge2._move_player(Vector2i(2, 2), Vector2i(3, 2)) # 1st Capture this Turn: returns
	eldridge2._move_player(Vector2i(2, 2), Vector2i(4, 2)) # 2nd Capture this Turn: stays put
	check(eldridge2.board.has(Vector2i(4, 2)) and not eldridge2.board.has(Vector2i(2, 2)),
		"USS Eldridge Invisibility Paint: only your first Capture each Turn returns")
	eldridge2.queue_free()
	await process_frame

	var fiat := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2]],
		"wave": 3, "artefacts": ["royal-fiat-undamaged"]})
	await process_frame
	fiat.actions_left = 5
	fiat._move_player(Vector2i(2, 2), Vector2i(3, 2))
	check(fiat.board.has(Vector2i(0, 0)) and not fiat.board.has(Vector2i(3, 2)),
		"Royal Fiat (Undamaged): the first capturing piece each Turn retreats to the back row")
	fiat.queue_free()
	await process_frame

	var backrow: Array = []
	for x in 8:
		backrow.append(["pawn", 0, x, 0])
	var fiat_full := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2]] + backrow,
		"wave": 3, "artefacts": ["royal-fiat-undamaged"]})
	await process_frame
	fiat_full.actions_left = 5
	fiat_full._move_player(Vector2i(2, 2), Vector2i(3, 2))
	check(fiat_full.board.has(Vector2i(3, 2)),
		"Royal Fiat (Undamaged): a full back row is a no-op, the piece stays put")
	fiat_full.queue_free()
	await process_frame

	# both held: return_to_start wins the tie (ruled in artefact_hooks.gd)
	var both := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2]],
		"wave": 3, "artefacts": ["uss-eldridge-invisibility-paint", "royal-fiat-undamaged"]})
	await process_frame
	both.actions_left = 5
	both._move_player(Vector2i(2, 2), Vector2i(3, 2))
	check(both.board.has(Vector2i(2, 2)),
		"USS Eldridge Invisibility Paint takes precedence over Royal Fiat when both fire together")
	both.queue_free()
	await process_frame

	# Fireproof Pajamas — blocks Item/Tariff destruction (_destroy's choke
	# point), leaves ordinary Capture untouched
	var fire := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 4, 4]],
		"wave": 3, "artefacts": ["fireproof-pajamas"]})
	await process_frame
	fire._destroy(Vector2i(4, 4))
	check(fire.board.has(Vector2i(4, 4)) and fire.lost_player == 0,
		"Fireproof Pajamas: an Item/Tariff destroy is blocked and doesn't count as a loss")
	fire.queue_free()
	await process_frame

	var fire2 := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 2, 5]],
		"wave": 4, "artefacts": ["fireproof-pajamas"]})
	await process_frame
	await fire2._run_enemy_actions() # the enemy rook captures the player's pawn
	check(fire2.board.has(Vector2i(2, 2)) and fire2.board[Vector2i(2, 2)].owner == Rules.ENEMY,
		"Fireproof Pajamas: does not block an ordinary Capture, only Item/Tariff destruction")
	fire2.queue_free()
	await process_frame

	# Hoffa's Cement Shoes — once per Wave, the capturer sinks with its victim
	var hoffa := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 2, 5]],
		"wave": 4, "artefacts": ["hoffa-s-cement-shoes"]})
	await process_frame
	await hoffa._run_enemy_actions()
	check(not hoffa.board.has(Vector2i(2, 2)) and hoffa.lost_enemy == 1,
		"Hoffa's Cement Shoes: the capturing enemy piece is removed along with its victim")
	hoffa.queue_free()
	await process_frame

	var hoffa2 := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 0, 4, 2],
			["rook", 1, 2, 5], ["rook", 1, 4, 5]],
		"wave": 4, "artefacts": ["hoffa-s-cement-shoes"]})
	await process_frame
	await hoffa2._run_enemy_actions() # 1st Capture this Wave: mutual destruction
	await hoffa2._run_enemy_actions() # 2nd Capture this Wave: already used, capturer survives
	var enemies_left := 0
	for pos in hoffa2.board:
		if hoffa2.board[pos].owner == Rules.ENEMY:
			enemies_left += 1
	check(hoffa2.board.is_empty() == false and enemies_left == 1 and hoffa2.lost_enemy == 1
			and hoffa2.lost_player == 2,
		"Hoffa's Cement Shoes: once per Wave — the second Capture's attacker survives")
	hoffa2.queue_free()
	await process_frame

	# --- issue 23: on_buff_consume (Amityville Ouija Board, Cleopatra's Hairpin)
	# — game.gd's new _consume_buff choke point
	var amc := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["amityville-ouija-board", "cleopatra-s-hairpin"]})
	await process_frame
	BuffLogic.add(amc.board[Vector2i(2, 2)], "shield") # Tactical
	await amc._run_enemy_actions() # the rook attacks, Shield repels and is consumed
	check(amc.gold == 10,
		"Amityville Ouija Board: +10 Gold on any-tier Piece Buff consume; Cleopatra's Hairpin skips a Tactical buff")
	BuffLogic.add(amc.board[Vector2i(2, 2)], "reflect") # Decisive
	await amc._run_enemy_actions() # the same rook attacks again, into Reflect
	check(amc.gold == 10 + 10 + 100,
		"Cleopatra's Hairpin: +100 Gold on top of Amityville's own +10, for a Decisive Buff (Reflect)")
	amc.queue_free()
	await process_frame

	# --- issue 23: on_buff_consume / on_piece_demoted, owner-agnostic
	# (Guidestone Blood Ritual) ---
	var gbr := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5]],
		"wave": 3, "gold": 0, "artefacts": ["guidestone-blood-ritual"]})
	await process_frame
	gbr.actions_left = 5
	BuffLogic.add(gbr.board[Vector2i(2, 5)], "shield") # the ENEMY rook carries it
	gbr._move_player(Vector2i(2, 2), Vector2i(2, 5)) # the player attacks into it
	check(gbr.gold == 25,
		"Guidestone Blood Ritual: +25 Gold on ANY piece's Buff consume, ally or enemy")
	gbr.queue_free()
	await process_frame

	var gbr2 := _boot({"board": [["sergeant", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["guidestone-blood-ritual"]})
	await process_frame
	gbr2.actions_left = 5
	gbr2.items.append(_item("demote", "tile"))
	gbr2._use_item(0)
	gbr2._item_click(Vector2i(2, 2))
	check(gbr2.board[Vector2i(2, 2)].id == "pawn" and gbr2.gold == 25,
		"Guidestone Blood Ritual: +25 Gold whenever a piece (ally or enemy) is Demoted")
	gbr2.queue_free()
	await process_frame

	# --- issue 23: on_buff_consume, first-per-Wave re-apply (Youth Fountain Martini) ---
	var yfm := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 2, 5]],
		"wave": 3, "artefacts": ["youth-fountain-martini"]})
	await process_frame
	BuffLogic.add(yfm.board[Vector2i(2, 2)], "shield")
	await yfm._run_enemy_actions() # Shield blocks the attack and is consumed
	check(BuffLogic.has(yfm.board[Vector2i(2, 2)], "shield"),
		"Youth Fountain Martini: the first Buff consumed each Wave is re-applied to the same piece")
	await yfm._run_enemy_actions() # the same rook, repelled again, attacks again
	check(not BuffLogic.has(yfm.board[Vector2i(2, 2)], "shield"),
		"Youth Fountain Martini: only the first consume each Wave gets the refresh")
	yfm.queue_free()
	await process_frame

	# --- issue 23: on_buff_apply (Pied Piper's Rat Census, mRNA Firmware Update)
	# — game.gd's new _apply_buff choke point ---
	var ppr := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 3, 3], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["pied-piper-s-rat-census"]})
	await process_frame
	ppr.actions_left = 5
	ppr.items.append(_item("buff_box", "tile"))
	ppr._use_item(0)
	ppr._buff_chosen("shield")
	ppr._item_click(Vector2i(2, 2)) # buff the queen — the pawn at (3,3) is adjacent
	check(BuffLogic.has(ppr.board[Vector2i(2, 2)], "shield")
			and BuffLogic.has(ppr.board[Vector2i(3, 3)], "shield"),
		"Pied Piper's Rat Census: applying a Piece Buff copies it to one adjacent ally")
	ppr.queue_free()
	await process_frame

	var mrna := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["mrna-firmware-update"]})
	await process_frame
	mrna.actions_left = 5
	for i in 3:
		mrna.items.append(_item("buff_box", "tile"))
		mrna._use_item(0)
		mrna._buff_chosen("shield")
		mrna._item_click(Vector2i(2, 2))
	check(mrna.board[Vector2i(2, 2)].id == "sergeant",
		"mRNA Firmware Update: every 3rd Piece Buff you apply also Ranks Up the piece")
	mrna.queue_free()
	await process_frame

	# --- issue 23: on_piece_lost buff transfer (KGB Photo Eraser) ---
	var kgb := _boot({"board": [["queen", 0, 2, 2, {"buffs": [{"key": "critical"}]}],
			["pawn", 0, 3, 3], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["kgb-photo-eraser"]})
	await process_frame
	kgb._destroy(Vector2i(2, 2)) # the queen carries a Buff and is lost
	check(BuffLogic.has(kgb.board[Vector2i(3, 3)], "critical"),
		"KGB Photo Eraser: a lost piece's Buff transfers to the nearest ally")
	kgb.queue_free()
	await process_frame

	# --- issue 23: demotion / buff-removal immunity (Antikythera Warranty
	# Card, Atlantis Snow Globe) — game.gd "demote"/"radar_jamming" ---
	var ant := _boot({"board": [["sergeant", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["antikythera-warranty-card"]})
	await process_frame
	ant.actions_left = 5
	ant.items.append(_item("demote", "tile"))
	ant._use_item(0)
	ant._item_click(Vector2i(2, 2))
	check(ant.board[Vector2i(2, 2)].id == "sergeant",
		"Antikythera Warranty Card: your pieces cannot be Demoted")
	BuffLogic.add(ant.board[Vector2i(2, 2)], "shield")
	ant.items.append(_item("radar_jamming", "tile"))
	ant._use_item(0)
	ant._item_click(Vector2i(2, 2))
	check(BuffLogic.has(ant.board[Vector2i(2, 2)], "shield"),
		"Antikythera Warranty Card: your Piece Buffs cannot be removed by Radar Jamming")
	ant.queue_free()
	await process_frame

	var atl := _boot({"board": [["sergeant", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["atlantis-snow-globe"]})
	await process_frame
	atl.actions_left = 5
	atl.items.append(_item("demote", "tile"))
	atl._use_item(0)
	atl._item_click(Vector2i(2, 2))
	check(atl.board[Vector2i(2, 2)].id == "sergeant",
		"Atlantis Snow Globe: your pieces cannot be Demoted")
	atl.queue_free()
	await process_frame

	# --- issue 23: payout + strip (45.5 Carat Curse) — no new hook needed ---
	var carat := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "score": 0, "artefacts": ["45-5-carat-curse"]})
	await process_frame
	BuffLogic.add(carat.board[Vector2i(2, 2)], "shield")
	Economy.earn(carat, 100)
	check(carat.gold == 145 and carat.score == 145,
		"45.5 Carat Curse: +45% Gold and Score gain")
	WaveLogic.queue(carat, carat.wave + 1) # Wave 3 clears — every 3rd Wave strips Buffs
	check(BuffLogic.of(carat.board[Vector2i(2, 2)]).is_empty(),
		"45.5 Carat Curse: every 3rd Wave clear strips all allied Piece Buffs")
	carat.queue_free()
	await process_frame

	# --- issue 23: Buff Box choice-count (Numbers Station Sudoku, Bohemian
	# Grove Friendship Bracelet) — a UI change in _open_buff_pick/_buff_chosen,
	# not a REGISTRY hook (issue 18's own held-back note) ---
	var nss := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 20, "artefacts": ["numbers-station-sudoku"]})
	await process_frame
	nss.actions_left = 5
	nss.items.append(_item("buff_box", "tile"))
	nss._use_item(0)
	var nss_box: Node = nss.modals.buff_panel.get_child(0).get_child(0)
	check(nss_box.get_child_count() - 2 == 4, # minus the head label and cancel button
		"Numbers Station Sudoku: the Buff Box offers 4 choices instead of 3")
	nss._buff_chosen("shield")
	check(nss.gold == 20 - 5, "Numbers Station Sudoku: each pick costs 5 Gold")
	nss.queue_free()
	await process_frame

	var bgf := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["bohemian-grove-friendship-bracelet"]})
	await process_frame
	bgf.actions_left = 5
	bgf.items.append(_item("buff_box", "tile"))
	bgf._use_item(0)
	var bgf_box: Node = bgf.modals.buff_panel.get_child(0).get_child(0)
	check(bgf_box.get_child_count() - 2 == 5,
		"Bohemian Grove Friendship Bracelet: the Buff Box offers 5 choices instead of 3")
	bgf.queue_free()
	await process_frame

	# --- issue 25: per-piece capture ledger (split from 19) — game.gd
	# _note_capture, fired from both the player's _move_player capture branch
	# and the enemy's _run_enemy_actions capture branch, plus the three
	# artefacts that read it.
	var ledger_p := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	ledger_p._move_player(Vector2i(2, 2), Vector2i(2, 5))
	check(ledger_p.board[Vector2i(2, 5)].get("captures", 0) == 1
		and ledger_p.board[Vector2i(2, 5)].get("wave_captures", 0) == 1,
		"issue 25: the player's OWN capturing piece gets its ledger bumped (_move_player)")
	ledger_p.queue_free()
	await process_frame

	var ledger_e := _boot({"board": [["pawn", 0, 2, 6], ["rook", 1, 2, 8], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	await ledger_e._run_enemy_actions()
	check(ledger_e.board.has(Vector2i(2, 6)) and ledger_e.board[Vector2i(2, 6)].owner == 1
		and ledger_e.board[Vector2i(2, 6)].get("captures", 0) == 1,
		"issue 25: the enemy's OWN capturing piece gets its ledger bumped too (_run_enemy_actions, no on_capture/scoring)")
	ledger_e.queue_free()
	await process_frame

	# Chupacabra Chew Toy: +2 Gold on Capture, +10 more if the captured piece
	# had captured one of yours (a lifetime captures > 0 on the victim)
	var chup_fresh := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 3], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["chupacabra-chew-toy"]})
	await process_frame
	var chup_base: int = chup_fresh.defs.pawn.value # captures also earn base Gold via Economy.earn
	chup_fresh._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(chup_fresh.gold == chup_base + 2, "Chupacabra Chew Toy: +2 Gold on a Capture of a piece with no capture history")
	chup_fresh.queue_free()
	await process_frame

	var chup_marked := _boot({"board": [["queen", 0, 2, 2],
			["pawn", 1, 2, 3, {"captures": 1}], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["chupacabra-chew-toy"]})
	await process_frame
	var chup_marked_base: int = chup_marked.defs.pawn.value
	chup_marked._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(chup_marked.gold == chup_marked_base + 12,
		"Chupacabra Chew Toy: +10 more Gold when the captured piece had captured one of yours")
	chup_marked.queue_free()
	await process_frame

	# Alien Rocket Toy: on a piece's 3rd (lifetime) Capture, it Ranks Up
	var rocket := _boot({"board": [["pawn", 0, 2, 2, {"captures": 2}], ["pawn", 1, 3, 3], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["alien-rocket-toy"]})
	await process_frame
	rocket._move_player(Vector2i(2, 2), Vector2i(3, 3)) # diagonal: pawns only capture on the diagonal
	check(rocket.board[Vector2i(3, 3)].id == "sergeant" and rocket.board[Vector2i(3, 3)].get("captures", 0) == 3,
		"Alien Rocket Toy: the 3rd Capture Ranks the piece Up (pawn -> sergeant)")
	rocket.queue_free()
	await process_frame

	# Zodiac Crossword Puzzle: On Wave clear, the ally with the most Captures
	# THAT WAVE (not lifetime) gets +1 Piece Buff — resets every Wave
	var zodiac := _boot({"board": [
			["queen", 0, 2, 1, {"wave_captures": 3}], ["pawn", 0, 3, 1, {"wave_captures": 1}],
			["rook", 1, 7, 10]],
		"wave": 4, "artefacts": ["zodiac-crossword-puzzle"]})
	await process_frame
	WaveLogic.queue(zodiac, zodiac.wave + 1)
	check(BuffLogic.of(zodiac.board[Vector2i(2, 1)]).size() == 1,
		"Zodiac Crossword Puzzle: the ally with the most Captures that Wave gets +1 Piece Buff")
	check(BuffLogic.of(zodiac.board[Vector2i(3, 1)]).is_empty(),
		"Zodiac Crossword Puzzle: the ally with fewer Captures that Wave gets nothing")
	check(not zodiac.board[Vector2i(2, 1)].has("wave_captures")
		and not zodiac.board[Vector2i(3, 1)].has("wave_captures"),
		"Zodiac Crossword Puzzle: the Wave-scoped ledger resets for every piece at the next Wave, win or lose")
	zodiac.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL ITEM CHECKS OK")
	quit(1 if fails > 0 else 0)
