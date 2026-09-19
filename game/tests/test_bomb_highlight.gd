extends SceneTree
## NO-122: the bomb blast preview must highlight the exact tiles _detonate
## would destroy — asserts the returned tile SET from _bomb_highlight_tiles,
## not a flag (CLAUDE.md, "tests that pass for the wrong reason": "assert the
## observable consequence, never the flag that was just written").
##
## Boots the "NO-122: bomb blast + drone strike zone preview" scenario
## (data/scenarios.gd): a bomb-carrying queen at (3,3), an enemy pawn at
## (4,4) it can legally capture. Drives selection through the real
## `_on_tile_clicked`, the same function a board tap calls, so this can't
## drift from what a player's click actually does.
## Run headless:  godot --headless --path game -s tests/test_bomb_highlight.gd

const GameScript := preload("res://scripts/game.gd")
const Scenarios := preload("res://data/scenarios.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func tile_set(arr: Array) -> Dictionary:
	var out := {}
	for t in arr:
		out[t] = true
	return out


## NO-122: how many blast zones cover each tile — _bomb_highlight_tiles()
## keeps duplicates (one entry per zone) precisely so this can be counted
## from the array _draw() itself iterates, rather than a second dedicated
## return shape.
func tile_counts(arr: Array) -> Dictionary:
	var out := {}
	for t in arr:
		out[t] = out.get(t, 0) + 1
	return out


func _init() -> void:
	var matches: Array = Scenarios.all().filter(
		func(e: Dictionary) -> bool: return e.name.begins_with("NO-122: bomb blast"))
	check(matches.size() == 1, "exactly one NO-122 bomb-preview scenario exists")
	if matches.size() != 1:
		quit(1)
		return
	var cfg: Dictionary = matches[0].cfg.duplicate()
	cfg.seed = 1
	GameScript.next_config = cfg
	GameScript.is_scenario = true
	var game: Node2D = load("res://scenes/Game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	# Nothing selected yet: no blast preview.
	check(game._bomb_highlight_tiles().is_empty(), "no selection -> no highlight")

	# Select the bomb queen at (3,3). Selecting it also computes legal_dests
	# (Rules.moves_for), which already includes the capture at (4,4) — so the
	# highlight set is the UNION of the piece's own ring (it could stay put
	# and be captured there) and that capture destination's ring (blast
	# lands at the destination, not the origin): 9 + 9 tiles, 4 shared.
	game._on_tile_clicked(Vector2i(3, 3))
	check(game.legal_dests.has(Vector2i(4, 4)), "queen's legal_dests include the capturable pawn")
	var expect := tile_set([
		Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
		Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
		Vector2i(5, 3), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 4), Vector2i(5, 5)])
	var got := tile_set(game._bomb_highlight_tiles())
	var matches_expected := got.size() == expect.size()
	for k in expect:
		matches_expected = matches_expected and got.has(k)
	check(matches_expected,
		"selecting the bomb queen highlights its own ring + the capture ring (got %s)" % [got.keys()])

	# NO-122 cross-hatch: exactly the 4 tiles inside BOTH 3x3 rings (the
	# queen's own square at 3,3 and its capture ring at 4,4 overlap on their
	# shared corner) should read as multiply covered — the observable
	# consequence _draw's cross-hatch is keyed on, not a flag.
	var expect_multi := tile_set([
		Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)])
	var counts := tile_counts(game._bomb_highlight_tiles())
	var multi := {}
	for k in counts:
		if counts[k] > 1:
			multi[k] = true
	var multi_matches := multi.size() == expect_multi.size()
	for k in expect_multi:
		multi_matches = multi_matches and multi.has(k)
	check(multi_matches,
		"exactly the 4 shared tiles are covered by more than one blast zone (got %s)" % [multi.keys()])

	# Deselect: the preview clears.
	game._clear_selection()
	check(game._bomb_highlight_tiles().is_empty(), "deselecting clears the highlight")

	game.queue_free()
	await process_frame

	print("---")
	if fails == 0:
		print("ALL BOMB-HIGHLIGHT CHECKS OK")
	quit(1 if fails > 0 else 0)
