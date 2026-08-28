# 10 — Arrow Planning

Status: done

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

[Arrow Planning](https://app.notion.com/p/367f1559c99b81d2ab98f65c293d72d9) is a
**decorative-only** drawing mode: the player draws arrows on the board to plan their moves
and predict the enemy's. Arrows have **no effect on gameplay**. A dedicated button toggles
the mode.

Nothing exists. It is a small, self-contained slice with no dependencies — the board
already has a custom `_draw` and an animation overlay to hang arrows off.

Decisions the page leaves open, to settle while building: do arrows survive the turn, the
wave, a save? Simplest useful answer is that they clear on turn end and are never saved —
they are a scratchpad, not run state.

## Acceptance criteria

- [ ] A button toggles arrow mode; the board stops selecting pieces while it is on
- [ ] Drag draws an arrow; arrows render over the board
- [ ] A way to clear one and clear all
- [ ] Arrows never affect legality, targeting or the AI
- [ ] Lifetime decided and recorded on the Notion page
- [ ] Click probe covers toggle, draw, clear
- [ ] `run_all.sh` all green

## Blocked by

- nothing

## Outcome

Shipped as-scoped, decorative-only (`game/scripts/game.gd`, `game/scripts/hud.gd`,
`game/tests/test_game_clicks.gd`).

- **Toggle**: a top-bar "Arrows" button (`hud.arrow_button`) flips `game.arrow_mode`.
  Turning it on drops the current selection/armed placement so the two modes never
  overlap; while it's on, `_unhandled_input` routes board drags to `_arrow_input`
  instead of the normal select/drag/place path (item targeting still wins if an item
  is active, so Arrows can't steal its clicks).
- **Draw**: press-drag-release between two different tiles appends `{from, to}` to
  `arrows`; redrawing the exact same pair removes it again (clear-one, chess.com-style
  toggle — no extra button needed for that case).
- **Clear all**: a floating "Clear" button (same slot pattern as the item multi-confirm
  button) appears only while Arrows is on and empties `arrows`. It doesn't live in the
  top bar — the 480px-wide portrait top bar was already full; a second top-bar button
  pushed off-screen past x=480 and silently ate clicks (caught by the click probe, see
  below), which is why Clear floats above the bottom button row instead.
- **Rendering**: arrows are drawn last in `_draw()`, on top of pieces/anims, in a new
  amber `COL_ARROW` that's deliberately outside the blue(player)/red(enemy) palette.
- **Lifetime — decided**: arrows are a scratchpad, not run state. `arrows.clear()` runs
  at the top of `_on_pass()`, so every path that ends a turn (manual PASS, checkmate
  auto-pass, last-enemy auto-pass) wipes them. They are never written to save data and
  don't survive a wave or a save/load. `arrow_mode` itself (the toggle) is *not* reset
  at turn end — only the drawn arrows are.
- **Invariant**: arrows never touch `board`, `selected`, `legal_dests`, or any AI/rules
  path — confirmed by a click-probe check that a full drag-draw leaves the board and
  selection untouched.
- Click probe (`test_game_clicks.gd`) covers: toggle on/off, board taps not selecting
  while on, drag-draw, redraw-clears-one, Clear-all, mode-off restores normal selection,
  and the turn-end auto-clear.
- No new scenario added to `game/data/scenarios.gd` — arrows never reach rules/AI state,
  so there's nothing for the autoplay bot or scenario sweep to exercise.
