# 81 — The hand-built combo boards (20-30)

Status: todo

## Parent

`.scratch/gdd-gaps/issues/73-scenario-coverage.md` (split (b))

## Scope

The boards a generator cannot produce, because their point is an *interaction* rather than a
trigger. 20-30 of them, hand-authored. From 73: the stacking pairs, the cap interactions, and
the Army Power / Artefact overlaps.

These are the ones that will actually get opened twice — the rest of 73 is a reference shelf.

## Candidates worth including

Drawn from interactions this backlog has already argued about, so each board settles a
question that has genuinely come up:

- **The three caps refusing at the limit** — Items 3, Piece Buffs 2, Artefacts 5. One board
  each, already at the cap, with a grant incoming, to watch it refuse *visibly* rather than
  silently drop (issues 53, 60).
- **Deep State Yearbook + selling** — the loop that was wrongly called infinite. A board that
  shows it netting -5 per cycle is the fastest possible answer to it being raised again.
- **Mao's Loyalty Badge** buy-two-sell-both, break-even at 50%.
- **Denver Bunker Timeshare** losing its +30% the moment an Item is sold.
- **Tape Eraser Magnet** — selling is not using; it must not fire.
- **Captured Stock**: merge, convert at 50%, sell — and *not* deployable (issue 60's largest
  behaviour change).
- **Jet Fuel Vial / Pandemic Toilet Paper Pallet** across a Wave boundary, since both moved
  off the retired per-visit boundary (issue 61).
- **Army Power + Artefact overlaps** — the six Armies against the Artefacts that touch the
  same resource.
- **Bible Gag Reel Scroll** granting Shield to all three of `bishop` / `dragon-horse` /
  `archbishop` and hitting the Buff cap (issue 58).

Judgement work: pick the ~25 that teach the most, not the ones that are easiest to build.

## Acceptance

- Each board is named for the question it answers, not for the Artefact it holds.
- Loadable and playable; the interaction is visible within a couple of moves, not twenty.
- Boots under `test_scenarios.gd`.
- `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

- 79 (menu grouping — these land in the same list)
