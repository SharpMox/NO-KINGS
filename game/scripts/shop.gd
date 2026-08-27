## The Shop — pure logic over the live game node `g`, no nodes (like box.gd).
## Owns the randomized 19-slot stock (3 lootboxes / 4 artefacts / 4 items /
## 8 distinct base pieces), gold prices, purchase rules, and rerolls.
## Slots are JSON-safe ({kind, key, sold}) so saves carry them verbatim;
## names and prices are derived on demand. (money-and-shop/04)

const Tuning := preload("res://scripts/tuning.gd")
const Items := preload("res://data/items.gd")

const ROWS := {"box": 3, "artefact": 4, "item": 4, "piece": 8}


## Reroll g.shop_stock in place. Plain function on purpose: future effects
## (items, tariffs) may call it outside the wave cadence (money-and-shop/07).
static func roll(g) -> void:
	var slots := []
	for i in ROWS.box:
		slots.append({"kind": "box", "key": "box", "sold": false})
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
	return "Lootbox"


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
