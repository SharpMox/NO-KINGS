## Merging: pair validation, partner highlighting, and the merge commit —
## drives the live game node `g` (split out of game.gd; the confirmation
## dialog stays with the modals).

const Rules := preload("res://scripts/rules.gd")
const Economy := preload("res://scripts/economy.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")


## The piece the current selection would merge FROM: an armed pool stack
## (placing_id, stock or captured), a mid-drag stack, or the selected board
## piece. "" when nothing is selected.
static func origin_id(g) -> String:
	if g.pool_drag_id != "":
		return g.pool_drag_id
	if g.placing_id != "":
		return g.placing_id
	if g.selected.x >= 0 and g.board.has(g.selected) and g.board[g.selected].owner == Rules.PLAYER:
		return g.board[g.selected].id
	return ""


## Valid pair under the current tariffs (Regulation blocks pawn merges).
static func pair_ok(g, a: String, b: String) -> bool:
	if not Economy.merge_ok(g, a, b):
		return false
	return Rules.merge_result([a, b], g.defs, g.fusions) != ""


## Ids that complete a merge with the current selection — drives the gold
## highlights on pool stacks and board pieces. Empty outside the player turn,
## with no selection, or with no action left to pay for the merge.
static func partner_ids(g) -> Dictionary:
	var out := {}
	var origin := origin_id(g)
	if origin == "" or g.state != g.State.PLAYER_TURN or g.actions_left <= 0:
		return out
	var all: Array = g._pool()
	for pos in g._player_pieces():
		all.append(g.board[pos].id)
	var counts := {}
	for id in all:
		counts[id] = counts.get(id, 0) + 1
	for id in all:
		if id == origin and counts[id] < 2:
			continue # a self-pair needs a second copy
		if pair_ok(g, origin, id):
			out[id] = true
	return out


## Merge entry point: validates the pair, then asks for confirmation showing
## the result piece (the bot skips straight to the commit). Cancel keeps the
## origin selected so another partner can be picked.
static func do_merge(g, a: Variant, b: Variant) -> void:
	if g.state != g.State.PLAYER_TURN or g.actions_left <= 0:
		return
	var ids := []
	for ref in [a, b]:
		ids.append(g.board[ref].id if ref is Vector2i else ref.id)
	if not pair_ok(g, ids[0], ids[1]):
		return
	if g.autoplay:
		return commit_merge(g, a, b)
	g.pending_merge = [a, b]
	g.modals.show_merge_confirm(ids[0], ids[1], Rules.merge_result(ids, g.defs, g.fusions))


## The result lands on the LATER board tile (grilled 2026-07-02: drop/tap
## target wins); pool-only merges go to Stock.
static func commit_merge(g, a: Variant, b: Variant) -> void:
	if g.state != g.State.PLAYER_TURN or g.actions_left <= 0:
		return
	var ids := []
	for ref in [a, b]:
		ids.append(g.board[ref].id if ref is Vector2i else ref.id)
	if not pair_ok(g, ids[0], ids[1]):
		return
	var result := Rules.merge_result(ids, g.defs, g.fusions)
	g.actions_left -= 1
	g.turn_action_count += 1
	var result_tile := Vector2i(-1, -1)
	for ref in [a, b]:
		if ref is Vector2i:
			result_tile = ref # later selections win
			g.board.erase(ref)
		else: # a unit from a stack: remove one copy by value — the exact entry,
			# so a stateful copy is consumed and its state discarded (ADR-0002)
			(g.captured if ref.cap else g.stock).erase(ref.get("entry", ref.id))
	var stock_index := -1
	if result_tile.x >= 0:
		g.board[result_tile] = {"id": result, "owner": Rules.PLAYER}
		g.fx_at = g._tile_px(result_tile) + Vector2(g.tile, g.tile) / 2
	else:
		g.stock.append(result)
		stock_index = g.stock.size() - 1 # captured now — a handler appending its
			# own Stock grant during on_rank_up (Bigfoot Toenail Clipping) must
			# not shift which entry Holy Grail Coaster's stock case converts
		g.fx_at = Vector2((g.hud.pool_box.get_parent() as Control).get_global_rect().get_center())
	if ids[0] == ids[1]: # a same-id merge advances the promotion chain — a Rank
		# Up, distinct from a Fusion of two different pieces (artefact hook 19).
		# result_tile.x < 0 means the result landed in Stock, not the board —
		# handlers that grant something onto the piece itself branch on that,
		# reading `stock_index` rather than "the last Stock entry" (see above).
		ArtefactHooks.run(g, "on_rank_up",
			{"pos": result_tile, "old_id": ids[0], "id": result, "stock_index": stock_index})
	Economy.charge(g, "fuse_cost")
	g.placing_id = ""
	g.placing_cap = false
	g._clear_selection()
	if g.actions_left == 0 or g._board_cleared(): # last action spent on the merge
		return g._on_pass()
	g._refresh()
