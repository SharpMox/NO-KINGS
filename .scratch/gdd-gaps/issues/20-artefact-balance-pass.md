# 20 — Artefact rarity, weighting & balance pass

Status: done

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

With the catalog implemented, make it *play*. Today artefacts are rolled uniformly from a
7-entry list; at 180 with four rarities that is no longer acceptable.

- **Rarity weighting.** Common 50 · Uncommon 54 · Rare 50 · Legendary 26. Box rolls and
  Shop stock draw weighted by rarity, not uniformly. Weights are tuning constants.
- **Rarity should be visible.** A Legendary and a Common look identical in the box-pick
  and shop today.
- **Progression.** Legendaries appearing on wave 2 flattens the run. Decide whether rarity
  is gated by depth/score or purely random, and record it.
- **Anti-stacking.** Artefacts stack. Some combinations are almost certainly degenerate
  once 180 exist — a percentage stack that runs away, or two artefacts that feed each
  other. Run the fleet/autoplay sweep with random artefact loadouts and look for runs that
  never end.
- **Shop pricing by rarity.** The Shop page currently prices every artefact at 100 flat.
  With four rarities that is probably wrong, and it is already listed as an open question
  on the page.

This is the slice where autoplay earns its keep: it can play thousands of runs with random
loadouts and surface the combinations a human would take weeks to find.

## Acceptance criteria

- [x] Rolls and Shop stock weighted by rarity; weights in `tuning.gd`
- [x] Rarity is legible in the box-pick and the Shop
- [x] Progression rule decided and written back to Notion
- [x] A fleet sweep over random loadouts, with degenerate combinations listed
- [x] Per-rarity pricing decided, and the Shop page's open question closed
- [x] `run_all.sh` all green

## Decision: rarity is depth-gated (2026-08-28)

The page asks whether rarity is gated by progression or purely random. **Gate it.**

Legendaries appearing on wave 2 flattens the run — the whole pressure model is a ramp, and
a Legendary in the first shop stock removes the ramp's early half. Weight the draw so
Legendary and Rare probability rises with depth (wave, or cumulative Score, whichever the
restock cadence already uses) while Common tapers.

Exact curve is a tuning constant, not a design decision — start linear, then let the fleet
sweep in this slice's own acceptance criteria say whether it needs shaping.


## Blocked by

- 16 / 17 / 18 / 19 — enough of the catalog implemented to be worth balancing

## Outcome (2026-08-28)

**Weighting.** `tuning.gd` `ARTEFACT_RARITY_WEIGHT_START` — Common 100 / Uncommon 40 /
Rare 20 / Legendary 10 (~10:4:2:1, population-independent — a Legendary is rare to draw
regardless of how many Legendaries the catalog has). Box rolls (`box.gd`) and Shop stock
(`shop.gd`, both the normal 4-slot roll and the Sub-Antarctic Visa hidden-slot bias) draw
through the same `Tuning.weighted_artefact_pick`.

**Depth gating, keyed off cumulative Score** (what the Shop's own restock cadence already
uses — `SHOP_RESTOCK_BASE`/`STEP` — so box.gd and shop.gd share one depth signal instead of
wave, which box.gd's roll doesn't otherwise track). Linear ramp from
`ARTEFACT_RARITY_WEIGHT_START` at Score 0 to `ARTEFACT_RARITY_WEIGHT_DEEP` (Common 20 /
Uncommon 45 / Rare 45 / Legendary 35) at Score ≥ `ARTEFACT_RARITY_DEPTH_CAP_SCORE` (5000,
~3rd shop restock). The 7 core artefacts (no rarity) stay flat at weight 100, ungated —
they predate the rarity catalog. Verified in `test_box.gd`: at Score 0 a synthetic
Common-vs-Legendary pick landed 1838:162 (~11:1) over 2000 draws; past the depth cap it
flipped to 712:1288 favoring Legendary. An integration check on `game._box_options()`
itself showed Common's share of artefact rolls dropping 0.75 → 0.24 as Score went from 0 to
50000.

**Legibility.** Shop tiles tint by rarity (`self_modulate`, so the price badge stays
readable) and the expanded detail dock adds a colored rarity label; the box-pick list adds
"· Rarity" to the header and tints the option's text. Colors in `Tuning.ARTEFACT_RARITY_COLOR`
(grey/green/blue/gold, Common→Legendary). Fits the existing no-scroll icon-tile drawer from
issue 08 with no layout changes.

**Per-rarity pricing** (closes the Shop Notion page's "Artefact — 100 flat" price row):
Common 50 · Uncommon 100 · Rare 200 · Legendary 400 (`Tuning.SHOP_ARTEFACT_PRICE`, doubling
per tier like `SHOP_ITEM_PRICE`'s tier jumps). The 7 core (unrated) artefacts price as
Common, 50. The existing hidden-slot +50% and `on_price` percentage modifiers (Denazification
Visa, Hollow Moon Cross-Section, Shrinkflation Cereal Box, Skull and Bones Coffin, Silk Road
Coupon) compose on top unchanged — all percentage-of-base, no absolute-value assumptions to
break. Written back to the Notion Shop page (page id `3c9f1559-c99b-8153-b127-ea8c079c02cd`).

**Anti-stacking sweep.** Bounded per the coordinator's steer — not an exhaustive search.
**26 headless `--autoplay` runs** (`--artefacts` CLI flag added for this slice, forcing a
starting loadout on top of the normal boot path): 14 targeted stacking suspects (same
artefact ×5/×10, suspected feed-each-other pairs, a "kitchen sink" of every gold/score-hook
artefact), 4 organic baselines (no forced artefacts, varying army), 8 loadouts of 3-7
randomly-drawn implemented artefacts. All 26 finished inside a 1500-step cap — **no run hit
the step cap or otherwise failed to terminate**; the degenerate signal is score/gold
runaway, not an infinite loop.

Headline finding — **Tungsten-Filled Gold Bar + Popemobile Piggy Bank is a real degenerate
pair, and it's an architecture bug, not just a tuning number.** Both hook `on_gold_change`
and write directly to `g.score` (`g.score += roundi(ctx.amount) * 2` / `* 10`) instead of
going through `ctx.amount` like every other percentage handler. `Economy.earn()` already
scores the raw capture amount once *before* dispatching `on_gold_change` — so these two
artefacts silently add a second, uncounted score payout on top of the normal one, on every
single gold gain, bypassing the "immutable base, additive stacking" contract the rest of
the hook system documents and relies on (`artefact_hooks.gd`'s own header). Sweep numbers:
- 1 copy each: score **103,924** (wave 46, Resource starvation) vs. an organic Crown
  baseline of 7,930 / 9,405 in the same sweep — ~11-13x.
- 5 copies each: score **430,830** (wave 46) — ~45-54x baseline, ~4x the 1-copy pair.
- The "kitchen sink" loadout (11 different gold/score artefacts, 1 copy each, including
  this pair) scored 126,069 — dominated by the same two.

Not fixed here (coordinator: list, don't silently nerf) — a follow-up issue should either
route both handlers through `ctx.amount` like their siblings, or cap/rebalance the
multiplier once routed correctly.

Secondary, milder observation: **El Dorado Body Glitter** reads the *running*
`ctx.amount` inside `on_score_change` (`g.gold += roundi(ctx.amount * 0.05)`, comment
acknowledges "reads the possibly already-modified score ctx") rather than the immutable
`ctx.base` every other percentage handler reads from — a real feed-forward path if another
`on_score_change` artefact sorts before it alphabetically and inflates `ctx.amount` first.
El Dorado ×3 + Naruto Run Manual ×3 (chosen to probe this) scored 10,380 — only modestly
above the Crown baseline, so the practical exposure was small in this sweep, but the
architecture gap is the same shape as the headline finding and worth the same follow-up.

Action-stacking (10× `move`, or 5× `move` + Cia's Exploding Cigar + I Am Not A Robot
Checkbox — extra actions/turn) did **not** produce runaway score or an unending run: it
mainly extended turn count before an eventual Resource-starvation loss (1082 and 1218
turns vs. an ~500-turn baseline), scores stayed unremarkable (7,783 / 5,660). Flat
unconditional per-turn artefacts (5×/10× Shrinkflation Cereal Box, +10 score/+10 gold/+1s
clock every turn with no action required) scaled roughly linearly with copy count as
expected (26,090 → 28,210) — strong but bounded, not exponential, and still lost to
Resource starvation in every run.

Full sweep log kept for reference: the sweep script and raw results are scratch, not
committed (`sweep.sh` / `sweep_results.txt` in the agent's scratchpad).
