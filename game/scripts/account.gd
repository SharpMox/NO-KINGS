## issue 83: who owns a save.
##
## THE RULING THIS EXISTS TO SERVE (user, 2026-08-31): a guest keeps their
## progress when they sign in. That is why saves are keyed by account from day
## one, with a local pseudo-account that gets REBOUND on sign-in rather than
## copied. It never merges two histories, because until sign-in there is only
## one.
##
## Retrofitting an owner id later would have meant migrating every existing
## save. `save_config.gd`'s header is explicit that an additive field read with
## a default is safe forever while a RESHAPED field read with a default is a
## silent corruption — an owner id added now is the additive case, and adding it
## after saves had grown around its absence would not have been.
##
## The account file is deliberately separate from the save files: it survives a
## deleted run, and a save that is being rebound must not also be the thing
## recording who it is being rebound to.

const ACCOUNT_PATH := "user://account.json"

## Providers. "guest" is a real account, not the absence of one — it owns saves
## exactly as a signed-in account does, which is the whole point.
const GUEST := "guest"
const GOOGLE := "google"
const APPLE := "apple"

## Bypass for the windowed click probes. They drive real input at real
## coordinates and expect the main menu; a login screen in front of it would
## break every one. The probes ALSO exercise the screen itself — a bypass that
## is the only path tested is how this repo once green-lit a dead main menu.
const SKIP_ARG := "--skip-login"

static var _cache: Dictionary = {}


static func _read() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	if FileAccess.file_exists(ACCOUNT_PATH):
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(ACCOUNT_PATH))
		if parsed is Dictionary and parsed.has("owner"):
			_cache = parsed
	return _cache


static func _write(data: Dictionary) -> void:
	_cache = data
	var f := FileAccess.open(ACCOUNT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))


## True until an account exists — i.e. the first run, and only the first run.
static func needs_login() -> bool:
	return _read().is_empty()


static func owner() -> String:
	return str(_read().get("owner", ""))


static func provider() -> String:
	return str(_read().get("provider", ""))


static func signed_in() -> bool:
	return provider() != "" and provider() != GUEST


## Create the local pseudo-account. Stable for the life of the install, and the
## owner of every guest save until a sign-in rebinds it.
static func start_guest() -> String:
	var id := "guest-%d-%d" % [Time.get_unix_time_from_system(), randi()]
	_write({"owner": id, "provider": GUEST})
	return id


## REBIND, not copy: point the account at the real id and rewrite the owner
## stamp in the files that already exist. The guest's progress comes with them
## because it was never a separate history — it was this one, under the old id.
##
## `save_paths` are the local save files to restamp; the caller passes them so
## this stays a pure account module with no opinion about what a save is.
static func sign_in(new_provider: String, account_id: String,
		save_paths: Array) -> void:
	_write({"owner": account_id, "provider": new_provider})
	for path in save_paths:
		_restamp(str(path), account_id)


static func _restamp(path: String, account_id: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return # scores/history may be Arrays; only owner-stamped Dicts rebind
	parsed["owner"] = account_id
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(parsed))


## Stamp the current owner onto a save payload on its way to disk. Additive:
## a save written before this existed simply has no `owner` and reads back as
## "" — which is exactly the pre-account state and needs no migration.
static func stamp(payload: Dictionary) -> Dictionary:
	payload["owner"] = owner()
	return payload


## Test seam: drop the in-memory cache so a suite can write an account file
## and have the next read see it. Production never calls this.
static func _reset_cache() -> void:
	_cache = {}
