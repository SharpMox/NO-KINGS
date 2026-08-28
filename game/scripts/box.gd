## Lootbox reward rolls — pure logic over the Items/Tuning catalogs, no nodes
## (split out of game.gd; the box UI stays there).

const Items := preload("res://data/items.gd")
const Tuning := preload("res://scripts/tuning.gd")


## One randomized offer (goal rework 2026-07-06, diverges from the GDD's
## two-step pick): 3 options rolled independently — Item 40% / Artefact 30% /
## Score 30% — never repeating within the offer. Each is self-describing:
## {kind, name, description, tier?, value?, payload?}.
## `only_kind` pins every option to one kind — that is what a typed Shop Box
## sells (GDD Shop page); the capture-driven Box Pick leaves it empty.
## `allowed_tiers` further restricts an Item roll (Majestic 12 Secret
## Handshake Diagram, issue 18: "Item Boxes only offer Strategic and Decisive
## Items") — empty means every tier, as before.
static func roll_options(rng: RandomNumberGenerator, only_kind := "",
		allowed_tiers: Array = []) -> Array:
	var out := []
	var taken := {}
	for i in 3:
		var r := rng.randf()
		var kind := only_kind if only_kind != "" \
			else ("item" if r < 0.4 else ("artefact" if r < 0.7 else "score"))
		var opt := {}
		match kind:
			"item":
				var pool := Items.ITEMS.filter(func(e: Dictionary) -> bool:
					return not taken.has(e.name) \
						and (allowed_tiers.is_empty() or allowed_tiers.has(e.tier)))
				var e: Dictionary = pool[rng.randi() % pool.size()]
				opt = {"kind": "item", "name": e.name, "tier": e.tier,
					"description": e.description, "payload": e}
			"artefact":
				var pool := Items.ARTEFACT_EFFECTS.filter(func(e: Dictionary) -> bool:
					return not taken.has(e.name))
				var e: Dictionary = pool[Tuning.weighted_artefact_pick(pool, rng)]
				opt = {"kind": "artefact", "name": e.name,
					"description": e.description, "payload": e}
			"score":
				var pool := Tuning.SCORE_BOX_CHUNKS.filter(func(v: int) -> bool:
					return not taken.has("+%d score" % v))
				var v: int = pool[rng.randi() % pool.size()]
				opt = {"kind": "score", "name": "+%d score" % v, "value": v,
					"description": "Banked immediately."}
		taken[opt.name] = true
		out.append(opt)
	return out
