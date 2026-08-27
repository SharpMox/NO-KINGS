# 02 — Notion reconciliation (doc only)

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

No code. The 2026-08-27 sweep found pages that newer pages have silently superseded, so
the GDD now contradicts itself. Fix the doc so the next audit compares against one truth.

1. **`Score`** — delete "placing a piece costs score" and "tariffs reduce score". The
   `Shop` and `Reward Economy` pages (2026-08-27) reversed this: Score never falls, every
   cost debits Gold. Point the costs section at Gold.
2. **`Captured Stock`** and **`Game Flow — Player Turn`** — both still describe 3-piece
   merges (3 same → 1 of that; 3 different → 1 of the lowest value). Superseded by
   divergence #4 (merges are exactly 2 pieces). Re-text to the pair model.
3. **`Board`** (6×8) and **`Overview`** (6×8, "any enemy reaching the bottom row ends the
   run") — superseded by divergences #1 and #3. Either update the numbers or add the
   pointer to the divergence page; do not leave a bare contradiction.
4. **`Fable Prototype Test`** — two of its own entries are stale:
   - #12 says "Blitz grants +2 actions (net +1)". Blitz is now a targeted re-move that
     refunds its own action.
   - #13 says "every placement costs score". Placements charge `PLACEMENT_COST` in Gold.
5. **`Pieces` DB `Letter` column** — still original-name initials (`AD` Alibaba, `SG`
   Sergeant, `Ki` Kirin, `GZ` Godzilla) while every other surface uses the fantasy names.
   Either resync to the game's glyphs or record why the column keeps source initials.
6. **Ask the two open questions** from the PRD: the capture bounce-back rule, and whether
   Stock capacity is genuinely wanted.

## Acceptance criteria

- [ ] No page states a rule another page reverses
- [ ] The divergence list matches the code it describes
- [ ] `Letter` resolved either way, with the reason recorded
- [ ] Both open questions answered or explicitly parked on the page

## Blocked by

- nothing
