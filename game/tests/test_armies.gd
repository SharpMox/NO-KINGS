extends SceneTree
## Army data sanity: three 12-piece starting stocks (grilled 2026-07-03) —
## known piece ids, signature piece present, totals roughly equal and below
## the old 280-value STARTING_STOCK ("too strong").
## Run headless:  godot --headless --path game -s tests/test_armies.gd

const Tuning := preload("res://scripts/tuning.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _init() -> void:
	var defs: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/pieces.json"))
	var signatures := {"Crown": "rook", "Wild Hunt": "kirin", "Old Guard": "ferz"}

	check(Tuning.ARMIES.size() == 3, "three armies")
	check(Tuning.ARMIES.has(Tuning.DEFAULT_ARMY), "default army exists")
	var totals := []
	for name in Tuning.ARMIES:
		var army: Array = Tuning.ARMIES[name]
		check(army.size() == 12, "%s: 12 pieces" % name)
		check(army.has(signatures[name]), "%s: signature %s present" % [name, signatures[name]])
		var total := 0
		var ids_ok := true
		for id in army:
			ids_ok = ids_ok and defs.has(id)
			total += int(defs.get(id, {}).get("value", 0))
		check(ids_ok, "%s: every id is a known piece" % name)
		check(total < 280, "%s: total %d below the old stock's 280" % [name, total])
		totals.append(total)
	totals.sort()
	check(totals[-1] - totals[0] <= 60, "army totals roughly equal (spread %d)" % (totals[-1] - totals[0]))

	print("---")
	if fails == 0:
		print("ALL ARMY CHECKS OK")
	quit(1 if fails > 0 else 0)
