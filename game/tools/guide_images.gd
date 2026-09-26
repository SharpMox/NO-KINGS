extends SceneTree
## NO-264 option B: Guide illustrations composed from the game's own assets —
## piece tokens (Game.load_piece_tex), the board chequer and highlight palette
## (game.gd's COL_* / HATCH_* / ZONE_* constants, read off the class, never
## restated), Buff badge glyphs (BuffLogic) and Pixel Operator — drawn into an
## off-screen SubViewport and saved as PNGs at S x the in-game pixel size.
##
## One command renders every image in IMAGES into game/assets/guide/:
##   tools/godot-lock.sh godot --path game -s tools/guide_images.gd
## Windowed, not --headless: frame_post_draw never resolves headless (CLAUDE.md,
## "The --screenshot seam is windowed"). CI renders them under xvfb
## (.github/workflows/guide-images.yml) and uploads them as an artifact.
##
## The hatch, zone outline and badge geometry below are small ports of game.gd's
## _draw_hatch, _draw_zone_outline, _buff_badge_centres and _draw_buff_badge:
## those are instance methods drawing onto the live board, so they cannot be
## called from here. Their constants are shared; their shapes are copied.
## ponytail: ported geometry can drift from game.gd; if it does, render these
## from a real Game node with the HUD hidden instead.
##
## Add an image: one entry in IMAGES (name -> [size in px, paint callable]).

const Game := preload("res://scripts/game.gd")
const Rules := preload("res://scripts/rules.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")
const _UiFonts := preload("res://scripts/ui_fonts.gd") # its _static_init chains NoKingsSymbols behind Pixel Operator
const PIXEL := preload("res://assets/fonts/PixelOperator.ttf")

const S := 2 # output scale over the in-game 480x800 canvas
const TILE := 56 * S # about the in-game board tile at 480x800
const GAP := TILE * 3 / 4 # room between tiles for a "+" / "→"
const CAPTION_H := 28 * S
const TEXT_COL := Color.WHITE # the Guide's panels are dark
const OUT_DIR := "res://assets/guide"

var defs: Dictionary


func _initialize() -> void:
	defs = Rules.load_pieces()
	var strip := Vector2i(3 * TILE + 2 * GAP, TILE + CAPTION_H)
	var images := {
		"knight-moves": [Vector2i(5, 5) * TILE, _knight_moves],
		"merge-pawns": [strip, _merge_pawns],
		"buff-badges": [strip, _buff_badges],
	}
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


# --- images -------------------------------------------------------------------

## Guide > Pieces / Rules > Turns: the Knight selected on a 5x5 slice, its leap
## squares hatched blue, one of them holding an enemy Pawn, hatched red. The
## squares come from pieces.json's own Knight moves, not a restated list.
func _knight_moves(c: Control) -> void:
	var at := Vector2i(2, 2)
	var enemy := at + Vector2i(1, -2) # up-right on screen
	_board(c, 5, 5)
	c.draw_rect(_tile(at), Game.COL_SELECT)
	var dests: Array[Vector2i] = []
	for m in defs.knight.moves:
		for d in m.dirs:
			dests.append(at + Vector2i(int(d[0]), -int(d[1]))) # +y is up on the board
	for d in dests:
		if d == enemy:
			_hatch(c, _tile(d), Color(Game.COL_CAPTURE, Game.HATCH_ALPHA))
		else:
			_hatch(c, _tile(d), Color(Game.COL_ZONE_OUTLINE_MOVE, Game.HATCH_ALPHA), Game.HATCH_BLUE_PHASE)
	_outline(c, dests, [enemy])
	_piece(c, "knight", Rules.PLAYER, _tile(at))
	_piece(c, "pawn", Rules.ENEMY, _tile(enemy))


## Rules > Merging: Pawn (selected) + Pawn (merge ring) → the Pawn's `next`
## in pieces.json, each captioned with its name.
func _merge_pawns(c: Control) -> void:
	var result: String = defs.pawn.next
	var tiles := _strip_tiles()
	for i in 3:
		c.draw_rect(tiles[i], Game.COL_LIGHT if i % 2 == 0 else Game.COL_DARK)
	c.draw_rect(tiles[0], Game.COL_SELECT)
	c.draw_arc(tiles[1].get_center(), TILE * 0.46, 0, TAU, 48, Game.COL_MERGE, 3.0 * S)
	for i in 3:
		var id: String = "pawn" if i < 2 else result
		_piece(c, id, Rules.PLAYER, tiles[i])
		_caption(c, tiles[i], defs[id].name)
	_between(c, tiles[0], tiles[1], "+")
	_between(c, tiles[1], tiles[2], "→")


## Guide > Items > Piece Buffs / Indicators: a Rook with one Buff, with two,
## and Stunned (the red badge), badges laid out exactly as the board lays them.
func _buff_badges(c: Control) -> void:
	var shield := BuffLogic.glyph_of("shield")
	var crit := BuffLogic.glyph_of("critical")
	var rows := [
		[[shield], -1, BuffLogic.name_of("shield")],
		[[shield, crit], -1, "%s + %s" % [BuffLogic.name_of("shield"), BuffLogic.name_of("critical")]],
		[[shield, Game.STUN_BADGE_GLYPH], 1, "Stunned"],
	]
	var tiles := _strip_tiles()
	for i in 3:
		c.draw_rect(tiles[i], Game.COL_LIGHT if i % 2 == 0 else Game.COL_DARK)
		_piece(c, "rook", Rules.PLAYER, tiles[i])
		var glyphs: Array = rows[i][0]
		var centres := _badge_centres(tiles[i].position, glyphs.size())
		for j in glyphs.size():
			_badge(c, centres[j], glyphs[j], Game.STUN_BADGE_COL if j == rows[i][1] else Game.BUFF_BADGE_ACCENT)
		_caption(c, tiles[i], rows[i][2])


# --- drawing helpers (in output pixels) ---------------------------------------

func _tile(t: Vector2i) -> Rect2:
	return Rect2(Vector2(t) * TILE, Vector2(TILE, TILE))


## Three tiles left to right with GAP between them, captions below.
func _strip_tiles() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in 3:
		out.append(Rect2(Vector2(i * (TILE + GAP), 0), Vector2(TILE, TILE)))
	return out


func _board(c: Control, w: int, h: int) -> void:
	for x in w:
		for y in h:
			c.draw_rect(_tile(Vector2i(x, y)), Game.COL_LIGHT if (x + y) % 2 == 0 else Game.COL_DARK)


## game.gd _draw_piece: token slightly overflowing its square (inset -2), the
## side tint only on the monochrome fallback art.
func _piece(c: Control, id: String, owner: int, r: Rect2) -> void:
	var tint := Color.WHITE
	if Game.is_mono_piece(id):
		tint = Game.COL_SIDE_PLAYER if owner == Rules.PLAYER else Game.COL_SIDE_ENEMY
	c.draw_texture_rect(Game.load_piece_tex(id, owner), r.grow(2 * S), false, tint)


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
## neighbour, red around capture tiles. ponytail: no purple move/capture
## boundary and no diagonal bridges — no image here has either yet.
func _outline(c: Control, tiles: Array[Vector2i], captures: Array) -> void:
	var w := Game.ZONE_OUTLINE_WIDTH * S
	for t in tiles:
		var col := Color(Game.COL_CAPTURE if captures.has(t) else Game.COL_ZONE_OUTLINE_MOVE, Game.ZONE_OUTLINE_ALPHA)
		var r := _tile(t)
		var corners := [r.position, r.position + Vector2(TILE, 0), r.end, r.position + Vector2(0, TILE)]
		var sides := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT] # screen space
		for i in 4:
			if not tiles.has(t + sides[i]):
				c.draw_line(corners[i], corners[(i + 1) % 4], col, w)


## game.gd _inv_mark_size / _buff_badge_half / _buff_badge_centres, for a tile
## TILE wide whose top-left is `px`.
func _badge_half() -> float:
	return maxi(18 * S, int(TILE * 0.56)) * Game.INV_MARK_DISC_RATIO * Game.BUFF_BADGE_SCALE


func _badge_centres(px: Vector2, n: int) -> Array[Vector2]:
	var gap := _badge_half() * 2.2
	var c0 := px + Vector2(TILE, TILE) / 2.0 + Vector2(0, TILE * (Game.INV_MARK_DROP + Game.BUFF_BADGE_EXTRA_DROP))
	var out: Array[Vector2] = []
	for i in n:
		var row_n := mini(n - (i / 2) * 2, 2)
		out.append(Vector2(c0.x - gap * (row_n - 1) / 2.0 + gap * (i % 2), c0.y - gap * (i / 2)))
	return out


## game.gd _draw_buff_badge at full scale/alpha, glyph on the board's symbol font.
func _badge(c: Control, ctr: Vector2, glyph: String, accent: Color) -> void:
	var half := _badge_half()
	var box := StyleBoxFlat.new()
	box.bg_color = Game.BUFF_BADGE_FILL
	box.border_color = accent
	box.set_border_width_all(S)
	box.set_corner_radius_all(int(half * 0.45))
	c.draw_style_box(box, Rect2(ctr - Vector2(half, half), Vector2(half, half) * 2))
	var font := ThemeDB.fallback_font
	var tune: Array = Game.BUFF_GLYPH_TUNE.get(glyph, [0.0, 0.0, 1.0])
	var gsize := int(int(half * Game.BUFF_GLYPH_RATIO) * tune[2])
	var gbase := (font.get_ascent(gsize) - font.get_descent(gsize)) / 2.0
	c.draw_string(font, Vector2(ctr.x - half + tune[0] * half, ctr.y + gbase + (Game.BUFF_GLYPH_LIFT + tune[1]) * half),
		glyph, HORIZONTAL_ALIGNMENT_CENTER, half * 2, gsize, accent)


func _caption(c: Control, under: Rect2, text: String) -> void:
	var size := 16 * S
	var w := under.size.x + GAP
	c.draw_string(PIXEL, Vector2(under.position.x - GAP / 2.0, under.end.y + CAPTION_H * 0.75),
		text, HORIZONTAL_ALIGNMENT_CENTER, w, size, TEXT_COL)


## A "+" or "→" centred in the gap between two tiles.
func _between(c: Control, a: Rect2, b: Rect2, text: String) -> void:
	var size := 32 * S
	var mid := Vector2((a.end.x + b.position.x) / 2.0, a.get_center().y)
	c.draw_string(PIXEL, Vector2(mid.x - GAP / 2.0, mid.y + (PIXEL.get_ascent(size) - PIXEL.get_descent(size)) / 2.0),
		text, HORIZONTAL_ALIGNMENT_CENTER, GAP, size, TEXT_COL)
