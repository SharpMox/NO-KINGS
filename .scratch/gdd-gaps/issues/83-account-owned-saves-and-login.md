# 83 — Account-owned saves, the login screen, and Guest

Status: done (2026-08-31, PR #271)

## Parent

`.scratch/gdd-gaps/issues/72-accounts-and-offline.md` (split (a))

## Scope

The first and load-bearing slice of 72. Everything else in that issue sits on top of it.

### 1. Saves carry an owner id — from day one

The user's ruling (2026-08-31) is that **a guest keeps their progress when they sign in**. The
consequence is structural, not cosmetic: saves are keyed by account *now*, with a stable local
pseudo-account that gets **rebound** on sign-in rather than copied.

- Guest runs are owned by a stable local id, generated once and persisted.
- Signing in **rewrites** that id to the real account and pushes.
- It never merges two histories, because until sign-in there is only one.

**This is why it goes first.** Retrofitting an owner id later means migrating every existing
save, and the migration table has exactly one entry today (issue 69) — proven, but not free.
`save_config.gd`'s header is explicit about which changes are additive and which are silent
corruption: an owner id read with a default is additive and safe; **reshaping the save around
it later would not be.**

### 2. The login screen — Google, Apple, Guest

New first-run flow, in front of the menu. UI only; the two platform buttons call into the
existing stubs in `game/scripts/cloud/` and are expected to no-op on desktop.

### 3. Guest with local persistence

Closest to done — the local save already works. This slice binds it to the local owner id.

## The thing that will break everything if missed

**A login screen in front of the menu breaks every windowed click probe**, which drives real
input at real coordinates and expects the menu first. 72's own acceptance calls this out.

It needs a bypass — a settings flag or a CLI arg the probes pass — and the bypass must be
exercised by the probes themselves, not assumed. This repo has already had CLI bypasses
green-light a fully dead main menu (CLAUDE.md, "UI first, bypasses second"), so the probe must
go **through** the login screen at least once as well as around it.

## Acceptance

- A fresh install shows the login screen; Guest reaches the menu and plays.
- The save carries an owner id; a guest save survives sign-in **rebinding**, with the run
  history intact — assert the rebind, not just the field.
- `save_config.gd` handles the added field per its own additive rule, with a migration only if
  the shape actually changed.
- Menu click probes pass both **through** the login screen and via the bypass.
- `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

- nothing

## Outcome (2026-08-31) — shipped in PR #271

**Saves carry an owner id; the login screen is first-run only; a guest's progress survives
sign-in by rebinding.**

`scripts/account.gd` owns `user://account.json`, deliberately **separate from the save files**:
it survives a deleted run, and a save being rebound must not also be the thing recording who it
is bound to.

- **Guest is a real account, not the absence of one.** It owns saves exactly as a signed-in
  account does — which is what makes sign-in a *rebind* rather than a merge. There is only ever
  one history, so nothing is ever merged.
- `SaveConfig.capture()` routes through `Account.stamp()`. **Additive, so no migration**: a
  pre-account save has no `owner`, reads back as `""`, and loads. `save_config.gd`'s header is
  explicit that an additive field is safe forever while a reshaped one is silent corruption —
  which is exactly why this slice had to come first.
- **Google/Apple say when they are unavailable.** The backends are stubs until 86/87, so
  `is_available()` is false on desktop; the screen states that rather than appearing to sign in
  and doing nothing. `account_id()` joined the backend contract.

### The probe drives the login screen, it does not skip it

`--skip-login` exists, and the probes deliberately **do not use it** — a bypass that is the
only tested path is how this repo once green-lit a fully dead main menu. The probe deletes the
account, asserts the login screen renders **in front of** the main menu, clicks an unavailable
provider and asserts it says so *and creates no account*, then goes through Guest.

`--screenshot` **does** bypass the gate: a capture run on a machine with no account would
otherwise photograph the login screen instead of the menu, which is a silent trap on any fresh
checkout rather than a real result.

18 assertions in `test_account.gd`, the load-bearing one being that a guest's score and wave
survive the rebind **intact**, plus 9 in the click probe.

**This slice also fixed issue 74 shipping as a no-op** — see 74's CORRECTION section.

`run_all.sh` **156.0s ALL GREEN**, foreground, alone.
