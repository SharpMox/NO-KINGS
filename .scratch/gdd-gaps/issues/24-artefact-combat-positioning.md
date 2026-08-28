# 24 — Artefacts: combat & positioning rules (zones, dodge, forced moves)

Status: done (partial — see Outcome)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Split out of

19 — that slice's `_on_enemy_half`/`_player_positions` helpers cheaply
covered the two artefacts that just *read* board position (Dyatlov Geiger
Counter, FEMA Summer Camp Flyer). Everything here instead wants to *change*
combat resolution or movement legality itself — `Rules.legal_moves`,
`Rules.is_attacked`, and `_move_player`'s capture branch are pure/static and
don't know about `g.artefacts` at all, so each of these means threading
artefact-awareness into code that's deliberately artefact-agnostic today.

## What to build

| Artefact | Needs | Note |
| --- | --- | --- |
| Cheyenne Mountain Doorbell | capture-immunity zone | "pieces on your back row cannot be captured" — `Rules.legal_moves`/AI target selection would need to exclude row-0 player pieces, for both the player's own move-legality display and the enemy AI |
| Winchester Salt Lined Doors | zone denial | "enemy pieces cannot move onto your back row" — same shape, the mirror direction |
| Bovine Tractor Beam | forced move | "once per Wave: move one enemy piece anywhere on your side" — a player-initiated targeting action (new Item-like UI flow), not a hook |
| Royal Fiat (Undamaged) | forced retreat | "your first piece to Capture each Turn is moved to your back row after capturing" — post-capture board mutation with a real placement question (which back-row tile if it's occupied?) |
| USS Eldridge Invisibility Paint | return-to-start position | "on your first Capture each Turn: the capturing piece returns to its starting position" — on_capture fires from `Economy.capture_score`, mid-`_move_player`, BEFORE `board[to] = board[from]` runs; expressing "undo the slide after landing" needs a ctx flag `_move_player` checks post-move, the same shape Blitz/Stargate already use for actions but not yet used for position |
| Inflatable Vietcong Torpedo | dodge + choice | "once per Wave, when a piece would be captured: pay 15 Gold and it survives" — a modal choice mid-capture-resolution (does the player see this before or after the capture lands?) |
| UAP Breath Mint | dodge | "once per Wave: the piece instead moves 1 square away" — same trigger point as Torpedo, no choice, needs a landing-tile rule (which adjacent square?) |
| Hoffa's Cement Shoes | mutual destruction | "once per Wave: when a piece is captured, the capturer sinks with it" — Trap's mechanic already exists (BuffLogic "trap"); this is Trap-as-a-passive-Artefact-rule instead of a Piece Buff, once per Wave |
| Fireproof Pajamas | destruction immunity | "pieces cannot be destroyed by Item or Tariff effects" — `_destroy`/`_detonate`'s callers (Drone Strike, Air Strike, Sniper, bomb detonation, `jd_vance` tariff) would all need an owner+artefact check |
| Roanoke Hex Kit | piece removal | "on use: the strongest enemy piece vanishes, no Score/Gold; recharges every 2nd 5-Wave Milestone" — a player-initiated action with a recharge-state field, not a passive hook |
| Zapruder's Director's Cut | action replay | "once per Wave: repeat your previous Action without spending an Action" — needs the last action's full shape recorded (move/capture/item/merge — different action types, different replay semantics) |
| Pegasus Free Trial | double move | "pieces at the end of their Rank chain can move twice each Turn" — an action-economy change scoped to specific pieces, not a flat +1 Action; `moved_this_turn`'s single-move-per-piece lock would need a per-piece exception |
| Alien Pet Rocks | movement tracking | "at Wave end: +2 Gold per allied piece that didn't move this Wave" — `moved_this_turn` resets every Turn, not Wave; needs a new `moved_this_wave` Set threaded through every move/place site, reset in WaveLogic.queue |
| Curtain Rods Bag (Rifle-Shaped) | score/gold split | "double Score, but it pays no Gold" (issue 16's held-back note) — the `ctx.pts -> Economy.earn` pipeline derives Gold from the same amount as Score; suppressing Gold for one specific capture needs a ctx flag threaded through `capture_score` into `earn()`, the same "flag survives the call boundary" gap Zeta Reticuli Souvenir Map hits in issue 26 |

## Acceptance criteria

- [ ] Cheyenne Mountain Doorbell / Winchester Salt Lined Doors: a design
      ruling on where zone rules plug into `Rules` (a parameter? a
      passed-in artefact set?) before either ships — this one's genuinely
      structural, worth a `grill-with-docs` pass of its own
- [ ] USS Eldridge Invisibility Paint / Royal Fiat: a shared "post-move ctx
      flag" mechanism, since both want to mutate the board after
      `_move_player`'s own slide already ran
- [ ] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine
- 19 — Special + prereq triage (this file is one of its splits)

## Outcome

PR #126 (`feat/artefact-combat-positioning`), branched off main after #125
(the ctx-contract fix). 4 of the 14 artefacts shipped; 88 -> 92 of 180
implemented. `game/tests/run_all.sh` ALL GREEN, 9 new `test_items.gd` checks.

**Shipped**, all via the shared "post-move ctx flag" mechanism this file's
acceptance criteria called for:
- **USS Eldridge Invisibility Paint** and **Royal Fiat (Undamaged)**:
  `Economy.capture_score` now stashes its `on_capture` ctx on
  `g.last_capture_ctx` (a Dictionary reference, so it survives the call
  boundary the existing `int` return can't) right before returning. Both
  gate on `turn_capture_index == 0 and attacker_pos.x >= 0` (first Capture
  this Turn, a real attacker — same pattern as CIA Heart Attack Gun /
  Obedience-Flavored Tap Water). `_move_player` snapshots
  `return_to_start`/`move_to_backrow` into locals right after its own (first)
  `capture_score` call — before Multicapture's second call can overwrite
  `g.last_capture_ctx` — then applies whichever one fired right after its
  own `board[to] = board[from]` slide. Royal Fiat's landing tile: the first
  empty back-row (y=0) square scanning x=0..BOARD_W-1 (ruled 2026-08-28, no
  GDD guidance on ties); a full back row is a no-op, the piece stays on
  `to`. Holding both at once (rare — both Rare-rarity): return_to_start wins
  the tie, since it fully undoes the move rather than partially redirecting
  it. Neither flag is read outside the plain-capture path — Trap/Bomb/
  Multicapture's branches `return` before reaching it, which reads as "the
  piece already didn't end its move at `to` for other reasons."
- **Fireproof Pajamas**: `on_piece_lost` grew a `cancel` output flag
  (mirroring `on_item_consume`'s), scoped to `ctx.reason == "destroyed"` —
  `_destroy` is already the single choke point every Item/Tariff kill funnels
  through (Drone Strike, Air Strike, Sniper, bomb detonation via `_detonate`,
  the jd_vance Tariff), so one guard there covers all of them. Captures/Trap/
  Reflect don't set `reason == "destroyed"`, so ordinary combat is untouched.
  `_lose_player_piece` now returns its ctx (was void) and only increments
  `lost_player` when the loss isn't cancelled; the other 4 existing call
  sites already ignored the return value, so this is additive.
- **Hoffa's Cement Shoes**: reuses `on_piece_lost`'s `reason == "captured"` +
  `attacker_pos` gate (Tutankhamun's Death Thong's exact condition) to set a
  new `destroy_attacker` output flag, once per Wave
  (`g.hoffa_used_this_wave`, reset `on_wave_clear` — the
  "satoshi-s-private-key"-style two-hook shape). The enemy-move loop
  (`_run_enemy_actions`) reads the flag straight off `_lose_player_piece`'s
  return and, when set, removes the attacker too — Trap's existing mutual-
  destruction branch, just artefact-gated instead of BuffLogic-gated, and
  once per Wave instead of every time.

**Left `implemented: false`** (quality over count — each is a real follow-up,
not a guess):
- **Cheyenne Mountain Doorbell** / **Winchester Salt Lined Doors**: still
  need the design ruling this file's own acceptance criteria called for —
  where a zone rule plugs into `Rules.legal_moves`/AI target selection (a
  parameter? a passed-in artefact set?) before either can ship. Worth its
  own `grill-with-docs` pass, not a call to make inside a batch PR.
  Notion question.
- **Bovine Tractor Beam** / **Roanoke Hex Kit**: both are player-initiated
  targeting actions (a new Item-like UI flow + a recharge-state field for
  Roanoke), not something `ArtefactHooks` dispatch can express — out of
  scope for a hook-registry slice.
- **Inflatable Vietcong Torpedo** / **UAP Breath Mint**: both need a new
  pre-capture "would be captured" choke point in the enemy-move loop
  (nothing dispatches there today — Reflect/Shield/Trap/Bomb are all
  hardcoded BuffLogic checks, not registry hooks) plus an undecided design
  ruling (Torpedo: a modal gold-payment choice, timing unclear from the GDD
  text; Breath Mint: which of 8 adjacent squares). Deferred rather than
  opening a new branch in the same combat loop two other concurrently-active
  branches (`feat/artefact-buff-lifecycle`, `feat/artefact-capture-ledger`)
  are also touching, under an unresolved design question. Notion question
  for the Torpedo's choice timing; Breath Mint's landing square is a smaller
  ruling that could ship alongside a future pre-capture hook.
- **Zapruder's Director's Cut**: needs a recorded "last action" shape
  spanning move/capture/item/merge — each with different replay semantics —
  before "repeat it" means anything. Not attempted; a guess here would be
  wrong more often than right.
- **Pegasus Free Trial**: needs a per-piece exception to
  `moved_this_turn`'s flat `Array[Vector2i]`-membership lock (Blitz already
  depends on its exact shape via `.erase()`). Redesigning that data
  structure's semantics mid-batch, while other branches also touch move
  sites, was judged too risky for this slice; deferred rather than rushed.
- **Alien Pet Rocks**: needs a new `moved_this_wave` Set threaded through
  every move/place site, reset in `WaveLogic.queue` — explicitly flagged in
  this file as invasive; out of scope for a 4-artefact batch.
- **Curtain Rods Bag (Rifle-Shaped)**: needs a ctx flag threaded through
  `capture_score` into `earn()` so a single capture can suppress its own
  Gold payout — the exact "flag survives the call boundary" gap issue 26 is
  scoped to close for Zeta Reticuli Souvenir Map. Deferred to that issue
  rather than duplicating the fix here.
