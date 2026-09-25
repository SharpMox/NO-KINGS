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
- It has no glyph for `★` (U+2605) or `−` (U+2212). Both appear in banner text; they come from
  the NoKingsSymbols fallback (below).

## Project Theme (NO-256)

- `assets/ui_theme.tres` (wired by `gui/theme/custom`) makes `PixelOperator.ttf` every Control's
  font. Ramp: `Meta` 16, body 20 (the default), `Header` 24, Buttons **Bold** 24, `Heading` Bold
  20, `Title` Bold 32, `Hero` Bold 48; button variations `CompactButton` Bold 20, `SmallButton` Bold 16, `BigButton` Bold
  32, `Pill` Regular 16 (prices on cell badges). Bold for every button, title, heading and section
  label; Regular for body, stats and small meta (Max, 2026-09-25).
- Set a role with `theme_type_variation = &"Title"` etc., not `add_theme_font_size_override`.
- Symbols Pixel Operator lacks come from `NoKingsSymbols.ttf`, chained by `scripts/ui_fonts.gd`
  as the one fallback of both faces, so they render the same on every device (Max, 2026-09-25).
  The OS font fallback stays on for anything else (player names in other scripts).
- `Font.get_height` is the max over the chain. Chaining the engine's Open Sans made every line
  1.36 em tall and broke the Header, so NoKingsSymbols carries Pixel Operator's exact vertical
  metrics instead (below): a line of symbols is as tall as a line of letters.
- Code that measures text outside a Control uses `Tuning.ui_font()`, which falls back to
  `ThemeDB.fallback_font` when the Theme failed to load (a cold import cache).
- All three faces draw AA-off (Max, 2026-09-25: pixel-sharp text everywhere). The `.ttf.import`
  files import them with Antialiasing None, Hinting None, Subpixel Positioning Disabled;
  `scripts/ui_fonts.gd` also sets AA off at script load, for an import cache that predates them.

## NoKingsSymbols (NO-256 follow-up: bundled symbol font)

- `NoKingsSymbols.ttf` (7 KB): the 46 symbols in `tests/test_theme.gd`'s `GLYPHS`, subset from
  Noto Sans Symbols 2, Noto Sans Math, Noto Sans Symbols and Noto Sans (first source that has a
  glyph supplies it) and merged into one face.
- Built by `tools/build_symbol_font.py` (fontTools), which also rescales it to Pixel Operator's
  1600 units/em and sets its hhea, OS/2 typo and OS/2 win ascent/descent to Pixel Operator's
  (1300/300, line gap 72, USE_TYPO_METRICS). FreeType then gives both fonts identical pixel
  ascent/descent at every size (checked at 16/20/24/32/48 px).
- To add a symbol: add it to `GLYPHS` in both the script and the test, re-run the script on the
  four unhinted Noto TTFs (URLs in its header), commit the new TTF.
- License: SIL Open Font License 1.1, full text and the Noto copyright lines in
  `NoKingsSymbols-LICENSE.txt`. No Reserved Font Names, so the modified font may ship under its
  own name.
- Board symbols drawn in `ThemeDB.fallback_font` (piece-glyph fallbacks, the inversion mark ⟲,
  Piece Buff badges, game.gd `_draw`) still use Open Sans plus the OS fallback; their per-glyph
  nudges were tuned against that.
