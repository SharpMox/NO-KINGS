extends Control
## Main menu: Play / TEST (scenario launcher) / Quit. `--autoplay` and
## `--scenario N` skip the menu; `--screenshot <dir>` captures menu.png first.

const GameScript := preload("res://scripts/game.gd")
const Scenarios := preload("res://data/scenarios.gd")
const Tuning := preload("res://scripts/tuning.gd")
const Guide := preload("res://scripts/guide.gd")
const Settings := preload("res://scripts/settings.gd")
const CloudSave := preload("res://scripts/cloud_save.gd")
const Armies := preload("res://scripts/armies.gd")
const Account := preload("res://scripts/account.gd")
const SaveConfig := preload("res://scripts/save_config.gd")
const Leaderboard := preload("res://scripts/leaderboard.gd")

const PlayBridge := preload("res://scripts/cloud/play_games_bridge.gd")
const IosBridge := preload("res://scripts/cloud/ios_cloud_bridge.gd")


## ONE sign-in flow, two bridges. The iOS bridge mirrors the Android one's
## static surface and signals exactly (issue 87 copied issue 86 on purpose),
## so the menu never branches on platform beyond these two pickers.
static func _BRIDGE() -> GDScript:
	return IosBridge if OS.get_name() == "iOS" else PlayBridge


## The provider this platform can actually sign into: Game Center on iOS,
## Play Games elsewhere. The other button refuses with the honest message.
static func _NATIVE_PROVIDER() -> String:
	return Account.APPLE if OS.get_name() == "iOS" else Account.GOOGLE


## What to CALL the provider on screen. "Apple" names Sign in with Apple — a
## DIFFERENT Apple service; what we actually use is Game Center, and a player
## who reads "Apple" goes looking for the wrong thing (observed on the
## simulator, 2026-09-04: "is there supposed to be a Game Center app?").
static func _LABEL(prov: String) -> String:
	return "Game Center" if prov == Account.APPLE else "Google"


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
	match key:
		"scores": return Leaderboard.merge
		"history": return Leaderboard.merge_history
	return Callable()


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
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if login_center != null and login_center.visible:
		return
	# The tier picker goes back to the army picker, not to the main menu, so the
	# gesture lands where its own Back button does. Checked first because both
	# are visible in that state.
	if is_instance_valid(rank_center) and rank_center.visible:
		rank_center.visible = false
		army_center.visible = true
		return
	var panels: Array[Control] = [test_scroll, army_center, scores_center,
		history_scroll, about_center, guide_scroll, settings_panel]
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
				% [_LABEL(_NATIVE_PROVIDER()), _RETRY_HINT(_NATIVE_PROVIDER())]
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
	# So a switch does NOTHING here: no rebind, no fetch. is_available() also
	# reports false while the ids disagree, which keeps the rest of the session
	# from pushing A's progress into B. Keeping the two accounts genuinely
	# separate needs per-account local saves — a real feature, and a design call
	# rather than something to guess at. See issue 86.
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
		Account.sign_in(_NATIVE_PROVIDER(), id, _SAVE_PATHS())
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
			% _LABEL(_NATIVE_PROVIDER())


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
func _finish_login() -> void:
	if not login_center.visible:
		return
	login_center.visible = false
	main_box.visible = true


func _set_providers_disabled(locked: bool) -> void:
	for b in provider_buttons:
		b.disabled = locked


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
		login_note.text = "%s sign-in isn't available on this device yet." % _LABEL(prov)
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
			% [_LABEL(prov), _RETRY_HINT(prov)]
		_set_providers_disabled(false))
	_BRIDGE().begin_sign_in()

var main_box: VBoxContainer
var guest_button: Button # relabelled by _on_logout; see there
var test_scroll: ScrollContainer
var army_center: ScrollContainer
var rank_center: CenterContainer
var seed_field: LineEdit # issue 75
var scores_center: CenterContainer
var history_scroll: ScrollContainer
var about_center: CenterContainer
var guide_scroll: ScrollContainer
var settings_panel: CenterContainer
var login_center: CenterContainer # issue 83, first run only
var login_note: Label # the login screen's status line
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


func _ready() -> void:
	# CLI bypasses/probes boot Game.tscn straight past this scene, so it also
	# applies at its own _ready() — belt and suspenders, both are idempotent.
	# Carries issue 74's hard-edged text as well as the sound setting.
	Settings.apply(Settings.load_settings())
	# real boots only — the click probes instantiate the menu by hand and inject
	# clicks at 480×800 coords, which a mid-probe resize would break
	if not window_sized and DisplayServer.get_name() != "headless" \
			and get_tree().current_scene == self:
		window_sized = true
		var usable := DisplayServer.screen_get_usable_rect()
		var h: int = usable.size.y - 40 # title-bar allowance
		get_window().size = Vector2i(int(h * 480.0 / 800.0), h) # keep portrait aspect
		get_window().move_to_center()
	var args := OS.get_cmdline_user_args()
	if args.has("--autoplay") or args.has("--scenario"):
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
		"/root/IosCloudBridge" if OS.get_name() == "iOS" else "/root/PlayGamesBridge")
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
	var saved: Variant = null
	if FileAccess.file_exists(GameScript.SAVE_PATH):
		saved = JSON.parse_string(FileAccess.get_file_as_string(GameScript.SAVE_PATH))
	if SaveConfig.is_loadable(saved):
		_button(main_box, "Continue", 32, func() -> void:
			GameScript.next_config = saved
			GameScript.is_scenario = false
			get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	_button(main_box, "Play", 32, _show_armies)
	_button(main_box, "Scores", 24, _show_scores)
	_button(main_box, "Games History", 24, _show_history)
	_button(main_box, "Guide", 24, func() -> void:
		main_box.visible = false
		guide_scroll.visible = true)
	_button(main_box, "About", 24, _show_about)
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
	_button(main_box, "Settings", 24, func() -> void:
		main_box.visible = false
		settings_panel.visible = true)
	_button(main_box, "TEST", 24, _show_tests)
	_button(main_box, "Quit", 20, func() -> void: get_tree().quit())

	# Guide and Settings are shared with the in-game menu (scripts/guide.gd,
	# scripts/settings.gd) so the two entry points can't drift apart
	guide_scroll = Guide.build(self, func() -> void: main_box.visible = true)
	settings_panel = Settings.build(self, func() -> void: main_box.visible = true,
		Callable(), _on_logout)

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
	for prov in [Account.GOOGLE, Account.APPLE]:
		provider_buttons.append(
			_button(login_box, "Sign in with %s" % _LABEL(prov), 22,
				_on_provider_pressed.bind(prov)))
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
	var head := Label.new()
	head.text = "Test scenarios — %d boards" % Scenarios.all().size()
	head.add_theme_font_size_override("font_size", 22)
	test_box.add_child(head)
	_button(test_box, "← Back", 20, func() -> void:
		test_scroll.visible = false
		main_box.visible = true)
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
	var sections: Array = [] # {rows, relabel} per section — the accordion
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(1, 1, 1, 0.06)
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
		sec_head.add_theme_font_size_override("font_size", 16)
		sec_head.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
		for style in ["normal", "hover", "pressed"]:
			sec_head.add_theme_stylebox_override(style, head_style)
		var relabel := func(open: bool) -> void:
			sec_head.text = "%s  %s  (%d)" % ["▾" if open else "▸",
				sec.to_upper(), groups[sec].size()]
		relabel.call(false)
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
			row.tooltip_text = s.name
			for style in ["normal", "hover", "pressed"]:
				row.add_theme_stylebox_override(style, row_style)
			row.visible = false
			rows.append(row)
		sections.append({"rows": rows, "relabel": relabel})
		sec_head.pressed.connect(func() -> void:
			var open := not rows[0].visible
			for other in sections: # accordion: one section open at a time
				for r in other.rows:
					r.visible = false
				other.relabel.call(false)
			if open:
				for r in rows:
					r.visible = true
				relabel.call(true)
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

	# army select: Play goes here; each army is a button + composition line.
	# ScrollContainer, not CenterContainer (issue 68): 6 Armies' worth of
	# buttons + roster + Power/Ability lines overflow the fixed 480x800
	# portrait window — the same scrollable-list shape test_scroll/
	# history_scroll/guide_scroll already use below, so every entry (and the
	# trailing Back button) stays reachable regardless of Army count.
	army_center = ScrollContainer.new()
	army_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	army_center.offset_left = 40
	army_center.offset_top = 30
	army_center.offset_right = -40
	army_center.offset_bottom = -30
	army_center.visible = false
	add_child(army_center)
	var army_box := VBoxContainer.new()
	army_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# On a 9:20 phone the six entries were sized for 480x800 and simply stopped
	# halfway down, leaving the bottom ~45% empty. Same answer as the in-run
	# deck: the leftover height goes into the BUTTONS, which makes them easier
	# to hit, rather than into a void under the last one.
	army_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# issue 68 tightened this from 12: six Armies' worth of entries have to
	# fit 480x800 without scrolling. The ScrollContainer above stays as the
	# safety net for a seventh.
	army_box.add_theme_constant_override("separation", 5)
	army_center.add_child(army_box)
	var pick := Label.new()
	pick.text = "Choose your Army" # issue 67: replaces the Army pick
	pick.add_theme_font_size_override("font_size", 22)
	army_box.add_child(pick)
	for army_name in Tuning.ARMIES: # the id stays Tuning.ARMIES' key
		# (load-bearing in the save's `army` field) — only the button's
		# display text differs, via Armies.display_name
		var army_btn := _button(army_box, Armies.display_name(army_name), 18,
			func() -> void:
				GameScript.next_army = army_name
				army_center.visible = false
				rank_center.visible = true)
		# only the buttons stretch: the roster and power lines under each one
		# are reference text and stay at their natural height
		army_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var roster := Label.new()
		roster.text = _army_summary(Tuning.ARMIES[army_name])
		roster.add_theme_font_size_override("font_size", 11)
		roster.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		roster.modulate = Color(1, 1, 1, 0.7)
		army_box.add_child(roster)
		var kit: Dictionary = Armies.entry(army_name)
		var powers := Label.new()
		powers.text = "%s · %s" % [kit.power_name, kit.ability_name]
		powers.add_theme_font_size_override("font_size", 10)
		powers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		powers.modulate = Color(0.85, 0.8, 0.55) # gold tint, matches the
			# in-game Army Ability chip's own tint (hud.gd)
		army_box.add_child(powers)
	_button(army_box, "← Back", 20, func() -> void:
		army_center.visible = false
		main_box.visible = true)

	# tier select: chosen after the army, locked for the run
	# (07-difficulty-ranks — Continue into endless keeps it)
	rank_center = CenterContainer.new()
	rank_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	rank_center.visible = false
	add_child(rank_center)
	var rank_box := VBoxContainer.new()
	rank_box.add_theme_constant_override("separation", 12)
	rank_center.add_child(rank_box)
	var rank_pick := Label.new()
	rank_pick.text = "Choose your difficulty"
	rank_pick.add_theme_font_size_override("font_size", 28)
	rank_box.add_child(rank_pick)
	# issue 75: the seed field. Sits on the LAST screen before a run starts, so
	# it is the final thing set and cannot be lost by backing out of a later
	# step. Empty = a fresh random seed, exactly as before.
	var seed_row := VBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 2)
	var seed_label := Label.new()
	seed_label.text = "SEED — leave blank for random"
	seed_label.add_theme_font_size_override("font_size", 11)
	seed_label.modulate = Color(1, 1, 1, 0.55)
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_row.add_child(seed_label)
	seed_field = LineEdit.new()
	seed_field.placeholder_text = "any word or number"
	seed_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_field.custom_minimum_size = Vector2(240, 0)
	# must NOT take focus on show — the windowed click probes drive real input,
	# and a focused text field would swallow their keystrokes
	seed_field.focus_mode = Control.FOCUS_CLICK
	seed_row.add_child(seed_field)
	rank_box.add_child(seed_row)
	for tier_name in Tuning.TIERS:
		_button(rank_box, tier_name, 26, func() -> void:
			GameScript.next_tier = tier_name
			GameScript.next_seed = seed_field.text.strip_edges() # "" = random
			GameScript.next_config = {}
			GameScript.is_scenario = false
			get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	_button(rank_box, "← Back", 20, func() -> void:
		rank_center.visible = false
		army_center.visible = true)

	if args.has("--screenshot"):
		var dir: String = args[args.find("--screenshot") + 1]
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("menu.png"))
		get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _show_tests() -> void:
	main_box.visible = false
	test_scroll.visible = true


func _show_armies() -> void:
	main_box.visible = false
	army_center.visible = true


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
	_button(box, "← Back", 20, func() -> void:
		scores_center.visible = false
		main_box.visible = true)


## Games History: every real run's summary, newest first — distinct from the
## ranked top-10 Highscores above (05-menus-and-settings).
func _show_history() -> void:
	main_box.visible = false
	if history_scroll:
		history_scroll.queue_free()
	history_scroll = ScrollContainer.new()
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
			int(e.tariffs), "y" if int(e.tariffs) == 1 else "ies", int(e.get("lost", 0))]
		row.add_theme_font_size_override("font_size", 15)
		box.add_child(row)
	_button(box, "← Back", 20, func() -> void:
		history_scroll.visible = false
		main_box.visible = true)


func _show_about() -> void:
	main_box.visible = false
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
		main_box.visible = true)


func _army_summary(army: Array) -> String:
	var counts := {} # insertion-ordered, so the summary follows the army list
	for id in army:
		counts[id] = counts.get(id, 0) + 1
	var parts := []
	for id in counts:
		parts.append(("%d× %s" % [counts[id], id]) if counts[id] > 1 else id)
	return " · ".join(parts)


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
func _test_row_text(name: String, sec: String) -> String:
	if sec == "Other" or sec == "General" or not name.begins_with(sec):
		return name
	var rest := name.substr(sec.length()).strip_edges()
	if rest.begins_with(":"):
		rest = rest.substr(1).strip_edges()
	return rest if rest != "" else name
