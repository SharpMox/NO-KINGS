# 09 — The 16-King cast

Status: done

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

The [Kings](https://app.notion.com/p/3b0f1559c99b8092b2d3e4d0570bd59a) page defines a cast
of **16 named Kings** across four costume tiers — 🌿 Laurel, 🎩 Hat, 🎖️ Uniform, 👔 Suit —
each with its own Notion page, plus 13 documented reserves and a ratified casting rule.

The game has one anonymous `king` piece. Waves 50, 100 and 150 spawn the identical thing.
The entire cast, the tiers and the conspiracy lore the artefact catalogue leans on are
absent, and the King is also the one piece with no painted art (it still renders as the
old cream disc beside 38 painted tokens).

1. **King identity as data** — id, display name, tier, per the Notion cast.
2. **Selection** — which King shows up on a King wave. The GDD does not say; simplest
   coherent rule is tier-ordered by depth (wave 50 / 100 / 150 escalate), with the roster
   sampled within a tier. Decide and record it.
3. **Surfacing** — the King wave banner names the King; the end screens report which were
   defeated. `kings_defeated` is already a count, not a roster.
4. **Art** — `king-light.png` / `king-dark.png` per King. The loader already picks these
   up with no code change (`mono_art` falls back until they exist), so art can land
   independently of the mechanics.

Per-King *mechanics* are not specced anywhere — do not invent them here. This slice is
identity, selection, presentation and art only.

## Acceptance criteria

- [x] All 16 Kings exist as data with name and tier
- [x] A King wave spawns a named King by a recorded rule
- [x] The wave banner names it; end screens list which were defeated
- [x] Save/load preserves which King is on the board
- [x] King art wired (or cleanly absent, still falling back)
- [x] `run_all.sh` all green

## Blocked by

- nothing

## Outcome

Shipped on `feat/king-cast`. Identity, selection and presentation only — no per-King
mechanics, as scoped.

- **`game/data/kings.gd`** (new): the 16-King roster from the Notion Kings page, 4 per
  tier (`{id, name}`), plus the selection rule.
- **Selection rule (recorded):** King waves escalate tier-ordered by King-wave depth —
  the Nth King wave (0-based) draws from `TIER_ORDER[N]` = `[Laurel, Hat, Uniform, Suit]`,
  clamped to the last tier once waves run out. Today that's wave 50 → Laurel, 100 → Hat,
  150 → Uniform; Suit is reserved for a King wave beyond 150, which `data/waves.gd`
  doesn't generate yet (its own comment: "the catalog's procedural extension past 150 is
  not implemented"). The specific King is sampled uniformly within the tier from the
  run's own RNG (`g.rng`), so it's seed/save-deterministic. Picked as the literal,
  order-preserving reading of "tier-ordered by depth" from the issue text — no subjective
  re-ranking by notoriety needed.
- **Identity travels on the board piece:** `WaveLogic.queue()` picks the King once (so
  the banner can name it) and stamps `king_id` onto the "king" pending-spawn entry;
  `spawn_pending()` copies it onto the board dict, mirroring the existing `buff` flag
  pattern. `king_id` is plain extra piece state, so it rides through save/load for free
  via the board-piece's already-generic extra-field mechanism (`save_config.gd`) — no
  save-format change needed there.
- **Surfacing:** the turn-fx banner reads "KING WAVE: <Name>" (`wave_logic.gd`); the HUD
  wave label reads "King: <Name>" while one is alive (`hud.gd`); the win-screen overlay
  names which King just fell (`modals.gd`); the game-over/victory overlay lists every
  King defeated this run.
- **Roster, not just a count:** added `king_ids_defeated: Array` alongside the existing
  `kings_defeated` int (left untouched — still drives "endless unlocked" and the local
  leaderboard). New array is captured on both the checkmate and capture paths in
  `_move_player`/`_king_down` (`game.gd`) and persisted explicitly in `save_config.gd`
  (it's run-level state, not per-piece, so it doesn't ride the generic board mechanism).
- **Art:** untouched by design. `king-light.png`/`king-dark.png` were not created; the
  `mono_art` fallback to `king.svg` in `game.gd` is unchanged, and since every King still
  spawns with piece id `"king"`, the fallback keys correctly regardless of which King it
  is — no code change needed for the art path to keep working (or to pick up painted art
  later).
- **Tests:** new `game/tests/test_kings.gd` (roster shape, selection-by-tier, and that a
  queued wave-50 King's identity lands on the board and is readable via `_king_name()`)
  registered in `run_all.sh`. New scenario "Win screen: named King (identity, issue 09)"
  in `data/scenarios.gd` exercises the named win-screen text through the scenario sweep.
  `test_save.gd`/`test_endless.gd`/existing scenarios needed no changes — bare `"king"`
  board entries with no `king_id` still resolve to "King" via `Kings.name_of`'s fallback.

`game/tests/run_all.sh` (windowed click probes + full headless suite) is ALL GREEN.
