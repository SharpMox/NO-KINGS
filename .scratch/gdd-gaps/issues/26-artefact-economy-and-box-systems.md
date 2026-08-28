# 26 — Artefacts: economy, Shop, Box and misc small systems

Status: done (partial — 15 of ~39 rows; see Outcome)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Split out of

19 — the long tail left over after the cheap shared hooks (on_piece_lost,
on_item_consume, on_rank_up, on_tariff_apply/charge) and the 4 other themed
splits (21-25). Genuinely a grab-bag — each row below is its own small
system, most touching one file, none sharing a hook with another row here.
Triage each independently when picked up; don't force a shared abstraction
that doesn't exist yet.

## What to build

| Artefact | Needs | Note |
| --- | --- | --- |
| Area 51 Parking Permit | item cap | "+3 Item held capacity" — `items` has no cap today (unbounded); needs the cap to exist first |
| Denver Bunker Timeshare | item cap | "+30% Gold while all Item slots full" — same prerequisite, reads the cap rather than raising it |
| HAARP Volume Knob | spawn modifier | "Waves spawn +1 extra piece; on Wave clear: +200 Score, +15 Gold" — the Score/Gold half is cheap (on_wave_clear, already wired); the spawn half needs `WaveLogic.queue`'s roster-building to consult `g.artefacts` |
| Pigeon Charging Cable | spawn modifier | "Waves spawn 1 fewer piece" — same prerequisite, other direction (floor at 0? at 1?) |
| Wuhan Vial Label | spawn modifier | "Waves spawn +1 extra piece; Captures +25% more Gold" — the Gold half is cheap (on_capture); spawn half shares Wuhan/HAARP/Pigeon's prerequisite |
| Bible Gag Reel Scroll | box reroll | "On Box Pick: reject the contents once and reroll" |
| Snowden's Rubik's Cube | box reroll | "Once per Box: reroll the offered Picks" — near-identical to Bible Gag Reel Scroll; triage together |
| All-Seeing Eye Contact Lens | combined box UI | "Box Picks show all 3 box types' contents at once" — a UI change to the Box modal, not a hook |
| Trojan Horse Assembly Manual | box grant | "On 5-Wave Milestone: open a free Box" — cheap once `_open_box_pick` can be invoked from a hook context instead of only player input (check it doesn't assume a synchronous player action) |
| Nostradamus Mad Libs | box multi-pick | "On opening a Box: +1 extra pick" — `_box_options`/the pick UI hardcode option counts, same shape as Numbers Station Sudoku (issue 23) but for item/piece Boxes, not Buff Boxes |
| Pre-Scratched Lottery Ticket | purchase counter | "Every 5th Shop purchase: free" |
| Pandemic Toilet Paper Pallet | purchase counter | "Every 2nd purchase in the same Shop visit: 50% less" — **"Shop visit" is a retired term** (issue 18's Outcome: the Shop has no discrete visit/session boundary in this codebase's economy) — ask Notion whether this re-texts to "every 2nd purchase this Wave" or similar before touching it |
| Jet Fuel Vial | reroll system | "Once per Shop visit: pay 20 Gold to reroll the whole Shop stock" — same retired-term question as above |
| Agartha Welcome Mat | credit system | "Shop purchases can take your Gold negative, down to -100" — `gold` is clamped to `maxi(x, 0)` in several places (charge, tariffs); a credit system means auditing every one of those clamps |
| FIFA Complimentary Yacht | gold-action exchange | "spend 50 Gold for +1 Action, any number of times per Turn" — a player-initiated action (new UI affordance), not a passive hook |
| Oak Island Wishing Well | gold sink action | "Once per Turn: pay 25 Gold for +400 Score" — same shape, capped once/Turn |
| Templar Debit Card | score payment | "pay Shop costs with Score, 10 Score per 1 Gold" — Shop.buy assumes Gold; a whole alternate payment path |
| Hitler's Argentinian Passport | free-deploy rule | "Deploying doesn't spend an Action" — `_place`'s `actions_left -= 1` would need an artefact-conditioned skip |
| Nazca Boarding Pass | free deploy placement | "Deploy onto any empty square" — `_setup_open_tiles`/placement legality currently restrict to `PLAYER_ZONE_ROWS`; this lifts that restriction |
| Hellfire Club Discord Invite | forced-action rule | "+2 Actions/Turn, but can't Pass while Actions remain" — the +2 is cheap (on_turn_start, already wired); the Pass-lock is a new UI/legality rule on the Pass button itself |
| Zero-Point Energy Drink | gold threshold hook | "On reaching exactly 0 Gold: +2 Actions that Turn" — needs a check at every Gold-spending site (charge, Shop.buy, tariffs), not just on_gold_change (which only fires on gains) |
| Doomsday Clock Snooze Button | threshold hook | "First time Clock drops below 30s each Wave: +25s" — the Clock ticks in `_process`, continuously, not through a discrete hook; needs a per-frame or per-turn watch, a different shape from every hook in `ArtefactHooks` today |
| Black Knight Morse Code | turn counter | "Every 3rd Turn: Score/Clock gains that Turn are doubled" — a new turn-index counter plus a flag threaded through on_score_change AND clock-gain sites (which don't have a hook at all today) |
| Loch Ness Stool Sample | score threshold | "Every 1000 Score gained: open a random Piece Box" — a cumulative-since-last-trigger watch on `g.score`, same "continuous threshold" shape as Doomsday Clock Snooze Button |
| Cicada Rejection Letter | decline option | "On declining a Box Pick: +Gold equal to the Shop value of the offered pieces" — Box Pick has no "decline" path today (every open resolves to a pick); a new UI affordance |
| Yalta Cocktail Napkin | choice UI | "On 5-Wave Milestone: choose one — +100 Gold / +1 Item / +15s Clock" — a modal choice, same UI shape as Exhibit 399 (issue 22) and Inflatable Vietcong Torpedo (issue 24); worth a shared "artefact choice modal" if 3+ of these land together |
| Epstein's Black Book | consumable artefacts | "On your next Box Pick: take all 5 contents; then this Artefact is consumed" — no artefact has ever self-removed from `g.artefacts` before; needs that removal path plus a "pending" flag surviving to the next Box open |
| Moscovium Glow Stick | consumable artefacts + gain multiplier | "On use: until end of Turn, Score/Gold gains tripled; then consumed" — stacks Epstein's self-consume prerequisite with Déjà Vu Glitch's gain-multiplier shape (issue 21); also introduces "activate an Artefact" as a player action, which nothing else in the catalog does |
| $2.3 Trillion Receipt | destroy-score hook | "Enemies destroyed by Items award their Score/Gold value" — `_destroy` deliberately pays nothing (its own doc comment: "no score, no captured stock"); this asks for an artefact-conditioned exception there |
| 27 Club Punch Card | streak tracking | "+5% Score/Wave cleared without losing a piece; resets and -50 Score on loss" — issue 16 already ruled the loss-penalty debits Gold not Score for its sibling (Social Credit Report Card); the same ruling likely applies here — confirm on Notion, then it's on_wave_clear (streak-building) + on_piece_lost (reset), both already-wired hooks (issue 19) |
| 'Definitely Not Russia' Patch | loss masking | "The first piece you lose each Wave doesn't count as a loss for your Artefacts/penalties" — needs on_piece_lost (issue 19, have it) to SUPPRESS other artefacts' own on_piece_lost handlers for that one event — an ordering/veto problem between artefacts, not a simple additive handler |
| Jon Burrows' Fake ID | per-wave loss tracking | "On Wave clear: the first piece lost that Wave returns to Stock" — needs a per-Wave "first lost piece" record (id + reset at Wave start), distinct from the run-wide `lost_player` counter |
| Walt's Cryonic Capsule | loss tracking + stock return | "On Wave clear: the LAST piece lost that Wave returns to Stock" — same prerequisite as Jon Burrows' Fake ID, opposite end; triage together |
| Ark's Bunkbed | piece duplication | "On buying a Piece: a second copy joins Stock; once per 5-Wave Milestone" — on_purchase (have it) + a milestone-scoped recharge flag |
| Zeta Reticuli Souvenir Map | capture conversion | "Every 3rd Capture: the captured piece goes to Stock instead of Captured Stock" — on_capture's ctx is discarded by `Economy.capture_score`'s `-> int` return signature before it reaches `_move_player`'s `captured.append(victim.id)` line; needs that return contract widened (or a second out-param) to carry a redirect flag — Stockholm Syndrome Pamphlet (issue 19, shipped) is this same system's cheap on_wave_clear half |
| Elvish Hard Hat | action-type tracking | "First Action of the Turn is an Item or ability: [effect]" (issue 17's held-back note) — no action-type tag exists at the point actions are spent; "ability" is also undefined separately from "Item" in the current data model |
| Nuclear Football Menu | cost exemption | "Items don't spend an Action under 60s Clock" (issue 17's held-back note) — a cost EXEMPTION, not a hook-triggered grant; means branching `_item_apply`'s action-cost line directly |
| Mar-a-Lago Toilet Papers | stateful shop discount | "On 5-Wave Milestone: a random Shop item becomes free; all other prices +10%" (issue 18's held-back note) — genuinely stateful (which slot stays free across a restock?) and underspecified whether +10% stacks per milestone, forever, or resets |
| Dark Market Light Bulb | Demoted-piece state | "Ranked pieces give double Gold; Demoted pieces give no Score" (issue 16's held-back note) — the Ranked half is now cheap (`ItemLogic.chain_base`, issue 19); "Demoted" has no distinguishable state (a demoted piece looks identical to one that was never promoted) — Notion question: is "Demoted" trackable at all, or does this artefact's text need to change? |

## Acceptance criteria

- [x] Re-group this table at pickup time — several rows (box reroll pair,
      loss-tracking pair, spawn-modifier trio, choice-UI trio) are cheap
      once their ONE shared prerequisite lands; don't reopen each as a
      separate design question — done for the spawn-modifier trio and the
      loss-tracking pair (both shipped, see Outcome); the box-reroll pair and
      choice-UI trio's shared prerequisite is a new UI affordance, which
      stayed out of scope this pass (see Outcome) — still one triage
      decision each, not reopened individually
- [ ] "Shop visit" is retired — Notion ruling needed before Pandemic Toilet
      Paper Pallet or Jet Fuel Vial are touched at all — still open, neither
      touched
- [ ] Dark Market Light Bulb: Notion ruling on whether "Demoted" is
      trackable state or a text change — still open, not touched
- [x] Scenario coverage, `run_all.sh` all green — see Outcome

## Blocked by

- 15 — trigger engine
- 19 — Special + prereq triage (this file is one of its splits)

## Outcome

15 of the ~39 rows shipped (`implemented: true`, wired in
`game/scripts/artefact_hooks.gd`); the rest stayed `false` — either a new
player-facing UI affordance (button, modal, alt payment path) that this pass
didn't build, or a genuine ambiguity that belongs on Notion, not guessed into
code. Quality over count, per the slice brief.

### Shipped (15)

- **Spawn-roster trio** (on_wave_roster, already wired for Trade War — issue
  13's own prerequisite, not a new one): HAARP Volume Knob (+1 piece, +200
  Score/+15 Gold on Wave clear), Wuhan Vial Label (+1 piece, +25% Gold on
  Capture off the capture's own base), Pigeon Charging Cable (-1 piece,
  floored so a Wave never spawns zero non-King pieces).
- **Shop purchase counter**: Pre-Scratched Lottery Ticket. The "every 5th
  purchase free" text is an absolute override applied after Shop.price's
  on_price composition finishes, not a percentage handler inside it — a
  later-sorting discount artefact adding to a forced-to-0 `ctx.amount` would
  go negative (see the comment in `shop.gd:price`).
- **Free-deploy / free placement**: Hitler's Argentinian Passport
  (`on_deploy` grew `ctx.skip_action`), Nazca Boarding Pass (no hook — a
  standing rule read off `g.artefacts` in a new `game.gd:_deploy_tiles`
  helper, the same no-hook pattern chocolate-key-cake already uses).
- **Cost exemption**: Nuclear Football Menu — a single call site
  (`_item_apply`'s action-cost line), no hook needed.
- **Per-frame threshold watch**: Doomsday Clock Snooze Button. The Clock
  ticks in `_process` every frame, continuously — no discrete hook fires on
  a threshold cross, so this is a direct watch (`_held` + a per-Wave "already
  spent" flag) at that one call site, same no-hook reasoning as Nazca/Nuclear
  Football Menu above.
- **"5-Wave Milestone" grants** (on_wave_clear + `g.wave % 5 == 0` —
  silk-road-coupon/crop-circle-plank's cadence, a different one than
  `on_milestone`'s own 10-wave Clock-refill trigger; the issue table's
  reference to "milestone" was this cadence, confirmed against the existing
  precedent, not the hook of the same English word): Ark's Bunkbed (piece
  duplication, once per window), Trojan Horse Assembly Manual (a free Box —
  `_open_box_pick` turned out already safe to call from a hook dispatch,
  guarded against clobbering an already-open Box Pick).
- **Per-Wave first/last-lost tracking** (`g.wave_lost_ids`, reset in
  `WaveLogic.queue`, appended centrally in `_lose_player_piece`): Jon
  Burrows' Fake ID (first), Walt's Cryonic Capsule (last).
- **Score-gain streak**: 27 Club Punch Card (`g.club27_streak`, built off
  `on_wave_clear`'s existing `ctx.clean` rather than reinventing Nibiru
  Hide-and-Seek Trophy's own streak logic) — its -50 Score penalty re-texted
  to -50 Gold, the same issue-16 ruling Social Credit Report Card already
  carries (Score is up-only).
- **Gold reaching exactly 0**: Zero-Point Energy Drink. Required a new
  choke point — `economy.gd`/`shop.gd`'s `spend_gold` — since Gold is spent
  from 3 different call sites (`Economy.charge`, `Shop.buy`, the deploy-cost
  line in `game.gd:_place`) and none of them previously shared one. New
  `on_gold_zero` hook, fires once per spend that lands exactly on 0 Gold not
  already there.
- **Gold floor on Shop purchases**: Agartha Welcome Mat. Scoped exactly to
  its own text ("Shop purchases can take your Gold negative") — `Shop.buy`
  passes a -100 floor and `Shop.can_buy` extends its afford check by the
  same 100, not a change to `charge()`/tariffs/deploy cost. `shop.gd`
  can't call `Economy.spend_gold` directly (`economy.gd` already preloads
  `Shop`; a preload back would cycle), so `Shop.buy` inlines the same 3
  lines — noted in both places so they don't drift apart.

### Left `implemented: false` (~24) — why

- **Item cap** (Area 51 Parking Permit, Denver Bunker Timeshare): the
  prerequisite isn't "add a cap," it's "what's the baseline cap before any
  artefact modifies it" — no number for that exists anywhere in the GDD
  text extracted for this issue. Guessing a baseline changes core economy
  balance for every run, held artefact or not. **Notion question.**
- **"Shop visit" retired term** (Pandemic Toilet Paper Pallet, Jet Fuel
  Vial): unchanged from issue 18/19/the table's own note — still blocked on
  a ruling, still not touched.
- **New player-facing UI** (a real new affordance or a legality change to
  an existing control, not just a hook): box reroll (Bible Gag Reel Scroll,
  Snowden's Rubik's Cube), combined box UI (All-Seeing Eye Contact Lens),
  box multi-pick (Nostradamus Mad Libs), box decline (Cicada Rejection
  Letter), choice modal (Yalta Cocktail Napkin), gold-for-actions button
  (FIFA Complimentary Yacht), gold-sink action button (Oak Island Wishing
  Well), alt Shop payment currency (Templar Debit Card), a Pass-button
  legality lock while Actions remain (Hellfire Club Discord Invite — its
  own +2 Actions/Turn half is cheap, on_turn_start, but shipping only that
  half would silently drop the artefact's actual cost). None of these fit
  CLAUDE.md's "UI first, bypasses second" rule inside a hook-focused pass —
  each needs its own click-probe coverage and belongs in a UI-scoped
  follow-up, ideally batched (the choice-UI trio named in the table shares
  one modal design).
- **Loch Ness Stool Sample** ("open a random Piece Box"): "Piece Box" isn't
  a real Box kind in this codebase — `Box.roll_options`/`_box_choose` only
  ever resolve to item/artefact/score, never a piece grant. Implementing
  this means inventing a new Box-content kind, not wiring an existing one.
  **Notion question**: is a Piece Box worth adding as a real kind, or does
  this artefact's text change to one of the 3 existing kinds?
- **Zeta Reticuli Souvenir Map** ("every 3rd Capture: Stock instead of
  Captured Stock"): `_move_player` has 4 separate `captured.append(...)`
  sites (normal capture, bomb, trap, multicapture), each with different
  control flow and some early-returning. Redirecting all 4 consistently is
  real surface area with real edge-case risk for one artefact; Stockholm
  Syndrome Pamphlet (issue 19) already shipped this system's cheap
  wave-clear half, so only the per-capture half is still open.
- **Consumable artefacts** (Epstein's Black Book, Moscovium Glow Stick):
  "an Artefact removes itself from `g.artefacts`" plus, for Moscovium,
  "activate an Artefact" as a brand-new player action — two pieces of
  architecture nothing else in the catalog needs yet. Out of scope for a
  pass that's otherwise wiring existing hooks.
- **Dark Market Light Bulb**: unchanged from issue 19's own note — no
  "Demoted" state exists or can exist without new tracking. Still a Notion
  question, still not touched.
- **'Definitely Not Russia' Patch** ("the first piece you lose each Wave
  doesn't count... for your Artefacts and penalties"): needs one artefact's
  `on_piece_lost` handler to veto every *other* held artefact's own
  `on_piece_lost` handler for that one event — the ORDERING section of
  `artefact_hooks.gd`'s header exists specifically to keep handlers
  commutative for a fixed multiset of keys; a veto is the opposite of that
  guarantee and the engine has no mechanism for it today.
- **$2.3 Trillion Receipt** ("Enemies destroyed by Items award their Score
  and Gold value"): `_destroy`'s own doc comment says "no score, no
  captured stock" — deliberately. An artefact-conditioned exception to a
  documented deliberate design decision is a bigger call than this pass's
  scope, and worth confirming the decision still holds before coding
  around it.
- **Mar-a-Lago Toilet Papers** ("a random Shop item becomes free; all other
  prices +10%"): genuinely stateful and underspecified per the table's own
  note — which slot stays free across a restock, and whether +10% stacks
  per Milestone, forever, or resets. **Notion question**, not a guess.
- **Everything else needing its own new call site with real edge-case
  surface** left alone rather than half-implemented: Elvish Hard Hat
  ("ability" is undefined separately from "Item" in this data model — itself
  a Notion question) and Black Knight Morse Code (a turn counter plus
  clock-gain sites that have no hook at all today).

### Tests

`game/tests/test_items.gd` gained 27 checks across all 15 shipped
artefacts, including 6 explicit controls (a tile normally illegal without
Nazca, the same Item costing an Action at full Clock without Nuclear
Football Menu, no duplicate before/after Ark's Bunkbed's Milestone window,
the middle of 3 losses returning to neither Jon Burrows' nor Walt's Stock
grant, Gold landing exactly on 0, and the same Shop purchase blocked
without Agartha's credit line). `game/data/scenarios.gd` gained "Artefacts:
economy & Box batch (issue 26)" holding all 15 keys together, swept by
`test_scenarios` and the full autoplay run. `game/tests/run_all.sh` — ALL
GREEN (windowed click probes, headless suites, autoplay).
