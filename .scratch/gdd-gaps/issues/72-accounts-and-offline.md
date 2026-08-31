# 72 — Login: Google, Apple, Guest — and offline

Status: todo — NEEDS DECISIONS (large; likely splits)

## Parent

`.scratch/gdd-gaps/PRD.md`

## What already exists

Slice 12 built the local half and **stubbed the platform backends**. Present today in
`game/scripts/cloud/`:

- `cloud_backend_play_games.gd` (Google Play Games) — stub
- `cloud_backend_game_center.gd` (Apple Game Center) — stub
- `cloud_backend_memory.gd`, `cloud_backend_noop.gd` — test/fallback

So the **seam exists**; this slice fills the stubs and puts a screen in front of them. That
is a much smaller job than it sounds, and the backend choice is already abstracted.

## The scope, and why it is not one slice

1. **The login screen** — Google, Apple, Guest. UI work; new first-run flow.
2. **Real Play Games / Game Center integration** — needs the actual SDKs, which in Godot
   means either official plugins or a custom Android/iOS build. **This cannot be tested by
   the existing suite** (headless Godot has no Play Games), so it needs device testing.
3. **Guest with local persistence** — closest to done; the local save already works.
4. **Offline** — the interesting design work, see below.

## Offline is the part that needs thought, not code

The questions that decide the shape:

- **Can a guest upgrade to a real account later, keeping their data?** (Almost always yes —
  and it decides whether local saves are keyed by account from day one.)
- **What happens when a signed-in player is offline?** Play normally and sync later, is the
  usual answer — which means a **queue of unsynced runs**, and a conflict rule for when the
  same account played on two devices.
- **Does the leaderboard work offline?** `Economy.record_score` writes a local leaderboard
  today; a cloud one needs a merge rule.

**Do not build until these are answered** — an auth flow built on the wrong assumption about
guest upgrades is expensive to unpick, because it reaches into how every save is keyed.

## Acceptance

- Split into at least: (a) the login screen + guest, (b) each platform backend, (c) offline
  sync. Ship (a) first; it is testable and unblocks the rest.
- Probes must still reach the game — a login screen in front of the menu will break every
  windowed probe unless it can be bypassed by a settings flag.

## Blocked by

- the offline/guest-upgrade questions above
