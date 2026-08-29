# 32 — Box & Shop UI extensions

Status: superseded (2026-08-29) — every Artefact rehomed, all three decisions answered

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why this is parked

Roughly ten artefacts are blocked not on plumbing but on **player-facing UI that does not
exist**, each implying a design decision nobody has made. Grouped here so they stop being
re-triaged one at a time:

| Artefact | Needs |
| --- | --- |
| Snowden's Rubik's Cube, Bible Gag Reel Scroll | **Box reroll** — a reroll control in the Box Pick |
| Nostradamus Mad Libs | **Box multi-pick** — take more than one option |
| Cicada Rejection Letter | **Decline option** — refuse a Box for a benefit |
| All-Seeing Eye Contact Lens | **Combined Box UI** — one panel showing several box types |
| Yalta Cocktail Napkin, Exhibit 399 | **Choice modal** — "choose one of N" mid-effect |
| FIFA Complimentary Yacht, Oak Island Wishing Well | **Gold-for-X buttons** — a spend action outside the Shop |
| Jet Fuel Vial | **Reroll system** — force a Shop restock on demand |

## The decisions needed first

1. **Does a mid-effect choice modal block input and pause the Clock?** The Buff Box sub-pick
   is the precedent and it does NOT pause — the [Box Pick](https://app.notion.com/p/36af1559c99b81a7ae8fc44029c93935)
   rule is that indecision is punished. Do these follow that, or is the Buff Box special?
2. **Is a Gold-for-X spend an Action?** Every other spend either costs an action (Shop
   purchase) or is passive. A free spend button is a new category.
3. **How does a rerolled Box interact with the Tariff on Box Pick?** Once per open, or per
   roll?

Until those are answered this is speculative UI, and the shop drawer (slice 08) is
deliberately no-scroll — new controls have to fit that constraint.

## Blocked by

- the three decisions above

## Superseded 2026-08-29

Every Artefact in the table above now has a home, and all three blocking decisions were
answered in the 2026-08-29 design sessions:

1. **Does a mid-effect choice modal block input and pause the Clock?** Answered: it blocks
   input and the **Clock keeps ticking** — indecision is punished, the Buff Box is not
   special. Built as the shared seam in slice 41.
2. **Is a Gold-for-X spend an Action?** Answered: **no** — Artefact activation costs 0
   Actions, and each Artefact's own per-Turn/per-Wave limit does the gating (issue 52).
3. **How does a rerolled Box interact with the Box Pick Tariff?** Answered: `box_cost` is
   charged **once per Box, never per roll** — built and asserted in slice 46.

Rehomed: Snowden's Rubik's Cube / Bible Gag Reel Scroll / Nostradamus Mad Libs -> slice 46
(shipped). Yalta Cocktail Napkin -> slice 44 (shipped). Cicada Rejection Letter /
All-Seeing Eye Contact Lens -> issue 49. FIFA Complimentary Yacht / Oak Island Wishing Well
/ Jet Fuel Vial -> issue 52. Exhibit 399 -> issue 54.

Nothing left here. Kept for the decision record.
