extends SceneTree
## NO-241: the ad placeholders — the Ads seam, the once-per-run retry on the
## first loss, and the Shop's Ad Box.
## Run headless:  godot --headless --path game -s tests/test_ads.gd

const GameScript := preload("res://scripts/game.gd")
const Ads := preload("res://scripts/ads.gd")
const Shop := preload("res://scripts/shop.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _boot(cfg: Dictionary) -> Node2D:
	GameScript.reset_boot_defaults()
	cfg = cfg.duplicate()
	cfg.seed = 1
	GameScript.next_config = cfg
	GameScript.is_scenario = true # keep the probe from touching the real save
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


## to_config minus what legitimately differs between a checkpoint and the run
## restored from it: the live-ticking Clock, the retry flag the restore sets,
## and the checkpoint itself (cleared inside a checkpoint). JSON-normalised.
func _comparable(cfg: Dictionary) -> String:
	var c: Dictionary = JSON.parse_string(JSON.stringify(cfg))
	for k in ["clock_s", "ad_retry_used", "wave_snapshot"]:
		c.erase(k)
	return JSON.stringify(c)


func _press_ad_close() -> void:
	var b: Button = Ads.close_button()
	if b != null:
		b.pressed.emit()


func _init() -> void:
	await process_frame # Engine.get_main_loop() is still null inside _init
	# --- the seam: the placeholder's Close grants the reward ---
	var rewarded := [0]
	Ads.show_rewarded(func() -> void: rewarded[0] += 1)
	check(Ads.is_open(), "Ads.show_rewarded opens the AD overlay")
	var label_ok := false
	if Ads.is_open():
		for l in Ads._layer.find_children("*", "Label", true, false):
			label_ok = label_ok or (l as Label).text == "AD"
	check(label_ok, "the overlay reads AD")
	check(rewarded[0] == 0, "no reward before it is closed")
	_press_ad_close()
	check(rewarded[0] == 1 and not Ads.is_open(), "closing the placeholder calls on_reward once and closes it")
	await process_frame

	var base := {"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 5}

	# --- a wave start takes the checkpoint ---
	var w := _boot(base)
	await process_frame
	w._queue_wave(w.wave + 1)
	w._begin_player_turn()
	check(int(w.wave_snapshot.get("wave", -1)) == w.wave
			and int(w.wave_snapshot.get("turn_number", -1)) == w.turn_number,
		"the first turn start of a wave snapshots the run (wave %d)" % w.wave)
	check((w.wave_snapshot.get("wave_snapshot", {}) as Dictionary).is_empty(),
		"a checkpoint never nests the previous one")
	w.queue_free()
	await process_frame

	# --- first loss: offered once; Accept -> ad -> the checkpoint, exactly ---
	var g := _boot(base)
	await process_frame
	g.ad_retry_enabled = true # scenario boots turn it off; this test drives it
	current_scene = g # reload_current_scene needs one, as the real game has
	g._take_wave_snapshot()
	var checkpoint := _comparable(g.wave_snapshot)
	g.gold += 777 # the run moves on after the checkpoint...
	g.score += 1234
	g.board.erase(Vector2i(2, 2))
	g._game_over(false, "Back-row breach") # ...and is lost
	check(g.buff_pick_open and g.ad_retry_used, "the first loss offers the ad retry")
	check(g.state == GameScript.State.GAME_OVER and not g.modals.overlay.visible,
		"the run is frozen, not ended, while the offer is up")
	g._choice_picked(true) # Accept
	check(Ads.is_open(), "Accept shows the ad")
	_press_ad_close()
	var r: Node = null
	for i in 60: # bounded: a reload that never lands fails here, not as a hang
		await process_frame
		if current_scene != null and current_scene != g and is_instance_valid(current_scene):
			r = current_scene
			break
	check(r != null, "the reward reloads the game")
	if r != null:
		await process_frame
		check(_comparable(r._to_config()) == checkpoint,
			"the restored run equals the wave-start checkpoint (to_config)")
		check(r.ad_retry_used, "the restored run has spent its retry")
		# --- second loss: the normal game over ---
		r.ad_retry_enabled = true
		r._game_over(false, "Clock out")
		check(not r.buff_pick_open and r.modals.overlay.visible,
			"a second loss ends the run — no second offer")
		r.queue_free()
		await process_frame

	# --- Decline -> the normal game over ---
	var d := _boot(base)
	await process_frame
	d.ad_retry_enabled = true
	d._take_wave_snapshot()
	d._game_over(false, "Clock out")
	d._choice_pick_cancelled()
	check(not Ads.is_open() and d.state == GameScript.State.GAME_OVER and d.modals.overlay.visible,
		"Decline ends the run normally")
	d.queue_free()
	await process_frame

	# --- autoplay never offers it ---
	var a := _boot(base)
	await process_frame
	a.ad_retry_enabled = true
	a._take_wave_snapshot()
	a.autoplay = true
	a._game_over(false, "Clock out")
	check(not a.buff_pick_open and a.modals.overlay.visible, "autoplay never offers the retry")
	a.queue_free()
	await process_frame

	# --- scenarios never offer it (ad_retry_enabled left as booted) ---
	var s := _boot(base)
	await process_frame
	s._take_wave_snapshot()
	s._game_over(false, "Clock out")
	check(not s.buff_pick_open, "a scenario boot never offers the retry")
	s.queue_free()
	await process_frame

	# --- the Ad Box: a 6th Box, bought with an ad, once per restock ---
	var b := _boot(base) # gold 0: the Ad Box needs none
	await process_frame
	var ai := -1
	for i in b.shop_stock.size():
		if b.shop_stock[i].get("ad", false):
			ai = i
	check(ai >= 0 and b.shop_stock[ai].kind == "box", "the Shop stocks an Ad Box")
	if ai >= 0:
		var slot: Dictionary = b.shop_stock[ai]
		check(b.gold == 0 and Shop.can_buy(b, slot) and Shop.price_text(b, slot) == "Watch ad",
			"it costs \"Watch ad\", not Gold")
		b._open_shop()
		await process_frame
		var tile_label := false
		for btn in b.modals.shop_panel.find_children("*", "Button", true, false):
			if btn.has_meta("shop_index") and int(btn.get_meta("shop_index")) == ai:
				for l in btn.find_children("*", "Label", true, false):
					tile_label = tile_label or (l as Label).text == "Watch ad"
		check(tile_label, "its Shop tile is labelled \"Watch ad\"")
		var contents: Array = slot.contents.duplicate(true)
		b.modals.shop_buy_pressed.emit(ai)
		check(Ads.is_open() and not b.box_open and not slot.sold, "buying it shows the ad first")
		_press_ad_close()
		check(b.box_open and b.shop_stock[ai].sold and b.gold == 0,
			"the reward opens the Box, marks the slot SOLD, and charges no Gold")
		check(JSON.stringify(b.box_offer) == JSON.stringify(contents),
			"the Box reveals its stock-time roll, exactly as a bought Box")
		check(not Shop.can_buy(b, b.shop_stock[ai]), "once per restock: a SOLD Ad Box is not buyable")
		Shop.roll(b) # a restock
		var fresh: Array = b.shop_stock.filter(func(sl: Dictionary) -> bool: return sl.get("ad", false))
		check(fresh.size() == 1 and not fresh[0].sold, "a restock refills the Ad Box")
	b.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL AD CHECKS OK")
	quit(1 if fails > 0 else 0)
