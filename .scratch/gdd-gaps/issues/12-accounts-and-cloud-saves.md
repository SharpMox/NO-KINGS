# 12 — Accounts & cloud saves (spike first)

Status: done (local half; platform backends stubbed)

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

**This is a spike, not an implementation slice.** The
[Accounts & Save Data](https://app.notion.com/p/383f1559c99b818e805de4d60ab1c5e6) page is
an investigation, not a spec, and it turns on a product decision nobody has made:

- **Cross-platform unified account** → needs a backend (Firebase / Supabase / PlayFab /
  Nakama).
- **Platform-siloed saves** → no backend at all; Game Center + iCloud on iOS, Play Games
  Saved Games on Android.

Pure Sign in with Apple / Google Sign-In only prove identity — they store no save data, so
the "no manual account" goal alone does not settle it.

Today saves are local-only (`user://`) and the leaderboard is local top-10 (divergence #9).
Offline play — the page's one hard requirement — already works.

Deliver the decision and a verified plan, not code:

1. Pick siloed vs unified.
2. If unified, shortlist the BaaS and **verify the Godot 4 plugin actually works on native
   iOS + Android exports** — the page already flags GodotFirebase compatibility as unproven.
3. Sketch the save-data model and the conflict-resolution rule (the page's open question:
   what happens when one save is played on two offline devices before either reconnects).
4. Only then split the build into its own slices.

Note this also decides divergence #9 — a shared leaderboard needs the same backend.

## Acceptance criteria

- [ ] Siloed vs unified decided and recorded
- [ ] If unified: plugin verified on a real device export, not just claimed
- [ ] Save-data model and conflict rule sketched
- [ ] Follow-up implementation slices written
- [ ] Leaderboard (divergence #9) decided alongside it

## Decision: platform-siloed saves, no backend (2026-08-28)

Taken so the slice can proceed as an implementation rather than an open question.

**Ship Game Center + iCloud on iOS and Play Games Saved Games on Android. No backend.**

Reasoning, against the page's own framing:

- The hard requirement — *"the game must be fully playable offline"* — is already met and
  stays met.
- The stated motivation was "no manual account". Platform sign-in delivers exactly that;
  it is only *cross-platform* progress that needs a backend, and nobody has asked for it.
- A BaaS adds an operated dependency, and the page already flags the Godot 4 plugin story
  (GodotFirebase) as unverified on native iOS/Android exports. That is a real integration
  risk for a benefit nobody has requested.
- It can be revisited: moving siloed saves into a backend later is a migration, not a
  rewrite. Choosing a backend now and finding the plugin broken is the expensive mistake.

**Consequence:** the leaderboard stays local (divergence #9 stands). A shared leaderboard
needs the same backend, so it is deferred with it.

The remaining work is real but bounded: wire the two platform save APIs, decide the
conflict rule (last-write-wins is fine for a single-player roguelike), and keep the local
save as the source of truth with the cloud as a mirror.


## Outcome

Built the local half of the Decision above: the sync abstraction, a real
desktop backend, and the wiring — not a working cloud sync on any platform.

**Real and shipped:**
- `game/scripts/cloud_save.gd` — the sync layer: `push`/`pull`/`resolve`
  (last-write-wins, ties and malformed/missing remotes keep local) plus
  `sync_file(key, path)`, the full mirror step (pull → resolve → write-back
  if remote won → push) used at every call site.
- `game/scripts/cloud/cloud_backend_noop.gd` — the desktop backend, selected
  by `OS.get_name()`. This is finished, not a stub: there is no cloud on
  desktop, so `is_available()` is `false` and push/pull correctly no-op.
- `game/scripts/cloud/cloud_backend_memory.gd` — an in-memory backend used
  only by the test suite, to exercise push/pull/resolve without a platform.
- Wiring into the existing local-save path: `game.gd`'s autosave
  (`SAVE_PATH`, at every turn start), `economy.gd`'s `record_score` /
  `record_history` (`SCORES_PATH` / `HISTORY_PATH`, slice 05), and
  `menu.gd`'s boot (`_ready`, pulling all three before the Continue check).
  On every platform tested here (desktop) this wiring is a confirmed no-op —
  `backend.is_available()` gates it off — so offline play has zero new
  network dependency and the existing save format is untouched byte-for-
  byte (`test_save.gd`'s exact round-trip still holds; the cloud timestamp
  lives only in a wrapper envelope, never in the save files themselves).
- `game/tests/test_cloud_save.gd` — headless coverage of push/pull,
  `resolve()`'s last-write-wins rule (newer remote wins, older remote
  loses, ties keep local, no local takes a fresh-device remote, missing/
  malformed remote keeps local), and `sync_file()`'s file-level round-trip.
  Wired into `run_all.sh`.

**Explicitly NOT real — unimplemented stubs, not working integrations:**
- `game/scripts/cloud/cloud_backend_game_center.gd` (iOS: Game Center +
  iCloud) and `game/scripts/cloud/cloud_backend_play_games.gd` (Android:
  Play Games Saved Games) are both stubs: `is_available()` hardcoded
  `false`, `push`/`pull` bodies are `TODO(native plugin)` comments
  returning `false`/`null`. No native plugin is installed or verified —
  this repo has no iOS/Android export configured to test against, per the
  issue's own practical constraint. Nothing platform-specific has been
  proven; there is no cloud save on any device today.
- Making a stub real is meant to be a drop-in: install the platform's
  native plugin, fill in the three TODO bodies in that one file, change
  nothing in `cloud_save.gd` or its callers.
- No backend, no Firebase/Supabase (per the Decision). No shared/cloud
  leaderboard — it stays local (divergence #9 stands, unchanged by this
  slice).

**Verification:** `game/tests/run_all.sh` (windowed click probes + full
headless suite, including the new `test_cloud_save`) is ALL GREEN.

## Blocked by

- 05 — Settings surface (where an account row would live)
