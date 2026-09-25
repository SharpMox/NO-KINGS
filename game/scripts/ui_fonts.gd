extends Node
## NO-256 (a): the project Theme (assets/ui_theme.tres, wired by gui/theme/custom)
## makes Pixel Operator every Control's default font. NOT gui/theme/custom_font:
## that also replaces ThemeDB.fallback_font, so the banner/feed fallback would
## point at Pixel Operator itself and ★ − ✦ would vanish.
##
## Symbols Pixel Operator lacks come from NoKingsSymbols.ttf, chained as the one
## fallback of both faces, so they render the same on every device (Max, 2026-09-25)
## instead of through the OS font fallback. Font.get_height is the max over the
## chain; NoKingsSymbols is built with Pixel Operator's exact vertical metrics
## (assets/fonts/README.md), so chaining it leaves every line 1.0 em tall.
##
## Antialiasing is not set here: the .ttf.import files import all three faces AA
## None. A runtime write from this autoload never showed up in test_theme (CI runs
## 36063501655 and 36076048114 read AA 1 after it), the import params do.
##
## _static_init, not _enter_tree: it runs when the autoload pass loads this script,
## before any scene, and does not depend on the node reaching the tree.

const SYMBOLS := preload("res://assets/fonts/NoKingsSymbols.ttf")
const FONTS := [
	preload("res://assets/fonts/PixelOperator.ttf"),
	preload("res://assets/fonts/PixelOperator-Bold.ttf"),
]


static func _static_init() -> void:
	var chain: Array[Font] = [SYMBOLS]
	for f: FontFile in FONTS:
		f.fallbacks = chain
