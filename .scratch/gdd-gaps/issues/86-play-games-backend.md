# 86 — Google Play Games backend (Android)

Status: todo — **cannot be verified in this environment, see below**

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
