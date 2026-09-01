# 93 — Hat, Uniform and the rest of Suit: the remaining 11 Kings

Status: done (2026-09-01)

## Parent

`.scratch/gdd-gaps/KINGS-DESIGN-WORKSHEET.md` (ruling 8)

## Outcome — all 16 Kings are built

22 effects, completing the 32 (16 Powers + 16 Abilities) the user set in the design session.

### Hat

| King | Power | Ability |
| --- | --- | --- |
| Genghis Khan | **No Fixed Cities** — you cannot merge | **The Silent Steppe** — strips every Piece Buff from your board |
| Tamerlane | **Scorched Earth** — Score gains halved | **The Pyramid of Skulls** — your two *least* valuable pieces die |
| Ivan the Terrible | **The Oprichnina** — Items cannot be used | **Kill the Tsarevich** — one of your pieces turns and fights for the King |
| Emperor Napoléon | **La Grande Armée** — reinforcements arrive with an extra Piece Buff | **Artillery Barrage** — your whole most-crowded column dies |

### Uniform

| King | Power | Ability |
| --- | --- | --- |
| Mao Zedong | **Backyard Furnaces** — pieces you deploy arrive demoted | **The Long March** — every enemy advances a row |
| Joseph Stalin | **The Purge** — your pieces cannot gain Piece Buffs | **Order No. 227** — your pieces on your own back row die |
| Adolf Hitler | **Total War** — every piece you lose also costs Gold | **Total Mobilisation** — +1 enemy Action for the rest of the wave |
| Hideki Tojo | **Kamikaze** — each capture you make also kills the capturer's neighbour | **Total Attrition** — halves the Clock you have left |

### Suit

| King | Power | Ability |
| --- | --- | --- |
| Benjamin Netanyahu | **Iron Dome** — the King cannot be captured while any escort stands | **Targeted Strike** — kills whatever stands closest to the King |
| Vladimir Putin | **Annexation** — your pieces ending your turn in the enemy half are annexed | **Disinformation** — your pieces are shuffled between their own squares |
| Kim Jong Un | **Juche** — the Shop is closed | **The Parade** — flattens your densest 3x3 block |

*(Donald Trump — Tariff / Diplomatic Visit – JD Vance — shipped in slice 91.)*

## Distinctness is enforced, not just intended

A run meets **four Kings of one tier** (issue 89), so four Kings taxing the same resource would
read as one long King rather than four. The suite now asserts it mechanically: **every Power
key and every Ability key is unique across all 16**, so a future addition that duplicates an
existing lever fails the tests rather than shipping as filler.

Within each tier the four levers are deliberately unrelated — Hat hits merging / Score / Items
/ enemy quality; Uniform hits deploy quality / Buff acquisition / loss cost / the act of
capturing; Suit hits the Tariff system / the win condition / ownership / Shop access.

**Iron Dome is the one that changes shape rather than numbers**: it makes the King uncapturable
while any escort stands, so the fight becomes "clear the room first" instead of "reach the
King". Worth keeping in mind if a later balance pass touches King waves.

**Kamikaze taxes the act of capturing** — the move the whole game is built on — which no other
Power does.

## Two implementation traps, both found by tests

1. **`match` takes the first matching branch.** Total Mobilisation (Hitler's Ability, +1 enemy
   Action for the rest of the wave) was first written as a `match` case on
   `on_enemy_turn_start` — where it would have **shadowed any Power answering the same hook**,
   silently cancelling Xerxes' The Countless Host. It is applied *outside* the match, and the
   suite asserts the two stack (tier base + 1 + 2).
2. **All 16 Kings now have kits**, so the "a kitless King is charged no Action" assertions had
   no subject left. They use `larry` — the wave-201 boss the user parked (ruling 9) — which is
   both a real absent id and self-documenting.

## Design constraints carried from slice 92

- **Scorched Earth halves rather than zeroes Score.** Shop restocks are Score-gated, so zeroing
  Score for a wave would quietly close the Shop too — which is Kim Jong Un's Power, and two
  Kings should not do the same thing by accident.
- **Total War routes through `ctx.gold_bonus`, never `g.gold`** — `artefact_hooks.gd`'s ctx
  contract, so Economy applies it exactly once.
- **Annexation resolves at the end of the player's turn and only in the enemy half**, so it is
  a rule the player can see and play around rather than an unavoidable drip.
- **Kill the Tsarevich converts rather than destroys; Disinformation costs no material at all.**
  Between them and JD Vance / the Statue / the Pyramid, the Abilities span destroy-best,
  destroy-worst, demote, convert, displace and shuffle rather than being one effect at five
  strengths.

## Verification

`test_kings.gd` — **205 assertions**. Every effect is asserted by its observable consequence:
the Pyramid leaves the *best* piece standing, Kill the Tsarevich reduces your count without a
destroy, Disinformation leaves the count *unchanged*, Iron Dome refuses `_king_down()` with an
escort present and allows it once cleared, Total War lands on `ctx.gold_bonus`.

Live autoplay across four seeds (Crown / Tier 1): ended at waves 47, 13, 49 and **78** — runs
still pass through King waves into Endless with the full cast live.

`run_all.sh` **160.3s ALL GREEN**, foreground, alone.

## Remaining in the Kings program

Nothing structural. Larry (wave 201) stays parked by ruling 9, and issue 82's per-King
sandboxes are now unblocked.
