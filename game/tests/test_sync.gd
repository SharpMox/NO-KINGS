extends SceneTree
## issue 84: offline play queues for sync; highest wave wins on conflict.
##
## The two assertions that matter are the ones an implementation can pass while
## being wrong: a drain that loses the rest of the queue on a partial failure,
## and a "highest wins" that only ever discards the REMOTE side.

const CloudSave := preload("res://scripts/cloud_save.gd")
const SyncQueue := preload("res://scripts/sync_queue.gd")
const Memory := preload("res://scripts/cloud/cloud_backend_memory.gd")
const Noop := preload("res://scripts/cloud/cloud_backend_noop.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("ok: ", label)
	else:
		fails += 1
		print("FAIL: ", label)


func _init() -> void:
	SyncQueue.clear()
	Memory.reset()

	# --- offline: play normally, queue for sync ---
	CloudSave.backend = Noop # desktop: is_available() false, i.e. "offline"
	check(not CloudSave.push("run", {"wave": 12}),
		"an offline push reports that it did not reach the cloud")
	check(SyncQueue.size() == 1, "...and queues it instead of dropping it")
	CloudSave.push("scores", {"best": 500})
	check(SyncQueue.size() == 2, "a second key queues alongside the first")

	# the same key twice keeps the LATEST, not a log — replaying stale states
	# in order just arrives at the same place more slowly
	CloudSave.push("run", {"wave": 19})
	check(SyncQueue.size() == 2, "re-queueing a key supersedes rather than appends")
	check(int(SyncQueue.pending()["run"].wave) == 19, "and keeps the newer payload")

	# --- the queue survives a kill ---
	# read straight off disk: an in-memory queue would lose exactly the
	# sessions this exists to protect
	check(FileAccess.file_exists(SyncQueue.QUEUE_PATH), "the queue is on disk, not in memory")
	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(SyncQueue.QUEUE_PATH))
	check(raw is Dictionary and raw.has("run") and raw.has("scores"),
		"a relaunch would find both entries still pending")

	# --- reconnect: drain ---
	CloudSave.backend = Memory
	check(CloudSave.drain_queue() == 2, "reconnecting drains every queued push")
	check(SyncQueue.is_empty(), "a fully drained queue is emptied")
	check(int(Memory.pull("run").data.wave) == 19, "the newest run payload reached the cloud")
	check(Memory.pull("scores") != null, "and so did the other key")
	check(CloudSave.drain_queue() == 0, "draining an empty queue is a no-op")

	# --- a partial failure must not lose the rest ---
	SyncQueue.clear()
	SyncQueue.enqueue("a", {"n": 1})
	SyncQueue.enqueue("b", {"n": 2})
	SyncQueue.enqueue("c", {"n": 3})
	var sent := SyncQueue.drain(func(key: String, _payload: Variant) -> bool:
		return key != "b") # "b" fails, the others succeed
	check(sent == 2, "a drain sends what it can")
	var left := SyncQueue.pending()
	check(left.size() == 1 and left.has("b"),
		"the failed entry is KEPT and the successful ones are dropped")
	check(int(left["b"].n) == 2, "the kept entry still carries its payload")

	# --- highest wave wins, in BOTH directions ---
	# An implementation that only ever discards the REMOTE side passes a naive
	# test and is wrong in exactly the case that matters: this device being the
	# one that is behind.
	var remote_ahead := {"ts": 1, "data": {"wave": 40, "who": "remote"}}
	var won: Variant = CloudSave.resolve(9999, {"wave": 12, "who": "local"}, remote_ahead)
	check(won.who == "remote",
		"the REMOTE device wins when it reached a deeper wave — even with a newer local file")

	var remote_behind := {"ts": 9999, "data": {"wave": 3, "who": "remote"}}
	won = CloudSave.resolve(1, {"wave": 30, "who": "local"}, remote_behind)
	check(won.who == "local",
		"the LOCAL device wins when it reached a deeper wave — even with a newer remote push")

	# equal waves fall through to last-write-wins rather than picking arbitrarily
	won = CloudSave.resolve(1, {"wave": 7, "who": "local"},
		{"ts": 5000, "data": {"wave": 7, "who": "remote"}})
	check(won.who == "remote", "equal waves fall back to last-write-wins")

	# payloads with no wave are not run states; the timestamp rule still governs
	won = CloudSave.resolve(1, {"best": 10, "who": "local"},
		{"ts": 5000, "data": {"best": 5, "who": "remote"}})
	check(won.who == "remote",
		"a payload with no wave (scores/history) still resolves by timestamp")

	SyncQueue.clear()
	Memory.reset()
	CloudSave.backend = Noop
	print("---")
	print("ALL SYNC CHECKS OK" if fails == 0 else "SYNC FAILURES: %d" % fails)
	quit(1 if fails > 0 else 0)
