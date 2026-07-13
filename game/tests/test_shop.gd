extends SceneTree
## The Shop: 19-slot randomized stock (3 lootboxes / 4 trinkets / 4 items /
## 8 distinct base pieces), priced in money, purchases cost 1 action, bought
## slots go SOLD. Pure logic in scripts/shop.gd over the live game node.
## Run headless:  godot --headless --path game -s tests/test_shop.gd

const GameScript := preload("res://scripts/game.gd")
const Shop := preload("res://scripts/shop.gd")
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
	check(game.shop_stock.size() == 19, "a run boots with a rolled 19-slot shop")
	check(kinds.get("box", 0) == 3 and kinds.get("trinket", 0) == 4
			and kinds.get("item", 0) == 4 and kinds.get("piece", 0) == 8,
		"rows: 3 lootboxes / 4 trinkets / 4 items / 8 base pieces")

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

	# prices: piece = catalog value, item by tier, trinket/box flat
	var priced_ok := true
	for slot in game.shop_stock:
		var want: int
		match slot.kind:
			"piece":
				want = int(game.defs[slot.key].value)
			"item":
				want = Tuning.SHOP_ITEM_PRICE[Items.ITEMS.filter(
					func(it: Dictionary) -> bool: return it.key == slot.key)[0].tier]
			"trinket":
				want = Tuning.SHOP_TRINKET_PRICE
			_:
				want = Tuning.SHOP_BOX_PRICE
		priced_ok = priced_ok and Shop.price(game, slot) == want
	check(priced_ok, "every slot prices by its row's rule")

	# purchases: money + one action, slot goes SOLD, the piece lands in stock
	var pi := -1
	for i in game.shop_stock.size():
		if game.shop_stock[i].kind == "piece":
			pi = i
			break
	var slot: Dictionary = game.shop_stock[pi]
	var cost: int = Shop.price(game, slot)
	var s0: int = game.score
	game.actions_left = 2
	game.money = cost - 1
	check(not Shop.can_buy(game, slot), "short on money -> not buyable")
	game.money = cost
	game.actions_left = 0
	check(not Shop.can_buy(game, slot), "no actions left -> not buyable")
	game.actions_left = 2
	check(Shop.can_buy(game, slot), "affordable + an action -> buyable")
	var stock_n: int = game.stock.size()
	Shop.buy(game, pi)
	check(game.money == 0 and game.actions_left == 1,
		"buying debits the price and one action")
	check(game.shop_stock[pi].sold, "a bought slot is SOLD")
	check(game.stock.size() == stock_n + 1 and game.stock.back() == slot.key,
		"the piece lands in stock")
	check(not Shop.can_buy(game, slot), "a SOLD slot is not buyable")
	Shop.buy(game, pi)
	check(game.stock.size() == stock_n + 1, "buying a SOLD slot is a no-op")
	check(game.score == s0, "shopping never touches score")

	# items and trinkets are purchasable (05)
	game.money = 9999
	game.actions_left = 4
	var ii := -1
	var ti := -1
	var bi := -1
	for i in game.shop_stock.size():
		match game.shop_stock[i].kind:
			"item":
				ii = i
			"trinket":
				ti = i
			"box":
				bi = i
	var items_n: int = game.items.size()
	Shop.buy(game, ii)
	check(game.items.size() == items_n + 1
			and game.items.back().key == game.shop_stock[ii].key,
		"a bought item joins the held items")
	game.trinkets.append(Items.TRINKET_EFFECTS.filter(func(t: Dictionary) -> bool:
		return t.key == game.shop_stock[ti].key)[0]) # pre-own one copy: stacks?
	Shop.buy(game, ti)
	check(game.trinkets.size() == 2 and game.trinkets.back().key == game.shop_stock[ti].key,
		"a bought trinket applies immediately and stacks")
	check(game.shop_stock[ii].sold and game.shop_stock[ti].sold,
		"item and trinket slots go SOLD")
	check(game.actions_left == 2, "each purchase cost one action")
	game._refresh()
	check(game.hud.item_box.get_child_count() == game.items.size(),
		"bought items show in the Inventory drawer strip")
	check(game.hud.drawer_buttons["inventory"].text == "Inventory %d"
			% (game.items.size() + game.trinkets.size()),
		"the Inventory count includes both purchases")

	# lootboxes (06): buying debits and opens the 3-option roll right away
	game.money = 100
	game.actions_left = 2
	game._open_shop()
	game.modals.shop_buy_pressed.emit(bi)
	check(game.shop_stock[bi].sold, "the box slot goes SOLD")
	check(game.money == 100 - Tuning.SHOP_BOX_PRICE and game.actions_left == 1,
		"a box costs its price + one action")
	check(game.box_open and not game.modals.shop_panel.visible,
		"buying a box opens the roll modal over a closed shop")
	var sc0: int = game.score
	var mo0: int = game.money
	game.modals.box_chosen.emit({"kind": "score", "name": "+50 score",
		"value": 50, "description": ""})
	check(game.score == sc0 + 50 and game.money == mo0 + 50,
		"a rolled score option earns raw score + money")
	check(not game.box_open, "the pick closes the roll modal")

	game.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL SHOP CHECKS OK")
	quit(1 if fails > 0 else 0)
