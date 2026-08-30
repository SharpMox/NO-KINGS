# 56 — SETI's Red Marker and Zapruder's, both redesigned

Status: done (2026-08-30) — **catalog closed at 180 / 180**

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

## Outcome

Shipped in PR `feat/marker-and-zapruder-56`. Catalog closes at **180/180**.

- **SETI's Red Marker** is now an ordinary self-referential `on_purchase` REGISTRY handler
  (`artefact_hooks.gd`): `ctx.kind == "artefact" and ctx.key == "seti-s-red-marker"` fires
  because `Shop.buy()` appends the bought copy to `g.artefacts` before dispatching
  `on_purchase`. Both halves always run in the handler body — a random active Tariff is
  removed (`g.tariffs_active.remove_at(...)`) if the array isn't empty, and a Big Artefact
  Box (`Box.roll_options(g, "artefact", "big")`, 5 choices/1 pick) opens unconditionally via
  `g._open_box_pick(...)`, guarded by `not g.box_open` (mirrors Trojan Horse Assembly
  Manual/Loch Ness Stool Sample's own guard — two held SETI copies dispatching on the same
  purchase, the documented per-held-copy stacking rule, must not clobber one open Box pick
  with a second). Re-texted: "On acquiring this Artefact: remove a random active Tariff (if
  any), and open a Big Artefact Box." Tested in `test_items_tariffs.gd`: the no-Tariff-active
  case (the only one a live run hits, `TARIFFS_SCHEDULED` false) and the Tariff-removal case,
  driven directly via `Economy.activate_tariff_by_key` since it can't happen live.
- **Zapruder's Director's Cut** keeps its issue-52 move/capture replay untouched and adds a
  resource-return for the 3 kinds a replay can't express, via new `_zapruder_available()`/
  `_zapruder_resolve()` in `game.gd` (replacing the direct `_can_repeat_last_action()`/
  `_repeat_last_action()` calls in the activation dispatch table). `_log_action`'s "place"
  and "item" call sites now stamp `{pos}`/`{item}` the same way the plain move/capture site
  already stamped `{from, to}`; `merge_logic.gd`'s `commit_merge` snapshots both consumed
  pieces' ADR-0002 Stock-shaped state into a new `{pieces}` field on the "merge" log entry
  **before** its existing erase loop discards that state for real — the one ordering detail
  that would have silently broken the Merge case. Item use returns the Item via
  `ItemLogic.grant` (refuses at the issue-53 cap of 3, same "spent either way" precedent as
  every other full-inventory grant path — the once-per-Wave charge is still spent); Deploy
  un-deploys the piece back to Stock (same "duplicate, strip owner, bare id" shape as
  `_capture_to_stock`); Merge returns BOTH consumed pieces to Stock, on top of the merge
  result the player already kept (user ruling — an accepted, bounded duplication of value).
  Re-texted to describe all 4 branches. Tested in `test_items_artefacts_4.gd`: Deploy, Item
  (normal + full-inventory refusal), and Merge (both pieces returned, one with buff state
  intact) — the existing move/capture test is untouched.
- `data/artefacts.js` / `game/data/artefacts.json` (regenerated via
  `tools/export-game-artefacts.mjs`) and `.scratch/gdd-gaps/FLAGS.md`'s Zapruder
  overpromise flag are updated to match.

## Outcome

Shipped in PR #199. **The catalog is complete: 180 / 180 Artefacts implemented.**

Final card texts:

- **SETI's Red Marker** — *"On acquiring this Artefact: remove a random active Tariff (if
  any), and open a Big Artefact Box"*
- **Zapruder's Director's Cut** — *"Once per Wave, at no Action cost: repeat your previous
  move or capture; if your last Action was an Item, return it to your inventory; if it was a
  Deploy, return that piece to Stock; if it was a Merge, return both consumed pieces to
  Stock"*

**SETI opens its Box with no Tariff active** — asserted explicitly, because with
`TARIFFS_SCHEDULED` false that is the *only* case a live run reaches. A second test drives a
Tariff directly to cover the removal half. Multiple copies are guarded with `not g.box_open`
so they cannot clobber each other's Box.

**Zapruder's Item return is refused at a full inventory**, routing through
`ItemLogic.grant` like every other acquisition path, and the once-per-Wave charge is spent
either way — consistent with how every other full-inventory grant behaves.

**The detail that made the Merge branch possible at all:** `merge_logic.gd`'s `commit_merge`
now snapshots both consumed pieces' ADR-0002 Stock-shaped state **before** the erase loop
discards it. Verified by reading the code, not the report — `g.board[ref].duplicate()` runs
before `g.board.erase(ref)` in the same iteration, strips `owner`, and collapses to a bare id
when nothing else remains. By the time Zapruder's activates the originals are otherwise gone
for good, so a snapshot taken any later would have returned nothing.

**Process note worth keeping:** this agent detected another agent's Godot process and
**waited rather than running concurrently**, unprompted — the first time the "never run two
suites at once" rule has been self-enforced.
