# Open flags

Things surfaced while working the slices that are **not blocking**, have no owner, and
will quietly rot if they only live in a PR description. None of these is a slice on its
own; most are a decision or a small piece of art away from closing.

Reviewed 2026-08-28.

## Art

- **The King has no painted token.** It still renders as the old generated cream disc
  beside 38 painted pieces, which is conspicuous on the board. Dropping
  `king-light.png` + `king-dark.png` into `game/assets/pieces/` switches it over with
  **zero code change** — the loader already falls back through `mono_art`, and
  `test_assets.gd` will start requiring the pair once one half exists.
- **The Dark token set is not one faction.** `Bishop-Dark` is bright red while
  `Pawn-Dark`, `Rook-Dark` and `Knight-Dark` are near-black with almost no outline
  contrast. Against the dark brown square (`#b58863`) the near-black ones read as holes
  rather than pieces. The Light set is consistent; this is a Dark-set value problem.
- **Two source filenames are wrong** in `Documents/NO KINGS - PIECES DESIGNS/`:
  `Dragonlord.png` is missing its `-Dark` suffix and `Queztalcoatl-Light.png` is a typo.
  Both were imported from their intended targets, so the game is fine — but the next
  import from that folder will hit them again.

## Balance / tuning, unvalidated

- **Shop restock thresholds may be unreachable.** The GDD Shop page flags it itself:
  fleet data has a median Crown run ending near Score 300, and the first threshold is
  1000. Either the threshold drops or income rises. Nobody has re-run the numbers since
  the ×10 economy landed.
- **Buff Box is priced Strategic (60 Gold) on reasoning, not playtesting.** It is a
  lottery over three buffs and can hit a Decisive one, which is why it sits above
  Tactical. Revisit once buffs have actually been played.
- **Enemy actions per turn is 1, GDD says 2** — divergence #2, a playtest override from
  2026-07-02 that predates the wave-catalog rebalance, the tariff system and the unified
  action economy. Slice 11 exists to re-test it with fleet data rather than assume.

## Rulings I made that are cheap to reverse

Each was a judgement call needed to ship; none was specced.

- **Range is consumed by the capture, not by any move**, so repositioning the piece does
  not waste it.
- **Multicapture picks its extra victim automatically** — the most valuable eligible
  neighbour — so the trigger needs no second targeting step mid-capture. The alternative
  is letting the player choose, which costs a targeting stage.
- **Buff Box resolves on use, not on acquisition.** The GDD fires the sub-pick
  immediately when it is picked from the Item Box's 5 options; the prototype has no
  two-step box (divergence #10) and every other item resolves on use, so it enters the
  inventory like any item. Recorded on its Notion page.

## Open design questions raised by implementation

Each was surfaced by an agent that declined to guess, and each is written up where it was
found. Collected here so they are not lost in Outcome sections:

- **Holy Lint's grant timing** — issue 27. ~17% of its rolls are consumed by the very
  capture that granted them.
- **Tungsten-Filled Gold Bar + Popemobile Piggy Bank** compound to 11-54x baseline score
  over a full run. Confirmed *not* a double-count bug (see issue 20's Outcome) — a
  genuinely powerful catalog-specified pair. Balance call outstanding.
- **Abduction Probe** ("pieces can carry 2 Piece Buffs at once") — there is no 1-buff cap
  anywhere in the code today, so implementing it means inventing a base-game restriction
  nothing currently asks for.
- **`on_milestone` fires every 10 waves but several artefacts say "5-Wave Milestone"** —
  a real GDD/code mismatch. Those artefacts currently hook `on_wave_clear` and check
  `g.wave % 5` directly.
- Assorted per-artefact ambiguities parked in issues 19, 21, 22, 24 and 26 Outcomes.
- **Tier 5 kills Blitz outright.** With one action per turn, the move spends the turn before
  Blitz's already-moved target filter can ever match. Measured, not theorised; flagged rather
  than compensated for, since the tier spec calls for a flat action cut.
- **Tier 5 may simply be too harsh.** 24-run sweep: median survival wave 38.5 -> 9.5, 0/24
  wins, every loss to resource starvation. That is the measurement, not a verdict — a top
  tier is allowed to be brutal, but it wants a play test before it is called balanced.

## Housekeeping

- **`tools/generate-piece-art.py` is mostly orphaned.** It generated the 38 svg tokens
  that the painted PNGs replaced; it now only produces `king.svg`. Delete it once King
  art lands, or keep it as the fallback generator and say so in its header.
- **`data/artefacts.js` and `game/data/` have no shared pipeline yet.** The site knows all
  180 artefacts; the game hand-writes 7. Slice 14 fixes this.
