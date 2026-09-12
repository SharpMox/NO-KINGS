## NO-61: Android delivers NOTIFICATION_WM_GO_BACK_REQUEST TWICE per press, and
## this is the one place that fact is written down.
##
## WHAT IT BROKE. Every handler in this project ran twice per press. On the main
## menu the first call closed the open panel and returned, the second found
## nothing open and fell through to get_tree().quit() — so Back from any panel
## KILLED THE APP, on the platform where Back is the primary navigation gesture.
## In a run the first call opened the pause menu and the second closed it, so
## Back appeared to do nothing at all. The intro only looked correct by accident,
## because _advance() already guards on _advanced.
##
## MEASURED on a Nothing Phone (2a), 2026-09-12, from ONE `input keyevent 4`:
##
##   14:27:46.904  GO_BACK  history_scroll=true   main_box=false  -> hid the panel
##   14:27:46.905  GO_BACK  history_scroll=false  main_box=true   -> quit()
##
## IT IS AN UPSTREAM GODOT REGRESSION, not our bug and not a misconfiguration.
## Two independent paths both raise GO_BACK on 4.7:
##   A. the KEY EVENT — KEYCODE_BACK ACTION_DOWN reaches the view tree and
##      android_input_handler.cpp turns it into a DEFERRED GO_BACK.
##   B. the CALLBACK — GodotActivity registers onBackPressedDispatcher, which
##      calls GodotLib.back() and raises GO_BACK immediately.
## Path B was added by godotengine/godot#117653 ("[Android] Fix handling of back
## navigation when targeting API level 36", merged 2026-04-07, present in
## 4.7-stable). At targetSdk 36 — ours, game/android/build/config.gradle — the
## OnBackInvoked dispatcher is mandatory, and AOSP's ViewRootImpl forwards the
## ACTION_DOWN to the view tree AND invokes the callback on ACTION_UP. Before
## #117653 the callback only ran if the view hierarchy declined the key, which
## Godot never does. An earlier press+release double was #101457, fixed in 4.4;
## this is a different one, re-introduced, and unreported upstream as of
## 2026-09-09.
##
## WHY MILLISECONDS AND NOT A FRAME COUNTER: path A is DEFERRED and path B is
## not, so the two deliveries can straddle a frame boundary. The 1 ms gap
## measured above is what this window is sized against.
##
## WHY A GUARD IN EACH HANDLER AND NOT ONE SWALLOWER: notifications propagate to
## every node rather than being routed through anything, so there is no single
## place to intercept them. Three handlers exist — menu.gd, intro.gd, game.gd,
## one per scene — and each asks this.
##
## DELETE THIS FILE WHEN GODOT FIXES IT. That is the real fix; this is a
## defence. Test by rebuilding against a Godot without the duplicate dispatch,
## or at targetSdk 35, where the double vanishes.

## Long enough to cover two deliveries that straddle a frame, short enough that a
## human double-press is not swallowed — a deliberate double tap is 150-300 ms.
const WINDOW_MS := 100

static var _last_msec := -WINDOW_MS * 10


## True when this delivery is the duplicate of one already handled, in which case
## the caller must return without doing anything. Stamps on the first of a pair,
## so the FIRST delivery is always the one that acts.
static func is_duplicate() -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_msec < WINDOW_MS:
		return true
	_last_msec = now
	return false


## Tests only: forget the last press, so a case can drive a fresh pair without
## waiting out the window. Same idiom as Account._reset_cache().
static func _reset() -> void:
	_last_msec = -WINDOW_MS * 10
