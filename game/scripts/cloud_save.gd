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
##   * cloud_backend_game_center.gd (iOS) and cloud_backend_play_games.gd
##     (Android) are UNIMPLEMENTED STUBS awaiting their native plugin — see
##     the TODOs in each file. is_available() stays false on both, so no
##     caller here ever depends on cloud data that doesn't exist yet.
##   * cloud_backend_memory.gd is dev/test-only; production never selects it.
##
## Backend contract (static funcs called via the preloaded script, same
## no-instantiation idiom as SaveConfig/Economy/Settings):
##   is_available() -> bool
##   push(key: String, envelope: Dictionary) -> bool
##   pull(key: String) -> Variant   # envelope Dictionary, or null
##   account_id() -> String         # issue 83: stable account id, "" if none

const Noop := preload("res://scripts/cloud/cloud_backend_noop.gd")
const GameCenter := preload("res://scripts/cloud/cloud_backend_game_center.gd")
const PlayGames := preload("res://scripts/cloud/cloud_backend_play_games.gd")

## Swappable by tests (cloud_backend_memory.gd); production code never
## reassigns it — the platform switch below picks it once at load.
static var backend = _default_backend()


static func _default_backend():
	match OS.get_name():
		"iOS":
			return GameCenter
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
		return false
	return backend.push(key, _envelope(payload))


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
	if local_payload != null and int(remote.ts) <= local_ts:
		return local_payload
	return remote.data


## Full mirror step for one on-disk save at `path`: pull the cloud copy,
## resolve it against local by last-write-wins, write the winner back to
## disk if the cloud copy won, then push the (possibly just-updated) local
## copy back up so the mirror stays current. End-to-end no-op while the
## backend is unavailable — every desktop run today, and iOS/Android until
## their native plugin lands.
static func sync_file(key: String, path: String) -> void:
	if not backend.is_available():
		return
	var local_ts := 0
	var local_payload: Variant = null
	if FileAccess.file_exists(path):
		local_ts = FileAccess.get_modified_time(path)
		local_payload = JSON.parse_string(FileAccess.get_file_as_string(path))
	var resolved: Variant = resolve(local_ts, local_payload, pull(key))
	if resolved == null:
		return
	if resolved != local_payload:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(resolved))
	push(key, resolved)
