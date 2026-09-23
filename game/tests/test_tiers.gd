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
const MenuScript := preload("res://scripts/menu.gd")

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
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
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
		check(Tuning.actions_per_turn(t) == Tuning.ACTIONS_PER_TURN - (1 if i >= 3 else 0),
			"%s: actions/turn (NO-213: Tier 4+)" % t)
		check(Tuning.enemy_actions_per_turn(t) == Tuning.ENEMY_ACTIONS_PER_TURN + (1 if i >= 4 else 0),
			"%s: enemy actions/turn (issue 59 — Tier 5 only)" % t)
	check(Tuning.tier_index("nonsense") == 0 and Tuning.tier_index("") == 0
			and Tuning.tier_index("Officer") == 0,
		"an unrecognized tier string (old save rank name, or unset) falls back to Tier 1")

	# --- NO-211 (Max): plain handicap text — no "Also:" prefix on the
	# cumulative lines, no parenthetical asides. ---
	var menu_node: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(menu_node)
	await process_frame
	var menu := menu_node as MenuScript
	for t in Tuning.TIERS:
		var desc: String = menu._tier_description(t)
		check(not desc.contains("Also:"), '%s: description has no "Also:" prefix' % t)
		check(not desc.contains("("), "%s: description has no parenthetical aside" % t)
	menu_node.queue_free()
	await process_frame

	# --- NO-213: the Stock-halving lever is gone from the ladder entirely —
	# starting Stock is always the full army, at every tier, not just through
	# Tier 3 as before. ---
	GameScript.next_army = "Crown"
	GameScript.next_tier = "Tier 5" # the old halving threshold's own highest tier
	var boot: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(boot)
	await process_frame
	check(boot.stock.size() == Tuning.ARMIES["Crown"].size()
			and boot.stock.count("pawn") == Tuning.ARMIES["Crown"].count("pawn"),
		"NO-213: a fresh Tier 5 boot carries the FULL Crown stock — no halving left")
	boot.queue_free()
	await process_frame
	GameScript.next_tier = Tuning.DEFAULT_TIER

	# --- NO-213: -1 action/turn moved down to Tier 4 (Knight); enemy's +1
	# action stays Tier 5 (Queen) only. A live boot proves both actually
	# stack at Tier 5 — not just the pure Tuning math in the loop above. ---
	# A raw instantiate() boots into SETUP (no board config -> _set_drawer
	# ("stock") only) and never reaches _begin_player_turn(), so actions_left
	# stays at its unset default of 0 regardless of tier — these two checks
	# could never pass. _boot() with a board config carries no "state" key,
	# so SaveConfig.apply() routes through g._begin_player_turn() (see its
	# own comment: only a mid-turn save with a "state" key skips it), which
	# is the real code path that reads next_tier into actions_left (line
	# ~1345) — the live boot the comment above promises, not just Tuning math.
	GameScript.next_tier = "Tier 4"
	var knight := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	check(knight.actions_left == Tuning.ACTIONS_PER_TURN - 1,
		"Tier 4 (Knight): actions/turn is one lower than base")
	check(Economy.enemy_actions(knight) == Tuning.ENEMY_ACTIONS_PER_TURN,
		"Tier 4 (Knight): enemy actions/turn is still unchanged")
	knight.queue_free()
	await process_frame

	GameScript.next_tier = "Tier 5"
	var queen := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	check(queen.actions_left == Tuning.ACTIONS_PER_TURN - 1,
		"Tier 5 (Queen): still one action fewer — Knight's handicap is inherited")
	check(Economy.enemy_actions(queen) == Tuning.ENEMY_ACTIONS_PER_TURN + 1,
		"Tier 5 (Queen): AND enemy actions/turn is one higher — both stack")
	queen.queue_free()
	await process_frame
	GameScript.next_tier = Tuning.DEFAULT_TIER

	# --- Shop rows: unchanged through Tier 2, -1/kind at Tier 3+, box slots
	# stay grouped by type with the remainder taken off the last type ---
	var s1 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	Shop.roll(s1) # NO-240: a pre-Wave-5 boot no longer stocks the Shop
	await process_frame
	check(s1.shop_stock.size() == 27, "Tier 1 Shop: unchanged 27 slots (NO-201)")
	s1.queue_free()
	await process_frame

	GameScript.next_tier = "Tier 3"
	var s3 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	Shop.roll(s3) # NO-240: a pre-Wave-5 boot no longer stocks the Shop
	await process_frame
	var kinds := {}
	for slot in s3.shop_stock:
		kinds[slot.kind] = kinds.get(slot.kind, 0) + 1
	check(kinds.get("piece", 0) == 11 and kinds.get("artefact", 0) == 4
			and kinds.get("item", 0) == 4 and kinds.get("box", 0) == 4,
		"Tier 3+ Shop: 11 pieces / 4 artefacts / 4 items / 4 boxes (NO-201) (%s)" % str(kinds))
	var box_types := {}
	for slot in s3.shop_stock:
		if slot.kind == "box":
			box_types[slot.key] = box_types.get(slot.key, 0) + 1
	check(box_types.get("piece", 0) == 2 and box_types.get("artefact", 0) == 1
			and box_types.get("item", 0) == 1,
		"the 4 Tier-3+ box slots stay grouped by theme, the odd one off the last theme (%s)"
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

	# --- a71f574 shipped Modals.pause_modal_open() with no tests at all. The
	# three full-rect panels carry no *_open flag of their own — `visible` is
	# their only state — so nothing pinned them. Assert BOTH directions: they
	# pause at Tier 1 here, and at Tier 2+ below they do not, which is what
	# keeps clock_never_pauses the only thing deciding it. Each case must
	# close its panel: the issue-41 block below asserts the Clock KEEPS
	# running, and a panel left visible turns that into a silent false fail. ---
	c1._show_king_abilities()
	check(c1.king_ability_panel != null and c1.king_ability_panel.visible, "the tariff overlay opened")
	var before_tar: float = c1.clock_ms
	await create_timer(0.2).timeout
	check(c1.clock_ms == before_tar, "Tier 1: the tariff overlay pauses the Clock")
	if c1.king_ability_panel != null:
		c1.king_ability_panel.visible = false
	# ids only feed the confirm's label — this exercises the panel, not merge rules
	c1.modals.show_merge_confirm("pawn", "pawn", "knight")
	var before_merge: float = c1.clock_ms
	await create_timer(0.2).timeout
	check(c1.clock_ms == before_merge, "Tier 1: the merge confirm pauses the Clock")
	c1.modals.merge_panel.visible = false
	c1.modals.show_reinforce([]) # NO-141: ids only feed the group picture — this exercises the panel, not the grant
	var before_reinf: float = c1.clock_ms
	await create_timer(0.2).timeout
	check(c1.clock_ms == before_reinf,
		"Tier 1: the reinforcement pick pauses the Clock (the third instance of the same gap)")
	c1.modals.reinforce_panel.visible = false
	var before_none: float = c1.clock_ms
	await create_timer(0.2).timeout
	check(c1.clock_ms < before_none,
		"...and the Clock runs again once they close — the pause was the panel, not a stuck flag")

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
	# the same three panels, at Tier 2+: the lever must still bite through them
	c2._show_king_abilities()
	var t2_tar: float = c2.clock_ms
	await create_timer(0.2).timeout
	check(c2.clock_ms < t2_tar, "Tier 2+: the tariff overlay no longer pauses the Clock")
	c2.king_ability_panel.visible = false
	c2.modals.show_merge_confirm("pawn", "pawn", "knight")
	var t2_merge: float = c2.clock_ms
	await create_timer(0.2).timeout
	check(c2.clock_ms < t2_merge, "Tier 2+: the merge confirm no longer pauses the Clock")
	c2.modals.merge_panel.visible = false
	c2.modals.show_reinforce([]) # NO-141: ids only feed the group picture — this exercises the panel, not the grant
	var t2_reinf: float = c2.clock_ms
	await create_timer(0.2).timeout
	check(c2.clock_ms < t2_reinf,
		"Tier 2+: the reinforcement pick no longer pauses it either — the lever still bites")
	c2.modals.reinforce_panel.visible = false
	c2.buff_pick_open = true # issue 41: the choice-pick seam, higher tier too
	var before_c2_choice: float = c2.clock_ms
	await create_timer(0.2).timeout
	check(c2.clock_ms < before_c2_choice,
		"Tier 2+: the choice-pick seam still never pauses the Clock")
	c2.buff_pick_open = false
	c2.queue_free()
	await process_frame
	GameScript.next_tier = Tuning.DEFAULT_TIER

	# --- issue 59: the enemy takes 2 Actions at Tier 5, 1 at Tiers 1-4 — a
	# live boot, not just the pure Tuning math above, to prove Economy.
	# enemy_actions actually reads g.next_tier when it seeds on_enemy_turn_start ---
	var ea1 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	check(Economy.enemy_actions(ea1) == 1, "Tier 1: the enemy takes 1 action per Turn")
	ea1.queue_free()
	await process_frame

	GameScript.next_tier = "Tier 4"
	var ea4 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	check(Economy.enemy_actions(ea4) == 1, "Tier 4: still 1 — the enemy-action lever is Tier 5 only")
	ea4.queue_free()
	await process_frame
	GameScript.next_tier = Tuning.DEFAULT_TIER

	GameScript.next_tier = "Tier 5"
	var ea5 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3})
	await process_frame
	check(Economy.enemy_actions(ea5) == 2, "Tier 5: the enemy takes 2 actions per Turn (issue 59)")
	ea5.queue_free()
	await process_frame
	GameScript.next_tier = Tuning.DEFAULT_TIER

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

	# --- issue 78: starting Clock 15 min, cut to 5 at Tier 3+ ---
	# Pure-math first, across the whole ladder, so an off-by-one in tier_index
	# cannot hide. Tier 3 is the BOUNDARY and the one that actually matters:
	# asserting only Tiers 1 and 5 would pass with the cut placed a rung wrong.
	for i in Tuning.TIERS.size():
		var t: String = Tuning.TIERS[i]
		var want: int = Tuning.CLOCK_START_MS_HARD if i >= 2 else Tuning.CLOCK_START_MS
		check(Tuning.clock_start_ms(t) == want,
			"%s: starting Clock is %d min (15 at Tiers 1-2, 5 at Tier 3+)"
				% [t, want / 60000])
	check(Tuning.clock_start_ms("Tier 2") == 15 * 60 * 1000
			and Tuning.clock_start_ms("Tier 3") == 5 * 60 * 1000,
		"the cut lands exactly at the Tier 2 -> Tier 3 boundary, not a rung either side")

	# ...and live, through a real boot: the fresh-run path must read the tier,
	# not the bare constant.
	var lo := _boot({"rank": "Tier 1", "board": [["queen", 0, 2, 2]]})
	await process_frame
	check(lo.clock_ms > 14.0 * 60_000.0,
		"Tier 1 boots with the full 15 minutes on the Clock")
	lo.queue_free()
	await process_frame
	var hi := _boot({"rank": "Tier 3", "board": [["queen", 0, 2, 2]]})
	await process_frame
	check(hi.clock_ms < 6.0 * 60_000.0,
		"Tier 3 boots with 5 minutes — the mid-rung cut applies on a real run")
	hi.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL TIER CHECKS OK")
	quit(1 if fails > 0 else 0)
