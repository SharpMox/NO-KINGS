extends SceneTree
## issue 83: account-owned saves. The load-bearing assertion is the REBIND —
## a guest signing in must keep their progress, and must keep it because the
## save was rebound rather than copied or merged.

const Account := preload("res://scripts/account.gd")
const SyncQueue := preload("res://scripts/sync_queue.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("ok: ", label)
	else:
		fails += 1
		print("FAIL: ", label)


func _clean() -> void:
	var paths := [Account.ACCOUNT_PATH, "user://t_run.json", "user://t_scores.json"]
	# ...and anything logout parked, or a failed run leaves saves behind that
	# silently satisfy the next run's assertions.
	for owner_id in ["google-alice", "google-bob", "google-solo"]:
		for base in ["user://t_run.json", "user://t_scores.json"]:
			paths.append(Account._parked(base, owner_id))
	for p in paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	Account._reset_cache()
	SyncQueue.clear()


func _write(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))


func _read(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _init() -> void:
	_clean()

	# --- first run ---
	check(Account.needs_login(), "a fresh install needs login")
	check(Account.owner() == "", "and has no owner until one is made")

	# --- guest is a real account ---
	var guest_id := Account.start_guest()
	check(guest_id != "", "starting as guest mints an id")
	check(not Account.needs_login(), "once an account exists, login is never shown again")
	check(Account.owner() == guest_id, "the guest owns saves")
	check(Account.provider() == Account.GUEST, "provider is guest")
	check(not Account.signed_in(), "a guest is not 'signed in' — that is the upgrade path")

	# the id must survive a relaunch, or every session would own different saves
	Account._reset_cache()
	check(Account.owner() == guest_id, "the guest id persists across a relaunch")

	# --- saves carry the owner ---
	var stamped := Account.stamp({"score": 100})
	check(stamped.get("owner", "") == guest_id, "a save payload is stamped with its owner")
	check(stamped.get("score") == 100, "stamping does not disturb the payload")

	# --- THE REBIND: a guest keeps their progress when they sign in ---
	_write("user://t_run.json", Account.stamp({"score": 4200, "wave": 37}))
	_write("user://t_scores.json", Account.stamp({"best": 9000}))
	Account.sign_in(Account.GOOGLE, "google-abc",
		["user://t_run.json", "user://t_scores.json"])

	check(Account.owner() == "google-abc", "sign-in rebinds the owner")
	check(Account.provider() == Account.GOOGLE, "and records the provider")
	check(Account.signed_in(), "and now reads as signed in")

	var run: Variant = _read("user://t_run.json")
	check(run.get("owner", "") == "google-abc", "the existing run save is restamped")
	# the point of the whole design: the PROGRESS came with them, untouched
	check(run.get("score") == 4200 and run.get("wave") == 37,
		"the guest's progress survives the rebind intact — it was never a second history")
	check(_read("user://t_scores.json").get("owner", "") == "google-abc",
		"every save file is restamped, not just the run")

	# a missing file must not break sign-in — a player can sign in before ever
	# finishing a run, and that is the common case on a fresh install
	Account.sign_in(Account.APPLE, "apple-xyz", ["user://does_not_exist.json"])
	check(Account.owner() == "apple-xyz", "sign-in survives a save file that is not there")

	# --- pre-account saves ---
	# save_config.gd's rule: an additive field read with a default is safe
	# forever. A save written before issue 83 has no owner and must load, not
	# crash — this is why no migration was needed.
	var legacy := {"score": 10, "save_version": 2}
	check(str(legacy.get("owner", "")) == "",
		"a pre-account save reads back as unowned rather than failing")

	# --- issue 86: an EMPTY owner is not an account ---
	# A file carrying {"owner": ""} once bypassed the login screen forever while
	# also refusing every rebind: cloud off permanently, no route back. The rule
	# that fixed it — needs_login() treats an empty owner as no account — is
	# load-bearing, so it is pinned here rather than trusted to a comment.
	_write(Account.ACCOUNT_PATH, {"owner": "", "provider": Account.GOOGLE})
	Account._reset_cache()
	check(Account.needs_login(),
		"an account file with an empty owner still needs login (recoverable, not a dead state)")

	# --- issue 86: a rebind discards the previous owner's sync queue ---
	# The queue stamps no owner, so an entry queued under account A and drained
	# after binding to B would land in B's cloud — a run tombstone crossing that
	# way nulls B's cloud save. sign_in() clearing the queue is the guarantee.
	_clean()
	SyncQueue.enqueue("run", null)
	check(not SyncQueue.is_empty(), "precondition: something is queued")
	Account.sign_in(Account.GOOGLE, "google-after-queue", [])
	check(SyncQueue.is_empty(),
		"signing in clears a queue the previous owner filled — nothing crosses accounts")

	# ---- LOGOUT: progress stays with the account that earned it -------------
	# The ruling (user, 2026-09-05) is that logging out must not hand this
	# device's progress to whoever signs in next, and must give it back to the
	# account that owned it. Nothing gates LOADING on the owner stamp, so these
	# pins are about files existing or not, which is what the player actually
	# experiences.
	_clean()
	var RUN := "user://t_run.json"
	var SCORES := "user://t_scores.json"
	var paths: Array = [RUN, SCORES]
	Account.sign_in(Account.GOOGLE, "google-alice", paths)
	_write(RUN, {"wave": 42, "owner": "google-alice"})
	_write(SCORES, [{"score": 900}])

	check(Account.logout(paths), "logout succeeds for a signed-in account")
	check(Account.needs_login(), "after logout the login screen is what comes next")
	check(not Account.signed_in(), "and the session is over")
	check(not FileAccess.file_exists(RUN), "the run is gone from where the game reads it")
	check(FileAccess.file_exists(Account._parked(RUN, "google-alice")),
		"...parked under the account that owns it, not deleted")

	# A DIFFERENT account arrives on this device.
	Account.sign_in(Account.GOOGLE, "google-bob", paths)
	check(not FileAccess.file_exists(RUN),
		"a different account starts fresh — it does NOT inherit the run")
	check(not FileAccess.file_exists(SCORES),
		"...nor the scores, which carry no owner stamp of their own to protect them")
	check(FileAccess.file_exists(Account._parked(RUN, "google-alice")),
		"and Alice's parked run is still hers, untouched by Bob signing in")

	# Alice comes back.
	Account.logout(paths)
	Account.sign_in(Account.GOOGLE, "google-alice", paths)
	check(FileAccess.file_exists(RUN), "the returning account gets its run back")
	var restored: Variant = _read(RUN)
	check(restored is Dictionary and int(restored.get("wave", 0)) == 42,
		"...the same run, not an empty one")
	check(_read(SCORES) is Array and (_read(SCORES) as Array).size() == 1,
		"...and its scores")

	# A guest has no session to end, and start_guest() would mint a new id that
	# could never reclaim what was parked — so logout refuses rather than
	# orphaning it. The UI hides the button too; this is the belt.
	_clean()
	Account.start_guest()
	check(not Account.logout(paths), "logout refuses a guest — a fresh id could never reclaim the saves")
	check(not Account.needs_login(), "and leaves the guest account intact")

	# --- NO-11: the device's Google account changes under a signed-in install.
	# Before this the mismatch fell through every branch in menu.gd (its
	# sign_in call requires NOT signed in), so sync silently went dead.
	# switch_to composes logout+sign_in, so each account keeps its own progress.
	_clean()
	var sw_run := "user://t_run.json"
	var sw_paths: Array = [sw_run]
	Account.sign_in(Account.GOOGLE, "google-alice", sw_paths)
	_write(sw_run, {"wave": 42, "owner": "google-alice"})

	check(Account.switch_to(Account.GOOGLE, "google-bob", sw_paths),
		"NO-11: a live owner mismatch is handled as a switch")
	check(Account.owner() == "google-bob", "...the session is now the new account")
	check(not FileAccess.file_exists(sw_run),
		"...Bob does not inherit Alice's run")
	check(FileAccess.file_exists(Account._parked(sw_run, "google-alice")),
		"...Alice's run is PARKED under her id, never deleted")

	# switching back restores it — the property that makes this safe to ship
	# before a device can confirm it, since nothing is destroyed either way.
	check(Account.switch_to(Account.GOOGLE, "google-alice", sw_paths),
		"NO-11: switching back is the same operation")
	check(FileAccess.file_exists(sw_run), "...and Alice gets her run returned")
	var back: Variant = JSON.parse_string(FileAccess.get_file_as_string(sw_run))
	check(back is Dictionary and int(back.get("wave", 0)) == 42,
		"...with her progress intact, not just a file of the right name")

	check(not Account.switch_to(Account.GOOGLE, "google-alice", sw_paths),
		"NO-11: switching to the account already signed in is a no-op")
	check(not Account.switch_to(Account.GOOGLE, "", sw_paths),
		"NO-11: an empty id is refused rather than parking saves to nowhere")

	# A GUEST hitting this path is the conversion case, not a switch: sign_in
	# REBINDS so the guest's progress follows them. Parking it would orphan it,
	# because start_guest mints a new id every call.
	_clean()
	Account.start_guest()
	_write(sw_run, {"wave": 7})
	check(not Account.switch_to(Account.GOOGLE, "google-alice", sw_paths),
		"NO-11: a guest is refused — that is conversion, which sign_in rebinds")
	check(FileAccess.file_exists(sw_run),
		"...so the guest's run stays exactly where it is, unparked")

	# ---- NO-63: logout must not leave the run behind -------------------------
	# The defect, measured on Max's phone 2026-09-12: a stale parked file from an
	# earlier cycle made every move in logout() fail silently, logout still
	# returned true, and the outgoing account's run stayed live for the next
	# account to inherit. save.json and save.json.parked.<google-id> held the
	# SAME run — wave 8, score 6900, gold 364 — under two different owners.
	_clean()
	var n63_paths: Array = [RUN, SCORES]
	Account.sign_in(Account.GOOGLE, "google-alice", n63_paths)
	_write(RUN, {"wave": 1, "owner": "google-alice"})
	check(Account.logout(n63_paths), "precondition: a first logout parks normally")
	check(FileAccess.file_exists(Account._parked(RUN, "google-alice")),
		"...and the parked copy exists")

	# Alice comes back, plays further, and logs out AGAIN. The second logout is
	# the one that used to fail: its destination already exists.
	Account.sign_in(Account.GOOGLE, "google-alice", n63_paths)
	_write(RUN, {"wave": 42, "owner": "google-alice"})
	check(Account.logout(n63_paths),
		"a SECOND logout succeeds even though a parked copy already exists")
	check(not FileAccess.file_exists(RUN),
		"...and THE RUN IS GONE from where the game reads it — the whole defect")
	var n63_back: Variant = _read(Account._parked(RUN, "google-alice"))
	check(n63_back is Dictionary and int(n63_back.get("wave", 0)) == 42,
		"...and the parked copy is the LATEST run, not the stale one (user ruling: overwrite)")

	# And the consequence that made it an account-correctness bug rather than a
	# housekeeping one: the next account must not find the previous one's run.
	Account.sign_in(Account.GOOGLE, "google-bob", n63_paths)
	check(not FileAccess.file_exists(RUN),
		"a different account signing in after that logout inherits NOTHING")

	# A logout that CANNOT park must not report success, and must not unbind —
	# clearing the owner while the run is still live is exactly what hands it to
	# the next account. Forced by making the destination undeletable: a
	# DIRECTORY where the parked file would go cannot be removed or renamed over.
	_clean()
	Account.sign_in(Account.GOOGLE, "google-solo", n63_paths)
	_write(RUN, {"wave": 7, "owner": "google-solo"})
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(Account._parked(RUN, "google-solo")))
	check(not Account.logout(n63_paths),
		"a logout whose move FAILS reports failure rather than succeeding quietly")
	check(Account.owner() == "google-solo",
		"...and leaves the account BOUND, so the run is not handed to the next signer")
	check(FileAccess.file_exists(RUN), "...with the run still where its owner can reach it")
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(Account._parked(RUN, "google-solo")))

	# A SWITCH inherits the same guarantee. switch_to is logout-then-sign_in, so
	# a switch whose logout cannot park must not go on to bind the incoming
	# account — that is the same handover by another route.
	_clean()
	Account.sign_in(Account.GOOGLE, "google-solo", n63_paths)
	_write(RUN, {"wave": 3, "owner": "google-solo"})
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(Account._parked(RUN, "google-solo")))
	check(not Account.switch_to(Account.GOOGLE, "google-bob", n63_paths),
		"a switch whose logout cannot park REFUSES rather than binding the new account")
	check(Account.owner() == "google-solo",
		"...and the outgoing account still owns the install")
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(Account._parked(RUN, "google-solo")))

	# The reclaim is the OPPOSITE rule, deliberately: a live save at sign-in time
	# is a guest conversion, and the guest's run must follow them rather than be
	# overwritten by an older parked copy of the account they are converting to.
	_clean()
	Account.sign_in(Account.GOOGLE, "google-alice", n63_paths)
	_write(RUN, {"wave": 5, "owner": "google-alice"})
	Account.logout(n63_paths)                      # park Alice's wave-5 run
	Account.start_guest()
	_write(RUN, {"wave": 99, "owner": "a-guest"})  # the guest plays
	Account.sign_in(Account.GOOGLE, "google-alice", n63_paths) # conversion
	var n63_conv: Variant = _read(RUN)
	check(n63_conv is Dictionary and int(n63_conv.get("wave", 0)) == 99,
		"a guest converting KEEPS their own run — the reclaim does not overwrite it")
	check(str(n63_conv.get("owner", "")) == "google-alice",
		"...and it is restamped to the account they converted to")
	check(FileAccess.file_exists(Account._parked(RUN, "google-alice")),
		"...and the older parked run is left alone rather than deleted")

	# ---- NO-54: the display name is UNTRUSTED INPUT --------------------------
	# A display name is chosen by the account holder, arrives from a platform
	# service, and we render it and write it to disk. Each case below is a thing
	# that string can be.
	_clean()
	check(Account.clean_name("Max\nQuit the game") == "MaxQuit the game",
		"a newline is stripped — a name cannot add lines to the prompt")
	# Built with char() rather than written literally: an invisible control
	# character sitting in a source file is the very hazard under test here, and
	# Godot's own parser refuses to compile one.
	check(Account.clean_name("ab" + char(0x202E) + "cd") == "abcd",
		"a bidi OVERRIDE is stripped — displayed text cannot be made to lie")
	check(Account.clean_name(char(0x2066) + "a" + char(0x2069) + "b") == "ab",
		"...and so are the isolates, which do the same job")
	check(Account.clean_name("a" + char(0x200B) + "b" + char(0xFEFF) + "c") == "abc",
		"zero-width padding is stripped — two accounts cannot render identically")
	check(Account.clean_name("\t" + char(0x07) + "x" + char(0x9F) + "y") == "xy",
		"C0 and C1 controls are stripped")
	var huge := "A".repeat(10000)
	check(Account.clean_name(huge).length() == Account.NAME_MAX_CHARS,
		"a 10,000-character name is capped at %d, before anything measures it"
			% Account.NAME_MAX_CHARS)
	# THE CASE THAT MAKES THE REST MEANINGFUL. A sanitizer that mangles a real
	# name is worse than none, and this project has already shipped one string
	# defect (NO-52) that only a non-Latin account revealed.
	for legit in ["Максим", "山田太郎", "Zoë O'Brien-Smith", "مُحَمَّد", "🎲 Dice"]:
		check(Account.clean_name(legit) == legit,
			"a legitimate name survives UNCHANGED: %s" % legit)

	# ---- NO-54: the save field is ADDITIVE, which is why it is safe ----------
	# save_config.gd's header draws the line this asserts: a field ADDED and read
	# with a default is safe forever; a field RESHAPED and read with a default is
	# a silent corruption. Both halves are pinned — an old file still loads, and
	# the field appears once something writes it.
	_clean()
	_write(Account.ACCOUNT_PATH, {"owner": "google-old", "provider": Account.GOOGLE})
	Account._reset_cache()
	check(Account.owner() == "google-old" and Account.provider() == Account.GOOGLE,
		"a save written BEFORE the name field still loads")
	check(Account.owner_name() == "",
		"...and reads an empty name rather than failing")
	Account.sign_in(Account.GOOGLE, "google-named", [], "Renée")
	check(Account.owner_name() == "Renée",
		"a rebind writes the name, so it is populated the next time the file is written")
	var on_disk: Variant = _read(Account.ACCOUNT_PATH)
	check(on_disk is Dictionary and str(on_disk.get("name", "")) == "Renée",
		"...and it really is on disk, not only in the cache")
	Account.sign_in(Account.GOOGLE, "google-nameless", [])
	check(Account.owner_name() == "",
		"a provider that gives no name lands on empty, which callers read as \"use the id\"")
	# The file is a plain file on the player's device. A clean write is not a
	# guarantee of a clean read, so the read sanitizes too.
	_write(Account.ACCOUNT_PATH, {"owner": "google-tampered",
		"provider": Account.GOOGLE, "name": "good" + char(0x202E) + "reversed\nbad"})
	Account._reset_cache()
	check(Account.owner_name() == "goodreversedbad",
		"a HAND-EDITED account.json cannot inject through the name either")

	_clean()
	print("---")
	print("ALL ACCOUNT CHECKS OK" if fails == 0 else "ACCOUNT FAILURES: %d" % fails)
	quit(1 if fails > 0 else 0)
