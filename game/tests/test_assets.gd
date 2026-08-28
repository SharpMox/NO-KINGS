extends SceneTree

const Rules := preload("res://scripts/rules.gd")
const Items := preload("res://data/items.gd")
## Asserts a token sprite exists for every piece def and an icon for every
## item (picked 2026-07-17, .scratch/item-icons). A piece needs either the
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
	if missing.is_empty():
		print("ALL %d TOKENS + %d ITEM ICONS + %d ARTEFACTS PRESENT"
			% [Rules.load_pieces().size(), Items.ITEMS.size(), Items.ARTEFACT_CATALOG.size()])
		quit(0)
	else:
		push_error("missing tokens: " + ", ".join(missing))
		quit(1)


## The catalog and the code must agree on which keys are implemented: every
## catalog entry flagged implemented must have a matching ARTEFACT_EFFECTS
## entry (the code actually backs it), keys must be unique across the 180,
## and none may collide with a core key (a collision would silently shadow
## a shipped effect).
func _artefact_catalog_errors() -> Array:
	var errors := []
	var catalog: Array = Items.ARTEFACT_CATALOG
	if catalog.size() != 180:
		errors.append("artefact catalog: expected 180 entries, got %d" % catalog.size())
	var core_keys := {}
	for e in Items.ARTEFACT_EFFECTS_CORE:
		core_keys[e.key] = true
	var effect_keys := {}
	for e in Items.ARTEFACT_EFFECTS:
		effect_keys[e.key] = true
	var seen := {}
	for e in catalog:
		if seen.has(e.key):
			errors.append("artefact catalog: duplicate key %s" % e.key)
		seen[e.key] = true
		if core_keys.has(e.key):
			errors.append("artefact catalog: key %s collides with a core key" % e.key)
		if e.get("implemented", false) and not effect_keys.has(e.key):
			errors.append("artefact catalog: %s marked implemented but code has no matching effect" % e.key)
	return errors
