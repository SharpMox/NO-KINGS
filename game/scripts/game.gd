extends Node2D
## The whole run: SETUP placement -> PLAYER_TURN <-> ENEMY_TURN -> GAME_OVER.
## This node owns run state, the turn state machine, input, and board
## painting. Everything else is split out (all UI still built in code):
## rules.gd (move legality) · wave_logic/economy/merge_logic/save_config/
## item_logic/box (domain logic, statics over this node) · hud.gd + modals.gd
## (child UI layers — signals up, calls down) · autoplay.gd (headless bot).

const Rules := preload("res://scripts/rules.gd")
const BackGuard := preload("res://scripts/back_guard.gd")
const Box := preload("res://scripts/box.gd")
const ItemLogic := preload("res://scripts/item_logic.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const Economy := preload("res://scripts/economy.gd")
const GlobalBoard := preload("res://scripts/global_board.gd")
const MergeLogic := preload("res://scripts/merge_logic.gd")
const SaveConfig := preload("res://scripts/save_config.gd")
const CloudSave := preload("res://scripts/cloud_save.gd")
const Shop := preload("res://scripts/shop.gd")
const AutoplayBot := preload("res://scripts/autoplay.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Waves := preload("res://data/waves.gd")
const Items := preload("res://data/items.gd")
const KingAbilities := preload("res://data/king_abilities.gd")
const Scenarios := preload("res://data/scenarios.gd")
const Settings := preload("res://scripts/settings.gd")
const Kings := preload("res://data/kings.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")
const Armies := preload("res://scripts/armies.gd")
const HudScript := preload("res://scripts/hud.gd") # HEADER_H feeds the board solve (NO-83)

enum State { SETUP, PLAYER_TURN, ENEMY_TURN, GAME_OVER }

## Boot config for the next Game scene (menu sets it; Restart CLEARS it —
## a71f574, so a Continue-entered run re-rolls rather than replaying itself).
## Shape documented in data/scenarios.gd — the save file uses the same format.
static var next_config := {}
## TEST-menu / CLI scenario runs never autosave over the real run.
static var is_scenario := false
## Starting stock for a fresh run (menu's army select sets it; saves carry
## their stock in next_config instead, so this only matters when empty).
static var next_army: String = Tuning.DEFAULT_ARMY
## Difficulty tier (07-difficulty-ranks): menu's tier picker sets it, locked
## for the run — a save/Continue restores it via SaveConfig instead of
## re-reading this, same split as next_army above.
static var next_tier: String = Tuning.DEFAULT_TIER
## issue 75: "" means roll a fresh random seed, as before. Set from --seed or
## the new-run screen. Kept as the raw String the player typed so it can be
## shown back to them verbatim on the results screen.
static var next_seed: String = ""
## NO-77: a `--autoplay` / `--scenario N` launch is honoured by the FIRST Game
## boot only. The args last for the whole process, so without this every
## later Menu load (pause -> Main Menu) re-forwarded into a fresh copy of the
## scenario, and Play re-applied it. Set by the first Game._ready, read by
## menu.gd before it forwards and by the arg checks below.
static var cli_bypass_used := false


## Any string -> a stable seed. Digits are used as-is so "12345" behaves like
## the number a player expects; anything else is hashed, so words work too.
static func seed_of(text: String) -> int:
	return int(text) if text.is_valid_int() else int(hash(text))

const SAVE_PATH := "user://save.json"
const SCORES_PATH := "user://scores.json"
const HISTORY_PATH := "user://history.json"


## Local high scores, best first: [{score, wave, kings}], top 10 kept.
static func load_scores() -> Array:
	if not FileAccess.file_exists(SCORES_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCORES_PATH))
	return parsed if parsed is Array else []


## Games History: every real run's summary, newest first — distinct from the
## top-10 Highscores above. See Economy.record_history for what's stored.
static func load_history() -> Array:
	if not FileAccess.file_exists(HISTORY_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(HISTORY_PATH))
	return parsed if parsed is Array else []

## Y1/NO-216: two selectable board chequers, id -> {light, dark, label}. The
## values are the single source of truth for the chequer — piece_diagram.gd
## reads COL_LIGHT/COL_DARK off this class at runtime (see its NO-215
## comment) rather than keeping its own copy, and settings.gd reads this
## dict the same way to build its switcher, so a third theme is one new
## entry here, nowhere else.
const BOARD_THEMES := {
	"sage": {"light": Color("DCF5B7"), "dark": Color("8763A8"), "label": "Sage"},
		# NO-215: lighter, warmer sage — supersedes NO-177's D0E6B3/573F6E,
		# exact hex from Max, 2026-09-21
	"sand": {"light": Color("EAE0D0"), "dark": Color("8483B6"), "label": "Sand"},
		# Y1/NO-216: warm off-white on muted blue-violet, exact hex from Max,
		# 2026-09-21 — lower-contrast and cooler than Sage by design
}
const DEFAULT_BOARD_THEME := "sage"
static var COL_LIGHT: Color = BOARD_THEMES[DEFAULT_BOARD_THEME].light
static var COL_DARK: Color = BOARD_THEMES[DEFAULT_BOARD_THEME].dark


## Switches the active chequer; callers still need queue_redraw() to see it
## (static vars don't trigger one). Unknown ids fall back to the default
## rather than erroring, since this only ever gets a value the player's own
## settings toggle wrote.
static func set_board_theme(theme_id: String) -> void:
	var t: Dictionary = BOARD_THEMES.get(theme_id, BOARD_THEMES[DEFAULT_BOARD_THEME])
	COL_LIGHT = t.light
	COL_DARK = t.dark

const COL_PLAYER := Color("1a3a6b")
const COL_ENEMY := Color("8b1a1a")
# side shift for monochrome tokens only — the painted art carries its own colour
const COL_SIDE_PLAYER := Color(0.72, 0.85, 1.25)
const COL_SIDE_ENEMY := Color(1.25, 0.72, 0.72)
const COL_PLACE := Color(0.2, 0.5, 0.9, 0.6) # placement / setup-relocation blue
# Palette rule (2026-07-07): everything player-side is a shade of blue —
# selection, moves, placement, merge partners; everything enemy-side is red —
# enemy pieces, threats, capture targets, recon.
const COL_MOVE := Color(0.3, 0.55, 0.95, 0.8)
const COL_CAPTURE := Color(0.85, 0.15, 0.15)
const COL_SELECT := Color(0.35, 0.62, 1.0, 0.4)
const COL_MERGE := Color(0.45, 0.85, 1.0) # cyan-blue: merge partners
const COL_ARROW := Color(0.95, 0.65, 0.15, 0.9) # Arrow Planning: deliberately
	# outside the blue/red side palette — decorative, not player or enemy state
const HATCH_SPACING := 8.0 # NO-122: pitch of the hatch lines. A single
	# direction fills a target-zone tile with ordinary (single) coverage —
	# NO-176 replaced the old flat Color(COL_CAPTURE, 0.22) rect wash with
	# this. Both directions together (the existing crosshatch) mark a tile
	# covered by more than one zone: direction COUNT is the overlap signal,
	# not alpha-stacking, so single coverage and overlap stay distinguishable
	# regardless of alpha tuning. NO-184: _draw_hatch now phases its lines off
	# board_px (board-space), not each tile's own rect — `tile` is computed
	# per-viewport in _layout_board and is NOT always a multiple of this
	# spacing, so a per-tile-local phase (the old behaviour) drifted out of
	# alignment across a tile boundary on real device sizes even though it
	# happened to line up at the desktop default (72, a multiple of 8).
const HATCH_ALPHA := 0.6 # NO-184: was 0.8 (NO-176) — read nearly solid at
	# that weight, over-correcting NO-176's own flag below. NOT VERIFIED ON
	# SCREEN — flag per NO-150's lesson.
const HATCH_WIDTH := 1.0 # NO-184: was 2.0 (NO-176) — thinner lines, paired
	# with the alpha drop above so the hatch reads as a texture, not a wash.
	# NOT VERIFIED ON SCREEN.
const HATCH_BLUE_PHASE := HATCH_SPACING * 0.5 # NO-184: the reachable
	# (move) zone's hatch is offset half a pitch from the red bomb/Item
	# hatch's phase (0), so a tile covered by both interleaves the two
	# colours instead of stacking them. Max's ruling: an offset, not a
	# second hatch direction — direction COUNT already means "more than one
	# zone" (see HATCH_SPACING above), so a blue `\` next to a red `/` would
	# collide with that vocabulary on any blue+red overlap.
const ANIM_TIME := 0.12 # seconds per move slide / capture pop

# NO-129: reachable-zone outline, a steadier selection ring, and larger/
# semi-transparent move+capture indicators — a spread of legal moves read as
# scattered marks rather than one shape. No new COL_* here: the outline and
# ring reuse COL_MOVE/COL_ENEMY/COL_SELECT/COL_CAPTURE at a different alpha.
# NO-150: 0.55/2.0 didn't read at a glance (flagged at NO-129 review) — bumped
# by eye against the NO-129 screenshots until the outline is unmistakable
# beside the board grid without overpowering the move dots/arrows.
const ZONE_OUTLINE_ALPHA := 0.6 # NO-176: was 0.9 — Max flagged real board
	# screenshots ("careful of lines stacking up on each other and looking
	# weird"). Safe only because _draw_zone_outline now draws every internal
	# boundary edge exactly once (see its NO-176 comment below) — two 0.6
	# strokes still compositing on the same edge is the exact "third colour"
	# this drop is meant to avoid, not just soften.
const ZONE_OUTLINE_WIDTH := 3.5
const ZONE_OUTLINE_OVERLAP_ALPHA := 0.9 # NO-183: the overlap boundary is a
	# thin marker interrupting the larger blue/red outline shapes, not a
	# shape of its own competing for the same "don't stack up and look
	# weird" budget ZONE_OUTLINE_ALPHA (0.6) was tuned for — raised toward
	# opaque so the purple (see COL_ZONE_OUTLINE_OVERLAP) reads at a glance.
# NO-161: board highlight palette. COL_MOVE/COL_CAPTURE stay as they were
# (move dots/arrows, the capture ring) — these three are only for the zone
# OUTLINE and the capture tile wash, which needed their own values:
const COL_ZONE_OUTLINE_MOVE := Color(0.55, 0.75, 1.0) # lighter than COL_MOVE
	# (0.3, 0.55, 0.95) so the outline itself reads as distinct from the move
	# dots/arrows it wraps, not a repeat of the same blue
const COL_ZONE_OUTLINE_OVERLAP := Color(0.75, 0.45, 1.0) # where a move-tile
	# outline edge and a capture-tile outline edge fall on the identical
	# boundary (two tiles of different kinds touching inside one reachable
	# zone), drawn once in this colour. NOT relied on to emerge from
	# stacking blue-then-red: both outline strokes sit at ZONE_OUTLINE_ALPHA
	# 0.9, so the underlying layer would barely show through the top one —
	# computed explicitly instead of hoped for (can't screenshot to check).
	# NO-183: Max asked for purple here explicitly ("I want purple outlines
	# where blue and red stack") and his later complaint ("the purple
	# outlines don't really show up") is that the mark was invisible, not a
	# request for a different colour — purple stays; a same-hue-family
	# stand-in (tried: gold, purple's complement) was reverted because it
	# breaks the blue=move/red=capture/purple=both vocabulary and needs
	# babysitting against COL_ARROW for no reason purple ever had. The old
	# value (0.62, 0.32, 0.88) sat close in both HUE and VALUE to NO-177's
	# aubergine dark square (#573F6E) — flagged as a predicted failure on
	# that ticket, never verified until now. This is separated on VALUE
	# instead: a much lighter, more saturated violet/lavender, so it stands
	# off the dark aubergine square by brightness and off the pale sage
	# square by saturation and hue, rather than trying to out-contrast
	# aubergine on hue alone (purple-on-purple, however different the
	# shade, is the fight NO-177 flagged in the first place). Paired with
	# ZONE_OUTLINE_OVERLAP_ALPHA below (was folded into the shared
	# ZONE_OUTLINE_ALPHA, 0.6 — a boundary marker can afford more than the
	# large outline shapes it interrupts). NOT VERIFIED ON SCREEN.
const SELECTED_INSET := -6.0 # NO-199: the selected piece draws bigger than a
	# normal token (the -6.0 at the board draw loop below) — the outline
	# shader traces that SAME enlarged rect, shared here so it can't drift
	# out of sync with the piece's actual drawn size.
const SELECT_OUTLINE_WIDTH := 6.0 # px, how far the outline shader dilates past
	# the token's own alpha silhouette — NO-199, replacing NO-183's ring (a
	# flat circle, never the piece's own shape) with one that traces it.
	# Max, 2026-09-21: doubled from 3.0 — at 3px the outline was there but did
	# not announce "selected" the way the ring it replaced did.
const SELECT_OUTLINE_RIM := 3.0 # px of SELECT_OUTLINE_WIDTH given to the outer
	# purple rim; the rest nearer the piece is BUFF_BADGE_BG — the same
	# dark-fill/light-rim split NO-185 used for buff badges against these
	# same four backgrounds (COL_LIGHT/COL_DARK tiles, light/dark tokens).
const SELECT_OUTLINE_RIM_ALPHA := 0.8 # Max, 2026-09-21: "a transparent purple
	# to contrast with the red and blue". Scales the pulse, so the rim breathes
	# 0.56-0.80 rather than 0.70-1.00 — present without reading as a solid band.
const SELECT_OUTLINE_ALPHA_MIN := 0.7 # NO-183's breathing range, reused as-is
const SELECT_OUTLINE_ALPHA_RANGE := 0.3 # for the outline's pulse (0.7-1.0)

## NO-199: traces the selected piece's own alpha silhouette instead of a flat
## ring. Samples TEXTURE's alpha at two dilations around each transparent
## pixel (16 directions — a distance-transform approximation, cheap here
## since it only ever runs over the one selected token) and paints the
## nearer band BUFF_BADGE_BG-dark, the further one COL_SELECT/COL_CAPTURE —
## the same dark-fill/light-rim split NO-185 used for buff badges, so it
## reads against COL_LIGHT and COL_DARK tiles alike. UV outside [0,1] reads
## as transparent rather than clamping to the texture edge, so a piece whose
## painted alpha touches its own 192x192 canvas (a few do) doesn't smear a
## false band there. Works unchanged for the mono-SVG King path — it only
## ever reads alpha, never the source colour.
const SELECT_OUTLINE_SHADER := """
shader_type canvas_item;
uniform vec4 rim_color : source_color = vec4(1.0);
uniform vec4 fill_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float fill_reach = 0.02; // UV fraction: dilation for the inner (dark) band
uniform float rim_reach = 0.03;  // UV fraction: dilation for the outer (colour) band

float _alpha_at(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

void fragment() {
	// TEXTURE only exists inside fragment() — passed explicitly to the
	// helper rather than referenced from it (that's what failed to compile:
	// "Unknown identifier in expression: 'TEXTURE'"). No `return` in here —
	// processor functions reject it outright ("Using 'return' in the
	// 'fragment' processor function is incorrect") — so this falls through
	// an if/else instead, COLOR assigned exactly once per branch.
	if (_alpha_at(TEXTURE, UV) > 0.5) {
		COLOR = vec4(0.0); // inside the token — the real piece draws itself here
	} else {
		float fill_hit = 0.0;
		float rim_hit = 0.0;
		for (int i = 0; i < 16; i++) {
			float ang = float(i) * 0.39269908; // TAU / 16
			vec2 dir = vec2(cos(ang), sin(ang));
			fill_hit = max(fill_hit, _alpha_at(TEXTURE, UV + dir * fill_reach));
			rim_hit = max(rim_hit, _alpha_at(TEXTURE, UV + dir * rim_reach));
		}
		if (fill_hit > 0.5) {
			COLOR = fill_color;
		} else if (rim_hit > 0.5) {
			COLOR = rim_color;
		} else {
			COLOR = vec4(0.0);
		}
	}
}
"""
const MOVE_INDICATOR_ALPHA := 0.55 # was 0.85 (recon) / 0.9 (player) baked in
const MOVE_DOT_RADIUS := 13.0 # was 10.0 (leap) / 8.0 (linked/bent dots) —
	# NO-183: the leap dot itself is gone (see the legal_paths match below);
	# this constant now sizes only the hop/bent linked-dot path, which is
	# unaffected (it shows the path SHAPE, not a plain destination marker,
	# so it stayed out of "remove the circle indicators").
const ARROW_WIDTH := 4.5 # was 3.0 — ride-move arrow only, not Arrow Planning
const ARROW_HEAD_LEN := 20.0 # was 14.0
const ARROW_HEAD_HALF := 11.0 # was 8.0

# NO-101: text-mode glyph marking the four LITERAL inv- ids (inv-sergeant,
# inv-arrow-pawn, inv-kirin-plus, inv-kirin-plus-plus) only — never the ten
# inversion pairs that turn a piece into an ordinary existing piece (those
# keep that piece's own id, so this check never sees them; out of scope per
# Max's ruling 2026-09-16). U+27F2 ANTICLOCKWISE OPEN CIRCLE ARROW; no glyph
# in Open Sans SemiBold, so an OS fallback font renders it, same as every
# other symbol on this board — confirmed monochrome on macOS. At the corner
# mark's first size (tile * 0.3) it rendered as an unreadable speck; that
# was a SIZE bug, not missing glyph coverage (U+21BA renders no bigger from
# the same fallback) — fixed by sizing the mark for legibility below.
const INV_MARK_GLYPH := "⟲"

# NO-185: Piece Buff badges (BuffLogic.PIECE_BUFF_GLYPHS) — a dark disc with a
# light ring behind each glyph, rather than a flat colour matched to the
# background. A flat glyph colour can't win against all four combinations
# this board can put behind it (the sage light square, the aubergine dark
# square — NO-177 — and both the light and dark painted token art); a badge
# with its own fixed contrast doesn't need to. NOT VERIFIED ON SCREEN —
# screenshot at mobile tile size (~52px), light + dark, both chequer colours.
const BUFF_BADGE_RING := Color(1, 1, 1, 0.92)
const BUFF_BADGE_BG := Color(0.05, 0.05, 0.08, 0.9)
const BUFF_BADGE_GLYPH_COL := Color.WHITE

# board layout, computed from the viewport in _ready so any BOARD_W/H fits
var tile := 72
var board_px := Vector2(24, 120)

var defs: Dictionary
var fusions: Dictionary # unordered pair "a+b" -> result id
var textures := {} # id -> {Rules.PLAYER: Texture2D, Rules.ENEMY: Texture2D}
var mono_art := {} # ids whose token is one shared image, so it needs the side tint
var board := {} # Vector2i -> {id, owner}
var state := State.SETUP
var wave := 0            # last spawned wave number
var turns_since_wave := 0
var turn_number := 0 # run-long counter (issue 35), incremented once at the
	# single _begin_player_turn site — unlike turns_since_wave (reset every
	# Wave, in _enemy_turn), this never resets; Black Knight Morse Code's
	# "every 3rd Turn" reads it. Round-tripped through save_config.gd.
var kings_defeated := 0  # 1 = endless unlocked; end screens show it
var king_ids_defeated: Array = []  # roster (Kings.name_of), same order as falls
## issue 89: the run's King line-up — one costume tier, its four Kings in a
## shuffled order. Rolled ONCE at run start and saved, never re-derived: a
## re-roll on load would hand a resumed run a different King than the one it
## was about to fight.
var king_tier := ""
var king_order: Array = []
## issue 90: the King held back through segment 1 of its wave, or {}.
var pending_king: Dictionary = {}
## issue 91: the King Ability is once per Wave, same idiom as the Army's
## (army_ability_used_this_wave) — reset by WaveLogic.queue.
var king_ability_used_this_wave := false
## issue 91: the Tariff key a King's Power put in force, so it can be taken
## back out when the wave ends. "" when no Power is live.
var king_power_abilities: Array = [] # keys in force from the King's Power (escalates)
## issue 92: the King whose Power is in force, or "". Distinct from the board
## King: the Power is live through segment 1, before the King has arrived.
var king_power_id := ""
## issue 93: Total Mobilisation adds an enemy Action for the REST of the wave,
## so it compounds with the turns still to come rather than being a one-off.
var king_extra_actions := 0
var win_open := false    # wave-50 win screen showing (Continue / End Run)
var lost_player := 0     # pieces lost, both sides — end-screen summary (GDD)
var lost_enemy := 0
var wave_start_lost_player := 0 # lost_player snapshot at wave start (artefact
	# hook 16: "clean wave" = lost_player unchanged since this snapshot)
var wave_capture_count := 0 # captures this wave, reset in WaveLogic.queue()
var turn_capture_count := 0 # captures this player turn, reset in _begin_player_turn
var run_capture_count := 0 # issue 55: run-long, never resets (Zeta Reticuli
	# Souvenir Map's "every 3rd Capture" of the whole run — the two indices
	# above reset on their own wave/turn boundaries and would undercount).
	# Persisted since issue 55. The sibling run-long counters below
	# (nibiru_wave_streak, club27_streak, lottery_purchase_count,
	# pallet_purchase_count) and the once-per-Wave activation flags joined it
	# in NO-20; this comment claimed none of them were saved, which was already
	# untrue of run_capture_count itself and is what made the gap read as
	# accepted rather than open.
var gold_spent_shop_this_wave := 0 # reset in WaveLogic.queue() (artefact hook 16)
var silk_road_active := false # Silk Road Coupon's -50% Shop prices, reset in
	# WaveLogic.queue() every wave (artefact hook 18)
var nibiru_wave_streak := 0 # Nibiru Hide-and-Seek Trophy: grows +1 per Wave
	# clear, reset to 0 on_piece_lost (artefact_hooks.gd, artefact hook 19)
var hoffa_used_this_wave := false # Hoffa's Cement Shoes: once per Wave, reset
	# on_wave_clear (artefact_hooks.gd, artefact hook 24)
var uap_used_this_wave := false # UAP Breath Mint: once per Wave, reset
	# on_wave_clear (artefact_hooks.gd, issue 54) — same idiom as Hoffa above
var torpedo_used_this_wave := false # Inflatable Vietcong Torpedo: once per
	# Wave, reset on_wave_clear (artefact_hooks.gd, issue 54)
var salvation_charged := true # Salvation Gift Card: ready to veto the next
	# Tariff applied; consumed on use, restored on_wave_clear at wave%5==0
	# (artefact hook 22)
var last_capture_ctx: Dictionary = {} # this move's on_capture ctx (Economy.
	# capture_score) — read back by _move_player after its own board mutation
	# for USS Eldridge / Royal Fiat's post-move reposition (artefact hook 24)
var club27_streak := 0 # 27 Club Punch Card (issue 26): grows +1 per clean
	# Wave clear, reset to 0 on_piece_lost — same shape as nibiru_wave_streak
var wave_lost_ids: Array = [] # ids of player pieces lost this Wave, in order
	# (Jon Burrows' Fake ID / Walt's Cryonic Capsule, issue 26); reset in
	# WaveLogic.queue(), appended in _lose_player_piece — distinct from the
	# run-wide lost_player counter above
var arks_bunkbed_used := false # Ark's Bunkbed: this 5-Wave Milestone window's
	# free duplicate already granted; reset on_wave_clear when this HELD COPY's
	# own per-artefact "5-Wave Milestone" cadence hits (ArtefactHooks.
	# _milestone5_hit, ruled 2026-08-28 — see artefact_hooks.gd)
var lottery_purchase_count := 0 # Pre-Scratched Lottery Ticket: Shop
	# purchases made while held (issue 26) — read by Shop.price()
var doomsday_snooze_used_this_wave := false # Doomsday Clock Snooze Button:
	# this Wave's one +25s already spent, reset in WaveLogic.queue() (26)
var dihydrogen_free_wave := -1 # Dihydrogen Monoxide Battery: wave its one free
	# Tactical Item use already fired this Wave, -1 = not yet (artefact hook 19)
var wardenclyffe_free_wave := -1 # same idea, Wardenclyffe AAA Batteries' any-tier version
var mar_a_lago_free_wave := -1 # Mar-a-Lago Toilet Papers: g.wave the free Shop
	# slot was last (re)picked, -1 = not yet — guards against a 2nd held copy's
	# own milestone dispatch, in the same on_wave_clear event, clearing the 1st
	# copy's freshly-tagged slot before it's counted (artefact hook 43)
var item_use_tactical_count := 0 # 33rd Degree Fidelity Card's per-tier use counters
var item_use_strategic_count := 0
var mrna_apply_count := 0 # mRNA Firmware Update: Piece Buffs applied to your
	# pieces so far — every 3rd also Ranks Up (artefact hook 23)
var youth_fountain_wave := -1 # Youth Fountain Martini: wave its one free
	# buff-consume re-apply already fired this Wave, -1 = not yet (hook 23)
var dnr_patch_wave := -1 # 'Definitely Not Russia' Patch (issue 53): wave its
	# one masked loss already used, -1 = not yet — same wave-stamp idiom as
	# dihydrogen_free_wave/youth_fountain_wave above, so a stale stamp from an
	# earlier Wave just reads as "not this Wave" with nothing to reset
var artefact_echo_depth := 0 # ArtefactHooks re-entrancy guard (artefact hook 21):
	# >0 while the meta/echo pass itself is running, so a handler that somehow
	# re-entered ArtefactHooks.run() could never trigger a second echo pass
var mona_lisa_turn_done := false # 100% Genuine Original Mona Lisa: this Turn's
	# (player or enemy) first Artefact trigger already echoed; reset in
	# ArtefactHooks.run() at on_turn_start/on_enemy_turn_start
var dejavu_score_turn_done := false # Déjà Vu Glitch: this Turn's first Score
	# gain already doubled; reset in ArtefactHooks.run() at on_turn_start
var dejavu_gold_turn_done := false # same idea, first Gold gain each Turn
var frog_armed := false # Frog Pride Flag (issue 45): armed by losing a piece
	# (on_piece_lost), consumed by the NEXT Deploy (on_deploy) — a single
	# flag, not one per lost piece: "the next piece" is singular, so losing
	# several before deploying still only arms once
var y2k_armed := false # Y2K Patch Floppy Disk (issue 45): (re)armed every
	# Wave start (on_wave_spawn), consumed by that Wave's first enemy Turn
	# (on_enemy_turn_start) — see artefact_hooks.gd for the deliberate
	# exception to the additive-stacking rule this makes
var pallet_purchase_count := 0 # Pandemic Toilet Paper Pallet (issue 45):
	# purchases made this Wave, reset on_wave_clear (artefact_hooks.gd) —
	# issue 61: moved off the "Shop visit" boundary, since the Shop panel can
	# be closed/reopened at will and _open_shop() no longer resets this
	# (contrast Pre-Scratched Lottery Ticket's lottery_purchase_count above,
	# which never resets at all)
var ecdysis_copy_key := "" # issue 55: Ecdysis Sheddings — the last OTHER
	# Artefact bought (set in ArtefactHooks.run() on on_purchase, kind ==
	# "artefact", unconditional of whether Ecdysis is held, so the history is
	# already there once it is; "" = inert, nothing bought yet, which is
	# correct not a bug). Box grants and effect grants never fire on_purchase
	# (shop.gd's buy() is the only call site), so they can't set this with no
	# extra guard needed. Never set to Ecdysis's own key ("other" excludes
	# it), which is also what keeps two held Ecdysis copies from chasing each
	# other. Persisted across saves (save_config.gd) — it's a fact about the
	# run, not a transient per-wave/turn flag.
var pending_spawn: Array = [] # piece ids waiting for open top-row tiles
var fx_at := Vector2.ZERO # where the next score popup lands; ZERO = HUD label
var score := 0:
	set(value): # every gain/loss anywhere pops floating feedback (round 4);
		# popups anchor to the piece/effect that caused them (game-feel pass)
		if value != score and is_node_ready() and not autoplay and animations_on:
			var d := value - score
			anims.append({"kind": "text", "t": 0.0, "dur": 1.2,
				"text": ("+%d" if d > 0 else "%d") % d,
				"at_px": fx_at if fx_at != Vector2.ZERO
					else Vector2(hud.score_label.get_global_rect().end) + Vector2(6, 0),
				"color": Color(0.3, 0.85, 0.35) if d > 0 else Color(0.95, 0.3, 0.25)})
			queue_redraw()
		score = value
var gold := 0 # per-run spend currency; score stays the up-only metric
var shop_stock: Array = [] # 22 rolled slots {kind, key, sold} (scripts/shop.gd)
var shop_restocks := 0 # total restocks banked so far, either lane — display
	# only; issue 64 replaced the old score-threshold gate that used to drive
	# it with Shop.lane_a_restock (every 5 Waves) / Shop.add_score_progress
	# (every 10,000 Score since the last Lane-A restock)
var shop_lane_b_progress := 0 # issue 64: Score earned toward the next Lane-B
	# restock — MUST be saved (save_config.gd), or a resumed run silently
	# loses progress toward it, same bug class issue 55 shipped once already
var clock_ms := float(Tuning.CLOCK_START_MS)
var stock: Array = []
var captured: Array = []
var actions_left := 0 # unified: move, place, merge, item — 1 action each
var actions_max := 0  # granted this turn (base + artefact/item bonuses)
var early_clear_awarded := false # once per wave (resets when the next queues)
var pending_reinforce := false # shop due at the next player-turn start
## issue 101: a Lane A restock asks the Shop to open itself. Drained at the
## same player-turn-start seam as pending_reinforce above, for the same reason:
## the restock happens mid-wave-transition, where a modal may already be up
## (a Wave clear can raise a Box pick), and _open_shop refuses over one. Held
## as a flag so the open QUEUES rather than being dropped.
var pending_shop_open := false
var pending_yalta_picks := 0 # Yalta Cocktail Napkin picks owed to the player.
	# Exists for ONE reason: backgrounding. Yalta's trigger is the 5-Wave
	# Milestone, which has already fired by the time the modal is up and will
	# not fire again, so rolling the modal back with its own Cancel (forfeit,
	# no refund) would charge a phone call the whole reward. Queued instead,
	# drained at turn start exactly like pending_bounty_boxes below.
var pending_bounty_boxes := 0 # Bounty Piece Buff (issue 48), ally half: how
	# many Box choices are queued. _lose_player_piece is synchronous — called
	# mid enemy-move loop among other sites — so it cannot itself open a modal
	# and wait; it queues here instead. Drained one at a time from
	# _begin_player_turn (a modal is always safe there); any extra copies
	# queued the same Enemy Turn wait for a later Turn rather than chaining.
	# The enemy half (you capture the carrier) never touches this — it opens
	# _open_bounty_pick() immediately, same Turn, since that's already safe.
var selected := Vector2i(-1, -1) # selected board piece
var legal_dests: Array[Vector2i] = []
var legal_paths: Array[Dictionary] = [] # shape-annotated dests (dots/arrows/links)
var moved_this_turn: Array[Vector2i] = [] # pieces (by tile) that already moved
# NO-232 (en passant). Softened from chess's "next move" expiry (ambiguous
# here — actions_per_turn varies) to "next TURN", per Max's ruling: each side
# remembers the double-steps it made LAST turn as {pawn, skip, id} entries.
# player_double_steps is offered to the ENEMY for the immediately following
# ENEMY_TURN, then cleared at the top of the NEXT _begin_player_turn — by
# then that ENEMY_TURN has already ended, so the window has genuinely closed.
# enemy_double_steps mirrors it, cleared at the top of the NEXT _enemy_turn.
# Same "rules.gd stays pure, game.gd computes and passes it in" precedent as
# _enemy_denied_tiles (Winchester Salt Lined Doors) — see its own comment.
var player_double_steps: Array[Dictionary] = []
var enemy_double_steps: Array[Dictionary] = []
var drag_from := Vector2i(-1, -1) # board drag in progress; ghost follows the mouse
var drag_moved := false # the pointer left the origin tile (tap vs aborted drag)
var drag_reselect := false # the pressed piece was already selected (re-click)
# NO-120: long-press-to-describe a board piece. token 0 = none pending,
# mirroring hud.gd's _long_press_input meta idiom (see _board_long_press_start).
var board_lp_token := 0
var board_lp_from := Vector2.ZERO
var board_lp_prev_selected := Vector2i(-1, -1)
var board_lp_fired := false # a hold completed for the tile now in board_lp_pending_tile
# a press classified as a COMMIT (_board_tap_is_readonly false) never calls
# _on_tile_clicked itself — the tile waits here for release to run it, and
# only if board_lp_fired is still false when release arrives (see the
# hazard this guards against in _board_tap_is_readonly's header).
var board_lp_pending_tile := Vector2i(-1, -1)
# NO-145: swipe-to-open a panel, tracked only on a press this ticket's own
# eligibility rule (_swipe_open_may_begin below) accepted — an empty board
# tile only, never a surface with existing drag/tap meaning, so this never
# races drag_from/board_lp_* above. _swipe_from is the press position;
# _swipe_eligible whether THIS press qualified at all.
var _swipe_from := Vector2.ZERO
var _swipe_eligible := false
# Arrow Planning (Notion): purely decorative — never read by rules/AI. A
# scratchpad, not run state: cleared at turn end, never saved (2026-08-27).
var arrow_mode := false # while on, board drags draw arrows instead of selecting
var arrows: Array[Dictionary] = [] # {from: Vector2i, to: Vector2i}
var arrow_from := Vector2i(-1, -1) # arrow drag in progress
var pool_click_key := "" # double-tap detection on pool stacks (piece preview)
var pool_click_ms := 0
var pool_drag_id := "" # stock piece mid-drag from the strip (game-feel pass)
var armed_entry: Variant = "" # the exact Stock entry behind placing_id /
	# pool_drag_id: a bare id String or {id + state} Dictionary (ADR-0002).
	# Only read while one of those is armed, so no reset bookkeeping.
var preview_open := false
var placing_id := ""  # stock piece id being placed, "" = none
var drawer_autoclosed := "" # drawer the current drag closed; reopens on cancel
var merge_highlights := {} # ids that complete a merge with the current selection
var anims: Array = [] # {kind: "move"|"pop", t, ...} rendered by _draw
var _pulse := Node2D.new() # the selection ring: its OWN canvas item, so the
	# per-frame pulse never rebuilds the board's draw list (review pass 2)
var items: Array = [] # held Items (single-use actives), max HUD row
var item_icons := {} # item key -> Texture2D; missing keys fall back to ✦ text
## NO-17: artefact key -> Texture2D. Only the painted ones are in here; read it
## through artefact_tex() rather than directly, so an unpainted artefact gets the
## placeholder instead of nothing. 38 of 180 are painted today.
var artefact_icons := {}
## The stand-in for any catalog art that does not exist yet — artefacts, Boxes,
## anything the Shop can stock. One texture at the same size as the real art, so
## a tile is the same size whether or not its art has landed.
var art_placeholder: Texture2D
var artefacts: Array = [] # run-long passive effects
var box_open := false # box-pick modal showing; blocks all other input
var buff_pick_open := false # generic "choose 1 of N, then continue" modal
	# showing (issue 41) — same input block regardless of which caller opened
	# it; the Buff Box sub-pick was the first caller, never a special case.
var _choice_on_chosen: Callable # continuation for the open choice pick
var _choice_on_cancelled: Callable # ditto, run on cancel (may be invalid)
var box_offer: Array = [] # current Box offer — the stocked slot's pre-rolled
	# `contents` (issue 47), revealed as-is; Nostradamus Mad Libs picks from
	# what's left of it, Reroll replaces it wholesale
var box_picks_left := 0 # extra picks left beyond the first: a Box's own
	# native picks-1 (Huge grants 2, issue 47) plus +1 per held Nostradamus
	# Mad Libs, taken from the same offer (not a fresh roll)
var box_rerolls_left := 0 # Bible Gag Reel Scroll + Snowden's Rubik's Cube:
	# functionally identical 1-reroll-per-copy budget for the current Box —
	# stacks additively, per-Box (reseeded fresh in _open_box_pick)
var box_only_kind := "" # the current Box's theme ("piece"/"artefact"/"item",
	# issue 47 — every Box is typed), pinned for its life so a Reroll re-rolls
	# the same theme
var box_size := "" # the current Box's size ("small"/"big"/"huge"), pinned
	# the same way — a Reroll keeps the same choice/pick shape too
var box_black_book_pending := false # Epstein's Black Book (49): true once
	# this Box's native+Nostradamus entitlement has been offered a free
	# "extra look" (reopened instead of closed) but not yet spent — the
	# artefact is consumed only on the pick actually taken from that look,
	# never on the entitled pick that exhausted the budget. Reset per-Box in
	# _open_box_pick, same lifetime as box_picks_left/box_rerolls_left.
var score_gained_total := 0 # run-long cumulative Score GAINED (issue 49,
	# Loch Ness Stool Sample) — tracks ctx.base off every on_score_change
	# dispatch, so it only ever goes up even though g.score itself can drop
	# (Templar Debit Card pays Shop purchases in Score). "Gained, not
	# current" per the spec: spending must never un-trigger the threshold.
var item_active := -1 # items[] index being targeted, -1 = none
var item_stage_a := Vector2i(-1, -1) # first pick of a "pair" item
var item_targets: Array[Vector2i] = [] # valid target tiles for the active item
var item_selected: Array[Vector2i] = [] # toggled picks of a "multi" item
var item_pending_tile := Vector2i(-1, -1) # NO-121: the tile a SECOND tap on
	# the same tile would confirm — the tap that used to commit a "tile"/
	# "pair"/"area" Item now stages here instead; a different valid tile
	# moves it, the same tile again opens the confirm gate.
var pending_buff := "" # Buff Box: the buff chosen, waiting for its target
var _extract_sel: Array[Vector2i] = [] # multi selection frozen at confirm
var _buff_pick := "" # pending_buff frozen at confirm (_item_reset runs first)
var skip_enemy_turns := 0 # Surprise Attack
var turn_action_count := 0 # moves+placements taken this turn (artefact hook)
var action_log: Array[Dictionary] = [] # ordered {kind} entries this Turn (issue 30);
	# kind is one of "move"/"capture"/"place"/"merge"/"item". Cleared in
	# _begin_player_turn; appended only by _log_action, the choke point every
	# action site's turn_action_count += 1 already funnelled through. The
	# plain move/capture call site (_move_player's tail) additionally stamps
	# {from, to} — Zapruder's Director's Cut's replay data (issue 52); every
	# other call site leaves those keys absent, which _can_repeat_last_action
	# reads as "not repeatable" rather than half-replaying a Deploy/Merge/Item.
	# Issue 56 gave the other 3 kinds their OWN data instead, for Zapruder's
	# resource-return half: "place" stamps {pos} (the deploy tile), "item"
	# stamps {item} (the consumed Item dict), and merge_logic.gd's
	# commit_merge stamps "merge" with {pieces} (both consumed pieces'
	# ADR-0002 Stock-shaped state, snapshotted before the merge discards it
	# for real) — see _zapruder_available/_zapruder_resolve below.

# --- issue 52: Artefact activation. Player-triggered ("on use"/"you may
# pay") Artefacts, costing 0 Actions (user ruling) — gated by each key's own
# once-per-Turn/Wave limit instead (issue 61: "Shop-visit" retired — the Shop
# panel can be closed/reopened at will, so it was never a real boundary).
# Deliberately separate from
# ArtefactHooks' REGISTRY/run() engine (built for "every HELD copy fires
# automatically on a hook") — see game.gd's _activate_artefact block for why.
const ACTIVATABLE_ARTEFACT_KEYS := [
	"oak-island-wishing-well", "fifa-complimentary-yacht", "moscovium-glow-stick",
	"roanoke-hex-kit", "zapruder-s-director-s-cut", "bovine-tractor-beam",
] # Jet Fuel Vial is the 7th — a Shop control, not part of this in-run set
	# (user ruling: "it does not belong in the in-run activation UI")
var oak_island_used_this_turn := false # reset in _begin_player_turn
var moscovium_active := false # "until end of Turn" — reset in _begin_player_turn;
	# read directly by Economy.earn() (economy.gd), NOT the REGISTRY: the
	# effect must keep tripling gains after the artefact consumes itself and
	# leaves g.artefacts, when there is no "held copy" left to dispatch from
var zapruder_used_this_wave := false # reset in WaveLogic.queue()
var bovine_used_this_wave := false # reset in WaveLogic.queue()
var jet_fuel_used_this_wave := false # Jet Fuel Vial (52): once per Wave,
	# reset in WaveLogic.queue() — same idiom as zapruder/bovine above (issue
	# 61: moved off the "Shop visit" boundary, since _open_shop() can't gate
	# reopening the panel and so was never a real limit)
var artefact_targeting_key := "" # Bovine Tractor Beam's staged board pick in
	# progress, "" = none — the one activation with a target (game's own
	# item-targeting flow, generalized: item_active plays this role for Items)
var artefact_target_stage_a := Vector2i(-1, -1) # first pick (an enemy tile)
var artefact_targets: Array[Vector2i] = [] # valid tiles for the current stage
var artefact_pending_tile := Vector2i(-1, -1) # NO-121: mirrors item_pending_tile
	# for Bovine Tractor Beam's own stage-B tap

# --- issue 67: the Army Ability — 1/Wave, 1 Action, same confirm-vs-
# targeting back-out shape as an Artefact activation above, but its own state
# (there is exactly one Ability per run, so no "key" is needed the way
# ACTIVATABLE_ARTEFACT_KEYS needs one per held Artefact). `army_ability_
# used_this_wave` is persisted (additive save field, save_config.gd) — the
# once-per-Wave idiom's own "assert the restored value" requirement (a
# missing field the generic identity check can't catch).
var army_ability_used_this_wave := false # reset in WaveLogic.queue()
var army_targeting := false # The Muster's Call the Banners: tap a Stock
	# stack to target it — the only Army Ability with a target, so a bare
	# bool (not a key string like artefact_targeting_key) is enough
var army_board_targeting := false # issue 68: Hostile Takeover (Syndicate)/
	# Ritual (Cult) — a target on the BOARD, not in a drawer, so these reuse
	# Bovine Tractor Beam's own targeting FLOW instead of army_targeting's
	# Stock-tap one; a bare bool is still enough (still exactly one Army
	# Ability per run, so no per-key string is needed)
var army_board_targets: Array[Vector2i] = [] # valid tiles for the current
	# board-targeted Army Ability (Hostile Takeover: affordable enemies,
	# King excluded; Ritual: any of your own pieces)
var hounds_free_turn := false # Wild Hunt's Loose the Hounds: "this Turn"
	# only, so it resets in _begin_player_turn, NOT WaveLogic.queue() — a
	# per-turn scratch flag needs no save round-trip (SaveConfig.apply's own
	# header: "a save is always taken at a turn start")

var king_abilities_active: Array = [] # action + persistent tariffs, run-long
var king_abilities_suppressed := false # Counter-Intel: off for the rest of the wave
var king_abilities_seen: Array = [] # every activation, for the end screens
var rng := RandomNumberGenerator.new()

## NO-109: per-tariff Gold charged this run, keyed by tariff key. Diagnostic
## only — a gold total cannot attribute a charge, which is why a balance
## question about tariffs could not be answered at all. Not saved.
var tariff_charges := {}

var autoplay := false
var autoplay_exit := false # quit-on-game-over: CLI --autoplay runs only, so the
                           # in-process scenario sweep (test_scenarios) survives
var autoplay_turns := 0
var autoplay_cap := 2000 # --steps N overrides, for short scenario sweeps

## issue 103: per-run leverage counters. "Is the bot using everything available
## to it?" is not answerable by reading the code — it has to be counted, and
## a leverage the bot never touches shows up here as a flat zero.
##
## Deliberately ONE Dictionary rather than a var per counter: the alternative
## is a dozen fields threaded through save/load for numbers that are pure
## measurement and must never affect play. Nothing reads this back — it is
## written, printed at run end, and dropped.
var telemetry: Dictionary = {}


func tally(key: String, n: int = 1) -> void:
	telemetry[key] = telemetry.get(key, 0) + n
var screenshot_dir := "" # debug: save PNGs for agent visual verification

# HUD nodes
var hud := HudScript.new()
# HUD state forwarded read-only for the click probes and saves
# (the widgets themselves live in scripts/hud.gd)
var drawer_open: String:
	get: return hud.drawer_open
## NO-84: every stack button across both Stock Drawer grids, Stock first then
## Captured — kept for probes and code that used to sweep the one-strip pool.
var pool_box: Array:
	get: return hud.pool_buttons()
var pass_button: Button:
	get: return hud.pass_button
var game_menu: PanelContainer:
	get: return hud.game_menu
var drawer_buttons: Dictionary:
	get: return hud.drawer_buttons
var stock_armed: Control:
	get: return hud.stock_armed
var modals := preload("res://scripts/modals.gd").new()
# modal panels forwarded read-only for the click probes (scripts/modals.gd)
var box_panel: PanelContainer:
	get: return modals.box_panel
var overlay: PanelContainer:
	get: return modals.overlay
var preview_panel: PanelContainer:
	get: return modals.preview_panel
var reinforce_panel: PanelContainer:
	get: return modals.reinforce_panel
var king_ability_panel: PanelContainer:
	get: return modals.king_ability_panel
var pending_merge: Array = [] # the two sources awaiting confirmation
var game_menu_open := false
var animations_on := true # Settings toggle (06); false short-circuits the
	# `anims` queue via the same seam autoplay already uses — see _add_*
var backgrounded := false # OS focus lost (app switch/call/notification, 06):
	# same pause state as the in-game menu — see _process and _enemy_turn


func _ready() -> void:
	# CLI bypasses (--autoplay/--scenario) and the click probes boot Game.tscn
	# straight, skipping the Menu's own apply() — so this scene applies too.
	var settings_data := Settings.load_settings()
	Settings.apply(settings_data)
	animations_on = settings_data.get("animations_on", true)
	set_board_theme(settings_data.get("board_theme", DEFAULT_BOARD_THEME))
	var args := OS.get_cmdline_user_args()
	var first_boot := not cli_bypass_used # NO-77: the launch bypass fires once
	cli_bypass_used = true
	autoplay = first_boot and args.has("--autoplay")
	autoplay_exit = autoplay
	# issue 74: no pixel filter here or anywhere — a full-screen quantising
	# post-effect would quantise everything composited below it, art included.
	# The hard-edged text that shipped in its place was removed 2026-09-06 at
	# the user's ask; the CRT overlay (scripts/crt_overlay.gd) is the one
	# look-changer, and it only shades/warps the finished frame.
	if args.has("--screenshot"): # fired once the scenario (if any) is booted, below
		screenshot_dir = args[args.find("--screenshot") + 1]
	if args.has("--clock"): # debug: short clock to reach the end screen fast
		clock_ms = float(args[args.find("--clock") + 1]) * 1000.0
	if args.has("--steps"): # debug: shorter autoplay cap for scenario sweeps
		autoplay_cap = int(args[args.find("--steps") + 1])
	if args.has("--army"): # balance fleets: run the bot with a specific army
		next_army = args[args.find("--army") + 1]
	if args.has("--tier"): # balance fleets: run the bot at a specific difficulty tier
		next_tier = args[args.find("--tier") + 1]
	if args.has("--seed"): # issue 75: reproduce a run exactly
		next_seed = args[args.find("--seed") + 1]
	_layout_board()
	# NO-57: the platform can settle the notch/cutout inset a frame or two
	# after boot, or change it outright (rotation, split-screen) — recompute
	# on the root viewport's own size_changed rather than trusting the boot
	# read forever. This is the viewport's signal, not a Control's `resized`:
	# binding to a rebuilt Control's own resize is the feedback loop the
	# stock strip already got burned by (CLAUDE.md, layout traps).
	get_viewport().size_changed.connect(_layout_board)
	add_child(_pulse)
	_pulse.draw.connect(_draw_pulse)
	var outline_shader := Shader.new()
	outline_shader.code = SELECT_OUTLINE_SHADER
	var outline_mat := ShaderMaterial.new()
	outline_mat.shader = outline_shader
	_pulse.material = outline_mat
	defs = Rules.load_pieces()
	fusions = Rules.load_fusions()
	for id in defs:
		# Painted art is side-specific: <id>-light.png is the player token,
		# <id>-dark.png the enemy one, so no side tint is applied to them.
		# A lone <id>.svg is the old generated vector set — one monochrome
		# token for both sides, still tinted blue/red at draw time (king,
		# until its art arrives).
		var light := "res://assets/pieces/%s-light.png" % id
		var dark := "res://assets/pieces/%s-dark.png" % id
		if ResourceLoader.exists(light) and ResourceLoader.exists(dark):
			textures[id] = {Rules.PLAYER: load(light), Rules.ENEMY: load(dark)}
			continue
		var mono := "res://assets/pieces/%s.svg" % id
		if ResourceLoader.exists(mono):
			var t: Texture2D = load(mono)
			textures[id] = {Rules.PLAYER: t, Rules.ENEMY: t}
			mono_art[id] = true
	for it in Items.ITEMS: # item glyphs (icon set picked 2026-07-17)
		var path := "res://assets/items/%s.svg" % it.key
		if ResourceLoader.exists(path):
			item_icons[it.key] = load(path)
	# NO-17: painted artefact art, same guarded shape as the items above — the
	# catalog is 180 entries and 38 are painted, so the miss is the normal case
	# here rather than the exception.
	for a in Items.ARTEFACT_CATALOG:
		var art := "res://assets/artefacts/%s.png" % str(a.get("key", ""))
		if ResourceLoader.exists(art):
			artefact_icons[a.key] = load(art)
	var ph := "res://assets/ui/art_placeholder.svg"
	if ResourceLoader.exists(ph):
		art_placeholder = load(ph)
	# GDD Game Flow — Run: one seed per run, captured so a save resumes the same
	# stream. SaveConfig.apply below overrides both when restoring a save, and a
	# scenario may pin "seed" to replay a bug exactly.
	# issue 75: a seed makes the whole run reproducible. Nothing in the game
	# rolls outside this generator (no bare randi/randf anywhere) and rules.gd's
	# AI is pure, so an identical seed + identical setup replays move for move.
	# Any string is accepted — hashed, so "crazy seeds" can be words.
	if next_seed != "":
		rng.seed = seed_of(next_seed)
	else:
		rng.randomize()
	add_child(hud)
	hud.build(self)
	_connect_hud()
	add_child(modals)
	modals.build(self)
	_connect_modals()
	if first_boot and args.has("--scenario"): # headless/CLI scenario boot, by index
		next_config = Scenarios.all()[int(args[args.find("--scenario") + 1])].cfg
		is_scenario = true
	if next_config.is_empty():
		# issue 89: roll the King line-up here, from the run RNG (seeded just
		# above), so the same seed always meets the same four Kings in the same
		# order — the reproducibility guarantee issue 75 shipped.
		var line_up := Kings.roll_run(rng)
		king_tier = line_up.tier
		king_order = line_up.order
		# NO-213: Stock-halving lever removed from the tier ladder — always
		# the full army.
		stock = Tuning.ARMIES[next_army].duplicate()
		clock_ms = float(Tuning.clock_start_ms(next_tier)) # issue 78: 15 min,
			# or 5 at Tier 3+. Set HERE, not at the var declaration — next_tier
			# is only meaningful once the run actually starts.
		# issue 67: the other 3 determinants of a Army's kit (Stock, above,
		# was already per-army). Starting Artefacts stays empty for all three
		# seed Armies — none of them specify one.
		var kit := Armies.entry(next_army)
		gold = int(kit.starting_gold)
		for key in kit.starting_items:
			for it in Items.ITEMS:
				if it.key == key:
					items.append(it)
		var starting_artefact_count: int = kit.get("starting_artefact_count", 0)
		if starting_artefact_count > 0: # issue 68: The Cult's 2 random
			# Artefacts — weighted the same way every other "n random
			# Artefacts" grant in this codebase already is
			# (Shop._sample_weighted_artefacts, shared with the Shop's own
			# 4-slot roll and Sub-Antarctic Visa's hidden slot). No cap check
			# needed: ARTEFACT_CAP_BASE is 5 and this is a fresh run with none
			# held yet, so 2 always fits.
			for key in Shop._sample_weighted_artefacts(Items.ARTEFACT_EFFECTS, starting_artefact_count, self):
				for t in Items.ARTEFACT_EFFECTS:
					if t.key == key:
						var inst: Dictionary = t.duplicate() # per-copy stamps,
							# same shape as the --artefacts debug loop below
						inst.acquired_wave = wave
						inst.rarity = ArtefactHooks.rarity_of(key)
						artefacts.append(inst)
						break
		_set_drawer("stock") # SETUP starts in the placement flow
	else:
		SaveConfig.apply(self, next_config)
	# NO-128/NO-154 (coordinator review 2026-09-19, extended 2026-09-21): every
	# boot places pieces on the player's own back rows — exactly the rows
	# army_band overlays while open, whether from SETUP's placement flow, a
	# scenario's `board` config, or a restored save (data/scenarios.gd,
	# save_config.gd). army_band_open has no saved counterpart (grep of
	# save_config.gd: none), no boot-time reader depends on it starting open
	# (only army_band_reopen's press handler and set_drawer()'s Inventory
	# exclusion ever write it, both user-driven), so there is no boot state
	# that legitimately wants it open. Transparency (hud.gd) already lets a
	# tap reach the board underneath either way, but the player still can't
	# SEE a piece or tile the band is painted over. Unconditional: the wedge
	# still reopens it on request, same as it does for Inventory; this isn't
	# a lock, just the default every boot path should have started with.
	hud.collapse_army_band()
	if args.has("--artefacts"): # balance sweep (issue 20): force a starting
		for key in args[args.find("--artefacts") + 1].split(","): # loadout, comma-separated keys, on top of whatever the boot path above granted
			for t in Items.ARTEFACT_EFFECTS:
				if t.key == key:
					var inst: Dictionary = t.duplicate() # per-copy acquisition
						# wave stamp (artefact_hooks.gd's "5-Wave Milestone") and
						# rarity stamp (issue 29 — Illuminati Fridge Magnet)
					inst.acquired_wave = wave
					inst.rarity = ArtefactHooks.rarity_of(key)
					artefacts.append(inst)
	if shop_stock.is_empty(): # fresh run, or a save from before the shop
		Shop.roll(self)
	if args.has("--scenario-check"): # boots, runs one frame, exits — CI probe
		await get_tree().process_frame
		await get_tree().process_frame
		print("SCENARIO OK")
		get_tree().quit()
	_refresh()
	if screenshot_dir != "" and not autoplay: # with --autoplay, the end screen is captured instead
		if is_scenario and (args.has("--select") or args.has("--arm-item")
				or args.has("--open-shop") or args.has("--open-drawer")
				or args.has("--show-screen")):
			_debug_state_screenshot(screenshot_dir, args) # NO-122: arm a preview, then shoot
		else:
			_screenshot_and_quit(screenshot_dir)


## The two bands the board sits between. The top one is the HEADER (NO-82/83):
## the platform's notch inset plus HudScript.HEADER_H, solved in _layout_board
## into `hud_top`. Every Header spacing constant lives in hud.gd's HEADER
## TUNING block; this file only adds the inset on top.
var safe_top := 0.0 ## the notch inset in canvas px (0 on desktop and un-notched phones)
var hud_top := 0.0 ## safe_top + HEADER_H: where the board starts

## NO-33 / ADR-0004. HUD_DECK used to be a flat 268.0 reservation, and the stock
## strip was the element that absorbed whatever the board left over. That makes a
## dead band inevitable rather than impossible: the strip spends absorbed height
## in whole icon rows, so any remainder smaller than a row is empty by
## construction — and a WIDER strip fits more icons per row, needs fewer rows,
## and wastes more. NO-25 measured ~100px of it on a 3:4 tablet.
##
## Now the BOARD absorbs, and the deck is the sum of the rows it is built from.
## Measured once (probe, 2026-09-08) and pinned here; test_game_clicks asserts
## the built deck still agrees and fails the moment a row is added or a font
## moves under one. It is a sum rather than a measurement on purpose: measuring
## needs a second layout pass, and a control that measures itself before layout
## caches nonsense (CLAUDE.md, layout traps).
## NO-83 retired the stock strip and the status line, so the sum was three
## rows (drawers, power, act).
## NO-128 (UNVERIFIED — no Godot run; see the PR; coordinator review
## 2026-09-19 rejected an earlier version of this change that grew DECK_ROWS
## to budget the Power/Ability/King-Abilities band's worst case, because a
## permanent board-size cost paid at every boot for a collapsible row is
## backwards — collapsing would have freed nothing, since the board is sized
## once here and never revisited). The band (army_band, hud.gd) is no longer
## a deck row at all: it overlays the board above the deck instead, exactly
## like the Inventory drawer, sized by its own flat ARMY_BAND_H constant
## (hud.gd) rather than by DECK_ROWS. So the sum drops back to two rows —
## drawers and act — and DECK_ROWS actually SHRINKS versus the pre-NO-128
## value of 132, because the always-reserved power row is gone too.
## NO-163: the 6px gap between those two rows (hud.gd's `deck` separation) is
## closed, so the sum drops again, 98 -> 92.
## NO-181: that gap reopens, at HudScript.DECK_GAP (5) — the same constant
## nav_row/act_row use for their own button gaps, so this sum can't drift
## from what hud.gd actually builds (test_game_clicks.gd's NO-33 guard
## computes the live deck's height and checks it against this constant).
const DECK_ROWS := 32.0 + HudScript.DECK_GAP + 60.0 ## drawers 32 + DECK_GAP (hud.gd) + act 60
## NO-196: used to split as "6 between board and deck, 6 under the deck" — but
## the deck is now bottom-anchored at a FIXED height (hud.gd's build()), flush
## to the screen edge with nothing padding it below, so there is no longer a
## separate "under the deck" margin to spend. Both 6's now land in the one
## gap between the board and the deck; the sum (and the tile solve below) is
## unchanged, only where it's spent moved.
const DECK_MARGINS := 12.0
## ICON sits this far under the board tile, so the deck always reads as smaller
## than the board. Design C picked 52 against a 59px tile; this is that gap, kept
## as the relationship rather than the pair of numbers it produced on one screen.
const ICON_GAP := 7
## NO-116: the board sat flush under the Header, so the whose-turn outline
## (drawn 4px OUTSET from the board, 3px wide) had its top edge land under the
## Header and get clipped. Just enough top margin for the outset + half the
## stroke width (4 + 1.5) to clear it — not a return to centring (2026-09-05).
const BOARD_TOP_MARGIN := 6.0
## NO-197: the whose-turn outline (_draw, below) sits this far OUTSIDE the tile
## grid, stroked BOARD_OUTLINE_WIDTH wide and CENTRED on that inset edge — so its
## outer ink reaches INSET + WIDTH/2 past the grid (4 + 1.5 = 5.5). Named so
## test_game_clicks.gd's overlap guard can derive that 5.5 instead of repeating
## it as a bare literal (CLAUDE.md: "two constants that happen to agree") —
## hud.gd's old deck_top offset was a bare 6.0, half a px past this ink, which
## read as overlap once anti-aliased. hud.gd no longer needs these two directly:
## the deck is bottom-anchored at a fixed height now (NO-196), which leaves
## DECK_MARGINS (12, below) — comfortably more than this 5.5 — as the board/deck
## clearance regardless of tile size; see hud.gd's build() for the inequality.
const BOARD_OUTLINE_INSET := 4.0
const BOARD_OUTLINE_WIDTH := 3.0


## The one-way, closed-form solve (ADR-0004, amended by NO-83). With the strip
## gone the deck no longer depends on ICON, so the solve is one division:
##
##   vp.y = top + BOARD_H*tile + DECK_MARGINS + DECK_ROWS
##
## `top` is the Header's full height including the notch inset, so a notched
## phone gets a slightly smaller tile — the board stays the slack absorber.
static func board_tile_for(vp: Vector2, top: float = HudScript.HEADER_H) -> int:
	return int(minf((vp.x - 8.0) / Tuning.BOARD_W,
		(vp.y - top - DECK_MARGINS - DECK_ROWS) / Tuning.BOARD_H))


## The notch inset in CANVAS px. The platform reports it in screen px; the
## viewport is 480 canvas px wide whatever the screen (project.godot: stretch
## canvas_items/expand), so the ratio of the two widths converts it. Measured
## on an iPhone 11 (NO-82): 48pt at the top -> 56 canvas px.
##
## `--safe-top N` (a user arg, after `--`) overrides it for desktop runs, so
## the notch layout can be probed and screenshotted without a phone. Desktop
## otherwise reports 0: DisplayServer.get_display_safe_area() would return the
## macOS menu bar as an inset there, which is not a notch.
static func safe_top_px(vp: Vector2) -> float:
	var args := OS.get_cmdline_user_args()
	if args.has("--safe-top"):
		return float(args[args.find("--safe-top") + 1])
	if not OS.has_feature("mobile"):
		return 0.0
	var win: Vector2i = DisplayServer.window_get_size()
	if win.x <= 0:
		return 0.0
	return roundf(DisplayServer.get_display_safe_area().position.y * vp.x / win.x)


## Art for an artefact, or the placeholder when it has none. Never returns null,
## which is the point: every artefact draws at the same size whether or not it is
## painted, so the Shop and the drawers do not reflow as art lands.
func artefact_tex(key: String) -> Texture2D:
	return artefact_icons.get(key, art_placeholder)


## NO-119: initials for a badge shown over placeholder art (Artefacts,
## Boxes), so two otherwise-identical unpainted icons read apart without a
## long-press. First letter of each of the first two words, uppercased
## ("Tinfoil Hat" -> "TH"); a single-word name (only "Apocrypha" today)
## gives its first two letters instead, so the badge is always two chars.
func initials_of(display_name: String) -> String:
	var words := display_name.split(" ", false)
	if words.size() >= 2:
		return (words[0][0] + words[1][0]).to_upper()
	return display_name.substr(0, 2).to_upper()


func _layout_board() -> void:
	var vp := get_viewport_rect().size
	safe_top = safe_top_px(vp)
	hud_top = safe_top + HudScript.HEADER_H
	var top := hud_top + BOARD_TOP_MARGIN
	tile = board_tile_for(vp, top)
	# PULLED UP under the top strip rather than centred in the span (user ruling,
	# 2026-09-05). Centring split the leftover height into a gap above AND below
	# the board, and on a 9:20 phone that was ~130px of nothing in two places.
	# Flush to the top puts every spare pixel in ONE place, under the board —
	# between the board and the deck (NO-196: the deck itself is a fixed
	# height now, hud.gd's build(), so it no longer absorbs any of this).
	board_px = Vector2(roundf((vp.x - tile * Tuning.BOARD_W) / 2.0), top)
	queue_redraw()




func _pool() -> Array:
	return stock + captured


## The tiles _draw circles as deploy targets — its ONLY source for those dots,
## so a probe can assert the highlight the player actually sees rather than the
## flag behind it. Empty unless a STOCK entry is armed or mid-drag: Captured
## Stock neither arms nor drags (2026-09-10), which is why dragging a captured
## piece no longer lights up a board it can never be placed on.
func _deploy_highlight_tiles() -> Array:
	if placing_id == "" and pool_drag_id == "":
		return []
	return _setup_open_tiles() if state == State.SETUP else _deploy_tiles()




func _clock_text() -> String:
	# NO-114: no icon, and milliseconds rather than tenths.
	return "%02d:%02d.%03d" % [int(clock_ms / 60000), int(clock_ms / 1000) % 60, int(clock_ms) % 1000]












func _clear_selection() -> void:
	selected = Vector2i(-1, -1)
	legal_dests.clear()
	legal_paths.clear()
	queue_redraw()
	_pulse.queue_redraw()


func _on_stack_pressed(entry: Variant, cap: bool, count: int) -> void:
	if pool_drag_id != "":
		# mid-drag: hiding the drawer (drag-out close) force-releases the held
		# button, which fires a spurious tap inside the visibility cascade and
		# corrupts the strip rebuild (found 2026-07-08). Real taps clear the
		# drag in _input before this signal arrives.
		return
	if army_targeting: # Call the Banners: this tap IS the target (issue 67)
		return _army_target_stock(entry, cap)
	var id: String = entry if entry is String else entry.id
	if state == State.GAME_OVER or state == State.ENEMY_TURN or box_open or buff_pick_open \
			or preview_open or game_menu_open or win_open:
		return
	# double-tap on the same stack: piece info (NO-144: Sell, for a Stock
	# entry, is in there too — never for a Captured one, entry stays null)
	var key := id + ("!" if cap else "")
	var now := Time.get_ticks_msec()
	if key == pool_click_key and now - pool_click_ms < 400:
		pool_click_key = ""
		return _show_preview(id, "", entry if not cap else null, # NO-185: buffs
			entry if entry is Dictionary else {})
	pool_click_key = key
	pool_click_ms = now
	# CAPTURED STOCK ARMS NOTHING (user ruling 2026-09-10). Its only two exits
	# are Convert (the badge that now sits on every captured entry) and Sell
	# (from Stock, after converting — NO-144 moved this off the Shop and onto
	# the preview modal above) — issue 60 had already taken its deploy, and
	# this slice takes its merge, which leaves the armed state with nothing
	# left to do.
	# Bailing here is also what stops the board painting deploy targets for a
	# piece that cannot be deployed: those dots come from placing_id /
	# pool_drag_id (see _deploy_highlight_tiles), and neither can ever hold a
	# captured entry now.
	if cap:
		return
	# tapping a partner of the current selection completes the merge; a
	# same-stack pair goes through drag instead (tap-again means deselect)
	var same_stack: bool = placing_id != "" and armed_entry == entry
	if not same_stack and merge_highlights.has(id):
		var unit := {"id": id, "entry": entry}
		if placing_id != "":
			return MergeLogic.do_merge(self,
				{"id": placing_id, "entry": armed_entry}, unit)
		if selected.x >= 0:
			return MergeLogic.do_merge(self, selected, unit)
	# select / deselect the stack: arms merging and Stock placement
	if same_stack:
		placing_id = ""
	else:
		if not (state == State.SETUP or actions_left > 0):
			return
		placing_id = id
		armed_entry = entry
	_clear_selection()
	_refresh()








## Arrow Planning: a button toggle, guarded like the other HUD actions that
## must not fire mid-modal or mid-item-target (item targeting owns board taps).
func _on_arrow_toggle() -> void:
	if state == State.GAME_OVER or state == State.ENEMY_TURN or box_open or buff_pick_open \
			or preview_open or game_menu_open or win_open or item_active >= 0:
		return
	arrow_mode = not arrow_mode
	arrow_from = Vector2i(-1, -1)
	if arrow_mode: # entering the mode drops any selection/armed placement —
		placing_id = ""    # the board stops selecting pieces while it's on
		_clear_selection()
	_refresh()


func _on_arrow_clear() -> void:
	arrows.clear()
	queue_redraw()


func _on_pass() -> void:
	if box_open or buff_pick_open or game_menu_open or win_open:
		return
	if _pass_blocked():
		return
	arrows.clear() # scratchpad: never survives past the turn it was drawn in
	queue_redraw()
	if state == State.SETUP:
		if hud.drawer_open != "": # setup done: full board for the run
			_set_drawer("")
		WaveLogic.spawn(self, 1)
		_begin_player_turn()
	elif state == State.PLAYER_TURN:
		fx_at = Vector2(hud.pass_button.get_global_rect().get_center())
		Economy.charge(self, "pass_cost")
		for pos in board: # same boundary rule, player side
			if board[pos].owner == Rules.PLAYER:
				BuffLogic.tick_side(board[pos])
		if not early_clear_awarded and _board_cleared():
			# wave beaten with turns to spare: score + clock scale with the lead
			early_clear_awarded = true
			var early := maxi(_cadence() - turns_since_wave, 0)
			if early > 0:
				Economy.earn(self, early * Tuning.EARLY_CLEAR_SCORE_PER_TURN, "early_clear")
				Economy.add_clock(self, early * Tuning.EARLY_CLEAR_CLOCK_MS_PER_TURN, "early_clear")
				_add_turn_fx("CLEARED EARLY  +%d ★ · +%ds" % [
					early * Tuning.EARLY_CLEAR_SCORE_PER_TURN,
					early * Tuning.EARLY_CLEAR_CLOCK_MS_PER_TURN / 1000],
					Color(0.95, 0.8, 0.25))
		Economy.add_clock(self, Tuning.TURN_END_CLOCK_BONUS_MS, "turn_end") # finishing a turn buys time
		ArtefactHooks.run(self, "on_turn_end") # Shrinkflation Cereal Box (18)
		_enemy_turn()


## Hellfire Club Discord Invite (issue 54): "you cannot Pass while Actions
## remain" — gated on _has_legal_action() so a fully boxed-in board can never
## be stuck with Actions left and nothing to spend them on (the softlock the
## issue called out explicitly). hud.gd's refresh() reads this too, to grey
## the Pass button out and say why instead of a silent failed click.
func _pass_blocked() -> bool:
	return state == State.PLAYER_TURN and actions_left > 0 \
		and _held("hellfire-club-discord-invite") and _has_legal_action()


## Any legal move/capture, Deploy, or Item use left this Turn? The one
## question _pass_blocked() above must get right, or Hellfire Club Discord
## Invite can lock a Turn with no way to end it.
func _has_legal_action() -> bool:
	# Rules.legal_moves knows nothing about moved_this_turn — that "one move
	# per piece per Turn" lock is enforced only at the click-select gate
	# (elsewhere in this file), so a piece that already moved doesn't count
	# here even though the engine calls its move geometrically legal. Same
	# filter autoplay.gd's own step() already applies for the same reason.
	for m in Rules.legal_moves(board, Rules.PLAYER, defs, true, [], enemy_double_steps):
		if not moved_this_turn.has(m.from):
			return true
	if not stock.is_empty() and not _deploy_tiles().is_empty():
		return true
	return _has_usable_item()


## Held Items with at least one valid use right now. `target == ""` items
## (Counter-Intel, Surprise Attack) fire immediately, always usable while
## held. "pair" items (Tactical Reposition, Rapid Deployment, Decoy Swap)
## need a real 2nd-stage check — a non-empty stage A doesn't guarantee any of
## its picks has a valid stage B — everything else (tile/area/multi) only
## ever needs one valid anchor to complete (the rest is a confirm button, not
## a second dependent pick), same as _use_item's own staging.
func _has_usable_item() -> bool:
	for it in items:
		if it.target == "":
			return true
		var stage_a := _item_stage_targets(it, Vector2i(-1, -1))
		if stage_a.is_empty():
			continue
		if it.target != "pair":
			return true
		for a in stage_a:
			if not _item_stage_targets(it, a).is_empty():
				return true
	return false


func _process(delta: float) -> void:
	if (selected.x >= 0 or placing_id != "") and not autoplay:
		_pulse.queue_redraw() # only the ring redraws every frame, not the board
		hud.stock_armed.queue_redraw()
	if autoplay and state == State.SETUP:
		# place the whole starting stock on random zone tiles, then begin
		var open := _setup_open_tiles()
		if stock.is_empty() or open.is_empty():
			_on_pass()
		else:
			_place(stock[rng.randi() % stock.size()], open[rng.randi() % open.size()])
		return
	if state == State.PLAYER_TURN:
		# Tier 1 (baseline) pauses the Clock for menu/win-screen/Shop/the Stock
		# and Inventory drawers/the piece preview; Tier 2+ keeps it running
		# through all of those, so browsing costs real time (07-difficulty-ranks).
		# Box Pick and the Buff Box sub-pick are deliberately absent from this
		# list at every tier — GDD Box Pick: "decisive picks rewarded,
		# indecision punished". OS-backgrounded pause (slice 06) always wins;
		# it is not a difficulty lever.
		var tier_pauses := not Tuning.clock_never_pauses(next_tier) \
				and (game_menu_open or shop_open() or drawer_open != "" or preview_open
				or modals.pause_modal_open())
		# `win_open` is NOT on that tier-gated list, and must not be: the victory
		# screen is not a pause. The run is already won at wave 50 and there is
		# nothing left to be decisive about, so the difficulty lever has nothing
		# to bite on. While it was gated, the clock kept draining at Tier 2+ while
		# the player read their win — and "Clock out" then called show_overlay(),
		# whose first act is to free the win screen's children. A wave-50 victory
		# turned into GAME OVER mid-read, with no explanation. A won run cannot be
		# lost to the clock.
		if not (tier_pauses or win_open) and not backgrounded:
			# issue 35: deliberately NOT routed through Economy.add_clock/
			# on_clock_change — this is a continuous per-frame DRAIN, not a
			# discrete gain, and hooking it would fire on_clock_change every
			# single frame. Direct mutation stays, on purpose; don't "finish
			# the job" by wiring this one up too.
			# Kings.clock_drain_mult is 1.0 for everyone but Larry, whose
			# Borrowed Time doubles it for his wave (NO-7). A multiplier on the
			# RATE, deliberately not a second clock source — see that function.
			clock_ms -= delta * 1000.0 * Kings.clock_drain_mult(self)
		# Doomsday Clock Snooze Button (issue 26): the THRESHOLD CROSS is
		# watched here every frame (no discrete hook fires on one), but the
		# actual grant below is a one-time-per-wave GAIN, guarded by
		# doomsday_snooze_used_this_wave — routed through Economy.add_clock
		# (issue 35) same as any other gain, unlike the drain right above.
		if clock_ms < 30000.0 and clock_ms > 0.0 and not doomsday_snooze_used_this_wave \
				and _held("doomsday-clock-snooze-button"):
			Economy.add_clock(self, 25000.0, "doomsday_snooze")
			doomsday_snooze_used_this_wave = true
		if clock_ms <= 0:
			clock_ms = 0
			return _game_over(false, "Clock out")
		hud.update_clock(clock_ms) # NO-127: routes through hud.gd's shared seam
		if autoplay:
			AutoplayBot.step(self)
	if not anims.is_empty():
		for a in anims:
			a.t += delta / a.get("dur", ANIM_TIME)
		anims = anims.filter(func(a: Dictionary) -> bool: return a.t < 1.0)
		queue_redraw()


# --- turn flow ---

## The wave/turn banner's on-screen rect at animation time `t`, for stack `slot`.
##
## Extracted from _draw so the geometry is testable, and CLAMPED to the board
## (NO-26). It used to be drawn at `board_px.x - (1 - slide) * board_width` with
## a full board width, i.e. entering from OUTSIDE the board with nothing
## clipping it. On a phone the board is nearly the full screen width, so the
## overflow ran off-screen and read as a slide; on a tablet the board is
## centred with wide margins, so the same draw visibly started at the LEFT
## SCREEN EDGE and stopped short of the board's right edge, with its text
## off-centre. The banner was never mis-SIZED -- bw has always been the board
## width and the settled position has always been correct. What was missing was
## any bound keeping the entrance inside the board.
##
## It now emerges from the board's own left edge: the right edge sweeps across
## while the left stays pinned, so nothing is ever drawn outside the board. The
## settled state (slide == 1) is byte-identical to before.
func _banner_rect(t: float, slot: int) -> Rect2:
	var bw: float = Tuning.BOARD_W * tile
	var by: float = board_px.y + tile * 3.0 + slot * 52.0
	var slide: float = ease(minf(t * 4.0, 1.0), 0.3)
	var right: float = board_px.x + slide * bw
	return Rect2(Vector2(board_px.x, by), Vector2(maxf(0.0, right - board_px.x), 44))


## Turn/wave transition feedback: board-outline glow + a wiping banner
## (game-feel pass 2026-07-06). Stacked banners offset so they never overlap.
func _add_turn_fx(text: String, color: Color) -> void:
	if autoplay or not animations_on:
		return
	var slot := 0
	for a in anims:
		if a.kind == "banner":
			slot += 1
	anims.append({"kind": "outline", "t": 0.0, "dur": 0.6, "color": color})
	anims.append({"kind": "banner", "t": 0.0, "dur": 1.1, "text": text,
		"color": color, "slot": slot})
	queue_redraw()


func _begin_player_turn() -> void:
	if state == State.ENEMY_TURN: # skip on the SETUP->first-turn transition
		_add_turn_fx("YOUR TURN", Color(0.45, 0.7, 1.0))
	turn_number += 1 # issue 35: the single increment site — save_config.gd's
		# apply() overrides the result AFTER this call (same pattern as
		# skip_enemy_turns there), since a resumed save must not double-count
		# the Turn it was saved on
	_clear_selection() # a setup selection must not survive START
	state = State.PLAYER_TURN
	actions_left = Tuning.actions_per_turn(next_tier) # Tier 4+: -1 (NO-213)
	moved_this_turn.clear()
	player_double_steps.clear() # NO-232: this turn's en passant window closed
		# with the enemy turn that just ended — starts empty again for
		# whatever the player does this turn (see the field's own comment)
	for pos in board: # Blitz's free move is scoped "this Turn" — never carries
		board[pos].erase("blitz_free_move") # over. Cleared BEFORE on_turn_start
		# dispatches (issue 54) so Pegasus Free Trial's own on_turn_start grant,
		# right below, isn't wiped out by this same-turn cleanup running after it.
	ArtefactHooks.run(self, "on_turn_start")
	actions_max = actions_left
	turn_action_count = 0
	action_log = []
	turn_capture_count = 0
	oak_island_used_this_turn = false # Oak Island Wishing Well (52): once per Turn
	moscovium_active = false # Moscovium Glow Stick (52): "until end of Turn"
	hounds_free_turn = false # Loose the Hounds (67): "this Turn" only
	for pos in board: # timed buffs (Slow/Aura/Smog) age one player turn
		BuffLogic.tick(board[pos])
	# board cleared early -> skip the cadence wait, next wave arrives now
	if _board_cleared():
		WaveLogic.queue(self, wave + 1)
	WaveLogic.spawn_pending(self)
	# Nothing on the board, nothing in Stock, and nothing captured to convert
	# INTO Stock. The third clause used to be "and Captured Stock holds no
	# legal merge"; captured pieces cannot merge since 2026-09-10, so the
	# escape hatch is conversion instead, and ANY captured piece is one. Like
	# the merge test it replaces, it ignores Gold (a merge cost Gold too), so
	# it stays exactly as forgiving as it was and never ends a run early.
	if _player_pieces().is_empty() and stock.is_empty() and captured.is_empty():
		return _game_over(false, "Resource starvation")
	_autosave() # at every turn start
	_refresh()
	if pending_reinforce: # saved BEFORE consuming: a resumed run reopens it
		if autoplay:
			pending_reinforce = false
			AutoplayBot.reinforce(self)
		else:
			modals.show_reinforce(_grant_reinforcements()) # NO-141: granted the
				# instant the screen fires — the modal is announcement only
	if pending_shop_open: # issue 101: the restock Wave opens the Shop itself
		pending_shop_open = false
		if not autoplay: # the bot buys through Shop.buy and never opens the
			_open_shop() # panel (autoplay.gd try_shop) — opening it here would
				# only stall a run that has no way to close it
	if pending_yalta_picks > 0: # deferred at background — see the field's own
		pending_yalta_picks -= 1 # comment. Drained BEFORE Bounty on purpose:
		_open_yalta_pick() # if this opens, _open_bounty_pick re-queues itself.
	if pending_bounty_boxes > 0: # Bounty Piece Buff (issue 48), ally half:
		# the deferred payout — see pending_bounty_boxes' own comment
		pending_bounty_boxes -= 1
		_open_bounty_pick()


## Write the run to disk and mirror it. Called at TURN START, and only there.
##
## PR #294 tried calling it on backgrounding too — the point at which Android
## may kill us — and reverted it (commit 8ee93ab): writing mid-turn violates the
## save schema's turn-start invariant, so a resumed run came back inconsistent.
## Backgrounding is therefore NOT a save point, and the guard below still reads
## as if it were because a result screen is a common place to switch away.
##
## The comment at the old call site referred to a `_save_run` that never
## existed; this is that function, finally.
## Does returning to the foreground raise the pause menu?
##
## Mobile only, and that is the whole point rather than a convenience: on a
## phone, backgrounding is a real lifecycle event — the player left, minutes or
## hours passed, and Android may have been about to kill the process. Coming
## back to a live clock mid-turn is disorienting there.
##
## On desktop a focus change is routine — alt-tab, a notification, clicking
## another window — and a modal on every one of them would be its own bug. It
## also broke the windowed click probes outright: they lose and regain focus
## during a run, so the menu landed over the board and every subsequent probe
## click hit the menu instead of the game.
##
## The clock still stops on focus loss everywhere; that part is not gated.
static func pauses_on_resume() -> bool:
	return OS.get_name() == "Android" or OS.get_name() == "iOS"


func _autosave() -> void:
	if autoplay or is_scenario:
		return # bot runs and scenarios are not resumable, by design
	# NOT after the run has ended. _game_over deletes SAVE_PATH and tombstones
	# the cloud copy precisely so a finished run cannot be resumed. The guard
	# predates the reverted backgrounding autosave (see the docstring) and is kept
	# on its own merits: a turn-start write after _game_over would resurrect a
	# finished run. Without this guard, switching away from
	# GAME OVER rewrote the save and resurrected the finished run at the next
	# launch: the same defect the tombstone was added to kill, reintroduced
	# through a new door.
	if state == State.GAME_OVER:
		return
	# Null-checked because this runs EVERY TURN on a phone, where storage
	# genuinely fills up. Dereferencing a failed open would crash the run at the
	# top of a turn — losing far more than the save it was trying to write. The
	# turn continues unsaved instead, which is the position the player was in a
	# moment earlier anyway.
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("save: could not write %s (error %d) — this turn is not saved"
			% [SAVE_PATH, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(SaveConfig.to_config(self)))
	f = null # close before the mirror reads the file back through its own handle
	CloudSave.sync_file("run", SAVE_PATH) # mirror to the platform backend (12)


func _enemy_turn() -> void:
	state = State.ENEMY_TURN
	_add_turn_fx("ENEMY TURN", Color(1.0, 0.42, 0.35))
	enemy_double_steps.clear() # NO-232: same expiry as player_double_steps,
		# mirrored for the enemy — see that field's own comment
	if hud.drawer_open != "": # full board while the enemy plays
		_set_drawer("")
	_clear_selection()
	placing_id = ""
	pool_drag_id = ""
	_item_reset()
	_artefact_targeting_reset() # Bovine Tractor Beam (52): never carries into the enemy turn
	_army_board_targeting_reset() # issue 68: Hostile Takeover/Ritual, same reasoning
	# Call the Banners (issue 67), for the SAME reason as the two above — it was
	# the one targeting mode missing from this list. Left armed, it survived into
	# the next player turn where nothing on screen showed it: the tint lives on
	# the Ability chip, and _begin_army_targeting force-closes that drawer. The
	# next tap on any Stock stack was then eaten by the targeting branch, which
	# spends an Action and the wave's Ability on a stack the player was only
	# trying to deploy. Reachable in three taps: activate, PASS, tap Stock.
	_army_targeting_reset()
	_refresh()
	# Vladimir Putin: Annexation. Deliberately resolved at the END of the
	# player's turn and only in the enemy half, so it is a rule the player can
	# see and play around rather than an unavoidable drip.
	if Kings.power_is(self, "annex"):
		for pos in _player_pieces():
			if pos.y >= Tuning.BOARD_H / 2:
				board[pos].owner = Rules.ENEMY
				_add_turn_fx("Annexed", Color(1.0, 0.5, 0.4))
	turns_since_wave += 1
	WaveLogic.release_king_if_due(self) # issue 90: segment 1 -> segment 2
	Kings.stack_power_if_due(self) # an escalating Power gains its next Tariff
	# `_king_to_come()` is load-bearing, not defensive. Through segment 1, and
	# on the turn release_king_if_due() above moves him into pending_spawn,
	# there is no King on the board, so `_king_alive()` is false — without this
	# the cadence would queue the NEXT wave and walk straight past a King wave
	# whose King had not arrived yet (NO-93).
	if wave < Waves.WAVES.size() and not _king_alive() and not _king_to_come() \
			and turns_since_wave >= _cadence():
		WaveLogic.queue(self, wave + 1)
	if skip_enemy_turns > 0: # Surprise Attack: the enemy sits this one out
		skip_enemy_turns -= 1
	else:
		if not autoplay and animations_on:
			await get_tree().create_timer(Tuning.ENEMY_TURN_PAUSE).timeout
		await _wait_while_backgrounded() # 06: no enemy turn resolves while backgrounded
		await _run_enemy_actions()
	if state != State.GAME_OVER:
		if not autoplay and animations_on:
			await get_tree().create_timer(Tuning.ENEMY_TURN_PAUSE).timeout
		await _wait_while_backgrounded()
		_begin_player_turn()


## OS backgrounding (06): app switch/call/notification must freeze the run
## exactly like the in-game menu — no enemy action may resolve mid-background.
## Polls rather than engine-pausing the tree, so it hangs off the same
## flag-based seam as game_menu_open/win_open/shop_open() instead of a second
## pause mechanism.
func _wait_while_backgrounded() -> void:
	while backgrounded or game_menu_open: # review pass 2: "Paused" froze the
		# clock and input but not this coroutine — enemy pieces kept resolving
		# under the overlay
		await get_tree().process_frame


func _run_enemy_actions() -> void:
	var actions := Economy.enemy_actions(self)
	for i in actions:
		await _wait_while_backgrounded()
		var act := Rules.ai_action(board, defs, _enemy_denied_tiles(), player_double_steps) # NO-232
		# issue 91: the King Ability COSTS THE KING AN ACTION, out of the same
		# budget the attacks come from — the tradeoff the player plays around.
		# 2026-09-06: WHEN to spend it is an AI decision, not a turn-start
		# reflex. Check resolution comes first (a King in check with one Action
		# used to spend it on the Ability and never move), then a profitable
		# capture, and only an Ability that would do something (Kings.
		# ability_useful). A turn zeroed by Y2K Patch Floppy Disk never reaches
		# this loop, so it still buys no Ability.
		if Kings.ability_useful(self):
			var king := Rules.find_king(board, Rules.ENEMY)
			var in_check: bool = king.x >= 0 and Rules.is_attacked(board, king, Rules.PLAYER, defs)
			var capturing: bool = not act.is_empty() and (board.has(act.to) or act.has("ep_victim")) # NO-232
			if not in_check and not capturing and Kings.fire_ability(self):
				continue # this Action went to the Ability; the next re-reads the board
		if act.is_empty():
			break # a held action still ends the turn: the Stun ageing below must run
		if not autoplay and animations_on:
			await get_tree().create_timer(0.35).timeout
		await _wait_while_backgrounded()
		if act.has("ep_victim"): # NO-232: teleport the victim onto the landing
			# square before anything below reads the board — same trick and
			# same reason as _move_player's own en passant handling.
			board[act.to] = board[act.ep_victim]
			board.erase(act.ep_victim)
		# Cheyenne Mountain Doorbell (issue 51): a player piece on the back
		# row cannot be captured — same repel shape as Shield/Reflect (the
		# attempt is spent, nothing moves) but no Buff is involved, so there
		# is nothing to consume. Winchester (above) already keeps enemies off
		# y=0 entirely when both are held, making this branch moot then —
		# the cards are independently written, so both still apply on their
		# own terms.
		var cheyenne_repel: bool = act.to.y == 0 and board.has(act.to) and board[act.to].owner == Rules.PLAYER \
			and _held("cheyenne-mountain-doorbell")
		# UAP Breath Mint / Inflatable Vietcong Torpedo (issue 54): both auto-
		# resolve (user ruling — no targeting step, no Gold prompt), so both
		# extend this same repel guard instead of a second interception
		# point. Checked only when nothing above has already repelled the
		# attempt, and UAP (free) before Torpedo (costs Gold) — a held UAP
		# with an open tile is strictly better for the player than spending
		# Gold, so it's tried first; Torpedo only fires when UAP couldn't
		# (unheld, already used this Wave, or no tile free).
		var already_repelled: bool = board.has(act.to) and (BuffLogic.repels_capture(board[act.to]) or cheyenne_repel)
		var uap_dodge_to := Vector2i(-1, -1)
		if not already_repelled and board.has(act.to) and board[act.to].owner == Rules.PLAYER \
				and _held("uap-breath-mint") and not uap_used_this_wave:
			uap_dodge_to = _uap_dodge_target(act.to, act.from)
		var torpedo_fires: bool = not already_repelled and uap_dodge_to.x < 0 \
			and board.has(act.to) and board[act.to].owner == Rules.PLAYER \
			and _held("inflatable-vietcong-torpedo") and not torpedo_used_this_wave and gold >= 15
		if already_repelled or uap_dodge_to.x >= 0 or torpedo_fires:
			# Shield works against the AI too: the attempt is spent, nothing
			# moves. Reflect kills the attacker and takes its tile.
			if BuffLogic.reflects_capture(board[act.to]):
				_consume_buff(act.to, "reflect")
				_add_float(act.from, "Reflected!", COL_CAPTURE)
				lost_enemy += 1
				_add_pop(act.from)
				board[act.from] = board[act.to]
				board[act.from].moved = true # NO-224: it relocated, whoever's piece it is
				board.erase(act.to)
			elif uap_dodge_to.x >= 0:
				uap_used_this_wave = true
				board[uap_dodge_to] = board[act.to]
				board[uap_dodge_to].moved = true # NO-224
				board.erase(act.to)
				_add_float(uap_dodge_to, "Dodged!", COL_MERGE)
			elif torpedo_fires:
				torpedo_used_this_wave = true
				Economy.spend_gold(self, 15)
				_add_float(act.to, "Paid Off", COL_MERGE)
			else:
				if BuffLogic.repels_capture(board[act.to]):
					_consume_buff(act.to, "shield")
				_add_float(act.to, "Blocked", COL_MERGE)
			queue_redraw()
			continue
		if board.has(act.to) and (BuffLogic.has(board[act.to], "bomb")
				or BuffLogic.has(board[act.from], "bomb")):
			# Consumed before either piece is erased, purely so Cleopatra's
			# Hairpin / Guidestone Blood Ritual see the trigger — both
			# pieces are gone either way.
			if BuffLogic.has(board[act.to], "bomb"):
				_consume_buff(act.to, "bomb")
			if BuffLogic.has(board[act.from], "bomb"):
				_consume_buff(act.from, "bomb")
			board.erase(act.to)
			board[act.to] = board[act.from]
			board[act.to].moved = true # NO-224
			board.erase(act.from)
			_detonate(act.to)
			queue_redraw()
			continue
		if board.has(act.to) and BuffLogic.has(board[act.to], "trap"):
			# Trap takes the attacker with it — neither piece survives
			_consume_buff(act.to, "trap") # same reasoning as bomb above
			_add_float(act.from, "Trapped!", COL_CAPTURE)
			_lose_player_piece(act.to, "trap")
			lost_enemy += 1
			_add_pop(act.to)
			_add_pop(act.from)
			board.erase(act.to)
			board.erase(act.from)
			queue_redraw()
			continue
		if board.has(act.to):
			if BuffLogic.has(board[act.to], "stun"):
				# 2 ticks: the buff ages at the start of each PLAYER turn, so
				# 2 keeps the attacker out for exactly one enemy turn
				BuffLogic.add(board[act.from], "stunned", Tuning.STUN_MISSES + 1)
				_add_float(act.from, "Stunned!", COL_MERGE)
			_note_capture(act.from) # no on_capture here (the enemy doesn't
				# score) — still the attacker's OWN ledger, read later by
				# Chupacabra Chew Toy off the victim (issue 25). Fires even
				# when Hoffa's Cement Shoes sinks the attacker right after —
				# the capture already happened, same as Bomb/Trap in
				# _move_player killing the attacker AFTER its capture scored.
			if _lose_player_piece(act.to, "captured", act.from).destroy_attacker:
				# Hoffa's Cement Shoes (artefact hook 24): once per Wave, the
				# capturer sinks with its victim — Trap's own mutual-
				# destruction shape above, artefact-gated instead of
				# BuffLogic-gated
				_add_float(act.from, "Sunk!", COL_CAPTURE)
				lost_enemy += 1
				_add_pop(act.to)
				_add_pop(act.from)
				board.erase(act.to)
				board.erase(act.from)
				queue_redraw()
				continue
			_add_pop(act.to)
		_add_slide(act.from, act.to)
		board[act.to] = board[act.from]
		board[act.to].moved = true # NO-224: the initial double-step gates on this
		board.erase(act.from)
		var skip := Rules.double_step_skip(board[act.to], act.from, act.to, defs) # NO-232
		if skip.x >= 0:
			enemy_double_steps.append({"pawn": act.to, "skip": skip, "id": board[act.to].id})
		queue_redraw()
		if _back_row_breached():
			return _game_over(false, "Back-row breach")
	for pos in board: # Stun ages on the stunned side's own turn boundary
		if board[pos].owner == Rules.ENEMY:
			BuffLogic.tick_side(board[pos])


## UAP Breath Mint (issue 54): auto-picks a landing square for the piece at
## `pos`, preferring the empty neighbour farthest from `attacker` — same
## "the trigger resolves itself, no targeting step" precedent as
## multicapture's auto-picked victim (buff_logic.gd:multicapture_target).
## Vector2i(-1,-1) when every neighbour is occupied or off-board: the user
## ruling is the dodge does nothing and the capture proceeds.
func _uap_dodge_target(pos: Vector2i, attacker: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := -1
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var to := pos + Vector2i(dx, dy)
			if to.x < 0 or to.x >= Tuning.BOARD_W or to.y < 0 or to.y >= Tuning.BOARD_H:
				continue
			if board.has(to):
				continue
			var dist := to.distance_squared_to(attacker)
			if dist > best_dist:
				best_dist = dist
				best = to
	return best


func _add_slide(from: Vector2i, to: Vector2i) -> void:
	if autoplay or not animations_on:
		return
	anims.append({"kind": "move", "to": to, "from_px": _tile_px(from), "to_px": _tile_px(to), "t": 0.0})


## Floating label at a tile — the same anim the score popups use, for effects
## that have no score to show (a buff landing, a capture repelled).
func _add_float(at: Vector2i, text: String, color: Color) -> void:
	if autoplay or not animations_on:
		return
	anims.append({"kind": "text", "t": 0.0, "dur": 1.2, "text": text,
		"at_px": _tile_px(at) + Vector2(tile, tile) / 2, "color": color})


func _add_pop(at: Vector2i) -> void:
	if autoplay or not animations_on:
		return
	anims.append({"kind": "pop", "at_px": _tile_px(at) + Vector2(tile, tile) / 2, "t": 0.0})


## Loss only when EVERY back-row tile holds an enemy (playtest rule 2026-07-02;
## a single enemy reaching row 0 no longer ends the run).
func _back_row_breached() -> bool:
	for x in Tuning.BOARD_W:
		var t := Vector2i(x, 0)
		if not board.has(t) or board[t].owner != Rules.ENEMY:
			return false
	return true


## Royal Fiat (Undamaged)'s forced-retreat landing tile (artefact hook 24):
## the first empty back-row (y=0) square scanning x=0..BOARD_W-1 — no GDD
## guidance on ties, ruled 2026-08-28. Vector2i(-1,-1) when the row is full,
## which the caller treats as "no forced move" rather than displacing anyone.
func _first_empty_backrow_tile() -> Vector2i:
	for x in Tuning.BOARD_W:
		var t := Vector2i(x, 0)
		if not board.has(t):
			return t
	return Vector2i(-1, -1)


func _cadence() -> int:
	var next_wave_i: int = mini(wave, Waves.WAVES.size() - 1)
	return Tuning.CADENCE_BASE + Waves.WAVES[next_wave_i].size()


func _king_alive() -> bool:
	return Rules.find_king(board, Rules.ENEMY).x >= 0


## Display name of the King currently on the board — or, before he lands, of
## the one pending (NO-83: the ⧖ counter names him through segment 1 too) — or
## "King" if there is none / it wasn't spawned with an identity (hand-written
## test scenarios).
func _king_name() -> String:
	var k := Rules.find_king(board, Rules.ENEMY)
	if k.x < 0:
		return Kings.name_of(pending_king.get("king_id", "")) if not pending_king.is_empty() else "King"
	return Kings.name_of(board[k].get("king_id", ""))








func _setup_open_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in Tuning.BOARD_W:
		for y in Tuning.PLAYER_ZONE_ROWS:
			if not board.has(Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out


func _any_enemy() -> bool:
	for pos in board:
		if board[pos].owner == Rules.ENEMY:
			return true
	return false


func _player_pieces() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pos in board:
		if board[pos].owner == Rules.PLAYER:
			out.append(pos)
	return out


## NO-232: the en passant offers a piece OF `owner` may capture — the
## OPPOSITE side's own double-steps from their last turn.
func _ep_offers_for(owner: int) -> Array:
	return enemy_double_steps if owner == Rules.PLAYER else player_double_steps


## Structural "is this Artefact held" read, for the handful of standing rules
## (issue 26: Nazca Boarding Pass, Nuclear Football Menu) that aren't a
## triggered effect and so have no hook to dispatch on — same direct
## g.artefacts read shop.gd already uses for chocolate-key-cake etc.
func _held(key: String) -> bool:
	for t in artefacts:
		if t.key == key:
			return true
	return false


## Nazca Boarding Pass (issue 26): Deploy legality opens to every empty tile
## instead of Rules.placement_tiles' zone/touching-ally set. A standing rule,
## not a hook — see _held above.
func _deploy_tiles() -> Array[Vector2i]:
	if _held("nazca-boarding-pass"):
		var out: Array[Vector2i] = []
		for x in Tuning.BOARD_W:
			for y in Tuning.BOARD_H:
				if not board.has(Vector2i(x, y)):
					out.append(Vector2i(x, y))
		return out
	return Rules.placement_tiles(board)


## Winchester Salt Lined Doors (issue 51): enemy pieces cannot move onto the
## back row (y=0) while held. Another standing rule read straight off held
## Artefacts (see _deploy_tiles above) — computed here, in game.gd, and
## passed into Rules.legal_moves/ai_action/is_checkmate as a parameter, so
## rules.gd never gains a g.artefacts reference of its own.
func _enemy_denied_tiles() -> Array[Vector2i]:
	if not _held("winchester-salt-lined-doors"):
		return []
	var out: Array[Vector2i] = []
	for x in Tuning.BOARD_W:
		out.append(Vector2i(x, 0))
	return out


## issue 103: one CSV line per bot run, prefixed PLAYTEST so a batch runner can
## grep it out of Godot's own chatter. Column order is FIXED and must stay that
## way — `tools/playtest.sh` appends these to a single file across hundreds of
## runs, and a reordered column silently corrupts every earlier row.
##
## A leverage the bot never uses reads as a plain 0 here. That is the whole
## point of the file: "resource starvation" next to shop_open=0 is a bot
## problem, not a difficulty problem.
const TELEMETRY_COLUMNS := [
	# where the run ended up
	"result", "reason", "wave", "score", "turns", "gold_left", "tier", "army", "seed",
	# the leverages
	"shop_open", "shop_buy", "sell", "convert", "item_use", "artefact_activate",
	"army_ability", "merge", "deploy", "buff_apply", "capture", "piece_lost",
]


static func telemetry_header() -> String:
	return "PLAYTEST," + ",".join(TELEMETRY_COLUMNS)


## `result` is a string, not a win/lose bool, because a run can also END
## UNRESOLVED: the bot can outlive its step cap, and calling that a LOSS would
## file the strongest runs as failures. It is its own outcome — see CAP below.
func _telemetry_csv(result: String, reason: String) -> String:
	var row := {
		"result": result,
		"reason": reason.replace(",", ";"), # never break the column count
		"wave": wave, "score": score, "turns": autoplay_turns,
		"gold_left": gold, # unspent at death — the number that exposes a bot
			# that never converted Gold into material
		"tier": next_tier, "army": next_army, "seed": rng.seed,
		"shop_open": telemetry.get("shop_open", 0),
		"shop_buy": telemetry.get("hook:on_purchase", 0),
		"sell": telemetry.get("sell", 0),
		"convert": telemetry.get("convert", 0),
		"item_use": telemetry.get("hook:on_item_consume", 0),
		"artefact_activate": telemetry.get("artefact_activate", 0),
		"army_ability": telemetry.get("action:army_ability", 0),
		"merge": telemetry.get("hook:on_fuse", 0),
		"deploy": telemetry.get("hook:on_deploy", 0),
		"buff_apply": telemetry.get("hook:on_buff_apply", 0),
		"capture": telemetry.get("hook:on_capture", 0),
		"piece_lost": telemetry.get("hook:on_piece_lost", 0),
	}
	var out: Array = []
	for col in TELEMETRY_COLUMNS:
		out.append(str(row[col]))
	return "PLAYTEST," + ",".join(out)


func _game_over(won: bool, reason: String) -> void:
	state = State.GAME_OVER
	ArtefactHooks.run(self, "on_game_over") # before record_score: e.g. Rapture
		# Insurance Policy converts Gold to Score, and the converted total is
		# what gets ranked (issue 16)
	if not is_scenario:
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(SAVE_PATH) # the run ended; nothing to resume
		# ...and the CLOUD has to be told, or deleting the local file achieves
		# nothing. cloud_save.resolve() treats "no local file" as the new-device
		# restore case and takes the cloud copy wholesale — so the next boot's
		# sync would pull the finished run straight back and offer to Continue a
		# game that is already over, every launch, for every player.
		#
		# A null payload is the tombstone: resolve() returns null for it, and
		# sync_file() bails before writing, so the deletion sticks instead of
		# being undone. (issue 86)
		CloudSave.push("run", null)
	var rank := 0 # scenario/bot runs stay off the local leaderboard
	if not is_scenario and not autoplay:
		rank = Economy.record_score(self)
		_record_history(won) # Games History: every real run, win or loss
		# NO-8: and the GLOBAL board, inside this same guard rather than a
		# second one. The harness plays hundreds of bot runs; a submit outside
		# here posts every single one to a real, public leaderboard. Reusing the
		# guard is what makes that impossible rather than merely unlikely.
		GlobalBoard.submit(GlobalBoard.HIGH_SCORE, score)
	modals.show_overlay(won, reason, rank)
	_refresh()
	if autoplay_exit:
		print("AUTOPLAY RESULT: %s — %s (wave %d, score %d, %d turns)" % ["WIN" if won else "LOSS", reason, wave, score, autoplay_turns])
		print(_telemetry_csv("WIN" if won else "LOSS", reason)) # issue 103
		if screenshot_dir != "":
			_end_shot() # fire-and-forget: capture the end screen, then quit
		else:
			get_tree().quit(0)




func _end_shot() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_dir.path_join("gameover.png"))
	get_tree().quit()






func _on_win_continue() -> void:
	win_open = false
	overlay.visible = false
	Economy.add_clock(self, Tuning.CONTINUE_CLOCK_REFILL_MS, "continue") # one-time endless bonus
	if actions_left == 0 and state == State.PLAYER_TURN:
		return _on_pass() # the checkmate spent the last action — resume the flow
	_refresh()


# --- input ---

## Press-drag from a stock stack: the piece follows the cursor and drops onto
## a valid placement tile. Tapping (release back on the button) still selects.
func _on_stack_drag_start(entry: Variant, cap: bool) -> void:
	var id: String = entry if entry is String else entry.id
	if box_open or buff_pick_open or win_open or game_menu_open or preview_open:
		return
	if cap:
		return # Captured Stock is not draggable: there is nothing to drag it
			# TO. It has no deploy (issue 60) and, since 2026-09-10, no merge
			# either — and starting the drag is what used to light up every
			# deploy tile for a piece that could not be placed on any of them.
	if state != State.SETUP and (state != State.PLAYER_TURN or actions_left <= 0):
		return
	_clear_selection()
	pool_drag_id = id
	armed_entry = entry
	drawer_autoclosed = ""
	# highlight drop targets WITHOUT rebuilding the strip — a rebuild would
	# free the pressed button and its release-tap (pressed) would never fire,
	# breaking tap-to-place (found 2026-07-07)
	merge_highlights = MergeLogic.partner_ids(self)
	for c in hud.pool_buttons():
		if c is Button and c.has_meta("id") and merge_highlights.has(c.get_meta("id")):
			c.modulate = Color(0.8, 1.1, 1.4)
	queue_redraw()


## Buttons capture the click, so the drag's release lands here, not in
## _unhandled_input.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT and pool_drag_id != "":
		# the cursor left the window mid-drag: cancel and restore the drawer
		pool_drag_id = ""
		if drawer_autoclosed != "":
			_set_drawer.call_deferred(drawer_autoclosed)
			drawer_autoclosed = ""
		queue_redraw()
	# 06: app switch, phone call or notification — same pause state as the
	# in-game menu (clock stopped, no enemy turns), via `backgrounded`.
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		backgrounded = true
		# NOW SAVES. It did not, and the comment here used to explain why: the
		# format assumed every save was taken at a TURN START, so a mid-turn
		# snapshot resumed as a fresh turn and handed back actions already
		# spent. save_config.gd carries the turn in progress now (state,
		# actions_left, the per-turn flags) and apply() resumes it without
		# re-running _begin_player_turn()'s side effects, so the snapshot is
		# honest and this call is safe.
		#
		# _autosave() keeps its own guards: never for autoplay or scenario runs,
		# and never at GAME_OVER — switching away from a finished run once
		# rewrote the save and resurrected it, and that door stays shut.
		#
		# A modal or targeting no longer blocks the save. It used to: the
		# continuation for an open choice lives in `_choice_on_chosen`, a
		# Callable, which cannot be serialised — so the first cut refused to
		# save at all and the player lost the turn for answering the phone.
		# _rollback_for_save() takes the run back to where that modal's own
		# Cancel lands, which IS representable, and saves there. See its header.
		# A Box pick is the one that needs no rollback: its state is pure data,
		# so it is saved as-is and re-opened on resume.
		_rollback_for_save()
		_autosave()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Only a RESUME raises the menu — a focus event with no matching
		# FOCUS_OUT behind it is not one. The window gains focus when it is first
		# created, and again on every alt-tab; raising the pause menu on those
		# put it over the board before the game had started, which hung the
		# windowed click probes outright (every probe click landed on the menu).
		var resuming := backgrounded
		backgrounded = false
		# Come back to a PAUSED game, not a live one. The player has been away
		# for an unknown length of time; dropping them straight into a running
		# clock mid-turn is worse than one deliberate tap to re-orient. Same
		# entry point the hardware Back handler uses, so the two cannot drift.
		if resuming and pauses_on_resume() and state != State.GAME_OVER \
				and not autoplay and not win_open:
			hud.toggle_menu(true)
	# Android's hardware Back. Godot quits the app on it by default, and mid-run
	# that is the worst possible response: the autosave is only written at turn
	# start (see _autosave), so a stray Back discarded the turn in progress and
	# looked like a crash. quit_on_go_back is off in project.godot, so this is
	# now the only handler.
	#
	# Back opens the pause menu, or closes it if it is already open — the pause
	# menu is where Main Menu lives, so leaving a run stays two deliberate taps
	# rather than one reflex gesture. Once the run is over the overlay owns the
	# screen and has its own buttons, so Back is ignored rather than resurrecting
	# a menu on top of it.
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if BackGuard.is_duplicate():
			return # NO-61: Android raises this TWICE per press. See back_guard.gd.
		if state == State.GAME_OVER:
			# Leaves, rather than doing nothing. "A gesture that silently does
			# nothing reads as a frozen app" is the reason this handler exists
			# at all, and the result screen is no exception — Back maps to the
			# Main Menu button sitting right there. The run is already over and
			# already scored, so nothing is lost by taking it.
			get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		else:
			hud.toggle_menu(not game_menu_open)


func _input(event: InputEvent) -> void:
	if pool_drag_id == "":
		return
	if event is InputEventMouseMotion:
		if hud.drawer_open != "" and not \
				(hud.drawers[hud.drawer_open] as Control).get_global_rect().has_point(event.position):
			drawer_autoclosed = hud.drawer_open # reopen if this drag cancels
			_set_drawer("") # dragged out toward the board: give it back
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		var t := _tile_at(event.position)
		var id := pool_drag_id
		var entry: Variant = armed_entry
		pool_drag_id = ""
		# a release inside the open drawer must never hit the board tiles
		# hidden beneath it — that reads as a misinput (2026-07-08). Dragging
		# out closes the drawer, so real board drops arrive uncovered.
		var covered: bool = hud.drawer_open != "" and (hud.drawers[hud.drawer_open] as Control) \
				.get_global_rect().has_point(event.position)
		# drop on a friendly partner piece: merge into its tile
		if not covered and state == State.PLAYER_TURN and t.x >= 0 and board.has(t) \
				and board[t].owner == Rules.PLAYER and merge_highlights.has(board[t].id):
			get_viewport().set_input_as_handled()
			drawer_autoclosed = ""
			return MergeLogic.do_merge(self, {"id": id, "entry": entry}, t)
		# drop on a DIFFERENT partner Stock stack in the strip: pool merge.
		# Dropping back on the same stack is a plain tap (arms placement) —
		# same-stack promotion goes through the ▲ badge instead (2026-07-07).
		# A CAPTURED stack is never a drop target (2026-09-10): merging into one
		# would consume it, and its only exits now are convert and sell.
		var target := hud.stack_button_at(event.position)
		if state == State.PLAYER_TURN and target != null \
				and not target.get_meta("cap") \
				and merge_highlights.has(target.get_meta("id")) \
				and target.get_meta("id") != id:
			get_viewport().set_input_as_handled()
			return MergeLogic.do_merge(self, {"id": id, "entry": entry},
				{"id": target.get_meta("id"), "entry": target.get_meta("entry")})
		var placeable: bool = not covered and t.x >= 0 and not board.has(t) \
			and (t.y < Tuning.PLAYER_ZONE_ROWS if state == State.SETUP
				else _deploy_tiles().has(t))
		if placeable and (state == State.SETUP
				or (state == State.PLAYER_TURN and actions_left > 0)):
			drawer_autoclosed = ""
			_place(entry, t)
			# NO-84 story 41/42/43: a successful drag-drop deploy reopens
			# the Stock Drawer only if there is still something to do in
			# it. SETUP already reopens it unconditionally (_place's own
			# "keep the placement flow going" branch), so this only fires
			# mid-turn.
			if state == State.PLAYER_TURN and _stock_drawer_reopens():
				_set_drawer("stock")
		else: # dropped elsewhere (incl. back on the button = plain tap)
			if drawer_autoclosed != "": # the drag closed it, nothing happened:
				_set_drawer.call_deferred(drawer_autoclosed) # give it back
				drawer_autoclosed = ""
			# deferred: an immediate rebuild frees the button before its
			# release-tap (pressed) fires, killing tap-to-place (2026-07-07)
			_refresh.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if preview_open or game_menu_open:
		return # the panels' own buttons handle dismissal
	if state == State.GAME_OVER or state == State.ENEMY_TURN or box_open or buff_pick_open or win_open:
		drag_from = Vector2i(-1, -1)
		arrow_from = Vector2i(-1, -1)
		board_lp_token = 0 # NO-120: none of these states can complete a hold
		board_lp_pending_tile = Vector2i(-1, -1) # ...or a deferred commit
		_swipe_eligible = false # NO-145: ditto — a press swallowed here must
			# never let a later release, once the state clears, fire a swipe
			# off a stale flag/position from an unrelated gesture
		return
	if arrow_mode and item_active < 0 and artefact_targeting_key == "":
		# item/artefact targeting still owns board taps
		return _arrow_input(event)
	if event is InputEventMouseMotion:
		if drag_from.x >= 0:
			if _tile_at(event.position) != drag_from:
				drag_moved = true # a real drag, not a tap in place
			queue_redraw()
		# NO-120: past the same deadzone hud.gd's _long_press_input cancels a
		# drawer long-press on, cancel a pending board one too.
		if board_lp_token != 0 and event.position.distance_to(board_lp_from) > HudScript.DRAWER_SCROLL_DEADZONE:
			board_lp_token = 0
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at := _tile_at(event.position)
		if event.pressed:
			# NO-145: capture swipe eligibility FIRST, off the state exactly as
			# it stood when this press landed — the drawer/Shop auto-close
			# branches right below mutate hud.drawer_open/shop_open() for
			# THIS press, and _swipe_open_may_begin must see the pre-mutation
			# values (a press that closes a drawer via outside-tap is a tap,
			# not the start of an open-swipe on the same gesture).
			_swipe_from = event.position
			_swipe_eligible = _swipe_open_may_begin(at)
			# any press outside an open drawer closes it to reveal the board
			if hud.drawer_open != "" and not (hud.drawers[hud.drawer_open] as Control) \
					.get_global_rect().has_point(event.position):
				_set_drawer("")
			# NO-118: same "outside closes it" trigger as the drawer above,
			# but this one CONSUMES the press instead of falling through —
			# deliberately diverging from the drawer, not an inconsistency to
			# "fix" later. The drawer's fall-through is itself deliberate:
			# dragging a Stock piece out of the drawer onto a tile depends on
			# that same press reaching the board. The Shop has no such
			# gesture, and its "outside" strip (the sliver shop_panel's 90%
			# width doesn't cover) sits over board column 0 — so without
			# consuming, the same tap that dismisses the Shop can also
			# select or complete a move on a piece there. That is exactly
			# the mis-tap class CLAUDE.md's device-testing section opens
			# with (a stray tap deploying a piece and syncing before anyone
			# noticed). Goes through modals.close_shop(), the same path the
			# Close button uses, so shop_closed still fires either way.
			if shop_open() and not (modals.shop_panel as Control) \
					.get_global_rect().has_point(event.position):
				modals.close_shop()
				return # consumed: `at` below is never acted on by this press
			if at.x < 0: # dead UI space: a no-interaction press drops selection
				if selected.x >= 0 or placing_id != "":
					placing_id = ""
					_clear_selection()
					_refresh()
			if event.double_click and at.x >= 0 and board.has(at):
				drag_from = Vector2i(-1, -1)
				board_lp_token = 0 # NO-120: this click's own press already armed one
				board_lp_pending_tile = Vector2i(-1, -1) # ...or deferred a commit
				# double-tap: piece info (a King's carries his active Abilities)
				return _show_preview(board[at].id, board[at].get("king_id", ""), null, board[at])
			var occupied := at.x >= 0 and board.has(at)
			# NO-120: a hold is offered on every occupied tile, but a press that
			# would COMMIT (a move, a capture, a merge, a deploy, an item/
			# Artefact/Ability effect — _board_tap_is_readonly's header has the
			# full list) must not run _on_tile_clicked until release, so a
			# still-pending hold can never let a capture through underneath it.
			var commits := occupied and not _board_tap_is_readonly(at)
			if occupied:
				_board_long_press_start(at, event.position, commits)
			if commits:
				board_lp_pending_tile = at
			else:
				var was_selected := at.x >= 0 and at == selected
				if at.x >= 0:
					_on_tile_clicked(at)
				# a selection of an OWN piece also starts a potential drag
				# (enemy recon selections are read-only — never draggable)
				if selected == at and at.x >= 0 and board.has(at) \
						and board[at].owner == Rules.PLAYER:
					drag_from = at
					drag_moved = false
					drag_reselect = was_selected # in-place release = re-click
		else:
			# NO-145: the swipe-to-open gesture — an empty board tile ONLY
			# (see _swipe_open_may_begin; hardware round 2 dropped deck
			# chrome and the Shop's edge-proximity check, both of which
			# failed on real hardware — tuning.gd has the diagnosis). Never
			# returns early: for every press this accepted, the rest of this
			# release branch below is already a no-op (no drag_from, no
			# board_lp_pending_tile — both require an occupied origin tile,
			# which _swipe_open_may_begin refuses), so letting it fall
			# through changes nothing.
			if _swipe_eligible:
				_swipe_eligible = false
				match Tuning.classify_swipe(event.position - _swipe_from):
					"down": _set_drawer("stock") # Max: "swipe down opens Stock"
					"up": _set_drawer("inventory") # Max: "swipe up opens Inventory"
					"left": _open_shop() # Shop slides in from the right — the
						# swipe DIRECTION carries that meaning; no edge
						# proximity needed (SWIPE_EDGE_ZONE removed)
			board_lp_token = 0 # NO-120: release cancels any pending long-press timer
			if board_lp_pending_tile.x >= 0:
				# NO-120: the commit this press deferred runs now — but only as
				# a clean tap: released back on the same tile, and no hold beat
				# it to showing the description instead. Whatever the hold's
				# timer did or didn't do, this press started no drag (a
				# committing tile is never a drag source), so there is nothing
				# else for this release to resolve.
				var pt := board_lp_pending_tile
				board_lp_pending_tile = Vector2i(-1, -1)
				var fired := board_lp_fired
				board_lp_fired = false
				if not fired and _tile_at(event.position) == pt:
					_on_tile_clicked(pt)
				return
			if drag_from.x >= 0: # release ends a drag
				var t := _tile_at(event.position)
				var from := drag_from
				drag_from = Vector2i(-1, -1)
				if t != from and legal_dests.has(t):
					if state == State.SETUP:
						_setup_relocate(from, t)
					else:
						_move_player(from, t)
				elif state == State.PLAYER_TURN and t.x >= 0 and t != from \
						and board.has(t) and board[t].owner == Rules.PLAYER \
						and board.has(from) and merge_highlights.has(board[t].id):
					MergeLogic.do_merge(self, from, t) # dragged onto a partner: merge onto its tile
				elif state == State.SETUP and t.x < 0 and (
						(hud.drawer_open == "stock" and (hud.drawers["stock"] as Control)
							.get_global_rect().has_point(event.position))
						or (hud.drawer_buttons["stock"] as Control)
							.get_global_rect().has_point(event.position)):
					_setup_to_stock(from) # dropped on the drawer or Stock button
				elif t == from and (drag_moved or drag_reselect):
					# dragged away and dropped back home (no action taken), or a
					# completed re-click on an already-selected piece: deselect
					_clear_selection()
					_refresh()
				else: # release in place = fresh select; elsewhere = cancel ghost
					queue_redraw()


## Hop-chains (bent rides, leap-riders): a dot per reachable tile, linked by
## a dotted line tracing the path from the piece outward.
func _draw_linked_dots(origin: Vector2, line: Array, col: Color) -> void:
	var prev := origin
	for t in line:
		var c: Vector2 = _tile_px(t) + Vector2(tile, tile) / 2
		draw_dashed_line(prev, c, Color(col, 0.65), 2.5, 5.0)
		if not board.has(t):
			draw_circle(c, MOVE_DOT_RADIUS, col) # NO-129: was a fixed 8px
		prev = c


## Slide indicator: shaft from the piece toward the ride's end, arrowhead at
## the last reachable tile (a capture there keeps its ring on top). Sizing
## defaults to the NO-129 move/capture dimensions; Arrow Planning's decorative
## overlay (unrelated feature) passes its own, unchanged, smaller numbers.
## NO-160: shaft and head composite against the background exactly once,
## everywhere — the old separate `draw_line` + triangle put the line's end
## 10px short of the tip while the triangle's base sat `head_len` (14/20,
## always > 10) back from it, so the line's last few pixels fell INSIDE the
## triangle and, both shapes sharing the same semi-transparent `col`, that
## patch composited twice, reading visibly darker: the shaft showed through
## the arrowhead.
## NO-183: drawn as TWO convex polygons (a shaft quad, a head triangle)
## sharing one exact edge at `shaft_end`, not NO-160's single 7-point
## composite. That composite is concave at its two "shoulders" (the shaft is
## narrower than the head, so the outline turns inward there) — fine for an
## axis-aligned arrow, but for a diagonal one the shoulder edge runs at 45°
## and Godot's polygon triangulator produced a sliver gap exactly there,
## letting the shaft show through the head again (the same symptom NO-160
## fixed, for a different reason). A quad and a triangle are each ALWAYS
## convex regardless of rotation, so there is no shape for the triangulator
## to get wrong at any angle; sharing the boundary exactly (no gap, no
## overlap) keeps NO-160's double-composite fix intact. NOT VERIFIED ON
## SCREEN — check a diagonal ride's arrow specifically, the case that broke.
func _draw_move_arrow(from_px: Vector2, to_px: Vector2, col: Color,
		width := ARROW_WIDTH, head_len := ARROW_HEAD_LEN, head_half := ARROW_HEAD_HALF) -> void:
	var dir := (to_px - from_px).normalized()
	var side := Vector2(-dir.y, dir.x)
	var shaft_start := from_px + dir * (tile * 0.35)
	var shaft_end := to_px - dir * head_len # where the arrowhead base sits
	var half_w := width * 0.5
	draw_colored_polygon(PackedVector2Array([
		shaft_start - side * half_w, shaft_end - side * half_w,
		shaft_end + side * half_w, shaft_start + side * half_w,
	]), col)
	draw_colored_polygon(PackedVector2Array([
		shaft_end - side * head_half, to_px, shaft_end + side * head_half,
	]), col)


## Arrow Planning: drag draws a decorative arrow; redrawing the same one
## removes it (clear-one). Purely visual — never reaches rules/AI/legality.
func _arrow_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if arrow_from.x >= 0:
			queue_redraw() # ghost line follows the pointer
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at := _tile_at(event.position)
		if event.pressed:
			arrow_from = at
		elif arrow_from.x >= 0:
			var from := arrow_from
			arrow_from = Vector2i(-1, -1)
			if at.x >= 0 and at != from:
				var idx := _arrow_index(from, at)
				if idx >= 0:
					arrows.remove_at(idx) # redrawing an existing arrow clears it
				else:
					arrows.append({"from": from, "to": at})
			queue_redraw()


func _arrow_index(from: Vector2i, to: Vector2i) -> int:
	for i in arrows.size():
		if arrows[i].from == from and arrows[i].to == to:
			return i
	return -1


func _tile_at(screen: Vector2) -> Vector2i:
	var local := screen - board_px
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var x := int(local.x / tile)
	var y := Tuning.BOARD_H - 1 - int(local.y / tile)
	return Vector2i(x, y) if Rules.in_bounds(Vector2i(x, y)) else Vector2i(-1, -1)


## NO-145: true when a press starting at `at` (a _tile_at result) may become
## a swipe-to-open gesture. Deliberately conservative — the ticket's own
## warning is that a swipe recogniser stealing an existing drag is worse than
## no swipe at all:
##   - never while a drawer or the Shop is already open — a swipe closing one
##     of those belongs to that panel's own chrome (hud.gd/modals.gd), not
##     the board; see their own _on_*_chrome_input for the reverse gesture.
##   - never on an occupied tile — that always has selection/drag meaning
##     (own-piece drag, enemy recon, a captured target, ...).
##   - never off the board (at.x < 0) — the coordinator's hardware round 2
##     ruling narrowed this to ONE surface, the empty board tile, after
##     deck-chrome and an assumed-tile-width edge zone both failed on real
##     hardware (see tuning.gd's SWIPE_MIN_DIST comment for the full
##     diagnosis). All three open gestures — down/up/left — now start here
##     and only here.
##   - on an EMPTY tile, only when nothing is already armed/selected that a
##     press there would otherwise resolve against — an empty tile that IS a
##     legal destination for a current selection, or a staged Item/Artefact
##     target, or an Arrow Planning draw, already commits on THIS press
##     (_on_tile_clicked fires immediately below, not on release), so a
##     swipe can never begin from one without also stepping on that commit.
func _swipe_open_may_begin(at: Vector2i) -> bool:
	if hud.drawer_open != "" or shop_open():
		return false
	if at.x < 0 or board.has(at):
		return false
	return selected.x < 0 and placing_id == "" and item_active < 0 \
			and artefact_targeting_key == "" and not arrow_mode


## NO-120: true when a press on `at` (occupied — the only case a long press
## ever arms on) resolves to a READ-ONLY branch of _on_tile_clicked: select
## an own piece, recon-select/dismiss an enemy, or clear the selection.
## Mirrors _on_tile_clicked's own branches, in the same order, end to end.
##
## Everything else COMMITS — Economy.charge, a capture, a merge, a deploy, an
## action spent — and the caller must not run it on press: a hold is still
## pending at that point, and undoing a selection afterwards (which is all
## the original long-press revert did) cannot undo a capture. Found in
## review (2026-09-18): a piece selected, an enemy on a legal destination,
## long-pressed to read it — _on_tile_clicked committed the capture on the
## press, half a second before the hold even fired.
##
## Every branch here, in _on_tile_clicked's own order:
##   artefact_targeting_key / army_board_targeting / item_active / placing_id
##     — every tap in these modes stages or commits an effect (Bovine's
##     target, an Item's multi/pair/area staging, a Stock deploy-merge) —
##     never read-only, so never run on press while any is active.
##   state == SETUP: only _setup_relocate commits, and it only ever targets
##     an EMPTY legal_dests tile — never one `at` can be (board.has(at) is
##     guaranteed by the caller), so every SETUP press here is a plain select.
##   state == PLAYER_TURN, selected legal_dests.has(at): _move_player — a
##     move or a capture.
##   state == PLAYER_TURN, `at` a merge partner: MergeLogic.do_merge.
##   everything else: select an own piece, recon-select/dismiss an enemy, or
##     clear the selection — read-only.
func _board_tap_is_readonly(at: Vector2i) -> bool:
	if artefact_targeting_key != "" or army_board_targeting or item_active >= 0 \
			or placing_id != "":
		return false
	if state == State.SETUP:
		return true
	if selected.x >= 0 and legal_dests.has(at) and board.has(selected) \
			and board[selected].owner == Rules.PLAYER:
		return false
	if selected.x >= 0 and at != selected and board[at].owner == Rules.PLAYER \
			and merge_highlights.has(board[at].id):
		return false
	return true


## NO-120: long-press a board piece opens its preview modal. The board is
## drawn in _draw, not built from Controls, so there is no Button for
## hud.gd's _long_press_input to hook — this mirrors that function's
## token+timer+deadzone idiom directly over the board's own press/release/
## motion handling, rather than adding a second input path.
##
## NO-138: this used to open hud.gd's lightweight tip popup (show_tip); it
## now opens the same richer preview modal a double-tap does (_show_preview),
## so a long press means one thing everywhere it fires — including mid-
## targeting, since `is_commit` below only changes what has to be undone
## first, never whether the hold ends in a preview.
##
## `is_commit` (see _board_tap_is_readonly) decides what a firing hold does:
## a read-only press already ran _on_tile_clicked immediately, same as any
## other press, so firing UNDOES that — restores the selection from before
## the press and drops any armed drag. A committing press never ran
## _on_tile_clicked at all (the caller left it in board_lp_pending_tile for
## release instead); firing here clears that pending tile itself rather than
## leaving it for release to clear, because _show_preview sets preview_open,
## and _unhandled_input's own top guard for preview_open swallows this
## press's release before it ever reaches that clean-up — left stuck, it
## would corrupt the NEXT press's release handling (drag/move never rearms).
func _board_long_press_start(at: Vector2i, press_pos: Vector2, is_commit: bool) -> void:
	board_lp_prev_selected = selected
	board_lp_from = press_pos
	board_lp_fired = false
	var piece: Dictionary = board[at]
	var token := Time.get_ticks_usec()
	board_lp_token = token
	get_tree().create_timer(HudScript.LONG_PRESS_MS / 1000.0).timeout.connect(func() -> void:
		if board_lp_token != token:
			return
		board_lp_token = 0
		board_lp_fired = true
		if not is_commit:
			drag_from = Vector2i(-1, -1)
			selected = board_lp_prev_selected
			if selected.x >= 0 and board.has(selected):
				var ep := _ep_offers_for(board[selected].owner) # NO-232
				legal_dests = Rules.moves_for(board, selected, defs, "", ep)
				legal_paths = Rules.move_paths(board, selected, defs, ep)
			else:
				selected = Vector2i(-1, -1)
				legal_dests.clear()
				legal_paths.clear()
			queue_redraw()
		else:
			board_lp_pending_tile = Vector2i(-1, -1)
		_show_preview(piece.id, piece.get("king_id", ""), null, piece))


## NO-120: _board_tap_is_readonly mirrors this function's branches — which
## ones commit, which only select — to decide whether a press can run
## straight away or has to wait out a possible hold first. Add or change a
## COMMITTING branch here and that mirror goes stale silently: it keeps
## classifying the new branch as read-only, runs it on press again, and the
## capture-on-long-press hazard that function's header describes comes back.
## Update both, in the same commit.
func _on_tile_clicked(tile: Vector2i) -> void:
	if artefact_targeting_key != "": # Bovine Tractor Beam (52) staging; board
		# clicks feed it, same priority Item targeting already has below
		_artefact_target_click(tile)
		return
	if army_board_targeting: # issue 68: Hostile Takeover/Ritual staging —
		# same priority as Bovine's own board-targeting above (the two can
		# never be active together, gated at _army_ability_available/
		# _artefact_activation_available)
		_army_board_target_click(tile)
		return
	if item_active >= 0: # an item is targeting; board clicks feed it
		_item_click(tile)
		return
	if placing_id != "":
		# tapping a partner piece on the board merges the armed stack unit
		# into it (result on that tile)
		if board.has(tile) and board[tile].owner == Rules.PLAYER \
				and merge_highlights.has(board[tile].id):
			return MergeLogic.do_merge(self,
				{"id": placing_id, "entry": armed_entry}, tile)
		var ok := tile.y < Tuning.PLAYER_ZONE_ROWS if state == State.SETUP else _deploy_tiles().has(tile)
		if ok and not board.has(tile):
			_place(armed_entry, tile)
		return
	if state == State.SETUP: # free repositioning before the game starts
		if selected.x >= 0 and legal_dests.has(tile):
			_setup_relocate(selected, tile)
		elif board.has(tile) and board[tile].owner == Rules.PLAYER:
			selected = tile
			legal_dests = _setup_open_tiles()
			_refresh()
		else:
			_clear_selection()
			_refresh()
		return
	if state != State.PLAYER_TURN:
		return
	if selected.x >= 0 and legal_dests.has(tile) and board.has(selected) \
			and board[selected].owner == Rules.PLAYER: # enemy previews never move
		_move_player(selected, tile)
	elif selected.x >= 0 and tile != selected and board.has(tile) \
			and board[tile].owner == Rules.PLAYER and merge_highlights.has(board[tile].id):
		MergeLogic.do_merge(self, selected, tile) # second pick completes the merge on its tile
	elif board.has(tile) and board[tile].owner == Rules.PLAYER and actions_left > 0 \
			and not moved_this_turn.has(tile) \
			and not BuffLogic.has(board[tile], "stunned"):
		selected = tile
		legal_dests = Rules.moves_for(board, tile, defs, "", enemy_double_steps) # NO-232
		legal_paths = Rules.move_paths(board, tile, defs, enemy_double_steps)
		_refresh()
	elif board.has(tile) and board[tile].owner == Rules.ENEMY:
		if tile == selected: # re-click on a recon selection: dismiss it
			_clear_selection()
			_refresh()
			return
		# read-only recon: show where the enemy can move and what it threatens
		selected = tile
		legal_dests = Rules.moves_for(board, tile, defs, "", player_double_steps) # NO-232
		legal_paths = Rules.move_paths(board, tile, defs, player_double_steps)
		_refresh()
	else:
		_clear_selection()
		_refresh()


## `entry` is a Stock entry: a bare id String or {id + state} (ADR-0002).
## Stock only, since issue 60: Captured Stock no longer deploys (it converts to
## Stock or sells instead). Nothing captured can reach here — placing_id and
## pool_drag_id are only ever set from a Stock entry (2026-09-10) — so this
## dropped its own `cap` param rather than carry a dead branch.
func _place(entry: Variant, tile: Vector2i) -> void:
	# Mao Zedong: Backyard Furnaces — what you deploy arrives worthless.
	if Kings.power_is(self, "furnaces"):
		var pid: String = entry.id if entry is Dictionary else str(entry)
		var base := Kings._base_of(self, pid)
		if base != pid:
			if entry is Dictionary:
				entry.id = base
			else:
				entry = base
	var id: String = entry if entry is String else entry.id
	fx_at = _tile_px(tile) + Vector2(self.tile, self.tile) / 2
	stock.erase(entry)
	board[tile] = {"id": id, "owner": Rules.PLAYER}
	if entry is Dictionary: # restore the piece state it left the board with
		board[tile].merge(entry)
	placing_id = ""
	if state == State.PLAYER_TURN:
		# MK-Ultra Sugar Cube (18); skip_action: Hitler's Argentinian Passport (26)
		var deploy_ctx := ArtefactHooks.run(self, "on_deploy", {"pos": tile, "skip_action": false})
		if not deploy_ctx.skip_action:
			actions_left -= 1
		_log_action("place", {"pos": tile}) # issue 56: Zapruder's Deploy-return reads this back
		Economy.charge(self, "deploy_cost",
			Economy.tariff_cut(Tuning.PLACEMENT_COST, Tuning.TARIFF_DEPLOY_PCT))
		if not (Armies.endless_ranks(self) and id == "pawn"): # issue 68:
			# Endless Ranks (The Horde) waives the base deploy cost for pawns
			# only — majors still pay (though Horde's own kit fields none).
			# The tariff surcharge above (Economy.charge) is a different
			# mechanism and stays live either way.
			Economy.spend_gold(self, Economy.deploy_cost(self))
		if actions_left == 0 or _board_cleared(): # last action spent placing
			return _on_pass()
	elif state == State.SETUP and not stock.is_empty() and hud.drawer_open != "stock":
		_set_drawer("stock") # keep the placement flow going
	_refresh()


## NO-84 story 41-43: is there still something to do in the Stock Drawer, mid-
## turn, after a drag-drop closed it? A Stock stack the player can afford to
## deploy (mirrors the price hud.gd's pool strip shows, incl. Endless Ranks'
## free pawns), or a Captured Stock entry they can afford to convert.
func _stock_drawer_reopens() -> bool:
	if actions_left <= 0:
		return false
	for e in stock:
		var id: String = e if e is String else e.id
		var cost: int = 0 if (id == "pawn" and Armies.endless_ranks(self)) else Economy.deploy_cost(self)
		if gold >= cost:
			return true
	for e in captured:
		if Shop.can_convert(self, e):
			return true
	return false


## NO-85 story 59-60: is there still something to do in the Inventory Drawer
## after an action closed it? An Item still held (no per-item afford check
## exists — held is usable, same as before this slice), or an activatable
## Artefact still available. Mirrors _stock_drawer_reopens' shape.
func _inventory_drawer_reopens() -> bool:
	if state != State.PLAYER_TURN or box_open or buff_pick_open or win_open:
		return false
	if not items.is_empty():
		return true
	for key in _activatable_held_keys():
		if _artefact_activation_available(key):
			return true
	return false


## Reopen the Inventory Drawer only if it isn't already the one showing (the
## toggle in hud.set_drawer would otherwise CLOSE it) and something is left
## to do in it — the "after use" half of stories 58-60. Cancels reopen
## unconditionally instead (story 58), called separately at each cancel site.
func _reopen_inventory_if_usable() -> void:
	if hud.drawer_open != "inventory" and _inventory_drawer_reopens():
		_set_drawer("inventory")


## SETUP-only: pieces slide anywhere open in the zone and can return to stock.
func _setup_relocate(from: Vector2i, to: Vector2i) -> void:
	board[to] = board[from]
	board.erase(from)
	_clear_selection()
	_refresh()


func _setup_to_stock(from: Vector2i) -> void:
	stock.append(board[from].id)
	board.erase(from)
	_clear_selection()
	_refresh()


func _move_player(from: Vector2i, to: Vector2i) -> void:
	var king_captured := false
	var captured_king_id := ""
	var return_to_start := false # USS Eldridge Invisibility Paint (artefact hook 24)
	var move_to_backrow := false # Royal Fiat (Undamaged), same mechanism
	# Blitz rework (Notion 2026-08-28): the target's next move/capture this
	# Turn costs no action — a one-shot flag on the piece Dictionary itself
	# (ADR-0002: opaque piece state rides the Dictionary object, not a board
	# position, since `from` is about to move or disappear). Captured once,
	# up front, so every actions_left -= 1 below can consume it.
	var moving_piece: Dictionary = board[from]
	var blitz_free: bool = moving_piece.get("blitz_free_move", false)
	# NO-232: an en passant capture lands on an EMPTY square with the actual
	# victim standing elsewhere — teleport it onto `to` BEFORE anything below
	# reads the board, so every capture branch (repel/reflect/bomb/trap/
	# plain) runs completely unmodified, exactly as if it had been standing
	# there all along. No second, divergent capture implementation.
	var ep_victim := Rules.en_passant_victim(board, from, to, enemy_double_steps, defs)
	if ep_victim.x >= 0:
		board[to] = board[ep_victim]
		board.erase(ep_victim)
	var did_capture := board.has(to) # action-log kind (issue 30): "move" vs "capture"
	fx_at = _tile_px(to) + Vector2(tile, tile) / 2 # popups at the action tile
	if board.has(to) and BuffLogic.repels_capture(board[to]):
		# GDD Pieces & Movement: a repelled attacker returns to its starting
		# tile and nothing is captured. The attempt still costs the action.
		# Reflect goes further — the defender takes the attacker's tile.
		if BuffLogic.reflects_capture(board[to]):
			_consume_buff(to, "reflect")
			_add_float(from, "Reflected!", COL_CAPTURE)
			_lose_player_piece(from, "reflect")
			_add_pop(from)
			board[from] = board[to] # the defender counter-attacks into the tile
			board[from].moved = true # NO-224
			board.erase(to)
		else:
			_consume_buff(to, "shield")
			_add_float(to, "Blocked", COL_MERGE)
		# NO-105 pattern, missed here: bill the same move-percentage the
		# unblocked path charges (line ~2307), off the attacker snapshotted
		# in moving_piece above — board[from] may already be the reflecting
		# defender by this point, moving_piece never is.
		Economy.charge(self, "move_cost",
			Economy.tariff_cut(defs[moving_piece.id].value, Tuning.TARIFF_MOVE_PCT))
		if blitz_free:
			moving_piece.erase("blitz_free_move")
		else:
			actions_left -= 1
		_log_action("capture") # blocked attack — still an attempt against a piece
		moved_this_turn.append(from)
		board[from].moved_wave = wave # Alien Pet Rocks (issue 53): an Action was
			# spent on this attempt, same "moved" idiom as moved_this_turn above
		_clear_selection()
		if actions_left == 0 and state == State.PLAYER_TURN:
			return _on_pass()
		return _refresh()
	if board.has(to): # capture
		var victim: Dictionary = board[to]
		var attacker_buffed := not BuffLogic.of(board[from]).is_empty()
		var capture_pts := Economy.capture_score(self, victim.id, board[from].id, attacker_buffed, from, to) \
			* BuffLogic.capture_multiplier(board, from)
		# Curtain Rods Bag (issue 31): "first Capture each Wave" is only
		# knowable here, right after capture_score() sets last_capture_ctx —
		# wave_capture_index is 0-based, read before Economy.earn runs, so its
		# on_score_change/on_gold_change handlers below can scope to this one
		# call by reason alone (see artefact_hooks.gd's header).
		var earn_reason := "wave_first_capture" if last_capture_ctx.get("wave_capture_index", -1) == 0 else ""
		Economy.earn(self, capture_pts, earn_reason)
		# snapshotted now, before Multicapture (below) can fire a second
		# capture_score call that overwrites g.last_capture_ctx with its own
		# ctx (artefact hook 24 — see artefact_hooks.gd header)
		return_to_start = last_capture_ctx.get("return_to_start", false)
		move_to_backrow = last_capture_ctx.get("move_to_backrow", false)
		var to_stock: bool = last_capture_ctx.get("to_stock", false) # issue 55:
			# Zeta Reticuli Souvenir Map's OUTPUT flag, snapshotted now for the
			# same reason return_to_start/move_to_backrow are — Multicapture
			# below fires its own capture_score call that overwrites
			# g.last_capture_ctx with a fresh ctx for its OWN victim.
		var grant_buffs: Array = last_capture_ctx.get("grant_buffs", [])
		var exhibit_destroys: int = last_capture_ctx.get("exhibit_destroys", 0) # NO-81,
			# snapshotted for the same reason: Multicapture overwrites the ctx
		if BuffLogic.has(board[from], "critical"):
			_consume_buff(from, "critical")
			_add_float(to, "Critical!", COL_MERGE)
		# Range is spent by the capture, not by repositioning
		if BuffLogic.has(board[from], "range"):
			_consume_buff(from, "range")
		# Grant-on-capture (Obedience-Flavored Tap Water, Holy Lint) lands here,
		# AFTER critical/range are consumed above — ruled 2026-08-28: a granted
		# buff is a reward banked for the NEXT capture, not this one. Landing it
		# any earlier let a newly-granted critical double THIS capture (its
		# score multiplier reads board[from] synchronously, right after the
		# on_capture dispatch above) or a newly-granted range get consumed here
		# for zero effect.
		for tier in grant_buffs:
			ArtefactHooks._grant_buff(self, from, tier)
		if BuffLogic.has(victim, "stun"): # cuts both ways
			BuffLogic.add(board[from], "stunned", Tuning.STUN_MISSES + 1)
			_add_float(from, "Stunned!", COL_MERGE)
		if BuffLogic.has(board[from], "multicapture"):
			# one extra enemy beside the piece just taken (ruled 2026-08-28)
			var also := BuffLogic.multicapture_target(board, to, Rules.PLAYER, defs)
			_consume_buff(from, "multicapture")
			if also.x >= 0:
				_add_float(also, "Multicapture!", COL_MERGE)
				Economy.earn(self, Economy.capture_score(self, board[also].id,
					board[from].id, attacker_buffed, from, also))
				if last_capture_ctx.get("to_stock", false): # this call's OWN
						# ctx (issue 55) — read immediately, before anything
						# else can overwrite g.last_capture_ctx again
					_capture_to_stock(board[also])
				else:
					if not Kings.deports_captures(self): # issue 92: The Babylonian Exile
						captured.append(board[also].id)
				lost_enemy += 1
				_add_pop(also)
				board.erase(also)
		# Exhibit 399 (NO-81): after Multicapture, one random adjacent non-King
		# enemy per held copy. _destroy, not a capture: no Score, Gold or
		# Captured Stock, and Shield does not protect the target.
		for i in exhibit_destroys:
			var near: Array[Vector2i] = []
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var at: Vector2i = to + Vector2i(dx, dy)
					if at != to and board.has(at) and board[at].owner == Rules.ENEMY \
							and board[at].id != "king":
						near.append(at)
			if near.is_empty():
				break
			var hit: Vector2i = near[rng.randi() % near.size()]
			_add_float(hit, "Exhibit 399!", COL_CAPTURE)
			_destroy(hit)
		Economy.charge(self, "capture_cost",
			Economy.tariff_cut(defs[victim.id].value, Tuning.TARIFF_CAPTURE_PCT))
		lost_enemy += 1
		if BuffLogic.has(victim, "piece_bounty"): # Bounty (issue 48), enemy
			# half — still your Turn, so the choice pick is safe right here.
			# Fires once, ahead of the bomb/trap/normal branches below so it's
			# never skipped by their own early returns; consumed now while
			# `to` still holds the victim (untouched by score/critical/range/
			# grant-on-capture/stun/multicapture above, none of which read
			# this buff).
			_consume_buff(to, "piece_bounty")
			_open_bounty_pick()
		if victim.id != "king" and (BuffLogic.has(victim, "bomb")
				or BuffLogic.has(board[from], "bomb")):
			# Precedence ruled 2026-08-28: Reflect > Bomb > Trap. Reflect
			# resolved above (the capture never lands); the blast takes the
			# attacker anyway, so Trap has nothing left to do.
			# Consumed before either piece is erased, purely so Cleopatra's
			# Hairpin / Guidestone Blood Ritual see the trigger.
			if BuffLogic.has(victim, "bomb"):
				_consume_buff(to, "bomb")
			if BuffLogic.has(board[from], "bomb"):
				_consume_buff(from, "bomb")
			if to_stock: # issue 55
				_capture_to_stock(victim)
			else:
				if not Kings.deports_captures(self): # issue 92: The Babylonian Exile
					captured.append(victim.id) # the capture itself still resolved
			board.erase(to)
			board[to] = board[from] # the attacker lands, then the blast
			board[to].moved = true # NO-224
			board.erase(from)
			_detonate(to)
			if blitz_free:
				moving_piece.erase("blitz_free_move")
			else:
				actions_left -= 1
			_log_action("capture")
			_kamikaze_after_capture(to)
			if state == State.PLAYER_TURN and (actions_left == 0 or _board_cleared()):
				return _on_pass()
			return _refresh()
		if BuffLogic.has(victim, "trap"): # the attacker goes with it
			_consume_buff(to, "trap") # same reasoning as bomb above
			_add_float(from, "Trapped!", COL_CAPTURE)
			_lose_player_piece(from, "trap")
			_add_pop(from)
			board.erase(from)
			board.erase(to)
			if to_stock: # issue 55
				_capture_to_stock(victim)
			else:
				if not Kings.deports_captures(self): # issue 92: The Babylonian Exile
					captured.append(victim.id)
			if blitz_free:
				moving_piece.erase("blitz_free_move")
			else:
				actions_left -= 1
			_log_action("capture")
			if actions_left == 0 and state == State.PLAYER_TURN:
				return _on_pass()
			return _refresh()
		if victim.id == "king": # boss piece — never enters Captured Stock
			king_captured = true
			captured_king_id = victim.get("king_id", "")
		elif to_stock: # issue 55: Zeta Reticuli Souvenir Map
			_capture_to_stock(victim)
		else:
			captured.append(victim.id)
		_add_pop(to)
	# NO-105: a long-range move pays the Long-Range Tariff INSTEAD of the Move
	# Tariff, but ONLY when Long-Range is actually HELD (user ruling
	# 2026-09-17). Skipping on piece type alone let every slider escape a Move
	# Tariff the player was holding — a queen dispatched "long_range_cost",
	# matched nothing held, and moved free.
	# Suppression counts: while king_abilities_suppressed (Counter-Intel) no
	# tariff charges at all, so Long-Range cannot be the one that fires —
	# Economy.tariff_fires checks that centrally, alongside the held-tariff
	# match itself.
	var mover_value: int = defs[board[from].id].value
	var lr_fires: bool = _is_long_range(board[from].id) \
		and Economy.tariff_fires(self, "long_range_cost")
	if lr_fires:
		var d := to - from
		Economy.charge(self, "long_range_cost",
			Economy.tariff_cut(mover_value, Tuning.TARIFF_LR_PCT) \
				* maxi(absi(d.x), absi(d.y)))
	else:
		Economy.charge(self, "move_cost",
			Economy.tariff_cut(mover_value, Tuning.TARIFF_MOVE_PCT))
	_add_slide(from, to)
	board[to] = board[from]
	board[to].moved = true # NO-224: the initial double-step gates on this
	board.erase(from)
	var skip := Rules.double_step_skip(board[to], from, to, defs) # NO-232
	if skip.x >= 0:
		player_double_steps.append({"pawn": to, "skip": skip, "id": board[to].id})
	var final_pos := to
	if return_to_start: # USS Eldridge Invisibility Paint — undo the slide
		board[from] = board[to]
		board.erase(to)
		_add_slide(to, from)
		final_pos = from
	elif move_to_backrow and to.y != 0: # Royal Fiat (Undamaged) — forced retreat
		var dest := _first_empty_backrow_tile()
		if dest.x >= 0:
			board[dest] = board[to]
			board.erase(to)
			_add_slide(to, dest)
			final_pos = dest
	if blitz_free:
		moving_piece.erase("blitz_free_move")
	elif hounds_free_turn and not did_capture: # Loose the Hounds (67): moves
		# free this Turn, captures still pay — did_capture already excludes
		# every capture that reached this shared branch (repel/bomb/trap
		# captures return early above, each with their own unconditional charge)
		pass
	else:
		actions_left -= 1
	_log_action("capture" if did_capture else "move", {"from": from, "to": final_pos})
		# final_pos, not `to` — USS Eldridge Invisibility Paint/Royal Fiat can
		# reposition the piece after landing; a replay must find it where it
		# actually ended up, not the tile it only passed through
	moved_this_turn.append(final_pos)
	board[final_pos].moved_wave = wave # Alien Pet Rocks (issue 53): an Action
		# was spent moving/capturing — a Deploy or an effect-driven shove
		# (Tactical Reposition/Decoy Swap/Rapid Deployment, all resolved
		# elsewhere in game.gd's _item_apply) never reaches this line
	_clear_selection() # incl. legal_paths — stale shape overlay bug 2026-07-07
	if king_captured or (_king_alive() and Rules.is_checkmate(board, Rules.ENEMY, defs,
			_enemy_denied_tiles(), player_double_steps)): # NO-232
		if _king_down(captured_king_id):
			return
	# last action auto-passes (playtest 2026-07-02); so does clearing the board's
	# last enemy — no point sitting on an empty board (game-feel 2026-07-06)
	if (actions_left == 0 or _board_cleared()) and state == State.PLAYER_TURN:
		return _on_pass()
	_refresh()


## No enemy left, nothing incoming, and more waves to come — the turn is over.
## NO-93: a King wave is not cleared while its King is still to come — without
## this the early-clear path queued the next wave over him.
func _board_cleared() -> bool:
	return not _any_enemy() and pending_spawn.is_empty() and not _king_to_come() \
		and wave < Waves.WAVES.size()


## The wave's King has not landed yet: held for segment 2, or released into
## pending_spawn and waiting for the next spawn. Both wave-advance paths (the
## cadence in _enemy_turn, the early clear in _begin_player_turn) must hold.
func _king_to_come() -> bool:
	return not pending_king.is_empty() or pending_spawn.any(func(e): return e.id == "king")


## Long-range = any non-leap move (ride or bent ride) — the Tariff on
## Long-Range covers every rider, not just bishop/rook (review 2026-07-03).
## NO-224: the Pawn's initial double-step is a `ride` (it slides, so it can't
## jump — same as mW2cF), but it's a 2-square lurch, not what this Tariff is
## for; excluded, or every ordinary pawn move — single-step, diagonal capture
## — would misfire as long-range once the piece definition carries any ride.
func _is_long_range(id: String) -> bool:
	for m in defs[id].moves:
		if m.type != "leap" and not m.get("initial", false):
			return true
	return false


func _king_down(defeated_id := "") -> bool:
	# Benjamin Netanyahu: Iron Dome. Changes the SHAPE of the fight rather than
	# its numbers — clear the escort before the King can be taken at all.
	if Kings.power_is(self, "dome"):
		for pos in board:
			if board[pos].owner == Rules.ENEMY and board[pos].get("id", "") != "king":
				_add_turn_fx("Iron Dome holds", Color(0.6, 0.8, 1.0))
				return false
	kings_defeated += 1
	fx_at = Vector2(hud.wave_label.get_global_rect().get_center())
	Economy.earn(self, Tuning.WIN_SCORE_BONUS)
	var k := Rules.find_king(board, Rules.ENEMY)
	if k.x >= 0: # checkmated, not captured — the boss still leaves the board
		if defeated_id == "":
			defeated_id = board[k].get("king_id", "")
		board.erase(k)
	if defeated_id != "":
		king_ids_defeated.append(defeated_id)
	if wave >= Waves.WAVES.size():
		_game_over(true, "FULL CLEAR — every King has fallen")
		return true
	if kings_defeated == 1:
		if autoplay: # nobody to press Continue; end the run as a win
			_game_over(true, "Wave-%d King checkmated" % wave)
			return true
		_show_win_screen()
		return true
	Economy.add_clock(self, Tuning.KING_CLOCK_REFILL_MS, "king_refill") # recurring King
	_refresh()
	return false


# --- piece preview (long-press a piece anywhere) ---



## The promotion chain containing `id` (base -> ... -> end), or [id].
func _chain_of(id: String) -> Array:
	var prev := {}
	for pid in defs:
		if defs[pid].next != null:
			prev[defs[pid].next] = pid
	var base := id
	while prev.has(base):
		base = prev[base]
	var chain := [base]
	while defs[chain[-1]].next != null:
		chain.append(defs[chain[-1]].next)
	return chain


# NO-139: the diagram renderer moved to its own script, scripts/piece_diagram.gd
# (PieceDiagram.draw), called directly from modals.gd's show_preview.


func _reinforce_ids() -> Array:
	var seen := {}
	var out := []
	for id in Tuning.ARMIES.get(next_army, Tuning.ARMIES[Tuning.DEFAULT_ARMY]):
		if not seen.has(id):
			seen[id] = true
			out.append(id)
	return out


## NO-170 (Max, 2026-09-20, "lets double up each piece, to make it count"):
## the doubled grant list, two of each _reinforce_ids() — pure, touches
## nothing. Split out so `_grant_reinforcements()` (which mutates Stock) and
## save_config.gd's resume display (which must never mutate Stock) build
## their list from the exact same place. Before this split they agreed only
## by coincidence — both independently read _reinforce_ids() and both
## happened to want "one of each" — and doubling broke that coincidence: the
## resume screen kept showing one-of-each while Stock already held two,
## silently under-reporting by half on every background/resume cycle. A
## shared source makes that discrepancy structurally impossible instead of
## just currently absent. `_reinforce_ids()` itself stays one-of-each and
## untouched — autoplay.gd's bot reads it directly for an unrelated pick.
func _reinforce_grant_ids() -> Array:
	var ids := []
	for id in _reinforce_ids():
		ids.append(id)
		ids.append(id)
	return ids


## NO-141: the doubled grant (NO-170) straight into Stock — the same free
## grant the old Buy button made per click (money-and-shop/02), now made
## once, automatically, the instant the screen fires. Returns the ids
## actually granted so the announcement modal's piece mass shows exactly
## what landed in Stock, never fewer.
func _grant_reinforcements() -> Array:
	var ids := _reinforce_grant_ids()
	stock.append_array(ids)
	return ids




func _use_item(index: int) -> void:
	if Kings.power_is(self, "noitems"): # Ivan the Terrible: The Oprichnina
		_add_turn_fx("The Oprichnina: no Items", Color(1.0, 0.5, 0.4))
		return
	if state != State.PLAYER_TURN or box_open:
		return
	if item_active == index: # tap again to cancel targeting
		_item_reset()
		if hud.drawer_open != "inventory": # NO-85 story 58: cancel always reopens
			_set_drawer("inventory")
		else:
			_refresh()
		return
	if hud.drawer_open != "": # using an item hands the board back (targeting)
		_set_drawer("")
	var it: Dictionary = items[index]
	if it.target == "":
		# NO-124: Max's click budget is "select, confirm" for an untargeted
		# Item — arming used to commit on the spot (1 click), one short of
		# that floor. Arm and show the floating Confirm affordance instead;
		# only the affordance actually spends it (autoplay drives no UI, so
		# it still resolves in the one call, same as every other bypass here).
		if autoplay:
			_consume_item(index, it)
			return _item_apply(it, Vector2i(-1, -1), Vector2i(-1, -1))
		item_active = index
		item_stage_a = Vector2i(-1, -1) # NO-121: same "no stale state from a
		item_targets = [] # previous item" guard as the targeted arm below —
		item_pending_tile = Vector2i(-1, -1) # this one just has nothing to stage
		hud.hide_tip()
		_clear_selection()
		placing_id = ""
		_refresh()
		return
	if it.key == "buff_box" and pending_buff == "": # pick the buff, then the target
		item_active = index
		return _open_buff_pick()
	item_active = index
	item_stage_a = Vector2i(-1, -1)
	item_targets = _item_stage_targets(it, Vector2i(-1, -1))
	item_pending_tile = Vector2i(-1, -1) # NO-121: switching items without an
		# explicit cancel first (tap chip B while A is still pending) must not
		# carry A's stale pending tile into B's own targeting
	hud.hide_tip()
	_clear_selection()
	placing_id = ""
	_refresh()


func _item_reset() -> void:
	item_active = -1
	item_stage_a = Vector2i(-1, -1)
	item_targets = []
	item_selected = []
	item_pending_tile = Vector2i(-1, -1) # NO-121
	pending_buff = ""
	hud.hide_tip() # NO-121: a description left over from browsing targets
		# must not outlive the targeting it described


## NO-124: commits an armed, untargeted Item — the floating Confirm
## affordance's handler when the active Item has no target (Counter-Intel,
## Surprise Attack). Mirrors _item_confirm_target/_item_confirm_multi below;
## Cancel needs no button of its own, since tapping the armed chip again
## (_use_item's own "tap again to cancel" branch) already disarms for free.
func _item_confirm_untargeted() -> void:
	if item_active < 0:
		return
	var it: Dictionary = items[item_active]
	if it.target != "":
		return
	_consume_item(item_active, it)
	_item_reset()
	_item_apply(it, Vector2i(-1, -1), Vector2i(-1, -1))


## Return the run to the last state the save schema can represent, so
## backgrounding can snapshot it instead of refusing to.
##
## The first cut of mid-turn resume refused to save while a choice modal or
## targeting was open, on the grounds that the continuation is a Callable and
## cannot be serialised. True, and beside the point (user, 2026-09-08): the
## continuation never needed serialising, because every one of these already
## has a written-down state one step EARLIER — where its own Cancel lands.
## That state is one normal play reaches and saves every day, so rolling back
## to it and saving THERE costs the player one redone decision instead of the
## whole turn. Nothing is replayed forward, so nothing can double-charge.
##
## Rolling back is safe for five of the seven choice callers because nothing is
## paid, consumed or charged when the modal opens — the effect body lives
## entirely in the on_chosen handler (see the Callable() cancels at
## _activate_artefact, _activate_army_ability and _jet_fuel_restock_pressed, and
## _item_reset() for the Buff Box). The two exceptions are the ones whose CALLER
## spent the trigger before opening, so their Cancel would take payment and give
## nothing: those are queued onto the deferral counters instead.
func _rollback_for_save() -> void:
	if buff_pick_open:
		match _choice_on_chosen.get_method():
			"_open_box_pick": # Bounty: its caller already consumed the
				pending_bounty_boxes += 1 # piece_bounty Buff / decremented
					# the counter, and this is the queue that exists for it
			"_yalta_chosen": # the 5-Wave Milestone cannot fire twice
				pending_yalta_picks += 1
		_choice_pick_cancelled()
	if item_active != -1:
		_item_reset() # nothing is consumed at _begin targeting: _consume_item
			# runs only on confirm (NO-124: including an untargeted Item's own
			# confirm now — arming it no longer commits on the spot), never here
	if artefact_targeting_key != "":
		_artefact_targeting_reset()
	if army_targeting:
		_army_targeting_reset()
	if army_board_targeting:
		_army_board_targeting_reset()


## Generic "choose 1 of N, then continue" modal seam (issue 41). `offers` are
## Dictionaries with `label` (button text) and `value` (handed back verbatim
## to `on_chosen`) — the modal and this seam don't know what a caller does
## with the pick. `on_cancelled` is called with no args on Cancel/close; pass
## an invalid Callable if backing out needs no cleanup.
func _open_choice_pick(header: String, offers: Array, cancel_text: String,
		on_chosen: Callable, on_cancelled: Callable) -> void:
	buff_pick_open = true
	_choice_on_chosen = on_chosen
	_choice_on_cancelled = on_cancelled
	modals.show_choice_pick(header, offers, cancel_text)


func _choice_picked(value) -> void:
	buff_pick_open = false
	modals.hide_choice_pick()
	var cb := _choice_on_chosen
	_choice_on_chosen = Callable()
	_choice_on_cancelled = Callable()
	cb.call(value)


func _choice_pick_cancelled() -> void:
	buff_pick_open = false
	modals.hide_choice_pick()
	var cb := _choice_on_cancelled
	_choice_on_chosen = Callable()
	_choice_on_cancelled = Callable()
	if cb.is_valid():
		cb.call()


## Buff Box stage 0: 3 random Piece Buffs, pick one, then target a piece.
## The clock keeps ticking through both (GDD Box Pick). Numbers Station
## Sudoku (+1 choice) / Bohemian Grove Friendship Bracelet (+2) are a plain
## UI change here (issue 23), not a REGISTRY hook — additive per held copy,
## same convention artefact_hooks.gd documents for its own stacking. Riding
## the generic choice-pick seam (issue 41): the Buff Box was never special,
## just first.
func _open_buff_pick() -> void:
	var offer_size := 3 + _artefact_count("numbers-station-sudoku") \
		+ 2 * _artefact_count("bohemian-grove-friendship-bracelet")
	var pool: Array = Items.PIECE_BUFFS.duplicate()
	var offer := []
	for i in mini(offer_size, pool.size()):
		offer.append(pool.pop_at(rng.randi() % pool.size()))
	if autoplay: # bot: take one so the flow is exercised, never stall
		return _buff_chosen(offer[rng.randi() % offer.size()].key)
	var choices := []
	for b in offer:
		choices.append({"label": "%s — %s\n%s" % [b.name, b.tier, b.description],
			"value": b.key})
	_open_choice_pick("✦ Buff Box — pick a Piece Buff:", choices,
		"Cancel (keeps the item)", _buff_chosen, _buff_pick_cancelled)


## Catalogued life of a timed buff, in player turns (0 = dormant).
func _buff_turns(key: String) -> int:
	for b in Items.PIECE_BUFFS:
		if b.key == key:
			return int(b.get("turns", 0))
	return 0


func _buff_chosen(key: String) -> void:
	pending_buff = key
	gold = maxi(gold - 5 * _artefact_count("numbers-station-sudoku"), 0) # "each pick costs 5 Gold"
	var it: Dictionary = items[item_active]
	item_stage_a = Vector2i(-1, -1)
	item_targets = _item_stage_targets(it, Vector2i(-1, -1))
	_clear_selection()
	placing_id = ""
	_refresh()


## Backing out of the buff pick leaves the item unspent, like cancelling any
## other targeting.
func _buff_pick_cancelled() -> void:
	_item_reset()
	if hud.drawer_open != "inventory": # NO-85 story 58: cancel always reopens
		_set_drawer("inventory")
	else:
		_refresh()


## Yalta Cocktail Napkin (issue 44): "On 5-Wave Milestone: choose one — +100
## Gold / +1 Item / +15s Clock". Called from artefact_hooks.gd's on_wave_clear
## dispatch, one call per held copy that hits its own _milestone5_hit beat.
## Autoplay resolves immediately with `rng` instead of opening the modal —
## same pattern as _open_buff_pick / _open_box_pick — so the bot never
## deadlocks on a panel nobody is there to click.
func _open_yalta_pick() -> void:
	if box_open or buff_pick_open: # DEFER rather than drop, for the reason
		pending_yalta_picks += 1 # _open_bounty_pick spells out: a hook on the
		return # same wave clear can already have a modal up, and rendering
			# this on top means the player picks and the pick goes nowhere.
	var offers := [
		{"label": "+$100", "value": "gold"},
		{"label": "+1 Item", "value": "item"},
		{"label": "+15s Clock", "value": "clock"},
	]
	if autoplay:
		return _yalta_chosen(offers[rng.randi() % offers.size()].value)
	_open_choice_pick("✦ Yalta Cocktail Napkin — 5-Wave Milestone, pick one:",
		offers, "Forfeit (no refund)", _yalta_chosen, _yalta_pick_cancelled)


func _yalta_chosen(value: String) -> void:
	match value:
		"gold":
			Economy.earn(self, 100, "yalta-cocktail-napkin")
		"item":
			ArtefactHooks.grant_item(self, Items.ITEMS[rng.randi() % Items.ITEMS.size()]) # NO-103
		"clock":
			Economy.add_clock(self, 15000.0, "yalta-cocktail-napkin")
	_refresh()


## A 5-Wave Milestone reward is not a spend — nothing to refund on Cancel,
## just forfeit it and close (issue 44).
func _yalta_pick_cancelled() -> void:
	pass


## Targeting shim — the item targeting rules live in scripts/item_logic.gd.
## `a` = first pick for "pair" items, or (-1,-1).
func _item_stage_targets(it: Dictionary, a: Vector2i) -> Array[Vector2i]:
	return ItemLogic.stage_targets(board, defs, it.key, a, moved_this_turn)


## NO-121: `key` for hud.show_tip's own toggle-on-repeat — a fresh string
## per tile so browsing to a new target always (re)shows its description,
## never silently no-ops the way re-tapping the exact same row would.
func _item_target_tip(t: Vector2i) -> void:
	if board.has(t):
		hud.show_tip("item-target:%s" % str(t), BuffLogic.describe(board[t].id, board[t], defs),
			Rect2(_tile_px(t), Vector2(self.tile, self.tile)), board[t].id) # NO-152: diagram
	else:
		hud.hide_tip()


func _item_click(tile: Vector2i) -> void:
	var it: Dictionary = items[item_active]
	if it.target == "area": # any tap re-anchors the preview and restages it
		if tile != item_stage_a:
			item_stage_a = tile
			item_targets = _item_stage_targets(it, tile)
	elif not item_targets.has(tile):
		return
	if it.target == "multi": # taps toggle; hud's Extract button confirms
		if item_selected.has(tile):
			item_selected.erase(tile)
		else:
			item_selected.append(tile)
			_item_target_tip(tile)
		_refresh()
		return
	if it.target == "pair" and item_stage_a.x < 0:
		item_stage_a = tile
		item_targets = _item_stage_targets(it, tile)
		_item_target_tip(tile)
		_refresh()
		return
	# NO-124: `tile` is now a complete, confirmable target — a "tile" item's
	# only valid tap, a "pair"'s second pick, or an "area" anchor (fresh or
	# re-anchored, both land here since the branch above never returns early
	# any more). Max's click budget is select/target/confirm, so the old
	# "tap the SAME tile again to open a gate" (NO-121) is gone: stage it and
	# show the floating Confirm affordance right away. A different valid tap
	# just re-stages (the branches above), and only the Confirm affordance
	# actually spends the Item — Economy.charge for ability_cost still fires
	# inside _item_apply, on commit, so a target that's never confirmed costs
	# nothing. autoplay.gd's Buff Box branch is the one caller that drives
	# this single call expecting a full commit (it has no affordance to
	# press), so it still skips straight past the stage.
	if autoplay:
		_consume_item(item_active, it)
		var auto_a := item_stage_a
		_buff_pick = pending_buff
		_item_reset()
		return _item_apply(it, auto_a, tile)
	item_pending_tile = tile
	_item_target_tip(tile)
	_refresh()


## NO-124: commits the target staged in item_pending_tile — the floating
## Confirm affordance's handler (hud.gd's multi_confirm_btn, generalised to
## every targeting shape rather than just "multi"'s own Extract). Cancel
## needs no button of its own: tapping the armed chip again (_use_item)
## already disarms for free, same gesture whether or not a target is staged.
func _item_confirm_target() -> void:
	if item_active < 0 or item_pending_tile.x < 0:
		return
	var it: Dictionary = items[item_active]
	var a := item_stage_a
	var b := item_pending_tile
	_consume_item(item_active, it)
	_buff_pick = pending_buff # _item_reset clears it; the effect still needs it
	_item_reset()
	_item_apply(it, a, b)


## The floating Confirm affordance's handler for a "multi" item's current
## selection (>= 1 picks required) — the same affordance tile/pair/area
## items use for their own final confirm (_item_confirm_target above).
## NO-121 had this open a SECOND confirm-gate modal on top of itself; NO-124
## removes that — pressing the floating button IS the confirm now, matching
## Max's select/target/confirm click budget. autoplay.gd calls this directly
## expecting a full commit (it drives no UI, so there's nothing to confirm).
func _item_confirm_multi() -> void:
	if item_active < 0 or item_selected.is_empty():
		return
	var it: Dictionary = items[item_active]
	_consume_item(item_active, it)
	_extract_sel = item_selected.duplicate()
	_buff_pick = pending_buff
	_item_reset()
	_item_apply(it, Vector2i(-1, -1), Vector2i(-1, -1))


## NO-124: the floating Confirm affordance's single entry point (hud.gd's
## multi_confirm_pressed) — routes to whichever targeting is actually live.
## Item targeting and Bovine Tractor Beam targeting are mutually exclusive
## (_army_ability_available/_artefact_activation_available), so at most one
## branch below is ever reachable.
func _confirm_target_pressed() -> void:
	if item_active >= 0:
		var it: Dictionary = items[item_active]
		if it.target == "multi":
			return _item_confirm_multi()
		if it.target == "":
			return _item_confirm_untargeted()
		return _item_confirm_target()
	if artefact_targeting_key != "":
		_artefact_confirm_target()


## NO-137: the floating Cancel affordance's entry point (hud.gd's
## multi_cancel_pressed) — the same reset either branch's own "tap the armed
## chip again" gesture already used (_use_item/_begin_artefact_targeting),
## just reachable without reopening the Inventory drawer first. Costs
## nothing: Economy.charge only ever runs from _item_apply, on a commit, and
## neither reset below goes near it.
func _confirm_target_cancelled() -> void:
	if item_active >= 0:
		_item_reset()
	elif artefact_targeting_key != "":
		_artefact_targeting_reset()
	else:
		return
	if hud.drawer_open != "inventory": # NO-85 story 58: cancel always reopens
		_set_drawer("inventory")
	else:
		_refresh()


func _item_apply(it: Dictionary, a: Vector2i, b: Vector2i) -> void:
	fx_at = _tile_px(b) + Vector2(tile, tile) / 2 if b.x >= 0 \
		else Vector2(hud.items_grid.get_global_rect().get_center())
	Economy.charge(self, "ability_cost", # on use — a cancelled targeting costs nothing
		Economy.tariff_cut(Tuning.SHOP_ITEM_PRICE[it.tier], Tuning.TARIFF_ITEM_PCT))
	# Nuclear Football Menu (issue 26): Items are free of their Action cost
	# while the Clock is under 60s. Single call site, so no hook needed.
	if not (clock_ms < 60000.0 and _held("nuclear-football-menu")):
		actions_left -= it.get("action_cost", 1) # data-driven (Blitz: 0)
	_log_action("item", {"item": it}) # issue 56: Zapruder's Item-return reads this back
	match it.key:
		"blitz": # Notion 2026-08-28 rework: costs 0 actions itself; the target's
			# NEXT move/capture this Turn is free (_move_player checks the flag).
			# If it already moved, also lift the one-move-per-piece lock so it
			# can genuinely move again — that move is the free one.
			moved_this_turn.erase(b)
			board[b].blitz_free_move = true
		"asset_recovery":
			stock.append(board[b].id) # copy a board piece into stock
		"surprise_attack":
			skip_enemy_turns += 1
		"counter_intel":
			king_abilities_suppressed = true
		"extraction": # selection -> Stock at current id; board-only fields
			# stripped, any remaining piece state rides along (ADR-0002)
			for pos in _extract_sel:
				if board.has(pos) and board[pos].owner == Rules.PLAYER:
					var e: Dictionary = board[pos].duplicate()
					e.erase("owner")
					stock.append(e.id if e.size() == 1 else e)
					board.erase(pos)
		"drone_strike": # 3x3 around b; the King is unaffected (Destruction)
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var hit := b + Vector2i(dx, dy)
					if board.has(hit) and board[hit].id != "king":
						_destroy(hit, true)
		"radar_jamming": # strips target's Piece Buffs (Antikythera Warranty
			# Card: "Piece Buffs cannot be removed by Tariffs or enemy
			# effects" — gates this)
			if not ArtefactHooks.run(self, "on_buff_removal", {"pos": b, "blocked": false}).blocked:
				BuffLogic.clear(board[b])
		"buff_box":
			_apply_buff(board[b], _buff_pick, _buff_turns(_buff_pick), b)
			_add_float(b, BuffLogic.name_of(_buff_pick), COL_MERGE)
			_buff_pick = ""
		"demote":
			# Atlantis Snow Globe / Antikythera Warranty Card: "your pieces
			# cannot be Demoted".
			if not ArtefactHooks.run(self, "on_demote", {"pos": b, "blocked": false}).blocked:
				var old_id: String = board[b].id
				board[b].id = ItemLogic.chain_base(defs, board[b].id)
				ArtefactHooks.run(self, "on_piece_demoted", {"pos": b, "old_id": old_id, "id": board[b].id})
		"promote":
			var old_id: String = board[b].id
			board[b].id = defs[board[b].id].next
			ArtefactHooks.run(self, "on_rank_up",
				{"pos": b, "old_id": old_id, "id": board[b].id, "stock_index": -1})
		"invert":
			board[b].id = "inv-" + board[b].id
		"air_strike", "sniper":
			_destroy(b, true)
		"tactical_reposition", "rapid_deployment":
			_add_slide(a, b)
			board[b] = board[a]
			board.erase(a)
		"decoy_swap":
			var tmp: Dictionary = board[a]
			board[a] = board[b]
			board[b] = tmp
	if _king_alive() and Rules.is_checkmate(board, Rules.ENEMY, defs,
			_enemy_denied_tiles(), player_double_steps): # NO-232
		if _king_down():
			return
	if state == State.PLAYER_TURN and (actions_left == 0 or _board_cleared()):
		return _on_pass() # last action, or the item cleared the last enemy
	_reopen_inventory_if_usable() # NO-85 story 59-60: every item completion
		# funnels through here, so one call covers _item_confirm_untargeted,
		# _item_confirm_target and _item_confirm_multi.
	_refresh()


## On-board tiles within 1 square of `at`, `at` included — the bomb blast
## radius. Shared by `_detonate` (the actual destruction) and `_draw`'s
## blast-preview highlight (NO-122), so the preview can't drift from the
## effect it previews.
func _blast_tiles(at: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var pos := at + Vector2i(dx, dy)
			if Rules.in_bounds(pos):
				out.append(pos)
	return out


## NO-122: every tile the bomb blast preview should wash right now — the
## piece's own blast radius while it's selected (it might stay put and be
## the one captured), plus each legal capture destination's blast radius
## where the blast would actually land (attacker or victim carrying bomb,
## same trigger _detonate's callers use at game.gd:1312-1320/2242-2252). A
## dedicated function, not inlined in `_draw`, so a headless test can assert
## the exact tile set rather than a flag (CLAUDE.md, "tests that pass for
## the wrong reason").
func _bomb_highlight_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if selected.x >= 0 and board.has(selected) and BuffLogic.has(board[selected], "bomb"):
		out.append_array(_blast_tiles(selected))
	for d in legal_dests:
		if board.has(d) and (BuffLogic.has(board[d], "bomb")
				or (board.has(selected) and BuffLogic.has(board[selected], "bomb"))):
			out.append_array(_blast_tiles(d))
	return out


## NO-176: one diagonal family of a hatch over a square target-zone tile —
## the "\" family, or its "/" mirror when `mirror` is true — offset by
## HATCH_SPACING. `r` is always square (board tiles are); closed-form (no
## clipping library): for offset c in [-s, s], the "\" line enters/exits
## whichever pair of edges admits it, and its mirror across the vertical axis
## is the "/" line. `_draw_target_zone` calls this once for ordinary (single)
## zone coverage, and `_draw_crosshatch` below calls it twice — this is the
## shared geometry, split out so a single-covered tile can get one family and
## a doubly-covered tile can get both.
## NO-184: `c`'s start used to be a bare `-s` — correct only because every
## tile's phase then happened to line up (the desktop default `tile` (72) is
## a multiple of HATCH_SPACING (8)); `tile` is recomputed per-viewport in
## _layout_board and is not a multiple of 8 on most real sizes, so adjacent
## tiles' lines landed at different phases and a diagonal run broke at every
## tile boundary. `c` now starts at the smallest value >= -s that lines this
## tile's pattern up with a GLOBAL grid anchored at `board_px` (phase 0) or
## `board_px` shifted by `phase` — so every tile in a zone, of any size,
## draws a continuation of the same board-wide lines. `phase` also carries
## HATCH_BLUE_PHASE (see its comment) for the move-zone caller.
func _draw_hatch(r: Rect2, col: Color, mirror: bool = false, phase: float = 0.0) -> void:
	var s := r.size.x
	var bx := r.position.x - board_px.x # this tile's board-space offset
	var by := r.position.y - board_px.y
	var c: float
	if mirror: # "/" family: board-space invariant is (bx + by)
		c = -s + fposmod(phase - (by + bx), HATCH_SPACING)
	else: # "\" family: board-space invariant is (by - bx)
		c = -s + fposmod(phase - (by - bx) + s, HATCH_SPACING)
	while c <= s:
		var a: Vector2 = Vector2(0, c) if c >= 0 else Vector2(-c, 0)
		var b: Vector2 = Vector2(s - c, s) if c >= 0 else Vector2(s, s + c)
		if mirror:
			draw_line(r.position + Vector2(s - a.x, a.y), r.position + Vector2(s - b.x, b.y), col, HATCH_WIDTH)
		else:
			draw_line(r.position + a, r.position + b, col, HATCH_WIDTH)
		c += HATCH_SPACING


## NO-122: both hatch families over a tile covered by more than one zone, so
## it reads as a denser texture than the single-direction hatch
## `_draw_target_zone` uses for ordinary coverage — direction count is the
## overlap signal (see HATCH_ALPHA's comment), not stacked alpha.
func _draw_crosshatch(r: Rect2, col: Color) -> void:
	_draw_hatch(r, col, false)
	_draw_hatch(r, col, true)


## Bomb blast: everything within 1 square of `at`, the bomb piece included.
## Destruction, not capture (CONTEXT.md) — no score, no Captured Stock, and
## destroyed allies do not return to Stock. The King is unaffected, as with
## Drone Strike.
func _detonate(at: Vector2i) -> void:
	_add_float(at, "Boom!", COL_CAPTURE)
	for pos in _blast_tiles(at):
		if board.has(pos) and board[pos].id != "king":
			_destroy(pos)


## Item destruction: piece leaves the board — no score, no captured stock.
## Fireproof Pajamas (artefact hook 24) vetoes this via _lose_player_piece's
## returned ctx.cancel — the single choke point every Item/Tariff kill
## (Drone Strike, Air Strike, Sniper, bomb detonation via _detonate, the
## jd_vance Tariff) already funnels through. `by_item` (issue 31) is true only
## from the three literal Item call sites (Drone Strike, Air Strike, Sniper)
## — $2.3 Trillion Receipt's "Enemies destroyed by Items award their Score
## and Gold value" is a DELIBERATE exception to "Destruction pays nothing"
## above, scoped exactly to the GDD text: Bomb's _detonate and the jd_vance
## Tariff are not Items, so they stay unpaid, same as ever.
## Hideki Tojo: Kamikaze — a capture costs the capturing piece its neighbour.
## Taxes the ACT of capturing, which no other King does: every other Power taxes
## a resource, this one taxes the move the whole game is built on.
func _kamikaze_after_capture(at: Vector2i) -> void:
	if not Kings.power_is(self, "kamikaze"):
		return
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = at + d
		if board.has(n) and board[n].owner == Rules.PLAYER:
			_add_float(n, "Kamikaze!", COL_CAPTURE)
			_destroy(n)
			return


func _destroy(pos: Vector2i, by_item: bool = false) -> void:
	if board[pos].owner == Rules.PLAYER:
		if _lose_player_piece(pos, "destroyed").cancel:
			return
	else:
		lost_enemy += 1
		if by_item:
			ArtefactHooks.run(self, "on_destroy", {"id": board[pos].id, "value": defs[board[pos].id].value})
	_add_pop(pos)
	board.erase(pos)


## Single choke point for a player piece leaving the board (artefact hook 19)
## — was 5 scattered `lost_player += 1` sites (enemy capture, both Reflect
## directions, both Trap directions, and _destroy above). Each now calls here
## instead, BEFORE the board entry is erased/overwritten, so on_piece_lost
## handlers can still read it (e.g. whether it carried a Piece Buff).
## `attacker_pos` is the enemy piece that did the capturing, when there is one
## (Vector2i(-1,-1) otherwise) — Tutankhamun's Death Thong debuffs it.
## Returns the dispatched ctx (artefact hook 24, was void — the other 4 call
## sites already ignored the return value): `cancel` is Fireproof Pajamas'
## veto (_destroy only), `destroy_attacker` is Hoffa's Cement Shoes' mutual-
## destruction request (the enemy-move loop only). `lost_player` and
## `wave_lost_ids` (issue 26: Jon Burrows' Fake ID / Walt's Cryonic Capsule,
## read on_wave_clear) only count when the loss isn't cancelled.
## `uncounted` (issue 53, 'Definitely Not Russia' Patch — a SECOND, distinct
## flag from `cancel`: the piece is still lost, only hidden from every effect
## reading this hook) is decided HERE, before dispatch, not by a handler
## during it — on_piece_lost's own handlers are one key-sorted pass (header:
## ORDERING), so a handler-set flag would only be visible to whichever
## handlers happen to sort AFTER it. Deciding it up front means every held
## on_piece_lost handler (all of them below check `ctx.uncounted`, same as
## `ctx.cancel`) sees the same verdict regardless of key order.
func _lose_player_piece(pos: Vector2i, reason: String, attacker_pos := Vector2i(-1, -1)) -> Dictionary:
	var uncounted := _artefact_count("definitely-not-russia-patch") > 0 and dnr_patch_wave != wave
	var ctx := ArtefactHooks.run(self, "on_piece_lost",
		{"pos": pos, "id": board[pos].id, "reason": reason, "attacker_pos": attacker_pos,
			"cancel": false, "destroy_attacker": false, "uncounted": uncounted,
			"gold_bonus": 0.0}) # Total War's side-payment channel (Kings.power_hook)
	if uncounted:
		dnr_patch_wave = wave
	if not ctx.cancel and not uncounted:
		lost_player += 1
		wave_lost_ids.append(board[pos].id)
		if ctx.gold_bonus < 0.0: # review pass 2: applied exactly once, here —
			# nothing consumed this channel before, so Total War was inert in play
			Economy.spend_gold(self, -roundi(ctx.gold_bonus))
		if BuffLogic.has(board[pos], "piece_bounty"): # Bounty (issue 48), ally
			# half — queue it, see pending_bounty_boxes' own comment for why
			# this can't open the choice pick here
			_consume_buff(pos, "piece_bounty")
			pending_bounty_boxes += 1
		if Armies.hold_the_line(self): # Old Guard (67): refund the lost
			# piece's full value in Gold. A structural check AFTER dispatch —
			# same shape as lost_player/the bounty buff just above, never a
			# g.gold write from inside a REGISTRY handler (ctx contract).
			# `not ctx.cancel and not uncounted` (this branch's own gate) is
			# the SAME condition every other on_piece_lost side effect here
			# already uses: Fireproof Pajamas' veto and 'Definitely Not
			# Russia' Patch's mask both apply to this refund for free, no
			# separate check needed. Selling never reaches this function at
			# all (_sell erases straight from g.stock and calls
			# Economy.earn_gold on its own) — the "no 150% money printer"
			# safety catch the issue calls out.
			Economy.earn_gold(self, defs[ctx.id].value, "army_hold_the_line")
	return ctx


## Single choke point for a piece's OWN capture ledger (issue 25, split from
## 19 — 3 artefacts read per-piece capture memory, not the run-wide
## wave/turn_capture_count Economy already tracks). `captures` is lifetime and
## rides through Stock round-trips like Piece Buffs already do (ADR-0002: the
## Stock entry is opaque, nothing strips a field it doesn't know about);
## `wave_captures` is reset every Wave in WaveLogic.queue. Both absent = 0.
## Called from Economy.capture_score (the player's own capture, `g._note_
## capture`) and _run_enemy_actions' capture branch above (the enemy's own
## capture, which never goes through capture_score since the enemy doesn't
## score) — the two "a piece's OWN capture resolves" sites issue 25 names.
func _note_capture(pos: Vector2i) -> void:
	board[pos].captures = board[pos].get("captures", 0) + 1
	board[pos].wave_captures = board[pos].get("wave_captures", 0) + 1


## Single choke point for the per-turn action log (issue 30) — the 7 sites
## that already did `turn_action_count += 1` (move, capture, blocked-capture,
## bomb, trap, place, item; merge_logic.gd's commit_merge calls this on `g`)
## now call this instead. Fires `on_action` BEFORE the log/counter update so
## a handler reading `ctx.first` (this being Action #1) can still act on the
## Turn's very first Action — same ordering first_capture_extra/Stargate
## Divination Crystal already rely on for `turn_action_count == 0` (see
## artefact_hooks.gd header). A handler granting an action here (Elvish Hard
## Hat) lands before every call site's own actions_left==0 auto-pass check,
## so it can never resurrect a turn that would otherwise already have ended —
## same shape as Stargate, covered by test_items.gd.
func _log_action(kind: String, data: Dictionary = {}) -> void:
	# issue 103: the Army Ability has THREE commit points — _army_ability_confirmed
	# (untargeted), _army_target_stock (Crown's Stock pick) and
	# _army_board_target_click (Syndicate/Cult) — and counting at only the first
	# would have silently under-reported four of the six Armies. All three call
	# through here, so this is the one place that sees every action kind.
	tally("action:" + kind)
	ArtefactHooks.run(self, "on_action", {"kind": kind, "first": action_log.is_empty()})
	var entry := {"kind": kind}
	entry.merge(data) # issue 52: {from, to} on the plain move/capture site only
	action_log.append(entry)
	turn_action_count += 1


## Single choke point for an Item leaving `items` (artefact hook 19) — was 3
## scattered `items.remove_at` sites. Fires BEFORE removal so a handler can
## veto it via ctx.cancel (Dihydrogen Monoxide Battery, Wardenclyffe AAA
## Batteries: "the Item is not consumed") — the call site only removes when
## the hook leaves ctx.cancel false. `it` is the item dict already looked up
## by the caller (items[index], before it moves).
func _consume_item(index: int, it: Dictionary) -> void:
	var ctx := ArtefactHooks.run(self, "on_item_consume",
		{"key": it.key, "tier": it.get("tier", ""), "last": items.size() == 1, "cancel": false})
	if not ctx.cancel:
		items.remove_at(index)


## Single choke point for granting a Piece Buff (artefact hook 23) — was
## BuffLogic.add called straight from game.gd's buff_box apply and half a
## dozen artefact grants in artefact_hooks.gd. Fires on_buff_apply AFTER the
## buff lands (Pied Piper's Rat Census, mRNA Firmware Update). `pos` is
## Vector2i(-1,-1) for a grant onto a piece not on the board (Stock — Holy
## Grail Coaster's stock-index branch); those handlers just no-op on pos.x<0.
## `fire_hook` is false for Pied Piper's own copy so a copy can never itself
## trigger another copy (would ping-pong between two adjacent allies).
## Debuffs riding the same buffs list (`stunned`) are NOT Piece Buffs and
## call BuffLogic.add directly — they must never reach this choke point.
## Issue 53 (user ruling): a piece already at Piece Buff capacity (base 2,
## Abduction Probe +1/copy) REFUSES the grant — no buff lands, on_buff_apply
## never fires (there's nothing to react to), and every caller here already
## treats this as fire-and-forget, so a refusal is a clean no-op for THEM.
## "Fails cleanly and visibly" is the floating label every other buff-landing
## event already uses (_add_float, same idiom as "Blocked"/"Stunned!" above);
## silent for an off-board grant (pos.x < 0, e.g. Holy Grail Coaster's Stock
## case) — there is no tile to float it at, but the refusal itself still
## holds (still no crash, still no partial state).
func _apply_buff(piece: Dictionary, key: String, turns: int,
		pos := Vector2i(-1, -1), fire_hook := true) -> void:
	if Kings.power_is(self, "purge"): # Stalin: The Purge — no Buffs are gained
		_add_turn_fx("The Purge", Color(1.0, 0.5, 0.4))
		return
	if BuffLogic.catalogued_count(piece) >= buff_cap():
		if pos.x >= 0:
			_add_float(pos, "Buffs full", COL_MERGE)
		return
	BuffLogic.add(piece, key, turns)
	if fire_hook:
		ArtefactHooks.run(self, "on_buff_apply", {"piece": piece, "key": key, "turns": turns, "pos": pos})


## The Piece Buff capacity in force: base + Abduction Probe copies +
## Communion, additive and never deduped (issue 68: Communion — The Cult —
## sums into the SAME cap() call as Abduction Probe, "Communion + Abduction
## Probe = cap 4"). One definition — _apply_buff and merge inheritance
## (NO-191) must never disagree on what the cap is.
func buff_cap() -> int:
	return BuffLogic.cap(_artefact_count("abduction-probe")
			+ (1 if Armies.communion(self) else 0))


## Single choke point for a Piece Buff resolving off the board (artefact hook
## 23) — was 5 scattered BuffLogic.consume call sites (Reflect/Shield x2,
## Critical, Range, Multicapture) plus 2 new ones added alongside this hook
## (Bomb, Trap — previously the carrying piece was just erased with no
## explicit consume, so Cleopatra's Hairpin/Guidestone Blood Ritual never saw
## those triggers). Fires on_buff_consume AFTER removal — no artefact needs
## to veto a buff resolving, so unlike on_item_consume there is no ctx.cancel.
func _consume_buff(pos: Vector2i, key: String) -> void:
	BuffLogic.consume(board[pos], key)
	ArtefactHooks.run(self, "on_buff_consume", {"pos": pos, "key": key})


## Zeta Reticuli Souvenir Map (issue 55): a captured piece diverted to Stock
## instead of Captured Stock, with its state intact — same shape as
## Extraction's own "duplicate, strip owner, bare id if that's all that's
## left" (ADR-0002: Stock never interprets the state, so buffs/capture
## ledger/peak-rank ride along for free, no new schema).
func _capture_to_stock(victim: Dictionary) -> void:
	var e: Dictionary = victim.duplicate()
	e.erase("owner")
	stock.append(e.id if e.size() == 1 else e)


## Held copies of one artefact key — Numbers Station Sudoku / Bohemian Grove
## Friendship Bracelet's Buff Box choice-count is a plain UI change
## (_open_buff_pick), not a REGISTRY hook (issue 23), so it just counts here.
func _artefact_count(key: String) -> int:
	return artefacts.filter(func(a: Dictionary) -> bool: return a.key == key).size()


## Remove exactly ONE held copy of `key` — Epstein's Black Book (49) is the
## first self-consuming Artefact in the catalog, so there's no precedent to
## reuse: every other artefacts.append() site (Shop.buy, _box_choose's own
## artefact grant, save_config.gd) has no matching removal path yet.
func _consume_artefact(key: String) -> void:
	for i in artefacts.size():
		if artefacts[i].key == key:
			artefacts.remove_at(i)
			return


# --- issue 52: Artefact activation — the 7 catalog entries whose GDD text is
# "on use"/"you may pay" instead of a passive hook listener. All 3 entry
# points (the Artefact-strip Activate section, the same section doubling as
# the Items-menu one — this codebase's single Items+Artefacts drawer has no
# second menu to put a distinct copy in — and, Jet Fuel Vial only, the Shop's
# own Restock button) reach the functions below. Deliberately outside
# ArtefactHooks' REGISTRY/run() — that engine dispatches automatically to
# every HELD copy on a hook; activation is "the player picks WHEN, for one
# use," and (Moscovium) must keep working after its own copy is gone from
# g.artefacts, when there is no held copy left for run() to find.

## Held Artefact entry, first match ("" key = none held) — reused for the
## confirm modal's name/description and the once-per-copy Roanoke state.
func _artefact_entry(key: String) -> Dictionary:
	for t in artefacts:
		if t.key == key:
			return t
	return {}


## The 6 in-run activatable keys currently held, in catalog order — empty
## hides the Activate section entirely (user ruling: the drawer must look
## exactly as it does today when nobody holds one of these seven).
func _activatable_held_keys() -> Array:
	var out := []
	for key in ACTIVATABLE_ARTEFACT_KEYS:
		if _held(key):
			out.append(key)
	return out


## Whether `key` has a use available RIGHT NOW — held, your Turn, no other
## activation/Item mid-flight, and not already spent this Turn/Wave (or,
## Oak Island/FIFA Yacht, unaffordable). Shared by the HUD chip's
## enabled/disabled state and the actual activation call, so a stale tap
## between the two can never pay out (acceptance: "must be visibly
## unavailable, not silently inert").
func _artefact_activation_available(key: String) -> bool:
	if not _held(key) or state != State.PLAYER_TURN or box_open or buff_pick_open \
			or win_open or item_active >= 0 or army_targeting or army_board_targeting:
			# issue 67/68: one activation/targeting in flight at a time, either
			# Army Ability targeting flavor included
		return false
	if artefact_targeting_key != "" and artefact_targeting_key != key:
		return false # one activation/targeting in flight at a time
	match key:
		"oak-island-wishing-well":
			return not oak_island_used_this_turn and gold >= 25
		"fifa-complimentary-yacht":
			return gold >= 50 # no per-Turn limit — the deliberate Legendary exception
		"moscovium-glow-stick":
			return true # free, consumed on use — its own limit
		"roanoke-hex-kit":
			return _roanoke_available()
		"zapruder-s-director-s-cut":
			return not zapruder_used_this_wave and _zapruder_available()
		"bovine-tractor-beam":
			return not bovine_used_this_wave and not _enemy_pieces().is_empty() \
					and not Rules.placement_tiles(board).is_empty()
	return false


func _enemy_pieces() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pos in board:
		if board[pos].owner == Rules.ENEMY:
			out.append(pos)
	return out


## Entry point for the 6 in-run keys (Activate section / Items-menu section).
## Bovine Tractor Beam is the one with a target (user ruling: the targeting
## step IS its pause, so it skips the confirm below and cancels from
## targeting instead); the other 5 confirm since an untargeted activation
## resolves the instant it's pressed — that press is the only catchable
## mis-tap.
func _activate_artefact(key: String) -> void:
	if not ACTIVATABLE_ARTEFACT_KEYS.has(key):
		return
	if key == "bovine-tractor-beam":
		return _begin_artefact_targeting(key)
	if not _artefact_activation_available(key):
		return
	if autoplay: # bot: resolve immediately, never stall on the modal (issue 52)
		return _artefact_confirmed(key)
	var entry := _artefact_entry(key)
	_open_choice_pick("✦ %s — activate?\n%s" % [entry.name, entry.description],
		[{"label": "Confirm", "value": key}], "Cancel", _artefact_confirmed, Callable())
		# Callable() on cancel: nothing has been paid/consumed/charged yet (the
		# effect body lives entirely in _artefact_confirmed below), so there is
		# nothing to undo — acceptance: "a cancelled activation costs nothing."


## Only reachable via the Confirm button above — re-checks availability since
## Gold/state can shift between opening the confirm and pressing it.
func _artefact_confirmed(key: String) -> void:
	if not _artefact_activation_available(key):
		return
	tally("artefact_activate") # issue 103: the single commit point both the
		# bot path (_activate_artefact's autoplay branch) and the confirm
		# button reach, so counting here can't double-count or miss one
	match key:
		"oak-island-wishing-well":
			oak_island_used_this_turn = true
			Economy.spend_gold(self, 25)
			Economy.earn(self, 400, "oak-island-wishing-well") # +Score (and its
				# matching Gold, same as every other earn() reward — Yalta
				# Cocktail Napkin's "+100 Gold" choice already does this too)
		"fifa-complimentary-yacht":
			Economy.spend_gold(self, 50)
			actions_left += 1
			actions_max += 1 # mid-turn grant, same shape as first_capture_extra
		"moscovium-glow-stick":
			moscovium_active = true
			_consume_artefact(key)
		"roanoke-hex-kit":
			_roanoke_activate()
		"zapruder-s-director-s-cut":
			zapruder_used_this_wave = true
			_zapruder_resolve()
	_refresh()


## Roanoke Hex Kit: "recharges at every 2nd 5-Wave Milestone" rides the same
## per-copy 5-Wave cadence artefact_hooks.gd's _milestone5_hit uses (each
## copy counts its own 5 waves from its own acquired_wave), but "every 2nd"
## needs a per-copy USE count, not just wave/acquired_wave — milestone N for
## a copy lands at wave = acquired_wave + 5N - 1, so its (used_count+1)-th
## EVEN milestone (the 2nd, 4th, 6th…) lands at
## acquired_wave + 10*(used_count+1) - 1. Stored on the held entry itself
## (each g.artefacts copy is its own Dictionary) rather than round-tripped
## through save_config.gd — an accepted existing gap, same as the other
## per-artefact run-long counters that already aren't (nibiru_wave_streak
## etc., artefact_hooks.gd's header).
func _roanoke_available() -> bool:
	var t := _artefact_entry("roanoke-hex-kit")
	if t.is_empty():
		return false
	var used: int = t.get("roanoke_used_count", 0)
	var target_wave: int = int(t.acquired_wave) + 10 * (used + 1) - 1
	return wave >= target_wave and not _enemy_pieces().is_empty()


func _strongest_enemy_pos() -> Vector2i:
	var best := Vector2i(-1, -1)
	for pos in board:
		if board[pos].owner == Rules.ENEMY and (best.x < 0
				or defs[board[pos].id].value > defs[board[best].id].value):
			best = pos
	return best


## "The strongest enemy piece vanishes, paying no Score or Gold" is
## _destroy-shaped, not a capture — CONTEXT.md's Destruction/Capture split,
## the same rule Bomb/Drone Strike/Air Strike/Sniper already follow.
func _roanoke_activate() -> void:
	var t := _artefact_entry("roanoke-hex-kit")
	if t.is_empty():
		return
	t.roanoke_used_count = t.get("roanoke_used_count", 0) + 1
	var pos := _strongest_enemy_pos()
	if pos.x >= 0:
		_destroy(pos)


## Zapruder's Director's Cut, move/capture half: "repeat your previous Action
## without spending an Action." _log_action (issue 30) only ever recorded
## {kind} — not enough to replay a Deploy (which Stock entry), a Merge (which
## pair) or an Item (which index/targets), and inventing a replay shape for 3
## more action kinds is not what this catalog text asked for. Scoped to
## exactly what the plain move/capture call site in _move_player also stamps:
## {from, to} (the piece's OWN starting tile and where it ACTUALLY ended up —
## final_pos, not a mid-flight tile a repositioning artefact moved it off of
## again). By the time Zapruder can fire, that piece has already moved from
## `from` to `to`, so "repeat" means "make that same displacement again,
## starting from where it is now" — extend the (to - from) vector once more
## and replay it through _move_player itself, so every rule (legality, buffs,
## bombs, scoring) re-runs exactly as a normal move would. `blitz_free_move`
## (Blitz; already reused once for Pegasus Free Trial) skips _move_player's
## own actions_left -= 1 at whichever of its branches this replay hits,
## instead of compensating before/after — a compensating add would
## double-count if _move_player's own auto-pass fired mid-call.
## Bomb/Trap/blocked-attack captures carry no {from, to} and so are correctly
## reported unavailable here, never half-replayed — but a Deploy/Item/Merge
## (issue 56) now has its OWN replacement path; see _zapruder_available below.
func _can_repeat_last_action() -> bool:
	if action_log.is_empty():
		return false
	var last: Dictionary = action_log.back()
	if (last.kind != "move" and last.kind != "capture") \
			or not last.has("from") or not last.has("to"):
		return false
	var from: Vector2i = last.to # the piece's CURRENT position
	if not board.has(from) or board[from].owner != Rules.PLAYER:
		return false
	var again: Vector2i = from + (Vector2i(last.to) - Vector2i(last.from))
	return Rules.moves_for(board, from, defs).has(again)


func _repeat_last_action() -> void:
	var last: Dictionary = action_log.back()
	var from: Vector2i = last.to
	var to: Vector2i = from + (Vector2i(last.to) - Vector2i(last.from))
	board[from].blitz_free_move = true
	_move_player(from, to)


## Zapruder's Director's Cut (issue 56 redesign): "this complements the
## existing replay, it does not replace it" — a move/capture still repeats
## (above); the 3 kinds a replay cannot express instead give back the
## resource the catalog names for each: the Item you just used, the piece you
## just Deployed, or both pieces a Merge just consumed. Availability never
## checks the Item cap (an Item-return activation is always offered — the cap
## only gates whether _zapruder_resolve's grant actually lands, same
## "spent either way" shape as every other full-inventory acquisition path,
## e.g. _box_choose's own ArtefactHooks.grant_item).
func _zapruder_available() -> bool:
	if action_log.is_empty():
		return false
	var last: Dictionary = action_log.back()
	match last.kind:
		"move", "capture":
			return _can_repeat_last_action()
		"item":
			return last.has("item")
		"place":
			return last.has("pos") and board.has(last.pos) and board[last.pos].owner == Rules.PLAYER
		"merge":
			return last.has("pieces")
	return false


func _zapruder_resolve() -> void:
	var last: Dictionary = action_log.back()
	match last.kind:
		"move", "capture":
			_repeat_last_action()
		"item":
			ArtefactHooks.grant_item(self, last.item) # refuses at a full inventory
				# (issue 53) — the once-per-Wave charge above is already spent
				# either way. Routed through grant_item so the returned Item pays
				# Tariff on Item like any other acquisition (user ruling 2026-09-17).
		"place":
			var piece: Dictionary = board[last.pos].duplicate() # same "duplicate,
				# strip owner, bare id if that's all that's left" shape as
				# _capture_to_stock (ADR-0002) — the un-deployed piece's state
				# (buffs, capture ledger, peak-rank) rides along for free
			piece.erase("owner")
			stock.append(piece.id if piece.size() == 1 else piece)
			board.erase(last.pos)
		"merge":
			for piece in last.pieces: # both consumed pieces (user ruling) — the
				# player keeps the merge result too, an accepted duplication
				# bounded by once-per-Wave on a Legendary
				stock.append(piece)


# --- Bovine Tractor Beam: the one targeted activation. Reuses the Item
# targeting FLOW (staged picks, board-click routing, tap-the-chip-again to
# cancel) rather than inventing a second one — see artefact_targeting_key's
# own declaration above for how it parallels item_active.

func _begin_artefact_targeting(key: String) -> void:
	if artefact_targeting_key == key: # tap again to cancel — same shape as _use_item
		_artefact_targeting_reset()
		if hud.drawer_open != "inventory": # NO-85 story 58: cancel always reopens
			return _set_drawer("inventory")
		return _refresh()
	if not _artefact_activation_available(key):
		return
	if hud.drawer_open != "":
		_set_drawer("")
	# Targeting itself is plain board-click state, not a blocking modal, so
	# the bot can drive both picks the same way it drives a "pair" Item — see
	# autoplay.gd's own Bovine branch. NO-121 put a confirm gate behind the
	# second pick (_artefact_target_click), same as an Item; that gate has
	# its own autoplay bypass there, same shape as _item_click's.
	artefact_targeting_key = key
	artefact_target_stage_a = Vector2i(-1, -1)
	artefact_targets = _artefact_stage_targets(key, Vector2i(-1, -1))
	_clear_selection()
	placing_id = ""
	_refresh()


func _artefact_targeting_reset() -> void:
	artefact_targeting_key = ""
	artefact_target_stage_a = Vector2i(-1, -1)
	artefact_targets = []
	artefact_pending_tile = Vector2i(-1, -1) # NO-121
	hud.hide_tip()


## Stage A: any enemy piece. Stage B: an empty tile "on your side of the
## Board" — Rapid Deployment's own Deploy-tile concept (Rules.placement_tiles)
## is the only "your side" notion this codebase already has, so Bovine reuses
## it rather than inventing a second, undefined one.
func _artefact_stage_targets(key: String, a: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if key != "bovine-tractor-beam":
		return out
	if a.x < 0:
		return _enemy_pieces()
	return Rules.placement_tiles(board)


func _artefact_target_click(tile: Vector2i) -> void:
	if not artefact_targets.has(tile):
		return
	if artefact_target_stage_a.x < 0:
		artefact_target_stage_a = tile
		artefact_targets = _artefact_stage_targets(artefact_targeting_key, tile)
		if board.has(tile):
			hud.show_tip("artefact-target:%s" % str(tile),
				BuffLogic.describe(board[tile].id, board[tile], defs),
				Rect2(_tile_px(tile), Vector2(self.tile, self.tile)), board[tile].id) # NO-152: diagram
		_refresh()
		return
	# NO-124: the second pick is now a complete, confirmable target — stage it
	# and show the floating Confirm affordance right away (tile is always
	# empty here, Rules.placement_tiles, so there is never a piece to
	# describe). The old re-tap-the-SAME-tile gate (NO-121) is gone, same
	# change as _item_click's own final tap. autoplay.gd drives both picks
	# itself with no affordance to bypass — same reasoning as _item_click's
	# autoplay branch.
	if autoplay:
		return _commit_artefact_target(artefact_target_stage_a, tile)
	artefact_pending_tile = tile
	_refresh()


## NO-124: commits Bovine Tractor Beam's staged target — the floating
## Confirm affordance's handler while Artefact targeting (rather than Item
## targeting) is active. Cancel needs no button of its own: tapping the
## Activate chip again (_begin_artefact_targeting) already disarms for free.
func _artefact_confirm_target() -> void:
	if artefact_targeting_key == "" or artefact_pending_tile.x < 0:
		return
	_commit_artefact_target(artefact_target_stage_a, artefact_pending_tile)


func _commit_artefact_target(from: Vector2i, to: Vector2i) -> void:
	_artefact_targeting_reset()
	bovine_used_this_wave = true # charged only now — both picks landed; a
		# cancel (re-tapping the Activate chip) never reaches this line
	_add_slide(from, to)
	board[to] = board[from]
	board.erase(from)
	_reopen_inventory_if_usable() # NO-85 story 59-60
	_refresh()


# --- issue 67: the Army Ability. Same Activate-section seam as the 6
# Artefact activations above, deliberately DIFFERENT cost (1 Action, gated
# and spent here — Artefact activation/the Shop are both 0) and back-out
# rule (slice 52): The Muster's Call the Banners has a target, so it skips
# the confirm modal and cancels from targeting like Bovine Tractor Beam;
# Wild Hunt/Old Guard's Abilities are untargeted, so an accidental tap is
# only catchable via a confirm, like Oak Island Wishing Well.

## Mirrors _artefact_activation_available's shape: held (every run always
## holds exactly one Army, unlike an Artefact), your Turn, no other
## activation/targeting/Item mid-flight, not already spent this Wave, and —
## the deliberate contrast with every Artefact activation above — an Action
## to spend. The Muster's Call the Banners additionally needs a Stock entry
## to target.
func _army_ability_available() -> bool:
	if state != State.PLAYER_TURN or box_open or buff_pick_open or win_open \
			or item_active >= 0 or actions_left < 1 or army_ability_used_this_wave:
		return false
	if artefact_targeting_key != "":
		return false # one activation/targeting in flight at a time
	match next_army:
		"Crown":
			return not stock.is_empty()
		"Syndicate": # Hostile Takeover: an enemy piece (King excluded) whose
			# 200% cost the current Gold can actually cover
			return not _affordable_takeover_targets().is_empty()
		"Cult": # Ritual: any of your own pieces to grant the Buff to
			return not _player_pieces().is_empty()
	return true


## Entry point for the HUD chip (game.gd's own hud.army_ability_pressed
## connection, _connect_hud below).
func _activate_army_ability() -> void:
	if next_army == "Crown":
		return _begin_army_targeting()
	if next_army == "Syndicate" or next_army == "Cult": # issue 68: both
		# target the BOARD, so they follow Bovine Tractor Beam's flow
		# (_begin_army_board_targeting) rather than Call the Banners' own
		# Stock-tap one — see that function's own header for why
		return _begin_army_board_targeting()
	if not _army_ability_available():
		return
	if autoplay: # bot: resolve immediately, never stall on the modal (issue 52)
		return _army_ability_confirmed()
	var kit := Armies.entry(next_army)
	_open_choice_pick("✦ %s — activate?\n%s" % [kit.ability_name, kit.ability_desc],
		[{"label": "Confirm", "value": true}], "Cancel",
		func(_v) -> void: _army_ability_confirmed(), Callable())
		# Callable() on cancel: nothing paid/consumed yet — the effect body
		# lives entirely in _army_ability_confirmed, same as
		# _artefact_confirmed's own "a cancelled activation costs nothing"


## Only reachable via Confirm (untargeted) or a completed Stock tap (Muster,
## _army_target_stock below) — re-checks availability since Gold/state/
## actions can shift between opening the confirm and pressing it.
func _army_ability_confirmed() -> void:
	if not _army_ability_available():
		return
	match next_army:
		"Wild Hunt": # Loose the Hounds: this Turn's moves are free; captures
			# still pay (checked at _move_player's own actions_left -= 1 site)
			hounds_free_turn = true
		"Old Guard": # Shield Wall: back two rows (y=0,1) — _apply_buff's own
			# cap refusal floats "Buffs full" per piece already at capacity,
			# which is correct and visible (no special-casing needed here)
			for pos in _player_pieces():
				if pos.y < 2:
					_apply_buff(board[pos], "shield", 0, pos)
		"Horde": # Conscription (issue 68): 2 pawns straight to Stock as bare
			# ids — a freshly conscripted pawn carries no state to preserve
			stock.append("pawn")
			stock.append("pawn")
	army_ability_used_this_wave = true
	actions_left -= 1
	_log_action("army_ability") # a REAL Action spend (unlike Artefact
		# activation, which is 0-cost and deliberately not logged) — this
		# must bump turn_action_count, or a capture made right after
		# activating Loose the Hounds would misread g.turn_action_count == 0
		# and wrongly qualify as "the Turn's first capture" a second time for
		# Blood in the Air / first_capture_extra
	if actions_left == 0 and state == State.PLAYER_TURN:
		return _on_pass()
	_refresh()


# --- The Muster's Call the Banners: the one targeted Army Ability. Not the
# board-targeting flow above (Bovine Tractor Beam) — it targets a STOCK
# entry, tapped off the pool strip, so it reuses _on_stack_pressed's own tap
# routing instead (see the `army_targeting` check at that function's top).

func _begin_army_targeting() -> void:
	if army_targeting: # tap the chip again to cancel — same shape as
		# _begin_artefact_targeting's own "tap again" cancel
		_army_targeting_reset()
		return _refresh()
	if not _army_ability_available():
		return
	if hud.drawer_open != "stock":
		_set_drawer("stock") # the target lives in the Stock strip, not the board
	army_targeting = true
	_clear_selection()
	placing_id = ""
	_refresh()


func _army_targeting_reset() -> void:
	army_targeting = false


## `entry` is the exact g.stock element tapped (ADR-0002: bare id String or a
## Dictionary carrying state) — duplicated VERBATIM into Stock, never
## interpreted, same "Stock never interprets the state" rule that lets
## Asset Recovery/Extraction/Zeta Reticuli Souvenir Map already copy a piece
## into Stock for free. `cap` (a Captured Stock tap) is refused: the Ability
## text is "a target piece from YOUR Stock", not Captured Stock.
func _army_target_stock(entry: Variant, cap: bool) -> void:
	if cap or not stock.has(entry):
		return
	_army_targeting_reset()
	stock.append(entry.duplicate(true) if entry is Dictionary else entry)
	army_ability_used_this_wave = true
	actions_left -= 1
	_log_action("army_ability") # see _army_ability_confirmed's own comment
	if actions_left == 0 and state == State.PLAYER_TURN:
		return _on_pass()
	_refresh()


# --- issue 68: Hostile Takeover (Syndicate) / Ritual (Cult) — the two
# board-targeted Army Abilities. Reuses Bovine Tractor Beam's targeting FLOW
# (staged board pick, board-click routing, tap-the-chip-again to cancel), not
# Call the Banners' Stock-tap one above: the target here lives on the board.
# One stage only (unlike Bovine's two), so no artefact_targeting_key-style
# shared key is needed — army_board_targeting is a bare bool, same
# reasoning army_targeting's own declaration already gives.

## Hostile Takeover: any enemy piece except the King (Air Strike/Sniper
## precedent, item_logic.gd's own "not king" filters) the player can
## currently afford at 200% of its value.
func _affordable_takeover_targets() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pos in _enemy_pieces():
		if board[pos].id != "king" and gold >= defs[board[pos].id].value * 2:
			out.append(pos)
	return out


func _begin_army_board_targeting() -> void:
	if army_board_targeting: # tap the chip again to cancel — same shape as
		# _begin_artefact_targeting's own "tap again" cancel
		_army_board_targeting_reset()
		return _refresh()
	if not _army_ability_available():
		return
	if hud.drawer_open != "":
		_set_drawer("") # the target lives on the board, same as Bovine Tractor Beam
	army_board_targeting = true
	army_board_targets = _army_board_target_tiles()
	_clear_selection()
	placing_id = ""
	_refresh()


func _army_board_targeting_reset() -> void:
	army_board_targeting = false
	army_board_targets = []


func _army_board_target_tiles() -> Array[Vector2i]:
	match next_army:
		"Syndicate":
			return _affordable_takeover_targets()
		"Cult":
			return _player_pieces()
	return []


func _army_board_target_click(tile: Vector2i) -> void:
	if not army_board_targets.has(tile):
		return
	_army_board_targeting_reset()
	match next_army:
		"Syndicate":
			_hostile_takeover_resolve(tile)
		"Cult":
			_ritual_resolve(tile)
	army_ability_used_this_wave = true
	actions_left -= 1
	_log_action("army_ability") # see _army_ability_confirmed's own comment
	if actions_left == 0 and state == State.PLAYER_TURN:
		return _on_pass()
	_refresh()


## Hostile Takeover: a PURCHASE, not a capture (issue 68's explicit ruling) —
## pay 200% of the target's value, then remove it exactly the way every other
## non-Item Destruction already does: _destroy's own by_item=false default —
## no Score, no Gold, no on_capture dispatch, no capture ledger (CONTEXT.md's
## Destruction/Capture split; the same reason Bomb/Drone Strike pay nothing).
## The bare id then joins Stock (state stripped — "you bought the soldier,
## not their buffs," issue 68's own recommendation), the same duplicate/
## strip/bare-id shape _zapruder_resolve's "place" branch and
## _capture_to_stock (ADR-0002) already use. `id` is read before _destroy
## erases the board entry.
func _hostile_takeover_resolve(pos: Vector2i) -> void:
	var id: String = board[pos].id
	Economy.spend_gold(self, defs[id].value * 2)
	_destroy(pos)
	stock.append(id)


## Ritual: a random Buff from the SAFE pool. ArtefactHooks._grant_buff already
## routes through _random_buff_key (never self_harming) and through
## _apply_buff's own cap refusal (Communion's +1 folds into that same call —
## see the comment there), so no special-casing is needed at this call site.
func _ritual_resolve(pos: Vector2i) -> void:
	ArtefactHooks._grant_buff(self, pos)


## Bounty Piece Buff (issue 48): 1-of-3 random Boxes, then the chosen one
## opens via the normal Box flow below. Shared by both halves — the enemy
## half calls this immediately from _move_player's capture block (still your
## Turn, a modal is safe); the ally half defers to _begin_player_turn via
## pending_bounty_boxes (see its own comment). Each offer is its own
## independent Box.random_slot roll (issue 47: contents rolled when offered,
## not at open time), same as Trojan Horse Assembly Manual's single free Box.
## Autoplay resolves immediately with `rng`, same shape as
## _open_buff_pick/_open_yalta_pick, so the bot never stalls on a modal — no
## "decline" consolation either, since forfeiting still spends the trigger
## (the Buff is already consumed by the caller before this runs).
func _open_bounty_pick() -> void:
	# DEFER rather than drop. Both callers spend something immediately before
	# calling — the capture path consumes the piece_bounty buff, the turn-start
	# path decrements pending_bounty_boxes — and another Box can already be open
	# by then, because an artefact hook on the same score change or wave clear
	# can open one first. The 1-of-3 offer would then render on top, the player
	# would choose, and _open_box_pick would refuse to clobber the live Box:
	# payment taken, nothing given, no message.
	#
	# Putting it back on the queue costs the player a turn's delay instead of
	# the reward. It nets out against the caller that just decremented, which is
	# exactly the "extra copies wait for a later Turn" rule this counter exists
	# to express.
	if box_open or buff_pick_open:
		pending_bounty_boxes += 1
		return
	var offer := [Box.random_slot(self), Box.random_slot(self), Box.random_slot(self)]
	if autoplay:
		return _open_box_pick(offer[rng.randi() % offer.size()])
	var choices := []
	for slot in offer:
		var label := "%s %s Box" % [str(slot.size).capitalize(), str(slot.key).capitalize()]
		if _artefact_count("all-seeing-eye-contact-lens") > 0: # X-ray (49):
			# Bounty's 1-of-3 offer sees inside all three before choosing, same
			# as a Shop Box slot — see modals.gd's show_preview for the Shop half.
			label += " (%s)" % Box.contents_names(slot.contents)
		choices.append({"label": label, "value": slot})
	_open_choice_pick("✦ Bounty — choose a Box:", choices, "Forfeit (no box)",
		_open_box_pick, Callable())


# --- box pick (GDD Game Flow — Box Pick; clock keeps ticking, input modal) ---

## `slot` is a shop_stock Box slot ({kind:"box", key:theme, size, contents,
## sold}) — issue 47: contents are rolled once, at Shop-stock time
## (Shop.roll), and stored on the slot. Opening only ever REVEALS box_offer =
## slot.contents, never re-rolls it — that's what makes the stock-time peek
## (a future Artefact) and the eventual open guaranteed to agree.
func _open_box_pick(slot: Dictionary) -> void:
	# A Box already open is a Box being picked from, and every field below is
	# rewritten wholesale — offer, size, kind, picks, rerolls, Black Book. The
	# four artefact hooks that can open a Box all check `not g.box_open` before
	# calling; the Shop's buy path does not, so buying a Box while a Bounty Box
	# was open behind the Shop destroyed the Bounty Box outright. Guarding here
	# covers every caller rather than the three that remembered.
	if box_open:
		return
	box_open = true
	box_only_kind = slot.key
	box_size = slot.size
	var native_picks: int = Box.SIZES[slot.size].picks # Huge grants 2 (issue 47)
	box_picks_left = (native_picks - 1) + _artefact_count("nostradamus-mad-libs")
	box_rerolls_left = _artefact_count("snowden-s-rubik-s-cube") # issue 58: Bible
		# Gag Reel Scroll gained a new effect (Shield-on-capture for the
		# bishop/dragon-horse/archbishop chain) and no longer contributes
		# rerolls — Snowden's Rubik's Cube keeps the Box reroll alone
	box_black_book_pending = false # fresh per-Box (Epstein's Black Book, 49)
	box_offer = slot.contents.duplicate(true)
	if autoplay: # bot: random pick (or skip), and exercise the reroll branch
		# too — every new path must stay inside this branch or the bot deadlocks
		# on a modal nobody is there to click (issue 46)
		if box_only_kind == "item" and not ItemLogic.has_room(self) and rng.randf() < 0.5:
			_sell("item", items[0]) # NO-38: the bot walks the sell path too
		if rng.randf() < 0.1:
			_decline_box_pick()
			return _box_close()
		if box_rerolls_left > 0 and rng.randf() < 0.5:
			box_rerolls_left -= 1
			box_offer = _box_options(box_only_kind, box_size)
		return _box_choose(box_offer[rng.randi() % box_offer.size()])
	modals.show_box(box_offer)


## Thin passthrough to Box.roll_options — a fresh roll for the current Box's
## theme/size, used by a Reroll (below) and by autoplay's own reroll branch
## above. Never called at open time; only stock-time rolling and interactive
## rerolls produce a fresh offer.
func _box_options(theme: String, size: String) -> Array:
	return Box.roll_options(self, theme, size)


func _box_choose(opt: Dictionary) -> void:
	fx_at = get_viewport_rect().size / 2.0
	match opt.kind:
		"piece":
			stock.append(opt.payload) # lands in Stock, like a Shop piece purchase (issue 47)
		"item":
			ArtefactHooks.grant_item(self, opt.payload) # issue 53: refuses at
				# capacity — the Box pick is spent either way (box_offer.erase(opt)
				# below), same "acquisition refused" shape as every other grant
				# path. NO-103: charges Tariff on Item only if it lands.
		"artefact":
			var entry: Dictionary = opt.payload.duplicate() # never mutate the
				# shared catalog Dictionary rolled by Box.roll_options — stamp a
				# per-copy acquisition wave (artefact_hooks.gd's "5-Wave
				# Milestone" cadence) and rarity (issue 29 — Illuminati Fridge
				# Magnet's "every rarity" check)
			entry.acquired_wave = wave
			entry.rarity = ArtefactHooks.rarity_of(entry.key)
			ArtefactHooks.grant(self, entry) # issue 60: refuses at the Artefact
				# cap of 5 — the Box pick is spent either way (box_offer.erase(opt)
				# below), same "acquisition refused" shape as the Item grant above
	# Nostradamus Mad Libs (issue 46) + a Box's own native picks (Huge, issue
	# 47): take an extra pick from what's left of THIS offer, not a fresh
	# roll — stop as soon as either the budget or the offer itself runs out.
	box_offer.erase(opt)
	if box_picks_left > 0 and not box_offer.is_empty():
		box_picks_left -= 1
	elif box_black_book_pending and not box_offer.is_empty():
		# Epstein's Black Book (49): this pick is the one that actually
		# exceeds native + Nostradamus entitlement — the exact "consumed the
		# moment you pick more than you should have" ruling. Spend the held
		# copy now and unlock every remaining item through the SAME budget
		# mechanic (box_picks_left), so "take all contents" falls out of the
		# normal reopen loop instead of a separate atomic-grant path.
		box_black_book_pending = false
		_consume_artefact("epstein-s-black-book")
		box_picks_left = box_offer.size() - 1
	elif not box_offer.is_empty() and _artefact_count("epstein-s-black-book") > 0:
		# Entitlement just ran out. Black Book, while held, offers ONE more
		# free look at what's left WITHOUT spending itself — "take a Big
		# Box's normal 1 pick, and it is NOT consumed — it waits" (issue 49).
		# Only actually taking this look (the elif above, on the next call)
		# spends it; declining it (Skip) leaves it untouched for the next Box.
		box_black_book_pending = true
	else:
		return _box_close()
	if autoplay:
		return _box_choose(box_offer[rng.randi() % box_offer.size()])
	modals.show_box(box_offer) # reopen with what's left — box_open stays untouched


## Snowden's Rubik's Cube (issue 46): "1 reroll of the offer" per held copy,
## stacking additively via box_rerolls_left. (Bible Gag Reel Scroll granted
## the same thing until issue 58 gave it a new effect — Shield-on-capture —
## and dropped out of this counter.) A reroll replaces the offer wholesale
## (not the Nostradamus Mad Libs "pick from what's left"). issue 65 removed
## the Tariff on Box Pick entirely — opening a Box costs no Gold under any
## Tariff state, so there is nothing left for a reroll to re-charge.
func _box_reroll() -> void:
	box_rerolls_left -= 1
	box_offer = _box_options(box_only_kind, box_size)
	modals.show_box(box_offer)


## NO-38 (user ruling 2026-09-08): sell a held Item from inside an open Item
## Box, then re-render the Box so its sell row reflects the room just made.
## Routes through _sell, so Insider Rates, Denver Bunker and the sell tally all
## see it as the sale it is; the Box itself stays open and untouched.
func _box_sell(entry: Dictionary) -> void:
	if _sell("item", entry):
		modals.show_box(box_offer)


func _box_close() -> void:
	box_open = false
	box_panel.visible = false
	_refresh()


## Debug: place the army, spawn wave 1, save a PNG of the board, quit.
## Used by the agent for visual verification (windowed run required).
func _screenshot_and_quit(dir: String) -> void:
	await get_tree().process_frame # let _ready finish first
	var open := _setup_open_tiles()
	while not stock.is_empty() and not open.is_empty():
		_place(stock[rng.randi() % stock.size()], open.pop_at(rng.randi() % open.size()))
	_on_pass()
	await _capture_and_quit(dir)


## Debug: like _screenshot_and_quit, but for a scenario already boarded and
## ready to play — arms a highlight preview instead of placing/passing, so
## the shot proves NO-122's blast/strike zone. Drives the same functions a
## real tap does: `--select X,Y[;X,Y]` calls _on_tile_clicked once per pair,
## in order — a second pair completes a move/capture/merge the first pair's
## selection started, the same two taps a player would make; `--arm-item KEY`
## [`--anchor X,Y`] calls _use_item then _item_click (item arm + anchor);
## `--open-shop` calls _open_shop(); `--open-drawer NAME` calls _set_drawer(NAME)
## ("inventory" or "stock") — NO-119: the Shop and the drawers have no CLI
## reach otherwise, and verifying an off-board grid needs one open.
## `--show-screen NAME` reaches panels no board tap opens on its own:
## "pause" (hud.toggle_menu), "king-abilities" (_show_king_abilities),
## "box" (_open_box_pick on a fresh Box.random_slot — a real Box normally
## takes a Shop purchase or a Bounty capture to reach, neither of which
## --select's two-tap budget can drive), and "tip"/"preview" [`--anchor X,Y`]
## (the long-press description tooltip / the piece-or-King preview modal, for
## the board tile at the anchor) — screenshot capture for a screenshot task
## (2026-09-19), one flag rather than a fourth board-tap-shaped one for each.
## Used by the agent for visual verification (windowed run required — see
## game/CLAUDE.md, "screenshot seam").
func _debug_state_screenshot(dir: String, args: PackedStringArray) -> void:
	await get_tree().process_frame # let _ready finish first
	if args.has("--select"):
		for pair in args[args.find("--select") + 1].split(";"):
			var xy := pair.split(",")
			_on_tile_clicked(Vector2i(int(xy[0]), int(xy[1])))
	elif args.has("--arm-item"):
		var key := args[args.find("--arm-item") + 1]
		for i in items.size():
			if items[i].key == key:
				_use_item(i)
				break
		if args.has("--anchor"):
			var xy := args[args.find("--anchor") + 1].split(",")
			_item_click(Vector2i(int(xy[0]), int(xy[1])))
	elif args.has("--open-shop"):
		_open_shop()
		await get_tree().create_timer(Tuning.PANEL_SLIDE_S).timeout # let the
			# NO-118 slide finish — animations_on defaults true, so the panel
			# is still moving 2 frames after this call returns
	elif args.has("--open-drawer"):
		_set_drawer(args[args.find("--open-drawer") + 1])
		await get_tree().create_timer(Tuning.PANEL_SLIDE_S).timeout
	elif args.has("--show-screen"):
		var screen := args[args.find("--show-screen") + 1]
		if screen == "pause":
			hud.toggle_menu(true)
		elif screen == "king-abilities":
			_show_king_abilities()
		elif screen == "box":
			_open_box_pick(Box.random_slot(self))
		elif (screen == "tip" or screen == "preview") and args.has("--anchor"):
			var xy := args[args.find("--anchor") + 1].split(",")
			var at := Vector2i(int(xy[0]), int(xy[1]))
			if board.has(at):
				if screen == "tip":
					hud.show_tip("board:%s" % str(at),
						BuffLogic.describe(board[at].id, board[at], defs),
						Rect2(_tile_px(at), Vector2(tile, tile)), board[at].id) # NO-152: diagram
				else:
					_show_preview(board[at].id, board[at].get("king_id", ""), null, board[at])
	await _capture_and_quit(dir)


## Shared tail for the two debug screenshot paths above (NO-122): wait for
## the frame just drawn to land, save it, quit. One copy so the two paths
## can't drift apart on how a capture actually happens.
func _capture_and_quit(dir: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(dir) # save_png fails outright if dir is missing
	get_viewport().get_texture().get_image().save_png(dir.path_join("game.png"))
	get_tree().quit()


# --- rendering ---

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for x in Tuning.BOARD_W:
		for y in Tuning.BOARD_H:
			var pos := Vector2i(x, y)
			var rect := Rect2(_tile_px(pos), Vector2(tile, tile))
			draw_rect(rect, COL_LIGHT if (x + y) % 2 == 0 else COL_DARK)
			if y < Tuning.PLAYER_ZONE_ROWS and state == State.SETUP and not board.has(pos):
				draw_rect(rect, Color(0.2, 0.5, 0.9, 0.25))
	# whose-turn outline around the board (game-feel pass 2026-07-06)
	var oc := Color(0.5, 0.5, 0.5)
	if state == State.PLAYER_TURN:
		oc = Color(0.45, 0.7, 1.0)
	elif state == State.ENEMY_TURN:
		oc = Color(1.0, 0.42, 0.35)
	var bsize := Vector2(Tuning.BOARD_W, Tuning.BOARD_H) * tile
	draw_rect(Rect2(board_px - Vector2(BOARD_OUTLINE_INSET, BOARD_OUTLINE_INSET),
		bsize + Vector2(BOARD_OUTLINE_INSET, BOARD_OUTLINE_INSET) * 2.0), oc, false,
		BOARD_OUTLINE_WIDTH)
	var recon: bool = selected.x >= 0 and board.has(selected) \
			and board[selected].owner == Rules.ENEMY
	if selected.x >= 0: # enemy recon selections tint red, own selections blue
		draw_rect(Rect2(_tile_px(selected), Vector2(tile, tile)),
			Color(COL_CAPTURE, 0.3) if recon else COL_SELECT)
	if not merge_highlights.is_empty(): # cyan ring: merges with the selection
		for pos in board:
			if board[pos].owner == Rules.PLAYER and pos != selected \
					and merge_highlights.has(board[pos].id):
				draw_arc(_tile_px(pos) + Vector2(tile, tile) / 2, tile * 0.46, 0, TAU, 24,
					COL_MERGE, 3.0)
	# NO-176: explicit draw order — red over purple over blue. The reachable
	# zone's own outline below (blue move edges, red capture edges, purple
	# where the two meet inside the same zone — NO-161) is drawn FIRST, as
	# the bottom layer; the
	# bomb-blast preview and armed-Item zone are pure red and are drawn
	# AFTER, on top, so a red capture edge is never hidden beneath a blue
	# move edge where the two zones' tiles coincide (the bomb highlight in
	# particular can share tiles with legal_dests — a capture destination
	# that also carries a bomb is in both sets). NO-183: the move/capture
	# indicator arrows/dots below and Arrow Planning's own overlay (drawn
	# last in this function) both come AFTER every hatch call above and
	# below this comment, so an arrow always draws over a hatch fill, never
	# under one.
	# recon (enemy) paths draw red; the player's draw blue (palette rule)
	var half := Vector2(tile, tile) / 2
	var capture_dests: Array[Vector2i] = [] # NO-161: legal_dests is drawn as
		# one outline shape, but the tiles with an enemy piece on them need
		# to be told apart from a plain move destination
	var no_captures: Array[Vector2i] = [] # NO-161 fix: a bare `[]` literal
		# inline in the ternary below is an UNTYPED Array — GDScript does not
		# infer the expected Array[Vector2i] from the argument position
		# through a conditional expression, so passing it threw
		# "Invalid type in function '_draw_zone_outline'... argument 4" on
		# every recon-selection frame. A separately DECLARED typed variable
		# carries its element type at runtime regardless of which ternary
		# branch is taken.
	for d in legal_dests:
		var d_rect := Rect2(_tile_px(d), Vector2(tile, tile))
		if board.has(d): # capturable target: red hatch, same family as the
			# move hatch below (phase 0.0, "\" direction — matches the other
			# COL_CAPTURE hatches, e.g. the bomb/Item zone, so a tile in both
			# sets doesn't fight itself). Max overruled NO-183's flat tint
			# ("capture squares don't seem to have the red hatch") — dropped it
			# rather than layering hatch on top, so captures read as the red
			# twin of the blue move hatch below, not a heavier, differently
			# styled tile.
			_draw_hatch(d_rect, Color(COL_CAPTURE, HATCH_ALPHA))
			capture_dests.append(d)
		else: # NO-184: move destination — a hatch fill, parity with the red
			# bomb/Item zone below (previously outline-only). Recon zones stay
			# uniform COL_ENEMY like their outline and phase 0 (same family as
			# a bomb/Item zone, so a double-red tile still reads as coverage,
			# not an offset); the player's own zone gets HATCH_BLUE_PHASE so a
			# coincident red bomb/Item hatch interleaves instead of stacking
			# (Max's ruling — an offset, not a second direction).
			_draw_hatch(d_rect,
				Color(COL_ENEMY, HATCH_ALPHA) if recon else Color(COL_ZONE_OUTLINE_MOVE, HATCH_ALPHA),
				false, 0.0 if recon else HATCH_BLUE_PHASE)
	# NO-129: one outline around the whole reachable zone, so a spread of
	# move/capture squares reads as a shape rather than each square drawn on
	# its own — reused by NO-130's _draw_target_zone for the bomb blast
	# preview and an armed Item's zone. NO-161: capture tiles draw red
	# instead of blue and a move/capture boundary reads purple (see
	# _draw_zone_outline); recon (enemy) zones are left as one uniform
	# COL_ENEMY shape — the ticket's blue-vs-red contrast doesn't apply to a
	# zone that's already all red, and there's no third recon-only colour to
	# reach for without inventing one nothing asked for.
	if not legal_dests.is_empty():
		var arrowed := {} # tiles a ride's own solid arrow will draw over —
			# the NO-150 diagonal bridge below draws an identical colinear
			# line the full length of a diagonal ride (straight rides never
			# trigger it: consecutive axis-aligned tiles share a real edge,
			# so the bridge loop's "already joined" check always skips them),
			# and that line sits UNDER the translucent arrow, visible through
			# it. Max: "diagonal arrows are still showing the arrow body
			# visible underneath the arrow head, you did fix this for the
			# arrows going straight" — the straight case was already clean
			# for exactly this reason, nothing to do with _draw_move_arrow's
			# own geometry (verified unchanged and correct by the same
			# convexity argument piece_diagram.gd's port confirmed on
			# screen).
		if not (state == State.SETUP or legal_paths.is_empty()):
			for p in legal_paths:
				if p.kind == "ride" and not p.get("hop", false):
					for t in p.line:
						arrowed[t] = true
		_draw_zone_outline(legal_dests, Color(COL_ENEMY, ZONE_OUTLINE_ALPHA) if recon \
				else Color(COL_ZONE_OUTLINE_MOVE, ZONE_OUTLINE_ALPHA),
			ZONE_OUTLINE_WIDTH, no_captures if recon else capture_dests, arrowed)
	_draw_target_zone(_bomb_highlight_tiles()) # NO-122/176 hatch, NO-130
		# shared — drawn after the zone outline above (see NO-176 comment)
	if item_active >= 0: # item targeting: same zone indicator as the bomb
		_draw_target_zone(item_targets) # NO-130: "what this will affect"
		if item_stage_a.x >= 0:
			draw_rect(Rect2(_tile_px(item_stage_a), Vector2(tile, tile)), COL_SELECT)
		for s in item_selected: # multi picks fill like the stage-A tile
			draw_rect(Rect2(_tile_px(s), Vector2(tile, tile)), COL_SELECT)
		if item_pending_tile.x >= 0: # NO-121: one more tap confirms this one —
			# the same ring merge partners use, so "this completes it" reads
			# consistently across both flows
			draw_arc(_tile_px(item_pending_tile) + Vector2(tile, tile) / 2, tile * 0.46, 0, TAU, 24,
				COL_MERGE, 3.0)
	if artefact_pending_tile.x >= 0: # NO-121: Bovine Tractor Beam's own pending pick
		draw_arc(_tile_px(artefact_pending_tile) + Vector2(tile, tile) / 2, tile * 0.46, 0, TAU, 24,
			COL_MERGE, 3.0)
	if state == State.SETUP or legal_paths.is_empty():
		for d in legal_dests: # setup relocation / placement targets: plain dots
			if not board.has(d):
				draw_circle(_tile_px(d) + half, 8, COL_PLACE)
	else:
		# movement by shape: rides = arrows, bent rides / hop-riders = dots
		# linked by a line (game-feel 2026-07-07). NO-183: a leap destination
		# used to get its own dot here too — removed as a duplicate now that
		# NO-184 hatch-fills every move tile in legal_dests (see the loop
		# above); a bent/hop path keeps its linked dots because those trace
		# the path's SHAPE, information the zone hatch doesn't carry.
		var col := Color(COL_ENEMY, MOVE_INDICATOR_ALPHA) if recon else Color(COL_MOVE, MOVE_INDICATOR_ALPHA)
		for p in legal_paths:
			match p.kind:
				"ride":
					if p.get("hop", false): # leap-rider: linked dots, not a slide
						_draw_linked_dots(_tile_px(selected) + half, p.line, col)
					else:
						_draw_move_arrow(_tile_px(selected) + half,
							_tile_px(p.line[-1]) + half, col)
				"bent":
					_draw_linked_dots(_tile_px(selected) + half, p.line, col)
	for t in _deploy_highlight_tiles():
		draw_circle(_tile_px(t) + Vector2(tile, tile) / 2, 8, COL_PLACE)
	var sliding := {} # tiles whose piece is mid-slide (drawn at the lerp instead)
	for a in anims:
		if a.kind == "move":
			sliding[a.to] = a
	for pos in board:
		if sliding.has(pos):
			continue
		var p: Dictionary = board[pos]
		var px := _tile_px(pos)
		var tint := Color.WHITE # side colour lives in the art; _draw_piece tints mono tokens
		if pos == drag_from:
			tint.a = 0.35 # ghost follows the cursor instead
		elif state == State.PLAYER_TURN and moved_this_turn.has(pos):
			tint = Color(0.75, 0.75, 0.75) # spent this turn
		# the selected piece draws bigger, with a pulsing outline (below)
		_draw_piece(font, p, px, tint, SELECTED_INSET if pos == selected else -2.0)
	for a in anims:
		if a.kind == "move" and board.has(a.to):
			var mp: Dictionary = board[a.to]
			_draw_piece(font, mp, a.from_px.lerp(a.to_px, ease(a.t, 0.4)), Color.WHITE)
		elif a.kind == "pop":
			draw_arc(a.at_px, tile * (0.2 + 0.3 * a.t), 0, TAU, 24, Color(COL_CAPTURE, 1.0 - a.t), 4.0)
		elif a.kind == "text": # score gains/losses float up and fade
			draw_string(font, a.at_px + Vector2(0, -20.0 * a.t), a.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(a.color, 1.0 - a.t))
		elif a.kind == "outline": # turn-switch glow expanding off the border
			var grow: float = 4.0 + 12.0 * a.t
			draw_rect(Rect2(board_px - Vector2(grow, grow),
				Vector2(Tuning.BOARD_W, Tuning.BOARD_H) * tile + Vector2(grow, grow) * 2),
				Color(a.color, 1.0 - a.t), false, 5.0)
		elif a.kind == "banner": # turn/wave strip: wipes in, holds, fades out
			var br := _banner_rect(a.t, a.get("slot", 0))
			if br.size.x <= 0.0:
				continue # not emerged yet
			var alpha: float = minf(1.0, 4.0 * (1.0 - a.t))
			draw_rect(br, Color(0.06, 0.06, 0.09, 0.78 * alpha))
			draw_string(font, Vector2(br.position.x, br.position.y + 31), a.text,
				HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 26, Color(a.color, alpha))
	if drag_from.x >= 0 and board.has(drag_from) and textures.has(board[drag_from].id):
		draw_texture_rect(piece_tex(board[drag_from].id, board[drag_from].owner),
			Rect2(get_global_mouse_position() - Vector2(tile, tile) * 0.5, Vector2(tile, tile)), false, Color(1, 1, 1, 0.85))
	if pool_drag_id != "" and textures.has(pool_drag_id): # stock drag ghost
		draw_texture_rect(piece_tex(pool_drag_id),
			Rect2(get_global_mouse_position() - Vector2(tile, tile) * 0.5, Vector2(tile, tile)), false, Color(1, 1, 1, 0.85))
	# Arrow Planning: drawn last so the decorative overlay always sits on top;
	# arrows persist independent of arrow_mode (toggling off just stops adding
	# more) and are cleared at turn end (scratchpad, never saved)
	for a in arrows:
		_draw_move_arrow(_tile_px(a.from) + half, _tile_px(a.to) + half, COL_ARROW, 3.0, 14.0, 8.0)
	if arrow_from.x >= 0:
		var arrow_cur := _tile_at(get_global_mouse_position())
		if arrow_cur.x >= 0 and arrow_cur != arrow_from:
			_draw_move_arrow(_tile_px(arrow_from) + half, _tile_px(arrow_cur) + half, COL_ARROW, 3.0, 14.0, 8.0)


## NO-130: "this is what the thing you are holding will affect" — a
## COL_CAPTURE HATCH per tile (NO-176: was a flat wash), a denser CROSSHATCH
## where more than one zone covers the same tile (NO-122), and the perimeter
## outline below (NO-129) so a spread reads as one shape. Shared by the bomb
## blast preview and an armed Item's target zone: one indicator, one meaning,
## one place to change it.
func _draw_target_zone(tiles: Array[Vector2i]) -> void:
	if tiles.is_empty():
		return
	var counts := {} # tile -> how many zones cover it
	var unique: Array[Vector2i] = [] # deduped, so an overlap tile's own
		# perimeter edges aren't drawn (and alpha-stacked) twice below
	for pos in tiles:
		if not counts.has(pos):
			unique.append(pos)
		counts[pos] = counts.get(pos, 0) + 1
	var hatch_col := Color(COL_CAPTURE, HATCH_ALPHA)
	for pos in unique:
		var r := Rect2(_tile_px(pos), Vector2(tile, tile))
		if counts[pos] > 1: # overlap: the denser two-direction crosshatch
			_draw_crosshatch(r, hatch_col)
		else: # NO-176: single coverage — one hatch direction, not a wash
			_draw_hatch(r, hatch_col)
	_draw_zone_outline(unique, Color(COL_CAPTURE, ZONE_OUTLINE_ALPHA))


## NO-129: outlines the PERIMETER of a tile set as one shape — an edge is
## drawn only where a tile's neighbour is outside the set, so a spread of
## squares reads as a silhouette instead of each square boxed on its own
## (which read as scattered marks). NO-150 adds diagonal bridging below, so
## a ride's corner-touching tiles read as one band too. Reusable: NO-130's
## `_draw_target_zone` calls this for both the bomb blast preview and an
## armed Item's zone.
func _draw_zone_outline(tiles: Array[Vector2i], col: Color, width := ZONE_OUTLINE_WIDTH,
		captures: Array[Vector2i] = [], no_bridge: Dictionary = {}) -> void:
	# NO-161: `captures` is the subset of `tiles` whose outline should be red
	# instead of `col`. An edge between two tiles that are BOTH in `tiles`
	# but disagree on capture-ness (one is, one isn't) is a boundary inside
	# the zone that neither a pure-blue nor a pure-red outline owns alone —
	# drawn once in COL_ZONE_OUTLINE_OVERLAP. Empty by default, so the
	# bomb-blast/Item-zone caller (already one uniform red shape) is
	# unchanged: every `captures.has(...)` below is then always false.
	var capture_col := Color(COL_CAPTURE, ZONE_OUTLINE_ALPHA)
	var overlap_col := Color(COL_ZONE_OUTLINE_OVERLAP, ZONE_OUTLINE_OVERLAP_ALPHA)
	for t in tiles:
		var px := _tile_px(t)
		var t_cap := captures.has(t)
		var above := Vector2i(t.x, t.y + 1)
		var below := Vector2i(t.x, t.y - 1)
		var left := Vector2i(t.x - 1, t.y)
		var right := Vector2i(t.x + 1, t.y)
		# NO-176: an internal boundary edge (both `t` and its neighbour are in
		# `tiles`, disagreeing on capture-ness) sits between exactly two
		# tiles and is reachable from EITHER side's check — from `t`'s
		# "above"/"right" here, or from the neighbour's own "below"/"left"
		# below. Drawing it from both sides put the same segment down twice:
		# same colour, so invisible at the old ZONE_OUTLINE_ALPHA 0.9, but a
		# real double composite once alpha dropped to 0.6 for this ticket —
		# exactly the "lines stacking and looking weird" Max's caveat named.
		# Only the "below"/"left" side draws the disagreement case; "above"/
		# "right" only ever draws the perimeter case (no matching tile).
		if not tiles.has(above): # nothing above on screen
			draw_line(px, px + Vector2(tile, 0), capture_col if t_cap else col, width)
		if not tiles.has(below): # nothing below
			draw_line(px + Vector2(0, tile), px + Vector2(tile, tile), capture_col if t_cap else col, width)
		elif captures.has(below) != t_cap:
			draw_line(px + Vector2(0, tile), px + Vector2(tile, tile), overlap_col, width)
		if not tiles.has(left): # nothing to the left
			draw_line(px, px + Vector2(0, tile), capture_col if t_cap else col, width)
		elif captures.has(left) != t_cap:
			draw_line(px, px + Vector2(0, tile), overlap_col, width)
		if not tiles.has(right): # nothing to the right
			draw_line(px + Vector2(tile, 0), px + Vector2(tile, tile), capture_col if t_cap else col, width)
	# NO-150: a diagonal ride's tiles touch only at one corner each, so the
	# four edge checks above box every tile separately — a staircase, not a
	# band (raised at NO-129 review, deliberately left; Max asked for it
	# fixed 2026-09-19). Two squares sharing a single point have no simple
	# (non-self-intersecting) outline that reads as joined without either
	# the crossing edges this already draws, or inflating the tiles into
	# real overlap — tried both by hand before writing this and neither is
	# a small change. So this bridges the pinch instead of tracing it: for
	# every corner-only diagonal touch (no orthogonal tile linking them),
	# stroke straight through both tiles' centres. Consecutive centres along
	# a ride are exactly collinear, so a whole diagonal draws as one
	# unbroken line rather than a dashed approximation of one.
	var half := Vector2(tile, tile) * 0.5
	for t in tiles:
		var t_cap := captures.has(t)
		for d in [Vector2i(1, -1), Vector2i(1, 1)]: # NE + SE catches every
			# diagonal pair exactly once: a tile's SW/NW touch is its
			# neighbour's own NE/SE, checked from that neighbour instead.
			var diag: Vector2i = t + d
			if not tiles.has(diag):
				continue
			if tiles.has(Vector2i(t.x + d.x, t.y)) or tiles.has(Vector2i(t.x, t.y + d.y)):
				continue # already joined by a real shared edge — no pinch
			if no_bridge.has(t) and no_bridge.has(diag):
				continue # a ride's own solid arrow already draws this exact
				# segment on top of the zone — this stroke would just
				# duplicate it, underneath a translucent arrow it shows
				# through (see the call site's comment)
			var diag_cap := captures.has(diag)
			var bridge_col: Color = overlap_col if diag_cap != t_cap \
					else (capture_col if t_cap else col) # NO-161: same
				# move/capture/overlap classification as the edges above
			draw_line(_tile_px(t) + half, _tile_px(diag) + half, bridge_col, width)


## The animated outline around the selected piece — drawn by `_pulse`, a
## child canvas item that is the only thing redrawn per frame while
## something is selected (the board itself only redraws on state changes).
## NO-199: replaces NO-183's ring (a flat circle, never the piece's own
## shape — Max: "the circle is not it") with SELECT_OUTLINE_SHADER tracing
## the selected token's own alpha silhouette, at the SAME enlarged rect the
## board draw loop already gives the selected piece (SELECTED_INSET). Colour
## still distinguishes a recon (enemy) selection from your own, and the old
## breathing alpha is kept — both bands fade together rather than dropping
## the pulse silently.
func _draw_pulse() -> void:
	if selected.x < 0 or not board.has(selected):
		return
	var p: Dictionary = board[selected]
	if not textures.has(p.id):
		return # ponytail: glyph-fallback piece (no PNG) — no silhouette to trace
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	var pulse_a := SELECT_OUTLINE_ALPHA_MIN + SELECT_OUTLINE_ALPHA_RANGE * pulse
	var size := tile - SELECTED_INSET * 2 # the TOKEN's own on-screen size. The
		# shader's UV space always spans exactly this (see canvas_rect below),
		# so reach stays in these units no matter how much extra canvas the
		# draw call gives the dilation room to spill into.
	var mat: ShaderMaterial = _pulse.material
	# Max, 2026-09-21: one purple for every selection, not blue/red by side —
	# the rim has to read AGAINST the blue move zone and the red capture zone
	# it sits inside, so it cannot be either of them. COL_ZONE_OUTLINE_OVERLAP
	# is the purple this board already uses; reused rather than a second one.
	mat.set_shader_parameter("rim_color",
		Color(COL_ZONE_OUTLINE_OVERLAP, pulse_a * SELECT_OUTLINE_RIM_ALPHA))
	mat.set_shader_parameter("fill_color", Color(BUFF_BADGE_BG, pulse_a))
	mat.set_shader_parameter("fill_reach", (SELECT_OUTLINE_WIDTH - SELECT_OUTLINE_RIM) / size)
	mat.set_shader_parameter("rim_reach", SELECT_OUTLINE_WIDTH / size)
	# Max, 2026-09-21 (2nd pass): raising SELECT_OUTLINE_WIDTH to 6 made the
	# dilated aura reach past the piece's own draw rect — clipped flat top and
	# bottom. The shader dilates OUTWARD from the token's alpha in UV space,
	# but a plain draw_texture_rect(tex, rect) maps UV[0,1] onto `rect`
	# exactly, so anything the dilation pushes past that rect's edge was never
	# drawn. Fix: grow the CANVAS by SELECT_OUTLINE_WIDTH on every side via
	# draw_texture_rect_region with a matching padded src_rect (in TEXTURE
	# pixels, at the token's own draw scale) and clamp_uv off. The four real
	# texture corners still land on the same screen pixels as before — the
	# silhouette neither moves nor rescales, only the margin around it grows —
	# and that margin gets genuine UV values outside [0,1] for the dilation to
	# spill into, which _alpha_at's existing out-of-bounds-is-transparent
	# guard already handles correctly (it was written for UV overflow at the
	# piece's own edge; this just gives it more of it to do the same thing).
	var tex := piece_tex(p.id, p.owner)
	var tex_size := tex.get_size()
	var margin := tex_size * (SELECT_OUTLINE_WIDTH / size)
	var canvas_rect := Rect2(
		_tile_px(selected) + Vector2(SELECTED_INSET, SELECTED_INSET) - Vector2(SELECT_OUTLINE_WIDTH, SELECT_OUTLINE_WIDTH),
		Vector2(size, size) + Vector2(SELECT_OUTLINE_WIDTH, SELECT_OUTLINE_WIDTH) * 2)
	var src_rect := Rect2(-margin, tex_size + margin * 2)
	_pulse.draw_texture_rect_region(tex, canvas_rect, src_rect, Color(1, 1, 1, 1), false, false)


## Token art for a piece; the player token unless a side is named.
func piece_tex(id: String, owner := Rules.PLAYER) -> Texture2D:
	return textures[id][owner]


## NO-146: the same lookup, usable BEFORE any Game exists — the menu's Army
## carousel shows starting-fleet art with no live Game to read `textures`
## from. Same file-probing rule as the `_ready()` loop above that populates
## `textures`: a painted <id>-light/-dark pair first, the shared monochrome
## <id>.svg second. Never indexes `textures` — this is a fresh, independent
## lookup for a context that has none.
static func load_piece_tex(id: String, owner := Rules.PLAYER) -> Texture2D:
	var side := "light" if owner == Rules.PLAYER else "dark"
	var painted := "res://assets/pieces/%s-%s.png" % [id, side]
	if ResourceLoader.exists(painted):
		return load(painted)
	var mono := "res://assets/pieces/%s.svg" % id
	return load(mono) if ResourceLoader.exists(mono) else null


## Whether `id` is on the shared-monochrome fallback path and so needs the
## side tint (COL_SIDE_PLAYER/COL_SIDE_ENEMY) applied at draw time — mirrors
## `mono_art` above, for a caller with no live Game to read it from.
static func is_mono_piece(id: String) -> bool:
	return not ResourceLoader.exists("res://assets/pieces/%s-light.png" % id)


## `inset` is negative on purpose: the painted tokens read better slightly
## overflowing their square than padded inside it (user call 2026-08-27).
func _draw_piece(font: Font, p: Dictionary, px: Vector2, tint: Color, inset := -2.0) -> void:
	if textures.has(p.id):
		# `tint` carries state only (spent grey, ghost alpha); a monochrome
		# token still needs the blue/red side shift multiplied in
		var col := tint
		if mono_art.has(p.id):
			col *= COL_SIDE_PLAYER if p.owner == Rules.PLAYER else COL_SIDE_ENEMY
		draw_texture_rect(piece_tex(p.id, p.owner),
			Rect2(px + Vector2(inset, inset), Vector2(tile - inset * 2, tile - inset * 2)), false, col)
	else: # ponytail: glyph fallback so a missing PNG never breaks the board
		var col := COL_PLAYER if p.owner == Rules.PLAYER else COL_ENEMY
		var glyph: String = defs[p.id].glyph
		var size := 40 if glyph.length() <= 1 else 22
		draw_string(font, px + Vector2(0, tile * 0.68), glyph, HORIZONTAL_ALIGNMENT_CENTER, tile, size, col)
	if _is_inversion_marked(p.id): # NO-101: over the token, corner only, never hides the piece
		var side_col := COL_PLAYER if p.owner == Rules.PLAYER else COL_ENEMY
		var mark_size := _inv_mark_size()
		draw_string(font, _inv_mark_px(px, mark_size), INV_MARK_GLYPH,
			HORIZONTAL_ALIGNMENT_LEFT, -1, mark_size, side_col)
	var buff_glyphs := BuffLogic.glyphs_of(p)
	if not buff_glyphs.is_empty(): # NO-185: bottom edge — NO-101's mark owns the top-right corner
		_draw_buff_badges(font, px, buff_glyphs)


## NO-185: a row of small badges along the tile's bottom edge, one per
## catalogued buff `p` carries (BuffLogic.glyphs_of) — capacity is base 2
## (Tuning.PIECE_BUFF_CAP_BASE) +1 per held Abduction Probe, so more than 2-3
## is a rare stacked-artefact case; shrinking the radius keeps any count
## legible rather than capping the row and losing information.
func _draw_buff_badges(font: Font, px: Vector2, glyphs: Array[String]) -> void:
	var n := glyphs.size()
	var r: float = tile * (0.16 if n <= 2 else 0.13)
	var gap := r * 2.2
	var start_x := px.x + tile / 2.0 - gap * (n - 1) / 2.0
	var y := px.y + tile - r * 1.2
	for i in n:
		var c := Vector2(start_x + gap * i, y)
		draw_circle(c, r, BUFF_BADGE_RING)
		draw_circle(c, r - 1.5, BUFF_BADGE_BG)
		draw_string(font, Vector2(c.x - r, c.y + r * 0.5), glyphs[i],
			HORIZONTAL_ALIGNMENT_CENTER, r * 2, int(r * 1.4), BUFF_BADGE_GLYPH_COL)


## NO-101: true for exactly the four literal inv- ids, never the ten
## inversion pairs that resolve to an ordinary piece's own id (out of scope,
## Max's ruling 2026-09-16). Shared by `_draw_piece` and
## tests/test_board_draw.gd so the probe can never diverge from what the
## draw call actually checks.
func _is_inversion_marked(id: String) -> bool:
	return id.begins_with("inv-")


## NO-101's inversion glyph, sized off the tile so it reads at any board
## scale (a fixed pixel size measured unreadable — a few px of ink — at the
## mobile tile size). Floor keeps it legible if the board ever shrinks
## further; the glyph itself is small within its own font metrics, so 56% of
## the tile lands it clearly short of covering the piece.
func _inv_mark_size() -> int:
	return maxi(18, int(tile * 0.56))


## Where NO-101's inversion glyph sits on a tile, from the tile's top-left
## pixel — pinned to the top-right corner and scaled with `size` so it never
## drifts off-tile as `_inv_mark_size` changes. `draw_string`'s y is the
## BASELINE, not the glyph's top: it must sit far enough down for the
## glyph's ascent (~0.8 * size) to still land inside this tile and not the
## one above it — measured wrong once already (NO-101).
func _inv_mark_px(px: Vector2, size: int) -> Vector2:
	return px + Vector2(tile - size * 0.9, size * 0.92)


func _tile_px(pos: Vector2i) -> Vector2:
	return board_px + Vector2(pos.x * tile, (Tuning.BOARD_H - 1 - pos.y) * tile)


# --- module shims (test-facing seams; logic lives in scripts/*.gd) ---

func _queue_wave(n: int) -> void:
	WaveLogic.queue(self, n)


func _to_config() -> Dictionary:
	return SaveConfig.to_config(self)


func _record_score() -> int:
	return Economy.record_score(self)


func _record_history(won: bool) -> void:
	Economy.record_history(self, won)


# --- HUD wiring (widgets live in scripts/hud.gd; signals up, calls down) ---

func _connect_hud() -> void:
	hud.pass_pressed.connect(_on_pass)
	hud.king_ability_pressed.connect(_show_king_abilities)
	hud.stack_pressed.connect(_on_stack_pressed)
	hud.stack_drag_started.connect(_on_stack_drag_start)
	hud.stack_preview_requested.connect(func(id: String, cap: bool, entry: Variant) -> void:
		_show_preview(id, "", entry if not cap else null, # NO-138/NO-144
			entry if entry is Dictionary else {})) # NO-185: buffs
	hud.item_preview_requested.connect(func(index: int) -> void:
		_show_kind_preview("item", items[index].key, items[index])) # NO-144
	hud.artefact_preview_requested.connect(func(key: String) -> void:
		_show_kind_preview("artefact", key, _artefact_entry(key))) # NO-144
	hud.multi_confirm_pressed.connect(_confirm_target_pressed)
	hud.multi_cancel_pressed.connect(_confirm_target_cancelled)
	hud.item_pressed.connect(_use_item, CONNECT_DEFERRED)
	hud.artefact_activate_pressed.connect(_activate_artefact)
	hud.army_ability_pressed.connect(_activate_army_ability)
	hud.promote_pressed.connect(func(id: String) -> void:
		MergeLogic.do_merge(self, {"id": id}, {"id": id}))
	hud.convert_pressed.connect(func(entry: Variant) -> void:
		if _convert_captured(entry): # same rules as the Shop's Convert button
			_refresh())
	hud.return_to_stock_pressed.connect(func() -> void:
		if selected.x >= 0 and board.has(selected):
			_setup_to_stock(selected))
	hud.shop_pressed.connect(_open_shop)
	hud.drawer_changed.connect(_after_drawer_change)
	hud.arrow_toggle_pressed.connect(_on_arrow_toggle)
	hud.arrow_clear_pressed.connect(_on_arrow_clear)
	hud.menu_toggled.connect(func(open: bool) -> void:
		game_menu_open = open
		if open:
			placing_id = ""
			_clear_selection())
	hud.settings_changed.connect(func(data: Dictionary) -> void:
		animations_on = data.get("animations_on", true) # live — no restart needed
		set_board_theme(data.get("board_theme", DEFAULT_BOARD_THEME))
		queue_redraw())


## Open one drawer (closing the others) or toggle it shut; "" closes all.
func _set_drawer(which: String) -> void:
	hud.set_drawer(which)
	_after_drawer_change()


func _after_drawer_change() -> void:
	if hud.drawer_open != "": # opening a drawer drops any selection (2026-07-08);
		placing_id = ""       # closing keeps it (outside-tap flow places next tap)
		_clear_selection()
	_layout_board()
	_refresh()




func _refresh() -> void:
	merge_highlights = MergeLogic.partner_ids(self) # hud strips read it
	hud.refresh()
	queue_redraw()


# --- modal wiring (widgets live in scripts/modals.gd; signals up, calls down) ---

func _connect_modals() -> void:
	modals.choice_chosen.connect(_choice_picked)
	modals.choice_pick_cancelled.connect(_choice_pick_cancelled)
	modals.merge_confirmed.connect(func() -> void:
		var p := pending_merge
		pending_merge = []
		MergeLogic.commit_merge(self, p[0], p[1]))
	modals.merge_cancelled.connect(func() -> void:
		pending_merge = []
		_refresh())
	modals.box_chosen.connect(_box_choose)
	modals.box_skipped.connect(_on_box_skipped)
	modals.box_reroll_pressed.connect(_box_reroll)
	modals.box_sell_pressed.connect(_box_sell)
	modals.win_continue_pressed.connect(_on_win_continue)
	modals.win_end_pressed.connect(func() -> void:
		win_open = false
		_game_over(true, "Wave-%d King checkmated" % wave))
	modals.shop_buy_pressed.connect(func(index: int) -> void:
		# BEFORE Shop.buy, which takes the gold. _open_box_pick refuses to
		# clobber a Box that is already open, so buying one here while another
		# was open would otherwise charge the player and show them nothing.
		# (The Box now renders above the Shop, so this should be unreachable —
		# it is the guard that makes that a safety property rather than a
		# coincidence of draw order.)
		if box_open:
			return
		if not Shop.buy(self, index):
			return
		if shop_stock[index].kind == "box": # the roll modal IS the grant
			if modals.shop_panel:
				modals.shop_panel.visible = false
			return _open_box_pick(shop_stock[index]) # reveals its stock-time roll
		# An artefact's on_purchase can open a Box of its own — SETI's Red
		# Marker does. Rebuilding the Shop here would raise a fresh, opaque
		# shop_panel back on top of that Box, and every further Buy would then
		# hit the box_open guard and do nothing on a Shop that still looks live.
		# Step aside and let the Box have the screen, exactly as the box branch
		# above does.
		if box_open:
			if modals.shop_panel:
				modals.shop_panel.visible = false
			_refresh()
			return
		modals.show_shop() # rebuild: fresh SOLD + affordability state
		_refresh())
	modals.shop_tile_preview_requested.connect(func(index: int) -> void:
		_show_shop_preview(index)) # NO-167 (Max review, second pass)
	modals.restart_pressed.connect(func() -> void:
		# Restart means a FRESH ROLL (user ruling 2026-09-04). next_config used
		# to survive the reload, so a run entered via Continue restarted into
		# its own mid-run snapshot — Restart meant two different things
		# depending on how the run began. The army and tier stay: apply() put
		# them back into the statics, and SETUP reads statics. The seed clears
		# too — deliberately replaying an exact seed is the seed system's job,
		# and the seed is printed on this very screen for whoever wants it.
		# A TEST scenario keeps replaying its scenario, which is what TEST is for.
		if not is_scenario:
			next_config = {}
			next_seed = ""
		get_tree().reload_current_scene())
	modals.shop_closed.connect(func() -> void: _refresh())
	modals.shop_restock_pressed.connect(_jet_fuel_restock_pressed)
	modals.sell_pressed.connect(func(kind: String, entry: Variant) -> void: # NO-144
		_sell(kind, entry)
		_refresh())
	modals.reinforce_done_pressed.connect(func() -> void:
		pending_reinforce = false
		_refresh())
	modals.preview_closed.connect(func() -> void: preview_open = false)


## Shop entry: player's turn only, never over another modal.
##
## LOCKED BEFORE Tuning.SHOP_UNLOCK_WAVE (issue 101, user ruling 2026-09-01).
## This file previously said "always openable, in any state — the GDD makes the
## Shop the one surface the player can reach at will"; that is no longer true
## and the comment is rewritten rather than left contradicting the code. From
## the unlock Wave on, the old rule resumes: openable in any state, with buying
## still turn-gated by Shop.can_buy, so outside your turn it is a readable
## catalog with dead Buy buttons.
func _open_shop() -> void:
	if wave < Tuning.SHOP_UNLOCK_WAVE:
		_add_turn_fx("The Shop opens on Wave %d" % Tuning.SHOP_UNLOCK_WAVE,
			Color(1.0, 0.8, 0.4)) # says WHEN, not just "no" — a refusal with
			# no reason reads as a bug (issue 101's own acceptance)
		return
	if Kings.power_is(self, "juche"): # Kim Jong Un: Juche — the Shop is closed
		_add_turn_fx("Juche: the Shop is closed", Color(1.0, 0.5, 0.4))
		return
	if box_open or buff_pick_open or preview_open or win_open: # one modal at a time
		return
	tally("shop_open") # issue 103
	modals.show_shop() # issue 61: no per-visit resets here — the panel can be
		# closed/reopened at will, so nothing about a "visit" is a real
		# boundary (pallet_purchase_count/jet_fuel_used_this_wave both moved
		# to a per-Wave reset instead — see WaveLogic.queue()/artefact_hooks.gd)


## The Shop panel is up. Read from the panel itself rather than a mirrored
## flag: show_shop()/close both move it, and a second source of truth drifts.
func shop_open() -> bool:
	return modals.shop_panel != null and modals.shop_panel.visible


## Jet Fuel Vial (52): "Once per Wave: pay 20 Gold to restock the Shop" — a
## Shop control, not part of the in-run Activate section (user ruling). Read
## by modals.gd's Restock button (enabled state) and the confirm below.
## Issue 61: moved off the "Shop visit" boundary — closing/reopening the Shop
## panel (_open_shop()) can no longer re-arm this; only a Wave clear can.
func _jet_fuel_restock_available() -> bool:
	return _held("jet-fuel-vial") and not jet_fuel_used_this_wave \
			and state == State.PLAYER_TURN and gold >= 20


func _jet_fuel_restock_pressed() -> void:
	if not _jet_fuel_restock_available():
		return
	if autoplay: # bot: resolve immediately, never stall on the modal (issue 52)
		return _jet_fuel_restock_confirmed()
	_open_choice_pick("✦ Jet Fuel Vial — restock the Shop?",
		[{"label": "Confirm", "value": true}], "Cancel",
		func(_v) -> void: _jet_fuel_restock_confirmed(), Callable())


func _jet_fuel_restock_confirmed() -> void:
	if not _jet_fuel_restock_available(): # re-check (Gold/state may have shifted)
		return
	jet_fuel_used_this_wave = true
	Economy.spend_gold(self, 20)
	Shop.roll(self)
	if modals.shop_panel and modals.shop_panel.visible:
		modals.show_shop() # rebuild: fresh stock + affordability state
	_refresh()


## Selling (issue 60): Stock pieces, Captured Stock, Items and Artefacts sell
## for Tuning.SELL_RATE (50%, rounded down) of their buy price — never board
## pieces (Extraction already covers board -> Stock, deliberately two steps,
## so `kind` here is only ever "piece"/"captured"/"item"/"artefact"). Gold
## only, no Score — Economy.earn_gold is the Gold-only half of earn(), the
## same asymmetry Buy already has. `entry` is the exact element from
## g.stock/g.captured/g.items/g.artefacts (modals.gd reads it straight off
## those arrays to build the Sell UI, same as Shop.buy's `slot` is the exact
## g.shop_stock element). Free, same turn-gating shape as Shop.buy — costs no
## Action (issue 64, user ruling) and, like Buy, a sale never force-ends the
## turn (a Shop transaction, not a board action).
func _sell(kind: String, entry: Variant) -> bool:
	if not Shop.can_sell(self, kind, entry):
		return false
	var amount := Shop.sell_payout(self, kind, entry) # issue 68: Insider Rates'
		# sell-payout bonus lives here, never in Shop.sell_price() itself —
		# _convert_captured below keeps calling sell_price() at the flat rate
	tally("sell") # issue 103
	match kind:
		"piece": stock.erase(entry)
		"captured": captured.erase(entry)
		"item": items.erase(entry)
		_: artefacts.erase(entry) # "artefact"
	Economy.earn_gold(self, amount, "sell") # AFTER the erase above — Denver
		# Bunker Timeshare's own on_gold_change check must see the POST-sale
		# Item count, so selling the Item that empties the last slot doesn't
		# also collect that Item-cap bonus on its own way out
	return true


## Captured -> Stock conversion (issue 60): the only way a captured piece
## becomes deployable again — direct Captured Stock deploy is removed this
## slice (merge/convert/sell are its only exits). Costs the SAME 50% of
## value that selling pays out (Shop.sell_price(g, "captured", entry) — see
## Tuning.SELL_RATE's header for why that equality is deliberate: convert-
## then-sell is a wash, with the piece gone). Free, no Action (issue 64, user
## ruling), same turn-gating and never-force-ends-the-turn shape as
## Shop.buy/_sell.
func _convert_captured(entry: Variant) -> bool:
	if not Shop.can_convert(self, entry):
		return false
	var cost := Shop.convert_price(self, entry) # issue 97: its own rate now
	tally("convert") # issue 103
	captured.erase(entry)
	stock.append(entry) # ADR-0002: captured and stock share the same
		# bare-id-or-stateful-Dictionary shape, so the entry moves across as-is
	Economy.spend_gold(self, cost)
	return true


func _show_win_screen() -> void:
	win_open = true
	modals.show_win_screen()


## `entry` (NO-144): the live Stock element behind this preview, when it's
## one — a board tile or a Captured Stock entry pass none, so Sell is never
## offered for either (Sell is Stock-only; Captured has Convert instead).
## `piece` (NO-185): the buffs-bearing Dictionary to list in the modal —
## board[at] for a board tile, or `entry` itself for a Stock/Captured stack
## (ADR-0002: a stateful entry IS a piece Dictionary with `buffs`). Kept
## separate from `entry` because a board tile has buffs but no Sell entry.
func _show_preview(id: String, king_id := "", entry: Variant = null, piece: Dictionary = {}) -> void:
	preview_open = true
	modals.show_preview("piece", id, king_id, entry, -1, piece)


## NO-144: an Item/Artefact's own long-press menu — same preview modal a
## piece gets, minus the movement diagram, plus Sell when `entry` (the live
## g.items/g.artefacts element) is sellable.
func _show_kind_preview(kind: String, id: String, entry: Variant) -> void:
	preview_open = true
	modals.show_preview(kind, id, "", entry)


## NO-167 (Max review, second pass, 2026-09-20): a Shop tile's own preview —
## same modal a held Stock/Item/Artefact entry gets above, with a Buy button
## in Sell's place (modals.show_preview's shop_index). `entry` stays null: an
## unowned Shop slot has no owned form to pass; kind/id read straight off the
## slot, covering "piece"/"item"/"artefact"/"box" alike.
func _show_shop_preview(index: int) -> void:
	preview_open = true
	var slot: Dictionary = shop_stock[index]
	modals.show_preview(slot.kind, slot.key, "", null, index)


## Opening the tariff overlay deselects, like menus and drawers.
func _show_king_abilities() -> void:
	# The only modal opener with no guard at all. It is unreachable over another
	# modal today only because every other panel happens to cover the top bar
	# button — the same accident that made the pause menu safe over a finished
	# run until it was guarded explicitly. This one carries no flag of its own,
	# so opening it over a live Box or pick would leave that modal's flag set
	# beneath a panel whose Close returns to nothing the player can act on.
	if box_open or buff_pick_open or preview_open or game_menu_open \
			or win_open or state == State.GAME_OVER:
		return
	placing_id = ""
	_clear_selection()
	modals.show_king_abilities()


func _on_box_skipped() -> void:
	fx_at = get_viewport_rect().size / 2.0
	_decline_box_pick()
	_box_close()


## Both decline paths (the interactive Skip button above, and autoplay's own
## inline decline in _open_box_pick) pay the Box's OWN price in Gold and no
## Score (Tuning.box_skip_gold — PRs #343 and #345 replaced the flat rate), plus
## Cicada Rejection Letter's Gold (issue 49): "+Gold equal to the Shop value
## of the offered pieces" re-texted to "the Box's contents, whatever kind" —
## valued off whatever is STILL in box_offer at the moment of decline (the
## full original offer if declined outright, or whatever remains if this is
## a later round after Nostradamus/Huge/Black Book already took some picks).
## A Huge Box declining all 7 pays for all 7 — intended, not a bug (issue 49).
## Stacks additively per held copy, same convention as every other artefact.
func _decline_box_pick() -> void:
	# NO-23 (user rulings 2026-09-07): the consolation is the Box's own price,
	# so declining a Huge Box is worth four times declining a Small one — and it
	# is paid in GOLD ONLY. earn_gold, never earn(): earn() grants both
	# currencies, and declining a Box must not move the leaderboard.
	# box_size is pinned when the Box opens; the helper falls back to Small for
	# a Box that somehow carries no size, which pays rather than paying nothing.
	Economy.earn_gold(self, Tuning.box_skip_gold(box_size), "box_skip")
	var n := _artefact_count("cicada-rejection-letter")
	if n > 0:
		var value := 0
		for opt in box_offer:
			value += Box.content_value(self, opt)
		gold += value * n
