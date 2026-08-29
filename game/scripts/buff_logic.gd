## Piece Buffs — pure logic over a board piece Dictionary, no nodes (like
## item_logic.gd). Buffs ride on the piece as `buffs`, an Array of
## {"key": String} Dictionaries, so ADR-0002 carries them through Stock and
## the save with no schema of its own.
##
## `buff` (singular) used to be a different thing entirely — the box-carrier
## flag on a spawned enemy, removed with the carrier (issue 47). Nothing sets
## or reads it live any more; save_config.gd still parses the legacy string
## for an old save's board piece, harmlessly inert. Still worth not conflating
## with `buffs` (plural) above if you see it in an old save or scenario.

const Items := preload("res://data/items.gd")


static func of(piece: Dictionary) -> Array:
	return piece.get("buffs", [])


static func has(piece: Dictionary, key: String) -> bool:
	for b in of(piece):
		if b.key == key:
			return true
	return false


## `turns` marks a timed buff: it ticks down at the start of each player turn
## and is dropped at 0. Dormant buffs carry no `turns` and wait forever.
static func add(piece: Dictionary, key: String, turns := 0) -> void:
	var list: Array = of(piece).duplicate()
	var b := {"key": key}
	if turns > 0:
		b["turns"] = turns
	list.append(b)
	piece.buffs = list


## Buffs measured in the OWNER's own turns rather than in player turns, so
## they age on a different boundary (see tick_side).
const SIDE_TIMED := ["stunned"]


## Age the player-turn-timed buffs (Slow, Aura, Smog), dropping the expired.
static func tick(piece: Dictionary) -> void:
	_age(piece, false)


## Age the owner-turn-timed buffs (Stun). Called at the end of that side's own
## turn, so a stunned piece misses its own turns rather than the player's.
static func tick_side(piece: Dictionary) -> void:
	_age(piece, true)


static func _age(piece: Dictionary, side_timed: bool) -> void:
	var list := []
	for b in of(piece):
		if not b.has("turns") or SIDE_TIMED.has(b.key) != side_timed:
			list.append(b) # not this cadence — leave it alone
			continue
		var left: int = int(b.turns) - 1
		if left > 0:
			list.append({"key": b.key, "turns": left})
	if list.is_empty():
		piece.erase("buffs")
	else:
		piece.buffs = list


## Fire-and-forget: drop the first buff with this key. Dormant buffs are
## consumed the moment their trigger resolves.
static func consume(piece: Dictionary, key: String) -> void:
	var list: Array = of(piece).duplicate()
	for i in list.size():
		if list[i].key == key:
			list.remove_at(i)
			break
	if list.is_empty():
		piece.erase("buffs")
	else:
		piece.buffs = list


static func clear(piece: Dictionary) -> void:
	piece.erase("buffs")


static func name_of(key: String) -> String:
	for b in Items.PIECE_BUFFS:
		if b.key == key:
			return b.name
	return key


## A capture attempt on `victim` that an effect stops. Returns true when the
## attempt is repelled — the attacker does not move and nothing is captured
## (GDD Pieces & Movement: a repelled attacker returns to its starting tile).
## Shield is the first carrier; Reflect will hook the same call.
static func repels_capture(victim: Dictionary) -> bool:
	return has(victim, "shield") or has(victim, "reflect")


## Score multiplier the attacker applies to this capture. Critical is the
## attacker's own one-shot; Aura doubles for any ally standing beside it.
static func capture_multiplier(board: Dictionary, from: Vector2i) -> int:
	var attacker: Dictionary = board[from]
	if has(attacker, "critical") or _adjacent_source(board, from, "aura", true):
		return 2
	return 1


## "Reduced movement range" — ruled 2026-08-28: the piece moves and captures
## exactly like a Pawn. Slow is the piece's own debuff; Smog is projected onto
## adjacent enemies by whoever carries it.
static func moves_of(board: Dictionary, from: Vector2i, defs: Dictionary) -> Array:
	var piece: Dictionary = board[from]
	if has(piece, "slow") or _adjacent_source(board, from, "smog", false):
		return defs["pawn"].moves
	return defs[piece.id].moves


## Is a piece carrying `key` standing next to `from`? `same_side` picks whether
## we are looking for an ally (Aura) or an enemy (Smog).
static func _adjacent_source(board: Dictionary, from: Vector2i, key: String, same_side: bool) -> bool:
	var owner: int = board[from].owner
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var at := from + Vector2i(dx, dy)
			if not board.has(at) or not has(board[at], key):
				continue
			if (board[at].owner == owner) == same_side:
				return true
	return false


## A repelled capture that counter-attacks: Reflect stops the attempt, then
## the defender takes the attacker's tile and captures it instead.
static func reflects_capture(victim: Dictionary) -> bool:
	return has(victim, "reflect")


## Multicapture (ruled 2026-08-28): the capture also takes ONE enemy standing
## beside the piece just captured. Picks the most valuable neighbour so the
## trigger needs no extra targeting step. Returns (-1,-1) when nothing adjoins.
static func multicapture_target(board: Dictionary, at: Vector2i, owner: int, defs: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_value := -1
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var pos := at + Vector2i(dx, dy)
			if not board.has(pos) or board[pos].owner == owner:
				continue
			if board[pos].id == "king": # boss piece is never collateral
				continue
			var v: int = int(defs[board[pos].id].value)
			if v > best_value:
				best_value = v
				best = pos
	return best
