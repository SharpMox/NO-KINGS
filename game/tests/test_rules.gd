extends SceneTree

const Rules := preload("res://scripts/rules.gd")
## Assert-based self-tests for rules.gd. Run headless:
##   godot --headless --path game -s tests/test_rules.gd
## Exits 0 on success, 1 on the first failure.

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func piece(id: String, owner: int) -> Dictionary:
	return {"id": id, "owner": owner}


func _init() -> void:
	var defs := Rules.load_pieces()
	check(defs.size() == 39, "38 codex pieces + the enemy King load")
	var fus := Rules.load_fusions()
	check(fus.size() == 36, "full fusion table loads")

	# --- move-gen: pawn asymmetry + enemy mirroring ---
	var b := {Vector2i(2, 2): piece("pawn", Rules.PLAYER)}
	check(Rules.moves_for(b, Vector2i(2, 2), defs) == [Vector2i(2, 3)],
		"player pawn moves one square up, no double-step")
	b = {Vector2i(2, 2): piece("pawn", Rules.ENEMY)}
	check(Rules.moves_for(b, Vector2i(2, 2), defs) == [Vector2i(2, 1)],
		"enemy pawn is mirrored (moves down)")
	b = {
		Vector2i(2, 2): piece("pawn", Rules.PLAYER),
		Vector2i(2, 3): piece("pawn", Rules.ENEMY),
		Vector2i(3, 3): piece("pawn", Rules.ENEMY),
	}
	check(Rules.moves_for(b, Vector2i(2, 2), defs) == [Vector2i(3, 3)],
		"pawn: blocked forward, captures diagonally only")

	# --- move-gen: knight leaps over blockers ---
	b = {Vector2i(0, 0): piece("knight", Rules.PLAYER), Vector2i(0, 1): piece("pawn", Rules.PLAYER)}
	var knight_moves := Rules.moves_for(b, Vector2i(0, 0), defs)
	check(knight_moves.has(Vector2i(1, 2)) and knight_moves.has(Vector2i(2, 1)),
		"knight leaps over blockers")

	# --- move-gen: rook rides stop at blockers ---
	b = {
		Vector2i(0, 0): piece("rook", Rules.PLAYER),
		Vector2i(0, 3): piece("pawn", Rules.ENEMY),
		Vector2i(2, 0): piece("pawn", Rules.PLAYER),
	}
	var rook_moves := Rules.moves_for(b, Vector2i(0, 0), defs)
	check(rook_moves.has(Vector2i(0, 3)) and not rook_moves.has(Vector2i(0, 4)),
		"rook captures blocker, cannot pass it")
	check(rook_moves.has(Vector2i(1, 0)) and not rook_moves.has(Vector2i(2, 0)),
		"rook stops before friendly piece")

	# --- move-gen: archer (arrow-pawn) range-2 ride cannot jump ---
	b = {Vector2i(3, 3): piece("arrow-pawn", Rules.PLAYER), Vector2i(3, 4): piece("pawn", Rules.PLAYER)}
	var archer_moves := Rules.moves_for(b, Vector2i(3, 3), defs)
	check(not archer_moves.has(Vector2i(3, 5)), "archer cannot jump a blocker (W2 is a ride)")
	check(archer_moves.has(Vector2i(1, 3)) and archer_moves.has(Vector2i(3, 1)),
		"archer slides 2 orthogonally when clear")
	b = {Vector2i(3, 3): piece("arrow-pawn", Rules.PLAYER), Vector2i(3, 4): piece("pawn", Rules.ENEMY)}
	check(not Rules.moves_for(b, Vector2i(3, 3), defs).has(Vector2i(3, 4)),
		"archer move squares are move-only (no orthogonal capture)")
	b = {Vector2i(3, 3): piece("arrow-pawn", Rules.PLAYER), Vector2i(4, 4): piece("pawn", Rules.ENEMY)}
	check(Rules.moves_for(b, Vector2i(3, 3), defs).has(Vector2i(4, 4)),
		"archer captures diagonally (capture-only squares)")

	# --- move-gen: nightrider chains (Djinn/Lich/Valkyrie) ---
	b = {Vector2i(3, 3): piece("banshee", Rules.PLAYER)}
	var nr := Rules.moves_for(b, Vector2i(3, 3), defs)
	check(nr.has(Vector2i(4, 5)) and nr.has(Vector2i(5, 7)), "nightrider rides repeated leaps")
	b[Vector2i(4, 5)] = piece("pawn", Rules.PLAYER)
	nr = Rules.moves_for(b, Vector2i(3, 3), defs)
	check(not nr.has(Vector2i(5, 7)), "a blocker on the chain stops the nightrider")

	# --- move-gen: bent-riders (Quetzalcoatl) ---
	b = {Vector2i(2, 2): piece("gryphon", Rules.PLAYER)}
	var gm := Rules.moves_for(b, Vector2i(2, 2), defs)
	check(gm.has(Vector2i(3, 3)), "gryphon can stop on the pivot")
	check(gm.has(Vector2i(3, 6)), "gryphon rides outward beyond the pivot")
	check(not gm.has(Vector2i(4, 4)), "gryphon does not continue diagonally")
	b[Vector2i(3, 3)] = piece("pawn", Rules.PLAYER)
	gm = Rules.moves_for(b, Vector2i(2, 2), defs)
	check(not gm.has(Vector2i(3, 5)), "a piece on the pivot blocks the whole branch")

	# --- merges: pairs only (round 3) ---
	check(Rules.merge_result(["ferz", "ferz"], defs, fus) == "elephant-modern",
		"2 same -> next chain stage")
	check(Rules.merge_result(["queen", "queen"], defs, fus) == "",
		"chain-end pair does not merge")
	check(Rules.merge_result(["bishop", "rook"], defs, fus) == "queen",
		"fusion pair -> fusion result")
	check(Rules.merge_result(["rook", "bishop"], defs, fus) == "queen",
		"fusion is order-agnostic")
	check(Rules.merge_result(["knight", "alibaba"], defs, fus) == "squirrel",
		"fusion can produce fusion-only pieces")
	check(Rules.merge_result(["ferz", "rook"], defs, fus) == "gryphon",
		"bent-rider fusions are live (Seer + Rook -> Quetzalcoatl)")
	check(Rules.merge_result(["pawn", "rook"], defs, fus) == "",
		"non-fusion pair does not merge")
	check(Rules.merge_result(["pawn", "pawn", "pawn"], defs, fus) == "",
		"3-piece selections are invalid")
	check(Rules.has_merge(["pawn", "pawn"], defs, fus), "has_merge: promotion pair")
	check(Rules.has_merge(["bishop", "rook"], defs, fus), "has_merge: fusion pair")
	check(not Rules.has_merge(["pawn", "rook"], defs, fus), "has_merge: dead pair")
	check(not Rules.has_merge(["queen", "queen"], defs, fus), "has_merge: chain end is dead")

	# --- placement tiles ---
	b = {Vector2i(3, 3): piece("rook", Rules.PLAYER), Vector2i(0, 5): piece("rook", Rules.ENEMY)}
	var tiles := Rules.placement_tiles(b)
	check(tiles.has(Vector2i(0, 0)) and tiles.has(Vector2i(5, 1)), "zone rows placeable")
	check(tiles.has(Vector2i(3, 4)) and tiles.has(Vector2i(2, 2)), "tiles around friendly placeable")
	check(not tiles.has(Vector2i(3, 3)), "occupied tile not placeable")
	check(not tiles.has(Vector2i(0, 4)), "tile adjacent only to enemy not placeable")

	# --- check / checkmate ---
	var top := Rules.Tuning.BOARD_H - 1
	var right := Rules.Tuning.BOARD_W - 1
	# Enemy king in the top-right corner; player queen one diagonal below covers
	# everything, rook guards the top row.
	b = {
		Vector2i(right, top): piece("king", Rules.ENEMY),
		Vector2i(right - 1, top - 1): piece("queen", Rules.PLAYER),
		Vector2i(right - 2, top - 1): piece("rook", Rules.PLAYER),
	}
	check(Rules.is_checkmate(b, Rules.ENEMY, defs), "back-corner queen mate detected")
	# Same but queen unprotected and adjacent: king can capture it -> not mate.
	b = {
		Vector2i(right, top): piece("king", Rules.ENEMY),
		Vector2i(right - 1, top - 1): piece("queen", Rules.PLAYER),
	}
	check(not Rules.is_checkmate(b, Rules.ENEMY, defs), "king can take unprotected queen: not mate")
	check(Rules.legal_moves(b, Rules.ENEMY, defs).size() == 1, "check leaves exactly the capture")

	# --- AI ---
	# Best trade: pawn can take rook(5), knight can take bishop(3) -> pawn takes rook.
	b = {
		Vector2i(1, 3): piece("pawn", Rules.ENEMY),
		Vector2i(0, 2): piece("rook", Rules.PLAYER),
		Vector2i(4, 4): piece("knight", Rules.ENEMY),
		Vector2i(5, 2): piece("bishop", Rules.PLAYER),
	}
	var act := Rules.ai_action(b, defs)
	check(act.from == Vector2i(1, 3) and act.to == Vector2i(0, 2),
		"AI takes highest-value target with lowest-value attacker")
	# No captures: advances toward row 0.
	b = {Vector2i(2, 5): piece("knight", Rules.ENEMY)}
	act = Rules.ai_action(b, defs)
	check(act.to.y < 5, "AI advances toward player back row when no captures")
	# King never advances voluntarily.
	b = {Vector2i(2, 7): piece("king", Rules.ENEMY), Vector2i(4, 5): piece("rook", Rules.ENEMY)}
	act = Rules.ai_action(b, defs)
	check(act.from == Vector2i(4, 5), "King stays put; escort advances")
	# Back-row commitment: a lone rook at row 1 holds out of row 0...
	b = {Vector2i(3, 1): piece("rook", Rules.ENEMY)}
	act = Rules.ai_action(b, defs)
	check(act.is_empty() or act.to.y != 0, "lone enemy does not enter the back row")
	# ...but with enough massed to fill every column, entering row 0 is on.
	b = {}
	for x in Rules.Tuning.BOARD_W:
		b[Vector2i(x, 1)] = piece("pawn", Rules.ENEMY)
	act = Rules.ai_action(b, defs)
	check(not act.is_empty() and act.to.y == 0, "a full-width swarm commits to the back row")
	# one short of full width still holds
	b.erase(Vector2i(0, 1))
	act = Rules.ai_action(b, defs)
	check(act.is_empty() or act.to.y != 0, "one short of full width still holds")

	# --- move_paths (display shapes) must flatten to exactly moves_for ---
	# every piece def, alone and in a crowded scene, both owners
	var crowd := {
		Vector2i(3, 6): piece("pawn", Rules.PLAYER), Vector2i(5, 8): piece("rook", Rules.ENEMY),
		Vector2i(2, 9): piece("knight", Rules.ENEMY), Vector2i(4, 5): piece("bishop", Rules.PLAYER),
	}
	var mismatches := 0
	for id in defs:
		for owner in [Rules.PLAYER, Rules.ENEMY]:
			for base in [{}, crowd]:
				var scene: Dictionary = base.duplicate()
				var at := Vector2i(3, 7)
				scene[at] = piece(id, owner)
				var flat := {}
				for p in Rules.move_paths(scene, at, defs):
					if p.kind == "leap":
						flat[p.to] = true
					else:
						for t in p.line:
							flat[t] = true
				var dests := Rules.moves_for(scene, at, defs)
				if flat.size() != dests.size():
					mismatches += 1
					continue
				for d in dests:
					if not flat.has(d):
						mismatches += 1
						break
	check(mismatches == 0,
		"move_paths flattens to moves_for for all %d pieces (%d mismatches)" % [defs.size(), mismatches])

	print("---")
	if fails == 0:
		print("ALL TESTS PASSED")
	quit(1 if fails > 0 else 0)
