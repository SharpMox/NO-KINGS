# 05 — Buy items & trinkets

Status: done

## Parent

`.scratch/money-and-shop/PRD.md`

## What to build

Enable the item and trinket rows in the shop modal. A purchased item joins the held-items strip (identical to picking it from a lootbox); a purchased trinket applies immediately and stacks like box-acquired copies. Both show up in the Inventory drawer. Standard purchase rules from issue 04 apply (money + 1 action, SOLD).

## Acceptance criteria

- [ ] Buying an item adds it to held items and it is usable
- [ ] Buying a trinket applies its passive immediately and stacks with existing copies
- [ ] Both purchases appear in the Inventory drawer
- [ ] Shop suite extended for item/trinket purchase effects
- [ ] `game/tests/run_all.sh` all green

## Blocked by

- 03 — Inventory drawer
- 04 — shop skeleton
