# PRD: Money & Shop

Status: done — all 7 slices merged (PRs #48–#54)

## Problem Statement

Score currently does double duty: it is both the run's performance metric (the high-score table) and the spendable resource (placement costs, reinforce buys, tariff penalties). Every spend or tariff hit corrupts the metric — a player who plays well but shops actively ends the run with a *lower* score than one who hoards. Meanwhile there is almost nothing to spend on: items and trinkets only arrive through lootbox RNG, so income past the placement budget is dead weight.

## Solution

Split the two roles. **Score becomes a pure, up-only performance counter** — raw amounts, no deductions of any kind. A new per-run currency, **Money**, takes over every cost: it is earned 1:1 alongside score gains (Inflation taxes money instead of score) and spent in a new **Shop**, on placements, and on tariff penalties. The Shop is a bottom-row button next to Stock, opening a full-screen modal with a randomized 19-slot stock (lootboxes, trinkets, items, base pieces) that rerolls every 10 waves; each purchase costs money plus 1 action. The post-wave reinforce panel becomes free. The HUD shows money in the top bar (foes counter removed) and merges the Items and Trinkets drawers into a single Inventory drawer.

## User Stories

1. As a player, I want my score to only ever go up, so that it honestly reflects how well I played the run.
2. As a player, I want every action that awards score to also award money, so that playing well funds my purchases.
3. As a player, I want the Inflation tariff to tax my money income instead of my score, so that tariffs pressure my economy without corrupting my record.
4. As a player, I want tariff action charges and the Asset Freeze halving to hit my money, so that penalties cost me buying power, not leaderboard standing.
5. As a player, I want piece placements to cost money instead of score, so that deploying my army is an economic decision.
6. As a player, I want the post-wave reinforce panel to be free, so that rebuilding my army between waves is never gated.
7. As a player, I want a Shop button at the bottom of the screen next to Stock, so that I can shop mid-run during my turn.
8. As a player, I want the shop to stock 3 random lootboxes, 4 random trinkets, 4 random items, and 8 random distinct base pieces, so that every visit offers a varied catalog.
9. As a player, I want high-value pieces to appear in the shop rarely, so that heavyweights feel like finds, not fixtures.
10. As a player, I want each shop slot to sell out after one purchase, so that I can't stack the same trinket repeatedly from one stock.
11. As a player, I want the shop stock to reroll every 10 waves, so that the catalog refreshes as the run progresses.
12. As a player, I want each purchase to cost 1 action point on top of its money price, so that shopping competes with moving and capturing.
13. As a player, I want to browse the shop for free and see Buy buttons disabled when I can't afford a slot or have no actions left, so that the rules are visible before I commit.
14. As a player, I want a purchased piece to go to my stock, a purchased item to my held items, a purchased trinket to apply immediately, and a purchased lootbox to open the usual 3-option roll, so that purchases behave like their existing acquisition paths.
15. As a player, I want my money shown in the top bar next to my score, so that I always know my buying power.
16. As a player, I want the foes counter gone from the top bar, so that the header stays uncluttered with the new money display.
17. As a player, I want one Inventory button that opens a drawer showing both my items and my trinkets, so that my holdings live in one place.
18. As a player, I want Field Orders and Resupply Drop to work on money (free placements / refund placement costs), so that placement-economy items stay meaningful.
19. As a player, I want money, the shop's current stock, and its sold-out slots preserved across save/load, so that reloading can't reroll-scum the shop.
20. As a player, I want money to start at 0 and end with the run, so that each run's economy is self-contained.
21. As a player, I want the high-score table to keep ranking runs by score exactly as before, so that old records stay comparable.
22. As a developer, I want all shop logic in one pure module with no scene nodes, so that stock rolling, pricing, and purchase rules are testable headless.
23. As a developer, I want all money gains and charges routed through the economy module, so that no call site can drift from the score/money split.
24. As a developer, I want the shop reroll to be a plain callable, so that future effects (items, tariffs) can trigger a reroll without rework.
25. As a developer, I want all prices and weights as tuning constants, so that playtest rebalancing never touches logic.

## Implementation Decisions

- **New deep module: the Shop** (pure logic, mirrors the lootbox-roll module — no nodes). Owns: rolling the 19-slot stock (3 lootboxes / 4 trinkets / 4 items / 8 distinct base pieces), the weighted piece pick (weight = 1/value over merge-chain roots, excluding the King and the inversion pieces — 18 candidates), price lookup, purchase validation (money ≥ price, actions ≥ 1, slot not sold), purchase execution (debit money and 1 action, mark SOLD, return the granted good), and the reroll rule (at run start and every 10th wave; also exposed as a plain function for future external effects).
- **Economy module becomes the money authority**: the inflation-taxed gain path feeds money; tariff charges debit money; a single `earn` helper applies "raw score up + taxed money up" so call sites can't drift. Score has no decrement path left anywhere.
- **Money** is per-run state on the game node, integer, starts at 0, floored at 0 on debits.
- **Costs moved to money**: mid-turn placement (20), all tariff action charges (pass/deploy/capture/move/ability/fuse/box), Asset Freeze (halves money). Reinforce buys become free (panel otherwise unchanged, still price-less rows + Done).
- **Item re-texts**: Field Orders → "next 2 placements cost no money"; Resupply Drop → "refund the money cost of your last 3 placements"; both operate on money.
- **Purchases cost 1 action** uniformly (consistent with the unified action economy); browsing is free; buying never ends the turn; the shop opens only during the player's turn.
- **Purchase effects** reuse existing acquisition paths: piece → stock; item → held items; trinket → applies immediately (stacks); lootbox → opens the existing 3-option roll modal (its score option follows the new global rule: raw score, taxed money).
- **Prices** (tuning constants, playtest placeholders): pieces = catalog value; items by tier — Tactical 30 / Strategic 60 / Decisive 120; trinkets flat 100; lootboxes flat 50.
- **HUD**: top bar becomes clock · ★score · $money (green, after score) · wave — foes counter removed. Bottom row becomes Stock / Inventory / Shop / PASS; the Inventory drawer shows items and trinkets together.
- **Shop UI**: full-screen modal like the reinforce panel; rows in a scroll container (19 slots exceed the 480×800 viewport); each row: icon · name · price · Buy; SOLD greys the row.
- **Persistence**: the mid-run save gains money, the shop's slot contents, SOLD flags, and the reroll marker. The high-score record format is unchanged.

## Testing Decisions

- Good tests assert **external behavior** — money balances, slot states, what a purchase grants — never internals like weight tables or private helpers.
- **Shop module**: new dedicated headless suite (prior art: the lootbox-roll and item suites) — stock shape (3/4/4/8, distinct pieces, exclusions honored), sell-out, reroll cadence, purchase validation (money, actions, sold), purchase effects, price table.
- **Save round-trip**: extend the existing save suite — money, slots, SOLD flags, reroll marker survive save/load.
- **Score/economy semantics**: adjust the score and item suites — score never decreases; money takes Inflation, charges, and Asset Freeze; re-texted items act on money.
- **Click probes** (run windowed, FIRST, per repo policy): Shop and Inventory buttons open/close their surfaces; a Buy click completes a purchase.
- **Scenario sweep**: a shop scenario in the scenario catalog (manual sandbox + auto-swept).
- Full non-regression suite (`game/tests/run_all.sh`) all green before commit; autoplay bot updated for the free reinforce panel.

## Out of Scope

- **Seed system** (deterministic runs) — wanted soon; separate issue.
- **External shop-reroll effects** (items/tariffs that reroll the shop) — the callable hook ships, no effects use it yet.
- **Meta-currency** across runs; money is strictly per-run.
- Any shop catalog beyond the four rows (no abilities, no cosmetics, no clock time).
- New art; rows reuse existing piece textures and text glyphs.

## Further Notes

- All amounts are playtest placeholders on the ×10 economy; fleet data (median Crown run ends near score 30) says income is thin, so prices deliberately sit low.
- The 10-wave reroll cadence intentionally aligns with the existing milestone cadence (tariffs, clock refill, reinforce waves).
