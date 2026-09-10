extends SceneTree
## The host-driven input harness (scripts/drive.gd).
##
## Two things this pins that matter more than the vocabulary working:
##
## 1. IT DOES NOT EXIST WITHOUT ITS FLAG. Not "is idle" — does not exist. An
##    inactive driver is still a driver, and a harness that can synthesise input
##    must be unreachable in a normal run.
## 2. EVERY FAILURE REPORTS A REASON. A driver whose failures look like
##    successes is worse than no driver: the host would tap nothing and read
##    silence as success. Same family as this repo's "assert the observable
##    consequence" — the harness has to be falsifiable too.
##
## Run headless: godot --headless --path game -s tests/test_drive.gd

const Drive := preload("res://scripts/drive.gd")
const Intro := preload("res://scripts/intro.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("ok: ", label)
	else:
		fails += 1
		print("FAIL: ", label)


func _dir() -> String:
	return "user://t_drive"


## Write a command batch and run one poll cycle, returning the ack lines.
func _send(d: Drive, seq: int, cmds: Array) -> PackedStringArray:
	var f := FileAccess.open(_dir().path_join("cmd.txt"), FileAccess.WRITE)
	f.store_line("seq %d" % seq)
	for c in cmds:
		f.store_line(c)
	f = null
	await d._poll()
	var raw := FileAccess.get_file_as_string(_dir().path_join("ack.txt"))
	return raw.split("\n", false)


func _init() -> void:
	# --- 1. the flag parser, including the ways it must refuse ---------------
	check(Drive.drive_dir(PackedStringArray(["--drive", "user://x"])) == "user://x",
		"drive_dir reads the directory after the flag")
	check(Drive.drive_dir(PackedStringArray([])) == "",
		"no flag: no directory")
	check(Drive.drive_dir(PackedStringArray(["--autoplay", "--scenario", "3"])) == "",
		"other bypasses do not switch the driver on")
	check(Drive.drive_dir(PackedStringArray(["--drive"])) == "",
		"a flag with no value is refused rather than read past the end")

	# --- 2. UNREACHABLE WITHOUT THE FLAG. The load-bearing one. -------------
	# Asserts the node does not EXIST, via the same entry point the real boot
	# uses, rather than trusting that a created driver would sit still.
	check(Intro._start_driver(PackedStringArray([]), root) == null,
		"no --drive: _start_driver creates NOTHING")
	check(Intro._start_driver(PackedStringArray(["--autoplay"]), root) == null,
		"and --autoplay alone does not conjure one either")
	await process_frame
	check(root.get_node_or_null("Drive") == null,
		"so the scene tree has no Drive node at all — not an idle one, none")

	# ...and the control: WITH the flag it does exist, so the checks above are
	# not passing because _start_driver is simply broken.
	var made: Node = Intro._start_driver(PackedStringArray(["--drive", _dir()]), root)
	check(made != null, "(control) WITH --drive, _start_driver does create one")
	await process_frame
	await process_frame
	check(root.get_node_or_null("Drive") != null,
		"(control) and it reaches the scene tree root, so it outlives a scene change")
	made.queue_free()
	await process_frame

	# --- 3. the vocabulary, driven through the real cmd/ack protocol --------
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir()))
	var d := Drive.new()
	d.dir = _dir()
	root.add_child(d)
	await process_frame

	# something with known text to aim at
	var btn := Button.new()
	btn.text = "DRIVE TARGET"
	btn.position = Vector2(20, 20)
	btn.size = Vector2(160, 40)
	root.add_child(btn)
	await process_frame
	await process_frame

	# FAILURES FIRST, because they are the assertions that matter most
	var ack := await _send(d, 1, ["tap_text NO SUCH CONTROL"])
	check(ack.size() >= 2 and ack[0] == "seq 1", "the ack echoes the sequence number")
	check(ack.size() >= 2 and ack[1].begins_with("fail tap_text"),
		"tap_text on a missing control FAILS rather than silently doing nothing")
	check(ack.size() >= 2 and "NO SUCH CONTROL" in ack[1],
		"...and the reason NAMES what it looked for (%s)" % (ack[1] if ack.size() > 1 else "-"))

	ack = await _send(d, 2, ["wait_text NEVER APPEARS 300"])
	check(ack.size() >= 2 and ack[1].begins_with("fail wait_text") and "timed out" in ack[1],
		"wait_text says it TIMED OUT rather than just returning (%s)" % (ack[1] if ack.size() > 1 else "-"))

	ack = await _send(d, 3, ["frobnicate 1 2"])
	check(ack.size() >= 2 and ack[1] == "fail frobnicate unknown verb",
		"an unknown verb is reported, not ignored")

	ack = await _send(d, 4, ["tap 5"])
	check(ack.size() >= 2 and ack[1].begins_with("fail tap") and "needs" in ack[1],
		"a malformed command says what it needed (%s)" % (ack[1] if ack.size() > 1 else "-"))

	# then the successes. NOTE WHAT IS *NOT* ASSERTED HERE: that the button
	# actually fired. Godot headless DROPS GUI PICKING (CLAUDE.md, re-verified
	# on 4.7), so a synthesised tap reports `ok` while pressing nothing — the
	# ack is honest about having delivered the event, and the event goes
	# nowhere. Asserting `pressed` here fails for a reason that has nothing to
	# do with the driver. THE OBSERVABLE CONSEQUENCE IS ASSERTED IN THE WINDOWED
	# PROBE (tests/test_touch_scroll.gd), which is where every other
	# does-the-click-land question in this repo lives. Do not re-add it here.
	ack = await _send(d, 5, ["tap_text DRIVE TARGET"])
	check(ack.size() >= 2 and ack[1].begins_with("ok tap_text"),
		"tap_text finds a real control and reports ok (landing is the windowed probe's job)")
	check(ack.size() >= 2 and "at " in ack[1],
		"...and reports WHERE it tapped, so a miss is diagnosable (%s)"
			% (ack[1] if ack.size() > 1 else "-"))

	ack = await _send(d, 6, ["wait_text DRIVE TARGET 2000"])
	check(ack.size() >= 2 and ack[1].begins_with("ok wait_text"),
		"wait_text returns ok for text already present")

	ack = await _send(d, 7, ["probe"])
	check(ack.size() >= 2 and ack[1].begins_with("ok probe"), "probe reports ok")
	check(ack.size() >= 2 and "viewport=" in ack[1] and "DRIVE TARGET" in ack[1],
		"...and its dump carries the viewport size and the on-screen text")

	# `shot` cannot work here and says so: RenderingServer.frame_post_draw never
	# resolves under --headless, so capturing has to REFUSE rather than await a
	# frame that will not come. The windowed probe covers the working path.
	ack = await _send(d, 8, ["shot t_drive.png"])
	check(ack.size() >= 2 and ack[1].begins_with("fail shot") and "headless" in ack[1],
		"shot refuses under --headless with a reason, rather than hanging (%s)"
			% (ack[1] if ack.size() > 1 else "-"))

	# a batch: several commands, one result line each, in order
	ack = await _send(d, 9, ["probe", "tap_text NOPE", "wait_text DRIVE TARGET 500"])
	check(ack.size() == 4, "a 3-command batch produces 3 result lines (%d)" % (ack.size() - 1))
	check(ack.size() == 4 and ack[1].begins_with("ok probe")
			and ack[2].begins_with("fail tap_text") and ack[3].begins_with("ok wait_text"),
		"...in order, and one failure does not abort the ones after it")

	# a stale sequence number must be ignored, or a re-read of an old file
	# would replay input the host already consumed
	var before := FileAccess.get_file_as_string(_dir().path_join("ack.txt"))
	await _send(d, 9, ["probe"])
	check(FileAccess.get_file_as_string(_dir().path_join("ack.txt")) == before,
		"a repeated sequence number is ignored — no replay of consumed commands")

	d.queue_free()
	btn.queue_free()
	await process_frame
	# tidy: this directory is the harness's, and a stale cmd.txt would be read
	# by the next run
	for f in ["cmd.txt", "ack.txt", "t_drive.png"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_dir().path_join(f)))

	print("---")
	print("ALL DRIVE CHECKS OK" if fails == 0 else "DRIVE FAILURES: %d" % fails)
	quit(1 if fails > 0 else 0)
