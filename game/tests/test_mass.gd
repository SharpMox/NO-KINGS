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

## The Army carousel card's real content width (menu.gd _show_armies:
## card_w=280 minus its own 10+10px side content margins) — every test that
## builds a real Army passes this, the same budget menu.gd's own call site
## passes, so these tests exercise what actually ships rather than
## PieceMass.build()'s unbounded default (which only modals.gd's
## card-less Reinforcements panel relies on).
const CARD_INNER := 260.0

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
	_test_large_pieces_in_front()
	_test_rows_centered()
	_test_horde_row_width()
	_test_min_row_size()
	_test_no_row_overflow()
	_test_no_piece_scaled()
	_test_overflow_splits_instead_of_shrinking()
	_test_slim_pitch_tighter_than_large()
	_test_classification()

	print("---")
	if fails == 0:
		print("ALL GREEN")
		quit(0)
	else:
		print("FAILED: %d" % fails)
		quit(1)


## The bounding box should read as a wide, short rectangle — Max, 2026-09-25,
## reviewing #582's Army captures: "we can make much wider rows, it'll look
## better" (see TARGET_ASPECT's own header) — at a range of counts,
## Reinforcements' smallest lists and every army shape, not just the worst
## case. Bounds widened from the old (0.85, 1.5) "roughly square" range to
## (1.0, 2.0) to fit the new wider rows without going flat/absurd.
func _test_aspect() -> void:
	var cases := {
		"3 (small reinforce)": ["pawn", "pawn", "knight"],
		"11 (Crown)": Tuning.ARMIES["Crown"],
		"14 (Horde)": Tuning.ARMIES["Horde"],
	}
	for label in cases:
		var mass := PieceMass.build(cases[label], CARD_INNER)
		var size: Vector2 = mass.custom_minimum_size
		var aspect := size.x / size.y
		check(aspect > 1.0 and aspect < 2.0,
			"aspect wide-not-flat for %s (got %.2f, box %sx%s)"
				% [label, aspect, size.x, size.y])


## Same `ids` must draw identically every time (screenshots stay diffable,
## no reshuffle on repaint) — the hash(ids) seed, not randomize().
func _test_determinism() -> void:
	var ids: Array = Tuning.ARMIES["Old Guard"]
	var a := PieceMass.build(ids, CARD_INNER)
	var b := PieceMass.build(ids, CARD_INNER)
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


## Horde's 14 pawns must still fit inside the Army carousel card's own
## CONTENT area — CARD_INNER, not the card's outer 280px. 260, not 280, is
## the real bound: a PanelContainer's own minimum size is the LARGER of its
## custom_minimum_size and its content's required size, so a mass wider
## than 260px here silently grows the whole card past 280 and breaks
## NO-179's "every card is the same size" — caught live by
## test_menu_clicks.gd's windowed probe when TARGET_ASPECT briefly overshot
## this (piece_mass.gd, TARGET_ASPECT's own header).
func _test_horde_fits_carousel_card() -> void:
	var mass := PieceMass.build(Tuning.ARMIES["Horde"], CARD_INNER)
	check(mass.custom_minimum_size.x <= CARD_INNER,
		"Horde-14 mass width (%.1f) fits the card's %spx content area"
			% [mass.custom_minimum_size.x, CARD_INNER])


## Pawn (slim) sorts to the back (drawn first); a rook (large) sorts to the
## front (drawn last, on top) — identified by comparing each child's loaded
## texture against the known per-id texture, not by any test-only metadata
## on the node. See _test_large_pieces_in_front() for the general,
## class-driven version of this check across every real Army.
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


## Max, 2026-09-25 (Aux's review of #582): "on Crown and Cult (and Old
## Guard, less so), the Knight at the end of the back row covers its
## neighbour" — large pieces must sit in the FRONT row(s), never behind a
## slim one, EXCEPT where MIN_ROW_PIECES forced a slim piece into the front
## row too (Max: "rule 1 may mix a slim piece into the front row to reach
## 3; that's fine") — a mix WITHIN one row isn't "behind", so the check
## below (row indices, not per-piece order) already allows it. Checked on
## every real Army: groups children into rows (see _rows_of()), identifies
## each child's id by matching its texture against the (deduplicated)
## textures this Army's own ids load, then asserts the LAST row containing
## any slim piece is never further front than the FIRST row containing any
## large piece.
func _test_large_pieces_in_front() -> void:
	for army_name in Tuning.ARMIES:
		var ids: Array = Tuning.ARMIES[army_name]
		var mass := PieceMass.build(ids, CARD_INNER)
		var rows := _rows_of(mass)
		var tex_for_id := {}
		for id in ids:
			if not tex_for_id.has(id):
				tex_for_id[id] = GameScript.load_piece_tex(id)
		var last_slim_row := -1
		var first_large_row := rows.size()
		for r in rows.size():
			for c in rows[r]:
				var found_id := ""
				for id in tex_for_id:
					if tex_for_id[id] == c.texture:
						found_id = id
						break
				check(found_id != "", "%s: every child's texture matches one of its own ids" % army_name)
				if found_id == "":
					continue
				if PieceMass._is_slim(found_id):
					last_slim_row = maxi(last_slim_row, r)
				else:
					first_large_row = mini(first_large_row, r)
		check(last_slim_row <= first_large_row,
			"%s: no large piece behind a slim one (last slim row %d, first large row %d of %d)"
				% [army_name, last_slim_row, first_large_row, rows.size()])


## Groups a built mass's children into rows by Y — children are added in
## row-major order (row-major fill in build()) and rows are ROW_PITCH apart
## (28.08px) while JITTER_Y's wobble is tiny by comparison (<=3.9px), so
## comparing each child's Y against the first child of the current row group,
## with a half-ROW_PITCH tolerance, groups unambiguously without needing to
## know each row's size from outside piece_mass.gd.
func _rows_of(mass: Control) -> Array:
	var rows: Array = []
	for c in mass.get_children():
		if rows.is_empty() or absf(c.position.y - rows[-1][0].position.y) > PieceMass.ROW_PITCH * 0.5:
			rows.append([c])
		else:
			rows[-1].append(c)
	return rows


## Max, 2026-09-25, reviewing #582's Army captures: "I still see rows offset
## to one side instead of aligning to the centre" — every row, not just a
## short one, must sit on the mass's own centre line. Checked on every real
## Army (Crown, Old Guard and Cult mix slim/large pieces and can have an
## uneven last row, now with the large-class pieces grouped into the front
## row(s) too — see _test_large_pieces_in_front(); Horde is a pure-slim 14
## that picks a wide 2-row layout — see TARGET_ASPECT's header) by reading
## each row's span straight off the built children's positions, not by
## re-deriving cols/pitch by hand.
func _test_rows_centered() -> void:
	for label in Tuning.ARMIES:
		var mass := PieceMass.build(Tuning.ARMIES[label], CARD_INNER)
		var mass_center: float = mass.custom_minimum_size.x / 2.0
		var rows := _rows_of(mass)
		check(rows.size() >= 1, "%s: builds at least one row" % label)
		for r in rows.size():
			var left := INF
			var right := -INF
			for c in rows[r]:
				left = minf(left, c.position.x)
				right = maxf(right, c.position.x + PieceMass.ICON)
			var row_center := (left + right) * 0.5
			check(absf(row_center - mass_center) < 1.0,
				"%s row %d/%d centred (row_center=%.2f, mass_center=%.2f)"
					% [label, r, rows.size(), row_center, mass_center])


## Max, 2026-09-25: "we can make much wider rows" — Horde's 14 pawns (all
## slim, so every row is a single pitch class) is the widest-count army, and
## its widest row must use most of the carousel card's own width, not a
## squarish blob. Measured off the built children (see _rows_of()), not
## re-derived from CELL_SLIM/ICON by hand.
##
## Threshold is 65%, not Max's literal "~70%": TARGET_ASPECT is capped by
## CARD_INNER itself (its own header) — the next wider column count for
## Horde (12, ~72.7%) pushes the mass past 260px and breaks NO-179's "every
## card is the same size" (test_menu_clicks.gd's windowed probe caught this
## live). 67.9%, the actual value at the column count TARGET_ASPECT=2.2
## picks, is as close to "~70%" as the card's real budget allows.
func _test_horde_row_width() -> void:
	var mass := PieceMass.build(Tuning.ARMIES["Horde"], CARD_INNER)
	var max_row_w := 0.0
	for row in _rows_of(mass):
		var left := INF
		var right := -INF
		for c in row:
			left = minf(left, c.position.x)
			right = maxf(right, c.position.x + PieceMass.ICON)
		max_row_w = maxf(max_row_w, right - left)
	check(max_row_w >= CARD_INNER * 0.65,
		"Horde-14 widest row (%.1f) is at least 65%% of the card's %spx inner width"
			% [max_row_w, CARD_INNER])


## Max, 2026-09-25, on top of "large pieces go in the front row": "no row
## has fewer than 3 pieces... a lone piece is never allowed. When the front
## row would get 1-2 pieces, pull pieces from the row behind until it has
## 3 ... The only exception is an Army with fewer than 3 pieces in total,
## which gets a single row." Checked on every real Army.
func _test_min_row_size() -> void:
	for label in Tuning.ARMIES:
		var ids: Array = Tuning.ARMIES[label]
		var mass := PieceMass.build(ids, CARD_INNER)
		var rows := _rows_of(mass)
		if ids.size() < PieceMass.MIN_ROW_PIECES:
			check(rows.size() == 1,
				"%s: under-%d Army gets a single row (got %d)"
					% [label, PieceMass.MIN_ROW_PIECES, rows.size()])
			continue
		for r in rows.size():
			check(rows[r].size() >= PieceMass.MIN_ROW_PIECES,
				"%s row %d/%d has >= %d pieces (got %d)"
					% [label, r, rows.size(), PieceMass.MIN_ROW_PIECES, rows[r].size()])


## Max, 2026-09-25: "if a row is too wide for the card's 260 px content
## budget, take 3 pieces out of it... Repeat until every row fits" — checked
## on every row of every real Army (all of which fit today without ever
## needing a split; _test_overflow_splits_instead_of_shrinking() below
## exercises the split path itself with a synthetic worst case).
func _test_no_row_overflow() -> void:
	for label in Tuning.ARMIES:
		var mass := PieceMass.build(Tuning.ARMIES[label], CARD_INNER)
		var rows := _rows_of(mass)
		for r in rows.size():
			var left := INF
			var right := -INF
			for c in rows[r]:
				left = minf(left, c.position.x)
				right = maxf(right, c.position.x + PieceMass.ICON)
			check(right - left <= CARD_INNER + 0.01,
				"%s row %d/%d width (%.1f) fits the %spx budget"
					% [label, r, rows.size(), right - left, CARD_INNER])


## Max, 2026-09-25: "pieces must NEVER be scaled down to fit a wide row...
## Every piece in every mass renders at the same fixed ICON size." The old
## NO-178 back-row depth-perspective scale is gone — build() never sets
## `.scale` at all any more, and nothing else in this renderer touches it —
## checked directly on the built nodes, for every real Army, rather than
## trusting that no code path sets it.
func _test_no_piece_scaled() -> void:
	for label in Tuning.ARMIES:
		var mass := PieceMass.build(Tuning.ARMIES[label], CARD_INNER)
		for c: TextureRect in mass.get_children():
			check(c.scale.is_equal_approx(Vector2.ONE),
				"%s: piece renders unscaled (scale=%s)" % [label, c.scale])
			check(is_equal_approx(c.size.x, PieceMass.ICON) and is_equal_approx(c.size.y, PieceMass.ICON),
				"%s: piece renders at ICON size (size=%s)" % [label, c.size])


## Rule 2 (Max, 2026-09-25): "if a row is too wide for the card's 260 px
## content budget, take 3 pieces out of it and put them in a NEW row ABOVE
## it (further back), then re-check. Repeat until every row fits, and keep
## rule 1 true for the new row." None of the 6 shipped Armies are wide
## enough to actually exercise this (verified: every real Army fits without
## ever splitting — see _test_no_row_overflow()), so this constructs a
## synthetic worst case that does: 34 large-class pieces (Knight) is the
## smallest count where _choose_cols()'s own aspect pick (12 columns, 3
## rows of up to 12) still leaves a row wider than 260px and the overflow
## pass has to intervene. Checks the two invariants the split must keep:
## every resulting row still has >= MIN_ROW_PIECES, and every resulting row
## fits the budget — not an exact row count, which is more sensitive to the
## precise pitch arithmetic than the properties that actually matter.
func _test_overflow_splits_instead_of_shrinking() -> void:
	var ids := []
	for i in 34:
		ids.append("knight")
	var mass := PieceMass.build(ids, CARD_INNER)
	var rows := _rows_of(mass)
	check(rows.size() > 3,
		"34 large pieces split past the 3 rows the aspect pick alone would choose (got %d)"
			% rows.size())
	for r in rows.size():
		check(rows[r].size() >= PieceMass.MIN_ROW_PIECES,
			"overflow split row %d/%d still has >= %d pieces (got %d)"
				% [r, rows.size(), PieceMass.MIN_ROW_PIECES, rows[r].size()])
		var left := INF
		var right := -INF
		for c in rows[r]:
			left = minf(left, c.position.x)
			right = maxf(right, c.position.x + PieceMass.ICON)
		check(right - left <= CARD_INNER + 0.01,
			"overflow split row %d/%d fits the %spx budget (width %.1f)"
				% [r, rows.size(), CARD_INNER, right - left])


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
