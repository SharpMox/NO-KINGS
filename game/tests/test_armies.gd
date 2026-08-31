extends SceneTree
## Army data sanity. The ORIGINAL three (slimmed 2026-07-08: 8 base pieces +
## 3 specials) get the strict shape/balance rule: 11 pieces, a signature
## piece present, total value below the old 280-value STARTING_STOCK ("too
## strong"), and roughly equal to each other. Issue 68's three more Families
## are deliberate outliers by that same rule's own standard — a thin
## 7-piece Syndicate kit, a 14-pawn Horde swarm with no majors — so they only
## get the one check that applies universally: every id is a real piece.
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

	check(Tuning.ARMIES.size() == 6, "six armies: the original three (issue 67) + issue 68's three more")
	check(Tuning.ARMIES.has(Tuning.DEFAULT_ARMY), "default army exists")

	for name in Tuning.ARMIES:
		var ids_ok := true
		for id in Tuning.ARMIES[name]:
			ids_ok = ids_ok and defs.has(id)
		check(ids_ok, "%s: every id is a known piece" % name)

	var totals := []
	for name in signatures: # the original three only — see the header
		var army: Array = Tuning.ARMIES[name]
		check(army.size() == 11, "%s: 11 pieces" % name)
		check(army.has(signatures[name]), "%s: signature %s present" % [name, signatures[name]])
		var total := 0
		for id in army:
			total += int(defs.get(id, {}).get("value", 0))
		check(total < 280, "%s: total %d below the old stock's 280" % [name, total])
		totals.append(total)
	totals.sort()
	check(totals[-1] - totals[0] <= 60,
		"the original three armies' totals are roughly equal (spread %d)" % (totals[-1] - totals[0]))

	print("---")
	if fails == 0:
		print("ALL ARMY CHECKS OK")
	quit(1 if fails > 0 else 0)
