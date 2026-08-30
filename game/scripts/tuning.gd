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

const ITEM_CAP_BASE := 3          # issue 53 (user ruling): held Items were
                                   # unbounded before this — Area 51 Parking
                                   # Permit raises it, +3 per copy (item_logic.gd)
const PIECE_BUFF_CAP_BASE := 2    # issue 53 (user ruling): a board piece's
                                   # buffs Array was unbounded before this —
                                   # Abduction Probe raises it, +1 per copy
                                   # (buff_logic.gd)
## Automatic tariff scheduling — OFF for now (user call 2026-08-28), pending
## the combined Kings + Tariffs design pass. This ONLY stops the every-10-waves
## draw and the T0 Inflation in wave_logic.gd. The whole system stays live and
## testable: the catalog, the hooks slice 13 migrated onto ArtefactHooks, the
## tariff-intercepting artefacts, and direct activation via a scenario/save
## config or Economy.activate_tariff all behave exactly as before. Flip this
## back to true to restore the cadence — nothing else needs touching.
const TARIFFS_SCHEDULED := false

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

# Difficulty tiers (07-difficulty-ranks, redesigned 2026-08-28 — user call):
# 5 numbered tiers, picked pre-run, locked for the run (Continue into
# endless keeps it), NOT a leaderboard weight — comfort only. Levers are
# CUMULATIVE: each tier is the one below plus one more. Tier 1 is the
# default and has no debuffs.
#   2: the Clock never pauses (menu/win/Shop/drawers/preview all keep ticking)
#   3: Shop stocks 1 fewer of each kind
#   4: starting Stock halved per piece type, rounding up (singletons survive)
#   5: -1 action per turn, enemy actions per turn 2 instead of 1 (issue 59)
const TIERS := ["Tier 1", "Tier 2", "Tier 3", "Tier 4", "Tier 5"]
const DEFAULT_TIER := TIERS[0]

static func tier_index(tier: String) -> int:
	var i := TIERS.find(tier)
	return i if i >= 0 else 0 # unrecognized/old-save value falls back to baseline

static func clock_never_pauses(tier: String) -> bool:
	return tier_index(tier) >= 1

static func shop_row_delta(tier: String) -> int:
	return -1 if tier_index(tier) >= 2 else 0

static func actions_per_turn(tier: String) -> int:
	return ACTIONS_PER_TURN - (1 if tier_index(tier) >= 4 else 0)

## Issue 59: Tier 5 restores the GDD's 2 actions/turn (baseline stays 1, see
## ENEMY_ACTIONS_PER_TURN above for the fleet-sweep numbers on 2 as a global default).
static func enemy_actions_per_turn(tier: String) -> int:
	return ENEMY_ACTIONS_PER_TURN + (1 if tier_index(tier) >= 4 else 0)

## Starting Stock: Tier 4+ halves each distinct piece type, rounding UP so
## singletons survive — e.g. Crown's 8 pawns -> 4, its lone rook stays 1.
static func starting_stock(army: String, tier: String) -> Array:
	var base: Array = ARMIES[army]
	if tier_index(tier) < 3:
		return base.duplicate()
	var counts := {}
	for id in base:
		counts[id] = counts.get(id, 0) + 1
	var out := []
	for id in base: # preserve first-occurrence order
		if not counts.has(id):
			continue
		for i in ceili(counts[id] / 2.0):
			out.append(id)
		counts.erase(id)
	return out
