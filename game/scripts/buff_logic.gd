## Piece Buffs — pure logic over a board piece Dictionary, no nodes (like
## item_logic.gd). Buffs ride on the piece as `buffs`, an Array of
## {"key": String} Dictionaries, so ADR-0002 carries them through Stock and
## the save with no schema of its own.
##
## `buff` (singular) is a different thing entirely — the box-carrier flag on a
## spawned enemy. Don't conflate them.

const Items := preload("res://data/items.gd")


static func of(piece: Dictionary) -> Array:
	return piece.get("buffs", [])


static func has(piece: Dictionary, key: String) -> bool:
	for b in of(piece):
		if b.key == key:
			return true
	return false


static func add(piece: Dictionary, key: String) -> void:
	var list: Array = of(piece).duplicate()
	list.append({"key": key})
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
	return has(victim, "shield")


## Score multiplier the attacker applies to this capture.
static func capture_multiplier(attacker: Dictionary) -> int:
	return 2 if has(attacker, "critical") else 1
