## Merging: pair validation, partner highlighting, and the merge commit —
## drives the live game node `g` (split out of game.gd; the confirmation
## dialog stays with the modals).

const Rules := preload("res://scripts/rules.gd")
const Economy := preload("res://scripts/economy.gd")
const Tuning := preload("res://scripts/tuning.gd") # issue 98: MERGE_COST
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")
const Armies := preload("res://scripts/armies.gd")
const BuffLogic := preload("res://scripts/buff_logic.gd") # NO-191: inherited()
const Kings := preload("res://data/kings.gd") # banner pass: Genghis Khan's first bite


## The piece the current selection would merge FROM: an armed Stock stack
## (placing_id), a mid-drag Stock stack, or the selected board piece. "" when
## nothing is selected. Captured Stock is never any of them (2026-09-10).
static func origin_id(g) -> String:
	if g.pool_drag_id != "":
		return g.pool_drag_id
	if g.placing_id != "":
		return g.placing_id
	if g.selected.x >= 0 and g.board.has(g.selected) and g.board[g.selected].owner == Rules.PLAYER:
		return g.board[g.selected].id
	return ""


## Valid pair under the current King Power (Genghis Khan blocks every merge).
static func pair_ok(g, a: String, b: String) -> bool:
	if not Economy.merge_ok(g, a, b):
		return false
	return Rules.merge_result([a, b], g.defs, g.fusions) != ""


## issue 98: can the player pay for a merge right now? An Action AND the Gold.
##
## Close Ranks (The Muster) waives the ACTION ONLY. Its text is exactly "Merges
## cost no Action", so waiving the Gold too would be inventing a second effect
## the card does not claim — judgement call, no ruling, and the literal reading
## is the reversible one.
##
## No softlock risk (the standing check from issue 92's Great Wall): being
## unable to afford a merge never strands a run. Merging is optional — moves,
## captures and passing all stay available at 0 Gold — unlike a blocked DEPLOY,
## which can strand a player with an empty board.
static func can_afford_merge(g) -> bool:
	return g.gold >= Tuning.MERGE_COST


## Ids that complete a merge with the current selection — drives the gold
## highlights on pool stacks and board pieces. Empty outside the player turn,
## with no selection, or with no action left to pay for the merge.
static func partner_ids(g) -> Dictionary:
	var out := {}
	var origin := origin_id(g)
	if origin == "" or g.state != g.State.PLAYER_TURN \
			or (g.actions_left <= 0 and not Armies.merge_free(g)) \
			or not can_afford_merge(g): # Close Ranks (67)
		return out
	# STOCK ONLY, never g._pool(): a captured piece cannot merge (2026-09-10),
	# so highlighting it as a partner would offer an action that is refused.
	var all: Array = g.stock.duplicate()
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


## NO-185: `ref`'s buffs-bearing piece Dictionary — g.board[ref] for a board
## tile (a live piece Dictionary already), or `ref.entry` for a Stock/
## Captured pick (ADR-0002: a stateful entry IS a piece Dictionary; a bare id
## String carries no state). {} when there is none to show.
static func _piece_state(g, ref: Variant) -> Dictionary:
	if ref is Vector2i:
		return g.board[ref]
	var entry: Variant = ref.get("entry", null)
	return entry if entry is Dictionary else {}


## Merge entry point: validates the pair, then asks for confirmation showing
## the result piece (the bot skips straight to the commit). Cancel keeps the
## origin selected so another partner can be picked.
static func do_merge(g, a: Variant, b: Variant) -> void:
	if g.state != g.State.PLAYER_TURN or (g.actions_left <= 0 and not Armies.merge_free(g)) \
			or not can_afford_merge(g):
		return
	var ids := []
	for ref in [a, b]:
		ids.append(g.board[ref].id if ref is Vector2i else ref.id)
	if not pair_ok(g, ids[0], ids[1]):
		if Kings.power_is(g, "nomerge"): # Genghis Khan — the attempt is the
			# ACTION path; on_merge_check itself is a query hook (highlights)
			Kings.bite(g, "merge blocked")
		return
	if g.autoplay:
		return commit_merge(g, a, b)
	g.pending_merge = [a, b]
	var a_piece := _piece_state(g, a)
	var b_piece := _piece_state(g, b)
	var result_buffs := BuffLogic.inherited(a_piece, b_piece, g.buff_cap()) # NO-191
	g.modals.show_merge_confirm(ids[0], ids[1], Rules.merge_result(ids, g.defs, g.fusions),
		a_piece, b_piece, result_buffs) # NO-191: the buffs the result will inherit


## The result lands on the LATER board tile (grilled 2026-07-02: drop/tap
## target wins); pool-only merges go to Stock.
static func commit_merge(g, a: Variant, b: Variant) -> void:
	if g.state != g.State.PLAYER_TURN or (g.actions_left <= 0 and not Armies.merge_free(g)) \
			or not can_afford_merge(g):
		return
	var ids := []
	for ref in [a, b]:
		ids.append(g.board[ref].id if ref is Vector2i else ref.id)
	if not pair_ok(g, ids[0], ids[1]):
		return
	var result := Rules.merge_result(ids, g.defs, g.fusions)
	# NO-191: the union of both sources' catalogued Piece Buffs, capped —
	# read BEFORE the erase loop below discards both sources for real, same
	# reason consumed_states is snapshotted first. g.buff_cap() is the SAME
	# cap _apply_buff enforces (base + Abduction Probe + Communion) — never
	# a second computation of it (this repo's most-repeated bug shape).
	var result_buffs := BuffLogic.inherited(_piece_state(g, a), _piece_state(g, b), g.buff_cap())
	# issue 56: snapshot both consumed pieces' ADR-0002 Stock-shaped state
	# BEFORE the erase loop below discards it for real — Zapruder's
	# Director's Cut reads this back off the action_log entry to return both
	# pieces to Stock later, when they no longer exist anywhere else to read.
	var consumed_states := []
	var result_tile := Vector2i(-1, -1)
	var fx_sources := [] # NO-243: the board inputs, for the merge anim
	for ref in [a, b]:
		if ref is Vector2i:
			fx_sources.append({"px": g._tile_px(ref), "piece": g.board[ref].duplicate(true)})
			result_tile = ref # later selections win
			var state: Dictionary = g.board[ref].duplicate()
			state.erase("owner")
			consumed_states.append(state.id if state.size() == 1 else state)
			g.board.erase(ref)
		else: # a unit from a Stock stack: remove one copy by value — the exact
			# entry, so a stateful copy is consumed and its state discarded
			# (ADR-0002). `ref.entry` (or the bare id, same fallback the erase
			# below uses) is already Stock-shaped — no owner field to strip.
			# Stock is the only pool a unit can come from since 2026-09-10.
			consumed_states.append(ref.get("entry", ref.id))
			g.stock.erase(ref.get("entry", ref.id))
	if not Armies.merge_free(g): # Close Ranks (The Muster, issue 67)
		g.actions_left -= 1
	Economy.spend_gold(g, Tuning.MERGE_COST) # issue 98: Close Ranks waives the
		# Action, never the Gold — see can_afford_merge's header
	g._log_action("merge", {"pieces": consumed_states})
	var stock_index := -1
	if result_tile.x >= 0:
		var piece := {"id": result, "owner": Rules.PLAYER}
		if not result_buffs.is_empty():
			piece.buffs = result_buffs # NO-191
		g.board[result_tile] = piece
		g._add_merge_fx(fx_sources, result_tile) # NO-243: visual only
		g.fx_at = g._tile_px(result_tile) + Vector2(g.tile, g.tile) / 2
	else:
		# ADR-0002: bare id when the result carries no state to preserve,
		# same "duplicate, size()==1 means no extra state" idiom used
		# elsewhere for a Stock entry (see game.gd's _capture_to_stock).
		var entry := {"id": result}
		if not result_buffs.is_empty():
			entry.buffs = result_buffs # NO-191
		g.stock.append(entry.id if entry.size() == 1 else entry)
		stock_index = g.stock.size() - 1 # captured now — a handler appending its
			# own Stock grant during on_rank_up (Bigfoot Toenail Clipping) must
			# not shift which entry Holy Grail Coaster's stock case converts
		g.fx_at = Vector2((g.hud.drawers["stock"] as Control).get_global_rect().get_center())
	if ids[0] == ids[1]: # a same-id merge advances the promotion chain — a Rank
		# Up, distinct from a Fusion of two different pieces (artefact hook 19).
		# result_tile.x < 0 means the result landed in Stock, not the board —
		# handlers that grant something onto the piece itself branch on that,
		# reading `stock_index` rather than "the last Stock entry" (see above).
		ArtefactHooks.run(g, "on_rank_up",
			{"pos": result_tile, "old_id": ids[0], "id": result, "stock_index": stock_index})
	# Spare Organ Receipt (issue 53): every merge consumes exactly two pieces —
	# fires for a Rank Up too, not just a Fusion of two different pieces;
	# "a Fuse consumes two pieces" draws no distinction and both ids are
	# already in scope here regardless of which branch just ran above.
	ArtefactHooks.run(g, "on_fuse", {"a_id": ids[0], "b_id": ids[1]})
	Economy.charge(g, "fuse_cost",
		Economy.tariff_cut(Tuning.MERGE_COST, Tuning.TARIFF_FUSE_PCT))
	g.placing_id = ""
	g._clear_selection()
	if (g.actions_left == 0 and not Armies.merge_free(g)) or g._board_cleared():
		# last action spent on the merge — Close Ranks (67) never spends one,
		# so a free merge at 0 actions_left must not auto-pass; it just leaves
		# the Turn exactly as spent as it already was
		return g._on_pass()
	g._refresh()
