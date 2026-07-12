## Lootbox reward rolls — pure logic over the Items/Tuning catalogs, no nodes
## (split out of game.gd; the box UI stays there).

const Items := preload("res://data/items.gd")
const Tuning := preload("res://scripts/tuning.gd")


## One randomized offer (goal rework 2026-07-06, diverges from the GDD's
## two-step pick): 3 options rolled independently — Item 40% / Trinket 30% /
## Score 30% — never repeating within the offer. Each is self-describing:
## {kind, name, description, tier?, value?, payload?}.
static func roll_options(rng: RandomNumberGenerator) -> Array:
	var out := []
	var taken := {}
	for i in 3:
		var r := rng.randf()
		var kind := "item" if r < 0.4 else ("trinket" if r < 0.7 else "score")
		var opt := {}
		match kind:
			"item":
				var pool := Items.ITEMS.filter(func(e: Dictionary) -> bool:
					return not taken.has(e.name))
				var e: Dictionary = pool[rng.randi() % pool.size()]
				opt = {"kind": "item", "name": e.name, "tier": e.tier,
					"description": e.description, "payload": e}
			"trinket":
				var pool := Items.TRINKET_EFFECTS.filter(func(e: Dictionary) -> bool:
					return not taken.has(e.name))
				var e: Dictionary = pool[rng.randi() % pool.size()]
				opt = {"kind": "trinket", "name": e.name,
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
