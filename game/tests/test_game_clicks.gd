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


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		root.push_input(ev)


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
		"captured": ["pawn", "pawn"],
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

	# Buttonless merging: dragging the captured pawn stack onto itself promotes
	# the pair (same-stack pairs merge by drag; tap-again means deselect)
	check(await _click_button_in(game.hud, "Stock 2"), "Stock button opens the drawer")
	await process_frame
	check(game.drawer_open == "stock" and game.pool_box.is_visible_in_tree(),
		"stock drawer is open and shows the pool strip")
	# issue 96 added a VSeparator + label before the Captured section, so the
	# strip is no longer buttons-only — count the STACKS, not the children.
	var pool_stacks: Array = game.pool_box.get_children().filter(
		func(n: Node) -> bool: return n is Button)
	check(pool_stacks.size() == 1, "2 captured pawns show as one stack")
	var stack: Button = _first_pool_stack(game)
	_click(stack.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(game.placing_id == "pawn" and game.placing_cap,
		"tapping the stack arms it (no merge on tap — 2026-07-07)")
	var badges: Array = []
	for b in game.pool_box.get_children():
		if b.is_queued_for_deletion():
			continue
		for c in b.get_children():
			if c is Button and c.text.begins_with("▲"):
				badges.append(c)
	check(not badges.is_empty(), "an armed promotable stack shows the ▲ button")
	# issue 97/98: the badge carries the merge's PRICE, on the control that
	# starts the merge. Close Ranks does not make it free — that Power waives
	# the Action only (merge_logic.can_afford_merge), so the Gold always shows.
	check(badges[0].text == "▲$%d" % Tuning.MERGE_COST,
		"and the ▲ badge shows what the merge costs (%s)" % badges[0].text)
	_click((badges[0] as Button).get_global_rect().get_center())
	await process_frame
	check(game.pending_merge.size() == 2, "the ▲ badge asks for merge confirmation")
	check(game.captured.size() == 2, "nothing merges before confirmation")
	check(await _click_button_in(game.hud, "Merge"), "confirm button clickable")
	await process_frame
	check(game.stock == ["sergeant"] and game.captured.is_empty(),
		"confirming promotes the pawn pair into stock")

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

	# ONE ICON SIZE. Items were 30px, stock stacks 46, the strip 52 before this
	# was pulled onto a single constant; nothing but a pin stops them drifting
	# apart again, because each lives in a different rebuild function.
	var odd_sizes: Array = []
	for b in game.hud.stock_strip.find_children("*", "Button", true, false):
		if (b as Button).custom_minimum_size.x != game.hud.ICON:
			odd_sizes.append((b as Button).custom_minimum_size.x)
	check(odd_sizes.is_empty(),
		"every strip icon is exactly ICON (%d), found: %s" % [game.hud.ICON, str(odd_sizes)])

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
	_click(game._tile_px(Vector2i(0, 0)) + Vector2(game.tile, game.tile) / 2)
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

	# clearing the last enemy auto-passes the turn; first, confirm a captured
	# stack arms (for a merge) but a Deploy-tile tap does NOT place it (issue
	# 60 removed direct Captured Stock deploy — convert/sell live in the Shop
	# drawer's Sell mode instead, exercised earlier in this file)
	game.queue_free()
	await process_frame
	GameScript.next_config = {"wave": 3, "captured": ["rook"], "gold": 100,
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_button_in(game.hud, "Stock 1"), "Stock drawer opens")
	await process_frame
	# issue 96: Captured Stock is its own LABELLED section, not a tinted tail.
	# The two pools obey different rules (a Captured entry can never be
	# deployed, issue 60) and the only signals were a tint and a tooltip — and
	# a tooltip does not exist on a phone, which is the target platform.
	var pool_labels := ""
	for c in game.hud.pool_box.get_children():
		if c is Label:
			pool_labels += c.text
	check("CAPTURED" in pool_labels,
		"the Captured section is labelled in the pool strip")
	check("no deploy" in pool_labels,
		"and the label carries the rule, not just the name")
	var cap_stack: Button = game.pool_box.get_children().filter(func(b: Node) -> bool:
		return b is Button and b.has_meta("id") and not b.is_queued_for_deletion())[0]
	_click(cap_stack.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(game.placing_id == "rook" and game.placing_cap, "captured stack arms placement")
	_click(game._tile_px(Vector2i(5, 6)) + Vector2(game.tile, game.tile) / 2) # close drawer
	await process_frame
	_click(game._tile_px(Vector2i(5, 0)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(not game.board.has(Vector2i(5, 0)) and game.captured == ["rook"] and game.placing_cap,
		"tapping a Deploy tile no longer places a Captured stack — it stays armed, inert")
	# 2026-09-06: a Convert control ON the armed Captured stack. Conversion lived
	# only in the Shop's Sell mode, which issue 101 locks before Wave 5 — so at
	# Wave 3 this rook could not be converted at all through the UI.
	check(await _click_button_in(game.hud, "Stock 1"), "Stock drawer reopens")
	await create_timer(0.45).timeout # past the 400 ms double-tap window: a second
		# tap on the same stack inside it opens the piece preview, not the arm
	cap_stack = game.pool_box.get_children().filter(func(b: Node) -> bool:
		return b is Button and b.has_meta("id") and not b.is_queued_for_deletion())[0]
	_click(cap_stack.get_global_rect().get_center())
	await process_frame
	await process_frame
	var convert_badge: Button = null
	for c in game.pool_box.get_children():
		for sub_c in c.get_children():
			if sub_c is Button and (sub_c as Button).text.begins_with("⇄"):
				convert_badge = sub_c
	var badge_cost: int = Shop.convert_price(game, "rook")
	check(convert_badge != null and convert_badge.is_visible_in_tree()
			and convert_badge.text == "⇄$%d" % badge_cost and not convert_badge.disabled,
		"an armed Captured stack shows its Convert badge, priced and live at Wave 3")
	var gold_before_convert: int = game.gold
	_click(convert_badge.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(game.captured.is_empty() and game.stock.has("rook")
			and game.gold == gold_before_convert - badge_cost and not game.placing_cap,
		"tapping Convert moves the rook to Stock, debits the convert price and disarms the stack")
	_click(game._tile_px(Vector2i(5, 6)) + Vector2(game.tile, game.tile) / 2) # close drawer
	await process_frame
	# still armed (nothing clears it on a rejected deploy, same as any other
	# invalid tap on an armed stack) — deselect directly, same effect as
	# tapping the same stack again (exercised on regular Stock earlier in
	# this file), before the wave-clear check below
	game.placing_id = ""
	game.placing_cap = false
	game._clear_selection()
	game._refresh()
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
		"tariffs": ["move_cost"]}
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
	game.shop_lane_b_progress = 6300
	game.modals.show_shop() # rebuild, same as reopening after a Score gain
	await process_frame
	check(game.modals.shop_lane_b_bar.value == 6300,
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

	# Direct deploy is gone (issue 60): arm the drawer's Captured stack (the
	# same tap that used to arm a deploy) and confirm tapping a Deploy tile
	# does nothing — only merge/convert/sell remain.
	game.stock.append("pawn") # a fresh Stock piece so the drawer has both
	game._refresh()
	var deploy_target := Vector2i(-1, -1)
	for t in game._deploy_tiles():
		if not game.board.has(t):
			deploy_target = t
			break
	check(deploy_target.x >= 0, "(sanity) an open Deploy tile exists")
	game.placing_id = "pawn"
	game.placing_cap = true
	game.armed_entry = "pawn"
	game._on_tile_clicked(deploy_target)
	check(not game.board.has(deploy_target),
		"tapping a Deploy tile with a Captured stack armed no longer deploys it")
	game.placing_id = ""
	game.placing_cap = false

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
		"tariffs": ["move_cost"]} # the tariff section below reuses this boot
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.reinforce_panel != null and game.reinforce_panel.visible,
		"the reinforcement shop opens at turn start")
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
	check(game.tariff_panel != null and game.tariff_panel.visible, "tariff overlay opens")
	check(await _click_button_in(game.tariff_panel, "Close"), "tariff Close clickable")
	await process_frame
	check(not game.tariff_panel.visible, "tariff overlay closes")

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
	check(game.hud.activate_box.get_child_count() == 2,
		"the drawer shows two Activate chips: the Artefact's and the Army " +
		"Ability's (issue 67 — every run has a Army, so the section is never " +
		"Artefact-only)")
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
	check(await _click_button_in(game.hud, "Inventory 0"), "Inventory opens for the Army Ability chip")
	await process_frame
	check(await _click_button_in(game.hud.activate_box, "★Shield Wall"),
		"the Army Ability chip is clickable — visually distinct glyph (★, not ⚡)")
	await process_frame
	check(game.buff_pick_open and game.modals.buff_panel.visible,
		"clicking an untargeted Army Ability opens the confirm modal, same as an untargeted Artefact")
	check(await _click_button_in(game.modals.buff_panel, "Cancel"), "Cancel clickable on the confirm modal")
	await process_frame
	check(not game.buff_pick_open and game.actions_left == Tuning.ACTIONS_PER_TURN \
			and not game.army_ability_used_this_wave,
		"cancelling the confirm costs nothing — no Action spent, Wave flag untouched")
	check(await _click_button_in(game.hud.activate_box, "★Shield Wall"),
		"the chip is clickable again after a cancel, drawer untouched")
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
	check(await _click_button_in(game.hud, "Inventory 0"), "Inventory opens for Call the Banners")
	await process_frame
	check(await _click_button_in(game.hud.activate_box, "★Call the Banners"),
		"the Call the Banners chip is clickable")
	await process_frame
	check(not game.buff_pick_open and game.army_targeting and game.hud.drawer_open == "stock",
		"clicking Call the Banners stages targeting and switches straight to the Stock drawer — no confirm modal")
	# Targeting switched the drawer to Stock (that IS its targeting surface),
	# so the chip is out of reach until Inventory is reopened — the same
	# reach-the-chip step Bovine's board-targeting needs above.
	check(await _click_button_in(game.hud, "Inventory 0"),
		"Inventory reopens to reach the chip mid-targeting")
	await process_frame
	check(await _click_button_in(game.hud.activate_box, "★Call the Banners"),
		"tapping the chip again mid-targeting cancels (slice 52's rule)")
	await process_frame
	check(not game.army_targeting and game.stock.size() == 1 and not game.army_ability_used_this_wave,
		"cancelling FROM TARGETING costs nothing — no duplicate, no charge")
	check(await _click_button_in(game.hud.activate_box, "★Call the Banners"),
		"the chip is clickable again after a targeting cancel")
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
	check(await _click_button_in(game.hud, "Inventory 0"), "Inventory opens for Hostile Takeover")
	await process_frame
	check(await _click_button_in(game.hud.activate_box, "★Hostile Takeover"),
		"the Hostile Takeover chip is clickable")
	await process_frame
	check(not game.buff_pick_open and game.army_board_targeting and game.hud.drawer_open == "",
		"clicking Hostile Takeover stages targeting and hands the board back — no confirm modal (it has a target instead)")
	check(await _click_button_in(game.hud, "Inventory 0"),
		"Inventory reopens to reach the chip mid-targeting")
	await process_frame
	check(await _click_button_in(game.hud.activate_box, "★Hostile Takeover"),
		"the chip stays clickable mid-targeting (to cancel)")
	await process_frame
	check(not game.army_board_targeting and game.board.has(Vector2i(7, 10)) \
			and not game.army_ability_used_this_wave and game.gold == 1000,
		"tapping the chip again CANCELS FROM TARGETING — no purchase, no charge, board untouched")
	check(await _click_button_in(game.hud.activate_box, "★Hostile Takeover"),
		"the chip is clickable again after a targeting cancel (drawer still open post-cancel)")
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
	check(await _click_button_in(game.hud, "Inventory 0"), "Inventory opens for Conscription")
	await process_frame
	check(await _click_button_in(game.hud.activate_box, "★Conscription"),
		"the Conscription chip is clickable")
	await process_frame
	check(game.buff_pick_open and game.modals.buff_panel.visible,
		"clicking untargeted Conscription opens the confirm modal, same as an untargeted Artefact")
	check(await _click_button_in(game.modals.buff_panel, "Cancel"), "Cancel clickable on the confirm modal")
	await process_frame
	check(not game.buff_pick_open and game.stock.is_empty() and not game.army_ability_used_this_wave,
		"cancelling the confirm costs nothing — no pawns added, Wave flag untouched")
	check(await _click_button_in(game.hud.activate_box, "★Conscription"),
		"the chip is clickable again after a cancel, drawer untouched")
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
