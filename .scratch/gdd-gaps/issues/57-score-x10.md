# 57 — Score ×10 across the board

Status: done (2026-08-30)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

The Shop's restock thresholds are unreachable. The GDD Shop page flags it itself: fleet data
has a median Crown run ending near **Score 300**, and the first threshold is **1000**. Either
the threshold drops or income rises. The user chose income (2026-08-30): **multiply Score by
10**.

## Scope

Multiply by 10:

- **Piece capture values** (`defs[id].value` as it feeds Score — see the caution below).
- **Regular Score-gain mechanics** — wave-clear bonuses, early-clear, streaks, every
  ordinary source.
- **Flat Artefact Score constants** — user follow-up: *"bump the flat artefact gains also"*.
  So `+10 score per Pawn captured` (Greed) becomes +100, Bounty's +30 becomes +300, Oak
  Island Wishing Well's +400 becomes +4000, and so on.

**Percentage-based effects need no change** — they scale automatically, and touching them
would compound the multiplier.

## The one thing that will go wrong if rushed

**A piece's `value` is not only a Score number.** `Shop.price()`'s `"piece"` branch returns
`float(g.defs[slot.key].value)` — the piece's value *is* its Gold price — and
`_sample_pieces` weights the Shop roll by `1.0 / value`. Cicada Rejection Letter (issue 49)
also values Box pieces at `defs[id].value`.

So multiplying `defs[].value` blindly would **multiply every piece's Shop price by 10** and
leave the Gold economy untouched, making pieces unaffordable overnight.

**Decide explicitly**: either scale Score at the point of scoring (leaving `value` as the
Gold/price number it also is), or scale `value` and divide it back out at every Gold site.
The first is almost certainly right — it keeps one meaning per field. Say which you chose
and why in the commit.

## Expect large test churn, and treat it carefully

Nearly every Score assertion in the suite will move. That is expected — but it is also the
perfect cover for a real regression. For each changed assertion, confirm the new number is
`old × 10` (or a documented exception) rather than simply pasting whatever the run printed.
An assertion that changes by a factor of anything other than 10 is a finding, not a chore.

`SCORE_BOX_CHUNKS` is gone (issue 47), so there is no Score Box to update.

## Acceptance

- Score sources ×10; percentage effects untouched; **Shop piece prices unchanged**.
- Assert a piece's Shop price is what it was before this slice — that is the guard against
  the `value` trap above.
- The Shop's first restock threshold is now plausibly reachable in a median run; say what a
  quick autoplay sweep shows rather than asserting a specific number.
- `run_all.sh` ALL GREEN, foreground.

## Blocked by

- nothing

## Outcome

Shipped in PR #215.

**Scaled at the point of scoring, as specced** — `Economy.SCORE_MULTIPLIER := 10` applied in
`earn()`, the single choke point every ordinary Score source already routes through. The trap
was avoided: `defs[].value` is **untouched** (verified — 0 diff lines), because it is also the
Gold price read by `Shop.price()`, the `1/value` roll weighting in `_sample_pieces`, and Cicada
Rejection Letter's Box valuation.

Two details that make it correct rather than merely working:
- **Gold still derives from the raw, unscaled `amount`** in `gain()`, so a Score x10 never
  leaks into Gold.
- **The `on_score_change` dispatch stays on the UNSCALED base**, so percentage handlers and
  cross-resource converters (El Dorado's `ctx.gold_bonus`) are unaffected — the x10 lands only
  on the two writes to `g.score`, right at the end.

The guard held: `test_shop.gd`'s existing `Shop.price(game, slot) == int(game.defs[slot.key].value)`
assertion is **byte-for-byte unmodified** and still passes.

**~40 assertions moved by exactly 10x.** Four did not, all reported rather than quietly
adjusted:
1. Social Credit Report Card 600 -> 1500 (a preset `score: 500` baseline is not a gain; only
   the +100 scaled).
2. Threshold boundary tests had their `earn()` *arguments* divided by 10 (999 -> 99), because
   `earn()` now has a 10x granularity floor — you cannot land on exactly 999. Semantically
   identical, shifted by construction.
3. **The real finding** — see the new FLAGS.md entry. The Wave-10 milestone bonus now exactly
   equals `threshold(0)`.
4. A windowed click-probe assertion (Oak Island, 400 -> 4000) missed on the first pass because
   the sweep grepped headless tests only. **Caught by the full `run_all.sh`** — a good argument
   for the probes running as part of the suite rather than on demand.

**Autoplay sweep:** 5 runs — waves 43/46/45/19/9, scores 68700/75200/72800/13600/2800. Every
run cleared `threshold(0)`; several banked 5-6 restocks. Restock reachability looks fixed,
reported as observation rather than asserted.

Also fixed the stale `items.gd` docstring claiming `implemented` is false for all 180. Left the
file header's *"STATUS triage synced 2026-07-14"* alone as unverifiable without a Notion
snapshot — correctly flagged rather than guessed.
