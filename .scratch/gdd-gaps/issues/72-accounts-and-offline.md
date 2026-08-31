# 72 — Login: Google, Apple, Guest — and offline

Status: SPLIT (2026-08-31) — see 83 / 84 / 85 / 86 / 87; this file is now the parent spec

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

## Answered 2026-08-31

**1. A guest keeps their progress when they sign in. Yes.**

The consequence, and the reason this had to be answered before any code: **saves are keyed by
account from day one**, with a local pseudo-account that gets *rebound* on sign-in rather than
copied. Retrofitting this later would mean migrating every existing save — and the migration
table now has exactly one entry (issue 69), so it is proven but not free.

Concretely: the save carries an owner id. Guest runs are owned by a stable local id. Signing
in rewrites that id to the real account and pushes; it never merges two histories, because
until sign-in there is only one.

**2. Offline while signed in: play normally, queue for sync.** Conflict rule when the same
account has played on two devices: **highest wave reached wins.** That works precisely because
progress here is monotonic — Score and deepest-wave only ever increase, so "highest wins" is
well-defined and needs no timestamps or three-way merge.

**3. Leaderboards go cloud, with the same merge rule.** The local board (`Economy.record_score`)
stays as the offline view.

Worth noting the pairing: **the seed system (issue 75) is what makes a cloud leaderboard
meaningful.** Same seed, same board, genuinely comparable runs — otherwise a leaderboard is
just comparing luck. If seeded leaderboards are ever wanted, the seed and the build version are
both already displayed on the results screen for exactly this reason.

## Acceptance

- Split into at least: (a) the login screen + guest, (b) each platform backend, (c) offline
  sync. Ship (a) first; it is testable and unblocks the rest.
- Probes must still reach the game — a login screen in front of the menu will break every
  windowed probe unless it can be bypassed by a settings flag.

## Blocked by

- the offline/guest-upgrade questions above
