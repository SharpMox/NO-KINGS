extends Node
## issue 87 / T4 skeleton: the iOS twin of play_games_bridge.gd.
##
## For now it does exactly one job — THE PROBE. This week produced three
## artifact-vs-documentation lies (the Android plugin's phantom silent check,
## and two mislabelled binaries), so before any backend code is written against
## the gamecenter/icloud plugins, this dumps what the compiled singletons
## actually expose at runtime. T4 grows the real bridge from what it prints,
## not from what the README promised.

func _ready() -> void:
	if OS.get_name() != "iOS":
		return
	# print() reaches neither the sim pty nor os_log — only the error stream
	# does, and a file is the channel nothing can swallow. Both are used.
	var lines := PackedStringArray()
	for n in ["GameCenter", "ICloud", "iCloud"]:
		if not Engine.has_singleton(n):
			lines.append("singleton ABSENT: " + n)
			continue
		var s: Object = Engine.get_singleton(n)
		var own := PackedStringArray()
		for m in s.get_method_list():
			if not ClassDB.class_has_method("Object", m.name):
				own.append(m.name)
		lines.append("singleton %s exposes: %s" % [n, ", ".join(own)])
	var f := FileAccess.open("user://ios_probe.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
	printerr("[ios-probe] ", " | ".join(lines))
