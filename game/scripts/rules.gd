## Pure game logic over plain data — no nodes, fully headless-testable.
## Board: Dictionary[Vector2i -> {id: String, owner: int}]. Owner 0 = player
## (forward +y), 1 = enemy (forward -y). (0,0) is bottom-left.

const Tuning := preload("res://scripts/tuning.gd")

const PLAYER := 0
const ENEMY := 1


const BuffLogic := preload("res://scripts/buff_logic.gd")


static func load_pieces() -> Dictionary:
	var text := FileAccess.get_file_as_string("res://data/pieces.json")
	return JSON.parse_string(text)


static func load_fusions() -> Dictionary:
	var text := FileAccess.get_file_as_string("res://data/fusions.json")
	return JSON.parse_string(text)


static func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < Tuning.BOARD_W and p.y >= 0 and p.y < Tuning.BOARD_H


## Pseudo-legal destinations for the piece at `from`. `mode_filter` narrows to
## squares reachable as a move ("move") or capture ("capture") — used by
## is_attacked, which only cares about capture coverage.
static func moves_for(board: Dictionary, from: Vector2i, defs: Dictionary, mode_filter: String = "") -> Array[Vector2i]:
	var piece: Dictionary = board[from]
	var mirror := -1 if piece.owner == ENEMY else 1
	var out: Array[Vector2i] = []
	# Slow/Smog swap the move set for the Pawn's (ruling 2026-08-28)
	for m in BuffLogic.moves_of(board, from, defs):
		if mode_filter != "" and m.mode != "both" and m.mode != mode_filter:
			continue
		if m.type == "bent": # one step to the pivot, then ride outward from it
			var pivot := from + Vector2i(int(m.pivot[0]), int(m.pivot[1]) * mirror)
			if not in_bounds(pivot):
				continue
			_add_dest(board, from, pivot, piece.owner, m.mode, out)
			if board.has(pivot):
				continue # anything on the pivot blocks the continuation
			var bstep := Vector2i(int(m.dir[0]), int(m.dir[1]) * mirror)
			var bpos := pivot
			while true:
				bpos += bstep
				if not in_bounds(bpos):
					break
				_add_dest(board, from, bpos, piece.owner, m.mode, out)
				if board.has(bpos):
					break
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
	if mode_filter != "move" and BuffLogic.has(piece, "range"):
		for at in range_halo(board, from, out):
			if not out.has(at):
				out.append(at)
	return out


## Range buff (ruled 2026-08-28): every enemy this piece can already capture
## also exposes the enemies standing around it — capture-only, one level deep.
## Defined the same way for leapers, bounded riders and unbounded riders, which
## is what the catalog's "+2 extra squares" could not be. In practice it reaches
## one enemy deeper into a cluster, and lets a rider take past its blocker.
static func range_halo(board: Dictionary, from: Vector2i, dests: Array[Vector2i]) -> Array[Vector2i]:
	var owner: int = board[from].owner
	var extra: Array[Vector2i] = []
	for d in dests:
		if not board.has(d) or board[d].owner == owner:
			continue # only squares this piece can actually capture on
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var at := d + Vector2i(dx, dy)
				if at == from or not in_bounds(at) or extra.has(at):
					continue
				if board.has(at) and board[at].owner != owner:
					extra.append(at)
	return extra


## Display-annotated variant of moves_for — same legality, grouped by shape so
## the board can draw leaps as dots, rides as arrows, and bent rides as linked
## dots. Kept structurally parallel to moves_for; test_rules asserts the
## flattened destination set matches exactly.
static func move_paths(board: Dictionary, from: Vector2i, defs: Dictionary) -> Array[Dictionary]:
	var piece: Dictionary = board[from]
	var def: Dictionary = defs[piece.id]
	var mirror := -1 if piece.owner == ENEMY else 1
	var out: Array[Dictionary] = []
	for m in def.moves:
		if m.type == "bent": # one step to the pivot, then ride outward from it
			var pivot := from + Vector2i(int(m.pivot[0]), int(m.pivot[1]) * mirror)
			if not in_bounds(pivot):
				continue
			var bline: Array[Vector2i] = []
			_path_dest(board, pivot, piece.owner, m.mode, bline)
			if not board.has(pivot):
				var bstep := Vector2i(int(m.dir[0]), int(m.dir[1]) * mirror)
				var bpos := pivot
				while true:
					bpos += bstep
					if not in_bounds(bpos):
						break
					_path_dest(board, bpos, piece.owner, m.mode, bline)
					if board.has(bpos):
						break
			if not bline.is_empty():
				out.append({"kind": "bent", "line": bline})
			continue
		for dir in m.dirs:
			var step := Vector2i(int(dir[0]), int(dir[1]) * mirror)
			if m.type == "leap":
				var hop: Array[Vector2i] = []
				_path_dest(board, from + step, piece.owner, m.mode, hop)
				if not hop.is_empty():
					out.append({"kind": "leap", "to": hop[0]})
			else: # ride
				var range_limit: int = int(m.get("range", 0))
				var pos := from
				var steps := 0
				var line: Array[Vector2i] = []
				while true:
					pos += step
					steps += 1
					if not in_bounds(pos) or (range_limit > 0 and steps > range_limit):
						break
					_path_dest(board, pos, piece.owner, m.mode, line)
					if board.has(pos):
						break # rides stop at the first occupied square
				if not line.is_empty():
					# a ride whose step is itself a leap (nightrider-style, e.g.
					# the Valkyrie) hops down the line rather than sliding
					out.append({"kind": "ride", "line": line,
						"hop": absi(step.x) > 1 or absi(step.y) > 1})
	return out


static func _path_dest(board: Dictionary, to: Vector2i, owner: int, mode: String, line: Array[Vector2i]) -> void:
	if not in_bounds(to):
		return
	if board.has(to):
		if board[to].owner != owner and mode != "move":
			line.append(to)
	elif mode != "capture":
		line.append(to)


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
##
## `denied` (issue 51 — Winchester Salt Lined Doors): destination squares this
## call must never land on, regardless of piece or mode. rules.gd stays a pure
## static module with no g.artefacts access, so the caller (game.gd) computes
## which squares are denied from the held Artefacts and passes the set in —
## same precedent as _deploy_tiles' Nazca Boarding Pass read. A capture is a
## move onto the victim's tile in this engine (no piece captures without
## relocating there — Multicapture is the one exception, but it never targets
## a player piece, see buff_logic.gd), so filtering `to` here denies capture
## and plain movement alike with no separate case needed. Filtering is by
## destination only, not origin: a piece already standing on a denied square
## is untouched and free to leave; moving to ANOTHER denied square (e.g.
## sideways along the same row) is still denied — "cannot move onto" reads as
## about the destination, not the piece's starting side.
static func legal_moves(board: Dictionary, owner: int, defs: Dictionary, strict := true,
		denied: Array[Vector2i] = []) -> Array[Dictionary]:
	var king := find_king(board, owner)
	var out: Array[Dictionary] = []
	for pos in board:
		if board[pos].owner != owner:
			continue
		for to in moves_for(board, pos, defs):
			if denied.has(to):
				continue
			if king.x >= 0 and (strict or pos == king):
				var sim := board.duplicate(true)
				sim[to] = sim[pos]
				sim.erase(pos)
				var king_after := to if pos == king else king
				if is_attacked(sim, king_after, 1 - owner, defs):
					continue
			out.append({"from": pos, "to": to})
	return out


static func is_checkmate(board: Dictionary, owner: int, defs: Dictionary,
		denied: Array[Vector2i] = []) -> bool:
	var king := find_king(board, owner)
	if king.x < 0 or not is_attacked(board, king, 1 - owner, defs):
		return false
	return legal_moves(board, owner, defs, true, denied).is_empty()


## Merge result for exactly 2 selected piece ids, or "" if invalid.
## 2 identical -> next promotion-chain stage (chain-end pairs don't merge);
## 2 different -> the pair's fusion result, if the Fusions catalog has one.
## (Rules: playtest round 3, 2026-07-02.)
static func merge_result(ids: Array, defs: Dictionary, fusions: Dictionary) -> String:
	if ids.size() != 2:
		return ""
	if ids[0] == ids[1]:
		var next = defs[ids[0]].next
		return next if next != null else ""
	var pair: Array = [ids[0], ids[1]]
	pair.sort()
	return fusions.get("+".join(pair), "")


## Any valid merge available in the pool? (Part of the resource-starvation
## loss check.)
static func has_merge(pool: Array, defs: Dictionary, fusions: Dictionary) -> bool:
	for i in pool.size():
		for j in range(i + 1, pool.size()):
			if merge_result([pool[i], pool[j]], defs, fusions) != "":
				return true
	return false


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


## One greedy enemy action. Priority (GDD Enemy AI Behaviors + grilled advance
## rule): resolve check (prefer capture) > protect the King (capture a piece
## threatening it, else retreat it to safety) > best trade (max target value,
## min attacker value) > advance the most advanced non-King piece toward the
## player row. Returns {from, to} or {} when the enemy has no legal move.
##
## `denied` (issue 51): forwarded straight into legal_moves — see its header.
## ai_action calls the same legal_moves the player's own moves come from
## (rules.gd:280 pre-issue-51), so this one parameter binds the AI too; there
## is no second move generator to keep in sync.
static func ai_action(board: Dictionary, defs: Dictionary, denied: Array[Vector2i] = []) -> Dictionary:
	var king := find_king(board, ENEMY)
	var in_check := king.x >= 0 and is_attacked(board, king, PLAYER, defs)
	# full legality only when in check (must not miss a resolving move);
	# otherwise the fast path — king moves stay safety-checked, pins ignored
	var moves := legal_moves(board, ENEMY, defs, in_check, denied)
	moves = moves.filter(func(m: Dictionary) -> bool: # Stun: this piece sits it out
		return not BuffLogic.has(board[m.from], "stunned"))
	if moves.is_empty():
		return {}
	if in_check:
		# legal_moves already filtered to check-resolving moves; prefer a capture.
		return _best_capture(board, moves, defs) if _has_capture(board, moves) else moves[0]
	if king.x >= 0:
		# Rule 2, "protect the King at all cost": not yet in check, but a player
		# piece already covers a square next to it (one action away from a
		# multi-action turn combo: reposition + capture in the same player
		# turn, which the enemy would never get a turn to react to). Take out
		# the threat if a legal move can; otherwise pull the King to whichever
		# of its legal squares leaves the fewest threats standing. Simplest
		# defensible scope (2026-08-28): capture-the-threat + retreat, no path
		# interposition/blocking.
		var threats := _king_threats(board, king, defs)
		if not threats.is_empty():
			var defend := _defend_king(board, moves, king, threats, defs)
			if not defend.is_empty():
				return defend
	if _has_capture(board, moves):
		return _best_capture(board, moves, defs)
	# only commit pieces INTO the back row once enough force is massed nearby —
	# trickling in one at a time just feeds the player captures
	var near := 0
	for pos in board:
		if board[pos].owner == ENEMY and pos.y <= Tuning.BACKROW_NEAR_ROWS:
			near += 1
	var commit := near >= Tuning.BACKROW_COMMIT_COUNT
	var best := {}
	var best_key := Vector2i(Tuning.BOARD_H, Tuning.BOARD_H)
	for m in moves:
		if board[m.from].id == "king":
			continue # the King never advances voluntarily
		if not commit and m.to.y == 0:
			continue # hold at row 1 until the swarm is big enough
		var key := Vector2i(m.to.y, m.from.y) # min dest row, then most advanced piece
		if m.to.y < m.from.y and key < best_key:
			best_key = key
			best = m
	if not best.is_empty():
		return best
	for m in moves: # fallback shuffle also respects the back-row hold
		if commit or m.to.y != 0:
			return m
	return {} # nothing but back-row entries available: hold this action


static func _has_capture(board: Dictionary, moves: Array[Dictionary]) -> bool:
	for m in moves:
		if board.has(m.to):
			return true
	return false


static func _best_capture(board: Dictionary, moves: Array[Dictionary], defs: Dictionary) -> Dictionary:
	# Taunt overrides the value heuristic entirely: if a taunting piece can be
	# taken at all, it is the target.
	var taunts := moves.filter(func(m: Dictionary) -> bool:
		return board.has(m.to) and BuffLogic.has(board[m.to], "taunt"))
	if not taunts.is_empty():
		return taunts[0]
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


## Player pieces that already cover a square in the King's 8-neighborhood —
## one move away from a same-turn reposition-then-capture combo the enemy
## would get no turn to react to. Positions, not moves: several destinations
## can belong to the same attacker.
static func _king_threats(board: Dictionary, king: Vector2i, defs: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pos in board:
		if board[pos].owner != PLAYER:
			continue
		for to in moves_for(board, pos, defs, "capture"):
			if absi(to.x - king.x) <= 1 and absi(to.y - king.y) <= 1 and not out.has(pos):
				out.append(pos)
				break
	return out


## Protect-the-King response: capture a threatening piece if a legal move
## reaches one, else retreat the King to whichever of its own legal squares
## leaves the fewest threats standing. {} if neither is possible this turn.
static func _defend_king(board: Dictionary, moves: Array[Dictionary], king: Vector2i,
		threats: Array[Vector2i], defs: Dictionary) -> Dictionary:
	var strikes := moves.filter(func(m: Dictionary) -> bool: return threats.has(m.to))
	if not strikes.is_empty():
		return _best_capture(board, strikes, defs)
	var retreats := moves.filter(func(m: Dictionary) -> bool: return m.from == king)
	var best := {}
	var best_left := threats.size() + 1
	for m in retreats:
		var sim := board.duplicate(true)
		sim[m.to] = sim[m.from]
		sim.erase(m.from)
		var left := _king_threats(sim, m.to, defs).size()
		if left < best_left:
			best_left = left
			best = m
	return best
