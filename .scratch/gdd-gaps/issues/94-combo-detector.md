# 94 — The combo detector + the generated Combo boards

Status: todo (grilled 2026-09-01)

## Parent

`.scratch/gdd-gaps/issues/73-scenario-coverage.md` — the fourth axis. 73 split into 79
(per Artefact), 80 (per piece), 81 (hand-built combos), 82 (per King); this is the one 81
could only sample by hand.

## What this is

81 asked a human to pick "the ~25 that teach the most". This slice asks the data instead:
**which effects actually reach each other**, derived from the hook graph rather than from
memory, and one board per cluster it finds.

The catalogs already agree on a vocabulary — `artefact_hooks.gd`'s 34 `HOOKS` — but only
one side of it is written down. `REGISTRY` says what each Artefact **listens** to. Nothing
anywhere says what an Item, a Piece Buff, an Army Power or an Artefact **fires**. That
missing half is the whole slice; the boards fall out of it cheaply.

## The relation (grilled — this is the load-bearing decision)

A combo is **directed**:

```
combo(X, Y)  iff  fires(X) ∩ listens(Y) ≠ ∅
```

Not "both touch the same hook". `on_wave_clear` has **39** Artefact listeners that never
interact; undirected, that one hook emits 741 pairs of pure noise. Directed, it emits
**zero boards**, because no Item/Buff/Army/Artefact fires it — the wave does.

`suppresses(X)` is declared alongside `fires(X)` and **generates nothing in this slice**
(user ruling: combos-only boards). It is written down now because we are reading all 222
effects anyway and re-deriving it later means reading them all a second time. Its consumer
is a later anti-combo slice.

Only Artefacts listen — `REGISTRY` is the only listen-side data in the game — so every
board is *producer → Artefact listeners*.

## The declarations

**Hand-written, inline on the row they describe** (a separate table is a second place to
forget when an Item is added). Precedent: these rows already carry engine metadata beside
the Notion-mirrored fields — `target`, `action_cost`, `model`, `turns`, `self_harming`.

| Where | Rows | Field |
|---|---|---|
| `game/data/items.gd` `ITEMS` | 16 | `fires`, `suppresses` |
| `game/data/items.gd` `PIECE_BUFFS` | 14 | `fires`, `suppresses` |
| `game/scripts/armies.gd` `CATALOG` | 6 × 2 | `power_fires` / `power_suppresses`, `ability_fires` / `ability_suppresses` |

Safe against the drift checker: `tools/check-notion-drift.mjs:169` compares only
`{name, tier, description}` for Items, so extra fields are ignored.

**The 180 Artefacts are DERIVED, not hand-written.** `tools/derive-artefact-fires.mjs`
scans each `_dispatch` match arm — every one is labelled `["key", "hook"]`, so attribution
is unambiguous — for the calls that cause another hook to fire:

```
ctx.gold_bonus / ctx.score_bonus  -> Economy.earn  -> on_gold_change / on_score_change
Economy.earn / gain               -> on_gold_change / on_score_change
_apply_buff                       -> on_buff_apply
_destroy                          -> on_destroy
add_clock                         -> on_clock_change
grant                             -> on_deploy
```

Output: `game/data/artefact_fires.json`, **generated — never hand-edited**, same rule as
`pieces.json`/`artefacts.json`. This describes what the code *does*, not what someone
remembers it doing, and 180 hand judgements would have dominated the slice.

Known limitation, stated rather than hidden: it sees direct calls only. An Artefact that
fires a hook through an indirect path is missed, and shows up as a board that never gets
generated rather than as a wrong one.

**Kings are out of scope.** Their 32 Powers/Abilities plainly fire and suppress hooks
(Nero halves Gold gains; Nebuchadnezzar's exile suppresses the Captured Stock append), but
they are not in this slice — see 82, which wants boards of its own.

## The boards

`game/data/scenarios_combos.gd`, appended by `Scenarios.all()` beside `Generated` (79) and
`GeneratedPieces` (80). Same shape as both: derived at load, no hand-written entries.

**One board per (hook, listener-chunk).** Listeners sorted by key and chunked by the real
board cap — `ARTEFACT_CAP_BASE` is **5** (`tuning.gd:21`), so 4 when the producer is itself
an Artefact and occupies a slot. The producer is the first by key among that hook's
producers.

That representative rule is a deliberate cap, and it drops things: at `on_capture`,
Multicapture, Trap, Reflect and Wild Hunt's Power all behave differently, and only one of
them gets a board. It keeps the slice at ~40 boards instead of ~150. **The generator logs
which producers it dropped** — a silent truncation would read as "covered" when it isn't.

Expected volume: ~40–55 boards, bounded by `Σ ceil(listeners / 5)` over hooks that have a
producer. For scale, `on_item_consume`'s 112 true-but-redundant pairs (16 Items × 7
listeners) collapse to 2 boards.

Board contents, per cluster: the producer placed so it can be performed in a couple of
moves (reuse 79's templates), the chunk's Artefacts in `cfg.artefacts`, Items in
`cfg.items` (cap 3), Buffs on a board piece via the slot-4 Dictionary
(`{"buffs": [{"key": "critical"}]}`, `save_config.gd:160-166`), Army as `cfg.army`.

**Verify Army keys against `Armies.CATALOG`.** `cfg["army"]` is read as
`str(cfg.get("army", g.next_army))` — an unrecognised name sets an unrecognised name and
silently does nothing. 81 hit exactly this.

## Naming

`"Combo: <hook> via <Producer> (i/n)"`, index omitted when `n == 1`. `menu.gd:176-191`
cuts each name at the first `:` or `(`, so this **merges into the existing `Combo`
section** (15 hand-built from 81) rather than making a new one — user ruling. `Combo Army`
(7) is untouched.

## Acceptance

- `fires`/`suppresses` declared on all 16 Items, 14 Piece Buffs and 12 Army effects.
- `artefact_fires.json` generated by the script, not by hand; the script is committed.
- One board per (hook, listener-chunk); dropped producers logged, not silently cut.
- Every generated name starts `Combo: ` and lands in the `Combo` section.
- Boots under `test_scenarios.gd`.
- `run_all.sh` ALL GREEN, foreground, alone, `timeout: 600000`.

## Explicitly NOT in this slice

- Anti-combo boards (the `suppresses` half generates nothing — user ruling).
- Any test proving the hand-written declarations are true (user ruling — see FLAGS).
- Kings as producers.
- Artefact→Artefact boards beyond what the derived `fires` map produces on its own.

## Blocked by

Nothing. 79 (generator + menu grouping) and 81 (the `Combo` section) are both done.
