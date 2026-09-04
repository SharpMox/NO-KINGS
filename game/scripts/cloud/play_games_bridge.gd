extends Node
## issue 86 / T1: the Node the Play Games plugin needs, and the cache that lets
## a SYNCHRONOUS backend sit on top of an ASYNCHRONOUS SDK.
## See docs/adr/0003-synchronous-cloud-contract-over-async-sdk.md.
##
## WHY THIS EXISTS AT ALL. The plugin's clients — PlayGamesSignInClient,
## PlayGamesSnapshotsClient, PlayGamesPlayersClient — are Node subclasses that
## wire their signals in _ready(). Their own doc comments call them "autoloads",
## but addons/GodotPlayGameServices/export_plugin.gd registers exactly ONE
## autoload, `GodotPlayGameServices`, which holds only the raw android_plugin
## handle. So somebody has to own the client Nodes, and it cannot be
## cloud_backend_play_games.gd: that is static functions on a preloaded script,
## with no _ready() and no way to receive a signal.
##
## WHY AN AUTOLOAD rather than a node in a scene: menu.gd and game.gd both call
## CloudSave, so a scene-owned node would have to exist in both and would die on
## every scene change, taking the cache and any in-flight sign-in with it.
##
## WHY THE CACHE IS STATIC. The backend's contract is static functions. Static
## vars live on the SCRIPT, not the instance, so the backend reads them through
## a plain preload without ever looking up a node path. The autoload instance
## exists only to hold the clients and receive their signals; the state it
## collects lives here.

## Sign-in reached a verdict. `ok` is true only once the player id has ALSO
## arrived — authentication alone is not enough to bind an account. Emitted
## rather than returned because the whole flow is asynchronous; the login
## screen connects one-shot. (issue 86 / T3)
signal sign_in_finished(ok: bool)

## A snapshot came back for `key` and the cache is updated. The listener turns
## this into a CloudSave.sync_file() for that key — which is what actually
## restores progress on a fresh device. Emitted even when the cloud copy was
## empty; see _on_game_loaded. (issue 86 / T4)
signal snapshot_loaded(key: String)

## `GodotPlayGameServices.PlayGamesPluginError.OK`, as a literal. The autoload
## is reached by node path at runtime (see _ready), so its enum is not in scope
## at compile time — which is the whole reason for that indirection.
const _PLUGIN_OK := 0

## True once sign-in has actually completed. This — not "is the plugin
## present" — is what CloudSave's is_available() reports, because every caller
## of it (push/pull/sync_file/leaderboard) means "is there an account to sync
## with". Platform capability is a separate question; see `supported()` in T2.
static var signed_in := false

## True once sign-in has REACHED A VERDICT this session, either way.
##
## `sign_in_finished` fires ~2s after launch; the Menu — its only listener —
## does not exist until the 11.3s intro ends, and is rebuilt after every run.
## A signal is not a queue, so a listener arriving late reads this and
## `signed_in` to reconstruct what it missed.
static var sign_in_attempted := false

## The Play Games player id, cached from current_player_loaded. Empty until
## sign-in has completed AND the player has been loaded — it arrives on a
## SECOND async hop, not with authentication, which is why binding an account
## on user_authenticated alone would stamp an empty owner id into account.json.
static var player_id := ""

## key -> envelope Dictionary, the last snapshot seen for each save key.
## pull() answers from here so it can stay synchronous; a stale or missing
## entry is safe because resolve() is highest-wave-wins then last-write-wins,
## so a lagging mirror always loses to local.
static var snapshots := {}

## The clients are static for the same reason the cache is: the backend's
## contract is static functions, so `save()` and `fetch()` below have to reach
## them without an instance. The autoload assigns them in _ready() — which is
## the one thing that genuinely needs the instance, since add_child() does.
## They stay null off Android, and every static entry point below treats null
## as "no cloud", which is exactly the desktop answer.
##
## Typed as plain Node, and loaded by PATH at runtime rather than declared as
## PlayGamesSignInClient / PlayGamesSnapshotsClient / PlayGamesPlayersClient.
## Naming those classes here would be a compile-time dependency on them, and
## each one references the `GodotPlayGameServices` autoload identifier — which
## does not resolve while THIS file is being compiled as a preloaded dependency
## of cloud_backend_play_games.gd. The result is a script that compiles fine as
## an autoload and fails as a dependency. Runtime load() sidesteps it: by the
## time _ready() runs on Android, every autoload is registered.
static var _sign_in: Node
static var _snapshots: Node
static var _players: Node

const _SIGN_IN_SCRIPT := "res://addons/GodotPlayGameServices/scripts/sign_in/sign_in_client.gd"
const _SNAPSHOTS_SCRIPT := "res://addons/GodotPlayGameServices/scripts/snapshots/snapshots_client.gd"
const _PLAYERS_SCRIPT := "res://addons/GodotPlayGameServices/scripts/players/players_client.gd"


func _ready() -> void:
	# Autoloads boot on every platform, including every headless test run, so
	# this bails before touching anything Android-only. Off Android the static
	# cache simply stays at its defaults and the backend reports unavailable —
	# which is the correct desktop answer, not a degraded one.
	if OS.get_name() != "Android":
		return
	# Fetched by NODE PATH, not by the bare `GodotPlayGameServices` identifier.
	# An autoload's global identifier only resolves for scripts compiled after
	# the autoloads are registered, and this file is also pulled in as a
	# preloaded dependency of cloud_backend_play_games.gd — where that name does
	# not exist yet, so the whole script fails to compile. That failure is
	# silent-ish and vicious: the backend then has no encode(), and a headless
	# test dies before its quit(), leaving Godot running forever.
	var plugin := get_node_or_null(^"/root/GodotPlayGameServices")
	if plugin == null or plugin.initialize() != _PLUGIN_OK:
		# initialize() already printerr's the reason. Leaving the clients
		# uninstantiated keeps signed_in false, so the game stays fully
		# playable offline rather than half-wired to a plugin that isn't there.
		return
	_sign_in = (load(_SIGN_IN_SCRIPT) as GDScript).new()
	_snapshots = (load(_SNAPSHOTS_SCRIPT) as GDScript).new()
	_players = (load(_PLAYERS_SCRIPT) as GDScript).new()
	# CONNECTED BEFORE add_child, deliberately. Each client wires itself to the
	# native plugin in its own _ready(), which fires DURING add_child — so
	# connecting afterwards leaves a window in which the plugin's startup
	# authentication check could emit into nothing. Connecting first costs the
	# same and removes the question; a signal needs no tree to be connected.
	_sign_in.user_authenticated.connect(_on_authenticated)
	_players.current_player_loaded.connect(_on_player_loaded)
	_snapshots.game_loaded.connect(_on_game_loaded)
	_snapshots.conflict_emitted.connect(_on_conflict)
	add_child(_sign_in)
	add_child(_snapshots)
	add_child(_players)


## --- the snapshot codec (issue 86 / T1) --------------------------------------
## Play Games Snapshots are BYTES — `PlayGamesSnapshot.content` is a
## PackedByteArray — so every envelope crosses JSON and utf8 on the way out and
## back. A wrong round-trip corrupts every cloud save silently rather than
## failing loudly, which is why this pair is the one part of the Android backend
## under test: it is pure, so the desktop suite can reach it.
##
## It lives here rather than in cloud_backend_play_games.gd because BOTH use it
## and the dependency has to run one way — the backend preloads this file, so
## this file cannot preload the backend.


static func encode(envelope: Dictionary) -> PackedByteArray:
	return JSON.stringify(envelope).to_utf8_buffer()


## The envelope in `bytes`, or null when there isn't a usable one.
##
## Empty bytes are the NORMAL first-run case, not an error: fetch() calls
## load_game(create_if_not_found = true), which hands back an empty snapshot the
## first time a device ever syncs. Returning null makes that read as "no cloud
## copy", which resolve() already handles by keeping local.
static func decode(bytes: PackedByteArray) -> Variant:
	if bytes.is_empty():
		return null
	# JSON.new().parse(), not JSON.parse_string(): the static helper PRINTS a
	# parse error, and a corrupt snapshot is a case we HANDLE — it falls back to
	# local, which is already what resolve() does with a missing remote. Logging
	# an error for something we recover from cleanly is how a suite teaches
	# people to scroll past error lines.
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		return null
	return json.data if json.data is Dictionary else null


## --- the static API the backend calls (issue 86 / T2) ------------------------


## Whether this PLATFORM can do cloud at all — distinct from `signed_in`, which
## is whether an ACCOUNT is currently attached. The two were conflated behind a
## single is_available(), and conflating them deadlocks the login screen: it
## guarded the sign-in button on is_available(), which is false until you sign
## in, so you could never sign in. See ADR 0003.
static func supported() -> bool:
	return _snapshots != null


## Write an envelope to the Snapshot named `key`. Fire-and-forget by design:
## the SDK emits game_saved later and there is nothing useful to await, so this
## reports only whether the write was ACCEPTED for delivery.
##
## Deliberately does NOT enqueue into SyncQueue. menu.gd re-syncs all three keys
## on every boot and sync_file pushes at the end of each, so a push lost to a
## flaky network is re-pushed next launch with local intact throughout — see
## ADR 0003 for why the original enqueue ruling was overturned.
static func save(key: String, envelope: Dictionary) -> bool:
	if _snapshots == null:
		return false
	_snapshots.save_game(key, key, encode(envelope))
	return true


## Ask for the Snapshot named `key`. The answer arrives later on game_loaded;
## this only starts the round-trip, which is what keeps pull() synchronous.
##
## create_if_not_found is true so a device that has never synced gets an empty
## snapshot rather than an error — decode() reads empty content as null, which
## resolve() already handles by keeping local.
static func fetch(key: String) -> void:
	if _snapshots == null:
		return
	_snapshots.load_game(key, true)


## Start an interactive sign-in. The verdict arrives on `sign_in_finished`.
##
## Callers must check supported() first: this cannot report its own failure,
## being static, and a no-op here would look like a button that does nothing.
static func begin_sign_in() -> void:
	if _sign_in == null:
		return
	_sign_in.sign_in()


## --- the async chain (issue 86 / T3-T5) --------------------------------------
## Every handler below takes Variant rather than the plugin's own types
## (PlayGamesPlayer, PlayGamesSnapshot, PlayGamesSnapshotConflict) for the same
## reason the client vars are plain Nodes: naming those classes would be a
## compile-time dependency on scripts that reference the GodotPlayGameServices
## autoload identifier, which does not resolve while this file is compiled as a
## preloaded dependency.


## Authentication came back. NOT the end of sign-in: the player id arrives on a
## second hop, and binding an account without it would stamp an empty owner id
## into account.json — silently, and permanently for that install.
func _on_authenticated(is_authenticated: bool) -> void:
	if not is_authenticated:
		signed_in = false
		sign_in_attempted = true
		sign_in_finished.emit(false)
		return
	_players.load_current_player(true)


## The second hop. Only here is there both an authenticated session and an id,
## so only here is sign-in actually complete.
func _on_player_loaded(player: Variant) -> void:
	if player == null:
		signed_in = false
		sign_in_attempted = true
		sign_in_finished.emit(false)
		return
	player_id = str(player.player_id)
	signed_in = true
	sign_in_attempted = true
	sign_in_finished.emit(true)


## A snapshot arrived. `metadata.unique_name` is the file_name that save_game
## was given, i.e. our save key, which is how a single signal serves all three.
func _on_game_loaded(snapshot: Variant) -> void:
	# metadata is checked as well as the snapshot: PlayGamesSnapshot only sets it
	# when the payload dictionary carried one, so a malformed response leaves it
	# null and `.unique_name` throws. A snapshot we cannot file under a key is a
	# snapshot we cannot use, so both cases exit the same way.
	if snapshot == null or snapshot.metadata == null:
		return
	var key := str(snapshot.metadata.unique_name)
	var envelope: Variant = decode(snapshot.content)
	if envelope is Dictionary:
		snapshots[key] = envelope
	# Emitted even when there was NOTHING to decode. An empty cloud copy is the
	# fresh-account case, and the sync_file this triggers is what pushes this
	# device's local saves up to seed it. Staying quiet here would leave a
	# newly signed-in player's progress on the device only.
	snapshot_loaded.emit(key)


## Two versions of the same snapshot disagree. We settle it ourselves and never
## show Google's picker: resolution here is deterministic (highest wave, then
## last write), and asking the player to arbitrate would contradict local being
## the source of truth. See ADR 0003.
##
## Re-saving the winner IS the resolution — the plugin surfaces the conflict but
## exposes no resolveConflict() call, so overwriting is the only lever it gives
## us. Verified against the addon source, not assumed.
func _on_conflict(conflict: Variant) -> void:
	# Same metadata guard as _on_game_loaded, and for the same reason: without a
	# unique_name there is no key to settle the conflict under.
	if conflict == null or conflict.server_snapshot == null \
			or conflict.server_snapshot.metadata == null \
			or conflict.conflicting_snapshot == null:
		return
	var mine: Variant = decode(conflict.conflicting_snapshot.content)
	var theirs: Variant = decode(conflict.server_snapshot.content)
	var key := str(conflict.server_snapshot.metadata.unique_name)
	# Whichever side is missing or unreadable, the other one wins uncontested.
	if not (mine is Dictionary):
		if theirs is Dictionary:
			snapshots[key] = theirs
			save(key, theirs)
		return
	if not (theirs is Dictionary):
		save(key, mine)
		return
	# load() at runtime rather than a preload const: cloud_save.gd preloads the
	# Play Games backend, which preloads THIS file, so a preload here would be a
	# cyclic reference. Reusing resolve() still matters more than avoiding the
	# indirection — a second copy of the winner-picking rule is exactly how two
	# rules drift apart.
	# Set-shaped keys (scores/history) get pick-a-side HERE too — the plugin's
	# conflict path has no merger, so this is the one layer where "boards always
	# union" is not literally true. Self-healing: the next sync_file re-unions
	# the local file into the cloud, so a conflict costs at most one boot's
	# worth of the other side's entries, never the local ones.
	var cloud_save := load("res://scripts/cloud_save.gd") as GDScript
	var winner: Variant = cloud_save.resolve(int(mine.get("ts", 0)), mine.get("data"), theirs)
	var settled := {"ts": Time.get_unix_time_from_system(), "data": winner}
	snapshots[key] = settled
	save(key, settled)
