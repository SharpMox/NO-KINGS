## Artefact trigger engine — drives the live game node `g`. Dispatches artefact
## effects at named hook points instead of the ad hoc `for t in artefacts: if
## t.key == "move"` that used to be scattered through game.gd/economy.gd/
## wave_logic.gd. Fine for the 7 core effects (data/items.gd:ARTEFACT_EFFECTS_
## CORE); unworkable for the 180-entry catalog (data/artefacts.json) slices
## 16-20 wire in one at a time. This is that slice 13 (hook architecture)
## arriving against a real consumer — see .scratch/gdd-gaps/issues/13 and 15.
##
## HOOKS lists every trigger point the GDD effect texts imply. REGISTRY maps
## an artefact key to the hooks it listens on; ADD_HANDLER (the match in
## _dispatch) is where its logic lives. Adding artefact #8 means one REGISTRY
## line + one match case — never touching a call site again.
##
## STACKING: the same artefact can be held more than once — each copy is its
## own entry in g.artefacts (save_config.gd, shop.gd). run() dispatches once
## per held copy, so percentage/flat modifiers from repeats are ADDITIVE: two
## Greeds add +10 and +10, not +10 compounded multiplicatively. This is how
## the 7 core effects already behaved (each copy ran its own loop iteration
## pre-migration) and is simplest to reason about at 180 artefacts. A
## multiplicative artefact would be a deliberate, called-out exception inside
## its own handler. Covered by test_items.gd ("two Greeds stack additively").
##
## ORDERING: run() sorts the held artefacts by key before dispatching, so a
## value built from several artefacts touching the same number never depends
## on acquisition order. Handlers must be commutative for a fixed multiset of
## keys — true of all 7 today (every one just adds to a counter). Covered by
## test_items.gd ("Greed+Score" order doesn't change the total).
##
## issue 16 (Gold/Score batch) added:
## - on_score_change / on_gold_change (Economy.earn/economy.gd), ctx =
##   {base, amount, reason}. `base` is the untouched pre-artefact amount for
##   this one gain; every percentage handler does `ctx.amount += ctx.base *
##   pct` — reading from the immutable base (never the running `amount`) is
##   what keeps two held copies additive instead of compounding. `reason` is
##   "" for most gains; a few call sites tag one (e.g. "early_clear") so a
##   handler can scope itself to that specific gain without seeing every
##   other earn() in the game.
##
## on_score_change/on_gold_change CONTRACT (tightened by issue 20, after the
## fleet sweep caught two violations — see .scratch/gdd-gaps/issues/20):
## `base` is the only INPUT a handler may read to size its effect; `amount`
## is the OUTPUT for handlers that modify *this hook's own resource* (every
## percentage handler does `ctx.amount += ctx.base * pct`, off `base`, never
## off the running `amount` — reading `amount` makes the result depend on
## which other held keys happened to sort earlier, exactly the
## order-dependence the ORDERING rule above exists to rule out). A handler
## that pays a *different* resource as a side effect (El Dorado Body
## Glitter: Score -> Gold; Tungsten-Filled Gold Bar / Popemobile Piggy Bank:
## Gold -> Score) is a converter, not a percentage modifier on its own hook —
## it must still size itself off `base`, and must hand the payout back
## through the matching ctx output field (`gold_bonus` on on_score_change,
## `score_bonus` on on_gold_change, both pre-seeded 0.0 by Economy.earn and
## applied exactly once, after both ctx dispatches finish) rather than
## writing `g.score`/`g.gold` straight from inside the handler. Before this
## fix all three converters read the running `amount`, and the two Gold->Score
## ones additionally free-wrote `g.score` mid-dispatch instead of routing
## through `score_bonus` — order-dependent and impossible to reason about as
## a single deterministic value. Covered by test_items.gd ("Tungsten +
## Popemobile score bonuses add, not compound" and "El Dorado's Gold bonus
## doesn't depend on other Score handlers' dispatch order").
## - on_capture ctx grew `attacker_id`/`attacker_buffed` (board[from].id /
##   whether it carries a Piece Buff, read while the piece is still on the
##   board — "" / false from the two direct-call test sites, which every
##   attacker-dependent handler treats as "doesn't apply") and
##   `wave_capture_index`/`turn_capture_index` (captures already made this
##   wave/turn, 0-based, tracked centrally in Economy.capture_score so no
##   handler has to).
## - on_wave_clear (WaveLogic.queue, only n > 1) ctx = {clean, turns,
##   captures, gold_spent, gold_base} — all snapshotted before queue() resets
##   the underlying counters for the new wave, and `gold_base` in particular
##   keeps "N% of current Gold" handlers additive across held copies for the
##   same reason `ctx.base` does above. on_wave_spawn fires right after, for
##   the wave that's starting.
## - on_game_over (game.gd:_game_over, before the run is scored/saved) — new
##   hook, added to HOOKS below; Rapture Insurance Policy is its first user.
##
## issue 17 (Action/Time/Piece batch) added 8 no-prerequisite artefacts, all
## on hooks issue 16 had already wired (on_capture, on_turn_start,
## on_wave_clear) — no new call sites. Piece grants into Stock follow
## ADR-0002 (docs/adr/0002-stock-holds-opaque-piece-state.md): Terracotta
## Draft Card's grant is a bare id String because a fresh pool piece carries
## no board state (the Dictionary form is for a piece pulled off the board
## with state attached, e.g. Extraction in game.gd). Stargate Divination
## Crystal is the one action-granting handler that runs mid-turn (on_capture,
## not on_turn_start) — it fires from Economy.capture_score *before*
## _move_player's own actions_left -= 1 / auto-pass check, the same ordering
## that lets the Blitz item (game.gd _item_apply) refund its own action
## without ever resurrecting an already-ended turn. Covered by test_items.gd
## ("Stargate Divination Crystal refunds the capture's action before the
## auto-pass check").
##
## issue 18 (Shop/Item/Buff batch) added:
## - on_deploy fires from game.gd:_place, ctx = {pos} (the tile the piece just
##   landed on — MK-Ultra Sugar Cube reads g.board[ctx.pos]).
## - on_turn_end fires from game.gd:_on_pass's PLAYER_TURN branch, no ctx —
##   the turn-end mirror of the on_turn_start call already there.
## - on_capture ctx grew `attacker_pos` (the Vector2i the attacker piece was
##   still standing on when capture_score ran — Vector2i(-1,-1) from the two
##   direct-call test sites), so a handler can grant something to the actual
##   attacking piece instead of just reading its id.
## - on_price is the Shop's "base + modifiers" seam (shop-drawer-ui/08
##   deferred it "until an Artefact needs it" — several now do). Shop.price()
##   runs it after computing the row's base price; ctx = {base, amount, kind,
##   tier}. `tier` is an Item's tier ("Tactical"/"Strategic"/"Decisive") and
##   "" for every other kind. Same immutable-base/additive-amount contract as
##   on_score_change/on_gold_change, so two discounts stack additively.
##
## issue 13 (hook architecture, reduced scope) migrated the tariff system
## (data/tariffs.gd) onto this same registry, so g.artefacts and
## g.tariffs_active are just two flavours of "held modifier" run() dispatches
## identically — the ad hoc `if Economy.tariff_on(g, "...")` branches that
## used to sit inline in game.gd/wave_logic.gd/merge_logic.gd/hud.gd are now
## REGISTRY entries + _dispatch cases like any artefact. `tariff_on` is gone;
## Economy grew narrow query wrappers instead (sanctioned/merge_ok/
## deploy_cost/enemy_actions), mirroring how earn()/gain()/capture_score()
## already wrapped run() for artefacts. Kept file/class name: tariffs are
## conceptually "artefacts the GDD calls tariffs" — still artefact-shaped
## triggers, not a second kind of thing — and a rename would have widened the
## diff against the concurrent artefacts/shop/buff branch for no behavioural
## gain.
##
## g.tariffs_suppressed (Counter-Intel) pauses every held tariff at once —
## enforced centrally in run() by leaving tariffs_active out of `held`
## entirely while suppressed, rather than each handler re-checking it (that
## was the one thing `tariff_on` did that a plain REGISTRY lookup didn't).
##
## Two semantics coexist deliberately, same as the artefact-stacking note
## above: most tariff handlers are idempotent gates (Sanctions/Regulation/
## Austerity/Filibuster/Trade War, and the 8 action-cost keys on on_charge) —
## a key held twice (Mild tiers may redraw the same tariff) still only gates
## once, because the handler *sets* a ctx field rather than accumulating.
## Inflation is the deliberate stacking exception (data/tariffs.gd: "-10% per
## stack"): its on_gold_gain handler does `ctx.amount *= 0.9`, so N held
## copies compound multiplicatively — one dispatch per copy, same mechanism
## artefacts use for additive stacking, just a multiplicative handler body.
## Covered by test_gold.gd (single stack) and test_items.gd's counter-intel
## cases (suppression pauses it, next wave's spawn resumes it).
##
## Tariff/artefact ordering: run() dispatches the artefacts group before the
## tariffs group (two separately-sorted passes, not one merged sort) so a
## shared hook — only on_milestone today (artefact "timer" + tariff
## "recession") — keeps computing the artefact-modified base first and
## applying the tariff modifier on top, exactly the order the pre-migration
## call site used (`refill` built by the artefact hook run, then halved by
## Recession right after it, outside the hook). A single alphabetical sort
## across both groups would have flipped that for any key sorting before
## "timer" and changed the milestone refill's number.
##
## Oneoff tariffs (forced_audit, hostile_takeover, asset_seizure, jd_vance,
## asset_freeze) stay on Economy.apply_tariff's own `match t.key` — that's
## already a single non-scattered dispatch point (fires once, at activation),
## not an ad hoc branch repeated at multiple call sites, so folding it into
## REGISTRY/_dispatch too would add a hook with no behavioural or
## architectural win.
##
## issue 19 (Special + the `(needs: ...)` backlog, plus what 16/17/18 held
## back for a missing hook) closed the two most-cited gaps and added two more:
## - on_piece_lost was already in HOOKS (a placeholder since slice 15/16) but
##   had no call site — the 5 scattered `lost_player += 1` sites (enemy
##   capture, both Reflect directions, both Trap directions, item destruction)
##   now all funnel through game.gd's `_lose_player_piece(pos, reason,
##   attacker_pos)`, called BEFORE the board entry is erased/overwritten so a
##   handler can still read it (whether it carried a Piece Buff, its id).
##   `reason` is one of "captured"/"trap"/"reflect"/"destroyed"; `attacker_pos`
##   is the enemy piece that did the capturing when there is one
##   (Vector2i(-1,-1) otherwise, e.g. Trap/Reflect/_destroy).
## - on_item_consume: game.gd's 3 scattered `items.remove_at` sites now call
##   `_consume_item(index, it)`, ctx = {key, tier, last, cancel}. `last` is
##   whether this was the only Item held (Tape Eraser Magnet). Fires BEFORE
##   removal so a handler can veto it via ctx.cancel = true (Dihydrogen
##   Monoxide Battery, Wardenclyffe AAA Batteries: "the Item is not
##   consumed") — the call site only removes when ctx.cancel is still false
##   after every held artefact has run. The Item's own effect (_item_apply)
##   still happens either way; only whether it leaves `items` changes.
## - on_rank_up fires from two choke points: merge_logic.gd's commit_merge,
##   when the merged pair is a same-id promotion-chain step rather than a
##   Fusion of two different pieces (ids[0] == ids[1]), and game.gd's
##   "promote" Item. ctx = {pos, old_id, id}; `pos.x < 0` means the result
##   landed in Stock, not the board (a pool-only merge) — Holy Grail Coaster
##   branches on that to convert the bare Stock id into a buff-carrying
##   Dictionary, Sleeper Agent Pillow's same pattern (issue 18).
## - on_tariff_apply (economy.gd apply_tariff, ctx = {key, tier}) and
##   on_tariff_charge (economy.gd charge, fired right after on_charge leaves
##   ctx.charged true — issue 13 landed on_charge concurrently, so this rides
##   its gate rather than querying tariff state itself; ctx = {key, amount})
##   — both were already single choke points, so no call sites moved; issue
##   16/18's held-back tariff artefacts just needed the hook wired at the
##   spot that already existed.
## - "Ranked" (Templar Severance Gold, CIA Heart Attack Gun, Backmasked
##   Vinyl, Bigfoot Toenail Clipping) reads as `ItemLogic.chain_base(defs, id)
##   != id` — a piece not at its own promotion-chain base — the same check
##   the "demote" Item's own target validity already runs. No "Demoted" flag
##   exists (a piece demoted to its base is indistinguishable from one that
##   started there), so Dark Market Light Bulb's "Demoted pieces give no
##   Score" clause stays unimplemented — Notion question, not a guess.

const Rules := preload("res://scripts/rules.gd")
const Items := preload("res://data/items.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")
const Tuning := preload("res://scripts/tuning.gd")
const ItemLogic := preload("res://scripts/item_logic.gd")

const HOOKS := [
	"on_capture", "on_piece_lost", "on_deploy",
	"on_wave_clear", "on_wave_spawn", "on_milestone",
	"on_turn_start", "on_turn_end", "on_shop_restock", "on_purchase",
	"on_gold_change", "on_score_change", "on_box_open", "on_game_over", "on_price",
	"on_item_consume", "on_rank_up", "on_tariff_apply", "on_tariff_charge",
	# --- issue 13: tariff-only trigger points (see header) ---
	"on_charge", "on_gold_gain", "on_sanction_check", "on_merge_check",
	"on_place_cost", "on_enemy_turn_start", "on_wave_roster",
]

## Artefact key -> hooks it fires on. The source of truth for "does this
## artefact do anything at this hook" — _dispatch is just the handler body.
const REGISTRY := {
	"greed": ["on_capture"],
	"score": ["on_capture"],
	"bounty": ["on_capture"],
	"lifesteal": ["on_capture"],
	"first_capture_extra": ["on_capture"],
	"move": ["on_turn_start"],
	"timer": ["on_milestone"],
	# --- issue 16: Gold/Score batch (31 artefacts, no needs-note) ---
	"tinfoil-hat": ["on_score_change", "on_gold_change"],
	"daylight-savings-jar": ["on_score_change", "on_gold_change"],
	"the-red-phone": ["on_score_change", "on_gold_change"],
	"bermuda-triangulation": ["on_score_change", "on_gold_change"],
	"naruto-run-manual": ["on_score_change"],
	"moon-landing-slate": ["on_score_change"],
	"el-dorado-body-glitter": ["on_score_change"],
	"tungsten-filled-gold-bar": ["on_gold_change"],
	"popemobile-piggy-bank": ["on_gold_change"],
	"suspiciously-large-femur": ["on_capture"],
	"sphinx-s-booger": ["on_capture"],
	"phantom-punch-glove": ["on_capture"],
	"azimuthal-pancake-map": ["on_capture"],
	"men-in-black-prescription-sunglasses": ["on_capture"],
	"holy-dna-kit": ["on_capture"],
	"cia-press-pass": ["on_capture"],
	"library-of-alexandria-matchbox": ["on_capture"],
	"voynich-dictionary": ["on_capture"],
	"nero-s-marshmallow-stick": ["on_capture"],
	"zurich-gnome-figurine": ["on_wave_clear"],
	"social-credit-report-card": ["on_wave_clear"],
	"qanon-profile-picture": ["on_wave_clear"],
	"bielefeld-library-card": ["on_wave_clear"],
	"trilateral-meeting-stickers": ["on_wave_clear"],
	"money-printer-service-manual": ["on_wave_clear"],
	"alien-autopsy-bloopers": ["on_wave_clear"],
	"golden-buddha-bobblehead": ["on_wave_clear"],
	"nigerian-prince-wire-transfer": ["on_wave_spawn"],
	"john-titor-s-crypto-wallet": ["on_milestone"],
	"putin-s-golden-toilet-brush": ["on_purchase"],
	"rapture-insurance-policy": ["on_game_over"],
	# --- issue 17: Action/Time/Piece batch (8 artefacts, no needs-note) ---
	"cia-exploding-cigar": ["on_turn_start"],
	"i-am-not-a-robot-checkbox": ["on_turn_start"],
	"seed-vault-secret-hatch": ["on_turn_start"],
	"super-soldier-multivitamins": ["on_turn_start"],
	"stargate-divination-crystal": ["on_capture"],
	"5g-microchips": ["on_turn_start"],
	"terracotta-draft-card": ["on_wave_clear"],
	"charlemagne-s-birth-certificate": ["on_wave_clear"],
	# --- issue 18: Shop/Item/Buff batch (20 artefacts, no needs-note) ---
	"denazification-visa": ["on_price"],
	"hollow-moon-cross-section": ["on_price"],
	"shrinkflation-cereal-box": ["on_turn_end", "on_price"],
	"skull-and-bones-coffin": ["on_score_change", "on_price"],
	"silk-road-coupon": ["on_wave_clear", "on_price"],
	"crop-circle-plank": ["on_wave_clear"],
	"mk-ultra-sugar-cube": ["on_deploy"],
	"obedience-flavored-tap-water": ["on_capture"],
	"holy-lint": ["on_capture"],
	"scientology-e-meter": ["on_wave_clear"],
	"xenu-ot-iii-season-pass": ["on_wave_clear"],
	"sugar-free-chemtrail-can": ["on_wave_clear"],
	"sleeper-agent-pillow": ["on_purchase"],
	"frame-25": ["on_wave_clear"],
	"manna-vending-machine": ["on_wave_clear"],
	"mao-s-loyalty-badge": ["on_purchase"],
	# chocolate-key-cake, alleged-weather-balloon, sub-antarctic-visa and
	# majestic-12-secret-handshake-diagram fire nowhere — Shop.roll/price and
	# game.gd's _box_options read g.artefacts directly, the same way Shop.buy
	# already reads slot.kind without a hook (shop-drawer-ui/08's deferred pass).

	# --- issue 13: tariff system (data/tariffs.gd) ---
	"move_cost": ["on_charge"],
	"ability_cost": ["on_charge"],
	"capture_cost": ["on_charge"],
	"pass_cost": ["on_charge"],
	"long_range_cost": ["on_charge"],
	"box_cost": ["on_charge"],
	"deploy_cost": ["on_charge"],
	"fuse_cost": ["on_charge"],
	"inflation": ["on_gold_gain"],
	"sanctions": ["on_sanction_check"],
	"regulation": ["on_merge_check"],
	"austerity": ["on_place_cost"],
	"recession": ["on_milestone"],
	"filibuster": ["on_enemy_turn_start"],
	"trade_war": ["on_wave_roster"],

	# --- issue 19: on_piece_lost (game.gd _lose_player_piece, 5 call sites) ---
	"satoshi-s-private-key": ["on_wave_clear", "on_piece_lost"],
	"lusitania-hardtack-crate": ["on_piece_lost"],
	"templar-severance-gold-one-pile": ["on_piece_lost"],
	"d-b-cooper-s-parachute": ["on_piece_lost"],
	"nibiru-hide-and-seek-trophy": ["on_wave_clear", "on_piece_lost"],
	"flight-19-blackbox": ["on_piece_lost"],
	"backmasked-vinyl": ["on_piece_lost"],
	"tutankhamun-s-death-thong": ["on_piece_lost"],

	# --- issue 19: on_item_consume (game.gd _consume_item, 3 call sites) ---
	"arms-fair-goodie-bag": ["on_item_consume"],
	"doomsday-autoclicker": ["on_item_consume"],
	"tape-eraser-magnet": ["on_item_consume"],
	"dihydrogen-monoxide-battery": ["on_item_consume"],
	"wardenclyffe-aaa-batteries": ["on_item_consume"],
	"33rd-degree-fidelity-card": ["on_item_consume"],
	"defense-lobbyist-business-card": ["on_item_consume"],

	# --- issue 19: on_rank_up (merge_logic.gd commit_merge same-id merges,
	# game.gd "promote" item) ---
	"witness-protection-mustache": ["on_rank_up"],
	"holy-grail-coaster": ["on_rank_up"],
	"bigfoot-toenail-clipping": ["on_rank_up"],

	# --- issue 19: chain-lookup reads off existing hooks (ItemLogic.chain_base) ---
	"cia-heart-attack-gun": ["on_capture"],
	"montauk-eggo-waffle": ["on_wave_clear"],

	# --- issue 19: board-half reads off existing hooks ---
	"dyatlov-geiger-counter": ["on_score_change"],
	"fema-summer-camp-flyer": ["on_turn_end"],

	# --- issue 19: enemy auto-debuff (BuffLogic is owner-agnostic already) ---
	"diplomatic-migraine-ray": ["on_wave_spawn"],

	# --- issue 19: cheap follow-ups on hooks that landed after their own
	# slice (named in issue 16/17's own Outcome sections) ---
	"casino-invisible-clock": ["on_purchase"],
	"2012-doomsday-party-hat": ["on_gold_change"],
	"fort-knox-iou": ["on_score_change", "on_wave_clear"],

	# --- issue 19: on_tariff_apply / on_tariff_charge (economy.gd apply_tariff/charge) ---
	"merchants-of-death-sample-case": ["on_tariff_apply"],
	"tunguska-toothpicks": ["on_tariff_charge"],

	# --- issue 19: capture conversion, the cheap wave-clear half (economy.gd
	# capture_score's ctx isn't exposed to game.gd's _move_player caller, so
	# the per-capture half — Zeta Reticuli Souvenir Map — is out of scope; see
	# issue 26) ---
	"stockholm-syndrome-pamphlet": ["on_wave_clear"],
}


## Run every held modifier's handler for `hook`, mutating and returning
## `ctx`. Handlers write to `ctx` for values the caller reads back (e.g. a
## score total) and touch `g` directly for side effects (clock, actions) —
## exactly what the pre-migration call sites did inline.
##
## Two held sources, dispatched as two separately key-sorted groups —
## artefacts (g.artefacts) always before tariffs (g.tariffs_active, skipped
## entirely while g.tariffs_suppressed) — see the header for why a single
## merged sort would be wrong for the one hook (on_milestone) both groups use.
static func run(g, hook: String, ctx: Dictionary = {}) -> Dictionary:
	var held: Array = g.artefacts.duplicate()
	held.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.key < b.key)
	var tariffs: Array = [] if g.tariffs_suppressed else g.tariffs_active.duplicate()
	tariffs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.key < b.key)
	for t in held + tariffs:
		if REGISTRY.get(t.key, []).has(hook):
			_dispatch(g, t.key, hook, ctx)
	return ctx


## Player-owned board pieces of the given id — the "2+/3+ of your same-type
## pieces" synergy check (Men in Black, Holy DNA Kit).
static func _count_player_id(g, id: String) -> int:
	var n := 0
	for pos in g.board:
		if g.board[pos].owner == Rules.PLAYER and g.board[pos].id == id:
			n += 1
	return n


## Player-owned board positions — the random-ally-target pool for Buff-tag
## artefacts (Crop Circle Plank, Scientology E-Meter, Xenu OT III Season
## Pass, Sugar Free Chemtrail Can).
static func _player_positions(g) -> Array:
	var out := []
	for pos in g.board:
		if g.board[pos].owner == Rules.PLAYER:
			out.append(pos)
	return out


## A uniformly random Piece Buff key, optionally restricted to one tier
## ("Tactical Piece Buff" in several issue-18 effect texts).
static func _random_buff_key(rng: RandomNumberGenerator, tier := "") -> String:
	var pool: Array = Items.PIECE_BUFFS if tier == "" \
		else Items.PIECE_BUFFS.filter(func(b: Dictionary) -> bool: return b.tier == tier)
	return pool[rng.randi() % pool.size()].key


## Catalogued life of a timed buff, in player turns (0 = dormant) — mirrors
## game.gd's private _buff_turns, kept alongside its own PIECE_BUFFS lookup
## instead of reaching across files for a one-line match.
static func _buff_turns(key: String) -> int:
	for b in Items.PIECE_BUFFS:
		if b.key == key:
			return int(b.get("turns", 0))
	return 0


## Grant one random Piece Buff to a live Dictionary — a board piece
## (BuffLogic.add takes any Dictionary with a `buffs` field) or a freshly
## built {"id": ...} piece not yet placed (Sleeper Agent Pillow).
static func _grant_buff_to(piece: Dictionary, rng: RandomNumberGenerator, tier := "") -> void:
	var key := _random_buff_key(rng, tier)
	BuffLogic.add(piece, key, _buff_turns(key))


static func _grant_buff(g, pos: Vector2i, tier := "") -> void:
	_grant_buff_to(g.board[pos], g.rng, tier)


## "Ranked" (issue 19): a piece that has been promoted at least once, i.e. it
## is not its own promotion-chain base. Reuses ItemLogic.chain_base — the same
## walk the "demote" Item's own target-validity check already does.
static func _ranked(defs: Dictionary, id: String) -> bool:
	return ItemLogic.chain_base(defs, id) != id


## A uniformly random Item of one tier (Flight 19 Blackbox, 33rd Degree
## Fidelity Card, Defense Lobbyist Business Card — all grant-on-trigger).
static func _random_item_of_tier(rng: RandomNumberGenerator, tier: String) -> Dictionary:
	var pool: Array = Items.ITEMS.filter(func(it: Dictionary) -> bool: return it.tier == tier)
	return pool[rng.randi() % pool.size()]


## Player-owned board positions on the far half of the Board from their own
## deploy zone (Dyatlov Geiger Counter's "enemy half"); the complementary
## "your half" check (FEMA Summer Camp Flyer, over enemy positions) is the
## same predicate run over the other side's pieces.
static func _on_enemy_half(pos: Vector2i) -> bool:
	return pos.y >= Tuning.BOARD_H / 2


static func _dispatch(g, key: String, hook: String, ctx: Dictionary) -> void:
	match [key, hook]:
		["greed", "on_capture"]:
			if ctx.victim_id == "pawn":
				ctx.pts += 10
		["score", "on_capture"]:
			ctx.pts += 10
		["bounty", "on_capture"]:
			if ctx.base >= 50:
				ctx.pts += 30
		["lifesteal", "on_capture"]:
			g.clock_ms += 2000
		["first_capture_extra", "on_capture"]:
			if g.turn_action_count == 0:
				g.actions_left += 1
				g.actions_max += 1
		["move", "on_turn_start"]:
			g.actions_left += 1
		["timer", "on_milestone"]:
			ctx.refill += 5000

		# --- issue 16: percentage Score/Gold gain modifiers ---
		["tinfoil-hat", "on_score_change"]:
			ctx.amount += ctx.base * 0.15
		["tinfoil-hat", "on_gold_change"]:
			ctx.amount -= ctx.base * 0.05
		["daylight-savings-jar", "on_score_change"]:
			if g.clock_ms > 90000.0:
				ctx.amount += ctx.base * 0.20
			elif g.clock_ms < 30000.0:
				ctx.amount -= ctx.base * 0.20 # a smaller gain, never negative (issue 16 ruling)
		["daylight-savings-jar", "on_gold_change"]:
			if g.clock_ms > 90000.0:
				ctx.amount += ctx.base * 0.10
			elif g.clock_ms < 30000.0:
				ctx.amount -= ctx.base * 0.10
		["the-red-phone", "on_score_change"]:
			if g.clock_ms < 30000.0:
				ctx.amount += ctx.base * 1.00
		["the-red-phone", "on_gold_change"]:
			if g.clock_ms < 30000.0:
				ctx.amount += ctx.base * 0.50
		["bermuda-triangulation", "on_score_change"]:
			if g.clock_ms < 60000.0:
				ctx.amount += ctx.base * 0.50
		["bermuda-triangulation", "on_gold_change"]:
			if g.clock_ms < 60000.0:
				ctx.amount += ctx.base * 0.25
		["naruto-run-manual", "on_score_change"]:
			# "x2 Score" on the early-clear bonus (early-clear tracking already
			# exists — game.gd _on_pass) = +1x more, additive per held copy
			if ctx.reason == "early_clear" and g.turns_since_wave <= 3:
				ctx.amount += ctx.base
		["moon-landing-slate", "on_score_change"]:
			if ctx.reason == "early_clear" and g.turns_since_wave <= 2:
				ctx.amount += ctx.base * 9.0 # "x10 Score" = +9x more
		["el-dorado-body-glitter", "on_score_change"]:
			# issue 20 fix: off the immutable base (never the running amount —
			# see the on_score_change/on_gold_change CONTRACT in the header),
			# handed back through ctx.gold_bonus so Economy.earn applies it
			# exactly once instead of free-writing g.gold mid-dispatch.
			ctx.gold_bonus += ctx.base * 0.05

		# --- issue 16: Gold gain also pays Score (mirror of the above) ---
		["tungsten-filled-gold-bar", "on_gold_change"]:
			# issue 20 fix: ctx.base + ctx.score_bonus, same reasoning as
			# El Dorado above — was g.score += roundi(ctx.amount) * 2.
			ctx.score_bonus += ctx.base * 2
		["popemobile-piggy-bank", "on_gold_change"]:
			ctx.score_bonus += ctx.base * 10

		# --- issue 16: on_capture triggers ---
		["suspiciously-large-femur", "on_capture"]:
			var is_max := true
			for pos in g.board:
				if g.board[pos].owner == Rules.ENEMY and int(g.defs[g.board[pos].id].value) > ctx.base:
					is_max = false
					break
			if is_max:
				ctx.pts += 150
				g.gold += 3
		["sphinx-s-booger", "on_capture"]:
			if ctx.attacker_id != "" and int(g.defs[ctx.attacker_id].value) < ctx.base:
				ctx.pts += 100
				g.gold += 10
		["phantom-punch-glove", "on_capture"]:
			if ctx.attacker_id != "":
				var av: int = g.defs[ctx.attacker_id].value
				if av < ctx.base: # lower-value piece takes a higher-value one: double
					ctx.pts += ctx.base
				elif av > ctx.base: # higher-value piece takes a lower-value one: half
					ctx.pts -= roundi(ctx.base * 0.5)
		["azimuthal-pancake-map", "on_capture"]:
			if ctx.attacker_id.begins_with("inv-"):
				ctx.pts += ctx.base # double
		["men-in-black-prescription-sunglasses", "on_capture"]:
			if ctx.attacker_id != "" and _count_player_id(g, ctx.attacker_id) >= 2:
				ctx.pts += roundi(ctx.base * 0.25)
		["holy-dna-kit", "on_capture"]:
			if ctx.attacker_id != "" and _count_player_id(g, ctx.attacker_id) >= 3:
				ctx.pts += ctx.base # double Score and (via the shared pts->gold
					# pipeline in Economy.earn) proportionally double Gold too
		["cia-press-pass", "on_capture"]:
			if ctx.attacker_buffed:
				ctx.pts += ctx.base # double Score
				g.gold += roundi(ctx.base * 0.5) # +50% Gold
		["library-of-alexandria-matchbox", "on_capture"]:
			var n: int = g.stock.size()
			ctx.pts += 10 * n
			g.gold += n
		["voynich-dictionary", "on_capture"]:
			if ctx.wave_capture_index == 0: # first Capture this Wave
				ctx.pts += ctx.base # double Score and Gold
		["nero-s-marshmallow-stick", "on_capture"]:
			# "+25% more than the previous capture" — a linear +25%-per-copy
			# step off the untouched base, so it stacks additively like every
			# other percentage handler here instead of compounding
			ctx.pts += roundi(ctx.base * 0.25 * ctx.turn_capture_index)

		# --- issue 16: on_wave_clear triggers ---
		["zurich-gnome-figurine", "on_wave_clear"]:
			g.gold += roundi(ctx.gold_spent * 0.10)
		["social-credit-report-card", "on_wave_clear"]:
			if ctx.clean:
				g.score += 100
			else: # issue 16 ruling: the -10 Score penalty debits Gold instead
				g.gold = maxi(g.gold - 10, 0)
		["qanon-profile-picture", "on_wave_clear"]:
			if ctx.clean:
				g.score += 200
				g.gold += 20
		["bielefeld-library-card", "on_wave_clear"]:
			if ctx.captures == 0:
				g.score += 500
		["trilateral-meeting-stickers", "on_wave_clear"]:
			g.gold += 5 * g.artefacts.size()
		["money-printer-service-manual", "on_wave_clear"]:
			g.gold += roundi(ctx.gold_base * 0.10)
		["alien-autopsy-bloopers", "on_wave_clear"]:
			g.gold += 2 * g.captured.size()
		["golden-buddha-bobblehead", "on_wave_clear"]:
			g.gold += roundi(ctx.gold_base * 0.05)

		# --- issue 16: on_wave_spawn / on_milestone / on_purchase / on_game_over ---
		["nigerian-prince-wire-transfer", "on_wave_spawn"]:
			g.score += 100
			g.gold += 10
			g.clock_ms = maxf(g.clock_ms - 3000.0, 0.0)
		["john-titor-s-crypto-wallet", "on_milestone"]:
			g.gold += int(g.clock_ms / 1000.0 / 5.0)
		["putin-s-golden-toilet-brush", "on_purchase"]:
			g.score += 5 * ctx.price
		["rapture-insurance-policy", "on_game_over"]:
			g.score += g.gold * 20
			g.gold = 0

		# --- issue 17: Action/Time/Piece batch ---
		["cia-exploding-cigar", "on_turn_start"]:
			g.actions_left += 1
		["i-am-not-a-robot-checkbox", "on_turn_start"]:
			if g._player_pieces().size() >= 8:
				g.actions_left += 1
		["seed-vault-secret-hatch", "on_turn_start"]:
			if g.items.size() >= 3:
				g.actions_left += 1
		["super-soldier-multivitamins", "on_turn_start"]:
			var buffed := 0
			for pos in g._player_pieces():
				if not BuffLogic.of(g.board[pos]).is_empty():
					buffed += 1
			if buffed >= 3:
				g.actions_left += 1
		["stargate-divination-crystal", "on_capture"]:
			# Fires from Economy.capture_score, BEFORE the capture's own
			# actions_left -= 1 / auto-pass check runs (game.gd _move_player)
			# — same ordering that lets Blitz refund its own action without
			# ever resurrecting an already-ended turn. actions_max moves too,
			# mirroring first_capture_extra (its on_capture sibling above),
			# since turn start already happened and won't re-sync it for us.
			if g.turn_action_count == 0:
				g.actions_left += 1
				g.actions_max += 1
		["5g-microchips", "on_turn_start"]:
			var allies: int = g._player_pieces().size()
			var enemies: int = g.board.size() - allies
			g.clock_ms += (allies - enemies) * 1000
		["terracotta-draft-card", "on_wave_clear"]:
			var mix: Array = Tuning.ARMIES.get(g.next_army, Tuning.ARMIES[Tuning.DEFAULT_ARMY])
			g.stock.append(mix[g.rng.randi() % mix.size()]) # bare id: a fresh
				# piece carries no board state, so ADR-0002's plain-String form
				# applies (a Dictionary would only be needed for a piece pulled
				# off the board with state attached, e.g. Extraction)
		["charlemagne-s-birth-certificate", "on_wave_clear"]:
			g.clock_ms += 10000

		# --- issue 18: Shop price modifiers (Shop.price's on_price seam) ---
		["denazification-visa", "on_price"]:
			if ctx.kind == "item" and ctx.tier == "Tactical":
				ctx.amount -= ctx.base * 0.50
		["hollow-moon-cross-section", "on_price"]:
			if ctx.kind == "artefact":
				ctx.amount -= ctx.base * 0.25
		["shrinkflation-cereal-box", "on_price"]:
			ctx.amount += ctx.base * 0.50
		["shrinkflation-cereal-box", "on_turn_end"]:
			g.gold += 10
			g.score += 10
			g.clock_ms += 1000.0
		["skull-and-bones-coffin", "on_price"]:
			ctx.amount += ctx.base * 0.05
		["skull-and-bones-coffin", "on_score_change"]:
			if g.gold >= 200:
				ctx.amount += ctx.base * 0.20
		["silk-road-coupon", "on_price"]:
			if g.silk_road_active:
				ctx.amount -= ctx.base * 0.50
		["silk-road-coupon", "on_wave_clear"]:
			# "5-Wave Milestone" (12 effect texts) is a different cadence than
			# on_milestone's own 10-wave clock-refill trigger, so this checks
			# the just-cleared wave directly rather than piggybacking that hook.
			if g.wave % 5 == 0:
				g.silk_road_active = true # reset false at the top of every WaveLogic.queue()

		# --- issue 18: Buff-tag triggers, all through BuffLogic.add ---
		["crop-circle-plank", "on_wave_clear"]:
			if g.wave % 5 == 0: # "5-Wave Milestone" — see silk-road-coupon's on_wave_clear case above
				var pool := _player_positions(g)
				for i in mini(2, pool.size()):
					var idx: int = g.rng.randi() % pool.size()
					_grant_buff(g, pool[idx])
					pool.remove_at(idx)
				g.gold = maxi(g.gold - 10, 0)
		["mk-ultra-sugar-cube", "on_deploy"]:
			_grant_buff(g, ctx.pos, "Tactical")
		["obedience-flavored-tap-water", "on_capture"]:
			if ctx.wave_capture_index == 0 and ctx.attacker_pos.x >= 0:
				_grant_buff(g, ctx.attacker_pos, "Tactical")
		["holy-lint", "on_capture"]:
			if ctx.attacker_pos.x >= 0:
				_grant_buff(g, ctx.attacker_pos)
		["scientology-e-meter", "on_wave_clear"]:
			# "the piece" — Wave clear has no single trigger piece, so this
			# reads it as a random ally (same reading as Xenu OT III below).
			g.gold = maxi(g.gold - 5, 0)
			var se_pool := _player_positions(g)
			if not se_pool.is_empty():
				_grant_buff(g, se_pool[g.rng.randi() % se_pool.size()])
		["xenu-ot-iii-season-pass", "on_wave_clear"]:
			g.gold = maxi(g.gold - 15, 0)
			var xe_pool := _player_positions(g)
			for i in 3: # 3 independent random-ally picks; may repeat a piece
				if xe_pool.is_empty():
					break
				_grant_buff(g, xe_pool[g.rng.randi() % xe_pool.size()])
		["sugar-free-chemtrail-can", "on_wave_clear"]:
			if g.wave % 5 == 0:
				for pos in _player_positions(g):
					_grant_buff(g, pos)
		["sleeper-agent-pillow", "on_purchase"]:
			# the piece landed as a plain id string at the end of g.stock
			# (Shop.buy, just before this hook runs) — replace it with a
			# Dictionary carrying the buff; _place's `entry is Dictionary`
			# branch already merges any extra fields onto the board piece.
			if ctx.kind == "piece" and not g.stock.is_empty():
				var piece := {"id": ctx.key}
				_grant_buff_to(piece, g.rng, "Tactical")
				g.stock[g.stock.size() - 1] = piece

		# --- issue 18: Item-tag triggers ---
		["frame-25", "on_wave_clear"]:
			var tac_pool: Array = Items.ITEMS.filter(func(it: Dictionary) -> bool:
				return it.tier == "Tactical")
			g.items.append(tac_pool[g.rng.randi() % tac_pool.size()])
			g.gold = maxi(g.gold - 10, 0)
		["manna-vending-machine", "on_wave_clear"]:
			if g.wave % 5 == 0:
				for i in 2:
					g.items.append(Items.ITEMS[g.rng.randi() % Items.ITEMS.size()])
		["mao-s-loyalty-badge", "on_purchase"]:
			if ctx.kind == "item":
				var tier := ""
				for it in Items.ITEMS:
					if it.key == ctx.key:
						tier = it.tier
						break
				if tier == "Tactical":
					var pool: Array = Items.ITEMS.filter(func(it: Dictionary) -> bool:
						return it.tier == "Tactical")
					g.items.append(pool[g.rng.randi() % pool.size()])

		# --- issue 13: tariff system ---
		# The 8 action-cost tariffs share one hook: charge() calls run() once
		# per charge with ctx.key set to the specific tariff it's charging,
		# and only the matching held key may set ctx.charged — with several
		# cost tariffs held at once (common; see data/scenarios.gd "Tariffs:
		# all action costs"), each dispatch here still checks `key` against
		# `ctx.key` or an unrelated held tariff would gate a charge for a key
		# it isn't. ctx.charged is a flag, not a counter, so a key held twice
		# (a redrawn Mild tariff) still only gates once — no double charge.
		["move_cost", "on_charge"], ["ability_cost", "on_charge"], ["capture_cost", "on_charge"], ["pass_cost", "on_charge"], ["long_range_cost", "on_charge"], ["box_cost", "on_charge"], ["deploy_cost", "on_charge"], ["fuse_cost", "on_charge"]:
			if ctx.key == key:
				ctx.charged = true
		["inflation", "on_gold_gain"]:
			# stacks multiplicatively per held copy (header) — data/tariffs.gd:
			# "All gold gains reduced 10% (stacks)"
			ctx.amount *= 0.9
		["sanctions", "on_sanction_check"]:
			if ctx.id == g.sanctioned_id:
				ctx.blocked = true
		["regulation", "on_merge_check"]:
			if ctx.a == "pawn" or ctx.b == "pawn":
				ctx.blocked = true
		["austerity", "on_place_cost"]:
			ctx.cost *= 2
		["recession", "on_milestone"]:
			ctx.refill *= 0.5
		["filibuster", "on_enemy_turn_start"]:
			ctx.actions += 1
		["trade_war", "on_wave_roster"]:
			# +1 piece per wave, drawn from the wave's own mix, never the King
			# (review 2026-07-03)
			var extras: Array = ctx.roster.filter(func(id: String) -> bool: return id != "king")
			if not extras.is_empty():
				ctx.roster.append(extras[g.rng.randi() % extras.size()])

		# --- issue 19: on_piece_lost (game.gd _lose_player_piece) ---
		["satoshi-s-private-key", "on_wave_clear"]:
			g.gold += 2 * g._player_pieces().size()
		["satoshi-s-private-key", "on_piece_lost"]:
			g.gold = maxi(g.gold - 2, 0)
		["lusitania-hardtack-crate", "on_piece_lost"]:
			if not BuffLogic.of(g.board[ctx.pos]).is_empty():
				g.gold += 150
				g.score += 150
		["templar-severance-gold-one-pile", "on_piece_lost"]:
			if _ranked(g.defs, ctx.id):
				g.gold += 150
		["d-b-cooper-s-parachute", "on_piece_lost"]:
			g.gold += roundi(g.defs[ctx.id].value * 0.75)
		["nibiru-hide-and-seek-trophy", "on_wave_clear"]:
			g.nibiru_wave_streak += 1
			g.gold += 10 * g.nibiru_wave_streak
		["nibiru-hide-and-seek-trophy", "on_piece_lost"]:
			g.nibiru_wave_streak = 0
		["flight-19-blackbox", "on_piece_lost"]:
			g.items.append(_random_item_of_tier(g.rng, "Tactical"))
		["backmasked-vinyl", "on_piece_lost"]:
			if _ranked(g.defs, ctx.id):
				g.stock.append(ItemLogic.chain_base(g.defs, ctx.id))
		["tutankhamun-s-death-thong", "on_piece_lost"]:
			if ctx.reason == "captured" and ctx.attacker_pos.x >= 0:
				BuffLogic.add(g.board[ctx.attacker_pos], "slow", _buff_turns("slow"))

		# --- issue 19: on_item_consume (game.gd _consume_item) ---
		["arms-fair-goodie-bag", "on_item_consume"]:
			if ctx.tier == "Strategic":
				g.gold += 25
		["doomsday-autoclicker", "on_item_consume"]:
			if ctx.tier == "Decisive":
				g.score += 200
				g.clock_ms += 10000
		["tape-eraser-magnet", "on_item_consume"]:
			if ctx.last:
				g.score += 100
				g.gold += 50
		["dihydrogen-monoxide-battery", "on_item_consume"]:
			if ctx.tier == "Tactical" and g.dihydrogen_free_wave != g.wave:
				g.dihydrogen_free_wave = g.wave
				ctx.cancel = true
		["wardenclyffe-aaa-batteries", "on_item_consume"]:
			if g.wardenclyffe_free_wave != g.wave:
				g.wardenclyffe_free_wave = g.wave
				ctx.cancel = true
		["33rd-degree-fidelity-card", "on_item_consume"]:
			if ctx.tier == "Tactical":
				g.item_use_tactical_count += 1
				if g.item_use_tactical_count % 3 == 0:
					g.items.append(_random_item_of_tier(g.rng, "Strategic"))
			elif ctx.tier == "Strategic":
				g.item_use_strategic_count += 1
				if g.item_use_strategic_count % 3 == 0:
					g.items.append(_random_item_of_tier(g.rng, "Decisive"))
		["defense-lobbyist-business-card", "on_item_consume"]:
			if ctx.tier != "Tactical":
				g.items.append(_random_item_of_tier(g.rng, "Tactical"))

		# --- issue 19: on_rank_up (merge_logic.gd commit_merge, game.gd "promote") ---
		["witness-protection-mustache", "on_rank_up"]:
			g.clock_ms += 20000
		["holy-grail-coaster", "on_rank_up"]:
			if ctx.pos.x >= 0:
				_grant_buff(g, ctx.pos)
			elif ctx.stock_index >= 0: # landed in Stock: promote the bare id at
				# the exact index the merge placed it — NOT g.stock.size() - 1,
				# which a same-call handler appending its own grant (Bigfoot
				# Toenail Clipping) would otherwise shift out from under this
				var piece := {"id": g.stock[ctx.stock_index]} # (Sleeper Agent
				_grant_buff_to(piece, g.rng)                  # Pillow's pattern)
				g.stock[ctx.stock_index] = piece
		["bigfoot-toenail-clipping", "on_rank_up"]:
			g.stock.append(ItemLogic.chain_base(g.defs, ctx.id))

		# --- issue 19: chain-lookup off the existing on_capture/on_wave_clear hooks ---
		["cia-heart-attack-gun", "on_capture"]:
			if ctx.turn_capture_index == 0 and ctx.attacker_id != "" \
					and (ctx.attacker_buffed or _ranked(g.defs, ctx.attacker_id)):
				g.gold += roundi(ctx.base) # +100% Gold
		["montauk-eggo-waffle", "on_wave_clear"]:
			if g.wave % 5 == 0:
				var candidates: Array = []
				for i in g.stock.size():
					var e = g.stock[i]
					var id: String = e if e is String else e.id
					if g.defs[id].next != null:
						candidates.append(i)
				if not candidates.is_empty():
					var idx: int = candidates[g.rng.randi() % candidates.size()]
					var e = g.stock[idx]
					if e is String:
						g.stock[idx] = g.defs[e].next
					else:
						e.id = g.defs[e.id].next

		# --- issue 19: board-half reads (Tuning.BOARD_H, owner-agnostic) ---
		["dyatlov-geiger-counter", "on_score_change"]:
			var far := 0
			for pos in _player_positions(g):
				if _on_enemy_half(pos):
					far += 1
			if far >= 3:
				ctx.amount += ctx.base # +100% Score
		["fema-summer-camp-flyer", "on_turn_end"]:
			var near := 0
			for pos in g.board:
				if g.board[pos].owner == Rules.ENEMY and not _on_enemy_half(pos):
					near += 1
			g.gold += 2 * near

		# --- issue 19: enemy auto-debuff (BuffLogic is owner-agnostic already) ---
		["diplomatic-migraine-ray", "on_wave_spawn"]:
			var strongest := Vector2i(-1, -1)
			for pos in g.board:
				if g.board[pos].owner == Rules.ENEMY and (strongest.x < 0
						or g.defs[g.board[pos].id].value > g.defs[g.board[strongest].id].value):
					strongest = pos
			if strongest.x >= 0:
				BuffLogic.add(g.board[strongest], "slow", _buff_turns("slow"))

		# --- issue 19: cheap follow-ups (named in issue 16/17's Outcome) ---
		["casino-invisible-clock", "on_purchase"]:
			g.clock_ms += 25000
		["2012-doomsday-party-hat", "on_gold_change"]:
			# issue 20 fix: ctx.base, not the running ctx.amount (see the
			# on_score_change/on_gold_change CONTRACT in the header) — Clock
			# has no ctx output field of its own, so the direct g.clock_ms
			# write stays (same sanctioned pattern as lifesteal on_capture),
			# only the read source changes.
			g.clock_ms += ctx.base * 500.0 # +5s per 10 Gold
		["fort-knox-iou", "on_score_change"]:
			if g.gold < 10:
				ctx.amount += ctx.base * 0.5
		["fort-knox-iou", "on_wave_clear"]:
			if g.gold < 10:
				g.items.append(_random_item_of_tier(g.rng, "Tactical"))

		# --- issue 19: on_tariff_apply / on_tariff_charge (economy.gd) ---
		["merchants-of-death-sample-case", "on_tariff_apply"]:
			g.gold += 100
		["tunguska-toothpicks", "on_tariff_charge"]:
			g.score += 150
			g.clock_ms += 5000

		# --- issue 19: capture conversion, the cheap wave-clear half ---
		["stockholm-syndrome-pamphlet", "on_wave_clear"]:
			if not g.captured.is_empty():
				g.stock.append(g.captured.pop_front())
