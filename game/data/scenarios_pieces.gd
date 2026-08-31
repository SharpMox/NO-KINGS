## issue 80: one hand-playable sandbox per piece (39), GENERATED.
##
## The most directly useful part of issue 73 — the fairy pieces are where a
## movement bug would actually hide, and this is the fastest way to look at one
## move by move.
##
## Derived from `data/pieces.json`, never hand-transcribed, so a piece added to
## the codex gets a sandbox with no edit here. Family grouping comes from the
## `next` field: following it forward gives the promotion chain, so inverting it
## gives each piece's chain ROOT, which is what the sections are named for.
##
## Ids, never display names — `dragon-horse` is the id and "Cardinal" the
## display name, the convention this repo has already tripped on (issue 58).
## Entries key on ids and only ever *show* the name.

const PIECES_PATH := "res://data/pieces.json"

## The subject sits mid-board with open lines in every direction: a slider boxed
## into a corner demonstrates nothing. Enemies are placed at three distances —
## adjacent, a short leap, and down an open file — so short-range leapers, mid
## leapers and riders all have something takeable without a template per class.
const SUBJECT := Vector2i(3, 4)
const ENEMIES := [["pawn", 4, 5], ["knight", 5, 6], ["rook", 3, 9]]
## Player pieces that are not the subject, so a sandbox cannot instantly end in
## starvation while the subject is being looked at.
const ESCORT := [["pawn", 0, 1, 0], ["pawn", 0, 6, 0]]


## Loaded on first use, not at class-load: a static var whose initializer reads
## the filesystem resolves to null here, and iterating that is a silent empty
## scenario list rather than an error at the point of the mistake.
static var _catalog: Dictionary = {}


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(PIECES_PATH))
		assert(parsed is Dictionary, "pieces.json did not parse as a Dictionary")
		_catalog = parsed
	return _catalog


## The id this one promotes into, or "" — several entries carry an explicit
## `"next": null` rather than omitting the key, so `.get("next", "")` hands back
## the null instead of the default and a typed String assignment fails.
static func _next_of(cat: Dictionary, id: String) -> String:
	var nxt: Variant = cat[id].get("next")
	return nxt if nxt is String and cat.has(nxt) else ""


## id -> the id at the head of its promotion chain (itself, if nothing promotes
## into it). Built by inverting `next`.
static func _roots() -> Dictionary:
	var cat := catalog()
	var parent := {}
	for id in cat:
		var nxt := _next_of(cat, id)
		if nxt != "":
			parent[nxt] = id
	var roots := {}
	for id in cat:
		var cur: String = id
		var guard := 0
		while parent.has(cur) and guard < 16: # guard: a cycle in the data must
			cur = parent[cur]                 # not hang the menu build
			guard += 1
		roots[id] = cur
	return roots


static func all() -> Array:
	var out: Array = []
	var cat := catalog()
	var roots := _roots()
	for id in cat:
		var e: Dictionary = cat[id]
		# A piece in a promotion chain is filed under that chain's ROOT, which
		# is what makes the sections mean "Family". A piece that promotes into
		# nothing and is promoted into by nothing has no Family, and filing each
		# one under its own name would make 14 singleton sections — which
		# menu.gd folds into "Other", mixing them in with unrelated one-offs.
		# One "Standalone" section keeps them together and keeps "Other" honest.
		var root: String = roots[id]
		var fam := "Standalone"
		if root != id or _next_of(cat, id) != "":
			fam = cat[root].get("name", "Standalone")
		var cfg := {"gold": 300, "score": 500, "seed": abs(hash(id))}
		if id == "king":
			# the player never owns a King; use the shipped win-screen shape so
			# this entry shows the King as what it actually is — the boss
			cfg["board"] = [["queen", 0, 3, 8], ["king", 1, 3, 10]]
			cfg["wave"] = 50
		else:
			var board: Array = [[id, 0, SUBJECT.x, SUBJECT.y]] + ESCORT.duplicate(true)
			for en in ENEMIES:
				board.append([en[0], 1, en[1], en[2]])
			cfg["board"] = board
			# two of the subject (and two of what it promotes into, when there
			# is one) so the merge that walks the chain is reachable by hand
			var stock: Array = [id, id]
			var nxt := _next_of(cat, id)
			if nxt != "":
				stock += [nxt, nxt]
			cfg["stock"] = stock
		out.append({"name": "Piece %s: %s" % [fam, e.get("name", id)], "cfg": cfg})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.name < b.name)
	return out
