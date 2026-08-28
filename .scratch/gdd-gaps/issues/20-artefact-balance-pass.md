# 20 — Artefact rarity, weighting & balance pass

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

With the catalog implemented, make it *play*. Today artefacts are rolled uniformly from a
7-entry list; at 180 with four rarities that is no longer acceptable.

- **Rarity weighting.** Common 50 · Uncommon 54 · Rare 50 · Legendary 26. Box rolls and
  Shop stock draw weighted by rarity, not uniformly. Weights are tuning constants.
- **Rarity should be visible.** A Legendary and a Common look identical in the box-pick
  and shop today.
- **Progression.** Legendaries appearing on wave 2 flattens the run. Decide whether rarity
  is gated by depth/score or purely random, and record it.
- **Anti-stacking.** Artefacts stack. Some combinations are almost certainly degenerate
  once 180 exist — a percentage stack that runs away, or two artefacts that feed each
  other. Run the fleet/autoplay sweep with random artefact loadouts and look for runs that
  never end.
- **Shop pricing by rarity.** The Shop page currently prices every artefact at 100 flat.
  With four rarities that is probably wrong, and it is already listed as an open question
  on the page.

This is the slice where autoplay earns its keep: it can play thousands of runs with random
loadouts and surface the combinations a human would take weeks to find.

## Acceptance criteria

- [ ] Rolls and Shop stock weighted by rarity; weights in `tuning.gd`
- [ ] Rarity is legible in the box-pick and the Shop
- [ ] Progression rule decided and written back to Notion
- [ ] A fleet sweep over random loadouts, with degenerate combinations listed
- [ ] Per-rarity pricing decided, and the Shop page's open question closed
- [ ] `run_all.sh` all green

## Blocked by

- 16 / 17 / 18 / 19 — enough of the catalog implemented to be worth balancing
