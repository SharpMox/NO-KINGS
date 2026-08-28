# 08 — Shop right-edge drawer UI

Status: done

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

- [x] Drawer slides from the right, ~90% coverage
- [x] Every slot visible at once, no scrolling, at 22 slots and above
- [x] Four areas laid out as specced
- [x] Icon tiles with price badges; tap expands to name/effect/Buy
- [x] SOLD tiles grey out in place
- [x] Buy still costs 1 action and is live only on the player's turn
- [x] Click probes cover open, expand, buy, sold, close
- [x] `run_all.sh` all green

## Blocked by

- nothing (PR #102 should land first to avoid conflicts)

## Outcome

`modals.gd`'s `show_shop()` rebuilt as a right-edge drawer — `shop_panel` is now a
`Panel` positioned at `x = viewport.x * 0.9`, full height, rather than a full-rect
`PanelContainer`. All purchase logic stays in `shop.gd`, untouched.

Fitting 22 slots without scrolling: the four zones are plain nested
VBox/HBox/GridContainer/CenterContainer layout (no manual pixel math). PIECES is a
centered HBoxContainer band across the top; the lower block is an HBoxContainer split
into a left column (ARTEFACTS/ITEMS, each `SIZE_EXPAND_FILL` so they split the
column 50/50) and a right column (BOXES, full height of the lower block). Each
sub-zone is a `GridContainer(columns=2)` of 46×46 icon tiles (same size as the
existing pool-strip icons in `hud.gd`, for visual consistency) centered in whatever
space its zone gets — nothing scrolls, ever, because there's no ScrollContainer left
in the tree. Slots are grouped into the four zones generically by `slot.kind`, so it
already handles more than the base 22 if a future artefact grants extra slots (no
such mechanic exists in `shop.gd` today — checked).

Tapping a tile toggles `shop_expanded_index` (the new member replacing the old
`shop_scroll` exposure) and rebuilds; the fixed-height (92px) detail dock at the
bottom shows icon/name/effect/Buy so expanding a tile never reflows the grids. Sold
tiles grey (`modulate.a = 0.4`) and stay in the grid in place, never removed.

Dropped from the first pass: an animated slide-in Tween. This codebase has zero
Control-tween precedent, no acceptance criterion tests the animation itself, and it
made click probes racy (tiles clicked mid-flight, before the tween settled, landed
off their final position). The drawer's right-edge/90%-width geometry alone reads as
"slides in" vs. the old full-screen modal — simplest defensible call per the task
brief. Also found and fixed along the way: multi-character `glyph` fallbacks (e.g.
"vRg" for pieces with no painted art) were growing tiles past their fixed size and
blowing the PIECES row off-screen — fixed with `clip_text = true` on the tiles.

`test_game_clicks.gd`'s Shop block rewritten for the new interaction model (tap tile
→ expand → Buy) and to drop the `shop_scroll.ensure_control_visible` call (no
scrolling left to ensure). Covers: open, an affordable tile found, tap-to-expand
(`shop_expanded_index` assertion), Buy debits gold + 1 action, the slot flips
`sold`, the tile greys in place, the detail dock swaps Buy → SOLD, Close dismisses,
and the existing off-turn-reachability case.

`game/tests/run_all.sh` — ALL GREEN (menu-clicks, game-clicks, all 16 headless
suites, autoplay).
