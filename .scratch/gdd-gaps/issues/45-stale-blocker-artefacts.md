# 45 — Three Artefacts whose blocker notes went stale

Status: done (2026-08-29)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why this slice exists

The `(needs: …)` notes in the catalog are a snapshot of what was missing **when the row
was triaged**, and slices have been landing against them ever since. Slice 39's drift
checker already found ~30 of those notes stale on `main`. So the notes are a starting
point, not a filter — and re-reading the remaining 38 against the hooks that exist
*today* turns up three Artefacts that are buildable right now on live call sites.

Each was checked against the actual code, not against the note:

| Artefact | Note said | Reality on `main` (2026-08-29) |
| --- | --- | --- |
| Frog Pride Flag | `deploy hook` | `on_deploy` fires from `game.gd:1199` with `ctx = {pos, skip_action}`; two Artefacts already ride it |
| Y2K Patch Floppy Disk | `turn-skip hook` | `on_enemy_turn_start` fires from `economy.gd:277` and **returns the enemy's action count** — Filibuster already modifies it |
| Pandemic Toilet Paper Pallet | `purchase counter` | `on_purchase` and `on_price` both dispatch in `shop.gd`; `_open_shop` / `shop_open()` give a real visit boundary |

## Scope

### 1. Frog Pride Flag — Common

> The next piece you Deploy after losing a piece gains +1 Piece Buff

Hooks: `on_piece_lost` to arm, `on_deploy` to consume. Carry a single armed flag in run
state; losing several pieces before deploying does not stack it into several buffs
("the next piece" is singular) — say so in a comment so the next reader does not "fix" it.

Grant the buff with **`_random_buff_key`** (slice 42), never by picking from
`Items.PIECE_BUFFS` directly. That helper exists precisely because a *random* grant must
not hand a piece `slow`, which is flagged `self_harming` — a random grant that debuffs
your own piece is the bug slice 42's pool work was written to prevent.

### 2. Y2K Patch Floppy Disk — Legendary

> On Wave start: the enemy's first Turn is skipped

Hooks: `on_wave_spawn` to arm, `on_enemy_turn_start` to consume. The second hook already
returns `ctx.actions` (seeded from `Tuning.ENEMY_ACTIONS_PER_TURN`), so a skipped Turn is
`actions = 0` for exactly one dispatch — no new call site, and no special "skip" concept
to invent.

Consume the flag on the **first** enemy turn of the Wave only. Held twice does not skip
two Turns unless you decide it should — it should not; two copies both resolve to
"the first Turn is skipped", which is already true. Note that in the handler, since it is
an explicit exception to the additive stacking rule.

Interaction to check: Filibuster also writes `ctx.actions` on this hook. Make sure the
combination is sane and deterministic rather than dependent on key sort order.

### 3. Pandemic Toilet Paper Pallet — Common

> Every 2nd purchase in the same Shop visit costs 50% less

Hooks: `on_purchase` to count, `on_price` to discount. Reset the counter in `_open_shop`
— that is what "the same Shop visit" means, and without the reset it silently becomes
"every 2nd purchase of the run".

**The same trap as slice 43's Mar-a-Lago:** `Shop.price()` runs per slot on every redraw,
so the discount must be a **pure read** of the counter, never a mutation. If the handler
increments anything inside `price()`, the displayed price will drift between frames and
disagree with what the player is actually charged.

## Ordering

**Land slice 43 first.** Both slices add `on_price` handlers, and running them
concurrently is an avoidable conflict in the same match block.

## Not in this slice, and why

Checked and genuinely still blocked — recorded so the next pass does not re-check:

- **Loch Ness Stool Sample** ("Every 1000 Score gained: open a random **Piece** Box") hits
  the same mismatch as Cicada Rejection Letter: `Box.roll_options` offers Item / Artefact /
  Score and never a piece. Question for Notion, not a guess.
- **Denver Bunker Timeshare** and **Area 51 Parking Permit** both need an Item cap, which
  does not exist — that is issue 34, still blocked on design.
- **Oak Island Wishing Well** and **FIFA Complimentary Yacht** need a player-initiated
  "spend Gold now" action, i.e. new UI — issue 32, still blocked.
- **Ecdysis Sheddings** and **Troll Farm Employee of the Month** are meta-dispatch
  (copy another Artefact's effect / re-trigger a whole class of hooks). Buildable, but
  they change how `run()` itself behaves and deserve their own design pass rather than
  being smuggled in beside three simple handlers.

## Acceptance

- `implemented: true` in `data/artefacts.js`, stale `(needs: …)` notes cleared, then
  `node tools/export-game-artefacts.mjs`. Never hand-edit `game/data/artefacts.json`.
- Tests in the split suites (issue 37), seeds pinned, asserting observable behaviour.
- Cover specifically: Frog Pride Flag arms once and not per lost piece; Y2K skips exactly
  one enemy Turn and composes sanely with Filibuster; the Pallet's discount survives
  repeated `price()` calls unchanged and resets between Shop visits.
- `game/tests/run_all.sh` ALL GREEN.

## Blocked by

- nothing (sequence after 43)

## Outcome

Shipped in PR #163. All three implemented; catalog 146 -> 149.

- **Frog Pride Flag** — `on_piece_lost` arms a flag (skipped when `ctx.cancel` is set,
  matching KGB Photo Eraser's precedent on the same hook), `on_deploy` consumes it via
  `_grant_buff`, which routes through `_random_buff_key` internally and so can never hand
  a piece the `self_harming` `slow` debuff.
- **Y2K Patch Floppy Disk** — `on_wave_spawn` re-arms each Wave, `on_enemy_turn_start`
  sets `ctx.actions = 0`. An explicit, commented exception to additive stacking: two
  copies still skip one Turn, because "the first Turn is skipped" is already true.
- **Pandemic Toilet Paper Pallet** — `on_purchase` counts, `on_price` does a **pure read**
  (`ctx.amount -= ctx.base * 0.5` when the next purchase is even), so `Shop.price()`'s
  per-redraw calls never drift. Counter reset added to `_open_shop`, which is what "the
  same Shop visit" means.

**Y2K × Filibuster composition** (both write `ctx.actions` on the same hook): `run()`
iterates `held + tariffs`, so the artefact group always dispatches before the tariff
group — a structural invariant, not an alphabetical accident, since the two keys are never
compared. Y2K's zeroed base is therefore what Filibuster's `+1` lands on: held together,
the enemy's first Turn gets exactly 1 action. Verified by reading rules.gd/artefact_hooks
directly, not taken on the agent's word, and covered by a test in `test_items_tariffs.gd`.

**Assumption flagged, not buried:** Frog Pride Flag arms on any player-piece loss
regardless of `reason`, since the catalog text carries no qualifier.

**A false failure and what it taught us.** The agent's first full run reported three
`game-clicks` failures and it called them contention. That is indistinguishable from a
cover story until checked, so it was checked: three sequential full runs, all ALL GREEN
with clean probes. The agent was right — and the contention was largely self-inflicted,
since four windowed suites were running at once across worktrees. The click probes open a
**real window**; worktrees isolate the filesystem, not the window server. Written up as a
standing convention in `CLAUDE.md` (PR #164), including the half that is easier to forget:
a probe *pass* during a concurrent run is no more trustworthy than a failure.
