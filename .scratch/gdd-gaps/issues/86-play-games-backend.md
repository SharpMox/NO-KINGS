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

## The Gradle path is PROVEN, and the plugin is chosen (2026-09-02)

### Gradle builds work — the second half of the environmental blocker is cleared

The note above said the Play Games plugin needs `gradle_build/use_gradle_build=true` and that
"the plain APK proven above does not exercise that path". It does now:

```sh
godot --headless --path game --install-android-build-template \
      --export-debug "Android" build/nokings-gradle.apk
```

produces a valid **77.8 MB / 474-file APK** (the non-Gradle one is 28.4 MB) with the Kotlin
runtime inside it — a real Gradle build, not the prebuilt template.

**The flag is deliberately left at `false`.** This file's own earlier note is right: it flips
*as part of wiring the plugin, not before*. Turning it on now would add a hard prerequisite
(the 1 GB `game/android/` template) to every export for zero present benefit. What has changed
is that the flip is now known-good rather than hypothetical.

`game/android/` is **gitignored** — it is ~1 GB of regenerated SDK scaffolding, and the
regeneration command is recorded in `.gitignore` beside the rule.

### A store requirement this slice had not recorded

`gradle_build/export_format=0` is **APK**. Google Play requires an **AAB** (`=1`) for new
applications, so the store build needs that flag as well as a release keystore. Neither is
needed for device testing, which is what unblocks the rest of this slice.

### The plugin: `godot-sdk-integrations/godot-play-game-services`

MIT, Godot 4.3+, and it lives in the **Godot Foundation's GitHub organisation** (moved there
October 2024) — community-built rather than engine-official, but under the Foundation's
umbrella, which is as close to endorsed as an Android plugin gets.

It covers **exactly the three things this slice needs and nothing more**: sign-in,
leaderboards, and **Snapshots** (cloud saves). Play Games SDK v21.0.0, Android API 35,
node-based rather than autoload-based, and it **requires the custom Gradle build** — the path
proven above.

Mapping onto the existing seam is genuinely drop-in: `cloud_backend_play_games.gd` already
declares `is_available()` / `push()` / `pull()` / `account_id()`, and Snapshots is a
named-blob store, which is the same shape as `push(key, envelope)`.

### What is STILL blocked, unchanged

Sign-in needs an OAuth client tied to the package name **and the signing certificate
fingerprint**, both issued by the Play Console. No amount of local work produces those. Still
required from the user:

1. A Play Console entry for `com.sharpmox.nokings` (one-time $25 developer account).
2. Leaderboard IDs created there.
3. An Android device with USB debugging.

**The SDK calls are deliberately not written yet.** Writing them blind against a plugin that
is not installed would be guessing an API surface — the exact thing this repo's conventions
forbid ("ambiguity goes back as a question, not into code as a guess"), and it could not be
compiled, let alone verified.
