## Desktop cloud backend (issue 12 — accounts & cloud saves). There is no
## cloud on desktop, so this is a real, finished no-op — not a stub awaiting
## future work. cloud_save.gd selects it on every platform except iOS/Android.
##
## Backend contract (static funcs called via the preloaded script, same
## no-instantiation idiom as SaveConfig/Economy/Settings):
##   is_available() -> bool
##   push(key: String, envelope: Dictionary) -> bool
##   pull(key: String) -> Variant   # envelope Dictionary, or null


static func is_available() -> bool:
	return false


static func push(_key: String, _envelope: Dictionary) -> bool:
	return false


static func pull(_key: String) -> Variant:
	return null


## issue 83: the signed-in account's stable id, or "" when there is none.
## Part of the backend contract alongside is_available/push/pull.
static func account_id() -> String:
	return ""
