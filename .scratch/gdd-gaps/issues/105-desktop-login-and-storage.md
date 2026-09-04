# 105 — Desktop login, and the storage that would have to exist under it

Status: parked (user, 2026-09-03) — recorded so the idea is not lost, not queued

## Parent

`.scratch/gdd-gaps/issues/86-play-games-backend.md` — split out of its Q8 during grilling

## Where this came from

While wiring the Play Games sign-in button, the question was whether `menu.gd`'s two provider
buttons should be filtered per platform. The user asked the better question instead: could the
buttons open a **web login** on desktop, so desktop players sign in too?

Parked rather than answered, because it is not a button change.

## Why it is not a button change

**There is no desktop build.** `export_presets.cfg` contains exactly one preset — `Android` —
and `project.godot` is 480x800 with `window/handheld/orientation=1`. Desktop is the development
loop, not a shipping target. A login for a platform with no export is a login for nobody.

**And an authenticated desktop player would have nowhere to sync.** Play Games Saved Games is an
Android SDK; it has no desktop API. Storage would mean Google Drive REST plus our own OAuth
flow, token storage and refresh — which is the *"money to spend, architecture to build, GDPR
compliance and a slew of other work"* the user ruled out for issue 104. Signing in successfully
and then having nothing to save to is worse than no button at all.

So this is three things, not one:

1. a desktop export preset (and a UI that works at a non-portrait aspect),
2. an OAuth flow with token persistence,
3. a **third** cloud backend behind the existing `is_available/push/pull/account_id` seam.

Only (3) is cheap, and only because the seam already exists.

## If it is ever picked up

Grill it as its own design session — the storage decision is the load-bearing one and it is not
obvious. The seam is genuinely ready for a third backend, which is the good news; the ADR that
governs it is `docs/adr/0003-synchronous-cloud-contract-over-async-sdk.md`.

Do not start it before 86 is device-verified. There is no dependency running the other way, and
86 is the one with a real store deadline behind it.

## What was decided in the meantime

`menu.gd` keeps rendering both provider buttons on every platform, unchanged. Pressing one on a
platform that cannot serve it falls through to the existing *"isn't available on this device
yet"* message, which is honest. Filtering them per platform was offered and declined as scope.
