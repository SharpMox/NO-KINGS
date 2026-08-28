# 25 — Artefacts: per-piece capture ledger

Status: todo

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

- [ ] Notion ruling: does a piece's capture ledger survive Stock round-trips
      (ADR-0002), or reset? Ask, don't guess — the three artefacts above
      read differently either way
- [ ] The ledger field, incremented at both `_move_player` and
      `_run_enemy_actions`' capture branches
- [ ] Zodiac Crossword Puzzle's Wave-scoped variant, reset in
      `WaveLogic.queue`
- [ ] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine
- 19 — Special + prereq triage (this file is one of its splits)
