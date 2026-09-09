extends SceneTree
## Save/resume round-trip: boot a rich run, serialize it, boot a second game
## from the JSON-round-tripped save, and assert the state is identical.
## Run headless:  godot --headless --path game -s tests/test_save.gd

const GameScript := preload("res://scripts/game.gd")
const Box := preload("res://scripts/box.gd")

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


## Round-trip a live game through JSON exactly as the real save file does.
func _round_trip(g) -> Dictionary:
	return JSON.parse_string(JSON.stringify(g._to_config()))


func _init() -> void:
	# --- RESUME MID-TURN (NO-?? / backgrounding) -----------------------------
	# The save format used to assume every save was taken at a TURN START:
	# apply() ended with _begin_player_turn(), so a mid-turn snapshot came back
	# as a fresh turn. These three cases ARE that bug. Each asserts the resumed
	# game is in the state it was SAVED in, not the state a new turn would be —
	# a test that cannot tell those apart is not testing this.
	var mt := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	await process_frame
	mt.actions_left = 1 # two of three spent this turn
	mt.turn_action_count = 2
	var mt_actions: int = mt.actions_left
	var mt_saved := _round_trip(mt)
	mt.queue_free()
	await process_frame
	var mt_r := _boot(mt_saved)
	await process_frame
	check(mt_r.actions_left == mt_actions,
		"mid-turn resume keeps the actions already spent (%d, got %d)"
			% [mt_actions, mt_r.actions_left])
	check(mt_r.state == GameScript.State.PLAYER_TURN,
		"...and is still the player's turn")
	mt_r.queue_free()
	await process_frame

	# THE SIDE EFFECTS MUST NOT RE-RUN. _begin_player_turn() is not a reset: it
	# dispatches on_turn_start, ages every timed buff, and can spawn a wave.
	# Resuming through it would do all three a second time, and all three favour
	# the player — so a test that only checks "it resumed" passes while the run
	# silently drifts. A timed buff is the clearest independent signal: nothing
	# else in this file would notice it ageing twice.
	var bf := _boot({"board": [["queen", 0, 2, 2, {"buffs": [{"key": "aura", "turns": 2}]}],
		["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	await process_frame
	var turns_before: int = 0
	for e in bf.board[Vector2i(2, 2)].get("buffs", []):
		if e.key == "aura":
			turns_before = int(e.turns)
	check(turns_before > 0, "(setup) the aura buff is on the board with turns left")
	var bf_saved := _round_trip(bf)
	bf.queue_free()
	await process_frame
	var bf_r := _boot(bf_saved)
	await process_frame
	var turns_after: int = -1
	for e in bf_r.board[Vector2i(2, 2)].get("buffs", []):
		if e.key == "aura":
			turns_after = int(e.turns)
	check(turns_after == turns_before,
		"a timed buff does NOT age on resume — %d turns saved, %d restored"
			% [turns_before, turns_after])
	bf_r.queue_free()
	await process_frame

	# MID-CHOICE: come back to the SAME open Box with the SAME options (user
	# ruling 2026-09-09). The offer is persisted, not regenerated — regenerating
	# could hand back a different set after any RNG change, which would be a
	# quieter bug than losing the Box altogether.
	var bx := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3,
		"gold": 500})
	await process_frame
	await process_frame
	bx._open_box_pick({"kind": "box", "key": "item", "size": "small", "sold": false,
		"contents": Box.roll_options(bx, "item", "small")})
	check(bx.box_open, "(setup) a Box pick is open")
	var offer_before := JSON.stringify(bx.box_offer)
	var bx_saved := _round_trip(bx)
	bx.queue_free()
	await process_frame
	var bx_r := _boot(bx_saved)
	await process_frame
	check(bx_r.box_open, "a run backgrounded mid-Box resumes with the Box still open")
	check(JSON.stringify(bx_r.box_offer) == offer_before,
		"...showing the SAME offer, not a re-roll (%s vs %s)"
			% [JSON.stringify(bx_r.box_offer), offer_before])
	bx_r.queue_free()
	await process_frame

	# mid-ENEMY-turn: the old format resumed as the PLAYER's turn, so the
	# enemy's remaining moves were never played — repeatably, every background.
	var et := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	await process_frame
	et.state = et.State.ENEMY_TURN
	var et_saved := _round_trip(et)
	et.queue_free()
	await process_frame
	var et_r := _boot(et_saved)
	await process_frame
	check(et_r.state == GameScript.State.ENEMY_TURN,
		"a save taken mid-ENEMY-turn resumes in ENEMY_TURN, not as a free player turn")
	et_r.queue_free()
	await process_frame

	# mid-SETUP: the old format resumed at a turn start, skipping the free
	# placement phase entirely.
	var st := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 1})
	await process_frame
	await process_frame
	st.state = st.State.SETUP
	var st_saved := _round_trip(st)
	st.queue_free()
	await process_frame
	var st_r := _boot(st_saved)
	await process_frame
	check(st_r.state == GameScript.State.SETUP,
		"a save taken during SETUP resumes in SETUP, not past the free placement")
	st_r.queue_free()
	await process_frame


	var rich := {
		"board": [["queen", 0, 2, 1], ["pawn", 0, 3, 1, "buff"], ["rook", 1, 4, 10]],
		"stock": ["pawn", {"id": "ferz", "buff": true}],
		"captured": ["knight", "knight", "bishop"],
		"items": ["blitz", "sniper"],
		# issue 69 repointed "greed"/"move" (removed game-native keys) to
		# surviving catalog Artefacts of the same held-copy shape.
		"artefacts": ["voynich-dictionary", "voynich-dictionary", "cia-exploding-cigar"],
		"king_abilities": ["inflation", "inflation", "austerity"],
		"oneoffs": [], "wave": 23, "turns_since_wave": 4, "kings_defeated": 1,
		"lost_player": 5, "lost_enemy": 9,
		"pending": [{"id": "bishop"}, {"id": "pawn"}],
		"score": 470, "gold": 35, "clock_s": 812.5, "shop_restocks": 2,
		"shop_lane_b_progress": 6300, # issue 64, Lane B restock progress
		"shop_stock": [{"kind": "piece", "key": "pawn", "sold": true},
			{"kind": "box", "key": "item", "size": "big", "sold": false,
				"contents": [{"kind": "item", "name": "Blitz", "tier": "Tactical",
					"description": "d", "payload": {"key": "blitz"}}]}],
		"skip_enemy_turns": 1, "king_abilities_off": true,
		"ecdysis_copy_key": "voynich-dictionary", # issue 55
		"run_capture_count": 7, # issue 55, Zeta Reticuli Souvenir Map
		"wave_start_lost_player": 3, # review pass 1: `clean` on wave clear compares
			# lost_player against this; a resume that zeroed it denied every
			# clean-wave Artefact for the wave in progress
		"silk_road_active": true, # review pass 1: the coupon's -50% must survive a resume
		# NO-20: the once-per-Wave activation flags and run-long counters.
		# salvation_charged is deliberately set FALSE here — its default is
		# true, so a fixture that left it true would pass even if the field
		# were dropped entirely.
		"zapruder_used_this_wave": true, "bovine_used_this_wave": true,
		"jet_fuel_used_this_wave": true, "uap_used_this_wave": true,
		"torpedo_used_this_wave": true, "hoffa_used_this_wave": true,
		"doomsday_snooze_used_this_wave": true, "arks_bunkbed_used": true,
		"salvation_charged": false,
		"nibiru_wave_streak": 4, "club27_streak": 6,
		"lottery_purchase_count": 3, "pallet_purchase_count": 2,
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
	# NO-20: same missing-from-both-sides trap as run_capture_count above, so
	# these assert the restored VALUES rather than trusting the identity check.
	# Unpersisted, every one of these re-armed on quit-and-Continue — a
	# save-scum path for six player-triggered Artefacts.
	check(b.zapruder_used_this_wave and b.bovine_used_this_wave
			and b.jet_fuel_used_this_wave and b.uap_used_this_wave
			and b.torpedo_used_this_wave and b.hoffa_used_this_wave
			and b.doomsday_snooze_used_this_wave and b.arks_bunkbed_used,
		"NO-20: the eight once-per-Wave activation flags survive a resume — "
		+ "spend, quit, Continue must not re-arm them")
	check(not b.salvation_charged,
		"NO-20: a SPENT Salvation Gift Card stays spent — the field defaults to "
		+ "true, so this is the direction that fails if the key were dropped")
	check(b.nibiru_wave_streak == 4 and b.club27_streak == 6
			and b.lottery_purchase_count == 3 and b.pallet_purchase_count == 2,
		"NO-20: the four run-long counters survive — unpersisted they RESET, "
		+ "silently restarting a cadence mid-run")
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
	check(b.king_abilities_active.size() == 3, "tariff stacks restored")
	check(b.pending_spawn.is_empty(), "pending wave spawned on resume")
	check(b.board.size() >= 5, "pending pieces landed on the board")
	check(b.skip_enemy_turns == 1, "item counters restored")
	check(b.king_abilities_suppressed, "counter-intel suppression restored")
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

	# --- BACKGROUNDING MID-CHOICE (NO-?? review): roll back, don't refuse ----
	# The first cut refused to save while a choice modal or targeting was open,
	# because the continuation is a Callable and cannot be serialised. That
	# threw away the whole turn for a phone call.
	#
	# The continuation never needed serialising. Every choice modal already has
	# a written-down state one step earlier: where its own Cancel lands. That is
	# a state normal play reaches and saves every day, so rolling back to it and
	# saving THERE costs the player one redone decision instead of a turn.
	var rb := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3,
		"gold": 500})
	await process_frame
	await process_frame
	var actions_before: int = rb.actions_left
	rb._open_yalta_pick()
	check(rb.buff_pick_open, "(setup) a choice modal is open")
	rb._rollback_for_save()
	check(not rb.buff_pick_open,
		"backgrounding mid-choice closes the modal instead of refusing to save")
	check(rb.actions_left == actions_before,
		"...and does NOT cost the turn: the actions already spent are still spent, no more")

	# Yalta's trigger — the 5-Wave Milestone — has already fired and will not
	# fire again, so its own Cancel (forfeit, no refund) would take the reward
	# away for backgrounding. Queue it like Bounty instead.
	check(rb.pending_yalta_picks == 1,
		"a Yalta pick open at background is QUEUED, not forfeited — its milestone cannot re-fire")
	var rb_saved := _round_trip(rb)
	rb.queue_free()
	await process_frame
	var rb_r := _boot(rb_saved)
	await process_frame
	check(rb_r.pending_yalta_picks == 1,
		"...and the queued pick survives the save, so the resumed run still owes it")
	rb_r.queue_free()
	await process_frame

	# Bounty is the other one whose caller spends the trigger before opening
	# (the capture path consumes the piece_bounty Buff). It already had the
	# queue for exactly this — _open_bounty_pick defers onto it when a Box is
	# in the way — so backgrounding reuses that rather than inventing a second.
	var bq := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3,
		"gold": 500})
	await process_frame
	await process_frame
	bq._open_bounty_pick()
	check(bq.buff_pick_open, "(setup) a Bounty pick is open")
	bq._rollback_for_save()
	check(bq.pending_bounty_boxes == 1 and not bq.buff_pick_open,
		"a Bounty pick open at background goes back on pending_bounty_boxes, not forfeited")
	bq.queue_free()
	await process_frame

	# Targeting rolls back the same way, and for the plainest reason: nothing is
	# consumed when it opens. _item_reset() IS the pre-targeting state.
	var tg := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3,
		"gold": 500})
	await process_frame
	await process_frame
	tg.artefact_targeting_key = "bovine-tractor-beam"
	tg.army_targeting = true
	tg.army_board_targeting = true
	tg.item_active = 0
	tg._rollback_for_save()
	check(tg.artefact_targeting_key == "" and not tg.army_targeting
			and not tg.army_board_targeting and tg.item_active == -1,
		"every targeting flavour rolls back at background — including the two ARMY ones, "
		+ "which the first cut's guard did not even name")
	tg.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL SAVE CHECKS OK")
	quit(1 if fails > 0 else 0)
