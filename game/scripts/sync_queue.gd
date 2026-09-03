## issue 84: the offline push queue.
##
## User ruling (2026-08-31): offline while signed in **plays normally and
## queues for sync**. So a push that cannot reach the cloud is not an error and
## must not prompt — it is deferred.
##
## Persisted, not in-memory: the queue has to survive the app being killed,
## which is the ordinary way a mobile game ends. An in-memory queue would lose
## exactly the sessions it exists to protect.
##
## Keyed by save key, holding the LATEST payload per key rather than a log.
## Two offline sessions of the same run do not need pushing twice — the second
## payload supersedes the first, and a log would just replay stale states in
## order to arrive at the same place.

const QUEUE_PATH := "user://sync_queue.json"


static func _read() -> Dictionary:
	if not FileAccess.file_exists(QUEUE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUEUE_PATH))
	return parsed if parsed is Dictionary else {}


static func _write(q: Dictionary) -> void:
	# Null-checked like every other write. Reachable on Android now that a
	# blocked sync enqueues; losing the queue costs a deferred push the next
	# sync re-sends, where crashing costs the session.
	var f := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("sync queue: could not write %s (error %d)"
			% [QUEUE_PATH, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(q))


static func enqueue(key: String, payload: Variant) -> void:
	var q := _read()
	q[key] = payload
	_write(q)


static func pending() -> Dictionary:
	return _read()


static func size() -> int:
	return _read().size()


static func is_empty() -> bool:
	return _read().is_empty()


static func clear() -> void:
	if FileAccess.file_exists(QUEUE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QUEUE_PATH))


## Push everything queued through `pusher`, dropping only what it accepts.
##
## A partial failure must NOT lose the rest of the queue — that is the whole
## risk in a drain, and the reason this keeps failures rather than clearing
## wholesale on the first success. Returns how many entries were sent.
static func drain(pusher: Callable) -> int:
	var q := _read()
	if q.is_empty():
		return 0
	var sent := 0
	var kept := {}
	for key in q:
		if bool(pusher.call(key, q[key])):
			sent += 1
		else:
			kept[key] = q[key]
	if kept.is_empty():
		clear()
	else:
		_write(kept)
	return sent
