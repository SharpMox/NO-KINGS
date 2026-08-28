# 25 — Artefacts: per-piece capture ledger

Status: done

## Parent

`.scratch/gdd-gaps/PRD.md`

## Split out of

19 — 3 artefacts all want a capture count kept per INDIVIDUAL piece, which
is a different thing from every counter the trigger engine already has
(`wave_capture_count`/`turn_capture_count` are run-wide, not per-piece).

## What to build

A board piece Dictionary would need a new field (e.g. `captures: int`,
absent = 0) incremented wherever a piece's OWN capture resolves — that's
`_move_player`'s capture branch and `_run_enemy_actions`' capture branch,
both already touched by issue 19's `on_piece_lost`/`on_capture` wiring, so
the call sites are known. The open question is ADR-0002 (Stock holds opaque
piece state): does `captures` survive a piece going Stock -> board again
(Extraction, Asset Recovery) the way Piece Buffs already ride along as
`buffs`, or does it reset? The GDD text doesn't say, and it changes the
answer for all 3 artefacts below.

| Artefact | Needs | Note |
| --- | --- | --- |
| Chupacabra Chew Toy | per-piece capture memory | "+2 Gold on Capture; +10 more if the captured piece had captured one of yours" — reads the VICTIM's ledger at the moment of capture, before it's erased |
| Zodiac Crossword Puzzle | per-piece capture tracking | "on Wave clear: the ally with the most Captures that Wave gets +1 Piece Buff" — needs a WAVE-scoped ledger (reset at Wave start), separate from the lifetime one Chupacabra implies |
| Alien Rocket Toy | per-piece capture counter | "on a piece's 3rd Capture: it Ranks Up" — a lifetime ledger, and its trigger (an actual chain promotion) should fire on_rank_up (issue 19) once it lands, so this one plugs into the existing hook once the ledger exists |

## Acceptance criteria

- [x] Notion ruling: does a piece's capture ledger survive Stock round-trips
      (ADR-0002), or reset? Ask, don't guess — the three artefacts above
      read differently either way — **settled by the ADR itself, see Outcome**
- [x] The ledger field, incremented at both `_move_player` and
      `_run_enemy_actions`' capture branches
- [x] Zodiac Crossword Puzzle's Wave-scoped variant, reset in
      `WaveLogic.queue`
- [x] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine
- 19 — Special + prereq triage (this file is one of its splits)

## Outcome

All 3 artefacts implemented (91 -> the branch's own +3; landed on top of main
after issues 24/25 both merged, so the visible count moved from 92 -> 95).

**The ADR-0002 ruling wasn't sent to Notion as a question** — it's already
settled by the ADR's own text, not a GDD-design ambiguity: "Stock never
interprets the state... opaque pass-through absorbs any future state that
lives on the board-piece dict, by construction." A `captures` field is
exactly that kind of state, so it rides through Extraction/placement with
zero new code, the same way Piece Buffs (`buffs`) already do. Verified by a
round-trip test (test_save.gd), not assumed.

**Ledger fields** (game.gd board piece Dictionary, absent = 0):
- `captures` — lifetime, incremented once per capture the piece itself makes.
- `wave_captures` — same, reset every Wave in `WaveLogic.queue` (on both
  `g.board` and any Dictionary Stock entries, so a piece Extracted mid-Wave
  doesn't carry a stale count into a Wave it never played).

Both increment through one new choke point, `game.gd`'s `_note_capture(pos)`
— called from `Economy.capture_score` (the player's own capture, via
`g._note_capture(attacker_pos)`, before the `on_capture` hook runs) and from
`_run_enemy_actions`' capture branch directly (the enemy's own capture never
reaches `capture_score`, since the enemy doesn't score). Those are the two
"a piece's OWN capture resolves" sites this issue named; Reflect/Trap/Bomb
counter-kills are a different resolution path and stayed out of scope — a
deliberate boundary, not an oversight (the issue named exactly these two
branches, both already touched by 19's `on_piece_lost`/`on_capture` wiring).

`on_capture` ctx grew `victim_captures` (`economy.gd capture_score` reads the
victim's ledger before the caller erases it) for Chupacabra Chew Toy's "+10
more Gold if the captured piece had captured one of yours" — since only
enemies capture player pieces, any lifetime `captures > 0` on the victim
already means "one of yours". Alien Rocket Toy plugs into the same
`on_capture` dispatch: on a piece's 3rd lifetime capture, promotes it in
place (mirroring game.gd's "promote" Item) and fires `on_rank_up` itself.
Zodiac Crossword Puzzle reads `wave_captures` on `on_wave_clear` (fired
before the reset, so it still sees the Wave that just ended) and grants +1
Piece Buff to the ally with the highest count; ties keep whichever board
position is found first (same reading Diplomatic Migraine Ray's "the
strongest" already uses — no GDD tie-break specified).

**Rebased onto `fix/artefact-ctx-contract` (#125) and `feat/artefact-
combat-positioning` (#126)**, both merged to main first. No conflict with
the ctx-contract fix (Chupacabra/Alien Rocket Toy already returned values
through `ctx`/mutated `g` directly in the established on_capture pattern —
never wrote to `g.score` inside `on_gold_change`). Issue 24 added
`g.last_capture_ctx` and made `_lose_player_piece` return its ctx
(`destroy_attacker` for Hoffa's Cement Shoes); merged cleanly alongside
`_note_capture` in both `_move_player` and `_run_enemy_actions`.

**Bug found and fixed in my own test, not the game logic**: an early draft
put board pieces with pre-seeded `captures`/`wave_captures` into a config
with `wave: 3` and no enemy on the board — `_begin_player_turn`'s "board
cleared early -> next Wave arrives now" path then called `WaveLogic.queue`
immediately at boot, wiping `wave_captures` before the round-trip even ran.
Fixed by adding a live enemy piece to the fixture; not a production bug.
Also found (and worked around, not "fixed" — out of scope): JSON round-trips
turn ints into floats (`JSON.parse_string` always returns float for JSON
numbers), so `Array.has()`/`JSON.stringify` equality checks on a Dictionary
containing a numeric ledger field don't match string-for-string across a
double round-trip. This is a pre-existing, general characteristic of
ADR-0002's opaque untyped Dictionary state — any future int-valued piece
field would hit the same thing — not something this slice's `captures`/
`wave_captures` introduced. The dedicated round-trip test reads the restored
value with a scalar `==` (which coerces int/float) instead of dict/string
equality, and was kept out of the existing "save -> load -> save is
identical" JSON-string-identity fixture rather than loosening that fixture's
stricter guarantee.

**Nothing skipped** — all 3 artefacts in scope for this issue are fully
implemented and covered by scenario + unit + save-round-trip tests.
`game/tests/run_all.sh` (full, including windowed click probes) is ALL
GREEN.
