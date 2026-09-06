extends SceneTree
## Item behavior + review-regression coverage (2026-07-03 code review):
## merge-selection survives item removal, and the core item abilities
## (promote/invert/rapid-deployment/radar-jamming/drone-strike/extraction/
## merge/demote). Split from the former monolithic test_items.gd (issue 37) —
## tariff-flavored item behavior lives in test_items_tariffs.gd, Piece Buffs
## in test_items_buffs.gd, artefacts in test_items_artefacts_*.gd.
## Run headless:  godot --headless --path game -s tests/test_items.gd

const GameScript := preload("res://scripts/game.gd")
const MergeLogic := preload("res://scripts/merge_logic.gd")
const Rules := preload("res://scripts/rules.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")
const ItemLogic := preload("res://scripts/item_logic.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")
const Shop := preload("res://scripts/shop.gd")
const Economy := preload("res://scripts/economy.gd")

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
	# --- review bug 1 (reworked for buttonless merging): removing a selected
	# piece with an item must drop the selection, not leave a stale board ref
	var a := _boot({"board": [["pawn", 0, 2, 2], ["pawn", 0, 3, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 300}) # issue 98: merge highlights are gated on being
			# able to AFFORD the merge, so an unfunded board shows none
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

	# --- radar jamming: only pieces carrying an actual Piece Buff are valid
	# targets; jamming strips them (issue 47: the legacy box-carrier flag
	# this item also used to strip is gone — see test_items_buffs.gd for the
	# "strips piece buffs" assertion in isolation)
	var h := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 5],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	BuffLogic.add(h.board[Vector2i(3, 5)], "shield")
	h.items.append(_item("radar_jamming", "tile"))
	h._use_item(0)
	check(h.item_targets.size() == 1 and h.item_targets.has(Vector2i(3, 5)),
		"radar jamming targets only buffed pieces")
	h._item_click(Vector2i(3, 5))
	check(BuffLogic.of(h.board[Vector2i(3, 5)]).is_empty(),
		"radar jamming strips the piece buff")
	h.queue_free()
	await process_frame

	# --- drone strike: 3x3 destruction around the confirmed anchor; the King
	# survives; destruction is not capture (CONTEXT.md: Destruction)
	var ds := _boot({"board": [["queen", 0, 0, 1], ["pawn", 1, 3, 5], ["bishop", 1, 2, 4],
		["pawn", 0, 4, 6], ["king", 1, 3, 4], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["voynich-dictionary", "library-of-alexandria-matchbox"], "score": 100})
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
	var em := _boot({"board": [["rook", 1, 7, 10]], "wave": 3, "stock": ["pawn"], "gold": 300})
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

	# --- Item held capacity (issue 53, user ruling): base 3, unbounded before
	# this. ItemLogic.grant() is the single choke point every acquisition path
	# (Box pick, Artefact grant, Yalta's own pick, Shop purchase) now routes
	# new Items through — a full inventory REFUSES the grant (drops it), the
	# simpler of the two options and the one that matches "capacity".
	var ic := _boot({"board": [["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	for i in 3:
		check(ItemLogic.grant(ic, _item("blitz", "tile")),
			"Item %d/3 lands under the base cap" % (i + 1))
	check(ic.items.size() == 3, "base Item capacity is 3")
	check(not ItemLogic.grant(ic, _item("blitz", "tile")),
		"a 4th Item is refused at the base cap — the cap genuinely binds")
	check(ic.items.size() == 3, "the refused grant did not land")
	ic.artefacts.append({"key": "area-51-parking-permit"})
	check(ItemLogic.grant(ic, _item("blitz", "tile")),
		"Area 51 Parking Permit raises the cap (+3, to 6) — the 4th now lands")
	check(ic.items.size() == 4, "the Item actually landed")
	ic.queue_free()
	await process_frame

	# --- the Shop must never sell an Item slot the player has no room to hold
	var sh := _boot({"board": [["rook", 1, 7, 10]], "wave": 3, "gold": 100})
	await process_frame
	sh.state = sh.State.PLAYER_TURN
	sh.actions_left = 2
	for i in 3:
		sh.items.append(_item("blitz", "tile")) # at the base cap already
	var item_slot := {"kind": "item", "key": "blitz", "sold": false}
	sh.shop_stock = [item_slot]
	check(not Shop.can_buy(sh, item_slot), "a full inventory can't buy an Item slot")
	sh.artefacts.append({"key": "area-51-parking-permit"})
	check(Shop.can_buy(sh, item_slot),
		"Area 51 Parking Permit's +3 cap reopens the Item slot")
	sh.queue_free()
	await process_frame

	# --- Artefact held capacity (issue 60, user ruling): base 5, unbounded
	# before this. ArtefactHooks.grant() is the single choke point every
	# acquisition path (Box pick, Shop purchase) now routes new Artefacts
	# through — same "capacity refuses" shape as ItemLogic.grant above.
	# Duplicate copies each take a slot: 5 total is 5 copies of anything.
	var ac := _boot({"board": [["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	for i in 5:
		check(ArtefactHooks.grant(ac, {"key": "library-of-alexandria-matchbox", "name": "Library of Alexandria Matchbox",
				"rarity": "Rare", "description": "On Capture: +1 Gold and +10 Score per piece in your Stock."}),
			"Artefact %d/5 lands under the base cap" % (i + 1))
	check(ac.artefacts.size() == 5, "base Artefact capacity is 5")
	check(not ArtefactHooks.grant(ac, {"key": "library-of-alexandria-matchbox", "name": "Library of Alexandria Matchbox",
			"rarity": "Rare", "description": "On Capture: +1 Gold and +10 Score per piece in your Stock."}),
		"a 6th Artefact is refused at the cap of 5 — the cap genuinely binds")
	check(ac.artefacts.size() == 5, "the refused grant did not land")
	ac.queue_free()
	await process_frame

	# --- the Shop must never sell an Artefact slot the player has no room to
	# hold — Shop.can_buy mirrors the Item precedent above (issue 53/60).
	var ash := _boot({"board": [["rook", 1, 7, 10]], "wave": 3, "gold": 1000})
	await process_frame
	ash.state = ash.State.PLAYER_TURN
	ash.actions_left = 2
	for i in 5:
		ash.artefacts.append({"key": "library-of-alexandria-matchbox", "name": "Library of Alexandria Matchbox",
			"rarity": "Rare", "description": "On Capture: +1 Gold and +10 Score per piece in your Stock."}) # at the cap already
	var artefact_slot := {"kind": "artefact", "key": "voynich-dictionary", "sold": false}
	ash.shop_stock = [artefact_slot]
	check(not Shop.can_buy(ash, artefact_slot), "a full Artefact inventory can't buy an Artefact slot")
	ash.queue_free()
	await process_frame

	# --- issue 60: Box picks refuse an Artefact at the cap too (_box_choose
	# routes through ArtefactHooks.grant, mirroring the Item pick above) — the
	# pick is spent either way, but nothing lands.
	var abx := _boot({"board": [["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	for i in 5:
		abx.artefacts.append({"key": "library-of-alexandria-matchbox", "name": "Library of Alexandria Matchbox",
			"rarity": "Rare", "description": "On Capture: +1 Gold and +10 Score per piece in your Stock."})
	var artefact_payload := {"key": "voynich-dictionary", "name": "Voynich Dictionary",
		"description": "On your first Capture each Wave: double Score and Gold."}
	abx._box_choose({"kind": "artefact", "name": "x", "description": "x", "payload": artefact_payload})
	check(abx.artefacts.size() == 5,
		"a Box-picked Artefact is refused at the cap of 5, same as a full Item pick")
	abx.queue_free()
	await process_frame

	# --- Denver Bunker Timeshare: "+30% Gold gain while all your Item slots
	# are full" — item_logic.gd's cap() (issue 53) is what makes "full" a
	# reachable condition at all; before this slice there was no cap to fill.
	var db := _boot({"board": [["rook", 1, 7, 10]], "wave": 3,
		"artefacts": ["denver-bunker-timeshare"]})
	await process_frame
	db.gold = 0
	Economy.earn(db, 100)
	check(db.gold == 100, "Item slots not full: no bonus")
	for i in 2:
		db.items.append(_item("blitz", "tile")) # fills 2/3 of the base cap
	db.items.append({"key": "blitz", "name": "Blitz", "tier": "Tactical", "target": "tile",
		"description": ""}) # a real-tier catalog shape — this is the one sold below
	db.gold = 0
	Economy.earn(db, 100)
	check(db.gold == 130, "Item slots full: +30% Gold gain")
	# issue 60: SELLING an Item drops the slot count below full and turns the
	# bonus off — the sale that empties the last slot must NOT itself collect
	# the bonus (the erase in _sell() happens BEFORE the Gold-gain dispatch).
	db.state = db.State.PLAYER_TURN
	db.actions_left = 5
	var sell_price: int = Shop.sell_price(db, "item", db.items[2])
	var db_gold_before: int = db.gold
	db._sell("item", db.items[2])
	check(db.items.size() == 2 and db.gold == db_gold_before + sell_price,
		"Item slots no longer full: selling the Item that empties the last slot pays the plain sell price, no +30%")
	db.queue_free()
	await process_frame


	# --- review pass 1: Rapid Deployment's stage B is exactly the Deploy tile
	# set (guard for computing it once instead of once per candidate tile)
	var rd_board := {Vector2i(2, 1): {"id": "pawn", "owner": Rules.PLAYER},
		Vector2i(5, 9): {"id": "rook", "owner": Rules.ENEMY}}
	var rd_defs := Rules.load_pieces()
	check(ItemLogic.stage_targets(rd_board, rd_defs, "rapid_deployment", Vector2i(2, 1))
			== Rules.placement_tiles(rd_board),
		"Rapid Deployment stage B is exactly the Deploy tile set")

	print("---")
	if fails == 0:
		print("ALL ITEM CHECKS OK")
	quit(1 if fails > 0 else 0)
