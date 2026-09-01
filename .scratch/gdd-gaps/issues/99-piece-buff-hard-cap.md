# 99 — A piece carries at most 2 Piece Buffs, full stop

Status: todo — **RULED 2026-09-01: hard 2.** The cap is 2 and nothing raises it.

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

## THE RULING (user, 2026-09-01): hard 2

The cap is **2, and nothing raises it**. The two augmenting effects lose their current
purpose and both need replacing — that is the bulk of this slice, not the `min()`.

### Exactly two effects augment the cap — the complete list

Verified: `BuffLogic.cap()` has **one** call site, `game.gd:2468-2469`:

```gdscript
var buff_cap := BuffLogic.cap(_artefact_count("abduction-probe")
        + (1 if Armies.communion(self) else 0)) # issue 68: Communion
```

| Effect | Kind | Current effect | Becomes |
| --- | --- | --- | --- |
| **Abduction Probe** | Artefact | +1 cap **per held copy**, additive | a dead Artefact |
| **Communion** | The Cult's Army **Power** | +1 cap (to 3) | a dead Army Power |

Nothing else touches it. `PIECE_BUFF_CAP_BASE` is read only by `BuffLogic.cap()`.

### What the ruling costs

- **Abduction Probe becomes a no-op Artefact.** It has a Notion row and renders on the public
  `artefacts.html`, so it needs a **replacement effect**, not deletion — an Artefact that
  exists in the catalog and does nothing is worse than one that was never added.
- **The Cult loses its Power entirely.** Communion is that Army's identity — it is the buff
  Army, and its Ability (Ritual, grant a random Buff) is built around having room to hold
  buffs. A replacement Power has to keep The Cult *about* buffs without raising the cap.
  Candidate directions, none ruled: better buffs rather than more (upgrade a granted Buff's
  tier), buffs that persist through capture, or a free re-roll of a Buff already on a piece.

This is why the slice is blocked on **design**, not on code: `min(..., 2)` is one line, and
the two replacement effects are the actual work.

## Acceptance

- The cap is 2 at the single choke point (`_apply_buff`), and no effect can raise it.
- Abduction Probe has a **new effect**, implemented and re-texted in `data/artefacts.js` +
  Notion; `tools/check-notion-drift.mjs` run and clean for that row.
- The Cult has a **new Power**, implemented and re-texted in `armies.gd` + Notion.
- A scenario board showing the cap refusing at 2, visibly (81's precedent: a grant arriving
  at a full cap must *float a refusal*, not silently drop).
- The existing issue-68 assertion that "Communion + Abduction Probe = cap 4" is **removed**,
  not edited to a new number — the behaviour it pins is gone.
- `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

Two design decisions: **what Abduction Probe does now**, and **what The Cult's Power is now**.
Both are the user's to make. The `min()` is trivial and should not ship before them, or the
game briefly contains two effects that do nothing.
