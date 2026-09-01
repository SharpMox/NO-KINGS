# 92 — The Laurel tier: four Powers, four Abilities

Status: done (2026-09-01)

## Parent

`.scratch/gdd-gaps/KINGS-DESIGN-WORKSHEET.md` (ruling 8 — bespoke kits)

## The four kits

| King | Power | Ability |
| --- | --- | --- |
| **Nebuchadnezzar II** | **The Babylonian Exile** — pieces you capture this wave are deported; they never reach your Captured Stock | **The Dream of the Statue** — your highest-value board piece crumbles to its base form |
| **Xerxes I** | **The Countless Host** — the enemy takes one extra Action every turn | **Whip the Hellespont** — drives every piece you have on the board back one row |
| **Qin Shi Huang** | **The Great Wall** — deploying from Stock costs double | **The Terracotta Army** — three more of the wave's own pieces march in at once |
| **Nero** | **Rome Burns** — your Gold gains are halved | **The Fire of Rome** — every Item you hold burns |

Each hits a **different resource**, on purpose: Nebuchadnezzar the capture economy, Xerxes the
Action economy, Qin Shi Huang Gold-per-deploy, Nero Gold-per-gain and the Item stock. A run
meets four Kings of one tier (issue 89), so four Kings all taxing Gold would read as one long
King rather than four.

## Powers dispatch through the SAME contract as everything else

`Kings.power_hook()` is called from `ArtefactHooks.run()`, alongside Artefacts and Tariffs, on
every hook — so a Power participates in the established ordering instead of being applied
before or after the rest and drifting from it. It obeys the same ctx contract: return through
`ctx`, compute off the immutable base, never write `g.score`/`g.gold` mid-dispatch.

Kings are **not** in `REGISTRY`: only one Power is ever live, so there is nothing to key-sort
for order independence.

**The Babylonian Exile is the exception, deliberately.** "This capture produces no Captured
entry" is a *branch*, not a modified value, so it is read at the four `captured.append` sites
rather than dispatched. Forcing it through ctx would have meant inventing a suppression flag
that only one effect ever sets.

## Three design constraints applied while building

- **The Great Wall doubles deploy cost rather than blocking deploys.** Blocking them outright
  can strand a player into the resource-starvation game over — a softlock dressed as
  difficulty. Same reasoning that shaped issue 60's sell guard.
- **The Dream of the Statue demotes rather than destroys.** It takes the *investment*, which is
  a different loss from JD Vance destroying a piece outright — and keeps the two Suit/Laurel
  Abilities from being the same effect with different flavour text.
- **Whip the Hellespont costs position, never material.** Nobody can be starved out by it.
- **The Fire of Rome burns Items but not Artefacts.** Artefacts are the run's identity; taking
  those is a different order of loss and belongs to a heavier tier if anywhere.

## The compile cycle this hit

Dispatching Powers from `artefact_hooks.gd` meant preloading `kings.gd` there — which closed
the cycle **artefact_hooks -> kings -> economy -> artefact_hooks** and failed to compile.
`kings.gd` now loads Economy lazily; only the two Tariff-backed Trump effects need it, so the
cost is one `load()` on a path that runs once per wave.

## Verification

`test_kings.gd`, 22 new assertions — each effect asserted by its **observable consequence**,
not by its flag:

- The Countless Host adds to the tier's own enemy-action count rather than replacing it (1 -> 2),
  the property issue 59 required of Filibuster, and stops when the Power ends.
- Rome Burns halves Gold **and respects `gain_immune`** exactly as Inflation does — without
  that, Panama Papers Shredder and Amber Room Bubble Wrap would silently stop working against
  Kings while still working against Tariffs.
- The Great Wall doubles a real `on_place_cost` dispatch (30 -> 60).
- The Dream of the Statue leaves the piece **count unchanged** while changing its id
  (`archbishop` -> `bishop`), proving demote-not-destroy.
- Whip the Hellespont leaves material unchanged.
- The Terracotta Army queues exactly 3 and **never duplicates the King**.
- The Fire of Rome empties Items and **leaves Artefacts untouched**.

`run_all.sh` **166.0s ALL GREEN**, foreground, alone.

## Remaining

Hat, Uniform and the rest of Suit — 11 Kings, 22 effects. The engine no-ops on them, so they
can land tier by tier with no further infrastructure.
