# 61 — "Once per Shop visit" is not a real boundary

Status: done (2026-08-30)

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

## Fix — RULED 2026-08-30

**Both move to per Wave, and every mention of "per visit" is removed.** The user's call:
one boundary instead of two, and the weak one retired outright.

- **Jet Fuel Vial** -> *"Once per Wave: pay 20 Gold to restock the Shop"*
- **Pandemic Toilet Paper Pallet** -> *"Every 2nd purchase in the same Wave costs 50% less"*

Use the established idiom: a `*_used_this_wave` / per-Wave counter reset on `on_wave_clear`,
exactly as Hoffa's Cement Shoes, UAP Breath Mint, Inflatable Vietcong Torpedo, Bovine Tractor
Beam and Zapruder's Director's Cut already do. Delete the `_open_shop()` resets entirely.

**Note the Pallet gets *better* for the player**, not just sturdier: its count now persists
across Shop visits within a Wave, so closing the panel no longer silently discards progress
toward the discount. That is a small buff, and intended.

**Alternative considered and rejected:** tying the flag to the actual stock roll rather than
the panel open. It sounds tighter, but Jet Fuel Vial's own effect *is* a restock, so it would
reset its own flag and loop — it needs a self-exclusion carve-out that per-Wave avoids.

### Every site to clean

Catalog text (`data/artefacts.js`, then re-export):
- Jet Fuel Vial, Pandemic Toilet Paper Pallet — both texts above.

Code — the term appears in 10 places, all to be updated or deleted:
- `game.gd:186-187` (pallet_purchase_count's comment), `316` (the once-per limit comment),
  `331-332` (jet_fuel_used_this_visit + comment), `3034-3035` (the `_open_shop` resets —
  **delete both**), `3045` (the docstring), `3050` and `3067` (the flag reads/writes).
- `artefact_hooks.gd:2461` (the Pallet comment). Line `372` already refers to *"the retired
  Shop visit term"* — make that accurate rather than aspirational.

Rename the variables too (`jet_fuel_used_this_wave`, and the Pallet counter) so no stale
"visit" survives in an identifier.
## Wider point worth recording

**"Per Shop visit" is not a durable boundary in this codebase**, because the Shop panel can be
opened and closed at will. Any future card wanting a "per visit" limit has the same hole. The
sturdy boundaries here are **per Turn**, **per Wave**, and **per restock** — prefer those.
Issue 60 (selling) should not introduce a per-visit limit for the same reason.

## Acceptance

- Jet Fuel Vial cannot restock more than once per Wave regardless of panel open/close —
  **assert it by actually closing and reopening the Shop**, since that is the failing case.
- Card re-texted in `data/artefacts.js`, exported via `node tools/export-game-artefacts.mjs`.
- The Pallet's count persists across Shop visits within a Wave — assert that closing and
  reopening no longer resets it.
- **No occurrence of "visit" remains** in `data/artefacts.js`, `game.gd` or
  `artefact_hooks.gd` as a live boundary — grep for it as part of the work.
- `run_all.sh` ALL GREEN, foreground.

## Blocked by

- nothing

## Outcome

Shipped on `fix/retire-per-visit-61`. Both cards moved to per-Wave, `_open_shop()`'s two
resets deleted outright, and no "Shop visit" boundary survives anywhere in the code.

Final card texts:

- **Jet Fuel Vial** — *"Once per Wave: pay 20 Gold to restock the Shop"*
- **Pandemic Toilet Paper Pallet** — *"Every 2nd purchase in the same Wave costs 50% less"*

`jet_fuel_used_this_visit` renamed to `jet_fuel_used_this_wave`, reset in
`WaveLogic.queue()` — no REGISTRY entry, same no-REGISTRY activation family as
`zapruder_used_this_wave`/`bovine_used_this_wave` (game.gd:335, wave_logic.gd:38).
`pallet_purchase_count` (game.gd:185, name unchanged — it never had "visit" in it) keeps
its existing REGISTRY entry (`on_purchase`/`on_price`) and gained an `on_wave_clear` case
in `artefact_hooks.gd`, same idiom as Hoffa's Cement Shoes/UAP Breath Mint/Inflatable
Vietcong Torpedo. `game.gd:372`'s note calling "Shop visit" "retired" — written
aspirationally when it wasn't true yet — is now literally accurate.

Asserted the actual failing case, not just the happy path: `test_items_artefacts_4.gd`
calls `jet._open_shop()` after spending the Jet Fuel charge and checks it is still spent
(`jet_fuel_used_this_wave` still true, `_jet_fuel_restock_available()` still false) —
this exact assertion would have passed before the fix, since the old code cleared the
flag right there. `test_items_artefacts_3.gd` does the same for the Pallet, closing the
Shop at an odd purchase count (1, discount pending) so a stray reset — which would drop
it to an even count with no discount pending — shows up in `Shop.price()`, not just the
raw counter. Both suites then confirm the counters DO reset via `WaveLogic.queue(g, g.wave
+ 1)`, the established per-Wave idiom. `test_game_clicks.gd`'s click probe renamed
`jet_fuel_used_this_visit` -> `jet_fuel_used_this_wave` and its "Shop visit" wording.

`node tools/export-game-artefacts.mjs` re-run; `game/data/artefacts.json` carries both new
texts.

Grepped `data/artefacts.js`, `game.gd` and `artefact_hooks.gd` for "visit" — every
surviving occurrence narrates the retirement (this issue, and two historical issue-19/26
changelog entries in `data/artefacts.js` that already called it "the retired 'Shop visit'
term" ahead of when it actually was) or is unrelated flavor text ("visitors" in other
artefacts' summaries); none names a live boundary.

`game/tests/run_all.sh` (foreground, alone): **ALL GREEN**.
