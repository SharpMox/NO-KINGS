# A synchronous cloud contract, kept over an asynchronous SDK

`cloud_save.gd` declares a four-method backend contract — `is_available()`,
`push(key, envelope)`, `pull(key)`, `account_id()` — whose callers consume the
return value immediately: `resolve(local_ts, local, pull(key))` needs the
envelope *now*, and `SyncQueue.drain()` takes a `Callable` that must return
`bool` per entry. The Play Games plugin
(`godot-sdk-integrations/godot-play-game-services`) is signal-based:
`save_game()` / `load_game()` return nothing and emit `game_saved` /
`game_loaded` later, and even the player id arrives asynchronously via
`load_current_player()` → `current_player_loaded`. A literal drop-in is
therefore impossible.

Decision: **the contract stays synchronous, and the asynchrony is absorbed
behind it** — `push()` fires and reports accepted, `pull()` answers from a
cache and kicks a refresh for next time, `account_id()` returns the id cached
at sign-in. This works because `cloud_save.gd` already states that local is the
source of truth and the cloud is only a mirror, so a stale or absent mirror is
a case the design already handles rather than a new failure mode.

## Considered Options

- **Make the contract asynchronous.** Rejected: it ripples through
  `cloud_save.gd`, `sync_file()`, `leaderboard.gd`, `SyncQueue.drain()`'s
  `Callable -> bool` shape, all seven call sites in `menu.gd` / `game.gd` /
  `economy.gd`, and every test — a very large diff whose only beneficiary is
  one platform backend, on a game whose saves are a few kilobytes.
- **Block synchronously on the SDK.** Rejected: freezing the main thread on a
  network round-trip is precisely the offline-hostile behaviour issue 84 ruled
  against ("offline while signed in plays normally and queues for sync").
- **Cache-and-defer behind the existing contract — chosen.** No caller changes
  shape; the mirror is allowed to lag.

## The bridge Node this forces

The plugin's clients (`PlayGamesSignInClient`, `PlayGamesSnapshotsClient`,
`PlayGamesPlayersClient`) are `Node` subclasses that wire their signals in
`_ready()`, and `export_plugin.gd` registers only **one** autoload —
`GodotPlayGameServices` — which holds the raw `android_plugin` and nothing
else. Their doc comments calling them "autoloads" are stale. `initialize()`
must also be called manually before any client works.

Our backend is static functions on a preloaded script: no node, no `_ready`, no
way to receive a signal. So a **single autoload of ours** owns the three
clients, calls `initialize()`, holds the cache, and no-ops off Android. A
scene-owned node was rejected: `menu.gd` and `game.gd` both call `CloudSave`,
so it would have to exist twice and would die between scenes, taking the cache
and any in-flight sign-in with it.

## Consequences

- **`pull()` may return stale data or `null`.** Safe by construction: conflict
  resolution is highest-wave-wins, then last-write-wins, so a stale mirror
  loses to local. This is the property that makes the whole approach sound —
  if resolution were ever changed to trust the cloud, this ADR must be revisited.
- **`is_available()` means "signed in and able to sync now"**, not "this device
  could do cloud". The two were conflated, and conflating them deadlocks the
  login button: it guards on `is_available()`, which is false until you sign
  in, so you could never sign in. Platform capability is a separate method,
  used only to decide whether a sign-in button should render at all.
- **The first `pull()` after sign-in has no cache.** Not accepted as a gap:
  sign-in completion triggers a fetch of `run` / `scores` / `history`, and each
  `game_loaded` re-runs that key's `sync_file`. Without it a player on a new
  phone would sign in, see an empty history, and only recover their progress
  after finishing a full run — which reads as data loss, not as staleness.
  Blocking the menu on a first load was rejected for the same reason as
  blocking `pull()`.
- **`push()` does not enqueue into `SyncQueue`.** Issue 86 originally ruled that
  it should, before the call sites were traced. `menu.gd` re-syncs all three
  keys on every boot and `sync_file` pushes at the end of each, so a push lost
  to a flaky network is re-pushed next launch with local intact throughout.
  Enqueuing would need a new `SyncQueue.remove(key)` (it has only `clear()` and
  `drain()`) to build a second delivery path for a failure a reboot already
  fixes. `cloud_save.gd` keeps owning the queue for the genuinely-offline case.
- **Google's snapshot-conflict picker is never shown.** `conflict_emitted` is
  resolved silently with our own rule and re-saved. Surfacing a picker would
  ask the player to arbitrate something we already decide deterministically,
  and would contradict "local is the source of truth".
- **Almost none of this is testable on desktop.** The bridge is Android-only
  signal wiring. One thing is pure and worth a test: the
  `Dictionary → JSON → utf8 → PackedByteArray` codec, since
  `PlayGamesSnapshot.content` is bytes and a wrong round-trip corrupts every
  save silently. A fake plugin double was rejected as infrastructure that
  mostly watches our own mocks agree.
