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
const Scenarios := preload("res://data/scenarios.gd") # NO-83: the Header scenarios
const Kings := preload("res://data/kings.gd") # NO-83: escalate Trump's Power by hand
const Economy := preload("res://scripts/economy.gd") # NO-84: live deploy/convert costs

var fails := 0

## NO-192: the settle wait is bounded by WALL TIME, not a frame count. A frame
## budget measures the host, and this assertion fails on Aux and passes on Main
## with no recorded reason — PANEL_SLIDE_S is 0.18s, so 60 frames already looked
## ample, which is exactly why the cause is still unknown. 3s is ~16x the slide:
## a failure at this cap is a broken tween, not a slow machine. The detail string
## on the check is the point of this change — the old assertion printed nothing,
## so every failure had to be re-theorised from scratch.
const SETTLE_CAP_MS := 3000
## A tween's final frame can land a hair off its target; half a pixel cannot
## change which control a click lands on, and exact Vector2 equality was the
## other candidate cause of the failures above.
const SETTLE_EPS_PX := 0.5


## NO-113: `detail` is printed alongside a failing label — the observed values
## the assertion actually depends on — so a failure says what was true instead
## of just that something wasn't. Optional and appended only on failure, so
## every existing two-argument call site is unchanged.
func check(cond: bool, label: String, detail := "") -> bool:
	if not cond:
		push_error("FAIL: " + label + (" -- " + detail if detail != "" else ""))
		fails += 1
	else:
		print("ok: " + label)
	return cond


## NO-113: the detail a failed _click_button_in/_click_grid_cell lookup needs
## most — what buttons actually exist under `node`, and whether each is
## visible — so "clickable" failing can distinguish missing/hidden/mislabeled
## from actually covered-and-unclickable.
func _button_texts_in(node: Node) -> String:
	var out: Array[String] = []
	_collect_button_texts(node, out)
	return ", ".join(out) if not out.is_empty() else "(no buttons found under this node)"


func _collect_button_texts(node: Node, out: Array[String]) -> void:
	if node is Button:
		out.append("%s%s" % [(node as Button).text,
			"" if node.is_visible_in_tree() else " [hidden]"])
	for c in node.get_children():
		_collect_button_texts(c, out)




## NO-84: pool_box is already buttons-only (both grids hold nothing else), but
## the is-Button check stays cheap insurance against a future non-button child.
func _first_pool_stack(game: Node2D) -> Button:
	for c in game.pool_box:
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


## NO-119: items_grid/artefacts_grid cells carry no name text any more (the
## tooltip/long-press carries it instead), so probes that used to find a cell
## by _click_button_in's text match now match its "key" meta instead —
## hud.gd sets that meta on every cell for exactly this (Items: NO-119,
## Artefacts: pre-existing, "lookup for probes/tests"). Same shape and same
## scroll-into-view handling as _click_button_in otherwise.
func _click_grid_cell(node: Node, key: String) -> bool:
	if node is Button and node.has_meta("key") and node.get_meta("key") == key \
			and node.is_visible_in_tree():
		var p: Node = node.get_parent()
		while p:
			if p is ScrollContainer:
				p.ensure_control_visible(node)
				await process_frame
				break
			p = p.get_parent()
		_click(node.get_global_rect().get_center())
		return true
	for c in node.get_children():
		if await _click_grid_cell(c, key):
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


## NO-118: hud.gd's _slide_drawer takes Tuning.PANEL_SLIDE_S of real time to
## carry a drawer from drawer_hidden[key] to drawer_rest[key]. A press aimed
## at a control inside the drawer, sent before that settles, lands on wherever
## the panel actually is mid-slide — usually nothing. Poll process_frame,
## bounded, until the drawer's own Control sits at its cached rest position;
## the bound means a broken tween fails loudly here instead of every
## press-inside-the-drawer check downstream silently missing.
func _await_drawer_settled(game: Node, key: String) -> void:
	var panel: Control = game.hud.drawers[key]
	var rest: Vector2 = game.hud.drawer_rest[key]
	var t0 := Time.get_ticks_msec()
	var polls := 0
	while panel.position.distance_to(rest) > SETTLE_EPS_PX \
			and Time.get_ticks_msec() - t0 < SETTLE_CAP_MS:
		await process_frame
		polls += 1
	check(panel.position.distance_to(rest) <= SETTLE_EPS_PX,
		"the %s drawer's slide settled before use" % key,
		"pos=%s rest=%s polls=%d elapsed=%dms" % [
			panel.position, rest, polls, Time.get_ticks_msec() - t0])


## NO-83: Stock opens from the Header's icon button, which carries a badge
## rather than a "Stock N" text, so it is reached by rect instead of by text.
## NO-118: awaits the slide settling whenever this click OPENS the drawer (a
## second call that closes it has nothing to settle at — closing tweens
## toward drawer_hidden, never drawer_rest).
func _click_stock(game: Node2D) -> bool:
	var btn: Button = game.hud.drawer_buttons["stock"]
	if not btn.is_visible_in_tree():
		return false
	_click(btn.get_global_rect().get_center())
	if game.hud.drawer_open == "stock":
		await _await_drawer_settled(game, "stock")
	return true


## NO-118: every "Inventory N" open goes through here rather than a bare
## _click_button_in, so the drawer's slide is always settled before a caller
## presses something inside it — one place to get right instead of the
## dozen-plus call sites this button text appears at.
func _click_inventory(game: Node, label: String) -> bool:
	var clicked: bool = await _click_button_in(game.hud, label)
	if clicked and game.hud.drawer_open == "inventory":
		await _await_drawer_settled(game, "inventory")
	return clicked


## NO-118: the Shop is a full-screen modal (modals.gd), not one of
## hud.drawers, so it needs its own settle wait — same shape as
## _await_drawer_settled, against modals.shop_rest instead of
## hud.drawer_rest[key]. A rebuild while already open (Buy, Sell toggle,
## Restock, ...) never animates (modals.gd's show_shop() only calls
## _slide_shop when it wasn't already open), so this only actually waits on
## a fresh open — cheap to call unconditionally either way.
func _click_shop(game: Node) -> bool:
	var clicked: bool = await _click_button_in(game.hud, "Shop")
	if clicked and game.shop_open():
		var t0 := Time.get_ticks_msec()
		var polls := 0
		while game.modals.shop_panel.position.distance_to(game.modals.shop_rest) > SETTLE_EPS_PX \
				and Time.get_ticks_msec() - t0 < SETTLE_CAP_MS:
			await process_frame
			polls += 1
		check(game.modals.shop_panel.position.distance_to(game.modals.shop_rest) <= SETTLE_EPS_PX,
			"the shop's slide settled before use",
			"pos=%s rest=%s polls=%d elapsed=%dms" % [
				game.modals.shop_panel.position, game.modals.shop_rest,
				polls, Time.get_ticks_msec() - t0])
	return clicked


## A double-tap: the press carries `double_click`, the release does not.
func _double_click(at: Vector2) -> void:
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


## A board point the panel's BACKDROP covers — `preferred` if no visible
## Button of the panel sits over it, else the first tile whose centre none
## does. A click that lands on a modal's own button is consumed, and a probe
## asserting "the modal blocked the board" then passes for the wrong reason.
## NO-124: `panel` widened from Control to Node — the floating Confirm
## affordance's own "click a tile no HUD button covers" check passes hud.gd's
## CanvasLayer itself (never a Control), and find_children below is a Node
## method; existing Control callers still satisfy this just as well.
func _backdrop_point(game: Node2D, panel: Node, preferred: Vector2i) -> Vector2:
	var buttons: Array = panel.find_children("*", "Button", true, false)
	var tiles: Array = [preferred]
	for y in Tuning.BOARD_H:
		for x in Tuning.BOARD_W:
			tiles.append(Vector2i(x, y))
	for t in tiles:
		var p: Vector2 = game._tile_px(t) + Vector2(game.tile, game.tile) / 2
		var covered := false
		for b in buttons:
			if (b as Control).is_visible_in_tree() and (b as Control).get_global_rect().has_point(p):
				covered = true
				break
		if not covered:
			return p
	return game._tile_px(preferred) + Vector2(game.tile, game.tile) / 2


## True when some Label under `node` contains `text`.
func _has_label_text(node: Node, text: String) -> bool:
	if node is Label and text in (node as Label).text:
		return true
	for c in node.get_children():
		if _has_label_text(c, text):
			return true
	return false


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
	for c in game.pool_box:
		if c is Button and not c.is_queued_for_deletion() \
				and c.has_meta("cap") and bool(c.get_meta("cap")) == cap:
			out.append(c)
	return out


## NO-84: press a stack button, move the cursor to a screen point, release —
## one full press-drag-drop cycle, for the Stock Drawer reopen-rule checks.
func _drag_drop(root: Node, from_btn: Button, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from_btn.get_global_rect().get_center()
	press.global_position = press.position
	root.push_input(press)
	await process_frame
	# NO-84: the Stock Drawer now covers the top of the board, so `to` itself
	# can sit under its footprint. Cross a point well outside it first — that
	# is what auto-closes the drawer — so the release below reads as a drop
	# on the (by then revealed) board, not "inside the open drawer" (misinput
	# guard, hud.gd/game.gd's `covered` check).
	var away := InputEventMouseMotion.new()
	away.position = Vector2(10, 10000)
	away.global_position = away.position
	root.push_input(away)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.global_position = to
	root.push_input(motion)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	release.global_position = to
	root.push_input(release)
	await process_frame


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


## NO-194: this file has no shared _boot() helper — every fixture below sets
## GameScript.next_config directly, so each boot calls reset_boot_defaults()
## right before it, rather than inheriting a reset from one funnel. Not an
## oversight; see game.gd's reset_boot_defaults() doc comment.
func _init() -> void:
	# Watchdog: a SCRIPT ERROR mid-run kills this coroutine and quit() below
	# never fires, leaving the window open until a human closes it (user
	# report 2026-07-12). Force-quit instead; normal runs finish long before.
	# NO-192: raised from 120s — this probe was cut off at 395/462 assertions
	# by its own watchdog during a verification run. Must stay below
	# run_all.sh's TIMEOUT (600s) or the runner kills the process first and
	# the tail of this probe's log is lost.
	create_timer(240.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: probe still running after 240s — force quit")
		quit(1))
	DirAccess.remove_absolute(Settings.SETTINGS_PATH) # clean slate for the Sound toggle probe
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
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

	# NO-154: army_band used to start OPEN on a scenario boot (only the fresh
	# SETUP path collapsed it, game.gd) — it overlays the same rect a
	# scenario's `board` config already has player pieces sitting on. Assert
	# the RECT, not army_band_open: a property read-back "passes" even when
	# it changed nothing observable (CLAUDE.md, "tests that pass for the
	# wrong reason"). y=0/y=1 are the player's own back rows on screen
	# (SPAWN_ROW convention — CLAUDE.md, "Layout traps the device taught").
	# UPDATE: asserting the rect alone can never fail-or-pass on this fix —
	# collapse_army_band() only sets `visible = false`, and a hidden Control
	# keeps its rect unchanged. The pair below asserts the intent (hidden)
	# and the consequence (not occluding, gated on visibility) separately.
	var back_rows_top: float = game._tile_px(Vector2i(0, 1)).y
	var back_rows_rect := Rect2(game.board_px.x, back_rows_top,
		Tuning.BOARD_W * game.tile, game.tile * 2)
	check(not game.hud.army_band.visible, "army_band starts collapsed on a scenario boot")
	check(not (game.hud.army_band.visible and game.hud.army_band.get_global_rect().intersects(back_rows_rect)),
		"army_band doesn't cover the board's back two rows on a scenario boot",
		"visible=%s band=%s rows=%s" % [game.hud.army_band.visible, game.hud.army_band.get_global_rect(), back_rows_rect])

	# NO-154 (second fixture): the case with a real player behind it — a
	# genuine Continue (menu.gd:723, `next_config = _continue_save`) boots
	# with is_scenario FALSE and a config carrying "state" (every real save
	# has one — SaveConfig.to_config always writes it). That "state" key is
	# also what keeps this boot off save_config.gd's `_begin_player_turn()`
	# path (it takes `_resume_turn()` instead — see save_config.gd's own
	# comment on the `cfg.has("state")` branch), so it can't fire
	# `_autosave()` and touch the real on-disk save the way a bare
	# non-scenario config would.
	var cont_game: Node2D = load("res://scenes/Game.tscn").instantiate()
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {
		"state": GameScript.State.PLAYER_TURN, "actions_left": 1, "wave": 3,
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]],
	}
	GameScript.is_scenario = false
	root.add_child(cont_game)
	await process_frame
	await process_frame
	GameScript.is_scenario = true # restore before anything else in this suite boots
	check(cont_game.state == cont_game.State.PLAYER_TURN,
		"Continue-shaped config boots into player turn")
	var cont_back_rows_rect := Rect2(cont_game.board_px.x,
		cont_game._tile_px(Vector2i(0, 1)).y, Tuning.BOARD_W * cont_game.tile, cont_game.tile * 2)
	check(not cont_game.hud.army_band.visible, "army_band starts collapsed on a Continue-shaped boot")
	check(not (cont_game.hud.army_band.visible and cont_game.hud.army_band.get_global_rect().intersects(cont_back_rows_rect)),
		"army_band doesn't cover the board's back two rows on a Continue-shaped boot (is_scenario false)",
		"visible=%s band=%s rows=%s" % [cont_game.hud.army_band.visible, cont_game.hud.army_band.get_global_rect(), cont_back_rows_rect])
	cont_game.queue_free()
	await process_frame

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
	check(await _click_stock(game), "Stock button opens the drawer")
	await process_frame
	check(game.drawer_open == "stock"
			and (game.hud.drawers["stock"] as Control).is_visible_in_tree(),
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
	# NO-164: the old warm-tint wash on Captured rows is gone — the enemy-red
	# sprite itself is the signal now, so a captured pawn's modulate should
	# sit at the plain default (WHITE), never the armed/merge-partner tints.
	var cap_tint_ok := true
	for row in _pool_rows(game, true):
		if not (row as Button).modulate.is_equal_approx(Color(1, 1, 1)):
			cap_tint_ok = false
	check(cap_tint_ok,
		"and a captured pawn stays untinted — never gold, never a merge partner")
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

	# NO-140 hardware fix (coordinator diagnosis): merge_panel stays `visible`
	# for the MERGE_ANIM_S outro tween, and a visible full-rect panel at the
	# default MOUSE_FILTER_STOP silently ate every click underneath it for
	# that whole window — Pass, a double-tap, the ☰ menu, all swallowed on
	# real hardware. The fix moves the panel to MOUSE_FILTER_IGNORE the
	# instant Merge is pressed, not when the tween finishes. Prove it here,
	# not just trust it: the panel is STILL visible/animating one frame after
	# the click (below), yet the Pass click that follows immediately — landing
	# well inside the 0.35s window — goes through anyway.
	check(game.modals.merge_panel.visible, "the merge outro is still animating one frame later")

	# PASS hands the turn over, banks the +5s turn bonus, and comes back
	var clock_before: float = game.clock_ms
	_click(game.pass_button.get_global_rect().get_center()) # deliberately mid-animation
	await _await_player_turn(game) # enemy turn runs (animated + paced path)
	# NO-113/NO-140: merge_panel (modals.gd) is a PRESET_FULL_RECT,
	# move_to_front()'d PanelContainer that the "Merge" confirm above only
	# HIDES at the end of a Tuning.MERGE_ANIM_S (0.35s) tween. It used to keep
	# MOUSE_FILTER_STOP for that whole window and swallow this click — and the
	# next 13 too, all the way through the in-game menu. _play_merge_animation
	# now sets IGNORE on the panel and its descendants the instant Merge is
	# pressed, so the outro is visual only. This click is deliberately made
	# MID-ANIMATION: it is the regression proof, not incidental timing.
	check(game.state == game.State.PLAYER_TURN,
		"PASS reaches the enemy turn even clicked mid-merge-animation — the panel no longer eats it")
	check(game.clock_ms >= clock_before + 4000, # 5s bonus minus a little ticking
		"finishing the turn grants the clock bonus",
		"clock_before=%.0f clock_ms=%.0f state=%s merge_panel.visible=%s pause_modal_open=%s game_menu_open=%s box_open=%s buff_pick_open=%s win_open=%s pass_button.disabled=%s" % [
			clock_before, game.clock_ms, game.State.keys()[game.state],
			game.modals.merge_panel.visible, game.modals.pause_modal_open(),
			game.game_menu_open, game.box_open, game.buff_pick_open, game.win_open,
			game.pass_button.disabled])

	# ...and the animation itself genuinely finishes and hides the panel —
	# polled against Tuning.MERGE_ANIM_S rather than a guessed frame count,
	# so the wait and the tween's real duration can never drift apart. By now
	# the enemy-turn wait above has almost certainly already covered it; this
	# is the explicit, derived proof rather than an incidental one.
	var merge_polls := 0
	var merge_poll_max := int(ceil(Tuning.MERGE_ANIM_S * 60.0)) + 30 # generous margin past one 60fps tween
	while game.modals.merge_panel.visible and merge_polls < merge_poll_max:
		await process_frame
		merge_polls += 1
	check(not game.modals.merge_panel.visible, "the merge outro animation completes and hides the panel")

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
	check(game.preview_open, "double-tap opens the piece preview",
		"preview_open=%s state=%s board.has((2,2))=%s selected=%s merge_panel.visible=%s game_menu_open=%s drawer_open=%s" % [
			game.preview_open, game.State.keys()[game.state], game.board.has(Vector2i(2, 2)),
			game.selected, game.modals.merge_panel.visible, game.game_menu_open, game.hud.drawer_open])
	check(await _click_button_in(game.preview_panel, "Close"), "Close button clickable",
		"preview_open=%s preview_panel.visible_in_tree=%s buttons=%s" % [
			game.preview_open,
			is_instance_valid(game.preview_panel) and game.preview_panel.is_visible_in_tree(),
			_button_texts_in(game.preview_panel) if is_instance_valid(game.preview_panel) else "(preview_panel is null)"])
	await process_frame
	check(not game.preview_open, "Close dismisses the preview")

	# in-game menu: opens, pauses the clock, Resume returns
	check(await _click_button_in(game.hud, "☰"), "menu button clickable")
	await process_frame
	check(game.game_menu_open, "menu opens",
		"game_menu_open=%s game_menu.visible=%s merge_panel.visible=%s state=%s win_open=%s box_open=%s buff_pick_open=%s" % [
			game.game_menu_open, game.game_menu.visible, game.modals.merge_panel.visible,
			game.State.keys()[game.state], game.win_open, game.box_open, game.buff_pick_open])
	var frozen: float = game.clock_ms
	await create_timer(0.4).timeout
	check(game.clock_ms == frozen, "clock pauses while the menu is open")

	# Guide and Settings (05-menus-and-settings): each opens over the pause
	# menu and its own Back returns to the pause menu, not straight to Resume
	check(await _click_button_in(game.game_menu, "Guide"), "in-game Guide button clickable",
		"game_menu_open=%s game_menu.visible=%s buttons=%s" % [
			game.game_menu_open, game.game_menu.visible, _button_texts_in(game.game_menu)])
	await process_frame
	check(await _click_button_in(game.game_menu, "← Back"), "in-game Guide Back clickable",
		"game_menu_open=%s game_menu.visible=%s buttons=%s" % [
			game.game_menu_open, game.game_menu.visible, _button_texts_in(game.game_menu)])
	await process_frame
	check(await _click_button_in(game.game_menu, "Settings"), "in-game Settings button clickable",
		"game_menu_open=%s game_menu.visible=%s buttons=%s" % [
			game.game_menu_open, game.game_menu.visible, _button_texts_in(game.game_menu)])
	await process_frame
	var sound_on: bool = Settings.load_settings().sound_on
	check(await _click_button_in(game.game_menu, "Sound: %s" % ("On" if sound_on else "Off")),
		"in-game Sound toggle clickable",
		"sound_on=%s wanted_label=%s game_menu.visible=%s buttons=%s" % [
			sound_on, "Sound: %s" % ("On" if sound_on else "Off"), game.game_menu.visible,
			_button_texts_in(game.game_menu)])
	await process_frame
	check(Settings.load_settings().sound_on != sound_on, "in-game Sound toggle persists",
		"sound_on_before=%s sound_on_after=%s" % [sound_on, Settings.load_settings().sound_on])

	# Animations toggle (06): live-applies to the running game, no restart —
	# game.animations_on flips the instant the button is pressed
	check(game.animations_on, "animations start on by default")
	var anims_on: bool = Settings.load_settings().animations_on
	check(await _click_button_in(game.game_menu, "Animations: %s" % ("On" if anims_on else "Reduced")),
		"in-game Animations toggle clickable",
		"anims_on=%s wanted_label=%s game_menu.visible=%s buttons=%s" % [
			anims_on, "Animations: %s" % ("On" if anims_on else "Reduced"), game.game_menu.visible,
			_button_texts_in(game.game_menu)])
	await process_frame
	check(Settings.load_settings().animations_on != anims_on, "in-game Animations toggle persists",
		"anims_on_before=%s anims_on_after=%s" % [anims_on, Settings.load_settings().animations_on])
	check(not game.animations_on, "in-game Animations toggle applies live, no restart",
		"game.animations_on=%s settings.animations_on=%s" % [
			game.animations_on, Settings.load_settings().animations_on])

	check(await _click_button_in(game.game_menu, "← Back"), "in-game Settings Back clickable",
		"game_menu_open=%s game_menu.visible=%s buttons=%s" % [
			game.game_menu_open, game.game_menu.visible, _button_texts_in(game.game_menu)])
	await process_frame

	check(await _click_button_in(game.game_menu, "Resume"), "Resume clickable",
		"game_menu_open=%s game_menu.visible=%s buttons=%s" % [
			game.game_menu_open, game.game_menu.visible, _button_texts_in(game.game_menu)])
	await process_frame
	check(not game.game_menu_open, "Resume closes the menu")
	DirAccess.remove_absolute(Settings.SETTINGS_PATH)

	# wave-50 King capture opens the win screen; Continue resumes the run
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
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
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"wave": 5, # issue 101: the Shop is locked before
		# Tuning.SHOP_UNLOCK_WAVE, and _buy_a_box drives the real Shop button
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "gold": 500}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	if await _buy_a_box(game):
		check(game.box_open, "buying a Box opens the roll modal")
		var opt_tile := _first_option_tile(game.box_panel)
		check(opt_tile != null, "box options render as a tile grid (NO-133)")
		var loot_before: int = game.items.size() + game.artefacts.size() + game.stock.size()
		var native_picks: int = Box.SIZES[game.box_size].picks
		var box_described := false
		for i in native_picks: # Huge grants 2 native picks (issue 47) — take them all,
			# select-then-confirm each one (NO-133): tap the tile, then its Pick button
			var pick_tile := _first_option_tile(game.box_panel)
			if pick_tile != null:
				_click(pick_tile.get_global_rect().get_center())
			await process_frame
			var pick_btn := _box_pick_button(game.box_panel)
			box_described = box_described or pick_btn != null
			if pick_btn != null:
				_click(pick_btn.get_global_rect().get_center())
			await process_frame
		check(box_described, "selecting a box tile reveals its description and a Pick confirm (NO-133)")
		check(not game.box_open, "picking every offered option closes the box")
		check(game.items.size() + game.artefacts.size() + game.stock.size() > loot_before,
			"the picked reward is applied")

	# NO-38 (user ruling 2026-09-08): a full inventory sells from INSIDE the
	# Item Box — the row is only there at capacity, one click sells one Item and
	# pays, the Box survives it, and the pick then lands.
	game.items.clear()
	for key in ["blitz", "sniper", "promote"].slice(0, Tuning.ITEM_CAP_BASE):
		for it in Items.ITEMS:
			if it.key == key:
				game.items.append(it)
	game._open_box_pick({"kind": "box", "key": "item", "size": "small", "sold": false,
		"contents": Box.roll_options(game, "item", "small")})
	await process_frame
	var sell_btn := _sell_button(game.box_panel)
	if check(game.box_open and sell_btn != null,
			"NO-38: an Item Box at a full inventory shows a Sell row"):
		var items_before: int = game.items.size()
		var gold_before_sale: int = game.gold
		_click(sell_btn.get_global_rect().get_center())
		await process_frame
		await process_frame
		# NO-223: every sell path confirms now, including the Box's own Sell row
		# (Max, 2026-09-22: "yes align boxes too"). Nothing is sold until the
		# confirm is answered — the sibling assertion in test_box.gd:222 pins that
		# directly. Answering it here rather than asserting the old immediate sale.
		check(game.items.size() == items_before,
			"NO-38/NO-223: the Box's Sell confirms first — nothing sold yet")
		game._choice_picked(true) # the confirm's own Sell button
		await process_frame
		await process_frame
		check(game.items.size() == items_before - 1 and game.gold > gold_before_sale,
			"NO-38: clicking Sell frees one slot and pays the sell price")
		check(game.box_open and _sell_button(game.box_panel) == null,
			"NO-38: the Box survives the sale and the Sell row is gone")
		var after_sale_tile := _first_option_tile(game.box_panel)
		if after_sale_tile != null:
			_click(after_sale_tile.get_global_rect().get_center()) # NO-133: select...
		await process_frame
		var after_sale_pick := _box_pick_button(game.box_panel)
		if after_sale_pick != null:
			_click(after_sale_pick.get_global_rect().get_center()) # ...then confirm
		await process_frame
		check(not game.box_open and game.items.size() == items_before,
			"NO-38: the pick then lands and closes the Box")

	# Nostradamus Mad Libs (issue 46/47): the extra pick reopens the box
	# modal with what's left of the offer instead of closing it — stacks on
	# TOP of a Box's own native picks, so this Box needs (native + 1) clicks.
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"wave": 5,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "gold": 500,
		"artefacts": ["nostradamus-mad-libs"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	if await _buy_a_box(game):
		check(game.box_open, "(setup) buying the Box opens the roll modal")
		var mad_libs_total: int = Box.SIZES[game.box_size].picks + 1 # +1 Nostradamus copy
		var mad_libs_picks := 0
		while game.box_open:
			var mad_libs_opt := _first_option_tile(game.box_panel)
			if not check(mad_libs_opt != null, "an option is offered (pick %d)" % (mad_libs_picks + 1)):
				break # the box stays open with nothing to click — without this the loop never ends
			_click(mad_libs_opt.get_global_rect().get_center()) # NO-133: select...
			await process_frame
			var mad_libs_pick_btn := _box_pick_button(game.box_panel)
			if not check(mad_libs_pick_btn != null,
					"selecting reveals a Pick confirm (pick %d)" % (mad_libs_picks + 1)):
				break
			_click(mad_libs_pick_btn.get_global_rect().get_center()) # ...then confirm
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
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"wave": 5,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "gold": 500,
		"artefacts": ["snowden-s-rubik-s-cube"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	if await _buy_a_box(game):
		check(game.box_open, "(setup) buying the Box opens the roll modal")
		var reroll_btn := _button_prefix(game.box_panel, "Reroll")
		if check(reroll_btn != null, "Snowden's Rubik's Cube: a Reroll button appears on the box modal"):
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
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"wave": 3,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "items": ["buff_box"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_inventory(game, "Inventory 1"), "Inventory opens for the Buff Box")
	# issue 100: the Army POWER is written out in the drawer. It used to live
	# only in the Ability chip's TOOLTIP and on the army-select screen, and
	# this is a portrait touch game — a hover tooltip is unreachable once a run
	# starts, so a Power that changes what is legal was effectively invisible.
	var kit: Dictionary = Armies.entry(game.next_army)
	# NO-180: the Power's name (Title row) and its effect (new Subtitle row,
	# army_power_desc_label) are two separate Labels now, not one combined
	# line — check each where it actually lives.
	check(kit.power_name in game.hud.army_power_label.text
			and kit.power_desc in game.hud.army_power_desc_label.text,
		"the Army Power is readable in the drawer without hovering (%s)" % kit.power_name)
	# design C moved the Ability out of this drawer and onto the deck, so its
	# cost is asserted where it now lives. The point of the move is the next
	# check: you can read it WITHOUT opening anything.
	# NO-163: the READY state no longer repeats "1 Action" in the button text
	# (the tooltip, checked below, already carries the cost) — only an
	# UNAVAILABLE button states why, on the button itself.
	if game.hud.army_ability_button.disabled:
		check("no Action" in game.hud.army_ability_button.text
				or "next wave" in game.hud.army_ability_button.text,
			"a disabled Ability states why (%s)" % game.hud.army_ability_button.text)
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
	# NO-83 cut the Deck to three rows: the drawers (Inventory | Shop, equal
	# halves), the Power badge, and the thumb row. Stock lives in the Header.
	# NO-128 (coordinator review 2026-09-19, route 2 of 2 offered) cut it to
	# TWO: the band (renamed army_band — Power, the Ability hint, and the King
	# Abilities button) is no longer a deck row at all. An earlier version of
	# this change made it a collapsible THIRD row and grew DECK_ROWS to budget
	# its worst case, which was rejected — the board is sized once at boot and
	# never revisited, so a permanent reservation for a collapsible row costs
	# the board every run whether or not the row is ever open. army_band now
	# overlays the board above the deck instead, exactly like the Inventory
	# drawer, so it isn't part of the deck's sum at all.
	var HUD: CanvasLayer = game.hud
	var deck: Node = HUD.nav_row.get_parent()
	check(HUD.army_band.get_parent() != deck,
		"NO-128: army_band is not a deck row — it overlays the board instead")
	check(HUD.nav_row.get_index() == 0,
		"deck order: the drawers row sits directly under the board")
	check(HUD.act_row.get_index() == deck.get_child_count() - 1,
		"deck order: Ability and PASS are the LAST row, in the thumb arc")
	check(deck.get_child_count() == 2,
		"NO-128: the band left the Deck — drawers and act are the only two rows left (%d)"
			% deck.get_child_count())
	# NO-128 gave nav_row a middle child, army_band_reopen, that reopens the
	# band once it's collapsed; NO-180 moved it to the LEFT of Inventory/Shop
	# and gave it a square, fixed-size footprint (not EXPAND_FILL), so
	# Inventory and Shop — now the second and third children — stay equal to
	# EACH OTHER regardless of where the wedge sits.
	var nav_kids: Array = HUD.nav_row.get_children()
	check(nav_kids.size() == 3 and nav_kids[0] == HUD.army_band_reopen
			and nav_kids[1] == HUD.drawer_buttons["inventory"] and nav_kids[2] == HUD.shop_button,
		"NO-180: the button row is the band's reopen wedge, then Inventory, then Shop")
	check(absf((nav_kids[1] as Control).size.x - (nav_kids[2] as Control).size.x) <= 1.0,
		"NO-83: ...Inventory and Shop stay equal halves either side of the wedge (%s vs %s)"
			% [(nav_kids[1] as Control).size.x, (nav_kids[2] as Control).size.x])
	# Opening Inventory above (line 684, to reach army_power_label/the Ability
	# button) already exercised the NO-128 mutual exclusion below — it
	# silently collapsed army_band as a side effect, and closing Inventory
	# again never auto-reopens it (no magic reopen; only the wedge does).
	# Reopen it now to reach the clean baseline the invariants below assume;
	# army_band_reopen's own handler closes Inventory as it goes, so one
	# click does both.
	_click(HUD.army_band_reopen.get_global_rect().get_center())
	# NO-163: army_band_reopen is now ALWAYS visible (one control, anchored to
	# the button row, that flips its own glyph rather than two controls that
	# traded visibility) — assert the OPEN glyph instead of "not visible".
	# NO-180 replaced the old ▴/▾ open/closed pair with a static round-"i"
	# icon in both states (the warning glyph, unaffected here, is separate).
	check(HUD.drawer_open == "" and HUD.army_band_reopen.text == "ⓘ"
			and HUD.army_band.visible and HUD.army_band_open,
		"NO-128/NO-163: reopening the band also closed Inventory (same screen rect)")
	# NO-128: army_band overlays the SAME screen rect Inventory's drawer opens
	# into (both anchored to deck_top, extending upward) — see the mutual
	# exclusion in hud.gd's set_drawer() and army_band_reopen's own handler.
	# Opening Inventory here must close the band, or the two panels overlap.
	# Clicked by direct reference (not _click_inventory's text-match helper —
	# the button's text carries a live item/artefact count this scenario
	# doesn't pin) via the real synthetic-input path, same as every other
	# button in this file.
	_click(HUD.drawer_buttons["inventory"].get_global_rect().get_center())
	await _await_drawer_settled(game, "inventory")
	check(HUD.drawer_open == "inventory" and not HUD.army_band.visible
			and HUD.army_band_reopen.text == "ⓘ",
		"NO-128/NO-163: opening Inventory collapses army_band (same screen rect)")
	_click(HUD.army_band_reopen.get_global_rect().get_center())
	check(HUD.drawer_open == "" and HUD.army_band.visible and HUD.army_band_reopen.text == "ⓘ",
		"NO-128/NO-163: reopening the band closes Inventory back (same screen rect)")
	# NO-128 finally gives king_ability_button the home NO-83 promised it: it
	# is in the tree now (inside army_band), just hidden until an ability is
	# active. arrow_button has no ticket moving it yet, so it stays off-screen.
	check(HUD.king_ability_button.is_inside_tree() and not HUD.king_ability_button.visible
			and not HUD.arrow_button.is_inside_tree(),
		"NO-128: the King Abilities button is parented (hidden, no ability active); Arrows stays off screen")
	check(not HUD.king_ability_button.pressed.get_connections().is_empty()
			and not HUD.arrow_button.pressed.get_connections().is_empty()
			and HUD.king_ability_button.text.begins_with("⚠"),
		"...both keep their handlers and state")

	# ---- NO-33 / ADR-0004: the BOARD absorbs slack, the deck is a SUM -------
	# THE GUARD. The deck's height is a sum of constants, never a runtime
	# measurement (measuring needs a second layout pass, and a control that
	# measures itself before layout caches nonsense — CLAUDE.md, layout traps).
	# A sum can drift from the thing it describes, so this is what fails the
	# moment a deck row is added or a font moves under one.
	# NO-128: army_band left the deck entirely (see above), so this sum no
	# longer has anything state-dependent in it — DECK_ROWS is back to being a
	# plain sum of always-rendered rows, same as before NO-128 ever touched it.
	var rest := 0.0
	for c in deck.get_children():
		rest += (c as Control).get_combined_minimum_size().y
	rest += deck.get_theme_constant("separation") * (deck.get_child_count() - 1)
	check(is_equal_approx(rest, GameScript.DECK_ROWS),
		"NO-33: DECK_ROWS (%s) still matches the built deck (%s)"
			% [GameScript.DECK_ROWS, rest])
	# The closed form reproduces the numbers design C was tuned against: on a
	# 9:20 phone the WIDTH term wins at tile 59, which is exactly where ICON's
	# literal 52 came from. If this pair ever stops agreeing, the -7 relationship
	# was refitted rather than derived, and ADR-0004 wants re-reading.
	check(GameScript.board_tile_for(Vector2(480.0, 1066.0)) == 59,
		"NO-33: a 9:20 phone still solves to tile 59, as design C shipped it")
	check(GameScript.board_tile_for(Vector2(480.0, 1066.0)) - GameScript.ICON_GAP == 52,
		"NO-33: ...and ICON on that phone is still 52, the constant it replaced")
	# NO-83: the notch inset is ADDED to the Header, and the board pays for it.
	check(GameScript.board_tile_for(Vector2(480.0, 800.0), HUD.HEADER_H + 56.0)
			< GameScript.board_tile_for(Vector2(480.0, 800.0), HUD.HEADER_H),
		"NO-83: an iPhone 11 inset (56px) costs the board tile, not the Header")

	# ---- NO-196/NO-197: deck-layout guards -----------------------------------
	# Both measure real allocated geometry (get_global_rect()), never a constant,
	# so they actually exercise the layout rather than restating it. A freshly
	# laid-out Control's rect is not reliable until the next idle frame
	# (CLAUDE.md, layout traps) — the deck was built at boot, several frames
	# ago, but await one anyway rather than depend on that.
	await process_frame
	# NO-196: nav_row..act_row must read as ONE deliberate gap — the same
	# DECK_GAP the deck's own buttons use for their own separation — not
	# whatever int(tile) flooring happened to leave over (see hud.gd's build()).
	var row_gap: float = HUD.act_row.get_global_rect().position.y \
		- HUD.nav_row.get_global_rect().end.y
	var button_gap: float = HUD.pass_button.get_global_rect().position.x \
		- HUD.army_ability_button.get_global_rect().end.x
	check(is_equal_approx(row_gap, button_gap),
		"NO-196: the nav_row/act_row gap (%s) matches the Ability/PASS gap (%s)"
			% [row_gap, button_gap])
	# NO-197: nav_row must clear the board's own whose-turn outline — its outer
	# ink sits BOARD_OUTLINE_INSET + BOARD_OUTLINE_WIDTH/2 past the tile grid
	# (game.gd's _draw).
	var half_w: float = GameScript.BOARD_OUTLINE_WIDTH / 2.0
	var outline_outer := Rect2(
		game.board_px - Vector2.ONE * (GameScript.BOARD_OUTLINE_INSET + half_w),
		Vector2(Tuning.BOARD_W, Tuning.BOARD_H) * game.tile
			+ Vector2.ONE * (GameScript.BOARD_OUTLINE_INSET + half_w) * 2.0)
	check(not outline_outer.intersects(HUD.nav_row.get_global_rect()),
		"NO-197: nav_row (%s) clears the board outline's outer ink (%s)"
			% [HUD.nav_row.get_global_rect(), outline_outer])

	# ---- NO-83: THE HEADER --------------------------------------------------
	var stock_btn: Button = HUD.drawer_buttons["stock"]
	var sr: Rect2 = stock_btn.get_global_rect()
	var mr: Rect2 = HUD.menu_button.get_global_rect()
	check(is_equal_approx(game.hud_top, game.safe_top + HUD.HEADER_H),
		"the Header is the safe-area inset plus HEADER_H (NO-116)")
	# NO-229: assert the REQUIREMENT, not the formula. The old form here was
	# `board_px.y == hud_top + BOARD_TOP_MARGIN`, which restates _layout_board's
	# own arithmetic with the same constant — it passes for 6.0, for 15.5, and
	# for any wrong value typed next, while reading as proof the layout is
	# right. What Max actually asked for (2026-09-22) is clearance between the
	# Header and the OUTLINE, which is drawn BOARD_OUTLINE_INSET outside the
	# board rect and stroked BOARD_OUTLINE_WIDTH wide CENTRED on that edge — so
	# the outline's top edge is board_px.y - inset - half the stroke. Lowering
	# BOARD_TOP_MARGIN now fails this; before, nothing could.
	var outline_top: float = game.board_px.y - GameScript.BOARD_OUTLINE_INSET \
		- GameScript.BOARD_OUTLINE_WIDTH * 0.5
	check(outline_top - game.hud_top >= 10.0,
		"the board outline clears the Header by at least 10px (NO-229) — clearance=%.1f" \
			% (outline_top - game.hud_top))
	# NO-162 fix, 3rd pass. The first two attempts on this bug (font-fit
	# search, then suspecting the clock-pulse tween) each shipped with an
	# assertion that PASSED while a real device still showed the leading
	# digit clipped off the left edge — both times because the assertion
	# only read `get_global_rect()`, a Control's LAYOUT rect, which says
	# nothing about where the container placed it or how the text aligned
	# inside it. This block checks the things that actually determine what
	# lands on screen: the Label is no longer inside any Container (so its
	# rect IS its final position, not something a VBoxContainer computed),
	# its alignment is pinned instead of inherited, and clip_text is the
	# hard backstop — with all three true, `get_global_rect()` finally means
	# what the two earlier passes assumed it meant.
	check(HUD.clock_label.get_parent() == HUD,
		"the Clock is a direct HUD child, not inside a Container that could reposition or resize it")
	check(HUD.clock_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT,
		"the Clock's alignment is pinned, not left to a default/theme that could centre it")
	check(HUD.clock_label.clip_text,
		"the Clock cannot paint outside its own rect even if the width measurement below is ever wrong")
	var clock_font_applied: int = HUD.clock_label.get_theme_font_size("font_size")
	check(clock_font_applied <= HUD.CLOCK_FONT and clock_font_applied >= HUD.CLOCK_FONT_MIN,
		"the applied Clock font sits between the floor and the ceiling (%s)" % clock_font_applied)
	# The actual regression check for "04:59.833 clipped off the left edge":
	# re-measure the fixed-width clock text at the APPLIED size, using the
	# same live font the Label itself draws with (get_theme_default_font()
	# returns the FONT RESOURCE, unaffected by the font_size override, so
	# this is the same object build() measured against) — confirm it fits
	# the real budget the Label's own rect was given, and confirm the rect
	# starts no earlier than HEADER_PAD_X.
	var clock_font_res: Font = HUD.clock_label.get_theme_default_font()
	var clock_text_w: float = clock_font_res.get_string_size(
		"00:00.000", HORIZONTAL_ALIGNMENT_LEFT, -1, clock_font_applied).x
	check(clock_text_w <= HUD.clock_label.size.x + 0.5,
		"the measured text width fits inside the Label's own rect (%s vs rect %s)"
			% [clock_text_w, HUD.clock_label.size.x])
	# NO-175: the Clock is now CENTRED in the middle band (not confined to
	# a left column, since Gold moved out of the way) — the band runs from
	# where the fixed-width LEFT column ends to where the Stock button
	# begins. Containment against the Stock button's own live rect, not a
	# re-derivation of build()'s formula, so this fails on a real overlap
	# even if the two drift apart.
	var clock_r: Rect2 = HUD.clock_label.get_global_rect()
	var mid_left_edge: float = HUD.HEADER_PAD_X + HUD.COUNTER_W
	check(clock_r.position.x >= mid_left_edge - 0.5 and clock_r.end.x <= sr.position.x + 0.5,
		"NO-175: the Clock's rect stays past the left column (%s) and clear of the Stock button (%s)"
			% [mid_left_edge, sr.position.x])
	check(HUD.clock_label.size.y >= clock_font_res.get_height(clock_font_applied) - 0.5,
		"the Clock line covers its own font's height")
	# NO-175, 3rd pass fix: these read the ZEROS labels, not the coloured-
	# digit labels — score_label/gold_label are each their row's SECOND
	# child, offset by their own zero-padding width, which only
	# coincidentally matches between rows when Score and Gold happen to have
	# the same digit count. The zeros label is each row's actual first/
	# left-most child, so comparing ITS position is what genuinely tests
	# "shares a left edge".
	var gr: Rect2 = HUD.gold_zeros_label.get_global_rect()
	var sr2: Rect2 = HUD.score_zeros_label.get_global_rect()
	var wtr: Rect2 = HUD.wave_label.get_global_rect()
	var trr: Rect2 = HUD.turn_label.get_global_rect()
	# NO-175, 3rd pass (Max's revised mockup supersedes the 2nd pass, which
	# stacked Turn/Wave into the left column): LEFT is now just Score, then
	# Gold; Turn/Wave is a small centred line directly ABOVE the Clock, in
	# the same middle band. Containment against the Clock's and Stock's own
	# live rects, not a re-derivation of the centring formula, so these fail
	# on a real overlap or an off-band regression even if the exact pixel
	# math drifts.
	check(sr2.position.y >= game.safe_top - 0.5 and sr2.end.y <= gr.position.y + 0.5,
		"NO-175: Score sits above Gold in the left column")
	check(gr.end.y <= game.hud_top + 0.5,
		"NO-175: Gold stays inside the Header")
	check(absf(sr2.position.x - gr.position.x) <= 0.5,
		"NO-175: 'the numbers aligned' — Score and Gold's digits share a left edge (%s vs %s)"
			% [sr2.position.x, gr.position.x])
	check(is_equal_approx(wtr.position.y, trr.position.y) and wtr.position.x >= trr.position.x,
		"NO-175: '0/8  ⚑ 1/50' — Turn and Wave share a line, Wave after Turn")
	check(trr.end.y <= clock_r.position.y + 0.5,
		"NO-175: Turn/Wave sits above the Clock, not overlapping it")
	check(trr.position.x >= mid_left_edge - 0.5 and wtr.position.x <= sr.position.x + 0.5,
		"NO-175: Turn/Wave stays inside the middle band — past the left column (%s), clear of Stock (%s)"
			% [mid_left_edge, sr.position.x])
	check(mr.position.y >= game.safe_top and mr.end.x <= game.get_viewport_rect().size.x,
		"the menu button sits in the top-right corner, below the inset")
	# NO-175 margin fix: "equal margin above, under and to the right" — read
	# straight off the ☰ button's own live rect against the Header's own
	# edges (safe_top, hud_top, viewport width), not a re-derivation of
	# HEADER_PAD_Y/build()'s formula, so this fails on a real mismatch even
	# if the two drift apart.
	var margin_top: float = mr.position.y - game.safe_top
	var margin_bottom: float = game.hud_top - mr.end.y
	var margin_right: float = game.get_viewport_rect().size.x - mr.end.x
	check(is_equal_approx(margin_top, margin_bottom) and is_equal_approx(margin_top, margin_right),
		"NO-175: the ☰ button's top/bottom/right margins are equal (top=%s bottom=%s right=%s)"
			% [margin_top, margin_bottom, margin_right])
	# NO-131: the enlarged NO-83 tap zone is gone — the Stock button is a
	# regular button, sized to its own icon+padding, not the Header's full
	# height.
	check(sr.size.y < HUD.HEADER_H - 0.5,
		"the Stock button's rect no longer spans the Header's full height")
	# NO-175: "pause menu and stock buttons are now the same size" — they
	# differed before (Stock was icon+padding, ☰ a smaller fixed square).
	check(is_equal_approx(sr.size.x, mr.size.x) and is_equal_approx(sr.size.y, mr.size.y),
		"NO-175: Stock and the pause button are the same size (%s vs %s)" % [sr.size, mr.size])
	check(is_equal_approx(sr.position.y, mr.position.y),
		"NO-175: Stock and the pause button sit on the same row (nothing shares their column any more)")
	# NO-175, 3rd pass: "these should be exactly the same apart from their
	# icon and badge" — they were size-matched last pass but not style-
	# matched (Stock used _style_button's translucent-white tint, the ☰
	# button was still styled through the "compact" loop meant for the two
	# off-screen buttons, a solid dark grey). Both now go through the same
	# _style_button call, so this compares their live styleboxes directly.
	var stock_style := stock_btn.get_theme_stylebox("normal") as StyleBoxFlat
	var menu_style := HUD.menu_button.get_theme_stylebox("normal") as StyleBoxFlat
	check(stock_style != null and menu_style != null
			and stock_style.bg_color.is_equal_approx(menu_style.bg_color),
		"NO-175: Stock and the pause button share the same style — only the glyph and badge differ (%s vs %s)"
			% [stock_style.bg_color if stock_style else null, menu_style.bg_color if menu_style else null])
	check(sr.position.y >= game.safe_top - 0.5, "...never above the inset")
	check(sr.end.y <= game.hud_top + 0.5, "...and it never reaches over the board")
	check(is_equal_approx(sr.end.x, mr.position.x - HUD.HEADER_GAP),
		"...it stops HEADER_GAP short of the menu button, same gap as before")
	check(HUD.stock_badge.text == "0" and HUD.stock_badge.is_visible_in_tree(),
		"the Stock badge counts the pool (empty here: 0)")
	check(stock_btn.icon != null, "the Stock button shows a piece icon")
	# A tap on the top EDGE of the top-right board tile — the board point
	# nearest the Stock button — reaches the board, never Stock. The rect
	# exclusion is the geometry; the click proves the routing.
	var tr_tile := Vector2i(Tuning.BOARD_W - 1, Tuning.BOARD_H - 1)
	var tr_px: Vector2 = game._tile_px(tr_tile) + Vector2(game.tile / 2.0, 1.0)
	check(game._tile_at(tr_px) == tr_tile and not sr.has_point(tr_px),
		"(setup) the top-right tile's top edge is a board point outside the Stock button")
	_click(tr_px)
	await process_frame
	check(game.drawer_open == "", "a tap on the top-right board tile never opens Stock")
	_click(mr.get_center())
	await process_frame
	check(game.game_menu.visible and game.drawer_open == "",
		"a tap on the menu button opens the menu, never Stock")
	check(await _click_button_in(game.hud.game_menu, "Resume"), "Resume clickable")
	await process_frame
	# NO-60: the tap area is the Header's FULL height, not the glyph's own
	# content-sized rect — tap its top and bottom edges, well outside mr, and
	# confirm each opens the menu and never Stock.
	var menu_tap_r: Rect2 = HUD.menu_tap.get_global_rect()
	check(is_equal_approx(menu_tap_r.position.y, game.safe_top) and is_equal_approx(menu_tap_r.size.y, HUD.HEADER_H),
		"the menu button's tap area is the Header's full height, from the inset down")
	check(menu_tap_r.position.x >= sr.end.x - 0.5, "...and it never reaches over the Stock button")
	_click(Vector2(menu_tap_r.get_center().x, menu_tap_r.position.y + 1.0))
	await process_frame
	check(game.game_menu.visible and game.drawer_open == "",
		"a tap on the TOP edge of the tap area opens the menu, never Stock")
	check(await _click_button_in(game.hud.game_menu, "Resume"), "Resume clickable (top edge)")
	await process_frame
	_click(Vector2(menu_tap_r.get_center().x, menu_tap_r.end.y - 1.0))
	await process_frame
	check(game.game_menu.visible and game.drawer_open == "",
		"a tap on the BOTTOM edge of the tap area opens the menu, never Stock")
	check(await _click_button_in(game.hud.game_menu, "Resume"), "Resume clickable (bottom edge)")
	await process_frame
	check(await _click_stock(game), "the Header's Stock button opens the drawer")
	await process_frame
	check(game.drawer_open == "stock", "...and it is the Stock drawer")
	check(await _click_stock(game), "the Stock button toggles the drawer shut")
	await process_frame
	check(game.drawer_open == "", "...closed again")
	# (the armed marker on this button is asserted in the SETUP block below,
	# where a Stock stack exists to arm)
	# ⚑ WAVE COUNTER: out of 50 until the first King falls, then out of 201
	var wave_was: int = game.wave
	var kd_was: int = game.kings_defeated
	var tsw_was: int = game.turns_since_wave
	game.wave = 1
	game.kings_defeated = 0
	HUD.refresh()
	check(HUD.wave_label.text == "⚑ 1/50", "Wave 1 reads ⚑ 1/50 (got %s)" % HUD.wave_label.text)
	game.wave = 50
	HUD.refresh()
	check(HUD.wave_label.text == "⚑ 50/50", "Wave 50 reads ⚑ 50/50 (got %s)" % HUD.wave_label.text)
	game.wave = 51
	game.kings_defeated = 1
	HUD.refresh()
	check(HUD.wave_label.text == "⚑ 51/201", "Wave 51 after the win reads ⚑ 51/201 (got %s)" % HUD.wave_label.text)
	# TURN COUNTER: turns played out of the upcoming Wave's cadence — Wave 4
	# is three pawns (data/waves.gd), so 6 + 3. NO-114 dropped the ⧖ glyph.
	game.wave = 3
	game.kings_defeated = 0
	game.turns_since_wave = 2
	HUD.refresh()
	check(HUD.turn_label.text == "2/9", "turn counter counts 2 of Wave 4's 9 (got %s)" % HUD.turn_label.text)
	game.pending_king = {"id": "king", "king_id": "donald_trump"}
	HUD.refresh()
	check(HUD.turn_label.text == "Donald Trump",
		"turn counter names a PENDING King (got %s)" % HUD.turn_label.text)
	check(HUD.wave_label.text == "", "NO-114: the Wave counter blanks while a King is pending/alive")
	game.pending_king = {}
	game.wave = 201
	HUD.refresh()
	check(HUD.turn_label.text == "", "turn counter is blank after the last Wave (got %s)" % HUD.turn_label.text)
	# NO-175 regression, re-aimed for the 3rd pass (Turn/Wave now lives in
	# the CENTRE band, not the left column — the original "flush left"
	# framing no longer applies). The underlying concern survives: an EMPTY
	# Turn must not distort where Wave lands. Since the whole pair is
	# recentred every refresh() from its OWN visible width (build()'s
	# comment), Wave alone should still land inside the legal middle band,
	# not off past either edge.
	await process_frame
	var wr: Rect2 = HUD.wave_label.get_global_rect()
	var band_left: float = HUD.HEADER_PAD_X + HUD.COUNTER_W
	var band_right: float = game.get_viewport_rect().size.x - HUD.HEADER_PAD_X - HUD.HEADER_BTN * 2.0 - HUD.HEADER_GAP
	check(wr.position.x >= band_left - 0.5 and wr.position.x <= band_right + 0.5,
		"NO-175: Wave stays inside the middle band even when Turn is blank (%s, band %s-%s)"
			% [wr.position.x, band_left, band_right])
	# a long King name is cut with an ellipsis: the label never leaves its
	# band, whatever the text. NO-175 fix, 2nd pass: turn_label's box is
	# HARD-SET in build() and never resized by content (a plain Control, not
	# a Container — see build()'s own comment), so `tl.size.x` can no longer
	# regress to the 504px overflow a live capture caught (2026-09-20, root
	# cause: text_overrun_behavior alone does nothing without clip_text —
	# the box grew to fit the full un-ellipsised text). 3rd pass: the cap is
	# now the CENTRE band's width, not COUNTER_W — the left column no longer
	# holds Turn/Wave, so re-derive the same band-width formula build() uses
	# (mid_left_edge is already in scope, above).
	# Since the box is fixed BY CONSTRUCTION, a rect check on it would pass
	# even if `clip_text` were removed (CLAUDE.md: "a geometry assertion on
	# a Control's rect cannot see clipping") — so this asserts `clip_text`
	# itself, the property that actually makes the ink respect that fixed
	# box, plus the size/position invariants.
	var band_right2: float = game.get_viewport_rect().size.x - HUD.HEADER_PAD_X - HUD.HEADER_BTN * 2.0 - HUD.HEADER_GAP
	var centre_x2: float = game.get_viewport_rect().size.x / 2.0
	var centre_w2: float = (minf(centre_x2 - mid_left_edge, band_right2 - centre_x2) - HUD.HEADER_GAP) * 2.0
	HUD.turn_label.text = "Maximilian ".repeat(6)
	await process_frame
	var tl: Rect2 = HUD.turn_label.get_global_rect()
	check(HUD.turn_label.clip_text and tl.size.x <= centre_w2 + 0.5
			and tl.end.y <= game.hud_top + 0.5,
		"NO-175: a long King name stays capped to the centre band (clip_text on, %s wide, band %s), still inside the Header"
			% [tl.size.x, centre_w2])
	game.wave = wave_was
	game.kings_defeated = kd_was
	game.turns_since_wave = tsw_was
	HUD.refresh()

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
	# NO-163: ready no longer says "1 Action" (dropped from the button text) —
	# assert the absence of both unavailability captions instead, plus enabled.
	check(not ("no Action" in game.hud.army_ability_button.text)
			and not ("next wave" in game.hud.army_ability_button.text)
			and not game.hud.army_ability_button.disabled,
		"and it comes back ready once an Action exists again (%s)"
			% game.hud.army_ability_button.text)
	await process_frame

	# ---- ONE ICON SIZE, ACROSS ALL THREE STRIPS (NO-36, resized NO-119) ------
	# Items were 30px, stock stacks 46, the strip 52 before these were pulled
	# onto one constant. PR #312's pin named that drift but walked only
	# stock_strip — and on a config with no Stock that container is empty, so the
	# pin asserted nothing whatsoever. The two strips that ACTUALLY drifted, the
	# item strip and the pool strip, were never inspected.
	#
	# NO-119 dropped the icon size's tie to the board tile (hud.gd's old ICON
	# var) in favour of a flat Tuning.OFFBOARD_ICON for every off-board grid,
	# and dropped the item strip's name text — so the KNOWN EXCEPTION below
	# (item cells sized ICON-8 to leave room for a name beside the icon) is
	# gone too: every cell, item or pool, is now the same OFFBOARD_ICON square,
	# no separate case.
	#
	# So: a dedicated instance holding Stock AND items, both drawers visited, and
	# every strip asserted NON-EMPTY first — a vacuous pass is the exact failure
	# being fixed, and it must not be reachable again.
	var icon_game: Node2D = game
	game = null
	icon_game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"wave": 3, "board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"items": ["buff_box"], "stock": ["pawn", "rook"]}
	icon_game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(icon_game)
	await process_frame
	await process_frame
	var ICON_PX: int = int(Tuning.OFFBOARD_ICON)

	# (1. was the stock strip under the board — retired by NO-83.)

	# 2. the item strip, in the Inventory drawer. No name text any more
	# (NO-119), so it's the same flat square as every other off-board cell.
	check(await _click_inventory(icon_game, "Inventory 1"),
		"Inventory opens for the item strip")
	await process_frame
	var item_btns: Array = []
	for c in icon_game.hud.items_grid.get_children():
		if c is Button:
			item_btns.append(c)
	check(not item_btns.is_empty(), "(setup) the item strip actually holds buttons to measure")
	var odd_item: Array = []
	for b in item_btns:
		if (b as Button).custom_minimum_size != Vector2(ICON_PX, ICON_PX):
			odd_item.append((b as Button).custom_minimum_size)
	check(odd_item.is_empty(),
		"item strip: every icon is exactly OFFBOARD_ICON x OFFBOARD_ICON (%d), found: %s"
			% [ICON_PX, str(odd_item)])

	# NO-207, Max's 4th ask: the Items/Artefacts grids left one dead column of
	# empty space at the drawer's right edge. The FIRST geometry assertion
	# here (NO-201-shaped, landed a4c1150) compared grid.get_global_rect() to
	# grid.get_parent() — but the parent (inv_box, a VBoxContainer) shrinks to
	# its widest child, which custom_minimum_size.x (NO-182) already forces to
	# equal the grid itself. That comparison is tautological: it passed
	# against the live bug because the "parent" it measured never had any
	# slack to begin with. The real usable width is the Inventory drawer's
	# ScrollContainer (`sc`, hud.gd) — the actual chrome Max is looking at —
	# and what Max sees is icon positions, not a container rect, so assert
	# the leftmost/rightmost CELL edge (icon or empty-slot placeholder, both
	# real rendered cells) against it directly. One more idle frame first: a
	# freshly rebuilt GridContainer's rect isn't final until the container
	# has sorted (CLAUDE.md).
	await process_frame
	var inv_panel: Control = icon_game.hud.drawers["inventory"]
	var inv_sc: ScrollContainer = null
	for c in inv_panel.get_children():
		if c is ScrollContainer:
			inv_sc = c
			break
	if check(inv_sc != null, "(setup) the Inventory drawer's ScrollContainer is reachable"):
		var usable_rect: Rect2 = inv_sc.get_global_rect()
		var grids := {"items_grid": icon_game.hud.items_grid, "artefacts_grid": icon_game.hud.artefacts_grid}
		for grid_name in grids:
			var grid: Control = grids[grid_name]
			var cells: Array = grid.get_children()
			check(not cells.is_empty(), "(setup) %s actually holds cells to measure" % grid_name)
			if cells.is_empty():
				continue
			var left_x: float = INF
			var right_x: float = -INF
			for cell in cells:
				var r: Rect2 = (cell as Control).get_global_rect()
				left_x = minf(left_x, r.position.x)
				right_x = maxf(right_x, r.end.x)
			var left_gap: float = left_x - usable_rect.position.x
			check(absf(left_gap) <= 1.5,
				"%s: cells sit flush against the drawer's left edge (left_gap=%.1f)" %
					[grid_name, left_gap])
			# The right edge only has to reach the usable width when a row is
			# actually FULL (cells.size() >= columns) — a grid holding fewer
			# entries than columns (items_grid's cap can be below the 5-column
			# standard, e.g. ItemLogic.cap's base of 2) has nothing to put in the
			# trailing columns; that is not the dead-column bug NO-207 fixed, and
			# asserting edge-to-edge there would be wrong.
			if cells.size() >= grid.columns:
				var right_gap: float = usable_rect.end.x - right_x
				check(absf(right_gap) <= 1.5,
					"%s: a full row's cells reach the drawer's right edge, no dead column " %
						grid_name +
					"(right_gap=%.1f, usable_w=%.1f)" % [right_gap, usable_rect.size.x])

	# 3. the pool strip, in the Stock drawer. _rebuild_pool_strip returns early
	# while that drawer is closed ("stock drawer closed: no targets"), so the
	# drawer has to be OPEN for this container to hold anything at all.
	check(await _click_stock(icon_game), "Stock drawer opens for the pool strip")
	await process_frame
	var pool_btns: Array = []
	for c in icon_game.hud.pool_buttons():
		if c is Button:
			pool_btns.append(c)
	check(not pool_btns.is_empty(), "(setup) the pool strip actually holds buttons to measure")
	var odd_pool: Array = []
	for b in pool_btns:
		if (b as Button).custom_minimum_size != Vector2(ICON_PX, ICON_PX):
			odd_pool.append((b as Button).custom_minimum_size)
	check(odd_pool.is_empty(),
		"pool strip: every icon is exactly OFFBOARD_ICON x OFFBOARD_ICON (%d), found: %s" % [ICON_PX, str(odd_pool)])

	# The pool strip grows a "+" take-back slot, but ONLY in SETUP with a board
	# piece selected -- which is why it kept a hardcoded 46 long after every
	# stack button beside it moved onto the shared constant. Force that state
	# rather than leave the one control the pin cannot otherwise reach untested.
	icon_game.state = icon_game.State.SETUP
	icon_game.selected = Vector2i(2, 2)
	icon_game.hud.refresh()
	await process_frame
	var plus_slot: Button = null
	for c in icon_game.hud.pool_buttons():
		if c is Button and (c as Button).text == "+":
			plus_slot = c
	check(plus_slot != null, "(setup) the take-back \"+\" slot is present in SETUP with a selection")
	check(plus_slot != null and plus_slot.custom_minimum_size == Vector2(ICON_PX, ICON_PX),
		"pool strip: the \"+\" take-back slot is OFFBOARD_ICON too (%d), not the pre-NO-36 46" % ICON_PX)

	icon_game.queue_free()
	await process_frame

	# ---- NO-202: Inventory drawer shows most-recently-acquired first --------
	# _rebuild_items_grid/_rebuild_artefacts_grid used to list oldest-first —
	# the Stock drawer's own _stacks() was reversed for this by NO-182, these
	# two never were. save_config.gd appends "items"/"artefacts" config
	# entries in listed order, so g.items[0]/g.artefacts[0] are the OLDEST
	# held, [1] the NEWEST — the display's first cell must be the newest.
	var order_cfg := {"wave": 3, "board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"items": ["blitz", "extraction"],
		"artefacts": ["library-of-alexandria-matchbox", "oak-island-wishing-well"]}
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = order_cfg
	var order_game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(order_game)
	await process_frame
	await process_frame
	check(await _click_inventory(order_game, "Inventory 4"),
		"NO-202: (setup) Inventory opens with 2 Items + 2 Artefacts held")
	await process_frame
	check(order_game.items[0].key == "blitz" and order_game.items[1].key == "extraction",
		"NO-202: (setup) g.items itself is untouched — still acquisition order")
	check(order_game.artefacts[0].key == "library-of-alexandria-matchbox"
			and order_game.artefacts[1].key == "oak-island-wishing-well",
		"NO-202: (setup) g.artefacts itself is untouched — still acquisition order")

	# Items: display flips, but a cell's meta "key" — and the REAL g.items
	# index a click resolves to (item_pressed.emit(i) closes over the loop's
	# own `i`, unchanged by NO-202) — must still point at what that cell
	# shows, not at its on-screen position.
	var item_children: Array = order_game.hud.items_grid.get_children()
	check(item_children.size() >= 2, "(setup) two Item cells to check the order of")
	check(item_children[0].get_meta("key") == "extraction"
			and item_children[1].get_meta("key") == "blitz",
		"NO-202: Items grid shows the newest (extraction) first, oldest (blitz) last")
	var first_item_pos: Vector2 = (item_children[0] as Button).get_global_rect().get_center()
	_click(first_item_pos)
	await process_frame
	check(order_game.item_active == 1,
		"NO-202: clicking the newest-displayed (first) cell arms g.items[1] (extraction)'s"
			+ " real index, not display position 0")

	# Artefacts: same reversal, but a cell's tap closes over the artefact's
	# own KEY string (hud.gd's artefact_activate_pressed.emit(key)), never an
	# array index — so, unlike Items, there is no positional index for a
	# reversed display to point at the wrong entry. Verified structurally via
	# the same meta "key" convention _build_artefact_cell documents as its
	# probe/test lookup.
	check(await _click_inventory(order_game, "Inventory 4"),
		"NO-202: Inventory reopens (the Item click above closed it)")
	await process_frame
	var art_children: Array = order_game.hud.artefacts_grid.get_children()
	check(art_children.size() >= 2, "(setup) two Artefact cells to check the order of")
	check(art_children[0].get_meta("key") == "oak-island-wishing-well"
			and art_children[1].get_meta("key") == "library-of-alexandria-matchbox",
		"NO-202: Artefacts grid shows the newest (Oak Island) first, oldest (Library) last")
	order_game.queue_free()
	await process_frame

	# ---- NO-83: Donald Trump's info panel lists the Tariffs in force ---------
	# The Header scenario boots him with three Tariffs. His Power draws on the
	# King Ability catalogue (the only one that does), so his double-tap panel
	# carries the same rows the ⚠ overlay shows — and gains a row when his
	# Power escalates.
	var trump_cfg := {}
	for s in Scenarios.all():
		if str(s.name).begins_with("Header: King Wave"):
			trump_cfg = s.cfg
	check(not trump_cfg.is_empty(), "(setup) the Header King Wave scenario exists")
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = trump_cfg.duplicate(true)
	var trump_game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(trump_game)
	await process_frame
	await process_frame
	check(trump_game.hud.turn_label.text == "Donald Trump",
		"turn counter names the King while he is alive (got %s)" % trump_game.hud.turn_label.text)
	check(trump_game.hud.wave_label.text == "", "NO-114: the Wave counter is blank while a King is alive")
	var king_px: Vector2 = trump_game._tile_px(Vector2i(3, 10)) + Vector2(trump_game.tile, trump_game.tile) / 2
	_double_click(king_px)
	await process_frame
	check(trump_game.preview_open, "double-tap on the King opens his info panel")
	check(_has_label_text(trump_game.preview_panel, "Tariff on Move")
			and _has_label_text(trump_game.preview_panel, "Tariff on $ Gain")
			and _has_label_text(trump_game.preview_panel, "Tariff on Capture"),
		"...listing each Tariff in force by name")
	check(_has_label_text(trump_game.preview_panel, "Each piece move costs extra $."),
		"...with its description")
	check(not _has_label_text(trump_game.preview_panel, "Tariff on Pass"),
		"(setup) the fourth Tariff is not in force yet")
	check(await _click_button_in(trump_game.preview_panel, "Close"), "Close clickable")
	await process_frame
	trump_game.turns_since_wave = 30 # past the fourth stack step
	Kings.stack_power_if_due(trump_game)
	await create_timer(0.45).timeout # past the double-tap window of the last one
	_double_click(king_px)
	await process_frame
	check(trump_game.preview_open and _has_label_text(trump_game.preview_panel, "Tariff on Pass"),
		"the panel lists a Tariff that came into force since it was last opened")
	check(await _click_button_in(trump_game.preview_panel, "Close"), "Close clickable again")
	await process_frame
	trump_game.queue_free()
	await process_frame

	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"wave": 3,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "items": ["buff_box"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_inventory(game, "Inventory 1"), "Inventory opens for the Buff Box cancel/pick flow")
	await process_frame
	check(await _click_grid_cell(game.hud.items_grid, "buff_box"),
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
	# NO-85 story 58: cancelling targeting always reopens the Drawer — no
	# manual reopen needed any more (this used to be a click).
	check(game.hud.drawer_open == "inventory",
		"the Inventory Drawer reopened on its own after the cancel")
	# NO-118: an auto-reopen (game logic, not _click_inventory) — its own
	# settle wait, same reason as SETUP's auto-open above.
	await _await_drawer_settled(game, "inventory")
	check(await _click_grid_cell(game.hud.items_grid, "buff_box"), "Buff Box clickable again")
	await process_frame
	var buff_btn := _first_option_button(game.modals.buff_panel)
	check(buff_btn != null and "\n" in buff_btn.text,
		"choice options describe themselves (two-line label), same as Box Pick")
	# coordinator review 2026-09-21 (round3 abort): a failed check() above is
	# not licence to dereference the same null right after it — that is what
	# turned one honest failure into a dead coroutine and hid every assertion
	# past this point (CLAUDE.md: "a crash mid-coroutine silently skipping
	# later assertions"). Gate the click on buff_btn actually resolving so a
	# future regression here REPORTS instead of truncating the whole suite.
	if buff_btn:
		_click(buff_btn.get_global_rect().get_center())
		await process_frame
	check(not game.buff_pick_open and not game.item_targets.is_empty(),
		"picking a choice closes the modal and resumes targeting (the continuation)")
	_click(game._tile_px(Vector2i(2, 2)) + Vector2(game.tile, game.tile) / 2) # NO-124: tap stages + shows Confirm
	await process_frame
	check(not game.items.is_empty() and game.item_pending_tile == Vector2i(2, 2),
		"NO-124: staging the buff's target does not spend the Item yet")
	check(game.hud.multi_confirm_btn.visible, "NO-124: the floating Confirm affordance shows")
	_click(game.hud.multi_confirm_btn.get_global_rect().get_center())
	await process_frame
	check(game.items.is_empty(), "targeting the buff spends the item, closing the loop")

	# SETUP: the pass button reads START, and a stock piece can be dragged
	# from the pool strip onto a zone tile (game-feel pass 2026-07-06)
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {} # fresh run -> SETUP placement phase
	GameScript.next_army = "Crown"
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.state == game.State.SETUP, "empty config boots into SETUP")
	check(game.pass_button.text == "START", "setup shows START instead of PASS")
	# NO-128 (coordinator review 2026-09-19): SETUP places every piece on the
	# same back rows army_band overlays when open, so it starts collapsed
	# here — same call site and same reasoning as Stock starting open, just
	# the opposite direction. Not a lock: the wedge (asserted visible) still
	# reopens it on request.
	check(not game.hud.army_band.visible and not game.hud.army_band_open
			and game.hud.army_band_reopen.visible,
		"army_band starts collapsed in SETUP, freeing the placement rows")
	# NO-118: SETUP opens the Stock drawer on boot (game.gd:645), not through
	# _click_stock — a separate settle wait, since the geometry below
	# (drawer_rect, the press on stack_btn) reads the drawer's real on-screen
	# extent and a mid-slide Y would give the wrong covered-tile set.
	await _await_drawer_settled(game, "stock")
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
	# NO-84: the Drawer now covers the TOP of the board (high y, since
	# _tile_px draws y=0 at the screen BOTTOM) and leaves the SETUP zone
	# (y < PLAYER_ZONE_ROWS, always at the bottom) uncovered by construction
	# -- so `zone` above can never double as a legal SETUP placement tile
	# any more. `target` is a second, separate empty zone tile for the
	# "drag out, then actually deploy" half of this test.
	var target := Vector2i(-1, -1)
	for ty in range(Tuning.PLAYER_ZONE_ROWS):
		for tx in range(8):
			if not game.board.has(Vector2i(tx, ty)):
				target = Vector2i(tx, ty)
				break
		if target.x >= 0:
			break
	check(target.x >= 0, "(setup) an empty zone tile exists to deploy onto")
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

	# dragging OUT closes the drawer; the drop then lands on the revealed tile.
	# NO-84: the drawer opens from the TOP now — row 3 sits in the uncovered
	# band the Drawer is required to leave visible, but above the SETUP zone
	# (y < PLAYER_ZONE_ROWS) so it is genuinely "outside", not a placement
	# tile itself (this is a MOTION, not a release, so occupancy doesn't
	# matter either way).
	root.push_input(d_press.duplicate())
	await process_frame
	var high_px: Vector2 = game._tile_px(Vector2i(7, 3)) + Vector2(game.tile, game.tile) / 2
	var d_motion := InputEventMouseMotion.new()
	d_motion.position = high_px
	d_motion.global_position = high_px
	root.push_input(d_motion)
	await process_frame
	check(game.drawer_open == "", "dragging out of the drawer closes it")
	var target_px: Vector2 = game._tile_px(target) + Vector2(game.tile, game.tile) / 2
	var target_motion := InputEventMouseMotion.new()
	target_motion.position = target_px
	target_motion.global_position = target_px
	root.push_input(target_motion)
	await process_frame
	var target_release := InputEventMouseButton.new()
	target_release.button_index = MOUSE_BUTTON_LEFT
	target_release.pressed = false
	target_release.position = target_px
	target_release.global_position = target_px
	root.push_input(target_release)
	await process_frame
	check(game.board.has(target) and game.stock.size() == stock_before - 1,
		"drag from the stock strip places the piece on the target tile")
	# NO-118: a successful SETUP placement reopens the Stock drawer
	# unconditionally (_place's own "keep the placement flow going" branch,
	# game.gd) — a fresh slide, own settle wait before the next press reads
	# a row's rect.
	await _await_drawer_settled(game, "stock")

	# a CANCELLED drag (invalid drop spot) reopens the drawer it auto-closed
	var live2: Button = game.pool_box.filter(func(b: Node) -> bool:
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
	# (the drawer overlays the zone now — an outside tap closes it first).
	# NO-84: the "outside" tap needs to be outside the drawer's new TOP
	# footprint — (7, 0) again, same as high_px above.
	_click(game._tile_px(Vector2i(7, 3)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.drawer_open == "", "an outside tap closes the drawer")
	_click(game._tile_px(target) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	_click(game._tile_px(Vector2i(2, 1)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(Vector2i(2, 1)) and not game.board.has(target),
		"setup: tap-tap relocates a placed piece freely")

	# selecting a placed piece offers an empty stock slot to put it back
	_click(game._tile_px(Vector2i(2, 1)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	var slots: Array = game.pool_box.filter(func(b: Node) -> bool:
		return b is Button and b.text == "+" and not b.is_queued_for_deletion())
	check(not slots.is_empty(), "setup: selecting a placed piece shows the put-back slot")

	# and dragging a placed piece onto the Header's Stock button takes it back
	# (NO-83: drawer_buttons["stock"] IS the Header button — the Deck has none)
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
		"setup: drop on the Header's Stock button returns the piece to stock")

	# tap-to-place regression (2026-07-07): strip rebuilds on press/release used
	# to free the button before its arming tap fired
	check(await _click_stock(game), "Stock button reopens the drawer")
	await process_frame
	var live_stack: Button = game.pool_box.filter(func(b: Node) -> bool:
		return b is Button and b.has_meta("id") and not b.is_queued_for_deletion())[0]
	_click(live_stack.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(game.placing_id != "", "setup: tapping a stack arms placement")
	check(game.placing_id != "" and game.textures.has(game.placing_id) \
			and game.stock_armed.get_parent() == game.drawer_buttons["stock"]
			and game.drawer_buttons["stock"].get_parent() == game.hud
			and game.stock_armed.is_visible_in_tree(),
		"the armed marker rides the HEADER's Stock button overlay (NO-83)")
	_click(game._tile_px(Vector2i(6, 3)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.placing_id != "" and game.drawer_open == "",
		"outside tap closes the drawer but keeps the armed piece")
	_click(game._tile_px(Vector2i(6, 1)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(Vector2i(6, 1)), "setup: tapping a zone tile places the piece")

	# NO-128 (coordinator review 2026-09-19, third round): the second-round
	# version of this check threaded through the ~130 lines of SETUP state
	# above (which tile was empty, which drawer was open, whether an extra
	# outside tap was needed) and broke 4 checks, most likely one root cause
	# cascading through the rest — exactly the fragility flagged when it was
	# written. Rather than keep chasing it through someone else's state, a
	# dedicated, freshly-booted SETUP scenario is simpler and worth more:
	# the only state in play here is what this block itself creates.
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {} # fresh run -> SETUP placement phase
	GameScript.next_army = "Crown"
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.state == game.State.SETUP, "army_band transparency: fresh SETUP boot")
	check(not game.hud.army_band.visible and game.hud.army_band_reopen.visible,
		"army_band transparency: starts collapsed, same as the earlier SETUP check")
	await _await_drawer_settled(game, "stock") # SETUP opens Stock on boot
	var tband_stack: Button = game.pool_box.filter(func(b: Node) -> bool:
		return b is Button and b.has_meta("id") and not b.is_queued_for_deletion())[0]
	_click(tband_stack.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(game.placing_id != "", "army_band transparency: arming succeeds")
	# an outside tap dismisses Stock before the placement tap, same pattern
	# as every other SETUP placement in this file (e.g. the (6,3) -> (6,1)
	# pair above, before this block replaced its own copy of that pattern).
	_click(game._tile_px(Vector2i(6, 3)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.placing_id != "" and game.drawer_open == "",
		"army_band transparency: outside tap dismisses Stock, keeps the armed piece")
	# Row 0 is the row army_band's own geometry fully covers at a tile's
	# CENTER point (the point every click helper in this file targets):
	# ARMY_BAND_H (105, NO-180) plus ARMY_BAND_MARGIN (6) together exceed one
	# tile (~51) by more than the 6px gap between the board and the deck,
	# verified by hand against the formula, not measured.
	_click(game._tile_px(Vector2i(0, 0)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(Vector2i(0, 0)),
		"army_band transparency: places at row 0, under where the band opens")
	_click(game.hud.army_band_reopen.get_global_rect().get_center())
	check(game.hud.army_band.visible, "army_band transparency: the wedge reopens it mid-SETUP")
	# tap-tap relocate — both taps land inside army_band's now-open rect.
	# If the transparency fix regressed, the band eats the first tap and
	# neither board.has() call below changes.
	_click(game._tile_px(Vector2i(0, 0)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	_click(game._tile_px(Vector2i(3, 0)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(Vector2i(3, 0)) and not game.board.has(Vector2i(0, 0)),
		"army_band transparency: a tap-tap relocate reaches the board even under the OPEN band")

	# clearing the last enemy auto-passes the turn; first, the two properties
	# that need MORE THAN ONE captured piece to mean anything (user 2026-09-10):
	# the section lists one row per piece with the MOST RECENT CAPTURE FIRST,
	# and Convert works WITH A DUPLICATE HELD — the case that used to hand the
	# badge's corner to ▲ and merge instead of converting.
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"wave": 3, "gold": 100,
		"captured": ["rook", "bishop", "bishop"], # captured oldest -> newest
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_stock(game), "Stock drawer opens")
	await process_frame
	# NO-84: Captured Stock and Stock are two independent grids now, not a
	# tinted tail of one strip with a label marking the boundary (issue 96).
	# The two pools still obey different rules (a Captured entry can never be
	# deployed, issue 60, nor merged since 2026-09-10) — that is now which
	# GRID an entry is in.
	# V1: a button's direct parent is now its own row HBoxContainer, one level
	# under stock_grid/captured_grid (the VBoxContainer of rows) — check the
	# grandparent instead of the parent.
	check(_pool_rows(game, true).all(func(b: Button) -> bool:
				return b.get_parent().get_parent() == game.hud.captured_grid)
			and _pool_rows(game, false).all(func(b: Button) -> bool:
				return b.get_parent().get_parent() == game.hud.stock_grid),
		"Captured Stock and Stock are separate grids, not a tinted tail of one strip")
	# ONE ROW PER PIECE, NEWEST CAPTURE FIRST in _stacks()'s own data order —
	# but V1 (2026-09-21) fills the grid so _stacks()[0] (the newest, a
	# bishop) lands in the BOTTOM-RIGHT cell, with the rest filling backward
	# from there (hud.gd's _fill_rows_bottom_right). pool_buttons()'s flatten
	# (row-major: top row to bottom, left-to-right within a row) walks that
	# same ADD order, which is therefore the reverse of _stacks(): oldest
	# capture first, newest last.
	check(game.captured == ["rook", "bishop", "bishop"],
		"(sanity) the run captured a rook, then two bishops, in that order")
	var cap_order: Array = []
	for row in _pool_rows(game, true):
		cap_order.append(str((row as Button).get_meta("id")))
	check(cap_order == ["rook", "bishop", "bishop"],
		"the Captured section adds oldest-first, so the newest capture anchors the corner (%s)"
			% str(cap_order))
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
		check(await _click_stock(game), "Stock drawer reopens")
		await process_frame
	await create_timer(0.45).timeout # past the 400 ms double-tap window: a second
		# tap on the same entry inside it opens the piece preview instead
	# V1: [0] is no longer "the newest" (it's the oldest capture, the rook —
	# see the fill-order comment above), and this check specifically wants a
	# BISHOP row (the duplicate-held case) — filter by id instead of index.
	cap_row = _pool_rows(game, true).filter(
		func(b: Button) -> bool: return str(b.get_meta("id")) == "bishop")[0]
	var convert_badge: Button = null
	for c in cap_row.get_children():
		if c is Button and (c as Button).text.begins_with("⇄"):
			convert_badge = c
	var badge_cost: int = Shop.convert_price(game, "bishop")
	check(convert_badge != null and convert_badge.is_visible_in_tree()
			and convert_badge.text == "⇄$%d" % badge_cost and not convert_badge.disabled,
		"a captured entry shows its Convert badge with no arming step, priced and live at Wave 3")
	# NO-223 (2026-09-22 ruling, extended from the Sell badge): the ⇄ badge is
	# information only now — it takes no input, so clicking it does nothing.
	# Convert itself moved into the long-press preview's own menu.
	var gold_before_convert: int = game.gold
	_click(convert_badge.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(game.captured == ["rook", "bishop", "bishop"] and game.gold == gold_before_convert,
		"NO-223: the Convert badge is information only — clicking it does nothing")
	game.hud.stack_preview_requested.emit("bishop", true, "bishop") # the same
		# signal a real long press fires — see the Stock-sell block below
	await process_frame
	check(game.preview_open, "long-pressing a Captured entry opens its preview")
	check(await _click_button_in(game.preview_panel, "Convert (-$%d)" % badge_cost),
		"the preview's own Convert button is clickable")
	await process_frame
	check(game.captured == ["rook", "bishop"] and game.stock == ["bishop"]
			and game.gold == gold_before_convert - badge_cost,
		"Convert works with a DUPLICATE held: one bishop moves to Stock, priced, nothing merges")
	check(not game.preview_open, "converting closes the preview, same as Sell does")
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
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
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
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
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
	check(await _click_inventory(game, "Inventory 2"),
		"Inventory button opens the drawer")
	await process_frame
	check(game.drawer_open == "inventory"
			and game.hud.items_grid.is_visible_in_tree()
			and game.hud.artefacts_grid.is_visible_in_tree(),
		"inventory drawer shows items and artefacts together")
	var inv_acts: int = game.actions_left
	check(await _click_grid_cell(game.hud.items_grid, "blitz"),
		"item clickable in the inventory drawer")
	await process_frame
	check(game.item_targets.size() == 1 and game.item_targets[0] == Vector2i(2, 4),
		"Blitz offers the queen (its only own piece), whether moved or not")
	# NO-124: one tap stages the target AND shows the floating Confirm
	# affordance immediately — no re-tap, a real click, not an internal call.
	_click(game._tile_px(Vector2i(2, 4)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.item_pending_tile == Vector2i(2, 4) and not game.items.is_empty(),
		"NO-124: the tap stages the target — the Item is not spent yet")
	check(game.hud.tip_key != "", "NO-124: the pending target's description shows")
	check(game.hud.multi_confirm_btn.visible, "NO-124: the floating Confirm affordance shows")
	# NO-124 trap (CLAUDE.md "tests that pass for the wrong reason"): there is
	# no modal any more, so a stray board click must be proven a genuine
	# no-op, not mistaken for one because it silently landed on some HUD
	# chrome instead. A hardcoded corner is a geometry assertion in disguise
	# (the Buff Box check above hit exactly this) — reuse _backdrop_point to
	# FIND a tile no visible HUD button covers, same as the Buff Box probe.
	var elsewhere := _backdrop_point(game, game.hud, Vector2i(0, 0))
	_click(elsewhere)
	await process_frame
	check(game.item_pending_tile == Vector2i(2, 4) and not game.items.is_empty()
			and game.hud.multi_confirm_btn.visible,
		"NO-124: a tap on a non-target tile is a no-op — nothing committed, the affordance survives")
	_click(game.hud.multi_confirm_btn.get_global_rect().get_center())
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

	# Drone Strike: area targeting by real clicks — NO-124: one anchor tap
	# both previews the 3x3 AND stages it, showing the floating Confirm
	# affordance immediately (no re-tap needed to reach it).
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["pawn", 1, 4, 4],
		["pawn", 1, 5, 5], ["rook", 1, 7, 10]], "wave": 3, "items": ["drone_strike"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_inventory(game, "Inventory 1"), "Inventory opens for Drone Strike")
	await process_frame # let the drawer lay out before clicking into it
	check(await _click_grid_cell(game.hud.items_grid, "drone_strike"),
		"Drone Strike clickable in the drawer")
	await process_frame
	_click(game._tile_px(Vector2i(5, 5)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.item_active >= 0 and game.item_targets.size() == 9,
		"anchor click previews the 3x3")
	check(game.item_pending_tile == Vector2i(5, 5) and not game.items.is_empty(),
		"NO-124: the same tap already stages it — still not spent")
	check(game.hud.multi_confirm_btn.visible, "NO-124: the floating Confirm affordance shows")
	_click(game.hud.multi_confirm_btn.get_global_rect().get_center())
	await process_frame
	check(not game.board.has(Vector2i(5, 5)) and not game.board.has(Vector2i(4, 4))
			and game.items.is_empty(),
		"confirming the anchor wipes the 3x3")

	# Extraction: multi targeting by real clicks — taps toggle picks, and
	# NO-124: the floating Extract button IS the commit now (no second gate
	# behind it).
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["knight", 0, 4, 4],
		["rook", 1, 7, 10]], "wave": 3, "items": ["extraction"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_inventory(game, "Inventory 1"), "Inventory opens for Extraction")
	await process_frame # drawer layout before clicking into it
	check(await _click_grid_cell(game.hud.items_grid, "extraction"),
		"Extraction clickable in the drawer")
	await process_frame
	check(not game.hud.multi_confirm_btn.visible, "no confirm button before any pick")
	_click(game._tile_px(Vector2i(4, 4)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.hud.multi_confirm_btn.visible and game.hud.multi_confirm_btn.text == "Extract 1",
		"picking a piece shows the Extract confirm")
	# Cancel costs nothing (CLAUDE.md: "a cancelled targeting costs nothing").
	# NO-137 SUPERSEDED NO-124's cancel gesture here: this block used to
	# reopen the Inventory drawer and tap the armed chip again, but NO-137's
	# backdrop is MOUSE_FILTER_STOP over the whole deck (Shop/Inventory/
	# Ability/Pass) WHILE CONFIRM IS SHOWING — "these are not clickable right
	# now" is the ticket's own wording — so that reopen click is now
	# absorbed on purpose. Don't restore the reopen-and-retap version on the
	# grounds that it "used to pass"; cancel through multi_cancel_btn
	# instead, same as a player now must. The observable CONSEQUENCE is
	# unchanged (CLAUDE.md: "assert the observable consequence, never the
	# flag that was just written") — item_active/items/board(4,4) below are
	# the same assertions the old gesture made.
	_click(game.hud.multi_cancel_btn.get_global_rect().get_center())
	await process_frame
	check(game.item_active == -1 and not game.items.is_empty() and game.board.has(Vector2i(4, 4)),
		"NO-124/NO-137: cancelling disarms Extraction entirely — nothing spent, board untouched")
	# NO-85 story 58: cancelling always reopens the Drawer, on its own slide
	# (NO-118) — settle before clicking into it, same as every other reopen.
	# _confirm_target_cancelled (game.gd) reopens Inventory the same way the
	# old chip-tap cancel did.
	await _await_drawer_settled(game, "inventory")
	check(await _click_grid_cell(game.hud.items_grid, "extraction"),
		"Extraction re-armable after a cancel")
	await process_frame
	_click(game._tile_px(Vector2i(4, 4)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	_click(game.hud.multi_confirm_btn.get_global_rect().get_center())
	await process_frame
	check(not game.board.has(Vector2i(4, 4)) and game.stock.has("knight")
			and game.items.is_empty(),
		"Extract confirm returns the pick to Stock")

	# NO-137: the floating Confirm's backdrop + Cancel. Bottom UI (Shop/
	# Inventory) must read as "not clickable" while armed, and Cancel must
	# cost nothing (Economy.charge only ever runs from _item_apply, on a
	# commit — neither reset behind Cancel goes near it).
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["knight", 0, 4, 4],
		["rook", 1, 7, 10]], "wave": 3, "items": ["extraction"], "gold": 100}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_inventory(game, "Inventory 1"), "NO-137: Inventory opens for Extraction")
	await process_frame
	check(await _click_grid_cell(game.hud.items_grid, "extraction"),
		"NO-137: Extraction clickable in the drawer")
	await process_frame
	_click(game._tile_px(Vector2i(4, 4)) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.hud.multi_confirm_btn.visible, "NO-137: Confirm shows, staged")
	check(game.hud.confirm_backdrop.visible and game.hud.multi_cancel_btn.visible,
		"NO-137: the backdrop and Cancel appear alongside Confirm")
	var gold_before: int = game.gold
	# CLAUDE.md: "a probe can pass because its click was CONSUMED" — click
	# exactly where the Shop/Inventory buttons sit (now covered by the
	# backdrop) and assert BOTH that neither opened AND that the targeting
	# this backdrop belongs to survived; a swallowed click alone would
	# satisfy the first half either way.
	_click(game.hud.shop_button.get_global_rect().get_center())
	await process_frame
	check(not game.shop_open() and game.hud.multi_confirm_btn.visible
			and game.hud.confirm_backdrop.visible,
		"NO-137: the backdrop blocks Shop, and the targeting behind it survives the click")
	_click(game.hud.drawer_buttons["inventory"].get_global_rect().get_center())
	await process_frame
	check(game.hud.drawer_open != "inventory" and game.hud.multi_confirm_btn.visible,
		"NO-137: the backdrop blocks Inventory too")
	_click(game.hud.multi_cancel_btn.get_global_rect().get_center())
	await process_frame
	check(game.item_active == -1 and game.board.has(Vector2i(4, 4)) and game.gold == gold_before,
		"NO-137: Cancel disarms for free — board untouched, no Gold spent")
	check(not game.hud.multi_confirm_btn.visible and not game.hud.confirm_backdrop.visible
			and not game.hud.multi_cancel_btn.visible,
		"NO-137: Confirm/backdrop/Cancel all hide together once cancelled")

	# Shop: bottom-row button opens the right-edge drawer, which never scrolls
	# — tap a tile to expand it (name/effect/Buy), Buy purchases a piece for
	# gold only, no Action cost (issue 64), the tile greys SOLD in place,
	# Close dismisses (money-and-shop/04, shop-drawer-ui/08)
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 500}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_shop(game), "Shop button clickable")
	await process_frame
	check(game.modals.shop_panel != null and game.modals.shop_panel.visible,
		"the shop drawer opens")
	check(not game.hud.shop_button.disabled and game.hud.shop_button.text == "Shop",
		"the Shop button is live and unlabelled")

	# NO-240: the Shop opens from Wave 1 (issue 101's lock is gone), EMPTY until
	# its first restock -- a real click on its own Wave-1 boot.
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 1, "gold": 500}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(not game.hud.shop_button.disabled and game.hud.shop_button.text == "Shop",
		"NO-240: the Shop button is enabled on Wave 1")
	check(await _click_shop(game) and game.shop_open(), "NO-240: clicking it opens the Shop on Wave 1")
	await process_frame
	var early_tiles := 0
	var to_scan: Array = [game.modals.shop_panel]
	while not to_scan.is_empty():
		var n: Node = to_scan.pop_back()
		if n.has_meta("shop_index"):
			early_tiles += 1
		to_scan.append_array(n.get_children())
	check(early_tiles == 0 and game.shop_stock.is_empty(), "NO-240: the Wave-1 Shop has no slots",
		"tiles=%d stock=%d" % [early_tiles, game.shop_stock.size()])
	check(_has_label_text(game.modals.shop_panel, "Restocks at wave %d" % Tuning.SHOP_UNLOCK_WAVE),
		"NO-240: the empty Shop says when it restocks")

	# restore what the checks below expect: a stocked run with the Shop drawer
	# OPEN. The Wave-1 boot above consumed the instance they were written
	# against, and leaving it would fail them on state, not on behaviour.
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 500}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_shop(game), "Shop reopens after the empty-state check")
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
	if check(tile != null, "an affordable piece tile exists"):
		_click(tile.get_global_rect().get_center())
		await process_frame
		# NO-167 (Max review, second pass): a tile tap opens its own preview now,
		# not an in-place dock — same "long press = the thing's own menu" shape
		# NO-144 gave held Stock/Item/Artefact entries, mirrored here with Buy in
		# Sell's place.
		check(game.preview_open, "tapping a Shop tile opens its preview")
		var sh_stock: int = game.stock.size()
		var sh_gold: int = game.gold
		var sh_acts: int = game.actions_left
		check(await _click_button_in(game.preview_panel, "Buy"),
			"Buy clickable in the tile's preview")
		await process_frame
		check(game.stock.size() == sh_stock + 1 and game.gold < sh_gold
				and game.actions_left == sh_acts,
			"shop Buy adds the piece and debits gold, never an Action (issue 64)")
		check(game.shop_stock[tile_index].sold, "the bought slot is marked sold")
		check(not game.preview_open, "buying closes the preview, same as Close")
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
	if sold_tile != null:
		_click(sold_tile.get_global_rect().get_center())
		await process_frame
		check(game.preview_open, "the sold tile is still tappable to preview")
		check(await _click_button_in(game.preview_panel, "SOLD"),
			"the preview now shows SOLD instead of Buy")
		check(await _click_button_in(game.preview_panel, "Close"),
			"the preview's own Close is clickable")
		await process_frame
		check(not game.preview_open, "closing the preview leaves the Shop open behind it")
	check(game.modals.shop_panel.visible, "...the Shop itself is untouched")
	# NO-167 (Max review, second pass): Close is now PERMANENT at the bottom
	# of the Shop — present whether or not a tile's preview is open, not an
	# either/or with a detail zone (that either/or was the bug Max caught in
	# the first review pass).
	check(await _click_button_in(game.modals.shop_panel, "Close"), "shop Close clickable")
	# NO-118: Close now animates the panel off-screen and only hides it when
	# that tween finishes. Condition-based, same idiom as
	# _await_drawer_settled above, rather than a fixed timer: poll the exact
	# thing the check below asserts, bounded, so a broken tween fails loudly
	# instead of the wait silently outrunning or undershooting the animation.
	# NO-192 follow-up: bounded on WALL TIME, not a frame count. This loop was
	# missed when the settle waits were converted (it is an inline close wait,
	# not one of the _await_drawer_settled copies) and it was the one assertion
	# still failing on the slower Aux box afterwards — same cause, same fix.
	var shop_close_t0 := Time.get_ticks_msec()
	var shop_close_polls := 0
	while game.modals.shop_panel.visible \
			and Time.get_ticks_msec() - shop_close_t0 < SETTLE_CAP_MS:
		await process_frame
		shop_close_polls += 1
	check(not game.modals.shop_panel.visible, "the shop drawer closes",
		"visible=%s after %d polls, elapsed=%dms" % [game.modals.shop_panel.visible,
			shop_close_polls, Time.get_ticks_msec() - shop_close_t0])

	# Selling (NO-144): moved off the Shop entirely and onto the previewed
	# thing's own menu — long-pressing a Stock entry (here: the same signal a
	# real long press fires, hud.stack_preview_requested) opens its preview
	# with a Sell button in it. NO-223 (2026-09-22 ruling): every sell path
	# confirms now, this one included, and a Captured entry's preview offers
	# Convert in Sell's place (moved off the ⇄ badge, which is information
	# only now — tested separately above) rather than no action at all: per
	# NO-144's own ruling it still offers no Sell — convert first, then sell
	# from Stock like anything else.
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 500, "stock": ["pawn"], "captured": ["pawn"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	game.hud.stack_preview_requested.emit("pawn", false, game.stock[0])
	await process_frame
	check(game.preview_open, "long-pressing a Stock entry opens its preview")
	var sell_stock_before: int = game.stock.size()
	var sell_gold_before: int = game.gold
	var sell_acts_before: int = game.actions_left
	check(await _click_button_in(game.preview_panel, "Sell (+$5)"),
		"the Sell button in the Stock entry's preview is clickable (pawn value 10, 50% floored = 5)")
	await process_frame
	check(game.buff_pick_open and game.stock.size() == sell_stock_before and game.gold == sell_gold_before,
		"NO-223: Sell confirms first — nothing sold yet")
	check(await _click_button_in(game.modals.buff_panel, "Sell"), "the confirm's own Sell button is clickable")
	await process_frame
	check(game.stock.size() == sell_stock_before - 1 and game.gold == sell_gold_before + 5
			and game.actions_left == sell_acts_before and not game.buff_pick_open,
		"confirming sells the Stock piece, pays Gold, and costs no Action (issue 64)")
	check(not game.preview_open, "selling closes the preview, same as Close")

	game.hud.stack_preview_requested.emit("pawn", true, game.captured[0])
	await process_frame
	check(game.preview_open, "long-pressing a Captured entry opens its preview too")
	var cap_preview_has_sell := false
	var cap_preview_has_convert := false
	var to_visit_pv: Array = [game.preview_panel]
	while not to_visit_pv.is_empty():
		var n: Node = to_visit_pv.pop_back()
		if n is Button and (n as Button).text.begins_with("Sell"):
			cap_preview_has_sell = true
		if n is Button and (n as Button).text.begins_with("Convert"):
			cap_preview_has_convert = true
		to_visit_pv.append_array(n.get_children())
	check(not cap_preview_has_sell,
		"a Captured entry's preview offers no Sell — Convert first, then sell from Stock")
	check(cap_preview_has_convert,
		"NO-223: ...and offers Convert instead, moved off the ⇄ badge (information only now)")
	check(await _click_button_in(game.preview_panel, "Close"), "Close dismisses it")
	await process_frame

	# Direct deploy is gone (issue 60) and so is the merge (2026-09-10): the tap
	# that used to arm a Captured stack arms nothing now, so a following
	# Deploy-tile tap has nothing to place. Driven through the REAL tap rather
	# than by setting the armed flags — there are none left to set — and paired
	# with a Stock control, because "nothing was placed" is also what a tap
	# that failed to arm ANYTHING would look like.
	game.stock.append("pawn") # the Sell test above emptied Stock; Captured
		# still has its own untouched pawn from the boot config
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

	# NO-223 (2026-09-22 ruling): the Inventory drawer's own Sell badge on an
	# Item/Artefact cell is INFORMATION ONLY — price and affordability, no
	# input of its own (badges "should just be information, whatever they do
	# should be accessed with a long press"). Selling (and, for an Item,
	# Using) lives in the long-press preview's own menu instead: Use + Sell
	# for an Item, Sell only for an Artefact (Activate stays a plain tap,
	# never duplicated in here). Every Sell confirms first, including this
	# one (an Item wasn't originally going to, but Max ruled it in line with
	# the rest once the badge itself became always-visible chrome).
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 500, "items": ["blitz"], "artefacts": ["agartha-welcome-mat"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	check(await _click_inventory(game, "Inventory 2"),
		"Inventory opens with one held Item and one held Artefact")

	var item_cell: Button = null
	for c in game.hud.items_grid.get_children():
		if c is Button and c.has_meta("key") and str(c.get_meta("key")) == "blitz":
			item_cell = c
	var item_sell_badge: Button = null
	if check(item_cell != null, "(setup) the Blitz Item cell is in the Inventory grid"):
		for c in item_cell.get_children():
			if c is Button and (c as Button).text.begins_with("$"):
				item_sell_badge = c
	var item_payout: int = Shop.sell_payout(game, "item", game.items[0])
	check(item_sell_badge != null and item_sell_badge.is_visible_in_tree()
			and item_sell_badge.text == "$%d" % item_payout and not item_sell_badge.disabled
			and item_sell_badge.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the Item cell carries its own Sell badge, priced and live — but non-interactive")
	var gold_before_item: int = game.gold
	if item_sell_badge != null:
		_click(item_sell_badge.get_global_rect().get_center())
		await process_frame
		await process_frame
		check(game.items.size() == 1 and game.gold == gold_before_item and not game.buff_pick_open
				and game.item_active == 0,
			"NO-223: the Item's badge is information only — the click falls through to the cell, which arms the Item instead of selling it")
		# Disarm (a second tap on the Item cancels targeting) so the preview's Use
		# below starts from a clean state instead of hitting the cancel branch.
		game._use_item(0)
		await process_frame
		check(game.item_active == -1 and game.item_targets.is_empty(),
			"(setup) tapping the armed Item again disarms it")

	# Use, from the long-press preview: Blitz targets a tile ("target":
	# "tile"), so Use arms board targeting rather than resolving on the spot
	# — the same _use_item a plain tap on the cell already fires.
	game.hud.item_preview_requested.emit(0)
	await process_frame
	check(game.preview_open, "long-pressing the Item opens its preview")
	check(await _click_button_in(game.preview_panel, "Use"),
		"the preview's own Use button is clickable")
	await process_frame
	check(game.item_active == 0 and not game.preview_open,
		"Use arms Blitz's board targeting rather than resolving it immediately")
	check(not game.item_targets.is_empty(), "(setup) Blitz has a legal target tile")
	if not game.item_targets.is_empty():
		game._item_click(game.item_targets[0]) # stage a full target, same as a real board tap
		check(game.item_pending_tile == game.item_targets[0] and game.hud.multi_confirm_btn.visible,
			"(setup) staging a target raises the floating Confirm affordance")

		# Change 3 (2026-09-22 ruling — "selling mid target isn't an issue if we
		# handle the sell well by cancelling everything the targeting was doing
		# and coming back to a normal state"): selling the Item currently driving
		# that targeting cancels it first instead of being blocked.
		game.hud.item_preview_requested.emit(0)
		await process_frame
		check(await _click_button_in(game.preview_panel, "Sell (+$%d)" % item_payout),
			"the Sell button is still offered while the Item is armed and staged")
		await process_frame
		check(game.buff_pick_open and game.item_active == 0 and game.item_pending_tile == game.item_targets[0],
			"the confirm opens first — targeting is untouched until Sell is actually confirmed")
		check(await _click_button_in(game.modals.buff_panel, "Sell"), "confirming the sale")
		await process_frame
		check(game.items.is_empty() and game.gold == gold_before_item + item_payout,
			"the Item is gone and Gold paid")
		check(game.item_active == -1 and game.item_targets.is_empty()
				and game.item_pending_tile == Vector2i(-1, -1)
				and not game.hud.multi_confirm_btn.visible and not game.hud.multi_cancel_btn.visible,
			"and the targeting it was driving is fully cancelled — no armed item, no staged tile, no floating Confirm/Cancel left over")
		check(game.hud.drawer_open == "inventory" and game.state == game.State.PLAYER_TURN,
			"story 58: cancelling targeting reopens the Inventory Drawer — the board is back to a normal interactive state, not just a flag flipped")

	var art_cell: Button = null
	for c in game.hud.artefacts_grid.get_children():
		if c is Button and c.has_meta("key") and str(c.get_meta("key")) == "agartha-welcome-mat":
			art_cell = c
	var art_sell_badge: Button = null
	if check(art_cell != null, "(setup) the Agartha Welcome Mat Artefact cell is in the Inventory grid"):
		for c in art_cell.get_children():
			if c is Button and (c as Button).text.begins_with("$"):
				art_sell_badge = c
	var art_entry: Variant = game._artefact_entry("agartha-welcome-mat")
	var art_payout: int = Shop.sell_payout(game, "artefact", art_entry)
	check(art_sell_badge != null and art_sell_badge.is_visible_in_tree()
			and art_sell_badge.text == "$%d" % art_payout and not art_sell_badge.disabled
			and art_sell_badge.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the Artefact cell carries its own Sell badge too — also non-interactive")
	var gold_before_art: int = game.gold
	if art_sell_badge != null:
		_click(art_sell_badge.get_global_rect().get_center())
		await process_frame
		check(game.artefacts.size() == 1 and game.gold == gold_before_art and not game.buff_pick_open,
			"NO-223: clicking the Artefact's badge does nothing either")

	game.hud.artefact_preview_requested.emit("agartha-welcome-mat")
	await process_frame
	check(game.preview_open, "long-pressing the Artefact opens its preview")
	var art_preview_has_use := false
	var to_visit_art: Array = [game.preview_panel]
	while not to_visit_art.is_empty():
		var n: Node = to_visit_art.pop_back()
		if n is Button and (n as Button).text == "Use":
			art_preview_has_use = true
		to_visit_art.append_array(n.get_children())
	check(not art_preview_has_use,
		"NO-223: an Artefact's menu offers no Use — Activate stays a plain tap, never duplicated in here")
	check(await _click_button_in(game.preview_panel, "Sell (+$%d)" % art_payout),
		"the Sell button in the Artefact's preview is clickable")
	await process_frame
	check(game.buff_pick_open and game.artefacts.size() == 1 and game.gold == gold_before_art,
		"tapping Sell opens a confirm first — nothing sold yet")
	check(await _click_button_in(game.modals.buff_panel, "Cancel"), "Cancel is offered")
	await process_frame
	check(not game.buff_pick_open and game.artefacts.size() == 1 and game.gold == gold_before_art,
		"Cancel keeps the Artefact held and pays nothing")

	game.hud.artefact_preview_requested.emit("agartha-welcome-mat")
	await process_frame
	check(await _click_button_in(game.preview_panel, "Sell (+$%d)" % art_payout), "Sell again")
	await process_frame
	check(await _click_button_in(game.modals.buff_panel, "Sell"), "Sell confirms the sale")
	await process_frame
	check(game.artefacts.is_empty() and game.gold == gold_before_art + art_payout
			and not game.buff_pick_open,
		"confirming sells the Artefact, pays Gold through Economy, and closes the confirm")

	# Change 3, Artefact case: the same cancel-then-sell shape while an
	# activatable Artefact (Bovine Tractor Beam) is mid-targeting.
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults()
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 500, "artefacts": ["bovine-tractor-beam"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game._begin_artefact_targeting("bovine-tractor-beam")
	check(game.artefact_targeting_key == "bovine-tractor-beam",
		"(setup) Bovine Tractor Beam is armed and targeting")
	var bovine_entry: Variant = game._artefact_entry("bovine-tractor-beam")
	var bovine_payout: int = Shop.sell_payout(game, "artefact", bovine_entry)
	var gold_before_bovine: int = game.gold
	game.hud.artefact_preview_requested.emit("bovine-tractor-beam")
	await process_frame
	check(game.preview_open, "the preview opens even while the Artefact is mid-targeting")
	check(await _click_button_in(game.preview_panel, "Sell (+$%d)" % bovine_payout),
		"Sell is offered while targeting is live")
	await process_frame
	check(await _click_button_in(game.modals.buff_panel, "Sell"), "confirming the sale")
	await process_frame
	check(game.artefacts.is_empty() and game.gold == gold_before_bovine + bovine_payout,
		"the Artefact is gone and Gold paid")
	check(game.artefact_targeting_key == "" and game.artefact_targets.is_empty()
			and game.artefact_pending_tile == Vector2i(-1, -1)
			and not game.hud.multi_confirm_btn.visible and not game.hud.multi_cancel_btn.visible,
		"and its targeting is fully cancelled too — no staged pick, no floating Confirm/Cancel left over")
	check(game.hud.drawer_open == "inventory",
		"story 58: cancelling targeting reopens the Inventory Drawer here too")

	# Jet Fuel Vial (issue 52): a Shop-only control, restock button appears
	# only while it's held — confirm-gated, same as every untargeted
	# activation (user ruling).
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 100, "artefacts": ["jet-fuel-vial"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_shop(game), "Shop button clickable")
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
	if restock_btn != null:
		_click(restock_btn.get_global_rect().get_center()) # Godot doesn't fire
			# `pressed` on a disabled Button — this must be a genuine no-op
		await process_frame
		check(not game.buff_pick_open, "clicking the disabled Restock button opens nothing")

	# the Shop is reachable in any state, not just your turn (GDD Shop page)
	var was_state: int = game.state
	game.state = game.State.ENEMY_TURN
	check(await _click_shop(game), "Shop button clickable off-turn")
	await process_frame
	check(game.modals.shop_panel.visible, "the shop opens during the enemy turn")
	check(await _click_button_in(game.modals.shop_panel, "Close"), "off-turn shop closes")
	await process_frame
	game.state = was_state

	# All-Seeing Eye Contact Lens (issue 49): the Shop reveals a Box's
	# contents only while holding it — NO-167 (second pass) moved this from
	# the old detail dock into the tile's own preview modal. A fresh boot so
	# it's definitely held, then preview whichever Box slot rolled
	# (preferring Huge — 7 entries — when one shows up) and confirm the
	# reveal Label carries the slot's exact contents WITHOUT breaking the
	# Buy button underneath it — the concrete risk of a variable-length
	# reveal in a panel that also has to fit a Buy button.
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 5, "gold": 500, "artefacts": ["all-seeing-eye-contact-lens"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_shop(game), "(setup) Shop button clickable, All-Seeing Eye held")
	await process_frame
	var box_slot_index := -1
	var box_slot_size := ""
	for idx in game.shop_stock.size():
		var s: Dictionary = game.shop_stock[idx]
		if s.kind == "box" and not s.get("ad", false) and (box_slot_index == -1 or s.size == "huge"): # a Gold Box: its Buy reads "Buy" (NO-241)
			box_slot_index = idx
			box_slot_size = s.size
			if s.size == "huge": # the worst case (7 entries) — stop as soon as it's found
				break
	check(box_slot_index >= 0, "(setup) a Box slot exists to preview")
	var box_button: Button = null
	to_visit = [game.modals.shop_panel]
	while not to_visit.is_empty():
		var n: Node = to_visit.pop_back()
		if n is Button and n.has_meta("shop_index") and n.get_meta("shop_index") == box_slot_index:
			box_button = n
			break
		to_visit.append_array(n.get_children())
	if check(box_button != null, "(setup) the Box tile is clickable"):
		_click(box_button.get_global_rect().get_center())
		await process_frame
		check(game.preview_open, "tapping the Box tile opens its preview")
		var reveal_label: Label = null
		to_visit = [game.preview_panel]
		while not to_visit.is_empty():
			var n: Node = to_visit.pop_back()
			if n is Label and n.text.begins_with("Contains: "):
				reveal_label = n
				break
			to_visit.append_array(n.get_children())
		var expect_reveal := "Contains: %s" % Box.contents_names(game.shop_stock[box_slot_index].contents)
		check(reveal_label != null and reveal_label.text == expect_reveal,
			"All-Seeing Eye Contact Lens: the %s Box's reveal Label shows its exact contents" % box_slot_size)
		check(await _click_button_in(game.preview_panel, "Buy"),
			"...and the Buy button underneath it is still clickable, even at Huge's 7-entry worst case")

	# reinforcement shop: opens pending at turn start; NO-141 made the grant
	# automatic (in Stock by the time the panel shows) and turned the panel
	# into an announcement — no Buy button any more, Dismiss hands the turn back
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"wave": 11, "score": 100, "pending_reinforce": true,
		"king_abilities": ["move_cost"]} # the tariff section below reuses this boot
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.reinforce_panel != null and game.reinforce_panel.visible,
		"the reinforcement shop opens at turn start")
	check(game.stock.size() == game._reinforce_ids().size() * 2,
		"NO-141/NO-170: the grant already landed in Stock before the screen ever showed, two of each")
	# Same NO-5 question for the panel that now opens every 10 Waves. Tile (2,2)
	# holds the player queen, and the control below the tariff section proves
	# this exact tap selects her with no panel up.
	#
	# NO-83 moved the board 66px down and the queen's tile landed under the
	# pick's own Buy button: the click was CONSUMED, "selects nothing" passed
	# for the wrong reason, and "still open" failed (CLAUDE.md, tests that pass
	# for the wrong reason). The tap now goes to the queen's tile only when no
	# button of the pick covers it, else to a tile the backdrop covers.
	game.selected = Vector2i(-1, -1)
	var pick_tap: Vector2 = _backdrop_point(game, game.reinforce_panel, Vector2i(2, 2))
	_click(pick_tap)
	await process_frame
	check(game.selected == Vector2i(-1, -1),
		"NO-5: a board tap under the open reinforcement pick selects nothing")
	check(game.reinforce_panel.visible, "...and the pick is still open")
	check(not await _click_button_in(game.reinforce_panel, "Buy"),
		"NO-141: no Buy button — the grant already happened, nothing left to click")
	check(await _click_button_in(game.reinforce_panel, "Dismiss"), "Dismiss clickable")
	await process_frame
	check(not game.reinforce_panel.visible and not game.pending_reinforce,
		"Dismiss closes the announcement and clears the pending flag")

	# the ⚠ button is off screen (NO-83) but its state and handler stay: the
	# text still counts, and its signal still opens the detail overlay
	check(game.hud.king_ability_button.text == "⚠1", "the ⚠ button still counts the Tariff in force")
	game.hud.king_ability_pressed.emit()
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
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	# NO-83: the Arrows button is off screen; its signal and handler stay
	game.hud.arrow_toggle_pressed.emit()
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

	game.hud.arrow_toggle_pressed.emit()
	await process_frame
	check(not game.arrow_mode, "arrow mode is off again")
	_click(qpx2)
	await process_frame
	check(game.selected == Vector2i(2, 2), "board taps select pieces again once arrow mode is off")
	_click(qpx2) # deselect before the lifetime check below
	await process_frame

	game.hud.arrow_toggle_pressed.emit()
	await process_frame
	check(game.arrow_mode, "Arrows re-enabled")
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

	# --- Artefact activation (issue 52, NO-85): the ✹ cell in the Artefacts
	# grid, confirm/cancel, and Bovine Tractor Beam's targeted cancel. New
	# interactive UI — Godot headless drops GUI picking, which is why this
	# probe exists.
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"wave": 1, "gold": 100, "score": 0,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"artefacts": ["oak-island-wishing-well"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	# (the empty-vs-held Artefacts-grid sizing itself is asserted headlessly
	# in test_items_artefacts_4.gd; this probe exists for CLICKABILITY, which
	# headless can't verify — Godot headless drops GUI picking)
	check(await _click_inventory(game, "Inventory 1"), "Inventory opens for Oak Island Wishing Well")
	await process_frame
	# NO-85: the Artefacts grid holds every held Artefact, activatable or not.
	# This scenario holds exactly one, so the grid has exactly one REAL cell
	# (NO-165: plus empty-slot placeholders filling out the rest of the cap,
	# counted separately below since they're Panels, not Buttons).
	var real_cells := 0
	for c in game.hud.artefacts_grid.get_children():
		if c is Button:
			real_cells += 1
	check(real_cells == 1,
		"the Artefacts grid shows ONE cell: the Artefact's, and no Army Ability chip")
	var star_chips := 0
	for c in game.hud.artefacts_grid.get_children():
		if c is Button and (c as Button).text.begins_with("★"):
			star_chips += 1
	check(star_chips == 0,
		"no ★ chip survives in the Artefacts grid — the Ability has exactly one home")
	check(await _click_grid_cell(game.hud.artefacts_grid, "oak-island-wishing-well"),
		"the ✹ cell is clickable")
	await process_frame
	check(game.buff_pick_open and game.modals.buff_panel.visible,
		"clicking an untargeted ✹ cell opens the confirm modal (user ruling: no target = confirm)")
	check(await _click_button_in(game.modals.buff_panel, "Cancel"), "Cancel clickable on the confirm modal")
	await process_frame
	check(not game.buff_pick_open and game.gold == 100 and not game.oak_island_used_this_turn \
			and game._artefact_count("oak-island-wishing-well") == 1,
		"cancelling the confirm costs nothing — no Gold, no charge, Artefact untouched")
	# the confirm modal is the only thing that closed — this activation never
	# touches the drawer (unlike a targeted Item), so the cell is still
	# directly clickable with no need to reopen Inventory
	check(await _click_grid_cell(game.hud.artefacts_grid, "oak-island-wishing-well"),
		"the ✹ cell is clickable again after a cancel, drawer untouched")
	await process_frame
	check(await _click_button_in(game.modals.buff_panel, "Confirm"), "Confirm clickable on the confirm modal")
	await process_frame
	check(not game.buff_pick_open and game.gold == 475 and game.score == 4000, # issue 57:
			# Score x10 (400 -> 4000), Gold untouched
		"confirming activates it: 25 Gold spent, +400 Score (earn() also grants " +
		"the matching Gold, same as every other reward routed through it: 100 - 25 + 400 = 475)")

	# Bovine Tractor Beam: the one TARGETED activation. Tapping the chip again
	# MID-STAGE (before stage B) still cancels straight from targeting, no
	# confirm modal involved (user ruling, unchanged). NO-124: stage B itself
	# stages AND shows the floating Confirm affordance in the same tap, same
	# shape as an Item's own final tap. Targeting DOES hand the drawer back
	# to the board (same as a targeted Item), so cancelling requires
	# reopening Inventory to reach the chip.
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"wave": 1,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"artefacts": ["bovine-tractor-beam"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_inventory(game, "Inventory 1"), "Inventory opens for Bovine Tractor Beam")
	await process_frame
	check(await _click_grid_cell(game.hud.artefacts_grid, "bovine-tractor-beam"),
		"the Bovine Tractor Beam chip is clickable")
	await process_frame
	check(not game.buff_pick_open and game.artefact_targeting_key == "bovine-tractor-beam" \
			and game.hud.drawer_open == "",
		"clicking Bovine's chip stages targeting and hands the board back — no confirm modal (it has a target instead)")
	_click(game._tile_px(Vector2i(7, 10)) + Vector2(game.tile, game.tile) / 2) # stage A: the enemy Rook
	await process_frame
	check(game.artefact_target_stage_a == Vector2i(7, 10), "tapping the enemy Rook on the board stages it")
	check(await _click_inventory(game, "Inventory 1"), "Inventory reopens to reach the chip mid-targeting")
	await process_frame
	check(await _click_grid_cell(game.hud.artefacts_grid, "bovine-tractor-beam"),
		"the chip stays clickable mid-targeting (to cancel)")
	await process_frame
	check(game.artefact_targeting_key == "" and game.board.has(Vector2i(7, 10)) \
			and not game.bovine_used_this_wave and game._artefact_count("bovine-tractor-beam") == 1,
		"tapping the chip again CANCELS FROM TARGETING — no move, no charge, Artefact untouched")
	check(await _click_grid_cell(game.hud.artefacts_grid, "bovine-tractor-beam"),
		"the chip is clickable again after a targeting cancel (drawer still open post-cancel)")
	await process_frame
	_click(game._tile_px(Vector2i(7, 10)) + Vector2(game.tile, game.tile) / 2) # stage A again
	await process_frame
	var bovine_dest: Vector2i = game.artefact_targets[0]
	_click(game._tile_px(bovine_dest) + Vector2(game.tile, game.tile) / 2) # stage B
	await process_frame
	check(game.artefact_pending_tile == bovine_dest and game.board.has(Vector2i(7, 10)),
		"NO-124: the stage-B tap stages the destination — the Rook has not moved yet")
	check(game.hud.multi_confirm_btn.visible, "NO-124: the floating Confirm affordance shows")
	_click(game.hud.multi_confirm_btn.get_global_rect().get_center())
	await process_frame
	check(game.artefact_targeting_key == "" and not game.board.has(Vector2i(7, 10)) \
			and game.board.get(bovine_dest, {}).get("id", "") == "rook" and game.bovine_used_this_wave,
		"confirming relocates the enemy piece and spends the once-per-Wave charge")
	# NO-85 story 60: this scenario holds only Bovine, now spent for the Wave —
	# nothing left to do in the Inventory Drawer, so it stays closed.
	check(game.hud.drawer_open == "",
		"after Bovine completes with nothing else usable, the Inventory Drawer stays closed")

	# --- NO-85 stories 58-60: the Inventory Drawer reopen rule, all three
	# branches, on Items (Bovine above already covered the ✹ Artefact "stays
	# closed" branch). Two Sniper Items and two enemy pieces, each one Sniper
	# needs an enemy ATTACKED by a player piece (item_logic.gd's own gate):
	# the rook sits on the queen's diagonal, the pawn on her row, neither
	# obstructed.
	game.queue_free()
	await process_frame
	# NO-202 (round3 coordinator review, 2026-09-21): this used to hold TWO
	# Snipers — same key, same cell text/icon — so every _click_grid_cell(...,
	# "sniper") below was genuinely ambiguous between them: it always
	# resolves to whichever cell is FIRST in items_grid's child order, which
	# was g.items[0] under main's forward build order and is g.items[1] under
	# NO-202's reversed one. That is not a case this scenario's own point
	# (the Drawer reopen rule around using a targeted Item, stories 58-60)
	# ever needed to be ambiguous about — _inventory_drawer_reopens()
	# (game.gd) only ever checks `not items.is_empty()`, never an item's
	# identity or kind, so the rule does not require two of a kind. Air
	# Strike is the closest distinct substitute: same "target": "tile" shape,
	# same _item_apply case (`"air_strike", "sniper": _destroy(b, true)`,
	# game.gd) — its only difference is a WEAKER tile_valid condition
	# (item_logic.gd: `enemy and not king`, no "attacked by a player piece"
	# requirement), which the existing board (both the rook and the pawn are
	# already attacked, per the comment above) satisfies for free. Every
	# lookup below can now name the specific Item it means.
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"wave": 1,
		"board": [["queen", 0, 2, 2], ["rook", 1, 5, 5], ["pawn", 1, 7, 2]],
		"items": ["sniper", "air_strike"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.actions_left = 5 # generous: isolates the reopen rule from auto-pass-at-0
	check(await _click_inventory(game, "Inventory 2"), "Inventory opens for the reopen-rule probe")
	await process_frame
	check(await _click_grid_cell(game.hud.items_grid, "sniper"), "Sniper clickable")
	await process_frame
	check(game.item_active == 0 and game.hud.drawer_open == "",
		"arming an Item that needs a board target closes the Drawer")
	check(await _click_inventory(game, "Inventory 2"), "reopen to reach the item and cancel it")
	await process_frame
	check(await _click_grid_cell(game.hud.items_grid, "sniper"), "tap the armed Sniper again: cancel")
	await process_frame
	check(game.item_active == -1 and game.hud.drawer_open == "inventory",
		"cancelling targeting always reopens the Drawer (story 58)")
	await _await_drawer_settled(game, "inventory") # NO-118: auto-reopen, own settle wait
	check(await _click_grid_cell(game.hud.items_grid, "sniper"), "Sniper clickable again")
	await process_frame
	_click(game._tile_px(Vector2i(5, 5)) + Vector2(game.tile, game.tile) / 2) # Sniper's target: the rook
	await process_frame
	check(game.hud.multi_confirm_btn.visible, "NO-124: the tap stages AND shows Confirm")
	_click(game.hud.multi_confirm_btn.get_global_rect().get_center())
	await process_frame
	check(game.items.size() == 1 and game.items[0].key == "air_strike"
			and game.hud.drawer_open == "inventory",
		"after use, the Drawer reopens because Air Strike is still usable (story 59)")
	await _await_drawer_settled(game, "inventory") # NO-118: auto-reopen, own settle wait
	check(await _click_grid_cell(game.hud.items_grid, "air_strike"), "the remaining Air Strike clickable")
	await process_frame
	_click(game._tile_px(Vector2i(7, 2)) + Vector2(game.tile, game.tile) / 2) # the second enemy: the pawn
	await process_frame
	check(game.hud.multi_confirm_btn.visible, "NO-124: the tap stages AND shows Confirm")
	_click(game.hud.multi_confirm_btn.get_global_rect().get_center())
	await process_frame
	check(game.items.is_empty() and game.hud.drawer_open == "",
		"after using the last Item, the Drawer stays closed — nothing left usable (story 60)")

	# --- NO-124: an untargeted Item now needs a real Confirm too — Max's
	# click budget is "select, confirm", and arming used to spend
	# Counter-Intel on the spot (1 click, one short of that floor).
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"wave": 1,
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"items": ["counter_intel"], "king_abilities": ["move_cost"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_inventory(game, "Inventory 1"), "Inventory opens for Counter-Intel")
	await process_frame
	check(not game.hud.multi_confirm_btn.visible, "no confirm button before arming")
	check(await _click_grid_cell(game.hud.items_grid, "counter_intel"), "Counter-Intel clickable")
	await process_frame
	check(game.item_active == 0 and not game.items.is_empty(),
		"arming an untargeted Item stages it — not spent yet")
	check(game.hud.multi_confirm_btn.visible and game.hud.multi_confirm_btn.text == "Confirm",
		"the floating Confirm affordance shows immediately — nothing to target")
	_click(game.hud.multi_confirm_btn.get_global_rect().get_center())
	await process_frame
	check(game.items.is_empty() and game.king_abilities_suppressed,
		"confirming an untargeted Item spends it and applies its effect")

	# --- issue 67: the Army Ability chip — same Activate section, but 1
	# Action (not 0) and its own confirm-vs-targeting shapes. Old Guard's
	# Shield Wall is untargeted (confirm modal, same shape as Oak Island
	# above); The Muster's Call the Banners is targeted, but at a STOCK
	# entry, not a board tile (Bovine's own targeting flow above never
	# applies) — its cancel/commit both happen through the Stock drawer.
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
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
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
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
	# NO-118: re-clicking the ability re-stages targeting, which reopens the
	# Stock drawer the same way it did the first time (line 2157 above) —
	# game logic, not _click_stock, so its own settle wait before the press
	# below reads a real on-screen rect.
	await _await_drawer_settled(game, "stock")
	check(game.pool_box.size() == 1, "(setup) the Stock strip shows the one pawn stack")
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
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
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
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
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

	# NO-84: the Stock Drawer's grid split, empty hint, clipping, and the
	# reopen rule's three live branches after a successful mid-turn drag-drop
	# (cancel is already covered above; SETUP's own always-reopen is separate
	# and untouched).
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"wave": 3, "gold": 100, "stock": ["pawn", "pawn"],
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(await _click_stock(game), "NO-84: Stock drawer opens")
	await process_frame
	check((game.hud.drawers["stock"] as Control).clip_contents,
		"NO-84: the Stock Drawer clips its contents")
	check(game.hud.captured_hint.visible,
		"NO-84: with no Captured Stock, the left side shows the empty hint")
	# Three deploys follow, one Action each (Tuning.ACTIONS_PER_TURN is 2) — a
	# generous budget keeps the turn from auto-passing mid-sequence, which
	# would end PLAYER_TURN and mask the reopen rule under test, not exercise it.
	game.actions_left = 10

	# reopens: a Stock stack is still affordable to deploy. Deploy targets are
	# y < PLAYER_ZONE_ROWS or adjacent to a player piece (Rules.placement_tiles)
	# — (1,1) is a neighbour of the queen at (2,2) and empty.
	var deploy_cost: int = Economy.deploy_cost(game)
	game.gold = deploy_cost * 3
	var tile_a := Vector2i(1, 1)
	await _drag_drop(root, _pool_rows(game, false)[0],
		game._tile_px(tile_a) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(tile_a) and game.drawer_open == "stock",
		"NO-84: reopens after a drop — a Stock stack is still affordable")

	# reopens: Stock is now empty, but a Captured entry is affordable to convert
	game.captured = ["bishop"]
	game.hud.refresh()
	await process_frame
	game.gold = maxi(deploy_cost, Shop.convert_price(game, "bishop")) * 3
	var tile_b := Vector2i(3, 1) # also a neighbour of the queen, still empty
	# NO-118: the previous drop's auto-reopen (line 2275) is a fresh slide,
	# not a click through _click_stock — its own settle wait before reading
	# the row's rect again.
	await _await_drawer_settled(game, "stock")
	await _drag_drop(root, _pool_rows(game, false)[0],
		game._tile_px(tile_b) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(tile_b) and game.stock.is_empty() and game.drawer_open == "stock",
		"NO-84: reopens after a drop — Stock is empty but Captured Stock can convert")
	check(not game.hud.captured_hint.visible,
		"NO-84: the empty hint is gone once a Captured Stock entry exists")

	# stays closed: nothing left to deploy or convert
	game.captured = []
	game.stock = ["pawn"]
	game.hud.refresh()
	await process_frame
	var tile_c := Vector2i(1, 3) # also a neighbour of the queen, still empty
	await _await_drawer_settled(game, "stock") # NO-118: the 2nd drop's auto-reopen, own settle wait
	await _drag_drop(root, _pool_rows(game, false)[0],
		game._tile_px(tile_c) + Vector2(game.tile, game.tile) / 2)
	await process_frame
	check(game.board.has(tile_c) and game.drawer_open == "",
		"NO-84: stays closed after a drop when nothing is left to deploy or convert")

	# --- NO-152: the targeting tip must never cover the floating Confirm/
	# Cancel strip — item-confirm.png caught Blitz's tip drawn over a LOW
	# target tile's Confirm, fully hiding it (Cancel partly). hud.gd's
	# tip_panel and every one of its descendants already carry
	# MOUSE_FILTER_IGNORE (the NO-118 pattern, checked by hand: nothing in
	# the tip is left at the default STOP), so the click was never actually
	# swallowed — this was a pure z-order/positioning bug. Assert the
	# CONSEQUENCE of the press, not just that the button exists, so a
	# regression that reintroduces a real swallow would still be caught.
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194: every fixture starts from the documented default army
	GameScript.next_config = {"wave": 1,
		"board": [["queen", 0, 2, 2], ["pawn", 0, 4, 0]], "items": ["blitz"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var blitz_target := Vector2i(4, 0) # y=0: the BOTTOM row on screen — _tile_px
		# flips y (Tuning.BOARD_H - 1 - pos.y), so this is the lowest, tightest
		# case against the floating strip, matching item-confirm.png
	check(await _click_inventory(game, "Inventory 1"), "Inventory opens for Blitz")
	await process_frame
	check(await _click_grid_cell(game.hud.items_grid, "blitz"), "Blitz clickable")
	await process_frame
	_click(game._tile_px(blitz_target) + Vector2(game.tile, game.tile) / 2) # the low pawn
	await process_frame
	check(game.hud.tip_panel.visible and game.hud.multi_confirm_btn.visible,
		"NO-152: the targeting tip and the floating Confirm both show for a low target")
	var confirm_rect: Rect2 = game.hud.multi_confirm_btn.get_global_rect()
	var tip_rect: Rect2 = game.hud.tip_panel.get_global_rect()
	check(not tip_rect.intersects(confirm_rect),
		"the tip's rect never overlaps Confirm's — Confirm stays fully visible")
	# NO-152 follow-up (Max: "center name and infos with diagram, slim the
	# sides down to the diagram width"): the target tile above is the pawn from
	# next_config's board, so diagram_id != "" and tip_diagram is showing —
	# assert the geometry these changes actually produce, not the flags that
	# were just written.
	check(game.hud.tip_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"NO-152: the tip's name/info text is centred, matching the diagram above it")
	var tip_sb := game.hud.tip_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var expected_w: float = game.hud.tip_diagram.custom_minimum_size.x \
		+ tip_sb.content_margin_left + tip_sb.content_margin_right
	check(absf(tip_rect.size.x - expected_w) <= 2.0,
		"NO-152: the panel is slimmed to the diagram's own width (+ its fixed side margins), not the wider TIP_W")
	_click(confirm_rect.get_center())
	await process_frame
	check(game.board.get(blitz_target, {}).get("blitz_free_move", false)
			and not game.hud.multi_confirm_btn.visible,
		"a click at Confirm's centre actually reaches it: Blitz resolves and the pending state clears")

	# --- NO-236: drag and drop. A Stock drag deploys exactly like the tap
	# flow (same _place: 1 Action + the deploy Gold); a refused drop changes
	# nothing; drop_legal — the preview's green/red — agrees with what the
	# drop then does; an Item dragged onto a target arms and stages it, and
	# Confirm is still what commits it.
	game.queue_free()
	await process_frame
	GameScript.reset_boot_defaults() # NO-194
	GameScript.next_config = {"wave": 3, "gold": 200, "stock": ["pawn", "pawn", "pawn"],
		"board": [["queen", 0, 2, 2], ["pawn", 1, 2, 4]], "items": ["blitz"]}
	game = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.actions_left = 10 # several deploys below must never auto-pass the turn
	var half_tile := Vector2(game.tile, game.tile) / 2
	# CONTROL: the tap flow's price, in this same state
	check(await _click_stock(game), "NO-236: Stock opens")
	await process_frame
	var gold0: int = game.gold
	_click(_pool_rows(game, false)[0].get_global_rect().get_center())
	await process_frame
	var tap_tile := Vector2i(1, 1) # a neighbour of the queen: a deploy tile
	_click(game._tile_px(tap_tile) + half_tile)
	await process_frame
	var tap_gold: int = gold0 - game.gold
	check(game.board.has(tap_tile) and game.actions_left == 9,
		"NO-236 control: a tap deploy lands and spends 1 Action",
		"placed=%s actions=%d" % [game.board.has(tap_tile), game.actions_left])
	# the drag, onto another deploy tile
	if game.hud.drawer_open != "stock":
		await _click_stock(game)
	await process_frame
	var gold1: int = game.gold
	var drag_tile := Vector2i(3, 1)
	await _drag_drop(root, _pool_rows(game, false)[0], game._tile_px(drag_tile) + half_tile)
	await process_frame
	check(game.board.has(drag_tile) and game.actions_left == 8 and gold1 - game.gold == tap_gold,
		"NO-236: a Stock->board drag deploys and charges exactly like the tap",
		"placed=%s actions=%d drag_gold=%d tap_gold=%d" % [game.board.has(drag_tile),
			game.actions_left, gold1 - game.gold, tap_gold])
	# a refused Stock drop: the preview says so mid-drag, and nothing changes
	var bad_tile := Vector2i(-1, -1)
	for ty in range(Tuning.BOARD_H - 1, -1, -1):
		for tx in range(Tuning.BOARD_W):
			var cand := Vector2i(tx, ty)
			if bad_tile.x < 0 and not game.board.has(cand) and not game._deploy_tiles().has(cand):
				bad_tile = cand
	var good_tile := Vector2i(1, 3) # still a free neighbour of the queen
	check(bad_tile.x >= 0 and not game.board.has(good_tile) and game._deploy_tiles().has(good_tile),
		"NO-236: the fixture has a refused and an accepted deploy tile")
	await _await_drawer_settled(game, "stock") # the drop above reopened it
	var snap := [game.gold, game.actions_left, game.stock.size(), game.board.size()]
	var row: Button = _pool_rows(game, false)[0]
	_press(row.get_global_rect().get_center())
	await process_frame
	for p: Vector2 in [Vector2(10, 10000), game._tile_px(bad_tile) + half_tile]:
		var mv := InputEventMouseMotion.new()
		mv.position = p
		mv.global_position = p
		root.push_input(mv)
		await process_frame
	check(game.pool_drag_id != "" and not game.drop_legal(bad_tile) and game.drop_legal(good_tile),
		"NO-236: mid Stock drag, drop_legal is red on a non-deploy tile and green on a deploy tile",
		"drag=%s bad=%s good=%s preview=%s state=%d" % [game.pool_drag_id, game.drop_legal(bad_tile), game.drop_legal(good_tile), game.preview_open, game.state])
	_release(game._tile_px(bad_tile) + half_tile)
	await process_frame
	await process_frame
	check([game.gold, game.actions_left, game.stock.size(), game.board.size()] == snap,
		"NO-236: a refused Stock drop leaves Gold, Actions, Stock and the board unchanged",
		"before=%s after=%s" % [snap, [game.gold, game.actions_left, game.stock.size(), game.board.size()]])
	# a board drag: drop_legal follows legal_dests; a refused drop moves nothing
	game._set_drawer("")
	for i in 20:
		await process_frame # the close slide (PANEL_SLIDE_S) — clickability drops at once
	var queen := Vector2i(2, 2)
	_press(game._tile_px(queen) + half_tile)
	await process_frame
	var legal_dest: Vector2i = game.legal_dests[0] if not game.legal_dests.is_empty() else Vector2i(-1, -1)
	var refused := Vector2i(-1, -1)
	for ty in range(Tuning.BOARD_H):
		for tx in range(Tuning.BOARD_W):
			var cand := Vector2i(tx, ty)
			if refused.x < 0 and cand != queen and not game.board.has(cand) \
					and not game.legal_dests.has(cand):
				refused = cand
	var to_refused := InputEventMouseMotion.new()
	to_refused.position = game._tile_px(refused) + half_tile
	to_refused.global_position = to_refused.position
	root.push_input(to_refused)
	await process_frame
	check(game.drag_from == queen and legal_dest.x >= 0 and game.drop_legal(legal_dest)
			and not game.drop_legal(refused) and not game.drop_legal(queen),
		"NO-236: mid board drag, drop_legal is green on a legal destination, red elsewhere and on home",
		"drag_from=%s dest=%s refused=%s preview=%s" % [game.drag_from, legal_dest, refused, game.preview_open])
	_release(to_refused.position)
	await process_frame
	check(game.board.has(queen) and game.board[queen].id == "queen" and not game.board.has(refused)
			and game.actions_left == 8,
		"NO-236: a refused board drop leaves the piece home and spends nothing")
	# an Item dragged onto its target: armed + staged, Confirm still required
	var items_before: int = game.items.size()
	check(await _click_inventory(game, "Inventory %d" % items_before), "NO-236: Inventory opens")
	await process_frame
	var cell: Button = null
	for c in game.hud.items_grid.get_children():
		if c is Button and not c.is_queued_for_deletion() and c.get_meta("key", "") == "blitz":
			cell = c
	check(cell != null, "NO-236: the Blitz cell exists")
	_press(cell.get_global_rect().get_center())
	await process_frame
	for p: Vector2 in [Vector2(10, 10000), game._tile_px(queen) + half_tile]:
		var mv := InputEventMouseMotion.new()
		mv.position = p
		mv.global_position = p
		root.push_input(mv)
		await process_frame
	check(game.item_drag >= 0 and game.drop_legal(queen) and not game.drop_legal(refused),
		"NO-236: mid Item drag, drop_legal is green on a valid target and red on an empty tile",
		"item_drag=%d preview=%s" % [game.item_drag, game.preview_open])
	_release(game._tile_px(queen) + half_tile)
	await process_frame
	await process_frame
	check(game.item_active >= 0 and game.item_pending_tile == queen
			and game.hud.multi_confirm_btn.visible and game.items.size() == items_before
			and not game.board[queen].get("blitz_free_move", false),
		"NO-236: dropping an Item on a target arms and stages it — nothing spent before Confirm",
		"active=%d pending=%s confirm=%s items=%d" % [game.item_active, game.item_pending_tile,
			game.hud.multi_confirm_btn.visible, game.items.size()])
	_click(game.hud.multi_confirm_btn.get_global_rect().get_center())
	await process_frame
	check(game.board[queen].get("blitz_free_move", false) and game.items.size() == items_before - 1,
		"NO-236: Confirm commits the dragged Item")

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
	if node == null: # round3 abort (coordinator review 2026-09-21): the modal
		# not being open is a real failure the caller's own check() already
		# reports — this helper crashing on the null panel is what silently
		# killed the whole suite instead, one call before the guard above.
		return null
	if node is Button and not node.text.begins_with("Skip"):
		return node
	for c in node.get_children():
		var hit := _first_option_button(c)
		if hit:
			return hit
	return null


## NO-133: the Box's own options are an icon grid now (meta.box_index, same
## idiom as _shop_tile's meta.shop_index) — distinct from _first_option_button
## above, which still matches the choice-pick modal's plain text buttons
## (buff_panel) unchanged. Tapping this SELECTS the option; _box_pick_button
## below is the second tap that confirms it.
func _first_option_tile(node: Node) -> Button:
	if node is Button and node.has_meta("box_index"):
		return node
	for c in node.get_children():
		var hit := _first_option_tile(c)
		if hit:
			return hit
	return null


## The floating "Pick" confirm that appears in the Box's detail dock once a
## tile is selected (meta.box_pick, same idiom as box_index above).
func _box_pick_button(node: Node) -> Button:
	if node is Button and node.has_meta("box_pick"):
		return node
	for c in node.get_children():
		var hit := _box_pick_button(c)
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


## Opens the Shop, taps the first affordable Box tile to open its preview,
## then clicks Buy in there — issue 47: Boxes only come from the Shop now
## (the box-carrier enemy is gone), so every Box click-probe drives this same
## real-click path. NO-167 (Max review, second pass): the tile no longer
## expands in place — it opens its own preview (game.preview_panel), same as
## every other Shop tile since the detail dock was deleted.
## Assumes the Shop is closed and the player's turn is active on entry.
## Returns false when no Box could be bought, so callers skip what needs one.
func _buy_a_box(game: Node2D) -> bool:
	check(await _click_shop(game), "Shop button clickable")
	await process_frame
	var tile: Button = null
	var tile_index := -1
	var to_visit: Array = [game.modals.shop_panel]
	while not to_visit.is_empty():
		var n: Node = to_visit.pop_back()
		if n is Button and n.has_meta("shop_index"):
			var idx: int = n.get_meta("shop_index")
			var slot: Dictionary = game.shop_stock[idx]
			if slot.kind == "box" and not slot.get("ad", false) and ShopScript.can_buy(game, slot): # NO-241: not the Ad Box
				tile = n
				tile_index = idx
				break
		to_visit.append_array(n.get_children())
	if not check(tile != null, "(setup) an affordable Box tile exists"):
		return false
	_click(tile.get_global_rect().get_center())
	await process_frame
	check(game.preview_open, "(setup) tapping the Box tile opens its preview")
	var bought := check(await _click_button_in(game.preview_panel, "Buy"),
		"(setup) Buy clickable in the Box tile's preview")
	await process_frame
	return bought
