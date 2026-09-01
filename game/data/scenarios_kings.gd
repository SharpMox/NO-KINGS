## issue 82: one hand-playable sandbox per King (16), GENERATED.
##
## Kings arrive at waves 50/100/150/200 and a run meets ONE costume tier (issue
## 89), so without these the only way to look at a kit is a 50-wave run — and
## twelve of the sixteen are unreachable in any single run however long it goes.
##
## Derived from `Kings.ROSTER`, never hand-transcribed, so a roster edit gets a
## sandbox with no edit here. Ids, never display names (the issue 58
## convention): entries key on the King id and only ever *show* the name.
##
## THE POWER is live from the first turn because every Power branch reads
## `g.king_power_id` — `power_hook`, `power_is` and `deports_captures` all key
## off it (kings.gd) — and `save_config.gd` restores it straight from the
## config. Nothing here advances a wave, so `Kings.apply_power()` never runs;
## setting the field is what stands in for it.
##
## THE ABILITY needs no trigger of its own: `game.gd:_run_enemy_actions` spends
## one enemy Action on `Kings.fire_ability` whenever the King is on the board,
## so ending a turn fires it. It is once per Wave and no wave ever turns over
## here, so it fires once per load — reload to watch it again.

const Kings := preload("res://data/kings.gd")

## ONE template serves all 16. The kits bite different things — the highest
## value piece, the two least valuable, held Items, Piece Buffs, deploy cost,
## Gold gains, Score gains, captures — so the board carries one of each rather
## than sixteen bespoke setups that would drift apart the first time a kit
## changed.
const PLAYER := [
	["queen", 0, 3, 1],                     # highest value: Nebuchadnezzar crumbles it
	["rook", 0, 5, 1, {"buffs": [{"key": "shield"}, {"key": "critical"}]}],
		                                    # two Buffs (the cap): Genghis strips them
	["pawn", 0, 1, 0], ["pawn", 0, 6, 0],   # least valuable: Tamerlane's pyramid takes these
	["knight", 0, 3, 7],                    # past BOARD_H/2, so Putin's annex reaches it
]
## Takeable enemies, so the Powers that modify what a capture pays (Nero's
## halved Gold, Tamerlane's halved Score, Nebuchadnezzar's deported captures)
## have something to modify within a move or two.
const ENEMY := [
	["pawn", 1, 2, 8], ["pawn", 1, 4, 8], ["rook", 1, 6, 10],
]
const KING_AT := Vector2i(3, 10)


static func all() -> Array:
	var out: Array = []
	for tier in Kings.TIER_ORDER:
		for k in Kings.ROSTER[tier]:
			var kit: Dictionary = Kings.kit_of(k.id)
			var board: Array = PLAYER.duplicate(true) + ENEMY.duplicate(true)
			board.append(["king", 1, KING_AT.x, KING_AT.y, {"king_id": k.id}])
			var cfg := {
				"board": board,
				"stock": ["pawn", "pawn", "rook"], # deploy cost: Qin Shi Huang doubles it
				"items": ["blitz", "promote", "air_strike"], # the Item cap; Nero burns them
				"gold": 300, "score": 500,
				"king_power_id": k.id,
				"seed": abs(hash(k.id)),
			}
			# Donald Trump's Power is the ONLY tariff-backed one (Tariff ->
			# `inflation`, slice 66); the other 15 are bespoke keys that
			# king_power_id alone switches on. Listing the tariff in the config
			# activates it exactly as apply_power() would.
			# ponytail: this leaves g.king_power_tariff unset, so the tariff
			# would outlive its wave — unreachable here (a sandbox turns no
			# wave over). Call Kings.apply_power() from save_config if a
			# scenario ever needs to advance past its King.
			var power_tariff: String = str(kit.get("power_tariff", ""))
			if power_tariff != "":
				cfg["tariffs"] = [power_tariff]
			# Named for the Power, which is the thing that is live on arrival —
			# the Ability announces itself in the turn feed when it fires.
			# menu.gd cuts at the first ":", so all 16 land in one "King"
			# section, clear of the existing "King wave" entry.
			out.append({
				"name": "King: %s — %s" % [k.name, kit.get("power_name", "no kit")],
				"cfg": cfg,
			})
	return out
