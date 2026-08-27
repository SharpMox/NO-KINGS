extends SceneTree

const Rules := preload("res://scripts/rules.gd")
const Items := preload("res://data/items.gd")
## Asserts a token sprite exists for every piece def and an icon for every
## item (picked 2026-07-17, .scratch/item-icons). A piece needs either the
## side-specific pair (<id>-light.png + <id>-dark.png, the 2026-08-27 designs)
## or a single monochrome <id>.svg — a lone half of the pair is a mistake, and
## a piece with side art must not also keep a stale svg. Run headless:
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
	if missing.is_empty():
		print("ALL %d TOKENS + %d ITEM ICONS PRESENT"
			% [Rules.load_pieces().size(), Items.ITEMS.size()])
		quit(0)
	else:
		push_error("missing tokens: " + ", ".join(missing))
		quit(1)
