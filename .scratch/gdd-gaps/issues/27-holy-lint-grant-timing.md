# 27 — Holy Lint's grant is eaten by its own capture

Status: done (2026-08-28)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Found by

The slice-20 balance sweep did not catch this; a **flaky test** did. The check
`"Holy Lint: the capturing piece gets +1 Piece Buff"` failed roughly 1 run in 3 on
identical code, which turned out not to be flakiness in the harness at all.

## The problem

Holy Lint reads *"On Capture, the capturing piece gets +1 Piece Buff."* Its handler calls
`_grant_buff(g, ctx.attacker_pos)` with **no tier**, so the roll is uniform over all 12
Piece Buffs. But the grant fires from inside `Economy.capture_score`, which `_move_player`
calls **before** its own `critical` / `range` consumption block.

So when the roll lands on `critical` or `range`, the buff is granted and consumed by the
same capture, for zero net effect. That is **2 of 12 rolls — about 17%** of the time this
artefact does literally nothing.

(A third case, `slow`, expired immediately when the capture cleared the board and
auto-passed into a new turn, but that one was an artefact of the test fixture rather than
a general problem.)

## Why it is a design question, not a bug fix

Two defensible readings, and picking one is a design call:

1. **Reroll away from same-capture-consumable keys** — Holy Lint always lands something
   the piece keeps. Simple, but it silently narrows the buff pool for one artefact.
2. **Resolve the grant after the capture's consumption checks** — the buff always applies
   to the *next* capture. Truer to "gets +1 Piece Buff", and it would apply uniformly to
   any future grant-on-capture artefact rather than special-casing this one.

Reading 2 looks better, but it changes ordering inside `_move_player`, which several
Piece Buffs and artefacts now depend on — so it wants a deliberate pass, not a patch.

## Outcome (2026-08-28)

Both halves resolved by the user, then implemented in `fix/artefact-rulings`.

**Ruling 1 — `slow` is excluded from RANDOM grants.** The deeper problem turned out not to
be the timing at all: `slow` is a *debuff* (the piece moves and captures like a Pawn), so an
artefact reading "+1 Piece Buff" could actively penalise the player's own piece. It is now
flagged `self_harming` in the catalog and filtered out of random grants across every
grant-on-capture artefact. `smog` stays — it debuffs *adjacent enemies*, so it is a genuine
buff for its holder. The Buff Box's player-chosen sub-pick still offers everything, because
choosing Slow deliberately (onto an enemy) is legitimate.

**Ruling 2 — the grant lands after the capture.** Reading 2 from below. Grant-on-capture
artefacts now append to a `ctx.grant_buffs` output list which `_move_player` applies *after*
the critical/range consumption block, so the buff is banked for the next capture. User's
framing: "it really works as a reward."

**Correction to this issue's original diagnosis.** It claimed ~17% of rolls "do nothing".
Re-reading the code showed that was imprecise: `capture_multiplier` is evaluated *after*
`capture_score` in the same expression, so a rolled `critical` was doubling the current
capture rather than being wasted. Only `range` was genuinely inert. The real defect was the
`slow` case nobody had named.

## Acceptance criteria

- [ ] Decide between the two readings (or a third), and record it on the Notion Holy Lint
      page
- [ ] Whatever is chosen, applies to *any* grant-on-capture artefact, not just Holy Lint
- [ ] The seed pin in `test_items.gd` can then assert the contract rather than one
      specific rolled key
- [ ] `run_all.sh` all green

## Blocked by

- nothing (needs a decision, not code)
