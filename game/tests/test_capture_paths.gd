extends SceneTree
## The debug capture paths (tools/capture.md), driven headless: every new
## `--show-screen` state reaches its screen, every `--ui-demo` flow completes
## through the real modals, every Guide page opens, and every scenario name
## the doc quotes still resolves. The PNG/video capture itself needs a window;
## the state behind it does not.
## Run headless:  godot --headless --path game -s tests/test_capture_paths.gd

const GameScript := preload("res://scripts/game.gd")
const Scenarios := preload("res://data/scenarios.gd")
const UiDemo := preload("res://scripts/ui_demo.gd")
const Ads := preload("res://scripts/ads.gd")
const Guide := preload("res://scripts/guide.gd")
const ItemLogic := preload("res://scripts/item_logic.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _boot(scenario_name: String) -> Node2D:
	var index := Scenarios.find(scenario_name)
	check(index >= 0, "scenario resolves by name: " + scenario_name)
	GameScript.reset_boot_defaults()
	var cfg: Dictionary = Scenarios.all()[maxi(index, 0)].cfg.duplicate()
	cfg.seed = 1
	GameScript.next_config = cfg
	GameScript.is_scenario = true # never touches the real save
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	return game


func _free(game: Node2D) -> void:
	game.queue_free()
	await process_frame


func _has_button(node: Node, text: String) -> bool:
	for b in node.find_children("*", "Button", true, false):
		if (b as Button).text == text and not b.is_queued_for_deletion():
			return true
	return false


func _init() -> void:
	await process_frame # Engine.get_main_loop() is still null inside _init

	# --- every scenario name tools/capture.md quotes ---------------------------
	var doc := FileAccess.get_file_as_string(
		ProjectSettings.globalize_path("res://").path_join("../tools/capture.md"))
	check(doc != "", "tools/capture.md is readable")
	var re := RegEx.create_from_string("--scenario-name \"([^\"]+)\"")
	var quoted := {}
	for m in re.search_all(doc):
		quoted[m.get_string(1)] = true
	check(quoted.size() >= 5, "capture.md quotes scenario names (%d)" % quoted.size())
	for n in quoted:
		check(Scenarios.find(n) >= 0, "capture.md's scenario exists: " + str(n))
	check(Scenarios.find("no such scenario") == -1, "an unknown name is -1, not a fallback")

	# --- --show-screen states -------------------------------------------------
	var shots := [
		["gameover", "Loss: clock-out (10s)"],
		["gameover-retry", "Loss: clock-out (10s)"],
		["ad", "Movement & drag"],
		["win", "Win screen: wave 50 (capture King)"],
		["setup", "Movement & drag"],
		["stock-return", "Movement & drag"],
		["feed", "Movement & drag"],
		["pick", UiDemo.SCENARIO],
	]
	for shot in shots:
		var screen: String = shot[0]
		var game := await _boot(shot[1])
		await game._debug_show_screen(screen, PackedStringArray())
		await process_frame # the kill feed flushes deferred
		match screen:
			"gameover":
				check(game.state == GameScript.State.GAME_OVER and game.overlay.visible
					and game.modals.buff_panel == null, "gameover: the loss screen, no retry offer")
				check(not game._banner_layer.visible and not game.hud.feed.visible,
					"gameover: banners and the kill feed are hidden under the end screen (NO-100)")
			"gameover-retry":
				check(game.state == GameScript.State.GAME_OVER and not game.overlay.visible
					and game.modals.buff_panel != null, "gameover-retry: the ad-retry prompt is up")
			"ad":
				check(Ads.is_open(), "ad: the AD overlay is up")
				if Ads.is_open():
					Ads.close_button().pressed.emit()
			"win":
				check(game.win_open and game.overlay.visible, "win: the wave-50 win screen is up")
				var text := ""
				for l in game.overlay.find_children("*", "Label", true, false):
					text += (l as Label).text + "\n"
				check(text.contains("King, Nero, has fallen"),
					"win: names the fallen King (NO-100), not a bare \"King\"")
				check(not game._banner_layer.visible and not game.hud.feed.visible,
					"win: banners and the kill feed are hidden under the end screen (NO-100)")
				game._on_win_continue()
				check(game._banner_layer.visible and game.hud.feed.visible,
					"win Continue: banners and the kill feed are back for endless")
			"setup":
				check(game.state == GameScript.State.SETUP and game.board.is_empty()
					and not game.stock.is_empty() and game.hud.drawer_open == "stock",
					"setup: SETUP, empty board, full Stock, Stock drawer open")
			"stock-return":
				check(game.state == GameScript.State.SETUP and game.selected.x >= 0
					and game.hud.drawer_open == "stock" and _has_button(game.hud.stock_grid, "+"),
					"stock-return: the \"+\" return slot is in the open Stock drawer")
			"feed":
				check(game.hud.feed.get_child_count() >= 3, "feed: three kill-feed lines posted")
			"pick":
				check(game.modals.buff_panel != null and _has_button(game.modals.buff_panel, "Sell"),
					"pick: the shared choice modal, as a Sell confirm")
		await _free(game)

	# --- --open-drawer stock on the Promote-badge scenario (NO-100) ----------
	# It captured the Shop: an enemy-free board made the first turn queue wave
	# 10, a restock Wave, and that opens the Shop over the drawer.
	var crown := await _boot("Combo Army: Crown — free merges against a Stock full of pairs")
	check(crown.wave == 9 and not crown.shop_open(),
		"promote capture: boots on wave 9 with the Shop closed (wave %d)" % crown.wave)
	crown._set_drawer("stock")
	check(crown.hud.drawer_open == "stock" and not crown.shop_open(),
		"promote capture: --open-drawer stock shows the Stock drawer")
	await _free(crown)

	# --- --ui-demo flows, through the real preview + confirm ----------------
	for flow in UiDemo.FLOWS:
		var game := await _boot(UiDemo.SCENARIO)
		check(game.items.size() == ItemLogic.cap(game),
			"(setup) the sandbox holds a full inventory, %d Items (the cap)" % ItemLogic.cap(game))
		var stock_n: int = game.stock.size()
		var cap_n: int = game.captured.size()
		var items_n: int = game.items.size()
		var arts_n: int = game.artefacts.size()
		var gold: int = game.gold
		var ok: bool = await UiDemo.run(game, flow, 0.0, false)
		check(ok, "ui-demo %s: every step found its button" % flow)
		match flow:
			"sell-stock":
				check(game.stock.size() == stock_n - 1 and game.gold > gold,
					"ui-demo sell-stock: one Stock piece sold for Gold")
			"convert":
				check(game.captured.size() == cap_n - 1 and game.stock.size() == stock_n,
					"ui-demo convert: Captured converted, then sold from Stock")
			"sell-item":
				check(game.items.size() == items_n - 1 and game.gold > gold, "ui-demo sell-item: one Item sold")
			"sell-artefact":
				check(game.artefacts.size() == arts_n - 1 and game.gold > gold,
					"ui-demo sell-artefact: one Artefact sold")
			"box-sell":
				check(game.items.size() == items_n and not game.box_open,
					"ui-demo box-sell: sold one Item inside the Box, then picked one (items %d -> %d, box_open %s, picks_left %d, offer %d)"
					% [items_n, game.items.size(), game.box_open, game.box_picks_left, game.box_offer.size()])
		await _free(game)

	# --- guide:<page> ---------------------------------------------------------
	var layer := Control.new()
	root.add_child(layer)
	var guide: Control = Guide.build(layer, func() -> void: pass, GameScript)
	guide.visible = true
	for page in ["rules", "pieces", "promotions", "fusions", "artefacts", "items", "indicators"]:
		check(Guide.open_page(guide, page), "guide:%s has a hub button" % page)
		var shown := false
		for c in guide.get_children():
			if c is ScrollContainer and c.visible:
				var head: Node = c.get_child(0).get_child(0)
				shown = shown or (head is Label and (head as Label).text.to_lower() == page)
			c.visible = false # back to a clean hub for the next page
		check(shown, "guide:%s opens its page" % page)
	check(not Guide.open_page(guide, "nope"), "an unknown Guide page opens nothing")
	# guide:<page>:<row> — the page with its detail panel open, settled
	var panel = Guide.detail_panel(guide)
	for page in ["pieces", "promotions", "fusions", "artefacts", "items"]:
		check(Guide.show_screen(guide, page + ":0"), "guide:%s:0 opens a row" % page)
		check(panel.is_open() and panel.visible and panel.content() != null,
			"guide:%s:0 shows the detail panel" % page)
		panel.instant = true
		check(Guide.go_back(guide) and not panel.visible, "guide:%s:0 Back closes the panel" % page)
		check(Guide.go_back(guide), "guide:%s:0 Back then leaves the page" % page)
		panel.instant = false
	check(not Guide.show_screen(guide, "rules:0"), "Rules has no rows to open")
	check(not Guide.show_screen(guide, "pieces:999"), "an out-of-range row opens nothing")
	layer.queue_free()

	print("---")
	if fails == 0:
		print("ALL CAPTURE PATHS OK")
	quit(1 if fails > 0 else 0)
