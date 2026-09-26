## Every tunable constant in one place. GDD-sourced values note their page;
## the rest are MVP placeholders to adjust after playtests.

const BOARD_W := 8                 # GDD said 6; +2 cols playtest round 3
const BOARD_H := 12                # GDD said 8; +3 rows twice, -2 (user call 2026-07-08)
const PLAYER_ZONE_ROWS := 2        # GDD Board — bottom rows, placement zone
const SPAWN_ROW := BOARD_H - 1     # top row; waves spill to next turn if full

## Board tile texture (game.gd BOARD_TILE_SHADER): pixelated Perlin noise added
## to each tile's base colour. AMOUNT is the peak offset per channel (0.09 =
## ±9% value; Max softened 0.15 -> 0.12 -> 0.09 on 2026-09-26, at freq 0.9);
## 0 renders exactly COL_LIGHT/COL_DARK, i.e. the flat board.
## PIXEL is the noise pixel's size in canvas px, rounded so a whole number of
## noise pixels spans each tile — it scales with the tile, and the pixel grid
## lines up with the tile edges.
## FREQ scales the noise-pixel coordinate before sampling Perlin (both
## octaves) — higher shrinks the blobs. Max picked 0.9 over 0.6 and 0.3,
## 2026-09-26.
const BOARD_NOISE_AMOUNT := 0.09
const BOARD_NOISE_PIXEL := 4.0
const BOARD_NOISE_FREQ := 0.9

const ACTIONS_PER_TURN := 2        # unified economy (user call 2026-07-06):
                                   # move/capture, place, merge/fuse, item use
                                   # each cost 1 action (was 2 moves + 1 place
                                   # + 3 merges; 3 actions → 2 on 2026-07-07)

## NO-254: the feedback Google Form ("NO KINGS: playtest feedback"; responses
## land in the Sheet "NO KINGS: playtest feedback (Responses)"), opened via
## game.gd's open_feedback() from the pause menu and the end-of-run screens.
const FEEDBACK_URL := "https://forms.gle/2h7zgrMxNSQv1iQM9"

## NO-118: the shared duration for every Drawer/Shop slide (open and close
## alike) — one constant so hud.gd and modals.gd, which each animate their
## own panel, can't drift apart on it.
const PANEL_SLIDE_S := 0.18

## NO-140: the merge-confirm's sources-fade/result-grows animation — longer
## than PANEL_SLIDE_S on purpose, a slide reads at a glance but "the two
## becoming the result" needs a beat to register.
const MERGE_ANIM_S := 0.35

## NO-145: swipe-to-open/close the Stock/Inventory/Shop panels. One shared
## classifier (classify_swipe below) so game.gd (board opens) and hud.gd/
## modals.gd (each panel's own chrome closes) all agree on what counts as a
## swipe, instead of independent guesses drifting.
##
## Hardware round 2 (coordinator diagnosis): the first cut also let an open
## swipe begin on `deck`'s own unclaimed area, and gated the Shop's opening
## swipe on an edge-proximity constant derived from an assumed 60px tile
## (480 / BOARD_W 8). Both were wrong on real hardware — NO-128 shrank
## DECK_ROWS (132 -> 98) between when that was written and when it ran,
## squeezing the deck gap a press was aimed at, and the board is centred
## with margins (`game.gd`'s `board_px`), not full-width, at a tile size
## that had already dropped to ~51px by the time this ran. Both failures
## trace to a surface/number this ticket's own report had flagged as
## unverified. Fix: ALL THREE open gestures now begin only on an empty
## board tile — the one surface that passed on hardware first try — and
## SWIPE_EDGE_ZONE is gone; a leftward swipe reads as "opens the Shop"
## anywhere on the board, no edge proximity required.
const SWIPE_MIN_DIST := 40.0 ## px a press must travel before it's a swipe
	## rather than a tap or a drag — comfortably past hud.gd's
	## DRAWER_SCROLL_DEADZONE (24), so a scroll's own deadzone is never read
	## as a swipe underneath it.
const SWIPE_AXIS_RATIO := 1.5 ## the dominant axis must beat the other by
	## this factor or the drag is too diagonal to call any direction.

## NO-145: `delta` is a press's total (release position - press position)
## movement. Returns "up"/"down"/"left"/"right" once it clears
## SWIPE_MIN_DIST with a dominant axis (SWIPE_AXIS_RATIO); "" if it's too
## short or too diagonal to call.
static func classify_swipe(delta: Vector2) -> String:
	if delta.length() < SWIPE_MIN_DIST:
		return ""
	var ax := absf(delta.x)
	var ay := absf(delta.y)
	if ax > ay * SWIPE_AXIS_RATIO:
		return "right" if delta.x > 0 else "left"
	if ay > ax * SWIPE_AXIS_RATIO:
		return "down" if delta.y > 0 else "up"
	return ""

## Two taps on the same Stock/Captured stack within this much GAME time are a
## double tap (the piece preview). Measured with now_ms(), never the wall clock.
const DOUBLE_TAP_MS := 400

## GAME TIME, in ms: the sum of every process delta since the first call — the
## same clock SceneTreeTimers, Tweens and the Clock's drain already run on.
## Every test-visible time window reads this instead of Time.get_ticks_msec().
## At a normal frame rate delta IS elapsed real time, so play is unchanged
## (except that a hitch longer than max_physics_steps_per_frame is capped, as
## it is for every timer). Under `--fixed-fps 60` each frame adds exactly
## 16.67 ms however long it really took, so a window N frames wide is N frames
## wide on a fast Mac and a loaded CI runner alike — the 2026-09-24 double-tap flake
## (#581: taps 410-451 ms apart by wall clock) cannot recur.
## The stopwatch is one SceneTreeTimer that never fires: the tree subtracts
## each frame's delta from it, so no autoload or _process hook is needed, and
## it works in a `-s` test script from its first frame.
const _STOPWATCH_S := 1.0e9 # ~31 years; a double keeps ~0.1 us of precision here
static var _stopwatch: SceneTreeTimer


static func now_ms() -> int:
	if _stopwatch == null:
		_stopwatch = (Engine.get_main_loop() as SceneTree).create_timer(_STOPWATCH_S)
	return int((_STOPWATCH_S - _stopwatch.time_left) * 1000.0)

## NO-119: every icon OUTSIDE the board (Shop, Inventory Drawer, Stock Drawer)
## reads at this one fixed size, with no name label beside it — the tooltip /
## long-press carries the name instead. Same drift-guard shape as
## PANEL_SLIDE_S above: one constant so hud.gd and modals.gd's grids can't
## drift apart on it (the old split was SHOP_TILE at 46 vs a tile-relative
## ICON of ~52 in hud.gd).
const OFFBOARD_ICON := 72.0

## NO-132: the one column-count standard for every off-board grid (Shop,
## Inventory Drawer, Stock Drawer, and whatever NO-133/NO-142 build next). A
## grid spanning the full screen width uses this many columns; a narrower
## one computes its own cap with grid_cols() below, off the SAME cell size
## and separation, so nothing is a hand-picked number that happens to agree.
const OFFBOARD_GRID_COLS := 5

## NO-132: how many OFFBOARD_ICON cells, `sep` apart, fit in `avail_w` —
## capped at OFFBOARD_GRID_COLS so a wide container never exceeds the
## standard just because it has the room.
static func grid_cols(avail_w: float, sep: float) -> int:
	var fit := int(floor((avail_w + sep) / (OFFBOARD_ICON + sep)))
	return clampi(fit, 1, OFFBOARD_GRID_COLS)

## NO-132: the pixel width of a full `cols`-wide row. A GridContainer inside
## a CenterContainer shrinks to whatever it actually holds, so a row with
## fewer than `cols` entries gets centered as its OWN smaller block — sliding
## into the middle of the lane instead of sitting at columns 1..n. Forcing
## the GridContainer's custom_minimum_size.x to this fixed width first means
## the CenterContainer centers the FULL row instead: the reserved box never
## shrinks, and the actual cells still pack from the grid's own left edge.
static func grid_row_w(cols: int, sep: float) -> float:
	return cols * OFFBOARD_ICON + maxi(cols - 1, 0) * sep

## Newest-first run log, capped so the file cannot grow forever. Lives here
## rather than in economy.gd because leaderboard.gd needs it too and preloading
## economy there drags in the whole gameplay chain -- which is why that file
## carried a bare 50 with a comment apologising for it (NO-37).
const HISTORY_CAP := 50

const ITEM_CAP_BASE := 2          # issue 53 (user ruling): held Items were
                                   # unbounded before this — Area 51 Parking
                                   # Permit raises it, +3 per copy (item_logic.gd)
                                   # 2026-09-24: Max lowered 3 → 2
const PIECE_BUFF_CAP_BASE := 2    # issue 53 (user ruling): a board piece's
                                   # buffs Array was unbounded before this —
                                   # Abduction Probe raises it +1, non-stacking
                                   # (Max, NO-244; game.gd buff_cap)
const ARTEFACT_CAP_BASE := 5      # issue 60 (user ruling): a third base-game
                                   # cap, same shape as the two above — held
                                   # Artefacts were unbounded before this.
                                   # Duplicate copies each take a slot (g.artefacts
                                   # holds one entry per copy, same as Items/Piece
                                   # Buffs), so 5 total is 5 copies of anything,
                                   # ever. No modifier artefact raises it (none in
                                   # the catalog grants Artefact capacity).

## Selling (issue 60): Stock pieces, Captured Stock, Items and Artefacts sell
## for this fraction of their BUY price (g.defs[id].value / SHOP_ITEM_PRICE /
## SHOP_ARTEFACT_PRICE — never Score, issue 57 scales Score x10 but explicitly
## not these), rounded DOWN so the spread never vanishes on a cheap item (a
## 1-Gold item sells for 0, not 1). Captured -> Stock conversion costs the
## SAME rate — deliberately equal: convert-then-sell then costs 50% and
## returns 50%, a wash with the piece gone. Below the sell rate and every
## captured piece is free money; above it and converting is strictly worse
## than selling and re-buying. 50/50 (both directions of this one constant)
## is the only pair that is neither (user ruling, delegated 2026-08-30).
const SELL_RATE := 0.5

## issue 97 (user ruling 2026-09-01: "make it cost more"). Converting a Captured
## piece into deployable Stock now costs MORE than selling pays, instead of
## sharing SELL_RATE with it.
##
## THE DIRECTION IS THE SAFETY PROPERTY, not the value. Equal rates were
## deliberate: issue 68 refused to discount conversion for The Syndicate because
## "it is not a Shop purchase, and discounting it would reopen the convert/sell
## arbitrage that equal rates deliberately closed". Splitting them reopens that
## question, and only one direction is safe:
##
##   CONVERT_RATE >  SELL_RATE  -> safe: convert-then-sell always loses money
##   CONVERT_RATE <  SELL_RATE  -> a money pump, which is what 68 closed
##
## So this may be raised freely and must never drop below SELL_RATE. 0.75 is a
## first value chosen to be clearly "more" without being prohibitive; the
## balance pass owns the number, now that issue 103 can measure it.
const CONVERT_RATE := 0.75

const STUN_MISSES := 2            # Stun: turns the attacker loses, its own
                                   # side's turns (user call 2026-08-28)
const ENEMY_ACTIONS_PER_TURN := 1  # playtest override, re-justified 2026-08-28 (Issue 11,
                                   # gdd-gaps divergence #2 — GDD says 2). Re-run under the
                                   # current wave catalog + tariffs + unified action economy,
                                   # not just carried over from the 2026-07-02 playtest: a
                                   # 60-run fleet sweep (Crown/Wild Hunt/Old Guard, 20 each)
                                   # at 2 actions/turn put every run at 0/60 wins (was 2/60 at
                                   # 1) and collapsed median survival from wave 17.5 to wave 8
                                   # (mean 26.3 -> 9.7, mostly Resource starvation). 2 remains
                                   # too strong for the current economy; 1 stays.
                                   # Issue 59 (user ruling 2026-08-30): rather than pick one
                                   # value for the whole game, GDD's 2 becomes a difficulty
                                   # rank — see enemy_actions_per_turn() below. Baseline stays
                                   # 1; Tier 5 restores 2.
const ENEMY_TURN_PAUSE := 0.4      # beat before/after the enemy acts (feel 2026-07-06)

const CADENCE_BASE := 6            # GDD Wave Catalog: cadence = 6 + piece count

# AI holds out of the player's back row until enough enemies sit within the
# bottom NEAR_ROWS rows to actually fill every column — derived from BOARD_W
# so board resizes can't strand the strategy (round 5)
const BACKROW_COMMIT_COUNT := BOARD_W
const BACKROW_NEAR_ROWS := 2       # rows 0..2 count as "near"

## issue 90: a King wave is TWO segments (user ruling, 2026-08-31) — this many
## turns of buffed enemies BEFORE the King arrives, then the fight proper.
## Wave-scoped King Powers only feel like anything because the wave is long.
const KING_SEGMENT_TURNS := 15
## Donald Trump's Tariff Power escalates: one MORE Tariff comes into force every
## this many turns of his wave, up to the seven in the catalog. A King wave has
## no turn limit — game.gd bars the wave from advancing while the King is alive
## or pending — so before this, stalling a King out cost nothing but Clock.
## UNTUNED: picked to reach all seven around turn 60, against a 15-turn segment
## and a 15-minute Clock. It belongs to the balance pass (NO-6), not to a guess.
const KING_TARIFF_STACK_TURNS := 10

## How many Piece Buffs a segment-1 spawn arrives carrying. Reuses the 12
## shipped buffs rather than inventing an enemy-only stat line: the player
## already knows what each does, and WHICH buffs appear is a per-King flavour
## lever for free.
const KING_SEGMENT_BUFFS := 1

const CLOCK_START_MS := 15 * 60 * 1000  # 30 → 5 (2026-07-07) → 15 (issue 78,
                                        # user call 2026-08-31). Tier 3+ cuts it
                                        # back to CLOCK_START_MS_HARD below, so
                                        # this widens the difficulty range rather
                                        # than shifting it: low tiers get 3x the
                                        # Clock, high tiers keep what they had.
const CLOCK_START_MS_HARD := 5 * 60 * 1000  # Tier 3+ (issue 78) — the old value
const TURN_END_CLOCK_BONUS_MS := 5 * 1000 # +5s for finishing a turn (2026-07-07)
# Early wave clear (2026-07-07): board emptied N turns before the next wave
# spawns → +N× these. Amounts are playtest assumptions on the ×10 economy.
const EARLY_CLEAR_SCORE_PER_TURN := 10
const EARLY_CLEAR_CLOCK_MS_PER_TURN := 2000
## The 10-Wave beat (user ruling 2026-09-06): ONE event at the start of waves
## 11/21/31…, forever — you clear 10 waves, the reinforcement pick greets you.
## It carries the Clock refill and nothing else. The silent 2-piece Stock drip
## and the Score chunk that used to fire a wave earlier are both gone: the pick
## IS the reward, and a beat that pays three separate things a wave apart was
## two mechanics wearing one name.
##
## Kept deliberately separate from KING_CLOCK_REFILL_MS even though they are
## equal today — they are equal by coincidence, and aliasing them would make a
## future King-refill tune silently move the reinforcement refill too.
const CLOCK_REFILL_MS := 2 * 60 * 1000  # per beat (2026-09-06: was 30s)
const MILESTONE_WAVES := 10             # the beat's period; fires at n where
                                        # (n - 1) % MILESTONE_WAVES == 0.
                                        # NOT the per-artefact "5-Wave
                                        # Milestone" (artefact_hooks.gd's
                                        # _milestone5_hit) — different cadence,
                                        # counted per held copy, shares nothing.

# x10 economy (2026-07-03): pawn = 10 points, queen = 90, amazon = 120
const PLACEMENT_COST := 20         # placing mid-turn costs gold (GDD, amount TBD)

## issue 98: a merge costs Gold as well as an Action. Before this a merge was
## FREE in Gold all run long (Economy.charge(g, "fuse_cost") is the Tariff hook
## and charges nothing unless a Fuse Tax is live), so the run's main power curve
## — two bases into a mid, two mids into an end — was gated only by having
## pairs, and the opening had no resource decision in it.
##
## FLAT, not scaled by the result's value (judgement call, no ruling): it is one
## constant, and it is scarce early for the reason the issue actually asks for —
## Gold is scarce early — without making end-tier fusions expensive forever,
## which is a different and much larger change.
##
## Below PLACEMENT_COST on purpose: a merge consumes two pieces you already own,
## so it should not cost more than putting a fresh one on the board.
##
## Composes with the `fuse_cost` Tariff charge; it does not replace it.
const MERGE_COST := 15
const WIN_SCORE_BONUS := 1000      # every King checkmate (GDD, amount TBD)
const KING_CLOCK_REFILL_MS := 2 * 60 * 1000     # recurring King (grilled 2026-07-03)
const CONTINUE_CLOCK_REFILL_MS := 5 * 60 * 1000 # one-time, on entering endless
## Declining a Box pays the Box's own PRICE in GOLD (user rulings 2026-09-07).
## A Huge Box is worth four times a Small one, so a flat consolation made
## declining the expensive one read as a punishment for a choice the game
## itself offered.
##
## GOLD ONLY — routed through Economy.earn_gold, not earn(). earn() grants BOTH
## currencies (score x10 AND gold 1:1), so the first cut of this silently
## multiplied the Score payout too; the ruling is that declining a Box should
## not move the leaderboard at all (and since NO-250 no Artefact converts Gold
## into Score either).
##
## Was `BOX_SKIP_CONSOLATION := 20`, paid through earn() — so it actually gave
## ~20 Gold AND 200 Score while the button read "+20 score". Both halves of
## that were wrong: the amount was flat, and the label under-reported tenfold.
static func box_skip_gold(size: String) -> int:
	return SHOP_BOX_PRICE.get(size, SHOP_BOX_PRICE["small"])
# Shop prices (money-and-shop PRD; playtest placeholders on the x10 economy —
# income is thin, so they sit low; piece slots charge the catalog value)
const SHOP_ITEM_PRICE := {"Tactical": 30, "Strategic": 60, "Decisive": 120}
# Per-rarity (issue 20: closes the Shop page's "Artefact 100 flat" open
# question). Doubles per tier, same shape as SHOP_ITEM_PRICE's tier jumps —
# a Legendary should cost meaningfully more than a Common, not the same 100
# every rarity paid before. "" priced as Common — a fallback for an
# unrecognized key (e.g. one of the 7 game-native keys issue 69 removed,
# briefly reachable in an un-migrated old save).
const SHOP_ARTEFACT_PRICE := {"": 50, "Common": 50, "Uncommon": 100, "Rare": 200, "Legendary": 400}
## Price by SIZE only, theme ignored (issue 47) — doubling shape the file
## already uses everywhere else (SHOP_ITEM_PRICE, SHOP_ARTEFACT_PRICE). Small
## keeps the old flat 50, so nothing gets cheaper. Starting curve, expected
## to get tuned (user call 2026-08-29).
const SHOP_BOX_PRICE := {"small": 50, "big": 100, "huge": 200}

# Artefact rarity draw weight (issue 20), population-independent — a
# Legendary should feel rare regardless of how many Legendaries the catalog
# has. Ratio ~10:4:2:1, mirrored by SHOP_ARTEFACT_PRICE's own doubling curve
# (rarer to find, costs more to buy). Flat for the whole run — depth-gating
# (rarity odds rising with cumulative Score) was reverted 2026-08-28: this is
# a roguelike, a lucky early Legendary is a good story, and the Shop already
# gates rarity by price. "" is the 7 core artefacts (no rarity, predate the
# system) — always Common-weighted.
const ARTEFACT_RARITY_WEIGHT_START := {
	"": 100.0, "Common": 100.0, "Uncommon": 40.0, "Rare": 20.0, "Legendary": 10.0}

static func artefact_rarity_weight(rarity: String) -> float:
	return ARTEFACT_RARITY_WEIGHT_START.get(rarity, ARTEFACT_RARITY_WEIGHT_START["Common"])


## Weighted-random index into `pool` (an Array of Dictionaries carrying a
## `rarity` field, "" if untagged) — shared by box.gd's single-pick roll and
## shop.gd's sample-without-replacement stock roll.
static func weighted_artefact_pick(pool: Array, rng: RandomNumberGenerator) -> int:
	var weights: Array[float] = []
	var total := 0.0
	for e in pool:
		var w := artefact_rarity_weight(str(e.get("rarity", "")))
		weights.append(w)
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0 or i == weights.size() - 1:
			return i
	return pool.size() - 1


## Rarity legibility (issue 20) — box-pick and Shop tiles color by this so a
## Legendary no longer looks identical to a Common.
const ARTEFACT_RARITY_COLOR := {
	# NO-256 (Max, 2026-09-25): white / green / blue / purple. Uncommon green is
	# the one deliberate exception to "green means money only" — an emerald,
	# bluer and deeper than the money green COL_GOLD so the two never read alike.
	"": Color(1, 1, 1),
	"Common": Color(1, 1, 1),
	"Uncommon": Color(0.15, 0.7, 0.5),
	"Rare": Color(0.35, 0.6, 1.0),
	"Legendary": Color(0.75, 0.45, 1.0),
}
const COL_GOLD := Color(0.35, 0.85, 0.4)   # NO-151: the currency green, shared by every $ display
## NO-256 (d): the one money red — costs, losses and prices the player cannot
## pay. game.gd's BANNER_LOSS is this same colour.
const COL_LOSS := Color(0.95, 0.35, 0.3)


## NO-256 (d): the money colour for `amount` — green (COL_GOLD) for a gain or a
## price the player can pay, red (COL_LOSS) for a cost (amount < 0) or a price
## they can't (affordable = false).
static func money_color(amount: int, affordable := true) -> Color:
	return COL_GOLD if amount >= 0 and affordable else COL_LOSS


## NO-256 (d): colour a money Label or Button (see money_color). A Button gets
## every enabled state, so a touch's pressed/hover/focus never flips it back to
## white; font_disabled_color is left alone, so a disabled button still greys.
static func money(c: Control, amount: int, affordable := true) -> void:
	var col := money_color(amount, affordable)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color"]:
		c.add_theme_color_override(k, col)


# Restock cadence (issue 64, user ruling 2026-08-30): two lanes REPLACE the
# old rising Score-threshold curve (was BASE=1000/STEP=500 -> 1000/2500/4500/
# 7000) entirely. Lane A is guaranteed, every SHOP_RESTOCK_WAVES Waves, first
# at Wave 5; Lane B is Score-driven and resets on every Lane-A restock.
# LANE_B_SCORE=10,000 calibrated against observed full-run scoring post-x10
# economy (~8,085 Score per 5-Wave window, three ~45-Wave runs) so a typical
# window earns slightly under one bonus Lane-B restock — Lane A stays the
# backbone, Lane B rewards scoring above average.
const SHOP_RESTOCK_WAVES := 5

## The Shop's first restock Wave. NO-240 (Max, 2026-09-24) replaced issue
## 101's lock: the Shop OPENS from Wave 1 but is EMPTY ("Restocks at wave N")
## until this Wave's Lane A restock — no setup roll, Lane B banks without
## rolling, Jet Fuel can't restock it. Equal to SHOP_RESTOCK_WAVES, so the first
## stock is the first Lane A beat, bannered "SHOP OPEN" and auto-opened.
const SHOP_UNLOCK_WAVE := 5

## Lane B: the bonus restock gauge. Score banked since the last Lane-A restock,
## which ZEROES it (shop.gd's lane_a_restock) — user ruling 2026-09-07, keeping
## Lane B a within-window sprint rather than a run-long accumulation.
##
## 10000 -> 5000 the same day, because the wipe makes the real bar "this much
## between two Lane-A fires", not "this much cumulatively". Measured on the
## 30-run sweep: median score 3900 over a median 25 waves, so a typical 5-Wave
## window banks about 780. At 10000 that was a ~13x gap and Lane B effectively
## never fired; only 9 of 30 runs reached 10000 even CUMULATIVELY. Same shape
## as the pre-issue-57 flag about an unreachable first threshold.
##
## 5000 is still ~6x a typical window ON PURPOSE: Lane B is a reward for a
## scoring burst, not a second guaranteed lane. If it should fire for ordinary
## play, this number is the lever — not the wipe, which is now a ruling.
##
## 5000 -> 3000 (2026-09-26, Max's ruling after NO-250 / #585 took all Score
## off Artefacts): restock as often as before on core Score alone. A/B, 60
## runs a side: mean Score 19,114 -> 11,103 (x0.58), median 2,700 -> 2,350
## (x0.87), waves unchanged, so per-Wave accrual fell by the same ratios. A
## Lane-B fire needs ~6x a typical window, so it lives in the high-scoring
## windows, where Artefact stacks had compounded most: the Score-weighted
## mean (x0.58 -> 2,900) is the better guide than the median (x0.87 ->
## 4,350). Rounded to 3000 (-40%), slightly above 2,900 because the mean is
## lifted by runaway runs whose big single gains rolled once however many
## gates they crossed. Target: shop_buy per run back from 37.7 toward 52.1.
const SHOP_LANE_B_SCORE := 3000

# The flat Tariff fallback: upstream catalog says 200/500/1000, scaled to the
# /10 economy; halved 2026-07-06 — at 20/10 a tariffed Move+Capture pair ate
# more than most captures earn (fleet data: Crown median score 30 at run end).
# Since NO-105 only Tariff on Pass and the blocked-move charge still bill this
# flat amount; every other tariff bills a percentage of a reference value below.
const KING_ABILITY_ACTION_COST := 10     # per tariffed action

## NO-105 (user ruling 2026-09-17): a Tariff takes a cut of what the taxed
## thing is WORTH, not a flat fee. Mild tariffs bill a percentage of an asset's
## Shop value; Moderate ones bill a percentage of what the action already
## costs. See docs/adr/0005-tariff-cost-model.md for why the bases differ.
## Every result is rounded DOWN with a floor of 1 — a Tariff is never free.
const TARIFF_MOVE_PCT := 0.10       # of the moving piece's value
const TARIFF_CAPTURE_PCT := 0.10    # of the CAPTURED piece's value
const TARIFF_LR_PCT := 0.03         # of the moving piece's value, PER SQUARE
const TARIFF_ITEM_PCT := 0.60       # of the Item's Shop price for its tier
const TARIFF_DEPLOY_PCT := 0.60     # of PLACEMENT_COST
const TARIFF_FUSE_PCT := 0.60       # of MERGE_COST

# Armies (grilled 2026-07-03; slimmed 2026-07-08 — "too many pieces"): three
# 11-piece starting stocks, one shape: 8 cheap base pieces + 3 specials.
# Each army's identity is its signature piece and merge chain — the GDD's
# "unique Queen", trimmed: team abilities and Piece Cases are deferred.
const ARMIES := {
	"Crown": [ # classic chess: 8 pawns + rook, bishop, knight (190)
		"pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn",
		"rook", "bishop", "knight"],
	"Wild Hunt": [ # leapers: 8 pawns + the kirin pair + a knight (170)
		"pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn",
		"kirin", "kirin", "knight"],
	"Old Guard": [ # walkers: 8 ferz/wazir + 3 leapers for income (230;
		# 2026-07-06 insight — range-1 walkers can't capture, and captures
		# are income; alibaba leaps 2 so it earns too)
		"ferz", "ferz", "ferz", "ferz", "wazir", "wazir", "wazir", "wazir",
		"knight", "alibaba", "alibaba"],
	# issue 68: three more Armies, same "one shape, ballpark numbers"
	# license as the three above (issue 68's own header: "all numbers are
	# ballpark and tunable later").
	"Syndicate": [ # money: a thin kit (6 pawns + knight, 130) — Insider
		# Rates and triple starting Gold carry this army, not piece count
		"pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "knight"],
	"Cult": [ # buffs: "standard stock" (issue 68) read as Crown's own
		# classic-chess kit verbatim — the army's identity is Communion/
		# Ritual/2 starting Artefacts, not a piece gimmick (no source for a
		# different shape, so the un-modified baseline stands)
		"pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn",
		"rook", "bishop", "knight"],
	"Horde": [ # swarm: 14 pawns, no majors — merge fuel, not an army
		# (issue 68's own text)
		"pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn",
		"pawn", "pawn", "pawn", "pawn", "pawn", "pawn", "pawn"],
}
const DEFAULT_ARMY := "Crown" # --autoplay / --screenshot skip the menu

## Army framework (issue 67, ratified 2026-08-30): a fresh run has never
## had a non-zero starting-Gold concept before this slice — `g.gold` began
## every fresh boot at its bare declaration value, 0, uniformly for every
## army. The GDD ruling's "baseline Gold" / "~half Gold" / (issue 68's
## sibling slice) "triple baseline Gold" all presuppose a real number, and
## issue 68 states outright "All numbers are ballpark and tunable later
## (standing user stance)" for that same design session's Armies — so this
## is picked on that authority, not invented in a vacuum: pinned to
## SHOP_ITEM_PRICE's own "Tactical" tier above, enough for one early buy.
const ARMY_BASELINE_GOLD := SHOP_ITEM_PRICE["Tactical"] # 30

# Difficulty tiers (07-difficulty-ranks, redesigned 2026-08-28 — user call;
# ladder retuned 2026-09-21 — user call, NO-213): 5 numbered tiers, picked
# pre-run, locked for the run (Continue into endless keeps it), NOT a
# leaderboard weight — comfort only. Levers are CUMULATIVE: each tier is the
# one below plus one more. Tier 1 is the default and has no debuffs.
#   2: the Clock never pauses (menu/win/Shop/drawers/preview all keep ticking)
#   3: starting Clock drops from 15 minutes to 5; Shop stocks 1 fewer of each kind
#   4: -1 action per turn
#   5: enemy actions per turn 2 instead of 1 (issue 59)
const TIERS := ["Tier 1", "Tier 2", "Tier 3", "Tier 4", "Tier 5"]
const DEFAULT_TIER := TIERS[0]

static func tier_index(tier: String) -> int:
	var i := TIERS.find(tier)
	return i if i >= 0 else 0 # unrecognized/old-save value falls back to baseline

static func clock_never_pauses(tier: String) -> bool:
	return tier_index(tier) >= 1


## Starting Clock: Tier 3+ (the mid rung) drops from 15 minutes back to the old
## 5 (issue 78). Cumulative like every other tier rule, so Tiers 4-5 inherit it.
static func clock_start_ms(tier: String) -> int:
	return CLOCK_START_MS_HARD if tier_index(tier) >= 2 else CLOCK_START_MS

static func shop_row_delta(tier: String) -> int:
	return -1 if tier_index(tier) >= 2 else 0

## NO-213 (Max, 2026-09-21): the -1 action handicap moved down from Tier 5 to
## Tier 4 — knight difficulty was reading as random without it, since the
## Stock-halving lever it replaces (dropped below) gave no felt difficulty
## signal of its own.
static func actions_per_turn(tier: String) -> int:
	return ACTIONS_PER_TURN - (1 if tier_index(tier) >= 3 else 0)

## Issue 59: Tier 5 restores the GDD's 2 actions/turn (baseline stays 1, see
## ENEMY_ACTIONS_PER_TURN above for the fleet-sweep numbers on 2 as a global default).
static func enemy_actions_per_turn(tier: String) -> int:
	return ENEMY_ACTIONS_PER_TURN + (1 if tier_index(tier) >= 4 else 0)


## NO-148: the handicaps above, as DATA — the single source rank_center's
## per-tier descriptions are generated from, keyed to the tier they first
## apply at (a TIERS index), so a retune here can't silently drift the copy
## a player reads.
const TIER_HANDICAPS := [
	{"at": 1, "text": "The Clock never pauses"},
	{"at": 2, "text": "Starting Clock drops from 15 minutes to 5"},
	{"at": 2, "text": "Shop stocks 1 fewer of each kind"},
	{"at": 3, "text": "-1 action per turn"},
	{"at": 4, "text": "Enemy takes 2 actions per turn instead of 1"},
]

## Handicaps newly introduced AT this tier — empty for Tier 1.
static func new_handicaps(tier: String) -> Array[String]:
	var idx := tier_index(tier)
	var out: Array[String] = []
	for h in TIER_HANDICAPS:
		if h.at == idx:
			out.append(h.text)
	return out


## NO-256: the project Theme's body font, for code that measures or draws text
## outside a Control's own theme lookup. ThemeDB.fallback_font when the Theme
## is missing: on a cold import cache the TTFs are not imported yet when the
## engine loads gui/theme/custom, so the project theme is null and a bare
## `get_project_theme().default_font` crashed the Shop (Aux, 2026-09-25).
static func ui_font() -> Font:
	return font_of(ThemeDB.get_project_theme())


static func font_of(theme: Theme) -> Font:
	if theme != null and theme.default_font != null:
		return theme.default_font
	return ThemeDB.fallback_font
