# 60 — Selling: Stock pieces, Items and Artefacts

Status: todo — NEEDS DESIGN DECISIONS (the exploit below is the blocking one)

## Parent

`.scratch/gdd-gaps/PRD.md`

## What the user asked for

Let the player **sell Stock pieces, Items and Artefacts** back for Gold.

Straightforward as a feature. The problem is not the selling — it is what selling turns two
already-shipped Artefacts into.

---

## THE BLOCKER: two pay-on-purchase Artefacts become infinite Gold

Buying **costs no Action** (`shop.gd`'s own header: *"not a board action"*), so a buy/sell
cycle is limited only by the Clock. Two shipped Artefacts pay out on purchase:

### Deep State Yearbook (Uncommon) — the severe one

> On buying an Artefact: each other Artefact you own pays +5 Gold

The payout scales with **how many Artefacts you hold**, not with what you paid. Hold 20,
buy a Common Artefact for 50 Gold, receive **5 × 19 = 95 Gold**. Sell it back at 50% (25) and
you net **+70 per cycle**, forever. A lower sell rate does not fix this — the payout is
independent of price, so a large enough collection always outruns the spread.

### Mao's Loyalty Badge (Uncommon)

> On buying a Tactical Item in the Shop: a second random Tactical Item is free

Buy one Tactical Item at 30 Gold, receive **two**. At a 50% sell rate that is 15 + 15 = 30 —
exact break-even, so it is a free, unbounded Item generator even without profit. Above 50% it
is straight profit.

(**Ark's Bunkbed** duplicates a bought Piece but is capped *once per 5-Wave Milestone*, so it
is bounded and fine. **Sleeper Agent Pillow** grants a Buff, not value.)

### Options — one of these must be chosen before this can ship

1. **Artefacts cannot be sold.** Kills the Deep State Yearbook loop outright and shrinks the
   feature to Pieces + Items. Mao's still needs option 3 or 4.
2. **Sell price is a flat low rate AND the pay-on-purchase Artefacts are capped** — e.g. Deep
   State Yearbook fires once per Wave, Mao's once per Shop visit. Keeps the feature whole;
   changes two shipped cards.
3. **You cannot sell something you acquired this Shop visit.** Blocks the tight loop, but the
   Yearbook loop still works across visits — it only slows it down.
4. **Selling pays Score, not Gold.** Removes the Gold cycle entirely, since the exploit needs
   Gold back to re-buy. Changes what the feature *is*, but it is the most robustly
   loop-proof.

*Recommendation: **2**.* It keeps the feature the user actually asked for and treats the two
cards as what they are — effects written before selling existed, which never anticipated a
Gold-out path. Capping them is a smaller change than amputating the feature.

---

## Scope, once the above is decided

### What can be sold

- **Stock pieces** (`g.stock`) — asked for explicitly.
- **Captured Stock** (`g.captured`) — decide. It is a separate pool and the same argument
  applies; recommend yes, for consistency.
- **Items** (`g.items`).
- **Artefacts** (`g.artefacts`) — pending the decision above.
- **Not** board pieces. Extraction already exists for board -> Stock, so selling a board
  piece is two steps, deliberately.

### Sell price

Every kind already has a buy price, so the sell rate is one constant:

| Kind | Buy price | Notes |
| --- | --- | --- |
| Piece | `g.defs[id].value` | value *is* the price — see issue 57, do not confuse it with Score |
| Item | `Tuning.SHOP_ITEM_PRICE[tier]` | |
| Artefact | `Tuning.SHOP_ARTEFACT_PRICE[rarity]` | |

*Recommendation: **50%**, rounded down*, as a new `Tuning.SELL_RATE`. Round **down** so the
spread never disappears on cheap items.

Note issue 57 multiplies Score by ×10 but explicitly **not** these prices — make sure selling
reads the price, never the Score value.

### Softlock guard

**The player must not be able to sell themselves into an unwinnable state.** Check what
happens with an empty Stock, empty board, and no Gold — if that state exists and cannot
recover, block the sale that would create it. Find the case rather than assuming it cannot
happen; Hellfire Club (issue 54) had exactly this shape.

### UI

The Shop is the natural home — it already lists prices and has the buy flow. Selling needs a
distinct affordance so it can never be confused with buying: the drawer is deliberately
no-scroll, so a "Sell" mode toggle on the Shop screen is likely cheaper than a parallel list.
Decide, and extend the **windowed click probes** — this is interactive UI.

### Interactions to check

- **Item cap 3** (issue 53) — selling is a second way to get under it, alongside spending.
  That is fine and probably good.
- **Denver Bunker Timeshare** (+30% Gold while Items are full) — selling an Item drops you
  below full and turns the bonus off. Intended, worth a test.
- **Tape Eraser Magnet** ("on using your **last** held Item: +100 Score and +50 Gold") —
  selling is not using. Confirm it does **not** fire on a sale.
- **Ecdysis Sheddings** copies the last Artefact you *bought*; issue 55 ruled the key
  persists after that Artefact leaves. Selling it should behave the same way — confirm.
- **Moscovium Glow Stick** is consumable; make sure selling and consuming cannot both happen.

## Acceptance

- Selling works for each permitted kind at the agreed rate, paying Gold (or Score, per the
  decision).
- **The two exploit loops are closed and tested** — assert that repeated buy/sell with Deep
  State Yearbook and with Mao's Loyalty Badge cannot net positive value.
- No sale can create an unrecoverable state.
- Click probes extended for the new UI.
- Tests in the split suites, seeds pinned. `run_all.sh` ALL GREEN, foreground.

## Blocked by

- the exploit decision above (options 1-4)
- whether Captured Stock is sellable
