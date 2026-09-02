# 87 — Apple Game Center backend (iOS)

Status: todo — **cannot be verified in this environment, see below**

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
