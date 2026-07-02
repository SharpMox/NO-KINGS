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
	check(defs.size() == 25, "25 piece defs load")

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

	# --- merges ---
	check(Rules.merge_result(["ferz", "ferz"], defs) == "ferz", "2 same -> 1 of same")
	check(Rules.merge_result(["ferz", "ferz", "ferz"], defs) == "elephant-modern",
		"3 same -> next chain stage")
	check(Rules.merge_result(["queen", "queen", "queen"], defs) == "queen",
		"3 same at chain end -> same piece")
	check(Rules.merge_result(["rook", "knight", "pawn"], defs) == "pawn",
		"3 different -> lowest value")
	check(Rules.merge_result(["rook", "rook", "pawn"], defs) == "", "2+1 is not a valid merge")
	check(Rules.merge_result(["rook", "knight"], defs) == "", "2 different is not a valid merge")
	check(Rules.has_merge(["pawn", "pawn"]), "has_merge: pair")
	check(Rules.has_merge(["pawn", "rook", "ferz"]), "has_merge: 3 distinct")
	check(not Rules.has_merge(["pawn", "rook"]), "has_merge: 2 distinct is dead")

	# --- placement tiles ---
	b = {Vector2i(3, 3): piece("rook", Rules.PLAYER), Vector2i(0, 5): piece("rook", Rules.ENEMY)}
	var tiles := Rules.placement_tiles(b)
	check(tiles.has(Vector2i(0, 0)) and tiles.has(Vector2i(5, 1)), "zone rows placeable")
	check(tiles.has(Vector2i(3, 4)) and tiles.has(Vector2i(2, 2)), "tiles around friendly placeable")
	check(not tiles.has(Vector2i(3, 3)), "occupied tile not placeable")
	check(not tiles.has(Vector2i(0, 4)), "tile adjacent only to enemy not placeable")

	# --- check / checkmate ---
	var top := Rules.Tuning.BOARD_H - 1
	# Enemy king in the top corner; player queen one diagonal below covers
	# everything, rook guards the top row.
	b = {
		Vector2i(5, top): piece("king", Rules.ENEMY),
		Vector2i(4, top - 1): piece("queen", Rules.PLAYER),
		Vector2i(3, top - 1): piece("rook", Rules.PLAYER),
	}
	check(Rules.is_checkmate(b, Rules.ENEMY, defs), "back-corner queen mate detected")
	# Same but queen unprotected and adjacent: king can capture it -> not mate.
	b = {
		Vector2i(5, top): piece("king", Rules.ENEMY),
		Vector2i(4, top - 1): piece("queen", Rules.PLAYER),
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

	print("---")
	if fails == 0:
		print("ALL TESTS PASSED")
	quit(1 if fails > 0 else 0)
