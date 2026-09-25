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
## Antialiasing off is Pixel Operator's own look; the .ttf.import files already
## import all three faces AA None, this keeps it so when an import cache predates them.
##
## _static_init, not _enter_tree: it runs when the autoload pass loads this script,
## before any scene, and does not depend on the node reaching the tree
## (test_theme's AA check read the faces unchanged from an _enter_tree version).

const SYMBOLS := preload("res://assets/fonts/NoKingsSymbols.ttf")
const FONTS := [
	preload("res://assets/fonts/PixelOperator.ttf"),
	preload("res://assets/fonts/PixelOperator-Bold.ttf"),
]


static func _static_init() -> void:
	var sym: FontFile = SYMBOLS # the parser refuses a property write through a const
	sym.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	var chain: Array[Font] = [sym]
	for f: FontFile in FONTS:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.fallbacks = chain
