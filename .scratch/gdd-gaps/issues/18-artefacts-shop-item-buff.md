# 18 — Artefacts: Shop, Item & Buff

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

Three tags that hang off systems built in earlier slices: **Shop (13)**, **Item (12)**,
**Buff (19)**.

- **Shop** — price modifiers, extra slots, forced rerolls. The GDD Shop page already names
  several by name (Chocolate Key Cake +2 Item slots, Alleged Weather Balloon +1 Item slot,
  Sub-Antarctic Visa +1 hidden Artefact slot, Denazification Visa −50% on Tactical Items,
  Hollow Moon Cross-Section −25% on Artefacts, Shrinkflation Cereal Box +50% on
  everything, Skull and Bones Coffin +5% while rich, Jet Fuel Vial forces a reroll).
  ⚠️ This is the slice that finally needs the **"base + modifiers" slot pass** that slice
  02 of the shop work deliberately deferred "until an Artefact needs it". One does now.
- **Item** — held-item capacity, extra rolls, tier upgrades.
- **Buff** — **unblocked by slice 04**: these grant Piece Buffs directly. *Crop Circle
  Plank* gives 2 random allied pieces +1 buff on a 5-Wave milestone; *MK-Ultra Sugar Cube*
  buffs the piece you deploy. `BuffLogic.add` is the whole API they need.

Note the GDD's own vocabulary ruling: **"Shop visit" is not a term.** Six artefact texts
used it before the Shop page existed and were re-texted onto **per restock**. Anything
still saying "visit" is stale text, not a mechanic.

## Acceptance criteria

- [ ] Every no-prerequisite Shop/Item/Buff artefact implemented and flagged
- [ ] Shop slot counts become base + modifiers; the stock still fits without scrolling
- [ ] Price modifiers compose per the slice 15 stacking rule
- [ ] Buff-granting artefacts go through `BuffLogic.add`, not a parallel path
- [ ] No implemented artefact text says "Shop visit"
- [ ] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine
- 04 — Piece Buffs (done) for the Buff tag
- 08 — Shop drawer UI, if the slot changes need the new layout
