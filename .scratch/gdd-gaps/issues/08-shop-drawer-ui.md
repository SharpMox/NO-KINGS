# 08 — Shop right-edge drawer UI

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

The **last** of the seven divergences on the GDD
[Shop](https://app.notion.com/p/3c9f1559c99b8153b127ea8c079c02cd) page — the other six
landed on `feat/shop-gdd-sync`. All of it is UI.

- A drawer that **slides in from the right edge**, covering ~90% of the screen up to full.
- **It never scrolls.** Every slot in the current stock is visible at once, including
  extra slots granted by artefacts. (The page explicitly killed the earlier
  bottom-panel-at-40% sketch for exactly this reason.)
- Four areas: **PIECES** as a full-width band across the top; **ARTEFACTS** lower-left
  upper half; **ITEMS** lower-left lower half; **BOXES** lower-right, full height.
- Slots are **icon tiles with a price badge**, not text rows. Tapping expands a tile to
  name, effect text and Buy. A sold tile greys and stays in place.

Today it is a full-screen scrolling modal with text rows. The purchase logic, prices,
weighting, sell-out and 1-action cost all stay exactly as they are — this is a reskin of
the surface, not of the shop.

Portrait is 480×800, so the no-scroll constraint is the hard part: 22 base slots plus
artefact-granted extras must fit without shrinking tiles below readable.

## Acceptance criteria

- [ ] Drawer slides from the right, ~90% coverage
- [ ] Every slot visible at once, no scrolling, at 22 slots and above
- [ ] Four areas laid out as specced
- [ ] Icon tiles with price badges; tap expands to name/effect/Buy
- [ ] SOLD tiles grey out in place
- [ ] Buy still costs 1 action and is live only on the player's turn
- [ ] Click probes cover open, expand, buy, sold, close
- [ ] `run_all.sh` all green

## Blocked by

- nothing (PR #102 should land first to avoid conflicts)
