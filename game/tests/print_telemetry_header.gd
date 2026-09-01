extends SceneTree
## issue 103: prints the telemetry CSV header, so `tools/playtest.sh` takes its
## column names from the game rather than repeating them. A column added to
## _telemetry_csv() then appears in the CSV automatically; a hand-copied header
## would silently mislabel every row from the day they diverged.
##   godot --headless --path game -s tests/print_telemetry_header.gd

const GameScript := preload("res://scripts/game.gd")


func _init() -> void:
	print(GameScript.telemetry_header())
	quit(0)
