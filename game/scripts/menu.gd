extends Control
## Main menu: Play / TEST (scenario launcher) / Quit. `--autoplay` and
## `--scenario N` skip the menu; `--screenshot <dir>` captures menu.png first.

const GameScript := preload("res://scripts/game.gd")
const Rules := preload("res://scripts/rules.gd") # NO-190: Rules.ENEMY, for the tier icons' side
const BackGuard := preload("res://scripts/back_guard.gd")
const Scenarios := preload("res://data/scenarios.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Guide := preload("res://scripts/guide.gd")
const Settings := preload("res://scripts/settings.gd")
const CloudSave := preload("res://scripts/cloud_save.gd")
const Armies := preload("res://scripts/armies.gd")
const PieceMass := preload("res://scripts/piece_mass.gd") # NO-157
const Account := preload("res://scripts/account.gd")
const SaveConfig := preload("res://scripts/save_config.gd")
const Leaderboard := preload("res://scripts/leaderboard.gd")
const GlobalBoard := preload("res://scripts/global_board.gd")
const Connectivity := preload("res://scripts/connectivity.gd")
const HudScript := preload("res://scripts/hud.gd") # HEADER_H, for the TEST menu's device-info readout

const PlayBridge := preload("res://scripts/cloud/play_games_bridge.gd")
const IosBridge := preload("res://scripts/cloud/ios_cloud_bridge.gd")


## ONE sign-in flow, two bridges. The iOS bridge mirrors the Android one's
## static surface and signals exactly (issue 87 copied issue 86 on purpose),
## so the menu never branches on platform beyond these two pickers.
## ONE platform predicate. OS.get_name() == "iOS" was written out at three
## separate decision points here, so a fourth platform meant finding all three
## (NO-37). cloud_save.gd's _default_backend keeps its own three-arm match on
## OS.get_name(): it chooses between iOS, Android AND a desktop no-op, which is
## a switch rather than this boolean, and folding it in here would make it less
## clear, not more.
static func _IS_IOS() -> bool:
	return OS.get_name() == "iOS"


static func _BRIDGE() -> GDScript:
	return IosBridge if _IS_IOS() else PlayBridge


## The provider this platform can actually sign into: Game Center on iOS,
## Play Games elsewhere. The other button refuses with the honest message.
static func _NATIVE_PROVIDER() -> String:
	return Account.APPLE if _IS_IOS() else Account.GOOGLE


## Where to send a player whose sign-in does not land. This is the one place
## the two platforms genuinely differ, and it decides whether a failure is a
## retry or a dead end: Play Games presents its own sign-in, so retrying can
## work. Game Center CANNOT — once iOS has stopped offering the prompt (the
## player is signed out, or dismissed it enough times), authenticate() is
## accepted and simply never answers. Retrying that forever is the loop; the
## device's own Settings is the only way through, so the message says so.
static func _RETRY_HINT(prov: String) -> String:
	return " Check Settings › Game Center on this device." if prov == Account.APPLE \
		else " Check your connection."

## How long the login screen waits for the provider before handing the buttons back.
## Two native round trips (authenticate, then load the player) on a phone that
## may have just lost signal — generous enough not to cut off a slow-but-working
## sign-in, short enough that a dead one does not strand the player.
const SIGN_IN_TIMEOUT := 30.0

## The login screen's resting status line. One const so the two places that
## show it — first build, and every re-open — cannot drift.
const LOGIN_TAGLINE := "Your progress follows your account."

## NO-64: the reason shown beside a control that needs the network while there
## is none. Plain on purpose — presentation is Max's to rule on.
const OFFLINE_REASON := "No internet connection"

## NO-158's tint for a bordered panel nested inside another panel — a subtle
## white overlay that reads as "one shade lighter than its parent" regardless
## of what that parent's own colour is. Shared by the TEST list's row_style,
## the Army carousel's card_style, and the tier rows (_update_tier_outline) —
## one constant so the three can't quietly drift apart (CLAUDE.md: "bitten
## five times by two constants that happen to agree").
const NESTED_PANEL_TINT := Color(1, 1, 1, 0.06)

## Every mirrored save, as cloud key -> local file. The single place that
## mapping lives: boot sync, and the post-sign-in re-sync, both walk this.
static func _SYNC_KEYS() -> Dictionary:
	return {
		"run": GameScript.SAVE_PATH,
		"scores": GameScript.SCORES_PATH,
		"history": GameScript.HISTORY_PATH,
	}


## The local saves an account owns. Passed to Account.sign_in so the rebind
## restamps them — the guest's progress comes with them because it was never a
## separate history, it was this one under the old id.
static func _SAVE_PATHS() -> Array:
	return _SYNC_KEYS().values()


## SET-shaped keys sync by per-entry union; the run is a STATE and resolves by
## picking a side. See leaderboard.gd's header for why a board synced by
## pick-a-side silently deletes the other device's real entries.
static func _MERGER(key: String) -> Callable:
	return Leaderboard.merger_for(key) # NO-37: the table lives beside the mergers


static var window_sized := false # once per launch, not on every return to menu


## Android's hardware Back. Godot's default for it is to quit the app outright,
## which on a portrait phone game means the primary navigation gesture kills the
## session from any screen — see quit_on_go_back in project.godot.
##
## Back means "up one level": close whatever panel is open and return to the main
## menu. From the main menu itself there is nowhere up, so it quits, which is what
## Android users expect at the root of an app.
##
## The login screen deliberately does NOT quit and does not dismiss: on a first
## run the player has to pick something, and "Play as Guest" is right there and
## always live. Quitting on Back would make a stray gesture look like a crash on
## the very first screen anyone sees.
func _notification(what: int) -> void:
	# NO-64: turning airplane mode off means pulling down Control Center or the
	# notification shade, which takes focus from the app — so the return of focus
	# is exactly when a greyed control may need to come back. The poll covers the
	# rest.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_apply_connectivity()
		return
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if BackGuard.is_duplicate():
		return # NO-61: Android raises this TWICE per press. See back_guard.gd.
	if login_center != null and login_center.visible:
		return
	# The tier picker goes back to the army picker, not to the main menu, so the
	# gesture lands where its own Back button does. Checked first because both
	# are visible in that state.
	if is_instance_valid(rank_center) and rank_center.visible:
		rank_center.visible = false
		army_center.visible = true
		return
	# NO-147: TEST and About now live inside Settings, and Games History
	# inside Scores — same "Back lands where its own on-screen button does"
	# shape as the tier picker above, so all three get bespoke treatment
	# rather than the generic main-menu jump below.
	if is_instance_valid(test_scroll) and test_scroll.visible:
		test_scroll.visible = false
		settings_panel.visible = true
		return
	if is_instance_valid(about_center) and about_center.visible:
		about_center.visible = false
		settings_panel.visible = true
		return
	if is_instance_valid(history_scroll) and history_scroll.visible:
		history_scroll.visible = false
		scores_center.visible = true
		return
	var panels: Array[Control] = [army_center, scores_center,
		guide_scroll, settings_panel, device_info_center]
	for p in panels:
		if is_instance_valid(p) and p.visible:
			p.visible = false
			main_box.visible = true
			return
	get_tree().quit()


## A cloud snapshot arrived for `key` — mirror it to disk through the normal
## resolve path, so the cloud copy only wins where it would have won at boot.
## The connection dies with this menu instance, so returning to the menu
## reconnects rather than stacking handlers. (issue 86 / T4)
func _on_snapshot_loaded(key: String) -> void:
	var paths := _SYNC_KEYS()
	if paths.has(key):
		CloudSave.sync_file(key, paths[key], _MERGER(key))
	if key == "run":
		_refresh_continue() # NO-88: the restore just landed; offer it now, not next launch


## Show Continue exactly when the save on disk can be READ (see the comment at
## the button's build), and stage that save for the press. Re-run whenever the
## run file may have changed under a built menu.
func _refresh_continue() -> void:
	_continue_save = null
	if FileAccess.file_exists(GameScript.SAVE_PATH):
		_continue_save = JSON.parse_string(FileAccess.get_file_as_string(GameScript.SAVE_PATH))
	continue_button.visible = SaveConfig.is_loadable(_continue_save)


## THE ONE PLACE A SIGN-IN VERDICT IS HANDLED — binding, cloud fetch and UI.
##
## Reached three ways, and it must behave identically for all of them: the
## plugin's silent check at startup, a button press, and a verdict that lands
## after the screen gave up waiting. Everything below is therefore written to
## run with or without the login screen on screen.
func _on_sign_in_finished(ok: bool) -> void:
	# Whether the PLAYER started this. The boot check fails on every device with
	# no Google session, and reporting that as a failed sign-in would accuse a
	# first-run player of an attempt they never made, on a screen they have not
	# touched yet. Only an attempt gets a result.
	var was_interactive := _sign_in_gen != 0
	_sign_in_gen = 0
	_set_providers_disabled(false)
	if not ok:
		# Already BOUND means the session lapsed rather than never existing, and
		# the way back to this screen is otherwise guest-only — so without this
		# the cloud goes dark with nothing offering a retry.
		if sync_button != null and Account.signed_in():
			sync_button.text = "Reconnect to sync"
			sync_button.visible = true
		# Written whether or not the screen is still up: the guest exit stays
		# live during an attempt, so the player may already have left. This text
		# only needs to be true for a player still watching — a later re-entry
		# resets the note to the tagline anyway.
		if was_interactive:
			login_note.text = "%s sign-in didn't complete.%s You can try again." \
				% [Account.label(_NATIVE_PROVIDER()), _RETRY_HINT(_NATIVE_PROVIDER())]
		return
	# ADOPT the local saves only when there is one history to adopt. account.gd
	# states the premise the rebind rests on: "it never merges two histories,
	# because until sign-in there is only one." That is true for a guest, and
	# FALSE for a player who changes the device's Google account.
	#
	# Rebinding on a switch restamps account A's saves as B's, and the fetch
	# below then resolves A's local run against B's cloud one — highest wave
	# wins, and resolve() does not read owners — so A's deeper run overwrites
	# B's saved game permanently. Scores and history carry no wave and fall to
	# last-write-wins, taking B's outright. Silent, and it destroys the data of
	# an account the player was not even playing.
	#
	# That was why a switch originally did NOTHING here. NO-11 then replaced the
	# no-op with switch_to, which resolves the danger above a different way: it
	# PARKS account A's saves under A's id instead of restamping them as B's, so
	# the two histories never meet and switching back restores A intact. NO-31
	# adds the consent gate — the player is asked before the install re-homes.
	#
	# Declining keeps exactly the pre-NO-11 behaviour for the session: no rebind,
	# no fetch, and is_available() stays false while the ids disagree, which keeps
	# the rest of the session from pushing A's progress into B. Genuinely
	# SIMULTANEOUS accounts would still need per-account local saves — a real
	# feature and a design call, not something to guess at. See issue 86.
	var id: String = CloudSave.backend.account_id()
	# ONLY WHEN THE PLAYER ASKED. A verdict that arrives on its own must not
	# convert a guest who deliberately chose "Play as Guest", and on a first run
	# it must not answer the login screen's question on their behalf — both were
	# possible while any successful verdict bound whatever was unbound, and
	# neither can be undone, because nothing in the game signs you out.
	#
	# GOOGLE because Play Games is the only provider that reaches this signal;
	# Game Center is issue 87 and needs its own path.
	if id != "" and was_interactive and not Account.signed_in():
		# NO-54: the name is recorded WITH the bind, because this is the only
		# moment it is knowable — once another account signs in, nothing can say
		# what this one was called.
		Account.sign_in(_NATIVE_PROVIDER(), id, _SAVE_PATHS(),
			CloudSave.backend.account_name())
	# NO-11: the device's account changed under a signed-in install. The branch
	# above cannot catch it — it requires NOT signed in — so before this the
	# mismatch fell through every path and sync just went quiet. switch_to
	# parks the outgoing owner's saves and reclaims the incoming account's, and
	# refuses on its own when this is really a guest conversion or a first bind.
	#
	# NO-31: ASK first. NO-11 called switch_to straight from here, on every
	# verdict including the silent boot check, so a device whose Google account
	# changed re-homed the install with nothing on screen saying so. Nothing was
	# lost — parking is reversible — but the consent gate that binding has was
	# missing. Now the mismatch raises a prompt and returns; the rebind happens
	# in _on_switch_accepted, through the same switch_to.
	#
	# NO-86: ONLY when a real account owns the install — the same test switch_to
	# applies before it will act. An empty owner (fresh install, or after a
	# logout) and a guest both differ from `id` too, and were asked to "switch"
	# to a button that refused: on the iPhone the silent boot verdict raised
	# this inside the hidden main_box, the player's press then bound through
	# the branch above, and the menu came up wearing the stale prompt. Those
	# two fall through to the tail instead, where the login screen (or the
	# guest's sync button) is left up for the press that binds.
	elif id != "" and Account.signed_in() and Account.owner() != id \
			and not _switch_declined:
		_ask_to_switch(id)
		return
	if Account.owner() == id:
		if sync_button != null:
			sync_button.visible = false
		_finish_login()
		CloudSave.drain_queue() # safe: sign_in() clears a queue owned by anyone else
		for key: String in _SYNC_KEYS():
			_BRIDGE().fetch(key)
		return
	# Nothing to bind and nothing to sync — either a guest/first-run who has not
	# chosen (leave the screen up for them), or an account SWITCH: signed in as
	# someone other than this install's owner. A switch has no safe resolution
	# without per-account saves (issue 86), so the main menu offers no control
	# for it — a button that cannot help is a worse answer than none. The Scores
	# screen names the state ("signed in as a different account") for a player
	# who goes looking.
	#
	# But a PRESS deserves a verdict. A bound player who tapped Google and got
	# a mismatched account back was left staring at "Signing in…" forever — the
	# attempt succeeded, just as someone else, so the failure path never wrote a
	# word. Continue offline remains the exit.
	if was_interactive and Account.signed_in():
		login_note.text = "This device is signed in as a different %s account." \
			% Account.label(_NATIVE_PROVIDER())


## Logging out returns to the LOGIN SCREEN, not to guest play: becoming a guest
## is a decision the player did not make (user ruling, 2026-09-05). Both exits
## from that screen stay live, so this cannot strand anyone.
##
## The device is still signed in natively — no mobile provider lets an app end
## the OS session — so pressing the provider button again binds immediately and
## Account.sign_in() hands back everything logout parked. That is the intended
## round trip, not a leak.
func _on_logout() -> void:
	Account.logout(_SAVE_PATHS())
	main_box.visible = false
	login_note.text = LOGIN_TAGLINE
	_set_providers_disabled(false)
	if sync_button != null:
		sync_button.visible = false
	# This button chose its label when the screen was BUILT, and the screen is
	# not rebuilt on the way here — so without this a logged-out player is
	# offered "Continue offline" on a device with nothing left to continue.
	if guest_button != null:
		guest_button.text = "Play as Guest"
	login_center.visible = true


## Dismiss the login screen — but only if it is what the player is looking at.
## A verdict can land long after they left it for Settings, the Guide or Scores,
## each of which hides main_box, and showing main_box unconditionally would
## surface the menu underneath whatever they opened. Signing in never moves the
## player.
## NO-31: raise the switch prompt. Names BOTH accounts, because "an account
## changed" without saying which is not something a player can answer.
func _ask_to_switch(id: String) -> void:
	_switch_pending_id = id
	# NO-54: NAMES, not ids. Both halves: the live account through the backend,
	# the outgoing one from what was stored when it was bound. NO-76: a side with
	# no recorded name gets a generic label, never its id — the iPhone showed a
	# 64-hex Game Center id, which no player can recognise as theirs.
	switch_prompt_label.text = ("This device is now signed in to %s as %s.\n" +
		"This install's progress belongs to %s.\nSwitch to the new account?") \
		% [Account.label(_NATIVE_PROVIDER()),
			_who(switch_prompt_label, CloudSave.backend.account_name(), "another account"),
			_who(switch_prompt_label, Account.owner_name(), "this device's account")]
	switch_prompt.visible = true


## Yes: rebind through the SAME switch_to NO-11 used, then do the post-bind work
## the verdict path would have done had it not returned to ask.
func _on_switch_accepted() -> void:
	var id := _switch_pending_id
	_switch_pending_id = ""
	switch_prompt.visible = false
	Account.switch_to(_NATIVE_PROVIDER(), id, _SAVE_PATHS(),
		CloudSave.backend.account_name()) # NO-54
	if Account.owner() != id:
		return # switch_to refused (guest conversion / first bind); it owns that call
	if sync_button != null:
		sync_button.visible = false
	_finish_login()
	CloudSave.drain_queue()
	for key: String in _SYNC_KEYS():
		_BRIDGE().fetch(key)


## No: the pre-NO-11 behaviour for the rest of the session. Say so on the login
## note rather than going quiet — going quiet is the defect NO-11 set out to fix,
## and declining must not reintroduce it.
func _on_switch_declined() -> void:
	_switch_declined = true
	_switch_pending_id = ""
	switch_prompt.visible = false
	# NO-54: the second site, and the one a fix scoped to the prompt misses —
	# this line carries a raw id too, on the screen the player is left looking at
	# after declining.
	login_note.text = ("Playing as %s. This device is signed in to a different " +
		"%s account, so sync is paused until you accept the switch.") \
		% [_who(login_note, Account.owner_name(), "this device's account"),
			Account.label(_NATIVE_PROVIDER())]


func _finish_login() -> void:
	if not login_center.visible:
		return
	login_center.visible = false
	main_box.visible = true


## `locked` is the in-flight sign-in lock; being offline disables them too, so
## every caller releasing the lock cannot re-enable a button with no network.
func _set_providers_disabled(locked: bool) -> void:
	for b in provider_buttons:
		b.disabled = locked or not _online


## NO-64: disable, with a reason, every control that needs the network — never
## hide it (a hidden button reads as "this game has no sign-in", a greyed one as
## "not now": the Shop's precedent, issue 101). Continue offline / Play as Guest
## are deliberately untouched: they are the way out.
##
## Re-run by a 1 s poll and on regaining focus, so a control greyed by airplane
## mode comes back when the player turns it off. See connectivity.gd.
func _apply_connectivity() -> void:
	# Not built yet: _ready is still assembling, or a CLI bypass returned early.
	if provider_offline_note == null:
		return
	_online = Connectivity.online()
	_set_providers_disabled(_sign_in_gen != 0)
	provider_offline_note.visible = not _online
	if sync_button != null:
		sync_button.disabled = not _online
		sync_offline_note.visible = not _online and sync_button.visible
	if is_instance_valid(global_btn):
		global_btn.disabled = not _online
		global_offline_note.visible = not _online


## The plain one-line reason under a disabled control. Same size and fade as the
## Scores screen's existing status line, so it introduces no new styling.
func _offline_note(parent: Container) -> Label:
	var l := Label.new()
	l.text = OFFLINE_REASON
	l.add_theme_font_size_override("font_size", 12)
	l.modulate = Color(1, 1, 1, 0.55)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.visible = false
	parent.add_child(l)
	return l


## Start an interactive sign-in. Everything that happens AFTER this — binding,
## the UI, the cloud fetch — belongs to _on_sign_in_finished, which also
## handles the boot verdict this button never sees.
func _on_provider_pressed(prov: String) -> void:
	# supported() is the PLATFORM question. is_available() reports whether an
	# ACCOUNT is attached, which is false until sign-in completes — guarding on
	# it here would mean the button refused forever. ADR 0003.
	#
	# Both providers are implemented now (86 Play Games, 87 Game Center); this
	# refuses the one this platform is not — Google on an iPhone, Apple on
	# Android — where no amount of retrying could ever succeed.
	if prov != _NATIVE_PROVIDER() or not _BRIDGE().supported():
		login_note.text = "%s sign-in isn't available on this device yet." % Account.label(prov)
		return
	# Already authenticated silently — so there is a session, but this press is
	# what makes it CONSENTED. Run the verdict path directly rather than calling
	# begin_sign_in(): the native side may not re-emit for a session it has
	# already authenticated, and the buttons would then stay locked until the
	# timeout told the player a sign-in failed while they were signed in.
	#
	# The counter is bumped first so the handler sees an interactive attempt and
	# will bind — this is the path a guest takes to sign in, and it is the only
	# one that may convert them.
	if _BRIDGE().signed_in:
		_sign_in_gen += 1
		_on_sign_in_finished(true)
		return
	_sign_in_gen += 1
	var gen := _sign_in_gen # this press's identity, for its timer alone
	login_note.text = "Signing in…"
	_set_providers_disabled(true) # one press at a time; Guest stays live
	# Neither native hop is guaranteed to answer — a phone that just lost signal
	# simply never calls back — and the screen would otherwise sit on "Signing
	# in…" forever. The guest exit stays available throughout, but the provider
	# buttons have to come back too.
	#
	# `_sign_in_gen` makes this and the verdict mutually exclusive: whichever
	# lands first zeroes it, and the other finds nothing to do. Comparing against
	# `gen` rather than merely testing non-zero is what stops a timer outliving
	# its own press and firing on a later one. The tree check matters because a
	# SceneTreeTimer outlives this menu — the player can take the guest exit,
	# start a run, and free every node touched here.
	get_tree().create_timer(SIGN_IN_TIMEOUT).timeout.connect(func() -> void:
		if not is_inside_tree() or _sign_in_gen != gen:
			return
		_sign_in_gen = 0
		login_note.text = "%s sign-in timed out.%s You can try again." \
			% [Account.label(prov), _RETRY_HINT(prov)]
		_set_providers_disabled(false))
	_BRIDGE().begin_sign_in()

var main_box: VBoxContainer
var continue_button: Button # NO-88: shown/hidden by _refresh_continue
var _continue_save: Variant = null # the readable save Continue will load, or null
var guest_button: Button # relabelled by _on_logout; see there
var test_scroll: ScrollContainer
## NO-58: the TEST list's search box, and the state _apply_test_filter needs.
##
## `_test_open` is an INDEX rather than the old "is rows[0] visible" test. That
## test read visibility back to decide what to do to visibility, which works
## only while the accordion is the sole writer of it — and a filter is a second
## writer. One place decides, from state it owns.
var test_filter: LineEdit
var test_head: Label
## NO-69: the soft keyboard covers the TEST list's results (measured on the
## Android emulator: ~47% of the screen, hiding all but ~7 of 30 rows). -1
## means "ask DisplayServer for real"; tests set this to inject a height
## without a real IME, then call _update_test_scroll_for_keyboard() directly.
var keyboard_height_override := -1
var _test_sections: Array = [] # {rows, head, relabel} per section, in list order
var _test_open := -1 # index into _test_sections, or -1 for "all collapsed"
var army_center: VBoxContainer # NO-146: the carousel's own ScrollContainer is nested inside now
## NO-179 follow-up: wraps army_row so it can be vertically centred inside
## army_scroll's REAL height — see _show_armies. A ScrollContainer always
## places its single child flush at its own top-left (hud.gd NO-135), so
## leaving army_row as that child directly collects all the dead space below
## the card instead of splitting it above and below.
var _army_row_wrap: CenterContainer
var rank_center: PanelContainer # NO-190: a background panel now, not a bare CenterContainer
## NO-159: index into Tuning.TIERS — which tier is selected right now, drawn
## as a blue outline enclosing tiers 1..this one. NO-190: Confirm is what
## actually starts the run; a tier tap only ever selects
## (test_menu_clicks.gd reads this directly, same convention as _test_open).
var _selected_tier := 0
## NO-190: one Button per tier, in Tuning.TIERS order — index i is tier i.
## The buttons carry no text any more (the "Tier N" label was removed), so
## test_menu_clicks.gd can't find them by text; it reads this array directly
## instead, same convention as _selected_tier above.
var _tier_buttons: Array[Button] = []
var seed_field: LineEdit # issue 75
var scores_center: CenterContainer
var history_scroll: ScrollContainer
var about_center: CenterContainer
## Diagnostic-only (no issue yet, 2026-09-18): Max reported the Header
## reserving extra space on a phone he describes as having no notch, and
## desktop could not reproduce it. Nobody has read DisplayServer's actual
## numbers off that hardware, and a device-model lookup table was rejected
## as unbounded — the platform already reports this, so this panel just
## surfaces it. Read-only; never touches layout.
var device_info_center: CenterContainer
var guide_scroll: Control # NO-189: a hub + sub-pages now, not a bare ScrollContainer
var settings_panel: CenterContainer
var login_center: CenterContainer # issue 83, first run only
var login_note: Label # the login screen's status line
## NO-31: the device's account changed under a signed-in install. Rebinding is
## reversible -- switch_to parks the outgoing owner's saves and reclaims the
## incoming account's -- but it is not invisible, and BINDING already asks: the
## first-bind path below is gated on was_interactive, i.e. the player pressed
## the button. A silent re-home was the one consent gate missing.
var switch_prompt: VBoxContainer
var switch_prompt_label: Label
var _switch_pending_id := "" # the incoming account waiting on an answer
## Answered "Not now" THIS SESSION. Deliberately not persisted: the prompt
## re-appears on the next boot, not on every verdict (a verdict can arrive
## several times a session, and re-asking each time is nagging, not consent).
var _switch_declined := false
var provider_buttons: Array[Button] = [] # Google/Apple; locked during a sign-in

## Which sign-in attempt is in flight, or 0 for none. A COUNTER not a bool, so
## a timeout can tell whether it belongs to the attempt still running: press,
## get refused, press again inside 30s — which the refusal message invites —
## and with a bool the first press's timer fires on the second press's flag,
## unlocking the buttons mid-sign-in. Doubles as `was_interactive`.
var _sign_in_gen := 0

## The main menu's "Sign in to sync", for a guest. A MEMBER rather than a local
## because _on_sign_in_finished has to hide it: an account can bind without any
## button being pressed — the plugin signs in silently at boot — and a local
## would leave it advertising sign-in to an account that just signed in.
var sync_button: Button

## NO-64: whether the phone last said there is a connection, and the reason
## labels shown under each network-only control while it says there is not.
var _online := true
var sync_offline_note: Label
var provider_offline_note: Label
var global_btn: Button # the Scores screen's door; rebuilt with that screen
var global_offline_note: Label


## Did the launch ask for a specific window size? `--resolution` cannot be
## detected as a FLAG — Godot consumes it and strips it from both
## OS.get_cmdline_args() and get_cmdline_user_args() (verified 2026-09-08: a
## `--resolution 600x800` boot reports an arg list of just ["-s", "<script>"]).
## It has already been APPLIED by the time this runs, though, so the window
## differing from the project default IS the request.
static func _window_size_requested() -> bool:
	var want := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 480)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 800)))
	return DisplayServer.window_get_size() != want


## NO-158/NO-179: the Army carousel card. NO-158 first gave each card a
## bordered, backgrounded panel (see card_style in the carousel build below)
## so a peeking neighbour reads as a card edge, not raw prose — that stays.
## NO-179 originally scaled non-resting cards down to a small peek; Max
## rejected that ("can we just make a normal carousel with out changing any
## dimensions of the other cards?") — every card is now rendered at the SAME
## size, full scale, all the time. Every card occupies the SAME slot width,
## ARMY_CARD_WIDTH_FRACTION of the scroller, with a spacer on each end (see
## the carousel build) so the resting card sits centred and its full-size
## neighbours simply extend past the viewport edge on each side, showing a
## plain uncropped-looking slice — an ordinary carousel peek, not a preview
## render.
##
## The width fraction is content-driven, not aesthetic: Horde's Starting
## Pieces crowd (PieceMass.build() of 14 pawns, the widest of the 6 Armies)
## measures ~218.2px wide at PieceMass's own ICON=52 constant (was ~198.4px
## before V3 raised ROW_PITCH enough to drop PieceMass._choose_rows()'s own
## pick for that count from 4 rows to 3 — fewer rows means more columns,
## hence wider — see piece_mass.gd's own build() comment), and needs to fit
## inside the card with room either side. 280px clears that with ~41.8px to
## spare and is the known-good absolute width already shipped. NO-179
## full-width follow-up: scroll_w changed (army_scroll lost its 40+40
## inset, see _show_armies) from 400 to the full 480px viewport, so the
## fraction is re-derived to hold card_w at that same 280px: 280/480 = 7/12.
const ARMY_CARD_WIDTH_FRACTION := 7.0 / 12.0
## NO-179 (Max: "longer playing card ratio... 2.5:3.5"): width:height of a
## standard playing card. Card height is DERIVED from this and card_w, never
## a second literal that has to be kept in sync by hand.
const ARMY_CARD_RATIO := 2.5 / 3.5
## NO-179 (Max: "cards have currently no margin in between them, lets add
## some"): gap between card slots — replaces the old separation:0.
const ARMY_CARD_MARGIN := 16.0


func _ready() -> void:
	# CLI bypasses/probes boot Game.tscn straight past this scene, so it also
	# applies at its own _ready() — belt and suspenders, both are idempotent.
	# Carries issue 74's hard-edged text as well as the sound setting.
	Settings.apply(Settings.load_settings())
	# real boots only — the click probes instantiate the menu by hand and inject
	# clicks at 480×800 coords, which a mid-probe resize would break.
	# NO-33 slice 3: and never when the launch asked for a window size. This
	# resize is unconditional-once-per-launch, so it silently OVERWROTE
	# --resolution — three tablet captures for the NO-25 audit came back
	# byte-identical before anyone spotted why, and the design-C format work was
	# done in HTML rather than in-engine for the same reason.
	if not window_sized and DisplayServer.get_name() != "headless" \
			and not _window_size_requested() \
			and get_tree().current_scene == self:
		window_sized = true
		var usable := DisplayServer.screen_get_usable_rect()
		var h: int = usable.size.y - 40 # title-bar allowance
		get_window().size = Vector2i(int(h * 480.0 / 800.0), h) # keep portrait aspect
		get_window().move_to_center()
	var args := OS.get_cmdline_user_args()
	# NO-77: once only — the args outlive the first Game, this scene does not.
	if not GameScript.cli_bypass_used \
			and (args.has("--autoplay") or args.has("--scenario")):
		get_tree().change_scene_to_file.call_deferred("res://scenes/Game.tscn")
		return
	# issue 84: send anything queued while offline BEFORE pulling the mirror.
	# Draining after the pull would resolve this device's progress against a
	# cloud copy that is missing the very sessions still sitting in the queue.
	CloudSave.drain_queue()
	# pull the cloud mirror before deciding what's on disk (12): a no-op on
	# desktop today, but on iOS/Android (once the native plugin lands) this
	# is what makes a fresh install offer "Continue" from another device.
	for key: String in _SYNC_KEYS():
		CloudSave.sync_file(key, _SYNC_KEYS()[key], _MERGER(key))
	# A snapshot fetched after sign-in lands asynchronously, long after the
	# sync above has run. Mirroring it to disk is what actually restores
	# progress on a fresh device. Null off Android, where nothing fetches.
	# (issue 86 / T4)
	var bridge := get_node_or_null(
		"/root/IosCloudBridge" if _IS_IOS() else "/root/PlayGamesBridge")
	if bridge != null:
		bridge.snapshot_loaded.connect(_on_snapshot_loaded)
		# Connected HERE, not inside the login button, and this distinction is
		# load-bearing. The sync above runs while is_available() is still false —
		# the plugin's own startup auth check has not answered yet — so all three
		# calls no-op. The answer arrives on this signal, and on every launch
		# after the first there is no login screen to have connected a listener.
		# Wiring it only to the button meant the cloud was pulled exactly once in
		# an install's life, so "continue from another device" quietly did
		# nothing for the returning player. (issue 86 / T4)
		bridge.sign_in_finished.connect(_on_sign_in_finished)
		# ...and CATCH UP on a verdict that already happened, because connecting
		# is not enough. The plugin answers its startup check in a second or two;
		# this menu does not exist until the 11.3s intro finishes, and it is
		# rebuilt from scratch every time a run ends. So on a normal launch the
		# boot verdict was emitted while nothing was listening, and nothing ever
		# asked again — the account never bound, an account switch never
		# rebound, and the Reconnect button never appeared. The signal is not a
		# queue; the bridge's cached state is what survives, so read that.
		#
		# Deferred so it runs after this _ready has built main_box and
		# sync_button, which the handler touches.
		if bridge.signed_in:
			_on_sign_in_finished.call_deferred(true)
		elif bridge.sign_in_attempted:
			_on_sign_in_finished.call_deferred(false)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 24)
	center.add_child(main_box)

	var title := Label.new()
	title.text = "NO KINGS"
	title.add_theme_font_size_override("font_size", 48)
	main_box.add_child(title)
	# NO-31: the account-switch consent prompt. Inline on the main menu rather
	# than a modal, matching the logout confirm in settings.gd — the verdict that
	# raises it usually lands at boot, with the main menu already up.
	switch_prompt = VBoxContainer.new()
	switch_prompt.add_theme_constant_override("separation", 8)
	switch_prompt.visible = false
	main_box.add_child(switch_prompt)
	switch_prompt_label = Label.new()
	switch_prompt_label.add_theme_font_size_override("font_size", 13)
	switch_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_prompt.add_child(switch_prompt_label)
	_wrap_account_text(switch_prompt_label) # NO-55 — after add_child: it reads the theme font
	_button(switch_prompt, "Switch account", 20, _on_switch_accepted)
	_button(switch_prompt, "Not now", 20, _on_switch_declined)
	# Offered on whether the save can actually be READ, not on whether a file is
	# there. The old check was file_exists alone, which fed JSON.parse_string
	# straight into the run — so a corrupt file loaded `null`, and a save from a
	# newer build loaded fields this one does not understand.
	#
	# Cloud sync is what made that reachable: sync_file writes whatever resolve()
	# picks, and resolve() compares waves and timestamps, not schema versions. A
	# phone on the newer build could hand this one a save it cannot read, and
	# Continue would break every time it was pressed, forever, with no way to
	# clear it from the menu. Hiding the button leaves Play working and the other
	# build's save intact. (issue 86)
	#
	# NO-88: built ALWAYS and shown by _refresh_continue, because the save it
	# offers can arrive after this menu exists — on a fresh install the player
	# signs in FROM this menu, and the cloud run lands later, on
	# _on_snapshot_loaded. Building it only here left that restore invisible
	# until a relaunch.
	continue_button = _button(main_box, "Continue", 32, func() -> void:
		GameScript.next_config = _continue_save
		GameScript.is_scenario = false
		get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	_refresh_continue()
	_button(main_box, "Play", 32, _show_armies)
	_button(main_box, "Scores", 24, _show_scores)
	_button(main_box, "Guide", 24, func() -> void:
		main_box.visible = false
		guide_scroll.visible = true)
	# issue 83's ruling — "a guest keeps their progress when they sign in" — had
	# no way to happen: the login screen only ever appears on a first run, so
	# once start_guest() wrote an account file, Account.sign_in()'s rebind was
	# unreachable by any player. This is the entry point that makes it real.
	# Hidden once signed in, and on any platform that cannot sync at all.
	#
	# BUILT whenever the platform can sync, but only SHOWN to a guest up front.
	# The other case it exists for is a player already bound to Google whose
	# session has lapsed — revoked access, or a Play Games account removed from
	# the device. Their provider is not guest, so a guest-only test left them
	# with no manual retry at all, dependent on a silent check that had just
	# failed. It stays hidden until sign-in actually reports failure, so a normal
	# launch never flashes a Reconnect button at a player who is about to be
	# signed in a moment later. See _on_sign_in_finished.
	if _BRIDGE().supported():
		sync_button = _button(main_box, "Sign in to sync", 24, func() -> void:
			login_note.text = LOGIN_TAGLINE # clear any stale "timed out" / "didn't complete"
			main_box.visible = false
			login_center.visible = true)
		sync_button.visible = Account.provider() == Account.GUEST
		sync_offline_note = _offline_note(main_box)
		# its visibility is flipped from several places; the note follows it
		sync_button.visibility_changed.connect(_apply_connectivity)
	_button(main_box, "Settings", 24, func() -> void:
		main_box.visible = false
		settings_panel.visible = true)
	# NO-147 (Max, 2026-09-19): Quit is REMOVED, not merely hidden — "people
	# can just close the app." Android's hardware Back already quits from the
	# bare main menu (NO-61; the get_tree().quit() fall-through at the end of
	# _notification above), so the button only duplicated a platform
	# affordance every player already has. Do not re-add it on noticing it's
	# gone — this is deliberate.

	# Guide and Settings are shared with the in-game menu (scripts/guide.gd,
	# scripts/settings.gd) so the two entry points can't drift apart
	guide_scroll = Guide.build(self, func() -> void: main_box.visible = true, GameScript)
	settings_panel = Settings.build(self, func() -> void: main_box.visible = true,
		Callable(), _on_logout)
	# NO-147: About and TEST fold into Settings (eight main-menu entries down
	# to four). Appended here rather than inside settings.gd's own build() —
	# that panel is ALSO embedded in the in-game pause menu (hud.gd), and
	# neither About (main-menu chrome) nor TEST (a scenario launcher) belongs
	# mid-run. settings_panel.get_child(0) is that build()'s own
	# VBoxContainer, always ending [.., ← Back]; the two new rows are appended
	# and then moved in front of whatever is currently last, so Back stays
	# the last row regardless of whether the Log out rows above it exist.
	var settings_box := settings_panel.get_child(0) as VBoxContainer
	var settings_back := settings_box.get_child(settings_box.get_child_count() - 1) as Button
	var about_btn := _button(settings_box, "About", 24, _show_about)
	var settings_test_btn := _button(settings_box, "TEST", 24, _show_tests)
	settings_box.move_child(about_btn, settings_back.get_index())
	settings_box.move_child(settings_test_btn, settings_back.get_index())

	# issue 83: the login screen. Shown ONLY on a first run — once an account
	# exists, needs_login() is false forever and this never appears again.
	#
	# Guest is a real account, not the absence of one: it owns saves exactly as
	# a signed-in account does, which is what lets sign-in REBIND that progress
	# instead of merging two histories.
	login_center = CenterContainer.new()
	login_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	login_center.visible = false
	add_child(login_center)
	var login_box := VBoxContainer.new()
	login_box.add_theme_constant_override("separation", 18)
	login_center.add_child(login_box)
	var login_head := Label.new()
	login_head.text = "NO KINGS"
	login_head.add_theme_font_size_override("font_size", 40)
	login_box.add_child(login_head)
	login_note = Label.new()
	login_note.add_theme_font_size_override("font_size", 13)
	login_note.modulate = Color(1, 1, 1, 0.6)
	login_note.text = LOGIN_TAGLINE
	login_box.add_child(login_note)
	# NO-55: the same treatment, because _on_switch_declined puts an account
	# label in here too — and this label sits in the login screen's own centred
	# box, which overflows exactly the same way.
	login_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wrap_account_text(login_note)
	for prov in [Account.GOOGLE, Account.APPLE]:
		provider_buttons.append(
			_button(login_box, "Sign in with %s" % Account.label(prov), 22,
				_on_provider_pressed.bind(prov)))
	provider_offline_note = _offline_note(login_box)
	# ALWAYS VISIBLE, AND NEVER DISABLED — this is the screen's only guaranteed
	# exit, and the one control that must work when everything else has failed.
	#
	# It does two jobs because the screen is reached two ways. On a first run it
	# creates the guest account. Reached from the main menu by a guest who chose
	# to sign in, it must NOT call start_guest() again — that would mint a new
	# guest id and orphan every save the old one owned, the exact data loss the
	# rebind exists to prevent — so there it is purely a way back out.
	#
	# It was previously hidden in that second case, which trapped the player:
	# every other exit from here requires a SUCCESSFUL sign-in, so a guest who
	# tapped "Sign in to sync" and then had no network had no way back to the
	# menu at all. Force-quitting the app was the only escape.
	guest_button = _button(login_box,
		"Play as Guest" if Account.needs_login() else "Continue offline",
		22, func() -> void:
			if Account.needs_login():
				Account.start_guest()
				# The player is a guest as of now, so the main menu's sign-in
				# entry applies to them. Its visibility was decided during
				# _ready, when there was no account at all and provider() was
				# "" — so without this it stays hidden until the next launch,
				# missing exactly the session in which a new player is most
				# likely to want it.
				if sync_button != null:
					sync_button.visible = true
			_finish_login())
	# The gate. --screenshot bypasses it too: a capture run on a machine with no
	# account would otherwise photograph the login screen instead of the menu,
	# which is a silent trap on any fresh checkout rather than a real result.
	#
	# The windowed probes deliberately do NOT take this bypass — they establish
	# an account and then drive the login screen for real. A bypass that is the
	# only tested path is exactly how this repo once green-lit a dead main menu.
	if Account.needs_login() and not args.has(Account.SKIP_ARG) \
			and not args.has("--screenshot"):
		main_box.visible = false
		login_center.visible = true

	# scenario submenu: scrollable list, hidden until TEST — hide the SCROLL
	# itself: a visible full-rect ScrollContainer eats every click beneath it
	test_scroll = ScrollContainer.new()
	test_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	# issue 77: vertical only — a long scenario name must wrap or clip, never
	# push the list sideways
	test_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	test_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER # NO-136
	# 2026-09-10 (Max, on the phone: "I can't scroll the test menu list ...
	# using touchscreen"). Every row here is a Button, and a Button's default
	# mouse_filter is STOP: Viewport::_gui_call_input marks a pointer press
	# handled at a STOP control and stops climbing, so the press never reached
	# this ScrollContainer and its touch-drag never started (Godot 4.7,
	# scroll_container.cpp: drag_touching is set in the press branch, motion is
	# ignored without it). The Guide panel drags fine because its body is a
	# Label. So the buttons below PASS instead, and this deadzone keeps a
	# slightly-moving tap a tap: past it the container fires
	# NOTIFICATION_SCROLL_BEGIN and BaseButton drops its press attempt, which is
	# how a drag that starts on a row scrolls instead of launching a scenario.
	# Regression probe: tests/test_touch_scroll.gd. UNVERIFIED ON DEVICE.
	test_scroll.scroll_deadzone = 24
	# 2026-09-06 (user: "horrible to use, scrolls awkwardly, x overflows"). The
	# list now runs nearly edge to edge; every row is a full-width button that
	# CLIPS with an ellipsis instead of pushing past the right edge; rows drop
	# their section's own prefix ("Artefact Common: " is the header already);
	# ONE section is open at a time; opening one scrolls it to the top so the
	# view never lands mid-list; and Back sits at the top, where it is
	# reachable without scrolling past an open section.
	test_scroll.offset_left = 12
	test_scroll.offset_top = 24
	test_scroll.offset_right = -12
	test_scroll.offset_bottom = -24
	test_scroll.visible = false
	add_child(test_scroll)
	var test_box := VBoxContainer.new()
	test_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_box.add_theme_constant_override("separation", 4)
	test_scroll.add_child(test_box)
	test_head = Label.new()
	test_head.text = "Test scenarios — %d boards" % Scenarios.all().size()
	test_head.add_theme_font_size_override("font_size", 22)
	test_box.add_child(test_head)
	# NO-58 (user ruling 2026-09-11: "Add a search box"). 385 scenarios in 50
	# sections, and the 16 sections with a single member fold into "Other" — all
	# 16 of which are HAND-WRITTEN, because a hand-written scenario is named
	# distinctively and that is exactly what makes it a section of one. The
	# grouping rule buries the entries that exist for hand-testing; a search is
	# what makes them reachable without scrolling past 380 generated boards.
	#
	# It COMPLEMENTS the accordion rather than replacing it — with the box empty
	# the list behaves exactly as before.
	test_filter = LineEdit.new()
	test_filter.placeholder_text = "search scenarios"
	test_filter.clear_button_enabled = true
	test_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# MUST NOT TAKE FOCUS ON SHOW, and this is the same load-bearing line the
	# seed field carries for the same reason: tests/test_menu_clicks.gd drives
	# THIS list with synthesised input, and a focused text field swallows the
	# probe's keystrokes. FOCUS_CLICK means it is focused by being clicked and
	# never by appearing.
	test_filter.focus_mode = Control.FOCUS_CLICK
	test_filter.text_changed.connect(func(_t: String) -> void: _apply_test_filter())
	# NO-69: only poll while the field is focused (mobile IME height has no
	# signal in Godot 4.7 — DisplayServer.virtual_keyboard_get_height() is
	# poll-only), and stop the moment focus leaves so desktop pays nothing.
	test_filter.focus_entered.connect(func() -> void: set_process(true))
	test_filter.focus_exited.connect(func() -> void:
		set_process(false)
		keyboard_height_override = -1
		_update_test_scroll_for_keyboard())
	set_process(false)
	test_box.add_child(test_filter)
	var back := _button(test_box, "← Back", 20, func() -> void:
		test_scroll.visible = false
		settings_panel.visible = true) # NO-147: TEST is reached through Settings now
	back.mouse_filter = Control.MOUSE_FILTER_PASS # touch-drag reaches the list
	# Diagnostic-only (2026-09-18, no issue yet): TEST is the one menu Android
	# reaches with no CLI flag — see device_info_center's own comment. Sits
	# beside Back so it's reachable without scrolling past the scenario
	# sections.
	var device_info_btn := _button(test_box, "Device info", 20, _show_device_info)
	device_info_btn.mouse_filter = Control.MOUSE_FILTER_PASS # touch-drag reaches the list, same as every row/header/Back above
	# issue 77: 53 scenarios in one flat column is unscannable. Sections are
	# DERIVED from the names rather than stored, so scenarios.gd is untouched
	# and anything added later groups itself by how it is named.
	#
	# The cut is at the first ":" OR "(", whichever comes first. Splitting on
	# ":" alone breaks on names whose colon sits inside parentheses
	# ("Recurring King (wave 100: ...)" -> a section literally called
	# "Recurring King (wave 100"). Cutting at "(" too fixes those and folds
	# "Piece Buffs (Buff Box: ...)" in with the other Piece Buffs entries.
	#
	# Sections with a single member collapse into "Other" — without that the
	# 53 split into 20 sections, 12 of them singletons, which is no more
	# scannable than the flat list it replaced.
	var groups := {}
	for s in Scenarios.all():
		var cuts: Array[int] = []
		for ch in [":", "("]:
			var at: int = s.name.find(ch)
			if at > 0:
				cuts.append(at)
		cuts.sort()
		var sec: String = s.name.substr(0, cuts[0]).strip_edges() if not cuts.is_empty() else "General"
		if not groups.has(sec):
			groups[sec] = []
		groups[sec].append(s)
	var singles := []
	for sec in groups:
		if groups[sec].size() == 1:
			singles.append(sec)
	for sec in singles:
		if not groups.has("Other"):
			groups["Other"] = []
		groups["Other"].append(groups[sec][0])
		groups.erase(sec)
	var ordered := groups.keys()
	ordered.sort_custom(func(a: String, b: String) -> bool:
		# biggest first, "Other" always last however big it gets
		if a == "Other":
			return false
		if b == "Other":
			return true
		return groups[a].size() > groups[b].size())
	# issue 79: sections COLLAPSE, and start collapsed. 77's sectioning was
	# enough for 53 entries; the 180 generated Artefact sandboxes take the list
	# to 240, and a 240-row scroll is the flat list all over again — the last
	# section would be minutes of dragging away. Collapsed-by-default turns the
	# whole catalog into nine headers on one screen, at the cost of one extra
	# click to reach any entry. That trade is only worth it at this size, which
	# is why 77 did not make it.
	_test_sections = [] # {rows, head, relabel} per section — the accordion
	_test_open = -1
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = NESTED_PANEL_TINT
	row_style.set_corner_radius_all(6)
	row_style.content_margin_left = 10
	row_style.content_margin_right = 10
	var head_style := StyleBoxFlat.new()
	head_style.bg_color = Color(0.22, 0.22, 0.28)
	head_style.set_corner_radius_all(6)
	head_style.content_margin_left = 10
	head_style.content_margin_right = 10
	for sec in ordered:
		var rows: Array[Button] = []
		var sec_head := Button.new()
		sec_head.alignment = HORIZONTAL_ALIGNMENT_LEFT
		sec_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sec_head.custom_minimum_size = Vector2(0, 44) # a thumb-sized row
		sec_head.mouse_filter = Control.MOUSE_FILTER_PASS # touch-drag reaches the list
		sec_head.add_theme_font_size_override("font_size", 16)
		sec_head.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		for style in ["normal", "hover", "pressed"]:
			sec_head.add_theme_stylebox_override(style, head_style)
		# NO-58: the count is now a PARAMETER. While a search is running the
		# header must say how many of its entries MATCH, not how many it holds —
		# "PIECE BUFFS (12)" above two visible rows is a header that lies.
		var relabel := func(open: bool, shown: int) -> void:
			sec_head.text = "%s  %s  (%d)" % ["▾" if open else "▸",
				sec.to_upper(), shown]
		relabel.call(false, groups[sec].size())
		test_box.add_child(sec_head)
		for s in groups[sec]:
			var row := _button(test_box, _test_row_text(s.name, sec), 15, func() -> void:
				GameScript.next_config = s.cfg
				GameScript.is_scenario = true # scenarios never autosave
				get_tree().change_scene_to_file("res://scenes/Game.tscn"))
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.clip_text = true # never wider than the list: ellipsis, not overflow
			row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.custom_minimum_size = Vector2(0, 40)
			row.mouse_filter = Control.MOUSE_FILTER_PASS # touch-drag reaches the list
			row.tooltip_text = s.name
			# NO-58: the FULL name, kept on the row, because that is what a search
			# has to match. The row's own text is _test_row_text(), which strips
			# the section prefix — "Artefacts: Tinfoil Hat" renders as "Tinfoil
			# Hat" — so matching row.text would silently never find anything by
			# its section name. set_meta rather than reusing tooltip_text: a
			# tooltip is display and could be changed for display reasons.
			row.set_meta("scenario_name", s.name)
			for style in ["normal", "hover", "pressed"]:
				row.add_theme_stylebox_override(style, row_style)
			row.visible = false
			rows.append(row)
		var my_index := _test_sections.size()
		_test_sections.append({"rows": rows, "head": sec_head, "relabel": relabel})
		sec_head.pressed.connect(func() -> void:
			# The accordion no longer writes visibility itself — it records WHICH
			# section is open and lets _apply_test_filter decide what that means.
			# One writer, so the filter and the accordion cannot disagree.
			_test_open = -1 if _test_open == my_index else my_index
			_apply_test_filter()
			# put the header at the top. Computed from the siblings above it
			# (hidden rows count nothing) rather than read back after a frame:
			# set_deferred lands after this frame's container sort, so the new
			# content height is known and nothing else has moved the scroll.
			var y := 0.0
			for c in test_box.get_children():
				if c == sec_head:
					break
				if c.visible:
					y += c.size.y + 4.0
			test_scroll.set_deferred("scroll_vertical", int(y)))

	# army select: Play goes here. NO-146: a horizontal CAROUSEL, one Army at a
	# time, each decorated by its starting pieces as a "group picture" (the
	# same treatment NO-141 gives the Reinforcements screen).
	#
	# NO-146 is the ONE deliberate exception to this codebase's "no horizontal
	# scrolling" rule (reference-site CLAUDE.md, carried into the game) — a
	# carousel's whole point is a sideways swipe. Do not read the scroller
	# below as an oversight and "fix" it back to vertical: test_scroll (the
	# TEST menu's scenario list, further up this file) sets
	# horizontal_scroll_mode to DISABLED on ITS OWN scroller for the opposite
	# reason — issue 77, "a long scenario name must wrap or clip, never push
	# the list sideways" — and the two are not the same container.
	army_center = VBoxContainer.new()
	army_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	army_center.offset_top = 30
	army_center.offset_bottom = -30
	army_center.visible = false
	add_child(army_center)
	# NO-179 full-width follow-up (Max: a dead strip sat between the peeking
	# card and the screen edge): army_center no longer carries its own
	# left/right inset, so army_scroll below — added straight to army_center
	# with no wrapper — spans the FULL viewport and a peeking neighbour runs
	# to the screen edge. The title, dots and Back button are not part of
	# that ask, so each gets its own 40px MarginContainer, reproducing
	# army_center's old inset exactly for everything except the carousel.
	var pad_side := func() -> MarginContainer:
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 40)
		m.add_theme_constant_override("margin_right", 40)
		army_center.add_child(m)
		return m
	var pick := Label.new()
	pick.text = "Choose your Army" # issue 67: replaces the Army pick
	pick.add_theme_font_size_override("font_size", 22)
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pad_side.call().add_child(pick)
	var army_scroll := ScrollContainer.new() # the carousel strip itself
	army_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	army_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER # NO-136: bar hidden, the swipe still works
	army_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Same touch-drag fix test_scroll carries (CLAUDE.md, "Layout traps"): a
	# Button's default mouse_filter is STOP, which would otherwise eat a swipe
	# that starts on the card's own Army button before drag_touching sets.
	army_scroll.scroll_deadzone = 24
	army_center.add_child(army_scroll)
	var army_row := HBoxContainer.new() # one card per Army, laid out side by side
	army_row.add_theme_constant_override("separation", int(ARMY_CARD_MARGIN)) # NO-179
	# NO-179 follow-up: army_row's real parent is now this wrap, not
	# army_scroll directly — see _army_row_wrap's own header for why, and
	# _show_armies for where its height is actually set.
	_army_row_wrap = CenterContainer.new()
	army_scroll.add_child(_army_row_wrap)
	_army_row_wrap.add_child(army_row)
	# NO-179: every card is the same slot width now (see ARMY_CARD_WIDTH_
	# FRACTION's own header), rendered at full scale always — no per-card
	# scaling. Height is DERIVED from width via the named playing-card
	# ratio, not a second literal.
	# NO-179 full-width follow-up: army_scroll carries no inset any more (see
	# army_center above), so scroll_w is the full viewport, not the old
	# viewport-minus-80.
	var scroll_w: float = get_viewport_rect().size.x
	var card_w: float = scroll_w * ARMY_CARD_WIDTH_FRACTION
	var card_h: float = card_w / ARMY_CARD_RATIO
	var card_style := StyleBoxFlat.new() # same bg tint as the TEST list's row_style
	card_style.bg_color = NESTED_PANEL_TINT
	card_style.border_color = Color(1, 1, 1, 0.22)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(10)
	card_style.content_margin_left = 10
	card_style.content_margin_right = 10
	card_style.content_margin_top = 14
	card_style.content_margin_bottom = 14
	var army_names: Array = Tuning.ARMIES.keys() # dot count/order/click-target follow this
	# NO-179: a spacer at each end, sized so the RESTING card sits centred
	# in the scroller with equal room either side for a full-size neighbour
	# to peek in from BOTH sides — the old layout only ever peeked on the
	# right, because the resting card sat flush against the scroller's own
	# left edge.
	#
	# HBoxContainer puts ARMY_CARD_MARGIN between EVERY pair of children,
	# including the spacer and the first card — so lead_w has to give up one
	# margin's worth to keep the resting card centred at scroll_horizontal
	# 0: a bare (scroll_w-card_w)/2 would land it ARMY_CARD_MARGIN too far
	# right. At scroll_w=480, card_w=280: lead_w=84 — the width of the
	# neighbour's slice visible on each side of the resting card. NO-179
	# full-width follow-up: that slice now runs flush to the screen edge,
	# since army_scroll itself is full width (no 40px container inset for
	# it to fall short of any more).
	var lead_w: float = (scroll_w - card_w) / 2.0 - ARMY_CARD_MARGIN
	var lead_spacer := Control.new()
	lead_spacer.custom_minimum_size = Vector2(lead_w, 0)
	lead_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	army_row.add_child(lead_spacer)
	# NO-179: name+description pair, decreasing visual weight (bigger head,
	# smaller body) — shared by Power and Ability so the two read the same
	# way. `custom_minimum_size.x` forces autowrap at the card's own text
	# width rather than the label's natural (unbounded) one.
	var add_pair := func(box: VBoxContainer, head: String, body: String, tint: Color) -> void:
		var head_lbl := Label.new()
		head_lbl.text = head
		head_lbl.add_theme_font_size_override("font_size", 13)
		head_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head_lbl.custom_minimum_size.x = card_w - 40.0
		head_lbl.modulate = tint
		box.add_child(head_lbl)
		var body_lbl := Label.new()
		body_lbl.text = body
		body_lbl.add_theme_font_size_override("font_size", 10)
		body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_lbl.custom_minimum_size.x = card_w - 40.0
		body_lbl.modulate = tint
		box.add_child(body_lbl)
	# NO-179: a small caption above a piece list, same treatment for
	# Starting Pieces and Reinforcements.
	var add_caption := func(box: VBoxContainer, text: String) -> void:
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = Color(1, 1, 1, 0.5)
		box.add_child(lbl)
	for army_name in Tuning.ARMIES: # the id stays Tuning.ARMIES' key
		# (load-bearing in the save's `army` field) — only the button's
		# display text differs, via Armies.display_name
		var card := PanelContainer.new() # NO-158: was a bare CenterContainer —
			# see card_style for why the peek needed this border/bg
		card.custom_minimum_size = Vector2(card_w, card_h)
		card.add_theme_stylebox_override("panel", card_style)
		army_row.add_child(card)
		var card_center := CenterContainer.new() # keeps the old vertical centring
		card.add_child(card_center)
		var card_box := VBoxContainer.new()
		card_box.add_theme_constant_override("separation", 6)
		card_center.add_child(card_box)
		# ARMY NAME — the largest text on the card (Max: information
		# hierarchy, name first).
		var army_btn := _button(card_box, Armies.display_name(army_name), 22,
			func() -> void:
				GameScript.next_army = army_name
				army_center.visible = false
				rank_center.visible = true)
		army_btn.mouse_filter = Control.MOUSE_FILTER_PASS # touch-drag reaches the carousel
		var kit: Dictionary = Armies.entry(army_name)
		# NO-179: no Army in armies.gd's CATALOG carries a tagline field —
		# reported in the branch, not invented here (CLAUDE.md: "leave it
		# ... and write down why" rather than guess player-facing copy).
		# Renders the instant the field exists, no further code change.
		if kit.has("tagline"):
			var tagline := Label.new()
			tagline.text = str(kit.tagline)
			tagline.add_theme_font_size_override("font_size", 12)
			tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tagline.custom_minimum_size.x = card_w - 40.0
			tagline.modulate = Color(1, 1, 1, 0.7)
			card_box.add_child(tagline)
		add_pair.call(card_box, kit.power_name, kit.power_desc, Color(1, 1, 1, 0.75))
		add_pair.call(card_box, kit.ability_name, kit.ability_desc,
			Color(0.85, 0.8, 0.55)) # gold tint, matches the in-game Army
			# Ability chip's own tint (hud.gd)
		# NO-179: Starting Pieces — the actual Stock a run begins with,
		# duplicates included, so the packed-crowd PieceMass treatment (one
		# token per real piece) is the right renderer — same call this
		# screen already made pre-NO-179.
		add_caption.call(card_box, "Starting Pieces")
		card_box.add_child(PieceMass.build(Tuning.ARMIES[army_name])) # NO-157
		# NO-179: Reinforcements — the set of piece TYPES game.gd's
		# _reinforce_ids() grants (deduped, doubled at the grant site — see
		# that function's own header), not a second multiset of instances.
		# A type list is different information from Starting Pieces'
		# instance crowd, so it gets the compact row below rather than a
		# second PieceMass call — see _reinforce_row's own header.
		add_caption.call(card_box, "Reinforcements")
		card_box.add_child(_reinforce_row(Tuning.ARMIES[army_name]))
	var trail_spacer := Control.new()
	trail_spacer.custom_minimum_size = Vector2(lead_w, 0)
	trail_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	army_row.add_child(trail_spacer)
	# NO-158: clickable page dots — one per Army, filled for the resting
	# card, hollow for the rest; a tap scrolls straight to that card. Count
	# and order come from army_names (Tuning.ARMIES), so a 7th Army needs no
	# edit here. Godot's ScrollContainer has no page-snap, so the "current
	# card" read in the value_changed listener below is an approximation —
	# exact once a swipe settles, which is the only time this reads it.
	var army_dots := HBoxContainer.new()
	army_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	army_dots.add_theme_constant_override("separation", 8)
	pad_side.call().add_child(army_dots)
	var dot_buttons: Array[Button] = []
	for i in army_names.size():
		var dot := Button.new()
		dot.flat = true
		dot.focus_mode = Control.FOCUS_NONE
		dot.custom_minimum_size = Vector2(28, 28)
		dot.add_theme_font_size_override("font_size", 16)
		dot.text = "●" if i == 0 else "○"
		dot.pressed.connect(func() -> void:
			army_scroll.scroll_horizontal = int(i * (card_w + ARMY_CARD_MARGIN)))
		army_dots.add_child(dot)
		dot_buttons.append(dot)
	# Setting scroll_horizontal above fires this same signal (it just proxies
	# the underlying HScrollBar's value), so a dot click updates the dots
	# through the identical path a swipe does — one writer, not two.
	army_scroll.get_h_scroll_bar().value_changed.connect(func(_v: float) -> void:
		var idx := clampi(roundi(army_scroll.scroll_horizontal / (card_w + ARMY_CARD_MARGIN)), 0, army_names.size() - 1)
		for i in dot_buttons.size():
			dot_buttons[i].text = "●" if i == idx else "○")
	_button(pad_side.call(), "← Back", 20, func() -> void:
		army_center.visible = false
		main_box.visible = true)

	# tier select: chosen after the army, locked for the run
	# (07-difficulty-ranks — Continue into endless keeps it)
	#
	# NO-190: rank_center is now a PanelContainer, not a bare CenterContainer,
	# so it can carry a background — the app's default clear colour ("soft
	# grey") read as too light here. The colour is READ off the engine's own
	# Button "normal" stylebox rather than a new literal (Max: "can use the
	# button background gray"), which is already darker than that default —
	# an inner CenterContainer does the centring PanelContainer itself
	# doesn't do.
	rank_center = PanelContainer.new()
	rank_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	rank_center.visible = false
	var rank_bg := StyleBoxFlat.new()
	rank_bg.bg_color = (ThemeDB.get_default_theme().get_stylebox("normal", "Button") as StyleBoxFlat).bg_color
	rank_center.add_theme_stylebox_override("panel", rank_bg)
	add_child(rank_center)
	var rank_middle := CenterContainer.new()
	rank_center.add_child(rank_middle)
	var rank_box := VBoxContainer.new()
	rank_box.add_theme_constant_override("separation", 12)
	rank_middle.add_child(rank_box)
	# issue 75 / NO-190: the seed field is now the FIRST control on the
	# screen, above the title — still the same field (focus_mode, "" =
	# random untouched), just moved. Its own label ("SEED — leave blank for
	# random") is gone; the placeholder carries the hint instead.
	seed_field = LineEdit.new()
	seed_field.placeholder_text = "Enter seed"
	seed_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_field.custom_minimum_size = Vector2(240, 0)
	# must NOT take focus on show — the windowed click probes drive real input,
	# and a focused text field would swallow their keystrokes
	seed_field.focus_mode = Control.FOCUS_CLICK
	rank_box.add_child(seed_field)
	var rank_pick := Label.new()
	rank_pick.text = "Difficulty Tiers"
	rank_pick.add_theme_font_size_override("font_size", 28)
	rank_box.add_child(rank_pick)
	# NO-159: one row per tier, icon + a bordered description panel, the
	# description GENERATED from Tuning.TIER_HANDICAPS rather than
	# hand-written — see _tier_description() (untouched). The old font-26
	# "Tier N" header is gone (Max: "the largest text on screen, carries the
	# least information" — the icon and the description already say which
	# tier this is).
	#
	# NO-190: the small flat button that used to carry the SAME "Tier N" text
	# as the tap target now carries NO text — Max ruled the numbering itself
	# should go, not just its old large header. NO-212 turned it into a
	# borderless overlay spanning the whole tier_panel (see the loop below)
	# so the row stays a real, full-height tap target with nothing to read.
	# test_menu_clicks.gd can no longer find it by text, so it is
	# collected into _tier_buttons (a member array, read directly by the
	# test — the same convention _selected_tier already uses) instead.
	#
	# NO-190 also replaces select-then-confirm's second tap with an explicit
	# Confirm button below the tier list: tapping a tier (selected or not)
	# only ever selects it now; Confirm is the one and only way to stage and
	# launch the run. Two things staged the same commit by one more tap each
	# was judged more confusing than a single dedicated control, and it
	# matches the "Confirm above Back" placement Max asked for.
	#
	# tier_panels holds ONE PanelContainer per tier — the outline surface,
	# separate from the icon (Max was explicit the outline must not wrap the
	# icons) — and tiers_box stacks the rows with ZERO separation, so
	# adjoining panels touch with no gap: _update_tier_outline can then draw
	# a border on only the outer edges of a contiguous i<=selected range and
	# have it read as ONE box, not N stacked ones. Row breathing room comes
	# from each panel's own content margins instead of container separation.
	var tier_panels: Array[PanelContainer] = []
	_tier_buttons = []
	var tiers_box := VBoxContainer.new()
	tiers_box.add_theme_constant_override("separation", 0)
	rank_box.add_child(tiers_box)
	for i in Tuning.TIERS.size():
		var tier_name: String = Tuning.TIERS[i]
		var tier_row := HBoxContainer.new()
		tier_row.add_theme_constant_override("separation", 10)
		tiers_box.add_child(tier_row)
		tier_row.add_child(_tier_icon(tier_name)) # outside tier_panel — never outlined
		var tier_panel := PanelContainer.new()
		tier_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_row.add_child(tier_panel)
		tier_panels.append(tier_panel)
		var tier_desc := Label.new()
		tier_desc.text = _tier_description(tier_name)
		tier_desc.add_theme_font_size_override("font_size", 11)
		tier_desc.modulate = Color(1, 1, 1, 0.7)
		tier_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# icon column (70) + the row separation (10) + tier_panel's own left/
		# right content margin (10*2, set in _update_tier_outline) — same
		# "state an explicit minimum or autowrap collapses to zero" fix
		# _wrap_account_text documents, widened by the panel's own margins so
		# this row can't demand more width than the panel actually has to give
		# it (that mismatch is what pushed the whole menu sideways there).
		tier_desc.custom_minimum_size.x = _text_width() - 100.0
		# NO-212: top-align, mirroring the icon's own SIZE_SHRINK_BEGIN
		# (_tier_icon). tier_desc used to sit inside a VBoxContainer below a
		# same-height invisible tap-target button stacked above it, so every
		# row's text started a full button-height below its own icon. A
		# PanelContainer fits each of its children to that child's own size
		# flags, so adding the label straight into tier_panel and shrinking it
		# to the top pins it to the panel's top content margin regardless of
		# what else shares the panel — the tap target below no longer sits in
		# this stack at all, so its height can't push the text down.
		tier_desc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tier_panel.add_child(tier_desc)
		# The tap target is now a borderless overlay spanning the whole panel
		# (PanelContainer fits every child to the same rect) instead of a slim
		# strip stacked above the text — a bigger, full-row hit area, and one
		# that can no longer dictate where the text sits.
		var tier_btn := _button(tier_panel, "", 13, func() -> void:
			_selected_tier = i
			_update_tier_outline(tier_panels, i))
		tier_btn.flat = true
		_tier_buttons.append(tier_btn)
	_update_tier_outline(tier_panels, _selected_tier)
	_button(rank_box, "Confirm", 20, func() -> void:
		GameScript.next_tier = Tuning.TIERS[_selected_tier]
		GameScript.next_seed = seed_field.text.strip_edges() # "" = random
		GameScript.next_config = {}
		GameScript.is_scenario = false
		get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	_button(rank_box, "← Back", 20, func() -> void:
		rank_center.visible = false
		army_center.visible = true)

	# NO-64: keep asking the phone while the menu is up. See _apply_connectivity.
	var poll := Timer.new()
	poll.wait_time = 1.0
	poll.autostart = true
	poll.timeout.connect(_apply_connectivity)
	add_child(poll)
	_apply_connectivity()

	if args.has("--screenshot"):
		var dir: String = args[args.find("--screenshot") + 1]
		# Screenshot pass (2026-09-19): one generic flag for whichever menu
		# panel the capture wants, rather than a flag per panel — folds in
		# the 2026-09-18 --show-device-info, which named only that one panel.
		if args.has("--show-screen"):
			match args[args.find("--show-screen") + 1]:
				"tests": _show_tests()
				"armies": _show_armies()
				"rank": # the tier picker sits past an Army pick, not its own
					# button — reached the same way the "← Back" on rank_box
					# does, so a screenshot doesn't need an Army actually chosen
					_show_armies()
					GameScript.next_army = Tuning.ARMIES.keys()[0]
					army_center.visible = false
					rank_center.visible = true
				"scores": _show_scores()
				"history": # NO-147: nested under Scores now — build it first,
					# same idiom as "rank" building its Army pick above, so
					# a screenshot doesn't need Scores opened as a separate step
					_show_scores()
					_show_history()
				"about": _show_about()
				"guide":
					main_box.visible = false
					guide_scroll.visible = true
				"settings":
					main_box.visible = false
					settings_panel.visible = true
				"device-info": # diagnostic-only: the notch-diagnostic panel
					# from the command line, the same idiom as --safe-top
					# probing the Game scene's Header without a phone
					_show_tests()
					_show_device_info()
				"login":
					# --screenshot bypasses the login gate above (a fresh
					# checkout would otherwise photograph it instead of the
					# main menu) — asking for it BY NAME opts back in, no
					# sign-in required either way, just the panel showing
					main_box.visible = false
					login_center.visible = true
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(dir) # save_png fails outright if dir is missing
		get_viewport().get_texture().get_image().save_png(dir.path_join("menu.png"))
		get_tree().change_scene_to_file("res://scenes/Game.tscn")


## NO-147: reached from Settings now, so settings_panel is hidden here rather
## than left showing underneath (main_box.visible = false stays too — the
## --show-screen "tests"/"device-info" bypasses reach this straight from a
## fresh main menu, where settings_panel is already hidden).
func _show_tests() -> void:
	main_box.visible = false
	settings_panel.visible = false
	test_scroll.visible = true


func _show_armies() -> void:
	main_box.visible = false
	army_center.visible = true
	# NO-179 follow-up: army_scroll's own height isn't knowable at build
	# time — it's whatever's left of army_center after the title and the
	# dots/Back row, both font-sized, claim theirs — so wait a frame for the
	# container's deferred sort to settle (CLAUDE.md: a freshly added
	# Control's geometry isn't usable until the next idle frame), then read
	# the real value and give the wrap exactly that height. CenterContainer
	# then centres army_row inside it, splitting the dead space (CLAUDE.md,
	# "Layout traps": flush-to-one-edge is right when something can absorb
	# the slack; here nothing does, so it was reading as a mistake) evenly
	# above and below the card instead of stranding it all below. Guard on
	# `visible` after the await in case Back was pressed in that one frame.
	await get_tree().process_frame
	if army_center.visible:
		var scroll: Control = _army_row_wrap.get_parent()
		_army_row_wrap.custom_minimum_size.y = scroll.size.y


## NO-179: one small icon per unique piece TYPE in `ids`, first-occurrence
## order — the same set game.gd's _reinforce_ids() computes for the
## Reinforcement grant (game.gd:2875: `Tuning.ARMIES[army]`, deduped), so
## the card shows exactly what a Reinforcement pick will offer. Deliberately
## NOT PieceMass.build(): that renderer draws one token per real piece
## instance (duplicates included, packed into a crowd) — right for Starting
## Pieces, wrong for a TYPE list, where "4 pawns" should read as one pawn
## icon, not four.
static func _reinforce_row(ids: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var seen := {}
	for id in ids:
		if seen.has(id):
			continue
		seen[id] = true
		var icon := TextureRect.new()
		icon.texture = GameScript.load_piece_tex(id) # player side (the default)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(28, 28)
		row.add_child(icon)
	return row


func _show_scores() -> void:
	main_box.visible = false
	# rebuilt on every open so fresh runs show up without a restart
	if scores_center:
		scores_center.queue_free()
	scores_center = CenterContainer.new()
	scores_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scores_center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	scores_center.add_child(box)
	var head := Label.new()
	head.text = "High scores"
	head.add_theme_font_size_override("font_size", 28)
	box.add_child(head)
	# issue 85: local unioned with the cloud board when there is one. The local
	# board is NOT replaced — it is exactly what shows when the cloud is
	# unreachable, which is the normal case rather than a failure.
	var scores := Leaderboard.board(GameScript.load_scores())
	var status := Label.new()
	status.add_theme_font_size_override("font_size", 12)
	status.modulate = Color(1, 1, 1, 0.55)
	# Three states, not two: signed in and syncing, signed in as SOMEONE ELSE, or
	# not signed in. Without the middle one this told a player who was signed in
	# to go and sign in.
	if Leaderboard.cloud_available():
		status.text = "Cloud scores included."
	elif _BRIDGE().signed_in:
		status.text = "Local scores — signed in as a different account."
	else:
		status.text = "Local scores — sign in to compare."
	box.add_child(status)
	# NO-8: the door OUT to the global board. The personal list below is
	# untouched — this adds a way to ask "how do I rank?" beside the existing
	# "am I improving?", and opens the PLATFORM's own screen rather than a
	# second list for us to maintain. Hidden rather than disabled when there is
	# no platform behind it: a permanently greyed button on desktop would be
	# chrome advertising something that cannot exist there.
	#
	# NO-64: OFFLINE is the opposite case — the platform exists, the network does
	# not, so "not now" is the true message and the door is disabled, not hidden.
	if GlobalBoard.available():
		global_btn = Button.new()
		global_btn.text = "Global ranking"
		global_btn.pressed.connect(func() -> void:
			GlobalBoard.show_board(GlobalBoard.HIGH_SCORE))
		box.add_child(global_btn)
		global_offline_note = _offline_note(box)
		_apply_connectivity()
	if scores.is_empty():
		var none := Label.new()
		none.text = "No runs yet"
		box.add_child(none)
	for i in scores.size():
		var e: Dictionary = scores[i]
		var row := Label.new()
		row.text = "%2d.  %5d — wave %d · %d king%s" % [i + 1, int(e.score),
			int(e.wave), int(e.kings), "" if int(e.kings) == 1 else "s"]
		row.add_theme_font_size_override("font_size", 18)
		box.add_child(row)
	# NO-147: Games History folds into Scores — a door to the per-run log
	# beside the ranked top-10 above, same shape as the Global ranking door.
	_button(box, "Games History", 20, _show_history)
	_button(box, "← Back", 20, func() -> void:
		scores_center.visible = false
		main_box.visible = true)


## Games History: every real run's summary, newest first — distinct from the
## ranked top-10 Highscores above (05-menus-and-settings). NO-147: reached
## from Scores only, so scores_center is guaranteed built by the time this
## runs — hidden here rather than left showing underneath.
func _show_history() -> void:
	main_box.visible = false
	scores_center.visible = false
	if history_scroll:
		history_scroll.queue_free()
	history_scroll = ScrollContainer.new()
	history_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER # NO-136
	history_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	history_scroll.offset_left = 40
	history_scroll.offset_top = 30
	history_scroll.offset_right = -40
	history_scroll.offset_bottom = -30
	add_child(history_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	history_scroll.add_child(box)
	var head := Label.new()
	head.text = "Games History"
	head.add_theme_font_size_override("font_size", 28)
	box.add_child(head)
	var runs := GameScript.load_history()
	if runs.is_empty():
		var none := Label.new()
		none.text = "No runs yet"
		box.add_child(none)
	for e in runs:
		var row := Label.new()
		row.text = "%s — %d · wave %d · %d king%s · %d king abilit%s · %d lost" % [
			"Win" if e.get("won", false) else "Loss", int(e.score), int(e.wave),
			int(e.kings), "" if int(e.kings) == 1 else "s",
			int(e.king_abilities), "y" if int(e.king_abilities) == 1 else "ies", int(e.get("lost", 0))]
		row.add_theme_font_size_override("font_size", 15)
		box.add_child(row)
	_button(box, "← Back", 20, func() -> void:
		history_scroll.visible = false
		scores_center.visible = true) # NO-147: reached from Scores now


## NO-147: reached from Settings now, so settings_panel is hidden here rather
## than left showing underneath.
func _show_about() -> void:
	main_box.visible = false
	settings_panel.visible = false
	if about_center:
		about_center.queue_free()
	about_center = CenterContainer.new()
	about_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(about_center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	about_center.add_child(box)
	var head := Label.new()
	head.text = "About"
	head.add_theme_font_size_override("font_size", 28)
	box.add_child(head)
	var body := Label.new()
	body.text = "NO KINGS\nAn explosive Chess riot.\nBuilt with Godot 4."
	body.add_theme_font_size_override("font_size", 15)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	_button(box, "← Back", 20, func() -> void:
		about_center.visible = false
		settings_panel.visible = true) # NO-147: reached from Settings now


## Diagnostic-only readout of the platform's own safe-area numbers, so a
## report from Max's hardware is a screenshot instead of a guess. Built from
## the same calls the layout code already uses (safe_top_px, HudScript.HEADER_H)
## plus the raw DisplayServer/OS values behind them — never a device-model
## table (rejected: unbounded, and the platform already reports this).
func _device_info_text() -> String:
	var vp := get_viewport_rect().size
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var usable := DisplayServer.screen_get_usable_rect()
	var screen := DisplayServer.screen_get_size()
	var safe_top := GameScript.safe_top_px(vp)
	var hud_top := safe_top + HudScript.HEADER_H
	return "\n".join([
		"model: %s" % OS.get_model_name(),
		"os: %s %s" % [OS.get_name(), OS.get_version()],
		"window size: %s" % win,
		"safe area: pos %s  size %s" % [safe.position, safe.size],
		"usable rect: pos %s  size %s" % [usable.position, usable.size],
		"screen size: %s" % screen,
		"safe_top_px: %.1f" % safe_top,
		"hud_top: %.1f" % hud_top,
	])


func _show_device_info() -> void:
	test_scroll.visible = false
	if device_info_center:
		device_info_center.queue_free()
	device_info_center = CenterContainer.new()
	device_info_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(device_info_center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	device_info_center.add_child(box)
	var head := Label.new()
	head.text = "Device info"
	head.add_theme_font_size_override("font_size", 24)
	box.add_child(head)
	var body := Label.new()
	body.text = _device_info_text()
	body.add_theme_font_size_override("font_size", 14)
	# WORD_SMART, not off: a long Rect2i string is one unbroken token on a
	# 480px-wide phone otherwise, same trap _wrap_account_text documents.
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = _text_width()
	box.add_child(body)
	_button(box, "← Back", 20, func() -> void:
		device_info_center.visible = false
		test_scroll.visible = true)


## NO-148 (Max, 2026-09-20): piece token per tier, ascending through his own
## ladder order — Pawn, Rook, Bishop, Knight, Queen. (His list read "Pawn Rook
## ... Knight Queen"; Bishop is the piece he meant by "Tower", which has no
## art or codex id — confirmed directly.) Replaces the dot-meter placeholder.
const TIER_PIECE_IDS := ["pawn", "rook", "bishop", "knight", "queen"]

## Player-side token for `tier_name`, same TextureRect idiom as the Army
## carousel's piece mass (PieceMass.build, NO-157): 40x40, EXPAND_IGNORE_SIZE +
## STRETCH_KEEP_ASPECT_CENTERED so the 192x192 source doesn't override the
## minimum size. 40x40 fits inside the row's existing 70px icon column
## (carried over unchanged below) with room to spare — Tuning.OFFBOARD_ICON
## (72px) is sized for the off-board strip, not a menu row, and would crowd
## the description text beside it.
func _tier_icon(tier_name: String) -> Control:
	var wrap := CenterContainer.new()
	# NO-212: top-align, not row-centered — the row's own height grows with
	# its cumulative handicap text, and centering in that meant the icon
	# drifted toward the middle of an ever-taller block instead of sitting
	# beside the text it actually belongs to.
	wrap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wrap.custom_minimum_size = Vector2(70, 0)
	var icon := TextureRect.new()
	# NO-190 (Max): red icons — the enemy/dark side of the pair, not a tint.
	icon.texture = GameScript.load_piece_tex(TIER_PIECE_IDS[Tuning.tier_index(tier_name)], Rules.ENEMY)
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wrap.add_child(icon)
	return wrap


## V2 (Max, 2026-09-21): each tier's description states ONLY what THAT tier
## adds — supersedes NO-148's cumulative listing (every inherited handicap
## repeated underneath), which read as the Queen/Tier-4 row re-printing four
## lines it shared with the tiers below. The handicaps still STACK in
## behaviour (every gate in tuning.gd is tier_index(tier) >= N) — this is
## only what the screen prints. GENERATED from Tuning.TIER_HANDICAPS (via
## new_handicaps), never hand-written, so retuning a threshold there moves
## this copy for free.
func _tier_description(tier_name: String) -> String:
	var new_h := Tuning.new_handicaps(tier_name)
	if new_h.is_empty():
		return "No handicaps"
	return "\n".join(new_h)


## NO-159: redraw the tier-selection outline. `panels[i]` is tier i's
## description panel (tier_panels from the rank_center build); `selected` is
## the highest tier whose description should read as enclosed. Every panel in
## range i<=selected gets left/right borders, plus a top border only on the
## FIRST (i==0) and a bottom border only on the LAST (i==selected) — since
## adjoining panels touch with zero gap (tiers_box separation is 0), that
## reads as one continuous box around tiers 1..selected, not a stack of
## separate ones. Content margins are set unconditionally so toggling the
## border never changes row height/layout, only what's drawn.
##
## NO-212: every panel, selected or not, gets a full faint border of its own
## (TIER_BORDER_COLOR) so its text block reads as one box beside its own
## icon — before this, an unselected row had no border at all and the
## description text ran on as one unbroken column. The selected range's
## brighter, internally-joined TIER_OUTLINE_COLOR border still draws on top
## of that, unchanged.
const TIER_OUTLINE_COLOR := Color(0.35, 0.65, 1.0)
const TIER_BORDER_COLOR := Color(1, 1, 1, 0.12)
const TIER_OUTLINE_WIDTH := 2

func _update_tier_outline(panels: Array, selected: int) -> void:
	for i in panels.size():
		var sb := StyleBoxFlat.new()
		sb.bg_color = NESTED_PANEL_TINT
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		sb.border_color = TIER_BORDER_COLOR
		sb.border_width_left = TIER_OUTLINE_WIDTH
		sb.border_width_right = TIER_OUTLINE_WIDTH
		sb.border_width_top = TIER_OUTLINE_WIDTH
		sb.border_width_bottom = TIER_OUTLINE_WIDTH
		if i <= selected:
			sb.border_color = TIER_OUTLINE_COLOR
			sb.border_width_top = TIER_OUTLINE_WIDTH if i == 0 else 0
			sb.border_width_bottom = TIER_OUTLINE_WIDTH if i == selected else 0
		panels[i].add_theme_stylebox_override("panel", sb)


## NO-55: how wide an account label may be. One number, read from the viewport
## rather than hardcoded, so it is right on any canvas this game is stretched to;
## the inset leaves the wrapped text clear of both screen edges.
const TEXT_INSET := 40.0

func _text_width() -> float:
	return maxf(120.0, get_viewport_rect().size.x - TEXT_INSET)


## NO-55: make a Label that carries arbitrary account text safe to put in a
## container.
##
## A Label with AUTOWRAP_OFF reports a MINIMUM WIDTH equal to its full text
## width. A VBoxContainer's minimum is the max of its children's, and
## CenterContainer centres its child at that minimum WITHOUT clamping to its own
## rect — the offset just goes negative — so one long line pushed the whole main
## menu sideways: "NO KINGS" clipped off the left edge, every button shoved
## right, measured at 792-797px inside a 480px viewport.
##
## WORD_SMART, not plain WORD (user ruling: wrap, do not clip). Plain WORD cannot
## break an unbroken token, and an account id — or a name with no spaces — is
## exactly that, so plain WORD would have left the minimum width unchanged and
## fixed nothing.
##
## The explicit minimum is what makes wrapping USEFUL rather than merely safe:
## with autowrap on, the label's own minimum collapses toward zero and the
## container would size to its widest BUTTON instead, wrapping the prompt into a
## narrow column. Stating the width puts it back under the player's screen.
func _wrap_account_text(l: Label) -> void:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = _text_width()


## NO-54: what to CALL an account on screen — its display name, or `fallback`
## when no name was recorded. NO-76: the fallback is a generic label the caller
## chooses ("another account"), never the id — an id is 64 hex characters that
## fill the line and mean nothing to the player looking at them.
## Truncated so a name can never be absurdly long, which
## is the value half of the user's ruling ("your display name, shortened if
## long"); _wrap_account_text is the layout half, and neither substitutes for
## the other.
##
## TRUNCATED ON MEASURED WIDTH, NOT CHARACTER COUNT, and that is the whole
## reason this is not a substr(): a display name is arbitrary user text, and CJK
## is short by character count and wide in pixels — four Japanese characters
## outrun twenty Latin ones. Character counting would trim the wrong names.
##
## ponytail: trims one character at a time. The ceiling is the length of a
## display name, measured once per prompt; a binary search if that ever shows up
## in a profile.
func _who(l: Label, name: String, fallback: String) -> String:
	var text := name if name != "" else fallback
	var font := l.get_theme_font("font")
	if font == null:
		return text
	var size := l.get_theme_font_size("font_size")
	var limit := _text_width()
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= limit:
		return text
	while text.length() > 1 and font.get_string_size(
			text + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > limit:
		text = text.substr(0, text.length() - 1)
	return text + "…"


func _button(parent: Container, text: String, size: int, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


## A scenario row's text inside its section: the section prefix is the header
## already, so "Artefact Common: Loch Ness Stool Sample" reads "Loch Ness Stool
## Sample" under ARTEFACT COMMON. "Other" and "General" carry no shared prefix.
## NO-58: THE ONE PLACE THAT DECIDES WHAT IS VISIBLE IN THE TEST LIST.
##
## Both the accordion and the search box want to hide and show rows, and before
## this the accordion owned `visible` outright — it even read it back to decide
## which way to toggle. Two writers of one property is how a filter and an
## accordion end up undoing each other, so neither writes it now: the accordion
## records which section is open, the box holds the query, and this computes the
## answer from both.
##
## WITH AN EMPTY QUERY THE LIST BEHAVES EXACTLY AS IT DID — one section open at a
## time, every header showing its own size. That is the property to preserve;
## the search is an addition, not a replacement.
##
## While a query IS running, every section opens itself: a match hidden inside a
## collapsed section is this issue's original complaint arriving by a new route.
## Sections with no match hide their header too, so what is left on screen is
## the result rather than fifty empty headings.
func _apply_test_filter() -> void:
	if test_filter == null:
		return
	var q := test_filter.text.strip_edges().to_lower()
	var searching := q != ""
	var hits := 0
	for i in _test_sections.size():
		var sec: Dictionary = _test_sections[i]
		var open: bool = searching or i == _test_open
		var shown := 0
		for r: Button in sec.rows:
			var hit: bool = not searching or q in str(r.get_meta("scenario_name")).to_lower()
			r.visible = open and hit
			if hit:
				shown += 1
		hits += shown
		sec.head.visible = not searching or shown > 0
		sec.relabel.call(open, shown)
	test_head.text = "Test scenarios — %d of %d" % [hits, Scenarios.all().size()] \
		if searching else "Test scenarios — %d boards" % Scenarios.all().size()


func _process(_delta: float) -> void:
	_update_test_scroll_for_keyboard()


## NO-69: shrinks the results ScrollContainer above the soft keyboard while
## the search field is focused. DisplayServer.virtual_keyboard_get_height()
## reports real screen pixels; the viewport runs canvas_items stretch at a
## fixed 480x800, so the height is rescaled by canvas-px-per-screen-px before
## it is subtracted from the container's bottom offset. Desktop always
## reports 0, so offset_bottom lands back on its original -24.
func _update_test_scroll_for_keyboard() -> void:
	if test_scroll == null:
		return
	var kb_px := keyboard_height_override if keyboard_height_override >= 0 \
		else DisplayServer.virtual_keyboard_get_height()
	if kb_px <= 0:
		test_scroll.offset_bottom = -24
		return
	var window_h := DisplayServer.window_get_size().y
	var canvas_h := get_viewport_rect().size.y
	var scale := canvas_h / float(window_h) if window_h > 0 else 1.0
	test_scroll.offset_bottom = -24 - kb_px * scale


func _test_row_text(name: String, sec: String) -> String:
	if sec == "Other" or sec == "General" or not name.begins_with(sec):
		return name
	var rest := name.substr(sec.length()).strip_edges()
	if rest.begins_with(":"):
		rest = rest.substr(1).strip_edges()
	return rest if rest != "" else name
