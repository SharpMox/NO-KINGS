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
- ~~**Two source filenames are wrong**~~ — fixed by the user 2026-08-30, verified:
  `Dragonlord-Dark.png` and `Quetzalcoatl-Light.png` are now correct in the designs folder.

## Balance / tuning, unvalidated

- ~~**Shop restock thresholds may be unreachable.**~~ Fixed by issue 57 (Score x10). Post-slice
  autoplay scores 68700 / 75200 / 72800 across full runs against a first threshold of 1000 —
  every run cleared it, several banked 5-6 restocks. The median-300 problem is gone.
- **Buff Box is priced Strategic (60 Gold) on reasoning, not playtesting.** It is a
  lottery over three buffs and can hit a Decisive one, which is why it sits above
  Tactical. Revisit once buffs have actually been played.
- ~~**Enemy actions per turn is 1, GDD says 2**~~ — divergence #2, resolved by issue 59
  (user ruling): **baseline stays 1, Tier 5 restores the GDD's 2.** The GDD value became the
  top-difficulty value rather than the default. Notion's Enemy AI Behaviors page reconciled;
  issue 11 closed as moot.

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

## Standing design principles (user rulings — read before triaging a "bug")

- **Big interactions stay. At worst cap them, never remove them.** User, 2026-08-30, on the
  buy/sell loop around Deep State Yearbook and Mao's Loyalty Badge:

  > *This kind of interaction is big for players so we want to keep those anyway, at worst we
  > cap them but never remove.*

  This changes how a finding should be triaged. When something looks exploitable, the question
  is **"what bounds it?"**, not "how do we close it?" — and if the answer is "nothing", the
  fix is a **cap**, not a deletion. Two findings this session were framed as exploits needing
  closure and both turned out to be bounded interactions worth keeping: the buy/sell loop
  (bounded by `not slot.sold`, Score-gated restocks, and the Artefact cap making Deep State
  Yearbook's payout a guaranteed net loss) and Mao's Loyalty Badge (break-even, bounded by
  4 Item slots per stock and the Item cap).

  The corollary: **do not propose removing an Artefact because it combos well.** Propose the
  bound.

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

- **Holding duplicate Artefacts to stack them — intended, or a bug?** User, 2026-09-01:
  *"feels like a bug, lets leave it for now but note it down."* **Not actioned; recorded.**

  What the code says today: it is deliberate, documented and tested. `artefact_hooks.gd`'s
  header specifies it — *"the same artefact can be held more than once; each copy is its own
  entry in `g.artefacts`. `run()` dispatches once per held copy, so percentage/flat modifiers
  from repeats are ADDITIVE"* — with the reasoning that additive-per-copy is the simplest
  behaviour to reason about across 180 Artefacts, and that a multiplicative one would be a
  called-out exception inside its own handler. `run()` also key-sorts so the result never
  depends on acquisition order (issue 20).

  It is load-bearing in at least four places, which is why this is not a small revert:
  `test_items_artefacts_1.gd` asserts *"two Library of Alexandria Matchboxes stack
  additively"*; slice 81 ships a board for **two Snowden copies stacking rerolls**;
  **Abduction Probe** raises the Piece Buff cap **+1 per held copy** (issue 53's ruling, and
  see issue 99 — the effects that push past the cap were deliberately kept on 2026-09-01);
  and the standing principle *"big interactions stay, at worst cap them, never remove them"*
  points at bounding it rather than removing it.

  So if it is judged a bug, the fix is most likely a **cap on copies** (or on the stacked
  magnitude), not de-duplication at dispatch — de-duping would silently change four shipped
  behaviours and one shipped scenario board. Worth a deliberate decision in the balance pass
  rather than an incidental one.

- **The `suppresses` declarations of issue 94 are unverified, and a mistake in one is
  invisible.** Grilled 2026-09-01: the slice ships hand-written `fires`/`suppresses` lists
  on the 42 Item/Buff/Army effects with **no test proving them true** (user ruling — the
  generated boards are their own check). That is fine for `fires`, where a wrong line makes
  a board where nothing happens and you notice on opening it. It is not symmetric for
  `suppresses`: a wrong entry there describes an effect silently no-op'ing, and the whole
  point of that relation is that nothing happens *and nothing reports it*. Nothing consumes
  `suppresses` yet, so this costs nothing today — but the anti-combo slice that eventually
  reads it inherits an unchecked map. The cheap fix if it ever bites is the trace already
  sketched in 94's grilling: ~5 lines in `ArtefactHooks.run` recording fired hook names,
  and `g._use_item(0)` (already used throughout `test_items.gd`) to drive each producer.

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
- **SUPERSEDED 2026-09-02 by issue 103 — read this first.** The table below was produced by a
  bot that **never opened the Shop** (0 buys, 0 sells, 0 conversions across 90 runs, dying of
  "resource starvation" on a median of 1640 unspent Gold). After teaching it to buy and
  convert, the same 90 runs went **5 wins -> 55, with 15 FULL CLEARs**. Tier 1 went 0 -> 15
  wins, Tier 4 1 -> 13. **Tier 5 barely moved: median wave 8.0 -> 9.5, still 0/18** — so Tier
  5's difficulty is real and the rest of the ladder's was mostly the instrument. Also: **Tier
  1 and Tier 2 are byte-identical** in both batches, because Tier 2's only lever is
  `clock_never_pauses` and the bot opens no menus — Tier 2 is unmeasurable by autoplay by
  construction. Re-measure with `tools/playtest.sh` before tuning anything.

- **Tier 5 is unwinnable, and the gap to Tier 1 is now enormous.** Re-measured 2026-08-31,
  after the Score x10, Clock-to-15 and enemy-2-Actions changes all landed:

  | | wins | median wave |
  | --- | --- | --- |
  | **Tier 1** (6 runs) | **4 — all by checkmating the Wave-50 King** | 50 |
  | **Tier 5** (8 runs) | 0 | **8.5** |

  Tier 5 dies at wave 8 while Tier 1 finishes the game. Every Tier-5 loss but one was resource
  starvation; the exception was a back-row breach at wave 11.

  The earlier reading (median 38.5 -> 9.5, 0/24) is superseded — the shape is the same but the
  spread between tiers is far wider now, because slice 78 raised the Clock to 15 minutes at
  Tiers 1-2 while Tier 3+ keeps 5. That was the intent, so this is the lever working; the open
  question is whether a 50-vs-8 spread across five rungs is the *distribution* wanted, or
  whether the middle rungs need to carry more of it. Measurement, not a verdict — the user has
  parked tuning until every lever is coded, and Kings are the last one.
- ~~**Holy Lint's pinned-seed assertion names a specific granted buff**~~ — fixed 2026-08-31.
  It churned **twice** (`stun` -> `reflect` when issue 47 moved the RNG stream by rolling Box
  contents at boot; `reflect` -> `shield` when issue 48 added a 13th Piece Buff and changed
  `_random_buff_key`'s modulo). Each update was verified rather than rubber-stamped, but every
  break was an invitation to "update the expected value until it passes" — which is how a real
  regression gets buried inside a rename.
  Now asserts the **behaviour**: exactly one Buff granted, and not one of the self-triggering
  hazards (`bomb`/`trap`/`multicapture`) that would resolve during the very capture that
  granted it. Immune to stream shifts and pool-size changes by construction — and it now
  *enforces* the hazard check that was previously only a comment a human had to re-read.
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

## Test traps found by the HUD redesign (2026-09-05, issue 106)

Four of these were tests that passed for the wrong reason or hid a real overlap. They cost
most of a day between them, and every one is the kind that comes back.

- **A probe can pass because its click was CONSUMED.** `test_game_clicks` proved the choice
  modal blocks board input by clicking tile (2,2). Once the board moved, that coordinate sat
  under the modal's own option buttons, so the click PICKED an option and closed the modal —
  and the assertion still passed, because a consumed click leaves `selected` untouched either
  way. It now clicks a tile over the backdrop and additionally asserts the modal survived.
- **`test_menu_clicks` leaves a Game instance in the tree while testing the Menu.** The probe
  rebuilds the menu after the scenario click's scene change but never freed the game that
  change created, so the game's HUD has always been drawing over the menu. Invisible while
  the HUD's only bottom control was a 42px bar at y754; the new deck reaches y524 and started
  swallowing the menu's own Back button at y540. The two never coexist in the real app.
- **Hardcoded tile coordinates in drag tests are geometry assertions in disguise.** The
  "drop inside the open drawer places nothing" guard stopped testing anything when drawers
  moved above the deck; it now FINDS a tile the drawer actually covers.
- **A failure you can explain is not a failure you have diagnosed.** A suite SIGTERM was read
  as window-focus contention — which was real and self-inflicted — while a genuine infinite
  loop sat underneath it. Binding a rebuild to Godot's `resized` is a feedback loop when the
  rebuild changes its own children: `test_scenarios` hung with 2.7M lines of "Object was
  deleted while awaiting a callback".
- **Leaving a game window open makes every windowed probe flaky.** Kill stray `godot --path`
  processes before running suites; two runs were lost to a window left open for review.

## Layout lessons the device taught (2026-09-05)

- **A control that measures itself before layout will cache nonsense.** The stock strip sizes
  its rows from its own width, which arrives a frame or two after build. At 13px wide it
  concluded one tile fitted, drew nothing, and cached that under a signature that never
  changed — "Stock 21" with a "+21" chip and no pieces, permanently, on the phone. Desktop
  hid it twice: a fresh run has Stock 0, and when there were pieces a stray refresh happened
  to recompute it. Wait for a sane width, retry bounded, never bind to `resized`.
- **Centring content in a span splits empty space into two gaps.** Flush to one edge puts all
  the slack in one place where something can absorb it. This is why the board is pinned under
  the top strip rather than centred.

## Cards whose text overpromises what shipped

- ~~**Zapruder's Director's Cut says "repeat your previous Action"** but only repeats a
  **move or capture**~~ — resolved 2026-08-30 (issue 56, user redesign). The card now
  COMPLEMENTS the move/capture replay instead of leaving the other 3 kinds dead: an Item use
  returns the Item, a Deploy returns the piece to Stock, and a Merge returns both consumed
  pieces to Stock. Bomb/Trap/blocked-attack captures still carry no `{from, to}` and stay
  correctly unavailable — that part of the original flag was never in scope to fix. Re-texted
  in `data/artefacts.js`.
- **Fort Knox IOU vs the Item cap.** Issue 53's base Item cap of 3 means its *"+1 Tactical
  Item on Wave clear while under 10 Gold"* is silently dropped at a full inventory. Manna
  Vending Machine had the same exposure and was **fixed** by issue 58 (it now opens a Big Item
  Box, so a full inventory becomes a choice rather than a dropped grant) — Fort Knox could take
  the same treatment if it bothers anyone. Selling (issue 60) also gives the player a way to
  make room, which softens it.

## Housekeeping

- ~~**`tools/generate-piece-art.py` is mostly orphaned.**~~ Resolved 2026-08-31 by taking the
  second branch the flag itself offered: King art has **not** landed (only `king.svg` exists;
  `dragon-king-*.png` is a different piece), so the generator stays as the fallback and its
  header now says so — including the trigger for deleting it later, which is
  `king-light.png`/`king-dark.png` arriving.
- ~~**`data/artefacts.js` and `game/data/` have no shared pipeline yet.**~~ Built by slice
  14: `tools/export-game-artefacts.mjs` generates `game/data/artefacts.json` from
  `data/artefacts.js`. The "game hand-writes 7" era is over — those 7 survive as
  `ARTEFACT_EFFECTS_CORE` (they pre-date the catalog and have no Notion equivalent), and
  everything else flows through the exporter. **`game/data/artefacts.json` is generated;
  never hand-edit it.**

## Review passes 2026-09-06 (PRs #313, #314, #315) — what was NOT fixed

- **Once-per-Wave activation flags are not persisted**, so quit-and-Continue re-arms them
  mid-wave: `zapruder_used_this_wave`, `bovine_used_this_wave`, `jet_fuel_used_this_wave`,
  `uap_used_this_wave`, `torpedo_used_this_wave`, `hoffa_used_this_wave`, `arks_bunkbed_used`,
  `salvation_charged`, plus the run-long streaks `nibiru_wave_streak` / `club27_streak` /
  `lottery_purchase_count`. game.gd's own comments call this an "accepted existing gap";
  it is now also a save-scum path for six player-triggered Artefacts. Each is one additive
  save field away from closed (`army_ability_used_this_wave` shows the shape). Decide whether
  save-scumming is a problem before spending the fields.
- **The check-resolution path costs ~5 ms** on a 12-a-side board with the enemy King in
  check (`Rules.legal_moves(strict=true)`, measured headless). The cost is move generation
  in `is_attacked`, not the board copy (a shallow copy changed nothing). Only reachable on
  King waves and only when the King is actually attacked, so it is one frame at worst. If
  King waves ever stutter, the upgrade is an attacker/pin pre-filter, not micro-optimising
  `moves_for`.
- **`hud.refresh()` rebuilds all four strips on every refresh** (~1.7 ms measured with a
  10-piece Stock), including strips inside a hidden drawer. Gating them on drawer visibility
  is blocked by suites that assert on `activate_box`/`item_box` child counts with the drawer
  closed (`test_items_artefacts_4.gd`, `test_shop.gd`). Not worth the test churn at 1.7 ms.
- **`Kings.power_hook` still runs on query hooks** (`on_price`, `on_place_cost`,
  `on_merge_check`), which is correct — Qin Shi Huang's wall and Genghis Khan's no-merge are
  legitimately modifiers — but it means a King Power is the one thing that can still add
  state-dependent behaviour to a read path. Keep Powers pure on those three hooks.
