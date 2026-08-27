## The Shop — pure logic over the live game node `g`, no nodes (like box.gd).
## Owns the randomized 22-slot stock (6 typed boxes / 4 artefacts / 4 items /
## 8 distinct base pieces), gold prices, purchase rules, and restocks.
## Slots are JSON-safe ({kind, key, sold}) so saves carry them verbatim;
## names and prices are derived on demand. (money-and-shop/04)

const Tuning := preload("res://scripts/tuning.gd")
const Items := preload("res://data/items.gd")

const ROWS := {"box": 6, "artefact": 4, "item": 4, "piece": 8}
const BOX_TYPES := ["item", "artefact", "score"] # 2 slots each (GDD Shop page)


## Reroll g.shop_stock in place. Plain function on purpose: effects
## (items, tariffs) may call it outside the score cadence (money-and-shop/07).
static func roll(g) -> void:
	var slots := []
	for type in BOX_TYPES:
		for i in ROWS.box / BOX_TYPES.size():
			slots.append({"kind": "box", "key": type, "sold": false})
	for key in _sample(Items.ARTEFACT_EFFECTS.map(func(t: Dictionary) -> String:
			return t.key), ROWS.artefact, g.rng):
		slots.append({"kind": "artefact", "key": key, "sold": false})
	for key in _sample(Items.ITEMS.map(func(it: Dictionary) -> String:
			return it.key), ROWS.item, g.rng):
		slots.append({"kind": "item", "key": key, "sold": false})
	for id in _sample_pieces(g, ROWS.piece):
		slots.append({"kind": "piece", "key": id, "sold": false})
	g.shop_stock = slots


## Base pieces: merge-chain roots (nothing merges into them), minus the King
## and the inversion pieces — inversions are a mechanic outcome, not a product.
static func base_piece_pool(defs: Dictionary) -> Array:
	var merged_into := {}
	for id in defs:
		if defs[id].get("next", ""):
			merged_into[defs[id].next] = true
	var out := []
	for id in defs:
		if not merged_into.has(id) and id != "king" and not id.begins_with("inv-"):
			out.append(id)
	return out


static func price(g, slot: Dictionary) -> int:
	match slot.kind:
		"piece":
			return int(g.defs[slot.key].value)
		"item":
			return int(Tuning.SHOP_ITEM_PRICE[_catalog(slot).tier])
		"artefact":
			return Tuning.SHOP_ARTEFACT_PRICE
	return Tuning.SHOP_BOX_PRICE


static func description(slot: Dictionary) -> String:
	return str(_catalog(slot).get("description", ""))


static func display_name(g, slot: Dictionary) -> String:
	match slot.kind:
		"piece":
			return str(g.defs[slot.key].name)
		"item", "artefact":
			return str(_catalog(slot).name)
	return "%s Box" % str(slot.key).capitalize()


## Cumulative score that buys the (n+1)-th restock, given n already banked:
## 1000 / 2500 / 4500 / 7000 … — the gap itself grows by the step each time.
static func threshold(n: int) -> int:
	return Tuning.SHOP_RESTOCK_BASE * (n + 1) + Tuning.SHOP_RESTOCK_STEP * n * (n + 1) / 2


## Restock every threshold the run's score has passed. Called from the single
## gain site (Economy.earn); a leap over several thresholds banks them all but
## rolls once — the shelf can only be fresh, not fresher.
static func maybe_restock(g) -> void:
	var crossed := false
	while g.score >= threshold(g.shop_restocks):
		g.shop_restocks += 1
		crossed = true
	if crossed:
		roll(g)


## Purchasable right now: player's turn, an action and the gold to spare,
## not sold. Kinds outside PURCHASABLE render but stay Buy-disabled.
const PURCHASABLE := ["piece", "item", "artefact", "box"]

static func can_buy(g, slot: Dictionary) -> bool:
	return slot.kind in PURCHASABLE and not slot.sold \
			and g.state == g.State.PLAYER_TURN \
			and g.actions_left >= 1 and g.gold >= price(g, slot)


## Debit gold + 1 action, mark the slot SOLD, grant the good; returns
## whether the purchase happened. Buying never ends the turn (a purchase is
## not a board action). A bought box grants nothing here — the caller opens
## the roll modal, which IS the grant.
static func buy(g, index: int) -> bool:
	var slot: Dictionary = g.shop_stock[index]
	if not can_buy(g, slot):
		return false
	g.gold -= price(g, slot)
	g.actions_left -= 1
	slot.sold = true
	match slot.kind: # grants reuse the existing acquisition paths
		"piece":
			g.stock.append(slot.key)
		"item":
			g.items.append(_catalog(slot))
		"artefact":
			g.artefacts.append(_catalog(slot)) # stacks like box copies
	return true


## n distinct picks from a key array, uniform.
static func _sample(pool: Array, n: int, rng: RandomNumberGenerator) -> Array:
	var open := pool.duplicate()
	var out := []
	for i in mini(n, open.size()):
		out.append(open.pop_at(rng.randi() % open.size()))
	return out


## n distinct base pieces, weighted 1/value so heavies are finds, not fixtures.
static func _sample_pieces(g, n: int) -> Array:
	var open := base_piece_pool(g.defs)
	var out := []
	for i in mini(n, open.size()):
		var total := 0.0
		for id in open:
			total += 1.0 / float(g.defs[id].value)
		var r: float = g.rng.randf() * total
		for j in open.size():
			r -= 1.0 / float(g.defs[open[j]].value)
			if r <= 0.0 or j == open.size() - 1:
				out.append(open.pop_at(j))
				break
	return out


static func _catalog(slot: Dictionary) -> Dictionary:
	var pool: Array = Items.ITEMS if slot.kind == "item" else Items.ARTEFACT_EFFECTS
	for e in pool:
		if e.key == slot.key:
			return e
	return {}
