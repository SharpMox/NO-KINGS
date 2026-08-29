# 33 — Board & positional rules

Status: blocked — NEEDS DESIGN DECISIONS (do not start without them)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why this is parked

These artefacts change how the **board itself** behaves, which reaches into
`Rules.legal_moves` / `moves_for` / `ai_action` — the most load-bearing code in the game,
and the part every Piece Buff, Tariff and AI heuristic now sits on top of.

| Artefact | Needs |
| --- | --- |
| Cheyenne Mountain Doorbell | **Capture-immunity zone** — squares where pieces cannot be taken |
| Winchester Salt Lined Doors | **Zone denial** — squares the enemy cannot enter |
| Bovine Tractor Beam | **Forced move** — move an enemy piece on demand |
| Inflatable Vietcong Torpedo, UAP Breath Mint | **Dodge** — a pre-capture "would be captured" interception |
| Zeta Reticuli Souvenir Map | **Capture conversion** — a captured enemy becomes an ally |
| Alien Pet Rocks | **Movement tracking** — a per-wave "has moved" set |
| Pegasus Free Trial | **Move-twice for chain-end pieces** — redefines `moved_this_turn` |
| Hellfire Club Discord Invite | **Forced-action rule** |
| 'Definitely Not Russia' Patch | **Loss masking** |

## The decisions needed first

1. **Do zone rules bind the AI, or only the player?** `ai_action` would need to respect
   them or it will walk into illegal squares.
2. **A "dodge" needs a pre-capture interception point that does not exist.** Piece Buffs
   (Shield/Reflect) intercept *at* the capture; a dodge implies choosing a landing square,
   which is a modal mid-capture. Same question as slice 32's choice modal.
3. **Pegasus Free Trial redefines `moved_this_turn`**, which Blitz now depends on
   (`blitz_free_move` and the lock-lift). Changing its semantics needs care.
4. **Capture conversion** — does a converted piece keep its buffs? enter Stock or the board?

The `grill-with-docs` skill exists for exactly this shape of problem; this group wants one
pass rather than nine separate rulings.

## Addendum 2026-08-29 — "what zone rules do we have?"

The user asked this directly. Answering it up front, because it turns out decision #1 is
much cheaper than this issue assumed, and the answer narrows what actually needs ruling.

### What exists today

The game already has a full vocabulary of zone **queries**. Every one of these ships:

| Zone | Where | Used by |
| --- | --- | --- |
| **Placement zone** — rows `y < PLAYER_ZONE_ROWS` (0–1), plus any empty square adjacent to one of your pieces | `Rules.placement_tiles` / `_touches_player` | Setup, Deploy |
| **Deploy tiles** | `game.gd._deploy_tiles()` | Deploy; Nazca Boarding Pass widens it to *any* empty square |
| **Spawn row** — `SPAWN_ROW = BOARD_H - 1` (row 11) | `tuning.gd` | Wave entry; spills to the next Turn when full |
| **Your back row** — `y = 0` | `game.gd._back_row_breached()` | The loss condition: you lose when **all 8** back-row tiles hold an enemy (`BACKROW_COMMIT_COUNT`) |
| **"Near" rows** — 0–2 | `BACKROW_NEAR_ROWS` | The AI's back-row commit heuristic |
| **Board halves** | already shipped | FEMA Summer Camp Flyer ("your half"), Dyatlov Geiger Counter ("enemy half") |
| **Adjacency** | `_adjacent_source`, `_touches_player` | Aura, Smog, Pied Piper's Rat Census |
| **Forced relocation to the back row** | `game.gd._first_empty_backrow_tile()` | Royal Fiat (Undamaged) |

### So what is actually missing

Not zones — **restrictions**. Every zone above answers a question; none of them forbids
anything. Winchester wants a zone that denies *movement*, Cheyenne a zone that denies
*capture*. That is the whole gap.

### Decision #1 is nearly free

This issue worried that `ai_action` would "walk into illegal squares" and need its own
handling. It will not: **`ai_action` calls `Rules.legal_moves` (rules.gd:280)**, the same
generator the player's moves come from. One filter there binds both sides. There is no
second AI move generator to keep in sync.

The one constraint: `rules.gd` is a **pure static module with no access to `g.artefacts`**,
and it should stay that way. So the denied-square set is computed by the caller
(`game.gd`, from the held Artefacts) and passed *into* `legal_moves` as a parameter —
never read from game state inside `Rules`.

### Winchester makes the back-row breach loss unreachable — and that is just the effect

You lose the run when every back-row tile holds an enemy. If enemy pieces cannot move onto
your back row, that cannot happen, so holding Winchester means only the Clock can end the
run.

An earlier revision of this addendum called that a "side effect" and raised it as a
blocking balance question. **Both framings were wrong** (user, 2026-08-29): "Enemy pieces
cannot move onto your back row" straightforwardly *means* enemies never occupy the back
row, so breach immunity is the plain reading of the card, not something the implementation
sneaks in. And the user had already ruled that balance tuning waits until every gameplay
lever is coded, so raising it as a blocker re-litigated a settled decision.

Recorded because the failure is worth remembering, not the conclusion.

**Cheyenne Mountain Doorbell** is unaffected either way — capture immunity on `y = 0` does
not touch the breach condition, which only counts enemy occupancy.

### GO-AHEAD: Winchester and Cheyenne are cleared to build

Ruled by the user (originally before the 2026-08-29 compaction, and re-confirmed after).
**Written here because the first ruling existed only in conversation** — when context
compacted, this file still said "blocked", the durable record won, and the decision was
re-derived from scratch. Rulings go in the issue file when they are made.

Both are implementable now:

- **Winchester Salt Lined Doors** — enemies cannot move onto `y = 0`. One filter in
  `Rules.legal_moves`, denied set passed in by `game.gd`.
- **Cheyenne Mountain Doorbell** — player pieces on `y = 0` cannot be captured. Hook the
  existing repel path (`BuffLogic.repels_capture` is the precedent for "this capture
  attempt does not happen"), keeping `rules.gd` pure.

Order is free; Cheyenne is the simpler of the two.

### What still needs a ruling

Decision #1 is answered (one filter in `legal_moves`, fed from the caller), and the two
zone Artefacts are cleared. Decisions #2 (dodge / mid-capture modal), #3 (Pegasus vs
`moved_this_turn`) and #4 (capture conversion) stand unchanged.

Issue 48's Bounty Piece Buff was briefly thought to be a new dependent of #2, since it
pays out on *losing* an ally piece inside the enemy turn loop. **It is not.** Checked
2026-08-29: `_lose_player_piece` is synchronous and `ArtefactHooks.run` does not await, so
no handler can open a modal there — but Bounty's Box is a *payout* that changes nothing
about the capture, so it can simply be deferred to the start of the player's next turn.

The distinction is the useful part: #2 is only needed when the choice **changes the outcome
of the capture itself** (Inflatable Vietcong Torpedo: pay 15 Gold and the piece survives).
A reward that merely follows a capture never needs the turn suspended.

### Addendum 2026-08-29 (second pass) — this issue is now fully resolved

All four decisions are answered, and every Artefact in the table above has a home:

- **#1 zone rules** — answered; Winchester and Cheyenne shipped in slice 51.
- **#2 dodge / mid-capture choice** — **dissolved rather than decided.** The user ruled that
  UAP Breath Mint auto-selects its landing tile (and does nothing when none is free) and that
  Inflatable Vietcong Torpedo auto-pays when affordable. Both resolve without a prompt, so
  **nothing in the catalog needs a suspended enemy turn.** Issue 54 builds them.
- **#3 Pegasus vs `moved_this_turn`** — **made moot.** The user reworked Pegasus Free Trial
  to "the first move or capture each Turn by an end-of-chain piece costs no Action", which
  reuses the Blitz free-move mechanism and never touches `moved_this_turn`. Issue 54.
- **#4 capture conversion** — answered by ADR-0002: a Stock entry already carries opaque
  piece state, so a converted piece keeps what it had. Issue 55.

Remaining Artefacts from the table are distributed: Bovine Tractor Beam and Zapruder's
Director's Cut to issue 52 (activation), Alien Pet Rocks and 'Definitely Not Russia' Patch to
issue 53, Hellfire Club Discord Invite to issue 54.

## Blocked by

- nothing — all four decisions resolved, work distributed across issues 51-55
