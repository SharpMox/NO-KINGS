extends Node
## issue 87 / T4: the iOS twin of play_games_bridge.gd — same static surface,
## same two signals, so menu.gd runs ONE sign-in flow and only picks a bridge.
##
## Where Android needed machinery, iOS mostly needs less, and the differences
## are worth naming because each one retires a defect class 86 hit on device:
##   * iCloud reads are SYNCHRONOUS (probe-verified) — so there is no snapshot
##     cache here, which is the class the stale-cache run-revival bug lived in.
##   * There is no fetch round-trip — so there is nothing to echo, which is the
##     class the 344-fetch loop lived in.
##   * GameCenter exposes is_authenticated() natively (probe found it; the
##     header never mentioned it) — the very call whose absence on Android
##     made the boot check a phantom.
## What iOS keeps from Android: results arrive via a POLLED event queue rather
## than signals, so the player id still lands asynchronously and the cached-id
## rule from ADR 0003 still applies.
##
## Like the Android bridge, this file names no plugin symbol at compile time —
## singletons are fetched by name at runtime, events are read as Variants.

## Same meaning as the Android bridge's signal: `ok` is true only once the
## player id has ALSO arrived. The menu connects the same handler either way.
signal sign_in_finished(ok: bool)

## Same meaning as Android's: a value for `key` is ready to mirror. On iOS the
## read itself is synchronous, so this fires immediately after a sync kick or
## when iCloud reports another device changed a key.
signal snapshot_loaded(key: String)

static var signed_in := false
static var sign_in_attempted := false
static var player_id := ""

## The plugin singletons, fetched at _ready. Objects, not Nodes — the plugin
## registers them with the Engine directly. Null off iOS, and every static
## entry point treats null as "no cloud", exactly like desktop.
static var _gc: Object
static var _ic: Object

## NSUbiquitousKeyValueStore refuses quietly when a value is oversized, so the
## guard has to live on our side and be LOUD. Apple's per-value limit is 1 MB;
## our heaviest measured envelope is ~10 KB, so tripping this means a bug, not
## growth. (issue 87 plan: "a size assertion at the push site rather than a
## silent truncation".)
const MAX_VALUE_BYTES := 900_000

## The keys this game mirrors; used to fan a generic iCloud change event out
## into per-key announcements the menu already knows how to handle.
const KEYS := ["run", "scores", "history"]


func _ready() -> void:
	if OS.get_name() != "iOS":
		return
	if Engine.has_singleton("GameCenter"):
		_gc = Engine.get_singleton("GameCenter")
	if Engine.has_singleton("ICloud"):
		_ic = Engine.get_singleton("ICloud") # probe: "ICloud", not "iCloud"
	if _gc == null and _ic == null:
		return # plugins absent (editor, or a build without them): stay dormant
	# The ask itself moved into the poll: live-run fact (simulator,
	# 2026-09-04) — authenticate() called from an autoload's _ready returns
	# FAILED with "!root_controller", because the view hierarchy does not
	# exist yet, and no event ever arrives for that failure. The poll retries
	# until the call is ACCEPTED, then leaves the verdict to the event queue.
	var t := Timer.new()
	t.wait_time = 0.5
	t.timeout.connect(_poll)
	add_child(t)
	t.start()


## --- the static API the backend and menu call (same names as Android) -------


static func supported() -> bool:
	# BOTH, and the identity half is not optional. Saves are what matters, but
	# a save with no account_id() can never be bound or fetched — so with GC
	# missing the login button would pass its guard, ask nobody, answer never,
	# and time out on every press for the life of the install. A control that
	# cannot succeed is worse than one that is honestly absent.
	return _ic != null and _gc != null


static func begin_sign_in() -> void:
	if _gc != null and _gc.authenticate() == OK:
		_auth_started = true


## Store an envelope under `key`. Synchronous accept, loud size guard.
static func save(key: String, envelope: Dictionary) -> bool:
	if _ic == null:
		return false
	var payload := JSON.stringify(envelope)
	if payload.to_utf8_buffer().size() > MAX_VALUE_BYTES:
		push_error("icloud: refusing oversized save '%s' (%d bytes) — store would drop it silently"
			% [key, payload.to_utf8_buffer().size()])
		return false
	_ic.set_key_values({key: payload})
	_ic.synchronize_key_values()
	return true


## The envelope stored under `key`, or null. SYNCHRONOUS — the property that
## deletes Android's whole cache layer from this platform.
static func read(key: String) -> Variant:
	if _ic == null:
		return null
	var raw: Variant = _ic.get_key_value(key)
	if not (raw is String) or raw == "":
		return null
	var json := JSON.new()
	if json.parse(raw) != OK:
		return null # a corrupt value reads as "no cloud copy"; local wins
	return json.data if json.data is Dictionary else null


## Remove `key` outright — iOS has real deletion, so a finished run needs no
## null-payload marker the way Android does.
static func erase(key: String) -> void:
	if _ic != null:
		_ic.remove_key(key)


## Same name, role and STATICNESS as Android's fetch(): kick a sync and queue
## the announcement. The poll below emits it within half a second — a static
## function cannot emit an instance signal, and the tiny delay also mirrors the
## arrival cadence menu.gd was built against on Android.
static var _announce: Array = []

## Set once authenticate() has been ACCEPTED (returned OK). Before that the
## poll keeps re-asking — see _ready for why the first asks can fail.
static var _auth_started := false

static func fetch(key: String) -> void:
	if _ic == null:
		return
	_ic.synchronize_key_values()
	_announce.append(key)


## --- the polled event queue (issue 87 / T4) ----------------------------------
## Both plugins answer through pending-event queues rather than signals. One
## poll drains both; every event is read as a Variant with lenient .get()s,
## because the artifact — not the README — defines what arrives.


func _poll() -> void:
	if _gc != null and not _auth_started:
		_auth_started = _gc.authenticate() == OK
	for k in _announce:
		snapshot_loaded.emit(k)
	_announce.clear()
	while _gc != null and _gc.get_pending_event_count() > 0:
		_on_gc_event(_gc.pop_pending_event())
	while _ic != null and _ic.get_pending_event_count() > 0:
		_on_ic_event(_ic.pop_pending_event())


func _on_gc_event(e: Variant) -> void:
	if not (e is Dictionary):
		return
	printerr("[ic-bridge] gc event: ", JSON.stringify(e)) # printerr: print() reaches no iOS log
	if str(e.get("type", "")) != "authentication":
		return
	if str(e.get("result", "")) == "ok":
		# The id arrives WITH the verdict here — one hop, not Android's two —
		# but the same rule holds: no id, no completed sign-in.
		var id := str(e.get("player_id", ""))
		if id == "":
			signed_in = false
			sign_in_attempted = true
			sign_in_finished.emit(false)
			return
		player_id = id
		signed_in = true
		sign_in_attempted = true
		sign_in_finished.emit(true)
	else:
		signed_in = false
		sign_in_attempted = true
		sign_in_finished.emit(false)


func _on_ic_event(e: Variant) -> void:
	if not (e is Dictionary):
		return
	printerr("[ic-bridge] icloud event: ", JSON.stringify(e))
	# Another device changed our data. Whatever shape the event names the keys
	# in, announcing all three is always CORRECT — sync_file resolves per key
	# and a no-op mirror costs nothing — so parse nothing and announce all.
	for k in KEYS:
		snapshot_loaded.emit(k)
