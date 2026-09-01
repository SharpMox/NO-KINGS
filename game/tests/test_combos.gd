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

	# THE DIRECTED RULE. Every Artefact on a board must actually listen on the
	# hook the board is named for — that is the whole difference between this
	# and "two effects that share a hook", and 39 on_wave_clear listeners are
	# what it is protecting against.
	var listeners := {}
	for key in ArtefactHooks.REGISTRY:
		for hook in ArtefactHooks.REGISTRY[key]:
			if not listeners.has(hook):
				listeners[hook] = []
			listeners[hook].append(key)
	var producer_keys := {}
	for p in Combos._producers():
		producer_keys[p.key] = p.fires
	var checked := 0
	for b in boards:
		var hook: String = b.name.split(" via ")[0].replace("Combo: ", "")
		check(listeners.has(hook), "%s is a hook something listens on" % hook)
		for key in b.cfg.artefacts:
			# the producer itself may sit in `artefacts` without listening —
			# it is there to BE the producer, not to be the audience
			if producer_keys.has(key) and not listeners.get(hook, []).has(key):
				continue
			checked += 1
			check(listeners.get(hook, []).has(key),
				"%s listens on %s" % [key, hook])
		check(b.cfg.artefacts.size() <= Tuning.ARTEFACT_CAP_BASE,
			"%s holds at most %d Artefacts (%d)"
				% [b.name, Tuning.ARTEFACT_CAP_BASE, b.cfg.artefacts.size()])
		check(b.name.begins_with("Combo: "),
			"%s lands in the Combo section" % b.name)
	check(checked > 0, "the directed rule was actually exercised (%d pairs)" % checked)

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
