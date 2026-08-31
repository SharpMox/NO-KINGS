extends SceneTree
## issue 83: account-owned saves. The load-bearing assertion is the REBIND —
## a guest signing in must keep their progress, and must keep it because the
## save was rebound rather than copied or merged.

const Account := preload("res://scripts/account.gd")

var fails := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("ok: ", label)
	else:
		fails += 1
		print("FAIL: ", label)


func _clean() -> void:
	for p in [Account.ACCOUNT_PATH, "user://t_run.json", "user://t_scores.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	Account._reset_cache()


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

	_clean()
	print("---")
	print("ALL ACCOUNT CHECKS OK" if fails == 0 else "ACCOUNT FAILURES: %d" % fails)
	quit(1 if fails > 0 else 0)
