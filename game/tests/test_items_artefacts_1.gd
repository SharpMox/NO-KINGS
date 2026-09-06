extends SceneTree
## Artefacts, part 1: trigger-engine stacking (issue 15), Gold/Score batch
## (issue 16, incl. issue 20's Tungsten regression), the Action/Time/Piece
## no-prerequisite subset (issue 17), the per-turn action log + Elvish Hard
## Hat (issue 30), and the Shop/Item/Buff batch (issue 18). Split out of
## test_items.gd (issue 37).
## Run headless:  godot --headless --path game -s tests/test_items_artefacts_1.gd

const GameScript := preload("res://scripts/game.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Economy := preload("res://scripts/economy.gd")
const WaveLogic := preload("res://scripts/wave_logic.gd")
const Rules := preload("res://scripts/rules.gd")
const Shop := preload("res://scripts/shop.gd")
const Items := preload("res://data/items.gd")
const Waves := preload("res://data/waves.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd")

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
	# --- artefact trigger engine (slice 15): stacking is additive per copy,
	# and the result never depends on acquisition order. issue 69 removed the
	# original "greed"/"score"/"bounty" fixtures this proved itself against
	# (game-native, pre-catalog) — repointed at catalog equivalents with the
	# same on_capture flat-Score shape: Library of Alexandria Matchbox
	# ("+1 Gold and +10 Score per piece in your Stock" — a literal flat +10
	# per copy with 1 piece in Stock, same arithmetic "greed"/"score" used).
	var stack := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "stock": ["pawn"], "artefacts": ["library-of-alexandria-matchbox", "library-of-alexandria-matchbox"]})
	await process_frame
	var pawn_base: int = stack.defs.pawn.value
	check(Economy.capture_score(stack, "pawn") == pawn_base + 20,
		"two Library of Alexandria Matchboxes stack additively (+10 each), not multiplicatively")
	stack.queue_free()
	await process_frame

	var order_a := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "stock": ["pawn"],
		"artefacts": ["voynich-dictionary", "library-of-alexandria-matchbox", "suspiciously-large-femur"]})
	await process_frame
	var order_b := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "stock": ["pawn"],
		"artefacts": ["suspiciously-large-femur", "library-of-alexandria-matchbox", "voynich-dictionary"]})
	await process_frame
	check(Economy.capture_score(order_a, "pawn") == Economy.capture_score(order_b, "pawn"),
		"capture score is independent of artefact acquisition order")
	order_a.queue_free()
	order_b.queue_free()
	await process_frame

	# --- issue 16 (Gold/Score batch): percentage Score/Gold modifiers stack
	# additively — two Tinfoil Hats give +30%/-10%, not compounding (95%^2)
	var tinfoil := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["tinfoil-hat", "tinfoil-hat"]})
	await process_frame
	Economy.earn(tinfoil, 100)
	check(tinfoil.score == 1300, # issue 57: x10 (percentage math unchanged: 100 * 1.30)
		"two Tinfoil Hats: +15% Score each stacks to +30%, not +30.25%")
	check(tinfoil.gold == 90, "two Tinfoil Hats: -5% Gold each stacks to -10%, not -9.75%")
	tinfoil.queue_free()
	await process_frame

	# Tungsten-Filled Gold Bar: +20% Score gain (rebalanced 2026-08-28 — was
	# "2x their amount as Score", an unconditional 3x Score multiplier since
	# Gold is earned 1:1 with Score, wildly out of scale with the catalog)
	var tungsten := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["tungsten-filled-gold-bar"]})
	await process_frame
	Economy.earn(tungsten, 100)
	check(tungsten.gold == 100, "Tungsten-Filled Gold Bar doesn't change the Gold gain itself")
	check(tungsten.score == 1200, # issue 57: x10 (+100 base, +20 20%-of-Gold Score bonus, both x10'd)
		"Tungsten-Filled Gold Bar: +100 base, +20 (20% of the Gold) Score")
	tungsten.queue_free()
	await process_frame

	# --- issue 20 regression: the slice 20 fleet sweep caught Tungsten-Filled
	# Gold Bar + Popemobile Piggy Bank as a degenerate pair because both wrote
	# g.score straight from inside their on_gold_change dispatch instead of
	# through Economy.earn's ctx.score_bonus channel — held together, held
	# score should be the plain additive sum of each one's own bonus (20% +
	# 50%, rebalanced 2026-08-28 — was 2x + 10x), not doubled or compounded
	var tungsten_pope := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["tungsten-filled-gold-bar", "popemobile-piggy-bank"]})
	await process_frame
	Economy.earn(tungsten_pope, 100)
	check(tungsten_pope.gold == 100, "Tungsten + Popemobile together don't change the Gold gain itself")
	check(tungsten_pope.score == (100 + 20 + 50) * 10, # issue 57: x10
		"Tungsten (+20, 20%) and Popemobile (+50, 50%) add on top of the +100 base — the correct sum, not doubled")
	tungsten_pope.queue_free()
	await process_frame

	# El Dorado Body Glitter: 5% of Score gains paid as Gold, off the
	# immutable ctx.base — must give the same payout whether or not another
	# on_score_change handler (Bermuda Triangulation, key-sorts before
	# "el-dorado-body-glitter" so it dispatches first) already inflated the
	# running ctx.amount. Pre-fix, El Dorado read ctx.amount and would have
	# paid 5% of the Bermuda-inflated 150 (= 8 Gold, for a buggy total of 133)
	# instead of 5% of the untouched 100 base.
	var el_dorado_order := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["el-dorado-body-glitter", "bermuda-triangulation"],
		"clock_s": 10})
	await process_frame
	Economy.earn(el_dorado_order, 100)
	check(el_dorado_order.score == 1500, "Bermuda Triangulation: +50% Score under 60s Clock") # issue 57: x10
	check(el_dorado_order.gold == 130,
		"El Dorado's 5% Gold bonus is off the 100 base (+5), not the Bermuda-inflated 150 (+8) — " +
		"125 (100 base +25% Bermuda Gold) + 5 (El Dorado) = 130, order-independent")
	el_dorado_order.queue_free()
	await process_frame

	# Zurich Gnome Figurine: at Wave end, refund 10% of Gold spent in the Shop
	var zurich := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["zurich-gnome-figurine"], "gold": 100})
	await process_frame
	zurich.gold_spent_shop_this_wave = 40
	WaveLogic.queue(zurich, zurich.wave + 1)
	check(zurich.gold == 104, "Zurich Gnome Figurine refunds 10% of Gold spent in the Shop at Wave clear")
	zurich.queue_free()
	await process_frame

	# Social Credit Report Card + issue 16 ruling: the -10 Score penalty on
	# losing a piece debits Gold instead, so Score stays up-only
	var social := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["social-credit-report-card"], "gold": 100, "score": 500})
	await process_frame
	WaveLogic.queue(social, social.wave + 1) # clean: no pieces lost since wave start
	check(social.score == 1500, "Social Credit Report Card: +100 Score on a clean Wave clear") # issue 57:
		# x10 on the GAIN (100 -> 1000), starting score was a preset 500: 500 + 1000 = 1500
	check(social.gold == 100, "Social Credit Report Card: no Gold change on a clean clear")
	social.lost_player += 1 # a piece falls during the next wave
	WaveLogic.queue(social, social.wave + 1)
	check(social.score == 1500, "Social Credit Report Card: Score stays up-only after losing a piece")
	check(social.gold == 90, "Social Credit Report Card: the -10 Score penalty debits Gold instead (issue 16 ruling)")
	social.queue_free()
	await process_frame

	# Nero's Marshmallow Stick: each Capture in a Turn gives +25% more Score
	# than the previous one (linear step off the untouched base value)
	var nero := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["nero-s-marshmallow-stick"]})
	await process_frame
	var nero_base: int = nero.defs.pawn.value
	var cap1 := Economy.capture_score(nero, "pawn")
	var cap2 := Economy.capture_score(nero, "pawn")
	var cap3 := Economy.capture_score(nero, "pawn")
	check(cap1 == nero_base, "Nero's Marshmallow Stick: the first Capture this Turn is unmodified")
	check(cap2 == nero_base + roundi(nero_base * 0.25), "Nero's Marshmallow Stick: the 2nd Capture gives +25% more")
	check(cap3 == nero_base + roundi(nero_base * 0.5), "Nero's Marshmallow Stick: the 3rd Capture gives +50% more")
	nero.queue_free()
	await process_frame

	# --- slice 17 (Action/Time/Piece, no-prerequisite subset) ---

	# CIA Exploding Cigar: flat +1 action every turn
	var cig := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["cia-exploding-cigar"]})
	await process_frame
	check(cig.actions_left == Tuning.ACTIONS_PER_TURN + 1
			and cig.actions_max == Tuning.ACTIONS_PER_TURN + 1,
		"CIA Exploding Cigar grants +1 action every turn")
	cig.queue_free()
	await process_frame

	# 'I Am Not a Robot' Checkbox: +1 action at 8+ allied pieces on the Board
	var bot8 := _boot({"board": [
			["queen", 0, 0, 0], ["rook", 0, 1, 0], ["bishop", 0, 2, 0], ["knight", 0, 3, 0],
			["pawn", 0, 4, 0], ["pawn", 0, 5, 0], ["pawn", 0, 6, 0], ["pawn", 0, 7, 0],
			["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["i-am-not-a-robot-checkbox"]})
	await process_frame
	check(bot8.actions_left == Tuning.ACTIONS_PER_TURN + 1,
		"'I Am Not a Robot' Checkbox grants +1 action at 8+ allied pieces")
	bot8.queue_free()
	await process_frame

	var bot7 := _boot({"board": [
			["queen", 0, 0, 0], ["rook", 0, 1, 0], ["bishop", 0, 2, 0], ["knight", 0, 3, 0],
			["pawn", 0, 4, 0], ["pawn", 0, 5, 0], ["pawn", 0, 6, 0],
			["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["i-am-not-a-robot-checkbox"]})
	await process_frame
	check(bot7.actions_left == Tuning.ACTIONS_PER_TURN,
		"'I Am Not a Robot' Checkbox withholds the bonus below 8 allied pieces")
	bot7.queue_free()
	await process_frame

	# Seed Vault Secret Hatch: +1 action while holding 3+ unused Items
	var sv3 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "items": ["blitz", "sniper", "demote"],
		"artefacts": ["seed-vault-secret-hatch"]})
	await process_frame
	check(sv3.actions_left == Tuning.ACTIONS_PER_TURN + 1,
		"Seed Vault Secret Hatch grants +1 action at 3+ unused items")
	sv3.queue_free()
	await process_frame

	var sv2 := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "items": ["blitz", "sniper"],
		"artefacts": ["seed-vault-secret-hatch"]})
	await process_frame
	check(sv2.actions_left == Tuning.ACTIONS_PER_TURN,
		"Seed Vault Secret Hatch withholds the bonus below 3 items")
	sv2.queue_free()
	await process_frame

	# Super Soldier Multivitamins: +1 action while 3+ allied pieces carry a
	# Piece Buff (board slot 4 as a Dictionary merges onto the piece — the
	# `buffs` array BuffLogic.of() reads, per buff_logic.gd's header)
	var ss3 := _boot({"board": [
			["queen", 0, 2, 2, {"buffs": [{"key": "shield"}]}],
			["rook", 0, 3, 2, {"buffs": [{"key": "critical"}]}],
			["bishop", 0, 4, 2, {"buffs": [{"key": "range"}]}],
			["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["super-soldier-multivitamins"]})
	await process_frame
	check(ss3.actions_left == Tuning.ACTIONS_PER_TURN + 1,
		"Super Soldier Multivitamins grants +1 action at 3+ buffed allies")
	ss3.queue_free()
	await process_frame

	var ss2 := _boot({"board": [
			["queen", 0, 2, 2, {"buffs": [{"key": "shield"}]}],
			["rook", 0, 3, 2, {"buffs": [{"key": "critical"}]}],
			["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["super-soldier-multivitamins"]})
	await process_frame
	check(ss2.actions_left == Tuning.ACTIONS_PER_TURN,
		"Super Soldier Multivitamins withholds the bonus below 3 buffed allies")
	ss2.queue_free()
	await process_frame

	# 5G Microchips: +1s Clock per allied piece, -1s per enemy piece, at Turn start
	var g5 := _boot({"board": [["queen", 0, 2, 2], ["rook", 0, 3, 2], ["bishop", 0, 4, 2],
			["rook", 1, 7, 10]],
		"wave": 3, "clock_s": 100.0, "artefacts": ["5g-microchips"]})
	await process_frame
	check(g5.clock_ms <= 100000 + 2000 and g5.clock_ms >= 100000 + 2000 - 1000,
		"5G Microchips nets +1s per ally minus 1s per enemy (3 allies, 1 enemy here)")
	g5.queue_free()
	await process_frame

	# Terracotta Draft Card + Charlemagne's Birth Certificate: On Wave clear.
	# An all-player, no-pending-spawn board clears on the very first
	# _begin_player_turn() the boot already runs, so no extra plumbing is
	# needed to reach the hook.
	var wc := _boot({"board": [["queen", 0, 2, 2]], "wave": 1, "clock_s": 100.0,
		"artefacts": ["terracotta-draft-card", "charlemagne-s-birth-certificate"]})
	await process_frame
	check(wc.stock.size() == 1 and wc.stock[0] is String,
		"Terracotta Draft Card grants a bare-id piece to Stock on Wave clear (ADR-0002: no board state to carry)")
	check(wc.clock_ms <= 100000 + 10000 and wc.clock_ms >= 100000 + 10000 - 1000,
		"Charlemagne's Birth Certificate grants +10s Clock on Wave clear")
	wc.queue_free()
	await process_frame

	# Stargate Divination Crystal — the auto-pass interaction the issue calls
	# out (Blitz hit the same shape): granting an action mid-resolution must
	# never resurrect a turn that already auto-passed. Baseline first: with no
	# artefact, spending the last action on a capture auto-passes.
	var base := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4], ["rook", 1, 7, 10]],
		"wave": 3})
	await process_frame
	base.actions_left = 1
	base.actions_max = 1
	base._move_player(Vector2i(2, 2), Vector2i(2, 4)) # captures the pawn: last action
	check(base.actions_left == 0 and base.state == base.State.ENEMY_TURN,
		"baseline: spending the last action on a capture auto-passes the turn")
	base.queue_free()
	await process_frame

	# With Stargate, the SAME capture is also the first action of the turn:
	# the hook refunds the action inside Economy.capture_score, before
	# _move_player's own actions_left -= 1 / auto-pass check runs — so the
	# check never sees 0 and the turn never ends.
	var sg := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["stargate-divination-crystal"]})
	await process_frame
	sg.actions_left = 1
	sg.actions_max = 1
	sg._move_player(Vector2i(2, 2), Vector2i(2, 4))
	check(sg.actions_left == 1 and sg.state == sg.State.PLAYER_TURN,
		"Stargate Divination Crystal refunds the capture's action before the auto-pass check — the turn stays open")
	sg.queue_free()
	await process_frame

	# --- issue 30: per-turn action log + Elvish Hard Hat ("first Action of a
	# Turn is an Item or ability: +1 Action"). Basic effect: an Item as the
	# Turn's first action grants the bonus.
	var ehh := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]], "wave": 3,
		"artefacts": ["elvish-hard-hat"]})
	await process_frame
	ehh.actions_left = 2
	ehh.actions_max = 2
	ehh.items.append(_item("counter_intel", ""))
	ehh._use_item(0) # untargeted Item, resolves immediately — costs 1 action
	check(ehh.actions_left == 2 and ehh.actions_max == 3,
		"Elvish Hard Hat: an Item as the Turn's first Action refunds it and grants +1 Action")
	check(ehh.action_log.size() == 1 and ehh.action_log[0].kind == "item",
		"the action log records the Item as this Turn's first entry")
	ehh.queue_free()
	await process_frame

	# A move (not an Item) as the first Action earns no bonus.
	var ehh_move := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]], "wave": 3,
		"artefacts": ["elvish-hard-hat"]})
	await process_frame
	ehh_move.actions_left = 2
	ehh_move.actions_max = 2
	ehh_move._move_player(Vector2i(2, 2), Vector2i(2, 3))
	check(ehh_move.actions_left == 1 and ehh_move.actions_max == 2,
		"Elvish Hard Hat doesn't fire when the first Action is a move, not an Item")
	ehh_move.queue_free()
	await process_frame

	# An Item as the SECOND Action (a move already spent the first) earns no
	# bonus either — the effect text is "first Action", not "any Item".
	var ehh_second := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]], "wave": 3,
		"artefacts": ["elvish-hard-hat"]})
	await process_frame
	ehh_second.actions_left = 2
	ehh_second.actions_max = 2
	ehh_second._move_player(Vector2i(2, 2), Vector2i(2, 3)) # first action: a move
	ehh_second.items.append(_item("counter_intel", ""))
	ehh_second._use_item(0) # second action: an Item — too late for the bonus
	check(ehh_second.actions_left == 0 and ehh_second.actions_max == 2,
		"Elvish Hard Hat doesn't fire on an Item that isn't the Turn's first Action")
	ehh_second.queue_free()
	await process_frame

	# The trap the issue calls out (same shape as Stargate above): a Tier-5
	# single-action Turn where the only Action is an Item. Baseline first —
	# with no artefact, spending the Turn's one action auto-passes.
	var ehh_base := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]], "wave": 3})
	await process_frame
	ehh_base.actions_left = 1
	ehh_base.actions_max = 1
	ehh_base.items.append(_item("counter_intel", ""))
	ehh_base._use_item(0)
	check(ehh_base.actions_left == 0 and ehh_base.state == ehh_base.State.ENEMY_TURN,
		"baseline: spending a single-action Turn's only action on an Item auto-passes the turn")
	ehh_base.queue_free()
	await process_frame

	# With Elvish Hard Hat, that SAME Item use is also the Turn's first Action:
	# the hook refunds it inside _log_action, before _item_apply's own
	# actions_left == 0 auto-pass check runs — the check never sees 0, so the
	# turn is never resurrected because it never actually passes.
	var ehh_trap := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 5]], "wave": 3,
		"artefacts": ["elvish-hard-hat"]})
	await process_frame
	ehh_trap.actions_left = 1
	ehh_trap.actions_max = 1
	ehh_trap.items.append(_item("counter_intel", ""))
	ehh_trap._use_item(0)
	check(ehh_trap.actions_left == 1 and ehh_trap.state == ehh_trap.State.PLAYER_TURN,
		"Elvish Hard Hat refunds the Item's action before the auto-pass check — an already-passed turn is never resurrected because the turn never passes")
	ehh_trap.queue_free()
	await process_frame

	# --- fix (ruled 2026-08-28): RANDOM artefact buff grants must never hand
	# out a self-harming buff — today only Slow (it makes its own holder move
	# and capture like a Pawn, a debuff on its own holder). The player's own
	# Buff Box pick (_open_buff_pick, game.gd) is untouched: choosing Slow
	# deliberately (e.g. onto an enemy) is legitimate. ---
	check(Items.PIECE_BUFFS.filter(func(b: Dictionary) -> bool: return b.key == "slow")[0]
			.get("self_harming", false),
		"Slow is flagged self_harming in the catalog")
	check(not Items.PIECE_BUFFS.filter(func(b: Dictionary) -> bool: return b.key == "smog")[0]
			.get("self_harming", false),
		"Smog (debuffs adjacent ENEMIES, not its own holder) stays unflagged — a genuine buff")
	var rbk_rng := RandomNumberGenerator.new()
	rbk_rng.seed = 7
	var seen_slow := false
	var seen_other := {}
	for i in 500:
		var k: String = ArtefactHooks._random_buff_key(rbk_rng)
		if k == "slow":
			seen_slow = true
		seen_other[k] = true
	check(not seen_slow, "RANDOM grants (_random_buff_key) never draw Slow, even over 500 rolls")
	check(seen_other.size() == Items.PIECE_BUFFS.size() - 1,
		"every OTHER Piece Buff is still reachable by a random grant (%d of %d)"
			% [seen_other.size(), Items.PIECE_BUFFS.size() - 1])
	check(Items.PIECE_BUFFS.duplicate().any(func(b: Dictionary) -> bool: return b.key == "slow"),
		"the player's own Buff Box pool (_open_buff_pick's source) still includes Slow")

	# --- issue 18 (Shop/Item/Buff batch): Buff-tag artefacts go through
	# BuffLogic.add, not a parallel path ---

	# Crop Circle Plank: "5-Wave Milestone" is PER-ARTEFACT (ruled 2026-08-28)
	# — this held copy counts its own 5 waves from its own acquisition, fired
	# off the just-cleared wave (on_wave_clear), not the engine's own GLOBAL
	# 10-wave on_clock_refill cadence. acquired_wave is forced to 1 here so the
	# test can isolate the handler's own cadence math (_milestone5_hit) from
	# the separate acquisition-stamping coverage below — wave 5 clearing is
	# then this copy's beat 5 (1 + 4), a real 5-Wave Milestone.
	var crop := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 3, 2],
		["knight", 0, 4, 2], ["rook", 1, 7, 10]],
		"wave": 5, "artefacts": ["crop-circle-plank"], "gold": 50})
	await process_frame
	crop.artefacts[0].acquired_wave = 1
	WaveLogic.queue(crop, crop.wave + 1) # clears wave 5: a real 5-Wave Milestone
	var buffed := 0
	for pos in crop.board:
		if crop.board[pos].owner == Rules.PLAYER and BuffLogic.of(crop.board[pos]).size() > 0:
			buffed += 1
	check(buffed == 2, "Crop Circle Plank: exactly 2 allied pieces get +1 Piece Buff")
	check(crop.gold == 40, "Crop Circle Plank: -10 Gold")
	crop.queue_free()
	await process_frame

	# it does NOT fire clearing wave 6 or 7 (not this copy's own multiple of 5)
	var crop_off := _boot({"board": [["queen", 0, 2, 2], ["pawn", 0, 3, 2],
		["rook", 1, 7, 10]], "wave": 6, "artefacts": ["crop-circle-plank"], "gold": 50})
	await process_frame
	crop_off.artefacts[0].acquired_wave = 1
	WaveLogic.queue(crop_off, crop_off.wave + 1)
	check(crop_off.gold == 50, "Crop Circle Plank: no-op on a wave clear that isn't a multiple of 5")
	crop_off.queue_free()
	await process_frame

	# John Titor's Crypto Wallet: was left wired to on_clock_refill (the GLOBAL
	# 10-wave beat) when the rest of this "5-Wave Milestone" batch moved to
	# the per-artefact on_wave_clear + _milestone5_hit cadence — paid at half
	# the intended rate. Acquired wave 2: fires clearing wave 6 (2+4, beat 1)
	# and wave 11 (2+9, beat 2). Waves 8-11 are jumped directly (g.wave set,
	# not queued one by one) so the test never calls WaveLogic.queue with the
	# GLOBAL beat wave (11 — `(n - 1) % MILESTONE_WAVES == 0`) itself, which
	# fires its OWN Clock refill, unrelated to this artefact and pure noise for
	# an assertion whose payout is int(clock_ms / 5000); the separate control
	# test below isolates that wave on purpose instead.
	var cw := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 2, "artefacts": ["john-titor-s-crypto-wallet"], "gold": 0})
	await process_frame
	cw.artefacts[0].acquired_wave = 2
	cw.clock_ms = 25000.0 # 25s left -> +5 Gold per firing (int(25.0 / 5.0))
	for n in range(3, 7): # clear waves 2..5: not this copy's beat yet
		WaveLogic.queue(cw, n)
	check(cw.gold == 0, "no payout before the copy's own beat 5 (acquired wave 2 -> W+4 = wave 6)")
	WaveLogic.queue(cw, 7) # clears wave 6: this copy's beat 1 (2+4)
	check(cw.gold == 5, "fires on its own 5-wave beat, +1 Gold per 5s left on the Clock (25s -> +5)")
	cw.wave = 11 # skip straight past 8/9/10 (see comment above)
	WaveLogic.queue(cw, 12) # clears wave 11: this copy's beat 2 (2+9)
	check(cw.gold == 10, "fires again on its own next 5-wave beat (W+9), not the global cadence")
	cw.queue_free()
	await process_frame

	# --- issue 58: on_milestone renamed to on_clock_refill — pure rename, no
	# behaviour change. Its two listeners were the "timer" artefact and the
	# Recession tariff; issue 69 removed "timer" (no catalog artefact has
	# taken its place on this hook), so only the tariff remains to prove the
	# hook still fires on the GLOBAL 10-Wave beat (Tuning.MILESTONE_WAVES —
	# the start of wave 11), unrelated to the PER-ARTEFACT "5-Wave Milestone"
	# cadence covered above (Crop Circle Plank/John Titor). The
	# artefact-computed-first/tariff-halves-on-top ordering this block used to
	# also prove is moot with no artefact left on the hook — the ordering
	# guarantee itself is unchanged (see this file's own header note above),
	# just currently unexercised by anything other than the tariff.
	var refill := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 10, "clock_s": 0})
	await process_frame
	WaveLogic.queue(refill, 11) # starting wave 11: the GLOBAL beat fires
	check(refill.clock_ms == Tuning.CLOCK_REFILL_MS,
		"the renamed on_clock_refill hook still fires: base refill, no artefact left on the hook")
	refill.queue_free()
	await process_frame

	var refill_recession := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 10, "clock_s": 0, "tariffs": ["recession"]})
	await process_frame
	WaveLogic.queue(refill_recession, 11)
	check(refill_recession.clock_ms == Tuning.CLOCK_REFILL_MS * 0.5,
		"the renamed on_clock_refill hook still fires Recession: halves the base refill")
	refill_recession.queue_free()
	await process_frame

	# MK-Ultra Sugar Cube: On Deploy, the deployed piece gets a Tactical buff
	var mkultra := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["mk-ultra-sugar-cube"], "stock": ["pawn"], "gold": 100})
	await process_frame
	mkultra.state = mkultra.State.PLAYER_TURN
	mkultra.actions_left = 2
	mkultra._place("pawn", Vector2i(4, 2))
	var deployed: Array = BuffLogic.of(mkultra.board[Vector2i(4, 2)])
	check(deployed.size() == 1, "MK-Ultra Sugar Cube: the deployed piece gets +1 Piece Buff")
	if deployed.size() == 1:
		var tac_keys: Array = Items.PIECE_BUFFS.filter(func(b: Dictionary) -> bool:
			return b.tier == "Tactical").map(func(b: Dictionary) -> String: return b.key)
		check(tac_keys.has(deployed[0].key), "MK-Ultra Sugar Cube: the Buff is Tactical-tier")
	mkultra.queue_free()
	await process_frame

	# Holy Lint: On Capture, the capturing piece gets +1 Piece Buff (no gate) —
	# exercises attacker_pos end to end through a real board capture.
	# Seed pinned: Holy Lint's random draw covers every tier, including Bomb/
	# Trap/Multicapture — self-consuming hazards of their own (a freshly
	# granted Bomb would detonate THIS capture, same class of bug as Critical/
	# Range below, just not in this fix's scope) that a random roll would
	# occasionally hit and destroy the piece the test then inspects. Seed 4
	# is a durable roll ("shield", a dormant buff untouched by this capture
	# path either way) — verified deterministic across repeated runs. (issue
	# 47 shifted the RNG stream position here: Shop.roll now rolls every Box's
	# full contents at boot instead of at open time, moving this seed's
	# downstream draw from "stun" to "reflect". Issue 48 shifted it again —
	# PIECE_BUFFS grew a 13th entry, Bounty, changing _random_buff_key's pool
	# size and therefore the modulo — from "reflect" to "shield". Still a
	# safe, non-self-triggering pick, re-verified against the same Bomb/Trap/
	# Multicapture hazard list both times.)
	var lint := _boot({"board": [["queen", 0, 2, 2], ["pawn", 1, 3, 2]],
		"wave": 3, "artefacts": ["holy-lint"], "seed": "4"})
	await process_frame
	lint.actions_left = 5
	lint._move_player(Vector2i(2, 2), Vector2i(3, 2))
	var lint_buffs: Array = BuffLogic.of(lint.board[Vector2i(3, 2)])
	# Assert the BEHAVIOUR (exactly one Buff, and a safe one), not which key the
	# RNG happened to land on. Naming the key made this assertion churn three
	# times in three slices — stun -> reflect (47 moved the stream by rolling
	# Box contents at boot), reflect -> shield (48 added a 13th Buff and changed
	# _random_buff_key's modulo) — and every churn is an invitation to "update
	# the expected value until it goes green", which is how a real regression
	# gets buried. What Holy Lint actually promises is "+1 Piece Buff"; the key
	# is incidental, so long as it is not one that self-triggers on the very
	# capture that granted it.
	const LINT_HAZARDS := ["bomb", "trap", "multicapture"] # would resolve
		# during this same capture and mask the grant
	check(lint_buffs.size() == 1,
		"Holy Lint: the capturing piece gets exactly +1 Piece Buff")
	check(not lint_buffs.is_empty() and not LINT_HAZARDS.has(lint_buffs[0].key),
		"...and it is a safe, non-self-triggering Buff (got %s)"
			% (lint_buffs[0].key if not lint_buffs.is_empty() else "none"))
	lint.queue_free()
	await process_frame

	# --- issue 43: New World Order Gerrymandering — "Gold paid by other
	# Artefacts is increased by 25%", a run()-tail post-pass (see
	# artefact_hooks.gd), not an ordinary key-sorted on_gold_change handler:
	# it multiplies exactly what Daylight Savings Jar's own +10% Gold
	# handler just added (ctx.amount - ctx.base), never the Gold gain's
	# unmodified base ---
	var gerry_control := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["daylight-savings-jar"], "clock_s": 100})
	await process_frame
	Economy.earn(gerry_control, 800)
	check(gerry_control.gold == 880,
		"(control) Daylight Savings Jar alone: +10% Gold on an 800 base = 880")
	gerry_control.queue_free()
	await process_frame

	var gerry_one := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["daylight-savings-jar", "new-world-order-gerrymandering"],
		"clock_s": 100})
	await process_frame
	Economy.earn(gerry_one, 800)
	check(gerry_one.gold == 900,
		"New World Order Gerrymandering: +25% of the +80 Daylight Savings Jar added (not +25% of the full 880) = 900")
	gerry_one.queue_free()
	await process_frame

	var gerry_two := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["daylight-savings-jar", "new-world-order-gerrymandering",
			"new-world-order-gerrymandering"], "clock_s": 100})
	await process_frame
	Economy.earn(gerry_two, 800)
	check(gerry_two.gold == 920,
		"two New World Order Gerrymanderings: +50% of the +80 added (920), not compounding (1.25^2 -> 925)")
	gerry_two.queue_free()
	await process_frame

	# The same +25% also applies to ctx.gold_bonus, the Score->Gold
	# converter channel (El Dorado Body Glitter) — it's Gold an Artefact
	# paid too, just riding the on_score_change hook rather than on_gold_change.
	var gerry_eldorado_control := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["el-dorado-body-glitter"]})
	await process_frame
	Economy.earn(gerry_eldorado_control, 800)
	check(gerry_eldorado_control.gold == 840,
		"(control) El Dorado Body Glitter alone: +40 Gold (5% of the 800 Score base)")
	gerry_eldorado_control.queue_free()
	await process_frame

	var gerry_eldorado := _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "artefacts": ["el-dorado-body-glitter", "new-world-order-gerrymandering"]})
	await process_frame
	Economy.earn(gerry_eldorado, 800)
	check(gerry_eldorado.gold == 850,
		"New World Order Gerrymandering: +25% of El Dorado's +40 Gold side-payment too = +50, total 850")
	gerry_eldorado.queue_free()
	await process_frame


	print("---")
	if fails == 0:
		print("ALL ARTEFACTS 1 CHECKS OK")
	quit(1 if fails > 0 else 0)
