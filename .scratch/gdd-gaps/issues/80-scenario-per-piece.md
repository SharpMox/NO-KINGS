# 80 — A sandbox per piece (39), generated

Status: done (2026-08-31)

## Parent

`.scratch/gdd-gaps/issues/73-scenario-coverage.md` (split (c))

## Scope

One generated board per piece: the piece placed with room to move, plus its Family chain so
promotion/fusion behaviour can be watched by hand. Mechanical, and the most directly useful
part of 73 — the exotic pieces are where movement bugs would actually hide.

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

## Outcome (2026-08-31)

**39 generated per-piece sandboxes in 9 Family sections; 279 scenarios total.**

`game/data/scenarios_pieces.gd`, derived from `data/pieces.json` — never hand-transcribed, so
a piece added to the codex gets a sandbox with no edit here. Keyed on **ids**, showing display
names only (the issue-58 convention: `dragon-horse` is the id, "Cardinal" the display name).

**Family grouping is derived from `next`.** Following it forward gives a promotion chain, so
inverting it gives each piece's chain root — which is what the sections are named for. Eight
real Families of 3, plus **Standalone (15)**: a piece that promotes into nothing and is
promoted into by nothing has no Family, and filing each under its own name would have made 14
singleton sections, which `menu.gd` folds into "Other" and mixes with unrelated one-offs.

**Board.** The subject sits mid-board at (3,4) with open lines in every direction — a slider
boxed into a corner demonstrates nothing. Enemies sit at three distances (adjacent, a short
leap, and down an open file) so short leapers, mid leapers and riders all have something
takeable without needing a template per movement class. Two escort pawns keep a sandbox from
ending in starvation while the subject is being looked at. Stock carries two of the subject
plus two of what it promotes into, so the merge that walks the chain is reachable by hand.

**The King is special-cased**: the player never owns one, so its entry uses the shipped
win-screen shape (enemy King at wave 50) rather than putting a player-owned King on the board.

### Two data traps, both silent

- **A static var whose initializer reads the filesystem resolves to null**, and iterating that
  produced an empty scenario list rather than an error at the point of the mistake. The
  catalog is loaded lazily on first use, matching `items.gd`'s existing pattern.
- **Several entries carry an explicit `"next": null`** rather than omitting the key, so
  `.get("next", "")` hands back the null instead of the default and the typed String
  assignment fails. `_next_of()` centralises that so the trap is handled once.

Both failed *quietly* — the list came back empty and the count read 240 instead of 279. Worth
knowing for any future generator reading these JSON catalogs.

### Suite runtime

| | Scenarios | `test_scenarios.gd` |
| --- | --- | --- |
| before 79 | 60 | 17.9s |
| after 79 | 240 | 75.9s |
| **after 80** | **279** | **88.8s** (+12.9s) |

`run_all.sh` total **151.3s**, ALL GREEN, foreground, alone. Still well short of anything that
would justify splitting `scenarios.gd` into swept and sandbox-only sets.
