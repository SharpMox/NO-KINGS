extends SceneTree
## Wave Catalog data sanity — the 150 designed waves transcribed from the GDD
## (Draft v1), plus the buff flags and tariff schedule that ride on them.
## Run headless:  godot --headless --path game -s tests/test_waves.gd

const Waves := preload("res://data/waves.gd")
const Tariffs := preload("res://data/tariffs.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _init() -> void:
	check(Waves.WAVES.size() == 150, "150 designed waves")

	# Kings at 50/100/150 only, with the catalog escorts
	for n in range(1, Waves.WAVES.size() + 1):
		var has_king: bool = Waves.WAVES[n - 1].has("king")
		if n % 50 == 0:
			check(has_king, "wave %d is a King wave" % n)
		elif has_king:
			check(false, "unexpected king in wave %d" % n)
	check(Waves.WAVES[49].size() == 5, "wave 50: King + 4 escorts")
	check(Waves.WAVES[99].size() == 5, "wave 100: King + 4 escorts")
	check(Waves.WAVES[149].size() == 6, "wave 150: King + 5 escorts")

	# Density curve (GDD totals): 5 through wave 69, 6 from wave 70
	var curve_ok := true
	for n in range(51, 70):
		curve_ok = curve_ok and Waves.WAVES[n - 1].size() == 5
	for n in range(70, 150):
		if n % 50 == 0:
			continue
		curve_ok = curve_ok and Waves.WAVES[n - 1].size() == 6
	check(curve_ok, "density curve: 5 (waves 51-69), 6 (waves 70-149)")

	# 25 buffed-enemy waves, each flag naming a piece in its own wave
	check(Waves.BUFFS.size() == 25, "25 buffed-enemy waves")
	for n in Waves.BUFFS:
		check(Waves.WAVES[n - 1].has(Waves.BUFFS[n]),
			"wave %d roster includes its buff carrier %s" % [n, Waves.BUFFS[n]])

	# Tariff schedule: every 10th wave through 150, catalog tiers
	var tiers := {
		10: "Mild", 20: "Mild", 30: "Mild", 40: "Moderate", 50: "Severe",
		60: "Mild", 70: "Mild", 80: "Moderate", 90: "Moderate", 100: "Severe",
		110: "Mild", 120: "Moderate", 130: "Moderate", 140: "Severe", 150: "Severe",
	}
	check(Tariffs.SCHEDULE.size() == 15, "15 tariff waves")
	for n in tiers:
		check(Tariffs.SCHEDULE.get(n) == tiers[n], "wave %d tariff is %s" % [n, tiers[n]])

	print("---")
	if fails == 0:
		print("ALL WAVE CHECKS OK")
	quit(1 if fails > 0 else 0)
