extends SceneTree
## In-game HUD click probe: boots the Game scene from a config and injects
## synthetic clicks — PASS ends the turn, Merge toggles, pool buttons select,
## board tiles respond, the box-pick modal blocks and resolves. Companion to
## test_menu_clicks.gd. Needs a window (headless drops GUI picking). Run:
##   godot --path game -s tests/test_game_clicks.gd

const GameScript := preload("res://scripts/game.gd")
const Settings := preload("res://scripts/settings.gd")
const ShopScript := preload("res://scripts/shop.gd")
const Box := preload("res://scripts/box.gd")
const Items := preload("res://data/items.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Armies := preload("res://scripts/armies.gd") # issue 100
const Shop := preload("res://scripts/shop.gd") # issue 97: convert price

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)




## issue 96: the pool strip is no longer buttons-only — a VSeparator and a
## label mark where Captured Stock begins — so "the first stack" is the first
## BUTTON, not the first child.
func _first_pool_stack(game: Node2D) -> Button:
	for c in game.pool_box.get_children():
		if c is Button:
			return c
	return null


func _click_button_in(node: Node, text: String) -> bool:
	if node is Button and node.text == text and node.is_visible_in_tree():
		var p: Node = node.get_parent()
		while p: # bring buttons inside scroll lists into the viewport first
			if p is ScrollContainer: # the in-game Guide panel scrolls (05-menus)
				p.ensure_control_visible(node)
				await process_frame
				break
			p = p.get_parent()
		_click(node.get_global_rect().get_center())
		return true
	for c in node.get_children():
		if await _click_button_in(c, text):
			return true
	return false


## NO-32: the Army Ability lives on the DECK button alone now, not in a drawer
## chip, so reaching it needs no Inventory step. Every Ability press below goes
## through here, which is also the pin that the deck button is the one home.
func _click_ability(game: Node) -> bool:
	var btn: Button = game.hud.army_ability_button
	if not btn.is_visible_in_tree():
		return false
	_click(btn.get_global_rect().get_center())
	return true


func _click(at: Vector2) -> void:
	_press(at)
	_release(at)


## A press with NO release. A press-drag starts on button_down, so _click's
## release would begin and end it inside one call and leave nothing to inspect.
func _press(at: Vector2) -> void:
	_mouse_button(at, true)


func _release(at: Vector2) -> void:
	_mouse_button(at, false)


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	root.push_input(ev)


## The pool-strip rows of ONE section, in on-screen order: Stock (cap false) or
## Captured (cap true). Re-read it after every refresh — the strip frees and
## rebuilds its buttons, so a row held across one is a freed node.
func _pool_rows(game: Node2D, cap: bool) -> Array:
	var out := []
	for c in game.pool_box.get_children():
		if c is Button and not c.is_queued_for_deletion() \
				and c.has_meta("cap") and bool(c.get_meta("cap")) == cap:
			out.append(c)
	return out


## Poll until the enemy turn hands control back (animations + ENEMY_TURN_PAUSE
## make its duration a tunable, not a constant) — up to 4s.
##
## Diagnosed under artificial load (fix/click-probe-stall): a real OS
## window can have its focus flicker under a busy machine, and the WM
## sometimes delivers a genuine NOTIFICATION_WM_WINDOW_FOCUS_OUT to this
## probe's window with no matching FOCUS_IN before the poll below gives up.
## game.gd correctly (06, test_background.gd) freezes the enemy turn
## indefinitely while `backgrounded` — that pause has no timeout by design,
## since a real player might tab away for minutes. This probe drives every
## click via synthetic root.push_input(), never real OS input, so it has no
## "player tabbed away" to honor; forcing the flag clear each poll costs at
## most one 0.1s tick and stops a WM focus hiccup from freezing the enemy
## turn for the rest of the run.
func _await_player_turn(game: Node2D) -> void:
	for i in 40:
		game.backgrounded = false
		if game.state == game.State.PLAYER_TURN:
			return
		await create_timer(0.1).timeout


func _init() -> void:
	# Watchdog: a SCRIPT ERROR mid-run kills this coroutine and quit() below
	# never fires, leaving the window open until a human closes it (user
	# report 2026-07-12). Force-quit instead; normal runs finish long before.
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: probe still running after 120s — force quit")
		quit(1))
	DirAccess.remove_absolute(Settings.SETTINGS_PATH) # clean slate for the Sound toggle probe
	GameScript.next_config = {
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]],
		"stock": ["pawn", "pawn"],   # the merge pair: Captured Stock cannot
		"captured": ["pawn", "pawn"], # merge since 2026-09-10, Stock still can
		"gold": 300, # issue 98: merging costs Gold, and this probe merges
	}
	# Hygiene fix, not the flake's cause (see _await_player_turn): every other
	# boot in this file, and every other test in the suite, sets is_scenario
	# to keep probes off the real save file — this one predates the autosave
	# feature by a day (git history) and was never updated. It has no real
	# on-disk-write test depending on it (test_save.gd round-trips _to_config()
	# in memory, never this file-write path), so there is nothing to preserve.
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	check(game.state == game.State.PLAYER_TURN, "config boots into player turn")

	# board click selects the queen and shows its moves
	_click(game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.selected == Vector2i(2, 2), "board click selects a piece")
	check(not game.legal_dests.is_empty(), "selection shows legal moves")

	# re-clicking the selected piece deselects it
	var qpx: Vector2 = game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2
	_click(qpx)
	await process_frame
	check(game.selected == Vector2i(-1, -1), "re-click deselects the piece")

	# dragging away and releasing back home takes no action and deselects
	var q_press := InputEventMouseButton.new()
	q_press.button_index = MOUSE_BUTTON_LEFT
	q_press.pressed = true
	q_press.position = qpx
	q_press.global_position = qpx
	root.push_input(q_press)
	await process_frame
	var q_motion := InputEventMouseMotion.new()
	q_motion.position = game._tile_px(Vector2i(4, 6)) + Vector2(game.tile, game.tile) / 2
	q_motion.global_position = q_motion.position
	root.push_input(q_motion)
	await process_frame
	var q_release := InputEventMouseButton.new()
	q_release.button_index = MOUSE_BUTTON_LEFT
	q_release.pressed = false
	q_release.position = qpx
	q_release.global_position = qpx
	root.push_input(q_release)
	await process_frame
	check(game.selected == Vector2i(-1, -1) and game.board.has(Vector2i(2, 2)),
		"aborted drag (released at home) deselects, no action taken")

	# enemy recon: clicking a foe shows its moves/threats but can't move it
	# (deselect the queen first — the foe is one of her capture targets)
	_click(game._tile_px(Vector2i(4, 9)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	_click(game._tile_px(Vector2i(2, 4)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.selected == Vector2i(2, 4) and not game.legal_dests.is_empty(),
		"clicking an enemy shows where it can move")
	var recon_dest: Vector2i = game.legal_dests[0]
	_click(game._tile_px(recon_dest) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(Vector2i(2, 4)) and not game.board.has(recon_dest),
		"an enemy recon selection can never be moved")

	# CAPTURED STOCK is convert-and-sell only (user ruling 2026-09-10). Three of
	# the reported problems are asserted here through real clicks: captured
	# pieces are listed ONE PER PIECE rather than stacked; a captured entry
	# carries no merge control and never lights up as a merge partner, even
	# though the armed Stock stack below holds the very same piece id; and
	# press-dragging one paints NO deploy targets on a board it can never be
	# placed on. Deployable Stock is untouched, which the ▲ merge at the end
	# of the block is here to prove.
	check(await _click_button_in(game.hud, "Stock 4"), "Stock button opens the drawer")
	await process_frame
	check(game.drawer_open == "stock" and game.pool_box.is_visible_in_tree(),
		"stock drawer is open and shows the pool strip")
	check(_pool_rows(game, false).size() == 1,
		"2 Stock pawns still show as ONE stack — Stock stacking is unchanged")
	var cap_rows: Array = _pool_rows(game, true)
	check(cap_rows.size() == 2, "2 captured pawns are listed individually, NOT stacked")
	# One control per captured entry and it is the ⇄ Convert badge: no ▲ merge,
	# and no arming step to reveal it. Holding two of a piece used to hand that
	# corner to ▲ and merge instead of converting (the user's report).
	var cap_cost: int = Shop.convert_price(game, "pawn")
	var cap_controls_ok := true
	var cap_controls_seen := ""
	for row in cap_rows:
		var controls: Array = (row as Button).get_children().filter(
			func(n: Node) -> bool: return n is Button)
		for c in controls:
			cap_controls_seen += (c as Button).text
		if controls.size() != 1 or (controls[0] as Button).text != "⇄$%d" % cap_cost \
				or (controls[0] as Button).disabled:
			cap_controls_ok = false
	check(cap_controls_ok,
		"each captured entry carries exactly ONE live control, its priced ⇄ Convert badge (%s)"
			% cap_controls_seen)
	# BUG (user 2026-09-10): press-dragging a captured piece lit up every legal
	# deploy tile. Assert the tile set _draw circles — the highlight the player
	# actually sees — not the flag behind it.
	var cap_at: Vector2 = (cap_rows[0] as Button).get_global_rect().get_center()
	_press(cap_at)
	await process_frame
	check(game._deploy_highlight_tiles().is_empty(),
		"press-dragging a captured entry paints NO deploy targets on the board")
	_release(cap_at)
	await process_frame
	await process_frame
	# CONTROL for the check above: arming the STOCK stack DOES paint them, in
	# this same game state, so an empty highlight set means something.
	var stock_stack: Button = _pool_rows(game, false)[0]
	_click(stock_stack.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(not game._deploy_highlight_tiles().is_empty(),
		"(control) arming the STOCK stack DOES paint them — the check above is not vacuous")
	check(game.merge_highlights.has("pawn"),
		"(control) 'pawn' is a highlighted merge-partner id while that stack is armed")
	var cap_tint_ok := true
	for row in _pool_rows(game, true):
		if not (row as Button).modulate.is_equal_approx(Color(1.0, 0.8, 0.8)):
			cap_tint_ok = false
	check(cap_tint_ok,
		"and a captured pawn keeps its warm tint — never gold, never a merge partner")
	var badges: Array = []
	for row in _pool_rows(game, false):
		for c in (row as Button).get_children():
			if c is Button and (c as Button).text.begins_with("▲"):
				badges.append(c)
	check(badges.size() == 1, "the armed STOCK stack shows the ▲ promote button")
	# issue 97/98: the badge carries the merge's PRICE, on the control that
	# starts the merge. Close Ranks does not make it free — that Power waives
	# the Action only (merge_logic.can_afford_merge), so the Gold always shows.
	check((badges[0] as Button).text == "▲$%d" % Tuning.MERGE_COST,
		"and the ▲ badge shows what the merge costs (%s)" % (badges[0] as Button).text)
	_click((badges[0] as Button).get_global_rect().get_center())
	await process_frame
	check(game.pending_merge.size() == 2, "the ▲ badge asks for merge confirmation")
	check(game.stock.size() == 2, "nothing merges before confirmation")
	check(await _click_button_in(game.hud, "Merge"), "confirm button clickable")
	await process_frame
	check(game.stock == ["sergeant"] and game.captured == ["pawn", "pawn"],
		"confirming promotes the STOCK pawn pair and leaves Captured Stock untouched")

	# PASS hands the turn over, banks the +5s turn bonus, and comes back
	var clock_before: float = game.clock_ms
	_click(game.pass_button.get_global_rect().get_center())
	await _await_player_turn(game) # enemy turn runs (animated + paced path)
	check(game.state == game.State.PLAYER_TURN, "PASS cycles through the enemy turn")
	check(game.clock_ms >= clock_before + 4000, # 5s bonus minus a little ticking
		"finishing the turn grants the clock bonus")

	# double-tap on the queen opens the piece preview; Close dismisses it
	var at: Vector2 = game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2
	_click(at)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.double_click = true
	press.position = at
	press.global_position = at
	root.push_input(press)
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	release.double_click = false
	root.push_input(release)
	await process_frame
	check(game.preview_open, "double-tap opens the piece preview")
	check(await _click_button_in(game.preview_panel, "Close"), "Close button clickable")
	await process_frame
	check(not game.preview_open, "Close dismisses the preview")

	# in-game menu: opens, pauses the clock, Resume returns
	check(await _click_button_in(game.hud, "☰"), "menu button clickable")
	await process_frame
	check(game.game_menu_open, "menu opens")
	var frozen: float = game.clock_ms
	await create_timer(0.4).timeout
	check(game.clock_ms == frozen, "clock pauses while the menu is open")

	# Guide and Settings (05-menus-and-settings): each opens over the pause
	# menu and its own Back returns to the pause menu, not straight to Resume
	check(await _click_button_in(game.game_menu, "Guide"), "in-game Guide button clickable")
	await process_frame
	check(await _click_button_in(game.game_menu, "← Back"), "in-game Guide Back clickable")
	await process_frame
	check(await _click_button_in(game.game_menu, "Settings"), "in-game Settings button clickable")
	await process_frame
	var sound_on: bool = Settings.load_settings().sound_on
	check(await _click_button_in(game.game_menu, "Sound: %s" % ("On" if sound_on else "Off")),
		"in-game Sound toggle clickable")
	await process_frame
	check(Settings.load_settings().sound_on != sound_on, "in-game Sound toggle persists")

	# Animations toggle (06): live-applies to the running game, no restart —
	# game.animations_on flips the instant the button is pressed
	check(game.animations_on, "animations start on by default")
	var anims_on: bool = Settings.load_settings().animations_on
	check(await _click_button_in(game.game_menu, "Animations: %s" % ("On" if anims_on else "Reduced")),
		"in-game Animations toggle clickable")
	await process_frame
	check(Settings.load_settings().animations_on != anims_on, "in-game Animations toggle persists")
	check(not game.animations_on, "in-game Animations toggle applies live, no restart")

	check(await _click_button_in(game.game_menu, "← Back"), "in-game Settings Back clickable")
	await process_frame

	check(await _click_button_in(game.game_menu, "Resume"), "Resume clickable")
	await process_frame
	check(not game.game_menu_open, "Resume closes the menu")
	DirAccess.remove_absolute(Settings.SETTINGS_PATH)

	# wave-50 King capture opens the win screen; Continue resumes the run
	game.queue_free()
	await process_frame
	GameScript.next_config = {"wave": 50,
		"board": [["queen", 0, 2, 2], ["king", 1, 2, 3], ["rook", 1, 7, 10]]}
	GameScript.is_scenario = true # keep the probe off the real save file
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_click(game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	_click(game._tile_px(Vector2i(2, 3)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.win_open, "capturing the wave-50 King opens the win screen")
	_click(game._tile_px(Vector2i(7, 10)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.selected != Vector2i(7, 10), "win screen blocks board clicks")
	check(await _click_button_in(game.overlay, "Continue"), "Continue clickable")
	await process_frame
	check(not game.win_open and game.state == game.State.PLAYER_TURN,
		"Continue resumes the run into endless")

	# Boxes (issue 47 rework: 9 typed Boxes, the box-carrier enemy is gone —
	# every Box comes from the Shop now). Buying a Box tile opens the roll
	# modal revealing its pre-rolled contents; an option button applies its
	# reward and closes the panel once every pick (native + extra) is taken.
	game.queue_free()
	await process_frame
	GameScript.next_config = {"wave": 5, # issue 101: the Shop is locked before
		# Tuning.SHOP_UNLOCK_WAVE, and _buy_a_box drives the real Shop button
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "gold": 500}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await _buy_a_box(game)
	check(game.box_open, "buying a Box opens the roll modal")
	var opt_btn := _first_option_button(game.box_panel)
	check(opt_btn != null and "\n" in opt_btn.text,
		"box options describe themselves (two-line label)")
	var loot_before: int = game.items.size() + game.artefacts.size() + game.stock.size()
	var native_picks: int = Box.SIZES[game.box_size].picks
	for i in native_picks: # Huge grants 2 native picks (issue 47) — take them all
		_click(_first_option_button(game.box_panel).get_global_rect().get_center())
		await process_frame
	check(not game.box_open, "picking every offered option closes the box")
	check(game.items.size() + game.artefacts.size() + game.stock.size() > loot_before,
		"the picked reward is applied")

	# NO-38 (user ruling 2026-09-08): a full inventory sells from INSIDE the
	# Item Box — the row is only there at capacity, one click sells one Item and
	# pays, the Box survives it, and the pick then lands.
	game.items.clear()
	for key in ["blitz", "sniper", "promote"]:
		for it in Items.ITEMS:
			if it.key == key:
				game.items.append(it)
	game._open_box_pick({"kind": "box", "key": "item", "size": "small", "sold": false,
		"contents": Box.roll_options(game, "item", "small")})
	await process_frame
	var sell_btn := _sell_button(game.box_panel)
	check(game.box_open and sell_btn != null,
		"NO-38: an Item Box at a full inventory shows a Sell row")
	var items_before: int = game.items.size()
	var gold_before_sale: int = game.gold
	_click(sell_btn.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(game.items.size() == items_before - 1 and game.gold > gold_before_sale,
		"NO-38: clicking Sell frees one slot and pays the sell price")
	check(game.box_open and _sell_button(game.box_panel) == null,
		"NO-38: the Box survives the sale and the Sell row is gone")
	_click(_first_option_button(game.box_panel).get_global_rect().get_center())
	await process_frame
	check(not game.box_open and game.items.size() == items_before,
		"NO-38: the pick then lands and closes the Box")

	# Nostradamus Mad Libs (issue 46/47): the extra pick reopens the box
	# modal with what's left of the offer instead of closing it — stacks on
	# TOP of a Box's own native picks, so this Box needs (native + 1) clicks.
	game.queue_free()
	await process_frame
	GameScript.next_config = {"wave": 5,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "gold": 500,
		"artefacts": ["nostradamus-mad-libs"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await _buy_a_box(game)
	check(game.box_open, "(setup) buying the Box opens the roll modal")
	var mad_libs_total: int = Box.SIZES[game.box_size].picks + 1 # +1 Nostradamus copy
	var mad_libs_picks := 0
	while game.box_open:
		var mad_libs_opt := _first_option_button(game.box_panel)
		check(mad_libs_opt != null, "an option is offered (pick %d)" % (mad_libs_picks + 1))
		_click(mad_libs_opt.get_global_rect().get_center())
		await process_frame
		mad_libs_picks += 1
		if mad_libs_picks < mad_libs_total:
			check(game.box_open,
				"Nostradamus Mad Libs: pick %d of %d keeps the box open" % [mad_libs_picks, mad_libs_total])
	check(mad_libs_picks == mad_libs_total,
		"Nostradamus Mad Libs: native picks + 1 extra = %d total picks taken" % mad_libs_total)

	# Snowden's Rubik's Cube / Bible Gag Reel Scroll (issue 46, functionally
	# identical): a Reroll button appears on the box modal while the budget
	# is above zero, clicking it replaces the offer without closing the box,
	# and it disappears once the budget is spent.
	game.queue_free()
	await process_frame
	GameScript.next_config = {"wave": 5,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "gold": 500,
		"artefacts": ["snowden-s-rubik-s-cube"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await _buy_a_box(game)
	check(game.box_open, "(setup) buying the Box opens the roll modal")
	var reroll_btn := _button_prefix(game.box_panel, "Reroll")
	check(reroll_btn != null, "Snowden's Rubik's Cube: a Reroll button appears on the box modal")
	var gold_before_reroll: int = game.gold
	_click(reroll_btn.get_global_rect().get_center())
	await process_frame
	check(game.box_open, "rerolling keeps the box open")
	check(game.gold == gold_before_reroll,
		"rerolling doesn't spend Gold here (opening/rerolling a Box never charges — the Tariff " +
		"on Box Pick was deleted entirely in issue 65; the under-any-Tariff-state proof lives " +
		"in test_items_artefacts_3.gd, with a full Mild-tier Tariff load held to make it observable)")
	check(_button_prefix(game.box_panel, "Reroll") == null,
		"the reroll budget is spent — no Reroll button on the fresh offer")

	# Buff Box sub-pick, riding the generic choice-modal seam (issue 41):
	# opening it blocks board input, Cancel leaves the item unspent, and
	# picking a choice resumes targeting exactly like before the migration.
	game.queue_free()
	await process_frame
	GameScript.next_config = {"wave": 3,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "items": ["buff_box"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_button_in(game.hud, "Inventory 1"), "Inventory opens for the Buff Box")
	# issue 100: the Army POWER is written out in the drawer. It used to live
	# only in the Ability chip's TOOLTIP and on the army-select screen, and
	# this is a portrait touch game — a hover tooltip is unreachable once a run
	# starts, so a Power that changes what is legal was effectively invisible.
	var kit: Dictionary = Armies.entry(game.next_army)
	check(kit.power_name in game.hud.army_power_label.text
			and kit.power_desc in game.hud.army_power_label.text,
		"the Army Power is readable in the drawer without hovering (%s)" % kit.power_name)
	# design C moved the Ability out of this drawer and onto the deck, so its
	# cost is asserted where it now lives. The point of the move is the next
	# check: you can read it WITHOUT opening anything.
	check("1 Action" in game.hud.army_ability_button.text
			or "no Action" in game.hud.army_ability_button.text
			or "next wave" in game.hud.army_ability_button.text,
		"the Ability states its cost or why it is unavailable (%s)"
			% game.hud.army_ability_button.text)
	check(kit.ability_name in game.hud.army_ability_button.text,
		"and names the ability itself")
	# NO-32: the drawer chip was the only place the Ability's DESCRIPTION lived.
	# It moved to the deck button's tooltip, so pin it here or the next refactor
	# drops the description entirely and nothing notices.
	check(kit.ability_desc in game.hud.army_ability_button.tooltip_text,
		"the deck button's tooltip carries the Ability description the chip used to hold")

	# ---- design C invariants (issue 106) ------------------------------------
	# DECK ORDER. This broke silently once: bar.move_to_front(), left over from
	# when the drawer opened OVER the button bar, made that bar the LAST child of
	# the deck. The tree reported one order and the screen showed another, and it
	# cost several rounds of screenshots to find. Order is load-bearing here —
	# the whole design is "board, then status, then the thumb row lowest".
	var deck: Node = game.hud.stock_strip.get_parent()
	check(game.hud.stock_strip.get_index() == 0,
		"deck order: the stock strip sits directly under the board")
	check(game.hud.act_row.get_index() == deck.get_child_count() - 1,
		"deck order: Ability and PASS are the LAST row, in the thumb arc")

	# ---- NO-33 / ADR-0004: the BOARD absorbs slack, the deck is a SUM -------
	# Design C made the strip the absorber. A strip built from fixed icon rows
	# spends a continuous quantity in discrete steps, so the remainder is dead by
	# construction — and a wider strip needs fewer rows and wastes MORE, which is
	# why NO-25 read it as a tablet bug. The board absorbs now.
	check(game.hud.stock_strip.size_flags_vertical != Control.SIZE_EXPAND_FILL,
		"NO-33: the stock strip no longer absorbs leftover height")
	# THE GUARD. The deck's height is a sum of constants, never a runtime
	# measurement (measuring needs a second layout pass, and a control that
	# measures itself before layout caches nonsense — CLAUDE.md, layout traps).
	# A sum can drift from the thing it describes, so this is what fails the
	# moment a deck row is added or a font moves under one.
	var rest := 0.0
	for c in deck.get_children():
		if c != game.hud.stock_strip:
			rest += (c as Control).get_combined_minimum_size().y
	rest += deck.get_theme_constant("separation") * (deck.get_child_count() - 1)
	check(is_equal_approx(rest, GameScript.DECK_BELOW_STRIP),
		"NO-33: DECK_BELOW_STRIP (%s) still matches the built deck (%s)"
			% [GameScript.DECK_BELOW_STRIP, rest])
	check(is_equal_approx(game.hud.stock_strip.get_combined_minimum_size().y,
			game.hud.ICON + GameScript.STRIP_CHROME),
		"NO-33: STRIP_CHROME still matches the strip's real one-row height (%s vs %s)"
			% [game.hud.stock_strip.get_combined_minimum_size().y,
				game.hud.ICON + GameScript.STRIP_CHROME])
	# The closed form reproduces the numbers design C was tuned against: on a
	# 9:20 phone the WIDTH term wins at tile 59, which is exactly where ICON's
	# literal 52 came from. If this pair ever stops agreeing, the -7 relationship
	# was refitted rather than derived, and ADR-0004 wants re-reading.
	check(GameScript.board_tile_for(Vector2(480.0, 1066.0)) == 59,
		"NO-33: a 9:20 phone still solves to tile 59, as design C shipped it")
	check(GameScript.board_tile_for(Vector2(480.0, 1066.0)) - GameScript.ICON_GAP == 52,
		"NO-33: ...and ICON on that phone is still 52, the constant it replaced")

	# ONE ICON SIZE. Items were 30px, stock stacks 46, the strip 52 before this
	# was pulled onto a single constant; nothing but a pin stops them drifting
	# apart again, because each lives in a different rebuild function.
	# The ONE ICON SIZE pin used to sit here, walking game.hud.stock_strip only.
	# It could not fail: this config carries no Stock, so the strip held ZERO
	# buttons and the loop asserted nothing at all (measured, NO-36). It now has
	# its own instance, with the content all three strips need — see below, after
	# the Ability states.

	# THE ABILITY WEARS ITS STATE. Availability without opening a menu is the
	# feature; "ready" was the only state ever exercised, and the other two are
	# what a player actually hits mid-turn.
	var was_used: bool = game.army_ability_used_this_wave
	var was_actions: int = game.actions_left
	game.army_ability_used_this_wave = true
	game.hud.refresh()
	check("next wave" in game.hud.army_ability_button.text
			and game.hud.army_ability_button.disabled,
		"spent: the Ability says when it returns, and refuses the press")
	game.army_ability_used_this_wave = false
	game.actions_left = 0
	game.hud.refresh()
	check("no Action" in game.hud.army_ability_button.text
			and game.hud.army_ability_button.disabled,
		"out of Actions: it says WHY, rather than greying out anonymously")
	game.actions_left = was_actions
	game.army_ability_used_this_wave = was_used
	game.hud.refresh()
	check("1 Action" in game.hud.army_ability_button.text
			and not game.hud.army_ability_button.disabled,
		"and it comes back ready once an Action exists again")
	await process_frame

	# ---- ONE ICON SIZE, ACROSS ALL THREE STRIPS (NO-36) ---------------------
	# Items were 30px, stock stacks 46, the strip 52 before these were pulled
	# onto one constant. PR #312's pin named that drift but walked only
	# stock_strip — and on a config with no Stock that container is empty, so the
	# pin asserted nothing whatsoever. The two strips that ACTUALLY drifted, the
	# item strip and the pool strip, were never inspected.
	#
	# So: a dedicated instance holding Stock AND items, both drawers visited, and
	# every strip asserted NON-EMPTY first — a vacuous pass is the exact failure
	# being fixed, and it must not be reachable again.
	var icon_game: Node2D = game
	game = null
	icon_game.queue_free()
	await process_frame
	GameScript.next_config = {"wave": 3, "board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"items": ["buff_box"], "stock": ["pawn", "rook"]}
	icon_game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(icon_game)
	await process_frame
	await process_frame
	var ICON_PX: int = icon_game.hud.ICON

	# 1. the stock strip under the board (rebuilt from _pool(), needs a sane width)
	var stock_btns: Array = icon_game.hud.stock_strip.find_children("*", "Button", true, false)
	check(not stock_btns.is_empty(), "(setup) the stock strip actually holds buttons to measure")
	var odd_stock: Array = []
	for b in stock_btns:
		if (b as Button).custom_minimum_size != Vector2(ICON_PX, ICON_PX):
			odd_stock.append((b as Button).custom_minimum_size)
	check(odd_stock.is_empty(),
		"stock strip: every icon is exactly ICON x ICON (%d), found: %s" % [ICON_PX, str(odd_stock)])

	# 2. the item strip, in the Inventory drawer. KNOWN EXCEPTION, asserted
	# rather than skipped: the button carries the item NAME beside the icon, so
	# its width is free and the icon is clamped to ICON - 8 (hud.gd's comment at
	# the icon_max_width override). Its HEIGHT is still a flat ICON.
	check(await _click_button_in(icon_game.hud, "Inventory 1"),
		"Inventory opens for the item strip")
	await process_frame
	var item_btns: Array = []
	for c in icon_game.hud.item_box.get_children():
		if c is Button:
			item_btns.append(c)
	check(not item_btns.is_empty(), "(setup) the item strip actually holds buttons to measure")
	var odd_item: Array = []
	for b in item_btns:
		if (b as Button).custom_minimum_size.y != ICON_PX \
				or (b as Button).get_theme_constant("icon_max_width") != ICON_PX - 8:
			odd_item.append([(b as Button).custom_minimum_size.y,
				(b as Button).get_theme_constant("icon_max_width")])
	check(odd_item.is_empty(),
		"item strip: height is ICON (%d) and the icon clamps to ICON-8 (%d), found: %s"
			% [ICON_PX, ICON_PX - 8, str(odd_item)])

	# 3. the pool strip, in the Stock drawer. _rebuild_pool_strip returns early
	# while that drawer is closed ("stock drawer closed: no targets"), so the
	# drawer has to be OPEN for this container to hold anything at all.
	check(await _click_button_in(icon_game.hud, "Stock 2"), "Stock drawer opens for the pool strip")
	await process_frame
	var pool_btns: Array = []
	for c in icon_game.hud.pool_box.get_children():
		if c is Button:
			pool_btns.append(c)
	check(not pool_btns.is_empty(), "(setup) the pool strip actually holds buttons to measure")
	var odd_pool: Array = []
	for b in pool_btns:
		if (b as Button).custom_minimum_size != Vector2(ICON_PX, ICON_PX):
			odd_pool.append((b as Button).custom_minimum_size)
	check(odd_pool.is_empty(),
		"pool strip: every icon is exactly ICON x ICON (%d), found: %s" % [ICON_PX, str(odd_pool)])

	# The pool strip grows a "+" take-back slot, but ONLY in SETUP with a board
	# piece selected -- which is why it kept a hardcoded 46 long after every
	# stack button beside it moved to ICON. Force that state rather than leave
	# the one control the pin cannot otherwise reach untested.
	icon_game.state = icon_game.State.SETUP
	icon_game.selected = Vector2i(2, 2)
	icon_game.hud.refresh()
	await process_frame
	var plus_slot: Button = null
	for c in icon_game.hud.pool_box.get_children():
		if c is Button and (c as Button).text == "+":
			plus_slot = c
	check(plus_slot != null, "(setup) the take-back \"+\" slot is present in SETUP with a selection")
	check(plus_slot != null and plus_slot.custom_minimum_size == Vector2(ICON_PX, ICON_PX),
		"pool strip: the \"+\" take-back slot is ICON too (%d), not the pre-ICON 46" % ICON_PX)

	icon_game.queue_free()
	await process_frame
	GameScript.next_config = {"wave": 3,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "items": ["buff_box"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_button_in(game.hud, "Inventory 1"), "Inventory reopens after the icon-size pin")
	await process_frame
	check(await _click_button_in(game.hud.item_box, "Buff Box"),
		"Buff Box clickable in the drawer")
	await process_frame
	check(game.buff_pick_open and game.modals.buff_panel.visible,
		"the Buff Box sub-pick opens the generic choice modal")
	# TOP-LEFT tile, not the middle of the board. The modal centres its option
	# buttons, and design C pulled the board flush under the top strip, so tile
	# (2,2) now sits under those buttons: this click was landing ON an option,
	# picking it, and closing the modal — while the assertion below still passed,
	# because a consumed click leaves `selected` untouched either way. A corner
	# tile is over the modal's backdrop, which is what the check is about.
	# FIND a tile the modal does not cover, rather than naming one. The old
	# hardcoded corner (0,0) is the BOTTOM-left tile, which sits inside the
	# modal's own button column — it passed only because it happened to land in
	# the 12px separation between the last option and Cancel, and NO-33's taller
	# board slid it 23px down onto Cancel, closing the very modal this check is
	# about. Same lesson as the drag probes: a hardcoded tile is a geometry
	# assertion in disguise (CLAUDE.md, tests that pass for the wrong reason).
	var modal_box: Control = game.modals.buff_panel.get_child(0).get_child(0)
	var box_rect: Rect2 = modal_box.get_global_rect()
	var backdrop := Vector2(-1, -1)
	for by in Tuning.BOARD_H:
		for bx in Tuning.BOARD_W:
			var c: Vector2 = game._tile_px(Vector2i(bx, by)) \
				+ Vector2(game.tile, game.tile) / 2
			if not box_rect.has_point(c):
				backdrop = c
				break
		if backdrop.x >= 0.0:
			break
	check(backdrop.x >= 0.0,
		"(setup) a board tile exists over the modal's backdrop rather than its buttons")
	_click(backdrop)
	await process_frame
	check(game.selected == Vector2i(-1, -1), "the choice modal blocks board clicks while open")
	check(game.modals.buff_panel != null and game.modals.buff_panel.visible,
		"...and the click did not reach a button behind it either")
	check(await _click_button_in(game.modals.buff_panel, "Cancel (keeps the item)"),
		"Cancel clickable on the choice modal")
	await process_frame
	check(not game.buff_pick_open and game.items.size() == 1,
		"cancelling the choice modal closes it and leaves the item unspent")
	check(await _click_button_in(game.hud, "Inventory 1"), "Inventory reopens after cancel")
	await process_frame
	check(await _click_button_in(game.hud.item_box, "Buff Box"), "Buff Box clickable again")
	await process_frame
	var buff_btn := _first_option_button(game.modals.buff_panel)
	check(buff_btn != null and "\n" in buff_btn.text,
		"choice options describe themselves (two-line label), same as Box Pick")
	_click(buff_btn.get_global_rect().get_center())
	await process_frame
	check(not game.buff_pick_open and not game.item_targets.is_empty(),
		"picking a choice closes the modal and resumes targeting (the continuation)")
	_click(game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.items.is_empty(), "targeting the buff spends the item, closing the loop")

	# SETUP: the pass button reads START, and a stock piece can be dragged
	# from the pool strip onto a zone tile (game-feel pass 2026-07-06)
	game.queue_free()
	await process_frame
	GameScript.next_config = {} # fresh run -> SETUP placement phase
	GameScript.next_army = "Crown"
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.state == game.State.SETUP, "empty config boots into SETUP")
	check(game.pass_button.text == "START", "setup shows START instead of PASS")
	var stack_btn: Button = _first_pool_stack(game)
	var stock_before: int = game.stock.size()
	# releasing INSIDE the open drawer must never place under it (2026-07-08)
	var d_press := InputEventMouseButton.new()
	d_press.button_index = MOUSE_BUTTON_LEFT
	d_press.pressed = true
	d_press.position = stack_btn.get_global_rect().get_center()
	d_press.global_position = d_press.position
	root.push_input(d_press)
	await process_frame
	# find a tile the OPEN DRAWER actually covers rather than assuming one. The
	# drawer used to be anchored to the bottom of the screen; design C opens it
	# above the deck instead, so the hardcoded (4,0) stopped being underneath it
	# and this drop was landing on a live square — the guard was still correct,
	# the coordinate had simply stopped testing it.
	var drawer_rect: Rect2 = (game.hud.drawers["stock"] as Control).get_global_rect()
	var zone := Vector2i(-1, -1)
	for ty in range(12):
		for tx in range(8):
			var c: Vector2 = game._tile_px(Vector2i(tx, ty)) \
				+ Vector2(game.tile, game.tile) / 2
			if drawer_rect.has_point(c):
				zone = Vector2i(tx, ty)
				break
		if zone.x >= 0:
			break
	check(zone.x >= 0, "the open drawer covers at least one board tile to test with")
	var zone_px: Vector2 = game._tile_px(zone) + Vector2(game.tile, game.tile) / 2
	var zone_motion := InputEventMouseMotion.new()
	zone_motion.position = zone_px
	zone_motion.global_position = zone_px
	root.push_input(zone_motion) # real pointers move before releasing —
	await process_frame           # without this the button still thinks it's
	var d_release := InputEventMouseButton.new() # hovered and fires a tap
	d_release.button_index = MOUSE_BUTTON_LEFT
	d_release.pressed = false
	d_release.position = zone_px
	d_release.global_position = zone_px
	# game.gd:1699 closes the drawer on ANY mouse motion outside its rect while
	# pool_drag_id is set, and _input sees REAL OS pointer motion as well as the
	# synthetic events pushed here. So a cursor crossing the Godot window during
	# the frame between the press and this release hands the drawer back, the
	# release is no longer covered, and the piece places LEGITIMATELY — the
	# check below then fails for a reason that is not in the code. It happened
	# on 2026-09-12 with another agent working on the same display. This
	# assertion makes that failure name itself instead of reading as a
	# behaviour regression; the motion pushed above is deliberately INSIDE the
	# drawer rect, so nothing this probe does can trip the auto-close.
	check(game.hud.drawer_open == "stock",
		"drawer still open at release (else a stray cursor closed it — see above)")
	root.push_input(d_release)
	await process_frame
	check(not game.board.has(zone) and game.stock.size() == stock_before,
		"a drop inside the open drawer places nothing (misinput guard)")

	# dragging OUT closes the drawer; the drop then lands on the revealed tile
	root.push_input(d_press.duplicate())
	await process_frame
	var high_px: Vector2 = game._tile_px(Vector2i(4, 6)) + Vector2(game.tile, game.tile) / 2
	var d_motion := InputEventMouseMotion.new()
	d_motion.position = high_px
	d_motion.global_position = high_px
	root.push_input(d_motion)
	await process_frame
	check(game.drawer_open == "", "dragging out of the drawer closes it")
	root.push_input(zone_motion.duplicate())
	await process_frame
	root.push_input(d_release.duplicate())
	await process_frame
	check(game.board.has(zone) and game.stock.size() == stock_before - 1,
		"drag from the stock strip places the piece on the zone tile")

	# a CANCELLED drag (invalid drop spot) reopens the drawer it auto-closed
	var live2: Button = game.pool_box.get_children().filter(func(b: Node) -> bool:
		return b is Button and b.has_meta("id") and not b.is_queued_for_deletion())[0]
	var l2_press: InputEventMouseButton = d_press.duplicate()
	l2_press.position = live2.get_global_rect().get_center()
	l2_press.global_position = l2_press.position
	root.push_input(l2_press)
	await process_frame
	root.push_input(d_motion.duplicate()) # out of the drawer: closes it
	await process_frame
	check(game.drawer_open == "", "drag-out closed the drawer again")
	var bad_motion: InputEventMouseMotion = d_motion.duplicate()
	bad_motion.position = Vector2(240, 10) # top bar: nowhere to drop
	bad_motion.global_position = bad_motion.position
	root.push_input(bad_motion)
	await process_frame
	var bad_release: InputEventMouseButton = d_release.duplicate()
	bad_release.position = bad_motion.position
	bad_release.global_position = bad_motion.position
	root.push_input(bad_release)
	await process_frame
	await process_frame
	check(game.drawer_open == "stock" and game.stock.size() == stock_before - 1,
		"a cancelled drop reopens the drawer, placing nothing")

	# setup free repositioning: tap the placed piece, tap another zone tile
	# (the drawer overlays the zone now — an outside tap closes it first)
	_click(game._tile_px(Vector2i(4, 8)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.drawer_open == "", "an outside tap closes the drawer")
	_click(game._tile_px(zone) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	_click(game._tile_px(Vector2i(2, 1)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(Vector2i(2, 1)) and not game.board.has(Vector2i(4, 0)),
		"setup: tap-tap relocates a placed piece freely")

	# selecting a placed piece offers an empty stock slot to put it back
	_click(game._tile_px(Vector2i(2, 1)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	var slots: Array = game.pool_box.get_children().filter(func(b: Node) -> bool:
		return b is Button and b.text == "+" and not b.is_queued_for_deletion())
	check(not slots.is_empty(), "setup: selecting a placed piece shows the put-back slot")

	# and dragging a placed piece onto the stock strip takes it back
	var piece_px: Vector2 = game._tile_px(Vector2i(2, 1)) + Vector2(game.tile, game.tile) / 2
	var strip_px: Vector2 = (game.drawer_buttons["stock"] as Control).get_global_rect().get_center()
	var b_press := InputEventMouseButton.new()
	b_press.button_index = MOUSE_BUTTON_LEFT
	b_press.pressed = true
	b_press.position = piece_px
	b_press.global_position = piece_px
	root.push_input(b_press)
	await process_frame
	var b_motion := InputEventMouseMotion.new()
	b_motion.position = strip_px
	b_motion.global_position = strip_px
	root.push_input(b_motion)
	await process_frame
	var b_release := InputEventMouseButton.new()
	b_release.button_index = MOUSE_BUTTON_LEFT
	b_release.pressed = false
	b_release.position = strip_px
	b_release.global_position = strip_px
	root.push_input(b_release)
	await process_frame
	check(not game.board.has(Vector2i(2, 1)) and game.stock.size() == stock_before,
		"setup: drop on the Stock button returns the piece to stock")

	# tap-to-place regression (2026-07-07): strip rebuilds on press/release used
	# to free the button before its arming tap fired
	check(await _click_button_in(game.hud, "Stock %d" % stock_before),
		"Stock button reopens the drawer")
	await process_frame
	var live_stack: Button = game.pool_box.get_children().filter(func(b: Node) -> bool:
		return b is Button and b.has_meta("id") and not b.is_queued_for_deletion())[0]
	_click(live_stack.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(game.placing_id != "", "setup: tapping a stack arms placement")
	check(game.placing_id != "" and game.textures.has(game.placing_id) \
			and game.stock_armed.get_parent() == game.drawer_buttons["stock"],
		"the armed piece rides the Stock button overlay")
	_click(game._tile_px(Vector2i(6, 8)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.placing_id != "" and game.drawer_open == "",
		"outside tap closes the drawer but keeps the armed piece")
	_click(game._tile_px(Vector2i(6, 1)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(Vector2i(6, 1)), "setup: tapping a zone tile places the piece")

	# clearing the last enemy auto-passes the turn; first, the two properties
	# that need MORE THAN ONE captured piece to mean anything (user 2026-09-10):
	# the section lists one row per piece with the MOST RECENT CAPTURE FIRST,
	# and Convert works WITH A DUPLICATE HELD — the case that used to hand the
	# badge's corner to ▲ and merge instead of converting.
	game.queue_free()
	await process_frame
	GameScript.next_config = {"wave": 3, "gold": 100,
		"captured": ["rook", "bishop", "bishop"], # captured oldest -> newest
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_button_in(game.hud, "Stock 3"), "Stock drawer opens")
	await process_frame
	# issue 96: Captured Stock is its own LABELLED section, not a tinted tail.
	# The two pools obey different rules (a Captured entry can never be
	# deployed, issue 60, nor merged since 2026-09-10) and the only signals
	# were a tint and a tooltip — and a tooltip does not exist on a phone,
	# which is the target platform.
	var pool_labels := ""
	for c in game.hud.pool_box.get_children():
		if c is Label:
			pool_labels += c.text
	check("CAPTURED" in pool_labels,
		"the Captured section is labelled in the pool strip")
	check("no deploy" in pool_labels and "⇄" in pool_labels,
		"and the label carries the rule and the control, not just the name")
	# ONE ROW PER PIECE, NEWEST CAPTURE FIRST: the bishops were captured after
	# the rook, so they sit above it — the reverse of g.captured's own order.
	check(game.captured == ["rook", "bishop", "bishop"],
		"(sanity) the run captured a rook, then two bishops, in that order")
	var cap_order: Array = []
	for row in _pool_rows(game, true):
		cap_order.append(str((row as Button).get_meta("id")))
	check(cap_order == ["bishop", "bishop", "rook"],
		"the Captured section lists one row per piece, most recent first (%s)" % str(cap_order))
	# tapping the entry arms nothing, so the board stays unlit and a following
	# Deploy-tile tap has nothing to place
	var cap_row: Button = _pool_rows(game, true)[0]
	_click(cap_row.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(game._deploy_highlight_tiles().is_empty(),
		"tapping a captured entry paints no deploy targets")
	_click(game._tile_px(Vector2i(5, 6)) + Vector2(game.tile, game.tile) / 2) # close drawer
	await process_frame
	_click(game._tile_px(Vector2i(5, 0)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(not game.board.has(Vector2i(5, 0))
			and game.captured == ["rook", "bishop", "bishop"],
		"and a Deploy-tile tap after it places nothing — Captured Stock never deploys")
	# 2026-09-06: a Convert control ON the captured entry. Conversion lived only
	# in the Shop's Sell mode, which issue 101 locks before Wave 5 — so at Wave
	# 3 these pieces could not be converted at all through the UI. 2026-09-10:
	# it is on EVERY captured entry now, with no arming step and no ▲ merge to
	# lose the corner to when a duplicate is held.
	if game.drawer_open != "stock":
		check(await _click_button_in(game.hud, "Stock 3"), "Stock drawer reopens")
		await process_frame
	await create_timer(0.45).timeout # past the 400 ms double-tap window: a second
		# tap on the same entry inside it opens the piece preview instead
	cap_row = _pool_rows(game, true)[0]
	var convert_badge: Button = null
	for c in cap_row.get_children():
		if c is Button and (c as Button).text.begins_with("⇄"):
			convert_badge = c
	var badge_cost: int = Shop.convert_price(game, "bishop")
	check(convert_badge != null and convert_badge.is_visible_in_tree()
			and convert_badge.text == "⇄$%d" % badge_cost and not convert_badge.disabled,
		"a captured entry shows its Convert badge with no arming step, priced and live at Wave 3")
	var gold_before_convert: int = game.gold
	_click(convert_badge.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(game.captured == ["rook", "bishop"] and game.stock == ["bishop"]
			and game.gold == gold_before_convert - badge_cost,
		"Convert works with a DUPLICATE held: one bishop moves to Stock, priced, nothing merges")
	_click(game._tile_px(Vector2i(5, 6)) + Vector2(game.tile, game.tile) / 2) # close drawer
	await process_frame
	_click(game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	_click(game._tile_px(Vector2i(2, 4)) + Vector2(game.tile, game.tile) / 2)
	await _await_player_turn(game) # auto-pass runs the enemy turn (animated)
	check(game.state == game.State.PLAYER_TURN and game.wave == 4,
		"capturing the last enemy auto-passes into the next wave")

	# stale-overlay regression (2026-07-07): a move must clear the movement
	# shapes with the selection, or arrows keep drawing from _tile_px(-1,-1)
	game.queue_free()
	await process_frame
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"king_abilities": ["move_cost"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_click(game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(not game.legal_paths.is_empty(), "selection builds the shape overlay")
	_click(game._tile_px(Vector2i(4, 4)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(Vector2i(4, 4)) and game.legal_paths.is_empty(),
		"moving clears the movement-shape overlay")

	# Inventory: one button opens a drawer holding both strips; items still
	# usable from it (money-and-shop/03)
	game.queue_free()
	await process_frame
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 3, "items": ["blitz"], "artefacts": ["library-of-alexandria-matchbox"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	# Blitz rework (Notion 2026-08-28): targets ANY own piece, moved or not,
	# costs 0 actions itself, and marks the target's next move/capture free.
	# Move the queen first so this probe also covers the already-moved case
	# (Blitz lifting the one-move-per-piece lock).
	_click(game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	_click(game._tile_px(Vector2i(2, 4)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.moved_this_turn.has(Vector2i(2, 4)), "the queen is spent for the turn")
	check(await _click_button_in(game.hud, "Inventory 2"),
		"Inventory button opens the drawer")
	await process_frame
	check(game.drawer_open == "inventory"
			and game.hud.item_box.is_visible_in_tree()
			and game.hud.artefact_box.is_visible_in_tree(),
		"inventory drawer shows items and artefacts together")
	var inv_acts: int = game.actions_left
	check(await _click_button_in(game.hud.item_box, "Blitz"),
		"item clickable in the inventory drawer")
	await process_frame
	check(game.item_targets.size() == 1 and game.item_targets[0] == Vector2i(2, 4),
		"Blitz offers the queen (its only own piece), whether moved or not")
	_click(game._tile_px(Vector2i(2, 4)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.items.is_empty() and not game.moved_this_turn.has(Vector2i(2, 4))
			and game.actions_left == inv_acts,
		"Blitz costs 0 actions and lifts the one-move-per-piece lock on the already-moved target")
	check(game.board[Vector2i(2, 4)].get("blitz_free_move", false),
		"the target's next move is flagged free")
	_click(game._tile_px(Vector2i(2, 4)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	_click(game._tile_px(Vector2i(2, 5)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(Vector2i(2, 5)) and game.actions_left == inv_acts,
		"the freed second move genuinely happens and still costs no action")

	# Drone Strike: area targeting by real clicks — anchor previews the 3x3,
	# tapping the anchor again confirms the wipe (rework-items/02)
	game.queue_free()
	await process_frame
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["pawn", 1, 4, 4],
		["pawn", 1, 5, 5], ["rook", 1, 7, 10]], "wave": 3, "items": ["drone_strike"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_button_in(game.hud, "Inventory 1"), "Inventory opens for Drone Strike")
	await process_frame # let the drawer lay out before clicking into it
	check(await _click_button_in(game.hud.item_box, "Drone Strike"),
		"Drone Strike clickable in the drawer")
	await process_frame
	_click(game._tile_px(Vector2i(5, 5)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.item_active >= 0 and game.item_targets.size() == 9,
		"anchor click previews the 3x3")
	_click(game._tile_px(Vector2i(5, 5)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(not game.board.has(Vector2i(5, 5)) and not game.board.has(Vector2i(4, 4))
			and game.items.is_empty(),
		"anchor re-click confirms the strike")

	# Extraction: multi targeting by real clicks — taps toggle picks, the
	# floating Extract button confirms (rework-items/03)
	game.queue_free()
	await process_frame
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["knight", 0, 4, 4],
		["rook", 1, 7, 10]], "wave": 3, "items": ["extraction"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_button_in(game.hud, "Inventory 1"), "Inventory opens for Extraction")
	await process_frame # drawer layout before clicking into it
	check(await _click_button_in(game.hud.item_box, "Extraction"),
		"Extraction clickable in the drawer")
	await process_frame
	check(not game.hud.multi_confirm_btn.visible, "no confirm button before any pick")
	_click(game._tile_px(Vector2i(4, 4)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.hud.multi_confirm_btn.visible and game.hud.multi_confirm_btn.text == "Extract 1",
		"picking a piece shows the Extract confirm")
	_click(game.hud.multi_confirm_btn.get_global_rect().get_center())
	await process_frame
	check(not game.board.has(Vector2i(4, 4)) and game.stock.has("knight")
			and game.items.is_empty(),
		"Extract click returns the pick to Stock")

	# Shop: bottom-row button opens the right-edge drawer, which never scrolls
	# — tap a tile to expand it (name/effect/Buy), Buy purchases a piece for
	# gold only, no Action cost (issue 64), the tile greys SOLD in place,
	# Close dismisses (money-and-shop/04, shop-drawer-ui/08)
	game.queue_free()
	await process_frame
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 500}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_button_in(game.hud, "Shop"), "Shop button clickable")
	await process_frame
	check(game.modals.shop_panel != null and game.modals.shop_panel.visible,
		"the shop drawer opens")
	# issue 101: before the unlock Wave the button STAYS and is DISABLED (user
	# ruling — a hidden button reads as "this game has no Shop"), and it names
	# the Wave, because a greyed control with no reason is the failure the
	# ruling was one step away from.
	check(not game.hud.shop_button.disabled and game.hud.shop_button.text == "Shop",
		"the Shop button is live and unlabelled from the unlock Wave on")

	# ...and the locked half of the same ruling, on its own boot one Wave short
	game.queue_free()
	await process_frame
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": Tuning.SHOP_UNLOCK_WAVE - 1, "gold": 500}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.hud.shop_button.disabled,
		"the Shop button is DISABLED the Wave before it unlocks")
	check("%d" % Tuning.SHOP_UNLOCK_WAVE in game.hud.shop_button.text,
		"and says which Wave it opens on (%s)" % game.hud.shop_button.text)
	check(not await _click_button_in(game.hud, "Shop"),
		"a disabled Shop button is not the plain \"Shop\" control any more")

	# restore what the checks below expect: an unlocked run with the Shop drawer
	# OPEN. The locked-state boot above consumed the instance they were written
	# against, and leaving it would fail them on state, not on behaviour.
	game.queue_free()
	await process_frame
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 500}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_button_in(game.hud, "Shop"), "Shop reopens after the locked-state check")
	await process_frame

	# issue 64: the Lane B restock progress bar — a real Control built by
	# show_shop(), so it needs the windowed probe (headless drops GUI
	# picking/layout the same way it drops clicks).
	check(game.modals.shop_lane_b_bar != null, "the Shop drawer builds a Lane B progress bar")
	check(game.modals.shop_lane_b_bar.max_value == Tuning.SHOP_LANE_B_SCORE,
		"the bar's range matches the Lane B threshold")
	check(game.modals.shop_lane_b_bar.value == game.shop_lane_b_progress,
		"the bar's value reflects g.shop_lane_b_progress on open (0, fresh run)")
	# Derived from the gate, not a literal: this was hardcoded 6300, which sat
	# below the old 10,000 threshold but ABOVE the 5,000 it became on
	# 2026-09-07 — so the ProgressBar clamped it to max_value and the assertion
	# failed on a tuning change rather than a real regression. Two thirds of
	# the gate is always mid-bar, and stays non-round so a clamp or a reset to
	# zero still reads as a failure.
	var probe_progress: int = Tuning.SHOP_LANE_B_SCORE * 2 / 3
	game.shop_lane_b_progress = probe_progress
	game.modals.show_shop() # rebuild, same as reopening after a Score gain
	await process_frame
	check(game.modals.shop_lane_b_bar.value == probe_progress,
		"the bar tracks g.shop_lane_b_progress after it changes and the drawer rebuilds")

	var tile: Button = null # first affordable piece tile — every slot is visible, none scrolled
	var tile_index := -1
	var to_visit: Array = [game.modals.shop_panel]
	while not to_visit.is_empty():
		var n: Node = to_visit.pop_back()
		if n is Button and n.has_meta("shop_index"):
			var idx: int = n.get_meta("shop_index")
			var slot: Dictionary = game.shop_stock[idx]
			if slot.kind == "piece" and ShopScript.can_buy(game, slot):
				tile = n
				tile_index = idx
				break
		to_visit.append_array(n.get_children())
	check(tile != null, "an affordable piece tile exists")
	_click(tile.get_global_rect().get_center())
	await process_frame
	check(game.modals.shop_expanded_index == tile_index, "tapping a tile expands it")
	var sh_stock: int = game.stock.size()
	var sh_gold: int = game.gold
	var sh_acts: int = game.actions_left
	check(await _click_button_in(game.modals.shop_panel, "Buy"),
		"Buy clickable in the expanded tile")
	await process_frame
	check(game.stock.size() == sh_stock + 1 and game.gold < sh_gold
			and game.actions_left == sh_acts,
		"shop Buy adds the piece and debits gold, never an Action (issue 64)")
	check(game.shop_stock[tile_index].sold, "the bought slot is marked sold")
	var sold_tile: Button = null
	to_visit = [game.modals.shop_panel]
	while not to_visit.is_empty():
		var n: Node = to_visit.pop_back()
		if n is Button and n.has_meta("shop_index") and n.get_meta("shop_index") == tile_index:
			sold_tile = n
			break
		to_visit.append_array(n.get_children())
	check(sold_tile != null and sold_tile.modulate.a < 0.9,
		"the sold tile greys out and stays in place")
	var shows_sold: bool = await _click_button_in(game.modals.shop_panel, "SOLD")
	var still_shows_buy: bool = await _click_button_in(game.modals.shop_panel, "Buy")
	check(shows_sold and not still_shows_buy, "the expanded detail now shows SOLD instead of Buy")
	check(await _click_button_in(game.modals.shop_panel, "Close"), "shop Close clickable")
	await process_frame
	check(not game.modals.shop_panel.visible, "the shop drawer closes")

	# Selling + Captured -> Stock conversion (issue 60): the Shop drawer's
	# Sell/Buy toggle swaps in held Stock/Captured/Item/Artefact tiles for
	# the shop_stock ones, so Sell can never be confused with Buy. A
	# Captured Stock tile's detail dock offers BOTH Convert and Sell.
	game.queue_free()
	await process_frame
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 500, "stock": ["pawn"], "captured": ["pawn"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_button_in(game.hud, "Shop"), "Shop button clickable")
	await process_frame
	check(await _click_button_in(game.modals.shop_panel, "Sell"), "the Sell toggle is clickable")
	await process_frame
	check(game.modals.shop_sell_mode, "the Shop drawer switches to Sell mode")

	var piece_tile: Button = null
	var to_visit_sell: Array = [game.modals.shop_panel]
	while not to_visit_sell.is_empty():
		var n: Node = to_visit_sell.pop_back()
		if n is Button and n.has_meta("sell_kind") and n.get_meta("sell_kind") == "piece":
			piece_tile = n
			break
		to_visit_sell.append_array(n.get_children())
	check(piece_tile != null, "a Stock sell tile exists")
	_click(piece_tile.get_global_rect().get_center())
	await process_frame
	check(game.modals.sell_expanded_kind == "piece" and game.modals.sell_expanded_index == 0,
		"tapping a Stock sell tile expands it")
	var sell_stock_before: int = game.stock.size()
	var sell_gold_before: int = game.gold
	var sell_acts_before: int = game.actions_left
	check(await _click_button_in(game.modals.shop_panel, "Sell (+$5)"),
		"the Sell button in the expanded detail is clickable (pawn value 10, 50% floored = 5)")
	await process_frame
	check(game.stock.size() == sell_stock_before - 1 and game.gold == sell_gold_before + 5
			and game.actions_left == sell_acts_before,
		"selling the Stock piece removes it, pays Gold, and costs no Action (issue 64)")

	var cap_tile: Button = null
	to_visit_sell = [game.modals.shop_panel]
	while not to_visit_sell.is_empty():
		var n: Node = to_visit_sell.pop_back()
		if n is Button and n.has_meta("sell_kind") and n.get_meta("sell_kind") == "captured":
			cap_tile = n
			break
		to_visit_sell.append_array(n.get_children())
	check(cap_tile != null, "a Captured Stock sell tile exists")
	_click(cap_tile.get_global_rect().get_center())
	await process_frame
	check(game.modals.sell_expanded_kind == "captured", "tapping a Captured tile expands it")
	var captured_before: int = game.captured.size()
	var stock_before2: int = game.stock.size()
	var gold_before2: int = game.gold
	var convert_acts_before: int = game.actions_left
	# issue 97: the Convert button carries its price, and that price now comes
	# from CONVERT_RATE rather than SELL_RATE — so read it from the game rather
	# than hardcoding a number that moves whenever the rate is tuned.
	var convert_cost: int = Shop.convert_price(game, game.captured[0])
	var convert_label := "Convert ($%d)" % convert_cost
	check(await _click_button_in(game.modals.shop_panel, convert_label),
		"Convert is clickable (%s)" % convert_label)
	await process_frame
	check(game.captured.size() == captured_before - 1 and game.stock.size() == stock_before2 + 1
			and game.gold == gold_before2 - convert_cost and game.actions_left == convert_acts_before,
		"converting moves the piece from Captured Stock into ordinary Stock, debits Gold, costs no Action (issue 64)")

	check(await _click_button_in(game.modals.shop_panel, "Buy"), "the toggle switches back to Buy mode")
	await process_frame
	check(not game.modals.shop_sell_mode, "the Shop drawer is back in Buy mode")

	# Direct deploy is gone (issue 60) and so is the merge (2026-09-10): the tap
	# that used to arm a Captured stack arms nothing now, so a following
	# Deploy-tile tap has nothing to place. Driven through the REAL tap rather
	# than by setting the armed flags — there are none left to set — and paired
	# with the Stock control, because "nothing was placed" is also what a tap
	# swallowed by the open Shop panel would look like.
	game.stock.append("pawn") # a fresh Stock piece so the drawer has both
	game.captured.append("pawn") # the Convert above emptied Captured Stock
	game._refresh()
	var deploy_target := Vector2i(-1, -1)
	for t in game._deploy_tiles():
		if not game.board.has(t):
			deploy_target = t
			break
	check(deploy_target.x >= 0, "(sanity) an open Deploy tile exists")
	game._on_stack_pressed("pawn", true, 1)
	check(game._deploy_highlight_tiles().is_empty(),
		"tapping a Captured entry paints no deploy targets")
	game._on_tile_clicked(deploy_target)
	check(not game.board.has(deploy_target) and game.captured == ["pawn"],
		"and a Deploy-tile tap after it deploys nothing")
	game._on_stack_pressed("pawn", false, 1) # the Stock pawn, same two calls
	check(not game._deploy_highlight_tiles().is_empty(),
		"(control) the Stock entry DOES arm and light the board")
	game._on_tile_clicked(deploy_target)
	check(game.board.has(deploy_target) and game.board[deploy_target].id == "pawn",
		"(control) and the very same Deploy-tile tap deploys a STOCK piece")

	# Jet Fuel Vial (issue 52): a Shop-only control, restock button appears
	# only while it's held — confirm-gated, same as every untargeted
	# activation (user ruling).
	game.queue_free()
	await process_frame
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 100, "artefacts": ["jet-fuel-vial"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_button_in(game.hud, "Shop"), "Shop button clickable")
	await process_frame
	check(await _click_button_in(game.modals.shop_panel, "Restock ($20)"),
		"the Restock button shows and is clickable while Jet Fuel Vial is held")
	await process_frame
	check(game.buff_pick_open and game.modals.buff_panel.visible,
		"clicking Restock opens the confirm modal (untargeted activation)")
	check(await _click_button_in(game.modals.buff_panel, "Cancel"), "Cancel clickable on the restock confirm")
	await process_frame
	check(not game.buff_pick_open and game.gold == 100 and not game.jet_fuel_used_this_wave,
		"cancelling the restock confirm costs nothing")
	check(await _click_button_in(game.modals.shop_panel, "Restock ($20)"), "Restock clickable again after a cancel")
	await process_frame
	check(await _click_button_in(game.modals.buff_panel, "Confirm"), "Confirm clickable on the restock confirm")
	await process_frame
	check(game.gold == 80 and game.jet_fuel_used_this_wave,
		"confirming restocks the Shop: 20 Gold spent, the once-per-Wave charge used")
	var restock_btn: Button = _button_prefix(game.modals.shop_panel, "Restock")
	check(restock_btn != null and restock_btn.disabled,
		"the Restock button greys out once used this Wave — visibly unavailable, not silently inert")
	_click(restock_btn.get_global_rect().get_center()) # Godot doesn't fire
		# `pressed` on a disabled Button — this must be a genuine no-op
	await process_frame
	check(not game.buff_pick_open, "clicking the disabled Restock button opens nothing")

	# the Shop is reachable in any state, not just your turn (GDD Shop page)
	var was_state: int = game.state
	game.state = game.State.ENEMY_TURN
	check(await _click_button_in(game.hud, "Shop"), "Shop button clickable off-turn")
	await process_frame
	check(game.modals.shop_panel.visible, "the shop opens during the enemy turn")
	check(await _click_button_in(game.modals.shop_panel, "Close"), "off-turn shop closes")
	await process_frame
	game.state = was_state

	# All-Seeing Eye Contact Lens (issue 49): the Shop's box detail dock
	# reveals contents only while holding it. A fresh boot so it's definitely
	# held, then expand whichever Box slot rolled (preferring Huge — 7
	# entries — when one shows up) and confirm the reveal Label carries the
	# slot's exact contents WITHOUT breaking the Buy button underneath it —
	# the concrete risk of a variable-length reveal in a fixed-height dock.
	game.queue_free()
	await process_frame
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 500, "artefacts": ["all-seeing-eye-contact-lens"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_button_in(game.hud, "Shop"), "(setup) Shop button clickable, All-Seeing Eye held")
	await process_frame
	var box_slot_index := -1
	var box_slot_size := ""
	for idx in game.shop_stock.size():
		var s: Dictionary = game.shop_stock[idx]
		if s.kind == "box" and (box_slot_index == -1 or s.size == "huge"):
			box_slot_index = idx
			box_slot_size = s.size
			if s.size == "huge": # the worst case (7 entries) — stop as soon as it's found
				break
	check(box_slot_index >= 0, "(setup) a Box slot exists to expand")
	var box_button: Button = null
	to_visit = [game.modals.shop_panel]
	while not to_visit.is_empty():
		var n: Node = to_visit.pop_back()
		if n is Button and n.has_meta("shop_index") and n.get_meta("shop_index") == box_slot_index:
			box_button = n
			break
		to_visit.append_array(n.get_children())
	check(box_button != null, "(setup) the Box tile is clickable")
	_click(box_button.get_global_rect().get_center())
	await process_frame
	var reveal_label: Label = null
	to_visit = [game.modals.shop_panel]
	while not to_visit.is_empty():
		var n: Node = to_visit.pop_back()
		if n is Label and n.text.begins_with("Contains: "):
			reveal_label = n
			break
		to_visit.append_array(n.get_children())
	var expect_reveal := "Contains: %s" % Box.contents_names(game.shop_stock[box_slot_index].contents)
	check(reveal_label != null and reveal_label.text == expect_reveal,
		"All-Seeing Eye Contact Lens: the %s Box's reveal Label shows its exact contents" % box_slot_size)
	check(await _click_button_in(game.modals.shop_panel, "Buy"),
		"...and the Buy button underneath it is still clickable, even at Huge's 7-entry worst case")

	# reinforcement shop: opens pending at turn start, Buy is free and adds
	# to stock, Done hands the turn back
	game.queue_free()
	await process_frame
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 11, "score": 100, "pending_reinforce": true,
		"king_abilities": ["move_cost"]} # the tariff section below reuses this boot
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.reinforce_panel != null and game.reinforce_panel.visible,
		"the reinforcement shop opens at turn start")
	# Same NO-5 question for the panel that now opens every 10 Waves. Tile (2,2)
	# holds the player queen, and the control below the tariff section proves
	# this exact tap selects her with no panel up.
	game.selected = Vector2i(-1, -1)
	_click(game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.selected == Vector2i(-1, -1),
		"NO-5: a board tap under the open reinforcement pick selects nothing")
	check(game.reinforce_panel.visible, "...and the pick is still open")
	var r_stock: int = game.stock.size()
	check(await _click_button_in(game.reinforce_panel, "Buy"), "Buy clickable")
	await process_frame
	check(game.stock.size() == r_stock + 1 and game.score == 100 and game.gold == 0,
		"Buy adds the piece to stock for free")
	check(await _click_button_in(game.reinforce_panel, "Done"), "Done clickable")
	await process_frame
	check(not game.reinforce_panel.visible and not game.pending_reinforce,
		"Done closes the shop and clears the pending flag")

	# tariff button in the top row opens the detail overlay
	check(await _click_button_in(game.hud, "⚠1"), "tariff button clickable")
	await process_frame
	check(game.king_ability_panel != null and game.king_ability_panel.visible, "tariff overlay opens")

	# NO-5: the three ad-hoc panels are PanelContainers on a CanvasLayer, and
	# Container defaults to MOUSE_FILTER_PASS with no MOUSE_FILTER_STOP
	# ancestor — so a tap in the panel's empty area fell straight through to the
	# board. Tile (2,2) holds the player queen, so a leaked tap SELECTS her:
	# this fails loudly rather than passing vacuously the way a click on an
	# empty tile would. The second assertion is the consumed-click guard — if
	# the tap had instead landed on the panel's own Close button the overlay
	# would be gone, and "selected nothing" would have been true for the wrong
	# reason.
	game.selected = Vector2i(-1, -1)
	# NO-33: FIND the tile rather than naming it, for the reason the paragraph
	# above already gives — the tap has to hold a PLAYER piece (so a leak selects
	# it and fails loudly) AND sit off the overlay's own buttons (so a consumed
	# click cannot masquerade as a blocked one). Hardcoding (2,2) satisfied both
	# only at the board geometry of the day; a taller board moved it onto Close.
	var tap := Vector2(-1, -1)
	var overlay_btns: Array = game.king_ability_panel.find_children("*", "Button", true, false)
	for pos in game.board:
		if int(game.board[pos].owner) != 0:
			continue
		var o: Vector2 = game._tile_px(pos)
		var t: float = float(game.tile)
		# ANY point inside the tile selects the piece if the tap leaks, so sample
		# a few rather than only the centre: the overlay's Close button covers
		# the middle of this tile and used to clear it by 12px, which is the
		# whole reason the hardcoded version broke when the board grew.
		for f in [Vector2(0.5, 0.5), Vector2(0.5, 0.12), Vector2(0.5, 0.88),
				Vector2(0.12, 0.5), Vector2(0.88, 0.5)]:
			var c := o + Vector2(t * f.x, t * f.y)
			var on_button := false
			for b in overlay_btns:
				if (b as Button).get_global_rect().has_point(c):
					on_button = true
					break
			if not on_button:
				tap = c
				break
		if tap.x >= 0.0:
			break
	check(tap.x >= 0.0,
		"(setup) a point on a player-held tile sits clear of the overlay's buttons")
	_click(tap)
	await process_frame
	check(game.selected == Vector2i(-1, -1),
		"NO-5: a board tap under the open tariff overlay selects nothing")
	check(game.king_ability_panel.visible,
		"...and the overlay is still open — the tap was blocked, not consumed by Close")

	check(await _click_button_in(game.king_ability_panel, "Close"), "tariff Close clickable")
	await process_frame
	check(not game.king_ability_panel.visible, "tariff overlay closes")

	# CONTROL for the NO-5 assertion above: the very same click, with no panel
	# up, MUST select the queen. Without this the "selects nothing" assertion is
	# satisfiable by a click that never reached the board at all.
	game.selected = Vector2i(-1, -1)
	_click(game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.selected == Vector2i(2, 2),
		"control: the same tap DOES select once the overlay is closed")
	game.selected = Vector2i(-1, -1)

	# Arrow Planning: decorative-only drawing mode (gdd-gaps/10) — toggle,
	# draw, clear-one (redraw), Clear-all, lifetime clears at turn end
	game.queue_free()
	await process_frame
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_button_in(game.hud, "Arrows"), "Arrows button clickable")
	await process_frame
	check(game.arrow_mode, "Arrows toggles arrow mode on")
	var qpx2: Vector2 = game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2
	_click(qpx2)
	await process_frame
	check(game.selected == Vector2i(-1, -1), "arrow mode stops board taps from selecting")

	var a_to: Vector2 = game._tile_px(Vector2i(4, 4)) + Vector2(game.tile, game.tile) / 2
	var a_press := InputEventMouseButton.new()
	a_press.button_index = MOUSE_BUTTON_LEFT
	a_press.pressed = true
	a_press.position = qpx2
	a_press.global_position = qpx2
	var a_motion := InputEventMouseMotion.new()
	a_motion.position = a_to
	a_motion.global_position = a_to
	var a_release := InputEventMouseButton.new()
	a_release.button_index = MOUSE_BUTTON_LEFT
	a_release.pressed = false
	a_release.position = a_to
	a_release.global_position = a_to

	root.push_input(a_press.duplicate())
	await process_frame
	root.push_input(a_motion.duplicate())
	await process_frame
	root.push_input(a_release.duplicate())
	await process_frame
	check(game.arrows.size() == 1 and game.arrows[0].from == Vector2i(2, 2)
			and game.arrows[0].to == Vector2i(4, 4),
		"dragging on the board draws an arrow")
	check(not game.board.has(Vector2i(4, 4)) and game.selected == Vector2i(-1, -1),
		"arrow drawing never places, moves or selects anything")

	root.push_input(a_press.duplicate())
	await process_frame
	root.push_input(a_motion.duplicate())
	await process_frame
	root.push_input(a_release.duplicate())
	await process_frame
	check(game.arrows.is_empty(), "redrawing the same arrow clears it (clear-one)")

	root.push_input(a_press.duplicate())
	await process_frame
	root.push_input(a_motion.duplicate())
	await process_frame
	root.push_input(a_release.duplicate())
	await process_frame
	check(game.arrows.size() == 1, "a fresh arrow can be redrawn")
	check(await _click_button_in(game.hud, "Clear"), "Clear button clickable")
	await process_frame
	check(game.arrows.is_empty(), "Clear removes every arrow")

	check(await _click_button_in(game.hud, "Arrows"), "Arrows button toggles off")
	await process_frame
	check(not game.arrow_mode, "arrow mode is off again")
	_click(qpx2)
	await process_frame
	check(game.selected == Vector2i(2, 2), "board taps select pieces again once arrow mode is off")
	_click(qpx2) # deselect before the lifetime check below
	await process_frame

	check(await _click_button_in(game.hud, "Arrows"), "Arrows re-enabled")
	await process_frame
	root.push_input(a_press.duplicate())
	await process_frame
	root.push_input(a_motion.duplicate())
	await process_frame
	root.push_input(a_release.duplicate())
	await process_frame
	check(game.arrows.size() == 1, "an arrow exists before PASS")
	_click(game.pass_button.get_global_rect().get_center())
	await _await_player_turn(game)
	check(game.arrows.is_empty(), "arrows clear at turn end (scratchpad, never saved)")

	# --- Artefact activation (issue 52): the Activate section, confirm/
	# cancel, and Bovine Tractor Beam's targeted cancel. New interactive UI —
	# Godot headless drops GUI picking, which is why this probe exists.
	game.queue_free()
	await process_frame
	GameScript.next_config = {"wave": 1, "gold": 100, "score": 0,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"artefacts": ["oak-island-wishing-well"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	# (the empty-vs-held Activate-section sizing itself is asserted headlessly
	# in test_items_artefacts_4.gd; this probe exists for CLICKABILITY, which
	# headless can't verify — Godot headless drops GUI picking)
	check(await _click_button_in(game.hud, "Inventory 1"), "Inventory opens for Oak Island Wishing Well")
	await process_frame
	# NO-32: issue 67 put an Army Ability chip in this row too, so the Ability
	# was reachable from two places and the count here was 2. The chip is gone;
	# the row is Artefact-only again.
	check(game.hud.activate_box.get_child_count() == 1,
		"the drawer shows ONE Activate chip: the Artefact's, and no Army Ability chip")
	var star_chips := 0
	for c in game.hud.activate_box.get_children():
		if c is Button and (c as Button).text.begins_with("★"):
			star_chips += 1
	check(star_chips == 0,
		"no ★ chip survives in the Activate row — the Ability has exactly one home")
	check(await _click_button_in(game.hud.activate_box, "⚡Oak Island Wishing Well"),
		"the Activate chip is clickable")
	await process_frame
	check(game.buff_pick_open and game.modals.buff_panel.visible,
		"clicking an untargeted Activate chip opens the confirm modal (user ruling: no target = confirm)")
	check(await _click_button_in(game.modals.buff_panel, "Cancel"), "Cancel clickable on the confirm modal")
	await process_frame
	check(not game.buff_pick_open and game.gold == 100 and not game.oak_island_used_this_turn \
			and game._artefact_count("oak-island-wishing-well") == 1,
		"cancelling the confirm costs nothing — no Gold, no charge, Artefact untouched")
	# the confirm modal is the only thing that closed — this activation never
	# touches the drawer (unlike a targeted Item), so the chip is still
	# directly clickable with no need to reopen Inventory
	check(await _click_button_in(game.hud.activate_box, "⚡Oak Island Wishing Well"),
		"the Activate chip is clickable again after a cancel, drawer untouched")
	await process_frame
	check(await _click_button_in(game.modals.buff_panel, "Confirm"), "Confirm clickable on the confirm modal")
	await process_frame
	check(not game.buff_pick_open and game.gold == 475 and game.score == 4000, # issue 57:
			# Score x10 (400 -> 4000), Gold untouched
		"confirming activates it: 25 Gold spent, +400 Score (earn() also grants " +
		"the matching Gold, same as every other reward routed through it: 100 - 25 + 400 = 475)")

	# Bovine Tractor Beam: the one TARGETED activation — no confirm modal;
	# tapping the chip again mid-targeting cancels instead (user ruling).
	# Targeting DOES hand the drawer back to the board (same as a targeted
	# Item), so cancelling requires reopening Inventory to reach the chip.
	game.queue_free()
	await process_frame
	GameScript.next_config = {"wave": 1,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"artefacts": ["bovine-tractor-beam"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_button_in(game.hud, "Inventory 1"), "Inventory opens for Bovine Tractor Beam")
	await process_frame
	check(await _click_button_in(game.hud.activate_box, "⚡Bovine Tractor Beam"),
		"the Bovine Tractor Beam chip is clickable")
	await process_frame
	check(not game.buff_pick_open and game.artefact_targeting_key == "bovine-tractor-beam" \
			and game.hud.drawer_open == "",
		"clicking Bovine's chip stages targeting and hands the board back — no confirm modal (it has a target instead)")
	_click(game._tile_px(Vector2i(7, 10)) + Vector2(game.tile, game.tile) / 2) # stage A: the enemy Rook
	await process_frame
	check(game.artefact_target_stage_a == Vector2i(7, 10), "tapping the enemy Rook on the board stages it")
	check(await _click_button_in(game.hud, "Inventory 1"), "Inventory reopens to reach the chip mid-targeting")
	await process_frame
	check(await _click_button_in(game.hud.activate_box, "⚡Bovine Tractor Beam"),
		"the chip stays clickable mid-targeting (to cancel)")
	await process_frame
	check(game.artefact_targeting_key == "" and game.board.has(Vector2i(7, 10)) \
			and not game.bovine_used_this_wave and game._artefact_count("bovine-tractor-beam") == 1,
		"tapping the chip again CANCELS FROM TARGETING — no move, no charge, Artefact untouched")
	check(await _click_button_in(game.hud.activate_box, "⚡Bovine Tractor Beam"),
		"the chip is clickable again after a targeting cancel (drawer still open post-cancel)")
	await process_frame
	_click(game._tile_px(Vector2i(7, 10)) + Vector2(game.tile, game.tile) / 2) # stage A again
	await process_frame
	var bovine_dest: Vector2i = game.artefact_targets[0]
	_click(game._tile_px(bovine_dest) + Vector2(game.tile, game.tile) / 2) # stage B: commit
	await process_frame
	check(game.artefact_targeting_key == "" and not game.board.has(Vector2i(7, 10)) \
			and game.board.get(bovine_dest, {}).get("id", "") == "rook" and game.bovine_used_this_wave,
		"completing both taps relocates the enemy piece and spends the once-per-Wave charge")

	# --- issue 67: the Army Ability chip — same Activate section, but 1
	# Action (not 0) and its own confirm-vs-targeting shapes. Old Guard's
	# Shield Wall is untargeted (confirm modal, same shape as Oak Island
	# above); The Muster's Call the Banners is targeted, but at a STOCK
	# entry, not a board tile (Bovine's own targeting flow above never
	# applies) — its cancel/commit both happen through the Stock drawer.
	game.queue_free()
	await process_frame
	GameScript.next_config = {"army": "Old Guard", "wave": 1, "gold": 0,
		"board": [["pawn", 0, 2, 0], ["rook", 1, 7, 10]]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(_click_ability(game),
		"the Army Ability is clickable on the deck — no drawer to open (NO-32)")
	await process_frame
	check(game.buff_pick_open and game.modals.buff_panel.visible,
		"clicking an untargeted Army Ability opens the confirm modal, same as an untargeted Artefact")
	check(await _click_button_in(game.modals.buff_panel, "Cancel"), "Cancel clickable on the confirm modal")
	await process_frame
	check(not game.buff_pick_open and game.actions_left == Tuning.ACTIONS_PER_TURN \
			and not game.army_ability_used_this_wave,
		"cancelling the confirm costs nothing — no Action spent, Wave flag untouched")
	check(_click_ability(game),
		"the deck button is clickable again after a cancel")
	await process_frame
	check(await _click_button_in(game.modals.buff_panel, "Confirm"), "Confirm clickable on the confirm modal")
	await process_frame
	check(not game.buff_pick_open and game.army_ability_used_this_wave \
			and game.actions_left == Tuning.ACTIONS_PER_TURN - 1 \
			and game.board[Vector2i(2, 0)].get("buffs", []).size() == 1,
		"confirming activates it: 1 Action spent, the back-row pawn gains Shield")

	# The Muster's Call the Banners: targeted at a Stock entry.
	game.queue_free()
	await process_frame
	GameScript.next_config = {"army": "Crown", "wave": 1,
		"stock": ["pawn"], "board": [["rook", 1, 7, 10]]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(_click_ability(game), "Call the Banners is clickable on the deck")
	await process_frame
	check(not game.buff_pick_open and game.army_targeting and game.hud.drawer_open == "stock",
		"clicking Call the Banners stages targeting and switches straight to the Stock drawer — no confirm modal")
	# Targeting switched the drawer to Stock (that IS its targeting surface).
	# The chip used to go out of reach here, needing an Inventory reopen; the
	# deck button never does, which is the point of NO-32.
	check(_click_ability(game),
		"tapping the deck button again mid-targeting cancels (slice 52's rule), with no drawer step")
	await process_frame
	check(not game.army_targeting and game.stock.size() == 1 and not game.army_ability_used_this_wave,
		"cancelling FROM TARGETING costs nothing — no duplicate, no charge")
	check(_click_ability(game),
		"the deck button is clickable again after a targeting cancel")
	await process_frame
	check(game.pool_box.get_child_count() == 1, "(setup) the Stock strip shows the one pawn stack")
	var pawn_stack: Button = _first_pool_stack(game)
	_click(pawn_stack.get_global_rect().get_center()) # the tap IS the target — no separate confirm
	await process_frame
	check(not game.army_targeting and game.stock.size() == 2 and game.stock.count("pawn") == 2 \
			and game.army_ability_used_this_wave,
		"tapping the Stock stack duplicates it (2 pawns in Stock now) and spends the once-per-Wave charge")

	# --- issue 68: Hostile Takeover (The Syndicate) — the OTHER targeted
	# Army Ability, a BOARD target (not a Stock one), so it follows Bovine
	# Tractor Beam's flow above: no confirm modal, targeting hands the drawer
	# back to the board, tap-the-chip-again cancels.
	game.queue_free()
	await process_frame
	GameScript.next_config = {"army": "Syndicate", "wave": 1, "gold": 1000,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(_click_ability(game), "Hostile Takeover is clickable on the deck")
	await process_frame
	check(not game.buff_pick_open and game.army_board_targeting and game.hud.drawer_open == "",
		"clicking Hostile Takeover stages targeting and hands the board back — no confirm modal (it has a target instead)")
	check(_click_ability(game),
		"the deck button stays clickable mid-targeting (to cancel), with no drawer step")
	await process_frame
	check(not game.army_board_targeting and game.board.has(Vector2i(7, 10)) \
			and not game.army_ability_used_this_wave and game.gold == 1000,
		"tapping the chip again CANCELS FROM TARGETING — no purchase, no charge, board untouched")
	check(_click_ability(game),
		"the deck button is clickable again after a targeting cancel")
	await process_frame
	_click(game._tile_px(Vector2i(7, 10)) + Vector2(game.tile, game.tile) / 2) # the enemy Rook: commit
	await process_frame
	check(not game.army_board_targeting and not game.board.has(Vector2i(7, 10)) \
			and game.stock.has("rook") and game.army_ability_used_this_wave,
		"tapping the enemy Rook completes Hostile Takeover: it leaves the board and joins Stock")

	# --- issue 68: Conscription (The Horde) — untargeted, same confirm shape
	# as Shield Wall/Oak Island above.
	game.queue_free()
	await process_frame
	GameScript.next_config = {"army": "Horde", "wave": 5,
		"board": [["pawn", 0, 2, 2], ["rook", 1, 7, 10]]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(_click_ability(game), "Conscription is clickable on the deck")
	await process_frame
	check(game.buff_pick_open and game.modals.buff_panel.visible,
		"clicking untargeted Conscription opens the confirm modal, same as an untargeted Artefact")
	check(await _click_button_in(game.modals.buff_panel, "Cancel"), "Cancel clickable on the confirm modal")
	await process_frame
	check(not game.buff_pick_open and game.stock.is_empty() and not game.army_ability_used_this_wave,
		"cancelling the confirm costs nothing — no pawns added, Wave flag untouched")
	check(_click_ability(game),
		"the deck button is clickable again after a cancel")
	await process_frame
	check(await _click_button_in(game.modals.buff_panel, "Confirm"), "Confirm clickable on the confirm modal")
	await process_frame
	check(not game.buff_pick_open and game.army_ability_used_this_wave \
			and game.stock.size() == 2 and game.stock.count("pawn") == 2,
		"confirming activates it: 2 pawns added to Stock")

	print("---")
	if fails == 0:
		print("ALL GAME CLICKS OK")
	quit(1 if fails > 0 else 0)


## First reward button in the box panel (options precede the Skip button).
## NO-38: the Box's own sell row — the first Button whose text starts "Sell ".
func _sell_button(node: Node) -> Button:
	if node is Button and node.text.begins_with("Sell "):
		return node
	for c in node.get_children():
		var hit := _sell_button(c)
		if hit:
			return hit
	return null


func _first_option_button(node: Node) -> Button:
	if node is Button and not node.text.begins_with("Skip"):
		return node
	for c in node.get_children():
		var hit := _first_option_button(c)
		if hit:
			return hit
	return null


## First button whose text starts with `prefix` — the box modal's Reroll
## button (issue 46) carries a dynamic "(N left)" suffix, so it can't be
## matched by exact text like _click_button_in does.
func _button_prefix(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix):
		return node
	for c in node.get_children():
		var hit := _button_prefix(c, prefix)
		if hit:
			return hit
	return null


## Opens the Shop, taps the first affordable Box tile to expand it, then
## clicks Buy — issue 47: Boxes only come from the Shop now (the box-carrier
## enemy is gone), so every Box click-probe drives this same real-click path.
## Assumes the Shop is closed and the player's turn is active on entry.
func _buy_a_box(game: Node2D) -> void:
	check(await _click_button_in(game.hud, "Shop"), "Shop button clickable")
	await process_frame
	var tile: Button = null
	var tile_index := -1
	var to_visit: Array = [game.modals.shop_panel]
	while not to_visit.is_empty():
		var n: Node = to_visit.pop_back()
		if n is Button and n.has_meta("shop_index"):
			var idx: int = n.get_meta("shop_index")
			var slot: Dictionary = game.shop_stock[idx]
			if slot.kind == "box" and ShopScript.can_buy(game, slot):
				tile = n
				tile_index = idx
				break
		to_visit.append_array(n.get_children())
	check(tile != null, "(setup) an affordable Box tile exists")
	_click(tile.get_global_rect().get_center())
	await process_frame
	check(await _click_button_in(game.modals.shop_panel, "Buy"), "(setup) Buy clickable on the expanded Box tile")
	await process_frame
