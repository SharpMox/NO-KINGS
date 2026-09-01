# 86 — Google Play Games backend (Android)

Status: in progress — **toolchain installed and an APK builds (2026-09-01)**; blocked on a Play Console entry

## Parent

`.scratch/gdd-gaps/issues/72-accounts-and-offline.md` (split (b), Android half)

## Scope

Fill in `game/scripts/cloud/cloud_backend_play_games.gd`, today a stub. Sign-in, cloud save
read/write, leaderboard submit — against the interface slices 83-85 already exercise via
`cloud_backend_memory.gd`.

The seam exists and is already proven by the memory backend, so this slice is the SDK
plumbing, not the architecture.

## Read this before starting

**This slice cannot be tested by the existing suite, and cannot be verified on this machine.**
72 says so plainly: headless Godot has no Play Games. It additionally needs:

- the official Godot Play Games plugin **or** a custom Android export template,
- an Android device or emulator with Play services,
- a Play Console entry for the app (leaderboard ids come from there).

None of that is reachable from the desktop dev loop that every other slice in this backlog
has been verified against. So this slice lands **written but unverified** unless it is done on
a machine with the toolchain and a device.

**Do not let `run_all.sh` ALL GREEN stand in as verification here.** Green means the desktop
build still works with the backend absent — which is exactly what it meant before this slice
was written. That is the trap this note exists to prevent.

## Acceptance

- Desktop build unaffected: the backend stays unselected, `run_all.sh` ALL GREEN.
- **Device-verified** sign-in, save round-trip and leaderboard submit — or the slice is
  explicitly recorded as unverified, with what was not tested named.

## Blocked by

- 83 (login screen calls into it)
- an Android toolchain + device — **environmental, not a code dependency**


## Toolchain: INSTALLED AND PROVEN (2026-09-01)

The environmental blocker in "Blocked by" is **half cleared**. A debug APK now builds from this
machine — 29.7 MB, 435 files — so the *build* half of this slice is no longer hypothetical.

### What was installed

| Piece | Where |
| --- | --- |
| JDK 17 | `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home` (brew formula, no sudo) |
| Android cmdline-tools + SDK | `/opt/homebrew/share/android-commandlinetools` |
| SDK packages | `platform-tools`, `build-tools;34.0.0`, `platforms;android-34`, licences accepted |
| Godot 4.7 export templates | `~/Library/Application Support/Godot/export_templates/4.7.stable` (1.28 GB) |

**Godot's editor settings were pointing at `~/Library/Android/sdk`, which does not exist on
this machine.** That is why the first export failed with *"Missing 'platform-tools'
directory"* despite the SDK being installed. `editor_settings-4.7.tres` now points at the brew
paths above; the original is backed up beside it as `.bak-preandroid`.

Reproduce the build with:

```sh
cd game && godot --headless --path . --export-debug "Android" ../build/nokings.apk
```

`build/` is already gitignored, so the APK never enters the repo.

### One cosmetic gap found

*"No project icon specified"* — `Application -> Config -> Icon` is unset. It does not block the
export and the APK is valid, but a store build will want one.

### What is still blocked, and why it cannot be worked around

Play Games sign-in needs an **OAuth client tied to the package name AND the signing
certificate fingerprint**, both of which are issued by the Play Console. So:

1. A Play Console entry for `com.sharpmox.nokings` (one-time $25 developer account).
2. Leaderboard IDs created in that console.
3. An Android device with USB debugging.

Also note `export_presets.cfg` has `gradle_build/use_gradle_build=false`. **The Play Games
plugin requires a Gradle build**, because Godot Android plugins are Android libraries — so
that flag flips as part of wiring the plugin, not before. The plain APK proven above does not
exercise that path.
