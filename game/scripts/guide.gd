## Shared "Guide" panel — one builder so the Main Menu and the in-game menu
## (05-menus-and-settings) show the exact same rules text instead of two
## copies drifting apart.
##
## NO-189: previously a single rules-text page; now a hub of 7 entries
## (Rules + six catalog references: Pieces, Promotions, Fusions, Artefacts,
## Items, Indicators) — one navigation level deeper, matching the "Back
## lands one level up" shape NO-159's tier picker and the TEST list already
## use. The outer node this returns still means exactly what it always did
## ("Guide is open"): callers only ever toggle its `.visible`, never its
## internal state — a sub-page's own Back always returns to the hub before
## the hub's Back reaches `on_back`, so whenever a caller re-shows this
## panel the hub is already what's showing.
##
## Every catalog page reads its content from the SAME data the game itself
## runs on (game/data/pieces.json via Rules.load_pieces(), fusions.json,
## items.gd, artefacts.json via Items.ARTEFACT_EFFECTS, and the board's own
## COL_* palette) — never a hand-copied restatement, so a catalog edit
## reaches this page with no separate update (CLAUDE.md: "read from the
## data, never copy it").
##
## Pieces carries no description text: game/data/pieces.json has no prose
## field, and modals.gd's own live "piece" preview shows a name + movement
## diagram with no description line either (show_preview, kind == "piece")
## — this page follows the same convention, not a gap.
##
## Fusions shows one flat list, not additive/synergistic sections:
## game/data/fusions.json (built by tools/export-game-pieces.mjs) already
## merges both source arrays into one "lhs+rhs" -> result map with the
## distinction gone, and merge_logic.gd resolves every fusion through that
## same map — recreating a split the game's own data and logic no longer
## draw would be inventing structure, not reading it.
##
## The menu has no live Game node (same constraint NO-190 documents for its
## tier icons), so `board` carries whatever a caller DOES have — menu.gd
## passes its GameScript preload (a script, read as a static namespace),
## hud.gd passes its live `g` (a Game instance) — and every lookup below
## (`board.load_piece_tex`, `board.COL_MOVE`, ...) resolves the same way off
## either, since GDScript looks up members on both alike. `board` carries no
## type hint on purpose: game.gd already preloads hud.gd, which preloads
## this file, so a `const GameScript := preload("res://scripts/game.gd")`
## HERE would close that into a cycle (hud.gd's own settings.gd call below
## documents the identical trap and works around it with `load()` instead of
## `preload()` for the same reason). Icons load through the same static
## asset paths game.gd's own _ready() uses (res://assets/pieces/<id>-<side>.png,
## res://assets/items/<key>.svg, res://assets/artefacts/<key>.png) rather
## than a live textures/item_icons/artefact_icons dictionary lookup — Godot's
## ResourceLoader caches by path, so this costs nothing extra whether or not
## a live Game has already loaded the same file.

const GuideText := preload("res://data/guide_text.gd")
const Rules := preload("res://scripts/rules.gd")
const Items := preload("res://data/items.gd")
const Tuning := preload("res://scripts/tuning.gd")
const PieceDiagram := preload("res://scripts/piece_diagram.gd")


## Builds a full-rect, initially-hidden Guide panel as a child of `layer` and
## returns it so the caller toggles `.visible`. `on_back` runs when the hub's
## own Back button is pressed (hides the panel itself). `board` supplies the
## piece-texture loader and board palette — see the header comment above.
static func build(layer: Node, on_back: Callable, board) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	layer.add_child(root)

	# the hub — built FIRST so every sub-page's own Back button can close
	# over it (a lambda captures a local by value at creation time, so the
	# sub-pages below must be built after hub_scroll already holds its real
	# value, not before).
	var hub_scroll := ScrollContainer.new()
	hub_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER # NO-136
	hub_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hub_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	hub_scroll.offset_left = 30
	hub_scroll.offset_top = 30
	hub_scroll.offset_right = -30
	hub_scroll.offset_bottom = -30
	root.add_child(hub_scroll)
	var hub_box := VBoxContainer.new()
	hub_box.add_theme_constant_override("separation", 10)
	hub_scroll.add_child(hub_box)
	var hub_head := Label.new()
	hub_head.text = "Guide"
	hub_head.add_theme_font_size_override("font_size", 28)
	hub_box.add_child(hub_head)

	var pages := [
		["Rules", func(box: VBoxContainer) -> void: _fill_rules(box)],
		["Pieces", func(box: VBoxContainer) -> void: _fill_pieces(box, board)],
		["Promotions", func(box: VBoxContainer) -> void: _fill_promotions(box, board)],
		["Fusions", func(box: VBoxContainer) -> void: _fill_fusions(box)],
		["Artefacts", func(box: VBoxContainer) -> void: _fill_artefacts(box)],
		["Items", func(box: VBoxContainer) -> void: _fill_items(box)],
		["Indicators", func(box: VBoxContainer) -> void: _fill_indicators(box, board)],
	]
	for entry in pages:
		var title: String = entry[0]
		var fill: Callable = entry[1]
		var page := _page(root, hub_scroll, title, fill)
		var btn := Button.new()
		btn.text = title
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(func() -> void:
			hub_scroll.visible = false
			page.visible = true)
		hub_box.add_child(btn)

	var hub_back := Button.new()
	hub_back.text = "← Back"
	hub_back.add_theme_font_size_override("font_size", 20)
	hub_back.pressed.connect(func() -> void:
		root.visible = false
		on_back.call())
	hub_box.add_child(hub_back)

	return root


## One sub-page's shell: header + whatever `fill_rows` appends + a Back
## button that returns to `hub_scroll`. Every catalog page below is just a
## `fill_rows` callable plugged into this.
static func _page(root: Control, hub_scroll: Control, title: String, fill_rows: Callable) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 30
	scroll.offset_top = 30
	scroll.offset_right = -30
	scroll.offset_bottom = -30
	scroll.visible = false
	root.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 24)
	box.add_child(head)
	fill_rows.call(box)
	var back := Button.new()
	back.text = "← Back"
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func() -> void:
		scroll.visible = false
		hub_scroll.visible = true)
	box.add_child(back)
	return scroll


static func _fill_rules(box: VBoxContainer) -> void:
	var body := Label.new()
	body.text = GuideText.TEXT
	body.add_theme_font_size_override("font_size", 15)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(body)


## NO-189: name + a compact movement diagram per row — piece_diagram.gd is
## the SAME renderer + move model (rules.gd's leap/ride/bent) the live board
## itself reads, so this can never disagree with what a piece actually does
## in a run. A diagram at this size already reads as "one line", so there is
## no separate list-then-modal step. Player-side art (the default owner) —
## unlike NO-190's difficulty-tier icons, Max ruled those red/enemy
## specifically; no such ruling exists for this roster reference.
## Excludes "king": tools/export-game-pieces.mjs's own comment calls it a
## boss ENTITY, not a roster piece (no Family, no fusions, never
## obtainable) — the reference site's codex lists 38, not 39, for the
## same reason.
static func _fill_pieces(box: VBoxContainer, board) -> void:
	var defs := Rules.load_pieces()
	var cells := 9 # matches modals.gd's own show_preview diagram (covers the longest leap)
	var cell := 8
	for id in defs:
		if id == "king":
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var name_l := Label.new()
		name_l.text = defs[id].name
		name_l.add_theme_font_size_override("font_size", 15)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_l)
		var dia := Control.new()
		dia.custom_minimum_size = Vector2(cells, cells) * cell
		var tex: Texture2D = board.load_piece_tex(id)
		dia.draw.connect(func() -> void: PieceDiagram.draw(dia, defs, id, cells, cell, tex))
		row.add_child(dia)


## NO-189: the 8 Families, derived from pieces.json's own `next` chain
## (tools/export-game-pieces.mjs) rather than a second copy of
## data/promotions.js — a base with a successor starts a Family; a base
## with none is just a piece with no promotion at all (22 of the 38, e.g.
## Berolina). Row title = the base piece's own name, exactly matching
## promotions.js's own `title` field (also just the base's name, e.g.
## "Pawn") — nothing here is invented copy.
static func _fill_promotions(box: VBoxContainer, board) -> void:
	var defs := Rules.load_pieces()
	var is_target := {}
	for id in defs:
		var nxt = defs[id].get("next")
		if nxt:
			is_target[nxt] = true
	for id in defs:
		if id == "king" or is_target.has(id) or not defs[id].get("next"):
			continue
		var chain := [id]
		var cur = id
		while defs[cur].get("next"):
			cur = defs[cur].next
			chain.append(cur)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var title_l := Label.new()
		title_l.text = defs[id].name
		title_l.add_theme_font_size_override("font_size", 15)
		title_l.custom_minimum_size.x = 100
		row.add_child(title_l)
		for i in chain.size():
			if i > 0:
				var arrow := Label.new()
				arrow.text = "→"
				row.add_child(arrow)
			var tr := TextureRect.new()
			tr.texture = board.load_piece_tex(chain[i])
			tr.custom_minimum_size = Vector2(32, 32)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			row.add_child(tr)


## NO-189: one line per fusion, "A + B → Result" — see the header comment
## for why additive/synergistic aren't split here.
static func _fill_fusions(box: VBoxContainer) -> void:
	var defs := Rules.load_pieces()
	var fusions := Rules.load_fusions()
	var keys := fusions.keys()
	keys.sort()
	for k in keys:
		var parts: PackedStringArray = k.split("+")
		var out: String = fusions[k]
		var row := Label.new()
		row.text = "%s + %s → %s" % [defs[parts[0]].name, defs[parts[1]].name, defs[out].name]
		row.add_theme_font_size_override("font_size", 14)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(row)


## NO-189: name + description straight from Items.ARTEFACT_EFFECTS — the
## same rollable/sellable pool the Shop draws from (game/data/artefacts.json,
## GDD-synced), so this can never show an artefact the game itself wouldn't
## grant. Rarity colours the name, reusing Tuning.ARTEFACT_RARITY_COLOR, the
## exact palette modals.gd's own preview already draws rarity in.
static func _fill_artefacts(box: VBoxContainer) -> void:
	for a in Items.ARTEFACT_EFFECTS:
		_row(box, _artefact_tex(a.key), a.name, a.description, Tuning.ARTEFACT_RARITY_COLOR[a.rarity])


## Mirrors game.gd's own artefact_tex() path convention (assets/artefacts/
## <key>.png, else the shared placeholder) — the menu has no live Game node
## to read artefact_icons/art_placeholder off (same constraint NO-190 notes
## for its tier icons), so this loads by the identical path instead of a
## second convention.
static func _artefact_tex(key: String) -> Texture2D:
	var art := "res://assets/artefacts/%s.png" % key
	if ResourceLoader.exists(art):
		return load(art)
	return load("res://assets/ui/art_placeholder.svg")


## NO-189: Items and Piece Buffs are two separate arrays in items.gd (16 +
## 13 entries) — the Buff Box item grants from PIECE_BUFFS specifically,
## carrying the dormant/timed distinction the Notion Piece Buffs DB draws.
## Shown as two headed sections on one page rather than merged, since that
## split already exists in the data, not invented for this page.
static func _fill_items(box: VBoxContainer) -> void:
	var head := Label.new()
	head.text = "Items"
	head.add_theme_font_size_override("font_size", 18)
	head.modulate = Color(1, 1, 1, 0.8)
	box.add_child(head)
	for it in Items.ITEMS:
		_row(box, _item_tex(it.key), "%s — %s" % [it.name, it.tier], it.description)
	var head2 := Label.new()
	head2.text = "Piece Buffs"
	head2.add_theme_font_size_override("font_size", 18)
	head2.modulate = Color(1, 1, 1, 0.8)
	box.add_child(head2)
	for b in Items.PIECE_BUFFS:
		_row(box, _item_tex(b.key), "%s — %s" % [b.name, b.tier], b.description)


static func _item_tex(key: String) -> Texture2D:
	var path := "res://assets/items/%s.svg" % key
	return load(path) if ResourceLoader.exists(path) else null


## NO-189: the ONE Guide page with no data file — the board's own visual
## language. Every colour is read off `board`'s own COL_* constants
## (game.gd, "Palette rule 2026-07-07" and NO-161/NO-176), never restated as
## a new literal, so this page cannot drift out of sync with NO-183/184
## (in flight as this ships, both changing the hatch and the indicators).
static func _fill_indicators(box: VBoxContainer, board) -> void:
	var rows := [
		["Move", board.COL_MOVE, "A square the selected piece can move to."],
		["Capture", board.COL_CAPTURE, "An enemy piece the selected piece can capture."],
		["Selected", board.COL_SELECT, "The piece currently selected."],
		["Merge partner", board.COL_MERGE, "A piece the selection can merge or fuse with."],
		["Reachable zone", board.COL_ZONE_OUTLINE_MOVE, "Outline around every square a selected piece can reach this turn."],
		["Zone overlap", board.COL_ZONE_OUTLINE_OVERLAP, "Where a move zone and a capture zone reachable this turn share a boundary."],
		["Capture zone tile", board.COL_CAPTURE, "A tile inside the selected piece's capture range."],
		["Placement", board.COL_PLACE, "A tile available during setup or relocation."],
		["Arrow Planning", board.COL_ARROW, "A planned move marker, placed by the Arrow Planning item."],
		["Your pieces", board.COL_PLAYER, "Your pieces and threats read blue — the game's palette rule."],
		["Enemy pieces", board.COL_ENEMY, "Enemy pieces and threats read red — the game's palette rule."],
	]
	for r in rows:
		_swatch_row(box, r[0], r[1], r[2])
	# NO-176 / NO-101: two conventions that aren't a single flat colour, so
	# they get a text-only row instead of a swatch.
	_row(box, null, "Target-zone hatch",
		"A single hatch direction marks a tile covered by one reachable zone; crossed hatching marks a tile where two zones overlap.")
	_row(box, null, "%s Inverted" % board.INV_MARK_GLYPH,
		"Marks a piece currently using its inverted move pattern.")


static func _swatch_row(parent: Container, title: String, color: Color, desc: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var sw := ColorRect.new()
	# floor the alpha so a low-alpha board colour (e.g. COL_MOVE's 0.8, or
	# COL_PLACE's 0.6) still reads as a solid swatch here
	sw.color = Color(color.r, color.g, color.b, maxf(color.a, 0.9))
	sw.custom_minimum_size = Vector2(20, 20)
	row.add_child(sw)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name_l := Label.new()
	name_l.text = title
	name_l.add_theme_font_size_override("font_size", 14)
	col.add_child(name_l)
	var desc_l := Label.new()
	desc_l.text = desc
	desc_l.add_theme_font_size_override("font_size", 11)
	desc_l.modulate = Color(1, 1, 1, 0.7)
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(desc_l)


## Shared list row: an optional icon, a name (optionally coloured), and an
## optional one-line description underneath — Artefacts and Items both
## reduce to this.
static func _row(parent: Container, icon: Texture2D, title: String, desc: String,
		title_color := Color(1, 1, 1, 1)) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	if icon != null:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.custom_minimum_size = Vector2(28, 28)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tr)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name_l := Label.new()
	name_l.text = title
	name_l.add_theme_font_size_override("font_size", 14)
	name_l.add_theme_color_override("font_color", title_color)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_l)
	if desc != "":
		var desc_l := Label.new()
		desc_l.text = desc
		desc_l.add_theme_font_size_override("font_size", 11)
		desc_l.modulate = Color(1, 1, 1, 0.75)
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(desc_l)
