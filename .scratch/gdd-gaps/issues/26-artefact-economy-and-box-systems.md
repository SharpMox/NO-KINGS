# 26 — Artefacts: economy, Shop, Box and misc small systems

Status: todo

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

- [ ] Re-group this table at pickup time — several rows (box reroll pair,
      loss-tracking pair, spawn-modifier trio, choice-UI trio) are cheap
      once their ONE shared prerequisite lands; don't reopen each as a
      separate design question
- [ ] "Shop visit" is retired — Notion ruling needed before Pandemic Toilet
      Paper Pallet or Jet Fuel Vial are touched at all
- [ ] Dark Market Light Bulb: Notion ruling on whether "Demoted" is
      trackable state or a text change
- [ ] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine
- 19 — Special + prereq triage (this file is one of its splits)
