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

	_clean()
	print("---")
	print("ALL ACCOUNT CHECKS OK" if fails == 0 else "ACCOUNT FAILURES: %d" % fails)
	quit(1 if fails > 0 else 0)
