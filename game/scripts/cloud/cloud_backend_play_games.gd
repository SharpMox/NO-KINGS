## Android cloud backend (issue 12 — accounts & cloud saves): Play Games
## Saved Games mirror.
##
## STATUS: UNIMPLEMENTED STUB. This checkout is desktop-only with no Android
## export configured and no native plugin available to verify against, so
## push/pull are no-ops and is_available() stays false — no caller in
## cloud_save.gd ever depends on cloud data that doesn't exist yet.
##
## Making this real is a drop-in, not a rewrite: add the Play Games
## Services native plugin (Saved Games API), then fill in the three TODOs
## below with calls into it. Nothing in cloud_save.gd or its callers needs
## to change.


## --- Play Games identifiers, issued by the Play Console (issue 86) ----------
## Not secrets. An Android OAuth client has no client secret; the security
## boundary is the package name plus the signing certificate fingerprint, which
## is what the credential binds to.

## Goes into the Android manifest as `com.google.android.gms.games.APP_ID`; the
## plugin reads it from there rather than from GDScript. Recorded here so the
## value has one home in the repo.
const APP_ID := "292256536070"

## The GLOBAL Play Games leaderboard, created 2026-09-02.
##
## NOTE THIS IS NOT scripts/leaderboard.gd. That module (issue 85) is a
## PERSONAL cross-device board: your own top ten, mirrored through the cloud
## save and unioned per entry. This id addresses a board Google hosts and ranks
## every player on. The two are complementary, and submitting to this one needs
## a seam that does not exist yet — it is not part of the
## is_available/push/pull/account_id contract this file implements.
const LEADERBOARD_HIGH_SCORE := "CgkIhqzj3sAIEAIQAQ"


## The bridge owns the plugin's client Nodes and the cache this file reads.
## The dependency runs ONE WAY — backend -> bridge — which is why the snapshot
## codec lives over there rather than here: the bridge needs it too (to decode
## a loaded snapshot and to settle a conflict), and preloading in both
## directions is a cyclic reference.
const Bridge := preload("res://scripts/cloud/play_games_bridge.gd")

## Safe to preload: account.gd preloads nothing, so there is no cycle back to
## this file the way there would be with cloud_save.gd.
const Account := preload("res://scripts/account.gd")


## Whether there is an ACCOUNT to sync with right now — not whether this device
## could ever do cloud. Every caller of this (push/pull/sync_file, and
## leaderboard.cloud_available) means the former. `Bridge.supported()` answers
## the latter, and the login screen uses that one instead. See ADR 0003.
static func is_available() -> bool:
	# Signed in AND the signed-in player is the one this install's saves belong
	# to. The second half matters because the local files are stamped with an
	# owner: if the device's Google account changes, every sync path — push,
	# pull, sync_file, the leaderboard — would otherwise carry one account's
	# progress into another's cloud, and resolve() compares waves rather than
	# owners so the deeper run simply wins. One condition here makes the whole
	# cloud inert on a mismatch, instead of guarding six call sites.
	#
	# It reads false during the moment between signing in and binding, which is
	# correct: there is no agreed account yet. menu.gd binds first and fetches
	# after, so nothing is lost by that ordering.
	return Bridge.signed_in and Account.owner() == Bridge.player_id


## Accepted for delivery, not confirmed written: the SDK reports the outcome
## later on game_saved, and there is nothing to await. Safe because local stays
## the source of truth and every boot re-pushes.
static func push(key: String, envelope: Dictionary) -> bool:
	return Bridge.save(key, envelope)


## The last snapshot seen for `key`, and a refresh kicked off for next time.
##
## Answering from cache is what lets this stay synchronous under an async SDK.
## Returning stale data — or null before the first snapshot lands — is safe
## because resolve() is highest-wave-wins then last-write-wins, so a lagging
## mirror always loses to local. See ADR 0003.
static func pull(key: String) -> Variant:
	Bridge.fetch(key)
	return Bridge.snapshots.get(key)


## issue 83: the signed-in account's stable id, or "" when there is none.
## Part of the backend contract alongside is_available/push/pull.
##
## Cached from current_player_loaded, which is a SECOND async hop after
## authentication — so this stays empty between "signed in" and "player
## loaded", and T3 deliberately waits for the id before binding an account.
static func account_id() -> String:
	return Bridge.player_id
