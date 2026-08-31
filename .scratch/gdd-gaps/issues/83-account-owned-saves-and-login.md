# 83 — Account-owned saves, the login screen, and Guest

Status: todo

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
