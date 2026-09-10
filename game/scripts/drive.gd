extends Node
## HOST-DRIVEN INPUT, for questions only a real device can answer.
##
## The problem it solves: on a phone there is no `adb input tap` equivalent we
## can rely on across both platforms, and on iOS there is none at all short of
## installing and signing a second app (WebDriverAgent). So the driver lives
## HERE, in the game, where it needs no extra signing, survives Godot
## regenerating the Xcode project on every export, and is one code path on both
## platforms. Recipe for the host side: docs/ios-device-automation.md.
##
## IT IS A TEST HARNESS, NOT A FEATURE. The vocabulary below is deliberately
## eight verbs with no composition, no variables and no control flow — enough to
## reach a screen and report what is on it. Resist growing it into a scripting
## language; if a question needs branching, the HOST branches, which is the whole
## point of an interactive loop rather than a launch-time batch.
##
## INERT WITHOUT ITS FLAG, like every other bypass here (`--autoplay`,
## `--scenario`, `--screenshot`). No `--drive`, no node: intro.gd only
## instantiates this when the flag is present, so in a normal run the class is
## never even loaded. tests/test_drive.gd asserts the node does not EXIST rather
## than that it is idle — an inactive driver is still a driver.
##
## Protocol, both directions through the app's own `user://`-style directory,
## which the host can read AND write on a device (`adb push`/`pull`, or
## `devicectl device copy to`/`from` — both measured 2026-09-10):
##
##   host writes  <dir>/cmd.txt   `seq <n>` then one command per line
##   app  writes  <dir>/ack.txt   `seq <n>` then one result line per command
##
## The sequence number is what makes a rewrite detectable — mtime is not
## trustworthy across a `copy to`, which preserves the source's timestamp.
##
## EVERY COMMAND REPORTS ok OR fail WITH A REASON. A driver whose failures are
## indistinguishable from successes is worse than no driver: `tap_text "Play"`
## with no such control on screen must say so, naming what it looked for, rather
## than silently doing nothing. That is the same rule as this repo's "assert the
## observable consequence" — a harness has to be falsifiable too.

const POLL_SECONDS := 0.25

## Bounds every wait. A host that asked for something that never arrives gets a
## `fail … timed out` line rather than a driver that stops answering.
const DEFAULT_WAIT_MS := 5000

var dir := ""

var _seq := -1
var _busy := false
var _results: Array[String] = []


## The directory after `--drive`, or "" when the flag is absent or has no value.
## Static so intro.gd can ask without instantiating anything.
static func drive_dir(args: PackedStringArray) -> String:
	var at := args.find("--drive")
	if at < 0 or at + 1 >= args.size():
		return ""
	return args[at + 1]


func _ready() -> void:
	if dir == "":
		push_error("drive: no directory; the node should not have been created")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var t := Timer.new()
	t.wait_time = POLL_SECONDS
	t.timeout.connect(_poll)
	add_child(t)
	t.start()
	printerr("[drive] listening in ", dir) # printerr: print() reaches no iOS log


func _poll() -> void:
	if _busy:
		return # a batch mid-flight; the host waits for its ack
	var path := dir.path_join("cmd.txt")
	if not FileAccess.file_exists(path):
		return
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	if lines.is_empty():
		return
	var head := lines[0].strip_edges().split(" ", false)
	if head.size() < 2 or head[0] != "seq":
		return # not a command file yet, or a partial write: ignore, do not guess
	var seq := int(head[1])
	if seq <= _seq:
		return
	_seq = seq
	_busy = true
	_results.clear()
	for i in range(1, lines.size()):
		var line := lines[i].strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		await _run(line)
	_write_ack()
	_busy = false


func _write_ack() -> void:
	var f := FileAccess.open(dir.path_join("ack.txt"), FileAccess.WRITE)
	if f == null:
		push_error("drive: cannot write ack.txt in " + dir)
		return
	f.store_line("seq %d" % _seq)
	for r in _results:
		f.store_line(r)


func _ok(verb: String, detail: String = "") -> void:
	_results.append("ok %s%s" % [verb, "" if detail == "" else " " + detail])


func _fail(verb: String, reason: String) -> void:
	_results.append("fail %s %s" % [verb, reason])


## --- the vocabulary ---------------------------------------------------------


func _run(line: String) -> void:
	var a := line.split(" ", false)
	var verb := a[0]
	match verb:
		"tap":
			if a.size() < 3:
				return _fail(verb, "needs <x> <y>")
			_touch(Vector2(float(a[1]), float(a[2])), true)
			await _frames(2)
			_touch(Vector2(float(a[1]), float(a[2])), false)
			await _frames(2)
			_ok(verb, "%s,%s" % [a[1], a[2]])
		"tap_text":
			var s := _rest(line, verb)
			var c := _find_text(s)
			if c == null:
				return _fail(verb, "no visible control with text '%s'" % s)
			var at := c.get_global_rect().get_center()
			_touch(at, true)
			await _frames(2)
			_touch(at, false)
			await _frames(2)
			_ok(verb, "'%s' at %d,%d" % [s, at.x, at.y])
		"drag":
			if a.size() < 5:
				return _fail(verb, "needs <x1> <y1> <x2> <y2>")
			await _drag(Vector2(float(a[1]), float(a[2])), Vector2(float(a[3]), float(a[4])))
			_ok(verb)
		"drag_text":
			var parts := _rest(line, verb).rsplit(" ", false, 2)
			if parts.size() < 3:
				return _fail(verb, "needs <text> <dx> <dy>")
			var c := _find_text(parts[0])
			if c == null:
				return _fail(verb, "no visible control with text '%s'" % parts[0])
			var from := c.get_global_rect().get_center()
			var to := from + Vector2(float(parts[1]), float(parts[2]))
			await _drag(from, to)
			_ok(verb, "'%s' %d,%d -> %d,%d" % [parts[0], from.x, from.y, to.x, to.y])
		"wait_text":
			var s := _rest(line, verb)
			var ms := DEFAULT_WAIT_MS
			var sp := s.rsplit(" ", false, 1)
			if sp.size() == 2 and sp[1].is_valid_int():
				s = sp[0]
				ms = int(sp[1])
			if await _until(func() -> bool: return _find_text(s) != null, ms):
				_ok(verb, "'%s'" % s)
			else:
				_fail(verb, "timed out after %dms waiting for '%s'" % [ms, s])
		"wait_settled":
			var ms := int(a[1]) if a.size() > 1 else DEFAULT_WAIT_MS
			if await _until_settled(ms):
				_ok(verb)
			else:
				_fail(verb, "timed out after %dms, the screen kept changing" % ms)
		"shot":
			var name := _rest(line, verb)
			if name == "":
				return _fail(verb, "needs a filename")
			if _headless():
				return _fail(verb, "no renderer: --headless draws no frame to capture")
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var err := img.save_png(dir.path_join(name))
			if err == OK:
				_ok(verb, "%s %dx%d" % [name, img.get_width(), img.get_height()])
			else:
				_fail(verb, "save_png failed (%d) for %s" % [err, name])
		"probe":
			_ok(verb, _probe())
		_:
			_fail(verb, "unknown verb")


## What is on screen, so the host can LOOK rather than infer from pixels. Every
## visible Control carrying text, with its rect — which is also what makes a
## missed tap_text diagnosable, and how a label wider than the viewport becomes
## a number instead of a judgement about a screenshot.
func _probe() -> String:
	var vp := get_viewport().get_visible_rect().size
	var out := PackedStringArray()
	out.append("viewport=%dx%d" % [vp.x, vp.y])
	for c in _controls():
		var t := _text_of(c)
		if t == "":
			continue
		var r := c.get_global_rect()
		out.append("%s|%d,%d,%dx%d|%s" % [c.get_class(), r.position.x, r.position.y,
			r.size.x, r.size.y, t.replace("\n", "\\n")])
	return " ;; ".join(out)


## --- helpers ----------------------------------------------------------------


## The line after its verb, unsplit — so text arguments may contain spaces
## without quoting rules the host would have to get right.
func _rest(line: String, verb: String) -> String:
	return line.substr(verb.length()).strip_edges()


func _text_of(c: Control) -> String:
	# Button, Label and LineEdit all expose `text`; ask rather than type-switch,
	# so a control type nobody thought of still reports itself.
	if not (c is Button or c is Label or c is LineEdit or c is RichTextLabel):
		return ""
	var v: Variant = c.get("text")
	return str(v) if v != null else ""


func _controls() -> Array[Control]:
	var out: Array[Control] = []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control and (n as Control).is_visible_in_tree():
			out.append(n)
		for ch in n.get_children():
			stack.append(ch)
	return out


## First visible control whose text matches exactly, else one that contains it.
## Exact first, because "Stock 0" and "Stock 0 — captured and extracted pieces
## land here" both exist and a contains-match would pick whichever came first.
func _find_text(s: String) -> Control:
	if s == "":
		return null
	var loose: Control = null
	for c in _controls():
		var t := _text_of(c)
		if t == "":
			continue
		if t == s:
			return c
		if loose == null and t.contains(s):
			loose = c
	return loose


func _touch(at: Vector2, pressed: bool) -> void:
	# ScreenTouch, not a mouse event: the questions this exists for are about
	# TOUCH handling (NO-45's ScrollContainer drag), and Godot converts touch to
	# mouse for Controls anyway, so this is the strictly more faithful input.
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = at
	e.pressed = pressed
	Input.parse_input_event(e)


## A press, N drag steps, a release. Stepped rather than teleported because a
## ScrollContainer's touch drag only starts once it has seen motion, and one
## giant jump is not what a finger does.
func _drag(from: Vector2, to: Vector2, steps: int = 8) -> void:
	_touch(from, true)
	await _frames(2)
	var prev := from
	for i in range(1, steps + 1):
		var at := from.lerp(to, float(i) / float(steps))
		var e := InputEventScreenDrag.new()
		e.index = 0
		e.position = at
		e.relative = at - prev
		Input.parse_input_event(e)
		prev = at
		await _frames(1)
	_touch(to, false)
	await _frames(2)


## `await RenderingServer.frame_post_draw` NEVER RESOLVES under --headless, so
## anything that captures or compares the framebuffer has to refuse rather than
## await — a hung driver reports nothing at all, which is the one failure mode
## worse than a reported one. Found the hard way: the first version of this file
## hung the headless test for 600s and lost its buffered output on the kill.
func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


## Poll a condition to a deadline. NOT a sleep: this repo's standing rule is
## that a fixed wait either wastes time or misses the thing, so every wait here
## is a condition with a bound.
func _until(cond: Callable, ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


## Settled = two consecutive captures with an identical hash. Cheaper and more
## honest than a fixed delay after a tap: it waits for the screen to stop
## moving rather than guessing how long that takes.
func _until_settled(ms: int) -> bool:
	if _headless():
		return false # nothing is drawn, so nothing can settle; the caller reports it
	var deadline := Time.get_ticks_msec() + ms
	var last := ""
	while Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
		var h := get_viewport().get_texture().get_image().get_data().hex_encode().md5_text()
		if h == last:
			return true
		last = h
		await _frames(2)
	return false
