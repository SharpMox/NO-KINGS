## issue 85: the cloud leaderboard.
##
## User ruling (2026-08-31): leaderboards go cloud, **and the local board stays
## as the offline view**. It is not replaced. So there are two views over the
## same data: local always available, cloud when reachable.
##
## WHY THIS DOES NOT REUSE `CloudSave.resolve()` — the issue asked it to, and it
## would be wrong. `resolve()` picks ONE SIDE WHOLESALE, which is right for a
## run state (there is one true current run) and destructive for a leaderboard
## (a board is a SET of finished runs, and picking a side silently deletes the
## other device's real scores). Highest-wins still governs, but applied per
## entry rather than per payload: union both boards, then keep the top N.
##
## That is the same monotonic principle — nothing ever regresses, no timestamps,
## no three-way merge — expressed for a set instead of a state. Recorded here
## because the issue's "reuse the rule" instruction is the tempting wrong answer.

const CloudSave := preload("res://scripts/cloud_save.gd")

const KEY := "scores"
const CAP := 10


## Union of two boards, best first, capped. Order-independent and idempotent:
## merge(a, b) == merge(b, a), and merging a board with itself changes nothing.
static func merge(a: Array, b: Array) -> Array:
	var seen := {}
	var out: Array = []
	for board in [a, b]:
		for e in board:
			if not (e is Dictionary) or not e.has("score"):
				continue
			# an identical run on both devices is ONE entry, not two — the same
			# board synced to the cloud and back must not duplicate itself
			var id := "%d/%d/%d" % [int(e.get("score", 0)), int(e.get("wave", 0)),
				int(e.get("kings", 0))]
			if seen.has(id):
				continue
			seen[id] = true
			out.append(e)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return int(x.get("score", 0)) > int(y.get("score", 0)))
	return out.slice(0, CAP)


## Games History is a set too — the same union rule as merge() above, keyed by
## the WHOLE entry: an identical summary on two devices is one run seen twice
## through the mirror, not two runs. Local order is kept and cloud-only entries
## append after it; entries carry no timestamp, so true interleaving is
## unknowable and not worth inventing.
static func merge_history(a: Array, b: Array) -> Array:
	var seen := {}
	var out: Array = []
	for board in [a, b]:
		for e in board:
			var id := JSON.stringify(e)
			if seen.has(id):
				continue
			seen[id] = true
			out.append(e)
	# 50 = Economy.HISTORY_CAP, not preloaded here (economy drags in the whole
	# gameplay chain). Writers re-cap on every record, so drift in this literal
	# only ever affects the size of one synced file, never what is kept.
	return out.slice(0, 50)


## The cloud board, or [] when there is no cloud to reach. An unreachable
## leaderboard is the NORMAL case (desktop, offline, a platform with no plugin
## yet) — never an error state, and never a reason to hide the local board.
static func cloud() -> Array:
	var env: Variant = CloudSave.pull(KEY)
	if not (env is Dictionary) or not env.has("data"):
		return []
	return env.data if env.data is Array else []


## What the Scores screen shows: local unioned with the cloud when it is there,
## and exactly the local board when it is not.
static func board(local: Array) -> Array:
	return merge(local, cloud())


## True when a cloud board could be read at all — drives the status line, so
## the player can tell "no cloud scores yet" from "not signed in / offline".
static func cloud_available() -> bool:
	return CloudSave.backend.is_available()
