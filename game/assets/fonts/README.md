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
  default font at 20 px; Buttons 24; type variations `Header` 24, `Title` Bold 32, `Hero` Bold 48.
- The Theme's fonts are FontVariations over each Pixel Operator face, falling back to
  `OpenSans_SemiBold.woff2`, then the OS system font fallback. That woff2 is the same file Godot
  embeds as its default font (`thirdparty/fonts/` in the 4.7 source, SIL OFL 1.1, text in
  `OpenSans-LICENSE.txt`). It's bundled because a `.tres` cannot reference the engine's built-in
  font, and a fallback attached at runtime arrived too late for the first HUD build. Of the UI's
  symbols Open Sans only has `−` and `θ`; `← → ★ ⚠ ☰ …` come from the OS, as before the Theme.
- A fallback raises the line height: `Font.get_height` is the max over the chain, so a Pixel
  Operator line is as tall as Open Sans (1.36 em), not 1.0 em.
- `scripts/ui_fonts.gd` (autoload) turns antialiasing off on both faces at boot.
- The `.ttf.import` / `.woff2.import` files are not committed yet. Godot writes them on import,
  with defaults. Commit the two Pixel Operator ones from a Godot machine with Antialiasing None,
  Hinting None, Subpixel Positioning Disabled.
