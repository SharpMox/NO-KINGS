extends SceneTree
## Tariff interactions: items that charge or suppress an active tariff
## (ability cost, long-range, counter-intel), and artefacts that intercept
## or modify tariffs (issue 19 on_king_ability_apply/charge, issue 22). Split out
## of test_items.gd (issue 37) to keep the tariff seam collision-free.
## Run headless:  godot --headless --path game -s tests/test_items_king_abilities.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Economy := preload("res://scripts/economy.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const Shop := preload("res://scripts/shop.gd")
const Kings := preload("res://data/kings.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd") # NO-103
const ItemLogic := preload("res://scripts/item_logic.gd") # NO-103
const Items := preload("res://data/items.gd") # NO-103

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


## NO-113: prints the observed value on failure, so a numeric failure needs no
## instrument-and-rerun round trip. Use it for any assertion on an amount.
func check_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		check(true, label)
	else:
		check(false, "%s — expected %s, got %s" % [label, expected, actual])


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
	# NO-105: tier must be a real Tuning.SHOP_ITEM_PRICE key — Tariff on Item
	# now prices off it (Economy.tariff_cut), so a placeholder tier errors.
	return {"key": key, "name": key, "tier": "Tactical", "target": target, "description": ""}


func _init() -> void:
	# --- review bug 4: ability tariff charges when the item is USED, once —
	# cancelling a targeted item costs nothing
	var b := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "score": 500, "king_abilities": ["ability_cost"]})
	await process_frame
	b.gold = 500 # tariffs charge gold now (money-and-shop/02)
	b.items.append(_item("demote", "tile"))
	b._use_item(0) # start targeting
	b._use_item(0) # tap again: cancel
	check(b.gold == 500, "cancelled item charges no ability tariff")
	b._use_item(0)
	b._item_click(Vector2i(2, 2)) # complete the use
	check(b.gold == 500 - Economy.tariff_cut(Tuning.SHOP_ITEM_PRICE["Tactical"], Tuning.TARIFF_ITEM_PCT),
		"completed item charges the ability tariff once")
	b.queue_free()
	await process_frame

	# --- review bug 3: Long-Range tariff covers every rider, not just
	# bishop/rook; leapers stay exempt
	var c := _boot({"board": [["queen", 0, 2, 2], ["knight", 0, 5, 2], ["rook", 1, 7, 10]],
		"wave": 3, "score": 500, "king_abilities": ["long_range_cost"]})
	await process_frame
	c.gold = 500
	c._move_player(Vector2i(2, 2), Vector2i(2, 5)) # queen rides 3 squares
	check(c.gold == 500 - 3 * Economy.tariff_cut(c.defs["queen"].value, Tuning.TARIFF_LR_PCT),
		"riding 3 squares charges 3x the long-range tariff")
	# NO-105: the held-check itself, because the bug it replaces was a guard
	# that silently answered false forever — "nothing was charged" cannot
	# tell a working exemption from a dead code path.
	check(Economy.tariff_fires(c, "long_range_cost"),
		"tariff_fires: a held tariff answers true")
	check(not Economy.tariff_fires(c, "move_cost"),
		"tariff_fires: an unheld tariff answers false")
	var gold_after: int = c.gold
	c._move_player(Vector2i(5, 2), Vector2i(6, 4)) # knight leap
	check(c.gold == gold_after, "leaps stay exempt from the long-range tariff")
	c.queue_free()
	await process_frame

	# --- counter-intel: suppresses action tariffs for the rest of the wave
	var ci := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "king_abilities": ["move_cost"]})
	await process_frame
	ci.gold = 500
	ci.items.append(_item("counter_intel", ""))
	ci._use_item(0)
	ci._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(ci.gold == 500, "counter-intel suppresses the move tariff")
	check(not Economy.tariff_fires(ci, "move_cost"),
		"tariff_fires: suppression makes a held tariff answer false")
	ci.queue_free()
	await process_frame

	# --- counter-intel: persistent tariffs pause too; the next wave's spawn
	# ends the suppression (CONTEXT.md: Tariff suppression)
	# NO-105: only Move is held here (no Long-Range), so a rider still pays
	# the Move Tariff — Long-Range only preempts it when Long-Range is
	# itself held (see the ADR).
	var cj := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "king_abilities": ["move_cost", "inflation"]})
	await process_frame
	cj.gold = 500
	cj.items.append(_item("counter_intel", ""))
	cj._use_item(0)
	Economy.earn(cj, 10)
	check(cj.gold == 510, "suppressed inflation taxes no gains")
	cj._refresh()
	check(cj.hud.king_ability_button.text.ends_with("·off"), "HUD marks tariffs suppressed")
	WaveLogic.spawn(cj, 4)
	Economy.earn(cj, 10)
	check(cj.gold == 519, "next wave spawn ends the suppression (inflation resumes)")
	cj._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(cj.gold == 519 - Economy.tariff_cut(cj.defs["queen"].value, Tuning.TARIFF_MOVE_PCT),
		"next wave spawn ends the suppression (move tariff resumes)")
	cj.queue_free()
	await process_frame

	# --- issue 19: on_king_ability_apply / on_king_ability_charge (Merchants of Death
	# Sample Case, Tunguska Toothpicks) — economy.gd's existing choke points
	var tar := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 0, "score": 0,
		"artefacts": ["merchants-of-death-sample-case", "tunguska-toothpicks"]})
	await process_frame
	Economy.activate_king_ability_by_key(tar, "move_cost")
	check(tar.gold == 100, "Merchants of Death Sample Case: +100 Gold whenever a new Tariff is applied")
	tar.gold = 500
	var clock_tar: float = tar.clock_ms
	Economy.charge(tar, "move_cost")
	check(tar.score == 1500 and tar.clock_ms > clock_tar, # issue 57: x10
		"Tunguska Toothpicks: +150 Score and +5s Clock whenever a Tariff charges you")
	tar.queue_free()
	await process_frame

	# --- issue 22: tariff interception (Panama Papers Shredder, Amber Room
	# Bubble Wrap, Ark Grounding Cable, Salvation Gift Card) ---
	var panama := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 500, "artefacts": ["panama-papers-shredder"],
		"king_abilities": ["move_cost", "deploy_cost"]})
	await process_frame
	var g0: int = panama.gold
	Economy.charge(panama, "move_cost")
	check(panama.gold == g0, "Panama Papers Shredder: a Mild Tariff (move_cost) doesn't charge you")
	Economy.charge(panama, "deploy_cost")
	check(panama.gold == g0 - Tuning.KING_ABILITY_ACTION_COST,
		"Panama Papers Shredder: a Moderate Tariff (deploy_cost) still charges you")
	panama.queue_free()
	await process_frame

	# NO-95: Tariff on Gold Gain reaches play through Donald Trump's Power, second
	# in his escalation, so it is driven through his Wave here rather than
	# seeded. Once with nothing held, then against each gain-immunity Artefact.
	for held: String in ["", "panama-papers-shredder", "amber-room-bubble-wrap"]:
		var dt := _boot({"board": [], "wave": 49, "artefacts": [held] if held != "" else []})
		await process_frame
		await process_frame
		dt.king_order = ["donald_trump", "nero", "xerxes_i", "qin_shi_huang"]
		dt._queue_wave(50)
		var label := held if held != "" else "nothing held"
		check(not dt.king_power_abilities.has("inflation"),
			"Trump's Wave (%s): Tariff on Gold Gain is not in force at turn 0" % label)
		dt.turns_since_wave = Tuning.KING_TARIFF_STACK_TURNS
		Kings.stack_power_if_due(dt)
		check(dt.king_power_abilities.has("inflation"),
			"Trump's Wave (%s): Tariff on Gold Gain comes into force at turn %d" % [label, Tuning.KING_TARIFF_STACK_TURNS])
		dt.gold = 0
		Economy.earn(dt, 100)
		var want := 90 if held == "" else 100
		check(dt.gold == want, "Trump's Wave (%s): earning 100 Gold pays %d (got %d)" % [label, want, dt.gold])
		dt.queue_free()
		await process_frame

	var ark := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 500, "artefacts": ["ark-grounding-cable"], "king_abilities": ["move_cost"]})
	await process_frame
	var g_ark: int = ark.gold
	Economy.charge(ark, "move_cost")
	check(ark.gold == g_ark - roundi(Tuning.KING_ABILITY_ACTION_COST * 0.5),
		"Ark Grounding Cable: Tariff penalties reduced by 50%")
	ark.queue_free()
	await process_frame

	var salvation := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 0, "artefacts": ["salvation-gift-card"]})
	await process_frame
	Economy.activate_king_ability_by_key(salvation, "move_cost")
	check(salvation.king_abilities_active.is_empty(),
		"Salvation Gift Card: the first Tariff applied is cancelled")
	check(not salvation.salvation_charged, "Salvation Gift Card: spent after cancelling")
	Economy.activate_king_ability_by_key(salvation, "capture_cost")
	check(salvation.king_abilities_active.size() == 1 and salvation.king_abilities_active[0].key == "capture_cost",
		"Salvation Gift Card: a second Tariff applies normally once spent")
	salvation.artefacts[0].acquired_wave = 1 # per-artefact cadence (2026-08-28):
		# isolate the handler's own math from acquisition-stamping coverage below
	WaveLogic.queue(salvation, 6) # clears wave 5, this copy's own 5-Wave Milestone: recharges
	check(salvation.salvation_charged, "Salvation Gift Card: recharges at the 5-Wave Milestone")
	salvation.queue_free()
	await process_frame

	# --- issue 45: Y2K Patch Floppy Disk (on_wave_spawn arms, on_enemy_turn_
	# start consumes)
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

	# issue 59: Tier 5 doubles the enemy's base — Y2K still skips exactly ONE
	# enemy Turn on top of that tier value.
	GameScript.next_tier = "Tier 5"
	var y2k5 := _boot({"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["y2k-patch-floppy-disk"]})
	await process_frame
	check(Economy.enemy_actions(y2k5) == 2,
		"(control) Tier 5, unarmed: the enemy's base Turn is 2 actions (issue 59)")
	WaveLogic.queue(y2k5, y2k5.wave + 1)
	check(Economy.enemy_actions(y2k5) == 0,
		"Y2K at Tier 5: the enemy's first Turn of the Wave is still 0 actions, not 1")
	check(Economy.enemy_actions(y2k5) == 2,
		"Y2K at Tier 5: the next Turn is back to the normal Tier-5 2 actions")
	y2k5.queue_free()
	await process_frame
	GameScript.next_tier = Tuning.DEFAULT_TIER

	# --- NO-81: Exhibit 399 no longer intercepts King Abilities (it is a capture
	# trigger now, test_items_artefacts_2.gd). Held through Donald Trump's Wave,
	# his Tariff lands at once and no choice modal opens.
	var ex_trump := _boot({"board": [], "wave": 49, "artefacts": ["exhibit-399"]})
	await process_frame
	await process_frame
	ex_trump.king_order = ["donald_trump", "nero", "xerxes_i", "qin_shi_huang"]
	ex_trump._queue_wave(50)
	var trump_live := false
	for a in ex_trump.king_abilities_active:
		trump_live = trump_live or ex_trump.king_power_abilities.has(a.get("key", ""))
	check(trump_live and not ex_trump.buff_pick_open,
		"Exhibit 399: Donald Trump's Tariff applies immediately — the old choice modal never opens")
	ex_trump.queue_free()
	await process_frame

	# --- issue 56: SETI's Red Marker, redesigned — "on acquiring this
	# Artefact: remove a random active Tariff (if any), and open a Big
	# Artefact Box." The Box opening is UNCONDITIONAL — the one thing that
	# matters, since a Tariff is active only during Donald Trump's Wave, so the
	# no-Tariff-active case (asserted first) is the common one.
	var seti_live := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 999})
	await process_frame
	check(seti_live.king_abilities_active.is_empty(), "setup: no Tariff active — the live-run case")
	seti_live.state = seti_live.State.PLAYER_TURN
	seti_live.actions_left = 2
	seti_live.shop_stock = [{"kind": "artefact", "key": "seti-s-red-marker", "sold": false}]
	Shop.buy(seti_live, 0)
	check(seti_live.king_abilities_active.is_empty(),
		"SETI's Red Marker: still no Tariff active — nothing to remove, and that's fine")
	check(seti_live.box_open and seti_live.box_only_kind == "artefact" and seti_live.box_size == "big",
		"SETI's Red Marker: opens a Big Artefact Box regardless — the whole point of the redesign")
	check(seti_live.box_offer.size() == 5, "Big Box: 5 choices")
	seti_live.queue_free()
	await process_frame

	# The Tariff-removal half, with a Tariff seeded directly.
	var seti_tar := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 999, "king_abilities": ["move_cost"]})
	await process_frame
	check(seti_tar.king_abilities_active.size() == 1, "setup: one Tariff active, driven directly")
	seti_tar.state = seti_tar.State.PLAYER_TURN
	seti_tar.actions_left = 2
	seti_tar.shop_stock = [{"kind": "artefact", "key": "seti-s-red-marker", "sold": false}]
	Shop.buy(seti_tar, 0)
	check(seti_tar.king_abilities_active.is_empty(), "SETI's Red Marker: removes the one active Tariff")
	check(seti_tar.box_open and seti_tar.box_only_kind == "artefact" and seti_tar.box_size == "big",
		"SETI's Red Marker: still opens its Big Artefact Box when a Tariff WAS removed too")
	seti_tar.queue_free()
	await process_frame

	# --- review pass 3: the echo layer's `fired` counted TARIFFS as "your
	# Artefacts". Bilderberg paid +15 on one Artefact + one Tariff firing
	# together, and Mona Lisa's "first Artefact trigger each Turn" echoed a
	# live Tariff on Gold Gain into a second -10% (reachable via Trump's Power).
	var bil := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 4, "gold": 0,
		"artefacts": ["bilderberg-hotel-slippers", "panama-papers-shredder"], "king_abilities": ["inflation"]})
	await process_frame
	bil.gold = 0
	Economy.gain(bil, 100)
	check(bil.gold == 0,
		"review pass 3: Bilderberg counts your Artefacts only — an Artefact + a Tariff firing together pays nothing")
	bil.queue_free()
	await process_frame

	var mona := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 4, "gold": 0,
		"artefacts": ["100-genuine-original-mona-lisa"], "king_abilities": ["inflation"]})
	await process_frame
	mona.mona_lisa_turn_done = false
	check(Economy.gain(mona, 100) == 90,
		"review pass 3: Mona Lisa never echoes a Tariff — Tariff on Gold Gain applies once, not twice")
	mona.queue_free()
	await process_frame

	# --- NO-103: Tariff on Item charges on ACQUISITION as well as on use ---
	# User ruling 2026-09-17: buying an Item, or an effect granting one, is
	# taxed like using one. Buy-then-use is therefore charged twice.
	var acq := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 500, "king_abilities": ["ability_cost"]})
	await process_frame

	# a granted Item charges once
	var g_before: int = acq.gold
	ArtefactHooks.grant_item(acq, Items.ITEMS[0])
	check(acq.gold == g_before - Economy.tariff_cut(Tuning.SHOP_ITEM_PRICE[Items.ITEMS[0].tier], Tuning.TARIFF_ITEM_PCT),
		"NO-103: an Item grant charges Tariff on Item once")

	# a grant REFUSED at the Item cap charges nothing
	while ItemLogic.has_room(acq):
		ItemLogic.grant(acq, Items.ITEMS[0])
	var g_full: int = acq.gold
	check(not ArtefactHooks.grant_item(acq, Items.ITEMS[0]),
		"NO-103: a grant at a full inventory is refused")
	check(acq.gold == g_full,
		"NO-103: a REFUSED grant charges nothing — no tax for an Item you did not get")
	acq.queue_free()
	await process_frame

	# NO-108: a Zapruder return IS an acquisition and pays the tariff. The call
	# must go through grant_item, the wrapper _zapruder_resolve now uses — a
	# direct ItemLogic.grant would never charge and would prove nothing.
	var zap := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 500, "king_abilities": ["ability_cost"]})
	await process_frame
	var g_zap: int = zap.gold
	ArtefactHooks.grant_item(zap, Items.ITEMS[0]) # the path _zapruder_resolve uses
	check(zap.gold == g_zap - Economy.tariff_cut(
			Tuning.SHOP_ITEM_PRICE[Items.ITEMS[0].tier], Tuning.TARIFF_ITEM_PCT),
		"NO-108: an Item RETURNED (Zapruder) is an acquisition and IS taxed")
	zap.queue_free()
	await process_frame

	# with no Tariff held, acquisition is free — the charge is inert
	var untaxed := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 4, "gold": 500})
	await process_frame
	var g_untaxed: int = untaxed.gold
	ArtefactHooks.grant_item(untaxed, Items.ITEMS[0])
	check(untaxed.gold == g_untaxed,
		"NO-103: no Tariff held — an Item grant costs nothing")
	untaxed.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL TARIFF CHECKS OK")
	quit(1 if fails > 0 else 0)
