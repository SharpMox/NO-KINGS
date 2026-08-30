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

## Tuning artifacts created by Score x10 (issue 57)

- **The Wave-10 milestone bonus now EXACTLY equals the first Shop restock threshold.**
  `MILESTONE_SCORE_BONUS` is 100, so x10 it pays **1000**; `Shop.threshold(0)` is
  `SHOP_RESTOCK_BASE` = **1000**. They are equal to the point. So reaching Wave 10 banks the
  first restock **by itself, regardless of how the run has gone** — before the slice a
  100-point bonus was nowhere near the 1000 threshold, and the first restock had to be
  earned by scoring.

  Verified by computing both sides, not inferred. The curve is
  `threshold(n) = 1000(n+1) + 500·n(n+1)/2` -> 1000 / 2500 / 4500 / 7000, so only the first
  threshold has this property; the milestone does not trivially cross later ones.

  Not a bug — the slice's whole purpose was to make thresholds reachable, and this is that
  working. But an exact tie is a coincidence rather than a decision, and it puts the first
  restock on rails. Adjusting either constant by any amount breaks the tie; worth a look in
  the tuning pass.

- **Rate coefficients were scaled as flat constants**, which is right but worth recording:
  Putin's Golden Toilet Brush (`5 * ctx.price` -> 50) and Rapture Insurance Policy
  (`g.gold * 20` -> 200) are Score-per-unit-of-Gold conversion rates, not percentages, so
  they do not scale on their own and needed the x10 explicitly. If any *other* effect is later
  found converting Gold to Score by a coefficient, it needs the same treatment.

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
- ~~**Abduction Probe**~~ — resolved 2026-08-29. The user ruled the base Piece Buff cap is
  **2** and the Probe adds **+1** (to 3). Issue 53 introduced that cap, which had to be
  invented — it did not exist before — so the Artefact was re-texted from "can carry 2",
  which by then described the base game.
- ~~**`on_milestone` fires every 10 waves but several artefacts say "5-Wave Milestone"**~~
  — RESOLVED 2026-08-30 (issue 58). The hook is renamed `on_clock_refill`, which is what
  it actually is: the global 10-Wave clock-refill trigger (`Tuning.MILESTONE_WAVES == 10`),
  used only by "timer" and the Recession tariff. Every per-artefact "5-Wave Milestone"
  effect keeps hooking `on_wave_clear` and calling `_milestone5_hit(g.wave, acquired_wave)`
  — each held copy counting its own 5 Waves from acquisition (issue 28, user ruling
  2026-08-29), unrelated to the renamed hook. The naming collision that made issue 43's
  spec name the wrong hook (caught by the implementing agent) is gone — pure rename, no
  behaviour change.
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
  **Update (issue 59, 2026-08-30):** Tier 5 now also doubles enemy Actions per Turn (GDD
  parity, difficulty-rank ruling). Re-swept 24 runs post-change: still 0/24 wins, median
  survival dropped further to wave 7.5. The tuning pass this flag was waiting on is still
  parked as "later," but now has both numbers to start from.

## Fragile tests

- **Holy Lint's pinned-seed assertion names a specific granted buff**, and that has now
  churned **twice in two slices**: issue 47 moved it `stun` -> `reflect` (rolling Box
  contents at boot shifted the RNG stream), and issue 48 moved it `reflect` -> `shield`
  (a 13th Piece Buff changed `_random_buff_key`'s modulo). Both updates were legitimate and
  were verified rather than rubber-stamped, but the assertion will keep breaking on any
  change to buff-pool size or RNG-stream position, and each break is an invitation to
  "update the expected value until it passes" — which is how a real regression gets buried.
  The behaviour under test is *"Holy Lint grants exactly one Piece Buff"*; the specific key
  is incidental. Reshaping it to assert `size() == 1` plus membership of the safe
  non-self-triggering set would keep all its value and stop the churn. Cheap, not urgent.
- ~~**The click probes carry a load-sensitive stall.**~~ Fixed 2026-08-30
  (`fix/click-probe-stall`). Worth keeping for the mechanism, which nobody would guess:
  `game.gd` freezes the enemy turn **indefinitely** while `backgrounded` is set
  (`_wait_while_backgrounded`, slice 06) — deliberately unbounded, because a real player
  might tab away for minutes, and covered headlessly by `test_background.gd`. The click
  probe drives a **real OS window**, so on a busy machine the window manager delivers a
  genuine `WM_WINDOW_FOCUS_OUT` with no matching FOCUS_IN, and the enemy turn simply sits
  frozen past the probe's 4s poll. **Nothing was ever stalling** — the game was correctly
  obeying a feature the probe had no business triggering, since it drives every click via
  synthetic `push_input()` and has no real "player tabbed away" to honour.
  Fix is **probe-side only**; `game.gd` untouched, so this was never player-facing.
  Two hypotheses were refuted along the way and both are worth remembering as cautionary
  tales: it was **not** the per-turn autosave write (measured 0.000-0.135s even on failing
  runs, and it reproduced in a segment where that branch never ran), and it was **not**
  introduced by slice 49 (see that issue's Outcome — batched A/B comparisons across
  different machine load produced a confident wrong answer). The confirming measurement was
  **interleaved**: 30 alternating before/after runs in one continuous load session,
  3/30 failures -> 0/30.

## Cards whose text overpromises what shipped

- ~~**Zapruder's Director's Cut says "repeat your previous Action"** but only repeats a
  **move or capture**~~ — resolved 2026-08-30 (issue 56, user redesign). The card now
  COMPLEMENTS the move/capture replay instead of leaving the other 3 kinds dead: an Item use
  returns the Item, a Deploy returns the piece to Stock, and a Merge returns both consumed
  pieces to Stock. Bomb/Trap/blocked-attack captures still carry no `{from, to}` and stay
  correctly unavailable — that part of the original flag was never in scope to fix. Re-texted
  in `data/artefacts.js`.
- **Abduction Probe / Manna Vending Machine vs the new caps.** The base caps introduced in
  issue 53 (Items 3, Piece Buffs 2) quietly weakened two already-shipped Artefacts: Manna
  Vending Machine grants **+2 Items**, wholly wasted at a full inventory of 3, and Fort Knox
  IOU's +1 Tactical Item has the same exposure. Not a bug — a tight cap is what makes Area
  51 Parking Permit and Denver Bunker Timeshare meaningful — but worth a look in the tuning
  pass rather than discovering it in a playtest as "Manna feels broken".

## Housekeeping

- **`tools/generate-piece-art.py` is mostly orphaned.** It generated the 38 svg tokens
  that the painted PNGs replaced; it now only produces `king.svg`. Delete it once King
  art lands, or keep it as the fallback generator and say so in its header.
- ~~**`data/artefacts.js` and `game/data/` have no shared pipeline yet.**~~ Built by slice
  14: `tools/export-game-artefacts.mjs` generates `game/data/artefacts.json` from
  `data/artefacts.js`. The "game hand-writes 7" era is over — those 7 survive as
  `ARTEFACT_EFFECTS_CORE` (they pre-date the catalog and have no Notion equivalent), and
  everything else flows through the exporter. **`game/data/artefacts.json` is generated;
  never hand-edit it.**
