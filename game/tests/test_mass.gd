extends SceneTree
## NO-178: PieceMass.build() geometry — the shared crowd renderer used by
## both the Army Choice carousel (menu.gd) and the Reinforcements
## announcement (modals.gd). Asserts observable geometry (bounding box,
## child count, draw order), never an internal flag. Run headless:
##   godot --headless --path game -s tests/test_mass.gd

const PieceMass := preload("res://scripts/piece_mass.gd")
const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _init() -> void:
	_test_aspect()
	_test_determinism()
	_test_child_count()
	_test_horde_fits_carousel_card()
	_test_back_to_front_order()

	print("---")
	if fails == 0:
		print("ALL GREEN")
		quit(0)
	else:
		print("FAILED: %d" % fails)
		quit(1)


## The bounding box should read as "roughly square, slightly wider than
## tall" at a range of counts — Reinforcements' smallest lists and every
## army shape, not just the worst case.
func _test_aspect() -> void:
	var cases := {
		"3 (small reinforce)": ["pawn", "pawn", "knight"],
		"11 (Crown)": Tuning.ARMIES["Crown"],
		"14 (Horde)": Tuning.ARMIES["Horde"],
	}
	for label in cases:
		var mass := PieceMass.build(cases[label])
		var size: Vector2 = mass.custom_minimum_size
		var aspect := size.x / size.y
		check(aspect > 0.85 and aspect < 1.5,
			"aspect near-square for %s (got %.2f, box %sx%s)"
				% [label, aspect, size.x, size.y])


## Same `ids` must draw identically every time (screenshots stay diffable,
## no reshuffle on repaint) — the hash(ids) seed, not randomize().
func _test_determinism() -> void:
	var ids: Array = Tuning.ARMIES["Old Guard"]
	var a := PieceMass.build(ids)
	var b := PieceMass.build(ids)
	check(a.custom_minimum_size == b.custom_minimum_size,
		"determinism: same bounding box across two builds")
	var same := a.get_child_count() == b.get_child_count()
	if same:
		for i in a.get_child_count():
			var ca: TextureRect = a.get_child(i)
			var cb: TextureRect = b.get_child(i)
			if ca.position != cb.position or ca.rotation != cb.rotation \
					or ca.scale != cb.scale or ca.texture != cb.texture:
				same = false
				break
	check(same, "determinism: identical per-child position/rotation/scale/texture")


## Duplicates draw as duplicates — three arriving pawns are three TextureRects,
## never a de-duplicated "pawn ×3".
func _test_child_count() -> void:
	var ids := ["pawn", "pawn", "pawn", "knight"]
	var mass := PieceMass.build(ids)
	check(mass.get_child_count() == ids.size(),
		"child count matches ids.size() including duplicates (%d)" % ids.size())


## Horde's 14 pawns must still fit inside the Army carousel card (NO-179:
## menu.gd _show_armies: card_w = (viewport.x - 80) * ARMY_CARD_WIDTH_FRACTION
## = 400 * 0.70 = 280px at the 480px portrait width this project targets —
## card_w itself is what sized ARMY_CARD_WIDTH_FRACTION in the first place,
## see that constant's own header).
func _test_horde_fits_carousel_card() -> void:
	const CARD_W := 280.0
	var mass := PieceMass.build(Tuning.ARMIES["Horde"])
	check(mass.custom_minimum_size.x <= CARD_W,
		"Horde-14 mass width (%.1f) fits the %spx carousel card"
			% [mass.custom_minimum_size.x, CARD_W])


## Pawns (value 10) sort to the back (drawn first); a rook (value 50) sorts
## to the front (drawn last, on top) — identified by comparing each child's
## loaded texture against the known per-id texture, not by any test-only
## metadata on the node.
func _test_back_to_front_order() -> void:
	var mass := PieceMass.build(["rook", "pawn", "pawn"])
	var pawn_tex := GameScript.load_piece_tex("pawn")
	var rook_tex := GameScript.load_piece_tex("rook")
	var pawn_idx := -1
	var rook_idx := -1
	for i in mass.get_child_count():
		var child: TextureRect = mass.get_child(i)
		var tex: Texture2D = child.texture
		if tex == pawn_tex and pawn_idx == -1:
			pawn_idx = i
		elif tex == rook_tex:
			rook_idx = i
	check(pawn_idx != -1 and rook_idx != -1 and pawn_idx < rook_idx,
		"pawn (back, drawn first at index %d) precedes rook (front, drawn last at index %d)"
			% [pawn_idx, rook_idx])
