## NO-157: one shared "mass of pieces" renderer for the Army Choice carousel
## (menu.gd's _show_armies) and the Reinforcements announcement (modals.gd's
## show_reinforce). Both screens want the same thing — every piece drawn
## individually, formed into tidy ranks so it reads as a crowd, not a
## de-duplicated icon with a "×N" badge — so it lives in ONE place instead of
## two. Replaces NO-146's _army_group_picture and NO-141's
## _reinforce_group_picture (both deleted): the same phrase produced two
## separate implementations last round, because two agents each built one.
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
	# overlap — the "neatly packed" rank spacing, exact and un-jittered.
	# A RATIO of ICON, not an independent number: the next size change is
	# one constant (ICON), not two literals that happen to agree today.
const JITTER_Y := ICON * 0.075 # px — Max, 2026-09-20: "barely not aligned
	# horizontally" — a small per-piece vertical wobble so a rank's baseline
	# waves slightly rather than ruling dead straight. Deliberately small:
	# any more and it reads as a blob again, same failure as the old scatter.
	# Also a ratio of ICON (3px at the original 40px) so it scales with the
	# icon instead of shrinking to a proportionally smaller wobble.
const JITTER_ROT := 0.3 # radians (~17°) — the "random tilt" Max asked to
	# keep; X position is NOT jittered any more (see build()), so this is
	# the only thing that stops a rank looking stamped from one mould.
# Same value as game.gd's COL_SIDE_PLAYER (game.gd:91) — duplicated rather
# than read off the `load()`'d script below: that call is verified working
# for a static FUNCTION (hud.gd's own load("res://scripts/menu.gd") calls
# MenuScript._SAVE_PATHS() the same way), but this file was written without
# a Godot instance to confirm the same `.` access resolves a plain `const`
# on a runtime-loaded (not preloaded) script — see the report's "could not
# verify" list.
const COL_SIDE_PLAYER := Color(0.72, 0.85, 1.25)

## Renders `ids` — the FULL list, duplicates included; three arriving pawns
## draw as three pawns, never "pawn ×3" — as a fixed-size Control: one
## TextureRect per piece, formed into 1-3 tidy ranks (Max, 2026-09-20: "2 or 3
## rows neatly packed with a random tilt, and barely not aligned
## horizontally" — never a square grid/blob for a big army). The X pitch is
## exact (no horizontal jitter); only a small per-piece Y offset and rotation
## vary. Player/light side only — neither caller ever shows the enemy's art.
##
## Seeded from `hash(ids)`, not randomize(): the same army or reinforcement
## list draws identically every time, so a screenshot of it stays diffable
## and the fan doesn't reshuffle on repaint (CLAUDE.md, NO-157).
static func build(ids: Array) -> Control:
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
	# Rows chosen from the count, never more than 3 (Max's ruling above): 1
	# for a couple of pieces, 2 up to 8, 3 beyond that — Crown/Cult/Old
	# Guard/Wild Hunt's 11-piece armies and Horde's 14 all land on 3 ranks,
	# never a near-square blob. Columns fill out whatever rows leaves over.
	#
	# Worst case at ICON=52, checked by hand (NO-157, 2026-09-20): Horde's 14
	# pawns -> rows=3, cols=ceili(14/3)=5 -> mass width =
	# (5-1)*31.2 + 52 + 2*(26+3.9) = 236.6px. The Army carousel card is
	# `viewport.x - 80` wide (menu.gd _show_armies) = 400px at the 480px
	# portrait width this project targets — 236.6px fits with ~163px to
	# spare. Re-check this if ICON changes again; it is not enforced in code.
	var n := ids.size()
	var rows := 1
	if n > 8:
		rows = 3
	elif n > 2:
		rows = 2
	var cols := maxi(1, ceili(float(n) / float(rows)))
	var pad := ICON * 0.5 + JITTER_Y # ICON/2 for the icon's own half-width,
		# plus JITTER_Y as slack for its vertical wobble (and, incidentally,
		# for the small bounding-box growth JITTER_ROT's tilt adds)
	mass.custom_minimum_size = Vector2(
		(cols - 1) * CELL + ICON + pad * 2.0,
		(rows - 1) * CELL + ICON + pad * 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ids)
	for i in ids.size():
		var id: String = ids[i]
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
		var col := i % cols
		var row := i / cols
		# X is exact pitch, no jitter — "neatly packed" ranks. Y gets a small
		# wobble and the icon a small tilt; that's the whole randomness budget.
		icon.position = Vector2(
			pad + col * CELL,
			pad + row * CELL + rng.randf_range(-JITTER_Y, JITTER_Y))
		icon.rotation = rng.randf_range(-JITTER_ROT, JITTER_ROT)
		mass.add_child(icon)
	return mass
