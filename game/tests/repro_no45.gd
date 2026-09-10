extends SceneTree
## REPRODUCTION, NOT A SUITE TEST. This is EXPECTED TO FAIL — it demonstrates
## NO-45, and it is deliberately not wired into tests/run_all.sh, because a
## suite test that is meant to be red teaches everyone to ignore red.
##
##   printf '[input_devices]\npointing/emulate_touch_from_mouse=true\n' > game/override.cfg
##   godot --path game -s tests/repro_no45.gd ; rm game/override.cfg
##
## WHAT IT SHOWS (measured 2026-09-10): with sixteen artefacts held, the
## inventory drawer has ~314px of scrollable range, and a touch drag that STARTS
## ON an artefact row moves the scroll offset by ZERO. The same run scrolls the
## TEST-menu list fine through the identical input path, which is the control —
## so this is not the harness failing to deliver a drag.
##
## WHY, from source: hud.gd sets every artefact row to MOUSE_FILTER_STOP ("so
## the tooltip shows") inside the drawer's ScrollContainer.
## Viewport::_gui_call_input marks a pointer press handled at a STOP control and
## stops climbing, so the press never reaches the container and its touch drag
## never starts (scroll_container.cpp: drag_touching is set in the press branch).
## Exactly the mechanism #379 fixed for the TEST menu.
##
## WHY IT IS NOT FIXED HERE: #379's remedy is rows -> MOUSE_FILTER_PASS plus a
## scroll_deadzone, and PASS gives up the tooltip that STOP was added for. On a
## phone there is no tooltip anyway; on desktop that is a real loss. Trading a
## desktop affordance for a touch one is a product call, not a harness one.
##
## Max's device test on 2026-09-10 reported "the drawer scrolls fine", which was
## a FALSE NEGATIVE: the scenario he used ("Items: full inventory") holds no
## artefacts at all, so the STOP rows this is about were not on screen. That is
## why the sixteen-artefact scenario exists.

const Drive := preload("res://scripts/drive.gd")
const GameScript := preload("res://scripts/game.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("ok: ", label)
	else:
		fails += 1
		print("FAIL: ", label)


func _drive(d: Node, dir: String, seq: int, cmds: Array) -> PackedStringArray:
	var f := FileAccess.open(dir.path_join("cmd.txt"), FileAccess.WRITE)
	f.store_line("seq %d" % seq)
	for c in cmds:
		f.store_line(c)
	f = null
	await d._poll()
	return FileAccess.get_file_as_string(dir.path_join("ack.txt")).split("\n", false)


func _init() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("WATCHDOG: repro still running after 60s — force quit")
		quit(1))
	if not DisplayServer.is_touchscreen_available():
		print("REFUSING: touch emulation is off — this repro needs game/override.cfg (see header)")
		quit(1)
		return

	var dd := "user://t_repro45"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dd))
	var drv := Drive.new()
	drv.dir = dd
	root.add_child(drv)

	GameScript.next_config = {
		"board": [["queen", 0, 2, 2], ["rook", 1, 7, 10]],
		"artefacts": ["27-club-punch-card", "tinfoil-hat",
			"area-51-parking-permit", "fort-knox-iou",
			"fema-summer-camp-flyer", "zurich-gnome-figurine",
			"nero-s-marshmallow-stick", "pre-scratched-lottery-ticket",
			"tungsten-filled-gold-bar", "crop-circle-plank",
			"mar-a-lago-toilet-papers", "suspiciously-large-femur",
			"daylight-savings-jar", "phantom-punch-glove",
			"naruto-run-manual", "social-credit-report-card"],
		"wave": 3, "gold": 200, "seed": 1}
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game._set_drawer("inventory")
	await process_frame
	await process_frame

	var isc: ScrollContainer = null
	for c in (game.hud.drawers["inventory"] as Control).get_children():
		if c is ScrollContainer:
			isc = c
	check(isc != null, "the inventory drawer has a ScrollContainer")
	if isc == null:
		quit(1)
		return
	var range_px: float = isc.get_v_scroll_bar().max_value - isc.size.y
	check(range_px > 100.0, "the drawer has real scroll range (%dpx)" % int(range_px))

	var before_v: int = isc.scroll_vertical
	var ack := await _drive(drv, dd, 1, ["drag_text Tinfoil Hat 0 -140"])
	check(ack.size() > 1 and ack[1].begins_with("ok drag_text"),
		"the drag started ON an artefact row (%s)" % (ack[1] if ack.size() > 1 else "-"))
	await process_frame
	var after_v: int = isc.scroll_vertical
	check(after_v != before_v,
		"a drag starting on an artefact row scrolls the drawer (%d -> %d)" % [before_v, after_v])

	for f in ["cmd.txt", "ack.txt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dd.path_join(f)))
	print("---")
	if fails == 0:
		print("NO-45 DID NOT REPRODUCE — the drawer scrolled. If this happens after a fix, delete this file.")
	else:
		print("NO-45 REPRODUCED (%d failing check(s)) — expected until it is fixed." % fails)
	# Exit 0 either way: this script's JOB is to show the bug, so reproducing it
	# is not a script failure, and a non-zero exit would invite someone to wire
	# it into run_all.sh and then "fix" the red by deleting the case.
	quit(0)
