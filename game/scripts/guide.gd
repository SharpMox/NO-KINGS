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
## NO-242 (Max's ruling 2026-09-24): the catalog pages are master-detail —
## compact tappable rows, and a slide-over detail panel (DetailPanel, bottom
## of this file) with the full entry. Pieces carries no description text:
## game/data/pieces.json has no prose field, and modals.gd's own live
## "piece" preview shows a name + movement diagram with no description line
## either — the piece detail reuses that diagram, large, plus what the data
## does carry (value, promotion chain, Void twin, fusions).
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
const ItemLogic := preload("res://scripts/item_logic.gd")
const Settings := preload("res://scripts/settings.gd")

## Marks a tappable list row's Button (NO-242), so `row_buttons()` can find them.
const ROW_META := "guide_row"


## Builds a full-rect, initially-hidden Guide panel as a child of `layer` and
## returns it so the caller toggles `.visible`. `on_back` runs when the hub's
## own Back button is pressed (hides the panel itself). `board` supplies the
## piece-texture loader and board palette — see the header comment above.
static func build(layer: Node, on_back: Callable, board) -> Control:
	var root := GuideRoot.new()
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
	root.hub_scroll = hub_scroll
	var hub_box := VBoxContainer.new()
	hub_box.add_theme_constant_override("separation", 10)
	hub_scroll.add_child(hub_box)
	var hub_head := Label.new()
	hub_head.text = "Guide"
	hub_head.theme_type_variation = &"Title"
	hub_box.add_child(hub_head)

	# NO-242: the slide-over detail panel, shared by every catalog page. Built
	# before the pages so their rows can close over it, added to `root` after
	# them so it draws on top.
	var detail := DetailPanel.new()
	root.detail = detail

	var pages := [
		["Rules", func(box: VBoxContainer) -> void: _fill_rules(box)],
		["Pieces", func(box: VBoxContainer) -> void: _fill_pieces(box, board, detail)],
		["Promotions", func(box: VBoxContainer) -> void: _fill_promotions(box, board, detail)],
		["Fusions", func(box: VBoxContainer) -> void: _fill_fusions(box, board, detail)],
		["Artefacts", func(box: VBoxContainer) -> void: _fill_artefacts(box, detail)],
		["Items", func(box: VBoxContainer) -> void: _fill_items(box, detail)],
		["Indicators", func(box: VBoxContainer) -> void: _fill_indicators(box, board)],
	]
	for entry in pages:
		var title: String = entry[0]
		var fill: Callable = entry[1]
		var page := _page(root, hub_scroll, title, fill)
		root.pages.append(page)
		var btn := Button.new()
		btn.text = title
		btn.pressed.connect(func() -> void:
			hub_scroll.visible = false
			page.visible = true)
		hub_box.add_child(btn)

	# Max ruling 2026-09-24 (isolated dismiss): Back leaves the Guide
	# entirely — the same role a modal's Cancel/Close plays — so it sits
	# alone below a gap, after every catalog page button, never among them.
	var hub_back_gap := Control.new()
	hub_back_gap.custom_minimum_size = Vector2(0, 32) # matches modals.gd's MODAL_CANCEL_GAP
	hub_box.add_child(hub_back_gap)
	var hub_back := Button.new()
	hub_back.text = "← Back"
	# NO-256: full width like the catalog-page buttons above it (their default
	# SIZE_FILL), so it lines up with the list; its text centres itself.
	hub_back.pressed.connect(func() -> void:
		root.visible = false
		on_back.call())
	hub_box.add_child(hub_back)

	root.add_child(detail)
	return root


## Debug capture (tools/capture.md, `--show-screen guide:<page>`): open the
## sub-page whose hub button reads `page` (any case — "rules", "pieces",
## "promotions", "fusions", "artefacts", "items", "indicators") by pressing
## that button. False if no hub button matches.
static func open_page(root: Control, page: String) -> bool:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text.to_lower() == page.to_lower():
			(b as Button).pressed.emit()
			return true
	return false


## Debug capture: `spec` is what follows "guide:" — "<page>" opens the page,
## "<page>:<index>" also opens the detail panel on that page's row <index>
## (0-based, list order), instantly so the screenshot never lands mid-slide.
## "<page>:row:<index>" instead scrolls the page's list so that row is at the
## TOP of the viewport (no detail panel) — for capturing rows further down
## than the default (top-of-list) view reaches.
## A coroutine (unlike the sync version before it) only because the "row"
## form awaits one frame: the page's ScrollContainer only just turned visible
## this frame (`open_page` above), and its content's laid-out position is
## still the stale pre-visible one until the next layout pass — same trap
## CLAUDE.md documents for a freshly-laid-out Control's `get_global_rect()`.
## Every caller must `await` this now, index paths included.
static func show_screen(root: Control, spec: String) -> bool:
	var parts := spec.split(":")
	if not open_page(root, parts[0]):
		return false
	if parts.size() < 2:
		return true
	if parts[1] == "row":
		await root.get_tree().process_frame
		var rows := row_buttons(root)
		var ri := int(parts[2]) if parts.size() >= 3 else -1
		if parts.size() < 3 or not parts[2].is_valid_int() or ri < 0 or ri >= rows.size():
			return false
		var row_top: float = (rows[ri].get_parent() as Control).position.y
		for page in (root as GuideRoot).pages:
			if page.visible:
				(page as ScrollContainer).scroll_vertical = int(row_top)
		return true
	var list := row_buttons(root)
	var i := int(parts[1])
	if not parts[1].is_valid_int() or i < 0 or i >= list.size():
		return false
	var detail: DetailPanel = (root as GuideRoot).detail
	detail.instant = true
	list[i].pressed.emit()
	detail.instant = false
	return true


## The tappable rows of whichever sub-page is showing, in list order.
static func row_buttons(root: Control) -> Array[Button]:
	var out: Array[Button] = []
	for page in (root as GuideRoot).pages:
		if page.visible:
			for b in page.find_children("*", "Button", true, false):
				if b.has_meta(ROW_META):
					out.append(b)
	return out


## The detail panel (NO-242): `.is_open()`, and its content for probes.
static func detail_panel(root: Control) -> Control:
	return (root as GuideRoot).detail


## Back / Escape inside the Guide, one level up: the detail panel first, then
## an open sub-page back to the hub. False at the hub itself, so the caller's
## own Back handling (close the Guide) takes over — same "Back lands where the
## on-screen ← does" shape as menu.gd's tier picker and TEST list.
static func go_back(root: Control) -> bool:
	return (root as GuideRoot).go_back()


## One sub-page's shell: a header row (title + Back) + whatever `fill_rows`
## appends + a second, identical Back below it — NO-263: a long catalog
## page pushes the bottom one below the fold, so the header row carries its
## own, wired to the same "return to `hub_scroll`" handler. Every catalog
## page below is just a `fill_rows` callable plugged into this.
static func _page(root: Control, hub_scroll: Control, title: String, fill_rows: Callable) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# NO-242: rows are PASS buttons (_tap_row) so a drag that starts on one
	# still scrolls; past this deadzone the press becomes a scroll, not a tap
	# — the TEST list's own recipe (menu.gd, tests/test_touch_scroll.gd).
	scroll.scroll_deadzone = 24
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
	# NO-263 (Max ruling 2026-09-25): a long catalog page pushes the bottom
	# Back below the fold, so a second Back sits in the header row next to
	# the title — title left, Back right, the same left/right split
	# show_shop()'s own header uses (title left, Gold pinned right). Both
	# Backs share one handler so they can never drift apart.
	var go_hub := func() -> void:
		scroll.visible = false
		hub_scroll.visible = true
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	box.add_child(head_row)
	var head := Label.new()
	head.text = title
	head.theme_type_variation = &"Title"
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(head)
	# NO-263 / NO-256: no font-size override — same theme role (default
	# Button) as the bottom Back below.
	var top_back := Button.new()
	top_back.text = "← Back"
	top_back.pressed.connect(go_hub)
	head_row.add_child(top_back)
	fill_rows.call(box)
	# Max ruling 2026-09-24 (isolated dismiss): same shape as the hub's own
	# Back — a gap separates it from the catalog rows above.
	var back_gap := Control.new()
	back_gap.custom_minimum_size = Vector2(0, 32) # matches modals.gd's MODAL_CANCEL_GAP
	box.add_child(back_gap)
	var back := Button.new()
	back.text = "← Back"
	# box is otherwise LEFT-aligned (the catalog rows above), but Back is
	# isolated below its own gap and reads better centred under the list.
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(go_hub)
	box.add_child(back)
	return scroll


static func _fill_rules(box: VBoxContainer) -> void:
	var body := Label.new()
	body.text = GuideText.TEXT
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(body)


## NO-242 (was NO-189's name + tiny-diagram rows): one compact row per piece
## — token + name — and the full picture lives in the detail panel
## (_piece_detail). Player-side art (the default owner) — unlike NO-190's
## difficulty-tier icons, Max ruled those red/enemy specifically; no such
## ruling exists for this roster reference.
## Excludes "king": tools/export-game-pieces.mjs's own comment calls it a
## boss ENTITY, not a roster piece (no Family, no fusions, never
## obtainable) — the reference site's codex lists 38, not 39, for the
## same reason.
static func _fill_pieces(box: VBoxContainer, board, detail: DetailPanel) -> void:
	var defs := Rules.load_pieces()
	for id: String in defs:
		if id == "king":
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(_icon(board.load_piece_tex(id), 40))
		row.add_child(_label("%s · Value: %d" % [defs[id].name, int(defs[id].value)], 17, true))
		_tap_row(box, row, func() -> void: detail.open(_piece_detail(id, board, detail)))


## NO-189: the 8 Families, derived from pieces.json's own `next` chain
## (tools/export-game-pieces.mjs) rather than a second copy of
## data/promotions.js — a base with a successor starts a Family; a base
## with none is just a piece with no promotion at all (22 of the 38, e.g.
## Berolina). Row title = the base piece's own name, exactly matching
## promotions.js's own `title` field (also just the base's name, e.g.
## "Pawn") — nothing here is invented copy. NO-242: a tap opens the chain's
## RESULT (its top piece); that panel shows the whole chain again, each
## stage tappable.
static func _fill_promotions(box: VBoxContainer, board, detail: DetailPanel) -> void:
	var defs := Rules.load_pieces()
	var is_target := {}
	for id in defs:
		var nxt = defs[id].get("next")
		if nxt:
			is_target[nxt] = true
	for id: String in defs:
		if id == "king" or is_target.has(id) or not defs[id].get("next"):
			continue
		var chain := _chain(defs, id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var title_l := _label(defs[id].name, 16)
		title_l.custom_minimum_size.x = 100
		row.add_child(title_l)
		for i in chain.size():
			if i > 0:
				row.add_child(_label("→", 16))
			row.add_child(_icon(board.load_piece_tex(chain[i]), 36))
		var top: String = chain[-1]
		_tap_row(box, row, func() -> void: detail.open(_piece_detail(top, board, detail)))


## NO-189: one line per fusion, "A + B → Result" — see the header comment
## for why additive/synergistic aren't split here. Each line leads with the
## three pieces' own tokens (the same board.load_piece_tex Promotions uses),
## and lines sort by result name rather than internal key. NO-242: a tap
## opens the result piece's panel.
static func _fill_fusions(box: VBoxContainer, board, detail: DetailPanel) -> void:
	var defs := Rules.load_pieces()
	var fusions := Rules.load_fusions()
	var keys := fusions.keys()
	keys.sort_custom(func(a, b) -> bool:
		var na: String = defs[fusions[a]].name
		var nb: String = defs[fusions[b]].name
		return na < nb if na != nb else a < b)
	for k in keys:
		var parts: PackedStringArray = k.split("+")
		var out: String = fusions[k]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		for part in [parts[0], "+", parts[1], "→", out]:
			if part == "+" or part == "→":
				row.add_child(_label(part, 15))
			else:
				row.add_child(_icon(board.load_piece_tex(part), 32))
		var names := _label("%s + %s → %s" % [defs[parts[0]].name, defs[parts[1]].name, defs[out].name], 15, true)
		names.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(names)
		_tap_row(box, row, func() -> void: detail.open(_piece_detail(out, board, detail)))


## NO-242: icon + name + a rarity dot per row (was NO-189's 180-row wall of
## name + full effect text). The data is Items.ARTEFACT_EFFECTS — the same
## rollable/sellable pool the Shop draws from (game/data/artefacts.json,
## GDD-synced), so this can never show an artefact the game itself wouldn't
## grant — and the dot reuses Tuning.ARTEFACT_RARITY_COLOR, the palette
## modals.gd's own preview draws rarity in.
static func _fill_artefacts(box: VBoxContainer, detail: DetailPanel) -> void:
	for a in Items.ARTEFACT_EFFECTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(_icon(_artefact_tex(a.key), 36))
		row.add_child(_label(a.name, 16, true))
		var col: Color = Tuning.ARTEFACT_RARITY_COLOR.get(a.rarity, Color.WHITE)
		var dot := Control.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.draw.connect(func() -> void: dot.draw_circle(dot.size / 2, 6, col))
		row.add_child(dot)
		var key: String = a.key
		_tap_row(box, row, func() -> void: detail.open(_artefact_detail(key)))


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
## split already exists in the data, not invented for this page. NO-242:
## rows are icon + name + tier; the tiers are explained once, in a note
## under the page title, with the Shop prices read off Tuning.
static func _fill_items(box: VBoxContainer, detail: DetailPanel) -> void:
	var note := _label(_tier_note(), 14)
	note.modulate = Color(1, 1, 1, 0.75)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	for section in [["Items", Items.ITEMS, false], ["Piece Buffs", Items.PIECE_BUFFS, true]]:
		var head := _label(section[0], 18)
		head.modulate = Color(1, 1, 1, 0.8)
		box.add_child(head)
		for it: Dictionary in section[1]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			row.add_child(_icon(_item_tex(it.key), 36))
			row.add_child(_label(it.name, 16, true))
			var tier := _label(it.tier, 14)
			tier.modulate = Color(1, 1, 1, 0.7)
			row.add_child(tier)
			var is_buff: bool = section[2]
			_tap_row(box, row, func() -> void: detail.open(_item_detail(it, is_buff)))


static func _tier_note() -> String:
	var p: Dictionary = Tuning.SHOP_ITEM_PRICE
	return ("Tiers, weakest to strongest: Tactical, Strategic, Decisive. " +
		"In the Shop an Item costs $%d / $%d / $%d by tier.") % [p.Tactical, p.Strategic, p.Decisive]


static func _item_tex(key: String) -> Texture2D:
	var path := "res://assets/items/%s.svg" % key
	return load(path) if ResourceLoader.exists(path) else null


## NO-189: the ONE Guide page with no data file — the board's own visual
## language. Every colour and alpha is read off `board`'s own constants
## (game.gd, "Palette rule 2026-07-07" and NO-161/NO-176), never restated as
## a new literal, so this page cannot drift out of sync with the board.
## NO-242: each swatch is a mini tile (a COL_LIGHT square) carrying the mark
## the board draws there — hatch, fill, merge-target outline, outline, dot or arrow — at the
## board's own alpha, not a flat colour square. The old "Capture zone tile"
## row repeated Capture's COL_CAPTURE for the same red hatch (game.gd's
## legal_dests loop draws a capture destination exactly once); it is gone.
## The red zone the board does draw separately — the bomb blast / armed Item
## zone (_draw_target_zone: red hatch inside a red outline) — replaces the
## old text-only "Target-zone hatch" row, whose "crossed hatching" copy
## NO-222 made stale (overlap now hatches in one direction, HATCH_SPACING).
static func _fill_indicators(box: VBoxContainer, board) -> void:
	var hatch_a: float = board.HATCH_ALPHA
	var rows := [
		["Move", "hatch", Color(board.COL_ZONE_OUTLINE_MOVE, hatch_a), "A square the selected piece can move to."],
		["Capture", "hatch", Color(board.COL_CAPTURE, hatch_a), "An enemy piece the selected piece can capture."],
		["Selected", "fill", board.COL_SELECT, "The piece currently selected."],
		["Merge target", "target", board.COL_MERGE_TARGET, "A piece the selection can merge or fuse with: a pulsing orange outline, and the piece wiggles."],
		["Reachable zone", "outline", Color(board.COL_ZONE_OUTLINE_MOVE, board.ZONE_OUTLINE_ALPHA), "Outline around every square a selected piece can reach this turn."],
		["Zone overlap", "outline", Color(board.COL_ZONE_OUTLINE_OVERLAP, board.ZONE_OUTLINE_OVERLAP_ALPHA), "Where a move zone and a capture zone reachable this turn share a boundary."],
		["Blast zone", "zone", Color(board.COL_CAPTURE, hatch_a), "Tiles a bomb or armed Item will hit."],
		["Placement", "dot", board.COL_PLACE, "A tile available during setup or relocation."],
		["Your pieces", "fill", board.COL_PLAYER, "Your pieces and threats read blue — the game's palette rule."],
		["Enemy pieces", "fill", board.COL_ENEMY, "Enemy pieces and threats read red — the game's palette rule."],
	]
	for r in rows:
		_swatch_row(box, board, r[0], r[1], r[2], r[3])
	# NO-101: a glyph, not a colour — stays a text-only row.
	_row(box, null, "%s Inverted" % board.INV_MARK_GLYPH,
		"Marks a piece currently using its inverted move pattern.")


static func _swatch_row(parent: Container, board, title: String, mark: String, color: Color, desc: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var sw := Control.new()
	sw.custom_minimum_size = Vector2(28, 28)
	sw.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sw.draw.connect(func() -> void: _draw_mini_tile(sw, board, mark, color))
	row.add_child(sw)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var name_l := Label.new()
	name_l.text = title
	name_l.theme_type_variation = &"Heading"
	col.add_child(name_l)
	var desc_l := Label.new()
	desc_l.text = desc
	desc_l.theme_type_variation = &"Meta"
	desc_l.modulate = Color(1, 1, 1, 0.7)
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(desc_l)


## One board tile in miniature, carrying `mark` the way game.gd's _draw does:
## "hatch" (_draw_hatch's diagonal lines at HATCH_SPACING / HATCH_WIDTH),
## "fill" (draw_rect), "target" (the merge target's orange stroke on a dark
## keyline, game.gd MERGE_TARGET_*),
## "outline" (a zone edge), "zone" (hatch + outline, _draw_target_zone),
## "dot" (the COL_PLACE circle).
static func _draw_mini_tile(c: Control, board, mark: String, col: Color) -> void:
	var s := c.size.x
	# COL_LIGHT is a static var (the board theme) — read off the class the way
	# piece_diagram.gd does, since `board` may be a live Game instance
	var game: GDScript = load("res://scripts/game.gd")
	c.draw_rect(Rect2(Vector2.ZERO, c.size), game.COL_LIGHT)
	if mark == "hatch" or mark == "zone":
		var step: float = board.HATCH_SPACING
		var o := -s + step * 0.5
		while o < s:
			c.draw_line(Vector2(maxf(0.0, -o), maxf(0.0, o)),
				Vector2(minf(s, s - o), minf(s, s + o)), col, board.HATCH_WIDTH)
			o += step
	match mark:
		"fill":
			c.draw_rect(Rect2(Vector2.ZERO, c.size), col)
		"target":
			var r := Rect2(Vector2.ONE * 2.0, c.size - Vector2.ONE * 4.0)
			c.draw_rect(r, board.BUFF_BADGE_BG, false, 5.0)
			c.draw_rect(r, col, false, 3.0)
		"outline", "zone":
			c.draw_rect(Rect2(Vector2.ONE * 1.5, c.size - Vector2.ONE * 3.0),
				Color(col, board.ZONE_OUTLINE_ALPHA) if mark == "zone" else col, false, 3.0)
		"dot":
			c.draw_circle(c.size / 2, s * 0.16, col)


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
	name_l.theme_type_variation = &"Heading"
	name_l.add_theme_color_override("font_color", title_color)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_l)
	if desc != "":
		var desc_l := Label.new()
		desc_l.text = desc
		desc_l.theme_type_variation = &"Meta"
		desc_l.modulate = Color(1, 1, 1, 0.75)
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(desc_l)


# --- NO-242: detail panel content ---------------------------------------------

## What an Item's `target` field (items.gd header) asks of the player.
const _TARGET_TEXT := {
	"": "No target: it takes effect as soon as you use it.",
	"tile": "Targets one tile on the board.",
	"pair": "Targets a piece first, then a second tile.",
	"multi": "Targets any number of your pieces.",
	"area": "Targets an area of tiles.",
}


## A piece's detail: the in-game long-press preview's own movement diagram
## (PieceDiagram.draw + its LEGEND, modals.gd show_preview kind == "piece")
## drawn as large as the panel allows, then its value, promotion chain (every
## stage tappable, the current one highlighted the way the preview does),
## Void twin, and fusions — all read off pieces.json / fusions.json.
static func _piece_detail(id: String, board, detail: DetailPanel) -> Control:
	var defs := Rules.load_pieces()
	var box := _detail_box()
	box.add_child(_title(defs[id].name))

	var cells := 9 # covers the longest leap (Ying Long's 4) — same as the preview
	var w: float = detail.size.x if detail.size.x > 0 else 480.0
	var cell := int(clampf(w * 0.85 - 48, 180, 360)) / cells
	var dia := Control.new()
	dia.custom_minimum_size = Vector2(cells, cells) * cell
	dia.size_flags_horizontal = Control.SIZE_SHRINK_CENTER # see modals.gd NO-171
	var tex: Texture2D = board.load_piece_tex(id)
	dia.draw.connect(func() -> void: PieceDiagram.draw(dia, defs, id, cells, cell, tex))
	box.add_child(dia)
	var legend := _body(PieceDiagram.LEGEND, 14)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.modulate = Color(1, 1, 1, 0.7)
	box.add_child(legend)
	var value := _body("Value: %d" % int(defs[id].value), 17)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)

	box.add_child(_section("Promotion"))
	var chain := _chain(defs, id)
	if chain.size() > 1:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		for i in chain.size():
			if i > 0:
				row.add_child(_label("→", 20))
			var b := _piece_button(chain[i], board, detail)
			if chain[i] != id:
				b.modulate = Color(1, 1, 1, 0.45) # current stage stands out
			row.add_child(b)
		box.add_child(row)
		box.add_child(_body(" → ".join(PackedStringArray(chain.map(
			func(c: String) -> String: return defs[c].name)))))
	else:
		box.add_child(_body("Does not promote."))

	var twin := _void_twin(defs, id)
	if twin != "":
		var is_void: bool = defs[id].name.begins_with("Void ")
		box.add_child(_section("Void form of" if is_void else "Void form"))
		_link_row(box, twin, board, detail, defs[twin].name, [twin])

	var fusions := Rules.load_fusions()
	var sources: Array = []
	box.add_child(_section("Fuses into"))
	var fuses := false
	for k: String in fusions:
		var parts := k.split("+")
		var out: String = fusions[k]
		if out == id:
			sources.append(parts)
		if not parts.has(id):
			continue
		fuses = true
		var other: String = parts[1] if parts[0] == id else parts[0]
		_link_row(box, out, board, detail,
			"+ %s → %s" % [defs[other].name, defs[out].name], [other, out])
	if not fuses:
		box.add_child(_body("Does not fuse."))
	if not sources.is_empty():
		box.add_child(_section("Made by fusing"))
		for parts in sources:
			_link_row(box, "", board, detail,
				"%s + %s" % [defs[parts[0]].name, defs[parts[1]].name], [parts[0], parts[1]])
	return box


## The whole promotion chain `id` sits in, base first (game.gd _chain_of's
## shape, off ItemLogic.chain_base so the menu needs no live Game).
static func _chain(defs: Dictionary, id: String) -> Array:
	var chain := [ItemLogic.chain_base(defs, id)]
	while defs[chain[-1]].next != null:
		chain.append(defs[chain[-1]].next)
	return chain


## A piece's Void counterpart, read off the names pieces.json already pairs
## ("Ranger" / "Void Ranger", "Pawn" / "Void Pawn") — "" if it has none.
static func _void_twin(defs: Dictionary, id: String) -> String:
	var n: String = defs[id].name
	var want := n.trim_prefix("Void ") if n.begins_with("Void ") else "Void " + n
	for k: String in defs:
		if defs[k].name == want:
			return k
	return ""


static func _artefact_detail(key: String) -> Control:
	var e: Dictionary = {}
	for c: Dictionary in Items.ARTEFACT_CATALOG:
		if c.key == key:
			e = c
			break
	var box := _detail_box()
	box.add_child(_center(_icon(_artefact_tex(key), 128)))
	box.add_child(_title(e.name))
	var rarity: String = e.get("rarity", "")
	var bits := [rarity, str(e.get("type", ""))].filter(func(s: String) -> bool: return s != "")
	var kind := _body(" · ".join(PackedStringArray(bits)), 16)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind.add_theme_color_override("font_color", Tuning.ARTEFACT_RARITY_COLOR.get(rarity, Color.WHITE))
	box.add_child(kind)
	box.add_child(_body(e.effect, 17))
	var bonus: Array = e.get("bonus", [])
	if not bonus.is_empty():
		box.add_child(_fact("Boosts: " + ", ".join(PackedStringArray(bonus))))
	if str(e.get("conspiracy", "")) != "":
		box.add_child(_fact("Conspiracy: " + str(e.conspiracy)))
	return box


static func _item_detail(it: Dictionary, is_buff: bool) -> Control:
	var box := _detail_box()
	var tex := _item_tex(it.key)
	if tex != null:
		box.add_child(_center(_icon(tex, 96)))
	box.add_child(_title(it.name))
	var tier := _body("%s %s" % [it.tier, "Piece Buff" if is_buff else "Item"], 16)
	tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier.modulate = Color(1, 1, 1, 0.8)
	box.add_child(tier)
	box.add_child(_body(it.description, 17))
	if is_buff:
		box.add_child(_fact("Rides on a single piece; the Buff Box Item applies one."))
		if it.get("model") == "timed":
			var n := int(it.get("turns", 1))
			box.add_child(_fact("Timed: active from the moment it is applied, for %d player turn%s."
				% [n, "" if n == 1 else "s"]))
		else:
			box.add_child(_fact("Dormant: waits on its piece until its trigger fires, then it is used up."))
	else:
		box.add_child(_fact(_TARGET_TEXT.get(it.get("target", ""), "")))
		var cost := int(it.get("action_cost", 1))
		box.add_child(_fact("Using it costs no Action." if cost == 0
			else "Using it costs %d Action%s." % [cost, "" if cost == 1 else "s"]))
	box.add_child(_fact(_tier_note()))
	return box


# --- NO-242: small builders ----------------------------------------------------

## One tappable list row: `content` laid out as usual, with a transparent
## Button stretched over it (a PanelContainer fits every child to its rect,
## and the content alone sets the height). The Button PASSes so a drag that
## starts on a row still scrolls the page (see _page's scroll_deadzone).
static func _tap_row(parent: Container, content: Control, on_tap: Callable) -> Button:
	var row := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.05)
	bg.set_corner_radius_all(6)
	row.add_theme_stylebox_override("panel", bg)
	row.custom_minimum_size.y = 52
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(row)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 6)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(content)
	row.add_child(pad)
	var btn := Button.new()
	for state in ["normal", "hover", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(1, 1, 1, 0.12)
	pressed.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.set_meta(ROW_META, true)
	btn.pressed.connect(on_tap)
	row.add_child(btn)
	return btn


## A row of piece tokens + text inside the detail panel; tapping it swaps the
## panel to `target` ("" = not tappable).
static func _link_row(box: VBoxContainer, target: String, board, detail: DetailPanel,
		text: String, icon_ids: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for pid: String in icon_ids:
		row.add_child(_icon(board.load_piece_tex(pid), 32))
	var l := _label(text, 15, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	if target == "":
		box.add_child(row)
	else:
		_tap_row(box, row, func() -> void: detail.open(_piece_detail(target, board, detail)))


static func _piece_button(id: String, board, detail: DetailPanel) -> Button:
	var b := Button.new()
	b.icon = board.load_piece_tex(id)
	b.expand_icon = true
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(56, 56)
	b.pressed.connect(func() -> void: detail.open(_piece_detail(id, board, detail)))
	return b


static func _detail_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	return box


static func _label(text: String, size: int, expand := false) -> Label:
	var l := Label.new()
	l.text = text
	# NO-256: `size` picks a theme role; 15-16 is body (the theme default 20).
	if size >= 24:
		l.theme_type_variation = &"Title"
	elif size >= 17:
		l.theme_type_variation = &"Heading"
	elif size <= 14:
		l.theme_type_variation = &"Meta"
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _title(text: String) -> Label:
	var l := _label(text, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _body(text: String, size := 16) -> Label:
	var l := _label(text, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func _fact(text: String) -> Label:
	var l := _body(text, 15)
	l.modulate = Color(1, 1, 1, 0.75)
	return l


static func _section(text: String) -> Label:
	var l := _label(text, 18)
	l.modulate = Color(1, 1, 1, 0.8)
	return l


static func _icon(tex: Texture2D, px: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func _center(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c


# --- NO-242: the Guide's root and its slide-over detail panel -----------------

## The Guide's root: remembers the hub, the pages and the detail panel so
## Back / Escape can step up one level (`go_back`).
class GuideRoot extends Control:
	var hub_scroll: Control
	var pages: Array[Control] = []
	var detail: DetailPanel

	func go_back() -> bool:
		if detail.is_open():
			detail.close()
			return true
		for page in pages:
			if page.visible:
				page.visible = false
				hub_scroll.visible = true
				return true
		return false

	# Escape on desktop does what Android's Back does inside the Guide. Only
	# consumed when there was a level to step up from.
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo \
				and event.keycode == KEY_ESCAPE and is_visible_in_tree() and go_back():
			get_viewport().set_input_as_handled()


## One reusable slide-over: slides in from the right over ~85% of the Guide,
## the list still showing (dimmed) on the left. `open(content)` shows any
## built Control, swapping it in place if the panel is already open. Closes
## on a tap on the dimmed strip, a swipe right on the panel, or its "←".
## Slides only while Settings' animations_on is set; instant otherwise.
class DetailPanel extends Control:
	const SLIDE_SEC := 0.2
	## Debug capture: open without the slide, so a screenshot lands settled.
	var instant := false
	var _open := false
	var _shade := ColorRect.new()
	var _sheet := PanelContainer.new()
	var _scroll := ScrollContainer.new()
	var _holder := MarginContainer.new()
	var _press_at := Vector2.INF
	var _tween: Tween

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_shade.color = Color(0, 0, 0, 0.6)
		_shade.gui_input.connect(_on_shade_input)
		add_child(_shade)
		_sheet.anchor_left = 0.15
		_sheet.anchor_right = 1.0
		_sheet.anchor_bottom = 1.0
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.1, 0.13, 0.98)
		bg.content_margin_left = 16
		bg.content_margin_right = 16
		bg.content_margin_top = 12
		bg.content_margin_bottom = 12
		_sheet.add_theme_stylebox_override("panel", bg)
		add_child(_sheet)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		_sheet.add_child(col)
		var back_btn := Button.new()
		back_btn.text = "←"
		back_btn.custom_minimum_size = Vector2(56, 44)
		back_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		back_btn.pressed.connect(close)
		col.add_child(back_btn)
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		_scroll.scroll_deadzone = 24
		col.add_child(_scroll)
		_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll.add_child(_holder)

	func is_open() -> bool:
		return _open

	# a tap on the dimmed strip (the list peeking out on the left) closes
	func _on_shade_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close()

	## What the panel is showing (null before the first open).
	func content() -> Control:
		return _holder.get_child(0) if _holder.get_child_count() > 0 else null

	func open(c: Control) -> void:
		for old in _holder.get_children():
			_holder.remove_child(old)
			old.queue_free()
		_holder.add_child(c)
		_scroll.scroll_vertical = 0
		if _open:
			return # already showing: swap the content, no second slide
		_open = true
		if _tween:
			_tween.kill()
		if not _animate():
			visible = true
			_place(0.0, 1.0)
			return
		if not visible: # else it was mid-close: turn around from where it is
			_place(size.x, 0.0)
		visible = true
		_slide(0.0, 1.0, Tween.EASE_OUT)

	func close() -> void:
		if not _open:
			return
		_open = false
		if _tween:
			_tween.kill()
		if not _animate():
			visible = false
			return
		_slide(size.x, 0.0, Tween.EASE_IN)
		_tween.chain().tween_callback(hide)

	func _animate() -> bool:
		return not instant and bool(Settings.load_settings().get("animations_on", true))

	func _place(x: float, shade_a: float) -> void:
		_sheet.offset_left = x
		_sheet.offset_right = x
		_shade.modulate.a = shade_a

	func _slide(x: float, shade_a: float, how: Tween.EaseType) -> void:
		_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(how)
		_tween.tween_property(_sheet, "offset_left", x, SLIDE_SEC)
		_tween.tween_property(_sheet, "offset_right", x, SLIDE_SEC)
		_tween.tween_property(_shade, "modulate:a", shade_a, SLIDE_SEC)

	# Swipe right on the panel closes it. Read in _input, ahead of the GUI, so
	# the panel's own ScrollContainer taking the drag cannot hide it.
	func _input(e: InputEvent) -> void:
		if not _open or not is_visible_in_tree() or not (e is InputEventMouseButton) \
				or e.button_index != MOUSE_BUTTON_LEFT:
			return
		if e.pressed:
			_press_at = e.position if _sheet.get_global_rect().has_point(e.position) else Vector2.INF
			return
		if _press_at == Vector2.INF:
			return
		var d: Vector2 = e.position - _press_at
		_press_at = Vector2.INF
		if d.x > 60 and d.x > absf(d.y) * 1.5:
			close()
			get_viewport().set_input_as_handled()
