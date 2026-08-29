## Item targeting rules — pure logic over the board Dictionary, no nodes
## (split out of game.gd; item effects and UI stay there).

const Rules := preload("res://scripts/rules.gd")
const Tuning := preload("res://scripts/tuning.gd")


## Base of a piece's promotion chain: walk `next` backwards. Returns `id`
## itself when nothing promotes into it (Demote then has no effect).
static func chain_base(defs: Dictionary, id: String) -> String:
	for k: String in defs:
		if defs[k].next == id:
			return chain_base(defs, k)
	return id


## Held Item capacity (issue 53, user ruling) — base 3, +3 per held Area 51
## Parking Permit, additive per copy (the header's stacking rule). A
## structural read off g.artefacts, not a hook — same pattern as
## Shop._extra_item_slots/_credit (shop.gd), Box's own standing-rule reads.
static func cap(g) -> int:
	var permits := 0
	for t in g.artefacts:
		if t.key == "area-51-parking-permit":
			permits += 1
	return Tuning.ITEM_CAP_BASE + 3 * permits


## Room for one more Item right now.
static func has_room(g) -> bool:
	return g.items.size() < cap(g)


## Grant one Item if there's room; refuses (drops it) when the inventory is
## full — a full inventory REFUSES the acquisition (issue 53 ruling: simpler,
## matches "capacity"), rather than forcing a discard. Every Item-granting
## path (Box pick, Artefact grant, Yalta Cocktail Napkin's own pick) routes
## new grants through here; the Shop instead keeps a full-capacity Item
## unbuyable via Shop.can_buy(), so that path never reaches this refusal at
## all. Returns whether it landed.
static func grant(g, item: Dictionary) -> bool:
	if not has_room(g):
		return false
	g.items.append(item)
	return true


static func stage_targets(board: Dictionary, defs: Dictionary, key: String, a: Vector2i,
		moved: Array[Vector2i] = [] as Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in Tuning.BOARD_W:
		for y in Tuning.BOARD_H:
			var pos := Vector2i(x, y)
			if tile_valid(board, defs, key, a, pos, moved):
				out.append(pos)
	return out


static func tile_valid(board: Dictionary, defs: Dictionary, key: String, a: Vector2i, pos: Vector2i,
		moved: Array[Vector2i] = [] as Array[Vector2i]) -> bool:
	var occupied := board.has(pos)
	var enemy: bool = occupied and board[pos].owner == Rules.ENEMY
	var own: bool = occupied and board[pos].owner == Rules.PLAYER
	var king: bool = occupied and board[pos].id == "king"
	if a.x < 0: # stage A (or single-tile items)
		match key:
			"blitz": # any own piece (Notion 2026-08-28 rework) — King excluded,
					# same as every other targeted item
				return own and not king
			"buff_box": # GDD: ally or enemy — the choice is the point
				return occupied and not king
			"demote":
				return occupied and not king \
					and chain_base(defs, board[pos].id) != board[pos].id
			"promote":
				return own and not king and defs[board[pos].id].next != null
			"invert":
				return occupied and not king and defs.has("inv-" + board[pos].id)
			"air_strike":
				return enemy and not king
			"sniper":
				return enemy and not king and Rules.is_attacked(board, pos, Rules.PLAYER, defs)
			"asset_recovery":
				return occupied and not king
			"radar_jamming": # any Piece Buff — the box-carrier flag it also
				# used to strip is gone (issue 47)
				return occupied and not board[pos].get("buffs", []).is_empty()
			"tactical_reposition", "decoy_swap":
				return occupied and not king
			"rapid_deployment":
				return own
			"drone_strike": # any tile anchors the 3x3
				return true
			"extraction": # multi: any of your board pieces
				return own
	else: # stage B of a pair
		match key:
			"tactical_reposition":
				return not occupied and pos.distance_to(a) < 1.5 and pos != a
			"rapid_deployment": # Deploy tiles: zone rows or touching an ally
				return Rules.placement_tiles(board).has(pos)
			"decoy_swap":
				return occupied and not king and pos != a
			"drone_strike": # preview: the 3x3 around the anchor, on-board part
				return maxi(absi(pos.x - a.x), absi(pos.y - a.y)) <= 1
	return false
