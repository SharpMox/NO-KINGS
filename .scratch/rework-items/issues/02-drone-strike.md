# 02 — Drone Strike: 3×3 area destruction

Status: done
Type: AFK

## Parent

`.scratch/rework-items/PRD.md`

## What to build

Drone Strike as the first `area`-target item (Decisive tier): every board tile
is a valid anchor; the targeting highlight covers the 3×3 centered on the
anchor; committing destroys every non-King piece (ally and enemy) inside the
area's intersection with the board, through the existing destruction path.
Destruction is not capture: no score, no money, no per-capture trinket procs.
The item enters the catalog with its Notion description; the autoplay bot and
scenario sweep can fire it headlessly.

## Acceptance criteria

- [ ] Tapping a tile destroys all pieces in the 3×3 centered there, allies included; a King inside survives
- [ ] Corner/edge anchors work: the off-board part of the area is ignored
- [ ] Score, money, and per-capture trinkets (Greed, Score, Bounty, Lifesteal) are all unmoved by the destruction
- [ ] Targeting shows the 9-tile area before commit; tapping the armed item again cancels unspent
- [ ] Destroying the last enemy ends the wave via the normal cleared-board path
- [ ] Item costs 1 action + ability tariff on use
- [ ] Headless items suite covers the above; a Drone Strike scenario joins the catalog; game click probe exercises the area targeting; full suite ALL GREEN

## Blocked by

None - can start immediately
