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

	DirAccess.remove_absolute(path)
	CloudSave.backend = Noop # restore the real default before quitting

	# --- the Play Games snapshot codec (issue 86 / T1) ---
	# Snapshots are bytes (PlayGamesSnapshot.content is a PackedByteArray), so
	# every envelope crosses Dictionary -> JSON -> utf8 -> bytes and back. This
	# is the ONLY part of the Android backend that runs on desktop, and a wrong
	# round-trip corrupts every cloud save silently rather than failing loudly —
	# which is exactly why it is the one piece of slice 86 under test.
	var env := {"ts": 1234, "data": {"score": 7, "wave": 3}}
	var bytes := PlayGames.encode(env)
	check(bytes.size() > 0, "encode produces bytes")
	var back: Variant = PlayGames.decode(bytes)
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
	check(PlayGames.decode(PackedByteArray()) == null, "empty bytes decode to null")
	check(PlayGames.decode("not json".to_utf8_buffer()) == null, "garbage bytes decode to null")
	check(PlayGames.decode("[1,2,3]".to_utf8_buffer()) == null,
		"valid JSON that isn't an envelope decodes to null")

	print("---")
	if fails == 0:
		print("ALL CLOUD SAVE CHECKS OK")
	quit(1 if fails > 0 else 0)
