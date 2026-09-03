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

const Bridge := preload("res://scripts/cloud/play_games_bridge.gd")

## How long the login screen waits for Google before handing the buttons back.
## Two native round trips (authenticate, then load the player) on a phone that
## may have just lost signal — generous enough not to cut off a slow-but-working
## sign-in, short enough that a dead one does not strand the player.
const SIGN_IN_TIMEOUT := 30.0

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


static var window_sized := false # once per launch, not on every return to menu


## A cloud snapshot arrived for `key` — mirror it to disk through the normal
## resolve path, so the cloud copy only wins where it would have won at boot.
## The connection dies with this menu instance, so returning to the menu
## reconnects rather than stacking handlers. (issue 86 / T4)
func _on_snapshot_loaded(key: String) -> void:
	var paths := _SYNC_KEYS()
	if paths.has(key):
		CloudSave.sync_file(key, paths[key])


## An account is attached — silently at boot for a returning player, or through
## the login screen on a first run. Either way this is the first moment the
## cloud can be read at all, so it is where the fetch belongs. The login button
## deliberately does NOT do this: it would only ever cover the first launch.
func _on_sign_in_finished(ok: bool) -> void:
	if not ok:
		return
	# BINDING LIVES HERE, not in the login button's one-shot, because this
	# handler is the only one that sees every success.
	#
	# The one-shot ignores a verdict that arrives after the timeout already gave
	# up — correctly, since it must not yank a player out of whatever they moved
	# on to. But Google answering late is still Google answering: the bridge is
	# signed in, the cloud starts syncing, and without this the account file
	# would still say guest. The player would then be silently syncing one
	# account's cloud data into another account's saves.
	#
	# Idempotent by comparing the STORED owner to the live player id, rather than
	# just asking whether we are signed in. A plain signed_in() check binds a
	# guest and then never looks again — so a player who switches Google account
	# on the device keeps saves owned by the OLD id while the cloud syncs under
	# the new one, and resolve() does not read owners, so the two accounts'
	# progress quietly merges. Comparing ids covers the first bind and the switch
	# with the same branch, and costs nothing on the common path where they match.
	var id: String = CloudSave.backend.account_id()
	if id != "" and Account.owner() != id:
		# GOOGLE, because Play Games is the only provider that reaches this
		# signal. Game Center is issue 87 and will need its own path.
		Account.sign_in(Account.GOOGLE, id, _SAVE_PATHS())
	# An account can bind with no button pressed — the silent sign-in at boot —
	# so the UI it invalidates is corrected here rather than in the button.
	if is_instance_valid(sync_button):
		sync_button.visible = false
	# And if the login screen is still up, it is now asking for something that
	# already happened. Dismiss it rather than making the player sign in again
	# to a session they are already in.
	if login_center != null and login_center.visible:
		login_center.visible = false
		main_box.visible = true
	for key: String in _SYNC_KEYS():
		Bridge.fetch(key)

var main_box: VBoxContainer
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
		CloudSave.sync_file(key, _SYNC_KEYS()[key])
	# A snapshot fetched after sign-in lands asynchronously, long after the
	# sync above has run. Mirroring it to disk is what actually restores
	# progress on a fresh device. Null off Android, where nothing fetches.
	# (issue 86 / T4)
	var bridge := get_node_or_null(^"/root/PlayGamesBridge")
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
	if Account.provider() == Account.GUEST and Bridge.supported():
		sync_button = _button(main_box, "Sign in to sync", 24, func() -> void:
			main_box.visible = false
			login_center.visible = true)
	_button(main_box, "Settings", 24, func() -> void:
		main_box.visible = false
		settings_panel.visible = true)
	_button(main_box, "TEST", 24, _show_tests)
	_button(main_box, "Quit", 20, func() -> void: get_tree().quit())

	# Guide and Settings are shared with the in-game menu (scripts/guide.gd,
	# scripts/settings.gd) so the two entry points can't drift apart
	guide_scroll = Guide.build(self, func() -> void: main_box.visible = true)
	settings_panel = Settings.build(self, func() -> void: main_box.visible = true)

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
	var login_note := Label.new()
	login_note.add_theme_font_size_override("font_size", 13)
	login_note.modulate = Color(1, 1, 1, 0.6)
	login_note.text = "Your progress follows your account."
	login_box.add_child(login_note)
	var finish_login := func() -> void:
		# Only dismisses the login screen if it is actually the thing on screen.
		# A verdict can arrive long after the player left it — they may be in
		# Settings, the Guide or Scores, each of which hides main_box — and
		# unconditionally showing main_box would surface the main menu UNDERNEATH
		# whatever they opened. Signing in should never move the player.
		if not login_center.visible:
			return
		login_center.visible = false
		main_box.visible = true
	var provider_buttons: Array[Button] = []
	for prov in [Account.GOOGLE, Account.APPLE]:
		provider_buttons.append(
			_button(login_box, "Sign in with %s" % prov.capitalize(), 22, func() -> void:
				var unavailable := "%s sign-in isn't available on this device yet." \
					% prov.capitalize()
				# supported() — the PLATFORM question — not is_available(), which
				# reports whether an ACCOUNT is attached and is therefore false
				# until sign-in completes. Guarding on that one here would make
				# signing in impossible: the button would refuse forever. ADR 0003.
				#
				# Only Play Games is implemented (86). Game Center is 87 and its
				# backend is still a stub, so Apple falls through to the same
				# honest message rather than pretending.
				if prov != Account.GOOGLE or not Bridge.supported() or bridge == null:
					login_note.text = unavailable
					return
				# ALREADY signed in, silently. The plugin authenticates an
				# existing Play Games session on its own at startup, and on a
				# first run that can land while this screen is still up — the
				# menu listener takes it, but nothing binds an account, because
				# the one-shot below is only connected on a press.
				#
				# Without this, pressing the button then depends on the native
				# side re-emitting user_authenticated for a session it has
				# already authenticated. If it does not, the buttons stay locked
				# until the timeout and the player is told sign-in failed while
				# being signed in. Binding directly costs one branch.
				if Bridge.signed_in:
					Account.sign_in(prov, CloudSave.backend.account_id(), _SAVE_PATHS())
					if sync_button != null:
						sync_button.visible = false
					finish_login.call()
					return
				login_note.text = "Signing in…"
				# Locked while a sign-in is in flight. Each press would otherwise
				# connect another one-shot AND start another sign-in, so a single
				# verdict would run the whole completion path once per press.
				for b in provider_buttons:
					b.disabled = true
				# Shared by the verdict and the timeout so whichever arrives
				# first wins and the other becomes a no-op — without it a late
				# refusal would overwrite the screen a player had moved on from.
				var settled := [false]
				var release := func(note: String) -> void:
					if settled[0]:
						return
					settled[0] = true
					login_note.text = note
					for b in provider_buttons:
						b.disabled = false
				bridge.sign_in_finished.connect(func(ok: bool) -> void:
					# Same hazard the timeout guards against, and easier to hit:
					# the guest button stays live during a sign-in, so the player
					# can take it, start a run, and free this whole screen while
					# Google is still thinking. This lambda is connected to the
					# AUTOLOAD, which outlives the menu, and it touches Buttons
					# and Labels that would be gone.
					if not is_inside_tree() or settled[0]:
						return
					if not ok:
						release.call(unavailable)
						return
					settled[0] = true
					# UI ONLY. Both the account binding and the cloud fetch belong
					# to _on_sign_in_finished, which runs for every success —
					# including the silent one at boot and one that lands after
					# this screen's timeout. Doing either here would cover only
					# the case where a player happened to be watching.
					for b in provider_buttons:
						b.disabled = false
					# No longer a guest, so the main menu's entry point to this
					# screen goes away. It is built once at _ready and would
					# otherwise sit there offering to sign in an account that
					# just did.
					if sync_button != null:
						sync_button.visible = false
					finish_login.call(), CONNECT_ONE_SHOT)
				# Neither native hop is guaranteed to answer — a phone that just
				# lost signal simply never calls back — and without this the
				# screen sits on "Signing in…" with no way forward and no way
				# back. Guest stays reachable, but only if the buttons return.
				get_tree().create_timer(SIGN_IN_TIMEOUT).timeout.connect(func() -> void:
					# A SceneTreeTimer outlives this menu: the player can start a
					# run while the sign-in is still pending, freeing every node
					# `release` touches. Firing then would write to freed Buttons
					# and a freed Label. Nothing needs releasing once the screen
					# is gone, so leaving is the whole answer.
					if not is_inside_tree():
						return
					release.call("%s sign-in timed out. Check your connection and try again."
						% Account.GOOGLE.capitalize()))
				Bridge.begin_sign_in()))
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
	_button(login_box, "Play as Guest" if Account.needs_login() else "Continue offline",
		22, func() -> void:
			if Account.needs_login():
				Account.start_guest()
			finish_login.call())
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
	test_scroll.offset_left = 60
	test_scroll.offset_top = 30
	test_scroll.offset_right = -60
	test_scroll.offset_bottom = -30
	test_scroll.visible = false
	add_child(test_scroll)
	var test_box := VBoxContainer.new()
	test_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_box.add_theme_constant_override("separation", 6)
	test_scroll.add_child(test_box)
	var head := Label.new()
	head.text = "Test scenarios"
	head.add_theme_font_size_override("font_size", 22)
	test_box.add_child(head)
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
	for sec in ordered:
		var rows: Array[Button] = []
		var sec_head := Button.new()
		sec_head.flat = true # a header that happens to be clickable, not a CTA
		sec_head.add_theme_font_size_override("font_size", 11)
		sec_head.modulate = Color(1, 1, 1, 0.55) # same dimmed-header idiom the
			# inventory drawer's Activate section uses
		var relabel := func(open: bool) -> void:
			sec_head.text = "%s  %s  (%d)" % ["▾" if open else "▸",
				sec.to_upper(), groups[sec].size()]
		relabel.call(false)
		test_box.add_child(sec_head)
		for s in groups[sec]:
			var row := _button(test_box, s.name, 15, func() -> void:
				GameScript.next_config = s.cfg
				GameScript.is_scenario = true # scenarios never autosave
				get_tree().change_scene_to_file("res://scenes/Game.tscn"))
			row.visible = false
			rows.append(row)
		sec_head.pressed.connect(func() -> void:
			var open := not rows[0].visible
			for r in rows:
				r.visible = open
			relabel.call(open))
	_button(test_box, "← Back", 20, func() -> void:
		test_scroll.visible = false
		main_box.visible = true)

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
		_button(army_box, Armies.display_name(army_name), 18, func() -> void:
			GameScript.next_army = army_name
			army_center.visible = false
			rank_center.visible = true)
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
	status.text = "Cloud scores included." if Leaderboard.cloud_available() \
		else "Local scores — sign in to compare."
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
	body.text = "NO KINGS\nA fairy-chess strategy game — MVP build.\nBuilt with Godot 4."
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
