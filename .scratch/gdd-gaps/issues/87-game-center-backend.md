# 87 — Apple Game Center backend (iOS)

Status: **T1-T3a done, T4 unblocked** (2026-09-04 afternoon). Xcode installed; both plugins
compiled from master against the exact 4.7-stable commit, vendored under `game/ios/plugins`
with the rebuild recipe; the game RUNS on an iPhone 17 Pro simulator unsigned (login screen
verified on screen); and the probe read the API from the compiled singletons in the running
app. Probe findings: ICloud matches its header exactly (sync get_key_value, real remove_key);
GameCenter additionally exposes `is_authenticated` — the very method whose absence on Android
caused the phantom-silent-check bug; the singleton is `ICloud`, not the gdip's `iCloud`.
Upstream trap found+patched durably: the official 4.7 iOS template ships an x86_64-only
simulator lib under an arm64_x86_64 label (recipe in game/ios/plugins/README.md).

GATES REMAINING: T3b/T6 need the $99 account AND a physical iPhone — the borrowed one left
with its owner (2026-09-04) and returns in a few days. T4 (backend) is simulator-testable and
needs neither.

## Parent

`.scratch/gdd-gaps/issues/72-accounts-and-offline.md` (split (b), iOS half)

## Scope

Fill in `game/scripts/cloud/cloud_backend_game_center.gd`, today a stub. Sign-in, cloud save
read/write, leaderboard submit — same interface as 86, already exercised by
`cloud_backend_memory.gd`.

## Read this before starting

Same constraint as 86, with an extra one: **iOS additionally requires a paid Apple Developer
account and Xcode**, so it is gated on more than a device.

- Godot iOS export template + Xcode,
- a real iOS device (Game Center does not fully work in the simulator),
- an App Store Connect entry for leaderboard ids,
- a paid developer account.

Lands **written but unverified** unless done on a Mac with the full toolchain and a device.
**`run_all.sh` ALL GREEN does not verify this slice** — it verifies the desktop build still
works with the backend absent, which was already true.

## Worth deciding before building both

86 and 87 are the same shape against two SDKs. If only one platform is being targeted first,
building one and leaving the other stubbed is a legitimate call — the seam is designed for
exactly that, and `cloud_backend_noop.gd` already covers the unselected case.

## Acceptance

- Desktop build unaffected: backend stays unselected, `run_all.sh` ALL GREEN.
- **Device-verified** sign-in, save round-trip and leaderboard submit — or explicitly recorded
  as unverified, naming what was not tested.

## Blocked by

- 83 (login screen calls into it)
- an iOS toolchain, a paid developer account and a device — **environmental**

## The plugin is OFFICIAL, and this is the harder of the two (2026-09-02)

### `godotengine/godot-ios-plugins` — actually engine-official

Unlike the Android side (whose plugin is Foundation-adjacent but community-built), the iOS
Game Center plugin lives in **Godot's own GitHub organisation**. It exposes `authenticate`,
`post_score`, achievements and the Game Center UI, and is reached through
`Engine.has_singleton("GameCenter")`.

That singleton check is exactly the shape `cloud_backend_game_center.gd`'s `is_available()`
already has, so the seam is right.

### Why 87 is blocked harder than 86, measured not assumed

The iOS export template **is** installed (`ios.zip` is present beside the Android ones), but:

```
$ xcodebuild -version
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer
directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

**There is no Xcode on this machine** — only the Command Line Tools. A Godot iOS export
produces an Xcode *project*, which then has to be built and signed by Xcode. So unlike 86,
where a real APK builds locally today, iOS cannot get past "generate a project" here.

Still required, and none of it is reachable from this environment:

1. Xcode (a large install, and it gates everything else).
2. A **paid** Apple Developer account.
3. An App Store Connect entry for the leaderboard ids.
4. A real device — Game Center does not fully work in the simulator.

### Recommendation

**Do 86 first and leave 87 stubbed.** This file already anticipated that call ("building one
and leaving the other stubbed is a legitimate call — the seam is designed for exactly that"),
and the evidence now supports it: Android is one Play Console entry away from being testable,
while iOS is an Xcode install, a paid account and a device away.

## Fit analysis (2026-09-02): TWO plugins, not one — and a release problem

### `cloud_backend_game_center.gd` is misnamed for what it must do

Game Center does **authentication, leaderboards and achievements**. It does **not** store save
data. On iOS the save mirror is **iCloud**, and `godotengine/godot-ios-plugins` ships them as
two separate plugins:

```
plugins/: apn  arkit  camera  gamecenter  icloud  inappstore  photo_picker
```

`cloud_save.gd`'s own header already says *"Game Center/iCloud on iOS"*, so the design knew —
but the single backend file conflates them. Whoever builds this needs both.

### The APIs, read from the source rather than assumed

**`icloud` — a good fit, and better than Android's.** From `plugins/icloud/icloud.h`:

```cpp
Array   set_key_values(Dictionary p_params);
Variant get_key_value(String p_param);      // SYNCHRONOUS — returns the value
Error   synchronize_key_values();
Variant get_all_key_values();
int     get_pending_event_count();          // Variant pop_pending_event();
```

`get_key_value()` returns **synchronously**, so it maps onto `pull()` directly, and
`set_key_values()` onto `push()`. This is a genuine key-value store — the same shape as our
`push(key, envelope)`.

Caveat to design around: iCloud KV (`NSUbiquitousKeyValueStore`) is capped at **1 MB total and
1024 keys**, and values must be plist types — so the envelope travels as a JSON string, and the
cap needs a deliberate check rather than a silent truncation.

**`gamecenter` — async, via a pending-event queue**, not signals: a call returns an `Error`
immediately, then results are drained with `get_pending_event_count()` / `pop_pending_event()`.
So `account_id()` cannot be synchronous without caching the id from the last completed
`authenticate()` — the same resolution 86 records.

### The health problem: no Godot 4 RELEASE

| | |
| --- | --- |
| licence | MIT |
| org | **`godotengine`** — engine-official |
| last push | 2026-07-10 (master is alive) |
| **latest release** | **`3.5-stable`, 2022-09-05** — and 3.4/3.3.3 before it |

**Every published artifact is Godot 3.** The source does support Godot 4 — `icloud.h` guards on
`#if VERSION_MAJOR == 4` — but there is no prebuilt Godot 4 binary, so the plugins must be
**compiled from master yourself**, which needs Xcode. This machine has only the Command Line
Tools, so that is a second Xcode dependency on top of the export.

### Verdict, unchanged but now evidenced

**Do 86 first, leave 87 stubbed.** Android needs one maintained plugin with current releases
and one Play Console entry. iOS needs two plugins, neither released for Godot 4, compiled from
source with an Xcode that is not installed, plus a paid account and a device.

## CORRECTION + storage investigation (2026-09-02)

An earlier line here — *"Game Center does not store save data"* — is true of **Game Center**
and of **Godot's `gamecenter` plugin**, but it was read as "iOS has no save storage". **It
does. There is no need for a server, a database, or a GDPR estate.**

### iOS save storage, three routes, in order of preference

**1. iCloud key-value store — the answer.** Wrapped by `plugins/icloud` in the same official
repo, `get_key_value()` is **synchronous**, and the limits are not close to binding for us:

| Apple's limits (iCloud Design Guide) | Our usage |
| --- | --- |
| **1 MB total per user** | **~30 KB** — three keys |
| **1 MB per value** | **~10 KB** — a deliberately heavy `run` |
| **1024 keys** | **3** (`run`, `scores`, `history`) |
| key string <= 64 bytes | our keys are 3-7 chars |

The 10 KB figure is **measured, not estimated**: `SaveConfig.to_config()` on a wave-140 state
with the Artefact cap full, 3 Items, 40 Stock and 40 Captured entries serialises to
**10,090 bytes** (10,115 in the envelope). The other two keys are bounded by construction —
`HISTORY_CAP = 50` and scores are `slice(0, 10)`.

So we sit at roughly **3% of the total quota**, with ~100x headroom on the per-value limit.
The cap only becomes a design question if a save ever grows two orders of magnitude — e.g. by
embedding a per-turn history. Worth a size assertion at the push site rather than a silent
truncation, since NSUbiquitousKeyValueStore fails quietly when over quota.

**2. `GKSavedGame` — Apple's true Snapshots analogue, and NOT available to us.** GameKit does
have a saved-games API, so the platform gap is smaller than "Game Center has no saves"
suggests. But Godot's plugin does **not** wrap it — read from `plugins/gamecenter/game_center.h`,
the whole surface is:

```cpp
Error authenticate();  Error post_score(Dictionary);
Error award_achievement(Dictionary);  void request_achievements();
void request_achievement_descriptions();  Error show_game_center(Dictionary);
Error request_identity_verification_signature();
int get_pending_event_count();  Variant pop_pending_event();
```

Auth, leaderboards, achievements, UI. No snapshots. Using it would mean writing a custom
native plugin — strictly more work than route 1 for no benefit at our data size.

**3. iCloud Documents / CloudKit** — far larger, and unnecessary. Not wrapped by the plugin;
CloudKit would also drag in exactly the schema-and-quota thinking route 1 avoids.

### The entitlement, and what it does NOT change

iCloud KV needs the `com.apple.developer.ubiquitous-key-value-store` entitlement, which
requires an **enrolled (paid) Apple Developer account**. That is already on this slice's
blocker list, so it adds nothing new.

### The floor if iCloud is ever unavailable

Nothing breaks. The design is local-first — `cloud_save.gd` treats local as the source of truth
and the cloud as a mirror, and `cloud_backend_noop.gd` is the shipped desktop reality today. A
device with iCloud disabled simply plays offline, which is the same path desktop already takes.

## Bundle id ruled (2026-09-02)

**`com.sharpunk.nokings`** — the same id as Android (user ruling). Reverse-DNS of a domain
actually owned, and App Store Connect bundle ids are as permanent as Play application ids, so
this is decided before the entry exists rather than after.

## PLAN (grilled 2026-09-04, the night 86 was device-verified)

Rulings: **spec + tickets only, no code** until Xcode exists · **scope = Android parity**
(Game Center auth for identity + iCloud KV for the three save keys; NO leaderboards — that is
issue 104's territory) · **structure mirrors Android exactly** (one contract file + one bridge
autoload) · **plugin binaries get vendored** with a documented rebuild recipe. iPhone: available.

### What 86 taught that changes this design

The Android session found three defects desktop review could not see, and each has an iOS
echo worth designing against rather than rediscovering:

1. **Do not trust documented startup behaviour.** The Android plugin's "silent check at
   startup" does not exist at runtime; the bridge must actively ask. The Game Center plugin's
   `authenticate()` must be treated the same way — call it explicitly at bridge start, never
   assume an event arrives unprompted. Its events also arrive through a POLLED queue
   (`get_pending_event_count`/`pop_pending_event`), so the bridge polls on a timer; there is
   no signal to miss, which removes 86's listener-timing class entirely but adds a poll
   cadence to choose (1s is plenty; auth is once per session).
2. **Caches that can disagree with our own writes will.** 86's tombstone raced its own stale
   snapshot cache. iOS DOES NOT HAVE THIS CLASS: `get_key_value()` is synchronous, so there is
   NO read cache in the backend at all — `pull()` calls straight through. The only cached
   state is the Game Center player id, exactly like Android's.
3. **Fetch loops need a brake.** Android's arrive→sync→pull→refresh echo looped. iOS has no
   fetch at all (synchronous reads), so the class is absent. Nothing to throttle.

Net: **the iOS backend is STRUCTURALLY SIMPLER than Android's.** No snapshots dict, no
fetch/cooldown, no write-through discipline, no snapshot_loaded signal — menu's post-sign-in
"fetch all three keys" becomes a plain sync_file loop, because pull() is honest immediately.

### Design, resolved

- **Files (mirror Android):** `cloud_backend_ios.gd` (contract: is_available/push/pull/
  account_id + supported()) and `ios_cloud_bridge.gd` (autoload: owns BOTH plugin singletons,
  polls the Game Center event queue, caches player id, emits sign_in_finished). The misnamed
  `cloud_backend_game_center.gd` is renamed in the same commit — Game Center never stores
  saves; iCloud does.
- **is_available()** = authenticated AND `Account.owner() == player id` — the same ownership
  gate that stopped cross-account bleed on Android, same single-condition placement.
- **push()** = `set_key_values({key: JSON string})` with a **size assertion before the write**:
  NSUbiquitousKeyValueStore fails silently over quota, so a >900KB envelope push_errors and
  refuses rather than truncating. (Measured usage ~30KB total; the guard is cheap honesty.)
- **pull()** = `get_key_value(key)` parsed through the same decode discipline as Android
  (JSON.new().parse, dict-or-null) — synchronous, no cache, no refresh kick.
- **Tombstone** = `remove_key(key)` — iOS has real deletion (Android does not), so a finished
  run REMOVES the key; pull() of a missing key is null; resolve() keeps local. The null-data
  envelope sentinel stays understood for cross-compat but iOS writes none.
- **Sign-in flow:** zero menu.gd changes. The Apple provider button already routes through the
  same `_on_provider_pressed`; the bridge exposes the same supported()/signed_in/begin_sign_in
  surface, so the only edit is the platform guard accepting APPLE when the iOS bridge is
  supported. The consent rule (only a press binds), the generation counter, the reconcile —
  all shipped, all provider-agnostic already.
- **iCloud KV has NO per-account namespacing** — the store follows the device's iCloud
  account, not the Game Center player. The ownership gate handles the mismatch case exactly
  as Android does (cloud inert on a switch), and this is recorded here because it is the
  most likely place iOS behaves differently in practice than on paper.

### Slices

| Ticket | What | Needs |
| --- | --- | --- |
| **T1** | Environment: install Xcode, `xcode-select` to it, verify `xcodebuild -version` | ~15GB disk, time |
| **T2** | Compile godot-ios-plugins from master for 4.7 (engine build, then `generate_xcframework.sh` for `gamecenter` + `icloud`, debug AND release); vendor under `res://ios/plugin/` with the rebuild recipe committed beside them | T1 |
| **T3** | iOS export preset (bundle id `com.sharpunk.nokings`, plugins enabled, iCloud KV entitlement) + first Xcode build reaching the iPhone — the walking skeleton, no backend yet | T1, T2, **paid Apple account** |
| **T4** | The backend: `ios_cloud_bridge.gd` + `cloud_backend_ios.gd` (rename included), per the design above | T3, and the API surface re-verified against the COMPILED plugin, not the README |
| **T5** | Desktop pins for the pure parts (size guard, decode, ownership gate reuse) + `run_all.sh` ALL GREEN | T4 |
| **T6** | Device script on the iPhone — the 86 script translated: sign-in consent, binding, relaunch reconnect, tombstone-as-deletion across relaunch, wipe-and-restore, and the two-iPhone union if a second iOS device ever exists. **NOT cross-platform**: Play Games Snapshots and iCloud KV are different clouds under different accounts — saves are platform-siloed by design (issue 12's ruling, no server), so an Android phone and an iPhone never see each other's boards. Worth saying in the store listing some day rather than letting players discover it | T3-T5, App Store Connect entry |

**T1-T2 are yours-and-mine at a keyboard with disk space; T3 needs the $99 account. Nothing
before T4 writes backend code, and T4 re-reads the API from the built artefact first — the
README lied to us once already this week.**
