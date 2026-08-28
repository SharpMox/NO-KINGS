## In-memory cloud backend for tests only (issue 12 — accounts & cloud
## saves). cloud_save.gd's platform switch never selects this; a test wires
## it in directly with `CloudSave.backend = CloudBackendMemory` to exercise
## push/pull/resolve/sync_file without a real platform. Call reset() between
## cases — the store is static (module-level) state, so it survives across
## calls within one run the same way a real cloud would.


static var _store := {}


static func is_available() -> bool:
	return true


static func push(key: String, envelope: Dictionary) -> bool:
	_store[key] = envelope
	return true


static func pull(key: String) -> Variant:
	return _store.get(key)


static func reset() -> void:
	_store = {}
