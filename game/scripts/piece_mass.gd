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
## crowd — a roughly square blob, pawns at the back, distinctive pieces at
## the front, heavy overlap both ways, staggered rows, varied tilt, a mild
## depth scale. See build()'s header comment for the geometry.
##
## Pure logic-over-nothing module, same shape as tuning.gd/armies.gd: no
## nodes of its own, one static entry point.

const ICON := 52.0 # 40 * 1.3 — Max, 2026-09-20: chose bigger icons over
	# tighter packing ("i think we can just increase the size of the icons by
	# 30%"). Was NO-146's original 40px; Tuning.OFFBOARD_ICON (72px) is sized
	# for the off-board strip's own row height, not a crowd of a dozen-plus
	# overlapping tokens, and would force scrolling or clipping here — see
	# build()'s Horde-14 arithmetic below for the worst case at this size.
const CELL := ICON * 0.6 # horizontal pitch, well under ICON so neighbours
	# overlap. A RATIO of ICON, not an independent number: the next size
	# change is one constant (ICON), not two literals that happen to agree
	# today.
const ROW_PITCH := ICON * 0.45 # NO-178: vertical pitch between rows — tighter
	# than CELL so rows pile into each other, not just sit stacked (the old
	# row pitch equalled CELL, which read as ranks, not a crowd).
const STAGGER := CELL * 0.5 # NO-178: alternate rows shift right by half a
	# cell so pieces nest into the gaps of the row behind, instead of lining
	# up into a visible grid.
const JITTER_Y := ICON * 0.075 # px — Max, 2026-09-20: "barely not aligned
	# horizontally" — a small per-piece vertical wobble so a rank's baseline
	# waves slightly rather than ruling dead straight. Also a ratio of ICON
	# (3px at the original 40px) so it scales with the icon instead of
	# shrinking to a proportionally smaller wobble.
const JITTER_ROT := 0.45 # radians (~25.8°) — NO-178: widened from 0.3
	# (~17°) to match Max's mockup, where a front-row rook is tilted roughly
	# 20-30°. X position is still not jittered (see build()); rotation plus
	# the NO-178 stagger below are what stop a row looking stamped from one
	# mould.
const DEPTH_BACK_SCALE := 0.85 # NO-178: mild perspective — back rows drawn
	# at this fraction of full size, rising linearly to 1.0 at the front row.
	# Unitless (it multiplies a Control's .scale, not a px distance), so it
	# is not expressed as a ratio of ICON the way the pitch/jitter constants
	# above are — there's no ICON-relative quantity it needs to track. Kept
	# subtle on purpose: this is perspective, not a size ladder.
const TARGET_ASPECT := 1.15 # width:height the crowd's bounding box should
	# land near — Max's own mockup selection measured 467x400 (≈1.1675),
	# "roughly square, slightly wider than tall".
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
## a crowd: one TextureRect per piece, rows derived from the count so the
## bounding box lands near TARGET_ASPECT (NO-178 — replaces the old fixed
## 1-3-rank rule, which produced a wide flat strip). Pawns and other
## low-value pieces sit at the back (drawn first, slightly smaller); rooks,
## knights and anything bigger sit at the front (drawn last, full size, on
## top). Player/light side only — neither caller ever shows the enemy's art.
##
## Seeded from `hash(ids)`, not randomize(): the same army or reinforcement
## list draws identically every time, so a screenshot of it stays diffable
## and the fan doesn't reshuffle on repaint (CLAUDE.md, NO-157). The seed is
## taken from `ids` before any internal reordering, so it stays a property of
## the input list, not of how this function happens to sort it.
##
## `max_width`, NO-179 (Army card shrink): 0 (the default) means "render at
## ICON, whatever width that takes" — modals.gd's show_reinforce never passes
## it, so that caller is untouched. A caller that DOES pass a positive value
## gets ICON scaled DOWN (never up) just far enough that the crowd's bounding
## width fits it. CELL/ROW_PITCH/STAGGER/JITTER_Y are already ratios of ICON
## (see the consts above), so scaling ICON alone scales the whole layout
## together — no second size constant to keep in sync.
static func build(ids: Array, max_width: float = 0.0) -> Control:
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
	var rows := _choose_rows(n)
	var cols := maxi(1, ceili(float(n) / float(rows)))

	# pad(sz): half an icon's own width/height, plus its vertical jitter
	# wobble, plus the bounding-box growth a square gains when rotated up to
	# JITTER_ROT (a square of side sz rotated by θ has half-extent
	# (sz/2)*(cos θ + sin θ), i.e. (cos θ + sin θ - 1) more than unrotated).
	# A function of icon size, not a const (GDScript const initializers can't
	# call cos()/sin()), because `max_width` below needs it evaluated twice:
	# once at ICON to size the scale-down, once at the chosen icon_size to
	# lay pieces out.
	var pad_for := func(sz: float) -> float:
		var rot_extra: float = (sz * 0.5) * (cos(JITTER_ROT) + sin(JITTER_ROT) - 1.0)
		return sz * 0.5 + sz * (JITTER_Y / ICON) + rot_extra
	var width_for := func(sz: float) -> float:
		var cell: float = sz * (CELL / ICON)
		var stagger: float = sz * (STAGGER / ICON)
		return (cols - 1) * cell + sz + pad_for.call(sz) * 2.0 + (stagger if rows > 1 else 0.0)

	# Icon size for THIS build: ICON, scaled DOWN (never up) just far enough
	# that the crowd's bounding width fits max_width.
	#
	# Worst case at ICON=52, checked by hand (NO-178/NO-179, 2026-09-21):
	# Horde's 14 pawns -> rows=4 (from _choose_rows), cols=ceili(14/4)=4 ->
	# natural mass width = width_for(52) = 238.4px. The Army carousel card
	# (menu.gd _show_armies) passes max_width = card_w - 20 (card_style's
	# content_margin_left/right) = 210 - 20 = 190px at the 480px portrait
	# width this project targets (card_w = 400 * ARMY_CARD_WIDTH_FRACTION =
	# 400 * 0.525 = 210) — so Horde scales to icon_size = 52 * 190/238.4 ≈
	# 41.4px (natural ICON=52 unaffected; modals.gd's show_reinforce never
	# passes max_width, so that caller renders exactly as before). Re-check
	# this if ICON, JITTER_ROT, the pitch constants, or
	# ARMY_CARD_WIDTH_FRACTION change again; it is not enforced in code.
	var icon_size := ICON
	if max_width > 0.0:
		var natural_w: float = width_for.call(ICON)
		if natural_w > max_width:
			icon_size = ICON * max_width / natural_w

	var cell: float = icon_size * (CELL / ICON)
	var row_pitch: float = icon_size * (ROW_PITCH / ICON)
	var stagger: float = icon_size * (STAGGER / ICON)
	var jitter_y: float = icon_size * (JITTER_Y / ICON)
	var pad: float = pad_for.call(icon_size)

	mass.custom_minimum_size = Vector2(
		(cols - 1) * cell + icon_size + pad * 2.0 + (stagger if rows > 1 else 0.0),
		(rows - 1) * row_pitch + icon_size + pad * 2.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ids)

	var sorted_ids: Array = _back_to_front(ids)
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
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.size = Vector2(icon_size, icon_size) # `mass` is a bare Control, not a
			# Container, so nothing else would size this child
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.pivot_offset = Vector2(icon_size, icon_size) * 0.5 # rotate AND scale
			# around its own centre, not the top-left corner
		if game_script.is_mono_piece(id): # the King's own path today (CLAUDE.md, "Piece art")
			icon.modulate = COL_SIDE_PLAYER
		var col := i % cols
		var row := i / cols
		# X pitch is exact, plus a half-cell stagger on odd rows so pieces
		# nest into the row behind rather than forming a grid. Y gets a small
		# wobble and the icon a tilt; row also gets a mild depth scale (back
		# rows a little smaller, front rows full size).
		icon.position = Vector2(
			pad + col * cell + (stagger if row % 2 == 1 else 0.0),
			pad + row * row_pitch + rng.randf_range(-jitter_y, jitter_y))
		icon.rotation = rng.randf_range(-JITTER_ROT, JITTER_ROT)
		var depth: float = 1.0 if rows <= 1 \
			else lerp(DEPTH_BACK_SCALE, 1.0, float(row) / float(rows - 1))
		icon.scale = Vector2(depth, depth)
		mass.add_child(icon)
	return mass


## Rows derived from the piece count, not a hardcoded ladder: tries every row
## count from 1 to n and keeps whichever bounding box lands closest to
## TARGET_ASPECT. Cheap (n is at most ~14 — Horde's army) and works the same
## way for Reinforcements' 2-3 pieces as it does for a full army.
static func _choose_rows(n: int) -> int:
	var best_rows := 1
	var best_err := INF
	for rows in range(1, maxi(1, n) + 1):
		var cols := maxi(1, ceili(float(n) / float(rows)))
		var w: float = (cols - 1) * CELL + ICON + (STAGGER if rows > 1 else 0.0)
		var h: float = (rows - 1) * ROW_PITCH + ICON
		var err: float = absf(w / h - TARGET_ASPECT)
		if err < best_err:
			best_err = err
			best_rows = rows
	return best_rows


## Sorts a COPY of `ids` back-to-front by piece value (the existing "how
## strong is this piece" number every def already carries — read the same
## way elsewhere, e.g. game.gd:3494's `defs[board[pos].id].value`),
## ascending: pawns and other cheap pieces first (drawn first = the back,
## since build()'s row = index/cols puts early indices in early rows), rooks/
## knights/anything pricier last (drawn last = the front, on top). Stable:
## equal-value pieces keep their original relative order, via an explicit
## index tiebreak rather than relying on sort_custom's own stability.
static func _back_to_front(ids: Array) -> Array:
	var defs: Dictionary = Rules.load_pieces()
	var tagged := []
	for i in ids.size():
		var id: String = ids[i]
		var value: int = int(defs.get(id, {}).get("value", 0))
		tagged.append([value, i, id])
	tagged.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] < b[0]
		return a[1] < b[1])
	var out := []
	for t in tagged:
		out.append(t[2])
	return out
