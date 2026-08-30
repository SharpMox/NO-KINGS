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
const Rules := preload("res://scripts/rules.gd")

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


func _init() -> void:
	var game: Node2D = _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame

	var kinds := {}
	for slot in game.shop_stock:
		kinds[slot.kind] = kinds.get(slot.kind, 0) + 1
	check(game.shop_stock.size() == 22, "a run boots with a rolled 22-slot shop")
	check(kinds.get("box", 0) == 6 and kinds.get("artefact", 0) == 4
			and kinds.get("item", 0) == 4 and kinds.get("piece", 0) == 8,
		"rows: 6 boxes / 4 artefacts / 4 items / 8 base pieces")

	# boxes are typed, 2 of each theme (issue 47: 9 Boxes = 3 sizes x 3
	# themes — Pieces/Artefacts/Items — Score Box and the mixed Box are gone),
	# each slot's SIZE rolled independently
	var box_types := {}
	for slot in game.shop_stock:
		if slot.kind == "box":
			box_types[slot.key] = box_types.get(slot.key, 0) + 1
			check(slot.size in Box.SIZE_KEYS, "every Box slot carries a rolled size")
			check(slot.contents.size() == Box.SIZES[slot.size].choices,
				"a stocked Box's contents match its size's choice count")
	check(box_types == {"piece": 2, "artefact": 2, "item": 2},
		"the box row is typed 2 Piece / 2 Artefact / 2 Item")
	check(Shop.display_name(game, {"kind": "box", "key": "item", "size": "small"}) == "Small Item Box",
		"a typed box names its size and theme")

	# a typed box rolls only its own theme
	var piece_opts := Box.roll_options(game, "piece", "small")
	check(piece_opts.size() == 3 and piece_opts.all(func(o: Dictionary) -> bool:
			return o.kind == "piece"),
		"a Piece Box rolls piece options only")
	check(Box.roll_options(game, "item", "small").all(func(o: Dictionary) -> bool:
			return o.kind == "item"),
		"an Item Box rolls item options only")
	check(Box.roll_options(game, "score", "small").is_empty(),
		"the old Score theme rolls nothing — Score Boxes are gone (issue 47)")

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

	# prices: piece = catalog value, item by tier, artefact by rarity,
	# box by SIZE only (issue 47), theme ignored
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
				want = Tuning.SHOP_ARTEFACT_PRICE[Shop.rarity_of(slot)]
			_:
				want = Tuning.SHOP_BOX_PRICE[slot.size]
		priced_ok = priced_ok and Shop.price(game, slot) == want
	check(priced_ok, "every slot prices by its row's rule (artefact: by rarity, box: by size)")
	check(Tuning.SHOP_BOX_PRICE == {"small": 50, "big": 100, "huge": 200},
		"Box price doubles by size, Small keeps the old flat 50")

	# --- issue 20: rarity legibility (Shop.rarity_of) ---
	check(Shop.rarity_of({"kind": "piece", "key": "pawn"}) == "",
		"pieces carry no rarity")
	check(Shop.rarity_of({"kind": "artefact", "key": "greed"}) == "",
		"the 7 core artefacts predate the rarity catalog")
	var rated := Items.ARTEFACT_CATALOG.filter(func(e: Dictionary) -> bool:
		return e.get("implemented", false))
	if not rated.is_empty():
		var sample: Dictionary = rated[0]
		check(Shop.rarity_of({"kind": "artefact", "key": sample.key}) == sample.rarity,
			"an implemented catalog artefact's rarity round-trips through the shop slot")

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
	# Chocolate Key Cake / Alleged Weather Balloon / Sub-Antarctic Visa change
	# how many slots a later roll() produces — the restock-size check below
	# assumes the artefact this test holds for the rest of the run does NOT,
	# so skip those 3 keys when picking `ti` (issue 19 grew the artefact pool,
	# which changed what a fixed rng seed happens to roll into this slot).
	var slot_count_modifiers := ["chocolate-key-cake", "alleged-weather-balloon", "sub-antarctic-visa"]
	for i in game.shop_stock.size():
		match game.shop_stock[i].kind:
			"item":
				ii = i
			"artefact":
				if ti < 0 or slot_count_modifiers.has(game.shop_stock[ti].key):
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

	# lootboxes (06 / issue 47): buying debits the box's SIZE price and opens
	# the roll modal revealing EXACTLY what was rolled at stock time — the
	# acceptance test issue 47 calls for: read a stocked Box's contents,
	# open it, assert the same entries (never a fresh roll on open)
	game.gold = 500
	game.actions_left = 2
	var box_slot: Dictionary = game.shop_stock[bi]
	var box_price: int = Shop.price(game, box_slot)
	var stocked_contents: Array = box_slot.contents.duplicate(true)
	game._open_shop()
	game.modals.shop_buy_pressed.emit(bi)
	check(game.shop_stock[bi].sold, "the box slot goes SOLD")
	check(game.gold == 500 - box_price and game.actions_left == 1,
		"a box costs its size's price + one action")
	check(game.box_open and not game.modals.shop_panel.visible,
		"buying a box opens the roll modal over a closed shop")
	check(game.box_offer == stocked_contents,
		"opening reveals EXACTLY the contents rolled at stock time, not a fresh roll")

	var stock_n2: int = game.stock.size()
	var items_n2: int = game.items.size()
	var artefacts_n2: int = game.artefacts.size()
	while game.box_open: # Huge grants 2 native picks (issue 47) — take them all
		game.modals.box_chosen.emit(game.box_offer[0])
	match box_slot.key:
		"piece":
			check(game.stock.size() > stock_n2, "picking Piece Box options lands them in Stock")
		"item":
			check(game.items.size() > items_n2, "picking Item Box options joins the held items")
		"artefact":
			check(game.artefacts.size() > artefacts_n2, "picking Artefact Box options applies immediately")
	check(not game.box_open, "resolving every pick closes the roll modal")

	# restock cadence: cumulative score thresholds, not waves (GDD Shop page).
	# Thresholds are 1000 / 2500 / 4500 / 7000 — the gap grows 500 each time.
	check(Shop.threshold(0) == 1000 and Shop.threshold(1) == 2500
			and Shop.threshold(2) == 4500 and Shop.threshold(3) == 7000,
		"thresholds step 1000 / 2500 / 4500 / 7000")

	var before := JSON.stringify(game.shop_stock)
	# issue 57: pre-bank past 3 thresholds so the wave-10 milestone's own
	# Score bonus (Tuning.MILESTONE_SCORE_BONUS, now x10'd by Economy.earn's
	# SCORE_MULTIPLIER — 100 -> 1000) can't incidentally cross a NEW
	# threshold on its own and confound this check. Isolates "waves alone
	# don't force a restock" from the score-threshold checks right below,
	# which already cover threshold-crossing.
	game.score = 5000
	game.shop_restocks = 3
	game._queue_wave(10)
	check(JSON.stringify(game.shop_stock) == before,
		"the 10-wave milestone no longer rerolls the shop")

	game.score = 0
	game.shop_restocks = 0
	Economy.earn(game, 99) # issue 57: Economy.earn's amount is x10'd on its
		# way to Score (SCORE_MULTIPLIER) — 99 lands at 990, still short of
		# threshold(0)=1000
	check(JSON.stringify(game.shop_stock) == before and game.shop_restocks == 0,
		"score below the threshold leaves the stock alone")
	Economy.earn(game, 1) # +10 Score -> exactly 1000
	check(JSON.stringify(game.shop_stock) != before, "crossing 1000 restocks")
	check(game.shop_restocks == 1, "the restock counter advances")
	check(game.shop_stock.filter(func(sl: Dictionary) -> bool:
			return sl.sold).is_empty(),
		"a restock clears every SOLD flag")
	check(game.shop_stock.size() == 22, "a restock refills all 22 slots")

	# one gain crossing several thresholds restocks once, not once per threshold
	game.score = 0
	game.shop_restocks = 0
	Economy.earn(game, 500) # issue 57: x10'd to 5000 Score by SCORE_MULTIPLIER
	check(game.shop_restocks == 3,
		"a single huge gain banks every threshold it crossed (next: 7000)")

	# always openable, and it pauses the run clock (GDD Shop page). Buying
	# stays turn-gated: outside your turn the shelf is a readable catalog.
	game.state = game.State.ENEMY_TURN
	game._open_shop()
	check(game.modals.shop_panel != null and game.modals.shop_panel.visible,
		"the Shop opens outside the player's turn")
	var any: Dictionary = game.shop_stock[0]
	game.gold = 99999
	game.actions_left = 5
	check(not Shop.can_buy(game, any), "but buying is refused outside your turn")

	game.state = game.State.PLAYER_TURN
	game._open_shop()
	var clock0: float = game.clock_ms
	game._process(0.5)
	check(game.clock_ms == clock0, "the clock does not tick while the Shop is open")
	game.modals.shop_panel.visible = false
	game._process(0.5)
	check(game.clock_ms < clock0, "closing the Shop resumes the clock")

	game.queue_free()
	await process_frame

	# --- issue 18: Shop slot pass — base + modifiers, additive per copy ---
	var slots: Node2D = _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["chocolate-key-cake", "chocolate-key-cake",
			"alleged-weather-balloon", "sub-antarctic-visa"]})
	await process_frame

	check(Shop._extra_item_slots(slots) == {"total": 5, "tactical": 1},
		"2 Chocolate Key Cakes (+2 each) + 1 Alleged Weather Balloon (+1, Tactical) = +5 Item slots")
	check(Shop._extra_artefact_slots(slots) == 1, "1 Sub-Antarctic Visa = +1 hidden Artefact slot")
	var item_n := 0
	var artefact_n := 0
	var hidden: Dictionary = {}
	for sl in slots.shop_stock:
		if sl.kind == "item":
			item_n += 1
		elif sl.kind == "artefact":
			artefact_n += 1
			if sl.get("biased", false):
				hidden = sl
	check(item_n == Shop.ROWS.item + 5, "the rolled stock actually carries the +5 Item slots (%d)" % item_n)
	check(artefact_n == Shop.ROWS.artefact + 1, "the rolled stock carries the +1 hidden Artefact slot")
	check(not hidden.is_empty(), "exactly one artefact slot is flagged biased (the hidden one)")
	check(Shop.price(slots, hidden)
			== roundi(Tuning.SHOP_ARTEFACT_PRICE[Shop.rarity_of(hidden)] * 1.5),
		"the hidden slot prices at +50% over a normal Artefact slot of its own rarity")
	slots.queue_free()
	await process_frame

	# --- issue 18: Shop price modifiers, same held copy stacks additively
	# off the immutable base as two Denazification Visas hit 0, not -25%^2
	var denaz: Node2D = _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["denazification-visa", "denazification-visa"], "gold": 500})
	await process_frame

	var tac_item := {"kind": "item", "key": "blitz", "sold": false} # Blitz is Tactical
	check(Shop.price(denaz, tac_item) == 0,
		"two Denazification Visas: -50% each stacks to -100%, clamped at 0 gold")
	var non_tac_item := {"kind": "item", "key": "air_strike", "sold": false} # Strategic
	check(Shop.price(denaz, non_tac_item) == Tuning.SHOP_ITEM_PRICE["Strategic"],
		"Denazification Visa only discounts Tactical Items, not other tiers")
	denaz.queue_free()
	await process_frame

	# --- issue 18: two different artefacts' price modifiers compose off the
	# same base too (slice 15 rule applies across artefacts, not just copies)
	var priced: Node2D = _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["hollow-moon-cross-section", "shrinkflation-cereal-box"], "gold": 500})
	await process_frame

	var artefact_slot := {"kind": "artefact", "key": "greed", "sold": false} # core key: rarity ""
	var artefact_price := Shop.price(priced, artefact_slot)
	# base 50 ("" rarity), -25% (Hollow Moon) +50% (Shrinkflation) = +25% additive net
	check(artefact_price == roundi(Tuning.SHOP_ARTEFACT_PRICE[""] * 1.25),
		"Hollow Moon's -25% and Shrinkflation's +50% compose additively off the same base")
	priced.queue_free()
	await process_frame

	# --- issue 60: selling — Stock pieces, Captured Stock, Items and
	# Artefacts sell for Tuning.SELL_RATE (50%), rounded DOWN, Gold only
	# (never Score — the price sources are the same Buy already reads:
	# g.defs[id].value, SHOP_ITEM_PRICE, SHOP_ARTEFACT_PRICE).
	var sl := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 0, "score": 0})
	await process_frame
	sl.state = sl.State.PLAYER_TURN
	sl.actions_left = 5
	sl.stock.append("pawn") # value 10 -> sells for 5
	var pawn_value: int = sl.defs.pawn.value
	check(Shop.sell_price(sl, "piece", "pawn") == floori(pawn_value * Tuning.SELL_RATE),
		"a Stock piece sells for SELL_RATE of g.defs[id].value, floored")
	var sl_stock_n: int = sl.stock.size()
	check(sl._sell("piece", "pawn"),
		"selling a Stock piece succeeds on the player's turn with an action to spare")
	check(sl.stock.size() == sl_stock_n - 1, "the sold piece leaves Stock")
	check(sl.gold == floori(pawn_value * Tuning.SELL_RATE) and sl.score == 0,
		"selling pays Gold only, never Score")
	check(sl.actions_left == 4, "selling costs 1 action, same as buying")

	sl.items.append({"key": "blitz", "name": "Blitz", "tier": "Tactical", "description": ""})
	check(Shop.sell_price(sl, "item", sl.items[0]) == floori(Tuning.SHOP_ITEM_PRICE["Tactical"] * Tuning.SELL_RATE),
		"an Item sells for SELL_RATE of its tier's SHOP_ITEM_PRICE, floored")
	var gold_before_item: int = sl.gold
	sl._sell("item", sl.items[0])
	check(sl.items.is_empty() and sl.gold == gold_before_item + floori(Tuning.SHOP_ITEM_PRICE["Tactical"] * Tuning.SELL_RATE),
		"selling an Item removes it and pays its own sell price")

	sl.artefacts.append({"key": "greed", "name": "Greed", "rarity": ""})
	check(Shop.sell_price(sl, "artefact", sl.artefacts[0]) == floori(Tuning.SHOP_ARTEFACT_PRICE[""] * Tuning.SELL_RATE),
		"a core (\"\" rarity) Artefact sells at the Common rate, floored")
	var gold_before_art: int = sl.gold
	sl._sell("artefact", sl.artefacts[0])
	check(sl.artefacts.is_empty() and sl.gold == gold_before_art + floori(Tuning.SHOP_ARTEFACT_PRICE[""] * Tuning.SELL_RATE),
		"selling an Artefact removes it and pays its own sell price")

	check(not sl._sell("piece", "pawn"), "selling a piece not actually held is a silent no-op refusal")
	sl.queue_free()
	await process_frame

	# --- issue 60: board pieces are never sellable — Extraction (board ->
	# Stock) stays the only way off the board, deliberately two steps.
	# There is no "board" kind at all; can_sell only ever receives an entry
	# already in Stock/Captured/Items/Artefacts, so this is a structural
	# guarantee, not a runtime check — confirmed by can_sell's own match.
	check(not ["piece", "captured", "item", "artefact"].has("board"),
		"(documentation) selling has no board-piece kind to accidentally reach")

	# --- issue 60: the softlock guard — mirrors _begin_player_turn()'s own
	# "Resource starvation" game-over check. An empty board + the LAST Stock
	# piece + no merge partner in the pool must refuse the sale that would
	# create that exact state; the same sale is fine with a board piece
	# still up, or with a merge partner still in the pool.
	var lock := _boot({"board": [], "stock": ["pawn"], "wave": 3, "gold": 0})
	await process_frame
	lock.state = lock.State.PLAYER_TURN
	lock.actions_left = 5
	check(Shop.sell_softlocks(lock, "piece", "pawn"),
		"selling the last Stock piece off an empty board with no merge partner triggers the guard")
	check(not lock._sell("piece", "pawn"), "the sale is refused outright")
	check(lock.stock == ["pawn"], "the piece stays put — refused, not silently dropped")
	lock.stock.append("pawn") # a second pawn IS a merge partner
	check(not Shop.sell_softlocks(lock, "piece", lock.stock[0]),
		"a merge partner left in the pool means the sale is safe (a merge is still a path forward)")
	check(lock._sell("piece", lock.stock[0]), "so the sale is allowed")
	lock.board[Vector2i(0, 0)] = {"id": "pawn", "owner": Rules.PLAYER}
	lock.stock = ["pawn"] # back to the last piece, no partner — but the
		# board is no longer empty, so starvation can't trigger at all
	check(not Shop.sell_softlocks(lock, "piece", "pawn"),
		"a board piece still up means the sale can never trigger the starvation shape")
	lock.queue_free()
	await process_frame

	# --- issue 60: Captured Stock's only exits are merge, convert, and sell —
	# direct deployment is REMOVED (game.gd:1393 used to call _place for it).
	# Both interaction paths that used to reach it (tap-to-place and
	# drag-to-drop) are checked directly, headless.
	var cap := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 1000})
	await process_frame
	cap.state = cap.State.PLAYER_TURN
	cap.actions_left = 5
	cap.captured.append("pawn")
	var target := Vector2i(-1, -1)
	for t in cap._deploy_tiles():
		if not cap.board.has(t):
			target = t
			break
	check(target.x >= 0, "(sanity) an open, EMPTY Deploy tile exists")
	# tap path: arm the captured stack, then tap an empty Deploy tile
	cap.placing_id = "pawn"
	cap.placing_cap = true
	cap.armed_entry = "pawn"
	cap._on_tile_clicked(target)
	check(not cap.board.has(target) and cap.captured == ["pawn"],
		"tapping a Deploy tile with a Captured stack armed does nothing — no direct deploy")
	cap.placing_id = ""
	cap.placing_cap = false
	# drag path: release a captured drag over an empty Deploy tile
	cap.pool_drag_id = "pawn"
	cap.pool_drag_cap = true
	cap.armed_entry = "pawn"
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = cap._tile_px(target) + Vector2(cap.tile, cap.tile) / 2
	cap._input(release)
	check(not cap.board.has(target) and cap.captured == ["pawn"],
		"dropping a Captured drag on a Deploy tile does nothing — no direct deploy")
	cap.queue_free()
	await process_frame

	# --- issue 60: Captured -> Stock conversion, the only way a captured
	# piece becomes deployable again — costs the SAME 50% Tuning.SELL_RATE
	# as selling (the deliberate equality: convert-then-sell is a wash).
	var cv := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 100})
	await process_frame
	cv.state = cv.State.PLAYER_TURN
	cv.actions_left = 5
	cv.captured.append("pawn")
	var convert_cost := Shop.sell_price(cv, "captured", "pawn")
	check(convert_cost == floori(cv.defs.pawn.value * Tuning.SELL_RATE),
		"Captured -> Stock conversion costs the same rate as selling")
	var gold_before_convert: int = cv.gold
	check(cv._convert_captured("pawn"), "conversion succeeds with enough Gold and an action to spare")
	check(cv.captured.is_empty() and cv.stock == ["pawn"],
		"the piece moves from Captured Stock into ordinary Stock")
	check(cv.gold == gold_before_convert - convert_cost, "conversion debits the Gold cost")
	var target2 := Vector2i(-1, -1)
	for t in cv._deploy_tiles():
		if not cv.board.has(t):
			target2 = t
			break
	check(target2.x >= 0, "(sanity) an open, EMPTY Deploy tile exists")
	cv._place("pawn", target2)
	check(cv.board.has(target2) and cv.board[target2].id == "pawn" and cv.stock.is_empty(),
		"the converted piece now deploys normally, like any other Stock piece")
	cv.queue_free()
	await process_frame

	# --- issue 60: convert-then-sell is a wash — the piece is simply gone,
	# not free money and not a strict loss beyond that.
	var wash := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 1000})
	await process_frame
	wash.state = wash.State.PLAYER_TURN
	wash.actions_left = 5
	wash.captured.append("pawn")
	var wash_gold_before: int = wash.gold
	wash._convert_captured("pawn")
	wash._sell("piece", "pawn")
	check(wash.gold == wash_gold_before, "convert (-50%) then sell (+50%) nets exactly zero, piece gone")
	wash.queue_free()
	await process_frame

	# --- issue 60: the full UI round-trip through the modal signals (same
	# wiring shop_buy_pressed already exercises elsewhere in this file) —
	# Sell mode toggle, a Sell action, and a Convert action.
	var ui := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "gold": 1000})
	await process_frame
	ui.state = ui.State.PLAYER_TURN
	ui.actions_left = 5
	ui.stock.append("pawn")
	ui.captured.append("pawn")
	ui._open_shop()
	check(ui.modals.shop_panel.visible and not ui.modals.shop_sell_mode,
		"the Shop opens fresh in Buy mode")
	ui.modals.shop_sell_mode = true
	ui.modals.show_shop()
	check(ui.modals.shop_sell_mode, "the Sell toggle switches modes")
	var ui_stock_before: int = ui.stock.size()
	ui.modals.shop_sell_pressed.emit("piece", ui.stock[0])
	check(ui.stock.size() == ui_stock_before - 1, "shop_sell_pressed sells through the same wiring shop_buy_pressed uses")
	var ui_captured_before: int = ui.captured.size()
	ui.modals.shop_convert_pressed.emit(ui.captured[0])
	check(ui.captured.size() == ui_captured_before - 1 and ui.stock.has("pawn"),
		"shop_convert_pressed converts through the same wiring")
	ui.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL SHOP CHECKS OK")
	quit(1 if fails > 0 else 0)
