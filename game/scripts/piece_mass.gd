## NO-157: one shared "mass of pieces" renderer for the Army Choice carousel
## (menu.gd's _show_armies) and the Reinforcements announcement (modals.gd's
## show_reinforce). Both screens want the same thing — every piece drawn
## individually, formed into a packed crowd, not a de-duplicated icon with a
## "×N" badge — so it lives in ONE place instead of two. Replaces NO-146's
## _army_group_picture and NO-141's _reinforce_group_picture (both deleted):
## the same phrase produced two separate implementations last round, because
## two agents each built one.
##
## NO-178: reworked from 1-3 tidy ranks (a wide flat strip) into a packed
## crowd — pawns at the back, distinctive pieces at the front, heavy overlap
## both ways, varied tilt. Max, 2026-09-25: wider/shorter rows (raised
## TARGET_ASPECT), every row centred on the same line (dropped the old
## brick-pattern row stagger), large pieces grouped into the front row(s),
## no row under MIN_ROW_PIECES, an overflowing row splits into two instead
## of shrinking, and no piece is ever scaled down to make a row fit — every
## icon renders at ICON, full stop. See build()'s header comment for the
## geometry.
##
## Pure logic-over-nothing module, same shape as tuning.gd/armies.gd: no
## nodes of its own, one static entry point.

const ICON := 52.0 # 40 * 1.3 — Max, 2026-09-20: chose bigger icons over
	# tighter packing ("i think we can just increase the size of the icons by
	# 30%"). Was NO-146's original 40px; Tuning.OFFBOARD_ICON (72px) is sized
	# for the off-board strip's own row height, not a crowd of a dozen-plus
	# overlapping tokens, and would force scrolling or clipping here — see
	# build()'s Horde-14 arithmetic below for the worst case at this size.
	# Max, 2026-09-25: every icon renders at exactly this size, in every row
	# — nothing here ever shrinks a piece to make a wide row fit. A row too
	# wide for its budget splits into two rows instead (see
	# _choose_row_sizes()'s overflow pass).
const CELL_LARGE := ICON * 0.38 # horizontal pitch for "large" pieces (Rook,
	# Knight, Queen, dragons...) — well under ICON so neighbours overlap. A
	# RATIO of ICON, not an independent number: the next size change is one
	# constant (ICON), not two literals that happen to agree today. NO-203:
	# tightened from 0.6 to 0.42 — Max: "the pieces are also too far from
	# each horizontally, we want to pack them a bit more". NO-210: tightened
	# again to 0.38 — Max: "pack the row element a bit more horizontally"
	# while giving ROW_PITCH (below) more room, since 0.36/0.42 read as rows
	# too close together. Was named CELL until the slim/large split below.
const CELL_SLIM := CELL_LARGE * 0.63 # tighter pitch for "slim" pieces (Pawn,
	# Void Pawn, Wazir...) — Max: the large-piece pitch above "looks great"
	# but slim pieces "sit too far apart" at the same spacing. 0.63 is not a
	# guess: it's the ratio of the two classes' MEASURED average opaque-width
	# ratios (Image.get_used_rect().size.x / texture width) across all 39
	# tokens at SLIM_WIDTH_RATIO's threshold — slim averages 0.543, large
	# averages 0.863, 0.543/0.863 ≈ 0.63 — so a slim piece's pitch shrinks by
	# the same factor its silhouette does. See _is_slim()/_slim_ratio() and
	# tests/test_mass.gd's printed classification table for the full 39-piece
	# breakdown.
const ROW_PITCH := ICON * 0.54 # NO-178: vertical pitch between rows. NO-203:
	# tightened from 0.45 to 0.36 — Max: "we need the rows to be closer on the
	# vertical axis so we can still visually see rows" — then NO-210 backed it
	# off to 0.42: Max, "rows are too close ... distance them vertically a
	# little bit". V3 (2026-09-21): still too tight — "bottom rows cover a bit
	# too much of the rows above it" — raised again to 0.54. Checked with a
	# Python/PIL mockup of build()'s exact maths against the real pawn PNG
	# (Horde-14, the worst case): 0.42-0.46 kept the row count (then chosen
	# by the rows-first search this file used at the time — see
	# _choose_cols()'s own header for why V4, 2026-09-25, searches columns
	# instead) at 4 rows for Horde-14, heads sitting right under the row in
	# front's shoulders; 0.50 is where that search opened up to 3 rows for
	# that count (stable through at least 0.74, so this isn't a knife-edge
	# pick) and the gap becomes visible; by 0.65 the rows start reading as
	# separate stripes with a visible dark band between them, and by 0.85
	# they fully split into 3 flat ranks — the exact "not a crowd" failure
	# this renderer exists to avoid. 0.54 sits in the middle of the
	# 0.50-0.65 window: past the 4-row-to-3-row jump with real margin, short
	# of where stripes start. Still governs vertical pitch under V4 — only
	# the horizontal column count changed.
const JITTER_Y := ICON * 0.075 # px — Max, 2026-09-20: "barely not aligned
	# horizontally" — a small per-piece vertical wobble so a rank's baseline
	# waves slightly rather than ruling dead straight. Also a ratio of ICON
	# (3px at the original 40px) so it scales with the icon instead of
	# shrinking to a proportionally smaller wobble.
const JITTER_ROT := 0.45 # radians (~25.8°) — NO-178: widened from 0.3
	# (~17°) to match Max's mockup, where a front-row rook is tilted roughly
	# 20-30°. X position is still not jittered (see build()); rotation is
	# what stops a row looking stamped from one mould now that rows no
	# longer carry a stagger offset (Max, 2026-09-25 — see build()'s header).
const TARGET_ASPECT := 2.2 # width:height the crowd's bounding box should
	# land near. Was 1.15 ("roughly square, slightly wider than tall", Max's
	# own mockup measurement) until Max reviewed the #582 Army captures,
	# 2026-09-25: "we can make much wider rows, it'll look better" — 2.2
	# picks fewer, wider rows using most of the carousel card's own width
	# instead of a squarish blob.
	#
	# The real ceiling is 260px, not the carousel card's own 280px: `card`
	# (menu.gd _show_armies) is a PanelContainer with a FIXED
	# custom_minimum_size of 280, but Godot Containers report their minimum
	# size as the larger of that and their content's own required size — so
	# a mass wider than the card's 260px CONTENT budget (280 minus the
	# card's own 10+10px side content-margins) silently grows the card
	# itself past 280, breaking NO-179's "every card renders at the same
	# size" (Max: "just make a normal carousel with out changing any
	# dimensions of the other cards") — caught live by
	# test_menu_clicks.gd's windowed "every card is the same size" probe at
	# TARGET_ASPECT=2.3 (Horde's mass hit 266px, 6px over budget). 2.2 keeps
	# every Army under 260px with real margin. This is now belt-and-braces,
	# not the only guard: menu.gd's _show_armies passes its own real budget
	# into build()'s `max_row_width`, and _choose_row_sizes() actively
	# splits any row that still doesn't fit rather than trusting this
	# constant alone (see that function's own header).
	#
	# Chosen by scanning candidate column counts (_choose_cols()). Re-check
	# against tests/test_mass.gd's `_test_horde_row_width` and
	# `_test_horde_fits_carousel_card` if this or the pitch/ICON constants
	# change again.
const MIN_ROW_PIECES := 3 # Max, 2026-09-25, on top of "large pieces go in
	# the front row": "no row has fewer than 3 pieces... a lone piece is
	# never allowed" — a Knight or Rook by itself in the front row read as
	# an accident, not a crowd. The only exception is an `ids` list with
	# fewer than this many pieces total, which gets one row of whatever it
	# has (_choose_row_sizes()'s own early-out).
const SLIM_WIDTH_RATIO := 0.64 # a piece is "slim" when its opaque-pixel
	# bounding-box width (Image.get_used_rect(), see _slim_ratio()) is under
	# this fraction of its 192px-square texture's own width. Chosen from the
	# measured ratio of all 39 tokens (tests/test_mass.gd prints the full
	# table): Pawn/Void Pawn/Bishop/Ferz share one silhouette at 0.479, and
	# every other pawn-shaped/simple token (Sergeant, Archer, Wazir, Amazon,
	# ...) falls between 0.52 and 0.63; Rook sits at 0.656, with Queen (0.81)
	# and Knight (0.90) further above. 0.64 is the natural gap directly under
	# Rook — the smallest "must be large" example — so Rook/Queen/Knight
	# land large and the pawn-shaped cluster lands slim, automatically, with
	# no piece hand-listed.
static var _slim_cache: Dictionary = {} # id -> bool, memoized: the art never
	# changes mid-run, and this can run once per piece per build() call.
# Same value as game.gd's COL_SIDE_PLAYER (game.gd:91) — duplicated rather
# than read off the `load()`'d script below: that call is verified working
# for a static FUNCTION (hud.gd's own load("res://scripts/menu.gd") calls
# MenuScript._SAVE_PATHS() the same way), but this file was written without
# a Godot instance to confirm the same `.` access resolves a plain `const`
# on a runtime-loaded (not preloaded) script — see the report's "could not
# verify" list.
const COL_SIDE_PLAYER := Color(0.72, 0.85, 1.25)

const Rules := preload("res://scripts/rules.gd") # no cycle: rules.gd never
	# loads this file, game.gd, menu.gd or modals.gd (unlike game_script
	# below, which is load()'d for exactly that reason).

## Renders `ids` — the FULL list, duplicates included; three arriving pawns
## draw as three pawns, never "pawn ×3" — as a fixed-size Control packed into
## a crowd: one TextureRect per piece, every icon at ICON size (never
## scaled — Max, 2026-09-25), rows derived from the count so the bounding
## box lands near TARGET_ASPECT (NO-178 — replaces the old fixed 1-3-rank
## rule, which produced a wide flat strip). Slim pieces (Pawn-shaped, see
## _is_slim()) sit at the back (drawn first); large pieces (Rook/Knight/
## Queen/dragon-shaped) sit at the front (drawn last, on top) — Max,
## 2026-09-25 (Aux's review of #582): a Knight at the end of a back row was
## covering its neighbour, "large pieces go in the FRONT row". Player/light
## side only — neither caller ever shows the enemy's art.
##
## `max_row_width` bounds each row's own pixel width (default: unbounded —
## modals.gd's Reinforcements announcement has no fixed card, so it doesn't
## pass one). menu.gd's Army carousel passes its card's real content budget;
## see _choose_row_sizes()'s header for what happens to a row that still
## doesn't fit: it splits into two, never shrinks.
##
## Seeded from `hash(ids)`, not randomize(): the same army or reinforcement
## list draws identically every time, so a screenshot of it stays diffable
## and the fan doesn't reshuffle on repaint (CLAUDE.md, NO-157). The seed is
## taken from `ids` before any internal reordering, so it stays a property of
## the input list, not of how this function happens to sort it.
static func build(ids: Array, max_row_width: float = INF) -> Control:
	# load(), not preload(): game.gd owns `modals` as a preloaded child
	# (game.gd:547 — `var modals := preload("res://scripts/modals.gd").new()`),
	# and modals.gd is one of this script's two callers, so a top-level
	# preload of game.gd here would close that into a compile cycle — the
	# same trap hud.gd's own `load("res://scripts/menu.gd")` documents.
	# load() resolves at call time, after every script involved is already
	# compiled, which breaks the cycle.
	var game_script: GDScript = load("res://scripts/game.gd")
	var mass := Control.new()
	mass.mouse_filter = Control.MOUSE_FILTER_IGNORE # decorative only — never
		# steals the Army carousel's touch-drag or a reinforce-panel tap
	# SHRINK_CENTER, or the VBoxContainer either callers sit in stretches
	# `mass` to its own (wider) width and the crowd lands flush left instead
	# of centred under the title/button above it (modals.gd:524 uses the
	# same fix for its own piece-art TextureRect).
	mass.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var n := ids.size()
	var sorted_ids: Array = _back_to_front(ids)

	# Per-piece horizontal pitch (Max's ruling: slim pieces — Pawn-shaped,
	# classified from the art, see _is_slim() — pack tighter than large
	# ones). Computed once per id, up front, so both _choose_row_sizes() and
	# the per-row layout below read the same values.
	var pitches: Array[float] = []
	var avg_pitch := 0.0
	for id in sorted_ids:
		var p := _pitch(id)
		pitches.append(p)
		avg_pitch += p
	if not pitches.is_empty():
		avg_pitch /= pitches.size()

	# `sizes[r]` = piece count of row r, back (r=0) to front (r=last) — see
	# _choose_row_sizes()'s own header for the two rules this applies (>=3
	# per row, split instead of overflow) on top of the wide-rows target.
	var sizes: Array[int] = _choose_row_sizes(n, avg_pitch, pitches, max_row_width)
	var rows := sizes.size()

	# Row layout, row-major fill matching `sizes` (row r holds sizes[r]
	# consecutive pieces from sorted_ids, back to front — see row_of[] built
	# alongside): each row's items are laid out left to right with the pitch
	# between neighbours = half of each one's own class pitch, summed (Max's
	# ruling) — reduces to the old uniform `col * CELL` when a row is all one
	# class. `row_x[i]` is icon i's x WITHIN its row, before centering/pad;
	# `row_width[r]` is that row's own natural span; `row_of[i]` is which
	# row global index i belongs to (rows can differ in size now, so this
	# replaces the old fixed `i / cols`).
	var row_x: Array[float] = []
	row_x.resize(n)
	var row_of: Array[int] = []
	row_of.resize(n)
	var row_width: Array[float] = []
	row_width.resize(rows)
	var idx := 0
	for r in rows:
		var count: int = sizes[r]
		var x := 0.0
		for k in count:
			var i := idx + k
			row_of[i] = r
			if k > 0:
				x += (pitches[i - 1] + pitches[i]) * 0.5
			row_x[i] = x
		row_width[r] = (x + ICON) if count > 0 else 0.0
		idx += count
	var max_row_w := 0.0
	for w in row_width:
		max_row_w = maxf(max_row_w, w)
	# Centre EVERY row on the widest row's centre line — not just a short
	# one. Max, 2026-09-25, reviewing #582's captures: "I still see rows
	# offset to one side instead of aligning to the centre" — the old NO-178
	# brick-pattern stagger (alternate rows shifted right by a half cell) is
	# gone for exactly this reason; nothing here shifts a row off this
	# centre line any more. Widest is measured in PIXELS, not piece count:
	# with mixed slim/large pitches two equal-count rows can differ in
	# natural width, and pixel width is what actually needs centring.
	var row_center_offset: Array[float] = []
	row_center_offset.resize(rows)
	for r in rows:
		row_center_offset[r] = (max_row_w - row_width[r]) * 0.5

	# Padding: half the icon's own width/height, plus JITTER_Y's vertical
	# wobble, plus the bounding-box growth a square gains when rotated up to
	# JITTER_ROT (a square of side ICON rotated by θ has half-extent
	# (ICON/2)*(cos θ + sin θ), i.e. (cos θ + sin θ - 1) more than unrotated).
	# Computed here, not as a const, because GDScript const initializers
	# can't call cos()/sin() — this only runs once per build().
	var rot_extra := (ICON * 0.5) * (cos(JITTER_ROT) + sin(JITTER_ROT) - 1.0)
	var pad := ICON * 0.5 + JITTER_Y + rot_extra

	# Worst case at ICON=52, TARGET_ASPECT=2.2 (V4, 2026-09-25): Horde-14
	# (all-pawn, the widest army at this pitch) lands on sizes=[11,3] ->
	# row width (11-1)*CELL_SLIM + ICON = 124.5 + 52 = 176.5px, mass width
	# 176.5 + 2*38.62(pad) = 253.7px. The carousel card's real content
	# budget (menu.gd _show_armies) is 260px — card_w = viewport.x *
	# ARMY_CARD_WIDTH_FRACTION = 480*7/12 = 280px, minus its own 10+10px
	# side content margins — 253.7px fits with ~6.3px to spare
	# (`_test_horde_fits_carousel_card`; see TARGET_ASPECT's own header for
	# why 280 alone isn't the real ceiling). Re-check this if ICON,
	# JITTER_ROT, TARGET_ASPECT, the pitch constants, or
	# ARMY_CARD_WIDTH_FRACTION change again; it is not enforced in code
	# beyond `max_row_width` itself, which the caller supplies.
	mass.custom_minimum_size = Vector2(
		max_row_w + pad * 2.0,
		(rows - 1) * ROW_PITCH + ICON + pad * 2.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ids)

	for i in sorted_ids.size():
		var id: String = sorted_ids[i]
		var icon := TextureRect.new()
		icon.texture = game_script.load_piece_tex(id) # player side (the default)
		# EXPAND_IGNORE_SIZE + STRETCH_KEEP_ASPECT_CENTERED BEFORE the size is
		# set — the exact order NO-146's group picture and NO-148's tier icon
		# both use. Setting `.size` first is the trap: with the default expand
		# mode, Control.set_size() clamps a requested size UP to
		# get_combined_minimum_size(), which for an un-configured TextureRect
		# is the source PNG's native 192x192 — and once `.size` is set, a
		# later expand_mode change does not shrink it back down.
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(ICON, ICON)
		icon.size = Vector2(ICON, ICON) # `mass` is a bare Control, not a
			# Container, so nothing else would size this child
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.pivot_offset = Vector2(ICON, ICON) * 0.5 # rotate around its
			# own centre, not the top-left corner
		if game_script.is_mono_piece(id): # the King's own path today (CLAUDE.md, "Piece art")
			icon.modulate = COL_SIDE_PLAYER
		var row := row_of[i]
		# X is the row-local mixed-pitch position plus that row's own
		# centring offset — no per-row stagger any more (Max, 2026-09-25:
		# every row, not just a short one, sits on the same centre line). Y
		# gets a small wobble and the icon a tilt. No scale is set — every
		# icon renders at its full ICON size regardless of row (Max,
		# 2026-09-25: pieces must never be scaled down to fit a wide row;
		# the old back-row depth scale is gone for the same reason).
		icon.position = Vector2(
			pad + row_x[i] + row_center_offset[row],
			pad + row * ROW_PITCH + rng.randf_range(-JITTER_Y, JITTER_Y))
		icon.rotation = rng.randf_range(-JITTER_ROT, JITTER_ROT)
		mass.add_child(icon)
	return mass


## Columns (pieces per row) derived from the piece count, not a hardcoded
## ladder: tries every column count from 1 to n and keeps whichever bounding
## box lands closest to TARGET_ASPECT. Cheap (n is at most ~14 — Horde's
## army) and works the same way for Reinforcements' 2-3 pieces as it does
## for a full army. This is Phase 1 of _choose_row_sizes() — the "wide rows
## as the default target" pass, before the MIN_ROW_PIECES and overflow
## passes adjust it.
##
## Searches COLUMNS, not rows (the caller derives rows = ceili(n/cols) from
## the result) — Max, 2026-09-25: "much wider rows" needs a column count
## that isn't forced to be n/rows exactly. A rows-first search can only
## reach the column counts ceili(n/rows) produces for some integer rows —
## for n=14 that's {14,7,5,4,3,2,1}, with no way to land on, say, 12
## (rows=2 forces cols=7; the next reachable cols is 14, at rows=1, which
## overflows the carousel card). Scanning cols directly reaches every
## integer 1..n.
##
## `avg_pitch` is the mean per-piece pitch of the actual `ids` (build()'s own
## average of CELL_SLIM/CELL_LARGE per piece) — an approximation, like the
## rest of this heuristic (it already ignores rotation/jitter growth), but
## one that lets a slim-heavy army (more Pawns) land on more, narrower
## columns the way a uniform CELL_SLIM would, instead of always reasoning in
## CELL_LARGE terms.
static func _choose_cols(n: int, avg_pitch: float) -> int:
	var best_cols := maxi(1, n)
	var best_err := INF
	for cols in range(1, maxi(1, n) + 1):
		var rows := maxi(1, ceili(float(n) / float(cols)))
		var w: float = (cols - 1) * avg_pitch + ICON
		var h: float = (rows - 1) * ROW_PITCH + ICON
		var err: float = absf(w / h - TARGET_ASPECT)
		if err < best_err:
			best_err = err
			best_cols = cols
	return best_cols


## Per-row piece counts, back (index 0) to front (last index) — the three
## rules Max laid down on top of "large pieces go in the front row"
## (2026-09-25), applied in order:
##
## 1. Wide rows as the default target: start from _choose_cols()'s aspect
##    pick, one full `cols`-sized row per row except the last (the natural
##    remainder from `n` not dividing evenly).
## 2. No row under MIN_ROW_PIECES: if that remainder (the front row) would
##    land on 1-2, pull pieces from the row(s) behind until it has
##    MIN_ROW_PIECES, cascading further back if a donor would itself drop
##    below the minimum. Since `sorted_ids` is already slim-then-large
##    (_back_to_front), pulling from the back doesn't undo "large in
##    front" — at worst it mixes the LAST few slim pieces into the front
##    row alongside the large ones, which Max explicitly allowed ("rule 1
##    may mix a slim piece into the front row to reach 3; that's fine").
##    The armies that need this (Crown/Cult/Wild Hunt/Old Guard, all
##    11-piece with 8-9 slim + 2-3 large) all land on exactly this shape.
##    An `ids` list under MIN_ROW_PIECES total is the one exception —
##    Max's own wording — and gets a single row of whatever it has.
## 3. Overflow: a row still wider than `max_row_width` splits into two —
##    MIN_ROW_PIECES pieces move to a NEW row inserted immediately before
##    it (further back), the rest stays where it was (now narrower).
##    Repeats until every row fits or no legal split remains. A row can
##    only split if doing so leaves BOTH halves >= MIN_ROW_PIECES (i.e. the
##    row has at least 2*MIN_ROW_PIECES pieces); a row of 4 or 5 that still
##    overflows is left as-is — rules 1 and 2 make that combination
##    essentially unreachable at real pitch/ICON values (the smallest
##    per-row width topping 260px would need far more than 5 large pieces
##    at CELL_LARGE's pitch), so this is a documented edge case, not a
##    solved one. None of the 6 shipped Armies reach it (verified: every
##    real Army fits at TARGET_ASPECT=2.2 without ever invoking this pass).
static func _choose_row_sizes(n: int, avg_pitch: float, pitches: Array[float],
		max_row_width: float) -> Array[int]:
	if n < MIN_ROW_PIECES:
		return [n]

	var cols := _choose_cols(n, avg_pitch)
	var rows_count := maxi(1, ceili(float(n) / float(cols)))
	# Cap so every row CAN average >= MIN_ROW_PIECES.
	while rows_count > 1 and n < MIN_ROW_PIECES * rows_count:
		rows_count -= 1

	var sizes: Array[int] = []
	for _r in rows_count - 1:
		sizes.append(cols)
	sizes.append(n - (rows_count - 1) * cols)

	# Rule 2: pull from the row(s) behind if the front row is short,
	# cascading backward if a donor would itself drop under the minimum.
	var r := sizes.size() - 1
	while r > 0 and sizes[r] < MIN_ROW_PIECES:
		var need: int = MIN_ROW_PIECES - sizes[r]
		var donor := r - 1
		var avail: int = maxi(0, sizes[donor] - MIN_ROW_PIECES)
		var take: int = mini(need, avail)
		sizes[donor] -= take
		sizes[r] += take
		if sizes[r] >= MIN_ROW_PIECES or donor == 0:
			break
		r = donor

	# Rule 3: split any row still too wide for max_row_width, inserting a
	# MIN_ROW_PIECES-sized row immediately before it (see this function's
	# own header for the size>=2*MIN_ROW_PIECES guard and its known gap).
	var changed := true
	var guard := 0 # n is at most a few dozen even for a large reinforcement
		# grant; this bounds the loop defensively rather than trusting that.
	while changed and guard < 64:
		changed = false
		guard += 1
		var start := 0
		var next_sizes: Array[int] = []
		for size in sizes:
			var w := _row_width(pitches, start, size)
			if w > max_row_width and size >= 2 * MIN_ROW_PIECES:
				next_sizes.append(MIN_ROW_PIECES)
				next_sizes.append(size - MIN_ROW_PIECES)
				changed = true
			else:
				next_sizes.append(size)
			start += size
		sizes = next_sizes
	return sizes


## Pixel width of `count` consecutive pieces from `pitches`, starting at
## `start` — the same pitch-summing maths build() uses for row_x/row_width,
## factored out so _choose_row_sizes()'s overflow pass can check a
## candidate row's width without laying out the whole mass first.
static func _row_width(pitches: Array[float], start: int, count: int) -> float:
	if count <= 0:
		return 0.0
	var x := 0.0
	for k in range(1, count):
		x += (pitches[start + k - 1] + pitches[start + k]) * 0.5
	return x + ICON


## The per-piece horizontal pitch: CELL_SLIM for a slim piece, CELL_LARGE
## otherwise. The pitch BETWEEN two neighbours in a row is the average of
## their own two pitches (Max's ruling) — computed where rows are laid out,
## in build(); this is just the per-piece half of that sum.
static func _pitch(id: String) -> float:
	return CELL_SLIM if _is_slim(id) else CELL_LARGE


## Whether `id`'s token art is "slim" (Pawn-shaped) rather than "large"
## (Rook/Knight/Queen/dragon-shaped) — see SLIM_WIDTH_RATIO for the threshold
## and its derivation. Memoized in _slim_cache: the art is static for the
## life of the process, so this only measures each id once.
static func _is_slim(id: String) -> bool:
	if _slim_cache.has(id):
		return _slim_cache[id]
	var slim: bool = _slim_ratio(id) < SLIM_WIDTH_RATIO
	_slim_cache[id] = slim
	return slim


## `id`'s opaque-pixel bounding-box width as a fraction of its texture's own
## width — Image.get_used_rect() is Godot's own "visible bounds" rect, so
## this reads the same silhouette a player sees. Unmeasurable art (missing
## texture, or a VRAM-compressed one get_image() can't decompress) reads as
## 1.0 — "large" — the safer default (more room, never a clipped-looking
## overlap).
static func _slim_ratio(id: String) -> float:
	var game_script: GDScript = load("res://scripts/game.gd") # see build()'s
		# own load() for why this isn't a top-level preload
	var tex: Texture2D = game_script.load_piece_tex(id)
	if tex == null:
		return 1.0
	var img := tex.get_image()
	if img == null or img.get_width() <= 0:
		return 1.0
	var used := img.get_used_rect()
	return float(used.size.x) / float(img.get_width())


## Sorts a COPY of `ids` back-to-front, primarily by width CLASS — every
## slim piece (see _is_slim()) before every large piece — and by piece
## value (the existing "how strong is this piece" number every def already
## carries — read the same way elsewhere, e.g. game.gd:3494's
## `defs[board[pos].id].value`) within each class, ascending. Slim-then-
## large, not value alone, since Max, 2026-09-25: Aux's review of #582 found
## a large piece (a Knight, high-value already) at the tail of a BACK row
## covering its neighbour — a plain value sort can still put a large piece
## behind a slim one whenever a cheap large piece (e.g. Alibaba, value 20,
## large-class) sorts ahead of an expensive slim one (e.g. Amazon, value
## 120, slim-class). Class comes first so that can't happen: every large
## piece's row is >= every slim piece's row, since row assignment (build()'s
## row_of[]) is monotonic in this sorted order. Drawn first = the back;
## drawn last = the front, on top. Stable within a class: equal-value pieces
## keep their original relative order, via an explicit index tiebreak rather
## than relying on sort_custom's own stability.
static func _back_to_front(ids: Array) -> Array:
	var defs: Dictionary = Rules.load_pieces()
	var tagged := []
	for i in ids.size():
		var id: String = ids[i]
		var size_rank: int = 0 if _is_slim(id) else 1
		var value: int = int(defs.get(id, {}).get("value", 0))
		tagged.append([size_rank, value, i, id])
	tagged.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] < b[0]
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[2] < b[2])
	var out := []
	for t in tagged:
		out.append(t[3])
	return out
