# 04 — Shop skeleton + piece row

Status: needs-triage

## Parent

`.scratch/money-and-shop/PRD.md`

## What to build

The Shop, end-to-end for its piece rows. A new deep `shop` module (pure logic, no nodes — mirrors the lootbox-roll module) owns: rolling the 19-slot stock (3 lootboxes / 4 trinkets / 4 items / 8 distinct base pieces — rolled once at run start for now), the weighted piece pick (weight = 1/value over merge-chain roots, excluding the King and inversion pieces), the price table (pieces = catalog value; items Tactical 30 / Strategic 60 / Decisive 120; trinkets 100; lootboxes 50 — as tuning constants), purchase validation (money ≥ price, ≥1 action, not sold), and purchase execution (debit money + 1 action, mark SOLD).

UI: a Shop button in the bottom row (next to Stock) opens a full-screen modal — scroll container, one row per slot (icon · name · price · Buy), SOLD greys the row, Buy disabled when unaffordable/actionless/sold. Only the piece rows are purchasable in this slice (piece → stock); the other rows render with Buy disabled and a "coming soon" tooltip is NOT needed — just disabled. Shop opens only during the player's turn; browsing is free; buying never ends the turn. Shop slot contents + SOLD flags persist in the mid-run save.

## Acceptance criteria

- [ ] Stock rolls 3/4/4/8 with distinct base pieces; King and inv-* never appear; heavies appear per 1/value weighting
- [ ] Buying a piece debits its price and 1 action, marks the slot SOLD, appends the piece to stock
- [ ] Buy disabled at insufficient money, 0 actions, or SOLD; browsing costs nothing
- [ ] Shop state (slots + SOLD) survives save/load
- [ ] New headless shop suite covers stock shape, exclusions, validation, purchase effects, prices
- [ ] Click probes: Shop opens/closes, a Buy click completes a purchase
- [ ] `game/tests/run_all.sh` all green

## Blocked by

- 01 — money must exist to spend
