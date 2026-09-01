extends SceneTree
## issue 94: the Combo generator's invariants. The boards themselves are booted
## and bot-played by test_scenarios.gd like every other scenario — this suite
## checks the things that sweep cannot see: that the DIRECTED rule actually
## holds for every board, that no board exceeds the real Artefact cap, and that
## the producers the generator passed over are recorded rather than dropped
## silently.
## Run headless:  godot --headless --path game -s tests/test_combos.gd

const Combos := preload("res://data/scenarios_combos.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")
const Items := preload("res://data/items.gd")
const Armies := preload("res://scripts/armies.gd")
const Tuning := preload("res://scripts/tuning.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _init() -> void:
	var boards := Combos.all()
	check(not boards.is_empty(), "the generator produces boards (%d)" % boards.size())

	# Every declared hook name must be a real one. A typo would silently drop a
	# producer out of every pairing — the failure mode with no symptom.
	var known := {}
	for h in ArtefactHooks.HOOKS:
		known[h] = true
	var declared := 0
	for row in Items.ITEMS + Items.PIECE_BUFFS:
		for h in row.get("fires", []) + row.get("suppresses", []):
			declared += 1
			check(known.has(h), "%s declares a real hook: %s" % [row.key, h])
	for id in Armies.CATALOG:
		var a: Dictionary = Armies.CATALOG[id]
		for f in ["power_fires", "power_suppresses", "ability_fires", "ability_suppresses"]:
			for h in a.get(f, []):
				declared += 1
				check(known.has(h), "%s.%s declares a real hook: %s" % [id, f, h])
	check(declared > 0, "the hand-written declarations exist (%d hook names)" % declared)

	# THE DIRECTED RULE, asserted on the graph the generator emits rather than
	# on strings parsed back out of the board names. Every listener on a board
	# must genuinely listen on that board's hook, and the producer must
	# genuinely fire it — that is the whole difference between this and "two
	# effects that share a hook", which 39 on_wave_clear listeners would make
	# meaningless.
	var listeners := {}
	for key in ArtefactHooks.REGISTRY:
		for hook in ArtefactHooks.REGISTRY[key]:
			if not listeners.has(hook):
				listeners[hook] = []
			listeners[hook].append(key)
	var checked := 0
	for p in Combos.pairs():
		check(p.producer.fires.has(p.hook),
			"%s fires %s" % [p.producer.key, p.hook])
		for key in p.listeners:
			checked += 1
			check(listeners.get(p.hook, []).has(key),
				"%s listens on %s" % [key, p.hook])
		check(p.listeners.size() <= Tuning.ARTEFACT_CAP_BASE,
			"%s via %s: at most %d listeners (%d)"
				% [p.hook, p.producer.key, Tuning.ARTEFACT_CAP_BASE, p.listeners.size()])
	check(checked > 0, "the directed rule was actually exercised (%d pairs)" % checked)

	# and the boards those pairs turn into hold no more Artefacts than a real
	# run can (the producer takes a slot too, when it is itself an Artefact)
	for b in boards:
		check(b.cfg.artefacts.size() <= Tuning.ARTEFACT_CAP_BASE,
			"%s holds at most %d Artefacts (%d)"
				% [b.name, Tuning.ARTEFACT_CAP_BASE, b.cfg.artefacts.size()])
		check(b.name.begins_with("Combo: "),
			"%s lands in the Combo section" % b.name)

	# An Army board must name a REAL Army: cfg["army"] is read as
	# str(cfg.get("army", g.next_army)), so an unrecognised name sets an
	# unrecognised name and silently does nothing (issue 81 hit exactly this).
	for b in boards:
		if b.cfg.has("army"):
			check(Armies.CATALOG.has(b.cfg.army),
				"%s names a real Army (%s)" % [b.name, b.cfg.army])

	# No silent caps: one board per (hook, chunk) means most producers never get
	# a board of their own, and that has to be visible.
	check(not Combos.dropped().is_empty(),
		"passed-over producers are recorded, not silently cut (%d)" % Combos.dropped().size())

	print("---")
	if fails == 0:
		print("ALL COMBO CHECKS OK")
	quit(1 if fails > 0 else 0)
