## Item targeting rules — pure logic over the board Dictionary, no nodes
## (split out of game.gd; item effects and UI stay there).

const Rules := preload("res://scripts/rules.gd")
const Tuning := preload("res://scripts/tuning.gd")


static func stage_targets(board: Dictionary, defs: Dictionary, key: String, a: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in Tuning.BOARD_W:
		for y in Tuning.BOARD_H:
			var pos := Vector2i(x, y)
			if tile_valid(board, defs, key, a, pos):
				out.append(pos)
	return out


static func tile_valid(board: Dictionary, defs: Dictionary, key: String, a: Vector2i, pos: Vector2i) -> bool:
	var occupied := board.has(pos)
	var enemy: bool = occupied and board[pos].owner == Rules.ENEMY
	var own: bool = occupied and board[pos].owner == Rules.PLAYER
	var king: bool = occupied and board[pos].id == "king"
	if a.x < 0: # stage A (or single-tile items)
		match key:
			"demote":
				return occupied and not king
			"promote":
				return own and not king and defs[board[pos].id].next != null
			"invert":
				return occupied and not king and defs.has("inv-" + board[pos].id)
			"air_strike":
				return enemy and not king
			"sniper":
				return enemy and not king and Rules.is_attacked(board, pos, Rules.PLAYER, defs)
			"extraction":
				return own
			"drone_strike", "bombing_run":
				return true
			"tactical_reposition", "decoy_swap", "forced_march":
				return occupied and not king
			"rapid_deployment":
				return own
	else: # stage B of a pair
		match key:
			"tactical_reposition":
				return not occupied and pos.distance_to(a) < 1.5 and pos != a
			"rapid_deployment":
				return not occupied
			"decoy_swap":
				return occupied and not king and pos != a
			"forced_march":
				var d := pos - a
				if pos == a or occupied:
					return false
				var steps := maxi(absi(d.x), absi(d.y))
				if steps > 3 or (d.x != 0 and d.y != 0 and absi(d.x) != absi(d.y)):
					return false
				var step := d.sign()
				for s in range(1, steps): # path must be clear
					if board.has(a + step * s):
						return false
				return true
	return false
