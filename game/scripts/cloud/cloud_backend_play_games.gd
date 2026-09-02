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


static func is_available() -> bool:
	return false # TODO(native plugin): true once Play Games Saved Games is wired


static func push(_key: String, _envelope: Dictionary) -> bool:
	# TODO(native plugin): write _envelope (JSON-safe) to a Play Games
	# Saved Games snapshot named _key.
	return false


static func pull(_key: String) -> Variant:
	# TODO(native plugin): read the Play Games Saved Games snapshot named
	# _key and return its envelope Dictionary, or null if there isn't one.
	return null


## issue 83: the signed-in account's stable id, or "" when there is none.
## Part of the backend contract alongside is_available/push/pull.
static func account_id() -> String:
	return ""
