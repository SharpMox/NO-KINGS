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

## Decision: platform-siloed saves, no backend (2026-08-28)

Taken so the slice can proceed as an implementation rather than an open question.

**Ship Game Center + iCloud on iOS and Play Games Saved Games on Android. No backend.**

Reasoning, against the page's own framing:

- The hard requirement — *"the game must be fully playable offline"* — is already met and
  stays met.
- The stated motivation was "no manual account". Platform sign-in delivers exactly that;
  it is only *cross-platform* progress that needs a backend, and nobody has asked for it.
- A BaaS adds an operated dependency, and the page already flags the Godot 4 plugin story
  (GodotFirebase) as unverified on native iOS/Android exports. That is a real integration
  risk for a benefit nobody has requested.
- It can be revisited: moving siloed saves into a backend later is a migration, not a
  rewrite. Choosing a backend now and finding the plugin broken is the expensive mistake.

**Consequence:** the leaderboard stays local (divergence #9 stands). A shared leaderboard
needs the same backend, so it is deferred with it.

The remaining work is real but bounded: wire the two platform save APIs, decide the
conflict rule (last-write-wins is fine for a single-player roguelike), and keep the local
save as the source of truth with the cloud as a mirror.


## Blocked by

- 05 — Settings surface (where an account row would live)
