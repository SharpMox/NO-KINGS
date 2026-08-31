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
