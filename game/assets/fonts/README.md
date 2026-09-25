# Fonts

## Pixel Operator (NO-219: wave/turn/event banners)

- `PixelOperator-Bold.ttf` draws the banners. `PixelOperator.ttf` (regular, 24 px — Max ruled
  32 too big) draws the kill feed (NO-239, hud.gd).
- Author: Jayvee Enaguas (HarvettFox96), version 2018.10.04-1.
- Source: https://www.dafont.com/pixel-operator.font (archive: https://dl.dafont.com/dl/?f=pixel_operator)
- License: CC0 1.0 (public domain dedication). The full text is in `PixelOperator-LICENSE.txt`,
  shipped in the same archive. The font's own name table says: "Released by Jayvee Enaguas
  (HarvettFox96), licensed under a Creative Commons Zero (CC0) 1.0
  <https://creativecommons.org/licenses/zero/1.0/>. (c) 2009-2018."
- Design grid: 16 px for both weights (1600 units/em, 100 units per pixel; odd multiples occur,
  so neither 24 nor 32 lands on a whole font pixel). This doesn't matter in practice: the game
  window is stretched at a non-integer scale (~1.9x) on device, so no integer-grid size stays
  crisp there anyway.
- It has no glyph for `★` (U+2605) or `−` (U+2212). Both appear in banner text, so the banner
  font lists the default theme font as a fallback (game.gd).

## Project Theme (NO-256)

- `assets/ui_theme.tres` (wired by `gui/theme/custom`) makes `PixelOperator.ttf` every Control's
  font. Ramp: `Meta` 16, body 20 (the default), `Header` 24, Buttons **Bold** 24, `Heading` Bold
  20, `Title` Bold 32, `Hero` Bold 48; button variations `CompactButton` Bold 20, `SmallButton` Bold 16, `BigButton` Bold
  32, `Pill` Regular 16 (prices on cell badges). Bold for every button, title, heading and section
  label; Regular for body, stats and small meta (Max, 2026-09-25).
- Set a role with `theme_type_variation = &"Title"` etc., not `add_theme_font_size_override`.
- No fallback font is chained. Symbols Pixel Operator lacks (`← → ★ − ⚠ ☰ ⇄ ⚑ …`, the list is in
  `tests/test_theme.gd`) come from the OS system font fallback, as most already did. Chaining the
  engine's Open Sans would make every line 1.36 em tall instead of 1.0 em (`Font.get_height` is
  the max over the chain). A line holding such a symbol can still be taller than the font: size
  boxes from a shaped sample (`get_string_size(...).y`), as the Header's Turn/Wave line does.
- Code that measures text outside a Control uses `Tuning.ui_font()`, which falls back to
  `ThemeDB.fallback_font` when the Theme failed to load (a cold import cache).
- `scripts/ui_fonts.gd` (autoload) turns antialiasing off on both faces at boot.
- The `.ttf.import` files are not committed yet. Godot writes them on import, with defaults.
  Commit them from a Godot machine with Antialiasing None, Hinting None, Subpixel Positioning
  Disabled.
