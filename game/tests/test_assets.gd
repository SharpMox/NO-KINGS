extends SceneTree

const Rules := preload("res://scripts/rules.gd")
const Items := preload("res://data/items.gd")
## Asserts a token sprite exists for every piece def and an icon for every
## item (picked 2026-07-17, .scratch/item-icons). Run headless:
##   godot --headless --path game -s tests/test_assets.gd

func _init() -> void:
	var missing := []
	for id in Rules.load_pieces():
		if not FileAccess.file_exists("res://assets/pieces/%s.png" % id) \
				and not FileAccess.file_exists("res://assets/pieces/%s.svg" % id):
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
