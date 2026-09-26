extends SceneTree
## NO-264 option B: Guide illustrations composed from the game's own assets —
## piece tokens (Game.load_piece_tex), the board chequer and highlight palette
## (game.gd's COL_* / HATCH_* / ZONE_* constants, read off the class, never
## restated), Buff badge glyphs (BuffLogic), the movement diagram
## (PieceDiagram.draw) and Pixel Operator — drawn into an off-screen SubViewport
## and saved as PNGs at S x the in-game pixel size.
##
## One command renders every image into game/assets/guide/:
##   tools/godot-lock.sh godot --path game -s tools/guide_images.gd
## Windowed, not --headless: frame_post_draw never resolves headless (CLAUDE.md,
## "The --screenshot seam is windowed"). CI renders them under xvfb
## (.github/workflows/guide-images.yml) and uploads them as an artifact.
##
## Board images are real positions: a board Dictionary run through Rules
## (moves_for, move_paths, placement_tiles), so what is hatched is what the game
## would allow. The hatch, outline, arrow, badge and inversion-mark shapes are
## small ports of game.gd instance methods (_draw_hatch, _draw_zone_outline,
## _draw_move_arrow, _draw_buff_badge, _draw_piece), which draw onto the live
## board and cannot be called from here. Constants are shared; shapes are copied.
## ponytail: ported shapes can drift from game.gd; if they do, render from a real
## Game node with the HUD hidden instead.

const Game := preload("res://scripts/game.gd")
const Rules := preload("res://scripts/rules.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")
const PieceDiagram := preload("res://scripts/piece_diagram.gd")
const _UiFonts := preload("res://scripts/ui_fonts.gd") # its _static_init chains NoKingsSymbols behind Pixel Operator
const PIXEL := preload("res://assets/fonts/PixelOperator.ttf")

const S := 2 # output scale over the in-game 480x800 canvas
const TILE := 56 * S # about the in-game board tile at 480x800
const GAP := TILE * 3 / 4 # room between strip tiles for a "+" / "→"
const CAPTION_H := 28 * S
const TEXT_COL := Color.WHITE
const TEXT_EDGE := Color(0, 0, 0, 0.9) # outline, so text reads on light and dark alike
const DIA_CELLS := 7
const DIA_CELL := 24 # logical px; the diagram is drawn at S x through a transform
const DIA_CAPTION_H := 44 * S
const OUT_DIR := "res://assets/guide"

var defs: Dictionary
## Every texture drawn so far. A canvas draw command does not hold its texture,
## so a load()ed token nobody else references is freed before the frame renders
## and draws as a plain white square.
var _held: Array[Texture2D] = []
## The board window the current image shows: bottom-left tile + size, board
## coordinates (y=0 is the player's back row).
var _win := Rect2i()
## The board's symbol font: ThemeDB.fallback_font, as game.gd _draw uses, plus
## named fallbacks so a machine whose OS fallback misses a glyph (CI's runner:
## ⨯ ⟲) still draws it. Where the OS fallback already has it this changes nothing.
var _sym: Font


func _initialize() -> void:
	defs = Rules.load_pieces()
	var sym := FontVariation.new()
	sym.base_font = ThemeDB.fallback_font
	var chain: Array[Font] = []
	for family in ["Noto Sans Math", "Noto Sans Symbols 2", "Noto Sans Symbols", "DejaVu Sans"]:
		var f := SystemFont.new()
		f.font_names = PackedStringArray([family])
		chain.append(f)
	sym.fallbacks = chain
	_sym = sym
	var images := {
		# Rules
		"rules-board": _board_image(Rect2i(0, 0, 8, 5), [["rook", 0, 0, 0], ["knight", 0, 1, 0],
			["bishop", 0, 2, 0], ["pawn", 0, 3, 1], ["pawn", 0, 4, 1], ["knight", 0, 5, 3]], {"place": true}),
		"merge-pawns": _strip_image(3, _merge_pawns),
		# Pieces / Promotions / Fusions
		"pieces-diagram-legend": [Vector2i(2 * DIA_CELLS * DIA_CELL * S + GAP, 2 * (DIA_CELLS * DIA_CELL * S + DIA_CAPTION_H)), _diagram_legend],
		"promotions-chain": _strip_image(_chain("pawn").size(), _promotion_chain),
		"fusions-strip": _strip_image(3, _fusion_strip),
		# Items
		"buff-badges": _strip_image(3, _buff_badges),
		# Indicators, one per row of guide.gd _fill_indicators
		"ind-move": _board_image(Rect2i(0, 0, 5, 5), [["rook", 0, 2, 2], ["pawn", 0, 2, 4], ["pawn", 0, 4, 2]], {"sel": Vector2i(2, 2)}),
		"ind-capture": _board_image(Rect2i(0, 0, 5, 5), [["knight", 0, 2, 2], ["pawn", 1, 3, 4], ["rook", 1, 0, 1]], {"sel": Vector2i(2, 2)}),
		"ind-selected": _board_image(Rect2i(0, 0, 3, 3), [["knight", 0, 1, 1]], {"sel": Vector2i(1, 1), "moves": false}),
		"ind-merge-target": _board_image(Rect2i(0, 0, 4, 3), [["pawn", 0, 1, 1], ["pawn", 0, 2, 1]],
			{"sel": Vector2i(1, 1), "moves": false, "target": Vector2i(2, 1)}),
		"ind-zone": _board_image(Rect2i(0, 0, 5, 5), [["bodyguard", 0, 2, 2]], {"sel": Vector2i(2, 2)}),
		"ind-overlap": _board_image(Rect2i(0, 0, 5, 5), [["rook", 0, 2, 1], ["pawn", 1, 2, 4], ["pawn", 0, 4, 1]], {"sel": Vector2i(2, 1)}),
		"ind-blast": _board_image(Rect2i(0, 0, 5, 5), [["pawn", 1, 2, 2], ["knight", 1, 1, 3], ["bishop", 0, 3, 1]],
			{"zone": _around(Vector2i(2, 2))}),
		"ind-placement": _board_image(Rect2i(0, 2, 5, 3), [["knight", 0, 2, 3]], {"place": true}),
		"ind-your-pieces": _board_image(Rect2i(0, 0, 4, 1), [["pawn", 0, 0, 0], ["knight", 0, 1, 0], ["bishop", 0, 2, 0], ["rook", 0, 3, 0]]),
		"ind-enemy-pieces": _board_image(Rect2i(0, 0, 4, 1), [["pawn", 1, 0, 0], ["knight", 1, 1, 0], ["bishop", 1, 2, 0], ["rook", 1, 3, 0]]),
		"ind-inverted": _board_image(Rect2i(0, 0, 2, 1), [["sergeant", 0, 0, 0], ["inv-sergeant", 0, 1, 0]]),
	}
	# Items > Buff detail: one tile per Piece Buff, carrying its badge
	for key: String in BuffLogic.PIECE_BUFF_GLYPHS:
		images["buff-" + key] = _board_image(Rect2i(0, 0, 1, 1), [["rook", 0, 0, 0, [BuffLogic.glyph_of(key)]]])

	var out := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	var fails := 0
	for name: String in images:
		var vp := SubViewport.new()
		vp.size = images[name][0]
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var canvas := Canvas.new()
		canvas.size = Vector2(vp.size)
		canvas.paint = images[name][1]
		vp.add_child(canvas)
		root.add_child(vp)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := out.path_join(name + ".png")
		var err := vp.get_texture().get_image().save_png(path)
		print("%s %s" % ["wrote" if err == OK else "FAILED (%d)" % err, path])
		fails += int(err != OK)
		vp.queue_free()
	quit(1 if fails > 0 else 0)


class Canvas extends Control:
	var paint: Callable

	func _draw() -> void:
		paint.call(self)


# --- image builders: [size in px, paint callable] -------------------------------

func _board_image(win: Rect2i, pieces: Array, opts := {}) -> Array:
	return [win.size * TILE, func(c: Control) -> void: _scene(c, win, pieces, opts)]


func _strip_image(n: int, paint: Callable) -> Array:
	return [Vector2i(n * TILE + (n - 1) * GAP, TILE + CAPTION_H), paint]


# --- strips -----------------------------------------------------------------------

## Rules > Merging: Pawn (selected) + Pawn (merge target) → the Pawn's `next`.
func _merge_pawns(c: Control) -> void:
	var tiles := _strip(c, ["pawn", "pawn", defs.pawn.next])
	c.draw_rect(tiles[0], Game.COL_SELECT)
	_piece(c, "pawn", Rules.PLAYER, tiles[0], true)
	_merge_target(c, tiles[1])
	_between(c, tiles[0], tiles[1], "+")
	_between(c, tiles[1], tiles[2], "→")


## Promotions: the Pawn Family, base to top, each step a merge of two.
func _promotion_chain(c: Control) -> void:
	var tiles := _strip(c, _chain("pawn"))
	for i in tiles.size() - 1:
		_between(c, tiles[i], tiles[i + 1], "→", "2 of a kind")


## Fusions: Bishop + Rook → whatever fusions.json says they make.
func _fusion_strip(c: Control) -> void:
	var tiles := _strip(c, ["bishop", "rook", Rules.load_fusions()["bishop+rook"]])
	_between(c, tiles[0], tiles[1], "+")
	_between(c, tiles[1], tiles[2], "→")


## Items > Piece Buffs: a Rook with one Buff, with two, and Stunned (red badge).
func _buff_badges(c: Control) -> void:
	var shield := BuffLogic.glyph_of("shield")
	var crit := BuffLogic.glyph_of("critical")
	var rows := [
		[[shield], -1, BuffLogic.name_of("shield")],
		[[shield, crit], -1, "%s + %s" % [BuffLogic.name_of("shield"), BuffLogic.name_of("critical")]],
		[[shield, Game.STUN_BADGE_GLYPH], 1, "Stunned"],
	]
	var tiles := _strip(c, ["rook", "rook", "rook"], false)
	for i in 3:
		_badges(c, tiles[i], rows[i][0], rows[i][1])
		_caption(c, tiles[i], rows[i][2])


## Tiles left to right with GAP between, alternating chequer, each piece captioned
## with its name (unless `named` is false). Returns the tile rects.
func _strip(c: Control, ids: Array, named := true) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in ids.size():
		var r := Rect2(Vector2(i * (TILE + GAP), 0), Vector2(TILE, TILE))
		out.append(r)
		c.draw_rect(r, Game.COL_LIGHT if i % 2 == 0 else Game.COL_DARK)
		_piece(c, ids[i], Rules.PLAYER, r)
		if named:
			_caption(c, r, defs[ids[i]].name)
	return out


func _chain(id: String) -> Array:
	var chain := [id]
	while defs[chain[-1]].get("next"):
		chain.append(defs[chain[-1]].next)
	return chain


# --- Pieces > detail: how to read a movement diagram ---------------------------

## Four diagrams drawn by PieceDiagram.draw itself, each captioned with the
## LEGEND marks it shows.
func _diagram_legend(c: Control) -> void:
	var cards := [
		["knight", "● move + capture"],
		["pawn", "○ move only   ✕ capture only"],
		["rook", "➜ slide"],
		["banshee", "⇢ rider"],
	]
	var side := DIA_CELLS * DIA_CELL * S
	for i in cards.size():
		var at := Vector2((i % 2) * (side + GAP), (i / 2) * (side + DIA_CAPTION_H))
		var tex := Game.load_piece_tex(cards[i][0])
		_held.append(tex)
		c.draw_set_transform(at, 0.0, Vector2(S, S))
		PieceDiagram.draw(c, defs, cards[i][0], DIA_CELLS, DIA_CELL, tex)
		c.draw_set_transform(Vector2.ZERO)
		_text(c, Vector2(at.x, at.y + side + 20 * S), defs[cards[i][0]].name, side, 16 * S)
		_text(c, Vector2(at.x, at.y + side + 38 * S), cards[i][1], side, 14 * S)


# --- board scenes ---------------------------------------------------------------

## A window onto a real board. `pieces`: [id, owner, x, y, optional badge glyphs].
## Options: "sel" (tile) selects it and, unless "moves" is false, shows its moves
## as the board does; "zone" (tiles) is a red blast / armed-Item zone; "place"
## shows the placement dots; "target" (tile) marks a merge target.
func _scene(c: Control, win: Rect2i, pieces: Array, o: Dictionary) -> void:
	_win = win
	var board := {}
	for p in pieces:
		board[Vector2i(p[2], p[3])] = {"id": p[0], "owner": p[1]}
	for x in range(win.position.x, win.end.x):
		for y in range(win.position.y, win.end.y):
			c.draw_rect(_tile(Vector2i(x, y)), Game.COL_LIGHT if (x + y) % 2 == 0 else Game.COL_DARK)
	var sel: Vector2i = o.get("sel", Vector2i(-1, -1))
	if sel.x >= 0:
		c.draw_rect(_tile(sel), Game.COL_SELECT)
		if o.get("moves", true):
			var dests := Rules.moves_for(board, sel, defs)
			var caps: Array[Vector2i] = []
			for d in dests:
				if board.has(d):
					caps.append(d)
					_hatch(c, _tile(d), Color(Game.COL_CAPTURE, Game.HATCH_ALPHA))
				else:
					_hatch(c, _tile(d), Color(Game.COL_ZONE_OUTLINE_MOVE, Game.HATCH_ALPHA), Game.HATCH_BLUE_PHASE)
			_outline(c, dests, caps, Color(Game.COL_ZONE_OUTLINE_MOVE, Game.ZONE_OUTLINE_ALPHA))
			for path in Rules.move_paths(board, sel, defs):
				if path.kind == "ride" and not path.hop:
					_arrow(c, _tile(sel).get_center(), _tile(path.line[-1]).get_center(),
						Color(Game.COL_MOVE, Game.MOVE_INDICATOR_ALPHA))
	var zone: Array[Vector2i] = []
	zone.assign(o.get("zone", []))
	for t in zone:
		_hatch(c, _tile(t), Color(Game.COL_CAPTURE, Game.HATCH_ALPHA))
	_outline(c, zone, zone, Color(Game.COL_CAPTURE, Game.ZONE_OUTLINE_ALPHA))
	if o.get("place", false):
		for t in Rules.placement_tiles(board):
			if win.has_point(t):
				c.draw_circle(_tile(t).get_center(), 8 * S, Game.COL_PLACE)
	for p in pieces:
		var r := _tile(Vector2i(p[2], p[3]))
		_piece(c, p[0], p[1], r, Vector2i(p[2], p[3]) == sel)
		if p.size() > 4:
			_badges(c, r, p[4])
	if o.has("target"):
		_merge_target(c, _tile(o.target))


## Screen rect of board tile `t` inside the current window (+y is up on the board).
func _tile(t: Vector2i) -> Rect2:
	return Rect2(Vector2(t.x - _win.position.x, _win.end.y - 1 - t.y) * TILE, Vector2(TILE, TILE))


func _around(t: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			out.append(t + Vector2i(dx, dy))
	return out


# --- ported board marks (in output pixels) --------------------------------------

## game.gd _draw_piece: token slightly overflowing its square (inset -2, the
## selected piece -6), the side tint only on the monochrome fallback art, and
## the inversion mark on inv- pieces.
func _piece(c: Control, id: String, owner: int, r: Rect2, selected := false) -> void:
	var tint := Color.WHITE
	if Game.is_mono_piece(id):
		tint = Game.COL_SIDE_PLAYER if owner == Rules.PLAYER else Game.COL_SIDE_ENEMY
	var tex := Game.load_piece_tex(id, owner)
	_held.append(tex)
	c.draw_texture_rect(tex, r.grow(-(Game.SELECTED_INSET if selected else -2.0) * S), false, tint)
	if id.begins_with("inv-"):
		_inv_mark(c, r)


func _mark_size() -> int: # game.gd _inv_mark_size
	return maxi(18 * S, int(TILE * 0.56))


func _inv_mark(c: Control, r: Rect2) -> void:
	var font := _sym
	var ctr := r.get_center() + Vector2(0, TILE * Game.INV_MARK_DROP)
	var rad := _mark_size() * Game.INV_MARK_DISC_RATIO
	c.draw_circle(ctr, rad, Game.INV_MARK_DISC_COL)
	var gs := int(_mark_size() * Game.INV_MARK_GLYPH_SCALE)
	var base := ctr.y + (font.get_ascent(gs) - font.get_descent(gs)) / 2.0
	var nudge: Vector2 = Game.INV_MARK_GLYPH_NUDGE * gs
	c.draw_string(font, Vector2(ctr.x - rad + nudge.x, base + nudge.y), Game.INV_MARK_GLYPH,
		HORIZONTAL_ALIGNMENT_CENTER, rad * 2, gs, Game.INV_MARK_GLYPH_COL)


## game.gd _draw_hatch, "\" family, phased off canvas space like the board's.
func _hatch(c: Control, r: Rect2, col: Color, phase := 0.0) -> void:
	var s := r.size.x
	var step := Game.HATCH_SPACING * S
	var o := -s + fposmod(phase * S - (r.position.y - r.position.x) + s, step)
	while o <= s:
		var a := Vector2(0, o) if o >= 0 else Vector2(-o, 0)
		var b := Vector2(s - o, s) if o >= 0 else Vector2(s, s + o)
		c.draw_line(r.position + a, r.position + b, col, Game.HATCH_WIDTH * S)
		o += step


## game.gd _draw_zone_outline: an edge wherever a zone tile has no zone
## neighbour, red around capture tiles, purple where a move tile meets a capture
## tile inside the zone. ponytail: no diagonal bridges; no image here needs one.
func _outline(c: Control, tiles: Array[Vector2i], captures: Array, col: Color) -> void:
	var w := Game.ZONE_OUTLINE_WIDTH * S
	var cap_col := Color(Game.COL_CAPTURE, Game.ZONE_OUTLINE_ALPHA)
	var over_col := Color(Game.COL_ZONE_OUTLINE_OVERLAP, Game.ZONE_OUTLINE_OVERLAP_ALPHA)
	var sides := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)] # top, right, bottom, left
	for t in tiles:
		var r := _tile(t)
		var corners := [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]
		var t_cap := captures.has(t)
		for i in 4:
			var n: Vector2i = t + sides[i]
			var edge: Color
			if not tiles.has(n):
				edge = cap_col if t_cap else col
			elif captures.has(n) != t_cap and i < 2: # a shared edge, drawn from one side only
				edge = over_col
			else:
				continue
			c.draw_line(corners[i], corners[(i + 1) % 4], edge, w)


## game.gd _draw_move_arrow: shaft quad + head triangle sharing one edge.
func _arrow(c: Control, from: Vector2, to: Vector2, col: Color) -> void:
	var dir := (to - from).normalized()
	var side := Vector2(-dir.y, dir.x)
	var start := from + dir * (TILE * 0.35)
	var end := to - dir * Game.ARROW_HEAD_LEN * S
	var hw := Game.ARROW_WIDTH * S * 0.5
	var hh := Game.ARROW_HEAD_HALF * S
	c.draw_colored_polygon(PackedVector2Array([start - side * hw, end - side * hw, end + side * hw, start + side * hw]), col)
	c.draw_colored_polygon(PackedVector2Array([end - side * hh, to, end + side * hh]), col)


## The merge-target mark on the tile `r`.
func _merge_target(c: Control, r: Rect2) -> void:
	c.draw_arc(r.get_center(), TILE * 0.46, 0, TAU, 48, Game.COL_MERGE, 3.0 * S)


## game.gd _buff_badge_centres + _draw_buff_badge for the tile `r`; the badge at
## `stun_index` is the red Stun badge.
func _badges(c: Control, r: Rect2, glyphs: Array, stun_index := -1) -> void:
	var half := _mark_size() * Game.INV_MARK_DISC_RATIO * Game.BUFF_BADGE_SCALE
	var gap := half * 2.2
	var c0 := r.get_center() + Vector2(0, TILE * (Game.INV_MARK_DROP + Game.BUFF_BADGE_EXTRA_DROP))
	var font := _sym
	var n := glyphs.size()
	for i in n:
		var row_n := mini(n - (i / 2) * 2, 2)
		var ctr := Vector2(c0.x - gap * (row_n - 1) / 2.0 + gap * (i % 2), c0.y - gap * (i / 2))
		var accent: Color = Game.STUN_BADGE_COL if i == stun_index else Game.BUFF_BADGE_ACCENT
		var box := StyleBoxFlat.new()
		box.bg_color = Game.BUFF_BADGE_FILL
		box.border_color = accent
		box.set_border_width_all(S)
		box.set_corner_radius_all(int(half * 0.45))
		c.draw_style_box(box, Rect2(ctr - Vector2(half, half), Vector2(half, half) * 2))
		var tune: Array = Game.BUFF_GLYPH_TUNE.get(glyphs[i], [0.0, 0.0, 1.0])
		var gsize := int(int(half * Game.BUFF_GLYPH_RATIO) * tune[2])
		var gbase := (font.get_ascent(gsize) - font.get_descent(gsize)) / 2.0
		c.draw_string(font, Vector2(ctr.x - half + tune[0] * half, ctr.y + gbase + (Game.BUFF_GLYPH_LIFT + tune[1]) * half),
			glyphs[i], HORIZONTAL_ALIGNMENT_CENTER, half * 2, gsize, accent)


# --- text -------------------------------------------------------------------------

## White Pixel Operator with a dark outline, centred in `width` from `pos`
## (baseline-left), so it reads on the Guide's dark panel and on a light page.
func _text(c: Control, pos: Vector2, text: String, width: float, size: int) -> void:
	c.draw_string_outline(PIXEL, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 4 * S, TEXT_EDGE)
	c.draw_string(PIXEL, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, TEXT_COL)


func _caption(c: Control, under: Rect2, text: String) -> void:
	# draw_string cuts text at its width: give it the gaps on both sides too
	_text(c, Vector2(under.position.x - GAP, under.end.y + CAPTION_H * 0.75), text, under.size.x + GAP * 2, 16 * S)


## A "+" or "→" centred in the gap between two strip tiles, `sub` small above it.
func _between(c: Control, a: Rect2, b: Rect2, text: String, sub := "") -> void:
	var size := 32 * S
	var mid := Vector2((a.end.x + b.position.x) / 2.0, a.get_center().y)
	var base := mid.y + (PIXEL.get_ascent(size) - PIXEL.get_descent(size)) / 2.0
	_text(c, Vector2(mid.x - GAP / 2.0, base), text, GAP, size)
	if sub != "":
		_text(c, Vector2(mid.x - GAP, mid.y - 18 * S), sub, GAP * 2, 12 * S)
