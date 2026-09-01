# 99 — A piece carries at most 2 Piece Buffs, full stop

Status: **blocked on a ruling** (planned 2026-09-01) — this deletes two shipped effects

## Parent

`.scratch/gdd-gaps/PRD.md`

## The cap is already 2

`tuning.gd:17` — `PIECE_BUFF_CAP_BASE := 2`, a user ruling from issue 53. `_apply_buff`
already refuses past the cap and floats "Buffs full", and slice 81 shipped a board proving it
refuses *visibly* rather than dropping silently.

So the base rule is exactly what was asked for. **Two shipped effects raise it:**

| Effect | What it does | Source |
| --- | --- | --- |
| **Abduction Probe** (Artefact) | +1 to the cap, **per held copy**, additive | issue 53 ruling |
| **Communion** (The Cult's Army Power) | +1 to the cap (cap 3) | issue 68 |

`BuffLogic.cap(probes)` is `PIECE_BUFF_CAP_BASE + probes`, and `game.gd`'s `_apply_buff` sums
Communion on top — issue 68 ruled explicitly that "Communion + Abduction Probe = cap 4".

## The conflict

A hard cap of 2 **removes Abduction Probe's entire effect** (it becomes a no-op Artefact) and
**guts The Cult's Power** (Communion becomes nothing — and it is that Army's whole identity).

That runs straight into a standing user ruling in FLAGS:

> **Big interactions stay. At worst cap them, never remove them.** — user, 2026-08-30
> The corollary: do not propose removing an Artefact because it combos well. Propose the bound.

By that principle the answer is not a hard 2 but a **ceiling**: let the effects raise the cap,
but stop the stack somewhere. Cap-of-the-cap at **3** keeps both effects meaningful (each can
be the one that gets you there) while killing the 4-buff stack that prompted this.

## The options

1. **Hard 2** — as asked. Abduction Probe needs a new effect or removal (it has a Notion row
   and a public artefacts.html entry); The Cult needs a new Power. Largest blast radius.
2. **Ceiling at 3** — `min(BASE + probes + communion, 3)`. One `min()`. Both effects keep
   working, the 4-stack dies. Matches the standing ruling.
3. **Leave it** — the 4-buff stack requires The Cult *and* two Abduction Probes, which is a
   deliberate, expensive build.

**Recommendation: 2.** It is one line, it honours "cap them, never remove them", and it does
not orphan a catalog entry that the public site also renders.

## Acceptance (once ruled)

- The cap is enforced at one choke point (`_apply_buff`), not at each call site.
- A scenario board showing the cap refusing at the new limit, visibly.
- If option 1: Abduction Probe and Communion are re-texted in Notion, `data/artefacts.js` and
  `armies.gd`, and the drift checker run.
- `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

The ruling above. Nothing should be coded until it lands — option 1 and option 2 touch
different files entirely.
