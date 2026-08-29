## The Shop — pure logic over the live game node `g`, no nodes (like box.gd).
## Owns the randomized 22-slot stock (6 typed boxes / 4 artefacts / 4 items /
## 8 distinct base pieces), gold prices, purchase rules, and restocks.
## Slots are JSON-safe ({kind, key, sold}) so saves carry them verbatim;
## names and prices are derived on demand. (money-and-shop/04)

const Tuning := preload("res://scripts/tuning.gd")
const Items := preload("res://data/items.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")

## Base slot counts (money-and-shop/04). Issue 18 adds the "base + modifiers"
## pass shop-drawer-ui/08 deferred: Chocolate Key Cake / Alleged Weather
## Balloon add Item slots, Sub-Antarctic Visa adds a hidden Artefact slot —
## see _extra_item_slots / _extra_artefact_slots, additive per held copy
## (slice 15 stacking rule) and read straight off g.artefacts, the same way
## Shop.buy already reads slot.kind with no hook indirection.
const ROWS := {"box": 6, "artefact": 4, "item": 4, "piece": 8}
const BOX_TYPES := ["item", "artefact", "score"] # 2 slots each (GDD Shop page)

## Rarity order low -> high (GDD Artefacts DB). A hidden slot (Sub-Antarctic
## Visa) samples from strictly above the lowest rarity present in the
## rollable pool — "one rarity higher" than a baseline roll, layered on top
## of the issue-20 flat rarity weighting the normal 4-slot roll uses too
## (depth-gating reverted 2026-08-28 — see tuning.gd).
const RARITY_ORDER := ["Common", "Uncommon", "Rare", "Legendary"]


## Row counts after the Tier 3+ modifier (07-difficulty-ranks: "Shop stocks
## 1 fewer of each kind") — the seam every roll() count reads through instead
## of the ROWS constant directly, same shape as the artefact/item modifiers
## below.
static func _rows(g) -> Dictionary:
	var d: int = Tuning.shop_row_delta(g.next_tier)
	var out := {}
	for k in ROWS:
		out[k] = ROWS[k] + d
	return out


## Reroll g.shop_stock in place. Plain function on purpose: effects
## (items, tariffs) may call it outside the score cadence (money-and-shop/07).
static func roll(g) -> void:
	var rows := _rows(g)
	var slots := []
	var box_base: int = rows.box / BOX_TYPES.size()
	var box_remainder: int = rows.box % BOX_TYPES.size()
	for ti in BOX_TYPES.size():
		for i in box_base + (1 if ti < box_remainder else 0):
			slots.append({"kind": "box", "key": BOX_TYPES[ti], "sold": false})

	var artefact_keys: Array = _sample_weighted_artefacts(Items.ARTEFACT_EFFECTS, rows.artefact, g)
	for key in artefact_keys:
		slots.append({"kind": "artefact", "key": key, "sold": false})
	for key in _sample_biased_artefacts(g, _extra_artefact_slots(g), artefact_keys):
		slots.append({"kind": "artefact", "key": key, "sold": false, "biased": true})

	var extra: Dictionary = _extra_item_slots(g)
	var tactical_pool: Array = Items.ITEMS.filter(func(it: Dictionary) -> bool:
			return it.tier == "Tactical").map(func(it: Dictionary) -> String: return it.key)
	var item_keys: Array = _sample(tactical_pool, extra.tactical, g.rng)
	var rest_pool: Array = Items.ITEMS.map(func(it: Dictionary) -> String: return it.key) \
			.filter(func(k: String) -> bool: return not item_keys.has(k))
	item_keys += _sample(rest_pool, rows.item + extra.total - extra.tactical, g.rng)
	for key in item_keys:
		slots.append({"kind": "item", "key": key, "sold": false})

	for id in _sample_pieces(g, rows.piece):
		slots.append({"kind": "piece", "key": id, "sold": false})
	g.shop_stock = slots


## Chocolate Key Cake (+2 Item slots) / Alleged Weather Balloon (+1, Tactical
## only) — additive per held copy. `tactical` is how many of `total` must
## come from the Tactical-tier pool alone.
static func _extra_item_slots(g) -> Dictionary:
	var total := 0
	var tactical := 0
	for t in g.artefacts:
		if t.key == "chocolate-key-cake":
			total += 2
		elif t.key == "alleged-weather-balloon":
			total += 1
			tactical += 1
	return {"total": total, "tactical": tactical}


## Sub-Antarctic Visa: +1 hidden Artefact slot per held copy.
static func _extra_artefact_slots(g) -> int:
	var n := 0
	for t in g.artefacts:
		if t.key == "sub-antarctic-visa":
			n += 1
	return n


## n keys for the hidden slot(s), biased toward the higher rarities and
## distinct from `exclude` (the normal 4-slot roll) where possible.
static func _sample_biased_artefacts(g, n: int, exclude: Array) -> Array:
	if n <= 0:
		return []
	var pool: Array = Items.ARTEFACT_EFFECTS.filter(func(t: Dictionary) -> bool:
		return not exclude.has(t.key) and RARITY_ORDER.has(t.get("rarity", "")))
	if not pool.is_empty():
		var lowest: String = pool[0].rarity
		for t in pool:
			if RARITY_ORDER.find(t.rarity) < RARITY_ORDER.find(lowest):
				lowest = t.rarity
		var biased: Array = pool.filter(func(t: Dictionary) -> bool: return t.rarity != lowest)
		if not biased.is_empty():
			pool = biased
	if pool.is_empty(): # every candidate excluded or unrated: fall back
		pool = Items.ARTEFACT_EFFECTS.filter(func(t: Dictionary) -> bool: return not exclude.has(t.key))
	return _sample_weighted_artefacts(pool, n, g)


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


## Base price by row, then the on_price seam (issue 18) composes every held
## modifier off that immutable base — same additive-not-compounding contract
## as on_score_change/on_gold_change (slice 15/16), so two Denazification
## Visas stack to -100%, not -75%. The hidden slot's own +50% (Sub-Antarctic
## Visa) is baked into `base` first, ahead of the hook: it's the slot's own
## structural price, not a held-artefact modifier on every artefact's price.
static func price(g, slot: Dictionary) -> int:
	var base: float
	var tier := ""
	match slot.kind:
		"piece":
			base = float(g.defs[slot.key].value)
		"item":
			tier = _catalog(slot).tier
			base = float(Tuning.SHOP_ITEM_PRICE[tier])
		"artefact":
			var rarity := rarity_of(slot)
			base = float(Tuning.SHOP_ARTEFACT_PRICE.get(rarity, Tuning.SHOP_ARTEFACT_PRICE[""]))
			if slot.get("biased", false):
				base *= 1.5
		_:
			base = float(Tuning.SHOP_BOX_PRICE)
	var ctx := ArtefactHooks.run(g, "on_price",
		{"base": base, "amount": base, "kind": slot.kind, "tier": tier})
	var amount: float = ctx.amount
	# Pre-Scratched Lottery Ticket (issue 26): "every 5th purchase free" is an
	# absolute override, not a percentage composed off `base` like every other
	# on_price handler — a later-sorting discount artefact adding on top of a
	# forced-to-0 ctx.amount would go negative. Applied after the hook instead
	# of inside it, same reasoning Inflation gets for stacking multiplicatively
	# instead of additively (artefact_hooks.gd header): a deliberate exception.
	for t in g.artefacts:
		if t.key == "pre-scratched-lottery-ticket" and (g.lottery_purchase_count + 1) % 5 == 0:
			amount = 0.0
			break
	# Mar-a-Lago Toilet Papers (issue 43): same reasoning as the lottery
	# ticket override just above — `slot` is the actual Dictionary held in
	# g.shop_stock (every caller reads it straight out of that array, never a
	# copy), tagged by the on_wave_clear handler above, so this is an
	# absolute forced-to-0 override applied after every percentage handler
	# (including this artefact's own +10%) rather than composed inside the
	# hook, where a later-sorting discount could add back on top of it.
	if slot.get("free_slot", false):
		for t in g.artefacts:
			if t.key == "mar-a-lago-toilet-papers":
				amount = 0.0
				break
	return maxi(roundi(amount), 0)


## "" for non-artefact slots and the 7 core artefacts that predate the
## rarity catalog — legibility (modals.gd) and pricing both fall back on it.
static func rarity_of(slot: Dictionary) -> String:
	return str(_catalog(slot).get("rarity", "")) if slot.kind == "artefact" else ""


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
			and g.actions_left >= 1 \
			and g.gold + _credit(g) + _score_credit(g) >= price(g, slot)


## Agartha Welcome Mat (issue 26): Shop purchases only may dip up to 100 Gold
## into the negative — read directly off g.artefacts like the other
## structural Shop reads above (_extra_item_slots etc.), not a hook: it's a
## standing rule on this one call site, not a triggered effect.
static func _credit(g) -> int:
	for t in g.artefacts:
		if t.key == "agartha-welcome-mat":
			return 100
	return 0


## Templar Debit Card (issue 31): "pay Shop costs with Score, 10 Score per 1
## Gold" — same shape as _credit above (a standing rule read directly off
## g.artefacts, not a hook). Gold-equivalent of the held Score, floored;
## can_buy() adds it to the funds check, buy() spends the Gold-uncovered
## remainder of a purchase as Score.
static func _score_credit(g) -> int:
	for t in g.artefacts:
		if t.key == "templar-debit-card":
			return g.score / 10 # int division floors
	return 0


## Debit gold + 1 action, mark the slot SOLD, grant the good; returns
## whether the purchase happened. Buying never ends the turn (a purchase is
## not a board action). A bought box grants nothing here — the caller opens
## the roll modal, which IS the grant.
static func buy(g, index: int) -> bool:
	var slot: Dictionary = g.shop_stock[index]
	if not can_buy(g, slot):
		return false
	var cost := price(g, slot)
	var before: int = g.gold
	var gold_floor := -_credit(g)
	var gold_pay: int = mini(cost, maxi(g.gold - gold_floor, 0))
	g.gold -= gold_pay # Economy.spend_gold would cycle back through this file
		# (economy.gd preloads Shop), so this inlines the same debit +
		# on_gold_zero dispatch it does — see there.
	var score_pay := cost - gold_pay # Templar Debit Card (issue 31): whatever
		# Gold (+ Agartha's credit line) can't cover pays as Score, 10:1 —
		# only nonzero when the card is held, since can_buy() only admits
		# this purchase by counting _score_credit(g) into the funds check.
	if score_pay > 0:
		g.score -= score_pay * 10
	if before > 0 and g.gold == 0:
		ArtefactHooks.run(g, "on_gold_zero", {}) # Zero-Point Energy Drink (26)
	g.actions_left -= 1
	slot.sold = true
	g.gold_spent_shop_this_wave += cost # issue 16: Zurich Gnome Figurine et al.
	match slot.kind: # grants reuse the existing acquisition paths
		"piece":
			g.stock.append(slot.key)
		"item":
			g.items.append(_catalog(slot))
		"artefact":
			var entry: Dictionary = _catalog(slot).duplicate() # never mutate the
				# shared catalog Dictionary — stamp a per-copy acquisition wave
				# (artefact_hooks.gd's per-artefact "5-Wave Milestone" cadence)
				# and rarity (issue 29 — Illuminati Fridge Magnet's "every
				# rarity" check, ArtefactHooks.holds_every_rarity)
			entry.acquired_wave = g.wave
			entry.rarity = ArtefactHooks.rarity_of(entry.key)
			g.artefacts.append(entry) # stacks like box copies
	ArtefactHooks.run(g, "on_purchase", {"kind": slot.kind, "key": slot.key, "price": cost})
	return true


## n distinct picks from a key array, uniform.
static func _sample(pool: Array, n: int, rng: RandomNumberGenerator) -> Array:
	var open := pool.duplicate()
	var out := []
	for i in mini(n, open.size()):
		out.append(open.pop_at(rng.randi() % open.size()))
	return out


## n distinct artefact keys, weighted by rarity (issue 20 — shares
## Tuning.weighted_artefact_pick with box.gd's single-pick roll).
static func _sample_weighted_artefacts(entries: Array, n: int, g) -> Array:
	var open := entries.duplicate()
	var out := []
	for i in mini(n, open.size()):
		out.append(open.pop_at(Tuning.weighted_artefact_pick(open, g.rng)).key)
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
