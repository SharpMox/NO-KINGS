# PRD: Rework Items — Counter-Intel, Drone Strike, Extraction

Status: done — all 3 slices merged; grilled 2026-07-17 (CONTEXT.md terms + ADR-0002, PR #58); Notion
Items DB rows flipped REWORK → KEEP with "implementation pending".
Tracker note: Linear MCP not connected; this file + `issues/` is the tracker
(money-and-shop precedent). Triage: needs-triage → this PRD supersedes it —
slices below are pre-triaged into implementation order.

## Problem Statement

The 2026-07-13 STATUS triage (PR #56) deleted three items the catalog is
poorer without: the player has no answer to tariffs (Counter-Intel), no
board-clearing panic button (Drone Strike), and no way to rescue developed
pieces from a collapsing position (Extraction). Their old designs were flagged
REWORK — turn-counted tariff relief that was fiddly to track, a cramped 2×2
strike, and an Extraction whose stock behavior was undefined for stateful
pieces.

## Solution

Ship the three reworked designs locked in the 2026-07-17 grilling:

- **Counter-Intel** (Strategic, instant): suppresses action + persistent
  tariffs — Inflation included — for the rest of the current wave; the
  suppression ends when the next wave spawns. Oneoff tariffs are untouched.
- **Drone Strike** (Decisive, area): destroys every piece, ally and enemy,
  in a 3×3 area centered on the tapped tile; the King is unaffected. The area
  may hang off the board edge. Destruction is not capture.
- **Extraction** (Tactical, multi): select any number (≥1) of your board
  pieces and return them to Stock at their current identity. Piece state
  rides along opaquely (ADR-0002): Stock entries become `{id + state}`,
  stacked separately in the HUD, restored on placement, discarded on merge.

## User Stories

1. As a player, I want Counter-Intel to silence every active tariff for the rest of the wave, so that I can take a heavy-action turn without bleeding money.
2. As a player, I want Counter-Intel to also pause Inflation's cut on my gains, so that "all tariffs" means what it says.
3. As a player, I want the suppression to end when the next wave spawns, so that its window is readable from the board, not from a hidden counter.
4. As a player, I want the HUD tariff display to show that tariffs are suppressed, so that I know my actions are currently free of surcharges.
5. As a player, I want Drone Strike to let me aim a 3×3 area by tapping its center tile, so that placing the blast feels precise.
6. As a player, I want a live highlight of the 9 affected tiles before I commit, so that I never misjudge the blast area.
7. As a player, I want to aim the blast at board edges with the excess hanging off, so that every tile on the board is reachable.
8. As a player, I want Drone Strike to destroy my own pieces in the area too, so that using it is a real trade-off, not a free wipe.
9. As a player, I want the King to survive a Drone Strike, so that checkmate remains the only way to beat a King wave.
10. As a player, I want destroyed pieces to award no score, money, or trinket procs, so that destruction and capture stay distinct economies.
11. As a player, I want Extraction to let me tap-toggle any number of my pieces and confirm, so that one item can rescue a whole cluster.
12. As a player, I want extracted pieces to return at their current identity (promoted/merged stays promoted/merged), so that rescuing developed pieces is the point of the item.
13. As a player, I want to back out of an Extraction selection before confirming without spending the item, so that exploring the selection is free.
14. As a player, I want a piece extracted with state (e.g. a future buff) to keep that state in Stock and get its own stock stack, so that it doesn't blend into the plain copies.
15. As a player, I want placing a stateful stock piece to restore its state on the board, so that extraction → redeploy round-trips faithfully.
16. As a player, I want my old saves to keep working after the stock format learns about state, so that an update never eats a run.
17. As a player, I want all three items to appear in lootbox rolls and the Shop like any other item, so that they enter play through the normal acquisition paths.
18. As a player, I want each use to cost 1 action (plus the ability tariff if one is active and unsuppressed), so that items stay inside the unified action economy.
19. As a developer, I want Stock code to never interpret piece state, so that any future buff design flows through without a Stock/save migration.
20. As a developer, I want each item's behavior covered by headless tests and a scenario, so that regressions surface in the standard suite.

## Implementation Decisions

- **Counter-Intel** is an instant item (no target). It sets a run-state flag
  consulted by the two tariff application points: the action-surcharge gate
  (`tariff_on`) and the persistent-modifier loop in money `gain`. The flag
  clears when the next wave's spawn executes. It is saved in the mid-run save
  so a reload cannot shake off or extend the suppression. The HUD tariff
  overlay shows a suppressed marker while active (precedent: the deleted
  version's `·off` note).
- **Drone Strike** introduces the fourth item target mode, `area`: every board
  tile is a valid anchor; the targeting highlight covers the 3×3 around the
  hovered/tapped anchor; commit destroys every non-King piece in the
  intersection of the area with the board, through the existing destruction
  path (no score, no money, no trinket procs, allies simply die).
- **Extraction** introduces the fifth target mode, `multi`: valid tiles are
  your own board pieces; taps toggle membership in a selection set; a confirm
  affordance appears once the set is non-empty; confirming spends the item and
  moves each selected piece into Stock; cancelling (tap the armed item again)
  resets the selection and leaves the item unspent.
- **Stock entry contract (ADR-0002)**: a Stock entry is a bare id `String` or
  a `Dictionary` `{id + opaque piece state}`. Extraction strips board-only
  fields (position, owner) and keeps whatever remains; today that leaves
  every extracted piece a bare id (allies cannot carry state yet), but the
  pipeline never assumes so. Stock UI stacks by whole-entry equality;
  placement merges the stored state back onto the board piece; merge inputs
  lose their state; saves serialize entries as-is, and bare-string stocks from
  old saves load unchanged.
- All three items join the item catalog and therefore the lootbox and Shop
  pools automatically; tiers per the Notion Items DB (Strategic / Decisive /
  Tactical).
- The autoplay bot and scenario sweep must be able to exercise both new
  target modes headlessly (pick a random anchor; extract a random non-empty
  selection).

## Testing Decisions

- Tests assert external behavior only: board/stock/money/score state after an
  item resolves — never internal flags or call order.
- Headless suites: extend the items suite with the three effects (suppression
  economics, 3×3 destruction incl. King survival and edge overlap, extraction
  round-trip incl. a synthetic stateful piece to prove pass-through); extend
  the save suite with the mixed String/Dictionary stock round-trip and an
  old-format load.
- Scenarios: one per item in the scenario catalog (manual sandbox + swept by
  the scenario suite + autoplay).
- Click probes: extend the game probe for the two new targeting flows
  (area anchor tap; multi toggle + confirm), per the UI-first policy.
- Prior art: the money/shop/items suites from the Money & Shop epic.

## Out of Scope

- Designing the actual buff system (kinds, acquisition, display) — ADR-0002
  only guarantees Stock transports whatever it turns out to be.
- Buff-preserving merges — merge discards state until the buff design says
  otherwise.
- Any tariff catalog rebalance (the ~/100 cost scaling note in the tariffs
  data file remains a separate design pass).
- Reintroducing any other deleted item (REMOVE verdicts stand).

## Further Notes

- Notion Items DB is the design source of truth; its three rows already carry
  the grilled semantics in Notes. The in-game catalog comment should keep
  pointing at it.
- Glossary terms for this epic (Tariff, Tariff suppression, Destruction,
  Stock entry) landed in CONTEXT.md via PR #58; ADR-0002 records the
  stock-state preshot decision.
