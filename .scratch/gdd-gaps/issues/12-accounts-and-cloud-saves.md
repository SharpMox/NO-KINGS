# 12 — Accounts & cloud saves (spike first)

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

**This is a spike, not an implementation slice.** The
[Accounts & Save Data](https://app.notion.com/p/383f1559c99b818e805de4d60ab1c5e6) page is
an investigation, not a spec, and it turns on a product decision nobody has made:

- **Cross-platform unified account** → needs a backend (Firebase / Supabase / PlayFab /
  Nakama).
- **Platform-siloed saves** → no backend at all; Game Center + iCloud on iOS, Play Games
  Saved Games on Android.

Pure Sign in with Apple / Google Sign-In only prove identity — they store no save data, so
the "no manual account" goal alone does not settle it.

Today saves are local-only (`user://`) and the leaderboard is local top-10 (divergence #9).
Offline play — the page's one hard requirement — already works.

Deliver the decision and a verified plan, not code:

1. Pick siloed vs unified.
2. If unified, shortlist the BaaS and **verify the Godot 4 plugin actually works on native
   iOS + Android exports** — the page already flags GodotFirebase compatibility as unproven.
3. Sketch the save-data model and the conflict-resolution rule (the page's open question:
   what happens when one save is played on two offline devices before either reconnects).
4. Only then split the build into its own slices.

Note this also decides divergence #9 — a shared leaderboard needs the same backend.

## Acceptance criteria

- [ ] Siloed vs unified decided and recorded
- [ ] If unified: plugin verified on a real device export, not just claimed
- [ ] Save-data model and conflict rule sketched
- [ ] Follow-up implementation slices written
- [ ] Leaderboard (divergence #9) decided alongside it

## Blocked by

- 05 — Settings surface (where an account row would live)
