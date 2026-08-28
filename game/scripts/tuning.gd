## Every tunable constant in one place. GDD-sourced values note their page;
## the rest are MVP placeholders to adjust after playtests.

const BOARD_W := 8                 # GDD said 6; +2 cols playtest round 3
const BOARD_H := 12                # GDD said 8; +3 rows twice, -2 (user call 2026-07-08)
const PLAYER_ZONE_ROWS := 2        # GDD Board — bottom rows, placement zone
const SPAWN_ROW := BOARD_H - 1     # top row; waves spill to next turn if full

const ACTIONS_PER_TURN := 2        # unified economy (user call 2026-07-06):
                                   # move/capture, place, merge/fuse, item use
                                   # each cost 1 action (was 2 moves + 1 place
                                   # + 3 merges; 3 actions → 2 on 2026-07-07)
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
const ENEMY_TURN_PAUSE := 0.4      # beat before/after the enemy acts (feel 2026-07-06)

const CADENCE_BASE := 6            # GDD Wave Catalog: cadence = 6 + piece count

# AI holds out of the player's back row until enough enemies sit within the
# bottom NEAR_ROWS rows to actually fill every column — derived from BOARD_W
# so board resizes can't strand the strategy (round 5)
const BACKROW_COMMIT_COUNT := BOARD_W
const BACKROW_NEAR_ROWS := 2       # rows 0..2 count as "near"

const CLOCK_START_MS := 5 * 60 * 1000   # 30 min → 5 (user call 2026-07-07)
const TURN_END_CLOCK_BONUS_MS := 5 * 1000 # +5s for finishing a turn (2026-07-07)
# Early wave clear (2026-07-07): board emptied N turns before the next wave
# spawns → +N× these. Amounts are playtest assumptions on the ×10 economy.
const EARLY_CLEAR_SCORE_PER_TURN := 10
const EARLY_CLEAR_CLOCK_MS_PER_TURN := 2000
const CLOCK_REFILL_MS := 30 * 1000      # every 10 waves; GDD example value
const MILESTONE_WAVES := 10             # GDD Reward Economy
const REINFORCE_WAVES := [10, 20, 30, 40]  # reinforcement shop opens when the
                                        # next wave queues ("end of" these);
                                        # prices = catalog piece values, the
                                        # selection = the army's starter mix
const MILESTONE_STOCK_DRIP := 2         # pieces from the army mix per milestone
                                        # (balance 2026-07-06: starvation valve —
                                        # income, not wave pressure, is what kills)

# x10 economy (2026-07-03): pawn = 10 points, queen = 90, amazon = 120
const PLACEMENT_COST := 20         # placing mid-turn costs gold (GDD, amount TBD)
const MILESTONE_SCORE_BONUS := 100 # every 10 waves (GDD, amount TBD)
const WIN_SCORE_BONUS := 1000      # every King checkmate (GDD, amount TBD)
const KING_CLOCK_REFILL_MS := 2 * 60 * 1000     # recurring King (grilled 2026-07-03)
const CONTINUE_CLOCK_REFILL_MS := 5 * 60 * 1000 # one-time, on entering endless
const BOX_SKIP_CONSOLATION := 20   # GDD: small consolation, amount TBD
# Shop prices (money-and-shop PRD; playtest placeholders on the x10 economy —
# income is thin, so they sit low; piece slots charge the catalog value)
const SHOP_ITEM_PRICE := {"Tactical": 30, "Strategic": 60, "Decisive": 120}
# Per-rarity (issue 20: closes the Shop page's "Artefact 100 flat" open
# question). Doubles per tier, same shape as SHOP_ITEM_PRICE's tier jumps —
# a Legendary should cost meaningfully more than a Common, not the same 100
# every rarity paid before. "" is the 7 core artefacts that predate the
# rarity catalog (items.gd ARTEFACT_EFFECTS_CORE) — priced as Common.
const SHOP_ARTEFACT_PRICE := {"": 50, "Common": 50, "Uncommon": 100, "Rare": 200, "Legendary": 400}
const SHOP_BOX_PRICE := 50

# Artefact rarity draw weight (issue 20), population-independent — a
# Legendary should feel rare regardless of how many Legendaries the catalog
# has. Ratio ~10:4:2:1 at run start, mirrored by SHOP_ARTEFACT_PRICE's own
# doubling curve (rarer to find, costs more to buy).
const ARTEFACT_RARITY_WEIGHT_START := {
	"": 100.0, "Common": 100.0, "Uncommon": 40.0, "Rare": 20.0, "Legendary": 10.0}
# Decision: rarity is depth-gated (.scratch/gdd-gaps/issues/20, 2026-08-28) —
# Legendary/Rare probability rises with depth while Common tapers, keyed off
# cumulative Score (what the Shop's own restock cadence already uses —
# SHOP_RESTOCK_BASE/STEP — so box.gd and shop.gd share one depth signal).
# Linear ramp from WEIGHT_START (score 0) to WEIGHT_DEEP (score >= the cap);
# "" (the 7 core artefacts, no rarity) stays flat — they predate the rarity
# system and aren't part of the gate.
const ARTEFACT_RARITY_WEIGHT_DEEP := {
	"": 100.0, "Common": 20.0, "Uncommon": 45.0, "Rare": 45.0, "Legendary": 35.0}
const ARTEFACT_RARITY_DEPTH_CAP_SCORE := 5000 # ~3rd shop restock (4500); curve shape, not a design decision

static func artefact_rarity_weight(rarity: String, score: int) -> float:
	var t := clampf(float(score) / float(ARTEFACT_RARITY_DEPTH_CAP_SCORE), 0.0, 1.0)
	var lo: float = ARTEFACT_RARITY_WEIGHT_START.get(rarity, ARTEFACT_RARITY_WEIGHT_START["Common"])
	var hi: float = ARTEFACT_RARITY_WEIGHT_DEEP.get(rarity, ARTEFACT_RARITY_WEIGHT_DEEP["Common"])
	return lerpf(lo, hi, t)


## Weighted-random index into `pool` (an Array of Dictionaries carrying a
## `rarity` field, "" if untagged) — shared by box.gd's single-pick roll and
## shop.gd's sample-without-replacement stock roll.
static func weighted_artefact_pick(pool: Array, score: int, rng: RandomNumberGenerator) -> int:
	var weights: Array[float] = []
	var total := 0.0
	for e in pool:
		var w := artefact_rarity_weight(str(e.get("rarity", "")), score)
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
	"": Color(0.8, 0.8, 0.82),
	"Common": Color(0.8, 0.8, 0.82),
	"Uncommon": Color(0.4, 0.85, 0.45),
	"Rare": Color(0.35, 0.6, 1.0),
	"Legendary": Color(1.0, 0.72, 0.15),
}
# Restock cadence (GDD Shop page): the shelf refreshes on cumulative score,
# not on waves. The 1st costs BASE, and every later one costs STEP more than
# the last — 1000 / 2500 / 4500 / 7000. Placeholders: a median Crown run ends
# near 300, so either these come down or income goes up after a playtest sweep.
const SHOP_RESTOCK_BASE := 1000
const SHOP_RESTOCK_STEP := 500
const SCORE_BOX_CHUNKS: Array = [50, 80, 100, 120, 150, 200]  # score-box pool

# Tariff costs: upstream catalog says 200/500/1000, scaled to the /10 economy;
# halved 2026-07-06 — at 20/10 a tariffed Move+Capture pair ate more than most
# captures earn (fleet data: Crown median score 30 at run end)
const TARIFF_ACTION_COST := 10     # per tariffed action
const TARIFF_LR_PER_SQUARE := 5    # Tariff on Long-Range, per square moved

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
}
const DEFAULT_ARMY := "Crown" # --autoplay / --screenshot skip the menu

# Difficulty ranks (07-difficulty-ranks, decided 2026-08-28): picked pre-run,
# locked for the run (Continue into endless keeps it), NOT a leaderboard
# weight — comfort only. Officer/Autocrat both disable the Shop clock-pause
# and shift tariffs one tier harsher (binary levers — a pause is on or off);
# starting Stock size is the one lever that scales per rank, trimming the
# rank's RANKS index worth of pieces off the front of the army.
const RANKS := ["Citizen", "Officer", "Autocrat"]
const DEFAULT_RANK := "Citizen"
