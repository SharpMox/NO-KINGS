# 55 — Meta-dispatch and capture conversion (the last 3)

Status: todo — SPECCED (engineering calls, no user input needed)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

The final three unimplemented Artefacts. None needed a *design* ruling — they are
engineering decisions about how `run()` dispatches, which is why they were not put to the
user. Decided here so they are on record rather than invented at implementation time.

With this slice the catalog reaches **180 / 180**.

---

## 1. Zeta Reticuli Souvenir Map — Rare

> Every 3rd Capture: the captured piece is added to your Stock instead of your Captured Stock

Issue 33's decision #4 asked whether a converted piece keeps its buffs and where it lands.
**ADR-0002 already answers it**: a Stock entry is a bare id String *or* a Dictionary carrying
the piece's opaque state, and Stock never interprets that state. So the captured piece
carries whatever it had into Stock for free, with no schema work.

**Decision:** the piece goes to `stock` with its state intact, exactly as Extraction already
does when pulling a piece off the board. Counting is every 3rd capture of the run —
`wave_capture_index`/`turn_capture_index` exist in `on_capture`'s ctx, but this wants a
run-long counter, so add one rather than misusing a per-wave index.

---

## 2. Troll Farm Employee of the Month — Legendary

> Your "Wave" Artefacts also trigger on Wave start

**Decision:** on `on_wave_spawn`, re-dispatch every held Artefact that listens on
`on_wave_clear`.

The echo layer (`_run_meta_triggers`, issue 21) is the precedent and the place for it — it
already re-dispatches other Artefacts' handlers, and it already carries the two protections
this needs:

- **`g.artefact_echo_depth`**, the re-entrancy guard, so an echo cannot echo itself.
- Passing each copy's **own `acquired_wave`** through, so a re-triggered 5-Wave Milestone
  Artefact fires on its own beat instead of defaulting to wave 1 — the exact bug issue 28
  fixed.

Do not route this through `run()`; go straight to `_dispatch`, as the rest of that layer
does. Note that `on_wave_clear`'s ctx carries snapshotted counters (`clean`, `turns`,
`captures`, `gold_spent`, `gold_base`) that are meaningless at Wave *start* — decide what
each should be and document it, rather than passing a stale snapshot.

---

## 3. Ecdysis Sheddings — Legendary

> Copies the effect of the last other Artefact you bought

**Decision:** it acts as a second copy of that Artefact — every hook the copied key listens
on, this dispatches too. Since stacking is additive per held copy, "a second copy" is
already a well-defined thing in this codebase and needs no new concept.

- **"Last other Artefact you **bought**"** — purchases only, via `on_purchase` with
  `kind == "artefact"`. Box grants and effect grants do not set it. "Other" excludes
  Ecdysis itself.
- Record the copied key in run state at purchase time and carry it in the save.
- Before anything is bought, it copies nothing and is inert. That is correct, not a bug.
- **Do not copy another Ecdysis** — guard it, or two copies chase each other.
- Respect `artefact_echo_depth`, as above.

Also decide what happens when the copied Artefact is itself consumable (Moscovium Glow
Stick, issue 52) and gets consumed: the recorded key should almost certainly persist, since
you bought it, but say so explicitly.

## Acceptance

- All 3 `implemented: true` in `data/artefacts.js`, exported via
  `node tools/export-game-artefacts.mjs` — **this should take the catalog to 180 / 180**.
- Zeta: assert the 3rd capture lands in Stock with state intact, and the 1st/2nd do not.
- Troll Farm: assert a Wave Artefact pays twice across a Wave boundary, and that a 5-Wave
  Milestone Artefact re-triggered this way uses its own `acquired_wave`.
- Ecdysis: assert it doubles the last *bought* Artefact, that a Box-granted one does not set
  it, and that two Ecdysis copies do not chase each other.
- All three: assert the echo-depth guard holds — no infinite dispatch.
- Tests in the split suites, seeds pinned. `run_all.sh` ALL GREEN, foreground.

## Blocked by

- issue 52 (only for Ecdysis's consumable-copy case; the rest is independent)
