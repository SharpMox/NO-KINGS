# 81 — The hand-built combo boards (20-30)

Status: done (2026-08-31)

## Parent

`.scratch/gdd-gaps/issues/73-scenario-coverage.md` (split (b))

## Scope

The boards a generator cannot produce, because their point is an *interaction* rather than a
trigger. 20-30 of them, hand-authored. From 73: the stacking pairs, the cap interactions, and
the Army Power / Artefact overlaps.

These are the ones that will actually get opened twice — the rest of 73 is a reference shelf.

## Candidates worth including

Drawn from interactions this backlog has already argued about, so each board settles a
question that has genuinely come up:

- **The three caps refusing at the limit** — Items 3, Piece Buffs 2, Artefacts 5. One board
  each, already at the cap, with a grant incoming, to watch it refuse *visibly* rather than
  silently drop (issues 53, 60).
- **Deep State Yearbook + selling** — the loop that was wrongly called infinite. A board that
  shows it netting -5 per cycle is the fastest possible answer to it being raised again.
- **Mao's Loyalty Badge** buy-two-sell-both, break-even at 50%.
- **Denver Bunker Timeshare** losing its +30% the moment an Item is sold.
- **Tape Eraser Magnet** — selling is not using; it must not fire.
- **Captured Stock**: merge, convert at 50%, sell — and *not* deployable (issue 60's largest
  behaviour change).
- **Jet Fuel Vial / Pandemic Toilet Paper Pallet** across a Wave boundary, since both moved
  off the retired per-visit boundary (issue 61).
- **Army Power + Artefact overlaps** — the six Armies against the Artefacts that touch the
  same resource.
- **Bible Gag Reel Scroll** granting Shield to all three of `bishop` / `dragon-horse` /
  `archbishop` and hitting the Buff cap (issue 58).

Judgement work: pick the ~25 that teach the most, not the ones that are easiest to build.

## Acceptance

- Each board is named for the question it answers, not for the Artefact it holds.
- Loadable and playable; the interaction is visible within a couple of moves, not twenty.
- Boots under `test_scenarios.gd`.
- `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

- 79 (menu grouping — these land in the same list)

## Outcome (2026-08-31)

**22 hand-built boards, in `scenarios.gd`'s hand-written list (they are not generated, so they
live where the hand-written ones live). 301 scenarios total.**

Every board is **named for the question it answers**, per the issue — "Combo: is the Deep State
Yearbook buy/sell loop really a net loss?", not "Combo: Deep State Yearbook". The point is that
a disputed interaction gets re-settled in seconds by loading the board, so the name has to be
the dispute.

Two sections, by name prefix: **Combo** (15) and **Combo Army** (7).

### What they cover

All nine candidates the issue listed, plus three the list implied:

- **The three caps** — an Item grant at 3, a 6th Artefact refused by the Shop, a Piece Buff
  grant at 2. The Buff board uses Bible Gag Reel Scroll against four takeable pawns, so the
  cap is reached in a couple of moves rather than engineered into the starting state.
- **A fourth**: all three caps full simultaneously, which no single-cap board shows.
- **Deep State Yearbook** at a full 5-Artefact collection — the arithmetic the "infinite Gold"
  claim died on (4 x 5 = 20 back on a 50-Gold Common at 50% sell = **-5 per cycle, at every
  collection size**).
- **Mao's Loyalty Badge**, **Denver Bunker Timeshare** losing its +30% on a sale,
  **Tape Eraser Magnet** (selling is not using), **Captured Stock** (merge/convert, never
  deploy), **Jet Fuel Vial** and the **Pallet** across a Shop close/reopen, **two Snowden
  copies** stacking rerolls, **Ecdysis** proving it copies a key rather than holding a copy,
  and **Hellfire Club** at the resource level where issue 54's softlock shape lives.
- **Bible Gag Reel Scroll** on a board carrying all three chain ids *and* a rook, so "fires for
  these three and nothing else" is one board rather than an inference.
- **One board per Army** (six), each on the resource its Power touches, plus a board contrasting
  the Army Ability's Action cost against Artefact activation's lack of one.

### The Army keys were verified, not assumed

`cfg["army"]` is read as `str(cfg.get("army", g.next_army))` — **an unrecognised name would set
an unrecognised name and silently do nothing**, which is precisely the failure this issue warns
about. Keys were extracted programmatically from `Armies.CATALOG` and then checked back against
it: all 7 army-carrying boards resolve, 0 bad keys.

### Runtime

`test_scenarios.gd` 88.8s (279) -> **93.6s (301)**, +4.8s. `run_all.sh` **155.5s**, ALL GREEN,
foreground, alone.

### Left out, deliberately

The issue asked for 20-30 and this is 22. Nothing on the candidate list was skipped. Boards
that would have needed a piece to start with pre-set buff state were built to *reach* that
state through play instead — the per-piece state dictionary in a board entry is real
(`["king", 1, 3, 10, {"king_id": "nero"}]`) but its buff key shape is not documented, and
guessing it would have produced a board that silently sets nothing.
