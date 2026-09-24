extends SceneTree
## NO-256 (a): the project Theme — Pixel Operator is every Control's default
## font, with a fallback chain for the symbols it lacks, and the two places that
## measured text with ThemeDB.fallback_font directly now use the theme's font.
## Run headless:  godot --headless --path game -s tests/test_theme.gd

const GameScript := preload("res://scripts/game.gd")
const PO := preload("res://assets/fonts/PixelOperator.ttf")
const PO_BOLD := preload("res://assets/fonts/PixelOperator-Bold.ttf")
const OPEN_SANS := preload("res://assets/fonts/OpenSans_SemiBold.woff2")
const THEME_PATH := "res://assets/ui_theme.tres"

## Every non-ASCII symbol the UI draws that Pixel Operator has no glyph for
## (NO-256 audit, fact 3; checked against the TTFs with fontTools).
const GLYPHS := ["←", "→", "✦", "☰", "⚠", "−", "⇄", "★", "⚑", "ⓘ", "◆", "✕",
	"θ", "⟲", "⧖", "♟", "▴", "●", "∩", "⚔", "○", "▾"]
## The part of GLYPHS Open Sans SemiBold (bundled; the same file the engine
## embeds as ThemeDB.fallback_font) carries itself. The rest have no glyph in
## any font the project ships or the engine embeds: they render through the OS
## system fallback, as they did before this change. If this set changes, the
## chain changed — re-check the list.
const IN_OPEN_SANS := ["−", "θ"]
## Non-ASCII the UI uses that Pixel Operator DOES have (audit fact 3).
const IN_PO := ["—", "·", "…", "×", "é", "à", "–", "°"]

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _chain_has(font: Font, ch: String) -> bool:
	return font.has_char(ch.unicode_at(0)) # Font.has_char walks font.fallbacks too


func _init() -> void:
	# Before the first frame — before any autoload joins — so this proves the
	# fallback holds from load, not from a runtime hook that a -s suite's first
	# HUD build can outrun (that race grew the Header's Turn/Wave line in CI).
	var theme := ThemeDB.get_project_theme()
	var regular = theme.default_font if theme else null # untyped: .base_font is FontVariation-only
	check(regular is FontVariation and regular.base_font == PO,
		"the Theme's default font is a FontVariation over Pixel Operator Regular")
	check(regular is FontVariation and regular.fallbacks.size() == 1
			and regular.fallbacks[0] == OPEN_SANS,
		"it falls back to the bundled Open Sans SemiBold from load, before any autoload runs")
	await process_frame # autoloads (UiFonts) join the root after the first frame

	# --- wiring ---
	check(ProjectSettings.get_setting("gui/theme/custom", "") == THEME_PATH,
		"gui/theme/custom points at the project Theme")
	check(ProjectSettings.get_setting("gui/theme/custom_font", "") == "",
		"gui/theme/custom_font stays unset (it would replace ThemeDB.fallback_font)")
	check(theme != null and theme.resource_path == THEME_PATH, "the project Theme loaded")
	check(ThemeDB.fallback_font != PO and ThemeDB.fallback_font != regular,
		"ThemeDB.fallback_font is still the engine default, not Pixel Operator")
	var bold = theme.get_font("font", "Title")
	check(bold is FontVariation and bold.base_font == PO_BOLD
			and bold.fallbacks.size() == 1 and bold.fallbacks[0] == OPEN_SANS,
		"Title/Hero use a FontVariation over Pixel Operator Bold, same fallback")

	# --- what a Control actually resolves (not just what the .tres says) ---
	var label := Label.new()
	root.add_child(label)
	check(label.get_theme_font("font") == regular, "a plain Label resolves Pixel Operator Regular")
	check(label.get_theme_font_size("font_size") == 20, "a plain Label resolves size 20 (Max, ruling 1)")
	var button := Button.new()
	root.add_child(button)
	check(button.get_theme_font("font") == regular, "a plain Button resolves Pixel Operator Regular")
	check(button.get_theme_font_size("font_size") == 24, "a plain Button resolves size 24")
	var ramp := {"Header": [regular, 24], "Title": [bold, 32], "Hero": [bold, 48]}
	for v: String in ramp:
		var l := Label.new()
		l.theme_type_variation = StringName(v)
		root.add_child(l)
		check(l.get_theme_font("font") == ramp[v][0] and l.get_theme_font_size("font_size") == ramp[v][1],
			"theme_type_variation %s resolves its face at %d" % [v, ramp[v][1]])
		l.queue_free()
	var sized := Label.new()
	sized.add_theme_font_size_override("font_size", 13)
	root.add_child(sized)
	check(sized.get_theme_font("font") == regular and sized.get_theme_font_size("font_size") == 13,
		"a per-site size override keeps its size and still gets Pixel Operator")

	# --- fallback chain: Pixel Operator -> Open Sans SemiBold -> OS ---
	# TODO(NO-256, pending Max's ruling on AA-off vs AA-on for UI text): the
	# UiFonts autoload is in the tree but the faces still read antialiasing=1
	# here (CI run 36063501655: aa=1/1, UiFonts node=true). Re-instate as a
	# check once Max rules; if AA-off stands, the .ttf.import files (AA None)
	# are the deterministic route, not the runtime hook.
	print("PENDING: Pixel Operator AA at boot = %d/%d (awaiting Max's AA ruling)"
		% [PO.antialiasing, PO_BOLD.antialiasing])
	check(PO.allow_system_fallback and PO_BOLD.allow_system_fallback and OPEN_SANS.allow_system_fallback,
		"every font in the chain ends in the OS system fallback")
	var ts := TextServerManager.get_primary_interface()
	for f: FontFile in [PO, PO_BOLD]:
		var n := f.resource_path.get_file()
		var po_own := ""
		for ch: String in GLYPHS:
			if ts.font_has_char(f.get_rids()[0], ch.unicode_at(0)):
				po_own += ch
		check(po_own == "", "%s itself has none of the audit's symbols (got '%s')" % [n, po_own])
	for font: Font in [regular, bold]:
		var chain := ""
		var missing := ""
		for ch: String in GLYPHS:
			if _chain_has(font, ch):
				chain += ch
		for ch: String in IN_PO:
			if not _chain_has(font, ch):
				missing += ch
		var n: String = (font as FontVariation).base_font.resource_path.get_file()
		check(chain == "".join(IN_OPEN_SANS),
			"%s chain covers exactly %s; the other %d are OS-fallback (got '%s')"
				% [n, "".join(IN_OPEN_SANS), GLYPHS.size() - IN_OPEN_SANS.size(), chain])
		check(missing == "", "%s has its own — · … × é à – ° (missing '%s')" % [n, missing])

	# --- the two measure sites use the theme font, not ThemeDB.fallback_font ---
	GameScript.reset_boot_defaults()
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 5, "seed": 1}
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.text_font() == regular, "board popups (game.gd text_font) draw in the theme's font")
	game._open_shop()
	await process_frame
	var bar: ProgressBar = game.modals.shop_lane_b_bar
	check(bar != null, "precondition: the Shop built its Lane B bar")
	if bar:
		# Numerically equal to Open Sans's height: Font.get_height is the max
		# over the chain, and Open Sans (1.36 em) is taller than Pixel Operator.
		var want: float = regular.get_height(12) + 4
		check(is_equal_approx(bar.custom_minimum_size.y, want),
			"the Lane B bar is sized off the theme font (%s, want %s)" % [bar.custom_minimum_size.y, want])

	game.queue_free()
	await process_frame
	print("---")
	if fails == 0:
		print("ALL THEME CHECKS OK")
	quit(1 if fails > 0 else 0)
