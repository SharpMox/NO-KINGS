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
const Scenarios := preload("res://data/scenarios.gd")
const SaveConfig := preload("res://scripts/save_config.gd")

## NO-110: same shape as test_scenarios.gd's sweep, BOT_STEPS included — enough
## to hit a few captures, not a full run.
const STEPS := 40

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


## NO-110: boots a real game from `cfg` (same idiom as test_scenarios.gd),
## lets the bot autoplay `steps` frames, and fingerprints the result with the
## existing save serializer — SaveConfig.to_config(g) — rather than inventing
## a second one.
##
## One key it returns is NOT seed-derived: "clock_s" drains by the real
## wall-clock `delta` handed to _process() every frame (game.gd:989,
## deliberately not routed through g.rng), so two runs of the very same seed
## still see slightly different frame timing and a different clock_s — that
## would fail the "same seed" assertion below for a reason that has nothing
## to do with the seed. It's erased before comparing. Everything else
## to_config() writes comes from g.rng draws, turn/wave counters, or board
## state, all of which the seed (and the fixed step count) fully determine.
func _fingerprint(cfg: Dictionary, steps: int) -> Dictionary:
	GameScript.next_config = cfg
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.autoplay = true
	var i := 0
	while i < steps and game.state != GameScript.State.GAME_OVER:
		await process_frame
		i += 1
	var snapshot: Dictionary = SaveConfig.to_config(game)
	snapshot.erase("clock_s")
	game.queue_free()
	await process_frame
	return snapshot


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

	# --- end-to-end: does a whole RUN reproduce, not just the raw stream? ---
	# The checks above only prove the SURFACE — a seed reaches the generator,
	# and two raw streams diverge. They say nothing about a full run, where
	# autoplay.gd itself draws from g.rng for every bot decision (move choice,
	# item use, army-ability rolls — see autoplay.gd), on top of wave spawns
	# (wave_logic.gd) and Box/Shop rolls. Same argument as above applies here:
	# asserting only "same seed reproduces a run" would pass trivially if
	# g.rng were never actually reached, since a stray "randomize()" or a bare
	# randi() would still look "reproducible" run after run in-process. Both
	# directions are required again.
	var scenario_cfg: Dictionary = {}
	for s in Scenarios.all():
		if s.name == "Captures & highlights":
			scenario_cfg = s.cfg
			break
	check(not scenario_cfg.is_empty(), "the 'Captures & highlights' scenario exists to seed this run")

	var cfg_a: Dictionary = scenario_cfg.duplicate(true)
	cfg_a.seed = 90210
	var run_a: Dictionary = await _fingerprint(cfg_a, STEPS)

	var cfg_b: Dictionary = scenario_cfg.duplicate(true)
	cfg_b.seed = 90210
	var run_b: Dictionary = await _fingerprint(cfg_b, STEPS)

	check(run_a == run_b,
		"SAME seed -> identical run state after %d bot-played steps (SaveConfig.to_config)" % STEPS)

	var cfg_c: Dictionary = scenario_cfg.duplicate(true)
	cfg_c.seed = 90211
	var run_c: Dictionary = await _fingerprint(cfg_c, STEPS)

	check(run_a != run_c,
		"DIFFERENT seed -> diverging run state — without this, the SAME-seed " +
		"check above would pass even if the run never touched g.rng at all")

	print("---")
	if fails == 0:
		print("ALL SEED CHECKS OK")
	quit(1 if fails > 0 else 0)
