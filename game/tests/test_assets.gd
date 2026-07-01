extends SceneTree

const Rules := preload("res://scripts/rules.gd")
## Asserts a token sprite exists for every piece def. Run headless:
##   godot --headless --path game -s tests/test_assets.gd

func _init() -> void:
	var missing := []
	for id in Rules.load_pieces():
		if not FileAccess.file_exists("res://assets/pieces/%s.png" % id):
			missing.append(id)
	if missing.is_empty():
		print("ALL %d TOKENS PRESENT" % Rules.load_pieces().size())
		quit(0)
	else:
		push_error("missing tokens: " + ", ".join(missing))
		quit(1)
