## The Shop — pure logic over the live game node `g`, no nodes (like box.gd).
## Owns the randomized 22-slot stock (6 typed boxes / 4 artefacts / 4 items /
## 8 distinct base pieces), gold prices, purchase rules, and restocks.
## Slots are JSON-safe ({kind, key, sold}, box slots additionally {size,
## contents} — issue 47) so saves carry them verbatim; names and prices are
## derived on demand. (money-and-shop/04)

const Tuning := preload("res://scripts/tuning.gd")
const Items := preload("res://data/items.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")
const Box := preload("res://scripts/box.gd")
const ItemLogic := preload("res://scripts/item_logic.gd")
const Rules := preload("res://scripts/rules.gd")
const Armies := preload("res://scripts/armies.gd")

## Base slot counts (money-and-shop/04). Issue 18 adds the "base + modifiers"
## pass shop-drawer-ui/08 deferred: Chocolate Key Cake / Alleged Weather
## Balloon add Item slots, Sub-Antarctic Visa adds a hidden Artefact slot —
## see _extra_item_slots / _extra_artefact_slots, additive per held copy
## (slice 15 stacking rule) and read straight off g.artefacts, the same way
## Shop.buy already reads slot.kind with no hook indirection.
const ROWS := {"box": 6, "artefact": 4, "item": 4, "piece": 8}
## 2 slots each (GDD Shop page); every Box's SIZE is rolled independently in
## roll() below (issue 47 — Score Box and the mixed Box are both gone).
const BOX_THEMES := ["piece", "artefact", "item"]

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
	var box_base: int = rows.box / BOX_THEMES.size()
	var box_remainder: int = rows.box % BOX_THEMES.size()
	for ti in BOX_THEMES.size():
		var theme: String = BOX_THEMES[ti]
		for i in box_base + (1 if ti < box_remainder else 0):
			# size rolled independently per slot (issue 47); contents rolled
			# NOW, at stock time, and stored — opening only ever reveals this.
			var size: String = Box.SIZE_KEYS[g.rng.randi() % Box.SIZE_KEYS.size()]
			slots.append({"kind": "box", "key": theme, "size": size, "sold": false,
				"contents": Box.roll_options(g, theme, size)})

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

	for id in sample_pieces(g, rows.piece):
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
		_: # box — price by SIZE only, theme ignored (issue 47)
			base = float(Tuning.SHOP_BOX_PRICE[slot.size])
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
	if Armies.insider_rates(g): # The Syndicate's Insider Rates (issue 68):
		# Shop buy prices -25% — a flat final multiplier, same seam as the two
		# absolute overrides just above (0 * 0.75 is still 0, so ordering
		# against them doesn't matter); Buy only, never sell_price()/
		# sell_payout() below share this constant.
		amount *= 0.75
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
	return "%s %s Box" % [str(slot.size).capitalize(), str(slot.key).capitalize()]


## Lane A: guaranteed restock every Tuning.SHOP_RESTOCK_WAVES Waves (5, 10,
## 15…), independent of Score — issue 64 (user ruling 2026-08-30) replaces
## the old rising Score-threshold curve (Shop.threshold, gone) with exactly
## two restock sources; this is the first. Wipes Lane B's progress too: a
## Wave-5 restock discards whatever had accumulated toward the next
## Score-lane restock, per spec ("resets on every Lane-A restock").
static func lane_a_restock(g) -> void:
	g.shop_lane_b_progress = 0
	g.shop_restocks += 1
	roll(g)


## Lane B: g.shop_lane_b_progress banks Score earned (via Economy.earn/
## earn_gold, the same two call sites the old threshold model used) since
## the last Lane-A restock, and restocks every Tuning.SHOP_LANE_B_SCORE,
## continuing to accumulate afterward — only a Lane-A restock (lane_a_restock,
## above) zeroes it. A single gain crossing several multiples banks them all
## but rolls once (issue 57's "leap crosses several thresholds" contract,
## preserved from the old maybe_restock).
static func add_score_progress(g, amount: int) -> void:
	if amount <= 0:
		return
	g.shop_lane_b_progress += amount
	var crossed := false
	while g.shop_lane_b_progress >= Tuning.SHOP_LANE_B_SCORE:
		g.shop_lane_b_progress -= Tuning.SHOP_LANE_B_SCORE
		g.shop_restocks += 1
		crossed = true
	if crossed:
		roll(g)


## Purchasable right now: player's turn and the gold to spare, not sold.
## Kinds outside PURCHASABLE render but stay Buy-disabled. No Action gate
## (issue 64, user ruling): Shop purchases don't spend an Action, so nothing
## here should require one either.
const PURCHASABLE := ["piece", "item", "artefact", "box"]

## issue 101 gates the PANEL, not this. The Wave gate deliberately does NOT
## live here: `can_buy` is the mechanics layer, and seven suites drive it
## directly at low Waves to test shop behaviour that has nothing to do with the
## unlock. A player can only reach a purchase through the panel, so gating the
## panel is behaviourally complete for them.
##
## The one thing that CAN bypass it is autoplay, which buys through buy()
## without opening the modal — so the bot carries the same Wave check itself
## (autoplay.gd's try_shop). The bot must never be able to do what a player
## cannot, or the issue-103 measurements stop describing the real game.
static func can_buy(g, slot: Dictionary) -> bool:
	return slot.kind in PURCHASABLE and not slot.sold \
			and g.state == g.State.PLAYER_TURN \
			and g.gold + _credit(g) + _score_credit(g) >= price(g, slot) \
			and (slot.kind != "item" or ItemLogic.has_room(g)) \
			and (slot.kind != "artefact" or ArtefactHooks.has_room(g)) # issue
				# 53/60: never sell an Item or Artefact slot the player has no
				# capacity to hold — a Box still sells fine even at capacity
				# (it might not roll one; _box_choose's own grant refuses that
				# pick if it does)


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


## Debit gold, mark the slot SOLD, grant the good; returns whether the
## purchase happened. Buying never spends an Action or ends the turn (issue
## 64: no Shop interaction of any kind costs one). A bought box grants
## nothing here — the caller opens the roll modal, which IS the grant.
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


# --- selling + Captured -> Stock conversion (issue 60) ---

## Sell/convert value for a held entry: the same price sources price() reads
## for the Shop's own Buy price, at Tuning.SELL_RATE, rounded down (never a
## percentage/artefact-price hook — Buy's on_price modifiers are Shop-stock
## specific, e.g. the hidden slot's own +50%, and don't apply to something
## already owned). `kind` is "piece" (Stock), "captured" (Captured Stock),
## "item" or "artefact"; `entry` is the actual g.stock/g.captured/g.items/
## g.artefacts element (a bare id String for piece/captured, a catalog
## Dictionary for item/artefact). Captured -> Stock conversion charges this
## exact number too (game.gd._convert_captured) — deliberately the same
## constant, not a second one (Tuning.SELL_RATE's own header explains why).
static func sell_price(g, kind: String, entry) -> int:
	return floori(_sell_base(g, kind, entry) * Tuning.SELL_RATE)


## The buy-price-equivalent base a held entry's sell/convert value scales off
## — split out of sell_price (issue 68) so sell_payout below can apply a
## different rate to the SAME base without duplicating this lookup.
static func _sell_base(g, kind: String, entry) -> float:
	match kind:
		"piece", "captured":
			var id: String = entry if entry is String else entry.id
			return float(g.defs[id].value)
		"item":
			return float(Tuning.SHOP_ITEM_PRICE[entry.tier])
		_: # "artefact"
			return float(Tuning.SHOP_ARTEFACT_PRICE.get(entry.get("rarity", ""), Tuning.SHOP_ARTEFACT_PRICE[""]))


## The Syndicate's Insider Rates (issue 68): an actual SELL payout is +25%
## (50% -> 62.5%), floored ONCE against the raw base — not 1.25x an
## already-floored sell_price(), which would silently disagree with "62.5%"
## on an odd value (e.g. a 7-value piece: floor(7*0.625)=4, not
## floor(floor(7*0.5)*1.25)=3). Every REAL sell call site (game.gd._sell,
## modals.gd's Sell-mode display) reads this, never sell_price() above —
## Captured -> Stock conversion (game.gd._convert_captured, modals.gd's
## Convert-mode display) keeps reading sell_price() at the flat rate; see
## Armies.insider_rates' own header for why that split is deliberate.
static func sell_payout(g, kind: String, entry) -> int:
	var rate := Tuning.SELL_RATE * 1.25 if Armies.insider_rates(g) else Tuning.SELL_RATE
	return floori(_sell_base(g, kind, entry) * rate)


## The live array a held entry of `kind` lives in — the single place both
## can_sell's "is it actually held" check and modals.gd's Sell-mode UI (whose
## own _sell_entries delegates here) read from, so the two can never disagree
## about what's sellable.
static func held_entries(g, kind: String) -> Array:
	match kind:
		"piece": return g.stock
		"captured": return g.captured
		"item": return g.items
		_: return g.artefacts # "artefact"


## Softlock guard: mirrors game.gd's own _begin_player_turn() "Resource
## starvation" game-over check exactly (no player board pieces, empty Stock,
## no merge left in the pool) rather than inventing a new threshold — that
## check runs at the START of the NEXT turn with no regard for Gold, so
## simulating the SAME condition here and refusing the sale that would
## trigger it is the correct mirror. Only a Stock or Captured sale can ever
## reach it; an Item/Artefact sale never touches board or Stock.
static func sell_softlocks(g, kind: String, entry) -> bool:
	if kind != "piece" and kind != "captured":
		return false
	if not g._player_pieces().is_empty():
		return false
	var stock_after: Array = g.stock.duplicate()
	var captured_after: Array = g.captured.duplicate()
	(stock_after if kind == "piece" else captured_after).erase(entry)
	return stock_after.is_empty() \
			and not Rules.has_merge(stock_after + captured_after, g.defs, g.fusions)


## Sellable right now: actually held (never sell/pay out for something not
## owned), player's turn, and the sale wouldn't trigger the starvation
## softlock above. No Action gate (issue 64, user ruling — selling is free
## too). Board pieces are never sellable at all — there is no "piece"/
## "captured" `entry` reachable from a board tile; callers only ever pass a
## Stock/Captured/Item/Artefact entry.
static func can_sell(g, kind: String, entry) -> bool:
	return held_entries(g, kind).has(entry) \
			and g.state == g.State.PLAYER_TURN \
			and not sell_softlocks(g, kind, entry)


## Convertible right now: actually held in Captured Stock, player's turn, and
## the Gold to cover the conversion price (same rate as sell_price, above).
## No Action gate (issue 64, user ruling). Converting only ever ADDS to Stock
## (never removes a board/Stock piece), so it can never trigger the
## starvation softlock the way a sale can.
static func can_convert(g, entry) -> bool:
	return g.captured.has(entry) \
			and g.state == g.State.PLAYER_TURN \
			and g.gold >= sell_price(g, "captured", entry)


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


## n distinct base pieces, weighted 1/value so heavies are finds, not
## fixtures. Public: box.gd's Piece Box (issue 47) draws from this exact
## pool + weighting too, so a Box can't skip the merge/promotion ladder.
static func sample_pieces(g, n: int) -> Array:
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
