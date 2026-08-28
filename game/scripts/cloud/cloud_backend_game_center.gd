## iOS cloud backend (issue 12 — accounts & cloud saves): Game Center +
## iCloud saved-game mirror.
##
## STATUS: UNIMPLEMENTED STUB. This checkout is desktop-only with no iOS
## export configured and no native plugin available to verify against, so
## push/pull are no-ops and is_available() stays false — no caller in
## cloud_save.gd ever depends on cloud data that doesn't exist yet.
##
## Making this real is a drop-in, not a rewrite: add the Game
## Center/iCloud native plugin, then fill in the three TODOs below with
## calls into it. Nothing in cloud_save.gd or its callers needs to change.


static func is_available() -> bool:
	return false # TODO(native plugin): true once Game Center/iCloud is wired


static func push(_key: String, _envelope: Dictionary) -> bool:
	# TODO(native plugin): write _envelope (JSON-safe) to the iCloud
	# key-value store or a Game Center saved game, keyed by _key.
	return false


static func pull(_key: String) -> Variant:
	# TODO(native plugin): read the iCloud key-value store / Game Center
	# saved game for _key and return its envelope Dictionary, or null if
	# there isn't one.
	return null
