extends SceneTree
## Cloud-save sync layer (issue 12): push/pull/resolve against the in-memory
## test backend, plus a sync_file() round-trip against real user:// files.
## The desktop Noop backend is also checked directly — it must stay a real,
## harmless no-op so offline play never depends on it.
## Run headless:  godot --headless --path game -s tests/test_cloud_save.gd

const CloudSave := preload("res://scripts/cloud_save.gd")
const Memory := preload("res://scripts/cloud/cloud_backend_memory.gd")
const Noop := preload("res://scripts/cloud/cloud_backend_noop.gd")
const PlayGames := preload("res://scripts/cloud/cloud_backend_play_games.gd")
const Bridge := preload("res://scripts/cloud/play_games_bridge.gd")
const Account := preload("res://scripts/account.gd")
const Leaderboard := preload("res://scripts/leaderboard.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		push_error("FAIL: " + label)
		fails += 1
	else:
		print("ok: " + label)


func _init() -> void:
	# --- the real desktop backend: a finished no-op, not a stub ---
	check(not Noop.is_available(), "desktop backend reports unavailable")
	check(not Noop.push("run", {"ts": 1, "data": {}}), "desktop backend push no-ops")
	check(Noop.pull("run") == null, "desktop backend pull returns null")

	# --- push/pull round-trip against the memory backend ---
	CloudSave.backend = Memory
	Memory.reset()
	check(CloudSave.pull("run") == null, "nothing pulls before anything is pushed")
	check(CloudSave.push("run", {"score": 1}), "push reports success")
	var pulled: Variant = CloudSave.pull("run")
	check(pulled is Dictionary and pulled.has("ts") and pulled.data == {"score": 1},
		"pull returns the envelope: timestamped payload")

	# --- resolve(): last-write-wins, with local as the tie-broken default ---
	var newer := {"ts": 200, "data": {"score": 99}}
	var older := {"ts": 50, "data": {"score": 1}}
	check(CloudSave.resolve(100, {"score": 5}, newer) == {"score": 99},
		"a strictly newer remote wins")
	check(CloudSave.resolve(100, {"score": 5}, older) == {"score": 5},
		"an older remote loses to local")
	check(CloudSave.resolve(200, {"score": 5}, {"ts": 200, "data": {"score": 99}}) == {"score": 5},
		"a tied timestamp keeps local (source of truth)")
	check(CloudSave.resolve(0, null, newer) == {"score": 99},
		"no local file at all takes the cloud copy (new-device restore)")
	check(CloudSave.resolve(100, {"score": 5}, null) == {"score": 5},
		"no remote at all keeps local")
	check(CloudSave.resolve(100, {"score": 5}, {"garbage": true}) == {"score": 5},
		"a malformed envelope keeps local")

	# --- sync_file(): full mirror against real user:// files ---
	Memory.reset()
	var path := "user://cloud_save_test.json"
	DirAccess.remove_absolute(path)

	# no local, no remote: sync_file leaves nothing behind
	CloudSave.sync_file("run", path)
	check(not FileAccess.file_exists(path), "sync_file with nothing on either side writes nothing")

	# local only: sync_file pushes it up, local file is untouched. Compared
	# via JSON.stringify (like test_save.gd): JSON round-trips ints to
	# floats, so a parsed Dictionary never == an int-literal one directly.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"score": 7}))
	f = null
	CloudSave.sync_file("run", path)
	check(FileAccess.get_file_as_string(path) == JSON.stringify({"score": 7}),
		"sync_file doesn't clobber local when local is the only copy")
	# pushed payload came from JSON.parse_string, so its number is a float
	var mirrored: Variant = CloudSave.pull("run")
	check(JSON.stringify(mirrored.data) == JSON.stringify({"score": 7.0}),
		"sync_file pushed the local copy to the cloud")

	# remote now has a newer copy (simulating another device) -> local file updates
	Memory.push("run", {"ts": Time.get_unix_time_from_system() + 3600, "data": {"score": 42}})
	CloudSave.sync_file("run", path)
	check(FileAccess.get_file_as_string(path) == JSON.stringify({"score": 42}),
		"sync_file overwrites local when the cloud copy is newer")

	# --- the game-over tombstone (issue 86) ---
	# Deleting the local save when a run ends is not enough on its own: resolve()
	# treats "no local file" as the new-device restore case and takes the cloud
	# copy, so the next sync would pull the finished run back and offer to
	# Continue it. game.gd pushes a null payload to mean "there is no run", and
	# what makes that work is sync_file declining to write anything for it.
	Memory.reset()
	DirAccess.remove_absolute(path)
	CloudSave.push("run", {"wave": 12, "score": 500}) # a run in progress, mirrored
	CloudSave.sync_file("run", path)
	check(FileAccess.file_exists(path), "an in-progress cloud run restores to disk")

	DirAccess.remove_absolute(path) # the run ends: game.gd deletes the save...
	CloudSave.push("run", null) # ...and tombstones the cloud copy
	CloudSave.sync_file("run", path)
	check(not FileAccess.file_exists(path),
		"a tombstoned run does NOT come back from the cloud")

	# --- set-shaped keys UNION instead of picking a side (issues 85/86) ---
	# leaderboard.gd's header warns that resolve() choosing wholesale "silently
	# deletes the other device's real scores" — but that warning only guarded the
	# display path. sync_file ran the destructive pick on the scores/history
	# FILES: two devices ping-pong overwrote each other's boards until only one
	# side's entries existed anywhere. With a merger, both sides survive.
	Memory.reset()
	DirAccess.remove_absolute(path)
	var sf := FileAccess.open(path, FileAccess.WRITE)
	sf.store_string(JSON.stringify([{"score": 5, "wave": 2, "kings": 0}]))
	sf = null
	Memory.push("scores", {"ts": Time.get_unix_time_from_system() + 3600,
		"data": [{"score": 9, "wave": 3, "kings": 1}]})
	CloudSave.sync_file("scores", path, Leaderboard.merge)
	var board: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(board is Array and board.size() == 2,
		"a set-shaped key UNIONS with a newer cloud copy — no local entry is lost")
	check(Memory.pull("scores").data.size() == 2,
		"and the union is pushed back, so the cloud accumulates instead of ping-ponging")
	# history is a BAG, not a set: entries carry no timestamp, so two identical
	# quick losses are two real runs and must both survive — while the same run
	# seen through the mirror twice stays one. max(N, M) copies per entry.
	# The three asserts together also kill the degenerate implementations: a
	# "return b" passes none of them, a set-union fails the middle one.
	var h1 := {"score": 10, "wave": 4, "kings": 0, "won": false}
	var h2 := {"score": 70, "wave": 9, "kings": 1, "won": true}
	check(Leaderboard.merge_history([h1], [h1]).size() == 1,
		"a summary mirrored through the cloud stays one run")
	check(Leaderboard.merge_history([h1, h1], [h1, h2]).size() == 3,
		"two identical REAL runs both survive the union (bag, not set)")
	check(Leaderboard.merge_history([h1], [h2]).size() == 2,
		"local-only and cloud-only entries both survive")

	DirAccess.remove_absolute(path)
	CloudSave.backend = Noop # restore the real default before quitting

	# --- the Play Games snapshot codec (issue 86 / T1) ---
	# Snapshots are bytes (PlayGamesSnapshot.content is a PackedByteArray), so
	# every envelope crosses Dictionary -> JSON -> utf8 -> bytes and back. This
	# is the ONLY part of the Android backend that runs on desktop, and a wrong
	# round-trip corrupts every cloud save silently rather than failing loudly —
	# which is exactly why it is the one piece of slice 86 under test.
	var env := {"ts": 1234, "data": {"score": 7, "wave": 3}}
	var bytes := Bridge.encode(env)
	check(bytes.size() > 0, "encode produces bytes")
	var back: Variant = Bridge.decode(bytes)
	check(back is Dictionary, "decode returns an envelope Dictionary")
	# Compared field-by-field through int(), not by ==: JSON round-trips every
	# number to a float, so a decoded envelope never equals an int-literal one.
	# test_save.gd hits the same wall.
	check(int(back.get("ts", 0)) == 1234, "the timestamp survives the round-trip")
	check(back.get("data") is Dictionary, "the nested payload stays a Dictionary")
	check(int(back.data.get("score", 0)) == 7 and int(back.data.get("wave", 0)) == 3,
		"payload values survive the round-trip")

	# load_game(create_if_not_found = true) hands back an EMPTY snapshot the
	# first time a device ever syncs, so empty bytes are the normal first-run
	# case and must read as "no cloud copy" rather than crash.
	check(Bridge.decode(PackedByteArray()) == null, "empty bytes decode to null")
	check(Bridge.decode("not json".to_utf8_buffer()) == null, "garbage bytes decode to null")
	check(Bridge.decode("[1,2,3]".to_utf8_buffer()) == null,
		"valid JSON that isn't an envelope decodes to null")

	# --- the Android backend, answering as it must on DESKTOP (issue 86 / T2) ---
	# The bridge no-ops off Android, so every one of these is the honest "there
	# is no cloud here" answer rather than a stub's placeholder. Worth asserting
	# because the whole desktop suite runs with this autoload live: if it ever
	# started claiming availability, every sync_file call in the game would
	# begin talking to a plugin that isn't there.
	check(not PlayGames.is_available(), "play games reports unavailable off Android")
	check(not Bridge.supported(), "play games reports the PLATFORM unsupported off Android")
	check(PlayGames.account_id() == "", "no account id without a signed-in player")
	check(PlayGames.pull("run") == null, "pull returns null with nothing cached")
	check(not PlayGames.push("run", {"ts": 1, "data": {}}),
		"push reports NOT accepted when there is no snapshot client")

	# --- the ownership gate (issue 86) ---
	# is_available() = signed in AND the signed-in player owns this install's
	# saves. The second half is what stops a switched Google account from
	# carrying one account's progress into another's cloud — resolve() compares
	# waves, never owners, so without the gate the deeper run simply wins.
	# The bridge statics are plain vars and Account has a cache seam, so the one
	# invariant every cloud path rests on is pinned here on desktop instead of
	# living only in a comment.
	var acc := FileAccess.open(Account.ACCOUNT_PATH, FileAccess.WRITE)
	acc.store_string(JSON.stringify({"owner": "player-A", "provider": "google"}))
	acc = null
	Account._reset_cache()
	Bridge.signed_in = true
	Bridge.player_id = "player-A"
	check(PlayGames.is_available(), "signed in as the owner: cloud is live")
	Bridge.player_id = "player-B"
	check(not PlayGames.is_available(),
		"signed in as a DIFFERENT account: cloud goes inert, nothing crosses")
	Bridge.signed_in = false
	check(not PlayGames.is_available(), "not signed in: cloud inert regardless of owner")
	# restore: statics survive within this process, and later checks assume defaults
	Bridge.player_id = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Account.ACCOUNT_PATH))
	Account._reset_cache()

	print("---")
	if fails == 0:
		print("ALL CLOUD SAVE CHECKS OK")
	quit(1 if fails > 0 else 0)
