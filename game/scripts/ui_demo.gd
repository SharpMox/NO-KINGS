## Debug: `--ui-demo <flow>` plays one selling flow on the "Capture: selling
## sandbox" scenario, one step every PAUSE_S so each screen is readable, then
## quits. Record it with Movie Maker (tools/capture.md). Same idea as the
## NO-243 `--anim-demo` driver (branch probe/no-243-demo).
##
## Every step goes through the path a real tap takes: the HUD signal a long
## press emits (stack/item/artefact_preview_requested), then the modal's own
## Button, pressed through its `pressed` signal, which is what a tap on it
## emits. Nothing calls _sell/_convert_captured directly, so the video shows
## the real preview and the real confirm. A step whose button is missing or
## disabled prints UI-DEMO FAIL and quits 1 rather than recording a video of
## nothing.
##
## Pure module on `g`, like the other scripts here. tests/test_capture_paths.gd
## runs every flow headless with a zero pause.

const Box := preload("res://scripts/box.gd")

const SCENARIO := "Capture: selling sandbox"
const PAUSE_S := 0.8
const FLOWS := ["sell-stock", "convert", "sell-item", "sell-artefact", "box-sell"]


## Plays `flow`; true when every step found its button. `quit` false (tests)
## leaves the tree running afterwards.
static func run(g, flow: String, pause := PAUSE_S, quit := true) -> bool:
	var ok: bool = await _flow(g, flow, pause)
	if not ok:
		printerr("UI-DEMO FAIL: %s" % flow)
	await _wait(g, pause * 2.0) # hold the end state
	if quit:
		g.get_tree().quit(0 if ok else 1)
	return ok


static func _flow(g, flow: String, pause: float) -> bool:
	await _wait(g, pause) # the board first, untouched
	match flow:
		"sell-stock":
			return await _sell_stack(g, g.stock[0], pause)
		"convert": # Captured -> Convert, then sell the converted piece from Stock
			var entry = g.captured[0]
			_open_drawer(g, "stock")
			await _wait(g, pause)
			g.hud.stack_preview_requested.emit(_id(entry), true, entry)
			await _wait(g, pause)
			if not await _press(g, g.modals.preview_panel, "convert", pause):
				return false
			return await _sell_stack(g, entry, pause)
		"sell-item":
			_open_drawer(g, "inventory")
			await _wait(g, pause)
			g.hud.item_preview_requested.emit(0)
			return await _preview_sell(g, pause)
		"sell-artefact":
			_open_drawer(g, "inventory")
			await _wait(g, pause)
			g.hud.artefact_preview_requested.emit(str(g.artefacts[0].key))
			return await _preview_sell(g, pause)
		"box-sell": # an Item Box on a full inventory: Sell row, confirm, then pick
			var slot := {"kind": "box", "key": "item", "size": "small", "sold": false,
				"contents": Box.roll_options(g, "item", "small")}
			g._open_box_pick(slot)
			await _wait(g, pause)
			if not await _press(g, g.modals.box_panel, "sell-row", pause):
				return false
			if not await _confirm(g, pause):
				return false
			await _wait(g, pause)
			if not await _press(g, g.modals.box_panel, "box-tile", pause):
				return false
			await _wait(g, pause)
			return await _press(g, g.modals.box_panel, "box-pick", pause)
	printerr("UI-DEMO: unknown flow %s (one of %s)" % [flow, ", ".join(FLOWS)])
	return false


## Stock drawer, long-press the stack, Sell, confirm.
static func _sell_stack(g, entry, pause: float) -> bool:
	_open_drawer(g, "stock")
	await _wait(g, pause)
	g.hud.stack_preview_requested.emit(_id(entry), false, entry)
	return await _preview_sell(g, pause)


## From an open preview: its Sell button, then the confirm.
static func _preview_sell(g, pause: float) -> bool:
	await _wait(g, pause)
	if not await _press(g, g.modals.preview_panel, "sell", pause):
		return false
	return await _confirm(g, pause)


## The shared choice modal's own Sell (_confirm_sell's offer).
static func _confirm(g, pause: float) -> bool:
	await _wait(g, pause)
	if g.modals.buff_panel == null:
		printerr("UI-DEMO: no confirm modal")
		return false
	return await _press(g, g.modals.buff_panel, "confirm", pause)


## Focus the first live, enabled Button under `root` that is `want` (the focus
## ring shows the viewer what is about to be tapped), then press it.
static func _press(g, root: Node, want: String, pause: float) -> bool:
	for b in root.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn.is_queued_for_deletion() or not btn.is_visible_in_tree() \
				or btn.disabled or not _is(btn, want):
			continue
		btn.grab_focus()
		await _wait(g, pause * 0.5)
		btn.pressed.emit()
		return true
	var seen := PackedStringArray()
	for b in root.find_children("*", "Button", true, false):
		seen.append("%s%s" % [(b as Button).text, "" if (b as Button).is_visible_in_tree() else " (hidden)"])
	printerr("UI-DEMO: no live %s button under %s; buttons: %s; items %d, box_open %s" \
		% [want, root.name, ", ".join(seen), g.items.size(), g.box_open])
	return false


static func _is(btn: Button, want: String) -> bool:
	match want:
		"convert": # preview: "Convert -$N"
			return btn.text.begins_with("Convert")
		"sell": # preview: "Sell +$N"
			return btn.text.begins_with("Sell")
		"confirm": # choice modal
			return btn.text == "Sell"
		"sell-row": # Item Box, full inventory: "Sell Blitz +$N"
			return btn.text.begins_with("Sell ") and not btn.text.begins_with("Sell +")
		"box-tile":
			return btn.has_meta("box_index")
		"box-pick":
			return btn.has_meta("box_pick")
	return false


## Open a drawer; g._set_drawer toggles, so never on one already open.
static func _open_drawer(g, which: String) -> void:
	if g.hud.drawer_open != which:
		g._set_drawer(which)


static func _id(entry) -> String: # ADR-0002: a bare id or a stateful Dictionary
	return entry if entry is String else str(entry.id)


static func _wait(g, s: float) -> void:
	await g.get_tree().create_timer(s).timeout
