# 41 — Mid-effect choice modal

Status: done (2026-08-29)

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

- [x] A reusable choice modal, with the Buff Box migrated onto it (proving it generalises)
- [x] Input blocked while open, at every existing guard site
- [x] The Clock keeps ticking — asserted by a test, at Tier 1 as well as higher tiers
- [x] Cancel leaves the triggering effect unspent
- [x] `run_all.sh` all green

## Outcome

Generalised `game.gd`'s `_open_buff_pick`/`_buff_chosen`/`_buff_pick_cancelled` into a
reusable seam without inventing new identifiers: `buff_pick_open` (the shared
input-block flag, already in every guard) and `modals.buff_panel` (the panel node) keep
their names — generalised in role, not renamed — so the existing Buff Box tests
(`test_items.gd`) needed zero edits, proving the migration is behaviour-preserving.

- `game.gd._open_choice_pick(header, offers, cancel_text, on_chosen, on_cancelled)` sets
  `buff_pick_open = true`, stores the two `Callable`s, and calls
  `modals.show_choice_pick`. The modal reports back via `choice_chosen(value)` /
  `choice_pick_cancelled`, which `game.gd` resolves to the stored continuation before
  clearing it — the modal and this seam never see what a caller does with the pick.
- `_open_buff_pick` now builds `{label, value}` offers from `Items.PIECE_BUFFS` and calls
  `_open_choice_pick(..., _buff_chosen, _buff_pick_cancelled)`. `_buff_chosen`/
  `_buff_pick_cancelled` lost their `buff_pick_open`/`modals.hide_*` bookkeeping (now
  generic, done once by the seam) but are otherwise unchanged.
- Clock: `buff_pick_open` was already absent from `_process`'s `tier_pauses` list at
  every tier (07-difficulty-ranks / Box Pick), so any caller through the new seam
  inherits "never pauses" for free — no new code needed there, only new test coverage.
- Tests: `tests/test_tiers.gd` exercises `_open_choice_pick` directly (not through the
  Buff Box) at Tier 1 and Tier 2+ — input-block, Clock-keeps-ticking, continuation-resume,
  and cancel-runs-the-cancel-continuation. `tests/test_game_clicks.gd` adds a windowed
  click probe: open the Buff Box via Inventory, confirm board clicks are blocked, Cancel
  leaves the item unspent, then a full pick-and-target pass spends it.
- Did not implement the six blocked artefacts (Yalta Cocktail Napkin, Exhibit 399,
  Nostradamus Mad Libs, Cicada Rejection Letter, All-Seeing Eye Contact Lens, Inflatable
  Vietcong Torpedo) — out of scope per this issue, one at a time per the user's
  preference.

## Blocked by

- nothing
