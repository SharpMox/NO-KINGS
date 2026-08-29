extends SceneTree
## Tariff interactions: items that charge or suppress an active tariff
## (ability cost, long-range, counter-intel), and artefacts that intercept
## or modify tariffs (issue 19 on_tariff_apply/charge, issue 22). Split out
## of test_items.gd (issue 37) to keep the tariff seam collision-free.
## Run headless:  godot --headless --path game -s tests/test_items_tariffs.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Economy := preload("res://scripts/economy.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")

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
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _item(key: String, target: String) -> Dictionary:
	return {"key": key, "name": key, "tier": "T", "target": target, "description": ""}


func _init() -> void:
	# --- review bug 4: ability tariff charges when the item is USED, once —
	# cancelling a targeted item costs nothing
	var b := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "score": 500, "tariffs": ["ability_cost"]})
	await process_frame
	b.gold = 500 # tariffs charge gold now (money-and-shop/02)
	b.items.append(_item("demote", "tile"))
	b._use_item(0) # start targeting
	b._use_item(0) # tap again: cancel
	check(b.gold == 500, "cancelled item charges no ability tariff")
	b._use_item(0)
	b._item_click(Vector2i(2, 2)) # complete the use
	check(b.gold == 500 - Tuning.TARIFF_ACTION_COST,
		"completed item charges the ability tariff once")
	b.queue_free()
	await process_frame

	# --- review bug 3: Long-Range tariff covers every rider, not just
	# bishop/rook; leapers stay exempt
	var c := _boot({"board": [["queen", 0, 2, 2], ["knight", 0, 5, 2], ["rook", 1, 7, 10]],
		"wave": 3, "score": 500, "tariffs": ["long_range_cost"]})
	await process_frame
	c.gold = 500
	c._move_player(Vector2i(2, 2), Vector2i(2, 5)) # queen rides 3 squares
	check(c.gold == 500 - 3 * Tuning.TARIFF_LR_PER_SQUARE,
		"riding 3 squares charges 3x the long-range tariff")
	var gold_after: int = c.gold
	c._move_player(Vector2i(5, 2), Vector2i(6, 4)) # knight leap
	check(c.gold == gold_after, "leaps stay exempt from the long-range tariff")
	c.queue_free()
	await process_frame

	# --- counter-intel: suppresses action tariffs for the rest of the wave
	var ci := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "tariffs": ["move_cost"]})
	await process_frame
	ci.gold = 500
	ci.items.append(_item("counter_intel", ""))
	ci._use_item(0)
	ci._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(ci.gold == 500, "counter-intel suppresses the move tariff")
	ci.queue_free()
	await process_frame

	# --- counter-intel: persistent tariffs pause too; the next wave's spawn
	# ends the suppression (CONTEXT.md: Tariff suppression)
	var cj := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "tariffs": ["move_cost", "inflation"]})
	await process_frame
	cj.gold = 500
	cj.items.append(_item("counter_intel", ""))
	cj._use_item(0)
	Economy.earn(cj, 10)
	check(cj.gold == 510, "suppressed inflation taxes no gains")
	cj._refresh()
	check(cj.hud.tariff_button.text.ends_with("·off"), "HUD marks tariffs suppressed")
	WaveLogic.spawn(cj, 4)
	Economy.earn(cj, 10)
	check(cj.gold == 519, "next wave spawn ends the suppression (inflation resumes)")
	cj._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(cj.gold == 519 - Tuning.TARIFF_ACTION_COST,
		"next wave spawn ends the suppression (move tariff resumes)")
	cj.queue_free()
	await process_frame

	# --- issue 19: on_tariff_apply / on_tariff_charge (Merchants of Death
	# Sample Case, Tunguska Toothpicks) — economy.gd's existing choke points
	var tar := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0, "score": 0,
		"artefacts": ["merchants-of-death-sample-case", "tunguska-toothpicks"]})
	await process_frame
	Economy.activate_tariff_by_key(tar, "move_cost")
	check(tar.gold == 100, "Merchants of Death Sample Case: +100 Gold whenever a new Tariff is applied")
	tar.gold = 500
	var clock_tar: float = tar.clock_ms
	Economy.charge(tar, "move_cost")
	check(tar.score == 150 and tar.clock_ms > clock_tar,
		"Tunguska Toothpicks: +150 Score and +5s Clock whenever a Tariff charges you")
	tar.queue_free()
	await process_frame

	# --- issue 22: tariff interception (Panama Papers Shredder, Amber Room
	# Bubble Wrap, Ark Grounding Cable, Salvation Gift Card) ---
	var panama := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 500, "artefacts": ["panama-papers-shredder"],
		"tariffs": ["move_cost", "deploy_cost"]})
	await process_frame
	var g0: int = panama.gold
	Economy.charge(panama, "move_cost")
	check(panama.gold == g0, "Panama Papers Shredder: a Mild Tariff (move_cost) doesn't charge you")
	Economy.charge(panama, "deploy_cost")
	check(panama.gold == g0 - Tuning.TARIFF_ACTION_COST,
		"Panama Papers Shredder: a Moderate Tariff (deploy_cost) still charges you")
	panama.queue_free()
	await process_frame

	var panama2 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0, "artefacts": ["panama-papers-shredder"], "tariffs": ["inflation"]})
	await process_frame
	Economy.earn(panama2, 100)
	check(panama2.gold == 100, "Panama Papers Shredder: Inflation (Mild) doesn't reduce Gold gains")
	panama2.queue_free()
	await process_frame

	var amber := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0, "artefacts": ["amber-room-bubble-wrap"], "tariffs": ["inflation"]})
	await process_frame
	Economy.earn(amber, 100)
	check(amber.gold == 100, "Amber Room Bubble Wrap: ignores Inflation's Gold-gain reduction")
	amber.queue_free()
	await process_frame

	var ark := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 500, "artefacts": ["ark-grounding-cable"], "tariffs": ["move_cost"]})
	await process_frame
	var g_ark: int = ark.gold
	Economy.charge(ark, "move_cost")
	check(ark.gold == g_ark - roundi(Tuning.TARIFF_ACTION_COST * 0.5),
		"Ark Grounding Cable: Tariff penalties reduced by 50%")
	ark.queue_free()
	await process_frame

	var salvation := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 0, "artefacts": ["salvation-gift-card"]})
	await process_frame
	Economy.activate_tariff_by_key(salvation, "sanctions")
	check(salvation.tariffs_active.is_empty() and salvation.sanctioned_id == "",
		"Salvation Gift Card: the first Tariff applied is cancelled")
	check(not salvation.salvation_charged, "Salvation Gift Card: spent after cancelling")
	Economy.activate_tariff_by_key(salvation, "regulation")
	check(salvation.tariffs_active.size() == 1 and salvation.tariffs_active[0].key == "regulation",
		"Salvation Gift Card: a second Tariff applies normally once spent")
	salvation.artefacts[0].acquired_wave = 1 # per-artefact cadence (2026-08-28):
		# isolate the handler's own math from acquisition-stamping coverage below
	WaveLogic.queue(salvation, 6) # clears wave 5, this copy's own 5-Wave Milestone: recharges
	check(salvation.salvation_charged, "Salvation Gift Card: recharges at the 5-Wave Milestone")
	salvation.queue_free()
	await process_frame

	# --- issue 45: Y2K Patch Floppy Disk (on_wave_spawn arms, on_enemy_turn_
	# start consumes) — grouped here, not in an items_artefacts_*.gd file,
	# because its own spec calls out checking the Filibuster interaction
	var y2k := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["y2k-patch-floppy-disk"]})
	await process_frame
	check(Economy.enemy_actions(y2k) == Tuning.ENEMY_ACTIONS_PER_TURN,
		"(control) unarmed (no Wave has started yet): a normal enemy Turn")
	WaveLogic.queue(y2k, y2k.wave + 1) # Wave 4 starts: on_wave_spawn arms Y2K
	check(Economy.enemy_actions(y2k) == 0,
		"Y2K Patch Floppy Disk: the enemy's first Turn of the Wave has 0 actions")
	check(Economy.enemy_actions(y2k) == Tuning.ENEMY_ACTIONS_PER_TURN,
		"Y2K Patch Floppy Disk: only the first enemy Turn is skipped — the next is normal")
	y2k.queue_free()
	await process_frame

	# held twice: still skips exactly ONE Turn, not two — the explicit
	# exception to additive stacking (artefact_hooks.gd's own comment there)
	var y2k2 := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["y2k-patch-floppy-disk", "y2k-patch-floppy-disk"]})
	await process_frame
	WaveLogic.queue(y2k2, y2k2.wave + 1)
	check(Economy.enemy_actions(y2k2) == 0,
		"Y2K Patch Floppy Disk x2: the first enemy Turn is still 0 actions, not negative")
	check(Economy.enemy_actions(y2k2) == Tuning.ENEMY_ACTIONS_PER_TURN,
		"Y2K Patch Floppy Disk x2: the second enemy Turn is normal — 2 held copies don't skip 2 Turns")
	y2k2.queue_free()
	await process_frame

	# Y2K + Filibuster on the same hook: run() always dispatches the
	# artefacts group before the tariffs group (header's "Tariff/artefact
	# ordering" note), so Y2K's zeroed ctx.actions is always the base
	# Filibuster's own "+1" composes on top of — deterministic by group
	# order, never by where the two keys happen to alphabetically sort
	# (they're in different groups, so that comparison never runs).
	var y2kf := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["y2k-patch-floppy-disk"], "tariffs": ["filibuster"]})
	await process_frame
	WaveLogic.queue(y2kf, y2kf.wave + 1)
	check(Economy.enemy_actions(y2kf) == 1,
		"Y2K + Filibuster: the first enemy Turn gets exactly Filibuster's own +1 (Y2K's base cancelled, not the tariff's)")
	check(Economy.enemy_actions(y2kf) == Tuning.ENEMY_ACTIONS_PER_TURN + 1,
		"Y2K + Filibuster: the second enemy Turn is Filibuster's usual +1 on top of the normal Turn")
	y2kf.queue_free()
	await process_frame

	# --- issue 54: Exhibit 399, dormant — Tuning.TARIFFS_SCHEDULED is false
	# (2026-08-29 ruling), so Tariffs never activate in a live run and this
	# can only be exercised by driving economy.gd's apply_tariff/
	# activate_tariff_by_key directly, as below. NOT exercised in a live run.
	# SETI's Red Marker stays implemented: false (a per-Tariff "equivalent
	# bonus" table doesn't exist in data/tariffs.gd — issue 22's gap, not
	# resolved by issue 54 either — a Notion question, not a guess), so it
	# has no test here. ---
	check(not Tuning.TARIFFS_SCHEDULED,
		"(context) Tariffs are off in a live run — Exhibit 399 below is only ever driven directly")

	var ex_ctrl := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 4})
	await process_frame
	Economy.activate_tariff_by_key(ex_ctrl, "move_cost")
	check(not ex_ctrl.buff_pick_open and ex_ctrl.tariffs_active.size() == 1,
		"control: without Exhibit 399, a Tariff applies immediately, no choice pick")
	ex_ctrl.queue_free()
	await process_frame

	var ex_apply := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 4,
		"artefacts": ["exhibit-399"]})
	await process_frame
	Economy.activate_tariff_by_key(ex_apply, "move_cost")
	check(ex_apply.buff_pick_open and ex_apply.tariffs_active.is_empty(),
		"Exhibit 399: opens the choice pick instead of applying immediately")
	ex_apply.modals.choice_chosen.emit(true) # "Let it apply"
	check(not ex_apply.buff_pick_open and ex_apply.tariffs_active.size() == 1 \
			and ex_apply.tariffs_active[0].key == "move_cost",
		"Exhibit 399: 'Let it apply' resolves the Tariff normally")
	ex_apply.queue_free()
	await process_frame

	var ex_block := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 4,
		"artefacts": ["exhibit-399"]})
	await process_frame
	Economy.activate_tariff_by_key(ex_block, "move_cost")
	check(ex_block.buff_pick_open, "(setup) the choice pick is open")
	ex_block.modals.choice_pick_cancelled.emit() # "Block it"
	check(not ex_block.buff_pick_open and ex_block.tariffs_active.is_empty(),
		"Exhibit 399: 'Block it' — the Tariff never lands")
	ex_block.queue_free()
	await process_frame

	# same-hook reward handlers still fire regardless of the pending pick
	# (Salvation Gift Card precedent, artefact_hooks.gd header)
	var ex_reward := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 4, "gold": 0,
		"artefacts": ["exhibit-399", "merchants-of-death-sample-case"]})
	await process_frame
	Economy.activate_tariff_by_key(ex_reward, "move_cost")
	check(ex_reward.gold == 100 and ex_reward.buff_pick_open,
		"Exhibit 399 + Merchants of Death Sample Case: the reward pays immediately, independent of the pending pick")
	ex_reward.queue_free()
	await process_frame


	print("---")
	if fails == 0:
		print("ALL TARIFF CHECKS OK")
	quit(1 if fails > 0 else 0)
