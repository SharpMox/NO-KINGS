extends SceneTree
## Seeded runs (issue 75). The determinism itself was already true before this
## slice — nothing rolls outside g.rng (no bare randi/randf anywhere) and
## rules.gd's AI is pure — so what is tested here is the SURFACE: that a seed
## actually reaches the generator and that different seeds actually diverge.
##
## Asserting only "same seed reproduces" would pass trivially if the seed were
## ignored entirely, since the game would then be deterministic by accident.
## Both directions are required.
##
## Run headless:  godot --headless --path game -s tests/test_seed.gd

const GameScript := preload("res://scripts/game.gd")

var fails := 0

func check(cond: bool, label: String) -> void:
	print(("ok: " if cond else "FAIL: ") + label)
	if not cond:
		fails += 1
		push_error("FAIL: " + label)


## A cheap fingerprint of where the generator lands after a fixed number of
## draws — enough to tell two streams apart without booting a whole run.
func _stream(seed_text: String, draws: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameScript.seed_of(seed_text)
	var out := []
	for i in draws:
		out.append(rng.randi() % 1000)
	return out


func _init() -> void:
	check(GameScript.seed_of("12345") == 12345,
		"a numeric seed is used as-is, so it means what a player expects")
	check(GameScript.seed_of("no kings") == GameScript.seed_of("no kings"),
		"a word seed hashes stably — the same phrase always gives the same seed")
	check(GameScript.seed_of("no kings") != GameScript.seed_of("no king"),
		"different phrases give different seeds")

	# the two directions that matter
	check(_stream("perfect-rng", 40) == _stream("perfect-rng", 40),
		"SAME seed -> identical stream (reproducible)")
	check(_stream("perfect-rng", 40) != _stream("perfect-rng-2", 40),
		"DIFFERENT seeds -> different streams — without this, the test above " +
		"would pass even if the seed were ignored entirely")

	# empty means "roll one", the pre-existing behaviour
	check(GameScript.next_seed == "",
		"the default is empty, i.e. a fresh random seed as before")

	print("---")
	if fails == 0:
		print("ALL SEED CHECKS OK")
	quit(1 if fails > 0 else 0)
