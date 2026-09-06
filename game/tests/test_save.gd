extends SceneTree
## Save/resume round-trip: boot a rich run, serialize it, boot a second game
## from the JSON-round-tripped save, and assert the state is identical.
## Run headless:  godot --headless --path game -s tests/test_save.gd

const GameScript := preload("res://scripts/game.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


## Fixtures are deterministic by default (slice 36: a flaky suite makes every
## green claim unfalsifiable). Pass a "seed" in cfg, or seed_it=false, to opt
## out — only for a test that genuinely wants variance.
const DEFAULT_SEED := 1


func _boot(cfg: Dictionary, seed_it: bool = true) -> Node2D:
	if seed_it and not cfg.has("seed"):
		cfg = cfg.duplicate()
		cfg.seed = DEFAULT_SEED
	GameScript.next_config = cfg
	GameScript.is_scenario = true # keep the probe from touching the real save
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _init() -> void:
	var rich := {
		"board": [["queen", 0, 2, 1], ["pawn", 0, 3, 1, "buff"], ["rook", 1, 4, 10]],
		"stock": ["pawn", {"id": "ferz", "buff": true}],
		"captured": ["knight", "knight", "bishop"],
		"items": ["blitz", "sniper"],
		# issue 69 repointed "greed"/"move" (removed game-native keys) to
		# surviving catalog Artefacts of the same held-copy shape.
		"artefacts": ["voynich-dictionary", "voynich-dictionary", "cia-exploding-cigar"],
		"tariffs": ["inflation", "inflation", "austerity"],
		"oneoffs": [], "wave": 23, "turns_since_wave": 4, "kings_defeated": 1,
		"lost_player": 5, "lost_enemy": 9,
		"pending": [{"id": "bishop"}, {"id": "pawn"}],
		"score": 470, "gold": 35, "clock_s": 812.5, "shop_restocks": 2,
		"shop_lane_b_progress": 6300, # issue 64, Lane B restock progress
		"shop_stock": [{"kind": "piece", "key": "pawn", "sold": true},
			{"kind": "box", "key": "item", "size": "big", "sold": false,
				"contents": [{"kind": "item", "name": "Blitz", "tier": "Tactical",
					"description": "d", "payload": {"key": "blitz"}}]}],
		"skip_enemy_turns": 1, "tariffs_off": true,
		"ecdysis_copy_key": "voynich-dictionary", # issue 55
		"run_capture_count": 7, # issue 55, Zeta Reticuli Souvenir Map
		"wave_start_lost_player": 3, # review pass 1: `clean` on wave clear compares
			# lost_player against this; a resume that zeroed it denied every
			# clean-wave Artefact for the wave in progress
		"silk_road_active": true, # review pass 1: the coupon's -50% must survive a resume
		"family_ability_used_this_wave": true, # issue 67 — note the SAVE KEY
			# deliberately kept its old name in issue 76 while the in-memory
			# symbol became army_*: renaming a persisted key is not additive and
			# would need a migration for no player-visible gain
	}
	var a := _boot(rich)
	await process_frame
	var saved: Dictionary = a._to_config()
	a.queue_free()
	await process_frame

	# through JSON, like the real save file
	var restored: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var b := _boot(restored)
	await process_frame

	var again: Dictionary = b._to_config()
	check(absf(again.clock_s - saved.clock_s) < 0.5, "clock survives (minus live ticking)")
	again.erase("clock_s") # the clock ticks between frames; compared above
	saved.erase("clock_s")
	check(JSON.stringify(again) == JSON.stringify(saved), "save -> load -> save is identical")
	for k in saved:
		if JSON.stringify(saved[k]) != JSON.stringify(again.get(k)):
			print("DIFF %s: %s -> %s" % [k, JSON.stringify(saved[k]), JSON.stringify(again.get(k))])
	check(b.score == 470, "score restored")
	check(b.run_capture_count == 7,
		"issue 55: the run-long Capture counter survives a resume — Zeta Reticuli's "
		+ "\"every 3rd Capture\" cadence must not restart at 0 on load. The generic "
		+ "save->load->save identity check cannot catch this: a field missing from the "
		+ "save entirely is absent from BOTH sides and compares equal.")
	check(b.gold == 35, "gold restored")
	check(b.army_ability_used_this_wave == true,
		"issue 67: the Army Ability's once-per-Wave flag survives a resume — same trap as "
		+ "run_capture_count/shop_lane_b_progress above, a field missing from the save is "
		+ "absent from BOTH sides of the generic identity check and compares equal, so this "
		+ "asserts the actual restored VALUE instead of trusting the identity check alone")
	check(b.wave_start_lost_player == 3 and b.silk_road_active,
		"review pass 1: the wave-in-progress snapshot (wave_start_lost_player) and Silk Road "
		+ "Coupon's active discount survive a resume — same missing-from-both-sides trap as above")
	check(b.shop_stock.size() == 2 and b.shop_stock[0].sold and not b.shop_stock[1].sold,
		"shop slots and SOLD flags restored")
	check(b.shop_stock[1].size == "big" and b.shop_stock[1].contents.size() == 1
			and b.shop_stock[1].contents[0].name == "Blitz",
		"a stocked Box's size + rolled contents survive the save round-trip (issue 47) — "
		+ "additive fields, no migration needed")
	check(b.shop_restocks == 2, "the restock marker survives (no reroll-scumming)")
	check(b.shop_lane_b_progress == 6300,
		"issue 64: Lane B's restock progress (Score banked since the last Lane-A restock) "
		+ "survives a resume — same trap issue 55's run_capture_count caught above: a field "
		+ "missing from the save is absent from BOTH sides of the generic identity check and "
		+ "compares equal, so this asserts the actual restored VALUE instead")
	check(b.wave == 23 and b.turns_since_wave == 4, "wave clock restored")
	check(b.kings_defeated == 1, "kings defeated restored")
	check(b.lost_player == 5 and b.lost_enemy == 9, "loss counters restored")
	check(b.artefacts.size() == 3, "artefact stacks restored")
	check(b.tariffs_active.size() == 3, "tariff stacks restored")
	check(b.pending_spawn.is_empty(), "pending wave spawned on resume")
	check(b.board.size() >= 5, "pending pieces landed on the board")
	check(b.skip_enemy_turns == 1, "item counters restored")
	check(b.tariffs_suppressed, "counter-intel suppression restored")
	check(b.stock.has({"id": "ferz", "buff": true}) and b.stock.has("pawn"),
		"mixed String/Dictionary stock survives the JSON round-trip (ADR-0002)")
	var buffed := 0
	for pos in b.board:
		if b.board[pos].get("buff", false):
			buffed += 1
	check(buffed == 1, "the legacy box-carrier flag on a board piece (pre-issue-47 saves) survives " +
		"the round trip — issue 47 removed the flag's transfer onto a newly spawned piece " +
		"(wave_logic.gd), so a pending-spawn entry carrying it no longer produces a second one")

	# --- issue 25: a piece's capture ledger (lifetime `captures` + Wave-scoped
	# `wave_captures`) survives the JSON round-trip on both board and Stock —
	# ADR-0002's opaque pass-through, same mechanism Piece Buffs already ride.
	# A separate, single round-trip (not folded into the "identical" check
	# above): JSON.parse_string returns floats for JSON numbers, and neither
	# Dictionary `==`/`has()` nor JSON.stringify string-compare treat 2 and
	# 2.0 as equal the way a bare `==` on the field does — this checks the
	# value actually read back, not a byte-identical re-serialization.
	var ledger := _boot({"board": [["knight", 0, 5, 1, {"captures": 2, "wave_captures": 1}],
			["rook", 1, 7, 10]], # a live enemy, so boot doesn't read as "board
			# cleared early" and advance straight into next Wave's own reset
		"stock": ["pawn", {"id": "rook", "captures": 3}], "wave": 3})
	await process_frame
	var ledger_saved: Dictionary = ledger._to_config()
	ledger.queue_free()
	await process_frame
	var ledger_restored := _boot(JSON.parse_string(JSON.stringify(ledger_saved)))
	await process_frame
	check(ledger_restored.board[Vector2i(5, 1)].get("captures", 0) == 2
		and ledger_restored.board[Vector2i(5, 1)].get("wave_captures", 0) == 1,
		"issue 25: a board piece's capture ledger (lifetime + Wave-scoped) survives the JSON round-trip")
	var restored_rook: Variant = null
	for e in ledger_restored.stock:
		if e is Dictionary and e.get("id") == "rook":
			restored_rook = e
	check(restored_rook != null and restored_rook.get("captures", 0) == 3,
		"issue 25: a piece's lifetime capture ledger rides along into Stock (ADR-0002), same as a Piece Buff")
	ledger_restored.queue_free()
	await process_frame

	# --- GDD Game Flow — Run: the seed rides along, so resuming a save rolls
	# exactly what an uninterrupted run would have rolled from that point.
	var live := _boot({"board": [["rook", 1, 4, 10]], "wave": 3})
	await process_frame
	live.rng.seed = 424242
	for i in 5: # burn some stream so the save is captured mid-sequence
		live.rng.randi()
	var mid: Dictionary = live._to_config()
	var expected := []
	for i in 8:
		expected.append(live.rng.randi())
	live.queue_free()
	await process_frame

	# round-trip through JSON, exactly as the real save file does
	var resumed := _boot(JSON.parse_string(JSON.stringify(mid)))
	await process_frame
	var got := []
	for i in 8:
		got.append(resumed.rng.randi())
	check(int(mid.seed) == 424242, "the seed is captured in the save")
	check(got == expected, "a resumed save continues the same RNG stream")
	resumed.queue_free()
	await process_frame

	# a fresh run without a seed still varies — opt out of the fixture's
	# default pin (slice 36) since this checks the real randomize() path
	var fresh := _boot({"board": [["rook", 1, 4, 10]], "wave": 3}, false)
	await process_frame
	check(fresh.rng.seed != 0, "an unpinned run still gets a random seed")
	fresh.queue_free()
	await process_frame

	# --- issue 38: schema versioning. A save written before `save_version`
	# existed must still load — proven against a hand-built v0 fixture, not a
	# live save, so the check keeps working once no v0 saves exist anywhere.
	const SaveConfig := preload("res://scripts/save_config.gd")
	var v0 := {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3,
		"score": 120, "gold": 45}
	check(not v0.has("save_version"), "the v0 fixture genuinely predates the field")
	var walked: Dictionary = SaveConfig.migrate(v0.duplicate(true))
	check(int(walked.save_version) == SaveConfig.SAVE_VERSION,
		"migrate() walks an unversioned save up to the current version")
	var old_save := _boot(v0.duplicate(true))
	await process_frame
	check(old_save.score == 120 and old_save.gold == 45,
		"a pre-versioning save still loads with its state intact")
	old_save.queue_free()
	await process_frame

	# --- issue 69: v1 -> v2 migration. Removing the 7 game-native core
	# Artefacts (first_capture_extra/greed/move/lifesteal/score/timer/bounty)
	# is NOT additive — an old v1 save can hold a removed key in `artefacts`
	# and/or point `ecdysis_copy_key` at one. Proven two ways: directly
	# against SaveConfig.migrate() (fails if _MIGRATIONS were emptied back
	# out, independent of apply()'s own incidental catalog-match filtering
	# of `artefacts`), and against a live boot's restored state — not
	# identity, the generic save->load->save check above can't catch this
	# class of bug (same trap run_capture_count/army_ability_used_this_wave
	# caught above).
	var v1_migrate := {"save_version": 1,
		"artefacts": ["greed", "voynich-dictionary", "move"], "ecdysis_copy_key": "greed"}
	var migrated: Dictionary = SaveConfig.migrate(v1_migrate.duplicate(true))
	check(int(migrated.save_version) == SaveConfig.SAVE_VERSION,
		"issue 69: migrate() walks a v1 save up to the current version")
	check(migrated.artefacts == ["voynich-dictionary"],
		"issue 69: migrate() filters the removed core Artefact keys (\"greed\", \"move\") " +
		"out of a v1 save's held artefacts, leaving the surviving catalog key")
	check(migrated.ecdysis_copy_key == "",
		"issue 69: migrate() clears ecdysis_copy_key when it names a removed core Artefact key")

	var v1_boot := {"save_version": 1, "board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3,
		"artefacts": ["greed", "voynich-dictionary", "move"], "ecdysis_copy_key": "greed"}
	var migrated_run := _boot(v1_boot.duplicate(true))
	await process_frame
	check(migrated_run.artefacts.size() == 1 and migrated_run.artefacts[0].key == "voynich-dictionary",
		"issue 69: a v1 save containing \"greed\" loads cleanly with the removed entry gone")
	check(migrated_run.ecdysis_copy_key == "",
		"issue 69: a v1 save's ecdysis_copy_key naming a removed core Artefact is cleared on load — " +
		"apply() copies this field verbatim with no catalog check of its own, so this assertion " +
		"fails outright if the migration were absent")
	migrated_run.queue_free()
	await process_frame

	var stamped: Dictionary = _boot({"board": [["rook", 1, 7, 10]], "wave": 3})._to_config()
	await process_frame
	check(int(stamped.get("save_version", -1)) == SaveConfig.SAVE_VERSION,
		"every save written now carries the current version")

	# --- a71f574: Restart always RE-ROLLS. next_config/next_seed are statics,
	# so they survived reload_current_scene() and a run entered via Continue
	# restarted into its own mid-run snapshot forever — one button meaning two
	# different things depending on how the run began. It shipped untested;
	# this pins it, because the regression is silent and only reachable through
	# the Continue-then-Restart sequence.
	#
	# Asserted on the statics rather than by driving the button: they are
	# exactly what game.gd's _ready branches on at the next boot, so they are
	# the observable consequence, not a flag the test just wrote.
	#
	# reload_current_scene() is a no-op here (this SceneTree has no
	# current_scene) and prints one engine ERROR per press — not a SCRIPT ERROR
	# and not a non-zero exit, so run_all.sh's failure predicate does not see
	# it. Do NOT "fix" that by assigning current_scene: the deferred scene
	# change memdeletes it and `rs` below becomes a freed instance.
	const Tuning := preload("res://scripts/tuning.gd")
	var rs := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	GameScript.next_config = {"wave": 42}
	GameScript.next_seed = "hunter2"
	GameScript.next_army = "Cult"
	GameScript.next_tier = "Tier 3"
	GameScript.is_scenario = false # the real-run branch...
	rs.modals.restart_pressed.emit()
	GameScript.is_scenario = true # ...restored with NO await between these two
		# lines: _autosave is a no-op only while it is true, and this suite must
		# never write over the player's real save.
	check(GameScript.next_config.is_empty(),
		"Restart clears next_config — a Continue-entered run re-rolls instead of replaying its own snapshot")
	check(GameScript.next_seed == "",
		"Restart clears next_seed — replaying an exact seed is the seed system's job, not Restart's")
	check(GameScript.next_army == "Cult" and GameScript.next_tier == "Tier 3",
		"...but army and tier survive the press: SETUP reads them back off the statics")

	GameScript.next_config = {"wave": 42}
	GameScript.next_seed = "hunter2"
	rs.modals.restart_pressed.emit() # is_scenario is true again
	check(GameScript.next_config == {"wave": 42} and GameScript.next_seed == "hunter2",
		"a TEST scenario's Restart keeps its config and seed — a scenario must keep replaying")
	rs.queue_free()
	await process_frame
	GameScript.next_army = Tuning.DEFAULT_ARMY
	GameScript.next_tier = Tuning.DEFAULT_TIER
	GameScript.next_config = {}
	GameScript.next_seed = ""

	print("---")
	if fails == 0:
		print("ALL SAVE CHECKS OK")
	quit(1 if fails > 0 else 0)
