# 80 — A sandbox per piece (39), generated

Status: todo

## Parent

`.scratch/gdd-gaps/issues/73-scenario-coverage.md` (split (c))

## Scope

One generated board per piece: the piece placed with room to move, plus its Family chain so
promotion/fusion behaviour can be watched by hand. Mechanical, and the most directly useful
part of 73 — the fairy pieces are where movement bugs would actually hide.

Reuses slice 79's generator and its menu grouping; this slice adds a template and a set, not
infrastructure.

## Watch out

- **Piece ids, never display names.** `dragon-horse` is the id, "Cardinal" the display name —
  the convention this repo has already tripped on (see issue 58). Entries key on ids.
- The 39 come from `data/pieces-codex.js` (38 curated + King). Derive the list; do not
  hand-transcribe it, or it silently rots the next time a piece is added.
- Board must give the piece **room to demonstrate its movement** — a slider boxed into a
  corner shows nothing. That is a template concern, not a per-piece one.

## Acceptance

- One entry per piece, loadable and playable, with its Family chain reachable.
- Derived from the data file, so a new piece appears without a code edit.
- Boots under `test_scenarios.gd`.
- `run_all.sh` ALL GREEN, foreground, alone, runtime delta reported.

## Blocked by

- 79 (generator + menu grouping)
