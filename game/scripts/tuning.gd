## Every tunable constant in one place. GDD-sourced values note their page;
## the rest are MVP placeholders to adjust after playtests.

const BOARD_W := 8                 # GDD said 6; +2 cols playtest round 3
const BOARD_H := 14                # GDD said 8; +3 rows twice (rounds 2 and 3)
const PLAYER_ZONE_ROWS := 2        # GDD Board — bottom rows, placement zone
const SPAWN_ROW := BOARD_H - 1     # top row; waves spill to next turn if full

const MOVES_PER_TURN := 2          # grilled 2026-07-02 (GDD leaves TBD)
const PLACEMENTS_PER_TURN := 1     # grilled 2026-07-02
const MERGES_PER_TURN := 3         # playtest round 4
const ENEMY_ACTIONS_PER_TURN := 1  # playtest override 2026-07-02 (GDD says 2)

const CADENCE_BASE := 6            # GDD Wave Catalog: cadence = 6 + piece count

const CLOCK_START_MS := 30 * 60 * 1000  # GDD example value, TBD upstream
const CLOCK_REFILL_MS := 30 * 1000      # every 10 waves; GDD example value
const MILESTONE_WAVES := 10             # GDD Reward Economy

# x10 economy (2026-07-03): pawn = 10 points, queen = 90, amazon = 120
const PLACEMENT_SCORE_COST := 20   # placing mid-turn costs score (GDD, amount TBD)
const MILESTONE_SCORE_BONUS := 100 # every 10 waves (GDD, amount TBD)
const WIN_SCORE_BONUS := 1000      # wave-50 checkmate (GDD, amount TBD)
const BOX_SKIP_CONSOLATION := 20   # GDD: small consolation, amount TBD
const SCORE_BOX_CHUNKS: Array = [50, 80, 100, 120, 150, 200]  # score-box pool

# Tariff costs: upstream catalog says 200/500/1000 — now a clean /10 scale
const TARIFF_ACTION_COST := 20     # per tariffed action
const TARIFF_LR_PER_SQUARE := 10   # Tariff on Long-Range, per square moved

# Starting Stock (12 = fills the placement zone exactly). Fairy bases included
# because enemies only field pawn/bishop/knight/rook — see plan, grilled 2026-07-02.
const STARTING_STOCK: Array = [
	"pawn", "pawn", "knight", "bishop", "rook",
	"ferz", "ferz", "ferz", "wazir", "wazir", "kirin", "alibaba",
]
