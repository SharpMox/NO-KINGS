# 99 — A piece carries at most 2 Piece Buffs

Status: **closed (2026-09-01) — no change needed. The game already does this.**

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why this closes without a commit

The ask was "only 2 Buffs can be applied at once on a piece". The base cap **is** 2 —
`tuning.gd:17`, `PIECE_BUFF_CAP_BASE := 2`, a user ruling from issue 53. `_apply_buff` already
refuses past it and floats "Buffs full", and slice 81 shipped a board proving the refusal is
*visible* rather than a silent drop.

Two effects raise it above 2:

| Effect | Kind | Effect on the cap |
| --- | --- | --- |
| **Abduction Probe** | Artefact | +1 **per held copy**, additive |
| **Communion** | The Cult's Army Power | +1 (to 3) |

Both were briefly ruled out on 2026-09-01 ("2 hard") and then **ruled back in the same day**:

> *"Keep the things with the effect that go over the cap, we don't mind too much actually."*

So the final rule is: **base cap 2, and effects may raise it.** That is exactly the shipped
behaviour — `BuffLogic.cap(probes) = PIECE_BUFF_CAP_BASE + probes`, summed with Communion at
`game.gd:2468`. Nothing to build.

This also lands back on the standing principle rather than against it:

> **Big interactions stay. At worst cap them, never remove them.** (FLAGS, user 2026-08-30)

## What was avoided

The hard-2 reading would have made **Abduction Probe a no-op Artefact** (it has a Notion row
and renders on the public `artefacts.html`, so it would have needed a replacement effect, not
deletion) and **deleted The Cult's Power outright** — Communion is that Army's identity, and
its Ability grants Buffs, so the Army would have needed rebuilding around nothing.

Closing here is the cheaper and more reversible outcome: the cap can still be revisited as a
**tuning number** in the balance pass without touching two catalogs and a public web page.

## If it is revisited

The middle option, never taken: a **ceiling** — `min(BASE + probes + communion, 3)` — which
keeps both effects meaningful while killing the 4-Buff stack (The Cult plus two Probes). One
line, no catalog churn. Recorded here so the option does not have to be rediscovered.
