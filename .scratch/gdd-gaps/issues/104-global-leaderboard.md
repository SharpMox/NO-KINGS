# 104 — A global leaderboard, on top of the personal one

Status: todo (planned 2026-09-02)

## Parent

`.scratch/gdd-gaps/issues/85-cloud-leaderboards.md` — this ADDS to it, replacing nothing.

## The distinction this slice exists to make

There are two different questions a player asks, and issue 85 only answers the first:

| | Answers | Mechanism | Exists? |
| --- | --- | --- | --- |
| **Personal board** (85) | *am I improving?* | own top ten, mirrored through the cloud save and unioned per entry | **yes** |
| **Global board** (this) | *how do I rank?* | Play Games / Game Center, hosted and ranked by the platform | no |

The personal board **cannot** become global at any amount of effort: it is built on the
cloud-save mirror, which is per-account storage. A shared board needs either a platform
service or a server of our own — and the server was explicitly ruled out (user, 2026-09-02:
it means "money to spend, architecture to build, GDPR compliance and a slew of other work").

So the platform services are not one option among several; they are the only route that does
not build a backend.

## The seam: a NEW one, not the cloud-save contract

`cloud_save.gd`'s backend contract is `is_available / push / pull / account_id` — a key-value
mirror. A leaderboard is not a key-value mirror, and jamming it in would corrupt a seam that
three slices already depend on.

Proposed instead — small, and shaped by what the SDKs actually offer:

```
submit(board: String, value: int) -> void     # fire-and-forget
show(board: String) -> bool                   # open the PLATFORM's own UI
available() -> bool
```

**`submit` returns nothing on purpose.** Both SDKs accept a score and queue it themselves,
including offline. There is no success to report synchronously and no queue for us to build —
`SyncQueue` is not needed here, unlike saves.

## Show the platform's UI. Do not render the board ourselves.

Both platforms ship a leaderboard screen: Play Games' `showLeaderboard`, Game Center's
`show_game_center`. Calling it is one line and always correct — avatars, paging, friends,
time windows, localisation, and the player's own row highlighted.

Rendering it ourselves would mean fetching pages asynchronously, handling avatars and display
names, and reimplementing what both platforms already do — for a board whose contents we do
not own. **The native UI is the lazy answer and also the right one.** Revisit only if the
platform screen is genuinely unacceptable, which is a design judgement to make after seeing it
on a device, not before.

## What gets submitted, and when

`game.gd:1330` already has exactly the right guard, and it is where this hooks in:

```gdscript
if not is_scenario and not autoplay:
    rank = Economy.record_score(self)
    _record_history(won)
```

Scenario boards and bot runs must never reach a global board — issue 103's harness plays
hundreds of runs, and every one of them would otherwise post a score. Reuse this guard rather
than writing a second one.

Submit `g.score` at game over. The other two candidate boards (Deepest Wave, Kings Defeated)
are already recorded at run end and cost one Console entry plus one line each when wanted.

## Platform ids

Per-platform, because the two services issue their own:

| Platform | Board | Id |
| --- | --- | --- |
| Play Games | High Score | `CgkIhqzj3sAIEAIQAQ` (created 2026-09-02) |
| Game Center | High Score | not yet — needs an App Store Connect entry (issue 87) |

Already recorded as `LEADERBOARD_HIGH_SCORE` in `cloud_backend_play_games.gd`. The mapping
belongs beside each platform's backend, not in shared code, since neither id means anything on
the other platform.

## Where the player finds it

The Scores screen (`menu.gd:379`) already shows the personal board and a status line —
*"Cloud scores included."* / *"Local scores — sign in to compare."* A **"Global ranking"**
button beside it, enabled only when `available()`, is the whole UI change. The personal board
stays exactly as it is; the global one is a door out to the platform, not a second list to
maintain.

## Acceptance

- Desktop unaffected: no backend selected, no button, `run_all.sh` ALL GREEN.
- Scenario and autoplay runs submit **nothing** — asserted, not assumed. This is the one that
  silently corrupts a real leaderboard if it regresses.
- **Device-verified**: a real run posts a score and the platform screen shows it. As with 86,
  `run_all.sh` green does NOT verify this slice.

## Blocked by

- **86** — the same plugin, the same Gradle build, the same sign-in. This is strictly an
  addition to that work and should not be started before it.
- **87** for the iOS half; Game Center's leaderboard needs an App Store Connect entry, which
  is gated on a paid Apple account and Xcode.
