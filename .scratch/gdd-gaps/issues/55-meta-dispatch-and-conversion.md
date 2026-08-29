# 55 — Meta-dispatch and capture conversion (the last 3)

Status: done

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

## Outcome

Shipped in PR feat/meta-dispatch-and-conversion-55 — all 3. Catalog 169 -> 172 implemented
in this branch (this file also carries 7 other still-`implemented: false` entries belonging
to other, independently in-flight issues — this slice's own scope was exactly these 3).

- **Zeta Reticuli Souvenir Map** — a new run-long `g.run_capture_count` (game.gd), never
  reset, feeds `on_capture`'s ctx as `run_capture_index` (economy.gd's `capture_score`,
  same 0-based idiom as its wave/turn siblings). The handler sets an OUTPUT flag,
  `ctx.to_stock`, on every 3rd capture of the run; game.gd's four capture-resolution sites
  (plain, Bomb, Trap, Multicapture's 2nd victim) read it back off `g.last_capture_ctx` the
  same way `return_to_start`/`move_to_backrow` already are, and divert into `stock` via a
  new `_capture_to_stock()` helper mirroring Extraction's own "duplicate, strip owner, bare
  id if that's all that's left" (ADR-0002) — no new schema. `run_capture_count` is NOT
  persisted across saves, matching the sibling per-artefact run-long counters that already
  aren't (`nibiru_wave_streak`, `club27_streak`, `lottery_purchase_count`,
  `pallet_purchase_count`) — an accepted existing gap, not a new one.
- **Troll Farm Employee of the Month** — no REGISTRY entry, lives entirely in
  `_run_meta_triggers` (same shape as Max Headroom Mask/Polybius/etc.): on
  `on_wave_spawn`, walks `held` for every key registered on `on_wave_clear` and
  `_dispatch`es it there directly (never through `run()`), passing each entry's own
  `acquired_wave` (issue 28's fix). **Wave-start ctx decision**: `on_wave_clear`'s usual
  `{clean, turns, captures, gold_spent, gold_base}` is a snapshot of the wave that just
  ended, meaningless at Wave start — built fresh instead: `clean = true` (no losses yet
  this brand-new wave, vacuously and correctly true), `turns = 0`, `captures = 0`,
  `gold_spent = 0` (all genuinely zero — `WaveLogic.queue()` already reset the underlying
  counters before firing `on_wave_spawn`), `gold_base = g.gold` (the one field that's just
  "current Gold", read live so a percentage handler stays correct). A handler that reads
  `g.wave` directly instead of ctx (John Titor's Crypto Wallet, Silk Road Coupon) sees the
  already-bumped NEW wave at this point, so its milestone cadence ends up keyed to the
  STARTING wave rather than the wave that just cleared — a consequence of reusing the
  handler body unmodified, not a deliberate narrative choice.
- **Ecdysis Sheddings** — also no REGISTRY entry. `g.ecdysis_copy_key` (String, "" =
  inert) is set in `run()` itself, unconditional of what's held, whenever
  `hook == on_purchase`, `ctx.kind == "artefact"`, and the bought key isn't Ecdysis's own
  — box grants and effect grants never fire `on_purchase` (shop.gd's `buy()` is the only
  call site), so they can't set it, no extra guard needed. **Consumable-copy decision**:
  the key is never cleared when the copied Artefact is later consumed/removed
  (`_consume_artefact`) — it's a fact about the run ("you bought it"), decoupled from
  whether that key is still in `g.artefacts`, so a later-consumed copy (Moscovium Glow
  Stick, issue 52, not yet implemented) keeps being copied. Dispatch: for every held
  Ecdysis entry, if `REGISTRY[g.ecdysis_copy_key]` lists the hook currently firing,
  `_dispatch` the copied key at that hook using THIS Ecdysis entry's own `acquired_wave`
  (Ecdysis itself is "the second copy", so its own cadence applies, not the original's).
  Guarded twice against copying another Ecdysis: recording never sets the key to
  `"ecdysis-sheddings"`, and dispatch refuses that key outright regardless.
- **Echo-depth guard**: proved by direct assertion (`g.artefact_echo_depth == 0` after
  dispatch) in three cases — Ecdysis alone, and the Ecdysis + Troll Farm + a bought Wave
  Artefact combo named in this issue as the one most likely to loop. That combo resolves
  to exactly 3 bounded dispatches per Wave boundary (normal Wave-clear + Ecdysis's mirror
  of it + Troll Farm's Wave-start echo of the real copy) because neither Troll Farm nor
  Ecdysis has a REGISTRY entry and `_dispatch` never calls `run()` — Troll Farm's extra
  dispatch can't be seen or re-mirrored by Ecdysis's own block, which is scoped to
  whichever hook the *outer* `run()` call is dispatching.
- Tests in `test_items_artefacts_4.gd` (kept all 7 split suite files, no new ones); seeds
  pinned via `_boot`'s default seed. `game/tests/run_all.sh` ran foreground, alone: `ALL
  GREEN`.
