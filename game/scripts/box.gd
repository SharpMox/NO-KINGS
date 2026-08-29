## Lootbox reward rolls — pure logic over the Items/Tuning/Shop catalogs, no
## nodes (like item_logic.gd). The box UI stays in modals.gd / game.gd.
##
## 9 Boxes (issue 47 rework): 3 sizes x 3 themes — Pieces/Artefacts/Items —
## replacing the prototype's single mixed 3-option offer (Item 40% /
## Artefact 30% / Score 30%). Score Boxes and the mixed Box are both gone.
##
## Contents are rolled ONCE, at Shop-stock time (Shop.roll calls
## roll_options and stores the result on the shop_stock slot), never at open
## time — game.gd's _open_box_pick reveals exactly what was already rolled.
## An interactive reroll (Bible Gag Reel Scroll / Snowden's Rubik's Cube,
## issue 46) calls roll_options again through the same seam.

const Items := preload("res://data/items.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Shop := preload("res://scripts/shop.gd")

## size -> {choices, picks}. Concrete values ruled 2026-08-29.
const SIZES := {
	"small": {"choices": 3, "picks": 1},
	"big": {"choices": 5, "picks": 1},
	"huge": {"choices": 7, "picks": 2},
}
const SIZE_KEYS: Array = ["small", "big", "huge"]

## Every Box is themed now — no mixed offer, no Score theme.
const THEMES: Array = ["piece", "artefact", "item"]


## Majestic 12 Secret Handshake Diagram (issue 18): "Item Boxes only offer
## Strategic and Decisive Items" — read at roll time (stock or reroll), same
## as any other per-Box modifier.
static func _allowed_item_tiers(g) -> Array:
	for t in g.artefacts:
		if t.key == "majestic-12-secret-handshake-diagram":
			return ["Strategic", "Decisive"]
	return []


## Roll one Box's full offer. `theme` + `size` fix its shape; `g` supplies
## the catalogs, the piece pool and the RNG stream.
static func roll_options(g, theme: String, size: String) -> Array:
	var choices: int = SIZES[size].choices
	var out := []
	match theme:
		"piece":
			# Shop.base_piece_pool, the same pool + 1/value weighting the Shop
			# itself sells from (issue 47, user call): the wider "entire
			# catalog" option would let a Box hand out a chain-end piece and
			# skip the merge/promotion ladder.
			for id in Shop.sample_pieces(g, choices):
				out.append({"kind": "piece", "name": str(g.defs[id].name),
					"description": "Joins Stock, like a Shop piece purchase.", "payload": id})
		"item":
			var allowed_tiers := _allowed_item_tiers(g)
			var taken := {}
			for i in choices:
				var pool: Array = Items.ITEMS.filter(func(e: Dictionary) -> bool:
					return not taken.has(e.name) \
						and (allowed_tiers.is_empty() or allowed_tiers.has(e.tier)))
				var e: Dictionary = pool[g.rng.randi() % pool.size()]
				taken[e.name] = true
				out.append({"kind": "item", "name": e.name, "tier": e.tier,
					"description": e.description, "payload": e})
		"artefact":
			var taken := {}
			for i in choices:
				var pool: Array = Items.ARTEFACT_EFFECTS.filter(func(e: Dictionary) -> bool:
					return not taken.has(e.name))
				var e: Dictionary = pool[Tuning.weighted_artefact_pick(pool, g.rng)]
				taken[e.name] = true
				out.append({"kind": "artefact", "name": e.name,
					"description": e.description, "payload": e})
	return out


## A grant that names only "a Box" (no theme/size), e.g. Trojan Horse
## Assembly Manual's "On 5-Wave Milestone: open a free Box" — issue 47 rules
## this rolls one of the 9 uniformly at random. Built as a full shop_stock-
## shaped slot (contents rolled right now, at grant time) so the caller can
## hand it straight to game.gd's _open_box_pick like any Shop-bought Box.
static func random_slot(g) -> Dictionary:
	var theme: String = THEMES[g.rng.randi() % THEMES.size()]
	var size: String = SIZE_KEYS[g.rng.randi() % SIZE_KEYS.size()]
	return {"kind": "box", "key": theme, "size": size, "sold": false,
		"contents": roll_options(g, theme, size)}
