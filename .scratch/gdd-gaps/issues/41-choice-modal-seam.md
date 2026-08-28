# 41 — Mid-effect choice modal

Status: todo — INDEPENDENT (ruled 2026-08-29)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

Six artefacts across slices 32 and 33 are blocked on the same missing primitive: a modal
that interrupts an effect to ask the player to choose. Yalta Cocktail Napkin, Exhibit 399,
Nostradamus Mad Libs, Cicada Rejection Letter, All-Seeing Eye Contact Lens, Inflatable
Vietcong Torpedo. Building it once unblocks the group.

## The ruling (user, 2026-08-29)

**A choice modal behaves exactly like the Buff Box sub-pick: it blocks input until the
player chooses, and the Clock keeps ticking the whole time.**

That is consistent with the [Box Pick](https://app.notion.com/p/36af1559c99b81a7ae8fc44029c93935)
rule — decisive picks rewarded, indecision punished — and it means the Buff Box was never
special, just first.

## What to build

Generalise what `_open_buff_pick` / `_buff_chosen` / `_buff_pick_cancelled` already do in
`game.gd` into a reusable "choose 1 of N, then continue" seam:

- Blocks board input the way `buff_pick_open` does (it is already in every input guard).
- Does **not** pause the Clock. Note slice 36's tier work made the Clock pause for drawers
  and the preview at Tier 1 — the choice modal is explicitly NOT one of those.
- Carries a continuation, so the caller resumes where it left off rather than the modal
  knowing what each artefact wants.
- Cancel/close behaviour: follow the Buff Box precedent — backing out leaves the effect
  unspent where that is meaningful.

Do **not** implement the six artefacts here. This slice is the seam plus a test proving the
block-input/keep-ticking contract. The artefacts follow one at a time (user's preference).

## Acceptance criteria

- [ ] A reusable choice modal, with the Buff Box migrated onto it (proving it generalises)
- [ ] Input blocked while open, at every existing guard site
- [ ] The Clock keeps ticking — asserted by a test, at Tier 1 as well as higher tiers
- [ ] Cancel leaves the triggering effect unspent
- [ ] `run_all.sh` all green

## Blocked by

- nothing
