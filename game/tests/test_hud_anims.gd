extends SceneTree
## NO-243 S3: the Header ticks (audit rows 31-34) and the end screens' staged
## reveal (rows 53/54). Each animation must land on exactly the state the old
## snap produced, animations off and autoplay must stay instant (no tween at
## all), and the end screens' buttons must work mid-reveal.
## Run headless:  godot --headless --path game -s tests/test_hud_anims.gd

const GameScript := preload("res://scripts/game.gd")

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
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	return game


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _running(hud, key: String) -> bool:
	var tw: Tween = hud._hud_tweens.get(key)
	return tw != null and tw.is_valid() and tw.is_running()


func _desat(game) -> float:
	return (game.modals._desat.material as ShaderMaterial).get_shader_parameter("amount")


func _labels(game) -> String:
	var text := ""
	for l in game.overlay.find_children("*", "Label", true, false):
		if not l.is_queued_for_deletion(): # the last screen's, freed at frame end
			text += (l as Label).text + "\n"
	return text


func _button(game, text: String) -> Button:
	for b in game.overlay.find_children("*", "Button", true, false):
		if (b as Button).text == text and not b.is_queued_for_deletion():
			return b
	return null


func _init() -> void:
	var game: Node2D = _boot({"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]], "wave": 3, "gold": 200})
	await process_frame
	var hud = game.hud
	game.animations_on = true
	hud.refresh()

	# --- row 31: a spend rolls Gold down and flashes the row red ---
	game.gold -= 40
	hud.refresh()
	check(_running(hud, "gold_spend"), "31: a Gold spend starts the red flash")
	check(hud.gold_label.self_modulate != Color.WHITE, "31: the Gold digits start red")
	await _wait(0.5)
	check(hud.gold_label.self_modulate == Color.WHITE and hud.gold_zeros_label.self_modulate == Color.WHITE,
		"31: the flash ends back at rest")
	check(hud.gold_label.text == str(game.gold), "31: the roll lands on the new Gold (%s)" % hud.gold_label.text)

	# --- rows 32/33: Wave flip, Turn tick, the row glides to the same centre ---
	var row_before: float = hud.turn_wave_row.position.x
	game.turns_since_wave += 1
	hud.refresh()
	check(_running(hud, "turn") and hud.turn_label.scale.y < 1.0, "33: a Turn tick flips the Turn counter")
	game.wave += 1
	hud.refresh()
	check(_running(hud, "wave") and hud.wave_label.scale.y < 1.0, "32: a Wave advance flips the Wave counter")
	await _wait(0.35)
	check(hud.wave_label.scale == Vector2.ONE and hud.turn_label.scale == Vector2.ONE
		and hud.wave_label.self_modulate == Color.WHITE and hud.turn_label.self_modulate == Color.WHITE,
		"32/33: both counters end at rest")
	check(hud.wave_label.text == "⚑ %d/50" % game.wave, "32: the Wave text is the new Wave")
	var row_animated: float = hud.turn_wave_row.position.x
	game.animations_on = false
	hud.refresh()
	check(is_equal_approx(hud.turn_wave_row.position.x, row_animated),
		"33: the re-centred row ends where the snap puts it (%s, before %s)" % [row_animated, row_before])
	game.animations_on = true

	# --- row 34: an Action drains the count, the last one shakes PASS ---
	var face: Control = hud.pass_count.get_parent()
	game.actions_left = 2
	hud.refresh()
	game.actions_left = 1
	hud.refresh()
	check(_running(hud, "pass") and hud.pass_count.scale.y < 1.0, "34: spending an Action drains the count")
	await _wait(0.3)
	check(hud.pass_count.scale == Vector2.ONE and hud.pass_count.self_modulate == Color.WHITE,
		"34: the count ends at rest")
	check(hud.pass_count.text == "1/%d" % game.actions_max, "34: the count reads the new total")
	game.actions_left = 0
	hud.refresh()
	check(_running(hud, "pass"), "34: the last Action shakes PASS")
	await process_frame
	await process_frame
	check(face.position.x != 0.0, "34: ...the PASS face is off centre mid-shake")
	await _wait(0.35)
	check(face.position.x == 0.0, "34: ...and settles back at 0")
	game.actions_left = 2
	hud.refresh()
	check(not _running(hud, "pass"), "34: a new turn's refill does not drain")

	# --- off and autoplay: no tween at all, the new values at once ---
	for mode in ["off", "autoplay"]:
		game.animations_on = mode != "off"
		game.autoplay = mode == "autoplay"
		hud._hud_tweens.clear()
		game.gold -= 10
		game.turns_since_wave += 1
		game.wave += 1
		game.actions_left = 1
		hud.refresh()
		check(hud._hud_tweens.is_empty(), "%s: no Header tween is created" % mode)
		check(hud.gold_label.text == str(game.gold) and hud.wave_label.text == "⚑ %d/50" % game.wave
			and hud.turn_label.scale == Vector2.ONE and hud.pass_count.scale == Vector2.ONE,
			"%s: every counter shows its new value at rest, instantly" % mode)
	game.autoplay = false
	game.animations_on = true

	# --- row 53: the game-over reveal ---
	game.score = 1234
	game.modals.show_overlay(false, "Clock out")
	var title: Label = game.overlay.find_children("*", "Label", true, false)[0] # nothing shown before
	check(game.modals.reveal != null and game.modals.reveal.is_running(), "53: the game-over screen reveals in stages")
	check(_desat(game) == 0.0 and title.modulate.a == 0.0, "53: it starts on the run as it stands, title hidden")
	check(_labels(game).contains("Score 0 ·"), "53: the Score starts from 0")
	var restart := _button(game, "Restart")
	check(restart != null and restart.is_visible_in_tree() and not restart.disabled
		and restart.mouse_filter == Control.MOUSE_FILTER_STOP and game.overlay.mouse_filter == Control.MOUSE_FILTER_STOP,
		"53: Restart is live mid-reveal (only its alpha animates; a real press reloads the scene, so the windowed probes click it)")
	await _wait(0.3)
	var d: float = _desat(game)
	check(d > 0.0 and d < 1.0, "53: the board is greying over 0.6 s (%s at 0.3 s)" % d)
	await game.modals.reveal.finished
	check(_desat(game) == 1.0, "53: the board ends grey under the dim")
	check(title.modulate.a == 1.0 and title.scale == Vector2.ONE, "53: the title has landed")
	check(_labels(game).contains("Score 1234 ·"), "53: the Score counted up to the total")
	check(restart.modulate.a == 1.0, "53: the buttons have faded in")

	# --- row 54: the win screen waits out the King's shatter, then bursts gold ---
	game.modals.show_win_screen()
	check(game.modals.reveal.is_running(), "54: the win screen reveals in stages")
	var cont := _button(game, "Continue")
	var conts := [0]
	game.modals.win_continue_pressed.connect(func() -> void: conts[0] += 1)
	check(cont != null and cont.mouse_filter == Control.MOUSE_FILTER_STOP, "54: Continue is live mid-reveal")
	cont.pressed.emit()
	check(conts[0] == 1, "54: ...and pressing it continues")
	await _wait(0.25)
	check(_desat(game) == 0.0, "54: nothing greys until the King's shatter (0.4 s) has played")
	var burst := false
	for c in game.overlay.get_children():
		if c.has_meta("t"):
			burst = true
	check(burst, "54: a gold burst is queued")
	await game.modals.reveal.finished
	check(_desat(game) == 1.0 and _labels(game).contains("Score 1234 ·"), "54: the win screen ends fully revealed")

	# --- off and autoplay: the end screen is complete on the first frame ---
	for mode in ["off", "autoplay"]:
		game.animations_on = mode != "off"
		game.autoplay = mode == "autoplay"
		game.modals.show_overlay(false, "Clock out")
		var t: Label = null
		for l in game.overlay.find_children("*", "Label", true, false):
			if t == null and not l.is_queued_for_deletion():
				t = l
		check(game.modals.reveal == null and _desat(game) == 1.0 and t.modulate.a == 1.0
			and _labels(game).contains("Score 1234 ·"), "%s: the game-over screen is complete at once" % mode)
		game.modals.show_win_screen()
		check(game.modals.reveal == null and _desat(game) == 1.0, "%s: so is the win screen" % mode)
	game.autoplay = false

	game.queue_free()
	await process_frame
	print("---")
	if fails == 0:
		print("ALL HUD ANIM CHECKS OK")
	quit(1 if fails > 0 else 0)
