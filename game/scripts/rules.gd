## Pure game logic over plain data — no nodes, fully headless-testable.
## Board: Dictionary[Vector2i -> {id: String, owner: int}]. Owner 0 = player
## (forward +y), 1 = enemy (forward -y). (0,0) is bottom-left.

const Tuning := preload("res://scripts/tuning.gd")

const PLAYER := 0
const ENEMY := 1


static func load_pieces() -> Dictionary:
	var text := FileAccess.get_file_as_string("res://data/pieces.json")
	return JSON.parse_string(text)


static func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < Tuning.BOARD_W and p.y >= 0 and p.y < Tuning.BOARD_H


## Pseudo-legal destinations for the piece at `from`. `mode_filter` narrows to
## squares reachable as a move ("move") or capture ("capture") — used by
## is_attacked, which only cares about capture coverage.
static func moves_for(board: Dictionary, from: Vector2i, defs: Dictionary, mode_filter: String = "") -> Array[Vector2i]:
	var piece: Dictionary = board[from]
	var def: Dictionary = defs[piece.id]
	var mirror := -1 if piece.owner == ENEMY else 1
	var out: Array[Vector2i] = []
	for m in def.moves:
		if mode_filter != "" and m.mode != "both" and m.mode != mode_filter:
			continue
		for dir in m.dirs:
			var step := Vector2i(int(dir[0]), int(dir[1]) * mirror)
			if m.type == "leap":
				_add_dest(board, from, from + step, piece.owner, m.mode, out)
			else: # ride
				var range_limit: int = int(m.get("range", 0))
				var pos := from
				var steps := 0
				while true:
					pos += step
					steps += 1
					if not in_bounds(pos) or (range_limit > 0 and steps > range_limit):
						break
					_add_dest(board, from, pos, piece.owner, m.mode, out)
					if board.has(pos):
						break # rides stop at the first occupied square
	return out


static func _add_dest(board: Dictionary, _from: Vector2i, to: Vector2i, owner: int, mode: String, out: Array[Vector2i]) -> void:
	if not in_bounds(to) or out.has(to):
		return
	if board.has(to):
		if board[to].owner != owner and mode != "move":
			out.append(to)
	elif mode != "capture":
		out.append(to)


static func find_king(board: Dictionary, owner: int) -> Vector2i:
	for pos in board:
		if board[pos].owner == owner and board[pos].id == "king":
			return pos
	return Vector2i(-1, -1)


static func is_attacked(board: Dictionary, target: Vector2i, by_owner: int, defs: Dictionary) -> bool:
	for pos in board:
		if board[pos].owner == by_owner and moves_for(board, pos, defs, "capture").has(target):
			return true
	return false


## All {from, to} moves for `owner`; when that side has a King on the board,
## moves that leave it attacked are excluded (GDD: "protect the King at all cost").
## strict=false skips the self-check simulation for NON-king pieces — pins are
## ignored. ponytail: the full sim is O(pieces² × moves) and made late-game AI
## turns take minutes on crowded boards; the greedy AI keeps full safety for
## king moves and for check resolution (callers pass strict=true there).
static func legal_moves(board: Dictionary, owner: int, defs: Dictionary, strict := true) -> Array[Dictionary]:
	var king := find_king(board, owner)
	var out: Array[Dictionary] = []
	for pos in board:
		if board[pos].owner != owner:
			continue
		for to in moves_for(board, pos, defs):
			if king.x >= 0 and (strict or pos == king):
				var sim := board.duplicate(true)
				sim[to] = sim[pos]
				sim.erase(pos)
				var king_after := to if pos == king else king
				if is_attacked(sim, king_after, 1 - owner, defs):
					continue
			out.append({"from": pos, "to": to})
	return out


static func is_checkmate(board: Dictionary, owner: int, defs: Dictionary) -> bool:
	var king := find_king(board, owner)
	if king.x < 0 or not is_attacked(board, king, 1 - owner, defs):
		return false
	return legal_moves(board, owner, defs).is_empty()


## Merge result for 2 or 3 selected piece ids (from the combined Stock +
## Captured pool), or "" if the selection is not a valid merge.
## 2 identical -> 1 of the same; 3 identical -> next chain stage (same id at
## chain end); 3 different -> lowest-value of the three. (Rules grilled 2026-07-02.)
static func merge_result(ids: Array, defs: Dictionary) -> String:
	if ids.size() == 2 and ids[0] == ids[1]:
		return ids[0]
	if ids.size() == 3:
		if ids[0] == ids[1] and ids[1] == ids[2]:
			var next = defs[ids[0]].next
			return next if next != null else ids[0]
		if ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2]:
			var lowest: String = ids[0]
			for id in ids:
				if defs[id].value < defs[lowest].value:
					lowest = id
			return lowest
	return ""


## Any valid merge available in the combined pool? (Part of the resource-
## starvation loss check: 2-of-a-kind, or 3 distinct ids.)
static func has_merge(pool: Array) -> bool:
	var counts := {}
	for id in pool:
		counts[id] = counts.get(id, 0) + 1
		if counts[id] >= 2:
			return true
	return counts.size() >= 3


## Empty tiles where the player may place: bottom zone rows, or adjacent
## (8-neighborhood) to a friendly piece.
static func placement_tiles(board: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in Tuning.BOARD_W:
		for y in Tuning.BOARD_H:
			var pos := Vector2i(x, y)
			if board.has(pos):
				continue
			if y < Tuning.PLAYER_ZONE_ROWS or _touches_player(board, pos):
				out.append(pos)
	return out


static func _touches_player(board: Dictionary, pos: Vector2i) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var n := pos + Vector2i(dx, dy)
			if n != pos and board.has(n) and board[n].owner == PLAYER:
				return true
	return false


## One greedy enemy action. Returns {from, to} or {} when the enemy has no
## legal move. Priority (GDD Enemy AI Behaviors + grilled advance rule):
## resolve check (prefer capture) > best trade (max target value, min attacker
## value) > advance the most advanced non-King piece toward the player row.
static func ai_action(board: Dictionary, defs: Dictionary) -> Dictionary:
	var king := find_king(board, ENEMY)
	var in_check := king.x >= 0 and is_attacked(board, king, PLAYER, defs)
	# full legality only when in check (must not miss a resolving move);
	# otherwise the fast path — king moves stay safety-checked, pins ignored
	var moves := legal_moves(board, ENEMY, defs, in_check)
	if moves.is_empty():
		return {}
	if in_check:
		# legal_moves already filtered to check-resolving moves; prefer a capture.
		return _best_capture(board, moves, defs) if _has_capture(board, moves) else moves[0]
	if _has_capture(board, moves):
		return _best_capture(board, moves, defs)
	var best := {}
	var best_key := Vector2i(Tuning.BOARD_H, Tuning.BOARD_H)
	for m in moves:
		if board[m.from].id == "king":
			continue # the King never advances voluntarily
		var key := Vector2i(m.to.y, m.from.y) # min dest row, then most advanced piece
		if m.to.y < m.from.y and key < best_key:
			best_key = key
			best = m
	return best if not best.is_empty() else moves[0]


static func _has_capture(board: Dictionary, moves: Array[Dictionary]) -> bool:
	for m in moves:
		if board.has(m.to):
			return true
	return false


static func _best_capture(board: Dictionary, moves: Array[Dictionary], defs: Dictionary) -> Dictionary:
	var best := {}
	var best_target := -1
	var best_attacker := 1000
	for m in moves:
		if not board.has(m.to):
			continue
		var target: int = defs[board[m.to].id].value
		var attacker: int = defs[board[m.from].id].value
		if target > best_target or (target == best_target and attacker < best_attacker):
			best_target = target
			best_attacker = attacker
			best = m
	return best
