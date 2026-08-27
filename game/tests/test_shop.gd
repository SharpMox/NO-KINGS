extends SceneTree
## The Shop: 22-slot randomized stock (6 typed boxes / 4 artefacts / 4 items /
## 8 distinct base pieces), priced in gold, purchases cost 1 action, bought
## slots go SOLD. Restocks on cumulative-score thresholds (GDD Shop page).
## Pure logic in scripts/shop.gd over the live game node.
## Run headless:  godot --headless --path game -s tests/test_shop.gd

const GameScript := preload("res://scripts/game.gd")
const Shop := preload("res://scripts/shop.gd")
const Box := preload("res://scripts/box.gd")
const Economy := preload("res://scripts/economy.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Items := preload("res://data/items.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _init() -> void:
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3}
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame

	var kinds := {}
	for slot in game.shop_stock:
		kinds[slot.kind] = kinds.get(slot.kind, 0) + 1
	check(game.shop_stock.size() == 22, "a run boots with a rolled 22-slot shop")
	check(kinds.get("box", 0) == 6 and kinds.get("artefact", 0) == 4
			and kinds.get("item", 0) == 4 and kinds.get("piece", 0) == 8,
		"rows: 6 boxes / 4 artefacts / 4 items / 8 base pieces")

	# boxes are typed, 2 of each (GDD Shop page: 2 Item / 2 Artefact / 2 Score)
	var box_types := {}
	for slot in game.shop_stock:
		if slot.kind == "box":
			box_types[slot.key] = box_types.get(slot.key, 0) + 1
	check(box_types == {"item": 2, "artefact": 2, "score": 2},
		"the box row is typed 2 Item / 2 Artefact / 2 Score")
	check(Shop.display_name(game, {"kind": "box", "key": "score"}) == "Score Box",
		"a typed box names its type")

	# a typed box rolls only its own kind
	var score_opts := Box.roll_options(game.rng, "score")
	check(score_opts.size() == 3 and score_opts.all(func(o: Dictionary) -> bool:
			return o.kind == "score"),
		"a Score Box rolls score options only")
	check(Box.roll_options(game.rng, "item").all(func(o: Dictionary) -> bool:
			return o.kind == "item"),
		"an Item Box rolls item options only")
	check(Box.roll_options(game.rng).size() == 3,
		"an untyped roll still mixes kinds (Box Pick path)")

	# pool rules: merge-chain roots minus the King and inversion pieces
	var pool: Array = Shop.base_piece_pool(game.defs)
	check(not pool.has("king"), "the King is never on the shelf")
	check(pool.filter(func(id: String) -> bool:
			return id.begins_with("inv-")).is_empty(),
		"inversion pieces are never on the shelf")
	check(pool.has("pawn") and pool.has("amazonrider"),
		"the pool spans cheap to heavy chain roots")

	# 8 distinct piece slots; 1/value weighting keeps heavies rare
	game.rng.seed = 7 # deterministic census
	var dupes := 0
	var pawn_n := 0
	var heavy_n := 0
	for i in 300:
		Shop.roll(game)
		var seen := {}
		for slot in game.shop_stock:
			if slot.kind == "piece":
				if seen.has(slot.key):
					dupes += 1
				seen[slot.key] = true
				pawn_n += 1 if slot.key == "pawn" else 0
				heavy_n += 1 if slot.key == "amazonrider" else 0
	check(dupes == 0, "piece slots are always 8 distinct picks")
	check(pawn_n > heavy_n * 2 and heavy_n > 0,
		"1/value weighting: pawns common, amazonriders rare but possible (%d vs %d)"
			% [pawn_n, heavy_n])

	# prices: piece = catalog value, item by tier, artefact/box flat
	var priced_ok := true
	for slot in game.shop_stock:
		var want: int
		match slot.kind:
			"piece":
				want = int(game.defs[slot.key].value)
			"item":
				want = Tuning.SHOP_ITEM_PRICE[Items.ITEMS.filter(
					func(it: Dictionary) -> bool: return it.key == slot.key)[0].tier]
			"artefact":
				want = Tuning.SHOP_ARTEFACT_PRICE
			_:
				want = Tuning.SHOP_BOX_PRICE
		priced_ok = priced_ok and Shop.price(game, slot) == want
	check(priced_ok, "every slot prices by its row's rule")

	# purchases: gold + one action, slot goes SOLD, the piece lands in stock
	var pi := -1
	for i in game.shop_stock.size():
		if game.shop_stock[i].kind == "piece":
			pi = i
			break
	var slot: Dictionary = game.shop_stock[pi]
	var cost: int = Shop.price(game, slot)
	var s0: int = game.score
	game.actions_left = 2
	game.gold = cost - 1
	check(not Shop.can_buy(game, slot), "short on gold -> not buyable")
	game.gold = cost
	game.actions_left = 0
	check(not Shop.can_buy(game, slot), "no actions left -> not buyable")
	game.actions_left = 2
	check(Shop.can_buy(game, slot), "affordable + an action -> buyable")
	var stock_n: int = game.stock.size()
	Shop.buy(game, pi)
	check(game.gold == 0 and game.actions_left == 1,
		"buying debits the price and one action")
	check(game.shop_stock[pi].sold, "a bought slot is SOLD")
	check(game.stock.size() == stock_n + 1 and game.stock.back() == slot.key,
		"the piece lands in stock")
	check(not Shop.can_buy(game, slot), "a SOLD slot is not buyable")
	Shop.buy(game, pi)
	check(game.stock.size() == stock_n + 1, "buying a SOLD slot is a no-op")
	check(game.score == s0, "shopping never touches score")

	# items and artefacts are purchasable (05)
	game.gold = 9999
	game.actions_left = 4
	var ii := -1
	var ti := -1
	var bi := -1
	for i in game.shop_stock.size():
		match game.shop_stock[i].kind:
			"item":
				ii = i
			"artefact":
				ti = i
			"box":
				bi = i
	var items_n: int = game.items.size()
	Shop.buy(game, ii)
	check(game.items.size() == items_n + 1
			and game.items.back().key == game.shop_stock[ii].key,
		"a bought item joins the held items")
	game.artefacts.append(Items.ARTEFACT_EFFECTS.filter(func(t: Dictionary) -> bool:
		return t.key == game.shop_stock[ti].key)[0]) # pre-own one copy: stacks?
	Shop.buy(game, ti)
	check(game.artefacts.size() == 2 and game.artefacts.back().key == game.shop_stock[ti].key,
		"a bought artefact applies immediately and stacks")
	check(game.shop_stock[ii].sold and game.shop_stock[ti].sold,
		"item and artefact slots go SOLD")
	check(game.actions_left == 2, "each purchase cost one action")
	game._refresh()
	check(game.hud.item_box.get_child_count() == game.items.size(),
		"bought items show in the Inventory drawer strip")
	check(game.hud.drawer_buttons["inventory"].text == "Inventory %d"
			% (game.items.size() + game.artefacts.size()),
		"the Inventory count includes both purchases")

	# lootboxes (06): buying debits and opens the 3-option roll right away
	game.gold = 100
	game.actions_left = 2
	game._open_shop()
	game.modals.shop_buy_pressed.emit(bi)
	check(game.shop_stock[bi].sold, "the box slot goes SOLD")
	check(game.gold == 100 - Tuning.SHOP_BOX_PRICE and game.actions_left == 1,
		"a box costs its price + one action")
	check(game.box_open and not game.modals.shop_panel.visible,
		"buying a box opens the roll modal over a closed shop")
	var sc0: int = game.score
	var mo0: int = game.gold
	game.modals.box_chosen.emit({"kind": "score", "name": "+50 score",
		"value": 50, "description": ""})
	check(game.score == sc0 + 50 and game.gold == mo0 + 50,
		"a rolled score option earns raw score + gold")
	check(not game.box_open, "the pick closes the roll modal")

	# restock cadence: cumulative score thresholds, not waves (GDD Shop page).
	# Thresholds are 1000 / 2500 / 4500 / 7000 — the gap grows 500 each time.
	check(Shop.threshold(0) == 1000 and Shop.threshold(1) == 2500
			and Shop.threshold(2) == 4500 and Shop.threshold(3) == 7000,
		"thresholds step 1000 / 2500 / 4500 / 7000")

	var before := JSON.stringify(game.shop_stock)
	game._queue_wave(10)
	check(JSON.stringify(game.shop_stock) == before,
		"the 10-wave milestone no longer rerolls the shop")

	game.score = 0
	game.shop_restocks = 0
	Economy.earn(game, 999)
	check(JSON.stringify(game.shop_stock) == before and game.shop_restocks == 0,
		"score below the threshold leaves the stock alone")
	Economy.earn(game, 1)
	check(JSON.stringify(game.shop_stock) != before, "crossing 1000 restocks")
	check(game.shop_restocks == 1, "the restock counter advances")
	check(game.shop_stock.filter(func(sl: Dictionary) -> bool:
			return sl.sold).is_empty(),
		"a restock clears every SOLD flag")
	check(game.shop_stock.size() == 22, "a restock refills all 22 slots")

	# one gain crossing several thresholds restocks once, not once per threshold
	game.score = 0
	game.shop_restocks = 0
	Economy.earn(game, 5000)
	check(game.shop_restocks == 3,
		"a single huge gain banks every threshold it crossed (next: 7000)")

	game.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL SHOP CHECKS OK")
	quit(1 if fails > 0 else 0)
