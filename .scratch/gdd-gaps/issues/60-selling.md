# 60 — Selling: Stock pieces, Items and Artefacts

Status: todo — SPECCED (user rulings 2026-08-30) · one small question left

## Parent

`.scratch/gdd-gaps/PRD.md`

## What the user asked for

Let the player **sell Stock pieces, Items and Artefacts** back for Gold.

Straightforward as a feature. The problem is not the selling — it is what selling turns two
already-shipped Artefacts into.

---

## The exploit, re-examined — NOT a blocker (2026-08-30)

An earlier revision of this issue called the buy/sell loop **infinite**. That was wrong, and
the user was right to push back. Two mechanics bound it, both of which should have been
checked before the claim was made:

- **`Shop.can_buy` requires `not slot.sold`.** Each slot is buyable exactly once, and a stock
  carries only **4 Artefact slots** and **4 Item slots** (`Shop.ROWS`). A loop therefore caps
  at 4 purchases per stock, not unlimited.
- **Restocks are Score-gated**, not free: `while g.score >= threshold(g.shop_restocks)`. You
  cannot spin the Shop at will. Jet Fuel Vial buys exactly one extra restock per visit.

So it is a bounded per-visit gain that scales with collection size — which, as the user put
it, reads as *a good interaction for the Artefacts to have* rather than a defect.

### And the new Artefact cap of 5 closes it arithmetically

With at most 5 held Artefacts, **Deep State Yearbook's maximum payout is 4 x 5 = 20 Gold**.
The cheapest Artefact costs 50 (`SHOP_ARTEFACT_PRICE`, Common). At a 50% sell rate a full
cycle is: pay 50, receive 20, sell back 25 -> **net -5**. It loses money at *every* collection
size, because the cap ends the scaling that made it dangerous in the first place.

No special-casing needed, and neither card has to change. **Mao's Loyalty Badge** is
break-even at 50% (buy one Item at 30, get two, sell both for 15 each) — a free Item
generator with no Gold gain, bounded by 4 Item slots per stock and by the Item cap of 3.
That is mild and, again, an interaction rather than a bug.

---

## The Artefact cap: 5 (user, 2026-08-30)

A third base-game cap, alongside Items (3) and Piece Buffs (2) from issue 53. Same shape as
those: a single choke point, refused cleanly and visibly at the limit, never a silent drop.

**Decide and document:**
- **Do duplicate copies each take a slot?** Almost certainly yes — stacking is per held copy
  (`g.artefacts` holds one entry per copy, and every percentage effect is additive per copy),
  so a cap on entries is a cap on copies. Say so explicitly, because it materially changes
  stacking strategy: 5 total means at most 5 copies of anything, ever.
- **Every acquisition path must respect it** — Shop purchase, Box pick, and Artefact-granting
  effects. `Shop.can_buy` already has the precedent from issue 53's Item cap
  (`ItemLogic.has_room`); mirror it so the Shop never sells an Artefact you cannot hold.
- **The 7 game-native core Artefacts count too** (`ARTEFACT_EFFECTS_CORE`) — they are ordinary
  entries in `g.artefacts`.
- **Ecdysis Sheddings copies a key, it does not hold a copy**, so it should not consume a
  slot. Confirm.

This is what makes selling matter: with a hard cap, selling is how you make room, which is
almost certainly the point.

## Scope, once the above is decided

### What can be sold

- **Stock pieces** (`g.stock`) — asked for explicitly.
- **Captured Stock** (`g.captured`) — decide. It is a separate pool and the same argument
  applies; recommend yes, for consistency.
- **Items** (`g.items`).
- **Artefacts** (`g.artefacts`) — yes; the cap of 5 is what makes this matter.
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

## Do not use a "per Shop visit" limit here

Issue 61: `_open_shop()` resets the per-visit counters and nothing gates reopening the Shop,
so "per visit" means "per panel open" and the player can reset it at will. If selling wants a
rate limit, use **per Turn**, **per Wave** or **per restock** — the boundaries that actually
hold.

## Blocked by

- whether **Captured Stock** is sellable (recommend yes, for consistency) — the only thing
  still open
