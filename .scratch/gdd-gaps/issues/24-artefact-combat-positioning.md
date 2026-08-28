# 24 — Artefacts: combat & positioning rules (zones, dodge, forced moves)

Status: todo

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
