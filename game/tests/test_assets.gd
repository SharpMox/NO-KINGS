extends SceneTree

const Rules := preload("res://scripts/rules.gd")
const Items := preload("res://data/items.gd")
## Asserts a token sprite exists for every piece def and an icon for every
## item (icon set picked 2026-07-17). A piece needs either the
## side-specific pair (<id>-light.png + <id>-dark.png, the 2026-08-27 designs)
## or a single monochrome <id>.svg — a lone half of the pair is a mistake, and
## a piece with side art must not also keep a stale svg. Also asserts the
## artefact catalog (game/data/artefacts.json, slice 14) and the code agree
## about which keys are implemented. Run headless:
##   godot --headless --path game -s tests/test_assets.gd

func _init() -> void:
	var missing := []
	for id in Rules.load_pieces():
		var light := FileAccess.file_exists("res://assets/pieces/%s-light.png" % id)
		var dark := FileAccess.file_exists("res://assets/pieces/%s-dark.png" % id)
		var mono := FileAccess.file_exists("res://assets/pieces/%s.svg" % id)
		if light != dark:
			missing.append("%s (only the %s side)" % [id, "light" if light else "dark"])
		elif light and mono:
			missing.append("%s (side art + a stale svg)" % id)
		elif not light and not mono:
			missing.append(id)
	for it in Items.ITEMS:
		if not FileAccess.file_exists("res://assets/items/%s.svg" % it.key):
			missing.append("item:" + it.key)
	missing.append_array(_artefact_catalog_errors())
	missing.append_array(_art_placeholder_errors())
	if missing.is_empty():
		print("ALL %d TOKENS + %d ITEM ICONS + %d ARTEFACTS PRESENT (%d painted)"
			% [Rules.load_pieces().size(), Items.ITEMS.size(),
				Items.ARTEFACT_CATALOG.size(), _painted_artefacts()])
		quit(0)
	else:
		push_error("missing tokens: " + ", ".join(missing))
		quit(1)


## The catalog and the code must agree on which keys are implemented: every
## catalog entry flagged implemented must have a matching ARTEFACT_EFFECTS
## entry (the code actually backs it), and keys must be unique across the
## 180. (issue 69 removed the 7 game-native core keys and the "collides with
## a core key" check that used to guard against — ARTEFACT_EFFECTS is now
## built solely from this catalog, so a collision within it is impossible.)
func _artefact_catalog_errors() -> Array:
	var errors := []
	var catalog: Array = Items.ARTEFACT_CATALOG
	if catalog.size() != 180:
		errors.append("artefact catalog: expected 180 entries, got %d" % catalog.size())
	var effect_keys := {}
	for e in Items.ARTEFACT_EFFECTS:
		effect_keys[e.key] = true
	var seen := {}
	for e in catalog:
		if seen.has(e.key):
			errors.append("artefact catalog: duplicate key %s" % e.key)
		seen[e.key] = true
		if e.get("implemented", false) and not effect_keys.has(e.key):
			errors.append("artefact catalog: %s marked implemented but code has no matching effect" % e.key)
	return errors


func _painted_artefacts() -> int:
	var n := 0
	for a in Items.ARTEFACT_CATALOG:
		if FileAccess.file_exists("res://assets/artefacts/%s.png" % str(a.get("key", ""))):
			n += 1
	return n


## NO-17: the placeholder is the load-bearing half of the artefact art, not a
## nicety. 38 of 180 artefacts are painted, so the MISS is the normal case — and
## a miss must still draw something, at the same size, or the Shop reflows as art
## lands one file at a time.
##
## Asserts the asset exists, that every painted file sits on a real catalog key
## (a typo'd filename is otherwise invisible: it just never loads), and that the
## painted set is square, which is what lets one tile size serve both.
func _art_placeholder_errors() -> Array:
	var errors := []
	if not FileAccess.file_exists("res://assets/ui/art_placeholder.svg"):
		errors.append("art placeholder: assets/ui/art_placeholder.svg is missing — "
			+ "every unpainted artefact and every Box would draw nothing")
	var keys := {}
	for a in Items.ARTEFACT_CATALOG:
		keys[str(a.get("key", ""))] = true
	var dir := DirAccess.open("res://assets/artefacts")
	if dir == null:
		errors.append("art: assets/artefacts/ does not exist")
		return errors
	for f in dir.get_files():
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		if not f.ends_with(".png"):
			errors.append("art: unexpected file assets/artefacts/%s" % f)
			continue
		var key := f.trim_suffix(".png")
		if not keys.has(key):
			errors.append("art: assets/artefacts/%s is not a catalog key — it will "
				% f + "never load, silently")
		var tex: Texture2D = load("res://assets/artefacts/%s" % f)
		if tex != null and tex.get_width() != tex.get_height():
			errors.append("art: %s is %dx%d, not square"
				% [f, tex.get_width(), tex.get_height()])
	return errors
