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
const Waves := preload("res://data/waves.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")

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

	# Tungsten-Filled Gold Bar: +20% Score gain (rebalanced 2026-08-28 — was
	# "2x their amount as Score", an unconditional 3x Score multiplier since
	# Gold is earned 1:1 with Score, wildly out of scale with the catalog)
	var tungsten := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["tungsten-filled-gold-bar"]})
	await process_frame
	Economy.earn(tungsten, 100)
	check(tungsten.gold == 100, "Tungsten-Filled Gold Bar doesn't change the Gold gain itself")
	check(tungsten.score == 120, "Tungsten-Filled Gold Bar: +100 base, +20 (20% of the Gold) Score")
	tungsten.queue_free()
	await process_frame

	# --- issue 20 regression: the slice 20 fleet sweep caught Tungsten-Filled
	# Gold Bar + Popemobile Piggy Bank as a degenerate pair because both wrote
	# g.score straight from inside their on_gold_change dispatch instead of
	# through Economy.earn's ctx.score_bonus channel — held together, held
	# score should be the plain additive sum of each one's own bonus (20% +
	# 50%, rebalanced 2026-08-28 — was 2x + 10x), not doubled or compounded
	var tungsten_pope := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["tungsten-filled-gold-bar", "popemobile-piggy-bank"]})
	await process_frame
	Economy.earn(tungsten_pope, 100)
	check(tungsten_pope.gold == 100, "Tungsten + Popemobile together don't change the Gold gain itself")
	check(tungsten_pope.score == 100 + 20 + 50,
		"Tungsten (+20, 20%) and Popemobile (+50, 50%) add on top of the +100 base — the correct sum, not doubled")
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

	# --- issue 30: per-turn action log + Elvish Hard Hat ("first Action of a
	# Turn is an Item or ability: +1 Action"). Basic effect: an Item as the
	# Turn's first action grants the bonus.
	var ehh := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]], "wave": 3,
		"artefacts": ["elvish-hard-hat"]})
	await process_frame
	ehh.actions_left = 2
	ehh.actions_max = 2
	ehh.items.append(_item("counter_intel", ""))
	ehh._use_item(0) # untargeted Item, resolves immediately — costs 1 action
	check(ehh.actions_left == 2 and ehh.actions_max == 3,
		"Elvish Hard Hat: an Item as the Turn's first Action refunds it and grants +1 Action")
	check(ehh.action_log.size() == 1 and ehh.action_log[0].kind == "item",
		"the action log records the Item as this Turn's first entry")
	ehh.queue_free()
	await process_frame

	# A move (not an Item) as the first Action earns no bonus.
	var ehh_move := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]], "wave": 3,
		"artefacts": ["elvish-hard-hat"]})
	await process_frame
	ehh_move.actions_left = 2
	ehh_move.actions_max = 2
	ehh_move._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(ehh_move.actions_left == 1 and ehh_move.actions_max == 2,
		"Elvish Hard Hat doesn't fire when the first Action is a move, not an Item")
	ehh_move.queue_free()
	await process_frame

	# An Item as the SECOND Action (a move already spent the first) earns no
	# bonus either — the effect text is "first Action", not "any Item".
	var ehh_second := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]], "wave": 3,
		"artefacts": ["elvish-hard-hat"]})
	await process_frame
	ehh_second.actions_left = 2
	ehh_second.actions_max = 2
	ehh_second._move_player(Vector2i(2, 2), Vector2i(2, 3)) # first action: a move
	ehh_second.items.append(_item("counter_intel", ""))
	ehh_second._use_item(0) # second action: an Item — too late for the bonus
	check(ehh_second.actions_left == 0 and ehh_second.actions_max == 2,
		"Elvish Hard Hat doesn't fire on an Item that isn't the Turn's first Action")
	ehh_second.queue_free()
	await process_frame

	# The trap the issue calls out (same shape as Stargate above): a Tier-5
	# single-action Turn where the only Action is an Item. Baseline first —
	# with no artefact, spending the Turn's one action auto-passes.
	var ehh_base := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]], "wave": 3})
	await process_frame
	ehh_base.actions_left = 1
	ehh_base.actions_max = 1
	ehh_base.items.append(_item("counter_intel", ""))
	ehh_base._use_item(0)
	check(ehh_base.actions_left == 0 and ehh_base.state == ehh_base.State.ENEMY_TURN,
		"baseline: spending a single-action Turn's only action on an Item auto-passes the turn")
	ehh_base.queue_free()
	await process_frame

	# With Elvish Hard Hat, that SAME Item use is also the Turn's first Action:
	# the hook refunds it inside _log_action, before _item_apply's own
	# actions_left == 0 auto-pass check runs — the check never sees 0, so the
	# turn is never resurrected because it never actually passes.
	var ehh_trap := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]], "wave": 3,
		"artefacts": ["elvish-hard-hat"]})
	await process_frame
	ehh_trap.actions_left = 1
	ehh_trap.actions_max = 1
	ehh_trap.items.append(_item("counter_intel", ""))
	ehh_trap._use_item(0)
	check(ehh_trap.actions_left == 1 and ehh_trap.state == ehh_trap.State.PLAYER_TURN,
		"Elvish Hard Hat refunds the Item's action before the auto-pass check — an already-passed turn is never resurrected because the turn never passes")
	ehh_trap.queue_free()
	await process_frame

	# --- fix (ruled 2026-08-28): RANDOM artefact buff grants must never hand
	# out a self-harming buff — today only Slow (it makes its own holder move
	# and capture like a Pawn, a debuff on its own holder). The player's own
	# Buff Box pick (_open_buff_pick, game.gd) is untouched: choosing Slow
	# deliberately (e.g. onto an enemy) is legitimate. ---
	check(Items.PIECE_BUFFS.filter(func(b: Dictionary) -> bool: return b.key == "slow")[0]
			.get("self_harming", false),
		"Slow is flagged self_harming in the catalog")
	check(not Items.PIECE_BUFFS.filter(func(b: Dictionary) -> bool: return b.key == "smog")[0]
			.get("self_harming", false),
		"Smog (debuffs adjacent ENEMIES, not its own holder) stays unflagged — a genuine buff")
	var rbk_rng := RandomNumberGenerator.new()
	rbk_rng.seed = 7
	var seen_slow := false
	var seen_other := {}
	for i in 500:
		var k: String = ArtefactHooks._random_buff_key(rbk_rng)
		if k == "slow":
			seen_slow = true
		seen_other[k] = true
	check(not seen_slow, "RANDOM grants (_random_buff_key) never draw Slow, even over 500 rolls")
	check(seen_other.size() == Items.PIECE_BUFFS.size() - 1,
		"every OTHER Piece Buff is still reachable by a random grant (%d of %d)"
			% [seen_other.size(), Items.PIECE_BUFFS.size() - 1])
	check(Items.PIECE_BUFFS.duplicate().any(func(b: Dictionary) -> bool: return b.key == "slow"),
		"the player's own Buff Box pool (_open_buff_pick's source) still includes Slow")

	# --- issue 18 (Shop/Item/Buff batch): Buff-tag artefacts go through
	# BuffLogic.add, not a parallel path ---

	# Crop Circle Plank: "5-Wave Milestone" is PER-ARTEFACT (ruled 2026-08-28)
	# — this held copy counts its own 5 waves from its own acquisition, fired
	# off the just-cleared wave (on_wave_clear), not the engine's own GLOBAL
	# 10-wave on_milestone cadence. acquired_wave is forced to 1 here so the
	# test can isolate the handler's own cadence math (_milestone5_hit) from
	# the separate acquisition-stamping coverage below — wave 5 clearing is
	# then this copy's beat 5 (1 + 4), a real 5-Wave Milestone.
	var crop := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 3, 2],
		["knight", 0, 4, 2], ["rook", 1, 7, 10]],
		"wave": 5, "artefacts": ["crop-circle-plank"], "gold": 50})
	await process_frame
	crop.artefacts[0].acquired_wave = 1
	WaveLogic.queue(crop, crop.wave + 1) # clears wave 5: a real 5-Wave Milestone
	var buffed := 0
	for pos in crop.board:
		if crop.board[pos].owner == Rules.PLAYER and BuffLogic.of(crop.board[pos]).size() > 0:
			buffed += 1
	check(buffed == 2, "Crop Circle Plank: exactly 2 allied pieces get +1 Piece Buff")
	check(crop.gold == 40, "Crop Circle Plank: -10 Gold")
	crop.queue_free()
	await process_frame

	# it does NOT fire clearing wave 6 or 7 (not this copy's own multiple of 5)
	var crop_off := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 3, 2],
		["rook", 1, 7, 10]], "wave": 6, "artefacts": ["crop-circle-plank"], "gold": 50})
	await process_frame
	crop_off.artefacts[0].acquired_wave = 1
	WaveLogic.queue(crop_off, crop_off.wave + 1)
	check(crop_off.gold == 50, "Crop Circle Plank: no-op on a wave clear that isn't a multiple of 5")
	crop_off.queue_free()
	await process_frame

	# John Titor's Crypto Wallet: was left wired to on_milestone (the GLOBAL
	# 10-wave beat) when the rest of this "5-Wave Milestone" batch moved to
	# the per-artefact on_wave_clear + _milestone5_hit cadence — paid at half
	# the intended rate. Acquired wave 2: fires clearing wave 6 (2+4, beat 1)
	# and wave 11 (2+9, beat 2). Waves 8-10 are jumped directly (g.wave set,
	# not queued one by one) so the test never calls WaveLogic.queue with the
	# GLOBAL milestone wave (10) itself — that fires its OWN clock refill +
	# score/gold bonus (wave_logic.gd's `n % MILESTONE_WAVES == 0` block),
	# unrelated to this artefact and just noise for this assertion; the
	# separate control test below isolates that wave on purpose instead.
	var cw := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 2, "artefacts": ["john-titor-s-crypto-wallet"], "gold": 0})
	await process_frame
	cw.artefacts[0].acquired_wave = 2
	cw.clock_ms = 25000.0 # 25s left -> +5 Gold per firing (int(25.0 / 5.0))
	for n in range(3, 7): # clear waves 2..5: not this copy's beat yet
		WaveLogic.queue(cw, n)
	check(cw.gold == 0, "no payout before the copy's own beat 5 (acquired wave 2 -> W+4 = wave 6)")
	WaveLogic.queue(cw, 7) # clears wave 6: this copy's beat 1 (2+4)
	check(cw.gold == 5, "fires on its own 5-wave beat, +1 Gold per 5s left on the Clock (25s -> +5)")
	cw.wave = 11 # skip straight past 8/9/10 (see comment above)
	WaveLogic.queue(cw, 12) # clears wave 11: this copy's beat 2 (2+9)
	check(cw.gold == 10, "fires again on its own next 5-wave beat (W+9), not the global cadence")
	cw.queue_free()
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
	# exercises attacker_pos end to end through a real board capture.
	# Seed pinned: Holy Lint's random draw covers every tier, including Bomb/
	# Trap/Multicapture — self-consuming hazards of their own (a freshly
	# granted Bomb would detonate THIS capture, same class of bug as Critical/
	# Range below, just not in this fix's scope) that a random roll would
	# occasionally hit and destroy the piece the test then inspects. Seed 4
	# is a durable roll ("stun", a dormant buff untouched by this capture
	# path either way) — verified deterministic across repeated runs.
	var lint := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2]],
		"wave": 3, "artefacts": ["holy-lint"], "seed": "4"})
	await process_frame
	lint.actions_left = 5
	lint._move_player(Vector2i(2, 2), Vector2i(3, 2))
	var lint_buffs: Array = BuffLogic.of(lint.board[Vector2i(3, 2)])
	check(lint_buffs.size() == 1 and lint_buffs[0].key == "stun",
		"Holy Lint: the capturing piece gets +1 Piece Buff (stun, seed 1)")
	lint.queue_free()
	await process_frame

	# --- fix (ruled 2026-08-28): grant-on-capture (Obedience-Flavored Tap
	# Water, Holy Lint) must land AFTER critical/range are consumed by the
	# SAME capture that granted them — a reward banked for the NEXT capture,
	# not this one. Before the fix, a granted Critical doubled the capture
	# that granted it (capture_multiplier read the just-mutated board[from]
	# synchronously) and a granted Range was immediately spent for zero
	# effect (the comment above, on Holy Lint, is the flake this caused).
	# Seeds are found live, mirroring _random_buff_key's own pool + roll, so
	# this doesn't hardcode an RNG index that could silently drift.
	var tac_pool: Array = Items.PIECE_BUFFS.filter(func(b: Dictionary) -> bool:
		return not b.get("self_harming", false) and b.tier == "Tactical")
	var crit_idx := -1
	var range_idx := -1
	for i in tac_pool.size():
		if tac_pool[i].key == "critical":
			crit_idx = i
		elif tac_pool[i].key == "range":
			range_idx = i
	var find_rng := RandomNumberGenerator.new()
	var crit_seed := -1
	var range_seed := -1
	for s in 5000:
		if crit_seed < 0:
			find_rng.seed = s
			if find_rng.randi() % tac_pool.size() == crit_idx:
				crit_seed = s
		if range_seed < 0:
			find_rng.seed = s
			if find_rng.randi() % tac_pool.size() == range_idx:
				range_seed = s
		if crit_seed >= 0 and range_seed >= 0:
			break
	check(crit_seed >= 0 and range_seed >= 0, "(setup) found seeds landing a granted Critical and a granted Range")

	var gc := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 1, 2, 3], ["pawn", 1, 5, 5], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["obedience-flavored-tap-water"]})
	await process_frame
	var gc_pawn_val: int = gc.defs.pawn.value
	gc.actions_left = 3
	gc.rng.seed = crit_seed # the very next rng draw is _random_buff_key's, inside this capture
	gc._move_player(Vector2i(2, 2), Vector2i(2, 3)) # first Capture this wave: Tap Water grants Critical
	check(gc.score == gc_pawn_val,
		"a Critical granted by THIS capture doesn't double THIS capture's own score")
	check(BuffLogic.has(gc.board[Vector2i(2, 3)], "critical"),
		"the granted Critical survives on the attacker after the capture that granted it")
	gc.score = 0
	gc._move_player(Vector2i(2, 3), Vector2i(5, 5)) # a second, unrelated capture
	check(gc.score == gc_pawn_val * 2,
		"the banked Critical doubles the NEXT capture — it really works as a reward")
	gc.queue_free()
	await process_frame

	var gr := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 1, 2, 3], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["obedience-flavored-tap-water"]})
	await process_frame
	gr.actions_left = 3
	gr.rng.seed = range_seed
	gr._move_player(Vector2i(2, 2), Vector2i(2, 3)) # first Capture this wave: Tap Water grants Range
	check(BuffLogic.has(gr.board[Vector2i(2, 3)], "range"),
		"the granted Range survives on the attacker after the capture that granted it, not spent for zero effect")
	gr.queue_free()
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
	montauk.artefacts[0].acquired_wave = 1 # per-artefact cadence (2026-08-28):
		# isolate the handler's own math from acquisition-stamping coverage below
	WaveLogic.queue(montauk, 6) # Wave 5 just cleared -> this copy's own "5-Wave Milestone" fires this on_wave_clear
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

	# --- issue 22: tariff interception (Panama Papers Shredder, Amber Room
	# Bubble Wrap, Ark Grounding Cable, Salvation Gift Card) ---
	var panama := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 500, "artefacts": ["panama-papers-shredder"],
		"tariffs": ["move_cost", "deploy_cost"]})
	await process_frame
	var g0: int = panama.gold
	Economy.charge(panama, "move_cost")
	check(panama.gold == g0, "Panama Papers Shredder: a Mild Tariff (move_cost) doesn't charge you")
	Economy.charge(panama, "deploy_cost")
	check(panama.gold == g0 - Tuning.TARIFF_ACTION_COST,
		"Panama Papers Shredder: a Moderate Tariff (deploy_cost) still charges you")
	panama.queue_free()
	await process_frame

	var panama2 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0, "artefacts": ["panama-papers-shredder"], "tariffs": ["inflation"]})
	await process_frame
	Economy.earn(panama2, 100)
	check(panama2.gold == 100, "Panama Papers Shredder: Inflation (Mild) doesn't reduce Gold gains")
	panama2.queue_free()
	await process_frame

	var amber := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0, "artefacts": ["amber-room-bubble-wrap"], "tariffs": ["inflation"]})
	await process_frame
	Economy.earn(amber, 100)
	check(amber.gold == 100, "Amber Room Bubble Wrap: ignores Inflation's Gold-gain reduction")
	amber.queue_free()
	await process_frame

	var ark := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 500, "artefacts": ["ark-grounding-cable"], "tariffs": ["move_cost"]})
	await process_frame
	var g_ark: int = ark.gold
	Economy.charge(ark, "move_cost")
	check(ark.gold == g_ark - roundi(Tuning.TARIFF_ACTION_COST * 0.5),
		"Ark Grounding Cable: Tariff penalties reduced by 50%")
	ark.queue_free()
	await process_frame

	var salvation := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 0, "artefacts": ["salvation-gift-card"]})
	await process_frame
	Economy.activate_tariff_by_key(salvation, "sanctions")
	check(salvation.tariffs_active.is_empty() and salvation.sanctioned_id == "",
		"Salvation Gift Card: the first Tariff applied is cancelled")
	check(not salvation.salvation_charged, "Salvation Gift Card: spent after cancelling")
	Economy.activate_tariff_by_key(salvation, "regulation")
	check(salvation.tariffs_active.size() == 1 and salvation.tariffs_active[0].key == "regulation",
		"Salvation Gift Card: a second Tariff applies normally once spent")
	salvation.artefacts[0].acquired_wave = 1 # per-artefact cadence (2026-08-28):
		# isolate the handler's own math from acquisition-stamping coverage below
	WaveLogic.queue(salvation, 6) # clears wave 5, this copy's own 5-Wave Milestone: recharges
	check(salvation.salvation_charged, "Salvation Gift Card: recharges at the 5-Wave Milestone")
	salvation.queue_free()
	await process_frame

	# --- issue 26: spawn roster modifiers (HAARP Volume Knob, Wuhan Vial
	# Label, Pigeon Charging Cable) — on_wave_roster, Trade War's own
	# prerequisite (issue 13), not a new one
	var haarp := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "score": 0, "gold": 0, "artefacts": ["haarp-volume-knob"]})
	await process_frame
	var haarp_base: int = Waves.WAVES[1].size() # wave 2's designed roster
	haarp._queue_wave(2) # clears wave 1 and queues wave 2's roster
	check(haarp.score == 200 and haarp.gold == 15,
		"HAARP Volume Knob: +200 Score and +15 Gold on Wave clear")
	check(haarp.pending_spawn.size() == haarp_base + 1,
		"HAARP Volume Knob: Wave roster spawns +1 extra piece")
	haarp.queue_free()
	await process_frame

	var wuhan := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "gold": 0, "artefacts": ["wuhan-vial-label"]})
	await process_frame
	var wuhan_base: int = Waves.WAVES[1].size()
	wuhan._queue_wave(2)
	check(wuhan.pending_spawn.size() == wuhan_base + 1,
		"Wuhan Vial Label: Wave roster spawns +1 extra piece")
	Economy.capture_score(wuhan, "rook") # base 50
	check(wuhan.gold == roundi(50 * 0.25),
		"Wuhan Vial Label: Captures give +25% more Gold, off the capture's own base")
	wuhan.queue_free()
	await process_frame

	var pigeon := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "artefacts": ["pigeon-charging-cable"]})
	await process_frame
	var pigeon_base: int = Waves.WAVES[1].size()
	pigeon._queue_wave(2)
	check(pigeon.pending_spawn.size() == pigeon_base - 1,
		"Pigeon Charging Cable: Wave roster spawns 1 fewer piece")
	pigeon.queue_free()
	await process_frame

	# --- issue 26: Shop purchase counter + forced-free override
	# (Pre-Scratched Lottery Ticket) ---
	var lottery := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 9, "gold": 99999, "artefacts": ["pre-scratched-lottery-ticket"]})
	await process_frame
	lottery.actions_left = 20
	for i in 4:
		for j in lottery.shop_stock.size():
			if not lottery.shop_stock[j].sold:
				Shop.buy(lottery, j)
				break
	check(lottery.lottery_purchase_count == 4,
		"Pre-Scratched Lottery Ticket: purchase counter increments per Shop purchase")
	var free_idx := -1
	for j in lottery.shop_stock.size():
		if not lottery.shop_stock[j].sold:
			free_idx = j
			break
	check(free_idx >= 0 and Shop.price(lottery, lottery.shop_stock[free_idx]) == 0,
		"Pre-Scratched Lottery Ticket: every 5th Shop purchase is free")
	var gold_before_free: int = lottery.gold
	Shop.buy(lottery, free_idx)
	check(lottery.gold == gold_before_free, "...: the free purchase costs no Gold")
	lottery.queue_free()
	await process_frame

	# --- issue 26: free-deploy (Hitler's Argentinian Passport) ---
	var hitler := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["hitler-s-argentinian-passport"], "stock": ["pawn"], "gold": 100})
	await process_frame
	hitler.state = hitler.State.PLAYER_TURN
	hitler.actions_left = 2
	hitler._place("pawn", Vector2i(4, 2))
	check(hitler.actions_left == 2,
		"Hitler's Argentinian Passport: Deploying doesn't spend an Action")
	hitler.queue_free()
	await process_frame

	# --- issue 26: free deploy placement (Nazca Boarding Pass) — no hook, a
	# standing rule read directly off g.artefacts (game.gd's _deploy_tiles) ---
	var nazca := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["nazca-boarding-pass"]})
	await process_frame
	check(not Rules.placement_tiles(nazca.board).has(Vector2i(0, 8)),
		"(control) Vector2i(0,8) is not normally a legal placement tile")
	check(nazca._deploy_tiles().has(Vector2i(0, 8)),
		"Nazca Boarding Pass: Deploy legality opens to any empty square")
	nazca.queue_free()
	await process_frame

	# --- issue 26: cost exemption (Nuclear Football Menu) — a single call
	# site (_item_apply), also no hook ---
	var nfm := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["nuclear-football-menu"], "clock_s": 30.0})
	await process_frame
	nfm.state = nfm.State.PLAYER_TURN
	nfm.actions_left = 2
	nfm.items.append(_item("counter_intel", ""))
	nfm._use_item(0)
	check(nfm.actions_left == 2,
		"Nuclear Football Menu: Items don't spend an Action while the Clock is under 60s")
	nfm.queue_free()
	await process_frame

	var nfm_control := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["nuclear-football-menu"]})
	await process_frame
	nfm_control.state = nfm_control.State.PLAYER_TURN
	nfm_control.actions_left = 2
	nfm_control.items.append(_item("counter_intel", ""))
	nfm_control._use_item(0)
	check(nfm_control.actions_left == 1,
		"(control) Nuclear Football Menu: Items spend an Action at full Clock")
	nfm_control.queue_free()
	await process_frame

	# --- issue 26: "5-Wave Milestone" grants (Ark's Bunkbed, Trojan Horse
	# Assembly Manual) — on_wave_clear + _milestone5_hit, PER-ARTEFACT
	# (ruled 2026-08-28), silk-road-coupon's cadence, not the GLOBAL 10-wave
	# on_milestone hook. acquired_wave forced to 1 to isolate the handler's
	# own cadence math from the acquisition-stamping coverage below.
	var arkb := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 99999, "artefacts": ["ark-s-bunkbed"]})
	await process_frame
	arkb.artefacts[0].acquired_wave = 1
	arkb.actions_left = 20
	var arkb_idx1 := -1
	for j in arkb.shop_stock.size():
		if arkb.shop_stock[j].kind == "piece":
			arkb_idx1 = j
			break
	var arkb_id1: String = arkb.shop_stock[arkb_idx1].key
	Shop.buy(arkb, arkb_idx1)
	check(arkb.stock.count(arkb_id1) == 2,
		"Ark's Bunkbed: buying a Piece also queues a free duplicate")
	var arkb_idx2 := -1
	for j in arkb.shop_stock.size():
		if arkb.shop_stock[j].kind == "piece" and not arkb.shop_stock[j].sold:
			arkb_idx2 = j
			break
	var arkb_id2: String = arkb.shop_stock[arkb_idx2].key
	Shop.buy(arkb, arkb_idx2)
	check(arkb.stock.count(arkb_id2) == 1,
		"Ark's Bunkbed: no duplicate on a 2nd Piece buy before the next Milestone")
	WaveLogic.queue(arkb, 6) # clears wave 5 -> 5-Wave Milestone: recharges it
	var arkb_idx3 := -1
	for j in arkb.shop_stock.size():
		if arkb.shop_stock[j].kind == "piece" and not arkb.shop_stock[j].sold:
			arkb_idx3 = j
			break
	if arkb_idx3 >= 0:
		var arkb_id3: String = arkb.shop_stock[arkb_idx3].key
		Shop.buy(arkb, arkb_idx3)
		check(arkb.stock.count(arkb_id3) == 2,
			"Ark's Bunkbed: the free duplicate is available again after the Milestone")
	arkb.queue_free()
	await process_frame

	var trojan := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "artefacts": ["trojan-horse-assembly-manual"]})
	await process_frame
	trojan.artefacts[0].acquired_wave = 1
	check(not trojan.box_open, "(control) no Box open before the Wave-5 clear")
	WaveLogic.queue(trojan, 6) # clears wave 5 -> 5-Wave Milestone
	check(trojan.box_open,
		"Trojan Horse Assembly Manual: a free Box opens on a 5-Wave Milestone")
	trojan.queue_free()
	await process_frame

	# --- issue 26: per-Wave first/last-lost tracking (Jon Burrows' Fake ID,
	# Walt's Cryonic Capsule) ---
	var loss := _boot({"board": [["pawn", 0, 2, 2], ["knight", 0, 3, 2], ["bishop", 0, 4, 2],
			["rook", 1, 7, 10]],
		"wave": 4, "artefacts": ["jon-burrows-fake-id", "walt-s-cryonic-capsule"]})
	await process_frame
	loss._lose_player_piece(Vector2i(2, 2), "captured") # first lost: pawn
	loss._lose_player_piece(Vector2i(3, 2), "captured") # middle: knight
	loss._lose_player_piece(Vector2i(4, 2), "captured") # last lost: bishop
	WaveLogic.queue(loss, loss.wave + 1)
	check(loss.stock.has("pawn"),
		"Jon Burrows' Fake ID: the first piece lost this Wave returns to Stock")
	check(loss.stock.has("bishop"),
		"Walt's Cryonic Capsule: the last piece lost this Wave returns to Stock")
	check(not loss.stock.has("knight"),
		"(sanity) the middle loss isn't returned by either artefact")
	loss.queue_free()
	await process_frame

	# --- issue 26: Score-gain streak (27 Club Punch Card); -50 Gold on loss,
	# same issue-16 ruling as Social Credit Report Card ---
	var club27 := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 3, 2], ["rook", 1, 7, 10]],
		"wave": 1, "score": 0, "artefacts": ["27-club-punch-card"]})
	await process_frame
	WaveLogic.queue(club27, 2) # clean Wave-1 clear: streak -> 1
	club27.score = 0
	Economy.earn(club27, 100)
	check(club27.score == 105,
		"27 Club Punch Card: +5% Score gain per consecutive clean Wave (streak 1)")
	WaveLogic.queue(club27, 3) # clean Wave-2 clear: streak -> 2
	club27.score = 0
	Economy.earn(club27, 100)
	check(club27.score == 110,
		"27 Club Punch Card: the streak compounds (streak 2 = +10%)")
	club27.gold = 100
	club27._lose_player_piece(Vector2i(3, 2), "captured")
	check(club27.club27_streak == 0 and club27.gold == 50,
		"27 Club Punch Card: losing a piece resets the streak and debits 50 Gold")
	club27.queue_free()
	await process_frame

	# --- issue 26: Gold reaching exactly 0 (Zero-Point Energy Drink) ---
	var zpe := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 9, "gold": 20, "artefacts": ["zero-point-energy-drink"],
		"tariffs": ["move_cost"]})
	await process_frame
	zpe.actions_left = 3
	var zpe_actions_before: int = zpe.actions_left
	Economy.charge(zpe, "move_cost", 20) # spend exactly down to 0
	check(zpe.gold == 0, "(control) Gold lands exactly on 0")
	check(zpe.actions_left == zpe_actions_before + 2,
		"Zero-Point Energy Drink: +2 Actions when Gold reaches exactly 0")
	zpe.queue_free()
	await process_frame

	# --- issue 26: Gold floor -100 on Shop purchases (Agartha Welcome Mat) ---
	var agartha := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 9, "gold": 0, "artefacts": ["agartha-welcome-mat"]})
	await process_frame
	agartha.actions_left = 5
	var agartha_idx := -1
	for j in agartha.shop_stock.size():
		if agartha.shop_stock[j].kind == "item" and Shop.price(agartha, agartha.shop_stock[j]) <= 100:
			agartha_idx = j
			break
	check(agartha_idx >= 0 and Shop.can_buy(agartha, agartha.shop_stock[agartha_idx]),
		"Agartha Welcome Mat: a purchase is allowed even at 0 Gold (credit line)")
	Shop.buy(agartha, agartha_idx)
	check(agartha.gold < 0 and agartha.gold >= -100,
		"Agartha Welcome Mat: the purchase takes Gold negative, floored at -100")
	agartha.queue_free()
	await process_frame

	var agartha_control := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 9, "gold": 0})
	await process_frame
	agartha_control.actions_left = 5
	var control_idx := -1
	for j in agartha_control.shop_stock.size():
		if agartha_control.shop_stock[j].kind == "item":
			control_idx = j
			break
	check(control_idx >= 0 and not Shop.can_buy(agartha_control, agartha_control.shop_stock[control_idx]),
		"(control) without Agartha Welcome Mat, 0 Gold blocks the same purchase")
	agartha_control.queue_free()
	await process_frame

	# --- issue 21: echo and meta-triggers (ArtefactHooks._run_meta_triggers) ---

	# Polybius Cartridge: a Capture Artefact (Greed) triggers one extra time
	var poly := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["greed", "polybius-cartridge"]})
	await process_frame
	var poly_base: int = poly.defs.pawn.value
	check(Economy.capture_score(poly, "pawn") == poly_base + 20,
		"Polybius Cartridge: a Capture Artefact (Greed) triggers an extra time (+10 twice)")
	poly.queue_free()
	await process_frame

	# Max Headroom Mask: a Wave Artefact triggers an extra time — both on Wave
	# clear (Zurich Gnome Figurine, +10% Gold spent) and Wave spawn (Nigerian
	# Prince Wire Transfer), the same queue() call fires both hooks
	var headroom := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 100, "score": 0,
		"artefacts": ["zurich-gnome-figurine", "nigerian-prince-wire-transfer", "max-headroom-mask"]})
	await process_frame
	headroom.gold_spent_shop_this_wave = 40
	WaveLogic.queue(headroom, headroom.wave + 1)
	check(headroom.score == 200 and headroom.gold == 128,
		"Max Headroom Mask: doubles a Wave Artefact's trigger on both Wave clear " +
		"(Zurich: +4 twice = 108) and Wave spawn (Nigerian Prince: +10/+100 twice, 108+20=128 Gold, 200 Score)")
	headroom.queue_free()
	await process_frame

	# Red Diary's Missing Pages: an on_piece_lost Artefact (D.B. Cooper's
	# Parachute) triggers one extra time
	var diary := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 2, 5]],
		"wave": 4, "gold": 0, "artefacts": ["d-b-cooper-s-parachute", "red-diary-s-missing-pages"]})
	await process_frame
	var diary_val: int = diary.defs.pawn.value
	await diary._run_enemy_actions()
	check(diary.gold == 2 * roundi(diary_val * 0.75),
		"Red Diary's Missing Pages: an on_piece_lost Artefact triggers an extra time")
	diary.queue_free()
	await process_frame

	# CERN Ctrl+Z Shortcut: a key held 2+ times (two Greeds) gets ONE flat
	# extra trigger, not one per duplicate; a singly-held key gets none
	var cern := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["greed", "greed", "cern-ctrl-z-shortcut"]})
	await process_frame
	var cern_base: int = cern.defs.pawn.value
	check(Economy.capture_score(cern, "pawn") == cern_base + 30,
		"CERN Ctrl+Z Shortcut: two held Greeds (a duplicate) get one flat extra trigger (+10x3, not +10x4)")
	cern.queue_free()
	await process_frame

	var cern_single := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["score", "cern-ctrl-z-shortcut"]})
	await process_frame
	var cern_single_base: int = cern_single.defs.pawn.value
	check(Economy.capture_score(cern_single, "pawn") == cern_single_base + 10,
		"CERN Ctrl+Z Shortcut: a singly-held Artefact (Score) gets no extra trigger")
	cern_single.queue_free()
	await process_frame

	# Bilderberg Hotel Slippers: +15 Gold only when 2+ Artefacts actually
	# fired this call — "fired", not "held" (Score alone never triggers it)
	var bilder := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["greed", "score", "bilderberg-hotel-slippers"]})
	await process_frame
	var bilder_base: int = bilder.defs.pawn.value
	var bilder_pts := Economy.capture_score(bilder, "pawn")
	check(bilder_pts == bilder_base + 20 and bilder.gold == 15,
		"Bilderberg Hotel Slippers: +15 Gold when 2+ of your Artefacts (Greed+Score) trigger on the same event")
	bilder.queue_free()
	await process_frame

	var bilder_one := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "artefacts": ["score", "bilderberg-hotel-slippers"]})
	await process_frame
	Economy.capture_score(bilder_one, "queen") # only Score fires (Greed isn't held)
	check(bilder_one.gold == 0, "Bilderberg Hotel Slippers: no bonus when only one Artefact triggers")
	bilder_one.queue_free()
	await process_frame

	# Illuminati: NWO Booster Pack: +2 Gold/+20 Score per Capture Artefact
	# trigger this call, scaling with how many actually fired
	var nwo := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "score": 0, "artefacts": ["greed", "illuminati-nwo-booster-pack"]})
	await process_frame
	var nwo_base: int = nwo.defs.pawn.value
	var nwo_pts := Economy.capture_score(nwo, "pawn")
	check(nwo_pts == nwo_base + 10 and nwo.gold == 2 and nwo.score == 20,
		"Illuminati: NWO Booster Pack: +2 Gold/+20 Score when one Capture Artefact triggers (Greed)")
	nwo.queue_free()
	await process_frame

	var nwo2 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "score": 0, "artefacts": ["greed", "score", "illuminati-nwo-booster-pack"]})
	await process_frame
	Economy.capture_score(nwo2, "pawn") # Greed + Score both fire on_capture: 2 triggers
	check(nwo2.gold == 4 and nwo2.score == 40,
		"Illuminati: NWO Booster Pack: scales with the number of Capture Artefact triggers (2 -> double)")
	nwo2.queue_free()
	await process_frame

	# 100% Genuine Original Mona Lisa: only the Turn's FIRST Artefact trigger
	# (any hook) is echoed, including a fresh echo when the enemy Turn begins
	var mona := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["greed", "100-genuine-original-mona-lisa"]})
	await process_frame
	var mona_base: int = mona.defs.pawn.value
	check(Economy.capture_score(mona, "pawn") == mona_base + 20,
		"100% Genuine Original Mona Lisa: the first Artefact trigger of the Turn (Greed) is echoed")
	check(Economy.capture_score(mona, "pawn") == mona_base + 10,
		"100% Genuine Original Mona Lisa: only the FIRST trigger of the Turn echoes, not every later one")
	mona.queue_free()
	await process_frame

	var mona_enemy := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 2, 5]],
		"wave": 4, "gold": 0,
		"artefacts": ["greed", "d-b-cooper-s-parachute", "100-genuine-original-mona-lisa"]})
	await process_frame
	var mona_enemy_val: int = mona_enemy.defs.pawn.value
	Economy.capture_score(mona_enemy, "pawn") # consumes this player Turn's echo via Greed
	await mona_enemy._run_enemy_actions() # on_enemy_turn_start resets the flag for a fresh echo
	check(mona_enemy.gold == 2 * roundi(mona_enemy_val * 0.75),
		"100% Genuine Original Mona Lisa: on_enemy_turn_start resets the echo — the enemy Turn " +
		"gets its own first-trigger echo even after the player Turn already used one")
	mona_enemy.queue_free()
	await process_frame

	# Déjà Vu Glitch: only the Turn's first Score/Gold gain is doubled (per
	# copy: N copies -> (1+N)x), later gains the same Turn are untouched
	var dejavu := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "score": 0, "artefacts": ["deja-vu-glitch", "deja-vu-glitch"]})
	await process_frame
	Economy.earn(dejavu, 100)
	check(dejavu.score == 300 and dejavu.gold == 300,
		"Déjà Vu Glitch: two held copies triple (not double) the Turn's first Score/Gold gain")
	Economy.earn(dejavu, 50)
	check(dejavu.score == 350 and dejavu.gold == 350,
		"Déjà Vu Glitch: only the Turn's FIRST Score/Gold gain doubles — later gains are untouched")
	dejavu.queue_free()
	await process_frame

	# Capstone Polish: +150 Score / +5s Clock on acquiring an Artefact
	var capstone := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 9999, "score": 0, "artefacts": ["capstone-polish"]})
	await process_frame
	var capstone_clock0: float = capstone.clock_ms
	for i in capstone.shop_stock.size():
		if capstone.shop_stock[i].kind == "artefact":
			Shop.buy(capstone, i)
			break
	check(capstone.score == 150 and capstone.clock_ms == capstone_clock0 + 5000,
		"Capstone Polish: +150 Score and +5s Clock on acquiring an Artefact")
	capstone.queue_free()
	await process_frame

	# --- the risky one: two echo artefacts (Polybius + CERN, both hooked to
	# on_capture) plus a percentage Artefact (Tinfoil Hat) on the resulting
	# gain — must be a single deterministic bounded number, not an infinite
	# loop, and identical regardless of REGISTRY-array insertion order.
	# Held: Greed x2 (the Capture Artefact being echoed, also CERN's
	# duplicate) + Polybius (+1 extra trigger PER fired Greed = +2) + CERN
	# (+1 flat extra trigger for the duplicated key = +1) -> 5 total Greed
	# dispatches (2 main + 2 Polybius + 1 CERN), pts = base + 50. Then
	# Tinfoil Hat's +15%/-5% applies once, off that same immutable base.
	var order_1 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "score": 0,
		"artefacts": ["greed", "greed", "polybius-cartridge", "cern-ctrl-z-shortcut", "tinfoil-hat"]})
	await process_frame
	var order_2 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "score": 0,
		"artefacts": ["tinfoil-hat", "greed", "cern-ctrl-z-shortcut", "greed", "polybius-cartridge"]})
	await process_frame
	var risky_base: int = order_1.defs.pawn.value
	var pts_1 := Economy.capture_score(order_1, "pawn")
	var pts_2 := Economy.capture_score(order_2, "pawn")
	check(pts_1 == risky_base + 50 and pts_2 == risky_base + 50,
		"two echo Artefacts stacked on the same Capture Artefact stay bounded at a fixed, computed " +
		"total (2 main + 2 Polybius + 1 CERN = 5 Greed dispatches), not a hang and not runaway growth")
	check(pts_1 == pts_2, "the same held keys in a different acquisition order give the same result")
	Economy.earn(order_1, pts_1)
	Economy.earn(order_2, pts_2)
	check(order_1.score == roundi(pts_1 * 1.15) and order_1.gold == roundi(pts_1 * 0.95),
		"Tinfoil Hat's percentage still applies once, off the echoed capture's own immutable base")
	check(order_1.score == order_2.score and order_1.gold == order_2.gold,
		"the full capture+earn pipeline stays order-independent with two echo Artefacts stacked")
	order_1.queue_free()
	order_2.queue_free()
	await process_frame

	# --- Blitz rework (Notion 2026-08-28): costs 0 actions itself (data-driven
	# via items.gd's action_cost, defaulting to 1 for every other item),
	# targets ANY own piece (King excluded, like every other targeted item —
	# the already-moved-only restriction is gone), and marks the target's
	# NEXT move/capture this Turn free. If the target already moved, Blitz
	# also lifts the one-move-per-piece lock so that free move can actually
	# happen. A real power increase (three Blitzes = three free moves), not a
	# wash: the old "costs 1, refunds 1" behavior is gone. ---

	# targeting: an un-moved own piece is now offered too; the King never is
	var bfree := _boot({"board": [["queen", 0, 2, 2], ["king", 0, 0, 0], ["rook", 1, 7, 10]],
		"wave": 3, "items": ["blitz"]})
	await process_frame
	check(bfree.actions_left == 2, "2 actions/turn at the default tier")
	bfree._use_item(0)
	check(bfree.item_targets.has(Vector2i(2, 2)) and not bfree.item_targets.has(Vector2i(0, 0)),
		"Blitz offers the un-moved queen but excludes the King")
	bfree._item_click(Vector2i(2, 2))
	check(bfree.items.is_empty() and bfree.actions_left == 2, "Blitz costs 0 actions to use")
	check(bfree.board[Vector2i(2, 2)].get("blitz_free_move", false),
		"Blitz marks the target's next move/capture as free")
	bfree._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(bfree.actions_left == 2, "the marked piece's move costs no action")
	check(not bfree.board[Vector2i(2, 3)].get("blitz_free_move", false),
		"the free-move flag is consumed by that one move")
	bfree.queue_free()
	await process_frame

	# an already-moved target: Blitz also lifts the one-move-per-piece lock,
	# and THAT second move is the free one
	var bt2 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "items": ["blitz"]})
	await process_frame
	bt2._move_player(Vector2i(2, 2), Vector2i(2, 3)) # spends the queen's move
	check(bt2.moved_this_turn.has(Vector2i(2, 3)) and bt2.actions_left == 1,
		"queen is spent for the turn, 1 action left")
	bt2._use_item(0)
	check(bt2.item_targets.has(Vector2i(2, 3)), "Blitz can target an already-moved piece too")
	bt2._item_click(Vector2i(2, 3))
	check(not bt2.moved_this_turn.has(Vector2i(2, 3)) and bt2.actions_left == 1,
		"Blitz lifts the one-move-per-piece lock, still costing nothing itself")
	bt2._move_player(Vector2i(2, 3), Vector2i(2, 4))
	check(bt2.actions_left == 1, "the second move is free — genuinely moved again for 0 actions")
	bt2.queue_free()
	await process_frame

	# the flag is scoped "this Turn" — it must not survive into the next one
	var bt3 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "items": ["blitz"]})
	await process_frame
	bt3._use_item(0)
	bt3._item_click(Vector2i(2, 2))
	check(bt3.board[Vector2i(2, 2)].get("blitz_free_move", false), "flag set this turn")
	bt3._begin_player_turn() # simulate the next player turn starting
	check(not bt3.board[Vector2i(2, 2)].get("blitz_free_move", false),
		"the free-move flag does not survive into a new turn")
	bt3.queue_free()
	await process_frame

	# --- 07-difficulty-ranks: Tier 5's -1 action/turn. The OLD Blitz refunded
	# its own action, so at 1 action/turn the first move alone spent the
	# turn's only action and auto-passed before Blitz's target filter (a
	# piece that already moved) was ever reachable — Blitz was functionally
	# dead at Tier 5. The rework fixes this by construction: Blitz itself is
	# free and its target's move is free too, so it must genuinely work here.
	GameScript.next_tier = "Tier 5"
	var bz := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "items": ["blitz"]})
	await process_frame
	check(bz.actions_left == 1, "Tier 5 grants exactly 1 action at turn start")
	bz._use_item(0) # Blitz on the un-moved queen
	bz._item_click(Vector2i(2, 2))
	check(bz.actions_left == 1 and bz.state == bz.State.PLAYER_TURN,
		"Blitz itself costs no action, even at Tier 5 — no auto-pass either")
	bz._move_player(Vector2i(2, 2), Vector2i(2, 3)) # the marked free move
	check(bz.actions_left == 1 and bz.state == bz.State.PLAYER_TURN,
		"the free move spends no action — the turn's only action is still there, no auto-pass")
	bz.queue_free()
	await process_frame
	GameScript.next_tier = Tuning.DEFAULT_TIER

	# --- fix (ruled 2026-08-28): the "5-Wave Milestone" is PER-ARTEFACT, not
	# the GLOBAL beat every held copy used to check (g.wave % 5 == 0). Each
	# held copy counts its own 5 waves from its own acquisition wave (stamped
	# on g.artefacts entries — ArtefactHooks._milestone5_hit) ---

	# core fix: two copies of the same artefact, acquired on different waves,
	# fire on DIFFERENT wave-clears — not in lockstep. Manna Vending Machine
	# (+2 Items per firing) makes each copy's own firing directly countable.
	var m5 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "artefacts": ["manna-vending-machine"]}) # copy A: acquired wave 1
	await process_frame
	for t in Items.ARTEFACT_EFFECTS: # copy B: acquired wave 3 (held from the
		if t.key == "manna-vending-machine": # start, same as two Shop buys on
			var copy_b: Dictionary = t.duplicate() # different waves would produce)
			copy_b.acquired_wave = 3
			m5.artefacts.append(copy_b)
			break
	check(m5.artefacts.size() == 2, "two held copies, acquired on different waves")
	for n in range(2, 6): # clear waves 1..4: neither copy is due yet
		WaveLogic.queue(m5, n)
	check(m5.items.size() == 0, "neither copy fires before its own beat 5 (waves 1-4 cleared)")
	WaveLogic.queue(m5, 6) # clears wave 5: copy A's beat 5 (1+4) — copy B's is wave 7 (3+4)
	check(m5.items.size() == 2, "only copy A (acquired wave 1) fires clearing wave 5")
	WaveLogic.queue(m5, 7) # clears wave 6: neither copy's beat
	check(m5.items.size() == 2, "no double-fire clearing wave 6")
	WaveLogic.queue(m5, 8) # clears wave 7: copy B's beat 5 (3+4)
	check(m5.items.size() == 4, "copy B (acquired wave 3) fires on its OWN beat, clearing wave 7 — not lockstepped with copy A")
	m5.queue_free()
	await process_frame

	# acquisition-wave stamping: every acquisition path stamps g.wave, and
	# never mutates the shared Items.ARTEFACT_EFFECTS catalog entry
	var catalog_entry: Dictionary
	for t in Items.ARTEFACT_EFFECTS:
		if t.key == "manna-vending-machine":
			catalog_entry = t
			break
	check(not catalog_entry.has("acquired_wave"),
		"the shared catalog entry itself is never stamped (each acquisition duplicates it)")

	# Shop buy
	var buyer := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 7, "gold": 99999})
	await process_frame
	buyer.actions_left = 5
	buyer.shop_stock.append({"kind": "artefact", "key": "manna-vending-machine", "sold": false})
	Shop.buy(buyer, buyer.shop_stock.size() - 1)
	check(buyer.artefacts.size() == 1 and buyer.artefacts[0].acquired_wave == 7,
		"Shop buy stamps acquired_wave to the current wave")
	check(buyer.artefacts[0].rarity == "Common", # issue 29
		"Shop buy stamps rarity from the catalog (Manna Vending Machine: Common)")
	buyer.queue_free()
	await process_frame

	# Box pick
	var boxer := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 9})
	await process_frame
	boxer._box_choose({"kind": "artefact", "name": "x", "description": "x", "payload": catalog_entry})
	check(boxer.artefacts.size() == 1 and boxer.artefacts[0].acquired_wave == 9,
		"Box pick stamps acquired_wave to the current wave")
	check(boxer.artefacts[0].rarity == "Common", # issue 29
		"Box pick stamps rarity from the catalog (Manna Vending Machine: Common)")
	boxer.queue_free()
	await process_frame

	# save/load round-trip: each held copy's own acquired_wave AND rarity survive
	var saver := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "artefacts": ["manna-vending-machine"]})
	await process_frame
	for t in Items.ARTEFACT_EFFECTS:
		if t.key == "manna-vending-machine":
			var b2: Dictionary = t.duplicate()
			b2.acquired_wave = 3
			saver.artefacts.append(b2)
			break
	var m5_cfg: Dictionary = saver._to_config()
	saver.queue_free()
	await process_frame
	var m5_restored := _boot(JSON.parse_string(JSON.stringify(m5_cfg)))
	await process_frame
	var restored_waves: Array = []
	for t in m5_restored.artefacts:
		restored_waves.append(int(t.acquired_wave))
		check(t.rarity == "Common", "save -> load preserves rarity (issue 29)") # issue 29
	restored_waves.sort()
	check(restored_waves == [1, 3],
		"save -> load preserves each held copy's own acquired_wave (%s)" % [restored_waves])
	m5_restored.queue_free()
	await process_frame

	# --- issue 29: runtime rarity metadata — an old save's artefact entries
	# predate the `rarity` field ({key, acquired_wave} only, no `rarity` key)
	# — apply() must not crash and must degrade to a fresh catalog lookup
	# (ArtefactHooks.rarity_of), not treat the copy as unrated
	var old_save := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "artefacts": [{"key": "manna-vending-machine", "acquired_wave": 2}]})
	await process_frame
	check(old_save.artefacts.size() == 1 and old_save.artefacts[0].rarity == "Common",
		"an old save entry with no `rarity` key degrades to the catalog lookup, not a crash")
	old_save.queue_free()
	await process_frame

	# --- issue 29: Illuminati Fridge Magnet — "+50% Gold gain" while holding
	# an Artefact of every rarity (Common/Uncommon/Rare/Legendary). Rare is
	# the Fridge Magnet itself; the other three are picked for hooks that
	# never touch on_gold_change/on_score_change, so Economy.earn's result
	# isolates the Fridge Magnet's own bonus.
	var partial := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3,
		"artefacts": ["illuminati-fridge-magnet", "fema-summer-camp-flyer", # Rare + Common
			"putin-s-golden-toilet-brush"]}) # + Uncommon — no Legendary yet
	await process_frame
	check(not ArtefactHooks.holds_every_rarity(partial),
		"three of four rarities held (Legendary missing): holds_every_rarity is false")
	Economy.earn(partial, 100)
	check(partial.gold == 100, "Illuminati Fridge Magnet withholds its bonus until every rarity is held")
	partial.queue_free()
	await process_frame

	var all_rarities := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3,
		"artefacts": ["illuminati-fridge-magnet", "fema-summer-camp-flyer",
			"putin-s-golden-toilet-brush", "cia-exploding-cigar"]}) # Rare/Common/Uncommon/Legendary
	await process_frame
	check(ArtefactHooks.holds_every_rarity(all_rarities),
		"all four rarities held: holds_every_rarity is true")
	Economy.earn(all_rarities, 100)
	check(all_rarities.gold == 150, "Illuminati Fridge Magnet: +50% Gold gain once every rarity is held")
	all_rarities.queue_free()
	await process_frame

	# --- issue 31: capture-context effects ---

	# Curtain Rods Bag: first Capture each Wave doubles Score and pays no
	# Gold; later Captures the same Wave are unaffected (pawn value 10)
	var crb := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 3], ["pawn", 1, 2, 4],
		["rook", 1, 7, 10]], "wave": 3, "score": 0, "gold": 0,
		"artefacts": ["curtain-rods-bag-rifle-shaped"]})
	await process_frame
	crb.actions_left = 5
	crb._move_player(Vector2i(2, 2), Vector2i(2, 3)) # first Capture this Wave
	check(crb.score == 20 and crb.gold == 0,
		"Curtain Rods Bag: first Capture each Wave doubles Score (10 -> 20) and pays no Gold")
	crb._move_player(Vector2i(2, 3), Vector2i(2, 4)) # second Capture this Wave
	check(crb.score == 30 and crb.gold == 10,
		"Curtain Rods Bag: the second Capture the same Wave pays normally")
	crb.queue_free()
	await process_frame

	# Templar Debit Card: pay Shop costs with Score, 10 Score per 1 Gold, for
	# whatever Gold can't cover
	var tdc := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "score": 100, "gold": 5, "artefacts": ["templar-debit-card"]})
	await process_frame
	tdc.shop_stock.append({"kind": "piece", "key": "pawn", "sold": false}) # 10 Gold
	check(Shop.can_buy(tdc, tdc.shop_stock[-1]),
		"Templar Debit Card: Score covers what 5 Gold can't of a 10-Gold pawn")
	Shop.buy(tdc, tdc.shop_stock.size() - 1)
	check(tdc.gold == 0 and tdc.score == 50,
		"Templar Debit Card: the Gold-uncovered remainder (5) debits as Score at 10:1 (-50)")
	tdc.queue_free()
	await process_frame

	var tdc_no := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "score": 100, "gold": 5})
	await process_frame
	tdc_no.shop_stock.append({"kind": "piece", "key": "pawn", "sold": false})
	check(not Shop.can_buy(tdc_no, tdc_no.shop_stock[-1]),
		"without the card, Score alone can't cover a Gold shortfall")
	tdc_no.queue_free()
	await process_frame

	# $2.3 Trillion Receipt: enemies destroyed by Items award their Score and
	# Gold value; non-Item destruction (Bomb/Tariff) still pays nothing
	var receipt := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 4, 4], ["pawn", 1, 5, 5],
		["rook", 1, 7, 10]], "wave": 3, "score": 0, "gold": 0,
		"artefacts": ["2-3-trillion-receipt"]})
	await process_frame
	receipt._destroy(Vector2i(4, 4), true) # Item-caused (Drone Strike/Air Strike/Sniper)
	check(receipt.score == 10 and receipt.gold == 10,
		"$2.3 Trillion Receipt: an enemy destroyed by an Item awards its Score and Gold value")
	receipt._destroy(Vector2i(5, 5)) # not Item-caused (Bomb's _detonate / jd_vance Tariff path)
	check(receipt.score == 10 and receipt.gold == 10,
		"$2.3 Trillion Receipt: non-Item destruction still pays nothing (Destruction default)")
	receipt.queue_free()
	await process_frame

	var no_receipt := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 4, 4], ["rook", 1, 7, 10]],
		"wave": 3, "score": 0, "gold": 0})
	await process_frame
	no_receipt._destroy(Vector2i(4, 4), true)
	check(no_receipt.score == 0 and no_receipt.gold == 0,
		"without the artefact, an Item-destroyed enemy still pays nothing")
	no_receipt.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL ITEM CHECKS OK")
	quit(1 if fails > 0 else 0)
