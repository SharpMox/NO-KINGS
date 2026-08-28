# 16 — Artefacts: Gold & Score

Status: partial — 31 of 54

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

The two largest bonus tags and the most mechanical: **Gold (53)** and **Score (43)**.
Mostly arithmetic on numbers that already exist, which makes them the right first real
batch — they exercise the slice 15 engine hard without needing new game systems.

Representative of the shape:

- *Tinfoil Hat* — +15% Score gain; −5% Gold gain
- *Tungsten-Filled Gold Bar* — Gold gains also add 2× their amount as Score
- *Zurich Gnome Figurine* — at Wave end, refund 10% of Gold spent in the Shop
- *Nero's Marshmallow Stick* — each capture in a turn gives +25% more Score and Gold than
  the previous one; resets at turn end

Work through the **94 artefacts with no `(needs: …)` prerequisite** first, taking the
Gold- and Score-tagged ones. Anything whose text carries a `needs:` note belongs to slice
19 until its prerequisite exists.

Watch for: several of these are *negative* trade-offs (−5% Gold, −50 Score), and Score is
now an up-only number. A Score **penalty** has to be reconciled against that rule before
it can ship — either it debits Gold instead, or the up-only rule gets an explicit
exception. Settle it here, once, and record it.

## Acceptance criteria

- [x] Every no-prerequisite Gold/Score artefact implemented and flagged `implemented`
      — 31 of the 54; see Outcome for the 23 held back and why
- [x] Percentage modifiers stack per the slice 15 rule
- [x] The Score-penalty question settled and written back to Notion
- [x] A scenario holding a representative handful, swept by `test_scenarios`
- [x] `run_all.sh` all green

## Decision: Score penalties debit Gold (2026-08-28)

Only **4 of 180** artefacts collide with the up-only Score rule, and two of those are rate
reductions (*Daylight Savings Jar*, *45.5 Carat Curse*: "−20% Score gain") — a smaller gain
is still a gain, so Score never falls and they need no change.

That leaves exactly two real subtractions: *27 Club Punch Card* (−50 Score) and *Social
Credit Report Card* (−10 Score).

**Ruling: those two debit Gold instead.** The up-only rule is load-bearing and stated on
three GDD pages (Score, Shop, Reward Economy) — it is why the final Score is an honest
leaderboard number. Two artefacts do not overturn it, and Gold is where every other
penalty in the game already lands. Re-text both on Notion when implementing.


## Blocked by

- 15 — trigger engine

## Outcome (2026-08-28)

Of the 54 no-`needs:` Gold/Score artefacts, **31 shipped**, all key-for-key against
`data/artefacts.js` names via `tools/export-game-artefacts.mjs`'s slugify.

Engine additions this slice made (each a single call site, so future artefacts on
these hooks stay a REGISTRY line + a `match` case — no call sites touched):
- `on_score_change` / `on_gold_change` wired into `Economy.earn()`, ctx =
  `{base, amount, reason}`. Every percentage handler adds off the immutable
  `base`, never the running `amount` — that's what keeps two held copies
  additive instead of compounding.
- `on_capture` ctx grew `attacker_id` / `attacker_buffed` (board[from], read
  while still on the board) and `wave_capture_index` / `turn_capture_index`
  (tracked centrally in `Economy.capture_score`).
- `on_wave_clear` (n > 1 only) / `on_wave_spawn`, both wired once inside
  `WaveLogic.queue()` since both existing call sites already funnel through it.
  ctx snapshots `clean`, `turns`, `captures`, `gold_spent`, and `gold_base`
  *before* the counters reset, so "% of current Gold" payouts stay additive
  across copies the same way `ctx.base` does above.
- `on_purchase` wired once in `Shop.buy()`; `on_game_over` is a new hook
  (added to `HOOKS`), wired once in `game.gd:_game_over()` before the run is
  scored/saved.

**Shipped (31):** Tinfoil Hat, Daylight Savings Jar, The Red Phone, Bermuda
Triangulation, Naruto Run Manual, Moon Landing Slate, El Dorado Body Glitter,
Tungsten-Filled Gold Bar, Popemobile Piggy Bank, Suspiciously Large Femur,
Sphinx's Booger, Phantom Punch Glove, Azimuthal Pancake Map, Men in Black
Prescription Sunglasses, Holy DNA Kit, CIA Press Pass, Library of Alexandria
Matchbox, Voynich Dictionary, Nero's Marshmallow Stick, Zurich Gnome Figurine,
Social Credit Report Card, QAnon Profile Picture, Bielefeld Library Card,
Trilateral Meeting Stickers, Money Printer Service Manual, Alien Autopsy
Bloopers, Golden Buddha Bobblehead, Nigerian Prince Wire Transfer, John
Titor's Crypto Wallet, Putin's Golden Toilet Brush, Rapture Insurance Policy.

**Held back (23)** — text was faithful-implementable-or-nothing; none of these
got a partial/lossy implementation:
- **Needs an `on_piece_lost` hook** (piece loss has ~5 scattered sites in
  `game.gd` — reflect, trap, enemy capture, `_destroy` — no single choke
  point yet, unlike the hooks this slice added): Satoshi's Private Key,
  Lusitania "Hardtack" Crate, Templar Severance Gold (One Pile), D.B.
  Cooper's Parachute, Nibiru Hide-and-Seek Trophy.
- **References a piece-tier concept the codebase doesn't have** (no
  "Ranked"/"Demoted" state tracked on a piece): CIA Heart Attack Gun, Dark
  Market Light Bulb.
- **Needs a trigger point outside the 13 hooks, with no clean single call
  site found this pass** — Piece Buff resolving (Amityville Ouija Board,
  Cleopatra's Hairpin), a Tariff activating/charging (Merchants of Death
  Sample Case, Tunguska Toothpicks), a Demote/buff-consumed event (Guidestone
  Blood Ritual), an Item use (Arms Fair Goodie Bag, Doomsday Autoclicker,
  Tape Eraser Magnet).
- **Shop price modifiers**: no hook covers "Shop prices +X%" (Skull and Bones
  Coffin, Shrinkflation Cereal Box) — would need a 14th hook or a special
  case in `Shop.price()`; deferred rather than half-implementing the rest of
  either artefact's text.
- **The text has a clause the ctx.pts→earn() pipeline can't express without
  a fragile flag threaded across hook dispatches**: Curtain Rods Bag
  (Rifle-Shaped) — "double Score, but it pays no Gold" needs to suppress the
  derived Gold from *this one* capture only.
- **Cross-artefact interaction, deliberately deferred rather than rushed**:
  Deep State Yearbook and New World Order Gerrymandering both modify what
  *other* artefacts pay — real design work for its own pass.
- **Acquisition-path ambiguity**: Capstone Polish ("on acquiring an
  Artefact") would only fire for Shop purchases via `on_purchase`, missing
  box-granted artefacts (a different call site) — held back rather than
  ship a narrower trigger than the text describes.
- **Rarity isn't threaded to runtime artefact instances**: Illuminati Fridge
  Magnet ("own Artefacts of every rarity") needs a key→rarity lookup that
  `Items.ARTEFACT_EFFECTS` doesn't carry (and the 7 core keys have no rarity
  at all) — a small but real plumbing gap, not this slice's scope.
- **Doesn't fit the hook/REGISTRY pattern as a one-off special case**: Amber
  Room Bubble Wrap ("ignore Inflation and other gold-reducing Tariffs")
  would mean a bespoke branch inside `Economy.gain()` outside the hook
  system entirely.

**Decision applied**: Social Credit Report Card's `-10 Score` penalty now
reads `-10 Gold` in both `data/artefacts.js` and the Notion Artefacts DB
page, per the ruling above. 27 Club Punch Card carries the same ruling but
is still `(needs: streak tracking)` — deferred to whichever slice adds that
and re-texts it then, as the ruling already says.

**Tests**: `game/tests/test_items.gd` gained coverage for stacking (two
Tinfoil Hats: +30%/-10%, not compounding), a Gold→Score cross-effect
(Tungsten-Filled Gold Bar), a wave-clear payout (Zurich Gnome Figurine), the
Social Credit debit-Gold ruling (both branches), and the turn-escalation
math (Nero's Marshmallow Stick). `game/data/scenarios.gd` gained "Artefacts:
Gold/Score batch (issue 16)" holding 7 of the 31, swept by `test_scenarios`.
