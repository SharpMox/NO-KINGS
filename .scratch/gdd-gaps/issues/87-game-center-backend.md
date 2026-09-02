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
