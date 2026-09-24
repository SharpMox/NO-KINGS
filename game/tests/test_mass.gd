extends SceneTree
## NO-178: PieceMass.build() geometry — the shared crowd renderer used by
## both the Army Choice carousel (menu.gd) and the Reinforcements
## announcement (modals.gd). Asserts observable geometry (bounding box,
## child count, draw order), never an internal flag. Run headless:
##   godot --headless --path game -s tests/test_mass.gd

const PieceMass := preload("res://scripts/piece_mass.gd")
const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Rules := preload("res://scripts/rules.gd")

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
	_test_partial_row_centered()
	_test_slim_pitch_tighter_than_large()
	_test_classification()

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


## Horde's 14 pawns must still fit inside the Army carousel card (NO-179,
## full-width follow-up: menu.gd _show_armies: card_w = viewport.x *
## ARMY_CARD_WIDTH_FRACTION = 480 * 7/12 = 280px at the 480px portrait width
## this project targets — card_w itself is what sized
## ARMY_CARD_WIDTH_FRACTION in the first place, see that constant's own
## header).
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


## Max's ruling: 2 rows of 3 plus a row of 1 must read as
##   AAA
##   BBB
##    C
## not C flush under A. 7 identical "rook" (large) pieces is the exact case:
## _back_to_front keeps ties in original order, so children add in index
## order and _choose_rows(7, CELL_LARGE) lands on rows=3/cols=3 (verified by
## hand against the same TARGET_ASPECT maths _choose_rows itself uses) —
## rows 0-1 get 3 each, row 2 gets the lone 7th. Row 0 and row 2 are both
## even (neither gets the odd-row STAGGER), so comparing their x positions
## directly, with no stagger to subtract out, isolates the centering fix:
## the lone piece's x must equal row 0's MIDDLE column, not its first.
func _test_partial_row_centered() -> void:
	var ids := []
	for i in 7:
		ids.append("rook")
	var rows := PieceMass._choose_rows(ids.size(), PieceMass.CELL_LARGE)
	var cols := maxi(1, ceili(float(ids.size()) / float(rows)))
	check(rows == 3 and cols == 3,
		"7 uniform pieces choose 3 rows x 3 cols (got %d x %d)" % [rows, cols])
	if rows != 3 or cols != 3:
		return # geometry assumption below doesn't hold; the mismatch is
			# already reported above.
	var mass := PieceMass.build(ids)
	var row0_col1: TextureRect = mass.get_child(1) # row 0, middle column
	var row2_col0: TextureRect = mass.get_child(6) # row 2, the lone piece
	check(is_equal_approx(row2_col0.position.x, row0_col1.position.x),
		"lone row (x=%.2f) centred on row 0's middle column (x=%.2f)"
			% [row2_col0.position.x, row0_col1.position.x])


func _test_slim_pitch_tighter_than_large() -> void:
	check(PieceMass.CELL_SLIM < PieceMass.CELL_LARGE,
		"slim pitch (%.2f) tighter than large pitch (%.2f)"
			% [PieceMass.CELL_SLIM, PieceMass.CELL_LARGE])


## Prints the slim/large call for all 39 known pieces (game/data/pieces.json)
## so it can be reviewed — task ask, not just a pass/fail. Also asserts the
## classification is non-trivial (both buckets used), stable across repeat
## calls (guards the memoization in _slim_cache), and gets the two named
## anchor cases right: Pawn/Void Pawn slim, Rook/Knight/Queen large.
func _test_classification() -> void:
	var ids: Array = Rules.load_pieces().keys()
	ids.sort()
	print("--- piece width classification (SLIM_WIDTH_RATIO=%.2f) ---"
		% PieceMass.SLIM_WIDTH_RATIO)
	var slim_count := 0
	for id in ids:
		var ratio: float = PieceMass._slim_ratio(id)
		var slim: bool = PieceMass._is_slim(id)
		if slim:
			slim_count += 1
		print("%s: %s (ratio=%.3f)" % [id, "slim" if slim else "large", ratio])
	print("--- %d/%d slim ---" % [slim_count, ids.size()])

	check(ids.size() == 39, "39 known pieces classified (got %d)" % ids.size())
	check(slim_count > 0 and slim_count < ids.size(),
		"classification is non-trivial: %d/%d slim" % [slim_count, ids.size()])

	var stable := true
	for id in ids:
		if PieceMass._is_slim(id) != PieceMass._is_slim(id):
			stable = false
			break
	check(stable, "classification is stable across repeated calls")

	check(PieceMass._is_slim("pawn"), "Pawn classified slim")
	check(PieceMass._is_slim("berolina"), "Void Pawn (berolina) classified slim")
	check(not PieceMass._is_slim("rook"), "Rook classified large")
	check(not PieceMass._is_slim("knight"), "Knight classified large")
	check(not PieceMass._is_slim("queen"), "Queen classified large")
