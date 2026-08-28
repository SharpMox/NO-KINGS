# 27 — Holy Lint's grant is eaten by its own capture

Status: todo (design question)

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

## Acceptance criteria

- [ ] Decide between the two readings (or a third), and record it on the Notion Holy Lint
      page
- [ ] Whatever is chosen, applies to *any* grant-on-capture artefact, not just Holy Lint
- [ ] The seed pin in `test_items.gd` can then assert the contract rather than one
      specific rolled key
- [ ] `run_all.sh` all green

## Blocked by

- nothing (needs a decision, not code)
