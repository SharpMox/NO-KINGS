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


## NO-8: the Game Center half.
##
## Creating the board is an App Store Connect action only the account holder can
## take (docs/MANUAL-STEPS.md section D) and Apple issues the identifier at that
## moment, which is why this sat empty from 2026-09-10: everything downstream —
## bridge calls, backend methods, the global_board seam — was already wired, so
## the id landing really was a one-string change with no new code.
##
## IT THEN SAT EMPTY FOR A DAY AFTER THE BOARD EXISTED, which is the part worth
## remembering. The leaderboard was created on 2026-09-10 and nobody came back
## to this line, so board_available() kept answering false and NOTHING ever
## reached GKScore on iOS — a wired feature that had never once run, with no
## symptom anywhere because "no board" and "board that is never asked" look
## identical from the outside. An empty id is a first-class state here by
## design; the cost of that design is that it is also completely silent.
## FILLED IN 2026-09-11. Max created the leaderboard in App Store Connect on
## 2026-09-10 — which is also what fixed NO-53, because a Game Center app with
## no leaderboard is not "fully configured" and GameKit hands back a fresh
## placeholder id at every launch instead of a stable teamPlayerID.
##
## The value is his, first-hand, plus a screenshot of the leaderboard page
## reading "Leaderboard ID: high_score". NOT re-read from App Store Connect by
## us. That distinction matters here more than usual: GKScore accepts ANY
## string, so a wrong id is a score that silently goes nowhere and looks
## exactly like a working board. It becomes verified the first time a score
## lands on a real device, and not before.
const LEADERBOARD_HIGH_SCORE := "high_score"


## Mirrors cloud_backend_play_games.gd's function of the same name. The mapping
## lives beside the platform that issued the id, never in global_board.gd: a
## Game Center identifier means nothing to Play Games and vice versa.
static func board_id(board: String) -> String:
	match board:
		"high_score": return LEADERBOARD_HIGH_SCORE
	return "" # an unknown board is not an error, it is simply not wired yet


## Signed in AND there is an id to talk to.
##
## Android's twin is just is_available(), because its board has been real since
## 2026-09-02. The second clause here is no longer load-bearing now the id is
## filled in (2026-09-11) — it is KEPT because what it guards against has not
## changed: an empty id would have a signed-in player submitting into an
## identifier Apple never issued, and GKScore takes any string, so that failure
## is a score that silently goes nowhere and looks exactly like a working
## board. A future board added to board_id() starts empty the same way.
##
## The clause names the constant directly rather than calling board_id(),
## because global_board.gd is what defines the logical board names and
## preloading it here would close a cycle back onto this file.
static func board_available() -> bool:
	return is_available() and LEADERBOARD_HIGH_SCORE != ""


static func board_submit(board: String, value: int) -> void:
	var id := board_id(board)
	if id != "":
		Bridge.submit_score(id, value)


static func board_show(board: String) -> bool:
	var id := board_id(board)
	return Bridge.show_leaderboard(id) if id != "" else false


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


## NO-54: the signed-in player's display name, or "" when there is none.
## Arrives in the SAME authentication event as the id, so it can never
## describe a different player than account_id() does.
static func account_name() -> String:
	return Account.clean_name(Bridge.display_name) # untrusted: see clean_name
