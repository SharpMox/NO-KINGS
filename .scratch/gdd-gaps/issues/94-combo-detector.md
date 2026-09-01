# 94 — The combo detector + the generated Combo boards

Status: done (2026-09-01) — grilled and built the same day

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

## Outcome (2026-09-01)

**34 generated boards in `game/data/scenarios_combos.gd`. 335 scenarios total** on this
branch (301 + 34), all in 81's existing `Combo` section. 351 once slice 82's 16 King
sandboxes merge — the two branches both append to `Scenarios.all()`, which is their only
overlap and a one-line conflict.

### The spec's firing table was wrong in two places, and deriving it caught both

The table in this file was written from memory during grilling. Checking each entry against a
real `ArtefactHooks.run` call site before coding killed two of them:

- **`ctx.gold_bonus` / `ctx.score_bonus` do NOT fire a hook.** `Economy.earn` applies them
  with a direct `g.gold += ...` / `g.score += ...` (economy.gd:111-114); they never re-enter
  the dispatch. `on_gold_change` fired because somebody called `earn()`, not because a
  handler set a bonus. Counting it would have paired every converter Artefact with every Gold
  listener for no reason.
- **`ItemLogic.grant` fires nothing** — it appends to `g.items` (item_logic.gd:41-45).
  `on_item_consume` fires on USE, not on grant.

Both are now in the script's exclusion list with their reasons, so the next reader does not
re-add them.

**A third finding, free**: `on_box_open` and `on_shop_restock` are declared in `HOOKS` but
fired nowhere in `game/scripts`, and nothing listens on either. Dead vocabulary.

### The hook graph is much sparser than the grilling assumed

- **21 of 180 Artefacts fire anything at all** (28 key→hook edges). The ctx contract is why:
  handlers return values through `ctx` instead of calling into the game, so they mostly
  cannot cause anything. The real producers are the ones that call out —
  `Economy.add_clock`, `g._apply_buff`, `WaveLogic.queue`, `Shop.price`, `Shop.buy`.
- **8 of the 12 Army effects fire nothing**, which is a finding rather than a gap. Most
  Army Powers MODIFY a value at a call site rather than cause a hook. The sharpest case:
  **Insider Rates is applied at `shop.gd:189`, after the `on_price` dispatch at
  `shop.gd:164`** — every `on_price` listener sees the undiscounted price, so the Syndicate's
  Power reaches none of them. Recorded in `armies.gd`'s header.
- The four that do produce: Hold the Line (`Economy.earn_gold` → `on_gold_gain`,
  `on_gold_change`), Shield Wall and Ritual (`_apply_buff` → `on_buff_apply`), Hostile
  Takeover (`spend_gold` → `on_gold_zero`).

### What the directed rule bought

`on_wave_clear` has **39** listeners and **no** producer, so it generates **zero** boards.
Undirected it would have emitted 741 pairs of noise. `on_item_consume`'s 112 true-but-
redundant pairs (16 Items × 7 listeners) collapse to **2** boards.

### Verification

`test_combos.gd` (new, registered in `run_all.sh`) checks what the scenario sweep cannot see:

- every declared hook name is real — a typo would silently drop a producer from every pairing
- **the directed rule holds for all 115 producer→listener pairs**: every Artefact on a board
  listens on the hook that board is named for
- no board exceeds `ARTEFACT_CAP_BASE` (5)
- every Army board names a real Army — `cfg["army"]` falls back silently otherwise (81 hit this)
- **53 passed-over producers are recorded**, not silently cut

The boards themselves boot and bot-play under `test_scenarios.gd` like every other scenario.

### Known limitations, stated rather than hidden

- One board per (hook, chunk) means the **first producer by key** represents its hook and the
  other 53 do not get boards. At `on_capture` that means Multicapture is shown and Trap,
  Reflect and Wild Hunt's Power are not, though they behave differently. `Combos.dropped()`
  lists them.
- The derive script sees **direct calls only**. An Artefact firing a hook through an indirect
  path is missed — which shows up as a board that never gets generated, not a wrong one.
- `suppresses` is declared on all 42 hand-written effects and **consumed by nothing**. See
  FLAGS: a mistake in it is invisible by construction.
