## Cloud-save sync layer (issue 12 — accounts & cloud saves). Mirrors the
## local user:// saves (run save, high scores, games history) to a platform
## save backend — Game Center/iCloud on iOS, Play Games Saved Games on
## Android. The local file is always the source of truth; syncing only
## overwrites it when the cloud copy resolves newer (last-write-wins — fine
## for a single-player roguelike, per the issue's Decision). No backend, no
## Firebase/Supabase; the leaderboard stays local (divergence #9).
##
## STATUS — local half only; see the issue's Outcome for the full picture:
##   * cloud_backend_noop.gd (desktop) is real and finished: there is no
##     cloud on desktop, so it correctly does nothing.
##   * cloud_backend_play_games.gd (Android, issue 86) and
##     cloud_backend_ios.gd (iOS, issue 87) are real; each pairs with a bridge
##     autoload that owns its native plugin.
##   * cloud_backend_memory.gd is dev/test-only; production never selects it.
##
## Backend contract (static funcs called via the preloaded script, same
## no-instantiation idiom as SaveConfig/Economy/Settings):
##   is_available() -> bool
##   push(key: String, envelope: Dictionary) -> bool
##   pull(key: String) -> Variant   # envelope Dictionary, or null
##   account_id() -> String         # issue 83: stable account id, "" if none

const SyncQueue := preload("res://scripts/sync_queue.gd")
const Noop := preload("res://scripts/cloud/cloud_backend_noop.gd")
const CloudIos := preload("res://scripts/cloud/cloud_backend_ios.gd")
const PlayGames := preload("res://scripts/cloud/cloud_backend_play_games.gd")

## Swappable by tests (cloud_backend_memory.gd); production code never
## reassigns it — the platform switch below picks it once at load.
static var backend = _default_backend()


static func _default_backend():
	match OS.get_name():
		"iOS":
			return CloudIos
		"Android":
			return PlayGames
		_:
			return Noop


## Cloud-only envelope: a save's payload plus the timestamp last-write-wins
## needs. Never written into the local save files, which keep their existing
## shape — test_save.gd's exact save/load/save round-trip depends on that.
static func _envelope(payload: Variant) -> Dictionary:
	return {"ts": Time.get_unix_time_from_system(), "data": payload}


## Push one local save's parsed payload up to the cloud. Silently no-ops
## when the backend is unavailable — desktop, or a platform stub with no
## plugin yet — offline play must never block or fail on this.
static func push(key: String, payload: Variant) -> bool:
	if not backend.is_available():
		# issue 84: unreachable is not a failure, it is deferred. Offline play
		# while signed in must never block or prompt — the push is queued and
		# drained on reconnect.
		SyncQueue.enqueue(key, payload)
		return false
	return backend.push(key, _envelope(payload))


## issue 84: send everything queued while offline. Safe to call at any boot —
## a no-op with an empty queue or an unavailable backend. A push that fails
## mid-drain keeps its queue entry; the rest of the queue is not lost with it.
static func drain_queue() -> int:
	if not backend.is_available():
		return 0
	return SyncQueue.drain(func(key: String, payload: Variant) -> bool:
		return backend.push(key, _envelope(payload)))


## Pull the cloud envelope for a named save, or null if there is none / the
## backend is unavailable.
static func pull(key: String) -> Variant:
	if not backend.is_available():
		return null
	return backend.pull(key)


## Last-write-wins conflict resolution. `local_ts` is the local file's mtime
## (0 when there is no local file); `local_payload` its parsed contents (null
## when there is no local file); `remote` is whatever pull() returned. A
## missing local file takes the cloud copy if there is one (first launch on
## a new device); otherwise ties, and a missing/malformed remote, both keep
## local — it is the source of truth, the cloud is only a mirror.
static func resolve(local_ts: int, local_payload: Variant, remote: Variant) -> Variant:
	if not (remote is Dictionary) or not remote.has("data") or not remote.has("ts"):
		return local_payload
	# issue 84 — HIGHEST WAVE WINS, ahead of the timestamp. The user's rule for
	# the same account on two devices, and it works precisely because progress
	# here is monotonic: deepest-wave only ever increases, so "highest wins" is
	# well-defined and needs no timestamps, no three-way merge and no clock
	# agreement between devices. Do not add one.
	#
	# Falls through to last-write-wins when either side carries no wave (scores
	# and history are not run states), or when the waves are equal.
	var local_wave := _wave_of(local_payload)
	var remote_wave := _wave_of(remote.data)
	if local_wave >= 0 and remote_wave >= 0 and local_wave != remote_wave:
		return local_payload if local_wave > remote_wave else remote.data
	if local_payload != null and int(remote.ts) <= local_ts:
		return local_payload
	return remote.data


## The wave a payload reached, or -1 when it is not a run state at all.
static func _wave_of(payload: Variant) -> int:
	if not (payload is Dictionary) or not payload.has("wave"):
		return -1
	return int(payload.wave)


## Full mirror step for one on-disk save at `path`: pull the cloud copy,
## resolve it against local by last-write-wins, write the winner back to
## disk if the cloud copy won, then push the (possibly just-updated) local
## copy back up so the mirror stays current. End-to-end no-op while the
## backend is unavailable — every desktop run today, and iOS/Android until
## their native plugin lands.
static func sync_file(key: String, path: String, merger := Callable()) -> void:
	if not backend.is_available():
		return
	var local_ts := 0
	var local_payload: Variant = null
	if FileAccess.file_exists(path):
		local_ts = FileAccess.get_modified_time(path)
		local_payload = JSON.parse_string(FileAccess.get_file_as_string(path))
	var remote: Variant = pull(key)
	var resolved: Variant
	# SET-shaped saves (scores, history) UNION per entry instead of picking a
	# side. leaderboard.gd's header says why: a board is a set of finished runs,
	# and resolve() choosing wholesale silently deletes the other device's real
	# entries. That warning only ever guarded the DISPLAY path — this is the
	# sync half of the same rule, and without it two devices ping-pong
	# overwrite each other's boards until only one side's entries exist at all.
	if merger.is_valid() and local_payload is Array \
			and remote is Dictionary and remote.get("data") is Array:
		resolved = merger.call(local_payload, remote.data)
	else:
		resolved = resolve(local_ts, local_payload, remote)
	if resolved == null:
		return
	if resolved != local_payload:
		# Null-checked like every other write. This one lands the cloud copy on
		# disk, so a failed open means the mirror simply did not apply — the
		# local file is untouched and the next sync tries again. Crashing here
		# would take down whatever was mid-flight: a boot, a save, or a run end.
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			push_error("cloud: could not apply the cloud copy to %s (error %d)"
				% [path, FileAccess.get_open_error()])
			return
		f.store_string(JSON.stringify(resolved))
	push(key, resolved)
