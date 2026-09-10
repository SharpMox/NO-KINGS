## NO-8 (was issue 104): the GLOBAL leaderboard — how do I rank? — on top of
## the personal one (issue 85, leaderboard.gd), which answers am I improving?
##
## The two are not the same board and the personal one cannot become global at
## any amount of effort: it is built on the cloud-save mirror, which is
## per-account storage. A shared board needs a platform service or a server of
## our own, and the server was ruled out (user, 2026-09-02: money to spend,
## architecture to build, GDPR compliance). So the platform services are not one
## option among several — they are the only route that does not build a backend.
##
## A NEW SEAM, deliberately not cloud_save.gd's. That contract is
## is_available/push/pull/account_id — a key-value mirror that three slices
## depend on. A leaderboard is not a key-value mirror, and widening that seam to
## fit one would corrupt it for everything else.
##
## submit() RETURNS NOTHING on purpose. Both SDKs accept a score and queue it
## themselves, including offline, so there is no success to report synchronously
## and no queue for us to build — unlike saves, this needs no SyncQueue.
##
## The board ids live beside each platform's backend, never here: an id issued
## by Play Games means nothing to Game Center and vice versa.

const PlayGames := preload("res://scripts/cloud/cloud_backend_play_games.gd")
const IOS := preload("res://scripts/cloud/cloud_backend_ios.gd")

## Logical board names. The platform backends map these to their own ids.
## One board today; the other two candidates (Deepest Wave, Kings Defeated) are
## already recorded at run end and cost one Console entry plus one line each.
const HIGH_SCORE := "high_score"

## Every submit ATTEMPT, counted before any availability check.
##
## This exists for one test, and it is the test that matters most in this slice:
## the playtest harness plays hundreds of bot runs, and if the submit call ever
## escapes game.gd's `not is_scenario and not autoplay` guard, every one of them
## posts a score to a real, public board. That regression is invisible on
## desktop — available() is false, so nothing would actually be sent — which is
## exactly why the counter has to sit BEFORE the availability check rather than
## after it. Counting attempts is what makes "submits nothing" assertable
## without a device.
static var submits := 0


## Per platform, the same shape cloud_save.gd's _default_backend() uses.
##
## iOS is wired here as of 2026-09-10, and it still reports no board — because
## its LEADERBOARD_HIGH_SCORE is empty until Apple issues the id, and its
## board_available() says so. That is deliberately a different mechanism from
## the `return null` this used to do: null meant "this platform has no backend",
## which stopped being true once the Game Center one existed, and it would have
## made the id landing a two-file change. The property that mattered about the
## null is kept either way — iOS never falls through to Play Games, so we never
## silently ask Google about an iOS player, the kind of wrong that looks fine in
## every test and shows up as an empty board on a real device.
static func _backend():
	match OS.get_name():
		"Android":
			return PlayGames
		"iOS":
			return IOS
	return null


## Is there a platform board to talk to? False on desktop (no backend), false
## on iOS until Game Center's board id exists, and false on either platform
## until the player is signed in — a board with no account behind it has nothing
## to post to.
static func available() -> bool:
	var b = _backend()
	return b != null and b.board_available()


## Fire-and-forget. Safe to call when unavailable; it simply does nothing.
static func submit(board: String, value: int) -> void:
	submits += 1
	if not available():
		return
	_backend().board_submit(board, value)


## Open the PLATFORM's own leaderboard screen. Returns false when there is none
## to open, so a caller can leave its button disabled rather than dead.
##
## We do NOT render the board ourselves. Both platforms ship a screen that
## already does avatars, paging, friends, time windows, localisation and the
## player's own row highlighted — for a board whose contents we do not own.
## Reimplementing that would be a fetch-and-paginate slice for a worse result.
static func show_board(board: String) -> bool:
	if not available():
		return false
	return _backend().board_show(board)
