# 32 — Box & Shop UI extensions

Status: blocked — NEEDS DESIGN DECISIONS (do not start without them)

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
