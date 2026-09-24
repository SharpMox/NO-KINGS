extends SceneTree
## NO-256: the project Theme — Pixel Operator is every Control's font, Bold for
## buttons/titles/headings (Max, ruling 7), on the size ramp 16 meta / 20 body /
## 24 buttons + Header / Bold 32 titles / Bold 48 hero; symbols Pixel Operator
## lacks come from the OS system font fallback; code that measures text outside
## a Control goes through Tuning.ui_font(), which survives a missing Theme.
## Run headless:  godot --headless --path game -s tests/test_theme.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")
const PO := preload("res://assets/fonts/PixelOperator.ttf")
const PO_BOLD := preload("res://assets/fonts/PixelOperator-Bold.ttf")
const THEME_PATH := "res://assets/ui_theme.tres"

## Every non-ASCII symbol the UI draws that Pixel Operator has no glyph for
## (NO-256 audit, fact 3; checked against the TTFs with fontTools). None of
## them is in any font the project ships: they render through the OS system
## font fallback (allow_system_fallback), as 20 of them already did before
## NO-256. The engine's Open Sans has only − and θ, and chaining it in made
## every Pixel Operator line 1.36 em tall instead of 1.0 (Font.get_height is
## the max over the chain), which broke the Header — so it is not chained.
const GLYPHS := ["←", "→", "✦", "☰", "⚠", "−", "⇄", "★", "⚑", "ⓘ", "◆", "✕",
	"θ", "⟲", "⧖", "♟", "▴", "●", "∩", "⚔", "○", "▾"]
## Non-ASCII the UI uses that Pixel Operator DOES have (audit fact 3).
const IN_PO := ["—", "·", "…", "×", "é", "à", "–", "°"]
## role -> [base type, font, size]
const RAMP := {
	"": ["Label", PO, 20], "Meta": ["Label", PO, 16], "Header": ["Label", PO, 24],
	"Heading": ["Label", PO_BOLD, 20], "Title": ["Label", PO_BOLD, 32], "Hero": ["Label", PO_BOLD, 48],
	"Button": ["Button", PO_BOLD, 24], "CompactButton": ["Button", PO_BOLD, 20], "SmallButton": ["Button", PO_BOLD, 16],
	"BigButton": ["Button", PO_BOLD, 32], "Pill": ["Button", PO, 16],
}

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _init() -> void:
	# --- Tuning.ui_font(): never null, even with no project Theme (cold import) ---
	check(Tuning.font_of(null) == ThemeDB.fallback_font and Tuning.font_of(null) != null,
		"with no project Theme, Tuning.font_of falls back to ThemeDB.fallback_font")
	check(Tuning.font_of(Theme.new()) == ThemeDB.fallback_font,
		"a Theme with no default font also falls back")
	await process_frame # autoloads (UiFonts) join the root after the first frame

	# --- wiring ---
	check(ProjectSettings.get_setting("gui/theme/custom", "") == THEME_PATH,
		"gui/theme/custom points at the project Theme")
	check(ProjectSettings.get_setting("gui/theme/custom_font", "") == "",
		"gui/theme/custom_font stays unset (it would replace ThemeDB.fallback_font)")
	var theme := ThemeDB.get_project_theme()
	check(theme != null and theme.resource_path == THEME_PATH, "the project Theme loaded")
	check(Tuning.ui_font() == PO, "Tuning.ui_font() is the Theme's Pixel Operator Regular")
	check(ThemeDB.fallback_font != PO and ThemeDB.fallback_font != PO_BOLD,
		"ThemeDB.fallback_font is still the engine default, not Pixel Operator")

	# --- the ramp, as a Control actually resolves it ---
	for role: String in RAMP:
		var spec: Array = RAMP[role]
		var c: Control = Label.new() if spec[0] == "Label" else Button.new()
		if role != "" and role != "Button":
			c.theme_type_variation = StringName(role)
		root.add_child(c)
		check(c.get_theme_font("font") == spec[1] and c.get_theme_font_size("font_size") == spec[2],
			"%s resolves %s %d" % [role if role != "" else "a plain Label",
				(spec[1] as FontFile).resource_path.get_file(), spec[2]])
		c.queue_free()

	# --- fallback: none chained, the OS fills the symbols in ---
	var ts := TextServerManager.get_primary_interface()
	for f: FontFile in [PO, PO_BOLD]:
		var n := f.resource_path.get_file()
		check(f.fallbacks.is_empty(), "%s chains no fallback font (line height stays 1.0 em)" % n)
		check(f.allow_system_fallback, "%s falls back to the OS system fonts" % n)
		# 1.0 em, give or take TextServer's rounding (CI: 21 at 20 px); Open Sans is ~27
		check(f.get_height(20) <= 21.0 and f.get_height(20) < ThemeDB.fallback_font.get_height(20) - 4.0,
			"%s's line is ~1 em (20 px -> %s, Open Sans %s)" % [n, f.get_height(20), ThemeDB.fallback_font.get_height(20)])
		var own := ""
		for ch: String in GLYPHS:
			if ts.font_has_char(f.get_rids()[0], ch.unicode_at(0)):
				own += ch
		check(own == "", "%s itself has none of the audit's symbols (got '%s')" % [n, own])
		var missing := ""
		for ch: String in IN_PO:
			if not f.has_char(ch.unicode_at(0)):
				missing += ch
		check(missing == "", "%s has its own — · … × é à – ° (missing '%s')" % [n, missing])
	# TODO(NO-256, pending Max's ruling on AA-off vs AA-on for UI text): the
	# UiFonts autoload is in the tree but the faces still read antialiasing=1
	# (CI run 36063501655). Re-instate as a check once Max rules; if AA-off
	# stands, the .ttf.import files (AA None) are the deterministic route.
	print("PENDING: Pixel Operator AA at boot = %d/%d (awaiting Max's AA ruling)"
		% [PO.antialiasing, PO_BOLD.antialiasing])

	# --- the two measure sites use the theme font, not ThemeDB.fallback_font ---
	GameScript.reset_boot_defaults()
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 5, "seed": 1}
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.text_font() == PO, "board popups (game.gd text_font) draw in the theme's font")
	game._open_shop()
	await process_frame
	var bar: ProgressBar = game.modals.shop_lane_b_bar
	check(bar != null, "precondition: the Shop built its Lane B bar")
	if bar:
		var want: float = PO.get_height(16) + 4
		check(is_equal_approx(bar.custom_minimum_size.y, want),
			"the Lane B bar is sized off the theme font (%s, want %s; Open Sans would give %s)"
				% [bar.custom_minimum_size.y, want, ThemeDB.fallback_font.get_height(16) + 4])

	game.queue_free()
	await process_frame
	print("---")
	if fails == 0:
		print("ALL THEME CHECKS OK")
	quit(1 if fails > 0 else 0)
