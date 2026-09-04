## iOS cloud backend (issue 87): Game Center for identity, iCloud key-value
## storage for the three save keys. Renamed from cloud_backend_game_center.gd —
## Game Center never stores saves, and the old name already misled one reader
## into "iOS has no save storage" (see issue 87's correction note).
##
## Mirrors cloud_backend_play_games.gd line for line where the platforms agree,
## and is SHORTER where iOS needs less: reads are synchronous, so there is no
## cache, no fetch kick, and no write-through discipline here at all.

const Bridge := preload("res://scripts/cloud/ios_cloud_bridge.gd")

## Safe to preload for the same reason as the Android pair: account.gd preloads
## only sync_queue.gd, which preloads nothing — no cycle back to this file.
const Account := preload("res://scripts/account.gd")


## Signed in AND the signed-in player owns this install's saves — the same
## single-condition ownership rule as Android, in the same place, so a device
## whose Game Center account changes goes cloud-inert instead of mixing two
## players' progress. See ADR 0003 and issue 86's account-switch section.
static func is_available() -> bool:
	return Bridge.signed_in and Account.owner() == Bridge.player_id


static func push(key: String, envelope: Dictionary) -> bool:
	# A finished run is DELETED, not marked. Android's cloud has no delete, so
	# a null-data envelope serves as its "no run" marker; iCloud has
	# remove_key, so the key simply stops existing and a later pull finds
	# nothing — the honest version of the same contract.
	if envelope.get("data") == null:
		Bridge.erase(key)
		return true
	return Bridge.save(key, envelope)


## SYNCHRONOUS, and therefore trivially honest: what the store holds is what
## the caller gets, including our own writes an instant ago. The entire
## defect family 86 found on device — stale cache, refresh echo — has no
## code to live in here.
static func pull(key: String) -> Variant:
	return Bridge.read(key)


## issue 83: the signed-in account's stable id, or "" when there is none.
## Cached from the authentication event; the id arrives in the same event as
## the verdict on iOS (one hop, not Android's two), but the rule is unchanged:
## no id, no completed sign-in.
static func account_id() -> String:
	return Bridge.player_id
