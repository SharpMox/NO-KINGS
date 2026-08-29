# Open flags

Things surfaced while working the slices that are **not blocking**, have no owner, and
will quietly rot if they only live in a PR description. None of these is a slice on its
own; most are a decision or a small piece of art away from closing.

Reviewed 2026-08-29.

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
- **Yalta Cocktail Napkin held twice, both copies acquired on the same Wave**: the first
  copy wins the modal that milestone and the second forfeits its pick, rather than
  queueing a second modal. Follows the existing `trojan-horse-assembly-manual` precedent
  (`not g.box_open`). Cheap to reverse into a queue if a forfeited reward feels bad — but
  note it only ever bites when you hold two copies bought on the same Wave.
- **New World Order Gerrymandering is a post-pass in `run()`, not a REGISTRY handler.**
  It multiplies "what the other Artefact handlers added" (`ctx.amount - ctx.base`), which
  is only correct once every other handler *and* the echo layer have run. Implementing it
  as an ordinary handler that happens to sort last would reintroduce exactly the
  order-dependence issue 20 was raised to kill. It is a deliberate, called-out exception
  to the ORDERING rule, and it must stay last in `run()`.
- **Buff Box resolves on use, not on acquisition.** The GDD fires the sub-pick
  immediately when it is picked from the Item Box's 5 options; the prototype has no
  two-step box (divergence #10) and every other item resolves on use, so it enters the
  inventory like any item. Recorded on its Notion page.

## Open design questions raised by implementation

Each was surfaced by an agent that declined to guess, and each is written up where it was
found. Collected here so they are not lost in Outcome sections:

- ~~**Holy Lint's grant timing**~~ — issue 27, closed 2026-08-28. The "~17% of its rolls
  do nothing" figure recorded here was **wrong** and is corrected for the record:
  `capture_multiplier` evaluates *after* `capture_score`, so a granted `critical` doubles
  the very capture that granted it rather than being wasted. Only `range` was genuinely
  inert. The real defect was narrower and different — `slow` is a **debuff on its own
  holder**, so a random grant could hand your own piece a penalty. Fixed by flagging it
  `self_harming` and excluding it from `_random_buff_key` (the player's deliberate Buff
  Box pick still offers it).
- **Tungsten-Filled Gold Bar + Popemobile Piggy Bank** compound to 11-54x baseline score
  over a full run. Confirmed *not* a double-count bug (see issue 20's Outcome) — a
  genuinely powerful catalog-specified pair. Balance call outstanding.
- **Abduction Probe** ("pieces can carry 2 Piece Buffs at once") — there is no 1-buff cap
  anywhere in the code today, so implementing it means inventing a base-game restriction
  nothing currently asks for.
- **`on_milestone` fires every 10 waves but several artefacts say "5-Wave Milestone"** —
  still true, and still worth a GDD ruling, but it is now a *naming* collision rather than
  a behavioural bug. `on_milestone` is the global 10-Wave clock-refill trigger
  (`Tuning.MILESTONE_WAVES == 10`), used only by "timer" and the Recession tariff. Every
  per-artefact "5-Wave Milestone" effect hooks `on_wave_clear` and calls
  `_milestone5_hit(g.wave, acquired_wave)` — each held copy counting its own 5 Waves from
  acquisition (issue 28, user ruling 2026-08-29), **not** the `g.wave % 5` this flag
  originally described. The trap is that the hook *named* `on_milestone` is not the one a
  "5-Wave Milestone" artefact wants; issue 43's spec got this wrong and the implementing
  agent caught it.
- Assorted per-artefact ambiguities parked in issues 19, 21, 22, 24 and 26 Outcomes.
- ~~**"Demoted" is undefined**~~ — issue 31, closed by slice 42. Resolved with a
  **peak-rank stamp**: `peak_ranked` is set on any piece the moment it ranks up (at the
  single `on_rank_up` choke point), so "Demoted" means *was Ranked once and is not now* —
  which settles the demoted-then-re-promoted reading. Dark Market Light Bulb ships on it.
- ~~**There is no Clock-gain choke point**~~ — issue 30/35, closed by slice 35.
  `Economy.add_clock` is now that choke point, matching `earn`/`gain` for Gold and Score;
  the ~15 direct `clock_ms` mutations route through it. Black Knight Morse Code is
  unblocked.
- ~~**There is no run-long turn counter**~~ — issue 30/35, closed by slice 35. A run-long
  Turn counter now rides in run state and the save, alongside the per-Wave
  `turns_since_wave`.
- ~~**Tier 5 kills Blitz outright.**~~ Resolved by the Blitz rework
  (`fix/blitz-and-crypto-wallet`, 2026-08-28, user call): Blitz itself now costs 0 actions
  and the target's next move/capture is free, so it no longer depends on the 2-actions/turn
  math this flag was measuring against.
- **Tier 5 may simply be too harsh.** 24-run sweep: median survival wave 38.5 -> 9.5, 0/24
  wins, every loss to resource starvation. That is the measurement, not a verdict — a top
  tier is allowed to be brutal, but it wants a play test before it is called balanced.

## Housekeeping

- **`tools/generate-piece-art.py` is mostly orphaned.** It generated the 38 svg tokens
  that the painted PNGs replaced; it now only produces `king.svg`. Delete it once King
  art lands, or keep it as the fallback generator and say so in its header.
- **`data/artefacts.js` and `game/data/` have no shared pipeline yet.** The site knows all
  180 artefacts; the game hand-writes 7. Slice 14 fixes this.
