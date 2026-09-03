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

## True once sign-in has actually completed. This — not "is the plugin
## present" — is what CloudSave's is_available() reports, because every caller
## of it (push/pull/sync_file/leaderboard) means "is there an account to sync
## with". Platform capability is a separate question; see `supported()` in T2.
static var signed_in := false

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

var _sign_in: PlayGamesSignInClient
var _snapshots: PlayGamesSnapshotsClient
var _players: PlayGamesPlayersClient


func _ready() -> void:
	# Autoloads boot on every platform, including every headless test run, so
	# this bails before touching anything Android-only. Off Android the static
	# cache simply stays at its defaults and the backend reports unavailable —
	# which is the correct desktop answer, not a degraded one.
	if OS.get_name() != "Android":
		return
	if GodotPlayGameServices.initialize() != GodotPlayGameServices.PlayGamesPluginError.OK:
		# initialize() already printerr's the reason. Leaving the clients
		# uninstantiated keeps signed_in false, so the game stays fully
		# playable offline rather than half-wired to a plugin that isn't there.
		return
	_sign_in = PlayGamesSignInClient.new()
	_snapshots = PlayGamesSnapshotsClient.new()
	_players = PlayGamesPlayersClient.new()
	add_child(_sign_in)
	add_child(_snapshots)
	add_child(_players)
