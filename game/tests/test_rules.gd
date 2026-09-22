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
	# NO-224: an unmoved pawn also gets the initial double-step.
	var b := {Vector2i(2, 2): piece("pawn", Rules.PLAYER)}
	check(Rules.moves_for(b, Vector2i(2, 2), defs) == [Vector2i(2, 3), Vector2i(2, 4)],
		"unmoved player pawn moves one OR two squares up (initial double-step)")
	b = {Vector2i(2, 2): piece("pawn", Rules.ENEMY)}
	check(Rules.moves_for(b, Vector2i(2, 2), defs) == [Vector2i(2, 1), Vector2i(2, 0)],
		"enemy pawn is mirrored (moves down), double-step included")
	b = {
		Vector2i(2, 2): piece("pawn", Rules.PLAYER),
		Vector2i(2, 3): piece("pawn", Rules.ENEMY),
		Vector2i(3, 3): piece("pawn", Rules.ENEMY),
	}
	check(Rules.moves_for(b, Vector2i(2, 2), defs) == [Vector2i(3, 3)],
		"pawn: blocked forward (incl. double-step), captures diagonally only")
	# NO-224: `moved` flag gates the double-step off after a piece's first move.
	b = {Vector2i(2, 2): piece("pawn", Rules.PLAYER)}
	b[Vector2i(2, 2)].moved = true
	check(Rules.moves_for(b, Vector2i(2, 2), defs) == [Vector2i(2, 3)],
		"a pawn that has already moved loses the double-step")
	# NO-224: the double-step is a slide, not a jump — a piece on the
	# intervening square (not the far square) blocks it, same as mW2cF above.
	b = {
		Vector2i(2, 2): piece("pawn", Rules.PLAYER),
		Vector2i(2, 3): piece("pawn", Rules.PLAYER),
	}
	check(Rules.moves_for(b, Vector2i(2, 2), defs).is_empty(),
		"double-step blocked by a piece on the intervening square")
	# The Void Pawn's mirror (mfFcfWimfnA): double-step along its own
	# move direction (forward-diagonal), same initial gating.
	b = {Vector2i(2, 2): piece("berolina", Rules.PLAYER)}
	var berolina_moves := Rules.moves_for(b, Vector2i(2, 2), defs)
	check(berolina_moves.has(Vector2i(3, 3)) and berolina_moves.has(Vector2i(4, 4)) \
		and berolina_moves.has(Vector2i(1, 3)) and berolina_moves.has(Vector2i(0, 4)),
		"unmoved Void Pawn gets the diagonal double-step both ways")
	b[Vector2i(2, 2)].moved = true
	berolina_moves = Rules.moves_for(b, Vector2i(2, 2), defs)
	check(not berolina_moves.has(Vector2i(4, 4)) and not berolina_moves.has(Vector2i(0, 4)),
		"a Void Pawn that has already moved loses its double-step")

	# --- NO-232: en passant, geometry-only (Max's ruling). An enemy pawn just
	# double-stepped (2,4)->(2,2), skip square (2,3); a player pawn beside it
	# at (1,2) already reaches (2,3) on its ordinary diagonal capture. ---
	var ep_offer := {"pawn": Vector2i(2, 2), "skip": Vector2i(2, 3), "id": "pawn"}
	b = {Vector2i(1, 2): piece("pawn", Rules.PLAYER), Vector2i(2, 2): piece("pawn", Rules.ENEMY)}
	check(Rules.moves_for(b, Vector2i(1, 2), defs, "", [ep_offer]).has(Vector2i(2, 3)),
		"a pawn's diagonal capture geometry reaches the en passant skip square")
	check(Rules.en_passant_victim(b, Vector2i(1, 2), Vector2i(2, 3), [ep_offer], defs) == Vector2i(2, 2),
		"en_passant_victim names the double-stepped pawn's own square, not the skip square")
	check(Rules.move_paths(b, Vector2i(1, 2), defs, [ep_offer]).any(
			func(p: Dictionary) -> bool: return p.kind == "leap" and p.to == Vector2i(2, 3)),
		"move_paths lists the en passant capture too, for the board's own arrow/dot")
	var ep_legal := Rules.legal_moves(b, Rules.PLAYER, defs, true, [], [ep_offer])
	var ep_move: Dictionary = ep_legal.filter(func(m: Dictionary) -> bool: return m.to == Vector2i(2, 3))[0]
	check(ep_move.get("ep_victim", Vector2i(-1, -1)) == Vector2i(2, 2),
		"legal_moves tags the move with which square to remove")
	# geometry, not a piece-id check: the Void Pawn's orthogonal-forward
	# capture (mfFcfWimfnA) never reaches a diagonal skip square
	var b_void := {Vector2i(1, 2): piece("berolina", Rules.PLAYER), Vector2i(2, 2): piece("pawn", Rules.ENEMY)}
	check(not Rules.moves_for(b_void, Vector2i(1, 2), defs, "", [ep_offer]).has(Vector2i(2, 3)),
		"a Void Pawn beside the same double-step cannot take it en passant")
	check(Rules.en_passant_victim(b_void, Vector2i(1, 2), Vector2i(2, 3), [ep_offer], defs) == Vector2i(-1, -1),
		"en_passant_victim agrees: no capture for the Void Pawn")
	# invalidated: the recorded pawn moved again (or was replaced) since
	var b_moved_away := {Vector2i(1, 2): piece("pawn", Rules.PLAYER)} # (2,2) now empty
	check(Rules.en_passant_victim(b_moved_away, Vector2i(1, 2), Vector2i(2, 3), [ep_offer], defs) == Vector2i(-1, -1),
		"a pawn that moved again this turn invalidates the offer")
	var b_replaced := {Vector2i(1, 2): piece("pawn", Rules.PLAYER), Vector2i(2, 2): piece("rook", Rules.ENEMY)}
	check(Rules.en_passant_victim(b_replaced, Vector2i(1, 2), Vector2i(2, 3), [ep_offer], defs) == Vector2i(-1, -1),
		"a different piece now standing on that square is not the recorded pawn")
	# a real piece already on the skip square: an ordinary capture, not en passant
	var b_occupied := {Vector2i(1, 2): piece("pawn", Rules.PLAYER), Vector2i(2, 2): piece("pawn", Rules.ENEMY),
		Vector2i(2, 3): piece("knight", Rules.ENEMY)}
	check(Rules.en_passant_victim(b_occupied, Vector2i(1, 2), Vector2i(2, 3), [ep_offer], defs) == Vector2i(-1, -1),
		"en passant only ever lands on an empty square")
	# rules.gd generates it for BOTH sides — same offer/geometry mechanism,
	# mirrored: an enemy pawn takes a player pawn's double-step via ai_action
	var ep_offer_enemy := {"pawn": Vector2i(2, 5), "skip": Vector2i(2, 4), "id": "pawn"}
	var b_ai := {Vector2i(1, 5): piece("pawn", Rules.ENEMY), Vector2i(2, 5): piece("pawn", Rules.PLAYER)}
	var ai_act := Rules.ai_action(b_ai, defs, [], [ep_offer_enemy])
	check(ai_act.get("from", Vector2i(-1, -1)) == Vector2i(1, 5) \
			and ai_act.get("to", Vector2i(-1, -1)) == Vector2i(2, 4) \
			and ai_act.get("ep_victim", Vector2i(-1, -1)) == Vector2i(2, 5),
		"ai_action takes an available en passant capture, mirrored for the enemy")
	# double_step_skip: the geometry NO-232 records from, both pawn shapes
	check(Rules.double_step_skip(piece("pawn", Rules.PLAYER), Vector2i(2, 1), Vector2i(2, 3), defs) == Vector2i(2, 2),
		"double_step_skip finds the Pawn's own midpoint")
	check(Rules.double_step_skip(piece("berolina", Rules.PLAYER), Vector2i(2, 1), Vector2i(4, 3), defs) == Vector2i(3, 2),
		"double_step_skip finds the Void Pawn's own (diagonal) midpoint")
	check(Rules.double_step_skip(piece("pawn", Rules.PLAYER), Vector2i(2, 1), Vector2i(2, 2), defs) == Vector2i(-1, -1),
		"double_step_skip is -1,-1 for an ordinary single-square move")

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
	# NO-224: an unmoved enemy pawn alone on the board has nothing to weigh
	# the double-step against (both advances are worth the same, v == 0), and
	# _pick prefers the deeper destination — proving ai_action can reach and
	# select the double-step, not just that legal_moves offers it.
	b = {Vector2i(2, 9): piece("pawn", Rules.ENEMY)}
	act = Rules.ai_action(b, defs)
	check(act.from == Vector2i(2, 9) and act.to == Vector2i(2, 7),
		"AI takes the initial double-step when it's the deeper of two equal advances")
	# King never advances voluntarily.
	b = {Vector2i(2, 7): piece("king", Rules.ENEMY), Vector2i(4, 5): piece("rook", Rules.ENEMY)}
	act = Rules.ai_action(b, defs)
	check(act.from == Vector2i(4, 5), "King stays put; escort advances")

	# --- material safety (2026-09-06): the AI looks one ply ahead at what it
	# stands to lose where it lands, so it stops hanging pieces and walking
	# into captures. Player pawns capture diagonally FORWARD (+y).
	# A rook must not take a pawn that a second pawn defends: -50 for +10.
	b = {
		Vector2i(0, 10): piece("rook", Rules.ENEMY),
		Vector2i(0, 5): piece("pawn", Rules.PLAYER),
		Vector2i(1, 4): piece("pawn", Rules.PLAYER), # defends (0,5)
	}
	act = Rules.ai_action(b, defs)
	check(not act.is_empty() and act.to != Vector2i(0, 5),
		"AI declines a poisoned capture (rook for a defended pawn)")
	# A free knight beats a defended rook: +30 clean vs +50 -40 on the recapture.
	b = {
		Vector2i(0, 10): piece("rook", Rules.ENEMY),
		Vector2i(0, 5): piece("rook", Rules.PLAYER),
		Vector2i(1, 4): piece("pawn", Rules.PLAYER), # defends (0,5)
		Vector2i(7, 10): piece("knight", Rules.PLAYER), # hanging, on the rook's row
	}
	act = Rules.ai_action(b, defs)
	check(act.to == Vector2i(7, 10), "AI prefers the free knight over the defended rook")
	# The only advance for the pawn is onto a square a player pawn covers; the
	# knight has a safe advance — the knight moves, the pawn is not fed.
	b = {
		# NO-224: `moved` so this pawn has no initial double-step. Without it the
		# pawn could reach (3,5), which (2,5) does NOT cover — a player pawn
		# captures to (1,6)/(3,6) — so "the only advance is a covered square"
		# would be false and the AI would rightly advance it. Passing THROUGH
		# the covered (3,6) is legal; only the landing square counts.
		Vector2i(3, 7): {"id": "pawn", "owner": Rules.ENEMY, "moved": true},
		Vector2i(6, 10): piece("knight", Rules.ENEMY),
		Vector2i(2, 5): piece("pawn", Rules.PLAYER), # covers (3,6)
	}
	act = Rules.ai_action(b, defs)
	check(act.from == Vector2i(6, 10), "AI advances the piece that can advance safely, not into a pawn")
	# With nothing but a losing move available, the enemy holds its action.
	# NO-224: `moved` for the same reason as the fixture above — an unmoved
	# pawn has a SAFE double-step to (3,5) here, so it would (correctly) take
	# it rather than hold, and this assertion would be testing nothing.
	b = {
		Vector2i(3, 7): {"id": "pawn", "owner": Rules.ENEMY, "moved": true},
		Vector2i(2, 5): piece("pawn", Rules.PLAYER),
	}
	act = Rules.ai_action(b, defs)
	check(act.is_empty(), "AI holds rather than feed its last piece into a capture")
	# NO-224, the same board with the pawn UNMOVED: the double-step clears the
	# covered square entirely and lands safe, so holding would now be the wrong
	# call. This is the positive half of the two fixtures above — they pin the
	# single-step behaviour, this pins that the AI actually uses the new move.
	b = {
		Vector2i(3, 7): piece("pawn", Rules.ENEMY),
		Vector2i(2, 5): piece("pawn", Rules.PLAYER),
	}
	act = Rules.ai_action(b, defs)
	check(not act.is_empty() and act.to == Vector2i(3, 5),
		"AI takes the safe double-step instead of holding (NO-224) — act=%s" % [act])

	# --- protect the King (GDD Rule 2) ---
	# Not in check (the knight's leap set is [(1,9),(1,5),(2,8),(2,6)], never
	# (2,9)) but it covers (1,9) and (2,8), both adjacent to the King: a
	# reposition-then-capture combo away. A juicier, non-threatening queen
	# is also up for grabs — the King guard must win over best-trade.
	b = {
		Vector2i(2, 9): piece("king", Rules.ENEMY),
		Vector2i(0, 7): piece("knight", Rules.PLAYER),
		Vector2i(0, 3): piece("rook", Rules.ENEMY),
		Vector2i(5, 3): piece("queen", Rules.PLAYER),
		Vector2i(5, 6): piece("rook", Rules.ENEMY),
	}
	act = Rules.ai_action(b, defs)
	check(act.from == Vector2i(0, 3) and act.to == Vector2i(0, 7),
		"King guard: neutralise the piece threatening it over a bigger, safe trade")
	# No enemy piece can reach the threat — the King retreats out of its range.
	b = {
		Vector2i(2, 9): piece("king", Rules.ENEMY),
		Vector2i(0, 7): piece("knight", Rules.PLAYER),
	}
	act = Rules.ai_action(b, defs)
	check(act.from == Vector2i(2, 9), "King guard: retreats when the threat can't be captured")
	var after := b.duplicate(true)
	after[act.to] = after[act.from]
	after.erase(act.from)
	check(Rules._king_threats(after, act.to, defs).is_empty(),
		"King guard: the retreat square is actually out of the knight's reach")

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

	# --- Winchester Salt Lined Doors (issue 51): `denied` is a caller-fed
	# parameter, not something rules.gd reads off g.artefacts. ai_action is
	# asserted directly (not just legal_moves) — proving the same filter
	# that binds legal_moves also binds the move ai_action actually picks. ---
	var back_row: Array[Vector2i] = []
	for x in Rules.Tuning.BOARD_W:
		back_row.append(Vector2i(x, 0))
	# same full-width-swarm fixture that commits to row 0 above; denying that
	# row leaves every pawn with zero legal moves (their only move is y=0).
	b = {}
	for x in Rules.Tuning.BOARD_W:
		b[Vector2i(x, 1)] = piece("pawn", Rules.ENEMY)
	check(Rules.legal_moves(b, Rules.ENEMY, defs, true, back_row).is_empty(),
		"legal_moves: denying the back row leaves the committed swarm with no legal move at all")
	act = Rules.ai_action(b, defs, back_row)
	check(act.is_empty(),
		"ai_action (not just legal_moves) is bound by `denied`: the swarm that would otherwise " +
		"commit to row 0 has no move left to make")
	# a piece already standing on a denied square is untouched: it stays put
	# freely (nothing forces it off) and remains free to leave via any
	# non-denied destination — only NEW entries onto the row are blocked.
	b = {Vector2i(3, 0): piece("rook", Rules.ENEMY)}
	var from_row0 := Rules.legal_moves(b, Rules.ENEMY, defs, true, back_row)
	check(not from_row0.is_empty() and from_row0.all(func(m: Dictionary) -> bool: return m.to.y != 0),
		"a rook already on the denied row keeps its non-row0 moves; sideways re-entry onto the row is denied")

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

	# --- review pass 1: strict legality simulates moves on a copy of the board
	# and must never touch the caller's board or its piece state (the copy is
	# shallow now — piece Dictionaries are shared, so this is the guard).
	var chk := {Vector2i(0, 11): piece("king", Rules.ENEMY),
		Vector2i(1, 10): piece("pawn", Rules.ENEMY), Vector2i(0, 3): piece("rook", Rules.PLAYER)}
	chk[Vector2i(1, 10)].buffs = [{"key": "shield"}]
	var chk_before := chk.duplicate(true)
	var strict := Rules.legal_moves(chk, Rules.ENEMY, defs, true)
	check(chk == chk_before and not strict.is_empty(),
		"strict legal_moves leaves the board and its piece state untouched")
	# NO-37: a timed x20 loop printed a number nothing asserted. Dropped rather
	# than turned into a bound: a wall-clock assertion in this suite would be
	# exactly the load-sensitive measurement CLAUDE.md records getting a PR
	# blocked on a wrong conclusion, and the strict path already has a
	# correctness assertion directly above. The accepted ~5 ms check-resolution
	# cost is documented in CLAUDE.md, not pinned here.

	print("---")
	if fails == 0:
		print("ALL TESTS PASSED")
	quit(1 if fails > 0 else 0)
