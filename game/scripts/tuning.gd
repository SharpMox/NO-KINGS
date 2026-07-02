## Every tunable constant in one place. GDD-sourced values note their page;
## the rest are MVP placeholders to adjust after playtests.

const BOARD_W := 6                 # GDD Board
const BOARD_H := 11                # GDD said 8; +3 rows playtest 2026-07-02
const PLAYER_ZONE_ROWS := 2        # GDD Board — bottom rows, placement zone
const SPAWN_ROW := BOARD_H - 1     # top row; waves spill to next turn if full

const MOVES_PER_TURN := 2          # grilled 2026-07-02 (GDD leaves TBD)
const PLACEMENTS_PER_TURN := 1     # grilled 2026-07-02
const ENEMY_ACTIONS_PER_TURN := 1  # playtest override 2026-07-02 (GDD says 2)

const CADENCE_BASE := 6            # GDD Wave Catalog: cadence = 6 + piece count

const CLOCK_START_MS := 30 * 60 * 1000  # GDD example value, TBD upstream
const CLOCK_REFILL_MS := 30 * 1000      # every 10 waves; GDD example value
const MILESTONE_WAVES := 10             # GDD Reward Economy

const PLACEMENT_SCORE_COST := 2    # placing mid-turn costs score (GDD, amount TBD)
const MILESTONE_SCORE_BONUS := 10  # every 10 waves (GDD, amount TBD)
const WIN_SCORE_BONUS := 100       # wave-50 checkmate (GDD, amount TBD)
const BOX_SKIP_CONSOLATION := 2    # GDD: small consolation, amount TBD
const SCORE_BOX_CHUNKS: Array = [5, 8, 10, 12, 15, 20]  # score-box contents pool

# Starting Stock (12 = fills the placement zone exactly). Fairy bases included
# because enemies only field pawn/bishop/knight/rook — see plan, grilled 2026-07-02.
const STARTING_STOCK: Array = [
	"pawn", "pawn", "knight", "bishop", "rook",
	"ferz", "ferz", "ferz", "wazir", "wazir", "kirin", "alibaba",
]
