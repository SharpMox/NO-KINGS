# 53 — Two base-game caps, and four resolved ambiguities

Status: todo — SPECCED (user rulings 2026-08-29)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

Six Artefacts, each blocked on a one-line question rather than on machinery. The user
answered all six on 2026-08-29. **Two of them introduce base-game restrictions that do not
exist today** — those are the risky half of this slice and are listed first.

---

## The two new base-game caps

### Item held capacity — base 3

There is **no Item cap today**; the player can hold unlimited Items. Introduce one, base
**3** (user ruling).

- **Area 51 Parking Permit** (Common) — *"+3 Item held capacity"* — takes it to 6.
- **Denver Bunker Timeshare** (Uncommon) — *"While all your Item slots are full: +30% Gold
  gain"* — now has a reachable condition.

Decide and document what happens when a full inventory would gain another Item (Box pick,
Artefact grant, Shop purchase): refuse the acquisition, or force a discard? Refusing is
simpler and matches "capacity"; whichever you pick, the Shop must not let you *buy* an Item
you cannot hold.

### Piece Buff capacity — base 2

There is **no buff cap today**; `buff_logic.gd` appends freely. Introduce one, base **2**.

- **Abduction Probe** (Rare) takes it to **3**.

**Re-text Abduction Probe.** Its catalog line — *"Your pieces can carry 2 Piece Buffs at
once"* — was written assuming a base of 1. Under the user's ruling the base *is* 2, so the
text must become **"+1 Piece Buff capacity"** (2 → 3) or it describes the base game and does
nothing.

This is the one change here that **nerfs the existing game**: Buff Box, Holy Lint, Pied
Piper's Rat Census and every random grant can currently stack without limit. Applying a
3rd buff must fail cleanly and visibly — not silently no-op, and not crash. Check every
grant path, not just the Buff Box.

---

## The four resolved ambiguities

All four rulings are the user's; each was previously parked in `NOTION-QUESTIONS.md`.

### Spare Organ Receipt — Common

> On Fuse: refund 50% of the consumed piece's value as Gold

A Fuse consumes **two** pieces. Ruling: **50% of both combined**.

`merge_logic.gd`'s `commit_merge` has both ids in scope and `g.defs[id].value` gives each
value, so this needs a small hook at that point — the only new call site in this slice.

### 'Definitely Not Russia' Patch — Rare

> The first piece you lose each Wave doesn't count as a loss for your Artefacts and penalties

Ruling: it masks the loss from **everything** — one flag, no carve-outs. Every effect
reading `on_piece_lost` (Nibiru Hide-and-Seek Trophy's streak collapse, Frog Pride Flag's
arming, `lost_player`, `wave_lost_ids`) sees no loss.

**The piece is still lost** — this is *not* Fireproof Pajamas' `ctx.cancel`, which saves the
piece. It needs a second, distinct flag meaning "lost, but uncounted". Do not overload
`cancel`.

### Alien Pet Rocks — Common

> At Wave end: +2 Gold per allied piece that did not move this Wave

Ruling: **only moves you spent an Action on count as moving.** A piece that was Deployed
this Wave, or shoved by an effect (Royal Fiat's forced retreat, Tactical Reposition, Decoy
Swap, Rapid Deployment), still counts as "did not move" and still pays.

Needs a per-Wave "moved under its own steam" set, cleared on Wave clear.

## Acceptance

- All 6 `implemented: true` in `data/artefacts.js`; **Abduction Probe re-texted**; exported
  via `node tools/export-game-artefacts.mjs`.
- Item cap 3 enforced on every acquisition path, and unbuyable Items are not purchasable.
- Buff cap 2 enforced on every grant path — Buff Box, random grants, artefact grants — and
  a refused 3rd buff fails cleanly and visibly.
- Assert the caps **bind**: a 4th Item and a 3rd buff are actually refused, and the
  Artefacts genuinely raise them.
- Alien Pet Rocks: assert a deployed piece and a force-moved piece both still pay.
- 'Definitely Not Russia' Patch: assert the piece is gone **and** that a loss-reading effect
  (Nibiru's streak) did not react.
- Tests in the split suites, seeds pinned. `run_all.sh` ALL GREEN, foreground.

## Blocked by

- nothing
