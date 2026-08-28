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

## Blocked by

- the four decisions above
