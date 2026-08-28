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

### The real question Winchester raises — and it is a balance one, not a technical one

> **Winchester Salt Lined Doors removes a loss condition outright.**

You lose the run when every back-row tile holds an enemy. If enemy pieces *cannot move
onto your back row at all*, that can never happen — so holding Winchester makes you
permanently immune to the breach loss, and only the Clock can end the run.

That may well be intended for a Legendary. But it is a much larger effect than "zone
denial" sounds, it is permanent rather than once-per-Wave, and it should be an explicit
call rather than something that arrives as a side effect of the implementation. Options,
if it reads as too strong: make it expire (N Waves / once per Wave), restrict it to a
subset of the back row, or let enemies enter but not *end their move* there.

**Cheyenne Mountain Doorbell has no such problem** — capture immunity on `y = 0` does not
touch the breach condition, since a breach only counts enemy occupancy. It is the safer
of the two to build first, which is the reverse of the order previously assumed.

### What still needs a ruling

Decision #1 is answered (one filter, in `legal_moves`, fed from the caller). Decisions #2
(dodge / mid-capture modal), #3 (Pegasus vs `moved_this_turn`) and #4 (capture conversion)
stand unchanged. Added to them: the Winchester balance call above.

## Blocked by

- decisions #2, #3 and #4 above, plus the Winchester balance call
- (decision #1 is resolved — see the addendum)
