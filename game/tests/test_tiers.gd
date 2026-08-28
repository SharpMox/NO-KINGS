extends SceneTree
## Difficulty tiers (07-difficulty-ranks, redesigned 2026-08-28): 5 numbered
## tiers, CUMULATIVE levers, Tier 1 the no-debuff default. Covers the pure
## Tuning math, the Shop row seam, the Clock-pause surfaces, the tariff
## parity (the old severity-shift lever is gone), and that an old save's
## rank name doesn't break a boot. Click-probe coverage for the menu picker
## lives in test_menu_clicks.gd (windowed).
## Run headless:  godot --headless --path game -s tests/test_tiers.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Economy := preload("res://scripts/economy.gd")
const Shop := preload("res://scripts/shop.gd")

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
	GameScript.is_scenario = true # never touch the real save
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _init() -> void:
	# --- shape ---
	check(Tuning.TIERS == ["Tier 1", "Tier 2", "Tier 3", "Tier 4", "Tier 5"],
		"5 numbered tiers, in order")
	check(Tuning.DEFAULT_TIER == "Tier 1", "Tier 1 is the default")

	# --- cumulative levers, pure math ---
	for i in Tuning.TIERS.size():
		var t: String = Tuning.TIERS[i]
		check(Tuning.clock_never_pauses(t) == (i >= 1),
			"%s: clock-never-pauses lever (Tier 2+)" % t)
		check(Tuning.shop_row_delta(t) == (-1 if i >= 2 else 0),
			"%s: Shop row delta (Tier 3+)" % t)
		check(Tuning.actions_per_turn(t) == Tuning.ACTIONS_PER_TURN - (1 if i >= 4 else 0),
			"%s: actions/turn (Tier 5 only)" % t)
	check(Tuning.tier_index("nonsense") == 0 and Tuning.tier_index("") == 0
			and Tuning.tier_index("Officer") == 0,
		"an unrecognized tier string (old save rank name, or unset) falls back to Tier 1")

	# --- starting Stock: unchanged through Tier 3, halved-per-type (round up) at 4+ ---
	for t in ["Tier 1", "Tier 2", "Tier 3"]:
		check(Tuning.starting_stock("Crown", t) == Tuning.ARMIES["Crown"],
			"%s: starting Stock is the full army" % t)
	check(Tuning.starting_stock("Crown", "Tier 4").size() == 7
			and Tuning.starting_stock("Crown", "Tier 4").count("pawn") == 4,
		"Crown at Tier 4+: 4 pawn + rook + bishop + knight (7)")
	var wild := Tuning.starting_stock("Wild Hunt", "Tier 5")
	check(wild.size() == 6 and wild.count("pawn") == 4 and wild.count("kirin") == 1
			and wild.count("knight") == 1,
		"Wild Hunt at Tier 5: 4 pawn + 1 kirin + 1 knight (6)")
	var og := Tuning.starting_stock("Old Guard", "Tier 4")
	check(og.size() == 6 and og.count("ferz") == 2 and og.count("wazir") == 2
			and og.count("knight") == 1 and og.count("alibaba") == 1,
		"Old Guard at Tier 4+: 2 ferz + 2 wazir + 1 knight + 1 alibaba (6)")

	# --- a fresh Tier 4 run actually boots with the halved stock ---
	GameScript.next_army = "Crown"
	GameScript.next_tier = "Tier 4"
	var boot: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(boot)
	await process_frame
	check(boot.stock.size() == 7 and boot.stock.count("pawn") == 4,
		"a fresh Tier 4 boot actually carries the halved Crown stock")
	boot.queue_free()
	await process_frame
	GameScript.next_tier = Tuning.DEFAULT_TIER

	# --- Shop rows: unchanged through Tier 2, -1/kind at Tier 3+, box slots
	# stay grouped by type with the remainder taken off the last type ---
	var s1 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	check(s1.shop_stock.size() == 22, "Tier 1 Shop: unchanged 22 slots")
	s1.queue_free()
	await process_frame

	GameScript.next_tier = "Tier 3"
	var s3 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	var kinds := {}
	for slot in s3.shop_stock:
		kinds[slot.kind] = kinds.get(slot.kind, 0) + 1
	check(kinds.get("piece", 0) == 7 and kinds.get("artefact", 0) == 3
			and kinds.get("item", 0) == 3 and kinds.get("box", 0) == 5,
		"Tier 3+ Shop: 7 pieces / 3 artefacts / 3 items / 5 boxes (%s)" % str(kinds))
	var box_types := {}
	for slot in s3.shop_stock:
		if slot.kind == "box":
			box_types[slot.key] = box_types.get(slot.key, 0) + 1
	check(box_types.get("item", 0) == 2 and box_types.get("artefact", 0) == 2
			and box_types.get("score", 0) == 1,
		"the 5 Tier-3+ box slots stay grouped by type, the odd one off the last type (%s)"
			% str(box_types))
	s3.queue_free()
	await process_frame
	GameScript.next_tier = Tuning.DEFAULT_TIER

	# --- Clock pause: Tier 1 pauses for the Shop/drawers/preview/menu, never
	# for Box Pick or the Buff Box sub-pick; Tier 2+ never pauses for any of
	# the first group. OS-backgrounded always wins, at every tier. ---
	var c1 := _boot({"board": [["queen", 0, 2, 2], ["king", 1, 2, 3]], "clock_s": 100.0})
	await process_frame
	await create_timer(0.15).timeout
	var before1: float = c1.clock_ms
	check(before1 < 100_000.0, "Tier 1: clock ticks normally with nothing open")
	c1.preview_open = true
	await create_timer(0.2).timeout
	check(c1.clock_ms == before1, "Tier 1: the piece preview pauses the Clock")
	c1.preview_open = false
	c1.box_open = true
	var before_box: float = c1.clock_ms
	await create_timer(0.2).timeout
	check(c1.clock_ms < before_box, "Tier 1: Box Pick never pauses the Clock")
	c1.box_open = false
	c1.buff_pick_open = true
	var before_buff: float = c1.clock_ms
	await create_timer(0.2).timeout
	check(c1.clock_ms < before_buff, "Tier 1: the Buff Box sub-pick never pauses the Clock")
	c1.buff_pick_open = false

	# --- issue 41: the generic choice-modal seam, exercised directly — not
	# through the Buff Box — proves it generalises: opening it blocks input
	# on the shared flag (same guard sites), the Clock keeps ticking (Tier
	# 1, same list the Buff Box check above just used), the continuation
	# resumes with the picked value, and cancel runs its OWN continuation
	# instead of the chosen one — the Buff Box precedent for "leaves the
	# triggering effect unspent."
	var picked := [] # closure cell: GDScript captures locals by value
	var cancelled := [false]
	c1._open_choice_pick("pick one", [{"label": "A", "value": "a"},
			{"label": "B", "value": "b"}], "Nope",
		func(v): picked.append(v),
		func(): cancelled[0] = true)
	check(c1.buff_pick_open and c1.modals.buff_panel != null,
		"issue 41: opening the generic seam sets the shared flag and shows the panel")
	var arrow_before: bool = c1.arrow_mode
	c1._on_arrow_toggle()
	check(c1.arrow_mode == arrow_before,
		"issue 41: the generic seam blocks input at the same guard sites as the Buff Box")
	var before_choice: float = c1.clock_ms
	await create_timer(0.2).timeout
	check(c1.clock_ms < before_choice,
		"Tier 1: the generic choice-pick seam never pauses the Clock (generalises, not Buff-Box-only)")
	c1.modals.choice_chosen.emit("b")
	check(picked == ["b"], "issue 41: the continuation resumes with the picked value")
	check(not c1.buff_pick_open and c1.modals.buff_panel == null,
		"issue 41: picking closes the panel and clears the shared flag")
	c1._open_choice_pick("pick one", [{"label": "A", "value": "a"}], "Nope",
		func(v): picked.append(v), func(): cancelled[0] = true)
	c1.modals.choice_pick_cancelled.emit()
	check(cancelled[0] and picked == ["b"],
		"issue 41: cancel runs the cancel continuation, not the chosen one — the effect stays unspent")
	check(not c1.buff_pick_open, "issue 41: cancelling clears the shared flag too")

	c1.queue_free()
	await process_frame

	GameScript.next_tier = "Tier 2"
	var c2 := _boot({"board": [["queen", 0, 2, 2], ["king", 1, 2, 3]], "clock_s": 100.0})
	await process_frame
	c2.preview_open = true
	var before2: float = c2.clock_ms
	await create_timer(0.2).timeout
	check(c2.clock_ms < before2, "Tier 2+: the piece preview no longer pauses the Clock")
	c2.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var before_bg: float = c2.clock_ms
	await create_timer(0.2).timeout
	check(c2.clock_ms == before_bg, "Tier 2+: OS-backgrounding still pauses the Clock")
	c2.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	c2.preview_open = false
	c2.buff_pick_open = true # issue 41: the choice-pick seam, higher tier too
	var before_c2_choice: float = c2.clock_ms
	await create_timer(0.2).timeout
	check(c2.clock_ms < before_c2_choice,
		"Tier 2+: the choice-pick seam still never pauses the Clock")
	c2.buff_pick_open = false
	c2.queue_free()
	await process_frame
	GameScript.next_tier = Tuning.DEFAULT_TIER

	# --- Tariffs: identical draw at every tier — the severity-shift lever is
	# gone (user call: rejected as illegible) ---
	var t1 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	t1.rng.seed = 99
	Economy.activate_tariff(t1, "Mild")
	var drawn_1: String = t1.tariffs_seen[0] if not t1.tariffs_seen.is_empty() else ""
	t1.queue_free()
	await process_frame

	GameScript.next_tier = "Tier 5"
	var t5 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	t5.rng.seed = 99
	Economy.activate_tariff(t5, "Mild")
	var drawn_5: String = t5.tariffs_seen[0] if not t5.tariffs_seen.is_empty() else ""
	t5.queue_free()
	await process_frame
	GameScript.next_tier = Tuning.DEFAULT_TIER

	check(drawn_1 != "" and drawn_1 == drawn_5,
		"the same Mild draw lands identically at Tier 1 and Tier 5 (no severity shift): %s"
			% drawn_1)

	# --- save compat: an old save's rank name boots and behaves like Tier 1 ---
	var old := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3,
		"rank": "Officer"})
	await process_frame
	check(old.next_tier == "Officer", "an old save's raw rank name round-trips as-is")
	check(old.actions_left == Tuning.ACTIONS_PER_TURN,
		"...but every Tuning lever reads it as Tier 1 baseline (no crash, no debuff)")
	check(not Tuning.clock_never_pauses(old.next_tier), "...clock still pauses normally")
	old.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL TIER CHECKS OK")
	quit(1 if fails > 0 else 0)
