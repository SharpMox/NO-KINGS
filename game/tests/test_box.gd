extends SceneTree
## 9 typed Boxes (issue 47): 3 sizes (small 3/1, big 5/1, huge 7/2) x 3 themes
## (piece/artefact/item). Contents are rolled once at Shop-stock time and
## stored on the slot — the Shop-integration side of that (test_shop.gd)
## proves reveal == what was stocked; this file is Box.roll_options' own
## shape/weighting, independent of the Shop wiring.
## Run headless:  godot --headless --path game -s tests/test_box.gd

const GameScript := preload("res://scripts/game.gd")
const Box := preload("res://scripts/box.gd")
const Shop := preload("res://scripts/shop.gd")
const Tuning := preload("res://scripts/tuning.gd")

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

	# --- shape: choices/picks by size, offer never repeats within itself ---
	check(Box.SIZES.small.choices == 3 and Box.SIZES.small.picks == 1, "Small: 3 choices, 1 pick")
	check(Box.SIZES.big.choices == 5 and Box.SIZES.big.picks == 1, "Big: 5 choices, 1 pick")
	check(Box.SIZES.huge.choices == 7 and Box.SIZES.huge.picks == 2, "Huge: 7 choices, 2 picks")

	for theme in Box.THEMES:
		for size in Box.SIZE_KEYS:
			var opts: Array = Box.roll_options(game, theme, size)
			check(opts.size() == Box.SIZES[size].choices,
				"%s %s Box: %d choices" % [size, theme, Box.SIZES[size].choices])
			var names := {}
			var shaped := true
			for o in opts:
				shaped = shaped and o.kind == theme and o.name != "" and o.description != ""
				names[o.name] = true
			check(shaped, "%s %s Box: every option is themed %s, self-describing" % [size, theme, theme])
			check(names.size() == opts.size(), "%s %s Box: options never repeat" % [size, theme])

	# --- Piece theme draws from Shop.base_piece_pool (issue 47, user call):
	# chain roots only, never the King or an inversion piece — a Box can't
	# hand out a chain-end piece and skip the merge/promotion ladder ---
	var piece_opts: Array = Box.roll_options(game, "piece", "huge")
	var all_from_pool := true
	var pool: Array = Shop.base_piece_pool(game.defs)
	for o in piece_opts:
		all_from_pool = all_from_pool and pool.has(o.payload)
	check(all_from_pool, "every Piece Box option is a base_piece_pool entry (chain root)")
	var no_king_or_inversion := true
	for o in piece_opts:
		no_king_or_inversion = no_king_or_inversion and o.payload != "king" \
			and not str(o.payload).begins_with("inv-")
	check(no_king_or_inversion, "a Piece Box never offers the King or an inversion piece")

	# --- choosing applies by kind (game.gd's _box_choose) ---
	var slot := {"kind": "box", "key": "piece", "size": "small", "sold": false,
		"contents": Box.roll_options(game, "piece", "small")}
	game._open_box_pick(slot)
	var stock_n: int = game.stock.size()
	game._box_choose(game.box_offer[0])
	check(game.stock.size() == stock_n + 1, "picking a Piece Box option lands it in Stock")
	check(not game.box_open, "a Small Box (1 pick) closes after one choice")

	var item_opt: Dictionary = Box.roll_options(game, "item", "small")[0]
	game._open_box_pick({"kind": "box", "key": "item", "size": "small", "sold": false,
		"contents": [item_opt]})
	game._box_choose(game.box_offer[0])
	check(game.items.size() == 1, "picking an Item Box option adds it to the held items")

	var artefact_opt: Dictionary = Box.roll_options(game, "artefact", "small")[0]
	game._open_box_pick({"kind": "box", "key": "artefact", "size": "small", "sold": false,
		"contents": [artefact_opt]})
	game._box_choose(game.box_offer[0])
	check(game.artefacts.size() == 1, "picking an Artefact Box option adds a run-long passive")

	# --- Huge grants 2 native picks (issue 47) ---
	var huge_slot := {"kind": "box", "key": "item", "size": "huge", "sold": false,
		"contents": Box.roll_options(game, "item", "huge")}
	game._open_box_pick(huge_slot)
	check(game.box_picks_left == 1, "Huge starts with 1 extra pick beyond the first (2 native picks)")
	game._box_choose(game.box_offer[0])
	check(game.box_open, "Huge: the first pick doesn't close the Box")
	game._box_choose(game.box_offer[0])
	check(not game.box_open, "Huge: the second (native) pick closes the Box")

	# --- issue 20 (rarity weighting), depth gating reverted 2026-08-28: flat
	# for the whole run — a roguelike lets a lucky early Legendary be a good
	# story, and the Shop already gates rarity by price (SHOP_ARTEFACT_PRICE)
	check(Tuning.artefact_rarity_weight("Common") == 100.0
			and Tuning.artefact_rarity_weight("Legendary") == 10.0,
		"Common outweighs Legendary 10:1")
	check(Tuning.artefact_rarity_weight("") == Tuning.artefact_rarity_weight("Common"),
		"the 7 core (unrated) artefacts weigh the same as Common")

	var pool2 := [{"rarity": "Common"}, {"rarity": "Legendary"}]
	var wrng := RandomNumberGenerator.new()
	wrng.seed = 1
	var common_n := 0
	var legend_n := 0
	for i in 2000:
		if Tuning.weighted_artefact_pick(pool2, wrng) == 0:
			common_n += 1
		else:
			legend_n += 1
	check(common_n > legend_n * 5,
		"the weighted pick strongly favors Common (%d vs %d)" % [common_n, legend_n])

	# integration: an Artefact Box's rarity mix doesn't shift with game.score —
	# no depth signal reaches it any more
	game.score = 0
	var low := {}
	for i in 400:
		for o in Box.roll_options(game, "artefact", "small"):
			var r: String = str(o.payload.get("rarity", ""))
			if r != "":
				low[r] = low.get(r, 0) + 1
	game.score = 50000 # what used to be "far past the depth cap"
	var high := {}
	for i in 400:
		for o in Box.roll_options(game, "artefact", "small"):
			var r: String = str(o.payload.get("rarity", ""))
			if r != "":
				high[r] = high.get(r, 0) + 1
	var low_total := 0
	for v in low.values():
		low_total += v
	var high_total := 0
	for v in high.values():
		high_total += v
	var low_common_share := float(low.get("Common", 0)) / float(maxi(1, low_total))
	var high_common_share := float(high.get("Common", 0)) / float(maxi(1, high_total))
	check(absf(low_common_share - high_common_share) < 0.15,
		"Common's share of Artefact Box rolls stays flat regardless of Score (%.2f vs %.2f)"
			% [low_common_share, high_common_share])

	game.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL BOX CHECKS OK")
	quit(1 if fails > 0 else 0)
