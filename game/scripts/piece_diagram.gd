## Piece movement-diagram renderer (NO-139) — a Godot port of the reference
## site's VISUAL LANGUAGE (assets/board.js), not a port of its JavaScript.
## Pure drawing: every shape here takes already-resolved board-relative
## squares/directions and paints them. It never decides what a piece can do
## — `_shapes_for` derives that straight from `defs[id].moves`, the same
## move model rules.gd itself reads (type leap/ride/bent, dirs, range,
## mode; see rules.gd's `moves_for`/`move_paths`), so a diagram can never
## disagree with the rules engine.
##
## Colours intentionally reuse game.gd's own COL_MOVE/COL_CAPTURE literals
## (blue = move, red = capture, "palette rule 2026-07-07") rather than
## assets/site.css's tokens, so the diagram matches the live board it sits
## next to, not the reference site. They land close to site.css's DARK
## theme anyway (--move-color #79a7ff / --capture-color #ff7878). The board
## squares are the one deliberate disagreement: they keep game.gd's own
## COL_LIGHT/COL_DARK chequer (NO-177: pale sage green / muted aubergine,
## exact hex from Max 2026-09-20, superseding the "NOKINGSBG palette" of
## issue 70) instead of site.css's dark chequer (#4a4270/#241d3e) — this
## diagram lives inside the live game and should read as the same board the
## player is already looking at, not the reference site's.
##
## `hop`/`capture-hop` are NOT ported. board.js's move model has them, but
## rules.gd's does not — `game/data/pieces.json` has exactly three move
## types (leap/ride/bent; audited 2026-09-19, 0 pieces use anything else)
## and no hurdle/hop concept exists anywhere in rules.gd or buff_logic.gd.
## Drawing geometry nothing can ever feed is untestable dead code, which
## this project's scope discipline rules out — see NO-139's report for the
## full audit. Add them back the day a piece's move model actually needs
## them; the exact geometry is in the NO-139 ticket.

const COL_LIGHT := Color("D0E6B3") # matches game.gd COL_LIGHT (NO-177)
const COL_DARK := Color("573F6E")  # matches game.gd COL_DARK (NO-177)
const COL_MOVE := Color(0.3, 0.55, 0.95, 0.8)  # matches game.gd COL_MOVE
const COL_CAPTURE := Color(0.85, 0.15, 0.15)   # matches game.gd COL_CAPTURE
const COL_RIDER := Color("ffae5c") # site.css --rider-color (dark) — no game.gd equivalent yet


## Draws the full diagram: chequer, piece glyph, every move shape for `id`.
## `tex` is the piece's own token (or null to skip it) — passed in because
## this script has no access to the Game node's `textures` dictionary.
static func draw(dia: Control, defs: Dictionary, id: String, cells: int, cell: int, tex: Texture2D) -> void:
	var c := cells / 2
	for x in cells:
		for y in cells:
			dia.draw_rect(Rect2(Vector2(x, y) * cell, Vector2(cell, cell)),
				COL_LIGHT if (x + y) % 2 == 0 else COL_DARK)
	if tex != null:
		dia.draw_texture_rect(tex,
			Rect2(Vector2(c, c) * cell + Vector2(2, 2), Vector2(cell - 4, cell - 4)), false)
	for shape in _shapes_for(defs[id].moves):
		_draw_shape(dia, shape, cells, cell)


## Translates rules.gd's own move model into renderer shapes. One shape per
## source move object (leap, bent) or per direction (ride, since a single
## ride move could in principle mix unit and multi-square steps).
static func _shapes_for(moves: Array) -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []
	for m in moves:
		match m.type:
			"leap":
				var kind: String = "dots" if m.mode == "both" else ("rings" if m.mode == "move" else "xs")
				shapes.append({"kind": kind, "squares": m.dirs})
			"ride":
				var max_range: int = int(m.get("range", 0))
				var rays: Array = []
				for dir in m.dirs:
					# a unit step slides square-by-square (rook/bishop-style) —
					# board.js's "rays": a line + arrowhead to the last square.
					# A step with magnitude >1 (knight-style, e.g. Banshee's
					# (1,2)) repeats a LEAP outward — board.js's "rider": dots
					# at each leap point, dashed, with a continuation arrow.
					if absi(int(dir[0])) <= 1 and absi(int(dir[1])) <= 1:
						rays.append(dir)
					else:
						shapes.append({"kind": "rider", "dir": dir})
				if not rays.is_empty():
					shapes.append({"kind": "rays", "dirs": rays, "max_range": max_range})
			"bent": # one leap to a pivot, then a ride outward from it
				shapes.append({"kind": "bent", "pivot": m.pivot, "dir": m.dir})
	return shapes


static func _draw_shape(dia: Control, shape: Dictionary, cells: int, cell: int) -> void:
	var c := cells / 2
	match shape.kind:
		"dots":
			for sq in shape.squares:
				dia.draw_circle(_center(c, cell, sq), cell * 0.22, COL_MOVE)
		"rings":
			for sq in shape.squares:
				dia.draw_arc(_center(c, cell, sq), cell * 0.22, 0, TAU, 24, COL_MOVE, 2.5, true)
		"xs":
			for sq in shape.squares:
				_draw_x(dia, _center(c, cell, sq), cell * 0.22, COL_CAPTURE)
		"rays":
			for dir in shape.dirs:
				_draw_ray(dia, cells, cell, dir, int(shape.max_range))
		"rider":
			_draw_rider(dia, cells, cell, shape.dir)
		"bent":
			_draw_bent(dia, cells, cell, shape.pivot, shape.dir)


static func _center(c: int, cell: int, sq) -> Vector2:
	return Vector2(c + int(sq[0]), c - int(sq[1])) * float(cell) + Vector2(cell, cell) / 2.0 # +y is up


## Fakes an SVG round line-cap (Godot's draw_line has none) with a filled
## circle of radius = width/2 at each end.
static func _capped_line(dia: Control, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	dia.draw_line(from, to, color, width, true)
	var r := width / 2.0
	dia.draw_circle(from, r, color)
	dia.draw_circle(to, r, color)


static func _draw_x(dia: Control, pc: Vector2, r: float, color: Color) -> void:
	_capped_line(dia, pc + Vector2(-r, -r), pc + Vector2(r, r), color, 3.0)
	_capped_line(dia, pc + Vector2(r, -r), pc + Vector2(-r, r), color, 3.0)


## Godot's draw_line has no dash support — segments a line by hand into
## alternating dash/gap runs. `opacity` multiplies `color`'s own alpha,
## matching board.js's dashed strokes (which are drawn at reduced opacity).
static func _dashed_line(dia: Control, from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float, opacity: float) -> void:
	var col := Color(color, color.a * opacity)
	var total := from.distance_to(to)
	if total <= 0.0:
		return
	var dir := (to - from) / total
	var pos := 0.0
	var on := true
	while pos < total:
		var seg: float = min(dash if on else gap, total - pos)
		if on:
			dia.draw_line(from + dir * pos, from + dir * (pos + seg), col, width, true)
		pos += seg
		on = not on


## A unit-step slide (rook/bishop/queen-style): a line from just off centre
## to an arrowhead at the furthest reachable square. Stops at the diagram
## edge (|x|,|y| > c) or at `max_range` (0 = unbounded), matching board.js's
## own "rays" clip exactly.
static func _draw_ray(dia: Control, cells: int, cell: int, dir: Array, max_range: int) -> void:
	var c := cells / 2
	var dx := int(dir[0])
	var dy := int(dir[1])
	var last := [0, 0]
	var steps := 0
	while true:
		var nx: int = last[0] + dx
		var ny: int = last[1] + dy
		if absi(nx) > c or absi(ny) > c:
			break
		last = [nx, ny]
		steps += 1
		if max_range > 0 and steps >= max_range:
			break
	if last[0] == 0 and last[1] == 0:
		return
	var start := _center(c, cell, [0, 0])
	var tip := _center(c, cell, last)
	var fwd := (tip - start).normalized()
	var line_start := start + fwd * cell * 0.42
	var arrow_len := cell * 0.30
	var arrow_w := cell * 0.16
	var base := tip - fwd * arrow_len
	var perp := Vector2(-fwd.y, fwd.x) * arrow_w
	_capped_line(dia, line_start, base, COL_MOVE, 3.4)
	dia.draw_colored_polygon(PackedVector2Array([tip, base + perp, base - perp]), COL_MOVE)


## A repeated-leap "rider" (Nightrider-style, e.g. Banshee's (1,2)): a dashed
## line through a dot at each leap point, then a continuation arrowhead —
## drawn only if its tip still lands inside the diagram, exactly like
## board.js's own inset-4 check.
static func _draw_rider(dia: Control, cells: int, cell: int, dir: Array) -> void:
	var c := cells / 2
	var dx := int(dir[0])
	var dy := int(dir[1])
	var dots: Array = []
	var s := 1
	while absi(dx * s) <= c and absi(dy * s) <= c:
		dots.append([dx * s, dy * s])
		s += 1
	if dots.is_empty():
		return
	var pts: Array[Vector2] = [_center(c, cell, [0, 0])]
	for d in dots:
		pts.append(_center(c, cell, d))
	for i in pts.size() - 1:
		_dashed_line(dia, pts[i], pts[i + 1], COL_RIDER, 1.4, 3.0, 3.0, 0.65)
	for i in range(1, pts.size()):
		dia.draw_circle(pts[i], cell * 0.18, COL_RIDER)
	var last_pt: Vector2 = pts[pts.size() - 1]
	var prev_pt: Vector2 = pts[pts.size() - 2]
	var delta := last_pt - prev_pt
	if delta.length() < 0.001:
		return
	var udir := delta.normalized()
	var tip := last_pt + udir * cell * 0.40
	var size := cells * cell
	if tip.x < 4 or tip.x > size - 4 or tip.y < 4 or tip.y > size - 4:
		return
	var arrow_len := cell * 0.22
	var arrow_w := cell * 0.13
	var base := tip - udir * arrow_len
	var perp := Vector2(-udir.y, udir.x) * arrow_w
	dia.draw_colored_polygon(PackedVector2Array([tip, base + perp, base - perp]), Color(COL_RIDER, 0.85))


## A "bent" move (one leap to a pivot, then an unbounded ride outward from
## it — Gryphon-style): a solid line from just off centre to the pivot, then
## either a dot (nothing beyond the pivot) or a continuation ray + a small
## dot marking the pivot itself.
static func _draw_bent(dia: Control, cells: int, cell: int, pivot: Array, dir: Array) -> void:
	var c := cells / 2
	var start := _center(c, cell, [0, 0])
	var pivot_c := _center(c, cell, pivot)
	var leap_fwd := (pivot_c - start).normalized()
	var leap_start := start + leap_fwd * cell * 0.42
	_capped_line(dia, leap_start, pivot_c, Color(COL_MOVE, 0.85), 2.6)

	var dx := int(dir[0])
	var dy := int(dir[1])
	var px := int(pivot[0])
	var py := int(pivot[1])
	var last := [px, py]
	while true:
		var nx: int = last[0] + dx
		var ny: int = last[1] + dy
		if absi(nx) > c or absi(ny) > c:
			break
		last = [nx, ny]
	if last[0] == px and last[1] == py:
		dia.draw_circle(pivot_c, cell * 0.18, COL_MOVE)
		return
	var end_c := _center(c, cell, last)
	var slide_fwd := (end_c - pivot_c).normalized()
	var arrow_len := cell * 0.28
	var arrow_w := cell * 0.14
	var base := end_c - slide_fwd * arrow_len
	var perp := Vector2(-slide_fwd.y, slide_fwd.x) * arrow_w
	_capped_line(dia, pivot_c, base, COL_MOVE, 2.8)
	dia.draw_colored_polygon(PackedVector2Array([end_c, base + perp, base - perp]), COL_MOVE)
	dia.draw_circle(pivot_c, cell * 0.10, COL_MOVE)
