extends SceneTree
## NO-256: the project Theme — Pixel Operator is every Control's font, Bold for
## buttons/titles/headings (Max, ruling 7), on the size ramp 16 meta / 20 body /
## 24 buttons + Header / Bold 32 titles / Bold 48 hero; symbols Pixel Operator
## lacks come from the bundled NoKingsSymbols fallback, which keeps every line
## 1.0 em; all three faces draw AA-off; code that measures text outside a
## Control goes through Tuning.ui_font(), which survives a missing Theme.
## Run headless:  godot --headless --path game -s tests/test_theme.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")
const PO := preload("res://assets/fonts/PixelOperator.ttf")
const PO_BOLD := preload("res://assets/fonts/PixelOperator-Bold.ttf")
const SYMBOLS := preload("res://assets/fonts/NoKingsSymbols.ttf")
const THEME_PATH := "res://assets/ui_theme.tres"

## Every non-ASCII symbol the UI draws that Pixel Operator has no glyph for:
## the NO-256 audit's list, then the Piece Buff glyphs, menu/modal markers,
## piece-glyph fallbacks and ½ (a Conspiracy name) found by grepping the
## scripts and data. NoKingsSymbols.ttf (tools/build_symbol_font.py, same
## list) supplies them all. Chaining the engine's Open Sans instead made every
## Pixel Operator line 1.36 em tall (Font.get_height is the max over the
## chain); NoKingsSymbols has Pixel Operator's exact ascent and descent.
const GLYPHS := ["←", "→", "✦", "☰", "⚠", "−", "⇄", "★", "⚑", "ⓘ", "◆", "✕",
	"θ", "⟲", "⧖", "♟", "▴", "●", "∩", "⚔", "○", "▾",
	"‼", "↩", "↯", "⇢", "≋", "⊘", "▣", "▸", "◈", "◎", "✚", "✳", "✴", "✹", "➜", "➤",
	"⧗", "⨯", "♚", "♛", "♜", "♝", "♞", "½"]
## Non-ASCII the UI uses that Pixel Operator DOES have (audit fact 3).
const IN_PO := ["—", "·", "…", "×", "é", "à", "–", "°", "›", "ë"]
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

	# --- fallback: NoKingsSymbols chained, and the line stays 1.0 em ---
	var ts := TextServerManager.get_primary_interface()
	var sym_rid: RID = SYMBOLS.get_rids()[0]
	var sym_missing := ""
	for ch: String in GLYPHS:
		if not ts.font_has_char(sym_rid, ch.unicode_at(0)):
			sym_missing += ch
	check(sym_missing == "", "NoKingsSymbols has every listed glyph (missing '%s')" % sym_missing)
	check(SYMBOLS.antialiasing == TextServer.FONT_ANTIALIASING_NONE,
		"NoKingsSymbols is AA-off (antialiasing = %d)" % SYMBOLS.antialiasing)
	for f: FontFile in [PO, PO_BOLD]:
		var n := f.resource_path.get_file()
		var rid: RID = f.get_rids()[0] # the face itself, not the chain
		check(f.fallbacks.size() == 1 and f.fallbacks[0] == SYMBOLS,
			"%s chains NoKingsSymbols as its one fallback (got %s)" % [n, f.fallbacks])
		check(f.allow_system_fallback, "%s still falls back to the OS for anything else (names)" % n)
		check(f.antialiasing == TextServer.FONT_ANTIALIASING_NONE,
			"%s is AA-off from boot (antialiasing = %d)" % [n, f.antialiasing])
		# 1.0 em, give or take TextServer's rounding (CI: 21 at 20 px); Open Sans is ~27
		var own_h := ts.font_get_ascent(rid, 20) + ts.font_get_descent(rid, 20)
		check(f.get_height(20) <= 21.0 and is_equal_approx(f.get_height(20), own_h),
			"%s's line stays ~1 em with the fallback chained (20 px -> %s, face alone %s, Open Sans %s)"
				% [n, f.get_height(20), own_h, ThemeDB.fallback_font.get_height(20)])
		for size: int in [16, 20, 24, 32, 48]:
			var plain := f.get_string_size("Wave", HORIZONTAL_ALIGNMENT_LEFT, -1, size).y
			var sym := f.get_string_size("Wave " + "".join(PackedStringArray(GLYPHS)), HORIZONTAL_ALIGNMENT_LEFT, -1, size).y
			check(is_equal_approx(sym, plain),
				"%s at %d px: a line of symbols is as tall as plain text (%s vs %s)" % [n, size, sym, plain])
		var own := ""
		var uncovered := ""
		for ch: String in GLYPHS:
			if ts.font_has_char(rid, ch.unicode_at(0)):
				own += ch
			if not f.has_char(ch.unicode_at(0)): # has_char walks the chain, not the OS
				uncovered += ch
		check(own == "", "%s itself has none of the listed symbols (got '%s')" % [n, own])
		check(uncovered == "", "every listed symbol is in %s's chain (uncovered '%s')" % [n, uncovered])
		var missing := ""
		for ch: String in IN_PO:
			if not ts.font_has_char(rid, ch.unicode_at(0)):
				missing += ch
		check(missing == "", "%s has its own %s (missing '%s')" % [n, " ".join(PackedStringArray(IN_PO)), missing])

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
