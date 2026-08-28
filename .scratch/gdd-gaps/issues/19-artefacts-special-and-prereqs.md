# 19 — Artefacts: Special, and the prerequisite backlog

Status: partial — 29 of 121

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

The long tail: the **Special (41)** tag, plus the **86 artefacts whose text carries an
explicit `(needs: …)` note** — the catalog authors flagging a system that does not exist.

Grouped, the missing systems were roughly (table as it stood at triage time —
see the Outcome below for what actually shipped, what split out, and the
final counts, which drifted a little from this original estimate: 83
`(needs: ...)` artefacts + 41 Special-tagged, 87 distinct after the overlap,
plus 16 more that issues 16/17/18 had already held back without a literal
`(needs: ...)` note — 103 total, not 86):

| Needed | Artefacts | Notes | Resolution |
| --- | --- | --- | --- |
| spawn modifier | 3 | change what a wave spawns | split → issue 26 |
| item cap | 2 | held-item capacity is currently unbounded | split → issue 26 |
| zone check | 2 | "while in your zone" positional predicate | **shipped** (board-half read, no new hook) |
| purchase counter | 2 | per-run purchase tally | split → issue 26 (blocked on a "Shop visit" Notion question) |
| shop layout change | 2 | needs slice 08 | already resolved by issue 18 |
| box reroll | 2 | re-roll an open Box Pick | split → issue 26 |
| enemy auto-debuff | 2 | slice 04's buffs, applied by the game | **shipped** (BuffLogic is owner-agnostic already) |
| chain lookup | 2 | promotion-chain queries — `ItemLogic.chain_base` is the seed | **shipped**, plus 3 more artefacts than expected (Templar Severance Gold, CIA Heart Attack Gun, Bigfoot Toenail Clipping) |
| capture conversion | 2 | turn a captured piece into an ally | **half-shipped** (Stockholm Syndrome Pamphlet, on_wave_clear); Zeta Reticuli Souvenir Map split → issue 26, blocked on `capture_score`'s return contract |
| artefact echo | 2 | re-trigger another artefact | split → issue 21 (grew into a 14-artefact meta-trigger system once triaged) |
| streak / loss / gold-threshold / rank / deploy hooks | 1 each | mostly slice 15 hooks | on_rank_up **shipped**; on_piece_lost **shipped** (bigger than expected — 8 artefacts); streak/gold-threshold/deploy split → issue 26 |

**Do not build these blind.** Each row is a small system, and several are one line of
catalog text away from being a slice of their own. The work here is:

1. Triage the 86 by prerequisite, using the table above.
2. Implement the cheap shared ones — most of the "hooks" collapse into slice 15's
   registry once it exists.
3. For anything that is genuinely a new system (capture conversion, artefact echo, spawn
   modifier), **split it out** rather than smuggling it in.
4. Anything still undefined after that goes back to Notion as a question, the way Slow and
   Range did — not into code as a guess.

## Acceptance criteria

- [x] All 103 prerequisite/Special/held-back artefacts triaged by system, with the table kept current
- [x] Shared hooks implemented once, in the trigger-engine registry (`game/scripts/artefact_hooks.gd`)
- [x] Genuinely new systems split into their own slices rather than absorbed (issues 21-26)
- [x] Every remaining ambiguity asked on Notion, not guessed (see Outcome — the 3 open questions)
- [x] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine
- 16 / 17 / 18 — the straightforward tags first

## Outcome (2026-08-28)

**29 of 121 in-scope artefacts shipped** (Special-tagged, `(needs: ...)`-flagged,
or named held-back in issue 16/17/18's own Outcomes). `data/artefacts.js`
flipped to `implemented: true`, re-exported via
`tools/export-game-artefacts.mjs` (`game/data/artefacts.json`: 88 of 180
implemented, up from 59). The other 92 triaged into 6 new issue files
(21-26) or one of 3 Notion questions below — none guessed into code.

### 4 new engine hooks (each a single choke point, REGISTRY + `match` case
only for every artefact after this)

- **`on_piece_lost`** — was already a name in `HOOKS` (a placeholder since
  slice 15/16) but had no call site. The 5 scattered `lost_player += 1`
  sites `game.gd` had (enemy capture, both Reflect directions, both Trap
  directions, `_destroy`) now all call `_lose_player_piece(pos, reason,
  attacker_pos)`, BEFORE the board entry is erased/overwritten. This alone
  unblocked 8 artefacts across 3 different slices' held-back lists (Satoshi's
  Private Key, Lusitania "Hardtack" Crate, Templar Severance Gold, D.B.
  Cooper's Parachute, Nibiru Hide-and-Seek Trophy, Flight 19 Blackbox,
  Backmasked Vinyl, Tutankhamun's Death Thong) — exactly the "two slices
  named it as missing" blocker flagged in the parent task.
- **`on_item_consume`** — `game.gd`'s 3 scattered `items.remove_at` sites
  now call `_consume_item(index, it)`, which can veto the removal via
  `ctx.cancel` (Dihydrogen Monoxide Battery, Wardenclyffe AAA Batteries:
  "the Item is not consumed" — the Item's own effect still fires either
  way). Unblocked 7 artefacts.
- **`on_rank_up`** — fires from `merge_logic.gd`'s `commit_merge` (a same-id
  merge, `ids[0] == ids[1]`, is a promotion-chain step, not a Fusion) and
  `game.gd`'s "promote" Item. `ctx.pos.x < 0` (landed in Stock, not the
  board) is how Holy Grail Coaster knows to convert the bare Stock id into a
  buff-carrying Dictionary — Sleeper Agent Pillow's exact pattern (issue 18).
  Unblocked 3 artefacts.
- **`on_tariff_apply`** (`economy.gd apply_tariff`) / **`on_tariff_charge`**
  (`economy.gd charge`, only when a charge actually happens) — both were
  already single choke points with no call-site changes needed; unblocked 2.

Plus a non-hook unlock: **"Ranked"** reads as `ItemLogic.chain_base(defs,
id) != id` — reusing the promotion-chain seed the parent task named — which
resolved 2 more artefacts directly off the existing `on_capture` hook (CIA
Heart Attack Gun) and `on_wave_clear` (Montauk Eggo Waffle), plus fed 3 of
the `on_piece_lost`/`on_rank_up` artefacts above (Templar Severance Gold,
Backmasked Vinyl, Bigfoot Toenail Clipping).

### Shipped (29)

on_piece_lost (8): Satoshi's Private Key, Lusitania "Hardtack" Crate,
Templar Severance Gold (One Pile), D.B. Cooper's Parachute, Nibiru
Hide-and-Seek Trophy, Flight 19 Blackbox, Backmasked Vinyl, Tutankhamun's
Death Thong.
on_item_consume (7): Arms Fair Goodie Bag, Doomsday Autoclicker, Tape Eraser
Magnet, Dihydrogen Monoxide Battery, Wardenclyffe AAA Batteries, 33rd Degree
Fidelity Card, Defense Lobbyist Business Card.
on_rank_up (3): Witness Protection Mustache, Holy Grail Coaster, Bigfoot
Toenail Clipping.
Chain-lookup off existing hooks (2): CIA Heart Attack Gun, Montauk Eggo
Waffle.
Board-half reads, no new hook (2): Dyatlov Geiger Counter, FEMA Summer Camp
Flyer.
Enemy auto-debuff, BuffLogic is owner-agnostic already (1): Diplomatic
Migraine Ray.
Cheap follow-ups on hooks that landed after their own slice, named in issue
16/17's own Outcomes (3): Casino Invisible Clock, 2012 Doomsday Party Hat,
Fort Knox IOU.
on_tariff_apply / on_tariff_charge (2): Merchants of Death Sample Case,
Tunguska Toothpicks.
Capture conversion, the cheap wave-clear half (1): Stockholm Syndrome
Pamphlet.

### Split into new issues (92 artefacts, 6 files) — genuinely new systems,
not smuggled in

- **21 — artefact echo and meta-triggers** (14): needs `ArtefactHooks.run()`
  itself to expose which keys fired, not just which are held. 100% Genuine
  Original Mona Lisa, Red Diary's Missing Pages, Polybius Cartridge, Max
  Headroom Mask, CERN Ctrl+Z Shortcut, Bilderberg Hotel Slippers, Déjà Vu
  Glitch, Troll Farm Employee of the Month, Ecdysis Sheddings, Illuminati:
  NWO Booster Pack, Illuminati Fridge Magnet, Capstone Polish, Deep State
  Yearbook, New World Order Gerrymandering.
- **22 — Tariff interception** (6): filter/scale/choose/cancel/invert, all
  wanting to change a Tariff's effect rather than just react to it. Panama
  Papers Shredder, Ark Grounding Cable, Exhibit 399, Salvation Gift Card,
  SETI's Red Marker, Amber Room Bubble Wrap.
- **23 — Buff lifecycle hooks** (13): needs `on_buff_apply`/`on_buff_consume`
  choke points, the buff-side mirror of this slice's item/piece ones.
  Amityville Ouija Board, Cleopatra's Hairpin, Guidestone Blood Ritual, KGB
  Photo Eraser, Pied Piper's Rat Census, Antikythera Warranty Card,
  Abduction Probe, 45.5 Carat Curse, mRNA Firmware Update, Atlantis Snow
  Globe, Youth Fountain Martini, Numbers Station Sudoku, Bohemian Grove
  Friendship Bracelet.
- **24 — Combat & positioning rules** (14): zones, dodges, forced moves —
  `Rules.legal_moves`/`_move_player` are deliberately artefact-agnostic
  today. Cheyenne Mountain Doorbell, Winchester Salt Lined Doors, Bovine
  Tractor Beam, Royal Fiat (Undamaged), USS Eldridge Invisibility Paint,
  Inflatable Vietcong Torpedo, UAP Breath Mint, Hoffa's Cement Shoes,
  Fireproof Pajamas, Roanoke Hex Kit, Zapruder's Director's Cut, Pegasus
  Free Trial, Alien Pet Rocks, Curtain Rods Bag (Rifle-Shaped).
- **25 — Per-piece capture ledger** (3): a new field on board piece
  Dictionaries, blocked on an ADR-0002 ruling (does it survive a Stock
  round-trip?). Chupacabra Chew Toy, Zodiac Crossword Puzzle, Alien Rocket
  Toy.
- **26 — Economy, Shop, Box and misc small systems** (42): the grab-bag —
  each row its own tiny system (item cap, spawn modifier, box reroll,
  purchase counter, credit system, gold-action exchange, threshold hooks,
  and more), triaged individually in the file rather than forced into a
  shared abstraction that doesn't exist.

### Open Notion questions (not guessed into code)

1. **Dark Market Light Bulb** — "Demoted pieces give no Score on Capture."
   The Ranked half is cheap now (`ItemLogic.chain_base`), but no "Demoted"
   state exists or can exist without new tracking: a piece demoted to its
   base is indistinguishable from one that was never promoted. Is this
   artefact's text meant to change, or is a `demoted` flag worth adding?
2. **"Shop visit" is a retired term** (issue 18 already flagged this) but 3
   more artefacts still use it in their text: Pandemic Toilet Paper Pallet,
   Jet Fuel Vial (both `(needs: ...)`-flagged, deferred to issue 26), plus
   the 2 issue 18 already named. Does the Shop need a discrete visit/session
   boundary added back, or do all 4 re-text to a Wave-scoped equivalent?
3. **Illuminati Fridge Magnet** — "own Artefacts of every rarity" can never
   be literally true while any of the 7 core keys (`greed`, `score`, `move`,
   `lifesteal`, `timer`, `bounty`, `first_capture_extra`) are held, since
   they predate the rarity system and carry none. Give them a nominal
   rarity, or exclude them from this artefact's check by design?

### Rebase note

Issue 13 (tariff migration onto `ArtefactHooks`) landed on `main` while this
branch was in flight, restructuring `Economy.charge()`/`gain()`/`apply_tariff`
around a new `on_charge`/`on_gold_gain` pair and retiring `tariff_on`
entirely. Rebased with both sides kept: `on_tariff_charge` (this slice) now
fires right after issue 13's `on_charge` dispatch leaves `ctx.charged`
true, inside the same `if ctx.charged:` block, instead of re-querying
tariff state itself (`tariff_on` no longer exists to query). `on_tariff_apply`
needed no change — `apply_tariff` wasn't touched by issue 13. Also fixed a
real bug this rebase's re-test surfaced: `on_rank_up`'s Stock-landing case
(Holy Grail Coaster) originally read "the last Stock entry," which broke
when another on_rank_up handler (Bigfoot Toenail Clipping) appends its own
Stock grant in the same dispatch — `merge_logic.gd` now hands the handler
the exact index the merge itself placed the result at (`ctx.stock_index`),
so order between the two handlers can't shift which entry gets converted.

### Tests

`game/tests/test_items.gd` gained coverage for all 8 on_piece_lost
artefacts (including the Reflect/Trap/enemy-capture/`_destroy` call sites
directly, not just the happy path), all 7 on_item_consume artefacts
(including the cancel-veto pair not leaving the Item behind), all 3
on_rank_up artefacts (board-landing and Stock-landing both), the two
chain-lookup artefacts, both board-half artefacts, the enemy-auto-debuff
artefact, the 3 cheap-hook-follow-ups, and both Tariff hooks.
`game/tests/test_shop.gd` needed one fix unrelated to the hook work: its
"a restock refills all 22 slots" scenario holds whichever artefact happens
to roll into a fixed slot for the rest of the run, and this slice's larger
artefact pool changed what a fixed rng seed rolls there — the test now
explicitly avoids the 3 slot-count-modifying keys (Chocolate Key Cake,
Alleged Weather Balloon, Sub-Antarctic Visa, issue 18) when picking that
slot, so it stays correct regardless of future pool growth.
`game/data/scenarios.gd` gained "Artefacts: slice 19 (Special + prereqs)"
holding a representative sample across all 4 new hooks, swept by
`test_scenarios`. `game/tests/run_all.sh` — ALL GREEN.
