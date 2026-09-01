# 97 — Converting Captured -> Stock costs Gold

Status: **ALREADY SHIPPED** — rescoped 2026-09-01, see below

## Parent

`.scratch/gdd-gaps/PRD.md`

## The mechanic already exists

`game.gd:3577` — `_convert_captured()`:

```gdscript
var cost := Shop.sell_price(self, "captured", entry)
captured.erase(entry)
stock.append(entry)
Economy.spend_gold(self, cost)
```

Converting a Captured piece into deployable Stock **already charges Gold**, at
`Tuning.SELL_RATE` (50%) of the piece's value. It is also deliberately excluded from The
Syndicate's Insider Rates discount (`armies.gd`, `shop.gd:373`) — "it is not a Shop purchase,
and discounting it would reopen the convert/sell arbitrage that equal rates deliberately
closed" (issue 68). Slice 81 shipped a board for it: *"Captured Stock: merge, convert at 50%,
sell — and not deployable"*.

So the request as stated is done. Two readings of what was actually wanted:

## (a) The cost is invisible — the likely real gap

Conversion is only reachable through the Shop panel, and nothing on the pool strip says an
entry costs Gold to make deployable. A player looking at their pieces cannot see the price.
**This is the same problem as 96** and should ship with it — put the cost on the entry.

## (b) The cost is wrong, not missing

If the intent is "conversion should cost *more*", that is a **tuning change, not a feature**,
and it belongs in the balance pass rather than a slice of its own — `SELL_RATE` is one
constant and moving it also moves selling, which is the arbitrage the equal rates closed.
Changing conversion alone means splitting the two rates, which issue 68 explicitly decided
against.

## Recommendation

Fold (a) into **96** and take (b) to the balance pass. Do not open a separate slice.

## Blocked by

A ruling on which of (a) or (b) was meant.
