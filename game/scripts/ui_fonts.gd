extends Node
## NO-256 (a): the project Theme (assets/ui_theme.tres, wired by gui/theme/custom)
## makes Pixel Operator every Control's default font. NOT gui/theme/custom_font:
## that also replaces ThemeDB.fallback_font, so the banner/feed fallback would
## point at Pixel Operator itself and ★ − ✦ would vanish.
##
## No fallback font is chained: symbols Pixel Operator lacks come from the OS
## system font fallback. Chaining the engine's Open Sans made every Pixel
## Operator line 1.36 em tall (Font.get_height is the max over the chain).
##
## This autoload only turns antialiasing off, which is Pixel Operator's own look
## (banners, feed). game.gd/hud.gd set it lazily on these SAME shared resources,
## so without this the first banner or feed post would flip every Control's text
## mid-run. Redundant once the .ttf.import files are committed with AA None.

const FONTS := [
	preload("res://assets/fonts/PixelOperator.ttf"),
	preload("res://assets/fonts/PixelOperator-Bold.ttf"),
]


func _enter_tree() -> void: # not _init: an autoload gets its script via set_script, which never calls _init
	for f: FontFile in FONTS:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
