## NO-157: one shared "mass of pieces" renderer for the Army Choice carousel
## (menu.gd's _show_armies) and the Reinforcements announcement (modals.gd's
## show_reinforce). Both screens want the same thing — every piece drawn
## individually, fanned and jittered so it reads as a crowd, not a
## de-duplicated icon with a "×N" badge — so it lives in ONE place instead of
## two. Replaces NO-146's _army_group_picture and NO-141's
## _reinforce_group_picture (both deleted): the same phrase produced two
## separate implementations last round, because two agents each built one.
##
## Pure logic-over-nothing module, same shape as tuning.gd/armies.gd: no
## nodes of its own, one static entry point.

const ICON := 40.0 # NO-146's own size for this card — small enough that
	# Horde's 14 pawns (Tuning.ARMIES) still fit fanned inside a menu carousel
	# card without cropping. Tuning.OFFBOARD_ICON (72px) is sized for the
	# off-board strip's own row height, not a crowd of a dozen-plus
	# overlapping tokens, and would force scrolling or clipping here.
const CELL := ICON * 0.6 # grid pitch, well under ICON so neighbours overlap
const JITTER_POS := 6.0 # px, each axis
const JITTER_ROT := 0.3 # radians (~17°)
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
## TextureRect per piece, placed on a loose grid and jittered in position and
## rotation so it reads as a fanned mass rather than a grid. Player/light
## side only — neither caller ever shows the enemy's art.
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
	var cols := maxi(1, ceili(sqrt(float(ids.size()))))
	var rows := maxi(1, ceili(float(ids.size()) / float(cols)))
	var pad := JITTER_POS + ICON * 0.5
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
		icon.position = Vector2(
			pad + col * CELL + rng.randf_range(-JITTER_POS, JITTER_POS),
			pad + row * CELL + rng.randf_range(-JITTER_POS, JITTER_POS))
		icon.rotation = rng.randf_range(-JITTER_ROT, JITTER_ROT)
		mass.add_child(icon)
	return mass
