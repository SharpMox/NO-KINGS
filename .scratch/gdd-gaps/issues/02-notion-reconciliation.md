# 02 — Notion reconciliation (doc only)

Status: done

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

- [x] No page states a rule another page reverses
- [x] The divergence list matches the code it describes
- [x] `Letter` resolved either way, with the reason recorded
- [x] Both open questions answered or explicitly parked on the page

## Outcome (2026-08-27)

Eight Notion pages edited plus 32 database rows. Every edit carries a dated
"Reconciled" note so the change is auditable from the page itself.

| Page | Change |
| --- | --- |
| `Score` | Costs section rewritten: everything debits Gold, Score only goes up |
| `Captured Stock` | 3-piece merges → the 2-piece pair model; placement cost → Gold |
| `Game Flow — Player Turn` | same two corrections |
| `Board` | 6×8 → 8×12 |
| `Overview` | 6×8 → 8×12; back-row breach needs the *whole* row |
| `Game Over & Winner Screens` | back-row breach needs the whole row |
| `Fable Prototype Test` | #12 Blitz updated; #13 struck — no longer a divergence |
| `Pieces & Movement` | bounce-back rule kept and defined (below) |
| `Stock` | capacity claim deleted (below) |
| `Pieces` DB | 32 `Letter` rows resynced to the game glyphs |

**Decisions taken (user, 2026-08-27):**

1. **`Letter` resynced to the game.** The column now matches `pieces.json` glyphs
   exactly — `Du` Duchess, `Rg` Ranger, `Lm` Long Ma, `Lv` Leviathan, `Kr` Kraken and so
   on; the 6 standard pieces keep their unicode chess glyphs and the King gained `♚`
   (it was empty). Verified all 39 match the game and are unique.
2. **Bounce-back is a real rule, not dead text.** It was written anticipating a general
   capture-repulsion mechanic. It now reads as effect-driven — an ordinary capture always
   succeeds; an effect on the defender can stop it, and then the attacker returns to its
   starting tile. **Shield** is the canonical carrier and **Reflect** the aggressive
   variant, so the rule first ships with slice 03, not before.
3. **Stock is uncapped.** The capacity line was aimed at a player hoarding unlimited
   Pawns; merging already applies that pressure. Deleted, with the note that Pawn
   hoarding should be capped specifically if it ever becomes a problem — not via a
   revived general capacity system.

## Blocked by

- nothing
