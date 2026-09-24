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
