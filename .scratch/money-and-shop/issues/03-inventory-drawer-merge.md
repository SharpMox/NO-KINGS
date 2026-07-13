# 03 — Inventory drawer merge

Status: done

## Parent

`.scratch/money-and-shop/PRD.md`

## What to build

Merge the bottom-row Items and Trinkets buttons into a single **Inventory** button whose drawer shows both held items and active trinkets. Frees the fourth bottom-row slot for the Shop button (issue 04). Independent of the money work.

## Acceptance criteria

- [ ] Bottom row shows one Inventory button in place of Items + Trinkets
- [ ] Inventory drawer displays held items and trinkets together; item use still works from it
- [ ] Click probes updated: Inventory opens/closes, an item is usable from it
- [ ] `game/tests/run_all.sh` all green

## Blocked by

None - can start immediately
