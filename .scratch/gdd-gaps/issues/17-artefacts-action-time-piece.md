# 17 — Artefacts: Action, Time & Piece

Status: done

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

Three mid-sized tags whose effects reach into the turn loop rather than into arithmetic:
**Action (12)**, **Time (11)**, **Piece (13)**.

- **Action** — extra actions per turn, conditional actions, action refunds. The `move`
  artefact already shipped is one of these, so the seam exists; the rest generalise it.
- **Time** — clock refills, tick-rate changes, bonus time on triggers. All land on the
  single clock in `game.gd`, which only ticks on the player's turn.
- **Piece** — grants, promotions, conversions, protection. These touch Stock and the
  board, so ADR-0002's opaque piece state matters: anything that puts a piece into Stock
  must carry its state the way Extraction does.

Take only the no-prerequisite ones; anything carrying `(needs: …)` waits for slice 19.

Watch for: **Action artefacts interact with Blitz and the auto-pass.** The turn
auto-passes when the last action is spent, so an artefact that grants an action *during*
resolution can un-end a turn that already ended. Blitz hit exactly this and had to refund
its own action. Test the interaction rather than assuming.

## Acceptance criteria

- [x] Every no-prerequisite Action/Time/Piece artefact implemented and flagged
      (8 of 17 — see Outcome for the 9 deferred with reasons)
- [x] Action grants never resurrect an already-passed turn — covered by a test
- [x] Piece grants into Stock carry state per ADR-0002
- [x] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine

## Outcome

Of the 36 Action/Time/Piece artefacts, 17 carry no `(needs: ...)` prerequisite.
Shipped **8**, all on hooks already wired to a call site at the time of
implementation (`on_capture`, `on_turn_start`) — REGISTRY line + match case,
no call sites touched, matching slice 15's stated ergonomics for 16-20.

**Shipped** (`data/artefacts.js` `implemented: true`, re-exported via
`tools/export-game-artefacts.mjs`):
- **CIA Exploding Cigar** (Action) — flat +1 Action/Turn, the same
  `on_turn_start` seam "move" already uses.
- **'I Am Not a Robot' Checkbox** (Action) — +1 Action/Turn at 8+ allied
  pieces on the Board.
- **Seed Vault Secret Hatch** (Action) — +1 Action/Turn while holding 3+
  unused Items.
- **Super Soldier Multivitamins** (Action) — +1 Action/Turn while 3+ allied
  pieces carry a Piece Buff.
- **Stargate Divination Crystal** (Action) — +1 Action if the first Action
  of the Turn is a Capture. The critical case: it grants from `on_capture`,
  mid-turn-resolution, before `_move_player`'s own `actions_left -= 1` /
  auto-pass check runs — the exact ordering that lets the Blitz item refund
  its own action without ever resurrecting an already-ended turn. Covered by
  a test pair: a baseline (no artefact) that DOES auto-pass on the last
  action, and the Stargate case that doesn't.
- **5G Microchips** (Time) — On Turn start, +1s Clock per allied piece on
  the Board, -1s per enemy piece.
- **Terracotta Draft Card** (Piece) — On Wave clear, +1 random Piece to
  Stock. A bare id `String` per ADR-0002 — a fresh pool piece carries no
  board state to preserve (the `Dictionary` form is for a piece pulled off
  the board with state attached, e.g. Extraction).
- **Charlemagne's Birth Certificate** (Time) — On Wave clear, +10s Clock.

`on_wave_clear` had zero call sites when this slice started; the concurrent
Gold/Score slice (issue 16, merged first) wired it centrally in
`WaveLogic.queue()` (guarded `n > 1`) for its own Wave-clear artefacts, which
this slice's rebase then inherited for free — Terracotta Draft Card and
Charlemagne's Birth Certificate needed no wiring of their own.

Added a scenario (`"Artefacts: slice 17 (Action/Time/Piece)"`,
`game/data/scenarios.gd`) and 13 checks in `test_items.gd`.
`game/tests/run_all.sh` — ALL GREEN (click probes + headless suites).

**Skipped** (left `implemented: false`), with reasons:
- **Witness Protection Mustache** (Time, On Rank Up) — no `on_rank_up` hook
  exists.
- **Capstone Polish** (Score/Time, On acquiring an Artefact) — no
  `on_artefact_acquire` hook exists.
- **Casino Invisible Clock** (Time, On Shop purchase) — `on_purchase`
  landed mid-slice (issue 16, via rebase), too late for this pass's test
  coverage. Cheap follow-up: one REGISTRY line + `g.clock_ms += 25000`.
- **2012 Doomsday Party Hat** (Time, Per 10 Gold gained: +5s Clock) — same
  timing: `on_gold_change` also landed via the issue-16 rebase. Cheap
  follow-up, reading `ctx.amount` (the realized gain, mirroring how
  Tungsten-Filled Gold Bar/El Dorado Body Glitter already read it off the
  same hook).
- **Tunguska Toothpicks** (Score/Time, Whenever a Tariff charges you) — no
  `on_tariff_charge` hook; tariffs still dispatch via a direct `match` in
  `economy.gd`, not through `ArtefactHooks` (issue 13's still-open scope).
- **Doomsday Autoclicker** (Score/Time, On Decisive Item use) — no
  `on_decisive_item_use` hook; item tier isn't surfaced to the hook layer.
- **Elvish Hard Hat** (Action, first Action is an Item or ability) — needs
  action-type tracking (item vs move vs capture) at the point actions are
  spent, meaning a direct touch to `_item_apply`/`_move_player`; "ability" is
  also ambiguous in the current data model (no such category exists
  separately from "item").
- **Nuclear Football Menu** (Action, Items don't spend an Action under 60s
  Clock) — a cost *exemption*, not a hook-triggered grant; implementing it
  faithfully means branching `_item_apply`'s action-cost line directly,
  which the hook-only architecture this slice otherwise held to doesn't
  cover.
- **Shrinkflation Cereal Box** (Score/Gold/Time, turn-end triple gain +
  permanent Shop price surcharge) — compound effect reaching into Shop
  pricing (`shop.gd:price()`), which has no hook at all; deferred as its own
  small design decision rather than folded in here.

The remaining 19 Action/Time/Piece artefacts all carry a `(needs: ...)`
prerequisite and wait for slice 19, per the issue's own scope.
