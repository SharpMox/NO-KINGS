# 61 — "Once per Shop visit" is not a real boundary

Status: todo — BUG, shipped · user caught it 2026-08-30

## Parent

`.scratch/gdd-gaps/PRD.md`

## The bug

`game.gd`'s `_open_shop()` resets both per-visit counters:

```gdscript
func _open_shop() -> void:
	if box_open or buff_pick_open or preview_open or win_open: # one modal at a time
		return
	pallet_purchase_count = 0
	jet_fuel_used_this_visit = false
	modals.show_shop()
```

Nothing gates **reopening** the Shop — the guard only refuses while another modal is up. So
"once per Shop visit" means "once per panel open", and the player can close and reopen the
Shop freely to reset it.

### Jet Fuel Vial (Common) — exploitable

> Once per Shop visit: pay 20 Gold to restock the Shop

Close the Shop, reopen it, and `jet_fuel_used_this_visit` clears. **Unlimited restocks at 20
Gold each.** That directly defeats the intent `shop.gd` states in its own comment on
`shop_restocks` — *"no reroll-scumming"* — which is why restocks are otherwise Score-gated
(`while g.score >= threshold(g.shop_restocks)`).

Gold is plentiful enough late that 20 per reroll is close to free, so this is not a
theoretical hole: it lets a player mill the Shop for a specific Piece, Artefact or Box.

### Pandemic Toilet Paper Pallet (Common) — not exploitable, but fragile

> Every 2nd purchase in the same Shop visit costs 50% less

Reopening resets the count to **0**, so the next purchase is the 1st and gets no discount —
spamming the panel *loses* you the discount rather than gaining it. Self-defeating, so there
is no exploit here.

It is still fragile: an accidental close silently discards progress toward the discount, with
no feedback. Worth deciding whether that is acceptable or whether this counter should also
move to a sturdier boundary.

## Fix

**Recommendation: move Jet Fuel Vial to once per Wave**, using the established idiom — a
`*_used_this_wave` flag reset on `on_wave_clear`, exactly as Hoffa's Cement Shoes, UAP Breath
Mint, Inflatable Vietcong Torpedo, Bovine Tractor Beam and Zapruder's Director's Cut all do.
It is spam-proof, it matches five existing cards, and it needs no new concept.

Re-text the card to say "Once per Wave".

**Alternative considered and rejected:** tying the flag to the actual stock roll rather than
the panel open. It sounds tighter, but Jet Fuel Vial's own effect *is* a restock, so it would
reset its own flag and loop — it needs a self-exclusion carve-out that once-per-Wave avoids
entirely.

**For the Pallet**, decide separately: leaving it per-panel-open is defensible (it only ever
costs the player, never exploits), but if it moves, it should move to the same Wave boundary
for consistency rather than inventing a third.

## Wider point worth recording

**"Per Shop visit" is not a durable boundary in this codebase**, because the Shop panel can be
opened and closed at will. Any future card wanting a "per visit" limit has the same hole. The
sturdy boundaries here are **per Turn**, **per Wave**, and **per restock** — prefer those.
Issue 60 (selling) should not introduce a per-visit limit for the same reason.

## Acceptance

- Jet Fuel Vial cannot restock more than once per Wave regardless of panel open/close —
  **assert it by actually closing and reopening the Shop**, since that is the failing case.
- Card re-texted in `data/artefacts.js`, exported via `node tools/export-game-artefacts.mjs`.
- A decision recorded for the Pallet either way.
- `run_all.sh` ALL GREEN, foreground.

## Blocked by

- nothing
