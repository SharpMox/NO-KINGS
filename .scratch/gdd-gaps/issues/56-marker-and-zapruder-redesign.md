# 56 — SETI's Red Marker and Zapruder's, both redesigned

Status: todo — SPECCED (user redesigns + sub-answers 2026-08-30) · ready

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

Two cards whose original text could not be implemented faithfully. Rather than re-texting
them to match a weaker implementation, the user redesigned both.

---

## 1. SETI's Red Marker — Rare

**Was:** *"On acquiring this Artefact: one random active Tariff is inverted into its
equivalent bonus"* — unimplementable, because no Tariff has a defined inverse and two of
them (Sanctions, Regulation) have no coherent opposite at all. This was
`NOTION-QUESTIONS.md` question 10 and the last unimplemented Artefact in the catalog.

**Now (user, 2026-08-30):** *on acquiring it, **remove a Tariff and open an Artefact Box**.*

This dissolves the problem rather than working around it — nothing needs inverting, and both
halves are things the game already does. Removing a Tariff is well-defined, and Artefact
Boxes became real in slice 47's nine-Box rework.

**Settled:**
- Trigger stays **on acquisition**, one-shot, as the original.
- The Tariff removed is **random among active ones**, as the original.

**Decide and document — the one that matters:**

> **The Box must open whether or not a Tariff was removed.**

`TARIFFS_SCHEDULED` is `false`, so **no Tariff is ever active in a run today**. If the Box
only opens as a consequence of a removal, this Artefact is *still* dead on arrival — which
is the exact problem the redesign exists to fix. So: always open the Box; removing a Tariff
is the extra when one happens to be active.

**Box size: BIG** (user, 2026-08-30) — 5 choices, 1 pick.

---

## 2. Zapruder's Director's Cut — Legendary

**Was:** *"Once per Wave: you may repeat your previous Action without spending an Action."*
Slice 52 shipped this repeating **moves and captures only** — `_log_action` recorded just
`{kind}`, so Deploys, Merges and Item uses could not be replayed and were reported
unavailable. A card that silently does nothing after an Item use.

**Now (user, 2026-08-30):** for the actions a replay cannot express, it **gives the
resource back instead** — regain the last **Item**, or the last **piece into Stock** for a
Deploy or a Merge.

**Reading taken:** this **complements** the existing move/capture replay rather than
replacing it, so the card does something useful whatever you did last:

| Last Action | Zapruder's does |
| --- | --- |
| Move or capture | Repeats it, free (already shipped in slice 52) |
| Item use | Returns that Item to your inventory |
| Deploy | Returns the deployed piece to Stock |
| Merge | Returns a consumed piece to Stock — **see sub-question** |

The alternative reading — *replace* the replay entirely — would leave the card dead after a
move, which is the same defect in a new place. Not taken.

**A Merge returns BOTH consumed pieces, to Stock** (user, 2026-08-30). More generous than
the one-piece option that was on the table, and consistent with Spare Organ Receipt (issue
53), which refunds 50% of *both*.

Note the consequence, accepted: the player keeps the merged result **and** gets both inputs
back, so a Merge + Zapruder's is a net duplication of value. That is bounded by once per
Wave on a Legendary, which is what makes it acceptable — but it is the strongest single
line in this slice, so if anything here wants revisiting after a playtest, it is this.

**Watch out:**
- The Item return must respect the **Item cap of 3** (issue 53). If the inventory is full,
  decide and document: refuse the return, or let it exceed. *Recommendation: refuse*,
  consistent with every other acquisition path.
- The returned piece follows **ADR-0002** — it goes to Stock carrying whatever opaque state
  it had, the same shape Extraction uses.
- Still once per Wave, still costs no Action.
- **Re-text the card** to describe what it actually does now.

## Acceptance

- SETI's Red Marker `implemented: true` — **this takes the catalog to 180 / 180.**
- Assert the Box opens with **no Tariff active**, which is the live case today.
- Assert Zapruder's covers all four Action kinds, and that the Item return respects the cap.
- Both re-texted in `data/artefacts.js`, exported via `node tools/export-game-artefacts.mjs`.
- Tests in the split suites, seeds pinned. `run_all.sh` ALL GREEN, foreground.

## Blocked by

- nothing
