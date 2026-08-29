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
## that lets the Blitz item's free-move flag (game.gd _move_player, checked
## before that decrement) skip it without ever resurrecting an already-ended
## turn. Covered by test_items.gd
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
##   the "demote" Item's own target validity already runs.
##
## issue 42 (ruled 2026-08-29) added "Demoted": currently BELOW the piece's
## own historical peak rank — option (b), chosen over "was ever demoted" —
## which unblocked Dark Market Light Bulb. `peak_ranked` is a sticky stamp
## run() writes on every on_rank_up dispatch (a piece is Ranked by
## definition right after a rank-up); `_demoted()` reads it back as
## "peak_ranked is set but the piece is at its base id right now" — the
## moment a later rank-up re-Ranks the piece, that comparison flips false on
## its own, satisfying "clears on re-promotion" for free, no separate reset
## needed. Rides the piece Dictionary per ADR-0002, so it round-trips through
## save_config.gd/Extraction the same way the per-piece capture ledger
## (issue 25) already does — no new save code. Covered by test_items.gd
## ("Dark Market Light Bulb: Ranked doubles Gold, Demoted zeroes Score,
## re-promoting clears Demoted").
##
## issue 24 (combat & positioning, split out of 19) added the "post-move ctx
## flag" mechanism issue 19's own Outcome deferred:
## - USS Eldridge Invisibility Paint / Royal Fiat (Undamaged) both want to
##   reposition the capturing piece AFTER `_move_player`'s own slide has
##   already landed it on `to` — but on_capture fires from
##   Economy.capture_score, mid-`_move_player`, BEFORE that slide runs.
##   capture_score now stashes its ctx on `g.last_capture_ctx` (a Dictionary,
##   so the reference survives the call boundary) right before returning
##   `ctx.pts`; `_move_player` reads `return_to_start`/`move_to_backrow` back
##   off it right after its own `board[to] = board[from]` — the same shape as
##   on_item_consume's `cancel`, just read one call frame later since the
##   mutation it's gating hasn't happened yet when the hook runs. Both gate
##   on `turn_capture_index == 0 and attacker_pos.x >= 0` (first Capture this
##   Turn, a real attacker) — same pattern as CIA Heart Attack Gun/Obedience-
##   Flavored Tap Water above. Royal Fiat's landing tile is the first empty
##   back-row (y=0) square scanning x=0..BOARD_W-1 (ruled 2026-08-28, no GDD
##   guidance on ties); a full back row is a no-op, the piece just stays on
##   `to`. Only the plain-capture path reads either flag — Trap/Bomb/
##   Multicapture's branches `return` before reaching it, and a second
##   capture_score call inside Multicapture would overwrite
##   `g.last_capture_ctx` anyway, so `_move_player` snapshots both flags into
##   locals immediately after its own (first) capture_score call rather than
##   re-reading `g.last_capture_ctx` at the tail. Holding both artefacts at
##   once is a real if rare combo (both Rare); return_to_start wins the tie
##   (checked first) since it fully undoes the move rather than partially
##   redirecting it. Covered by test_items.gd ("USS Eldridge Invisibility
##   Paint" / "Royal Fiat (Undamaged)" / the two-held-together case).
## - Fireproof Pajamas is on_piece_lost's own `cancel` flag (new, mirroring
##   on_item_consume's), scoped to `ctx.reason == "destroyed"` — the single
##   choke point `_destroy` already is for every Item/Tariff kill (Drone
##   Strike, Air Strike, Sniper, bomb detonation via `_detonate`, the
##   jd_vance Tariff). `_lose_player_piece` now returns its ctx (previously
##   void; the other 4 call sites already ignored the return value, so this
##   is additive) and only increments `lost_player` when not cancelled.
##   Captures/Trap/Reflect don't set `reason == "destroyed"`, so they're
##   untouched.
## - Hoffa's Cement Shoes reuses on_piece_lost's `reason == "captured"` +
##   `attacker_pos` (Tutankhamun's Death Thong's exact gate) to set a new
##   `destroy_attacker` output flag, once per Wave (`g.hoffa_used_this_wave`,
##   reset on_wave_clear — the "satoshi-s-private-key"-style two-hook shape).
##   The enemy-move loop (game.gd `_run_enemy_actions`) reads the flag
##   straight off `_lose_player_piece`'s return and, when set, removes the
##   attacker too — Trap's existing mutual-destruction shape, just artefact-
##   gated instead of BuffLogic-gated, and once per Wave instead of every
##   time. Covered by test_items.gd ("Hoffa's Cement Shoes").
##
## issue 24 left unimplemented (see .scratch/gdd-gaps/issues/24's Outcome for
## the full list): Cheyenne Mountain Doorbell / Winchester Salt Lined Doors
## (zone rules need their own design pass into Rules.legal_moves/AI
## targeting), Bovine Tractor Beam / Roanoke Hex Kit (player-initiated
## targeting UI, not a hook), Inflatable Vietcong Torpedo / UAP Breath Mint
## (a new pre-capture "dodge" choke point plus an undecided modal-choice /
## landing-tile ruling), Zapruder's Director's Cut (needs a recorded "last
## action" shape spanning move/capture/item/merge), Pegasus Free Trial (a
## per-piece exception to `moved_this_turn`'s flat Array-membership lock —
## risky to redesign under two concurrent branches also touching move
## sites), Alien Pet Rocks (a new `moved_this_wave` set threaded through
## every move/place site), Curtain Rods Bag (the same ctx-survives-earn()
## gap issue 26 is scoped to close).
##
## issue 23 (Buff lifecycle, split out of 19) added the Piece-Buff-side
## choke points 19 had already done for Item/piece-lost/rank-up:
## - on_buff_apply fires from game.gd's new `_apply_buff(piece, key, turns,
##   pos, fire_hook)` — was BuffLogic.add called straight from the buff_box
##   Item apply and half a dozen artefact grants in this file (_grant_buff_to
##   now takes `g` and routes through it too). ctx = {piece, key, turns,
##   pos}; `pos` is Vector2i(-1,-1) for a grant onto a piece not on the board
##   (Stock — Holy Grail Coaster's stock-index branch, Sleeper Agent
##   Pillow). AFTER the buff lands, not before — nothing needs to veto a
##   grant. `stunned` (the debuff Stun leaves on whoever triggers it) rides
##   the same `buffs` list but is NOT a catalogued Piece Buff (Items.
##   PIECE_BUFFS has no entry for it — see buff_logic.gd's own header on the
##   "buff"/"Buff" naming collision) and its 2 call sites still call
##   BuffLogic.add directly, deliberately bypassing this hook. `fire_hook` is
##   false for Pied Piper's Rat Census's own copy — otherwise two adjacent
##   allies both holding it would ping-pong the copy back and forth forever.
## - on_buff_consume fires from game.gd's new `_consume_buff(pos, key)` —
##   was 5 scattered BuffLogic.consume call sites (Reflect/Shield x2,
##   Critical, Range, Multicapture) plus 2 new ones added alongside this
##   hook: Bomb and Trap previously just erased the carrying piece with no
##   explicit consume() call (moot for BuffLogic's own state, since the
##   piece is discarded either way) — now consumed first, purely so
##   Cleopatra's Hairpin/Guidestone Blood Ritual see those two triggers.
##   Fires AFTER removal (no veto needed); ctx = {pos, key}. `_buff_tier(key)`
##   is Cleopatra's Decisive-only scope; `_nearest_ally`/`_adjacent_ally` are
##   the two different "closest ally" reads KGB Photo Eraser (transfer, any
##   distance) and Pied Piper (adjacent only) each need.
## - on_demote / on_piece_demoted both fire from game.gd's "demote" Item
##   case — the gate BEFORE the mutation (ctx = {pos, blocked}, Atlantis Snow
##   Globe / Antikythera Warranty Card set `blocked` for their own pieces)
##   and the event AFTER a demotion that wasn't blocked (ctx = {pos, old_id,
##   id}, mirrors on_rank_up's shape). Guidestone Blood Ritual is the only
##   on_piece_demoted listener — unlike Dark Market Light Bulb's still-open
##   "Demoted pieces give no Score" ask above (a PERSISTENT is-this-piece-
##   demoted flag, which genuinely doesn't exist), "whenever a piece IS
##   demoted" is a one-shot event with nothing to persist, so it isn't
##   blocked by that same gap.
## - on_buff_removal fires from game.gd's "radar_jamming" Item case, gating
##   the BuffLogic.clear call (radar_jamming used to also strip the
##   box-carrier `buff` flag outside this gate — that flag, and the gate-free
##   erase, are both gone with the carrier, issue 47). Antikythera
##   Warranty Card is its only listener. No Tariff or other enemy effect
##   currently removes a Piece Buff, so this clause is vacuously satisfied
##   everywhere else today; the hook exists for the one mechanism named in
##   the effect text and the GDD's own "Sanctions/radar_jamming/demote" list.
## - Numbers Station Sudoku / Bohemian Grove Friendship Bracelet (Buff Box
##   +1/+2 choices, the former at +5 Gold/pick) are a plain UI change in
##   game.gd's `_open_buff_pick`/`_buff_chosen` (`_artefact_count(key)`), not
##   a REGISTRY hook — issue 18's own held-back note already called this one
##   out as "not a hook at all", so it stays off this file's choke points
##   entirely, additive per held copy same as everything else here.
## - Abduction Probe ("pieces can carry 2 Piece Buffs at once") stays
##   unimplemented after the audit the issue asked for: BuffLogic.add already
##   appends to a plain Array with no 1-buff cap anywhere — not in BuffLogic,
##   not in buff_box's Item targeting, not in any artefact grant — so a
##   second Piece Buff already lands today, artefact or not. There is no
##   existing cap to lift from 1 to 2, so "implementing" this artefact would
##   mean introducing a brand-new base-game restriction (default 1, this
##   artefact raises it to 2) that nothing today asks for — a design
##   decision, not a wiring job. Notion question, not a guess.
##
## issue 25 (split from 19 — 3 artefacts want a capture count kept per
## INDIVIDUAL piece, not Economy's run-wide wave/turn_capture_count) added a
## board-piece ledger: `captures` (lifetime) and `wave_captures` (reset every
## Wave in WaveLogic.queue), both absent = 0. game.gd's `_note_capture(pos)`
## is the single choke point that increments both, called from Economy.
## capture_score (the player's own capture — g._note_capture(attacker_pos),
## before the on_capture hook runs, so a handler in the same dispatch already
## sees the bump) and from _run_enemy_actions' capture branch directly (the
## enemy's own capture never reaches capture_score — the enemy doesn't score).
## Those are the two, and only the two, "a piece's OWN capture resolves"
## sites issue 25 names; the Reflect/Trap/Bomb counter-kill branches are a
## different resolution path and are out of scope. ADR-0002 (Stock holds
## opaque piece state) already settles the round-trip question the issue
## raised without guessing: nothing strips a field it doesn't know about, so
## `captures` rides through Extraction/placement exactly like Piece Buffs
## already do — no new code needed, covered by test_save.gd. `wave_captures`
## is the one field this slice DOES reach in and strip, by name, at the one
## place issue 25 named (WaveLogic.queue) — on both g.board and any Dictionary
## Stock entries, so a piece Extracted mid-Wave doesn't carry a stale count
## into a Wave it never played.
## - on_capture ctx grew `victim_captures` (economy.gd capture_score reads
##   g.board[victim_pos].get("captures", 0) before the caller erases the
##   victim) — Chupacabra Chew Toy's "+10 more Gold if the captured piece had
##   captured one of yours" (only enemies capture player pieces, so any
##   lifetime count > 0 already means "one of yours").
## - Alien Rocket Toy plugs into the same on_capture dispatch: on
##   ctx.attacker_pos's 3rd lifetime capture, promotes it in place
##   (mirroring game.gd's "promote" Item) and fires on_rank_up itself —
##   exactly the "once on_rank_up lands" plan the issue described, since 19
##   had already wired that hook.
## - Zodiac Crossword Puzzle reads `wave_captures` on on_wave_clear (fired
##   from WaveLogic.queue BEFORE the reset above runs, so it still sees the
##   Wave that just ended) and grants +1 Piece Buff to the ally with the
##   highest count — ties keep whichever board position is found first, the
##   same reading Diplomatic Migraine Ray's "the strongest" already uses.
##
## issue 26 (the economy/Shop/Box grab-bag split off issue 19) shipped 15 of
## its ~39 rows, picking the ones with an existing hook or a single contained
## call site and leaving anything needing brand-new player-facing UI (a
## reroll button, a choice modal, a decline path, an alt payment currency, a
## gold-for-actions button) or a genuine Notion ruling (item cap's baseline
## size, the retired "Shop visit" term, "Piece Box" not being a real Box
## kind) for a follow-up — see .scratch/gdd-gaps/issues/26's Outcome. New:
## - on_gold_zero (economy.gd/shop.gd `spend_gold`, the shared debit+floor
##   choke point both now route every Gold spend through) fires once, only
##   when a spend lands exactly on 0 Gold that wasn't already there — Zero-
##   Point Energy Drink. shop.gd can't call economy.gd's `spend_gold` (that
##   file already preloads Shop; a preload back would cycle), so Shop.buy
##   inlines the same 3 lines instead of the two staying in sync by hand
##   being a real risk — see the comment there.
## - on_deploy's ctx grew `skip_action` (Hitler's Argentinian Passport: the
##   deploy still happens, `actions_left` just isn't spent) — seeded false by
##   game.gd's `_place`, the same output-field pattern as on_charge's
##   `charged` and on_sanction_check's `blocked`.
## - on_wave_roster (already wired for Trade War, issue 13) gets its first
##   artefact users: HAARP Volume Knob / Wuhan Vial Label add a piece the
##   same way Trade War does (drawn from the wave's own mix, never the King);
##   Pigeon Charging Cable removes one, floored so a wave never spawns with
##   zero non-King pieces.
## - Some rows never needed a REGISTRY/hook entry at all — Nazca Boarding
##   Pass, Nuclear Football Menu, Doomsday Clock Snooze Button and Agartha
##   Welcome Mat are standing rules read directly off `g.artefacts` at their
##   one call site (game.gd's `_deploy_tiles`/`_held`, `_item_apply`,
##   `_process`'s per-frame Clock tick, shop.gd's `can_buy`/`buy`) — the same
##   no-hook pattern chocolate-key-cake already used (see REGISTRY's comment
##   there), not a gap in the engine.
##
## issue 21 (echo and meta-triggers, split out of 19 because it's one real
## system — a meta-layer over run() itself, not a scatter of one-offs) grew
## run()'s own contract: `fired` (built inline, not a new field on `g`) is
## the subset of `held + tariffs` that actually dispatched this call — not
## just which keys are held, the distinction Bilderberg Hotel Slippers'
## effect text needs ("two or more of your Artefacts trigger", not "own").
## A dedicated pass, `_run_meta_triggers`, runs once after the normal
## dispatch loop and reads `fired` to run the family of artefacts that react
## to another artefact's own trigger:
## - Polybius Cartridge / Max Headroom Mask / Red Diary's Missing Pages: for
##   every key in `fired` (hook-scoped to on_capture / on_wave_clear+
##   on_wave_spawn / on_piece_lost respectively), one extra `_dispatch` per
##   held copy — "Capture"/"Wave"/"on losing a piece" Artefact in their GDD
##   text means "fired via this hook", not a `bonus` tag (none of the three
##   carry a Capture/Wave bonus tag in data/artefacts.js — Special only).
## - CERN Ctrl+Z Shortcut: for every *distinct* key in `fired` that is held
##   2+ times (REGISTRY already implied this; nothing read it before this
##   slice), one extra `_dispatch` per held CERN copy — flat, not scaled by
##   how many duplicates the key itself has.
## - Bilderberg Hotel Slippers / Illuminati: NWO Booster Pack: pure
##   observers, no `_dispatch` of their own — +15 Gold (any hook, `fired.
##   size() >= 2`) / +2 Gold+20 Score per on_capture entry in `fired`,
##   scaled by held copies.
## - 100% Genuine Original Mona Lisa: the first entry in `fired` (any hook)
##   each Turn is echoed once per held copy. "Each Turn, including enemy
##   Turns" is `g.mona_lisa_turn_done`, reset by `run()` itself (below, NOT
##   in `_run_meta_triggers` — it must be false before *this* call's own
##   dispatch loop runs, so the reset call's own first fire is still
##   eligible) at both on_turn_start (player) and on_enemy_turn_start
##   (Economy.enemy_actions, the one hook every enemy turn already dispatches
##   before anything else can) — the only two "a Turn just began" choke
##   points that already exist, so no new call site.
## - Déjà Vu Glitch: "first Score/Gold gain each Turn: they trigger again"
##   reads as the WHOLE gain repeating, not a second run through every
##   handler (that would double-charge reason-gated handlers like Naruto Run
##   Manual's early-clear bonus, and Economy.earn's own ctx never survives
##   the call boundary to re-invoke anyway — the exact gap issue 26 is
##   scoped to close) — so this scales the hook's own already-computed
##   `ctx.amount` by `(1 + held copies)` once, gated by its own
##   `dejavu_score_turn_done`/`dejavu_gold_turn_done` (on_turn_start only;
##   Score/Gold gains don't happen on enemy Turns today).
##
## RE-ENTRANCY RULE (issue 21): every extra trigger the meta pass produces
## goes straight through `_dispatch`, never back through `run()` — so an
## echo can never itself be observed by `_run_meta_triggers` (that pass only
## ever runs once, off the single `fired` snapshot the normal loop built) and
## a chain or a ping-pong between two held echo artefacts is structurally
## impossible, not just guarded. `g.artefact_echo_depth` is the
## belt-and-suspenders backstop for a future handler that DID call `run()`
## from inside `_dispatch` — `run()` only calls `_run_meta_triggers` at
## depth 0. Stacking stays additive (N held copies of an echo artefact = N
## extra `_dispatch` calls, not compounding) and ordering stays
## irrelevant (the meta pass reads `fired`, built from the same key-sorted
## `held + tariffs` loop the header's ORDERING rule already covers, and
## every echoed `_dispatch` targets one already-determined key — nothing
## about the echo pass itself depends on iteration order). Covered by
## test_items.gd ("two echo artefacts + a percentage artefact stay bounded
## and order-independent").
##
## issue 28 fixed a separate gap in the same layer: `fired` used to carry
## bare keys, so an echoed 5-Wave Milestone artefact (_milestone5_hit) always
## checked its cadence against the default acquired_wave=1 instead of the
## firing copy's own stamp — two copies acquired on different waves would
## echo on the wrong beat. `fired` now carries the whole entry through to
## every echoed `_dispatch` call; the RE-ENTRANCY RULE above is untouched —
## still bare `_dispatch`, never `run()`. Covered by test_items.gd ("Max
## Headroom Mask echoes John Titor's Crypto Wallet on THAT copy's own beat").
##
## Illuminati Fridge Magnet, Deep State Yearbook and New World Order
## Gerrymandering stay unimplemented — real design rulings, not guesses (see
## .scratch/gdd-gaps/issues/21's Outcome). So do Ecdysis Sheddings ("copies
## the last Artefact you bought" needs a way to invoke an arbitrary key's
## handler under a hook/ctx shape it wasn't built for — on_purchase's ctx
## has none of on_capture's `victim_id`/`attacker_id` fields a copied Greed
## or Sphinx's Booger would read) and Troll Farm Employee of the Month
## ("Wave Artefacts also trigger on Wave start" would hand on_wave_clear's
## handlers an on_wave_spawn ctx missing `gold_spent`/`gold_base`/`captures`
## — most of them would silently pay out on zeroed fields).

## issue 22 (split out of 19: "the reactive on_tariff_apply/on_tariff_charge
## hooks can't express changing whether/how a Tariff applies") added the
## filter/scale/cancel shapes those two hooks were missing:
## - Panama Papers Shredder ("Mild Tariffs don't affect you") and Amber Room
##   Bubble Wrap ("ignore Inflation and other gold-reducing Tariffs") both
##   dispatch before the tariff they're gating (artefacts-before-tariffs
##   ordering, header above) and set a ctx flag the gated tariff's own case
##   reads — `on_charge`'s 6 Mild action-cost keys check `ctx.mild_blocked`
##   (split from the 2 Moderate keys, deploy_cost/fuse_cost, which don't);
##   `on_gold_gain`'s Inflation checks `ctx.gain_immune`, set by either
##   artefact (a boolean gate, not a percentage — no compounding to reason
##   about). Neither artefact touches on_tariff_apply/on_tariff_charge
##   themselves (issue 19's "a Tariff was applied/charged" meta-notifications
##   fire regardless — Merchants of Death Sample Case still pays out on a
##   Mild Tariff even though Panama Papers Shredder just neutralized its
##   effect); on_tariff_charge additionally just can't fire for a blocked
##   charge, since Economy.charge only dispatches it inside `if ctx.charged`.
## - Ark Grounding Cable ("Tariff penalties reduced by 50%") is the
##   percentage-scale twin — economy.gd's charge() grew `base`/`amount` ctx
##   fields (mirroring on_score_change) so `ctx.amount -= ctx.base * 0.5` can
##   shrink the actual gold deducted, off the immutable base like every other
##   percentage handler.
## - Salvation Gift Card ("cancelled; recharges at each 5-Wave Milestone") is
##   the veto — economy.gd's apply_tariff() grew `ctx.cancel`, read right
##   after the on_tariff_apply dispatch, same shape as on_item_consume's
##   cancel. Recharge state (`g.salvation_charged`, starts true) is consumed
##   on a successful veto and restored on_wave_clear at wave%5==0, the same
##   cadence Silk Road Coupon already established (issue 18).
## - Exhibit 399 (tariff choice) and SETI's Red Marker (tariff inversion) stay
##   unimplemented — both need a design ruling before any code (a blocking
##   modal choice; a per-Tariff "equivalent bonus" table) — see the issue 22
##   Outcome / Notion questions.
##
## issue 31 (capture-context effects) added:
## - Curtain Rods Bag ("first Capture each Wave: double Score, but it pays no
##   Gold") needs the Score and Gold sides of one Economy.earn call to
##   diverge. game.gd's capture call site tags that one earn() with reason
##   "wave_first_capture" (readable right after Economy.capture_score sets
##   last_capture_ctx.wave_capture_index, before earn() runs) — its
##   on_score_change handler doubles off the immutable base like every other
##   doubler; its on_gold_change handler cancels this call's own 1:1 base
##   contribution (`ctx.amount = maxf(ctx.amount - ctx.base, 0.0)`, floored so
##   two held copies can't drive Gold negative). Both are own-resource
##   handlers, not a cross-resource gold_bonus/score_bonus payment — no new
##   ctx channel needed.
## - Templar Debit Card ("pay Shop costs with Score, 10 Score per 1 Gold") has
##   no REGISTRY entry, same as Agartha Welcome Mat's credit line: a standing
##   rule read directly off g.artefacts in shop.gd (Shop._score_credit), not
##   a triggered hook. can_buy() counts it into the funds check; buy() spends
##   whatever Gold (+ Agartha's credit line) can't cover as Score.
## - $2.3 Trillion Receipt ("Enemies destroyed by Items award their Score and
##   Gold value") is a deliberate, GDD-text-scoped exception to _destroy's
##   "Destruction pays nothing" rule (Destruction is not Capture — CONTEXT.md
##   — see _destroy's own header comment in game.gd). The new on_destroy hook
##   only fires for the `by_item = true` call sites (Drone Strike, Air
##   Strike, Sniper); Bomb's _detonate and the jd_vance Tariff still pay
##   nothing, same as ever.
## - Dark Market Light Bulb ("Demoted pieces give no Score on Capture") stays
##   unimplemented: "Demoted" is undefined for this catalog — a piece demoted
##   at some point this run, or one currently below its peak rank? A Notion
##   question, not a guess — see .scratch/gdd-gaps/issues/31's Outcome.
##
## issue 30 (action-type tracking) added a per-turn ordered action log
## (game.gd `action_log`, cleared in _begin_player_turn) and its own hook,
## `on_action` — the 7 sites that already did `turn_action_count += 1` (move,
## capture, blocked-capture, bomb, trap, place, item; merge_logic.gd's
## commit_merge calls it on `g`) now all funnel through one new choke point,
## game.gd's `_log_action(kind)`, instead of touching the counter directly.
## ctx = {kind, first} — `kind` is "move"/"capture"/"place"/"merge"/"item"
## (a blocked/repelled attack still logs "capture": it's an attempt against
## an occupied tile, the same shape Zapruder's Director's Cut will eventually
## want); `first` is whether this is the Turn's opening Action, computed off
## `action_log.is_empty()` BEFORE the log/counter update — so a handler can
## gate on "the very first Action" without reaching into game state itself.
## Elvish Hard Hat ("first Action of a Turn is an Item or ability: +1
## Action") is the first listener: `ctx.first and ctx.kind == "item"` grants
## `actions_left`/`actions_max` +1 from inside `_log_action`, which every
## call site invokes BEFORE its own `actions_left == 0` auto-pass check — the
## same ordering that already lets first_capture_extra/Stargate Divination
## Crystal (`turn_action_count == 0`, on_capture) refund an action without
## ever resurrecting a Turn that already ended (Blitz hit this exact shape
## during its own rework — see this header's on_capture notes above).
## Covered by test_items.gd ("Elvish Hard Hat" + "... cannot resurrect an
## already-passed Turn").
##
## Black Knight Morse Code ("Every 3rd Turn: your Score and Clock gains that
## Turn are doubled (needs: turn counter)") stayed unimplemented at issue 30 —
## its own catalog text names a different gap than issue 30's own description
## implied ("needs a per-turn action counter with type"). There was no "which
## Turn number is this" counter anywhere in game.gd (only `turns_since_wave`,
## reset every Wave, not a run-long count) and no hook for "a Clock gain
## happened" — `clock_ms` was mutated directly at ~15 scattered call sites,
## unlike Gold/Score which already route through Economy.earn/gain's
## on_score_change/on_gold_change. Both gaps are closed by issue 35 below.
##
## issue 35 (Clock-gain choke point & run-long turn counter) added:
## - `Economy.add_clock(g, ms, reason)`, mirroring earn()/gain() — every
##   direct `clock_ms +=`/`-=` GAIN site (milestone/King refills, the
##   Continue bonus, the early-clear/turn-end bonuses, and every artefact/
##   item/tariff that grants or drains time, including the ones IN this
##   file's own _dispatch below) now calls it instead, so the new
##   `on_clock_change` hook (added to HOOKS) sees every one. Same immutable-
##   base/additive-amount ctx contract as on_score_change (CONTRACT note
##   above): `base` is read-only input, `amount` is the output a percentage
##   handler adds to off `base` — never off the running `amount`. A handler
##   inside THIS file calling back into Economy.add_clock (economy.gd calling
##   back into ArtefactHooks.run) is a real re-entrant dispatch, unlike every
##   other cross-resource case above (which hand a value back through a ctx
##   output field instead, e.g. gold_bonus/score_bonus) — Clock has no paired
##   sibling dispatch to piggyback on the way Score/Gold do inside earn(), so
##   there is no output field to hand it through. Verified safe: run()'s only
##   shared mutable state is `g.artefact_echo_depth`, which _run_meta_triggers
##   already guards for reentrancy, and a nested on_clock_change call
##   completes (loop + its own meta-trigger pass) before control returns to
##   the outer dispatch, so the outer hook's `held`/`fired` snapshots are
##   never touched. Covered by test_clock.gd.
## - The ONE deliberate exception is game.gd's `_process` per-frame drain —
##   a continuous tick, not a discrete gain, so hooking it would fire every
##   frame; it stays a direct `clock_ms -=`, commented at the call site.
## - A run-long Turn counter, `g.turn_number`, incremented at the single
##   `_begin_player_turn` call site (game.gd) — unlike `turns_since_wave`
##   (reset every Wave, in `_enemy_turn`), this never resets, and
##   save_config.gd round-trips it.
## - Black Knight Morse Code is now an ordinary two-hook artefact
##   (on_score_change + on_clock_change, both gated `g.turn_number % 3 == 0`)
##   — see REGISTRY/_dispatch below.
##
const Rules := preload("res://scripts/rules.gd")
const Items := preload("res://data/items.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")
const Tuning := preload("res://scripts/tuning.gd")
const ItemLogic := preload("res://scripts/item_logic.gd")
const Economy := preload("res://scripts/economy.gd") # issue 35: clock-grant
const Box := preload("res://scripts/box.gd")
	# handlers below call Economy.add_clock so the Clock gets the same choke
	# point as Score/Gold — a real cycle (economy.gd preloads this file back),
	# which Godot 4 resolves fine for static-func calls (verified empirically;
	# nothing here is referenced at parse time, only called at runtime)

const HOOKS := [
	"on_capture", "on_piece_lost", "on_deploy",
	"on_wave_clear", "on_wave_spawn", "on_milestone",
	"on_turn_start", "on_turn_end", "on_shop_restock", "on_purchase",
	"on_gold_change", "on_score_change", "on_box_open", "on_game_over", "on_price",
	"on_item_consume", "on_rank_up", "on_tariff_apply", "on_tariff_charge",
	# --- issue 13: tariff-only trigger points (see header) ---
	"on_charge", "on_gold_gain", "on_sanction_check", "on_merge_check",
	"on_place_cost", "on_enemy_turn_start", "on_wave_roster",
	# --- issue 23: Piece Buff lifecycle choke points (see header) ---
	"on_buff_apply", "on_buff_consume", "on_demote", "on_piece_demoted", "on_buff_removal",
	# --- issue 26: Gold reaching exactly 0 (economy.gd/shop.gd spend_gold) ---
	"on_gold_zero",
	# --- issue 31: an enemy destroyed by an Item (game.gd _destroy) ---
	"on_destroy",
	# --- issue 30: per-turn action log (game.gd _log_action) ---
	"on_action",
	# --- issue 35: Clock-gain choke point (economy.gd add_clock) ---
	"on_clock_change",
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
	"loch-ness-stool-sample": ["on_score_change"], # issue 49
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
	# issue 26 adds 4 more standing rules to that same no-hook list: Nazca
	# Boarding Pass (game.gd's _deploy_tiles), Nuclear Football Menu (the
	# single _item_apply call site), Doomsday Clock Snooze Button (the
	# per-frame Clock tick in _process — no discrete hook to fire on) and
	# Agartha Welcome Mat (Shop.can_buy/buy's own credit-line read).

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

	# --- issue 42: peak-rank stamp (on_rank_up, above) unblocks Dark Market
	# Light Bulb's "Demoted" clause ---
	"dark-market-light-bulb": ["on_capture"],

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

	# --- issue 24: combat & positioning (post-move ctx flag; see header) ---
	"uss-eldridge-invisibility-paint": ["on_capture"],
	"royal-fiat-undamaged": ["on_capture"],
	"fireproof-pajamas": ["on_piece_lost"],
	"hoffa-s-cement-shoes": ["on_wave_clear", "on_piece_lost"],

	# --- issue 23: Piece Buff lifecycle (game.gd _apply_buff/_consume_buff) ---
	"amityville-ouija-board": ["on_buff_consume"],
	"cleopatra-s-hairpin": ["on_buff_consume"],
	"guidestone-blood-ritual": ["on_buff_consume", "on_piece_demoted"],
	"kgb-photo-eraser": ["on_piece_lost"],
	"pied-piper-s-rat-census": ["on_buff_apply"],
	"mrna-firmware-update": ["on_buff_apply"],
	"youth-fountain-martini": ["on_buff_consume"],
	"45-5-carat-curse": ["on_gold_change", "on_score_change", "on_wave_clear"],
	"antikythera-warranty-card": ["on_demote", "on_buff_removal"],
	"atlantis-snow-globe": ["on_demote"],

	# --- issue 25: per-piece capture ledger (game.gd _note_capture,
	# economy.gd capture_score's victim_captures) ---
	"chupacabra-chew-toy": ["on_capture"],
	"zodiac-crossword-puzzle": ["on_wave_clear"],
	"alien-rocket-toy": ["on_capture"],

	# --- issue 22: tariff interception (filter/scale/cancel; see header) ---
	"panama-papers-shredder": ["on_charge", "on_gold_gain"],
	"amber-room-bubble-wrap": ["on_gold_gain"],
	"ark-grounding-cable": ["on_charge"],
	"salvation-gift-card": ["on_tariff_apply", "on_wave_clear"],

	# --- issue 26: spawn roster modifiers (WaveLogic.queue's existing
	# on_wave_roster dispatch — trade_war's own prerequisite, not a new one) ---
	"haarp-volume-knob": ["on_wave_roster", "on_wave_clear"],
	"wuhan-vial-label": ["on_wave_roster", "on_capture"],
	"pigeon-charging-cable": ["on_wave_roster"],

	# --- issue 26: Shop purchase counter (Shop.price's forced-free override
	# reads g.lottery_purchase_count directly; this only increments it) ---
	"pre-scratched-lottery-ticket": ["on_purchase"],

	# --- issue 26: on_deploy ctx.skip_action / g.artefacts-read placement
	# (Hitler's Argentinian Passport, Nazca Boarding Pass — the latter has no
	# hook at all, see game.gd's _deploy_tiles) ---
	"hitler-s-argentinian-passport": ["on_deploy"],

	# --- issue 26: "5-Wave Milestone" (on_wave_clear + _milestone5_hit, the
	# silk-road-coupon/crop-circle-plank cadence — PER-ARTEFACT, ruled
	# 2026-08-28; a different one than on_milestone's own GLOBAL 10-wave
	# clock-refill trigger, see there) ---
	"ark-s-bunkbed": ["on_wave_clear", "on_purchase"],
	"trojan-horse-assembly-manual": ["on_wave_clear"],
	# was left on on_milestone (the GLOBAL 10-wave beat) when the other 8 were
	# converted above — paid at half the intended rate; moved to this
	# per-artefact cadence 2026-08-28 (user-reported)
	"john-titor-s-crypto-wallet": ["on_wave_clear"],

	# --- issue 44: the choice-modal seam's (issue 41) first real consumer —
	# choose 1 of 3 on the same per-artefact 5-Wave Milestone cadence as
	# silk-road-coupon/john-titor-s-crypto-wallet above ---
	"yalta-cocktail-napkin": ["on_wave_clear"],

	# --- issue 26: per-Wave first/last-lost tracking (g.wave_lost_ids,
	# WaveLogic.queue) ---
	"jon-burrows-fake-id": ["on_wave_clear"],
	"walt-s-cryonic-capsule": ["on_wave_clear"],

	# --- issue 26: Score-gain streak (g.club27_streak), same debits-Gold
	# ruling as Social Credit Report Card (issue 16) ---
	"27-club-punch-card": ["on_wave_clear", "on_piece_lost", "on_score_change"],

	# --- issue 26: Gold reaching exactly 0 (economy.gd/shop.gd spend_gold) ---
	"zero-point-energy-drink": ["on_gold_zero"],

	# --- issue 31: capture-context effects. Templar Debit Card has no entry
	# here (see the header) — it's a standing shop.gd rule, not a hook. ---
	"curtain-rods-bag-rifle-shaped": ["on_score_change", "on_gold_change"],
	"2-3-trillion-receipt": ["on_destroy"],

	# --- issue 21: echo and meta-triggers ---
	# Capstone Polish is a plain on_purchase handler, scoped like the other
	# "on acquiring/buying" artefacts above (putin's-golden-toilet-brush,
	# sleeper-agent-pillow, mao's-loyalty-badge, casino-invisible-clock) —
	# box-granted artefacts stay the known, already-deferred gap (issue 16's
	# held-back note, repeated in 17/18/19).
	"capstone-polish": ["on_purchase"],
	# Polybius Cartridge, Max Headroom Mask, Red Diary's Missing Pages, CERN
	# Ctrl+Z Shortcut, Bilderberg Hotel Slippers, Illuminati: NWO Booster
	# Pack, 100% Genuine Original Mona Lisa and Déjà Vu Glitch deliberately
	# have NO REGISTRY entry — they never dispatch through the normal loop
	# below, only through _run_meta_triggers reading `held`/`fired` directly
	# (see the issue 21 header section).

	# --- issue 29: runtime rarity metadata's first consumer ---
	"illuminati-fridge-magnet": ["on_gold_change"],
	# --- issue 30: per-turn action log (game.gd _log_action / on_action) ---
	"elvish-hard-hat": ["on_action"],
	# --- issue 35: Clock-gain choke point + run-long Turn counter ---
	"black-knight-morse-code": ["on_score_change", "on_clock_change"],

	# --- issue 43: the economy Artefacts with no `(needs: ...)` note ---
	"mar-a-lago-toilet-papers": ["on_wave_clear", "on_price"],
	"deep-state-yearbook": ["on_purchase"],
	# New World Order Gerrymandering deliberately has NO REGISTRY entry, same
	# shape as the issue-21 echo family above: it never runs through the
	# normal per-copy _dispatch loop below at all. "Gold paid by other
	# Artefacts +25%" can only be computed once every other held
	# artefact/tariff has already added its share to a Gold gain — reading
	# the running ctx.amount mid-loop is exactly the order-dependence issue
	# 20 exists to rule out (CONTRACT note, header) — so it's an explicit
	# post-pass at the tail of run() instead, after the on_gold_change/
	# on_score_change dispatch (and the echo layer right after it) both
	# finish. See run().

	# --- issue 45: three Artefacts whose `(needs: ...)` blocker notes went
	# stale — all three hooks below are live call sites today, checked
	# against the real code, not the note (see .scratch/gdd-gaps/issues/45) ---
	"frog-pride-flag": ["on_piece_lost", "on_deploy"],
	"y2k-patch-floppy-disk": ["on_wave_spawn", "on_enemy_turn_start"],
	"pandemic-toilet-paper-pallet": ["on_purchase", "on_price"],
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
	# issue 21: "a Turn just began" is the only reset these two echo flags
	# need, and both of the choke points that mean that already dispatch
	# through here — must happen BEFORE this call's own loop below so a
	# Mona Lisa/Déjà Vu fire on THIS turn-start/gain is still eligible.
	if hook == "on_turn_start" or hook == "on_enemy_turn_start":
		g.mona_lisa_turn_done = false
	if hook == "on_turn_start":
		g.dejavu_score_turn_done = false
		g.dejavu_gold_turn_done = false
	if hook == "on_rank_up" and ctx.pos.x >= 0: # issue 42: peak-rank stamp,
		# the single choke point every on_rank_up dispatch already passes
		# through (merge_logic.gd commit_merge, game.gd "promote" Item, and
		# this file's own mrna-firmware-update/alien-rocket-toy in-place
		# promotions) — a piece is Ranked by definition right after a rank-up,
		# so stamp unconditionally, independent of any artefact being held.
		# Skipped for a Stock landing (ctx.pos.x < 0): a fresh Stock entry is
		# a bare id String there (merge_logic.gd, ADR-0002 — "Merging discards
		# input state"), nothing to stamp a field onto until some other
		# handler (Holy Grail Coaster's own branch) converts it to a
		# Dictionary — same limitation buffs/the capture ledger already
		# accept for that path, not a new gap. See _demoted() below for the
		# read side (Dark Market Light Bulb).
		g.board[ctx.pos].peak_ranked = true
	var fired: Array = [] # issue 21: the held/tariff ENTRIES that actually
		# dispatched this call, not just held — Bilderberg Hotel Slippers' own
		# contract. Carries the whole entry (not just t.key) so the echo layer
		# below can re-dispatch with this specific copy's own acquired_wave
		# instead of falling back to the default (issue 28: a 5-Wave Milestone
		# artefact echoed by Max Headroom Mask/Polybius Cartridge/etc. used to
		# echo on the wrong beat for any copy not acquired on wave 1).
	for t in held + tariffs:
		if REGISTRY.get(t.key, []).has(hook):
			_dispatch(g, t.key, hook, ctx, t.get("acquired_wave", 1))
			fired.append(t)
	if g.artefact_echo_depth == 0: # re-entrancy guard, see header
		g.artefact_echo_depth += 1
		_run_meta_triggers(g, hook, ctx, fired, held)
		g.artefact_echo_depth -= 1
	# issue 43: New World Order Gerrymandering — "Gold paid by other Artefacts
	# +25%", a deliberate exception to the ORDERING rule above (REGISTRY has
	# no entry for it; see the comment there). It cannot size itself off
	# ctx.base like every other percentage handler: the thing it multiplies
	# is precisely what every OTHER held artefact/tariff just added, which
	# only exists once the main loop AND the echo layer above (e.g. Déjà Vu
	# Glitch's on_gold_change/on_score_change multiply) have both run. Counted
	# once here and applied as a single N-multiplier (not one +=25% per held
	# copy) so two copies land on a clean +50% of the artefact-added part,
	# never (1.25^2 - 1) = +56.25% compounding.
	if hook == "on_gold_change" or hook == "on_score_change":
		var n_gerrymander := 0
		for t in held:
			if t.key == "new-world-order-gerrymandering":
				n_gerrymander += 1
		if n_gerrymander > 0:
			if hook == "on_gold_change":
				ctx.amount += 0.25 * n_gerrymander * (ctx.amount - ctx.base)
			elif ctx.has("gold_bonus"): # on_score_change's Score->Gold side
				# payment (El Dorado Body Glitter) — itself entirely
				# "Gold paid by an Artefact", not a delta off some base.
				ctx.gold_bonus += 0.25 * n_gerrymander * ctx.gold_bonus
	return ctx


## The echo/meta layer (issue 21, header). Never calls run() — every extra
## trigger goes straight through _dispatch, so nothing here can ever be
## observed by a second pass of itself. `fired`/`held` are the same-call
## snapshots run() already built; `counts` is just `held` grouped by key,
## for CERN's duplicate check. `fired` holds full entries (issue 28), not
## bare keys, so every echoed _dispatch can pass the ORIGINAL copy's own
## acquired_wave through instead of silently defaulting to 1 — the gap
## that made a 5-Wave Milestone artefact echo on the wrong beat whenever
## the copy that fired wasn't acquired on wave 1.
static func _run_meta_triggers(g, hook: String, ctx: Dictionary, fired: Array, held: Array) -> void:
	var counts := {}
	for t in held:
		counts[t.key] = counts.get(t.key, 0) + 1

	var n_poly: int = counts.get("polybius-cartridge", 0)
	if n_poly > 0 and hook == "on_capture":
		for entry in fired:
			for i in n_poly:
				_dispatch(g, entry.key, hook, ctx, entry.get("acquired_wave", 1))

	var n_headroom: int = counts.get("max-headroom-mask", 0)
	if n_headroom > 0 and (hook == "on_wave_clear" or hook == "on_wave_spawn"):
		for entry in fired:
			for i in n_headroom:
				_dispatch(g, entry.key, hook, ctx, entry.get("acquired_wave", 1))

	var n_diary: int = counts.get("red-diary-s-missing-pages", 0)
	if n_diary > 0 and hook == "on_piece_lost":
		for entry in fired:
			for i in n_diary:
				_dispatch(g, entry.key, hook, ctx, entry.get("acquired_wave", 1))

	var n_cern: int = counts.get("cern-ctrl-z-shortcut", 0)
	if n_cern > 0:
		var seen := {}
		for entry in fired:
			var key: String = entry.key
			if seen.has(key):
				continue
			seen[key] = true
			if counts.get(key, 0) >= 2:
				for i in n_cern:
					_dispatch(g, key, hook, ctx, entry.get("acquired_wave", 1))

	var n_bilderberg: int = counts.get("bilderberg-hotel-slippers", 0)
	if n_bilderberg > 0 and fired.size() >= 2:
		g.gold += 15 * n_bilderberg

	var n_nwo: int = counts.get("illuminati-nwo-booster-pack", 0)
	if n_nwo > 0 and hook == "on_capture" and not fired.is_empty():
		g.gold += 2 * n_nwo * fired.size()
		g.score += 20 * n_nwo * fired.size()

	var n_mona: int = counts.get("100-genuine-original-mona-lisa", 0)
	if n_mona > 0 and not g.mona_lisa_turn_done and not fired.is_empty():
		g.mona_lisa_turn_done = true
		var first_entry: Dictionary = fired[0]
		for i in n_mona:
			_dispatch(g, first_entry.key, hook, ctx, first_entry.get("acquired_wave", 1))

	var n_dejavu: int = counts.get("deja-vu-glitch", 0)
	if n_dejavu > 0:
		if hook == "on_score_change" and not g.dejavu_score_turn_done:
			g.dejavu_score_turn_done = true
			ctx.amount *= (1.0 + n_dejavu)
		elif hook == "on_gold_change" and not g.dejavu_gold_turn_done:
			g.dejavu_gold_turn_done = true
			ctx.amount *= (1.0 + n_dejavu)


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


## Nearest OTHER ally to `pos` by straight-line distance (KGB Photo Eraser's
## buff-transfer target) — ties broken by board iteration order, no RNG
## needed. Vector2i(-1,-1) when `pos` has no ally left to transfer to.
static func _nearest_ally(g, pos: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := -1
	for p in _player_positions(g):
		if p == pos:
			continue
		var d: int = (p - pos).length_squared()
		if best_dist < 0 or d < best_dist:
			best_dist = d
			best = p
	return best


## First ally in one of the 8 tiles adjacent to `pos` (Pied Piper's Rat
## Census's buff-copy target). Vector2i(-1,-1) when none.
static func _adjacent_ally(g, pos: Vector2i) -> Vector2i:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var at := pos + Vector2i(dx, dy)
			if g.board.has(at) and g.board[at].owner == Rules.PLAYER:
				return at
	return Vector2i(-1, -1)


## "5-Wave Milestone" (12 effect texts) is PER-ARTEFACT, not the GLOBAL
## 10-wave beat (Tuning.MILESTONE_WAVES / on_milestone, wave_logic.gd's clock
## refill + score chunk — untouched, a genuinely different cadence). Each held
## copy counts its own 5 waves from its own acquisition — ruled 2026-08-28,
## matching .scratch/shop-gdd-sync/PRD.md ("each Artefact counts its own 5
## waves from acquisition"). The acquisition wave itself counts as beat 1, so
## a copy acquired on wave W fires when W+4, W+9, W+14… clears — two copies
## acquired on different waves legitimately fire on different beats. Called
## from `on_wave_clear` handlers, where `wave` is the just-cleared wave
## (wave_logic.gd's queue() dispatches on_wave_clear before bumping g.wave).
static func _milestone5_hit(wave: int, acquired_wave: int) -> bool:
	return wave >= acquired_wave and (wave - acquired_wave) % 5 == 4


## Catalog rarity for an artefact key ("Common"/"Uncommon"/"Rare"/"Legendary"),
## "" for the 7 core keys (items.gd's ARTEFACT_EFFECTS_CORE, which predate the
## catalog and carry no rarity at all) or an unrecognized key. Every
## acquisition path (shop.gd's buy, game.gd's _box_choose and --artefacts
## flag, save_config.gd's apply()) stamps `rarity` onto the held copy
## directly via this lookup — the same "stamp at acquisition" pattern
## acquired_wave uses — so this is only ever exercised live for a held entry
## that predates the stamp (an old save; issue 29).
static func rarity_of(key: String) -> String:
	for e in Items.ARTEFACT_CATALOG:
		if e.key == key:
			return str(e.get("rarity", ""))
	return ""


const RARITIES := ["Common", "Uncommon", "Rare", "Legendary"]

## Illuminati Fridge Magnet's "own Artefacts of every rarity" check — reads
## each held copy's own `rarity` stamp, falling back to rarity_of() for a
## copy that predates it (see rarity_of's header).
static func holds_every_rarity(g) -> bool:
	var have := {}
	for t in g.artefacts:
		have[str(t.get("rarity", rarity_of(t.key)))] = true
	for r in RARITIES:
		if not have.has(r):
			return false
	return true


## A uniformly random Piece Buff key, optionally restricted to one tier
## ("Tactical Piece Buff" in several issue-18 effect texts). RANDOM GRANTS
## only — excludes `self_harming` entries (today just Slow: it makes the
## piece move/capture like a Pawn, a debuff on its own holder) so "the piece
## gets +1 Piece Buff" artefacts (Holy Lint, MK-Ultra Sugar Cube, Crop Circle
## Plank, Obedience-Flavored Tap Water, Sugar Free Chemtrail Can, Zodiac
## Crossword Puzzle, Holy Grail Coaster, Scientology E-Meter, Xenu OT III
## Season Pass, Sleeper Agent Pillow…) never actively penalise the player
## (ruled 2026-08-28). The player's own Buff Box pick (game.gd
## _open_buff_pick) reads Items.PIECE_BUFFS directly, not this function, so
## choosing Slow deliberately (e.g. onto an enemy) is untouched.
##
## Two rules coexist here on different axes (issue 42, ruled 2026-08-29):
## `tier == ""` (the default every REGISTRY caller but 3 uses) draws from the
## FULL pool across all tiers — issue 28 asked whether random grants should
## be tier-restricted across the board, ruled no. `self_harming` exclusion
## (above, issue 27) is a separate axis: "full pool" means all TIERS, not
## "all buffs including the debuff" — Slow stays excluded from every random
## grant regardless of tier. An explicit `tier` arg (MK-Ultra Sugar Cube,
## Obedience-Flavored Tap Water, Sleeper Agent Pillow pass "Tactical") is a
## PER-ARTEFACT restriction matching that catalog entry's own text, not a
## blanket policy — see those 3 call sites' own comments for why they stay
## Tactical-only.
static func _random_buff_key(rng: RandomNumberGenerator, tier := "") -> String:
	var pool: Array = Items.PIECE_BUFFS.filter(func(b: Dictionary) -> bool:
		return not b.get("self_harming", false) and (tier == "" or b.tier == tier))
	return pool[rng.randi() % pool.size()].key


## Catalogued life of a timed buff, in player turns (0 = dormant) — mirrors
## game.gd's private _buff_turns, kept alongside its own PIECE_BUFFS lookup
## instead of reaching across files for a one-line match.
static func _buff_turns(key: String) -> int:
	for b in Items.PIECE_BUFFS:
		if b.key == key:
			return int(b.get("turns", 0))
	return 0


## The catalogued tier of a Piece Buff key (Cleopatra's Hairpin: "Decisive
## Piece Buffs" only — Trap, Reflect, Bomb).
static func _buff_tier(key: String) -> String:
	for b in Items.PIECE_BUFFS:
		if b.key == key:
			return b.tier
	return ""


## Grant one random Piece Buff to a live Dictionary — a board piece
## (BuffLogic.add takes any Dictionary with a `buffs` field) or a freshly
## built {"id": ...} piece not yet placed (Sleeper Agent Pillow). Routes
## through g._apply_buff (issue 23's choke point) so on_buff_apply (Pied
## Piper's Rat Census, mRNA Firmware Update) sees every artefact grant too.
## `pos` is Vector2i(-1,-1) for the off-board Stock case — those handlers
## just no-op on pos.x < 0.
static func _grant_buff_to(g, piece: Dictionary, tier := "", pos := Vector2i(-1, -1)) -> void:
	var key := _random_buff_key(g.rng, tier)
	g._apply_buff(piece, key, _buff_turns(key), pos)


static func _grant_buff(g, pos: Vector2i, tier := "") -> void:
	_grant_buff_to(g, g.board[pos], tier, pos)


## "Ranked" (issue 19): a piece that has been promoted at least once, i.e. it
## is not its own promotion-chain base. Reuses ItemLogic.chain_base — the same
## walk the "demote" Item's own target-validity check already does.
static func _ranked(defs: Dictionary, id: String) -> bool:
	return ItemLogic.chain_base(defs, id) != id


## "Demoted" (issue 42, ruled 2026-08-29 — option (b), chosen over "was ever
## demoted"): currently sitting BELOW the piece's own historical peak rank,
## not "was ever demoted". `peak_ranked` is the stamp run() writes on every
## on_rank_up (above) — sticky true once a piece has ever been Ranked, since
## nothing clears it. A piece is Demoted when that stamp is set but the piece
## is back at its base id (_ranked false): the moment a later rank-up
## re-Ranks it, this flips back to false on its own — no separate "clear"
## step, satisfying the ruling for free. A piece that never ranked up has no
## `peak_ranked` field (absent = false) and is never Demoted. Dark Market
## Light Bulb is the only reader.
static func _demoted(defs: Dictionary, piece: Dictionary) -> bool:
	return piece.get("peak_ranked", false) and not _ranked(defs, piece.id)


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


## `acquired_wave` (issue: "5-Wave Milestone" ruled per-artefact, not global —
## see _milestone5_hit below) is the wave this specific held copy entered
## g.artefacts (stamped on every acquisition path: save_config.gd, shop.gd,
## the box-pick/--artefacts spots in game.gd). Defaults to 1 only for the two
## call sites that genuinely have no copy in hand (run()'s own normal loop
## reads it off `t.get("acquired_wave", 1)`, an old-save fallback; direct
## test-only calls). The `_run_meta_triggers` echo calls (issue 21) now pass
## the firing copy's own `acquired_wave` explicitly (issue 28 fix — they used
## to re-dispatch by bare key and silently fall back to wave 1, so a
## milestone-5 artefact echoed by Max Headroom Mask/Polybius Cartridge/etc.
## fired on the wrong beat for any copy not acquired on wave 1). Covered by
## test_items.gd ("Max Headroom Mask echoes John Titor's Crypto Wallet on
## THAT copy's own beat, not the wave-1 default").
static func _dispatch(g, key: String, hook: String, ctx: Dictionary, acquired_wave: int = 1) -> void:
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
			Economy.add_clock(g, 2000, "lifesteal")
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
		["loch-ness-stool-sample", "on_score_change"]:
			# "Every 1000 Score gained" (issue 49) — a run-long cumulative
			# tracker off ctx.base (never the running g.score, which can DROP
			# via Templar Debit Card's Score-as-payment): each dispatch call
			# (once per held copy, same as every other stacking handler here)
			# advances g.score_gained_total by this gain's base amount, and a
			# crossed 1000-multiple opens one random Piece Box. `not g.box_open`
			# mirrors Trojan Horse Assembly Manual's own "don't clobber an open
			# Box Pick" guard just below — a crossing that lands while a Box is
			# already open (e.g. mid box-skip consolation) is silently dropped,
			# same precedent, rather than queued.
			var before: int = g.score_gained_total
			g.score_gained_total += roundi(ctx.base)
			if int(g.score_gained_total / 1000.0) > int(before / 1000.0) and not g.box_open:
				g._open_box_pick(Box.random_slot_for_theme(g, "piece"))

		# --- issue 16: Gold gain also pays Score (mirror of the above) ---
		["tungsten-filled-gold-bar", "on_gold_change"]:
			# Rebalanced 2026-08-28: "+20% Score gain" — was "2x their amount as
			# Score", an unconditional 3x Score multiplier (Gold is earned 1:1
			# with Score) wildly out of scale with the catalog (Tinfoil Hat is
			# +15% at the same Common rarity). ctx.score_bonus, same reasoning
			# as El Dorado above.
			ctx.score_bonus += ctx.base * 0.20
		["popemobile-piggy-bank", "on_gold_change"]:
			# Rebalanced 2026-08-28: "+50% Score gain" — was "10x" (an
			# unconditional 11x Score multiplier at Uncommon). Same reasoning
			# as Tungsten-Filled Gold Bar above.
			ctx.score_bonus += ctx.base * 0.50

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
			Economy.add_clock(g, -3000.0, "nigerian-prince-wire-transfer") # issue 35:
				# a Clock LOSS — routed through the same choke point (negative
				# amount, floored at 0 by add_clock itself)
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
			# — same ordering that lets Blitz's free-move flag skip that
			# decrement without ever resurrecting an already-ended turn. actions_max moves too,
			# mirroring first_capture_extra (its on_capture sibling above),
			# since turn start already happened and won't re-sync it for us.
			if g.turn_action_count == 0:
				g.actions_left += 1
				g.actions_max += 1
		["5g-microchips", "on_turn_start"]:
			var allies: int = g._player_pieces().size()
			var enemies: int = g.board.size() - allies
			Economy.add_clock(g, float((allies - enemies) * 1000), "5g-microchips") # issue
				# 35: signed — can net a loss when outnumbered, same call either way
		["terracotta-draft-card", "on_wave_clear"]:
			var mix: Array = Tuning.ARMIES.get(g.next_army, Tuning.ARMIES[Tuning.DEFAULT_ARMY])
			g.stock.append(mix[g.rng.randi() % mix.size()]) # bare id: a fresh
				# piece carries no board state, so ADR-0002's plain-String form
				# applies (a Dictionary would only be needed for a piece pulled
				# off the board with state attached, e.g. Extraction)
		["charlemagne-s-birth-certificate", "on_wave_clear"]:
			Economy.add_clock(g, 10000, "charlemagne-s-birth-certificate")

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
			Economy.add_clock(g, 1000.0, "shrinkflation-cereal-box")
		["skull-and-bones-coffin", "on_price"]:
			ctx.amount += ctx.base * 0.05
		["skull-and-bones-coffin", "on_score_change"]:
			if g.gold >= 200:
				ctx.amount += ctx.base * 0.20
		["silk-road-coupon", "on_price"]:
			if g.silk_road_active:
				ctx.amount -= ctx.base * 0.50
		["silk-road-coupon", "on_wave_clear"]:
			# "5-Wave Milestone" (12 effect texts) is PER-ARTEFACT, a different
			# cadence than on_milestone's own GLOBAL 10-wave clock-refill
			# trigger — see _milestone5_hit's header above.
			if _milestone5_hit(g.wave, acquired_wave):
				g.silk_road_active = true # reset false at the top of every WaveLogic.queue()
		["john-titor-s-crypto-wallet", "on_wave_clear"]:
			if _milestone5_hit(g.wave, acquired_wave): # see silk-road-coupon's case above
				g.gold += int(g.clock_ms / 1000.0 / 5.0)

		# --- issue 18: Buff-tag triggers, all through BuffLogic.add ---
		["crop-circle-plank", "on_wave_clear"]:
			if _milestone5_hit(g.wave, acquired_wave): # "5-Wave Milestone" — see silk-road-coupon's on_wave_clear case above
				var pool := _player_positions(g)
				for i in mini(2, pool.size()):
					var idx: int = g.rng.randi() % pool.size()
					_grant_buff(g, pool[idx])
					pool.remove_at(idx)
				g.gold = maxi(g.gold - 10, 0)
		["mk-ultra-sugar-cube", "on_deploy"]:
			# Tactical-only per its own catalog text (issue 42 considered
			# widening all 3 "Tactical Piece Buff" granters to the full pool
			# — declined: Common rarity + fires on literally every Deploy is
			# the highest-frequency grant in the catalog, and a Decisive buff
			# (Bomb/Trap/Reflect) that often from a Common artefact is a much
			# bigger swing than "no random buff grant is tier-restricted by
			# default" (Ruling 1, _random_buff_key above) was ever meant to
			# cover — see .scratch/gdd-gaps/issues/42's Outcome.
			_grant_buff(g, ctx.pos, "Tactical")
		["obedience-flavored-tap-water", "on_capture"]:
			# Doesn't grant here — game.gd's _move_player applies it AFTER this
			# capture's own critical/range consumption (ruled 2026-08-28, see
			# economy.gd's ctx.grant_buffs comment), so the new buff survives
			# for the NEXT capture instead of being doubled/wasted by this one.
			# Tactical-only: same issue-42 balance call as MK-Ultra Sugar Cube
			# above (Common rarity, once-per-Wave is still frequent).
			if ctx.wave_capture_index == 0 and ctx.attacker_pos.x >= 0:
				ctx.grant_buffs.append("Tactical")
		["holy-lint", "on_capture"]:
			if ctx.attacker_pos.x >= 0:
				ctx.grant_buffs.append("")
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
			if _milestone5_hit(g.wave, acquired_wave):
				for pos in _player_positions(g):
					_grant_buff(g, pos)
		["sleeper-agent-pillow", "on_purchase"]:
			# the piece landed as a plain id string at the end of g.stock
			# (Shop.buy, just before this hook runs) — replace it with a
			# Dictionary carrying the buff; _place's `entry is Dictionary`
			# branch already merges any extra fields onto the board piece.
			# Tactical-only: same issue-42 balance call as MK-Ultra Sugar
			# Cube above (Uncommon rarity, still a frequent Shop-buy trigger).
			if ctx.kind == "piece" and not g.stock.is_empty():
				var piece := {"id": ctx.key}
				_grant_buff_to(g, piece, "Tactical")
				g.stock[g.stock.size() - 1] = piece

		# --- issue 18: Item-tag triggers ---
		["frame-25", "on_wave_clear"]:
			var tac_pool: Array = Items.ITEMS.filter(func(it: Dictionary) -> bool:
				return it.tier == "Tactical")
			g.items.append(tac_pool[g.rng.randi() % tac_pool.size()])
			g.gold = maxi(g.gold - 10, 0)
		["manna-vending-machine", "on_wave_clear"]:
			if _milestone5_hit(g.wave, acquired_wave):
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
		# Mild-tier action costs only — Panama Papers Shredder (issue 22) sets
		# ctx.mild_blocked before these dispatch (artefacts-before-tariffs
		# ordering); the 2 Moderate keys below don't check it.
		["move_cost", "on_charge"], ["ability_cost", "on_charge"], ["capture_cost", "on_charge"], ["pass_cost", "on_charge"], ["long_range_cost", "on_charge"], ["box_cost", "on_charge"]:
			if ctx.key == key and not ctx.get("mild_blocked", false):
				ctx.charged = true
		["deploy_cost", "on_charge"], ["fuse_cost", "on_charge"]:
			if ctx.key == key:
				ctx.charged = true
		["inflation", "on_gold_gain"]:
			# stacks multiplicatively per held copy (header) — data/tariffs.gd:
			# "All gold gains reduced 10% (stacks)". ctx.gain_immune (issue 22:
			# Panama Papers Shredder / Amber Room Bubble Wrap) skips it entirely.
			if not ctx.get("gain_immune", false):
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
				g._apply_buff(g.board[ctx.attacker_pos], "slow", _buff_turns("slow"), ctx.attacker_pos)
		["kgb-photo-eraser", "on_piece_lost"]:
			# Fires before the board entry is erased (header), so the lost
			# piece's own Buffs are still readable. Each one transfers with
			# its remaining life intact — not re-rolled — to the nearest ally.
			# ctx.cancel (issue 24, Fireproof Pajamas) means the piece is NOT
			# actually lost — skip the transfer or it'd duplicate the Buff.
			var lost_buffs: Array = BuffLogic.of(g.board[ctx.pos])
			if not ctx.cancel and not lost_buffs.is_empty():
				var ally := _nearest_ally(g, ctx.pos)
				if ally.x >= 0:
					for b in lost_buffs:
						g._apply_buff(g.board[ally], b.key, int(b.get("turns", 0)), ally)

		# --- issue 19: on_item_consume (game.gd _consume_item) ---
		["arms-fair-goodie-bag", "on_item_consume"]:
			if ctx.tier == "Strategic":
				g.gold += 25
		["doomsday-autoclicker", "on_item_consume"]:
			if ctx.tier == "Decisive":
				g.score += 200
				Economy.add_clock(g, 10000, "doomsday-autoclicker")
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
			Economy.add_clock(g, 20000, "witness-protection-mustache")
		["holy-grail-coaster", "on_rank_up"]:
			if ctx.pos.x >= 0:
				_grant_buff(g, ctx.pos)
			elif ctx.stock_index >= 0: # landed in Stock: promote the bare id at
				# the exact index the merge placed it — NOT g.stock.size() - 1,
				# which a same-call handler appending its own grant (Bigfoot
				# Toenail Clipping) would otherwise shift out from under this
				var piece := {"id": g.stock[ctx.stock_index]} # (Sleeper Agent
				_grant_buff_to(g, piece)                      # Pillow's pattern)
				g.stock[ctx.stock_index] = piece
		["bigfoot-toenail-clipping", "on_rank_up"]:
			g.stock.append(ItemLogic.chain_base(g.defs, ctx.id))

		# --- issue 19: chain-lookup off the existing on_capture/on_wave_clear hooks ---
		["cia-heart-attack-gun", "on_capture"]:
			if ctx.turn_capture_index == 0 and ctx.attacker_id != "" \
					and (ctx.attacker_buffed or _ranked(g.defs, ctx.attacker_id)):
				g.gold += roundi(ctx.base) # +100% Gold

		# --- issue 42: peak-rank stamp unblocks Dark Market Light Bulb ---
		["dark-market-light-bulb", "on_capture"]:
			if ctx.attacker_id != "" and _ranked(g.defs, ctx.attacker_id):
				g.gold += roundi(ctx.base) # Ranked: double Gold, same idiom as
					# CIA Heart Attack Gun's own "+100% Gold" above
			if ctx.attacker_pos.x >= 0 and g.board.has(ctx.attacker_pos) \
					and _demoted(g.defs, g.board[ctx.attacker_pos]):
				# Demoted: no Score. Sets an OUTPUT flag rather than zeroing
				# ctx.pts here — a same-hook `+=` handler could dispatch
				# before or after this one (run()'s key-sort), and a direct
				# write here would make the result depend on which side of
				# "dark-market-light-bulb" alphabetically it landed (the
				# exact order-dependence the header's ctx contract bans).
				# economy.gd's capture_score applies `no_score` exactly once,
				# after every on_capture handler has finished.
				ctx.no_score = true
		["montauk-eggo-waffle", "on_wave_clear"]:
			if _milestone5_hit(g.wave, acquired_wave):
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
				g._apply_buff(g.board[strongest], "slow", _buff_turns("slow"), strongest)

		# --- issue 19: cheap follow-ups (named in issue 16/17's Outcome) ---
		["casino-invisible-clock", "on_purchase"]:
			Economy.add_clock(g, 25000, "casino-invisible-clock")
		["2012-doomsday-party-hat", "on_gold_change"]:
			# issue 20 fix: ctx.base, not the running ctx.amount (see the
			# on_score_change/on_gold_change CONTRACT in the header). issue 35:
			# now routes through Economy.add_clock (its own on_clock_change
			# dispatch, off Clock's OWN base — Gold's ctx.base here is only
			# the read source sizing the grant, same as john-titor's-crypto-
			# wallet reading g.clock_ms elsewhere in this file).
			Economy.add_clock(g, ctx.base * 500.0, "2012-doomsday-party-hat") # +5s per 10 Gold
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
			Economy.add_clock(g, 5000, "tunguska-toothpicks")

		# --- issue 19: capture conversion, the cheap wave-clear half ---
		["stockholm-syndrome-pamphlet", "on_wave_clear"]:
			if not g.captured.is_empty():
				g.stock.append(g.captured.pop_front())

		# --- issue 24: combat & positioning ---
		["uss-eldridge-invisibility-paint", "on_capture"]:
			if ctx.turn_capture_index == 0 and ctx.attacker_pos.x >= 0:
				ctx.return_to_start = true
		["royal-fiat-undamaged", "on_capture"]:
			if ctx.turn_capture_index == 0 and ctx.attacker_pos.x >= 0:
				ctx.move_to_backrow = true
		["fireproof-pajamas", "on_piece_lost"]:
			if ctx.reason == "destroyed":
				ctx.cancel = true
		["hoffa-s-cement-shoes", "on_wave_clear"]:
			g.hoffa_used_this_wave = false
		["hoffa-s-cement-shoes", "on_piece_lost"]:
			if ctx.reason == "captured" and ctx.attacker_pos.x >= 0 and not g.hoffa_used_this_wave:
				g.hoffa_used_this_wave = true
				ctx.destroy_attacker = true

		# --- issue 23: on_buff_consume (game.gd _consume_buff) ---
		["amityville-ouija-board", "on_buff_consume"]:
			if g.board[ctx.pos].owner == Rules.PLAYER:
				g.gold += 10
		["cleopatra-s-hairpin", "on_buff_consume"]:
			if g.board[ctx.pos].owner == Rules.PLAYER and _buff_tier(ctx.key) == "Decisive":
				g.gold += 100
		["guidestone-blood-ritual", "on_buff_consume"]:
			g.gold += 25 # owner-agnostic — ally or enemy, any tier
		["guidestone-blood-ritual", "on_piece_demoted"]:
			g.gold += 25 # owner-agnostic — ally or enemy
		["youth-fountain-martini", "on_buff_consume"]:
			if g.youth_fountain_wave != g.wave:
				g.youth_fountain_wave = g.wave
				g._apply_buff(g.board[ctx.pos], ctx.key, _buff_turns(ctx.key), ctx.pos)

		# --- issue 23: on_buff_apply (game.gd _apply_buff) ---
		["pied-piper-s-rat-census", "on_buff_apply"]:
			# fire_hook=false on the copy itself — otherwise two adjacent
			# allies holding this artefact would ping-pong the copy forever.
			if ctx.pos.x >= 0 and g.board[ctx.pos].owner == Rules.PLAYER:
				var ally := _adjacent_ally(g, ctx.pos)
				if ally.x >= 0:
					g._apply_buff(g.board[ally], ctx.key, ctx.turns, ally, false)
		["mrna-firmware-update", "on_buff_apply"]:
			if ctx.pos.x >= 0 and g.board[ctx.pos].owner == Rules.PLAYER:
				g.mrna_apply_count += 1
				if g.mrna_apply_count % 3 == 0:
					var old_id: String = g.board[ctx.pos].id
					var next_id = g.defs[old_id].next
					if next_id != null:
						g.board[ctx.pos].id = next_id
						run(g, "on_rank_up",
							{"pos": ctx.pos, "old_id": old_id, "id": next_id, "stock_index": -1})

		# --- issue 23: demotion/buff-removal immunity (game.gd "demote"/"radar_jamming") ---
		["antikythera-warranty-card", "on_demote"]:
			if g.board[ctx.pos].owner == Rules.PLAYER:
				ctx.blocked = true
		["antikythera-warranty-card", "on_buff_removal"]:
			if g.board[ctx.pos].owner == Rules.PLAYER:
				ctx.blocked = true
		["atlantis-snow-globe", "on_demote"]:
			if g.board[ctx.pos].owner == Rules.PLAYER:
				ctx.blocked = true

		# --- issue 23: payout half cheap, strip half needs no new hook ---
		["45-5-carat-curse", "on_gold_change"]:
			ctx.amount += ctx.base * 0.45
		["45-5-carat-curse", "on_score_change"]:
			ctx.amount += ctx.base * 0.45
		["45-5-carat-curse", "on_wave_clear"]:
			if g.wave % 3 == 0:
				for pos in g._player_pieces():
					BuffLogic.clear(g.board[pos])

		# --- issue 25: per-piece capture ledger ---
		["chupacabra-chew-toy", "on_capture"]:
			g.gold += 2
			if ctx.victim_captures > 0: # the victim had captured one of yours
				g.gold += 10
		["alien-rocket-toy", "on_capture"]:
			if ctx.attacker_pos.x >= 0 and g.board.has(ctx.attacker_pos):
				var rocket_piece: Dictionary = g.board[ctx.attacker_pos]
				if rocket_piece.get("captures", 0) == 3 and g.defs[rocket_piece.id].next != null:
					var old_id: String = rocket_piece.id
					rocket_piece.id = g.defs[old_id].next
					run(g, "on_rank_up", {"pos": ctx.attacker_pos,
						"old_id": old_id, "id": rocket_piece.id, "stock_index": -1})
		["zodiac-crossword-puzzle", "on_wave_clear"]:
			var best := Vector2i(-1, -1)
			var best_n := 0
			for pos in _player_positions(g):
				var n: int = g.board[pos].get("wave_captures", 0)
				if n > best_n:
					best_n = n
					best = pos
			if best.x >= 0:
				_grant_buff(g, best)

		# --- issue 22: tariff interception (see header) ---
		["panama-papers-shredder", "on_charge"]:
			ctx.mild_blocked = true # only the 6 Mild-tier keys' case checks this
		["panama-papers-shredder", "on_gold_gain"]:
			ctx.gain_immune = true # Inflation is the one Mild on_gold_gain tariff
		["amber-room-bubble-wrap", "on_gold_gain"]:
			ctx.gain_immune = true # same flag: "ignore Inflation and other
				# gold-reducing Tariffs" is the same gate regardless of tier
		["ark-grounding-cable", "on_charge"]:
			ctx.amount -= ctx.base * 0.5 # off the immutable base, additive per copy
		["salvation-gift-card", "on_tariff_apply"]:
			if g.salvation_charged:
				g.salvation_charged = false
				ctx.cancel = true
		["salvation-gift-card", "on_wave_clear"]:
			if _milestone5_hit(g.wave, acquired_wave): # same cadence as Silk Road Coupon (issue 18)
				g.salvation_charged = true

		# --- issue 26: spawn roster modifiers (on_wave_roster, WaveLogic.queue
		# — trade_war's own prerequisite above, not a new one) ---
		["haarp-volume-knob", "on_wave_roster"]:
			var extras: Array = ctx.roster.filter(func(id: String) -> bool: return id != "king")
			if not extras.is_empty():
				ctx.roster.append(extras[g.rng.randi() % extras.size()])
		["haarp-volume-knob", "on_wave_clear"]:
			g.score += 200
			g.gold += 15
		["wuhan-vial-label", "on_wave_roster"]:
			var wuhan_extras: Array = ctx.roster.filter(func(id: String) -> bool: return id != "king")
			if not wuhan_extras.is_empty():
				ctx.roster.append(wuhan_extras[g.rng.randi() % wuhan_extras.size()])
		["wuhan-vial-label", "on_capture"]:
			# a capture-only Gold bonus, off the capture's own immutable base —
			# ctx.pts (score) feeds Economy.earn's shared amount, so inflating
			# it would raise Gold *and* Score together; this stays Gold-only.
			g.gold += roundi(ctx.base * 0.25)
		["pigeon-charging-cable", "on_wave_roster"]:
			# -1 piece per wave, floored so a wave never spawns with zero
			# non-King pieces — same "never the King" rule as trade_war/HAARP/
			# Wuhan above, just subtracting instead of adding
			var pigeon_extras: Array = ctx.roster.filter(func(id: String) -> bool: return id != "king")
			if pigeon_extras.size() > 1:
				ctx.roster.erase(pigeon_extras[g.rng.randi() % pigeon_extras.size()])

		# --- issue 26: Shop purchase counter (Pre-Scratched Lottery Ticket;
		# the forced-free override itself lives in Shop.price) ---
		["pre-scratched-lottery-ticket", "on_purchase"]:
			g.lottery_purchase_count += 1

		# --- issue 26: free-deploy (Hitler's Argentinian Passport) ---
		["hitler-s-argentinian-passport", "on_deploy"]:
			ctx.skip_action = true

		# --- issue 26: "5-Wave Milestone" grants (Ark's Bunkbed, Trojan Horse
		# Assembly Manual) — per-artefact cadence, see silk-road-coupon's
		# on_wave_clear case / _milestone5_hit's header above
		["ark-s-bunkbed", "on_wave_clear"]:
			if _milestone5_hit(g.wave, acquired_wave):
				g.arks_bunkbed_used = false # the new Milestone recharges it
		["ark-s-bunkbed", "on_purchase"]:
			if ctx.kind == "piece" and not g.arks_bunkbed_used:
				g.stock.append(ctx.key)
				g.arks_bunkbed_used = true
		["trojan-horse-assembly-manual", "on_wave_clear"]:
			if _milestone5_hit(g.wave, acquired_wave) and not g.box_open: # don't clobber an open Box Pick
				g._open_box_pick(Box.random_slot(g)) # "a free Box" = one of the 9, random (issue 47)
		["yalta-cocktail-napkin", "on_wave_clear"]:
			# issue 44: first consumer of the issue-41 choice-modal seam.
			# `not g.buff_pick_open` mirrors trojan-horse-assembly-manual's
			# `not g.box_open` guard just above — two held copies acquired
			# on the exact same Wave both hit _milestone5_hit here in the
			# same synchronous dispatch pass; only the first opens the
			# modal, the second copy's pick is forfeit for that Wave rather
			# than clobbering the first copy's still-open panel.
			if _milestone5_hit(g.wave, acquired_wave) and not g.buff_pick_open:
				g._open_yalta_pick()

		# --- issue 26: per-Wave first/last-lost tracking (g.wave_lost_ids,
		# game.gd's _lose_player_piece / WaveLogic.queue) ---
		["jon-burrows-fake-id", "on_wave_clear"]:
			if not g.wave_lost_ids.is_empty():
				g.stock.append(g.wave_lost_ids[0])
		["walt-s-cryonic-capsule", "on_wave_clear"]:
			if not g.wave_lost_ids.is_empty():
				g.stock.append(g.wave_lost_ids[-1])

		# --- issue 26: Score-gain streak (27 Club Punch Card); -50 Gold on
		# loss, same issue-16 ruling as Social Credit Report Card (Score is
		# up-only) ---
		["27-club-punch-card", "on_wave_clear"]:
			if ctx.clean:
				g.club27_streak += 1
			else: # belt-and-suspenders: on_piece_lost below already zeroed it
				g.club27_streak = 0
		["27-club-punch-card", "on_piece_lost"]:
			g.club27_streak = 0
			g.gold = maxi(g.gold - 50, 0)
		["27-club-punch-card", "on_score_change"]:
			if g.club27_streak > 0:
				ctx.amount += ctx.base * 0.05 * float(g.club27_streak)

		# --- issue 26: Gold reaching exactly 0 (Zero-Point Energy Drink;
		# economy.gd/shop.gd's spend_gold) ---
		["zero-point-energy-drink", "on_gold_zero"]:
			g.actions_left += 2

		# --- issue 31: capture-context effects ---
		["curtain-rods-bag-rifle-shaped", "on_score_change"]:
			if ctx.reason == "wave_first_capture":
				ctx.amount += ctx.base # double Score, off the immutable base
					# like every other doubler (voynich-dictionary et al.)
		["curtain-rods-bag-rifle-shaped", "on_gold_change"]:
			if ctx.reason == "wave_first_capture":
				# "pays no Gold" — cancel this call's own 1:1 base contribution.
				# Own-resource (on_gold_change shrinking its own amount), not a
				# cross-resource gold_bonus/score_bonus payment — see the
				# CONTRACT note in the header. maxf floors at 0 so two held
				# copies (additive stacking, header) can't drive Gold negative.
				ctx.amount = maxf(ctx.amount - ctx.base, 0.0)
		["2-3-trillion-receipt", "on_destroy"]:
			# Deliberate exception to "_destroy pays nothing" (game.gd's
			# _destroy header) — direct writes are fine here exactly as they
			# are in on_capture/on_wave_clear/on_game_over above; on_destroy
			# only ever fires for Item-caused kills (game.gd's `by_item`
			# param), so this never sees Bomb or Tariff destructions.
			g.score += ctx.value
			g.gold += ctx.value

		# --- issue 21: echo and meta-triggers (the rest of the family runs
		# through _run_meta_triggers above, off `held`/`fired` directly —
		# Capstone Polish is the one plain direct-effect handler here) ---
		["capstone-polish", "on_purchase"]:
			if ctx.kind == "artefact":
				g.score += 150
				Economy.add_clock(g, 5000, "capstone-polish")

		# --- issue 29: Illuminati Fridge Magnet — off the immutable
		# `ctx.base` like every other percentage Gold/Score handler (see the
		# on_score_change/on_gold_change CONTRACT in the header) ---
		["illuminati-fridge-magnet", "on_gold_change"]:
			if holds_every_rarity(g):
				ctx.amount += ctx.base * 0.5

		# --- issue 30: per-turn action log ---
		["elvish-hard-hat", "on_action"]:
			# Fires from game.gd's _log_action, BEFORE the log/counter update —
			# ctx.first is action_log.is_empty() at that point, so this is the
			# gate on "the Turn's first Action", same shape first_capture_extra/
			# Stargate Divination Crystal use `turn_action_count == 0` for. The
			# grant lands before _log_action's caller runs its own
			# actions_left==0 auto-pass check, so it can never resurrect an
			# already-passed Turn — covered by test_items.gd.
			if ctx.first and ctx.kind == "item":
				g.actions_left += 1
				g.actions_max += 1

		# --- issue 35: Clock-gain choke point + run-long Turn counter ---
		["black-knight-morse-code", "on_score_change"]:
			if g.turn_number % 3 == 0:
				ctx.amount += ctx.base # double Score — base is never negative
					# (Score is up-only, economy.gd's earn() header)
		["black-knight-morse-code", "on_clock_change"]:
			if g.turn_number % 3 == 0 and ctx.base > 0:
				ctx.amount += ctx.base # double Clock GAINS only — "gains ...
					# doubled" (catalog text), so a same-Turn Clock LOSS
					# (e.g. Nigerian Prince Wire Transfer) is left alone

		# --- issue 43: economy Artefacts batch (no needs-note) ---
		["mar-a-lago-toilet-papers", "on_wave_clear"]:
			# "5-Wave Milestone" — the silk-road-coupon/crop-circle-plank
			# PER-ARTEFACT cadence (issue 26/28), not the GLOBAL 10-wave
			# on_milestone hook (see REGISTRY's issue-26 comment). The free
			# slot is picked HERE, once, and stamped onto the actual
			# g.shop_stock Dictionary (a plain field, same shape as roll()'s
			# own "biased" tag) — never re-rolled inside Shop.price(), which
			# runs on every redraw and would otherwise flicker the free slot
			# between frames and desync the UI price from the charged one.
			# g.mar_a_lago_free_wave gates the reset to once per wave-clear
			# EVENT (g.wave is the same for every copy dispatched by this
			# one run() call, WaveLogic.queue() below) rather than once per
			# copy, so N held copies that all hit this same milestone add N
			# distinct free slots (the additive stacking rule) instead of
			# each clearing the previous copy's pick.
			if _milestone5_hit(g.wave, acquired_wave):
				if g.mar_a_lago_free_wave != g.wave:
					for s in g.shop_stock:
						s.erase("free_slot")
					g.mar_a_lago_free_wave = g.wave
				var candidates := []
				for i in g.shop_stock.size():
					if not g.shop_stock[i].get("free_slot", false):
						candidates.append(i)
				if not candidates.is_empty():
					g.shop_stock[candidates[g.rng.randi() % candidates.size()]].free_slot = true
		["mar-a-lago-toilet-papers", "on_price"]:
			# "+10%" off the immutable base, same additive contract as every
			# other on_price handler. The free slot's price is forced to 0
			# below, AFTER this hook returns (Shop.price's own
			# Pre-Scratched Lottery Ticket override is the precedent: an
			# absolute override composed here would depend on where this
			# handler happens to sort against every other discount, and could
			# go non-zero again if a later-sorting one added back on top) —
			# so this can add the +10% unconditionally, including to the free
			# slot, with no observable effect once Shop.price zeroes it.
			ctx.amount += ctx.base * 0.10

		["deep-state-yearbook", "on_purchase"]:
			# "Each OTHER Artefact you own pays +5 Gold" — Shop.buy() appends
			# the bought artefact to g.artefacts BEFORE this dispatch (see
			# there), so g.artefacts.size() already counts the copy just
			# bought; "-1" excludes exactly that one, whether it's a
			# different artefact or (buying your first-ever copy of the
			# Yearbook itself) the Yearbook's own new copy — either way
			# "each other Artefact you own" is size() - 1. Direct g.gold
			# write, same precedent as Putin's Golden Toilet Brush's
			# on_purchase handler above (this hook has no gold_bonus output
			# to route through).
			if ctx.kind == "artefact":
				g.gold += 5 * (g.artefacts.size() - 1)

		# --- issue 45: three Artefacts whose `(needs: ...)` blocker notes went
		# stale — all three hooks below already have a live call site (see
		# REGISTRY comment above / .scratch/gdd-gaps/issues/45) ---
		["frog-pride-flag", "on_piece_lost"]:
			# Arms on ANY player-piece loss, not per-reason — "losing a piece"
			# has no qualifier in the catalog text. ctx.cancel (issue 24,
			# Fireproof Pajamas) means the piece is NOT actually lost — same
			# skip as KGB Photo Eraser's on_piece_lost handler above.
			if not ctx.cancel:
				g.frog_armed = true
		["frog-pride-flag", "on_deploy"]:
			# Single flag, not a counter: losing several pieces before the
			# next Deploy still only arms once ("the next piece", singular —
			# issue 45's own wording). Consumed here regardless of how many
			# losses armed it.
			if g.frog_armed:
				g.frog_armed = false
				_grant_buff(g, ctx.pos) # full pool, per _random_buff_key
					# (Ruling 1, header above) — the catalog text names no tier

		["y2k-patch-floppy-disk", "on_wave_spawn"]:
			g.y2k_armed = true # (re)arm every Wave — a held copy or two still
				# only means "the first Turn is skipped" once (see below)
		["y2k-patch-floppy-disk", "on_enemy_turn_start"]:
			# Deliberate exception to the additive-stacking rule (header):
			# two held copies both dispatch this same call, but the flag only
			# consumes once — the second copy's own dispatch is then a no-op,
			# so 2 copies still skip exactly ONE Turn, never two.
			# ctx.actions = 0 is an ABSOLUTE override (there is no "skip"
			# concept to add to), not a delta off a base — and it composes
			# safely with Filibuster's own additive "+1" on this same hook
			# because run() always dispatches the artefacts group before the
			# tariffs group (header's "Tariff/artefact ordering" note): this
			# handler's zeroed ctx.actions is always the base Filibuster's
			# "+1" lands on top of, deterministically, by group order — never
			# by where "filibuster" happens to alphabetically sort against
			# "y2k-patch-floppy-disk" (they're in different groups, so that
			# comparison never even runs). Net result held together: the
			# enemy's first Turn gets exactly Filibuster's bonus action, not
			# the normal 1 and not 0 — the same "artefact base, tariff modifies
			# on top" shape on_milestone/Recession already established.
			if g.y2k_armed:
				g.y2k_armed = false
				ctx.actions = 0

		["pandemic-toilet-paper-pallet", "on_purchase"]:
			g.pallet_purchase_count += 1
		["pandemic-toilet-paper-pallet", "on_price"]:
			# PURE read of the counter — Shop.price() runs this on every
			# redraw (the same Mar-a-Lago Toilet Papers trap, issue 43's own
			# comment above), so mutating here would drift the displayed
			# price between frames. "+1" reads the counter as if the pending
			# purchase already happened — the 2nd/4th/6th... purchase this
			# Shop visit (g.pallet_purchase_count reset in game.gd's
			# _open_shop()) is 50% off the immutable base, same additive
			# percentage contract as every other on_price handler.
			if (g.pallet_purchase_count + 1) % 2 == 0:
				ctx.amount -= ctx.base * 0.5
